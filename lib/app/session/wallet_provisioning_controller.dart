import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

/// What this run knows about provisioning the account's embedded wallet.
enum LoopWalletProvisioningStage {
  /// Nothing has been attempted yet, so nothing can be claimed.
  idle,

  /// A creation call is in flight. Every creation entry point is disabled
  /// while this holds, so one login can never open two wallets.
  creating,

  /// Privy answered with a wallet for the current principal.
  created,

  /// The attempt did not produce a wallet. The session is untouched: this is
  /// a wallet fact, never a login one.
  failed,
}

/// The single wallet-provisioning fact the product surfaces read.
@immutable
final class LoopWalletProvisioning {
  const LoopWalletProvisioning({required this.stage, this.errorMessage});

  const LoopWalletProvisioning.idle()
    : this(stage: LoopWalletProvisioningStage.idle);

  final LoopWalletProvisioningStage stage;

  /// The provider's own sentence for a failed attempt, or `null`. It is never
  /// invented and never replaces the empty-directory explanation.
  final String? errorMessage;

  bool get isCreating => stage == LoopWalletProvisioningStage.creating;
}

/// Owns the one embedded-wallet creation path.
///
/// LOOP promises on the login page that holding a position produces mining
/// power, which requires a wallet the account did not have to ask for. So the
/// wallet is created once per verified principal right after the LOOP session
/// is established, and the wallet pages offer the same call by hand when that
/// automatic attempt did not land.
///
/// Both entry points go through [LoopSessionController.createWallet], which
/// funnels into the idempotent single-flight `createFirstEthereumWallet`.
/// There is deliberately no second creation path.
final class LoopWalletProvisioningController
    extends Notifier<LoopWalletProvisioning> {
  Future<bool>? _operation;
  String? _autoAttemptedPrincipal;

  @override
  LoopWalletProvisioning build() => const LoopWalletProvisioning.idle();

  /// The automatic attempt, made once per verified principal.
  ///
  /// It never throws and never reports a failure upwards: authentication has
  /// already succeeded, and a missing wallet may not undo it. A development
  /// preview or an unverified session is not attempted at all, because
  /// neither may open a real wallet.
  Future<void> ensureWallet() async {
    final session = ref.read(loopSessionProvider);
    final account = session.account;
    if (!session.canUseProviderBackedFeatures || account == null) return;
    // Privy already reported a wallet for this principal. Creating again
    // would be a second wallet request for an account that has one.
    if (account.wallet != null) return;

    final principal = account.privyUserId;
    if (principal.isEmpty || _autoAttemptedPrincipal == principal) return;
    _autoAttemptedPrincipal = principal;
    await createWallet();
  }

  /// The explicit attempt made from a wallet page's empty state.
  ///
  /// Returns whether a wallet now exists for the current principal. It shares
  /// the automatic attempt's single flight, so the button cannot race the
  /// login-time call.
  Future<bool> createWallet() {
    final active = _operation;
    if (active != null) return active;

    late final Future<bool> operation;
    operation = _create().whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<bool> _create() async {
    state = const LoopWalletProvisioning(
      stage: LoopWalletProvisioningStage.creating,
    );
    try {
      await ref.read(loopSessionProvider.notifier).createWallet();
    } on PrivyGatewayException catch (error) {
      _fail(error.userMessage);
      return false;
    } catch (_) {
      _fail('钱包创建没有完成，账号与登录状态没有变化，可以稍后再试。');
      return false;
    }
    if (!ref.mounted) return true;
    state = const LoopWalletProvisioning(
      stage: LoopWalletProvisioningStage.created,
    );
    // The wallet list is the server's projection of Privy, so the directory
    // this client already read is now stale. Invalidating it makes the next
    // wallet surface re-read `/v2/wallets` instead of rendering a list that
    // predates the wallet.
    ref.invalidate(walletDirectoryControllerProvider);
    return true;
  }

  void _fail(String message) {
    if (!ref.mounted) return;
    state = LoopWalletProvisioning(
      stage: LoopWalletProvisioningStage.failed,
      errorMessage: message,
    );
  }
}

final loopWalletProvisioningProvider =
    NotifierProvider<LoopWalletProvisioningController, LoopWalletProvisioning>(
      LoopWalletProvisioningController.new,
    );
