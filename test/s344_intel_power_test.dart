// S344 · decision 0272: 情报 · 算力 — the segment, its deep links, the
// network and my cards, the three tabs, 算力榜 as its own page, the retired
// mining / referral routes, and the 价格提醒 glyph that is not the bell.
//
// The shots at the end run only with `--dart-define=LOOP_SHOTS=true`; they
// write 390-wide renders to `LOOP_SHOTS_DIR` (default `.dart_tool/s344_shots`).
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/intel_power_route.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _shotDir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: '.dart_tool/s344_shots',
);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

// The fixture adds up: my 总算力 1,237,577.89 = 代币 1,234,577.39 (Cake
// 1,234,567.39 + USDT 10) + NFT 3,000.5, and the last settled hour reads the
// same, inside a network of 5,025,001.1.
MiningNftTrack _nftTrack() => MiningNftTrack(
  realCount: BigInt.from(3),
  ownPower: Decimal.parse('3000.5'),
  invitePower: Decimal.zero,
  totalPower: Decimal.parse('3000.5'),
  reward: BigInt.zero,
  networkPower: Decimal.parse('25000.5'),
);

MiningAssetTrack _assetTrack() => MiningAssetTrack(
  assets: const <MiningTrackAsset>[],
  ownPower: Decimal.parse('1234577.39'),
  invitePower: Decimal.zero,
  totalPower: Decimal.parse('1234577.39'),
  reward: BigInt.zero,
  networkPower: Decimal.parse('5000000.6'),
);

List<MiningAssetRow> _rows() => <MiningAssetRow>[
  s7MiningAssetRow(
    holding: '1543209.8625',
    power: '1237567.89',
    nftPower: '3000.5',
  ),
  s7MiningAssetRow(
    assetId: s7UsdtAssetId,
    symbol: 'USDT',
    holding: '10',
    weight: '1',
    power: '10',
  ),
];

Future<void> _pumpPower(
  WidgetTester tester, {
  Widget? page,
  bool split = true,
  bool hour = true,
  List<MiningAssetRow>? rows,
  ReferralOverview? referral,
  Size size = const Size(390, 3200),
  VoidCallback? onOpenRank,
  VoidCallback? onOpenRewards,
}) => pumpS7Page(
  tester,
  page ??
      MiningScreen(
        embedded: true,
        onOpenRank: onOpenRank,
        onOpenRewards: onOpenRewards,
      ),
  mining: FakeMiningGateway(
    summary: S7Answer<MiningSummary>(
      value: (rows ?? _rows()).isEmpty
          ? s7MiningBaselineSummary(
              assetPower: split ? '0' : null,
              nftPower: split ? '0' : null,
              power: '0',
            )
          : s7MiningBaselineSummary(
              assetPower: split ? '1234577.39' : null,
              nftPower: split ? '3000.5' : null,
              power: '1237577.89',
              networkPower: '5025001.1',
              snapshot: s7MiningSnapshot(),
            ),
    ),
    assets: S7Answer<MiningAssets>(
      value: s7MiningSettledAssets(
        included: rows ?? _rows(),
        excluded: const <MiningExcludedAsset>[
          MiningExcludedAsset(
            assetId: s7WbnbAssetId,
            symbol: 'WBNB',
            reasonCode: 'MINING_PRICE_NOT_FRESH',
          ),
        ],
      ),
    ),
  ),
  referral: FakeReferralGateway(
    overview: S7Answer<ReferralOverview>(value: referral ?? s7Referral()),
  ),
  size: size,
  overrides: <Override>[
    miningRewardsGatewayProvider.overrideWithValue(
      hour
          ? S7TokenStageRewards.preToken(nft: _nftTrack(), asset: _assetTrack())
          : S7TokenStageRewards.preToken(),
    ),
  ],
);

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: _key('mining-power-tabs'), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// A mining port that answers each board with a populated first page.
final class _Boards implements MiningGateway {
  final FakeMiningGateway _inner = FakeMiningGateway();
  final List<MiningRankScope> scopes = <MiningRankScope>[];

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) {
    scopes.add(scope);
    return Future<MiningRank>.value(_board(scope));
  }

  @override
  Future<MiningSummary> loadSummary() => _inner.loadSummary();

  @override
  Future<MiningAssets> loadAssets() => _inner.loadAssets();

  @override
  Future<MiningCommunity> loadCommunity(String communityId) =>
      _inner.loadCommunity(communityId);

  @override
  Future<MiningRules> loadRules() => _inner.loadRules();
}

MiningRank _board(MiningRankScope scope) => s7MiningRank(
  scope: scope,
  snapshot: s7MiningSnapshot(),
  me: const MiningRankMe(rank: 12, value: '1240', communityId: 'mine'),
  ranking: switch (scope) {
    MiningRankScope.communities => MiningRankingCommunities(
      items: <MiningRankCommunityRow>[
        for (var index = 0; index < 8; index += 1)
          MiningRankCommunityRow(
            position: index + 1,
            power: '${12960 - index * 900}',
            community: MiningCommunityRef(
              communityId: 'community-${index + 1}',
              name: '社区${index + 1}',
              boundAssetId: s7CakeAssetId,
            ),
            weight: '1.0',
            participants: 30 - index,
          ),
      ],
      participants: 150,
    ),
    MiningRankScope.users => MiningRankingUsers(
      items: <MiningRankUserRow>[
        for (var index = 0; index < 6; index += 1)
          MiningRankUserRow(
            position: index + 1,
            power: '${3420 - index * 100}',
            powerVisibility: MiningRankAudience.everyone,
            display: MiningRankAlias(
              alias: 'member${index + 1}',
              publicProfileId:
                  '8c2b7a15-4d3e-4f60-9a11-${(index + 1).toString().padLeft(12, '0')}',
              audience: MiningRankAudience.everyone,
            ),
            isSelf: false,
          ),
      ],
      participants: 240,
    ),
    MiningRankScope.referrals => const MiningRankingReferrals(
      items: <MiningRankReferralRow>[
        MiningRankReferralRow(
          position: 1,
          invitedCount: 12,
          display: MiningRankAlias(
            alias: 'inviter',
            publicProfileId: s7PublicProfileId,
            audience: MiningRankAudience.everyone,
          ),
          isSelf: false,
        ),
      ],
      participants: 40,
      ruleKey: 'mining.rank.referrals.directActiveEdges',
    ),
  },
);

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
          const _EmptySpot(),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(MemeScreen)));
}

final class _EmptySpot implements HyperliquidSpotMarketRepository {
  const _EmptySpot();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async =>
      HyperliquidSpotSnapshot(
        receivedAt: DateTime.utc(2026, 11, 3),
        markets: const <HyperliquidSpotMarket>[],
      );
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump();
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotDir/S344-$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  loopWatchGround();

  group('情报 segments and the 价格提醒 glyph', () {
    testWidgets('the segments are 算力 / 行情; 算力 is the power page', (
      tester,
    ) async {
      expect(IntelScreen.segments, <String>['Power', 'Market']);
      await pumpS7Page(
        tester,
        IntelScreen(onNavigate: (_) {}),
        mining: FakeMiningGateway(),
      );
      expect(find.text('Power Ranking'), findsNothing);
      expect(_key('intel-power'), findsOneWidget);
      expect(_key('mining-screen'), findsOneWidget);
      // The segment's one (i) is 挖矿说明.
      expect(_key('mining-rules-action'), findsOneWidget);
    });

    testWidgets('价格提醒 wears the alarm, never the notifications bell', (
      tester,
    ) async {
      await pumpS5Page(tester, IntelScreen(onNavigate: (_) {}));
      await tester.tap(_key('intel-segment-1'));
      await tester.pumpAndSettle();
      final intel = tester.widget<LoopIconButton>(_key('intel-alerts-action'));
      expect(intel.icon, 'alarm');
      expect(intel.icon, isNot('bell'));

      await pumpS5Page(tester, MarketScreen(onNavigate: (_) {}));
      final market = tester.widget<LoopIconButton>(
        _key('market-alerts-action'),
      );
      expect(market.icon, 'alarm');
      expect(market.label, intel.label);
    });
  });

  group('deep links', () {
    test('the locations S343 links to', () {
      expect(IntelPowerRoute.powerLocation(), '/intel?tab=power');
      expect(IntelPowerRoute.inviteLocation(), '/intel?tab=power&sub=invite');
      expect(
        IntelPowerRoute.inviteLocation(code: 'LOOP-7HJKM'),
        '/intel?tab=power&sub=invite&code=LOOP-7HJKM',
      );
      expect(IntelPowerRoute.segmentOf('power'), 0);
      expect(IntelPowerRoute.segmentOf('market'), 1);
      expect(IntelPowerRoute.segmentOf('x'), isNull);
      expect(IntelPowerTab.tryParse('invite'), IntelPowerTab.invite);
    });

    testWidgets('tab=power&sub=invite opens 算力 on 邀请', (tester) async {
      await pumpS7Page(
        tester,
        IntelScreen(onNavigate: (_) {}, tab: 'power', sub: 'invite'),
        mining: FakeMiningGateway(),
        referral: FakeReferralGateway(),
      );
      expect(_key('mining-screen'), findsOneWidget);
      expect(_key('mining-power-tab-invite'), findsOneWidget);
      expect(_key('referral-invite-code'), findsOneWidget);
    });

    testWidgets('tab=market opens 行情', (tester) async {
      await pumpS5Page(tester, IntelScreen(onNavigate: (_) {}, tab: 'market'));
      expect(_key('market-screen'), findsOneWidget);
    });

    testWidgets('the router applies the link and clears the query', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      router.go(IntelPowerRoute.inviteLocation());
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/intel');
      expect(_key('mining-power-tab-invite'), findsOneWidget);

      // Picked by hand, then the same link again: it applies again.
      await _tab(tester, 'Token');
      expect(_key('mining-power-tab-token'), findsOneWidget);
      await tester.tap(_key('intel-segment-1'));
      await tester.pumpAndSettle();
      router.go(IntelPowerRoute.inviteLocation());
      await tester.pumpAndSettle();
      expect(_key('mining-power-tab-invite'), findsOneWidget);
    });
  });

  group('the retired routes forward to 情报 · 算力', () {
    testWidgets('mining and mining-assets open 算力, referral opens 邀请', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      for (final location in <String>['/mining', '/mining/assets']) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/intel',
          reason: location,
        );
        expect(_key('mining-screen'), findsOneWidget, reason: location);
        expect(find.byType(LoopTabBar), findsOneWidget, reason: location);
      }
      router.go('/profile/referral?code=LOOP-7HJKM');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/intel');
      expect(_key('mining-power-tab-invite'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoopApp)),
      );
      // The code waits for the overview (closed in this build) to offer it.
      expect(container.read(intelPendingInviteCodeProvider), 'LOOP-7HJKM');
    });

    testWidgets('a push from a page over the tabs lands without a crash', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      unawaited(router.push('/mining/rules'));
      await tester.pumpAndSettle();
      for (final location in <String>[
        '/mining',
        '/mining/assets',
        '/profile/referral',
      ]) {
        unawaited(router.push(location));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/intel',
          reason: location,
        );
        unawaited(router.push('/mining/rules'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('mining-rank renders 算力榜', (tester) async {
      final router = await _pumpApp(tester);
      unawaited(router.push('/mining/rank'));
      await tester.pumpAndSettle();
      expect(find.byType(IntelRankBoard), findsOneWidget);
      expect(_key('intel-rank-board'), findsOneWidget);
    });
  });

  group('the cards', () {
    testWidgets('全网总算力: the hour\'s NFT and 代币, and the 算力榜 icon', (
      tester,
    ) async {
      var rank = 0;
      var rewards = 0;
      await _pumpPower(
        tester,
        onOpenRank: () => rank += 1,
        onOpenRewards: () => rewards += 1,
      );
      expect(_key('mining-network-card'), findsOneWidget);
      expect(find.text('Network power · Last hour'), findsOneWidget);
      // 5,000,000.6 + 25,000.5.
      expect(
        tester
            .widget<Text>(_key('mining-network-total'))
            .textSpan!
            .toPlainText(),
        startsWith('5,025,001'),
      );
      expect(_text(tester, 'mining-summary-hero-network-nft'), '25,000');
      expect(_text(tester, 'mining-summary-hero-network-token'), '5,000,000');
      await tester.tap(_key('mining-network-rank-action'));
      expect(rank, 1);

      // 我的总算力: the figure, the hour's cells and 挖矿奖励 — no split
      // cells (the tabs have them), no formula chip (the (i) has it).
      expect(_key('mining-summary-hero'), findsOneWidget);
      expect(_key('mining-summary-hero-split'), findsNothing);
      expect(_key('mining-summary-hero-token-power'), findsNothing);
      expect(_key('mining-summary-hero-stamp'), findsNothing);
      expect(_key('mining-summary-hero-caption'), findsOneWidget);
      expect(_text(tester, 'mining-summary-hero-last-hour-power'), '1,237,577');
      final claim = _key('mining-summary-hero-claim');
      expect(
        find.descendant(of: claim, matching: find.text('Mining rewards')),
        findsOneWidget,
      );
      expect(find.text('小时算力'), findsNothing);
      await tester.tap(claim);
      expect(rewards, 1);
      expect(_key('mining-summary-hero-assets'), findsNothing);
    });

    testWidgets('no settled hour: the snapshot total alone, no split', (
      tester,
    ) async {
      await _pumpPower(tester, hour: false, rows: const <MiningAssetRow>[]);
      expect(find.text('Network power'), findsOneWidget);
      expect(_key('mining-network-split'), findsNothing);
      expect(
        tester
            .widget<Text>(_key('mining-network-total'))
            .textSpan!
            .toPlainText(),
        startsWith('4,000'),
      );
      // No snapshot time: no 「快照 · —」 line at all.
      expect(_key('mining-summary-hero-caption'), findsNothing);
      expect(find.textContaining('快照 ·'), findsNothing);
    });
  });

  group('the three tabs', () {
    testWidgets('代币 first; NFT and 邀请 switch the body', (tester) async {
      await _pumpPower(tester);
      final bar = tester.widget<LoopSegBar>(_key('mining-power-tabs'));
      // S350b · decision 0275: 代币 / NFT / 邀请.
      expect(bar.labels, <String>['Token', 'NFT', 'Invitation']);
      expect(_key('mining-power-tab-token'), findsOneWidget);
      expect(_key('mining-composition-token-$s7CakeAssetId'), findsOneWidget);
      // S348: what the snapshot did not count is not drawn.
      expect(_key('mining-composition-excluded'), findsNothing);
      expect(find.textContaining('参考价'), findsNothing);
      expect(find.text('Not included'), findsNothing);

      await _tab(tester, 'NFT');
      expect(_key('mining-power-tab-nft'), findsOneWidget);
      expect(_key('mining-composition-nft-$s7CakeAssetId'), findsOneWidget);
      expect(_key('mining-composition-excluded'), findsNothing);

      await _tab(tester, 'Invitation');
      expect(_key('mining-power-tab-invite'), findsOneWidget);
      expect(_key('referral-invite-code'), findsOneWidget);
      expect(_key('referral-poster'), findsOneWidget);
      // Not open yet on the server: left out, not explained.
      expect(_key('referral-link-block'), findsNothing);
      expect(find.text('Invite link'), findsNothing);
      expect(_key('referral-stats'), findsNothing);
      expect(find.textContaining('还没有开放'), findsNothing);
      expect(find.textContaining('还没有批准'), findsNothing);
      expect(find.text('No invitations yet'), findsOneWidget);
      expect(find.textContaining('绑定后，会出现在这里'), findsNothing);
      for (final label in <String>[
        'Invite list',
        'Invite boost',
        'My inviter',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('empty: nothing counted, and no NFT split sent', (
      tester,
    ) async {
      await _pumpPower(
        tester,
        split: false,
        hour: false,
        rows: const <MiningAssetRow>[],
      );
      expect(_key('mining-composition-empty'), findsOneWidget);
      await _tab(tester, 'NFT');
      expect(_key('mining-composition-nft-unavailable'), findsOneWidget);
    });

    testWidgets('a long list scrolls at 390 wide without overflow', (
      tester,
    ) async {
      await _pumpPower(
        tester,
        size: const Size(390, 844),
        rows: <MiningAssetRow>[
          for (var index = 0; index < 30; index += 1)
            s7MiningAssetRow(
              assetId:
                  'eip155:97:0x${index.toRadixString(16).padLeft(40, '0')}',
              symbol: 'TOKEN$index',
              holding: '1000',
              power: '${1000 + index}',
            ),
        ],
      );
      final last = _key(
        'mining-composition-token-eip155:97:0x${29.toRadixString(16).padLeft(40, '0')}',
      );
      await tester.scrollUntilVisible(
        last,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(last, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading, error and offline keep the tabs', (tester) async {
      for (final failure in <LaunchFailureKind>[
        LaunchFailureKind.offline,
        LaunchFailureKind.unavailable,
      ]) {
        await pumpS7Page(
          tester,
          const MiningScreen(embedded: true),
          mining: FakeMiningGateway(
            summary: S7Answer<MiningSummary>(failure: failure),
          ),
        );
        expect(_key('mining-power-tabs'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await pumpS7Page(
        tester,
        const MiningScreen(embedded: true),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(pending: true),
        ),
        settle: false,
      );
      expect(_key('mining-power-tabs'), findsOneWidget);
    });
  });

  group('算力榜', () {
    testWidgets('its own page: 社区 / 用户 / 邀请, no invite center card', (
      tester,
    ) async {
      final mining = _Boards();
      var back = 0;
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}, onBack: () => back += 1),
        mining: mining,
        size: const Size(390, 1600),
      );
      expect(find.text('Power Ranking'), findsWidgets);
      final chips = tester.widget<LoopSegBar>(_key('intel-rank-scope'));
      expect(chips.labels, <String>['Community', 'User', 'Invitation']);
      expect(_key('intel-rank-community-community-4'), findsOneWidget);

      await tester.ensureVisible(find.text('User'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('User'));
      await tester.pumpAndSettle();
      expect(mining.scopes, contains(MiningRankScope.users));
      expect(find.text('member4'), findsOneWidget);

      await tester.ensureVisible(find.text('Invitation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invitation'));
      await tester.pumpAndSettle();
      expect(mining.scopes, contains(MiningRankScope.referrals));
      expect(find.text('inviter'), findsOneWidget);
      expect(_key('intel-referral-center'), findsNothing);

      await tester.tap(_key('loop-topbar-back'));
      expect(back, 1);
    });
  });

  group('shots', () {
    testWidgets('算力 · 有数据', skip: !_shots, (tester) async {
      await tester.runAsync(loopLoadShotFonts);
      await _pumpPower(
        tester,
        page: IntelScreen(onNavigate: (_) {}),
        size: const Size(390, 1500),
      );
      await _shot(tester, 'power-data');
    });

    testWidgets('算力 · 空', skip: !_shots, (tester) async {
      await tester.runAsync(loopLoadShotFonts);
      await _pumpPower(
        tester,
        page: IntelScreen(onNavigate: (_) {}),
        split: false,
        hour: false,
        rows: const <MiningAssetRow>[],
        size: const Size(390, 1200),
      );
      await _shot(tester, 'power-empty');
    });

    testWidgets('算力榜', skip: !_shots, (tester) async {
      await tester.runAsync(loopLoadShotFonts);
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}, onBack: () {}),
        mining: _Boards(),
        size: const Size(390, 1500),
      );
      await _shot(tester, 'rank');
    });

    testWidgets('邀请 tab', skip: !_shots, (tester) async {
      await tester.runAsync(loopLoadShotFonts);
      await _pumpPower(
        tester,
        page: IntelScreen(onNavigate: (_) {}, sub: 'invite'),
        size: const Size(390, 2000),
      );
      await tester.pumpAndSettle();
      await _shot(tester, 'invite');
    });
  });
}
