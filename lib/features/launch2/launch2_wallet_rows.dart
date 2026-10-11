import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';

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

  Widget _row({
    required String key,
    required Launch2Position position,
    required String title,
    required String subtitle,
    required String value,
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
    valueCaption: Text(
      launch2StageLabel(position.stage),
      style: LoopTypography.body(14, color: LoopColors.text2),
    ),
    onTap: () => onOpen(Launch2Route.instance(position.instanceId)),
    semanticLabel:
        '$title，$subtitle，$value，${launch2StageLabel(position.stage)}',
  );
}
