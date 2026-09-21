import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';

/// Mining, where 行情 touches it.
///
/// The prototype's market row reads `128,420 成员 · 0.35×` and its token card
/// carries a `Mining Weight` strip; the visual audit (2026-09-21 §G.1/§G.2,
/// and §D item 8) found both replaced by provenance copy, which made 行情 and
/// 挖矿 read as two products.
///
/// This file follows `wallet_mining_hooks.dart`: it reads the snapshot the
/// Mining module already reads, adds no request type of its own, computes no
/// figure, and omits the line entirely when the published rules carry no
/// weight for the asset. A weight LOOP could not read is never drawn as
/// `1.0×`.

/// One asset's published weight, exactly as the rules version states it.
@immutable
final class MarketMiningWeight {
  const MarketMiningWeight({required this.weight, required this.baseline});

  /// The server's own decimal string. It is never parsed into a double.
  final String weight;

  /// The version that published it calls itself a development baseline, so
  /// every surface that prints the figure prints the label beside it.
  final bool baseline;

  /// `0.35×` — the prototype's `.mining-accent` figure.
  String get label => '$weight×';
}

/// The published mining rules, loaded once per surface that asks for them.
LaunchResourceState<MiningRules> watchMarketMiningRules(WidgetRef ref) {
  final state = ref.watch(miningRulesControllerProvider);
  if (state.phase == LaunchViewPhase.loading) {
    scheduleMicrotask(
      () => unawaited(ref.read(miningRulesControllerProvider.notifier).load()),
    );
  }
  return state;
}

/// The weight the approved version publishes for [assetId], or `null`.
///
/// `null` covers every way the figure can be missing — no rules answer, no
/// approved version, or an approved version whose table does not list this
/// asset — because a row that omits the line and a row that shows a zero say
/// different things, and only the first one is true.
MarketMiningWeight? marketMiningWeightFor(
  LaunchResourceState<MiningRules> state,
  String assetId,
) {
  final approved = state.value?.approved;
  if (approved == null) return null;
  final weight = approved.assetWeights[assetId];
  if (weight == null || weight.isEmpty) return null;
  return MarketMiningWeight(
    weight: weight,
    baseline: approved.scope.isBaseline,
  );
}
