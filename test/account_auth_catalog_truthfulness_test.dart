import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';

void main() {
  testWidgets('legacy OTP catalog cannot authenticate locally', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const AccountSurfaceScreen.fromId('auth-otp'),
      ),
    );

    expect(find.textContaining('No code was sent'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Verify code'), findsNothing);
    expect(find.text('Resend'), findsNothing);
  });
}
