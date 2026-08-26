import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/wallet/swap_preview_snapshot.dart';

void main() {
  test('one immutable demo snapshot derives every local review fact', () {
    const snapshot = SwapPreviewSnapshot.demo;
    final observedAt = DateTime.utc(2026, 8, 26, 8);
    final expiresAt = observedAt.add(const Duration(seconds: 20));

    final intent = snapshot.toLocalSigningIntent(
      revision: 'preview-revision',
      observedAt: observedAt,
      expiresAt: expiresAt,
    );

    expect(snapshot.payLabel, '0.50 ETH');
    expect(snapshot.receiveLabel, '2302.18 USDC');
    expect(snapshot.minimumReceiveLabel, '2290.66 USDC');
    expect(intent.kind, IntentKind.swap);
    expect(intent.origin, IntentOrigin.localPreview);
    expect(intent.allowsWalletHandoff, isFalse);
    expect(intent.observedAt, observedAt);
    expect(intent.expiresAt, expiresAt);
    expect(
      <String, String>{
        for (final field in intent.fields) field.label: field.value,
      },
      <String, String>{
        'You pay': snapshot.payLabel,
        'You receive': snapshot.receiveLabel,
        'Rate': snapshot.rate,
        'Provider fee': snapshot.providerFee,
      },
    );
  });
}
