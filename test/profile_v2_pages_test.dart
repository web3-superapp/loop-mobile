import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
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

import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

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
      // Metrics have no source, so the mining row states its figure as
      // unread and hands the reader the page that owns it.
      final mining = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('profile-open-mining')),
      );
      expect(mining.trailing, '—');
      expect(find.textContaining('24,820'), findsNothing);
    });

    testWidgets('the mining row prints the power and the place it earned', (
      tester,
    ) async {
      // Device walkthrough 2026-09-23 · h01: the row explained that it does
      // not read power, while the mining tab held 4.48 and 第 47 名.
      await _pump(
        tester,
        'profile',
        gateway: _Gateway(resource: active()),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(power: const MiningFigureValue('4.48')),
          ),
          rank: S7Answer<MiningRank>(
            value: s7MiningRank(
              scope: MiningRankScope.users,
              myPosition: const MiningRankPositionSettled(
                position: 47,
                power: '4.48',
              ),
            ),
          ),
        ),
      );

      final mining = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('profile-open-mining')),
      );
      expect(mining.trailing, '4.48');
      expect(mining.subtitle, '我的名次 第 47 名');
      expect(find.textContaining('这一页不读算力'), findsNothing);
    });

    testWidgets('each 账户 row carries the state it is a way into', (
      tester,
    ) async {
      // `#scr-profile`: 「2 个已绑定」, 「匿名模式已开启」, 「关注 24 · 粉丝 108」.
      await _pump(
        tester,
        'profile',
        gateway: _Gateway(resource: active()),
        social: FakeSocialGateway(
          connections: const ConnectionPage(
            direction: ConnectionDirection.following,
            items: <ConnectionEntry>[],
            counts: ConnectionCounts(following: 24, followers: 108),
            nextCursor: null,
          ),
        ),
      );

      Future<String?> subtitle(String key) async {
        final row = find.byKey(ValueKey<String>(key));
        await tester.scrollUntilVisible(row, 120);
        // Decision 0126: the state is the row's grey value on the right.
        return tester.widget<LoopRecordRow>(row).trailing;
      }

      // S107 §4: the row states the 公开持仓与交易 switch (the 匿名模式 line
      // left with its own switch). This harness keeps both facets private.
      expect(await subtitle('profile-open-privacy'), '持仓与交易仅自己可见');
      expect(await subtitle('profile-open-connections'), '关注 24 · 粉丝 108');
      // The wallet directory and the security posture were not read, so
      // those rows say nothing rather than 「读不到」.
      expect(await subtitle('profile-open-wallets'), isNull);
      expect(await subtitle('profile-open-security'), isNull);
      expect(find.textContaining('读不到'), findsNothing);
    });

    testWidgets('nothing on this page calls a working destination closed', (
      tester,
    ) async {
      final routes = <String>[];
      await _pump(
        tester,
        'profile',
        gateway: _Gateway(resource: active()),
        onNavigate: routes.add,
      );

      // The mining tab settles power every five minutes; this page only lacks
      // a reader of its own and says which page has one.
      expect(find.textContaining('挖矿数据还没有开放'), findsNothing);
      expect(find.textContaining('资产与挖矿数据还没有开放'), findsNothing);
      final toMining = find.byKey(
        const ValueKey<String>('profile-open-mining'),
      );
      await tester.scrollUntilVisible(toMining, 120);
      await tester.tap(toMining);
      await tester.pumpAndSettle();
      expect(routes, contains('mining'));

      // The connections page works and counts what it finds.
      expect(find.textContaining('关注数据还没有开放'), findsNothing);
      final connections = find.byKey(
        const ValueKey<String>('profile-open-connections'),
      );
      await tester.scrollUntilVisible(connections, 120);
      // The prototype's account rows carry a state value or nothing at all;
      // a state this device has not read is no second line, never a
      // description of the destination (audit 2026-09-21 §D+ #11).
      expect(tester.widget<LoopRecordRow>(connections).subtitle, isNull);
      expect(tester.widget<LoopRecordRow>(connections).onTap, isNotNull);
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

      // Decision 0110 · S106 §5: 我, top to bottom — mining, invite,
      // communities, account, settings. Every row reaches its own slug.
      expect(find.text('我'), findsWidgets);
      for (final entry in <(String, String)>[
        // Decision 0126: the round keys under the header, then the three
        // sections top to bottom; 挖矿总览 became the fourth key.
        ('profile-open-scan', 'scan'),
        ('profile-open-friends', 'connections'),
        ('profile-open-mining-key', 'mining'),
        ('profile-open-wallets', 'wallets'),
        ('profile-open-connections', 'connections'),
        ('profile-open-friend-requests', 'friend-requests'),
        ('profile-open-referral', 'referral'),
        ('profile-open-communities', 'community-discover'),
        ('profile-open-mining', 'mining'),
        ('profile-open-mining-assets', 'mining-assets'),
        ('profile-open-mining-rewards', 'mining-rewards'),
        ('profile-open-mining-rules', 'mining-rules'),
        ('profile-open-privacy', 'privacy'),
        ('profile-open-security', 'security'),
        ('profile-open-notifications', 'notif-settings'),
        ('profile-open-settings', 'settings'),
      ]) {
        await _scrollTo(tester, entry.$1);
        await tester.tap(find.byKey(ValueKey<String>(entry.$1)));
        await tester.pumpAndSettle();
        expect(destinations.last, entry.$2, reason: entry.$1);
      }
      // IDO Launch is hidden by default (需求方 2026-10-08): neither row is
      // drawn, and 未开放 appears nowhere.
      expect(
        find.byKey(const ValueKey<String>('profile-open-launch-history')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('profile-open-launch-tier')),
        findsNothing,
      );
      expect(find.text('未开放'), findsNothing);
      expect(find.text('社区成员关系尚未接入'), findsNothing);
    });

    testWidgets('the IDO switch brings both Launch rows back', (tester) async {
      final destinations = <String>[];
      await _pump(
        tester,
        'profile',
        gateway: _Gateway(resource: active()),
        onNavigate: destinations.add,
        switches: const LoopFeatureSwitchValues(idoLaunchVisible: true),
      );

      for (final entry in <(String, String)>[
        ('profile-open-launch-history', 'launch-history'),
        ('profile-open-launch-tier', 'launch-tier'),
      ]) {
        await _scrollTo(tester, entry.$1);
        await tester.tap(find.byKey(ValueKey<String>(entry.$1)));
        await tester.pumpAndSettle();
        expect(destinations.last, entry.$2);
      }
      expect(find.text('未开放'), findsNWidgets(2));
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

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(gateway.savedValues?.alias, 'Voyager_8');
      expect(gateway.savedValues?.bio, '长期持有，少动手');
      expect(gateway.savedExpectedVersion, 1);
    });

    testWidgets('a title, three groups and a pinned save', (tester) async {
      // S107 §4 / docs/09 §6.2 #7: no hero repeating the alias, no interest
      // tracks, and the save pinned under the scroll instead of after it.
      await _pump(
        tester,
        'profile-edit',
        gateway: _Gateway(resource: active()),
      );

      final page = tester.widget<LoopFocusPage>(find.byType(LoopFocusPage));
      expect(page.folio, isNull);
      expect(page.actionsFollowBody, isFalse);
      expect(find.byType(LoopFolioPrimary), findsNothing);
      for (final interest in ProfileInterest.values) {
        expect(
          find.byKey(ValueKey<String>('interest-${interest.wireValue}')),
          findsNothing,
        );
      }
      // Decision 0126: each label sits inside its 52-high field.
      for (final label in <String>['用户名', '简介', 'LOOP ID']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final key in <String>[
        'profile-edit-alias',
        'profile-edit-bio',
        'profile-edit-loop-id-field',
      ]) {
        final field = find.byKey(ValueKey<String>(key));
        expect(field, findsOneWidget, reason: key);
        expect(
          tester.getSize(field).height,
          greaterThanOrEqualTo(52),
          reason: key,
        );
      }
      expect(find.text('公开范围'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('profile-edit-copy-loop-id')),
        findsOneWidget,
      );
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
      await _tapSave(tester);
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
      await _tapSave(tester);
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
      await _tapSave(tester);
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
      await _tapSave(tester);
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
      // No upload transport in this harness: the button is shown, disabled,
      // and the page says why.
      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('loop-avatar-upload')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-avatar-upload-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('no preset list is offered any more', (tester) async {
      await _pump(
        tester,
        'profile-edit',
        gateway: _Gateway(resource: active()),
      );

      expect(
        find.byKey(const ValueKey<String>('profile-avatar-change')),
        findsNothing,
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

/// 保存 flows at the end of the body, so it is scrolled to before it is
/// tapped — the page is longer than the viewport on a phone.
Future<void> _tapSave(WidgetTester tester) async {
  final save = find.byKey(const ValueKey<String>('profile-edit-save'));
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
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
  MiningGateway? mining,
  SocialGateway? social,
  bool settle = true,
  LoopFeatureSwitchValues? switches,
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
        if (mining != null) miningGatewayProvider.overrideWithValue(mining),
        if (social != null) socialGatewayProvider.overrideWithValue(social),
        if (switches != null)
          loopFeatureSwitchesProvider.overrideWithValue(switches),
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
