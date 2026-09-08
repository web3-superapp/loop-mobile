import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/bridge_preview_snapshot.dart';
import 'package:loop_mobile/features/wallet/trade_screens.dart';

void main() {
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
