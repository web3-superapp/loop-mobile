import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// The order of the blocks on each Launch page, pinned.
///
/// The visual audit (2026-09-21 §H) found the module's pages readable but
/// ordered wrongly: `launch` put three explanations between its folio and the
/// segment bar, so the first screen held no project; `launch-detail` opened on
/// twelve key-value rows; `loop-economy` opened on two count tables. Those are
/// regressions an assertion about presence cannot catch, so this file asserts
/// position: block A is above block B, on the page as it renders.
void main() {
  /// The vertical offset of [key], which must be built exactly once.
  double topOf(WidgetTester tester, String key) {
    final finder = find.byKey(ValueKey<String>(key));
    expect(finder, findsOneWidget, reason: key);
    return tester.getTopLeft(finder).dy;
  }

  /// Asserts [keys] appear in this order, top to bottom.
  void expectOrder(WidgetTester tester, List<String> keys) {
    var previous = double.negativeInfinity;
    for (final (index, key) in keys.indexed) {
      final top = topOf(tester, key);
      expect(
        top,
        greaterThan(previous),
        reason: index == 0 ? key : '$key 必须排在 ${keys[index - 1]} 之后',
      );
      previous = top;
    }
  }

  testWidgets('launch puts the segment bar and the list on the first screen', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const LaunchScreen(),
      launch: FakeLaunchGateway(),
      meta: s7MetaSnapshot(launchChainId: 'eip155:97'),
    );

    expectOrder(tester, <String>[
      'loop-page-primary',
      'launch-segments',
      'loop-testnet-notice',
      'launch-segment-empty-live',
      'launch-unavailable-已毕业项目',
      'launch-curation-notice',
      'launch-chain-row',
      'launch-evidence-notice',
      'launch-source-footer',
      'launch-open-economy',
      'launch-open-apply',
    ]);
    // The catalogue's folio is the saturated Lime one the prototype gives it.
    expect(
      tester.widget<LoopFolioPrimary>(find.byType(LoopFolioPrimary)).variant,
      LoopFolioVariant.lime,
    );
  });

  testWidgets('launch-detail opens on the identity card, not on a table', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const LaunchDetailScreen(launchId: s7LaunchId),
      launch: FakeLaunchGateway(),
    );

    expectOrder(tester, <String>[
      'launch-detail-identity',
      'launch-detail-round-card',
      'launch-detail-stats',
      'launch-detail-open-tier',
      'launch-track',
      'launch-detail-open-holders',
      'launch-detail-open-trade',
      'launch-detail-facts',
      'launch-detail-baseline-notice',
    ]);
    // The twelve key-value rows are behind the disclosure, not in the flow.
    expect(
      find.byKey(const ValueKey<String>('launch-detail-slots')),
      findsNothing,
    );
    // The identity card is the prototype's Chalk half of the composite.
    expect(find.byType(LoopLedgerComposite), findsOneWidget);
  });

  testWidgets('launch-rounds is a timeline over a cap card', (tester) async {
    await pumpS7Page(
      tester,
      const LaunchRoundsScreen(launchId: s7LaunchId),
      launch: FakeLaunchGateway(),
    );

    expectOrder(tester, <String>[
      'loop-page-primary',
      'launch-rounds-list',
      'launch-rounds-caps',
      'launch-rounds-facts',
      'launch-rounds-notice',
    ]);
    expect(find.byType(LoopChalkCard), findsOneWidget);
  });

  testWidgets('launch-tier states the result, then the conditions', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const LaunchTierScreen(launchId: s7LaunchId),
      launch: FakeLaunchGateway(),
    );

    expectOrder(tester, <String>[
      'launch-tier-conditions',
      'launch-tier-open-stake',
      'launch-tier-mode',
      'launch-tier-result',
    ]);
    // The prototype's main action is Lime, not a grey row.
    expect(
      tester
          .widget<LoopButton>(
            find.byKey(const ValueKey<String>('launch-tier-open-stake')),
          )
          .primary,
      isTrue,
    );
  });

  testWidgets('launch-trade asks for an amount and shows what it buys', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const LaunchTradeScreen(launchId: s7LaunchId),
      launch: FakeLaunchGateway(),
    );

    expectOrder(tester, <String>[
      'launch-trade-quote',
      'launch-trade-rounds',
      'launch-trade-submit',
      'launch-trade-refusal',
      'launch-trade-buy-only',
      'launch-trade-facts',
    ]);
    // The amount field lives inside the Chalk quote box, above the half that
    // states what the amount would buy.
    expect(
      topOf(tester, 'launch-trade-amount'),
      greaterThan(topOf(tester, 'launch-trade-quote')),
    );
    expect(
      tester.widget<LoopFolioPrimary>(find.byType(LoopFolioPrimary)).variant,
      LoopFolioVariant.lime,
    );
  });

  testWidgets('launch-holders keeps the reader\'s own row in the list', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const LaunchHoldersScreen(launchId: s7LaunchId),
      launch: FakeLaunchGateway(),
    );

    expectOrder(tester, <String>[
      'loop-page-primary',
      'launch-holders-list',
      'launch-unavailable-持有人分布',
      'launch-holders-notice',
    ]);
    // The reader's own position is a row of the list, not a block below it.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('launch-holders-list')),
        matching: find.byKey(const ValueKey<String>('launch-holders-me')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('launch-graduation rails the four steps under the progress', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const LaunchGraduationScreen(launchId: s7LaunchId),
      launch: FakeLaunchGateway(),
    );

    expectOrder(tester, <String>[
      'loop-page-primary',
      'launch-graduation-steps',
      'launch-unavailable-池地址与锁定信息',
      'launch-graduation-notice',
    ]);
  });

  testWidgets('launch-history states its counts in the composite strip', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const LaunchHistoryScreen(launchId: s7LaunchId),
      launch: FakeLaunchGateway(),
    );

    expectOrder(tester, <String>[
      'loop-page-primary',
      'launch-unavailable-购买、权益与退款记录',
      'launch-history-notice',
    ]);
    expect(find.text('参与次数'), findsOneWidget);
    expect(find.byType(LoopLedgerComposite), findsOneWidget);
  });

  testWidgets('loop-stake keeps the form shape with every control closed', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const LoopStakeScreen(),
      launch: FakeLaunchGateway(),
    );

    expectOrder(tester, <String>[
      'loop-page-primary',
      'loop-stake-tabs',
      'loop-stake-executable',
      'loop-stake-submit',
      'loop-stake-notice',
    ]);
  });

  testWidgets('loop-economy opens on the ledger, not on the count tables', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const LoopEconomyScreen(),
      launch: FakeLaunchGateway(),
    );

    expectOrder(tester, <String>[
      'loop-page-primary',
      'loop-economy-launch-card',
      'loop-economy-loop-stats',
      'loop-economy-flywheel',
      'loop-economy-projects',
      'loop-economy-launches',
      'launch-source-footer',
    ]);
  });

  testWidgets('launch-apply opens on the review record', (tester) async {
    await pumpS7Page(
      tester,
      const LaunchApplyScreen(),
      launch: FakeLaunchGateway(),
    );

    expectOrder(tester, <String>[
      'loop-page-primary',
      'launch-apply-pipeline',
      'launch-apply-name',
      'launch-apply-save',
      'launch-apply-principles',
      'launch-apply-notice',
    ]);
  });

  testWidgets('every launch record page carries exactly one composite', (
    tester,
  ) async {
    for (final page in <Widget>[
      const LaunchDetailScreen(launchId: s7LaunchId),
      const LaunchRoundsScreen(launchId: s7LaunchId),
      const LaunchTierScreen(launchId: s7LaunchId),
      const LaunchHoldersScreen(launchId: s7LaunchId),
      const LaunchGraduationScreen(launchId: s7LaunchId),
      const LaunchHistoryScreen(launchId: s7LaunchId),
      const LoopStakeScreen(),
    ]) {
      await pumpS7Page(tester, page, launch: FakeLaunchGateway());
      expect(
        find.byType(LoopLedgerComposite),
        findsOneWidget,
        reason: '${page.runtimeType} 的主卡必须是 ledger-composite',
      );
    }
  });
}
