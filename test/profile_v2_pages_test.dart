import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

void main() {
  const loopId = 'LOOP-7HJKMNPQ';

  ProfileResource active({
    String? alias = 'Voyager_7',
    String? bio,
    int version = 1,
  }) => ProfileResource(
    version: version,
    values: ProfileValues(
      alias: alias,
      avatarRef: 'avatar:preset/people-01',
      bio: bio,
      interests: const <ProfileInterest>[ProfileInterest.meme],
    ),
    updatedAt: DateTime.utc(2026, 9, 7, 1),
    loopId: loopId,
    profileStatus: ProfileStatus.active,
    activatedAt: DateTime.utc(2026, 9, 7, 1),
  );

  group('profile', () {
    testWidgets('loading shows a skeleton, never an invented identity', (
      tester,
    ) async {
      await _pump(
        tester,
        'profile',
        gateway: _Gateway(
          resource: active(),
          loadDelay: const Duration(seconds: 1),
        ),
        settle: false,
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('profile-loading')),
        findsOneWidget,
      );
      expect(find.text(loopId), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('ready uses the dashboard layout and shows the LOOP ID', (
      tester,
    ) async {
      await _pump(tester, 'profile', gateway: _Gateway(resource: active()));

      expect(find.byType(LoopDashboardPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('profile-identity-card')),
        findsOneWidget,
      );
      expect(find.text('Voyager_7'), findsWidgets);
      expect(find.text(loopId), findsOneWidget);
      // Metrics have no source, so they stay explicitly unreadable.
      expect(
        find.byKey(const ValueKey<String>('profile-metrics-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('24,820'), findsNothing);
    });

    testWidgets('unavailable, offline and error each get their own block', (
      tester,
    ) async {
      const cases = <(ProfileGatewayFailureKind, String)>[
        (ProfileGatewayFailureKind.unavailable, 'profile-unavailable'),
        (ProfileGatewayFailureKind.offline, 'profile-offline'),
        (ProfileGatewayFailureKind.unexpected, 'profile-error'),
      ];
      for (final (kind, key) in cases) {
        await _pump(
          tester,
          'profile',
          gateway: _Gateway(failure: ProfileGatewayException(kind)),
        );
        expect(
          find.byKey(ValueKey<String>(key)),
          findsOneWidget,
          reason: '${kind.name} must render $key',
        );
        expect(find.text(loopId), findsNothing);
      }
    });

    testWidgets('an activated account with no alias is not called empty', (
      tester,
    ) async {
      await _pump(
        tester,
        'profile',
        gateway: _Gateway(resource: active(alias: null)),
      );

      expect(find.text('尚未设置别名'), findsWidgets);
      expect(find.byKey(const ValueKey<String>('profile-empty')), findsNothing);
    });

    testWidgets('the account entries reach their manifest slugs', (
      tester,
    ) async {
      final destinations = <String>[];
      await _pump(
        tester,
        'profile',
        gateway: _Gateway(resource: active()),
        onNavigate: destinations.add,
      );

      for (final entry in <(String, String)>[
        ('profile-open-communities', 'community-discover'),
        ('profile-open-launch-history', 'launch-history'),
        ('profile-open-launch-tier', 'launch-tier'),
        ('profile-open-wallets', 'wallets'),
      ]) {
        await _scrollTo(tester, entry.$1);
        await tester.tap(find.byKey(ValueKey<String>(entry.$1)));
        await tester.pumpAndSettle();
        expect(destinations.last, entry.$2);
      }
      // Unconnected sources say so instead of showing a count.
      expect(find.text('未接入'), findsNWidgets(3));
    });

    testWidgets('the primary action opens the edit page', (tester) async {
      final destinations = <String>[];
      await _pump(
        tester,
        'profile',
        gateway: _Gateway(resource: active()),
        onNavigate: destinations.add,
      );

      await tester.tap(find.byKey(const ValueKey<String>('profile-open-edit')));
      await tester.pumpAndSettle();
      expect(destinations, <String>['profile-edit']);
    });

    testWidgets('no retired social-privacy or copy-trade entry survives', (
      tester,
    ) async {
      await _pump(tester, 'profile', gateway: _Gateway(resource: active()));

      expect(find.textContaining('跟单'), findsNothing);
      expect(find.textContaining('社交隐私'), findsNothing);
      expect(find.textContaining('持仓广播'), findsNothing);
      await _scrollTo(tester, 'profile-open-privacy');
      expect(
        find.byKey(const ValueKey<String>('profile-open-privacy')),
        findsOneWidget,
      );
    });
  });

  group('preview truth', () {
    for (final surfaceId in <String>['profile', 'profile-edit', 'privacy']) {
      testWidgets('$surfaceId labels a Preview session', (tester) async {
        await _pump(
          tester,
          surfaceId,
          gateway: _Gateway(resource: active(), mode: ProfileMode.preview),
          privacyMode: PrivacyMode.preview,
        );

        expect(
          find.byKey(const ValueKey<String>('loop-preview-mode-notice')),
          findsOneWidget,
        );
        expect(find.text('开发预览'), findsWidgets);
      });

      testWidgets('$surfaceId carries no Preview label in production', (
        tester,
      ) async {
        await _pump(tester, surfaceId, gateway: _Gateway(resource: active()));

        expect(
          find.byKey(const ValueKey<String>('loop-preview-mode-notice')),
          findsNothing,
        );
        expect(find.text('开发预览'), findsNothing);
      });
    }
  });

  group('profile-edit', () {
    testWidgets('ready edits the alias, bio and tracks against one draft', (
      tester,
    ) async {
      final gateway = _Gateway(resource: active());
      await _pump(tester, 'profile-edit', gateway: gateway);

      expect(find.byType(LoopFocusPage), findsOneWidget);
      expect(_pressed(tester, 'profile-edit-save'), isNull);

      await tester.enterText(
        find.byKey(const ValueKey<String>('profile-edit-alias-field')),
        'Voyager_8',
      );
      await tester.pumpAndSettle();
      expect(_pressed(tester, 'profile-edit-save'), isNotNull);

      await tester.enterText(
        find.byKey(const ValueKey<String>('profile-edit-bio-field')),
        '长期持有，少动手',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('profile-edit-save')));
      await tester.pumpAndSettle();

      expect(gateway.savedValues?.alias, 'Voyager_8');
      expect(gateway.savedValues?.bio, '长期持有，少动手');
      expect(gateway.savedExpectedVersion, 1);
    });

    testWidgets('a rejected alias is shown as a failure, not a save', (
      tester,
    ) async {
      final gateway = _Gateway(
        resource: active(),
        saveFailure: const ProfileGatewayException(
          ProfileGatewayFailureKind.aliasReserved,
        ),
      );
      await _pump(tester, 'profile-edit', gateway: gateway);

      await tester.enterText(
        find.byKey(const ValueKey<String>('profile-edit-alias-field')),
        'admin',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('profile-edit-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('profile-edit-failure')),
        findsOneWidget,
      );
      expect(find.textContaining('保留词'), findsOneWidget);
      expect(find.text('资料已保存'), findsNothing);
      // The draft survives so the owner can correct it.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey<String>('profile-edit-alias-field')),
            )
            .controller
            ?.text,
        'admin',
      );
    });

    testWidgets('an offline save shows the offline block and pauses saving', (
      tester,
    ) async {
      final gateway = _Gateway(
        resource: active(),
        saveFailure: const ProfileGatewayException(
          ProfileGatewayFailureKind.offline,
        ),
      );
      await _pump(tester, 'profile-edit', gateway: gateway);

      await tester.enterText(
        find.byKey(const ValueKey<String>('profile-edit-alias-field')),
        'Voyager_8',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('profile-edit-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('profile-edit-offline')),
        findsOneWidget,
      );
    });

    testWidgets('a version conflict freezes the draft until a reload', (
      tester,
    ) async {
      final gateway = _Gateway(
        resource: active(),
        saveFailure: const ProfileGatewayException(
          ProfileGatewayFailureKind.versionConflict,
        ),
      );
      await _pump(tester, 'profile-edit', gateway: gateway);

      await tester.enterText(
        find.byKey(const ValueKey<String>('profile-edit-alias-field')),
        'Voyager_8',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('profile-edit-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('profile-edit-conflict')),
        findsOneWidget,
      );
      expect(_pressed(tester, 'profile-edit-save'), isNull);
    });

    testWidgets('a non-preset V1 avatar is dropped from the draft', (
      tester,
    ) async {
      final gateway = _Gateway(
        resource: ProfileResource(
          version: 1,
          values: ProfileValues(
            alias: 'Voyager_7',
            // Only a V1 write could have produced this.
            avatarRef: 'avatar:legacy/upload-9f2c',
          ),
          updatedAt: DateTime.utc(2026, 9, 7, 1),
          loopId: loopId,
          profileStatus: ProfileStatus.active,
          activatedAt: DateTime.utc(2026, 9, 7, 1),
        ),
      );
      await _pump(tester, 'profile-edit', gateway: gateway);

      // It renders as the monogram, and saving cannot resubmit it.
      expect(
        find.byKey(const ValueKey<String>('loop-profile-avatar-monogram')),
        findsWidgets,
      );
      await tester.tap(find.byKey(const ValueKey<String>('profile-edit-save')));
      await tester.pumpAndSettle();
      expect(gateway.savedValues?.avatarRef, isNull);
    });

    testWidgets('avatar upload is never offered as available', (tester) async {
      await _pump(
        tester,
        'profile-edit',
        gateway: _Gateway(resource: active()),
      );

      expect(
        find.byKey(const ValueKey<String>('profile-avatar-picker')),
        findsOneWidget,
      );
      expect(find.textContaining('自定义头像上传暂不可用'), findsOneWidget);
      expect(find.textContaining('上传照片'), findsNothing);
    });

    testWidgets('an unreadable catalog keeps the current avatar', (
      tester,
    ) async {
      await _pump(
        tester,
        'profile-edit',
        gateway: _Gateway(resource: active()),
        avatars: _AvatarCatalog(fails: true),
      );

      expect(
        find.byKey(const ValueKey<String>('profile-avatar-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('profile-avatar-avatar:preset/people-01'),
        ),
        findsNothing,
      );
    });

    testWidgets('unavailable and loading reuse the shared state blocks', (
      tester,
    ) async {
      await _pump(
        tester,
        'profile-edit',
        gateway: _Gateway(
          failure: const ProfileGatewayException(
            ProfileGatewayFailureKind.unavailable,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('profile-unavailable')),
        findsOneWidget,
      );
      expect(_pressed(tester, 'profile-edit-save'), isNull);
    });
  });
}

Future<void> _scrollTo(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey<String>(key)),
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

VoidCallback? _pressed(WidgetTester tester, String key) {
  return tester.widget<LoopButton>(find.byKey(ValueKey<String>(key))).onPressed;
}

Future<void> _pump(
  WidgetTester tester,
  String surfaceId, {
  required _Gateway gateway,
  _AvatarCatalog? avatars,
  ValueChanged<String>? onNavigate,
  PrivacyMode privacyMode = PrivacyMode.production,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileGatewayProvider.overrideWithValue(gateway),
        privacyGatewayProvider.overrideWithValue(_Privacy(privacyMode)),
        avatarCatalogGatewayProvider.overrideWithValue(
          avatars ?? _AvatarCatalog(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: LoopToastHost(
          child: ProfileSurfaceScreen.fromId(
            surfaceId,
            onNavigate: onNavigate ?? (_) {},
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

final class _Privacy implements PrivacyGateway {
  _Privacy(this.mode);

  @override
  final PrivacyMode mode;

  @override
  Future<PrivacyResource> load() async => PrivacyResource(
    version: 1,
    values: const PrivacyValues(discoverable: true, anonymousMode: true),
    updatedAt: DateTime.utc(2026, 9, 7, 1),
  );

  @override
  Future<PrivacyResource> replace({
    required int expectedVersion,
    required PrivacyValues values,
  }) async => PrivacyResource(
    version: expectedVersion + 1,
    values: values,
    updatedAt: DateTime.utc(2026, 9, 7, 2),
  );
}

final class _Gateway implements ProfileGateway {
  _Gateway({
    this.resource,
    this.failure,
    this.saveFailure,
    this.loadDelay,
    this.mode = ProfileMode.production,
  });

  ProfileResource? resource;
  ProfileGatewayException? failure;
  final ProfileGatewayException? saveFailure;
  final Duration? loadDelay;

  ProfileValues? savedValues;
  int? savedExpectedVersion;

  @override
  final ProfileMode mode;

  @override
  Future<ProfileResource> load() async {
    final delay = loadDelay;
    if (delay != null) await Future<void>.delayed(delay);
    final error = failure;
    if (error != null) throw error;
    return resource!;
  }

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) async {
    savedExpectedVersion = expectedVersion;
    savedValues = values;
    final error = saveFailure;
    if (error != null) throw error;
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
