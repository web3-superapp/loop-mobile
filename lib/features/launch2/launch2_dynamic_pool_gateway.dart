import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';

/// Feature-facing port for the LoopDynamic 外盘 Hook kind (client decision
/// 0157). No transport type, no route literal and no idempotency detail
/// crosses it; every failure is a [LoopChainException].
abstract interface class Launch2DynamicPoolGateway {
  LoopChainGatewayMode get mode;

  /// Which Hook the instance's official pool carries. A `404` or a closed
  /// capability is [Launch2OfficialTaxPool] — never a failure — so a server
  /// or an instance without LoopDynamic leaves the page as it was.
  Future<Launch2PoolKind> loadPoolKind(String instanceId);

  /// The account's reward rounds, newest first.
  Future<Launch2DynamicRewards> loadRewards(String instanceId);

  /// One round's `claim(roundId)` as a server intent (the MEME v2 shape).
  Future<Launch2Intent> prepareClaim({
    required String instanceId,
    required String walletId,
    required BigInt roundId,
  });

  /// Tells the server what the wallet broadcast for [intentId].
  Future<Launch2DynamicClaimReport> reportClaim({
    required String instanceId,
    required String walletId,
    required BigInt roundId,
    required String intentId,
    required String transactionHash,
  });
}

/// Production default: every call fails closed with `unavailable`, which
/// the page reads as OfficialTax (nothing new is drawn). No fixture ever
/// replaces a missing LoopDynamic fact.
final class UnavailableLaunch2DynamicPoolGateway
    implements Launch2DynamicPoolGateway {
  const UnavailableLaunch2DynamicPoolGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<Launch2PoolKind> loadPoolKind(String instanceId) => _unavailable();

  @override
  Future<Launch2DynamicRewards> loadRewards(String instanceId) =>
      _unavailable();

  @override
  Future<Launch2Intent> prepareClaim({
    required String instanceId,
    required String walletId,
    required BigInt roundId,
  }) => _unavailable();

  @override
  Future<Launch2DynamicClaimReport> reportClaim({
    required String instanceId,
    required String walletId,
    required BigInt roundId,
    required String intentId,
    required String transactionHash,
  }) => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final launch2DynamicPoolGatewayProvider = Provider<Launch2DynamicPoolGateway>(
  (ref) => const UnavailableLaunch2DynamicPoolGateway(),
);
