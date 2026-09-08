import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/bridge_preview_snapshot.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/trade_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_management_screens.dart';

void main() {
  testWidgets('permission Preview exposes no fake revocation action', (
    tester,
  ) async {
    await _pump(tester, const ApprovalsScreen());

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Revocation unavailable'),
    );
    expect(button.onPressed, isNull);
    _expectAllButtonStyleActionsDisabled(tester);
    expect(
      find.textContaining('balance currently held in this wallet'),
      findsNothing,
    );
    expect(
      find.textContaining('No allowance or wallet balance'),
      findsOneWidget,
    );
  });

  testWidgets('Bridge status consumes one snapshot and changes local layout', (
    tester,
  ) async {
    await _pump(
      tester,
      const BridgeStatusScreen(snapshot: BridgePreviewSnapshot.demo),
    );

    expect(
      find.text(BridgePreviewSnapshot.demo.sourceConfirmationLabel),
      findsOneWidget,
    );
    expect(find.text('Source confirmed'), findsOneWidget);
    expect(find.text('Relay processing'), findsOneWidget);
    expect(find.text('Destination pending'), findsOneWidget);
    _expectAllButtonStyleActionsDisabled(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Manual claim required'), findsOneWidget);
    expect(
      find.text(BridgePreviewSnapshot.demo.sourceConfirmationLabel),
      findsOneWidget,
    );
    expect(find.text('Source confirmed'), findsOneWidget);
    expect(find.text('Relay processing'), findsOneWidget);
    final claim = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Claim provider not connected'),
    );
    expect(claim.onPressed, isNull);
    _expectAllButtonStyleActionsDisabled(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Destination pending'), findsOneWidget);
    expect(find.text('Manual claim required'), findsNothing);
  });

  testWidgets('transaction result remains an explicit state-layout Preview', (
    tester,
  ) async {
    await _pump(tester, const TransactionResultScreen());

    expect(find.text('Pending state example'), findsOneWidget);
    expect(
      find.text('No request was sent or submitted. No pending receipt exists.'),
      findsOneWidget,
    );
    expect(find.text('Transaction'), findsOneWidget);
    expect(find.text('Not submitted'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(find.text('Success state example'), findsOneWidget);
    expect(
      find.text(
        'No transfer occurred or was submitted. No success receipt exists.',
      ),
      findsOneWidget,
    );
    expect(find.text('Not submitted'), findsOneWidget);

    await tester.tap(find.text('Failed'));
    await tester.pump();
    expect(find.text('Failure state example'), findsOneWidget);
    expect(
      find.text(
        'No request was sent or submitted. No verified failure receipt exists.',
      ),
      findsOneWidget,
    );
    expect(find.text('Not submitted'), findsOneWidget);

    await tester.tap(find.text('Unknown'));
    await tester.pump();
    expect(find.text('Unknown state example'), findsOneWidget);
    expect(
      find.text(
        'No request was sent or submitted. No reconciliation is running.',
      ),
      findsOneWidget,
    );
    expect(find.text('Not submitted'), findsOneWidget);

    final explorer = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'No transaction to inspect'),
    );
    expect(explorer.onPressed, isNull);
    expect(find.textContaining('Transfer completed'), findsNothing);
    expect(find.textContaining('Transaction confirmed'), findsNothing);
    expect(find.textContaining('submitted successfully'), findsNothing);
    expect(find.textContaining('Transaction hash'), findsNothing);
  });
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(theme: LoopTheme.dark, home: home));
  await tester.pumpAndSettle();
}

void _expectAllButtonStyleActionsDisabled(WidgetTester tester) {
  final buttons = tester.widgetList<ButtonStyleButton>(
    find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  expect(buttons, isNotEmpty);
  for (final button in buttons) {
    expect(button.onPressed, isNull);
  }
}
