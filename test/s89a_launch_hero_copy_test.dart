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
      expect(primary.caption, 'Loading project details and on-chain status');
      expect(find.text(launchMissingName), findsNothing);
      expect(find.textContaining("can't be loaded right now"), findsNothing);
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
      expect(primary.caption, contains('read at block'));
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
      expect(
        primary.caption,
        contains(
          "On-chain status, price and graduation progress can't be loaded right now",
        ),
      );
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
      expect(
        launchDetailHeading(null, loading: true),
        'Loading project details',
      );
      expect(
        launchDetailHeading(null, loading: false),
        'Couldn\'t load project details',
      );
      expect(launchDetailHeading(s7Detail(), loading: false), 'MoonCat');
      expect(
        launchDetailCaption(null, loading: true),
        'Loading project details and on-chain status',
      );
      expect(
        launchDetailCaption(null, loading: false),
        contains("can't be loaded right now"),
      );
    });
  });

  group('the Launch hero follows the catalogue rows', () {
    testWidgets('no chain row: 链下 and the cannot-read caption', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(),
      );
      final primary = folio(tester);
      expect(primary.stamp, 'Off-chain');
      expect(
        primary.caption,
        contains(
          "On-chain status, price and graduation progress can't be loaded right now",
        ),
      );
    });

    testWidgets('a chain row: 链上, and the testnet named', (tester) async {
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
      expect(primary.stamp, 'On-chain');
      expect(
        primary.caption,
        'Directory, applications and round config come from LOOP. On-chain status is read from BSC Testnet.',
      );
    });

    test('the caption names the main chain off the testnet', () {
      final overview = s7Overview(
        live: <LaunchSummary>[s7LaunchSummary(onChainState: s83cOnChain())],
      );
      expect(launchOverviewReadsChain(overview), isTrue);
      expect(launchOverviewReadsChain(s7Overview()), isFalse);
      expect(
        launchOverviewCaption(overview, testnet: false),
        contains('On-chain status is read from BSC Mainnet'),
      );
      expect(
        launchOverviewCaption(null, testnet: true),
        contains("can't be loaded right now"),
      );
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
      final card = key('launch-unavailable-graduated-projects');
      await scrollToS7Section(tester, card);
      expect(
        find.descendant(
          of: card,
          matching: find.text('The graduated list isn\'t open yet'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining("contract isn't live yet"), findsNothing);
    });

    testWidgets('pending: the original sentence stays', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(),
      );
      final card = key('launch-unavailable-graduated-projects');
      await scrollToS7Section(tester, card);
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining("The Launch contract isn't live yet"),
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
        find.descendant(
          of: row,
          matching: find.text('Participant count isn\'t open yet'),
        ),
        findsOneWidget,
      );
    });

    test('the mapping keeps every other code and the pending evidence', () {
      final holders = LaunchResourceState<LaunchHolders>(
        mode: LaunchGatewayMode.production,
        phase: LaunchViewPhase.ready,
        value: s7Holders(),
      );
      expect(
        launchHoldersRowText(holders),
        'The Launch contract isn\'t live yet. Participant count isn\'t available.',
      );
      expect(
        launchHoldersRowText(holders, contractLive: true),
        'Participant count isn\'t open yet',
      );
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
        find.descendant(
          of: liveRow,
          matching: find.text('MCAT, Live, Pending confirmation'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Awaiting schedule,'), findsNothing);

      // The chips scroll sideways; bring this one into view first.
      await tester.ensureVisible(find.text('Ended 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ended 1'));
      await tester.pumpAndSettle();
      final endedRow = key('launch-row-$s7LaunchId');
      expect(
        find.descendant(
          of: endedRow,
          matching: find.text('MCAT, Sale ended, Pending confirmation'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Approved, awaiting schedule'), findsNothing);
    });

    testWidgets('待排期 keeps the schedule wording', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(),
      );
      // The chips scroll sideways; the English chips run past the screen.
      await tester.ensureVisible(find.text('Awaiting schedule 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Awaiting schedule 1'));
      await tester.pumpAndSettle();
      expect(
        find.text('MCAT, Approved, awaiting schedule, Pending confirmation'),
        findsOneWidget,
      );
    });
  });
}
