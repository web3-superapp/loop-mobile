import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/review/signing_review_surface.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

void main() {
  testWidgets('Perp preview cannot invoke even an available wallet gateway', (
    tester,
  ) async {
    final gateway = _RecordingAvailableWalletGateway();
    final now = DateTime.now().toUtc();
    final intent = SigningIntent.perpOrder(
      revision: 'perp-preview',
      market: 'ETH',
      direction: OrderDirection.buy,
      orderType: PerpOrderType.market,
      size: '1.25',
      leverage: 20,
      price: '4630.50',
      margin: '289.41 USDC',
      fee: '2.89 USDC',
      builderFee: '0 USDC',
      liquidationEstimate: '4410.00',
      observedAt: now,
      expiresAt: now.add(const Duration(minutes: 1)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletSigningGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SigningReviewSurface(intent: intent),
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final action = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Backend execution unavailable'),
    );
    expect(action.onPressed, isNull);
    expect(gateway.handoffCalls, 0);
  });

  testWidgets(
    'local transfer draft cannot invoke even an available wallet gateway',
    (tester) async {
      final gateway = _RecordingAvailableWalletGateway();
      final now = DateTime.now().toUtc();
      final intent = SigningIntent.transfer(
        revision: 'local-transfer-preview',
        asset: 'ETH',
        amount: '0.1 ETH',
        recipient: '0x1111111111111111111111111111111111111111',
        network: 'Ethereum',
        fee: 'Unavailable · backend quote required',
        observedAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [walletSigningGatewayProvider.overrideWithValue(gateway)],
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SigningReviewSurface(intent: intent),
              ),
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final action = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Canonical intent required'),
      );
      expect(action.onPressed, isNull);
      expect(gateway.handoffCalls, 0);
    },
  );
}

final class _RecordingAvailableWalletGateway implements WalletSigningGateway {
  int handoffCalls = 0;

  @override
  WalletGatewayAvailability get availability =>
      WalletGatewayAvailability.available;

  @override
  String get label => 'Recording wallet';

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    handoffCalls += 1;
    return const WalletHandoffResult(accepted: true, code: 'unexpected');
  }
}
