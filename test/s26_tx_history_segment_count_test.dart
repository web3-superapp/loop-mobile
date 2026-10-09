import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// The transaction tape follows the segment.
///
/// Decision 0126 removed the hero that counted the rows (「1 笔」); what is
/// left to check is that a segment lists exactly what it names, and that an
/// empty one says so instead of keeping the other segment's rows.
void main() {
  testWidgets('the tape follows the segment', (tester) async {
    await pumpS5Page(
      tester,
      const TransactionHistoryScreen(walletId: s5WalletId),
      wallet: FakeWalletReadGateway(),
    );
    Finder rows() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('tx-entry-'),
    );

    // The fixture holds one incoming transfer and no outgoing one.
    expect(rows(), findsOneWidget);
    expect(find.text('1 笔'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('tx-history-seg-2')));
    await tester.pumpAndSettle();

    expect(rows(), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('tx-history-empty')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('tx-history-seg-1')));
    await tester.pumpAndSettle();

    expect(rows(), findsOneWidget);
  });
}
