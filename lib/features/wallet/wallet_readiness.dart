import 'package:flutter/foundation.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';

enum WalletReadinessMode {
  preview,
  restricted,
  needsWallet,
  ready,
  invalidAddress,
}

/// A product-facing projection of the current Privy embedded-wallet state.
///
/// It deliberately exposes neither the Privy principal nor SDK objects. A
/// complete address proves only wallet identity for the current session; it
/// does not prove balances, supported deposit routes, or signing capability.
@immutable
final class WalletReadiness {
  const WalletReadiness._(this.mode, {this.ethereumAddress});

  factory WalletReadiness.fromSession(LoopSessionState session) {
    if (session.isPreview) {
      return const WalletReadiness._(WalletReadinessMode.preview);
    }
    if (!session.canUseProviderBackedFeatures || session.account == null) {
      return const WalletReadiness._(WalletReadinessMode.restricted);
    }

    final rawAddress = session.account!.wallet?.address;
    if (rawAddress == null) {
      return const WalletReadiness._(WalletReadinessMode.needsWallet);
    }
    if (!_completeEthereumAddress.hasMatch(rawAddress)) {
      return const WalletReadiness._(WalletReadinessMode.invalidAddress);
    }
    return WalletReadiness._(
      WalletReadinessMode.ready,
      ethereumAddress: rawAddress,
    );
  }

  static final RegExp _completeEthereumAddress = RegExp(r'^0x[0-9a-fA-F]{40}$');

  final WalletReadinessMode mode;
  final String? ethereumAddress;

  bool get canCreate => mode == WalletReadinessMode.needsWallet;

  bool get canCopy =>
      mode == WalletReadinessMode.ready && ethereumAddress != null;
}
