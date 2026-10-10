import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';

/// What `claim/prepare` answered (decision 0140).
///
/// Two refusals are not failures of the request but a fact about the wallet:
/// it cannot pay the network fee. They come back as values so the page can
/// open the one sheet that says what to do next.
@immutable
sealed class MiningClaimPrepareResult {
  const MiningClaimPrepareResult();
}

final class MiningClaimPrepared extends MiningClaimPrepareResult {
  const MiningClaimPrepared(this.intent);

  final MiningClaimIntent intent;
}

/// `CLAIM_GAS_INSUFFICIENT`: not enough BNB, but USDT that can be swapped.
final class MiningClaimGasInsufficient extends MiningClaimPrepareResult {
  const MiningClaimGasInsufficient({this.swap, this.requiredNative});

  final MiningSuggestedSwap? swap;

  /// BNB the claim needs, whole-unit decimal string, when published.
  final String? requiredNative;
}

/// `CLAIM_NO_GAS_SOURCE`: neither BNB nor USDT.
final class MiningClaimNoGasSource extends MiningClaimPrepareResult {
  const MiningClaimNoGasSource({this.requiredNative});

  final String? requiredNative;
}

/// Feature-facing port for the hourly rewards and the claim (S138).
///
/// It exposes no transport type and no route literal. Every other failure is
/// a [LoopChainException] carrying the server's own reason code.
abstract interface class MiningRewardsGateway {
  LoopChainGatewayMode get mode;

  Future<MiningRewardsView> loadRewards();

  Future<MiningClaimPage> loadClaims({String? cursor});

  Future<MiningClaimPrepareResult> prepareClaim({required String walletId});

  /// Reports the hash the wallet broadcast. Returns the claim as the server
  /// now reads it.
  Future<MiningClaimRecord> reportClaim({
    required String claimId,
    required String txHash,
  });
}

/// Production default: unavailable. No fixture ever replaces a missing
/// reward.
final class UnavailableMiningRewardsGateway implements MiningRewardsGateway {
  const UnavailableMiningRewardsGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<MiningRewardsView> loadRewards() => _unavailable();

  @override
  Future<MiningClaimPage> loadClaims({String? cursor}) => _unavailable();

  @override
  Future<MiningClaimPrepareResult> prepareClaim({required String walletId}) =>
      _unavailable();

  @override
  Future<MiningClaimRecord> reportClaim({
    required String claimId,
    required String txHash,
  }) => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final miningRewardsGatewayProvider = Provider<MiningRewardsGateway>(
  (ref) => const UnavailableMiningRewardsGateway(),
);
