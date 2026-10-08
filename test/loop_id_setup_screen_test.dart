import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/loop_id_setup_screen.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';

void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

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
    expect(find.textContaining('不可更改'), findsOneWidget);
    // S107 §4: the LOOP ID can be copied, never edited — the two fields are
    // the user name and the bio.
    expect(find.byKey(const ValueKey<String>('loop-id-copy')), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
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
    await _tapKey(tester, 'loop-id-submit');
    await tester.pumpAndSettle();

    expect(activation.calls, 1);
    expect(activation.avatarRef, isNull);
  });

  testWidgets('no preset grid: the default avatar and a closed upload', (
    tester,
  ) async {
    await _pump(tester);

    // S107 §4: the preset grid is gone even when the catalog answers.
    expect(
      find.byKey(
        const ValueKey<String>('loop-id-avatar-avatar:preset/people-01'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('loop-profile-avatar-monogram')),
      findsOneWidget,
    );
    // No upload transport in this harness: the button stays, disabled, and
    // says why.
    expect(_pressed(tester, 'loop-avatar-upload'), isNull);
    expect(
      find.byKey(const ValueKey<String>('loop-avatar-upload-unavailable')),
      findsOneWidget,
    );
    // The interest tracks are gone too.
    expect(find.text('关注赛道'), findsNothing);
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

    expect(_pressed(tester, 'loop-id-submit'), isNotNull);
    await _tapKey(tester, 'loop-id-submit');
    await tester.pumpAndSettle();

    expect(activation.calls, 1);
    expect(activation.alias, 'Voyager_7');
    // The field is kept on the server and submitted empty (S107 §4).
    expect(activation.interests, isEmpty);
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
    await _tapKey(tester, 'loop-id-submit');
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
    await _tapKey(tester, 'loop-id-submit');
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

    expect(find.textContaining('可以和别人重复'), findsOneWidget);
    expect(_pressed(tester, 'loop-id-submit'), isNotNull);
  });

  testWidgets('a bio is written after activation, against its version', (
    tester,
  ) async {
    final activation = _ActivationGateway(activated('Voyager_7'));
    final profile = _ProfileGateway();
    await _pump(tester, profile: profile, activation: activation);

    await tester.enterText(
      find.byKey(const ValueKey<String>('loop-id-alias-field')),
      'Voyager_7',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('loop-id-bio-field')),
      '链上漫游者',
    );
    await tester.pumpAndSettle();
    await _tapKey(tester, 'loop-id-submit');
    await tester.pumpAndSettle();

    expect(activation.calls, 1);
    expect(profile.replaced?.bio, '链上漫游者');
    expect(profile.replacedVersion, 1);
    expect(
      find.byKey(const ValueKey<String>('loop-id-activated')),
      findsOneWidget,
    );
    expect(find.textContaining('简介没有保存成功'), findsNothing);
  });

  testWidgets('a bio that fails to save leaves the activation standing', (
    tester,
  ) async {
    final activation = _ActivationGateway(activated('Voyager_7'));
    final profile = _ProfileGateway(replaceFails: true);
    await _pump(tester, profile: profile, activation: activation);

    await tester.enterText(
      find.byKey(const ValueKey<String>('loop-id-alias-field')),
      'Voyager_7',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('loop-id-bio-field')),
      '链上漫游者',
    );
    await tester.pumpAndSettle();
    await _tapKey(tester, 'loop-id-submit');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('loop-id-activated')),
      findsOneWidget,
    );
    expect(find.textContaining('简介没有保存成功'), findsOneWidget);
  });
}

VoidCallback? _pressed(WidgetTester tester, String key) {
  return tester.widget<LoopButton>(find.byKey(ValueKey<String>(key))).onPressed;
}

/// The action and the disclosure flow with the body, so a control may sit
/// below the fold before it is reached.
Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
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
      child: MaterialApp(theme: LoopTheme.dark, home: LoopIdSetupScreen()),
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
  _ProfileGateway({
    this.failure,
    this.loadDelay,
    this.avatarRef,
    this.replaceFails = false,
  });

  ProfileGatewayException? failure;
  final Duration? loadDelay;
  final String? avatarRef;
  final bool replaceFails;
  ProfileValues? replaced;
  int? replacedVersion;

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
  }) async {
    if (replaceFails) {
      throw const ProfileGatewayException(ProfileGatewayFailureKind.offline);
    }
    replaced = values;
    replacedVersion = expectedVersion;
    return ProfileResource(
      version: expectedVersion + 1,
      values: values,
      updatedAt: DateTime.utc(2026, 9, 7, 2),
      loopId: 'LOOP-7HJKMNPQ',
      profileStatus: ProfileStatus.active,
      activatedAt: DateTime.utc(2026, 9, 7, 1),
    );
  }
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
  _AvatarCatalog();

  @override
  Future<List<AvatarPreset>> load() async {
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
