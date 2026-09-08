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
          navigate: (_) {},
          publish: (landing, kind) {
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

    test('signing out clears the recorded landing', () async {
      final published = <LoopProfileLanding>[];
      final coordinator = PostAuthProfileRedirectCoordinator(
        readProfile: () async => resource(ProfileStatus.pending),
        navigate: (_) {},
        publish: (landing, kind) => published.add(landing),
      );

      final session = _authenticated('did:privy:owner-a');
      coordinator.onSessionChanged(_signedOut(), session);
      await _settle();
      coordinator.onSessionChanged(session, _signedOut());

      expect(published.last, LoopProfileLanding.community);
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
