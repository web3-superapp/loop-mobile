import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// The transaction tape's figure counts the rows the tape is showing.
///
/// Filtering to 发出 emptied the list while the hero kept 「1 笔」, which reads
/// as a row the page lost rather than a filter that matched nothing.
void main() {
  testWidgets('the tape figure follows the segment', (tester) async {
    await pumpS5Page(
      tester,
      const TransactionHistoryScreen(walletId: s5WalletId),
      wallet: FakeWalletReadGateway(),
    );

    // The fixture holds one incoming transfer and no outgoing one.
    expect(find.text('1 笔'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('tx-history-seg-2')));
    await tester.pumpAndSettle();

    expect(find.text('0 笔'), findsOneWidget);
    expect(find.text('1 笔'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('tx-history-seg-1')));
    await tester.pumpAndSettle();

    expect(find.text('1 笔'), findsOneWidget);
  });
}
