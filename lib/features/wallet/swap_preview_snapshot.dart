import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';

/// Closed-set, labelled fixture used by the providerless Swap layout.
///
/// This object is not an executable quote. Keeping every derived field in one
/// immutable snapshot prevents the input, quote details, and review surface
/// from silently describing different drafts.
@immutable
final class SwapPreviewSnapshot {
  const SwapPreviewSnapshot._({
    required this.payAmount,
    required this.payAsset,
    required this.receiveAmount,
    required this.receiveAsset,
    required this.minimumReceiveAmount,
    required this.rate,
    required this.providerFee,
    required this.networkFee,
    required this.allFees,
    required this.priceImpact,
  });

  static const demo = SwapPreviewSnapshot._(
    payAmount: '0.50',
    payAsset: 'ETH',
    receiveAmount: '2302.18',
    receiveAsset: 'USDC',
    minimumReceiveAmount: '2290.66',
    rate: '1 ETH = 4604.36 USDC',
    providerFee: '2.30 USDC',
    networkFee: '0.00031 ETH',
    allFees: '3.73 USDC',
    priceImpact: '0.08%',
  );

  final String payAmount;
  final String payAsset;
  final String receiveAmount;
  final String receiveAsset;
  final String minimumReceiveAmount;
  final String rate;
  final String providerFee;
  final String networkFee;
  final String allFees;
  final String priceImpact;

  String get payLabel => '$payAmount $payAsset';
  String get receiveLabel => '$receiveAmount $receiveAsset';
  String get minimumReceiveLabel => '$minimumReceiveAmount $receiveAsset';

  SigningIntent toLocalSigningIntent({
    required String revision,
    required DateTime observedAt,
    required DateTime expiresAt,
  }) {
    return SigningIntent.swap(
      revision: revision,
      pay: payLabel,
      receive: receiveLabel,
      rate: rate,
      fee: providerFee,
      observedAt: observedAt,
      expiresAt: expiresAt,
    );
  }
}
