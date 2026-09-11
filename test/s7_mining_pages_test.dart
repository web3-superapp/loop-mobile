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
