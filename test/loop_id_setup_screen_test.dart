import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/account/loop_id_setup_controller.dart';
import 'package:loop_mobile/features/account/loop_id_setup_screen.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

void main() {
  const loopId = 'LOOP-7HJKMNPQ';

  ProfileResource activated(
    String alias, {
    List<ProfileInterest> interests = const <ProfileInterest>[],
  }) => ProfileResource(
    version: 1,
    values: ProfileValues(alias: alias, avatarRef: null, interests: interests),
    updatedAt: DateTime.utc(2026, 9, 7, 1),
    loopId: loopId,
    profileStatus: ProfileStatus.active,
    activatedAt: DateTime.utc(2026, 9, 7, 1),
  );

  testWidgets('loading shows a skeleton before any identity claim', (
    tester,
  ) async {
    final gateway = _ProfileGateway(loadDelay: const Duration(seconds: 1));
    await _pump(tester, profile: gateway, settle: false);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('loop-id-loading')),
      findsOneWidget,
    );
    expect(find.text(loopId), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('ready shows the read-only server LOOP ID', (tester) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey<String>('loop-id-value')), findsOneWidget);
    expect(find.text(loopId), findsOneWidget);
    expect(find.text('系统生成，不可更改'), findsOneWidget);
    // The LOOP ID is never editable.
    expect(find.byType(TextField), findsOneWidget);
    // Nothing can be submitted before an alias exists.
    expect(_pressed(tester, 'loop-id-submit'), isNull);
  });

  testWidgets('unavailable states the reason and blocks submission', (
    tester,
  ) async {
    await _pump(
      tester,
      profile: _ProfileGateway(
        failure: const ProfileGatewayException(
          ProfileGatewayFailureKind.unavailable,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('loop-id-unavailable')),
      findsOneWidget,
    );
    expect(_pressed(tester, 'loop-id-submit'), isNull);
  });

  testWidgets('an unread profile is empty, not an error', (tester) async {
    // Nothing failed yet: the initial state must not claim a failure.
    final gateway = _ProfileGateway(loadDelay: const Duration(seconds: 1));
    await _pump(tester, profile: gateway, settle: false);

    expect(find.byKey(const ValueKey<String>('loop-id-error')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed read offers retry instead of a fabricated ID', (
    tester,
  ) async {
    final gateway = _ProfileGateway(
      failure: const ProfileGatewayException(
        ProfileGatewayFailureKind.unexpected,
      ),
    );
    await _pump(tester, profile: gateway);

    expect(find.byKey(const ValueKey<String>('loop-id-error')), findsOneWidget);
    expect(find.textContaining('LOOP-'), findsNothing);

    gateway.failure = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text(loopId), findsOneWidget);
  });

  testWidgets('a non-preset V1 avatar is never seeded into the body', (
    tester,
  ) async {
    final activation = _ActivationGateway(activated('Voyager_7'));
    await _pump(
      tester,
      profile: _ProfileGateway(avatarRef: 'avatar:legacy/upload-9f2c'),
      activation: activation,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('loop-id-alias-field')),
      'Voyager_7',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('loop-id-submit')));
    await tester.pumpAndSettle();

    expect(activation.calls, 1);
    expect(activation.avatarRef, isNull);
  });

  testWidgets('the empty avatar catalog keeps the picker unavailable', (
    tester,
  ) async {
    await _pump(tester, avatars: _AvatarCatalog(fails: true));

    expect(
      find.byKey(const ValueKey<String>('loop-id-avatar-unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('loop-id-avatar-avatar:preset/people-01'),
      ),
      findsNothing,
    );
  });

  testWidgets('the primary action activates with the exact submitted body', (
    tester,
  ) async {
    final activation = _ActivationGateway(activated('Voyager_7'));
    await _pump(tester, activation: activation);

    await tester.enterText(
      find.byKey(const ValueKey<String>('loop-id-alias-field')),
      'Voyager_7',
    );
    await tester.pumpAndSettle();
    await _openDisclosure(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('loop-id-interest-MEME')),
    );
    await tester.pumpAndSettle();

    expect(_pressed(tester, 'loop-id-submit'), isNotNull);
    await tester.tap(find.byKey(const ValueKey<String>('loop-id-submit')));
    await tester.pumpAndSettle();

    expect(activation.calls, 1);
    expect(activation.alias, 'Voyager_7');
    expect(activation.interests, <ProfileInterest>[ProfileInterest.meme]);
    expect(
      find.byKey(const ValueKey<String>('loop-id-activated')),
      findsOneWidget,
    );
  });

  testWidgets('a reserved alias is shown as a rejection, not a success', (
    tester,
  ) async {
    final activation = _ActivationGateway(
      null,
      failure: const ProfileGatewayException(
        ProfileGatewayFailureKind.aliasReserved,
      ),
    );
    await _pump(tester, activation: activation);

    await tester.enterText(
      find.byKey(const ValueKey<String>('loop-id-alias-field')),
      'admin',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('loop-id-submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('loop-id-failure')),
      findsOneWidget,
    );
    expect(find.textContaining('保留词'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('loop-id-activated')),
      findsNothing,
    );
  });

  testWidgets('an offline activation keeps the draft and offers a retry', (
    tester,
  ) async {
    final activation = _ActivationGateway(
      null,
      failure: const ProfileGatewayException(ProfileGatewayFailureKind.offline),
    );
    await _pump(tester, activation: activation);

    await tester.enterText(
      find.byKey(const ValueKey<String>('loop-id-alias-field')),
      'Voyager_7',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('loop-id-submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('loop-id-offline')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('loop-id-alias-field')),
          )
          .controller
          ?.text,
      'Voyager_7',
    );
  });

  testWidgets('the local alias suggestion is labelled as a suggestion', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('loop-id-alias-suggest')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('只是本地建议'), findsOneWidget);
    expect(_pressed(tester, 'loop-id-submit'), isNotNull);
  });

  testWidgets('the notification switch stays a local preference', (
    tester,
  ) async {
    final container = await _pump(tester);
    await _openDisclosure(tester);

    expect(
      container.read(loopIdSetupControllerProvider).pushNotificationsRequested,
      isTrue,
    );
    expect(find.textContaining('仅本地偏好，投递仍不可用'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('loop-id-push-toggle')));
    await tester.pumpAndSettle();
    expect(
      container.read(loopIdSetupControllerProvider).pushNotificationsRequested,
      isFalse,
    );
  });
}

VoidCallback? _pressed(WidgetTester tester, String key) {
  return tester.widget<LoopButton>(find.byKey(ValueKey<String>(key))).onPressed;
}

Future<void> _openDisclosure(WidgetTester tester) async {
  await tester.ensureVisible(find.text('身份说明、关注赛道与通知'));
  await tester.tap(find.text('身份说明、关注赛道与通知'));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  _ProfileGateway? profile,
  _ActivationGateway? activation,
  _AvatarCatalog? avatars,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      profileGatewayProvider.overrideWithValue(profile ?? _ProfileGateway()),
      profileActivationGatewayProvider.overrideWithValue(
        activation ?? _ActivationGateway(null),
      ),
      avatarCatalogGatewayProvider.overrideWithValue(
        avatars ?? _AvatarCatalog(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LoopIdSetupScreen()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return container;
}

final class _ProfileGateway implements ProfileGateway {
  _ProfileGateway({this.failure, this.loadDelay, this.avatarRef});

  ProfileGatewayException? failure;
  final Duration? loadDelay;
  final String? avatarRef;

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() async {
    final delay = loadDelay;
    if (delay != null) await Future<void>.delayed(delay);
    final error = failure;
    if (error != null) throw error;
    return ProfileResource(
      version: 0,
      values: ProfileValues(alias: null, avatarRef: avatarRef),
      updatedAt: null,
      loopId: 'LOOP-7HJKMNPQ',
    );
  }

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) => throw UnimplementedError();
}

final class _ActivationGateway implements ProfileActivationGateway {
  _ActivationGateway(this.result, {this.failure});

  final ProfileResource? result;
  final ProfileGatewayException? failure;
  var calls = 0;
  String? alias;
  String? avatarRef;
  List<ProfileInterest> interests = const <ProfileInterest>[];

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> activate({
    required String alias,
    required String? avatarRef,
    required List<ProfileInterest> interests,
  }) async {
    calls += 1;
    this.alias = alias;
    this.avatarRef = avatarRef;
    this.interests = interests;
    final error = failure;
    if (error != null) throw error;
    return result!;
  }
}

final class _AvatarCatalog implements AvatarCatalogGateway {
  _AvatarCatalog({this.fails = false});

  final bool fails;

  @override
  Future<List<AvatarPreset>> load() async {
    if (fails) {
      throw const AvatarCatalogException(AvatarCatalogFailureKind.unavailable);
    }
    return const <AvatarPreset>[
      AvatarPreset(
        avatarRef: 'avatar:preset/people-01',
        atlas: 'people',
        slot: 1,
        label: 'People 01',
      ),
      AvatarPreset(
        avatarRef: 'avatar:preset/monogram',
        atlas: 'monogram',
        slot: null,
        label: 'Monogram',
      ),
    ];
  }
}
