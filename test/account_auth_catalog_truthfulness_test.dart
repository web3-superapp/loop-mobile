import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';

void main() {
  test('the legacy auth catalog surfaces are retired, not re-implemented', () {
    // S2 moved every credential step onto the real Privy screens. The catalog
    // must not keep a parallel copy of them, so these ids are gone entirely.
    expect(AccountSurfaceScreen.supportedIds, const <String>{
      'splash',
      'auth-wallet',
      'wallet-create',
      'wallet-recovery',
      'security-setup',
    });
    for (final retired in const <String>[
      'onboarding',
      'auth',
      'auth-otp',
      'seed-show',
      'seed-verify',
      'wallet-import',
      'wallet-backup',
      'profile-setup',
    ]) {
      expect(
        AccountSurfaceScreen.supportedIds,
        isNot(contains(retired)),
        reason: '$retired must not come back as a catalog mock',
      );
    }
  });

  testWidgets('the legacy OTP catalog page can no longer be reached', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const AccountSurfaceScreen.fromId('auth-otp'),
      ),
    );

    // Falls through to the unknown surface rather than rendering a second,
    // local verification UI beside the real PrivyOtpScreen at `/auth/otp`.
    expect(
      find.byKey(const ValueKey<String>('unknown-account-surface')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(find.textContaining('验证码'), findsNothing);
  });
}
