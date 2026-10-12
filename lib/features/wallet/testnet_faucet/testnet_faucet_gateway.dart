import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_models.dart';

/// Feature-facing port for the testnet faucet (client decision 0154).
///
/// It exposes no transport type and no route literal. Every failure other
/// than the cooldown and the partial grant is a [LoopChainException] carrying
/// the server's own reason code.
abstract interface class TestnetFaucetGateway {
  LoopChainGatewayMode get mode;

  Future<TestnetFaucetStatus> loadStatus({required String walletId});

  /// Asks LOOP to send the grant. One idempotency key per logical claim; it
  /// is replayed only while that claim's outcome is unresolved.
  Future<TestnetFaucetClaimResult> claim({required String walletId});
}

/// Production default: unavailable. No fixture ever stands in for a grant.
final class UnavailableTestnetFaucetGateway implements TestnetFaucetGateway {
  const UnavailableTestnetFaucetGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<TestnetFaucetStatus> loadStatus({required String walletId}) =>
      Future<Never>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );

  @override
  Future<TestnetFaucetClaimResult> claim({required String walletId}) =>
      Future<Never>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );
}

/// Overridden by the composition root with the authenticated V2 adapter.
final testnetFaucetGatewayProvider = Provider<TestnetFaucetGateway>(
  (ref) => const UnavailableTestnetFaucetGateway(),
);
