import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';

/// `POST …/dynamic-pool/claim/prepare`: the `dynamic_claim` intent and the
/// server's own simulation of the round's claim.
@immutable
final class Launch2DynamicClaimPrepared {
  const Launch2DynamicClaimPrepared({
    required this.intent,
    required this.claim,
  });

  final Launch2Intent intent;
  final Launch2DynamicClaim claim;
}

/// Feature-facing port for the LoopDynamic 外盘 Hook kind (client decisions
/// 0157 / 0159). No transport type, no route literal and no idempotency
/// detail crosses it; every failure is a [LoopChainException].
abstract interface class Launch2DynamicPoolGateway {
  LoopChainGatewayMode get mode;

  /// Which Hook the instance's official pool carries (§3.12.1: every
  /// instance answers its `hookKind`). `officialTax` and a server without
  /// the route (404) are [Launch2OfficialTaxPool]; a 503 with a LoopDynamic
  /// `reasonCode` is [Launch2LoopDynamicUnavailable].
  Future<Launch2PoolKind> loadPoolKind(String instanceId);

  /// [walletId]'s reward rounds, newest first (`walletId` is required by
  /// the route).
  Future<Launch2DynamicRewards> loadRewards({
    required String instanceId,
    required String walletId,
  });

  /// One round's `claim(roundId)` as a server intent (the MEME v2 shape).
  Future<Launch2DynamicClaimPrepared> prepareClaim({
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
  Future<Launch2DynamicRewards> loadRewards({
    required String instanceId,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2DynamicClaimPrepared> prepareClaim({
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
