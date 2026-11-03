// S343 · decision 0271 (docs/56 §二): 聊天 without its filter strip, in two
// parts, with 「＋」 at the top right; 钱包 became 我的 — the person, the
// stranger requests, 总资产, the holdings and the account rows — and 设置
// kept only 隐私与安全, 通用, 关于 and 退出登录.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/mining/referral_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_destinations.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_gateway.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_sheet.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_page_harness.dart';
import 'support/testnet_faucet_fakes.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _shotDir =
    '/private/tmp/claude-501/-Users-chenyang-Documents-LOOP/'
    '6293ad8a-21d0-4c44-84aa-93724a65bef3/scratchpad';

const _loopId = 'LOOP-GBZM3XAT';

ProfileResource _resource() => ProfileResource(
  version: 1,
  values: ProfileValues(alias: 'Boo123133', avatarRef: null, bio: null),
  updatedAt: DateTime.utc(2026, 10, 9),
  loopId: _loopId,
  profileStatus: ProfileStatus.active,
  activatedAt: DateTime.utc(2026, 10, 9, 12),
);

final class _Profile implements ProfileGateway {
  _Profile({this.pending = false});

  final bool pending;

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() =>
      pending ? Completer<ProfileResource>().future : Future.value(_resource());

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) async => _resource();
}

MessageRequestPage _oneRequest() => MessageRequestPage(
  items: <MessageRequestEntry>[
    MessageRequestEntry(
      messageRequestId: testRequestId,
      profile: testProfile(alias: 'fox_trader'),
      createdAt: DateTime.utc(2026, 9, 7),
      expiresAt: DateTime.utc(2026, 9, 14),
      preview: const LoopUnavailableFact('MESSAGE_PREVIEW_DEFERRED'),
      aiModeration: const LoopUnavailableFact('AI_MODERATION_DEFERRED'),
    ),
  ],
  nextCursor: null,
);

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Future<void> _pumpMe(
  WidgetTester tester, {
  ValueChanged<String>? onNavigate,
  LoopWalletBalances? balances,
  MessageRequestPage? requests,
  bool profilePending = false,
  Size size = const Size(390, 2400),
}) => pumpS5Page(
  tester,
  WalletScreen(onNavigate: onNavigate),
  size: size,
  wallet: FakeWalletReadGateway(
    balances: S5Answer<LoopWalletBalances>(value: balances ?? s5Balances()),
  ),
  overrides: [
    profileGatewayProvider.overrideWithValue(_Profile(pending: profilePending)),
    socialGatewayProvider.overrideWithValue(
      FakeSocialGateway(
        connections: const ConnectionPage(
          direction: ConnectionDirection.following,
          items: <ConnectionEntry>[],
          counts: ConnectionCounts(following: 3, followers: 12),
          nextCursor: null,
        ),
        requests: requests,
      ),
    ),
    referralGatewayProvider.overrideWithValue(FakeReferralGateway()),
  ],
  settle: !profilePending,
);

AppConfig _config() => const AppConfig(
  privyAppId: 'privy-app',
  privyAppClientId: 'privy-client',
  streamApiKey: 'public-stream-api-key',
  backendBaseUrl: '',
  firebaseConfigured: false,
);

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  MessageRequestPage? requests,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_config()),
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        if (requests != null)
          socialGatewayProvider.overrideWithValue(
            FakeSocialGateway(requests: requests),
          ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(MemeScreen)));
}

Future<void> _pumpChat(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        streamChatAuthorizationProvider.overrideWith(
          (ref) async => StreamSessionAuthorization.unavailable,
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: const StreamChatInboxPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// One 390-wide PNG of the whole frame, written to the scratchpad.
Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(loopLoadShotFonts);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotDir/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  loopWatchGround();

  group('聊天', () {
    testWidgets('no filter strip, no owner face, no bell, no floating key', (
      tester,
    ) async {
      await _pumpChat(tester);
      expect(_key('chat-inbox-filters'), findsNothing);
      expect(find.byType(LoopSegBar), findsNothing);
      expect(find.text('全部'), findsNothing);
      expect(_key('chat-open-profile'), findsNothing);
      expect(_key('me-notification-bell'), findsNothing);
      expect(_key('chat-create-slot'), findsNothing);
      expect(_key('stream-chat-message-requests-entry'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('「＋」 is in the bar\'s top right and opens the create panel', (
      tester,
    ) async {
      await _pumpChat(tester);
      final plus = _key('chat-create-menu');
      expect(plus, findsOneWidget);
      expect(
        find.descendant(of: find.byType(LoopTopbar), matching: plus),
        findsOneWidget,
      );
      expect(tester.getCenter(plus).dx, greaterThan(390 / 2));
      expect(tester.getCenter(plus).dy, lessThan(120));
      expect(tester.getSize(plus).width, greaterThanOrEqualTo(44));

      await tester.tap(plus);
      await tester.pumpAndSettle();
      for (final key in <String>[
        'chat-add-friend-menu-item',
        'chat-create-community-menu-item',
        'chat-create-group-menu-item',
        'chat-scan-menu-item',
      ]) {
        expect(_key(key), findsOneWidget, reason: key);
      }
    });
  });

  group('我的', () {
    testWidgets('top to bottom: bar, person, 总资产, keys, holdings, rows', (
      tester,
    ) async {
      await _pumpMe(tester);
      expect(
        find.descendant(of: find.byType(LoopTopbar), matching: find.text('我的')),
        findsWidgets,
      );
      // The bar: 交易历史, 通知, 设置 — and no 钱包管理.
      final history = tester.getCenter(_key('wallet-history-action')).dx;
      final bell = tester.getCenter(_key('me-notification-bell')).dx;
      final gear = tester.getCenter(_key('profile-open-settings')).dx;
      expect(history, lessThan(bell));
      expect(bell, lessThan(gear));
      expect(_key('wallet-manage-action'), findsNothing);
      // Only those three: no (i) in the bar.
      expect(_key('loop-page-info-action'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LoopTopbar),
          matching: find.byType(LoopIconButton),
        ),
        findsNWidgets(3),
      );

      double top(String key) => tester.getTopLeft(_key(key)).dy;
      expect(_key('profile-identity-card'), findsOneWidget);
      expect(_key('profile-share-loop-id'), findsOneWidget);
      expect(_key('profile-copy-loop-id'), findsOneWidget);
      expect(_key('profile-following-count'), findsOneWidget);
      expect(_key('profile-followers-count'), findsOneWidget);
      // 奖励 left the card (挖矿奖励 is on 情报 · 算力); 分享名片 ends the
      // name's line.
      expect(_key('profile-open-rewards'), findsNothing);
      expect(
        tester.getCenter(_key('profile-share-loop-id')).dy,
        moreOrLessEquals(
          tester.getCenter(_key('profile-alias')).dy,
          epsilon: 2,
        ),
      );
      // Name and LOOP ID each on one line.
      final idLine = tester.getSize(_key('profile-loop-id')).height;
      expect(idLine, lessThan(24));
      expect(find.text(_loopId), findsOneWidget);
      // No 持仓分布, no (i) beside 总资产, no explanation under a row.
      expect(_key('wallet-holdings-distribution'), findsNothing);
      expect(find.text('持仓分布'), findsNothing);
      expect(_key('wallet-info'), findsNothing);
      expect(find.textContaining('手续费保留'), findsNothing);
      expect(top('profile-identity-card'), lessThan(top('wallet-total-plate')));
      expect(top('wallet-total-plate'), lessThan(top('wallet-receive-entry')));
      for (final key in <String>[
        'wallet-receive-entry',
        'wallet-send-entry',
        'wallet-swap-entry',
        'wallet-pay-entry',
      ]) {
        expect(_key(key), findsOneWidget, reason: key);
      }
      expect(_key('wallet-asset-list'), findsOneWidget);
      expect(top('wallet-asset-list'), lessThan(top('me-account-entries')));

      // The account rows, in order.
      final rows = <String>[
        'profile-open-wallets',
        'profile-open-communities',
        'profile-open-referral',
        'wallet-dapp-entry',
      ];
      for (var i = 0; i < rows.length; i++) {
        expect(_key(rows[i]), findsOneWidget, reason: rows[i]);
        if (i > 0) expect(top(rows[i - 1]), lessThan(top(rows[i])));
      }
      expect(find.text('我加入的社区'), findsOneWidget);
      expect(find.text('邀请好友'), findsOneWidget);
      // The invite code and its copy stay on the row.
      expect(_key('profile-copy-invite-code'), findsOneWidget);

      // Removed: the bottom entry group, 充值, profile's own holdings.
      for (final gone in <String>[
        'wallet-entry-group',
        'wallet-bridge-entry',
        'wallet-approvals-entry',
        'wallet-networks-entry',
        'wallet-settings-entry',
        'profile-deposit',
        'profile-open-rewards',
        'profile-networth-panel',
        'profile-holdings-tabs',
        'profile-round-keys',
        'profile-open-scan',
        'profile-open-mining-key',
      ]) {
        expect(_key(gone), findsNothing, reason: gone);
      }
      expect(find.text('跨链'), findsNothing);
      expect(find.text('代币授权'), findsNothing);
      expect(find.text('网络'), findsNothing);
      expect(find.text('充值'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each entry opens its page', (tester) async {
      final opened = <String>[];
      await _pumpMe(tester, onNavigate: opened.add);
      Future<String> tapAndRead(String key) async {
        opened.clear();
        await tester.ensureVisible(_key(key));
        await tester.pumpAndSettle();
        await tester.tap(_key(key));
        await tester.pumpAndSettle();
        return opened.single;
      }

      expect(await tapAndRead('wallet-history-action'), '/wallet/history');
      expect(await tapAndRead('me-notification-bell'), '/chat/notifications');
      expect(await tapAndRead('profile-open-settings'), '/profile/settings');
      expect(await tapAndRead('profile-open-edit'), '/profile/edit');
      expect(
        await tapAndRead('profile-following-count'),
        '/profile/connections',
      );
      expect(await tapAndRead('profile-open-wallets'), '/wallet/manage');
      expect(
        await tapAndRead('profile-open-referral'),
        loopIntelInviteLocation,
      );
      expect(loopIntelInviteLocation, '/intel?tab=power&sub=invite');
      expect(await tapAndRead('wallet-dapp-entry'), '/wallet/dapp');
      expect(await tapAndRead('wallet-power-tag'), loopIntelPowerLocation);
      expect(loopIntelPowerLocation, '/intel?tab=power');
      expect(await tapAndRead('wallet-pay-entry'), '/scan');

      // 分享名片 opens the LOOP ID card sheet.
      await tester.tap(_key('profile-share-loop-id'));
      await tester.pumpAndSettle();
      expect(find.text(_loopId), findsWidgets);
    });

    testWidgets('a waiting stranger request stands under the person', (
      tester,
    ) async {
      final opened = <String>[];
      await _pumpMe(tester, onNavigate: opened.add, requests: _oneRequest());
      final entry = _key('stream-chat-message-requests-entry');
      expect(entry, findsOneWidget);
      expect(find.text('1 条待处理'), findsOneWidget);
      expect(
        tester.getTopLeft(entry).dy,
        greaterThan(tester.getTopLeft(_key('profile-identity-card')).dy),
      );
      expect(
        tester.getTopLeft(entry).dy,
        lessThan(tester.getTopLeft(_key('wallet-total-plate')).dy),
      );
      await tester.tap(entry);
      expect(opened, <String>['/chat/requests']);
    });

    testWidgets('no request: no row', (tester) async {
      await _pumpMe(tester);
      expect(_key('stream-chat-message-requests-entry'), findsNothing);
    });

    testWidgets('profile loading: the stored face, then the card', (
      tester,
    ) async {
      await _pumpMe(tester, profilePending: true);
      await tester.pump();
      await tester.pump();
      expect(_key('profile-loading'), findsOneWidget);
      expect(_key('profile-identity-card'), findsNothing);
      // The rest of the page does not wait for the person.
      expect(_key('wallet-total-plate'), findsOneWidget);
      expect(_key('me-account-entries'), findsOneWidget);
    });

    testWidgets('nothing held: the empty asset state, no overflow at 390', (
      tester,
    ) async {
      await _pumpMe(tester, balances: s5Balances(rows: const []));
      expect(_key('wallet-balances-empty'), findsOneWidget);
      expect(_key('me-account-entries'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 360 the name and the LOOP ID stay on one line', (
      tester,
    ) async {
      await _pumpMe(tester, size: const Size(360, 2400));
      expect(find.text(_loopId), findsOneWidget);
      expect(tester.getSize(_key('profile-loop-id')).height, lessThan(24));
      expect(tester.getSize(_key('profile-alias')).height, lessThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a short phone scrolls the whole page to its last row', (
      tester,
    ) async {
      await _pumpMe(tester, size: const Size(390, 700));
      await tester.scrollUntilVisible(
        _key('wallet-dapp-entry'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(_key('wallet-dapp-entry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wallet module closed: the person and the rows still stand', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        meta: s5MetaSnapshot(
          walletRead: LoopV2CapabilityAvailability.unavailable,
        ),
        overrides: [profileGatewayProvider.overrideWithValue(_Profile())],
      );
      expect(_key('wallet-capability-block'), findsOneWidget);
      expect(_key('profile-identity-card'), findsOneWidget);
      expect(_key('me-account-entries'), findsOneWidget);
      expect(_key('wallet-total-plate'), findsNothing);
    });
  });

  group('接收 · 获取资金', () {
    testWidgets('testnet: one 获取资金 button opens the faucet sheet', (
      tester,
    ) async {
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
      );
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
        meta: s5MetaSnapshot(
          testnetFaucet: LoopV2CapabilityAvailability.available,
        ),
        overrides: [testnetFaucetGatewayProvider.overrideWithValue(faucet)],
      );
      final button = _key('receive-faucet');
      expect(button, findsOneWidget);
      expect(find.text(testnetFaucetTitle), findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(_key('testnet-faucet-sheet'), findsOneWidget);
    });

    testWidgets('mainnet (capability closed): no button', (tester) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
      );
      expect(_key('receive-copy-address'), findsOneWidget);
      expect(_key('receive-faucet'), findsNothing);
    });
  });

  group('设置', () {
    testWidgets('only 隐私与安全, 通用, 关于 and 退出登录', (tester) async {
      final opened = <String>[];
      await pumpS5Page(
        tester,
        ProfileSurfaceScreen.fromId(
          'settings',
          onNavigate: opened.add,
          onSignOut: () async {},
        ),
      );
      for (final kept in <String>[
        'profile-open-privacy',
        'profile-open-security',
        'profile-open-notifications',
        'settings-theme',
        'settings-reduce-motion',
        'settings-app-lock',
        'settings-open-about',
        'settings-open-support',
        'settings-sign-out',
      ]) {
        expect(_key(kept), findsOneWidget, reason: kept);
      }
      for (final gone in <String>[
        'profile-round-keys',
        'profile-share-loop-id',
        'profile-open-scan',
        'profile-open-mining-key',
        'profile-open-wallets',
        'profile-open-connections',
        'profile-open-friend-requests',
        'profile-open-referral',
        'profile-open-communities',
        'profile-open-mining',
        'profile-open-mining-assets',
        'profile-open-mining-rewards',
        'profile-open-mining-rules',
        'profile-open-notification-inbox',
      ]) {
        expect(_key(gone), findsNothing, reason: gone);
      }
      expect(find.text('账号'), findsNothing);
      expect(find.text('资产与挖矿'), findsNothing);
      expect(find.text('通知中心'), findsNothing);
      expect(find.text('隐私与安全'), findsOneWidget);
      await tester.tap(_key('profile-open-notifications'));
      expect(opened, <String>['notif-settings']);
    });
  });

  group('routes', () {
    test('profile destinations land on 我的 and 情报 · 算力', () {
      expect(profileDestinationPath('profile'), '/wallet');
      expect(profileDestinationPath('invite'), '/intel?tab=power&sub=invite');
      expect(profileDestinationPath('dapp'), '/wallet/dapp');
      expect(profileDestinationPath('settings'), '/profile/settings');
      expect(profileDestinationPath('no-such-page'), '/wallet');
    });

    testWidgets('/profile lands on 我的; its child pages keep their paths', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/wallet');
      expect(_key('wallet-screen'), findsOneWidget);
      expect(find.byType(LoopTabBar), findsOneWidget);

      router.go('/profile/settings');
      await tester.pumpAndSettle();
      expect(_key('settings-screen'), findsOneWidget);
      router.go('/profile/edit');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/profile/edit');
      expect(tester.takeException(), isNull);
    });
  });

  group('the 我的 tab', () {
    testWidgets('label 我的, a person glyph, path /wallet', (tester) async {
      expect(LoopShell.destinationLabels.last, '我的');
      expect(LoopShell.destinationPaths.last, '/wallet');
      await _pumpApp(tester);
      final item = tester.widget<LoopTabItem>(
        find.widgetWithText(LoopTabItem, '我的'),
      );
      expect(item.icon, 'user');
      expect(item.slug, 'wallet');
      expect(item.dot, isFalse);
      expect(_key('loop-tab-dot-wallet'), findsNothing);
    });

    testWidgets('a waiting stranger request puts a dot on 我的', (tester) async {
      await _pumpApp(tester, requests: _oneRequest());
      expect(_key('loop-tab-dot-wallet'), findsOneWidget);
      final dot = tester.getCenter(_key('loop-tab-dot-wallet'));
      final tab = tester.getRect(find.widgetWithText(LoopTabItem, '我的'));
      expect(tab.contains(dot), isTrue);
      for (final other in <String>['chat', 'square', 'meme', 'intel']) {
        expect(_key('loop-tab-dot-$other'), findsNothing, reason: other);
      }
    });

    testWidgets('the bar draws the dot it is told to', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            bottomNavigationBar: LoopTabBar(
              selectedIndex: 0,
              onSelect: (_) {},
              attention: const <String>{'wallet'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('loop-tab-dot-wallet'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('我的，有新消息')), findsOneWidget);
    });
  });

  group('shots', () {
    testWidgets('聊天', skip: !_shots, (tester) async {
      await _pumpChat(tester);
      await _shot(tester, 'S343-chat');
    });

    testWidgets('我的 · 有资产', skip: !_shots, (tester) async {
      await _pumpMe(
        tester,
        requests: _oneRequest(),
        size: const Size(390, 1700),
      );
      await _shot(tester, 'S343-me-assets');
    });

    testWidgets('我的 · 360 宽', skip: !_shots, (tester) async {
      await _pumpMe(
        tester,
        requests: _oneRequest(),
        size: const Size(360, 1600),
      );
      await _shot(tester, 'S343-me-360');
    });

    testWidgets('我的 · 空资产', skip: !_shots, (tester) async {
      await _pumpMe(
        tester,
        balances: s5Balances(rows: const []),
        size: const Size(390, 1500),
      );
      await _shot(tester, 'S343-me-empty');
    });

    testWidgets('设置', skip: !_shots, (tester) async {
      await pumpS5Page(
        tester,
        ProfileSurfaceScreen.fromId(
          'settings',
          onNavigate: (_) {},
          onSignOut: () async {},
        ),
        size: const Size(390, 1100),
      );
      await _shot(tester, 'S343-settings');
    });
  });
}
