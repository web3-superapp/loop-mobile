import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/dapp/dapp_models.dart';

/// The server side of the DApp browser (S342 · decision 0270, docs/55 §二).
///
/// Every signing request a page makes is first prepared here as a wallet
/// intent; the device signs only what came back.
abstract interface class DappIntentsGateway {
  LoopChainGatewayMode get mode;

  /// `POST /v2/wallet-intents/dapp-tx`.
  Future<DappIntent> prepareTx({
    required String walletId,
    required String chainId,
    required String origin,
    required DappTxRequest tx,
  });

  /// `POST /v2/wallet-intents/dapp-sign`.
  Future<DappIntent> prepareSign({
    required String walletId,
    required String chainId,
    required String origin,
    required DappSignRequest request,
  });

  /// `POST /v2/wallet-intents/{id}/broadcast-report`.
  Future<DappIntent> reportBroadcast({
    required String intentId,
    required String txHash,
  });

  /// `POST /v2/wallet-intents/{id}/signature-report`.
  Future<DappIntent> reportSignature({
    required String intentId,
    required String signature,
  });

  /// `POST /v2/wallet-intents/{id}/cancel`, when the owner declined.
  Future<void> cancel({required String intentId});
}

final class UnavailableDappIntentsGateway implements DappIntentsGateway {
  const UnavailableDappIntentsGateway();

  static Never _unavailable() => throw const LoopChainException(
    LoopChainFailureKind.unavailable,
    reasonCode: 'DAPP_BROWSER_RUNTIME_UNAVAILABLE',
  );

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<DappIntent> prepareTx({
    required String walletId,
    required String chainId,
    required String origin,
    required DappTxRequest tx,
  }) => _unavailable();

  @override
  Future<DappIntent> prepareSign({
    required String walletId,
    required String chainId,
    required String origin,
    required DappSignRequest request,
  }) => _unavailable();

  @override
  Future<DappIntent> reportBroadcast({
    required String intentId,
    required String txHash,
  }) => _unavailable();

  @override
  Future<DappIntent> reportSignature({
    required String intentId,
    required String signature,
  }) => _unavailable();

  @override
  Future<void> cancel({required String intentId}) => _unavailable();
}

final dappIntentsGatewayProvider = Provider<DappIntentsGateway>(
  (ref) => const UnavailableDappIntentsGateway(),
);

/// The read-only JSON-RPC channel a page's read methods go through.
///
/// One interface, two possible sources (docs/55 §二): the server's
/// `POST /v2/chain/rpc-read` allowlist, or the embedded wallet's own provider.
/// The production default is the server's; a build without it answers every
/// read with an error rather than reaching a node directly.
abstract interface class DappRpcReader {
  /// Returns the JSON-RPC `result` of [method] on [chainId].
  Future<Object?> read({
    required String chainId,
    required String method,
    required List<Object?> params,
  });
}

/// The read methods the channel serves (docs/55 §二). Anything else is
/// `4200` before it leaves the device.
const Set<String> dappReadMethods = <String>{
  'eth_blockNumber',
  'eth_call',
  'eth_getBalance',
  'eth_getCode',
  'eth_getTransactionReceipt',
  'eth_getTransactionByHash',
  'eth_estimateGas',
  'eth_gasPrice',
  'eth_getLogs',
};

final class UnavailableDappRpcReader implements DappRpcReader {
  const UnavailableDappRpcReader();

  @override
  Future<Object?> read({
    required String chainId,
    required String method,
    required List<Object?> params,
  }) => throw const LoopChainException(
    LoopChainFailureKind.unavailable,
    reasonCode: 'DAPP_RPC_READ_UNAVAILABLE',
  );
}

final dappRpcReaderProvider = Provider<DappRpcReader>(
  (ref) => const UnavailableDappRpcReader(),
);
