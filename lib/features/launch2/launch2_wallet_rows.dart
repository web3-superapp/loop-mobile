import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';

/// Decision 0208 (S237b-A): the wallet's MEME v2 USD1 — the figure the
/// Launch chain block draws — out of the `me/positions` read. Every position
/// with balances read carries the same `usd1Balance` (the Hooks Factory's
/// `usd1()` at its block); the one at the highest block wins. No reading is a
/// reason, never a zero.
WalletLaunchUsd1 launch2WalletUsd1Of(
  LoopChainResourceState<Launch2Positions> state, {
  required String walletId,
}) {
  final value = state.value;
  if (value == null) {
    return switch (state.phase) {
      LoopChainViewPhase.loading => const WalletLaunchUsd1.missing(
        walletLaunchUsd1Loading,
      ),
      LoopChainViewPhase.unavailable => const WalletLaunchUsd1.missing(
        walletLaunchUsd1Closed,
      ),
      LoopChainViewPhase.ready || LoopChainViewPhase.empty =>
        const WalletLaunchUsd1.missing(walletLaunchUsd1NoReading),
      LoopChainViewPhase.error ||
      LoopChainViewPhase.offline ||
      LoopChainViewPhase.permission => const WalletLaunchUsd1.missing(
        walletLaunchUsd1Failed,
      ),
    };
  }
  Decimal? balance;
  BigInt? block;
  for (final position in value.items) {
    if (position.walletId != walletId) continue;
    final holding = position.holding;
    final usd1 = holding?.usd1Balance;
    final at = holding?.blockNumber;
    if (holding == null || !holding.balancesRead || usd1 == null) continue;
    if (block == null || (at != null && at > block)) {
      balance = usd1;
      block = at ?? block;
    }
  }
  return balance == null
      ? const WalletLaunchUsd1.missing(walletLaunchUsd1NoReading)
      : WalletLaunchUsd1.read(balance);
}

/// [launch2WalletUsd1Of] over the live positions read; a closed or blocked
/// MEME v2 surface reads nothing.
WalletLaunchUsd1 launch2WalletUsd1(WidgetRef ref, {required String walletId}) {
  if (!launch2SurfaceVisible(ref) || launch2ReadsBlocked(ref)) {
    return const WalletLaunchUsd1.missing(walletLaunchUsd1Closed);
  }
  final state = ref.watch(launch2PositionsControllerProvider);
  launch2LoadOnce(
    ref,
    state,
    () => ref.read(launch2PositionsControllerProvider.notifier).load(),
  );
  return launch2WalletUsd1Of(state, walletId: walletId);
}

/// 钱包 · 资产 · the MEME v2 rows (decision 0139): one row for an instance's
/// curve holding and one for its NFT, read from `me/positions`. Nothing else
/// in the wallet changes: no heading, no total, no net-worth share — the
/// curve figure is curve bought − sold, not a wallet balance.
///
/// Decision 0148: once the server reads the wallet's MEME balance (a
/// graduated instance, `memeBalance`), the token row is that balance —
/// 「钱包余额」 — instead of the curve figure; a balance it could not read
/// keeps the curve row as it was.
///
/// While the read runs, or when the account holds nothing, nothing is drawn;
/// a failed read is one weak line with a retry.
class Launch2WalletRows extends ConsumerWidget {
  const Launch2WalletRows({
    required this.onOpen,
    required this.hidden,
    super.key,
  });

  final void Function(String location) onOpen;

  /// The wallet's 隐藏金额.
  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!launch2SurfaceVisible(ref) || launch2ReadsBlocked(ref)) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(launch2PositionsControllerProvider);
    launch2LoadOnce(
      ref,
      state,
      () => ref.read(launch2PositionsControllerProvider.notifier).load(),
    );
    final value = state.value;
    if (value == null) {
      if (state.phase == LoopChainViewPhase.loading ||
          state.failureKind == null) {
        return const SizedBox.shrink();
      }
      return LoopInlineUnavailable(
        key: const ValueKey<String>('launch2-wallet-unavailable'),
        message: 'MEME v2 持仓暂时读不到',
        onRetry: () => unawaited(
          ref.read(launch2PositionsControllerProvider.notifier).reload(),
        ),
      );
    }
    final rows = <Widget>[
      for (final position in value.items) ...<Widget>[
        if (position.holding?.memeBalance case final Decimal balance) ...[
          if (balance > Decimal.zero)
            _row(
              key: 'launch2-wallet-meme-${position.instanceId}',
              position: position,
              title: position.ticker,
              subtitle: '钱包余额',
              value: hidden ? '****' : launch2MemeFigure(balance),
            ),
        ] else if (position.curve.net > Decimal.zero)
          _row(
            key: 'launch2-wallet-meme-${position.instanceId}',
            position: position,
            title: position.ticker,
            subtitle: 'v2 内盘持仓',
            value: hidden ? '****' : launch2MemeFigure(position.curve.net),
            // Decision 0188 (钱包 C): an internal-market holding carries
            // 买入 / 卖出, both into the instance page that trades it.
            trades: _tradesOnCurve(position.stage),
          ),
        if (position.nftHeld > 0)
          _row(
            key: 'launch2-wallet-nft-${position.instanceId}',
            position: position,
            title: '${position.ticker} NFT',
            subtitle: position.mintedTokenId == null
                ? '项目 NFT'
                : '项目 NFT #${position.mintedTokenId}',
            value: hidden ? '****' : '× ${position.nftHeld}',
            // Decision 0163: the NFT row opens 共识勋章.
            location: Launch2Route.nft(position.instanceId),
          ),
      ],
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey<String>('launch2-wallet-rows'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  /// The two rounds whose trades run on the curve.
  static bool _tradesOnCurve(Launch2Stage stage) =>
      stage == Launch2Stage.priority || stage == Launch2Stage.public;

  Widget _row({
    required String key,
    required Launch2Position position,
    required String title,
    required String subtitle,
    required String value,
    String? location,
    bool trades = false,
  }) {
    final row = _quoteRow(
      key: key,
      position: position,
      title: title,
      subtitle: subtitle,
      value: value,
      location: location,
    );
    if (!trades) return row;
    final instance = Launch2Route.instance(position.instanceId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        row,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              LoopSeg(
                key: ValueKey<String>(
                  'launch2-wallet-sell-${position.instanceId}',
                ),
                label: '卖出',
                quiet: true,
                selected: false,
                onSelected: () => onOpen(instance),
              ),
              const SizedBox(width: 8),
              LoopSeg(
                key: ValueKey<String>(
                  'launch2-wallet-buy-${position.instanceId}',
                ),
                label: '买入',
                quiet: true,
                selected: false,
                onSelected: () => onOpen(instance),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quoteRow({
    required String key,
    required Launch2Position position,
    required String title,
    required String subtitle,
    required String value,
    String? location,
  }) => LoopQuoteRow(
    tapKey: ValueKey<String>(key),
    leading: MemeLogo(
      symbol: position.ticker,
      imageUrl: position.logoUrl,
      identity: position.instanceId,
      size: memeCardLogoSize,
      radius: memeCardLogoSize / 2,
    ),
    title: title,
    subtitle: subtitle,
    value: value,
    // The quote row owns the secondary value's step (decision 0190 M21).
    valueCaption: Text(launch2StageLabel(position.stage)),
    onTap: () => onOpen(location ?? Launch2Route.instance(position.instanceId)),
    semanticLabel:
        '$title，$subtitle，$value，${launch2StageLabel(position.stage)}',
  );
}
