import 'package:loop_mobile/core/intent/signing_intent.dart';

enum WalletGatewayAvailability { available, unavailable, fixtureReadOnly }

/// The outcome of one wallet handoff.
///
/// [value] is the transaction hash for a device broadcast and the
/// authorization signature for a provider-executed swap. It is present only
/// when [accepted] is true; a non-accepted handoff never carries a result and
/// never reads as success.
final class WalletHandoffResult {
  const WalletHandoffResult({
    required this.accepted,
    required this.code,
    this.value,
  });

  const WalletHandoffResult.rejected(this.code)
    : accepted = false,
      value = null;

  final bool accepted;

  /// A stable, non-provider reason string. It never carries provider detail.
  final String code;
  final String? value;
}

/// The single wallet boundary for every money action.
///
/// It accepts only a backend-canonical [SigningIntent]: the payload it hands
/// to the wallet is the object the server produced, and the digest that binds
/// it to the reviewed facts travels with it. A locally assembled preview
/// intent is refused here, not merely hidden by the UI.
abstract interface class WalletSigningGateway {
  WalletGatewayAvailability get availability;

  String get label;

  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  });
}

/// Shared admission check for every implementation.
///
/// Returns the refusal code, or `null` when the intent may reach a wallet.
String? walletHandoffRefusal(SigningIntent intent, {required DateTime now}) {
  if (intent.requiresLoopBackend) return 'loop_backend_required';
  // A local preview object has no canonical payload and no digest, so it can
  // never be signed — this is the boundary that enforces it.
  if (intent.isLocalPreview) return 'canonical_intent_required';
  if (!intent.allowsWalletHandoff) return 'canonical_intent_required';
  return intent.validateAt(now);
}
