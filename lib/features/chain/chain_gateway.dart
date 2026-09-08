import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';

/// Feature-facing port for the `chain` module. It exposes no transport type,
/// no `/v2/` literal and no RPC URL.
abstract interface class ChainGateway {
  LoopChainGatewayMode get mode;

  Future<LoopChainStatus> loadStatus();

  Future<LoopChainAssetView> loadAsset(String assetId);
}

/// Production default: every call fails closed with `unavailable`. No fixture
/// ever replaces a missing chain fact.
final class UnavailableChainGateway implements ChainGateway {
  const UnavailableChainGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<LoopChainStatus> loadStatus() => Future<LoopChainStatus>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<LoopChainAssetView> loadAsset(String assetId) =>
      Future<LoopChainAssetView>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );
}

/// Overridden by the composition root with the authenticated V2 adapter.
final chainGatewayProvider = Provider<ChainGateway>(
  (ref) => const UnavailableChainGateway(),
);
