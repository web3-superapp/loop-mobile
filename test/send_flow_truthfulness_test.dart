import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';

void main() {
  const recipient = '0x1111111111111111111111111111111111111111';

  test('transfer draft preserves the complete recipient', () {
    const selected = TransferDraft(asset: 'ETH', network: 'Ethereum');

    final completed = selected.copyWith(recipient: recipient);

    expect(completed.asset, 'ETH');
    expect(completed.network, 'Ethereum');
    expect(completed.recipient, recipient);
  });

  testWidgets('recipient screen never invents validation or screening facts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const SendRecipientScreen(
          draft: TransferDraft(asset: 'ETH', network: 'Ethereum'),
        ),
      ),
    );

    expect(find.text('Not verified · backend unavailable'), findsOneWidget);
    expect(find.text('Valid'), findsNothing);
    expect(find.text('No known match'), findsNothing);
  });

  testWidgets('confirmation shows the raw recipient and no fake simulation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const SendConfirmScreen(
          draft: TransferDraft(
            asset: 'ETH',
            network: 'Ethereum',
            recipient: recipient,
          ),
        ),
      ),
    );

    final pageScrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Provider facts unavailable'),
      300,
      scrollable: pageScrollable.first,
    );

    expect(find.text(recipient), findsOneWidget);
    expect(find.text('Provider facts unavailable'), findsOneWidget);
    expect(find.text('Simulation ready'), findsNothing);
    expect(find.text('0xA1c0…88C2'), findsNothing);
  });

  testWidgets('transaction result catalog never claims a transfer occurred', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: LoopTheme.dark, home: const TransactionResultScreen()),
    );

    expect(find.textContaining('No wallet request occurred'), findsOneWidget);
    expect(find.textContaining('wallet submitted'), findsNothing);
    expect(find.textContaining('reached 0x'), findsNothing);
    expect(find.text('Not submitted'), findsOneWidget);
  });
}
