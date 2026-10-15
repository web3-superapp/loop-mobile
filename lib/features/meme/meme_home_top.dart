import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/loop_balance_visibility.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/meme/meme_best_trades.dart';
import 'package:loop_mobile/features/meme/meme_routes.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_sheet.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';

// ---------------------------------------------------------------------------
// S187-3 · MEME Tab 「首页」 top (decision 0176, design 35 首页)
// ---------------------------------------------------------------------------

/// What a masked figure prints (the same four stars as the wallet page).
const String memeMaskedFigure = '****';

/// What the figure slot prints when there is no verified total to show.
const String memeBalanceUnread = '--';

/// The balance figure and the reason it could not be drawn, if any.
typedef MemeBalanceView = ({
  String? figure,
  String? reason,
  LoopNetWorthChangeAvailable? change,
  String? quality,
  bool loading,
});

/// Projects the wallet's own read into the balance block (AGENTS rule 20 /
/// 25): only a complete `netWorth` is a total. A partial sum, an unavailable
/// one, a closed module and an absent wallet are all 「--」 with their reason,
/// never 0.
MemeBalanceView memeBalanceView({
  required bool walletClosed,
  required String? closedReason,
  required bool directoryLoading,
  required bool noWallet,
  required LoopChainResourceState<LoopWalletBalances>? balances,
}) {
  if (walletClosed) {
    return (
      figure: null,
      reason: closedReason ?? '钱包余额暂时读不到',
      change: null,
      quality: null,
      loading: false,
    );
  }
  if (noWallet) {
    return (
      figure: null,
      reason: '还没有钱包',
      change: null,
      quality: null,
      loading: false,
    );
  }
  final value = balances?.value;
  if (value == null) {
    final loading =
        directoryLoading ||
        balances == null ||
        balances.phase == LoopChainViewPhase.loading;
    return (
      figure: null,
      reason: loading
          ? null
          : '余额没有读到 · ${loopChainFailureReason(balances.failureKind)}',
      change: null,
      quality: null,
      loading: loading,
    );
  }
  return switch (value.netWorth) {
    LoopNetWorthValued(partial: true, unavailableCount: final count) => (
      figure: null,
      reason: '$count 项资产暂无价格，总资产暂不显示',
      change: null,
      quality: null,
      loading: false,
    ),
    final LoopNetWorthValued valued => (
      figure: loopFormatUsd(valued.valueUsd),
      reason: null,
      change: switch (valued.change24h) {
        final LoopNetWorthChangeAvailable change => change,
        LoopNetWorthChangeUnavailable() => null,
      },
      quality: loopFactQualityMarker(valued.quality),
      loading: false,
    ),
    LoopNetWorthUnavailable(reasonCode: final reason) => (
      figure: null,
      reason: loopReasonCodeText(reason),
      change: null,
      quality: null,
      loading: false,
    ),
  };
}

/// `+$12.08` / `-$3.10`: the signed 24h change of the total.
String memeBalanceChangeText(Decimal usd) {
  final magnitude = usd < Decimal.zero ? -usd : usd;
  final sign = usd < Decimal.zero
      ? '-'
      : usd > Decimal.zero
      ? '+'
      : '';
  return '$sign${loopFormatUsd(magnitude)}';
}

/// `.balance`: the wallet's total on the left, the one full-Lime 「充值」 on
/// the right.
class MemeBalanceBlock extends ConsumerStatefulWidget {
  const MemeBalanceBlock({required this.onNavigate, super.key});

  final void Function(String location) onNavigate;

  @override
  ConsumerState<MemeBalanceBlock> createState() => _MemeBalanceBlockState();
}

class _MemeBalanceBlockState extends ConsumerState<MemeBalanceBlock> {
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(
      walletReadGatewayProvider.select((gateway) => gateway.mode),
    );
    final preview = mode == LoopChainGatewayMode.preview;
    final walletGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.walletRead),
    );
    final bscGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.bscRead),
    );
    final closed =
        !preview &&
        (mode == LoopChainGatewayMode.unavailable ||
            !walletGate.isAvailable ||
            !bscGate.isAvailable);
    final closedReason = mode == LoopChainGatewayMode.unavailable
        ? '钱包余额暂时读不到'
        : !walletGate.isAvailable
        ? memeGateText(walletGate)
        : memeGateText(bscGate);
    final directory = ref.watch(walletDirectoryControllerProvider);
    if (!closed &&
        directory.phase == LoopChainViewPhase.loading &&
        directory.value == null) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(walletDirectoryControllerProvider.notifier).load(),
          );
        }
      });
    }
    final walletId = directory.value?.activeWalletId;
    final balances = closed || walletId == null
        ? null
        : ref.watch(walletBalancesControllerProvider(walletId));
    if (walletId != null &&
        balances != null &&
        balances.phase == LoopChainViewPhase.loading &&
        balances.value == null) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .load(),
          );
        }
      });
    }
    final noWallet =
        directory.isReady &&
        directory.value != null &&
        directory.value!.activeWalletId == null;
    final directoryFailed =
        directory.value == null &&
        directory.phase != LoopChainViewPhase.loading &&
        !directory.isReady;
    final view = memeBalanceView(
      walletClosed: closed || directoryFailed,
      closedReason: directoryFailed
          ? '钱包没有读到 · ${loopChainFailureReason(directory.failureKind)}'
          : closedReason,
      directoryLoading:
          directory.phase == LoopChainViewPhase.loading &&
          directory.value == null,
      noWallet: noWallet,
      balances: balances,
    );
    final hidden = ref.watch(
      loopBalanceVisibilityProvider.select((visibility) => visibility.hidden),
    );
    final faucetVisible =
        testnetFaucetVisible(ref) &&
        directory.value?.active?.kind == LoopWalletKind.embedded &&
        walletId != null &&
        WalletRoute.isCanonical(walletId);

    return Padding(
      key: const ValueKey<String>('meme-balance'),
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        4,
        LoopSpacing.page,
        12,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _figure(view, hidden: hidden)),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: LoopButton(
              key: const ValueKey<String>('meme-top-up'),
              label: '充值',
              primary: true,
              onPressed: () => faucetVisible
                  ? _openFaucet(walletId, directory.value?.active?.address)
                  : widget.onNavigate(
                      walletId != null && WalletRoute.isCanonical(walletId)
                          ? WalletRoute.receive(walletId)
                          : WalletRoute.receivePath,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFaucet(String walletId, String? address) => unawaited(
    showTestnetFaucetSheet(
      context,
      walletId: walletId,
      address: address,
      onGranted: () {
        if (!mounted) return;
        unawaited(
          ref
              .read(walletBalancesControllerProvider(walletId).notifier)
              .reload(),
        );
      },
    ),
  );

  Widget _figure(MemeBalanceView view, {required bool hidden}) {
    if (view.loading) {
      return const Align(
        key: ValueKey<String>('meme-balance-loading'),
        alignment: AlignmentDirectional.centerStart,
        child: LoopSkeletonBlock(width: 140, height: 30),
      );
    }
    final figure = view.figure;
    final Widget main;
    if (figure == null) {
      main = Text(
        memeBalanceUnread,
        key: const ValueKey<String>('meme-balance-figure'),
        style: LoopType.figureXl.copyWith(color: LoopColors.text3),
      );
    } else if (hidden) {
      main = Text(
        memeMaskedFigure,
        key: const ValueKey<String>('meme-balance-figure'),
        style: LoopType.figureXl,
      );
    } else {
      final dot = figure.indexOf('.');
      main = Text.rich(
        key: const ValueKey<String>('meme-balance-figure'),
        TextSpan(
          text: dot < 0 ? figure : figure.substring(0, dot),
          style: LoopTypography.withWeight(LoopType.figureXl, FontWeight.w700),
          children: <InlineSpan>[
            if (dot >= 0)
              TextSpan(
                text: figure.substring(dot),
                style: LoopType.figureLg.copyWith(color: LoopColors.text3),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final change = view.change;
    final sub = <Widget>[
      if (figure == null)
        Text(
          view.reason ?? '',
          key: const ValueKey<String>('meme-balance-reason'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: LoopType.caption.copyWith(color: LoopColors.text2),
        )
      else if (change != null)
        Text.rich(
          key: const ValueKey<String>('meme-balance-change'),
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: hidden
                    ? memeMaskedFigure
                    : memeBalanceChangeText(change.usd),
                style: LoopType.figureSm.copyWith(
                  color: hidden
                      ? LoopColors.text2
                      : LoopPriceMove.of(change.usd).color,
                ),
              ),
              TextSpan(
                text:
                    ' · 24 小时${view.quality == null ? '' : ' · ${view.quality}'}',
              ),
            ],
          ),
          style: LoopType.caption.copyWith(color: LoopColors.text2),
        )
      else if (view.quality case final String quality)
        Text(
          quality,
          style: LoopType.caption.copyWith(color: LoopColors.text2),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        main,
        if (sub.isNotEmpty) ...<Widget>[const SizedBox(height: 6), ...sub],
      ],
    );
  }
}

/// The sentence a closed wallet gate is explained with.
String memeGateText(LoopCapabilityProjection gate) {
  if (gate.isUnobserved) {
    return gate.unreachable ? '暂时连不上 LOOP，余额读不到' : '钱包状态还没有读到';
  }
  return '钱包余额暂时读不到 · ${loopReasonCodeText(gate.reasonCode)}';
}

/// 每周最佳交易: up to ten `LoopRecordCard`s scrolled sideways. Nothing at
/// all is drawn while the board is loading, empty, missing (404), closed
/// (503) or unreadable — the strip is a shortcut, never a state.
class MemeBestTradesStrip extends ConsumerWidget {
  const MemeBestTradesStrip({required this.onNavigate, super.key});

  static const double cardWidth = 170;

  final void Function(String location) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memeBestTradesControllerProvider);
    if (state.phase == LoopChainViewPhase.loading && state.value == null) {
      scheduleMicrotask(
        () => unawaited(
          ref.read(memeBestTradesControllerProvider.notifier).load(),
        ),
      );
    }
    final items = (state.value?.items ?? const <MemeBestTrade>[])
        .take(MemeBestTradesBoard.limit)
        .toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey<String>('meme-best-trades'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('每周最佳交易', tight: true),
        SingleChildScrollView(
          key: const ValueKey<String>('meme-best-trades-scroll'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final (index, trade) in items.indexed) ...<Widget>[
                if (index > 0) const SizedBox(width: 10),
                MemeBestTradeCard(
                  key: ValueKey<String>('meme-best-trade-${trade.rank}'),
                  trade: trade,
                  onOpenToken: () =>
                      onNavigate(MemeRoute.token(trade.memeTokenId)),
                  onOpenProfile: () =>
                      onNavigate(userProfileLocation(trade.publicProfileId)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// `.best`: avatar 24 + name over a Line hairline, then the token logo 26 and
/// the realised profit in Lime.
class MemeBestTradeCard extends StatelessWidget {
  const MemeBestTradeCard({
    required this.trade,
    required this.onOpenToken,
    required this.onOpenProfile,
    super.key,
  });

  final MemeBestTrade trade;
  final VoidCallback onOpenToken;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: MemeBestTradesStrip.cardWidth,
    child: Semantics(
      label:
          '${trade.displayName} 在 ${trade.symbol} 上赚了 '
          '${loopFormatUsd(trade.realizedUsd1)}',
      child: LoopRecordCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        onTap: onOpenToken,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LoopPressable(
              key: ValueKey<String>('meme-best-trade-${trade.rank}-user'),
              onTap: onOpenProfile,
              child: Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: LoopColors.line)),
                ),
                child: Row(
                  children: <Widget>[
                    LoopProfileAvatar(
                      avatarRef: trade.avatarRef,
                      alias: trade.displayName,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trade.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopTypography.label(
                          12,
                          weight: FontWeight.w700,
                          color: LoopColors.chalk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                MemeLogo(
                  symbol: trade.symbol,
                  imageUrl: trade.logoUrl,
                  identity: trade.memeTokenId,
                  size: 26,
                  // Half of 26: the design's round `.avatar`.
                  radius: LoopRadius.toolValue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '+${loopFormatUsd(trade.realizedUsd1)}',
                      key: ValueKey<String>(
                        'meme-best-trade-${trade.rank}-gain',
                      ),
                      maxLines: 1,
                      style: LoopTypography.figure(
                        15,
                        weight: FontWeight.w700,
                        height: 1,
                        color: LoopColors.lime,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// The three chalk-underlined tabs over the list: 自选 opens 行情's 自选,
/// 代币 is this list, 已毕业 is the third segment.
class MemeHomeTabs extends StatelessWidget {
  const MemeHomeTabs({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  static const List<String> labels = <String>['自选', '代币', '已毕业'];
  static const int watchlist = 0;
  static const int tokens = 1;
  static const int graduated = 2;

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: MarketTabBar(
      key: const ValueKey<String>('meme-home-tabs'),
      keyPrefix: 'meme-home-tab',
      labels: labels,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    ),
  );
}
