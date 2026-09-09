import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';

/// `approvals` · `GET /v2/approvals`.
///
/// A missing indexer checkpoint arrives as `indexingDelayed` and renders as
/// "unknown", never as "you have no approvals".
final class ApprovalsController
    extends LoopChainReadController<LoopApprovalInventory> {
  ApprovalsController(this.walletId);

  final String walletId;

  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(approvalsGatewayProvider.select((gateway) => gateway.mode));

  @override
  Future<LoopApprovalInventory> fetch() =>
      ref.read(approvalsGatewayProvider).loadApprovals(walletId);
}

final approvalsControllerProvider = NotifierProvider.autoDispose
    .family<
      ApprovalsController,
      LoopChainResourceState<LoopApprovalInventory>,
      String
    >(ApprovalsController.new);

/// `tx-result` · `GET /v2/wallet-intents/{intentId}`.
///
/// The page polls this until the server reaches a terminal state. `unknown`
/// keeps polling because reconciliation may still resolve it, but nothing is
/// ever resubmitted from here.
final class WalletIntentController
    extends LoopChainReadController<LoopWalletIntent> {
  WalletIntentController(this.intentId);

  final String intentId;

  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(walletIntentsGatewayProvider.select((gateway) => gateway.mode));

  @override
  Future<LoopWalletIntent> fetch() =>
      ref.read(walletIntentsGatewayProvider).loadIntent(intentId);

  /// Adopts a state the signing exit already received, so the result page does
  /// not re-read what it was just handed.
  void adopt(LoopWalletIntent intent) {
    if (intent.intentId != intentId) return;
    state = state.ready(intent);
  }

  /// True while the server has not reached a terminal state.
  bool get keepsPolling {
    final value = state.value;
    return value == null || !value.state.isTerminal;
  }
}

final walletIntentControllerProvider = NotifierProvider.autoDispose
    .family<
      WalletIntentController,
      LoopChainResourceState<LoopWalletIntent>,
      String
    >(WalletIntentController.new);

/// The composed signing exit: the intent gateway plus the one wallet boundary.
final moneyActionSignerProvider = Provider<MoneyActionSigner>((ref) {
  return MoneyActionSigner(
    intents: ref.watch(walletIntentsGatewayProvider),
    wallet: ref.watch(walletSigningGatewayProvider),
  );
});
