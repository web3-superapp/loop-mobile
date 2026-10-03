import 'dart:io';

import 'package:loop_mobile/integrations/community/memory_community_gateways.dart';

import 'package:flutter/material.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';

import 'support/s7_page_harness.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/preview/memory_market_gateway.dart';
import 'package:loop_mobile/preview/memory_catalog_gateways.dart';

import 'support/loop_ground_probe.dart';

void main() {
  loopWatchGround();
  test(
    'mining rank identities are unique and community details match each row',
    () async {
      final gateway = MemoryPreviewMiningGateway();
      final rank = await gateway.loadRank(MiningRankScope.communities);
      final rows = (rank.ranking as MiningRankingCommunities).items;
      expect(
        rows.map((r) => r.community.communityId).toSet().length,
        rows.length,
      );
      for (final row in rows) {
        final detail = await gateway.loadCommunity(row.community.communityId);
        expect(detail.community.communityId, row.community.communityId);
        expect(detail.community.name, row.community.name);
        expect((detail.communityPower as MiningFigureValue).value, row.power);
      }
      final users =
          ((await gateway.loadRank(MiningRankScope.users)).ranking
                  as MiningRankingUsers)
              .items;
      expect(
        users
            .map((r) => (r.display as MiningRankAlias).publicProfileId)
            .toSet()
            .length,
        users.length,
      );
      await expectLater(
        gateway.loadCommunity('unknown'),
        throwsA(isA<LaunchException>()),
      );
    },
  );
  testWidgets('preview community ranking mounts all uniquely keyed rows', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const MiningRankScreen(),
      mining: MemoryPreviewMiningGateway(),
      size: const Size(390, 2600),
    );
    for (final community in MemoryPreviewMiningGateway.communities) {
      expect(
        find.byKey(ValueKey<String>('mining-rank-community-${community.$1}')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('用户榜'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test(
    'every preview market community resolves in the mounted memory gateway',
    () async {
      final market = MemoryPreviewMarketGateway();
      final communities = MemoryCommunityGateway();
      for (final asset in MemoryPreviewMarketGateway.assets) {
        final detail = await market.loadAsset(asset.$1);
        final bound = detail.community as MarketCommunityBound;
        final community = await communities.loadCommunity(bound.communityId);
        expect(community.community.communityId, bound.communityId);
        expect(community.community.name, bound.name);
        expect(community.community.slug, bound.slug);
        expect(community.community.memberCount, bound.memberCount);
      }
    },
  );

  for (final width in [360.0, 390.0]) {
    testWidgets('populated mining and launch render at $width', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: MemoryPreviewMiningGateway(),
        size: Size(width, 1000),
      );
      expect(
        find.byKey(const ValueKey<String>('mining-capability-unavailable')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: MemoryPreviewLaunchGateway(),
        size: Size(width, 1000),
      );
      expect(find.text('MoonCat'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'production providers remain unavailable without composition overrides',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(
        c.read(marketReadGatewayProvider).mode,
        LoopChainGatewayMode.unavailable,
      );
      expect(
        c.read(walletReadGatewayProvider).mode,
        LoopChainGatewayMode.unavailable,
      );
      expect(c.read(miningGatewayProvider).mode, LaunchGatewayMode.unavailable);
      expect(c.read(launchGatewayProvider).mode, LaunchGatewayMode.unavailable);
      await expectLater(
        c.read(marketReadGatewayProvider).loadOverview(),
        throwsA(isA<LoopChainException>()),
      );
      await expectLater(
        c.read(miningGatewayProvider).loadSummary(),
        throwsA(isA<LaunchException>()),
      );
    },
  );
  test('only preview composition imports preview catalog and no transport lives in catalog', () {
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.dart') &&
                  !f.uri.pathSegments.last.startsWith('._'),
            )) {
      final source = f.readAsStringSync();
      if (!f.path.startsWith('lib/preview/') &&
          f.path != 'lib/main_preview.dart') {
        expect(
          RegExp(r'''(?:import|export)\s+['"][^'"]*(?:/preview/|preview/)''')
              .hasMatch(source),
          isFalse,
          reason: f.path,
        );
      }
      if (f.path.startsWith('lib/preview/')) {
        expect(source.contains('test/support'), isFalse);
        expect(
          RegExp(
            r'''import .*(?:dio|http|privy|stream_chat|shared_preferences)''',
          ).hasMatch(source),
          isFalse,
          reason: f.path,
        );
      }
    }
  });
  test('market preview has deterministic identity-specific details and valid period candles', () async {
    final g = MemoryPreviewMarketGateway();
    final overview = await g.loadOverview();
    final rows = (overview.trending as MarketTrendingAvailable).items;
    expect(rows.length, 8);
    expect(rows.map((r) => r.assetId).toSet().length, 8);
    for (final row in rows) {
      final detail = await g.loadAsset(row.assetId);
      final history = await g.loadCandles(
        row.assetId,
        interval: LoopCandleInterval.values.first,
      );
      expect((history.candles as MarketCandlesAvailable).items.length, 360);
      expect(detail.price.value, row.price.value);
      expect(detail.capability.swappable, isFalse);
      for (final interval in LoopCandleInterval.values) {
        final series = await g.loadCandles(
          row.assetId,
          interval: interval,
          limit: 24,
        );
        expect(series.interval, interval);
        final candles = (series.candles as MarketCandlesAvailable).items;
        expect(candles.length, 24);
        for (final c in candles) {
          expect(c.high >= c.open && c.high >= c.close, isTrue);
          expect(c.low <= c.open && c.low <= c.close, isTrue);
          expect(c.closeTime.isAfter(c.openTime), isTrue);
        }
      }
      expect(
        (await g.loadTrades(row.assetId)).trades,
        isA<MarketTradesAvailable>(),
      );
    }
    await expectLater(
      g.loadAsset('unknown'),
      throwsA(isA<LoopChainException>()),
    );
  });
  test('mining mock power is populated and claims stay disabled', () async {
    final g = MemoryPreviewMiningGateway();
    final s = await g.loadSummary();
    expect(s.power, isA<MiningFigureValue>());
    expect(
      (s.snapshot as MiningSnapshotComputed).holdingsSource,
      MiningHoldingsSource.mockSeed,
    );
    expect((await g.loadAssets()).included.length, 3);
    expect((await g.loadRewards()).claimExecutable, isFalse);
    expect(
      (await g.loadRank(MiningRankScope.users)).ranking,
      isA<MiningRankingUsers>(),
    );
    expect((await g.loadRules()).approved, isNotNull);
  });
  test('launch cannot manufacture intents and wallet cannot expose deposit address', () async {
    final l = MemoryPreviewLaunchGateway();
    expect((await l.loadOverview()).segments.live, isNotEmpty);
    await expectLater(
      l.preparePurchaseIntent(
        launchId: 'x',
        walletId: 'x',
        roundId: 'x',
        payAmount: '1',
      ),
      throwsA(isA<LaunchException>()),
    );
    final w = MemoryPreviewWalletGateway();
    final directory = await w.loadWallets();
    final id = directory.activeWalletId!;
    expect((await w.loadBalances(id)).walletId, id);
    expect((await w.loadActivity(id)).items, isNotEmpty);
    await expectLater(w.loadReceive(id), throwsA(isA<LoopChainException>()));
    final second = directory.wallets.last.walletId;
    await w.setActiveWallet(walletId: second, expectedActiveWalletId: id);
    expect((await w.loadBalances(second)).walletId, second);
  });
}
