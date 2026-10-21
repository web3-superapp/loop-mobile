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
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';

/// One MEME v2 token row of the wallet's 「代币」 tab and the figure it sorts
/// by (S259 · decision 0217). MEME v2 rows carry no price, so the tab sorts
/// them by [quantity] after every valued row.
typedef Launch2WalletTokenEntry = ({Decimal quantity, Widget row});

/// What `me/positions` gives the wallet's two asset tabs (S259 · decision
/// 0217): the token rows for 「代币」, the NFT rows for 「NFT」, and the one
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
      nfts.add(
        rows._row(
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
      ...entries.nfts,
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
    String? location,
  }) => _quoteRow(
    key: key,
    position: position,
    title: title,
    subtitle: subtitle,
    value: value,
    location: location,
  );

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
