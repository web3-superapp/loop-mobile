import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';

/// Decision 0097 · the Launch hero and `launch-detail` folio say what the
/// read actually established: a reading state while reading, the chain once
/// the catalogue carries a chain reading, and no "the contract is not live"
/// once the capability evidence confirms it is.
void main() {
  Finder key(String value) => find.byKey(ValueKey<String>(value));

  LoopFolioPrimary folio(WidgetTester tester) =>
      tester.widget<LoopFolioPrimary>(find.byType(LoopFolioPrimary).first);

  group('launch-detail folio while reading', () {
    testWidgets('loading: a heading skeleton and a neutral reading caption', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(pending: true),
        ),
        settle: false,
      );
      await tester.pump();
      await tester.pump();

      final primary = folio(tester);
      expect(primary.headingLoading, isTrue);
      expect(primary.caption, '正在读取项目资料与链上状态');
      expect(find.text(launchMissingName), findsNothing);
      expect(find.textContaining('暂时读不到'), findsNothing);
    });

    testWidgets('read with a name: the name, and the chain sentence', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(value: s83cDetail()),
        ),
      );
      final primary = folio(tester);
      expect(primary.headingLoading, isFalse);
      expect(primary.heading, isNot(launchMissingName));
      expect(primary.caption, contains('读自区块'));
    });

    testWidgets('read without a chain block: the cannot-read sentence', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(value: s7Detail()),
        ),
      );
      final primary = folio(tester);
      expect(primary.headingLoading, isFalse);
      expect(primary.caption, contains('链上状态、价格与毕业进度暂时读不到'));
    });

    testWidgets('a failed read never says 暂无名称', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(failure: LaunchFailureKind.offline),
        ),
      );
      final primary = folio(tester);
      expect(primary.headingLoading, isFalse);
      expect(primary.heading, isNot(launchMissingName));
    });

    test('the heading rule', () {
      expect(launchDetailHeading(null, loading: true), '项目资料读取中');
      expect(launchDetailHeading(null, loading: false), '没有读到项目资料');
      expect(launchDetailHeading(s7Detail(), loading: false), 'MoonCat');
      expect(launchDetailCaption(null, loading: true), '正在读取项目资料与链上状态');
      expect(launchDetailCaption(null, loading: false), contains('暂时读不到'));
    });
  });

  group('the Launch hero follows the catalogue rows', () {
    testWidgets('no chain row: OFF-CHAIN and the cannot-read caption', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(),
      );
      final primary = folio(tester);
      expect(primary.stamp, 'OFF-CHAIN');
      expect(primary.caption, contains('链上状态、价格与毕业进度暂时读不到'));
    });

    testWidgets('a chain row: ON-CHAIN, and the testnet named', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        meta: s7MetaSnapshot(
          launchEvidenceConfirmed: true,
          launchChainId: 'eip155:97',
        ),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(
            value: s7Overview(
              awaitingSchedule: const <LaunchSummary>[],
              ended: <LaunchSummary>[
                s7LaunchSummary(
                  chainId: 'eip155:97',
                  onChainState: s83cOnChain(sale: LaunchSaleState.ended),
                ),
              ],
            ),
          ),
        ),
      );
      final primary = folio(tester);
      expect(primary.stamp, 'ON-CHAIN');
      expect(primary.caption, '目录、申请与轮次配置由 LOOP 提供；链上状态读自 BSC 测试网。');
    });

    test('the caption names the main chain off the testnet', () {
      final overview = s7Overview(
        live: <LaunchSummary>[s7LaunchSummary(onChainState: s83cOnChain())],
      );
      expect(launchOverviewReadsChain(overview), isTrue);
      expect(launchOverviewReadsChain(s7Overview()), isFalse);
      expect(
        launchOverviewCaption(overview, testnet: false),
        contains('链上状态读自 BSC 主网'),
      );
      expect(launchOverviewCaption(null, testnet: true), contains('暂时读不到'));
    });
  });

  group('LAUNCH_CONTRACT_BASELINE_PENDING against confirmed evidence', () {
    testWidgets('confirmed: the graduated card says the list is not open', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        meta: s7MetaSnapshot(launchEvidenceConfirmed: true),
        launch: FakeLaunchGateway(),
      );
      final card = key('launch-unavailable-已毕业项目');
      await scrollToS7Section(tester, card);
      expect(
        find.descendant(of: card, matching: find.text('已毕业名单还没有开放读取')),
        findsOneWidget,
      );
      expect(find.textContaining('合约还没有上线'), findsNothing);
    });

    testWidgets('pending: the original sentence stays', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(),
      );
      final card = key('launch-unavailable-已毕业项目');
      await scrollToS7Section(tester, card);
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('Launch 合约还没有上线'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('confirmed: the holders row on launch-detail', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(launchId: s7LaunchId),
        meta: s7MetaSnapshot(launchEvidenceConfirmed: true),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(value: s83cDetail()),
          holders: S7Answer<LaunchHolders>(value: s7Holders()),
        ),
      );
      final row = key('launch-detail-open-holders');
      await scrollToS7Section(tester, row);
      expect(
        find.descendant(of: row, matching: find.text('参与人数还没有开放读取')),
        findsOneWidget,
      );
    });

    test('the mapping keeps every other code and the pending evidence', () {
      final holders = LaunchResourceState<LaunchHolders>(
        mode: LaunchGatewayMode.production,
        phase: LaunchViewPhase.ready,
        value: s7Holders(),
      );
      expect(launchHoldersRowText(holders), 'Launch 合约还没有上线，参与人数暂时不可用。');
      expect(launchHoldersRowText(holders, contractLive: true), '参与人数还没有开放读取');
      expect(
        launchBaselineReasonText(
          'LAUNCH_CHAIN_RPC_UNREACHABLE',
          contractLive: true,
          whenLive: 'x',
        ),
        launchReasonCodeText('LAUNCH_CHAIN_RPC_UNREACHABLE'),
      );
    });
  });

  group('live and ended rows state the sale, never 待排期', () {
    testWidgets('an unscheduled launch in 已结束 reads its sale state', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(
            value: s7Overview(
              awaitingSchedule: const <LaunchSummary>[],
              live: <LaunchSummary>[
                s7LaunchSummary(
                  launchId: 'live-1',
                  // The chain has not been read for this one.
                ),
              ],
              ended: <LaunchSummary>[
                s7LaunchSummary(
                  onChainState: s83cOnChain(sale: LaunchSaleState.ended),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // 发射中 is the default segment: no chain reading → the segment's name.
      final liveRow = key('launch-row-live-1');
      expect(
        find.descendant(of: liveRow, matching: find.text('MCAT · 发射中 · 待确认')),
        findsOneWidget,
      );
      expect(find.textContaining('待排期 ·'), findsNothing);

      await tester.tap(find.text('已结束 1'));
      await tester.pumpAndSettle();
      final endedRow = key('launch-row-$s7LaunchId');
      expect(
        find.descendant(
          of: endedRow,
          matching: find.text('MCAT · 销售已结束 · 待确认'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('已批准 · 待排期'), findsNothing);
    });

    testWidgets('待排期 keeps the schedule wording', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(),
      );
      await tester.tap(find.text('待排期 1'));
      await tester.pumpAndSettle();
      expect(find.text('MCAT · 已批准 · 待排期 · 待确认'), findsOneWidget);
    });
  });
}
