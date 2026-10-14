import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';

/// Feature-facing port for the NFT escrow refund (client decision 0162):
/// `POST …/nft/refund/prepare` and `…/nft/refund/report`. A separate port so
/// the [Launch2Gateway] fakes and an older composition stay as they were.
/// No transport type, no route literal and no idempotency detail crosses
/// it; every failure is a [LoopChainException].
abstract interface class Launch2NftRefundGateway {
  LoopChainGatewayMode get mode;

  /// One NFT's refund as a server intent (kind `nft_refund`).
  Future<Launch2Intent> prepareRefund({
    required String instanceId,
    required String walletId,
    required String tokenId,
  });

  /// Tells the server what the wallet broadcast for [intentId].
  Future<Launch2NftRefundReport> reportRefund({
    required String instanceId,
    required String walletId,
    required String tokenId,
    required String intentId,
    required String transactionHash,
  });
}

/// Production default: every call fails closed with `unavailable`.
final class UnavailableLaunch2NftRefundGateway
    implements Launch2NftRefundGateway {
  const UnavailableLaunch2NftRefundGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<Launch2Intent> prepareRefund({
    required String instanceId,
    required String walletId,
    required String tokenId,
  }) => _unavailable();

  @override
  Future<Launch2NftRefundReport> reportRefund({
    required String instanceId,
    required String walletId,
    required String tokenId,
    required String intentId,
    required String transactionHash,
  }) => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final launch2NftRefundGatewayProvider = Provider<Launch2NftRefundGateway>(
  (ref) => const UnavailableLaunch2NftRefundGateway(),
);
