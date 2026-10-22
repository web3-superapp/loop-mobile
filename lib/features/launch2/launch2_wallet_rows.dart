import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_card.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';

/// One MEME v2 token row of the wallet's 「代币」 tab and the figure it sorts
/// by (S259 · decision 0217). MEME v2 rows carry no price, so the tab sorts
/// them by [quantity] after every valued row.
typedef Launch2WalletTokenEntry = ({Decimal quantity, Widget row});

/// What `me/positions` gives the wallet's two asset tabs (S259 · decision
/// 0217): the token rows for 「代币」, the NFT tiles for 「NFT」 (S273 · decision
/// 0232: [Launch2WalletNftTile], laid out by [Launch2NftGrid]), and the one
/// line a failed read is said with.
@immutable
final class Launch2WalletEntries {
  const Launch2WalletEntries({
    this.tokens = const <Launch2WalletTokenEntry>[],
    this.nfts = const <Widget>[],
    this.failure,
    this.loading = false,
    this.closed = false,
  });

  final List<Launch2WalletTokenEntry> tokens;
  final List<Widget> nfts;

  /// The read failed: one weak line with a retry, drawn once.
  final Widget? failure;

  /// The first read is still running.
  final bool loading;

  /// The build switch is off or the server's `launch2` is not available.
  final bool closed;
}

/// 钱包 · 资产 · the MEME v2 rows (decision 0139): one row for an instance's
/// curve holding and one for its NFT, read from `me/positions`. No total and
/// no net-worth share — the curve figure is curve bought − sold, not a
/// wallet balance.
///
/// Decision 0148: once the server reads the wallet's MEME balance (a
/// graduated instance, `memeBalance`), the token row is that balance
/// instead of the curve figure; a balance it could not read keeps the curve
/// row as it was.
///
/// S259 · decision 0217: the rows are the Launch chain's and say so in
/// their grey line; a row holding nothing is not drawn.
Launch2WalletEntries launch2WalletEntries(
  WidgetRef ref, {
  required void Function(String location) onOpen,
  required bool hidden,
}) {
  if (!launch2SurfaceVisible(ref) || launch2ReadsBlocked(ref)) {
    return const Launch2WalletEntries(closed: true);
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
      return Launch2WalletEntries(
        loading: state.phase == LoopChainViewPhase.loading,
      );
    }
    return Launch2WalletEntries(
      failure: LoopInlineUnavailable(
        key: const ValueKey<String>('launch2-wallet-unavailable'),
        message: 'MEME v2 持仓暂时读不到',
        onRetry: () => unawaited(
          ref.read(launch2PositionsControllerProvider.notifier).reload(),
        ),
      ),
    );
  }
  final rows = Launch2WalletRows(onOpen: onOpen, hidden: hidden);
  final tokens = <Launch2WalletTokenEntry>[];
  final nfts = <Widget>[];
  for (final position in value.items) {
    if (position.holding?.memeBalance case final Decimal balance) {
      if (balance > Decimal.zero) {
        tokens.add((
          quantity: balance,
          row: rows._row(
            key: 'launch2-wallet-meme-${position.instanceId}',
            position: position,
            title: position.ticker,
            subtitle: launch2WalletChainLabel,
            value: hidden ? '****' : launch2MemeFigure(balance),
          ),
        ));
      }
    } else if (position.curve.net > Decimal.zero) {
      tokens.add((
        quantity: position.curve.net,
        row: rows._row(
          key: 'launch2-wallet-meme-${position.instanceId}',
          position: position,
          title: position.ticker,
          subtitle: '$launch2WalletChainLabel · 内盘持仓',
          // Decision 0219 (需求方 10-21): no 买入 / 卖出 chips; the whole
          // row opens the instance page, where the trade happens.
          value: hidden ? '****' : launch2MemeFigure(position.curve.net),
        ),
      ));
    }
    if (position.nftHeld > 0) {
      // S273 · decision 0232: a picture card, not a 36 dp row. Decision
      // 0163: it opens 共识勋章.
      nfts.add(
        Launch2WalletNftTile(
          key: ValueKey<String>('launch2-wallet-nft-${position.instanceId}'),
          position: position,
          hidden: hidden,
          onTap: () => onOpen(Launch2Route.nft(position.instanceId)),
        ),
      );
    }
  }
  return Launch2WalletEntries(tokens: tokens, nfts: nfts);
}

/// The grey line a Launch chain row of the wallet carries (S259 · decision
/// 0217). On the testnet the Launch chain is not the main chain; on mainnet
/// both are one chain and the rows read the same.
const String launch2WalletChainLabel = 'Launch 链';

/// The MEME v2 token rows and NFT rows in one column (decision 0139), as
/// [launch2WalletEntries] reads them. The wallet page draws the two kinds
/// under its 「代币」 and 「NFT」 tabs instead (decision 0217); this widget
/// stays for a page that wants both in one place.
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
    final entries = launch2WalletEntries(ref, onOpen: onOpen, hidden: hidden);
    if (entries.failure case final Widget failure) return failure;
    final rows = <Widget>[
      for (final entry in entries.tokens) entry.row,
      if (entries.nfts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
          child: Launch2NftGrid(children: entries.nfts),
        ),
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
    // The quote row owns the secondary value's step (decision 0190 M21).
    valueCaption: Text(launch2StageLabel(position.stage)),
    onTap: () => onOpen(Launch2Route.instance(position.instanceId)),
    semanticLabel:
        '$title，$subtitle，$value，${launch2StageLabel(position.stage)}',
  );
}

/// The wallet 「NFT」 tab's tiles two to a row (S273 · decision 0232): a
/// [LoopSpacing.rowGap] gutter across and down; an odd last tile keeps its
/// column's width. Precaches the cards' default art.
class Launch2NftGrid extends StatelessWidget {
  const Launch2NftGrid({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LoopAtmoPrecache(
    paths: launch2NftCardAssets,
    child: Column(
      key: const ValueKey<String>('launch2-nft-grid'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < children.length; i += 2) ...<Widget>[
          if (i > 0) const SizedBox(height: LoopSpacing.rowGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: children[i]),
              const SizedBox(width: LoopSpacing.rowGap),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// One project NFT in the wallet (S273 · decision 0232): its
/// [Launch2NftCard], then 「T NFT」 (body1) and 「× n · stage」 (caption,
/// Text2). The whole tile opens 共识勋章 (decision 0163).
class Launch2WalletNftTile extends StatelessWidget {
  const Launch2WalletNftTile({
    required this.position,
    required this.hidden,
    required this.onTap,
    super.key,
  });

  final Launch2Position position;

  /// The wallet's 隐藏金额.
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = '${position.ticker} NFT';
    final count = hidden ? '****' : '×${position.nftHeld}';
    final line = '$count · ${launch2StageLabel(position.stage)}';
    final id = position.mintedTokenId;
    return Semantics(
      button: true,
      label: '$title${id == null ? '' : ' #$id'}，$line',
      excludeSemantics: true,
      child: LoopPressable(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Launch2NftCard(
              ticker: position.ticker,
              nftImageUrl: position.nftImageUrl,
              logoUrl: position.logoUrl,
              tokenId: id,
            ),
            const SizedBox(height: LoopSpacing.tight),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopType.body1,
            ),
            const SizedBox(height: 2),
            Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopType.caption.copyWith(color: LoopColors.text2),
            ),
          ],
        ),
      ),
    );
  }
}
