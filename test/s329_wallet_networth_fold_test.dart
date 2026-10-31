// S329 · decision 0259: the net-worth chart under 总资产 folds again, its
// closed state is lower than before S327, and its windows are quiet tabs.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_segmented_control.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// The same fixture S329 measured the three closed heights with: a week with
/// a ¥ line and a 24h move.
final class _History implements WalletNetWorthHistoryGateway {
  final List<LoopNetWorthRange> requested = <LoopNetWorthRange>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopNetWorthHistory> loadNetWorthHistory(
    String walletId,
    LoopNetWorthRange range,
  ) async {
    requested.add(range);
    return LoopNetWorthHistory(
      range: range,
      points: <LoopNetWorthPoint>[
        for (final (index, value) in const <String>[
          '106.12',
          '141.90',
          '128.40',
        ].indexed)
          LoopNetWorthPoint(
            at: DateTime.utc(2026, 10, 8 + index),
            netWorthUsd: Decimal.parse(value),
          ),
      ],
      change24h: LoopNetWorthChangeAvailable(
        usd: Decimal.parse('12.08'),
        pct: Decimal.parse('10.4'),
      ),
      fiat: LoopNetWorthFiat(
        currency: 'CNY',
        rate: Decimal.parse('7.1125'),
        amount: Decimal.parse('913.27'),
      ),
      source: 'loop_networth_snapshots',
      observedAt: DateTime.utc(2026, 10, 15, 0, 5),
    );
  }
}

/// The 总资产 header's height, closed, on a 390-wide screen with the
/// fixture above: before S327 (88 × 44 sparkline slot + 「净值走势 ⌄」 row)
/// it measured 238, and S327's always-open chart 421.
const double _closedBeforeS327 = 238;

/// What decision 0259 allows the closed header: lower than before S327.
const double _closedCeiling = 212;

void main() {
  loopWatchGround();

  Future<_History> pump(WidgetTester tester) async {
    final history = _History();
    await pumpS5Page(
      tester,
      const WalletScreen(),
      wallet: FakeWalletReadGateway(),
      overrides: <Override>[
        walletNetWorthHistoryGatewayProvider.overrideWithValue(history),
      ],
    );
    return history;
  }

  testWidgets('closed by default: no chart and no windows; the line opens '
      'and closes it', (tester) async {
    final history = await pump(tester);
    expect(_key('wallet-networth-panel'), findsNothing);
    expect(_key('wallet-networth-chart'), findsNothing);
    expect(_key('wallet-networth-ranges'), findsNothing);
    expect(_key('wallet-networth-spark'), findsNothing);
    expect(_key('wallet-networth-expand'), findsOneWidget);
    expect(find.text('净值走势'), findsOneWidget);
    expect(history.requested, <LoopNetWorthRange>[LoopNetWorthRange.week]);

    await tester.tap(_key('wallet-networth-expand'));
    await tester.pumpAndSettle();
    expect(_key('wallet-networth-chart'), findsOneWidget);
    expect(_key('wallet-networth-ranges'), findsOneWidget);
    expect(_key('wallet-networth-collapse'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);

    await tester.tap(_key('wallet-networth-collapse'));
    await tester.pumpAndSettle();
    expect(_key('wallet-networth-panel'), findsNothing);
    expect(_key('wallet-networth-expand'), findsOneWidget);
  });

  testWidgets('the closed 总资产 header is lower than before S327', (
    tester,
  ) async {
    await pump(tester);
    final closed = tester.getSize(_key('wallet-total-header')).height;
    final plateClosed = tester.getSize(_key('wallet-total-plate')).height;
    // The switch is one 44-high line; nothing sits beside the total.
    expect(tester.getSize(_key('wallet-pnl')).height, LoopTouch.minimum);
    await tester.tap(_key('wallet-networth-expand'));
    await tester.pumpAndSettle();
    final open = tester.getSize(_key('wallet-total-header')).height;
    // ignore: avoid_print
    print(
      'S329 总资产 header closed=$closed (plate $plateClosed), open=$open, '
      'before S327 closed=$_closedBeforeS327',
    );
    expect(closed, lessThanOrEqualTo(_closedCeiling));
    expect(closed, lessThan(_closedBeforeS327));
    expect(open, greaterThan(closed));
  });

  testWidgets('the windows are quiet word tabs: no track, no edge, no '
      'filled cell; the chosen one Chalk w700 over a 1.5 underline', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(_key('wallet-networth-expand'));
    await tester.pumpAndSettle();
    final ranges = _key('wallet-networth-ranges');
    expect(
      tester.widget<WalletQuietTabs<LoopNetWorthRange>>(ranges).selected,
      LoopNetWorthRange.week,
    );
    expect(
      find.byType(WalletSegmentedControl<LoopNetWorthRange>),
      findsNothing,
    );
    for (final type in <Type>[DecoratedBox, Container, Material, Ink]) {
      expect(
        find.descendant(of: ranges, matching: find.byType(type)),
        findsNothing,
        reason: '$type',
      );
    }
    // Touch 44, drawn 28.
    expect(tester.getSize(ranges).height, LoopTouch.minimum);
    for (final option in LoopNetWorthRange.values) {
      final tab = _key('wallet-networth-range-${option.wireName}');
      expect(tester.getSize(tab).height, LoopTouch.minimum);
      final drawn = find.descendant(
        of: tab,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.height == WalletQuietTabs.visualHeight,
        ),
      );
      expect(drawn, findsOneWidget);
      final word = tester.widget<Text>(
        find.descendant(of: tab, matching: find.text(option.label)),
      );
      final chosen = option == LoopNetWorthRange.week;
      expect(word.style!.color, chosen ? LoopColors.chalk : LoopColors.text3);
      expect(
        word.style!.fontWeight,
        chosen ? FontWeight.w700 : FontWeight.w500,
      );
      final rule = tester.widget<ColoredBox>(
        find.descendant(of: tab, matching: find.byType(ColoredBox)),
      );
      expect(rule.color, chosen ? LoopColors.chalk : Colors.transparent);
      expect(
        tester
            .getSize(
              find.descendant(of: tab, matching: find.byType(ColoredBox)),
            )
            .height,
        WalletQuietTabs.underline,
      );
    }

    await tester.tap(_key('wallet-networth-range-30d'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<WalletQuietTabs<LoopNetWorthRange>>(ranges).selected,
      LoopNetWorthRange.month,
    );
    await tester.tap(_key('wallet-networth-range-7d'));
    await tester.pumpAndSettle();
  });
}
