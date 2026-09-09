import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/v2/approvals/loop_v2_approvals_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';
import 'package:loop_mobile/integrations/backend/v2/swap/loop_v2_swap_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_wallet_intents_api.dart';

/// Shared plumbing for the three S6 money-action adapters.
///
/// The access token is supplied by [LoopAuthenticatedSession] for exactly one
/// immediate request. These adapters own no credential cache and no transport
/// retry; they own only the idempotency key of each logical write.
base mixin _LoopV2S6Adapter {
  LoopV2ClientMetadata get clientMetadata;

  LoopAuthenticatedSession get session;

  LoopV2WriteOriginSource? get originSource;

  String get clientVersion => clientMetadata.clientVersion;

  Future<T> read<T>(Future<T> Function(String accessToken) request) =>
      executeChainRequest(session, request);

  Future<LoopV2WriteOrigin?> origin() async =>
      originSource == null ? null : await originSource!.resolve();

  /// One logical operation reserves exactly one key. The key is replayed only
  /// while the outcome stays unresolved — a resolved outcome, success or
  /// terminal rejection, releases it so the next attempt is a new operation.
  Future<T> idempotent<T>(
    LoopV2CommandKeyring keyring,
    String signature,
    Future<T> Function(String accessToken, String idempotencyKey) request,
  ) async {
    final key = keyring.reserve(signature);
    try {
      final result = await executeChainRequest(
        session,
        (accessToken) => request(accessToken, key),
      );
      keyring.release(signature);
      return result;
    } on LoopChainException catch (failure) {
      if (!loopChainOutcomeIsUnresolved(failure.kind)) {
        keyring.release(signature);
      }
      rethrow;
    } catch (_) {
      keyring.release(signature);
      rethrow;
    }
  }
}

final class DioLoopV2WalletIntentsGateway
    with _LoopV2S6Adapter
    implements WalletIntentsGateway {
  DioLoopV2WalletIntentsGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
  });

  final LoopV2WalletIntentsApi _api;
  final LoopV2CommandKeyring _keyring = LoopV2CommandKeyring();

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopSendPreflight> preflightRecipient({
    required String walletId,
    required String address,
  }) => read(
    (accessToken) => _api.preflightSend(
      accessToken: accessToken,
      clientVersion: clientVersion,
      walletId: walletId,
      address: address,
    ),
  );

  @override
  Future<LoopWalletIntent> prepareSend({
    required String walletId,
    required String assetId,
    required String amount,
    required String recipientAddress,
  }) async {
    final writeOrigin = await origin();
    return idempotent(
      _keyring,
      'send:$walletId:$assetId:$amount:$recipientAddress',
      (accessToken, key) => _api.prepareSend(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        walletId: walletId,
        assetId: assetId,
        amount: amount,
        recipientAddress: recipientAddress,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LoopWalletIntent> prepareApproval({
    required String walletId,
    required String assetId,
    required String spenderAddress,
    required LoopAllowanceRequest allowance,
  }) async {
    final writeOrigin = await origin();
    final signature = switch (allowance) {
      LoopExactAllowanceRequest(amount: final amount) => 'exact:$amount',
      LoopUnlimitedAllowanceRequest() => 'unlimited',
    };
    return idempotent(
      _keyring,
      'approve:$walletId:$assetId:$spenderAddress:$signature',
      (accessToken, key) => _api.prepareApprove(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        walletId: walletId,
        assetId: assetId,
        spenderAddress: spenderAddress,
        allowance: allowance,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LoopWalletIntent> prepareRevoke({
    required String walletId,
    required String assetId,
    required String spenderAddress,
  }) async {
    final writeOrigin = await origin();
    return idempotent(
      _keyring,
      'revoke:$walletId:$assetId:$spenderAddress',
      (accessToken, key) => _api.prepareRevoke(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        walletId: walletId,
        assetId: assetId,
        spenderAddress: spenderAddress,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LoopWalletIntent> prepareSwap({
    required String walletId,
    required String quoteId,
    required bool confirmPriceImpact,
  }) async {
    final writeOrigin = await origin();
    return idempotent(
      _keyring,
      'swap:$walletId:$quoteId:$confirmPriceImpact',
      (accessToken, key) => _api.prepareSwap(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        walletId: walletId,
        quoteId: quoteId,
        confirmPriceImpact: confirmPriceImpact,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LoopWalletIntent> reportBroadcast({
    required String intentId,
    required String txHash,
  }) async {
    final writeOrigin = await origin();
    // The hash identifies the report: a repeated report of the same hash is
    // the same logical operation and must reuse its key.
    return idempotent(
      _keyring,
      'broadcast:$intentId:$txHash',
      (accessToken, key) => _api.reportBroadcast(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        intentId: intentId,
        txHash: txHash,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LoopWalletIntent> execute({
    required String intentId,
    required String authorizationSignature,
  }) async {
    final writeOrigin = await origin();
    return idempotent(
      _keyring,
      'execute:$intentId',
      (accessToken, key) => _api.execute(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        intentId: intentId,
        authorizationSignature: authorizationSignature,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LoopWalletIntent> cancel(String intentId) async {
    final writeOrigin = await origin();
    return idempotent(
      _keyring,
      'cancel:$intentId',
      (accessToken, key) => _api.cancel(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        intentId: intentId,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LoopWalletIntent> loadIntent(String intentId) => read(
    (accessToken) => _api.getIntent(
      accessToken: accessToken,
      clientVersion: clientVersion,
      intentId: intentId,
    ),
  );

  @override
  Future<LoopWalletIntentPage> loadIntents({String? cursor}) => read(
    (accessToken) => _api.listIntents(
      accessToken: accessToken,
      clientVersion: clientVersion,
      cursor: cursor,
    ),
  );
}

final class DioLoopV2SwapQuoteGateway
    with _LoopV2S6Adapter
    implements SwapQuoteGateway {
  DioLoopV2SwapQuoteGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
  });

  final LoopV2SwapApi _api;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopSwapQuoteView> loadQuote({
    required String walletId,
    required String sourceAssetId,
    required String destinationAssetId,
    required String amount,
    int? slippageBps,
  }) => read(
    (accessToken) => _api.quote(
      accessToken: accessToken,
      clientVersion: clientVersion,
      walletId: walletId,
      sourceAssetId: sourceAssetId,
      destinationAssetId: destinationAssetId,
      amount: amount,
      slippageBps: slippageBps,
    ),
  );
}

final class DioLoopV2ApprovalsGateway
    with _LoopV2S6Adapter
    implements ApprovalsGateway {
  DioLoopV2ApprovalsGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
  });

  final LoopV2ApprovalsApi _api;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopApprovalInventory> loadApprovals(String walletId) => read(
    (accessToken) => _api.getApprovals(
      accessToken: accessToken,
      clientVersion: clientVersion,
      walletId: walletId,
    ),
  );

  @override
  Future<LoopApprovalRow> loadApproval({
    required String walletId,
    required String assetId,
    required String spender,
  }) => read(
    (accessToken) => _api.getApproval(
      accessToken: accessToken,
      clientVersion: clientVersion,
      walletId: walletId,
      assetId: assetId,
      spender: spender,
    ),
  );
}
