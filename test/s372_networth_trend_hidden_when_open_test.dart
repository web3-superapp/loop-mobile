// S372 · decision 0296, the requester 11-05 16:56: on 我的, once 「今日盈亏」
// opens the net-worth chart (1D … 360D) below, the 124 × 86 week trend at
// the right of 总资产 says nothing more and is not drawn. Its box stays as an
// empty gap, so the figure and the lines under it do not move; closing the
// chart brings the trend back. Open and close switch at once (decision 0259).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_networth_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

import 'support/me_page_fixtures.dart';

Finder _key(String key) => find.byKey(ValueKey<String>(key));

final class _Week implements WalletNetWorthHistoryGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopNetWorthHistory> loadNetWorthHistory(
    String walletId,
    LoopNetWorthRange range,
  ) async => LoopNetWorthHistory(
    range: range,
    points: <LoopNetWorthPoint>[
      for (var index = 0; index < 7; index++)
        LoopNetWorthPoint(
          at: DateTime.utc(2026, 10, 8 + index),
          netWorthUsd: Decimal.fromInt(5000 + index * 200),
        ),
    ],
    change24h: LoopNetWorthChangeAvailable(
      usd: Decimal.parse('12.08'),
      pct: Decimal.parse('1.2'),
    ),
    fiat: LoopNetWorthFiat(
      currency: 'CNY',
      rate: Decimal.parse('7.1'),
      amount: Decimal.parse('913.27'),
    ),
  );
}

void main() {
  for (final width in <double>[390, 360]) {
    testWidgets('$width wide: the open chart hides the small trend, the '
        'figure stays put, closing brings it back', (tester) async {
      await pumpMePage(
        tester,
        size: Size(width, 1400),
        overrides: [
          walletNetWorthHistoryGatewayProvider.overrideWithValue(_Week()),
        ],
      );
      await tester.pumpAndSettle();

      final trend = _key('wallet-networth-trend');
      expect(trend, findsOneWidget);
      expect(find.byType(WalletNetWorthTrend), findsOneWidget);
      expect(_key('wallet-networth-panel'), findsNothing);
      final figure = tester.getRect(_key('wallet-total-figure'));
      final pnl = tester.getTopLeft(_key('wallet-pnl'));
      final trendRect = tester.getRect(trend);

      // Open through 今日盈亏.
      await tester.tap(_key('wallet-pnl'));
      await tester.pumpAndSettle();
      expect(_key('wallet-networth-panel'), findsOneWidget);
      expect(trend, findsNothing);
      expect(find.byType(WalletNetWorthTrend), findsNothing);
      // The trend's box is an empty gap: nothing moves.
      expect(tester.getRect(_key('wallet-networth-trend-gap')), trendRect);
      expect(tester.getRect(_key('wallet-total-figure')), figure);
      expect(tester.getTopLeft(_key('wallet-pnl')), pnl);

      // Close again: the trend is back where it was.
      await tester.tap(_key('wallet-pnl'));
      await tester.pumpAndSettle();
      expect(_key('wallet-networth-panel'), findsNothing);
      expect(trend, findsOneWidget);
      expect(tester.getRect(trend), trendRect);
      expect(_key('wallet-networth-trend-gap'), findsNothing);
      expect(tester.getRect(_key('wallet-total-figure')), figure);
      expect(tester.takeException(), isNull);
    });
  }
}
