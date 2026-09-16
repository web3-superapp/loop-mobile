import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'package:loop_mobile/core/navigation/launch_route.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// Every Mining figure needs an approved formula version, and there is none.
/// These tests pin the em dash, the server's own reason and the absence of
/// every ratio the prototype used to state.
List<String> _figures(WidgetTester tester) {
  final pattern = RegExp(r'(\d+(\.\d+)?×)|(\d+(\.\d+)?%)|(\$\s?\d)');
  return <String>[
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      if (text.data != null && pattern.hasMatch(text.data!)) text.data!,
  ];
}

void main() {
  group('mining-community route identity', () {
    test('the panel is addressed by the opaque communityId alone', () {
      final location = MiningRoute.community(s7CommunityId);

      expect(location, '/mining/community?communityId=$s7CommunityId');
      expect(
        MiningRoute.parse(Uri.parse(location), MiningRoute.communityPath),
        s7CommunityId,
      );
      // A name, a slug or a bound address is never a route identity.
      for (final rejected in <String>[
        '/mining/community',
        '/mining/community?communityId=frog-holders',
        '/mining/community?communityId=$s7CommunityId&extra=1',
      ]) {
        expect(
          MiningRoute.parse(Uri.parse(rejected), MiningRoute.communityPath),
          isNull,
          reason: rejected,
        );
      }
    });
  });

  group('mining · the tab', () {
    testWidgets('loading shows a skeleton and no power figure', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(pending: true),
        ),
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(find.textContaining('待批准'), findsNothing);
    });

    testWidgets('every metric is an em dash with the server reason', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
      );

      for (final label in <String>[
        '我的算力',
        '全网算力',
        '今日预估',
        '累计已挖',
        '待领取',
        '邀请加成',
      ]) {
        final metric = find.byKey(ValueKey<String>('launch-metric-$label'));
        await scrollToS7Section(tester, metric);
        expect(metric, findsOneWidget, reason: label);
      }
      expect(find.text(launchMissingFigure), findsWidgets);
      expect(_figures(tester), isEmpty);
    });

    testWidgets('the hero says it has no number instead of drawing a dash', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
      );

      final folio = find.byKey(const ValueKey<String>('loop-folio-primary'));
      expect(folio, findsOneWidget);
      // At 29px in Lime the metric cells' em dash stops reading as a
      // placeholder and becomes a stray green rule, so the hero states the
      // absence. It is still not a 0, not a fixture and not blank.
      expect(
        find.descendant(of: folio, matching: find.text(launchMissingHeading)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: folio, matching: find.text(launchMissingFigure)),
        findsNothing,
      );
      expect(
        find.descendant(of: folio, matching: find.text('0')),
        findsNothing,
      );
      // The cells keep the dash: only the heading changed voice.
      expect(find.text(launchMissingFigure), findsWidgets);
    });

    testWidgets('the pending formula is labelled without naming its version', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
      );

      expect(find.text('待批准'), findsWidgets);
      // The stamp and the row say the status; the version says nothing a
      // reader can act on and stays out of both.
      expect(find.textContaining('MININGFORMULAV1-DRAFT'), findsNothing);
      final formula = find.byKey(const ValueKey<String>('mining-formula-row'));
      await scrollToS7Section(tester, formula);
      expect(find.text('miningFormulaV1-draft'), findsNothing);
    });

    testWidgets('the pending formula version stays inside the 详情', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
      );

      final details = find.byKey(
        const ValueKey<String>('mining-formula-details'),
      );
      await scrollToS7Section(tester, details);
      expect(details, findsOneWidget);
      expect(find.textContaining('miningFormulaV1-draft'), findsNothing);

      await tester.tap(
        find.descendant(
          of: details,
          matching: find.byKey(
            const ValueKey<String>('loop-disclosure-summary'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('miningFormulaV1-draft'), findsOneWidget);
    });

    testWidgets('one missing baseline is explained once, not per metric', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
      );

      // Five of the six figures are empty for the same reason. The block
      // states it once; the sixth keeps its own, different sentence.
      expect(find.text('挖矿公式还没有批准，算力、产量、排行与邀请加成都暂时不可用。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('launch-metric-grid-reason')),
        findsOneWidget,
      );
      expect(find.text('奖励发放还没有开启，暂时不能领取。'), findsOneWidget);
    });

    testWidgets('a settled figure prints with its baseline label', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
        ),
      );

      // The number is the server's, verbatim, and it never appears without
      // the label that says which kind of number it is.
      expect(find.text('1000'), findsWidgets);
      expect(find.text('4000'), findsOneWidget);
      expect(find.text('开发基线'), findsWidgets);
      // A placeholder budget is never a bare 1000000 on the screen.
      expect(find.text('1000000'), findsNothing);
      expect(find.textContaining('占位产量'), findsOneWidget);
      // The version is an identifier: it stays out of every sentence.
      expect(find.textContaining('miningFormula-devBaseline'), findsNothing);
    });

    testWidgets('the effective version stays inside the 详情', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
        ),
      );

      final details = find.byKey(
        const ValueKey<String>('mining-formula-details'),
      );
      await scrollToS7Section(tester, details);
      await tester.tap(
        find.descendant(
          of: details,
          matching: find.byKey(
            const ValueKey<String>('loop-disclosure-summary'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(s7BaselineVersion), findsOneWidget);
    });

    testWidgets('a baseline zero says why it is zero, not that it is missing', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              power: const MiningFigureValue('0'),
              networkPower: const MiningFigureValue('0'),
              estimatedToday: const MiningDailyOutputUnavailable(
                'MINING_NETWORK_POWER_ZERO',
              ),
              formula: MiningFormulaEffective(
                configVersion: s7BaselineVersion,
                effectiveAt: DateTime.utc(2026, 9, 15, 14, 57, 37),
                scope: MiningFormulaScope.developmentBaseline,
              ),
            ),
          ),
        ),
      );

      // A settled zero is a reading, not an absence: it keeps the figure and
      // says which rule produced it.
      expect(find.text('0'), findsWidgets);
      expect(find.text('开发基线'), findsWidgets);
      expect(find.textContaining('全网算力为 0'), findsOneWidget);
      // 我的算力 is a settled row now, not one of the em-dash cells.
      expect(
        find.byKey(const ValueKey<String>('mining-metric-power')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('mining-metric-power')),
          matching: find.text(launchMissingFigure),
        ),
        findsNothing,
      );
    });

    testWidgets('the snapshot is absent, not zero', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
      );

      final snapshot = find.byKey(
        const ValueKey<String>('mining-snapshot-unavailable'),
      );
      await scrollToS7Section(tester, snapshot);
      expect(snapshot, findsOneWidget);
      expect(find.textContaining('还没有任何一次算力结算'), findsOneWidget);
    });

    testWidgets('the capability gate stops the read', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
        meta: s7MetaSnapshot(mining: LoopV2CapabilityAvailability.unavailable),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-capability-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('offline and error stay distinct', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(failure: LaunchFailureKind.offline),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('mining-state-offline')),
        findsOneWidget,
      );

      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            failure: LaunchFailureKind.unexpected,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('mining-state-error')),
        findsOneWidget,
      );
    });
  });

  group('mining-assets', () {
    testWidgets('an empty asset list is stated as a contract fact', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: FakeMiningGateway(),
      );

      expect(find.textContaining('空列表是正常结果'), findsOneWidget);
      expect(find.textContaining('不代表你的钱包没有持仓'), findsOneWidget);
      expect(_figures(tester), isEmpty);
    });

    testWidgets('the community mining panel is reachable from here', (
      tester,
    ) async {
      var opened = false;
      await pumpS7Page(
        tester,
        MiningAssetsScreen(onOpenCommunities: () => opened = true),
        mining: FakeMiningGateway(),
      );

      final row = find.byKey(
        const ValueKey<String>('mining-assets-open-communities'),
      );
      await scrollToS7Section(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(opened, isTrue);
    });

    testWidgets('the reference price carries the server reason', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: FakeMiningGateway(),
      );

      final price = find.byKey(
        const ValueKey<String>('launch-unavailable-挖矿参考价'),
      );
      await scrollToS7Section(tester, price);
      expect(price, findsOneWidget);
    });

    testWidgets('a settled row prints its holding, price and weight', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: FakeMiningGateway(
          assets: S7Answer<MiningAssets>(
            value: s7MiningSettledAssets(
              included: <MiningAssetRow>[
                s7MiningAssetRow(holding: '12.5', power: '22.6'),
              ],
            ),
          ),
        ),
      );

      final row = find.byKey(
        ValueKey<String>('mining-assets-row-$s7CakeAssetId'),
      );
      await scrollToS7Section(tester, row);
      expect(row, findsOneWidget);
      // Every figure is the server's own decimal, printed verbatim.
      expect(find.textContaining('持有 12.5'), findsOneWidget);
      expect(find.textContaining('参考价 2.26'), findsOneWidget);
      expect(find.text('权重 0.8'), findsOneWidget);
      expect(find.text('22.6'), findsOneWidget);
      // The list is no longer empty, so the contract notice is gone.
      expect(
        find.byKey(const ValueKey<String>('mining-assets-empty-notice')),
        findsNothing,
      );
    });

    testWidgets('the native coin row says its price is a proxy', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: FakeMiningGateway(
          assets: S7Answer<MiningAssets>(value: s7MiningSettledAssets()),
        ),
      );

      final row = find.byKey(
        ValueKey<String>('mining-assets-row-$s7NativeAssetId'),
      );
      await scrollToS7Section(tester, row);
      expect(row, findsOneWidget);
      // The row names the asset the price came from instead of presenting it
      // as the coin's own.
      expect(find.textContaining('代理价，来自'), findsOneWidget);
      // Twice: the proxy's own row above, and the proxied row naming it.
      expect(find.textContaining('0xbb4c'), findsNWidgets(2));
      expect(find.textContaining('BNB Smart Chain 原生代币'), findsOneWidget);
    });

    testWidgets('an excluded asset says why it was not counted', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: FakeMiningGateway(
          assets: S7Answer<MiningAssets>(
            value: s7MiningSettledAssets(
              included: <MiningAssetRow>[s7MiningAssetRow()],
              excluded: <MiningExcludedAsset>[
                const MiningExcludedAsset(
                  assetId: s7UsdtAssetId,
                  reasonCode: 'MINING_PRICE_NOT_FRESH',
                ),
              ],
            ),
          ),
        ),
      );

      final row = find.byKey(
        ValueKey<String>('mining-assets-excluded-$s7UsdtAssetId'),
      );
      await scrollToS7Section(tester, row);
      expect(row, findsOneWidget);
      expect(find.textContaining('参考价不够新'), findsOneWidget);
      // The reason is a sentence; the code behind it never reaches the screen.
      expect(find.textContaining('MINING_PRICE'), findsNothing);
    });

    testWidgets('the price version stays inside the 详情', (tester) async {
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: FakeMiningGateway(
          assets: S7Answer<MiningAssets>(value: s7MiningSettledAssets()),
        ),
      );

      expect(find.textContaining(s7PriceVersion), findsNothing);
      final details = find.byKey(
        const ValueKey<String>('mining-assets-price-details'),
      );
      await scrollToS7Section(tester, details);
      await tester.tap(
        find.descendant(
          of: details,
          matching: find.byKey(
            const ValueKey<String>('loop-disclosure-summary'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(s7PriceVersion), findsOneWidget);
    });

    testWidgets('a settlement with no rows is not the contract empty', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: FakeMiningGateway(
          assets: S7Answer<MiningAssets>(
            value: s7MiningSettledAssets(included: <MiningAssetRow>[]),
          ),
        ),
      );

      final empty = find.byKey(
        const ValueKey<String>('mining-assets-included-empty'),
      );
      await scrollToS7Section(tester, empty);
      expect(empty, findsOneWidget);
      // "The settlement weighted nothing of yours" and "there was no
      // settlement" are different sentences.
      expect(
        find.byKey(const ValueKey<String>('mining-assets-empty-notice')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-assets-source')),
        findsOneWidget,
      );
    });
  });

  group('mining-rewards', () {
    testWidgets('the claim control is disabled by the server flag', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRewardsScreen(),
        mining: FakeMiningGateway(),
      );

      final claim = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('mining-rewards-claim')),
      );
      expect(claim.onPressed, isNull);
      expect(
        find.byKey(const ValueKey<String>('mining-rewards-claim-notice')),
        findsOneWidget,
      );
      expect(find.textContaining('奖励发放还没有开启'), findsWidgets);
    });

    testWidgets('an empty ledger is not "no output"', (tester) async {
      await pumpS7Page(
        tester,
        const MiningRewardsScreen(),
        mining: FakeMiningGateway(),
      );

      final notice = find.byKey(
        const ValueKey<String>('mining-rewards-ledger-notice'),
      );
      await scrollToS7Section(tester, notice);
      expect(notice, findsOneWidget);
      expect(_figures(tester), isEmpty);
    });

    testWidgets('a failed read is an error state, not a zero', (tester) async {
      await pumpS7Page(
        tester,
        const MiningRewardsScreen(),
        mining: FakeMiningGateway(
          rewards: S7Answer<MiningRewards>(
            failure: LaunchFailureKind.unexpected,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-rewards-state-error')),
        findsOneWidget,
      );
      expect(find.text('0'), findsNothing);
    });
  });

  group('mining-rank', () {
    testWidgets('both scopes stay unavailable and the rule is stated', (
      tester,
    ) async {
      final gateway = FakeMiningGateway();
      await pumpS7Page(tester, const MiningRankScreen(), mining: gateway);

      expect(
        find.byKey(const ValueKey<String>('launch-unavailable-排行榜条目')),
        findsOneWidget,
      );
      final anonymity = find.byKey(
        const ValueKey<String>('mining-rank-anonymity'),
      );
      await scrollToS7Section(tester, anonymity);
      expect(anonymity, findsOneWidget);
      expect(find.textContaining('匿名成员'), findsOneWidget);

      // Switching scope re-reads rather than relabelling the previous answer.
      await tester.tap(find.text('用户榜'));
      await tester.pumpAndSettle();
      expect(gateway.scopes, contains(MiningRankScope.users));
    });

    testWidgets('a zero-power row is 未上榜, never the position 0', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRankScreen(),
        mining: FakeMiningGateway(
          rank: S7Answer<MiningRank>(
            value: s7MiningRank(
              scope: MiningRankScope.users,
              ranking: s7MiningUserBoard(),
              myPosition: const MiningRankPositionUnavailable(
                'MINING_RANK_NOT_RANKED',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('用户榜'));
      await tester.pumpAndSettle();

      final board = find.byKey(const ValueKey<String>('mining-rank-items'));
      await scrollToS7Section(tester, board);
      expect(board, findsOneWidget);
      expect(find.textContaining('未上榜'), findsNWidgets(2));
      // The position 0 is not a rank, and it is never printed as one.
      expect(find.textContaining('第 0 名'), findsNothing);
      // An account that is not discoverable is named by the label, not an id.
      expect(find.text('匿名成员'), findsOneWidget);
      expect(find.text('whale'), findsOneWidget);
      expect(find.textContaining(s7PublicProfileId), findsNothing);
      expect(find.textContaining('算力为 0，暂时没有名次'), findsOneWidget);
    });

    testWidgets('a ranked user board prints places and marks the reader', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRankScreen(),
        mining: FakeMiningGateway(
          rank: S7Answer<MiningRank>(
            value: s7MiningRank(
              scope: MiningRankScope.users,
              ranking: s7MiningUserBoard(
                items: const <MiningRankUserRow>[
                  MiningRankUserRow(
                    position: 1,
                    power: '3000',
                    display: MiningRankAlias(
                      alias: 'whale',
                      publicProfileId: s7PublicProfileId,
                    ),
                    isSelf: false,
                  ),
                  MiningRankUserRow(
                    position: 2,
                    power: '1000',
                    display: MiningRankAnonymous('mining.rank.anonymousMember'),
                    isSelf: true,
                  ),
                ],
                participants: 2,
              ),
              myPosition: const MiningRankPositionSettled(
                position: 2,
                power: '1000',
              ),
              snapshot: s7MiningSnapshot(),
            ),
          ),
        ),
      );

      await tester.tap(find.text('用户榜'));
      await tester.pumpAndSettle();

      expect(find.text('第 1 名'), findsOneWidget);
      // The hero, my row on the board and 我的名次 all say the same place.
      expect(find.text('第 2 名'), findsNWidgets(3));
      expect(find.text('3000'), findsOneWidget);
      expect(find.text('我'), findsOneWidget);
      final participants = find.byKey(
        const ValueKey<String>('mining-rank-participants'),
      );
      await scrollToS7Section(tester, participants);
      expect(find.textContaining('有 2 个条目算出了算力'), findsOneWidget);
    });

    testWidgets('the community board carries weight and head count', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRankScreen(),
        mining: FakeMiningGateway(
          rank: S7Answer<MiningRank>(
            value: s7MiningRank(ranking: s7MiningCommunityBoard()),
          ),
        ),
      );

      final board = find.byKey(const ValueKey<String>('mining-rank-items'));
      await scrollToS7Section(tester, board);
      expect(find.text('Builders Guild'), findsOneWidget);
      expect(find.text('权重 1.5'), findsOneWidget);
      expect(find.text('权重 0.8'), findsOneWidget);
      expect(find.textContaining('0 人有算力'), findsNWidgets(2));
    });

    testWidgets('the capability gate hides the scopes too', (tester) async {
      await pumpS7Page(
        tester,
        const MiningRankScreen(),
        mining: FakeMiningGateway(),
        meta: s7MetaSnapshot(mining: LoopV2CapabilityAvailability.unavailable),
      );

      expect(find.byType(LoopSegBar), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('mining-rank-capability-unavailable'),
        ),
        findsOneWidget,
      );
    });
  });

  group('mining-community', () {
    testWidgets('a reviewed weight is shown, a pending one is not', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-community-weight-pending')),
        findsOneWidget,
      );
      expect(find.textContaining('权重还在审核中'), findsOneWidget);
      expect(_figures(tester), isEmpty);
    });

    testWidgets('an approved weight renders the server value verbatim', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningCommunity(
              weight: MiningCommunityWeightApproved(
                value: '0.35',
                configVersion: 'communityWeightV1',
                reviewedAt: DateTime.utc(2026, 9, 7),
              ),
            ),
          ),
        ),
      );

      expect(find.text('0.35'), findsOneWidget);
      expect(find.textContaining('communityWeightV1'), findsNothing);
    });

    testWidgets('a settled panel prints its four figures and its settlement', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningSettledCommunity(),
          ),
        ),
      );

      final metrics = find.byKey(
        const ValueKey<String>('mining-community-metrics'),
      );
      await scrollToS7Section(tester, metrics);
      expect(metrics, findsOneWidget);
      // A settled zero keeps its figure: it is a reading, not an absence.
      expect(find.text('0'), findsWidgets);
      // The weight is why this community has a power at all.
      expect(find.text('0.8'), findsOneWidget);
      expect(find.textContaining('算力为 0，暂时没有名次'), findsOneWidget);
      final snapshot = find.byKey(
        const ValueKey<String>('mining-community-snapshot'),
      );
      await scrollToS7Section(tester, snapshot);
      expect(find.textContaining('区块 122037728'), findsOneWidget);
    });

    testWidgets('a ranked community says its place, not a bare number', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningSettledCommunity(
              rank: const MiningRankPositionSettled(
                position: 7,
                power: '38200',
              ),
              participants: const MiningParticipantsCount(42),
            ),
          ),
        ),
      );

      final metrics = find.byKey(
        const ValueKey<String>('mining-community-metrics'),
      );
      await scrollToS7Section(tester, metrics);
      expect(find.text('第 7 名'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('the formula version stays inside the 详情', (tester) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningSettledCommunity(),
          ),
        ),
      );

      expect(find.textContaining(s7BaselineVersion), findsNothing);
      final details = find.byKey(
        const ValueKey<String>('mining-community-weight-details'),
      );
      await scrollToS7Section(tester, details);
      await tester.tap(
        find.descendant(
          of: details,
          matching: find.byKey(
            const ValueKey<String>('loop-disclosure-summary'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(s7BaselineVersion), findsOneWidget);
    });

    testWidgets('a missing communityId fails closed', (tester) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(),
        mining: FakeMiningGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-community-state-error')),
        findsOneWidget,
      );
    });
  });

  group('mining-rules', () {
    testWidgets('the draft is labelled 待批准 without its version', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      expect(find.text('待批准'), findsWidgets);
      expect(find.textContaining('MININGFORMULAV1-DRAFT'), findsNothing);
      expect(find.text('算力 = 持有量 × 参考价 × 权重'), findsWidgets);
      expect(find.textContaining('每日产出 = 我的算力 ÷ 全网算力'), findsOneWidget);
    });

    testWidgets('weight bands carry a key and a state, never a range', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      final loop = find.byKey(
        const ValueKey<String>(
          'mining-rules-pending-miningFormulaV1-draft-weight-loop',
        ),
      );
      await scrollToS7Section(tester, loop);
      expect(loop, findsOneWidget);
      // The prototype's 1.0× and 0.1×–1.0× bands are gone.
      expect(find.textContaining('1.0×'), findsNothing);
      expect(find.textContaining('0.1×'), findsNothing);
    });

    testWidgets('the three price guards are listed by rule key', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      for (final key in <String>[
        'mining.rules.priceGuard.twap',
        'mining.rules.priceGuard.multiPeriodMultiSource',
        'mining.rules.priceGuard.liquidityCap',
      ]) {
        final row = find.byKey(
          ValueKey<String>(
            'mining-rules-pending-miningFormulaV1-draft-guard-$key',
          ),
        );
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: key);
      }
    });

    testWidgets('no approved version renders the baseline reason', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-unavailable-已批准的公式版本')),
        findsOneWidget,
      );
      expect(find.textContaining('挖矿公式还没有批准'), findsWidgets);
    });

    testWidgets('the referral ladder comes from the server, verbatim', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      for (var level = 1; level <= 5; level += 1) {
        final row = find.byKey(
          ValueKey<String>('mining-rules-referral-l$level'),
        );
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: 'L$level');
      }
      expect(find.textContaining('referralRulesV1'), findsNothing);
    });
  });
}
