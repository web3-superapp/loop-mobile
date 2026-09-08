import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// Every rendered percentage, currency amount or countdown on the page. In
/// step 7 there is nothing that could legitimately produce one.
List<String> _figures(WidgetTester tester) {
  final pattern = RegExp(r'(\d+(\.\d+)?%)|(\\$\s?\d)|(\d+d\s\d+h)');
  return <String>[
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      if (text.data != null && pattern.hasMatch(text.data!)) text.data!,
  ];
}

/// Every figure the Launch pages could show is a contract fact, and no
/// contract baseline exists. These tests pin that: the em dash and the
/// server's own `reasonCode` appear, and the prototype's numbers never do.
void main() {
  group('launch · the catalogue tab', () {
    testWidgets('loading shows a skeleton and no figure', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(pending: true),
        ),
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(find.textContaining('个已登记项目'), findsNothing);
    });

    testWidgets('awaiting-schedule is its own segment, never "即将开始"', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(),
      );

      expect(find.textContaining('待排期 1'), findsOneWidget);
      expect(find.textContaining('即将开始 0'), findsOneWidget);
      // The default segment is 发射中, which is empty, so its empty block shows.
      expect(
        find.byKey(const ValueKey<String>('launch-segment-empty-live')),
        findsOneWidget,
      );
    });

    testWidgets('a catalogue row carries no on-chain figure', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(
            value: s7Overview(
              live: <LaunchSummary>[
                s7LaunchSummary(scheduleStatus: LaunchScheduleStatus.live),
              ],
            ),
          ),
        ),
      );

      expect(find.text('MoonCat'), findsOneWidget);
      expect(find.text('链上待确认'), findsWidgets);
      // The row carries the schedule and the configuration version only.
      expect(find.textContaining('MCAT · 发射中 · 待确认'), findsOneWidget);
      // No percentage, currency figure or countdown reaches the page.
      expect(_figures(tester), isEmpty);
    });

    testWidgets('graduation stays a liquidity fact with its own reason', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(),
      );

      final graduated = find.byKey(
        const ValueKey<String>('launch-unavailable-已毕业项目'),
      );
      await scrollToS7Section(tester, graduated);
      expect(graduated, findsOneWidget);
      expect(find.textContaining('Launch 合约基线尚未交付'), findsWidgets);
    });

    testWidgets('the capability gate stops the read', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(),
        meta: s7MetaSnapshot(launch: LoopV2CapabilityAvailability.unavailable),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-capability-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('LAUNCH_RUNTIME_UNAVAILABLE'), findsOneWidget);
    });

    testWidgets('offline and error are distinct states', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(
            failure: LaunchFailureKind.offline,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('launch-state-offline')),
        findsOneWidget,
      );

      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(
            failure: LaunchFailureKind.unexpected,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('launch-state-error')),
        findsOneWidget,
      );
    });
  });

  group('launch-detail', () {
    testWidgets('the four axes each render the server reason, never a value', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(),
      );

      for (final axis in <String>['销售状态', '权益状态', '流动性状态', '运营状态']) {
        final row = find.byKey(ValueKey<String>('launch-axis-$axis'));
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: axis);
      }
      expect(find.text(launchMissingFigure), findsWidgets);
    });

    testWidgets('every configuration slot says 待确认 with its version', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(),
      );

      final slots = find.byKey(const ValueKey<String>('launch-detail-slots'));
      await scrollToS7Section(tester, slots);
      expect(slots, findsOneWidget);
      expect(find.textContaining('待确认（launchMoonCatV1）'), findsWidgets);
      // None of the prototype's contract numbers appear.
      expect(find.textContaining('10 亿'), findsNothing);
      expect(find.textContaining('0.5%'), findsNothing);
    });

    testWidgets('a missing launchId fails closed instead of guessing', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(),
        launch: FakeLaunchGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-detail-state-error')),
        findsOneWidget,
      );
    });
  });

  group('launch-rounds', () {
    testWidgets('rounds come from the configuration, not from a fixed three', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchRoundsScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s7Detail(
              rounds: <LaunchRound>[
                s7Round(),
                s7Round(index: 2),
                s7Round(index: 3),
                s7Round(index: 4),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('4 个轮次槽位'), findsOneWidget);
      for (var index = 1; index <= 4; index += 1) {
        final row = find.byKey(ValueKey<String>('launch-round-$index'));
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: 'round $index');
      }
      // No fee ladder and no round-length story is written into the client.
      expect(find.text('10%'), findsNothing);
      expect(find.text('5%'), findsNothing);
      expect(find.textContaining('0–60 秒'), findsNothing);
    });

    testWidgets('an empty round list is stated, not invented', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchRoundsScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s7Detail(rounds: const <LaunchRound>[]),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-rounds-empty')),
        findsOneWidget,
      );
      expect(find.textContaining('本页不假设固定的轮数'), findsOneWidget);
    });
  });

  group('launch-tier', () {
    testWidgets('an unconfigured mode has no tier result', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchTierScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-tier-mode-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('launch-tier-result')),
        findsOneWidget,
      );
      expect(find.text('Priority'), findsNothing);
    });

    testWidgets('a configured mode still shows the server reason', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchTierScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          eligibility: S7Answer<LaunchEligibility>(
            value: s7Eligibility(
              mode: LaunchEligibilityMode.whitelist,
              reasonCode: 'LAUNCH_CONTRACT_BASELINE_PENDING',
              configVersion: 'launchMoonCatV1',
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-tier-mode-whitelist')),
        findsOneWidget,
      );
      expect(find.text('launchMoonCatV1'), findsWidgets);
    });

    testWidgets('eligibility never depends on staking', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchTierScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(),
      );

      final row = find.byKey(
        const ValueKey<String>('launch-tier-depends-on-staking'),
      );
      await scrollToS7Section(tester, row);
      expect(row, findsOneWidget);
      expect(find.text('否'), findsOneWidget);
      expect(find.textContaining('需质押'), findsNothing);
    });
  });

  group('loop-stake', () {
    testWidgets('the whole page is non-executable and has no amount field', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LoopStakeScreen(),
        launch: FakeLaunchGateway(),
      );

      expect(find.text('不可执行'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('质押合约尚未交付'), findsWidgets);
      // No stake or unstake action exists at all.
      for (final button in tester.widgetList<LoopButton>(
        find.byType(LoopButton),
      )) {
        expect(button.label, isNot(contains('质押')));
      }
    });
  });

  group('launch-trade', () {
    testWidgets('pending capability evidence closes the action and states it', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchTradeScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-trade-amount')),
        findsOneWidget,
      );
      final submit = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('launch-trade-submit')),
      );
      expect(submit.onPressed, isNull);
      // The copy is the evidence reason the server published, not a code the
      // client wrote down.
      expect(
        find.byKey(const ValueKey<String>('launch-trade-refusal')),
        findsOneWidget,
      );
      expect(find.textContaining('Launch 合约基线尚未交付'), findsWidgets);
    });

    testWidgets(
      'settled evidence opens the action and the server still refuses',
      (tester) async {
        final gateway = FakeLaunchGateway(
          intentFailure: LaunchFailureKind.unavailable,
        );
        await pumpS7Page(
          tester,
          const LaunchTradeScreen(launchId: s7LaunchId),
          launch: gateway,
          wallet: FakeWalletDirectory(activeWalletId: s7WalletId),
          meta: s7MetaSnapshot(launchEvidencePending: false),
        );

        // A round and an amount are real inputs; without them the action
        // stays closed even though the capability is open.
        expect(
          tester
              .widget<LoopButton>(
                find.byKey(const ValueKey<String>('launch-trade-submit')),
              )
              .onPressed,
          isNull,
        );
        expect(find.textContaining('请先选择要参与的轮次'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey<String>('launch-round-1')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey<String>('launch-trade-amount')),
          '500',
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('launch-trade-submit')),
        );
        await tester.pumpAndSettle();

        // The intent reached the gateway and the refusal shown is the one the
        // server answered with.
        expect(gateway.intents, <String>['$s7LaunchId:$s7RoundId:500']);
        expect(find.text('服务端拒绝了这次认购'), findsOneWidget);
      },
    );

    testWidgets('a malformed amount never becomes a request', (tester) async {
      final gateway = FakeLaunchGateway();
      await pumpS7Page(
        tester,
        const LaunchTradeScreen(launchId: s7LaunchId),
        launch: gateway,
        wallet: FakeWalletDirectory(activeWalletId: s7WalletId),
        meta: s7MetaSnapshot(launchEvidencePending: false),
      );

      await tester.tap(find.byKey(const ValueKey<String>('launch-round-1')));
      await tester.enterText(
        find.byKey(const ValueKey<String>('launch-trade-amount')),
        '5,00',
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('launch-trade-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('请输入一个有效的支付数量'), findsOneWidget);
      expect(gateway.intents, isEmpty);
    });

    testWidgets('no payment wallet keeps the action closed', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchTradeScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(),
        wallet: FakeWalletDirectory(),
        meta: s7MetaSnapshot(launchEvidencePending: false),
      );

      expect(find.textContaining('还没有可用的支付钱包'), findsOneWidget);
    });

    testWidgets('there is no sell side before graduation', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchTradeScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(),
      );

      expect(find.text('卖出'), findsNothing);
      expect(find.textContaining('未毕业只买不卖'), findsOneWidget);
    });
  });

  group('launch-holders / launch-graduation / launch-history', () {
    testWidgets('holders renders three unavailable blocks, never a percent', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchHoldersScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(),
      );

      for (final label in <String>['持有人分布', '我的持仓', '单地址持仓上限']) {
        final block = find.byKey(ValueKey<String>('launch-unavailable-$label'));
        await scrollToS7Section(tester, block);
        expect(block, findsOneWidget, reason: label);
      }
      expect(find.textContaining('0.50%'), findsNothing);
    });

    testWidgets('graduation keeps four pending steps and no percentage', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchGraduationScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(),
      );

      expect(find.text('待触发'), findsNWidgets(4));
      expect(find.textContaining('61%'), findsNothing);
      expect(find.textContaining('生态税'), findsNothing);
      expect(find.textContaining('「已结束」只表示排期结束'), findsOneWidget);
    });

    testWidgets('an empty history says "cannot prove", not "no records"', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchHistoryScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(),
      );

      expect(find.textContaining('空列表不代表没有参与'), findsOneWidget);
      expect(find.textContaining('累计盈亏'), findsNothing);
    });
  });

  group('loop-economy', () {
    testWidgets('only provable counts are numbers', (tester) async {
      await pumpS7Page(
        tester,
        const LoopEconomyScreen(),
        launch: FakeLaunchGateway(),
      );

      expect(find.textContaining('0 个已确认轮次'), findsOneWidget);
      final projects = find.byKey(
        const ValueKey<String>('loop-economy-projects'),
      );
      await scrollToS7Section(tester, projects);
      expect(projects, findsOneWidget);

      for (final label in <String>['总量', '累计分发', '累计生态税']) {
        final block = find.byKey(ValueKey<String>('launch-unavailable-$label'));
        await scrollToS7Section(tester, block);
        expect(block, findsOneWidget, reason: label);
      }
      expect(find.textContaining('980,000'), findsNothing);
    });
  });

  group('launch-apply', () {
    testWidgets('an empty list still offers the draft form', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchApplyScreen(),
        launch: FakeLaunchGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-apply-name')),
        findsOneWidget,
      );
      final submit = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('launch-apply-submit')),
      );
      // Nothing to submit until a draft exists on the server.
      expect(submit.onPressed, isNull);
    });

    testWidgets('a local shape failure never leaves the device', (
      tester,
    ) async {
      final gateway = FakeLaunchGateway();
      await pumpS7Page(tester, const LaunchApplyScreen(), launch: gateway);

      await tester.enterText(
        find.byKey(const ValueKey<String>('launch-apply-name')),
        'MoonCat',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('launch-apply-ticker')),
        'x',
      );
      await tester.tap(find.byKey(const ValueKey<String>('launch-apply-save')));
      await tester.pumpAndSettle();

      expect(gateway.created, isEmpty);
      expect(find.textContaining('Ticker 只能是'), findsOneWidget);
    });

    testWidgets('a valid draft is created and then submitted', (tester) async {
      final gateway = FakeLaunchGateway();
      await pumpS7Page(tester, const LaunchApplyScreen(), launch: gateway);

      await tester.enterText(
        find.byKey(const ValueKey<String>('launch-apply-name')),
        'MoonCat',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('launch-apply-ticker')),
        'mcat',
      );
      await tester.tap(find.byKey(const ValueKey<String>('launch-apply-save')));
      await tester.pumpAndSettle();

      expect(gateway.created, hasLength(1));
      // The ticker is upper-cased before it leaves the device.
      expect(gateway.created.single.ticker, 'MCAT');

      await scrollToS7Section(
        tester,
        find.byKey(const ValueKey<String>('launch-apply-submit')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('launch-apply-submit')),
      );
      await tester.pumpAndSettle();

      expect(gateway.submitted, hasLength(1));
      expect(find.text('审核中'), findsWidgets);
    });

    testWidgets('an edit carries the exact server version', (tester) async {
      final gateway = FakeLaunchGateway(
        projects: S7Answer<LaunchProjectPage>(
          value: LaunchProjectPage(
            items: <LaunchProject>[s7Project(version: 4)],
            nextCursor: null,
          ),
        ),
      );
      await pumpS7Page(tester, const LaunchApplyScreen(), launch: gateway);

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();
      await scrollToS7Section(
        tester,
        find.byKey(const ValueKey<String>('launch-apply-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('launch-apply-save')));
      await tester.pumpAndSettle();

      expect(gateway.expectedVersions, <int>[4]);
    });

    testWidgets('a returned application can be edited and re-submitted', (
      tester,
    ) async {
      final gateway = FakeLaunchGateway(
        projects: S7Answer<LaunchProjectPage>(
          value: LaunchProjectPage(
            items: <LaunchProject>[
              s7Project(
                reviewStatus: LaunchReviewStatus.returned,
                reviewReasonCode: 'narrative_too_short',
              ),
            ],
            nextCursor: null,
          ),
        ),
      );
      await pumpS7Page(tester, const LaunchApplyScreen(), launch: gateway);

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('launch-apply-returned-reason')),
        findsOneWidget,
      );
      expect(find.textContaining('narrative_too_short'), findsOneWidget);
      final submit = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('launch-apply-submit')),
      );
      expect(submit.label, '重新提交');
      expect(submit.onPressed, isNotNull);
    });

    testWidgets('an approved application is read-only', (tester) async {
      final gateway = FakeLaunchGateway(
        projects: S7Answer<LaunchProjectPage>(
          value: LaunchProjectPage(
            items: <LaunchProject>[
              s7Project(
                reviewStatus: LaunchReviewStatus.approved,
                launchId: s7LaunchId,
              ),
            ],
            nextCursor: null,
          ),
        ),
      );
      await pumpS7Page(tester, const LaunchApplyScreen(), launch: gateway);

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();

      final save = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('launch-apply-save')),
      );
      expect(save.onPressed, isNull);
      expect(find.textContaining('只有草稿与被退回的申请可以修改'), findsOneWidget);
    });

    testWidgets('a rejected write is reported without blanking the list', (
      tester,
    ) async {
      final gateway = FakeLaunchGateway(
        projects: S7Answer<LaunchProjectPage>(
          value: LaunchProjectPage(
            items: <LaunchProject>[s7Project()],
            nextCursor: null,
          ),
        ),
        updateFailure: LaunchFailureKind.versionConflict,
      );
      await pumpS7Page(tester, const LaunchApplyScreen(), launch: gateway);

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();
      await scrollToS7Section(
        tester,
        find.byKey(const ValueKey<String>('launch-apply-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('launch-apply-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('launch-apply-write-failure')),
        findsOneWidget,
      );
      expect(find.text('MoonCat'), findsWidgets);
    });

    testWidgets('attachments and KYB are shown as pending, with no upload', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchApplyScreen(),
        launch: FakeLaunchGateway(
          projects: S7Answer<LaunchProjectPage>(
            value: LaunchProjectPage(
              items: <LaunchProject>[s7Project()],
              nextCursor: null,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();

      final kyb = find.byKey(const ValueKey<String>('launch-apply-kyb'));
      await scrollToS7Section(tester, kyb);
      expect(kyb, findsOneWidget);
      expect(find.textContaining('KYB 服务商尚未选定'), findsOneWidget);
      for (final button in tester.widgetList<LoopButton>(
        find.byType(LoopButton),
      )) {
        expect(button.label, isNot(contains('上传')));
      }
    });

    testWidgets('all five tracks are listed, with the implicit ones marked', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchApplyScreen(),
        launch: FakeLaunchGateway(
          projects: S7Answer<LaunchProjectPage>(
            value: LaunchProjectPage(
              items: <LaunchProject>[s7Project()],
              nextCursor: null,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();

      for (final track in <String>[
        'lbank/spot',
        'binance/alpha',
        'binance/perpetual',
        'binance/spot',
        'bithumb/spot',
      ]) {
        final row = find.byKey(ValueKey<String>('launch-milestone-$track'));
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: track);
      }
      // A track with no stored record says so; it never reads as "started".
      expect(find.textContaining('尚无记录'), findsWidgets);
      // Alpha and spot are separate tracks and neither implies the other.
      expect(find.textContaining('Binance · Alpha'), findsOneWidget);
      expect(find.textContaining('Binance · 现货'), findsOneWidget);
    });

    testWidgets('LISTED and FEATURED keep their two evidence times apart', (
      tester,
    ) async {
      for (final state in <LaunchMilestoneState>[
        LaunchMilestoneState.listed,
        LaunchMilestoneState.featured,
      ]) {
        await pumpS7Page(
          tester,
          const LaunchApplyScreen(),
          launch: FakeLaunchGateway(
            projects: S7Answer<LaunchProjectPage>(
              value: LaunchProjectPage(
                items: <LaunchProject>[s7Project()],
                nextCursor: null,
              ),
            ),
            milestones: S7Answer<LaunchMilestones>(
              value: s7Milestones(
                items: <LaunchMilestone>[
                  s7ListedMilestone(state: state),
                  for (final track in launchMilestoneTracks.skip(1))
                    s7ImplicitMilestone(venue: track.$1, marketType: track.$2),
                ],
              ),
            ),
          ),
        );

        await tester.tap(
          find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(
          const ValueKey<String>('launch-milestone-lbank/spot'),
        );
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: state.name);
        // Two different facts, rendered separately and never derived.
        expect(
          find.textContaining('复核记录于 2026-09-05 03:00 UTC'),
          findsOneWidget,
          reason: state.name,
        );
        expect(
          find.textContaining('平台可核验于 2026-09-01 00:00 UTC'),
          findsOneWidget,
          reason: state.name,
        );
      }
    });

    testWidgets('a missing observedAt is an em dash, not the recorded time', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchApplyScreen(),
        launch: FakeLaunchGateway(
          projects: S7Answer<LaunchProjectPage>(
            value: LaunchProjectPage(
              items: <LaunchProject>[s7Project()],
              nextCursor: null,
            ),
          ),
          milestones: S7Answer<LaunchMilestones>(
            value: s7Milestones(
              items: <LaunchMilestone>[
                LaunchMilestone(
                  venueMilestoneId: s7MilestoneId,
                  venue: LaunchVenue.lbank,
                  marketType: LaunchMarketType.spot,
                  state: LaunchMilestoneState.listed,
                  evidence: LaunchMilestoneEvidence(
                    digest: 'a' * 64,
                    recordedAt: DateTime.utc(2026, 9, 5, 3),
                    observedAt: null,
                    reviewer: 'ops.alice',
                  ),
                  version: 2,
                  updatedAt: DateTime.utc(2026, 9, 5, 3),
                ),
                for (final track in launchMilestoneTracks.skip(1))
                  s7ImplicitMilestone(venue: track.$1, marketType: track.$2),
              ],
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();

      final row = find.byKey(
        const ValueKey<String>('launch-milestone-lbank/spot'),
      );
      await scrollToS7Section(tester, row);
      expect(
        find.textContaining('平台可核验时间 $launchMissingFigure（操作员未提供）'),
        findsOneWidget,
      );
      expect(find.textContaining('平台可核验于'), findsNothing);
    });

    testWidgets('a rejected write offers a reload that keeps the edits', (
      tester,
    ) async {
      final gateway = FakeLaunchGateway(
        projects: S7Answer<LaunchProjectPage>(
          value: LaunchProjectPage(
            items: <LaunchProject>[s7Project()],
            nextCursor: null,
          ),
        ),
        updateFailure: LaunchFailureKind.versionConflict,
      );
      await pumpS7Page(tester, const LaunchApplyScreen(), launch: gateway);

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('launch-apply-narrative')),
        '改过的叙事',
      );
      await scrollToS7Section(
        tester,
        find.byKey(const ValueKey<String>('launch-apply-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('launch-apply-save')));
      await tester.pumpAndSettle();

      final reload = find.byKey(const ValueKey<String>('launch-apply-reload'));
      await scrollToS7Section(tester, reload);
      expect(reload, findsOneWidget);
      await tester.tap(reload);
      await tester.pumpAndSettle();

      // The re-read refreshes the version; the typed edit is not discarded.
      expect(find.text('改过的叙事'), findsOneWidget);
    });

    testWidgets('all four official links round-trip through the form', (
      tester,
    ) async {
      final gateway = FakeLaunchGateway();
      await pumpS7Page(
        tester,
        const LaunchApplyScreen(),
        launch: gateway,
        size: const Size(390, 3600),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-apply-telegram')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('launch-apply-name')),
        'MoonCat',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('launch-apply-ticker')),
        'MCAT',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('launch-apply-telegram')),
        'https://t.me/mooncat',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('launch-apply-discord')),
        'https://discord.gg/mooncat',
      );
      await scrollToS7Section(
        tester,
        find.byKey(const ValueKey<String>('launch-apply-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('launch-apply-save')));
      await tester.pumpAndSettle();

      final links = gateway.created.single.officialLinks;
      expect(links.telegram, 'https://t.me/mooncat');
      expect(links.discord, 'https://discord.gg/mooncat');
    });

    testWidgets('a non-owner projection shows the trail as unavailable', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchApplyScreen(),
        launch: FakeLaunchGateway(
          projects: S7Answer<LaunchProjectPage>(
            value: LaunchProjectPage(
              items: <LaunchProject>[s7ForeignProject()],
              nextCursor: null,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('launch-apply-project-$s7ProjectId')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('审核轨迹与版本只属于申请人'), findsOneWidget);
      final save = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('launch-apply-save')),
      );
      expect(save.onPressed, isNull);
    });
  });

  group('the retired prototype口径 never appears', () {
    testWidgets('no ecosystem tax, fixed supply, cap or round ladder', (
      tester,
    ) async {
      for (final page in <Widget>[
        const LaunchScreen(),
        const LaunchDetailScreen(launchId: s7LaunchId),
        const LaunchRoundsScreen(launchId: s7LaunchId),
        const LoopEconomyScreen(),
      ]) {
        await pumpS7Page(tester, page, launch: FakeLaunchGateway());
        for (final forbidden in <String>[
          '永久 1%',
          '1% 生态税',
          '10 亿',
          '0.5% 单地址',
          '\$300,000',
          '300K',
        ]) {
          expect(
            find.textContaining(forbidden),
            findsNothing,
            reason: '$forbidden on ${page.runtimeType}',
          );
        }
      }
    });
  });
}
