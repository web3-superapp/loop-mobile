import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// Mining, where the wallet touches it.
///
/// The prototype puts four hooks inside Wallet — the holdings hint on the
/// wallet page, the power figure on an asset row, the contribution card on the
/// asset page and the warning on send — and the visual audit (item 8) found
/// all four missing, which made Wallet and Mining read as two products.
///
/// Every hook here reads the mining snapshot the Mining module already reads.
/// It adds no request type of its own, it never computes a figure, and a
/// snapshot it could not read renders [loopFigureDash] rather than a zero: a
/// holding that produced no power and a holding whose power was not read are
/// different facts.

/// The mining summary, loaded once per surface that asks for it.
LaunchResourceState<MiningSummary> watchWalletMiningSummary(WidgetRef ref) {
  final state = ref.watch(miningSummaryControllerProvider);
  if (state.phase == LaunchViewPhase.loading) {
    scheduleMicrotask(
      () =>
          unawaited(ref.read(miningSummaryControllerProvider.notifier).load()),
    );
  }
  return state;
}

/// The per-asset mining composition, loaded once per surface that asks.
LaunchResourceState<MiningAssets> watchWalletMiningAssets(WidgetRef ref) {
  final state = ref.watch(miningAssetsControllerProvider);
  if (state.phase == LaunchViewPhase.loading) {
    scheduleMicrotask(
      () => unawaited(ref.read(miningAssetsControllerProvider.notifier).load()),
    );
  }
  return state;
}

/// One asset's row in the snapshot, or `null` when the snapshot has none.
MiningAssetRow? walletMiningRowFor(
  LaunchResourceState<MiningAssets> state,
  String assetId,
) {
  final value = state.value;
  if (value == null) return null;
  for (final row in value.included) {
    if (row.assetId == assetId) return row;
  }
  return null;
}

/// The power figure for one asset, as an asset row's secondary line states it.
///
/// A snapshot that excluded the asset says so; a snapshot that was not read
/// says nothing more than [loopFigureDash], because the reason belongs to the
/// mining page that owns the read.
String walletAssetPowerText(
  LaunchResourceState<MiningAssets> state,
  String assetId,
) {
  final value = state.value;
  if (value == null) return '算力 $loopFigureDash';
  final row = walletMiningRowFor(state, assetId);
  if (row != null) return '算力 ${loopGroupedFigure(row.power)}';
  for (final excluded in value.excluded) {
    if (excluded.assetId == assetId) return '无权重';
  }
  return '算力 $loopFigureDash';
}

/// The Lime strip the prototype puts under the wallet page's action groups.
///
/// `.power-hint` with the account's own power and today's estimate. Neither
/// figure is computed here and neither is replaced by a zero.
class WalletHoldingsPowerHint extends ConsumerWidget {
  const WalletHoldingsPowerHint({required this.onOpenMining, super.key});

  final VoidCallback onOpenMining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = watchWalletMiningSummary(ref);
    final summary = state.value;
    final power = switch (summary?.power) {
      MiningFigureValue(value: final value) => loopGroupedFigure(value),
      MiningFigureUnavailable() || null => loopFigureDash,
    };
    final daily = switch (summary?.estimatedToday) {
      MiningDailyOutputEstimate(value: final value) => loopGroupedFigure(value),
      MiningDailyOutputUnavailable() || null => loopFigureDash,
    };
    final baseline = summary != null && miningGateIsBaseline(summary.formula);
    return LoopPowerHint(
      key: const ValueKey<String>('wallet-power-hint'),
      state: power == loopFigureDash
          ? LoopPowerHintState.pending
          : LoopPowerHintState.active,
      text: '钱包持仓正在产生算力',
      figure: <String>[
        '$power 算力',
        '今日预估 $daily LOOP',
        if (baseline) miningBaselineLabel,
      ].join(' · '),
      onTap: onOpenMining,
    );
  }
}

/// The asset page's 挖矿贡献 card.
///
/// The prototype states power, weight and today's estimate on one Lime strip.
/// A snapshot that excluded this asset states that instead — an excluded
/// holding has a reason, and it is not "zero power".
class WalletAssetPowerHint extends ConsumerWidget {
  const WalletAssetPowerHint({
    required this.assetId,
    required this.onOpenMining,
    super.key,
  });

  final String assetId;
  final VoidCallback onOpenMining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = watchWalletMiningAssets(ref);
    final row = walletMiningRowFor(state, assetId);
    if (row == null) {
      return LoopPowerHint(
        key: const ValueKey<String>('wallet-asset-power-hint'),
        state: LoopPowerHintState.pending,
        text: '这个资产的挖矿贡献',
        figure: walletAssetPowerText(state, assetId),
        onTap: onOpenMining,
      );
    }
    final value = state.value;
    final baseline = value != null && miningGateIsBaseline(value.formula);
    return LoopPowerHint(
      key: const ValueKey<String>('wallet-asset-power-hint'),
      text: '这个资产的挖矿贡献',
      figure: <String>[
        '${loopGroupedFigure(row.power)} 算力',
        '权重 ${row.weight}×',
        if (baseline) miningBaselineLabel,
      ].join(' · '),
      onTap: onOpenMining,
    );
  }
}
