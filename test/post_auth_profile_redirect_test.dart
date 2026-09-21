import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/app/session/post_auth_profile_redirect_coordinator.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  ProfileResource resource(ProfileStatus status) => ProfileResource(
    version: status == ProfileStatus.active ? 1 : 0,
    values: ProfileValues(
      alias: status == ProfileStatus.active ? 'Alice' : null,
      avatarRef: null,
    ),
    updatedAt: status == ProfileStatus.active
        ? DateTime.utc(2026, 9, 7, 1)
        : null,
    loopId: 'LOOP-7HJKMNPQ',
    profileStatus: status,
    activatedAt: status == ProfileStatus.active
        ? DateTime.utc(2026, 9, 7, 1)
        : null,
  );

  group('landing decision', () {
    test('pending lands on the LOOP ID setup step', () {
      expect(
        loopProfileLandingFor(resource(ProfileStatus.pending)),
        LoopProfileLanding.loopIdSetup,
      );
    });

    test('active lands on Community', () {
      expect(
        loopProfileLandingFor(resource(ProfileStatus.active)),
        LoopProfileLanding.community,
      );
    });

    test('every failure lands on Community, never on a gate', () {
      for (final kind in ProfileGatewayFailureKind.values) {
        expect(
          loopProfileLandingForFailure(kind),
          LoopProfileLanding.communityUnavailable,
          reason: 'failure kind ${kind.name} must not block login',
        );
      }
    });
  });

  group('coordinator', () {
    test('reads the profile once per newly verified principal', () async {
      var reads = 0;
      final landings = <LoopProfileLanding>[];
      final coordinator = PostAuthProfileRedirectCoordinator(
        readProfile: () async {
          reads += 1;
          return resource(ProfileStatus.pending);
        },
        prepare: (_) async {},
        navigate: landings.add,
        publish: (landing, kind) {},
      );

      final session = _authenticated('did:privy:owner-a');
      coordinator.onSessionChanged(_signedOut(), session);
      await _settle();
      coordinator.onSessionChanged(session, session);
      await _settle();

      expect(reads, 1);
      expect(landings, <LoopProfileLanding>[LoopProfileLanding.loopIdSetup]);
    });

    test('a different principal is checked again', () async {
      var reads = 0;
      final coordinator = PostAuthProfileRedirectCoordinator(
        readProfile: () async {
          reads += 1;
          return resource(ProfileStatus.active);
        },
        prepare: (_) async {},
        navigate: (_) {},
        publish: (landing, kind) {},
      );

      final first = _authenticated('did:privy:owner-a');
      final second = _authenticated('did:privy:owner-b');
      coordinator.onSessionChanged(_signedOut(), first);
      await _settle();
      coordinator.onSessionChanged(first, second);
      await _settle();

      expect(reads, 2);
    });

    test('a preview session never reads the profile', () async {
      var reads = 0;
      final coordinator = PostAuthProfileRedirectCoordinator(
        readProfile: () async {
          reads += 1;
          return resource(ProfileStatus.pending);
        },
        prepare: (_) async {},
        navigate: (_) {},
        publish: (landing, kind) {},
      );

      coordinator.onSessionChanged(_signedOut(), _preview());
      await _settle();

      expect(reads, 0);
    });

    test(
      'a failed read publishes the unavailable landing and its kind',
      () async {
        LoopProfileLanding? published;
        ProfileGatewayFailureKind? publishedKind;
        final coordinator = PostAuthProfileRedirectCoordinator(
          readProfile: () => Future<ProfileResource>.error(
            const ProfileGatewayException(ProfileGatewayFailureKind.offline),
          ),
          prepare: (_) async {},
          navigate: (_) {},
          publish: (landing, kind) {
            if (landing == null) return;
            published = landing;
            publishedKind = kind;
          },
        );

        coordinator.onSessionChanged(
          _signedOut(),
          _authenticated('did:privy:owner-a'),
        );
        await _settle();

        expect(published, LoopProfileLanding.communityUnavailable);
        expect(publishedKind, ProfileGatewayFailureKind.offline);
      },
    );

    test('an unexpected error still lands in Community', () async {
      LoopProfileLanding? published;
      final coordinator = PostAuthProfileRedirectCoordinator(
        readProfile: () => Future<ProfileResource>.error(StateError('boom')),
        prepare: (_) async {},
        navigate: (_) {},
        publish: (landing, kind) => published = landing,
      );

      coordinator.onSessionChanged(
        _signedOut(),
        _authenticated('did:privy:owner-a'),
      );
      await _settle();

      expect(published, LoopProfileLanding.communityUnavailable);
    });

    test('signing out drops the landing instead of answering for it', () async {
      final published = <LoopProfileLanding?>[];
      final coordinator = PostAuthProfileRedirectCoordinator(
        readProfile: () async => resource(ProfileStatus.pending),
        prepare: (_) async {},
        navigate: (_) {},
        publish: (landing, kind) => published.add(landing),
      );

      final session = _authenticated('did:privy:owner-a');
      coordinator.onSessionChanged(_signedOut(), session);
      await _settle();
      coordinator.onSessionChanged(session, _signedOut());

      expect(published.last, isNull);
    });

    test(
      'a newly accepted credential closes the gate before it reads',
      () async {
        final published = <LoopProfileLanding?>[];
        final coordinator = PostAuthProfileRedirectCoordinator(
          readProfile: () async => resource(ProfileStatus.pending),
          prepare: (_) async {},
          navigate: (_) {},
          publish: (landing, kind) => published.add(landing),
        );

        // The previous account's answer is on the record when the next one
        // signs in. If it survived even one frame, the router would land a
        // pending account in Community before the read that says otherwise.
        final first = _authenticated('did:privy:owner-a');
        coordinator.onSessionChanged(_signedOut(), first);
        await _settle();
        expect(published, <LoopProfileLanding?>[
          null,
          LoopProfileLanding.loopIdSetup,
        ]);

        coordinator.onSessionChanged(
          first,
          _authenticated('did:privy:owner-b'),
        );
        expect(published[2], isNull);
        await _settle();
        expect(published.last, LoopProfileLanding.loopIdSetup);
      },
    );

    test(
      'the landing is published only after the landing is prepared',
      () async {
        final order = <String>[];
        final coordinator = PostAuthProfileRedirectCoordinator(
          readProfile: () async => resource(ProfileStatus.pending),
          prepare: (landing) async {
            await Future<void>.delayed(Duration.zero);
            order.add('prepare:${landing.name}');
          },
          publish: (landing, kind) {
            if (landing != null) order.add('publish:${landing.name}');
          },
          navigate: (landing) => order.add('navigate:${landing.name}'),
        );

        coordinator.onSessionChanged(
          _signedOut(),
          _authenticated('did:privy:owner-a'),
        );
        await _settle();
        await _settle();

        expect(order, <String>[
          'prepare:loopIdSetup',
          'publish:loopIdSetup',
          'navigate:loopIdSetup',
        ]);
      },
    );

    test('a preparation that fails still lands the owner somewhere', () async {
      LoopProfileLanding? published;
      final coordinator = PostAuthProfileRedirectCoordinator(
        readProfile: () async => resource(ProfileStatus.pending),
        prepare: (_) async => throw StateError('no storage'),
        publish: (landing, kind) => published = landing ?? published,
        navigate: (_) {},
      );

      coordinator.onSessionChanged(
        _signedOut(),
        _authenticated('did:privy:owner-a'),
      );
      await _settle();

      expect(published, LoopProfileLanding.loopIdSetup);
    });

    test(
      'a read that never answers becomes unavailable, not a wait forever',
      () {
        fakeAsync((async) {
          LoopProfileLanding? published;
          ProfileGatewayFailureKind? publishedKind;
          final coordinator = PostAuthProfileRedirectCoordinator(
            readProfile: () => Completer<ProfileResource>().future,
            prepare: (_) async {},
            publish: (landing, kind) {
              if (landing == null) return;
              published = landing;
              publishedKind = kind;
            },
            navigate: (_) {},
            readCeiling: const Duration(seconds: 15),
          );

          coordinator.onSessionChanged(
            _signedOut(),
            _authenticated('did:privy:owner-a'),
          );
          async.elapse(const Duration(seconds: 14));
          expect(published, isNull);

          async.elapse(const Duration(seconds: 2));
          expect(published, LoopProfileLanding.communityUnavailable);
          expect(publishedKind, ProfileGatewayFailureKind.unavailable);
          expect(loopProfileRecheckCanHelp(publishedKind), isTrue);
        });
      },
    );
  });

  group('launch gate', () {
    test('a verified session waits while the profile is unknown', () {
      expect(
        loopPostAuthHoldsAtLaunch(
          session: _authenticated('did:privy:owner-a'),
          landing: const LoopProfileLandingState.unknown(),
        ),
        isTrue,
      );
    });

    test('every decided landing opens the gate', () {
      for (final landing in LoopProfileLanding.values) {
        expect(
          loopPostAuthHoldsAtLaunch(
            session: _authenticated('did:privy:owner-a'),
            landing: LoopProfileLandingState(landing: landing),
          ),
          isFalse,
          reason: '${landing.name} is an answer, so nothing is being waited on',
        );
      }
    });

    test('a session with no profile coming is never held', () {
      for (final session in <LoopSessionState>[
        _signedOut(),
        _preview(),
        const LoopSessionState(mode: LoopSessionMode.authenticatedUnverified),
        const LoopSessionState.restoring(),
      ]) {
        expect(
          loopPostAuthHoldsAtLaunch(
            session: session,
            landing: const LoopProfileLandingState.unknown(),
          ),
          isFalse,
          reason: '${session.mode.name} has no profile read to wait for',
        );
      }
    });
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

LoopSessionState _signedOut() => const LoopSessionState.signedOut();

LoopSessionState _preview() => const LoopSessionState.preview();

LoopSessionState _authenticated(String privyUserId) {
  return LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: privyUserId),
  );
}
