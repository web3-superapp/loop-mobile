import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';

/// Feature-facing port for the S6 wallet-intent lifecycle.
///
/// Every method addresses a wallet by its opaque `walletId` and an intent by
/// its opaque `intentId`. No page ever constructs call data, a fee or a
/// signature payload: the server owns the canonical intent end to end.
abstract interface class WalletIntentsGateway {
  LoopChainGatewayMode get mode;

  /// Recipient facts for `send-to`. It stores nothing and never blocks.
  Future<LoopSendPreflight> preflightRecipient({
    required String walletId,
    required String address,
  });

  Future<LoopWalletIntent> prepareSend({
    required String walletId,
    required String assetId,
    required String amount,
    required String recipientAddress,
  });

  Future<LoopWalletIntent> prepareApproval({
    required String walletId,
    required String assetId,
    required String spenderAddress,
    required LoopAllowanceRequest allowance,
  });

  Future<LoopWalletIntent> prepareRevoke({
    required String walletId,
    required String assetId,
    required String spenderAddress,
  });

  Future<LoopWalletIntent> prepareSwap({
    required String walletId,
    required String quoteId,
    required bool confirmPriceImpact,
  });

  /// Reports the hash the device broadcast. Until this call lands the server
  /// does not know the transaction exists.
  Future<LoopWalletIntent> reportBroadcast({
    required String intentId,
    required String txHash,
  });

  /// Hands the device's authorization signature to the server, which performs
  /// exactly one provider execution. It is never retried by the client.
  Future<LoopWalletIntent> execute({
    required String intentId,
    required String authorizationSignature,
  });

  Future<LoopWalletIntent> cancel(String intentId);

  Future<LoopWalletIntent> loadIntent(String intentId);

  Future<LoopWalletIntentPage> loadIntents({String? cursor});
}

/// Feature-facing port for `POST /v2/swap/quote`.
abstract interface class SwapQuoteGateway {
  LoopChainGatewayMode get mode;

  Future<LoopSwapQuoteView> loadQuote({
    required String walletId,
    required String sourceAssetId,
    required String destinationAssetId,
    required String amount,
    int? slippageBps,
  });
}

/// Feature-facing port for the approval inventory.
abstract interface class ApprovalsGateway {
  LoopChainGatewayMode get mode;

  Future<LoopApprovalInventory> loadApprovals(String walletId);

  Future<LoopApprovalRow> loadApproval({
    required String walletId,
    required String assetId,
    required String spender,
  });
}

Future<Never> _unavailable() => Future<Never>.error(
  const LoopChainException(LoopChainFailureKind.unavailable),
);

/// Production default: fails closed. Without an assembled adapter no money
/// action is prepared, reported or executed — and no page claims otherwise.
final class UnavailableWalletIntentsGateway implements WalletIntentsGateway {
  const UnavailableWalletIntentsGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<LoopSendPreflight> preflightRecipient({
    required String walletId,
    required String address,
  }) => _unavailable();

  @override
  Future<LoopWalletIntent> prepareSend({
    required String walletId,
    required String assetId,
    required String amount,
    required String recipientAddress,
  }) => _unavailable();

  @override
  Future<LoopWalletIntent> prepareApproval({
    required String walletId,
    required String assetId,
    required String spenderAddress,
    required LoopAllowanceRequest allowance,
  }) => _unavailable();

  @override
  Future<LoopWalletIntent> prepareRevoke({
    required String walletId,
    required String assetId,
    required String spenderAddress,
  }) => _unavailable();

  @override
  Future<LoopWalletIntent> prepareSwap({
    required String walletId,
    required String quoteId,
    required bool confirmPriceImpact,
  }) => _unavailable();

  @override
  Future<LoopWalletIntent> reportBroadcast({
    required String intentId,
    required String txHash,
  }) => _unavailable();

  @override
  Future<LoopWalletIntent> execute({
    required String intentId,
    required String authorizationSignature,
  }) => _unavailable();

  @override
  Future<LoopWalletIntent> cancel(String intentId) => _unavailable();

  @override
  Future<LoopWalletIntent> loadIntent(String intentId) => _unavailable();

  @override
  Future<LoopWalletIntentPage> loadIntents({String? cursor}) => _unavailable();
}

final class UnavailableSwapQuoteGateway implements SwapQuoteGateway {
  const UnavailableSwapQuoteGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<LoopSwapQuoteView> loadQuote({
    required String walletId,
    required String sourceAssetId,
    required String destinationAssetId,
    required String amount,
    int? slippageBps,
  }) => _unavailable();
}

final class UnavailableApprovalsGateway implements ApprovalsGateway {
  const UnavailableApprovalsGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<LoopApprovalInventory> loadApprovals(String walletId) =>
      _unavailable();

  @override
  Future<LoopApprovalRow> loadApproval({
    required String walletId,
    required String assetId,
    required String spender,
  }) => _unavailable();
}

final walletIntentsGatewayProvider = Provider<WalletIntentsGateway>(
  (ref) => const UnavailableWalletIntentsGateway(),
);

final swapQuoteGatewayProvider = Provider<SwapQuoteGateway>(
  (ref) => const UnavailableSwapQuoteGateway(),
);

final approvalsGatewayProvider = Provider<ApprovalsGateway>(
  (ref) => const UnavailableApprovalsGateway(),
);
