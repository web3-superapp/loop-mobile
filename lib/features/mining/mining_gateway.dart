import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';

/// Feature-facing port for the `mining` module. It exposes no transport type,
/// no `/v2/` literal and no idempotency detail.
abstract interface class MiningGateway {
  LaunchGatewayMode get mode;

  Future<MiningSummary> loadSummary();

  Future<MiningAssets> loadAssets();

  Future<MiningRewards> loadRewards();

  Future<MiningRank> loadRank(MiningRankScope scope);

  Future<MiningCommunity> loadCommunity(String communityId);

  Future<MiningRules> loadRules();
}

/// Production default: every call fails closed with `unavailable`. No fixture
/// ever replaces a missing mining fact.
final class UnavailableMiningGateway implements MiningGateway {
  const UnavailableMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.unavailable;

  Future<Never> _unavailable() =>
      Future<Never>.error(const LaunchException(LaunchFailureKind.unavailable));

  @override
  Future<MiningSummary> loadSummary() => _unavailable();

  @override
  Future<MiningAssets> loadAssets() => _unavailable();

  @override
  Future<MiningRewards> loadRewards() => _unavailable();

  @override
  Future<MiningRank> loadRank(MiningRankScope scope) => _unavailable();

  @override
  Future<MiningCommunity> loadCommunity(String communityId) => _unavailable();

  @override
  Future<MiningRules> loadRules() => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final miningGatewayProvider = Provider<MiningGateway>(
  (ref) => const UnavailableMiningGateway(),
);
