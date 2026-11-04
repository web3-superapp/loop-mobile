import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/meme/meme_design.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_chart.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_parts.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_mint.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_trade_panel.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/launch2/launch2_recent_trades.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_trade_panel.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_wallet.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_sheet.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';

/// `launch2-instance` · one MEME v2 project (archetype `record`, layout
/// `dashboard`, client decision 0139).
///
/// One page for every stage: the stage bar and its countdown on top, then the
/// stage's own content, swapped in place with one 150 ms fade when the server
/// says the stage moved — never a new page. The page counts down to the
/// server's `nextChangeAt` and re-reads; it never advances a stage itself.
///
/// - `upcoming` — 铸造开始时间 and the fixed template behind (i).
/// - `nft_sale` — 100 USD1, 我的持有 0/1, 已售 and 「购买 NFT」.
/// - `snapshot_pending` — the line illustration and the cutoff block.
/// - `priority` / `public` — the curve, the trade panel, the latest trades.
/// - `graduated` — the official pool behind (i), its figures, the in-page
///   外盘 buy / sell panel (decision 0145), the buyback.
/// - `paused` — the whole page greyed with the server's reason.
class Launch2InstanceScreen extends ConsumerStatefulWidget {
  const Launch2InstanceScreen({
    required this.instanceId,
    super.key,
    this.onBack,
    this.onNavigate,
  });

  final String? instanceId;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<Launch2InstanceScreen> createState() =>
      _Launch2InstanceScreenState();
}

/// What the page says about our own last write, until the read model shows
/// it.
@immutable
final class _Pending {
  const _Pending({
    required this.kind,
    required this.text,
    required this.locked,
    required this.baseline,
    this.venue = Launch2Venue.curve,
  });

  final Launch2IntentKind kind;
  final Launch2Venue venue;
  final String text;

  /// A broadcast is settling: no second signature until the lane shows it.
  final bool locked;

  /// What the viewer block read before the write.
  final String baseline;
}

/// What moves when our own write lands: the viewer's curve figures, and
/// after graduation the wallet's own attributed pool trades (decision 0148:
/// `viewer.poolTradeCount` / `lastPoolTradeAt`, loop-api S150). A server
/// without them leaves the pool's whole swap count (decision 0145), a
/// signal any swap moves.
String _viewerSignature(Launch2InstanceDetail detail) {
  final viewer = detail.viewer;
  final curve = viewer == null
      ? '-'
      : '${viewer.nftHeld}:${viewer.curve.bought}:${viewer.curve.sold}';
  final own = viewer?.holding;
  if (own != null) {
    return '$curve|own:${own.poolTradeCount}:'
        '${own.lastPoolTradeAt?.toIso8601String() ?? '-'}';
  }
  return '$curve|pool:${detail.pool?.tradeCount ?? '-'}';
}

/// Whether [detail] carries the wallet's own pool count (decision 0148).
bool _ownPoolSignal(Launch2InstanceDetail detail) =>
    detail.viewer?.holding != null;

/// USD1 is an 18-decimal token; `launchChain.usd1.balance` is base units.
const int _launchUsd1Decimals = 18;

class _Launch2InstanceScreenState extends ConsumerState<Launch2InstanceScreen> {
  Timer? _poll;
  _Pending? _pending;

  /// Our own last action's refusal (decision 0153): said in the body and
  /// right above the button that started it.
  Launch2ActionFailure? _actionFailure;
  bool _preparingNft = false;

  /// Decision 0240: the chosen tab and the 成交 tab's 「只看我的」.
  Launch2InstanceTab _tab = Launch2InstanceTab.trades;
  bool _mineOnly = false;
  int _settleReads = 0;

  /// How many re-reads a broadcast waits for before the page stops holding
  /// the next signature back.
  static const int _settleLimit = 36;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    unawaited(context.push(location));
  }

  Future<void> _reload(String id) async {
    final detail = ref.read(launch2InstanceControllerProvider(id)).value;
    await Future.wait(<Future<void>>[
      ref.read(launch2InstanceControllerProvider(id).notifier).reload(),
      if (detail?.stage == Launch2Stage.graduated)
        ref.read(launch2BuybacksControllerProvider(id).notifier).reload(),
      if (detail?.stage == Launch2Stage.graduated) _reloadPoolKind(id),
      if (detail?.stage == Launch2Stage.graduated) _reloadRecentTrades(id),
      if (detail?.viewer != null) _reloadPositions(),
    ]);
  }

  /// Decision 0240: the 成交 tab's public list, when it was asked for.
  Future<void> _reloadRecentTrades(String id) {
    final provider = launch2RecentPoolTradesControllerProvider(id);
    final state = ref.read(provider);
    if (state.mode == LoopChainGatewayMode.unavailable ||
        (state.phase == LoopChainViewPhase.loading && state.value == null)) {
      return Future<void>.value();
    }
    return ref.read(provider.notifier).reload();
  }

  /// Decision 0240: the holding strip's valuation, when it was asked for.
  Future<void> _reloadPositions() {
    final state = ref.read(launch2PositionsControllerProvider);
    if (state.mode == LoopChainGatewayMode.unavailable ||
        (state.phase == LoopChainViewPhase.loading && state.value == null)) {
      return Future<void>.value();
    }
    return ref.read(launch2PositionsControllerProvider.notifier).reload();
  }

  /// Decision 0157: the round moves with every swap, so a LoopDynamic
  /// instance (or one whose kind could not be read yet) is asked again with
  /// the page. An OfficialTax answer is final and never asked again.
  Future<void> _reloadPoolKind(String id) {
    final provider = launch2PoolKindControllerProvider(id);
    final state = ref.read(provider);
    if (state.mode == LoopChainGatewayMode.unavailable ||
        state.value is Launch2OfficialTaxPool) {
      return Future<void>.value();
    }
    return ref.read(provider.notifier).reload();
  }

  void _armPoll(String id, Launch2InstanceDetail detail) {
    // A terminal stage never moves again: nothing to poll for.
    if (_poll != null || detail.stage.terminal) return;
    final polling = ref.read(launch2PollingProvider);
    final fast = detail.stage.tradable || _pending != null;
    _poll = Timer(polling.intervalFor(detail.stage, fast: fast), () {
      _poll = null;
      if (!mounted) return;
      unawaited(
        ref.read(launch2InstanceControllerProvider(id).notifier).reload(),
      );
    });
  }

  void _settle(Launch2InstanceDetail detail) {
    final pending = _pending;
    if (pending == null) return;
    if (_viewerSignature(detail) != pending.baseline) {
      unawaited(_reloadPositions());
      final noun = launch2IntentNoun(pending.kind);
      setState(() {
        _pending = _Pending(
          kind: pending.kind,
          venue: pending.venue,
          text: pending.venue != Launch2Venue.officialPool
              ? LoopL10n.current.launch2_launch2InstanceText(noun)
              : _ownPoolSignal(detail)
              ? LoopL10n.current.launch2_launch2InstanceText2(noun)
              : LoopL10n.current.launch2_launch2InstanceText3(noun),
          locked: false,
          baseline: _viewerSignature(detail),
        );
        _settleReads = 0;
      });
      return;
    }
    _settleReads += 1;
    if (pending.locked && _settleReads >= _settleLimit) {
      setState(() {
        _pending = _Pending(
          kind: pending.kind,
          venue: pending.venue,
          text: LoopL10n.current.launch2_launch2InstanceText4(
            launch2IntentNoun(pending.kind),
          ),
          locked: false,
          baseline: pending.baseline,
        );
      });
    }
  }

  /// Hands one prepared intent to the signing exit and records what it
  /// answered; `true` when the wallet broadcast it.
  Future<bool> _sign(
    Launch2InstanceDetail detail,
    Launch2Intent intent, {
    Launch2IntentRefresher? refresh,
  }) async {
    final wallet = memeReadActiveWallet(ref);
    final outcome = await showLaunch2SignSheet(
      context,
      intent: intent,
      signer: ref.read(launch2IntentSignerProvider),
      fromAddress: wallet.address,
      ticker: detail.row.ticker,
      clock: ref.read(launch2ClockProvider),
      refresh: refresh,
      confirmation: launch2ReadModelConfirmation(ref, detail, intent),
    );
    if (!mounted || outcome == null) return false;
    _record(detail, intent, outcome);
    return outcome.broadcast;
  }

  /// What the signing exit answered for [intent], held until the read model
  /// shows it; a broadcast re-reads at once.
  void _record(
    Launch2InstanceDetail detail,
    Launch2Intent intent,
    Launch2SignOutcome outcome,
  ) {
    setState(() {
      _settleReads = 0;
      _pending = _Pending(
        kind: intent.kind,
        venue: intent.venue,
        text: launch2OutcomeText(outcome, intent.kind),
        locked: outcome.broadcast,
        baseline: _viewerSignature(detail),
      );
    });
    if (outcome.broadcast) {
      _poll?.cancel();
      _poll = null;
      // Decision 0203: the signing sheet may already have watched the read
      // show it; settle on what is on screen before asking again.
      final shown = ref
          .read(launch2InstanceControllerProvider(detail.instanceId))
          .value;
      if (shown != null) _settle(shown);
      unawaited(
        ref
            .read(launch2InstanceControllerProvider(detail.instanceId).notifier)
            .reload(),
      );
    }
  }

  /// 「购买 NFT」 (decision 0163: the trip is [launch2MintNft], shared with
  /// 共识勋章).
  Future<void> _buyNft(Launch2InstanceDetail detail) async {
    final result = await launch2MintNft(
      context,
      ref,
      detail,
      onPreparing: () {
        if (!mounted) return;
        setState(() {
          _preparingNft = true;
          _actionFailure = null;
        });
      },
      onPrepared: () {
        if (mounted) setState(() => _preparingNft = false);
      },
    );
    if (!mounted) return;
    switch (result) {
      case Launch2NftMintCancelled():
        return;
      case Launch2NftMintRefused(:final failure):
        setState(() {
          _preparingNft = false;
          _actionFailure = failure;
        });
      case Launch2NftMintSigned(:final intent, :final outcome):
        _record(detail, intent, outcome);
    }
  }

  /// 「去充值」: the wallet's own receive page (`receive`), for the active
  /// wallet when it has a canonical id.
  void _openTopUp(Launch2InstanceDetail detail) {
    final walletId =
        memeReadActiveWallet(ref).walletId ?? detail.viewer?.walletId;
    _open(
      walletId != null && WalletRoute.isCanonical(walletId)
          ? WalletRoute.receive(walletId)
          : WalletRoute.receivePath,
    );
  }

  /// 「领取测试币」 (decision 0154): the faucet sheet for the active wallet,
  /// offered only while the server publishes `testnetFaucet` as available and
  /// the wallet has a canonical id. A grant re-reads this project too, so the
  /// balance figures it shows follow.
  VoidCallback? _faucetAction(Launch2InstanceDetail detail) {
    if (!testnetFaucetVisible(ref)) return null;
    final active = memeReadActiveWallet(ref);
    final walletId = active.walletId ?? detail.viewer?.walletId;
    if (walletId == null || !WalletRoute.isCanonical(walletId)) return null;
    return () => unawaited(
      showTestnetFaucetSheet(
        context,
        walletId: walletId,
        address: active.address,
        onGranted: () {
          unawaited(
            ref
                .read(
                  launch2InstanceControllerProvider(detail.instanceId).notifier,
                )
                .reload(),
          );
          // Decision 0225: the curve panel's zero-balance line reads the
          // wallet balances; the grant re-reads them so the line lifts.
          unawaited(
            ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .reload(),
          );
        },
      ),
    );
  }

  /// The wallet the balances were last asked for on this page.
  String? _balancesAskedFor;

  /// Decision 0225: what the curve panel knows of the wallet's USD1 and of
  /// this token, or `null` for each figure not read. The detail's own
  /// holding (read at one block) comes first; on the curve the server
  /// leaves it `not_graduated`, so USD1 falls back to the wallet balances'
  /// Launch slot (`launchChain.usd1`, the Hooks Factory USD1 since loop-api
  /// S246) for this instance's chain. The balances are re-read once per
  /// page, and a figure that is restored, refreshing or for another chain
  /// counts as not read — a stale zero must not stop a quote.
  (Decimal?, Decimal?) _curveBalances(
    WidgetRef r,
    Launch2InstanceDetail detail,
    String? walletId,
  ) {
    final holding = detail.viewer?.holding;
    if (holding != null &&
        holding.balancesRead &&
        detail.viewer?.walletId == walletId) {
      return (holding.usd1Balance, holding.memeBalance);
    }
    if (walletId == null || !WalletRoute.isCanonical(walletId)) {
      return (null, null);
    }
    final provider = walletBalancesControllerProvider(walletId);
    final balances = r.watch(provider);
    if (_balancesAskedFor != walletId &&
        balances.mode != LoopChainGatewayMode.unavailable) {
      _balancesAskedFor = walletId;
      scheduleMicrotask(() {
        if (mounted) unawaited(r.read(provider.notifier).reload());
      });
      return (null, null);
    }
    final slot = balances.value?.launchChain;
    final usd1 = slot?.usd1;
    if (!balances.isReady ||
        balances.refreshing ||
        r.read(provider.notifier).restoredObservedAt != null ||
        slot == null ||
        slot.chainId != detail.row.chainId ||
        usd1 == null) {
      return (null, null);
    }
    final units = Decimal.tryParse(usd1.balance);
    if (units == null) return (null, null);
    return (
      (units / Decimal.ten.pow(_launchUsd1Decimals).toDecimal()).toDecimal(
        scaleOnInfinitePrecision: _launchUsd1Decimals,
      ),
      null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.instanceId;
    if (!Launch2Route.isInstanceId(id)) {
      return LoopFocusPage(
        key: const ValueKey<String>('launch2-invalid-route'),
        archetype: LoopPageArchetype.record,
        title: context.l10n.launch2_launch2InstanceLaunch2InvalidRouteTitle,
        onBack: widget.onBack,
        body: <Widget>[
          LoopEmptyState(
            key: ValueKey<String>('launch2-invalid-identity'),
            illustration: LoopIllustration.launchpad,
            title: context
                .l10n
                .launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidIdentityTitle,
            message: context
                .l10n
                .launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidIdentityMessage,
            compact: true,
          ),
        ],
      );
    }
    final instanceId = id!;
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch2),
    );
    final blocked = launch2ReadsBlocked(ref);
    final provider = launch2InstanceControllerProvider(instanceId);
    final state = blocked ? null : ref.watch(provider);
    if (state != null) {
      launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
    }
    ref.listen<LoopChainResourceState<Launch2InstanceDetail>>(provider, (
      previous,
      next,
    ) {
      final value = next.value;
      if (value != null && !identical(previous?.value, value)) {
        _settle(value);
        if (previous?.value != null && value.stage == Launch2Stage.graduated) {
          unawaited(_reloadPoolKind(instanceId));
          // Decision 0240: a new swap in the pool re-reads the 成交 list.
          final before = previous?.value?.pool?.tradeCount;
          final after = value.pool?.tradeCount;
          if (before != null && after != null && before != after) {
            unawaited(_reloadRecentTrades(instanceId));
          }
        }
      }
    });
    final detail = state?.value;
    if (detail != null) {
      _armPoll(instanceId, detail);
      // The wallet that signs is read before anything is offered, so the
      // signing exit can compare it with the transaction's `from`.
      if (detail.stage == Launch2Stage.nftSale ||
          detail.stage.tradable ||
          detail.stage == Launch2Stage.graduated) {
        memeActiveWallet(ref);
      }
    }
    final paused = detail?.stage == Launch2Stage.paused;
    final pool = detail == null ? null : _poolOf(ref, detail);
    return LoopDashboardPage(
      key: ValueKey<String>('launch2-instance-$instanceId'),
      archetype: LoopPageArchetype.record,
      title: detail == null ? 'MEME v2' : loopTickerLabel(detail.row.ticker),
      onBack: widget.onBack,
      updating: state?.refreshing ?? false,
      onRefresh: blocked ? null : () => _reload(instanceId),
      block: blocked
          ? LoopPageBlock(
              key: const ValueKey<String>('launch2-instance-blocked'),
              title: context
                  .l10n
                  .launch2_launch2DynamicRewardsLaunch2DynRewardsBlockedTitle,
              message: launch2CapabilityText(capability),
            )
          : null,
      bottomBar: detail == null || paused ? null : _bottomBar(detail, pool!),
      sections: <Widget>[
        if (state == null || detail == null)
          LoopChainStateBlock(
            keyPrefix: 'launch2-instance',
            phase: state?.phase ?? LoopChainViewPhase.unavailable,
            failureKind: state?.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: context.l10n.launch2_launch2FormatSwitch24,
            onRetry: () => unawaited(ref.read(provider.notifier).reload()),
          )
        else
          ..._sections(detail, capability, pool!),
      ],
    );
  }

  /// Decision 0157: only a graduated pool has a Hook kind; the read is not
  /// made for any other stage, and `null` (OfficialTax, unknown, absent
  /// adapter) draws the S146 page unchanged. Decision 0159: a LoopDynamic
  /// Hook that cannot be read now never falls back to the OfficialTax panel.
  _PoolKind _poolOf(WidgetRef r, Launch2InstanceDetail detail) {
    if (detail.stage != Launch2Stage.graduated) return const _PoolKind();
    final kind = launch2PoolKindOf(r, detail.instanceId);
    return _PoolKind(
      dynamicPool: kind is Launch2LoopDynamicPool ? kind.state : null,
      blocked: switch (kind) {
        Launch2LoopDynamicUnavailable(:final reasonCode) =>
          launch2PoolReasonText(reasonCode),
        Launch2LoopDynamicNotGraduated() =>
          LoopL10n.current.launch2_launch2DynamicRewardsReason,
        _ => null,
      },
    );
  }

  /// Decision 0240: the fixed 买入 / 卖出 bar on the curve and after
  /// graduation, 「铸造勋章」 while the NFT sells (unchanged).
  Widget? _bottomBar(Launch2InstanceDetail detail, _PoolKind pool) {
    switch (detail.stage) {
      case Launch2Stage.nftSale:
        final held = (detail.viewer?.nftHeld ?? 0) > 0;
        final hold = detail.tradingHold;
        final busy =
            _preparingNft || (_pending?.locked ?? false) || hold != null;
        final failure = held || _preparingNft || hold != null
            ? null
            : _actionFailure;
        return Launch2BarShell(
          failure: hold != null && !held
              ? Launch2TradingHoldLine(
                  key: const ValueKey<String>('launch2-bar-hold'),
                  hold: hold,
                  padding: EdgeInsets.zero,
                )
              : failure == null
              ? null
              : Launch2ActionFailureLine(
                  key: const ValueKey<String>('launch2-bar-failure'),
                  message: failure.text,
                  topUpKey: const ValueKey<String>('launch2-bar-topup'),
                  onTopUp: failure.topUp ? () => _openTopUp(detail) : null,
                  faucetKey: const ValueKey<String>('launch2-bar-faucet'),
                  onFaucet: _faucetAction(detail),
                ),
          child: LoopButton(
            key: const ValueKey<String>('launch2-buy-nft'),
            label: held
                ? LoopL10n.current.launch2_launch2InstanceLaunch2BuyNftLabel
                : _preparingNft
                ? LoopL10n.current.launch2_launch2DynamicRewardsLabel
                : LoopL10n.current.launch2_launch2InstanceLaunch2BuyNftLabel2,
            primary: true,
            block: true,
            onPressed: held || busy ? null : () => unawaited(_buyNft(detail)),
          ),
        );
      case Launch2Stage.priority:
      case Launch2Stage.public:
      case Launch2Stage.graduated:
        final hold = detail.tradingHold;
        final reason = (_pending?.locked ?? false)
            ? LoopL10n.current.launch2_launch2InstanceSwitch
            : pool.blocked;
        final sellReason = detail.stage == Launch2Stage.priority
            ? LoopL10n.current.launch2_launch2FormatSwitch26
            : null;
        final open = hold == null && reason == null;
        return Launch2BarShell(
          failure: hold != null
              ? Launch2TradingHoldLine(
                  key: const ValueKey<String>('launch2-bar-hold'),
                  hold: hold,
                  padding: EdgeInsets.zero,
                )
              : reason != null
              ? LoopInlineUnavailable(
                  key: const ValueKey<String>('launch2-bar-reason'),
                  icon: (_pending?.locked ?? false) ? 'clock' : 'warn',
                  message: reason,
                  padding: EdgeInsets.zero,
                )
              : sellReason != null
              ? LoopInlineUnavailable(
                  key: const ValueKey<String>('launch2-bar-sell-reason'),
                  icon: 'info',
                  message: sellReason,
                  padding: EdgeInsets.zero,
                )
              : null,
          child: Launch2TradeKeys(
            onBuy: open
                ? () => unawaited(_openTrade(detail, Launch2Side.buy))
                : null,
            onSell: open && sellReason == null
                ? () => unawaited(_openTrade(detail, Launch2Side.sell))
                : null,
          ),
        );
      case Launch2Stage.upcoming:
      case Launch2Stage.snapshotPending:
      case Launch2Stage.closedNoHolders:
      case Launch2Stage.paused:
        return null;
    }
  }

  /// Decision 0240: the stage's trade panel in a bottom sheet over the page.
  /// The sheet reads the project itself, so the panel follows every re-read;
  /// it closes when the stage moves under it or our broadcast is recorded.
  Future<void> _openTrade(Launch2InstanceDetail opened, Launch2Side side) {
    final id = opened.instanceId;
    final stage = opened.stage;
    return showLoopSheet<void>(
      context,
      barrierLabel:
          LoopL10n.current.launch2_launch2InstanceLaunch2TradeSheetBarrierLabel,
      builder: (sheet) => Consumer(
        builder: (context, r, _) {
          final live =
              r.watch(launch2InstanceControllerProvider(id)).value ?? opened;
          if (live.stage != stage) {
            scheduleMicrotask(() {
              if (sheet.mounted) Navigator.of(sheet).maybePop();
            });
            return const SizedBox.shrink();
          }
          void signed(bool broadcast) {
            if (broadcast && sheet.mounted) Navigator.of(sheet).maybePop();
          }

          final Widget panel;
          if (stage == Launch2Stage.graduated) {
            final pool = _poolOf(r, live);
            panel = pool.blocked != null
                ? Launch2DynamicUnavailableBlock(
                    reason: pool.blocked!,
                    onRetry: () => unawaited(_reloadPoolKind(id)),
                  )
                : Launch2PoolTradePanel(
                    key: ValueKey<String>('launch2-pool-panel-$id'),
                    detail: live,
                    walletId:
                        memeReadActiveWallet(r).walletId ??
                        live.viewer?.walletId,
                    locked: _pending?.locked ?? false,
                    initialSide: side,
                    onPrepared: (intent, refresh) async =>
                        signed(await _sign(live, intent, refresh: refresh)),
                    onTopUp: () => _openTopUp(live),
                    onFaucet: _faucetAction(live),
                    dynamicPool: pool.dynamicPool,
                  );
          } else {
            panel = _curvePanel(r, live, side, signed);
          }
          return Launch2DragUnfocus(
            child: Column(
              key: const ValueKey<String>('launch2-trade-sheet'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // The panel carries its own heading (外盘交易 / 公开内盘).
                panel,
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sections(
    Launch2InstanceDetail detail,
    LoopCapabilityProjection capability,
    _PoolKind pool,
  ) {
    final pending = _pending;
    final paused = detail.stage == Launch2Stage.paused;
    final body = <Widget>[
      Launch2InstanceHead(
        detail: detail,
        onCopy: () => unawaited(
          LoopCopy.text(
            context,
            detail.row.memeAddress,
            message: LoopL10n.current.launch2_launch2InstanceMessage,
          ),
        ),
        onElapsed: () => unawaited(
          ref
              .read(
                launch2InstanceControllerProvider(detail.instanceId).notifier,
              )
              .reload(),
        ),
      ),
      // Decision 0240 §7: what the page says about trading stays above the
      // price area, never inside a tab.
      // Decision 0161: the chain guard's hold, above every trade panel.
      if (detail.tradingHold case final Launch2TradingHold hold)
        Launch2TradingHoldBanner(hold: hold),
      if (launch2EvidenceNoticeShown(capability) && !paused)
        LoopInlineUnavailable(
          key: ValueKey<String>('launch2-evidence-pending'),
          icon: 'info',
          message: LoopL10n
              .current
              .launch2_launch2InstanceLaunch2EvidencePendingMessage,
        ),
      if (pending != null)
        LoopNotice(
          key: const ValueKey<String>('launch2-pending'),
          icon: pending.locked ? 'clock' : 'info',
          body: pending.text,
        ),
      if (_actionFailure case final Launch2ActionFailure failure)
        LoopInlineUnavailable(
          key: const ValueKey<String>('launch2-action-failed'),
          icon: 'warn',
          message: failure.text,
        ),
      if (detail.stage == Launch2Stage.public &&
          detail.snapshot.openedWithoutHolders != null)
        LoopNotice(
          key: ValueKey<String>('launch2-opened-without-holders'),
          icon: 'info',
          // Decision 0149: one line at 360–412 dp (「卖。」 was left alone on a
          // second line); 「人人可买」 is already the stage bar's line.
          body: LoopL10n.current
              .launch2_launch2InstanceLaunch2OpenedWithoutHoldersBody(
                launch2OpenedWithoutHoldersText,
              ),
        ),
      AnimatedSwitcher(
        duration: LoopMotion.of(context, LoopMotion.stageSwitch),
        switchInCurve: LoopMotion.contentFadeCurve,
        // The old stage leaves at once; only the new one fades in.
        switchOutCurve: const Threshold(0),
        layoutBuilder: (current, previous) =>
            current ?? const SizedBox.shrink(),
        child: KeyedSubtree(
          key: ValueKey<String>('launch2-stage-${detail.stage.wireName}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _stageWidgets(detail, pool),
          ),
        ),
      ),
    ];
    final owner = detail.viewerIsProjectOwner
        ? <Widget>[const _OwnerStrip()]
        : const <Widget>[];
    if (!paused) return <Widget>[...owner, ...body];
    // Integrity hold: the reason on top, everything else grey and inert.
    return <Widget>[
      ...owner,
      LoopNotice(
        key: const ValueKey<String>('launch2-paused-reason'),
        icon: 'warn',
        tone: LoopNoticeTone.warn,
        title: LoopL10n.current.launch2_launch2FormatSwitch29,
        body: launch2HoldReasonText(detail.row.holdReason),
      ),
      Launch2Greyed(
        key: const ValueKey<String>('launch2-paused-body'),
        greyed: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: body,
        ),
      ),
    ];
  }

  /// 提前购 / 公开内盘's panel with what is known of the wallet's balances
  /// (decision 0225).
  Widget _curvePanel(
    WidgetRef r,
    Launch2InstanceDetail detail,
    Launch2Side side,
    void Function(bool broadcast) signed,
  ) {
    final curveWalletId =
        memeReadActiveWallet(r).walletId ?? detail.viewer?.walletId;
    final curveBalances = _curveBalances(r, detail, curveWalletId);
    return Launch2TradePanel(
      key: ValueKey<String>('launch2-panel-${detail.instanceId}'),
      detail: detail,
      walletId: curveWalletId,
      locked: _pending?.locked ?? false,
      initialSide: side,
      onPrepared: (intent) async => signed(await _sign(detail, intent)),
      onTopUp: () => _openTopUp(detail),
      onFaucet: _faucetAction(detail),
      usd1Balance: curveBalances.$1,
      memeBalance: curveBalances.$2,
      onStageMoved: () => unawaited(
        ref
            .read(launch2InstanceControllerProvider(detail.instanceId).notifier)
            .reload(),
      ),
    );
  }

  /// The tabs [detail]'s stage offers (decision 0240): 成交 / 信息 from the
  /// NFT sale on, and 回购 after graduation (every graduated v2 project has
  /// its buyback escrow; no other stage has a buyback).
  static List<Launch2InstanceTab> _tabsFor(Launch2Stage stage) =>
      switch (stage) {
        Launch2Stage.graduated => Launch2InstanceTab.values,
        Launch2Stage.nftSale ||
        Launch2Stage.priority ||
        Launch2Stage.public => const <Launch2InstanceTab>[
          Launch2InstanceTab.trades,
          Launch2InstanceTab.info,
        ],
        Launch2Stage.upcoming ||
        Launch2Stage.snapshotPending ||
        Launch2Stage.closedNoHolders ||
        Launch2Stage.paused => const <Launch2InstanceTab>[],
      };

  /// The tab bar and the chosen tab's blocks.
  List<Widget> _tabbed(
    Launch2InstanceDetail detail,
    Map<Launch2InstanceTab, List<Widget>> content,
  ) {
    final tabs = _tabsFor(detail.stage);
    final chosen = tabs.contains(_tab) ? _tab : Launch2InstanceTab.trades;
    return <Widget>[
      Launch2InstanceTabs(
        tabs: tabs,
        selected: chosen,
        onSelected: (tab) => setState(() => _tab = tab),
      ),
      KeyedSubtree(
        key: ValueKey<String>('launch2-tab-body-${chosen.name}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: content[chosen] ?? const <Widget>[],
        ),
      ),
    ];
  }

  /// The wallet's position row for this project from `me/positions`
  /// (decision 0240: the valuation and, until the viewer carries it, the
  /// cost basis), or `null` while not read.
  Launch2Position? _positionFor(Launch2InstanceDetail detail) {
    final viewer = detail.viewer;
    if (viewer == null) return null;
    final provider = launch2PositionsControllerProvider;
    final state = ref.watch(provider);
    if (state.mode == LoopChainGatewayMode.unavailable) return null;
    launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
    for (final position in state.value?.items ?? const <Launch2Position>[]) {
      if (position.instanceId == detail.instanceId &&
          position.walletId == viewer.walletId) {
        return position;
      }
    }
    return null;
  }

  /// 我的持仓 (decision 0240), or nothing without a holding.
  Widget? _holdingStrip(Launch2InstanceDetail detail, Decimal? price) {
    final viewer = detail.viewer;
    if (viewer == null) return null;
    final graduated = detail.stage == Launch2Stage.graduated;
    final holding = viewer.holding;
    final quantity = graduated
        ? (holding != null && holding.balancesRead ? holding.memeBalance : null)
        : viewer.curve.net;
    if (quantity == null || quantity <= Decimal.zero) return null;
    final position = _positionFor(detail);
    return Launch2HoldingStrip(
      quantity: quantity,
      ticker: detail.row.ticker,
      valueUsd1: position?.valueUsd1,
      price: price,
      cost: viewer.cost.isEmpty
          ? (position?.cost ?? Launch2CostBasis.none)
          : viewer.cost,
      quantityKey: graduated
          ? 'launch2-holding-quantity'
          : 'launch2-curve-holding',
    );
  }

  List<Widget> _stageWidgets(
    Launch2InstanceDetail detail,
    _PoolKind pool,
  ) => switch (detail.stage) {
    Launch2Stage.upcoming => <Widget>[
      LoopLabel(LoopL10n.current.launch2_launch2InstanceLoopLabel),
      _Figures(
        keyName: 'launch2-upcoming',
        rows: <(String, String)>[
          (
            LoopL10n
                .current
                .launch2Creator_launch2ProjectLaunch2ProjectSaleStartLabel,
            loopDateTimeLabel(detail.row.nftSale.startAt),
          ),
          (
            LoopL10n.current.launch2Creator_launch2Build7,
            launch2Usd1Label(detail.row.nftSale.priceUsd1),
          ),
          (
            LoopL10n.current.launch2_launch2InstanceRows3,
            launch2SaleDurationLabel(detail.row.nftSale),
          ),
        ],
      ),
      _TemplateCard(detail: detail),
    ],
    Launch2Stage.nftSale => <Widget>[
      _NftSaleBlock(
        detail: detail,
        onOpenMintPage: () => _open(Launch2Route.nft(detail.instanceId)),
      ),
      ..._tabbed(detail, <Launch2InstanceTab, List<Widget>>{
        Launch2InstanceTab.trades: <Widget>[_RecentTrades(detail: detail)],
        Launch2InstanceTab.info: <Widget>[_TemplateCard(detail: detail)],
      }),
    ],
    Launch2Stage.snapshotPending => <Widget>[
      LoopEmptyState(
        showMessage: true,
        key: const ValueKey<String>('launch2-snapshot-pending'),
        illustration: LoopIllustration.holders,
        title: launch2SnapshotPendingTitle(detail.snapshot),
        message: launch2SnapshotPendingMessage(detail.snapshot),
        compact: true,
      ),
      _Figures(
        keyName: 'launch2-snapshot-figures',
        rows: <(String, String)>[
          (
            LoopL10n.current.launch2_launch2InstanceRows4,
            LoopL10n.current.launch2_launch2InstanceRows5(
              detail.row.nftSale.soldCount,
            ),
          ),
          (
            LoopL10n.current.launch2_launch2InstanceRows6,
            detail.viewer == null
                ? LoopL10n.current.launch2_launch2InstanceRows7
                : '${detail.viewer!.nftHeld} / 1',
          ),
        ],
      ),
    ],
    Launch2Stage.closedNoHolders => <Widget>[_ClosedBlock(detail: detail)],
    Launch2Stage.priority || Launch2Stage.public => <Widget>[
      Launch2PriceHeader(
        price: detail.row.curve.priceUsd1,
        priceKey: 'launch2-curve-price',
        aside: LoopL10n.current.launch2_launch2HeroSwitch5(
          launch2BpsLabel(detail.row.curve.soldBps),
        ),
      ),
      // Decision 0227: the K line between the price and the figures.
      Launch2CandleCard(
        key: ValueKey<String>('launch2-candles-${detail.instanceId}'),
        detail: detail,
        onExpand: () => _open(Launch2Route.chart(detail.instanceId)),
      ),
      ?_holdingStrip(detail, detail.row.curve.priceUsd1),
      _CurveProgress(detail: detail),
      ..._tabbed(detail, <Launch2InstanceTab, List<Widget>>{
        Launch2InstanceTab.trades: <Widget>[_RecentTrades(detail: detail)],
        Launch2InstanceTab.info: <Widget>[
          // Decision 0202: the published list, without its addresses.
          if (launch2SnapshotPublishedShown(detail))
            Launch2SnapshotPublishedBlock(detail: detail),
          _TemplateCard(detail: detail),
        ],
      }),
    ],
    Launch2Stage.graduated => <Widget>[
      Launch2PriceHeader(
        price: detail.pool?.lastPriceUsd1,
        priceKey: 'launch2-pool-price',
        aside: detail.pool == null
            ? null
            : LoopL10n.current.launch2_launch2InstanceAside(
                launch2Usd1Label(detail.pool!.volume24hUsd1),
              ),
      ),
      // Decision 0227: the same card, curve and pool on one series.
      Launch2CandleCard(
        key: ValueKey<String>('launch2-candles-${detail.instanceId}'),
        detail: detail,
        onExpand: () => _open(Launch2Route.chart(detail.instanceId)),
      ),
      ?_holdingStrip(detail, detail.pool?.lastPriceUsd1),
      if (pool.dynamicPool case final Launch2DynamicPoolState dynamicPool)
        Launch2DynamicStatusStrip(
          state: dynamicPool,
          observedAt: ref
              .read(
                launch2PoolKindControllerProvider(detail.instanceId).notifier,
              )
              .valueObservedAt,
          onOpenRewards: () =>
              _open(Launch2Route.dynamicRewards(detail.instanceId)),
        ),
      if (pool.blocked case final String reason)
        Launch2DynamicUnavailableBlock(
          reason: reason,
          onRetry: () => unawaited(
            ref
                .read(
                  launch2PoolKindControllerProvider(detail.instanceId).notifier,
                )
                .reload(),
          ),
        ),
      ..._tabbed(detail, <Launch2InstanceTab, List<Widget>>{
        Launch2InstanceTab.trades: <Widget>[
          _PoolTradesTab(
            detail: detail,
            walletId:
                memeReadActiveWallet(ref).walletId ?? detail.viewer?.walletId,
            mineOnly: _mineOnly,
            onMineOnly: (value) => setState(() => _mineOnly = value),
          ),
        ],
        Launch2InstanceTab.info: <Widget>[
          _GraduatedInfo(detail: detail),
          if (pool.dynamicPool case final Launch2DynamicPoolState dynamicPool)
            Launch2DynamicFeeSummaryCard(
              state: dynamicPool,
              ticker: detail.row.ticker,
            ),
          // S294 · decision 0244 (需求方 2026-10-23 第 07 条): the pool
          // rows (外盘最新价 … 最近成交) and their 还在同步 line are gone;
          // the price header and the 成交 tab carry those figures.
          if (launch2SnapshotPublishedShown(detail))
            Launch2SnapshotPublishedBlock(detail: detail),
          // Decision 0157: a LoopDynamic Hook credits rewards only to buys
          // it can attribute; the wallet Swap may route elsewhere, so the
          // link is not offered there.
          if (pool.dynamicPool == null && pool.blocked == null)
            Launch2PoolSwapLink(
              onOpen: () => _open(
                Launch2Route.swap(
                  chainId: detail.row.chainId,
                  memeAddress: detail.row.memeAddress,
                ),
              ),
            ),
        ],
        Launch2InstanceTab.buyback: <Widget>[_BuybackPanel(detail: detail)],
      }),
    ],
    Launch2Stage.paused => <Widget>[_TemplateCard(detail: detail)],
  };
}

/// What `dynamic-pool` said of a graduated instance (decisions 0157 /
/// 0159): the LoopDynamic state, or why it cannot be traded now.
@immutable
final class _PoolKind {
  const _PoolKind({this.dynamicPool, this.blocked});

  final Launch2DynamicPoolState? dynamicPool;
  final String? blocked;
}

/// 「你是项目方」: one line, nothing else changes for the owner here.
class _OwnerStrip extends StatelessWidget {
  const _OwnerStrip();

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey<String>('launch2-owner-strip'),
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      2,
      LoopSpacing.page,
      6,
    ),
    child: Row(
      children: <Widget>[
        LoopBadge(
          context.l10n.launch2_launch2InstanceLoopBadge,
          kind: LoopBadgeKind.launch,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.launch2_launch2InstanceText5,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
        ),
      ],
    ),
  );
}

/// The folio caption (decision 0166): the project's name, then the stage's
/// line without the countdown words the stamp now carries.
String launch2InstanceFolioCaption(Launch2InstanceDetail detail) {
  final row = detail.row;
  final line = switch (row.stage) {
    Launch2Stage.upcoming => LoopL10n.current.launch2_launch2InstanceUpcoming(
      launch2SaleDurationLabel(row.nftSale),
      launch2Usd1Label(row.nftSale.priceUsd1),
    ),
    Launch2Stage.nftSale => LoopL10n.current.launch2_launch2InstanceNftSale(
      row.nftSale.soldCount,
    ),
    Launch2Stage.priority => LoopL10n.current.launch2_launch2InstancePriority,
    Launch2Stage.snapshotPending ||
    Launch2Stage.closedNoHolders ||
    Launch2Stage.public ||
    Launch2Stage.graduated ||
    Launch2Stage.paused => launch2StageCaption(row.stage),
  };
  return '${row.name} · $line';
}

/// `closed_no_holders` (decision 0142): the sentence, the cutoff block and
/// the closing time, all grey and inert — nothing here can be traded and
/// nothing will open later.
class _ClosedBlock extends StatelessWidget {
  const _ClosedBlock({required this.detail});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final closure = detail.snapshot.closure;
    return Launch2Greyed(
      key: const ValueKey<String>('launch2-closed-no-holders'),
      greyed: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopEmptyState(
            showMessage: true,
            illustration: LoopIllustration.holders,
            title: launch2ClosedNoHoldersText,
            message: context.l10n.launch2_launch2InstanceMessage2,
            compact: true,
          ),
          _Figures(
            keyName: 'launch2-closed-figures',
            rows: <(String, String)>[
              (
                context.l10n.launch2_launch2InstanceRows4,
                context.l10n.launch2_launch2InstanceRows5(
                  detail.row.nftSale.soldCount,
                ),
              ),
              if (closure != null) ...<(String, String)>[
                (
                  context.l10n.launch2_launch2InstanceRows8,
                  '#${loopGroupedFigure(closure.cutoffBlock.toString())}',
                ),
                (
                  context.l10n.launch2_launch2InstanceRows9,
                  loopDateTimeLabel(closure.closedAt),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Label / value rows in one quiet group.
class _Figures extends StatelessWidget {
  const _Figures({required this.keyName, required this.rows});

  final String keyName;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey<String>(keyName),
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (label, value) in rows)
          LoopKeyValue(label: label, value: value),
      ],
    ),
  );
}

/// The fixed template, read-only (contract §3.2): the figures every v2
/// project shares. The explanation is behind (i).
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.detail});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = detail.template;
    return Column(
      key: const ValueKey<String>('launch2-template'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Launch2SectionLabel(
          context.l10n.launch2_launch2InstanceLaunch2TemplateInfo,
          info: LoopIconButton(
            key: const ValueKey<String>('launch2-template-info'),
            icon: 'info',
            label: context.l10n.launch2_launch2InstanceLaunch2TemplateInfoLabel,
            color: LoopColors.text2,
            onPressed: () => unawaited(
              showLoopInfoSheet(
                context,
                title: context.l10n.launch2_launch2InstanceLaunch2TemplateInfo,
                sheetKey: 'launch2-template-sheet',
                notes: <LoopInfoNote>[
                  LoopInfoNote(
                    title: context.l10n.launch2_launch2InstanceTitle,
                    body: context.l10n.launch2_launch2InstanceBody,
                  ),
                  LoopInfoNote(
                    title: context.l10n.launch2_launch2InstanceTitle2,
                    body: context.l10n.launch2_launch2InstanceBody2(
                      launch2MemeCompact(t.curveSaleSupply),
                      launch2Usd1Label(t.nftPriceUsd1),
                    ),
                  ),
                  LoopInfoNote(
                    key: ValueKey<String>('launch2-template-risk'),
                    title: context
                        .l10n
                        .launch2_launch2InstanceLaunch2TemplateRiskTitle,
                    body: LoopL10n.current.launch2_nftRiskBody(
                      launch2SentenceCase(launch2NftRiskSentence),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        LoopKeyValue(
          label: context.l10n.common_totalSupply,
          value: launch2MemeCompact(t.memeTotalSupply),
        ),
        LoopKeyValue(
          label: context.l10n.launch2_launch2InstanceLabel,
          value: launch2MemeCompact(t.curveSaleSupply),
        ),
        LoopKeyValue(
          label: context.l10n.launch2Creator_launch2Build2,
          value: launch2Usd1Label(
            t.graduationReserveUsd1,
            maxFractionDigits: 3,
          ),
        ),
        LoopKeyValue(
          label: context.l10n.launch2Creator_launch2Build3,
          value: launch2BpsLabel(t.curveBuyTaxBps),
        ),
        LoopKeyValue(
          label: context.l10n.launch2_launch2InstanceLabel4,
          value: launch2BpsLabel(t.officialPoolTaxBps),
        ),
        LoopKeyValue(
          label: context.l10n.launch2Creator_launch2Build6,
          value:
              // Decision 0197: the instance's own cap, whole tokens.
              context.l10n.launch2_launch2InstanceValue(
                launch2BpsLabel(t.perAddressCapBps),
                launch2CurveCapFigure(t.perAddressCap),
              ),
        ),
      ],
    );
  }
}

/// 项目 NFT (decision 0166): the price and what was sold as a `.stat-grid`,
/// the sale's elapsed time as a `.record-card` with its 6 px `.bar` and the
/// cutoff, 「铸造页」 at the card's foot in Text2, and what this wallet holds.
class _NftSaleBlock extends ConsumerWidget {
  const _NftSaleBlock({required this.detail, required this.onOpenMintPage});

  final Launch2InstanceDetail detail;

  /// 「铸造页」 (decision 0163): 共识勋章 of this instance.
  final VoidCallback onOpenMintPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = detail.row.nftSale;
    final viewer = detail.viewer;
    final elapsed = launch2HeroFuse(
      detail.row,
      ref.read(launch2ClockProvider)(),
    );
    final elapsedText = elapsed == null
        ? context.l10n.common_loading
        : context.l10n.launch2_launch2InstanceS((elapsed * 100).floor());
    return Column(
      key: const ValueKey<String>('launch2-nft-sale'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Launch2SectionLabel(
          context.l10n.launch2_launch2InstanceLaunch2NftInfo,
          info: LoopIconButton(
            key: const ValueKey<String>('launch2-nft-info'),
            icon: 'info',
            label: context.l10n.launch2_launch2InstanceLaunch2NftInfoLabel,
            color: LoopColors.text2,
            onPressed: () => unawaited(
              showLoopInfoSheet(
                context,
                title: context.l10n.launch2_launch2InstanceLaunch2NftInfo,
                sheetKey: 'launch2-nft-sheet',
                notes: <LoopInfoNote>[
                  LoopInfoNote(body: context.l10n.launch2_launch2InstanceBody3),
                  LoopInfoNote(
                    key: ValueKey<String>('launch2-nft-risk-note'),
                    title: context
                        .l10n
                        .launch2_launch2InstanceLaunch2TemplateRiskTitle,
                    body: LoopL10n.current.launch2_nftRiskBody(
                      launch2SentenceCase(launch2NftRiskSentence),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        MemeStatFigures(
          hero: true,
          stats: <LoopStat>[
            LoopStat(
              label: context.l10n.launch2_launch2InstanceLabel6,
              value: launch2Usd1Label(sale.priceUsd1),
              statKey: const ValueKey<String>('launch2-nft-price'),
            ),
            LoopStat(
              label: context.l10n.launch2_launch2InstanceRows4,
              value: context.l10n.launch2_launch2InstanceRows5(sale.soldCount),
              statKey: const ValueKey<String>('launch2-nft-sold'),
            ),
          ],
        ),
        LoopRecordCard(
          key: const ValueKey<String>('launch2-nft-progress'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      context.l10n.launch2_launch2InstanceBuild,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopType.body2.copyWith(color: LoopColors.text2),
                    ),
                  ),
                  const Spacer(),
                  Text(elapsedText, style: LoopType.figure),
                ],
              ),
              const SizedBox(height: 12),
              LoopProgressBar(
                value: elapsed,
                semanticLabel: context.l10n
                    .launch2_launch2InstanceSemanticLabel(elapsedText),
              ),
              const SizedBox(height: 3),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.l10n.launch2_launch2InstanceLaunch2NftEnd(
                        loopDateTimeLabel(sale.endAt),
                      ),
                      key: const ValueKey<String>('launch2-nft-end'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // R20 the note under the bar.
                      style: LoopType.caption.copyWith(color: LoopColors.text2),
                    ),
                  ),
                  _MintPageLink(onTap: onOpenMintPage),
                ],
              ),
            ],
          ),
        ),
        LoopKeyValue(
          key: const ValueKey<String>('launch2-nft-held'),
          label: context.l10n.launch2_launch2InstanceLaunch2NftHeldLabel,
          value: viewer == null
              ? context.l10n.launch2_launch2InstanceRows7
              : '${viewer.nftHeld} / 1',
        ),
      ],
    );
  }
}

/// 「铸造页」 (decision 0163 entry, decision 0166 colour): a Text2 link with a
/// chevron, 44 dp — the medal colour stays on the 共识勋章 page itself.
class _MintPageLink extends StatelessWidget {
  const _MintPageLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.launch2_launch2InstanceLaunch2NftOpenLabel,
    excludeSemantics: true,
    child: LoopPressable(
      key: const ValueKey<String>('launch2-nft-open'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: LoopTouch.minimum,
          minWidth: LoopTouch.minimum,
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // R17 inline text action (decision 0190 L23).
              Text(
                context.l10n.launch2_launch2InstanceLaunch2NftOpenLabel,
                style: LoopTypography.withWeight(
                  LoopType.label,
                  FontWeight.w600,
                ).copyWith(color: LoopColors.text2),
              ),
              const SizedBox(width: 2),
              const LoopIcon('chevron', size: 14, color: LoopColors.text3),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 内盘进度 (decision 0166, v3 decision 0229): the share sold as a
/// `.record-card` with its 6 px `.bar`, the supply under it. Under the
/// price area since decision 0240.
class _CurveProgress extends StatelessWidget {
  const _CurveProgress({required this.detail});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final curve = detail.row.curve;
    return LoopRecordCard(
      key: const ValueKey<String>('launch2-curve'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.launch2_launch2HeroSwitch6,
                  style: LoopType.body2.copyWith(color: LoopColors.text2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                launch2BpsLabel(curve.soldBps),
                key: const ValueKey<String>('launch2-curve-progress'),
                maxLines: 1,
                style: LoopType.figure,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LoopProgressBar(
            value: launch2Fraction(curve.soldBps),
            semanticLabel: context.l10n.launch2_launch2InstanceSemanticLabel2(
              launch2BpsLabel(curve.soldBps),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.launch2_launch2InstanceLaunch2CurveSupply(
              launch2MemeCompact(curve.soldSupply),
              launch2MemeCompact(curve.saleSupply),
            ),
            key: const ValueKey<String>('launch2-curve-supply'),
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
        ],
      ),
    );
  }
}

/// One curve trade. S239: with the trader's LOOP account attached (loop-api
/// decision 0162 §A) the line names the account and its face opens the
/// account's page; a bare address opens nothing.
///
/// v3 (decision 0229): one primary figure per line. Left, the side in its
/// rise / fall colour and who traded; right, the USD1 amount as the line's
/// figure over the MEME amount as its caption. Before v3 both amounts sat in
/// one 13 string behind a centre dot.
Widget _tradeRow(Launch2Trade trade, String ticker) {
  final account = trade.account;
  final buy = trade.side == Launch2Side.buy;
  final name = account?.displayName ?? launch2ShortAddress(trade.traderAddress);
  final who = Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(
          text: buy
              ? LoopL10n.current.common_buy
              : LoopL10n.current.common_sell,
          style: LoopTypography.withWeight(
            LoopType.body2,
            FontWeight.w600,
          ).copyWith(color: buy ? LoopColors.rise : LoopColors.fall),
        ),
        const TextSpan(text: '  '),
        TextSpan(
          text: name,
          style: LoopType.body2.copyWith(color: LoopColors.text2),
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
  final memeLine = ticker.trim().isEmpty
      ? launch2MemeCompact(trade.memeAmount)
      : '${launch2MemeCompact(trade.memeAmount)} ${loopTickerLabel(ticker)}';
  return Padding(
    key: ValueKey<String>('launch2-trade-${trade.tradeId}'),
    padding: const EdgeInsets.symmetric(
      horizontal: LoopSpacing.page,
      vertical: 10,
    ),
    child: Row(
      children: <Widget>[
        if (account != null) ...<Widget>[
          LoopProfileFaceLink(
            key: ValueKey<String>('launch2-trade-face-${trade.tradeId}'),
            publicProfileId: account.publicProfileId,
            name: name,
            child: LoopProfileAvatar(
              avatarRef: account.avatarRef,
              alias: account.displayName,
              size: 28,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(child: who),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              launch2Usd1Label(trade.usd1Gross),
              maxLines: 1,
              style: LoopType.figureBody,
            ),
            const SizedBox(height: 2),
            Text(memeLine, maxLines: 1, style: LoopType.figureSm),
          ],
        ),
      ],
    ),
  );
}

class _RecentTrades extends StatelessWidget {
  const _RecentTrades({required this.detail});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final trades = detail.recentTrades;
    return Column(
      key: const ValueKey<String>('launch2-trades'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopLabel(context.l10n.launch2_launch2InstanceLoopLabel2),
        if (trades.isEmpty)
          LoopEmptyState(
            key: ValueKey<String>('launch2-trades-empty'),
            illustration: LoopIllustration.chartEmpty,
            title: context.l10n.common_noTradesYet,
            compact: true,
          )
        else
          for (final trade in trades) _tradeRow(trade, detail.row.ticker),
        LoopProvenanceLine(
          key: const ValueKey<String>('launch2-trades-provenance'),
          sources: <String>[
            context.l10n.launch2_launch2InstanceLoopProvenanceLine,
          ],
          observedAt: detail.projectedAt,
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            6,
            LoopSpacing.page,
            4,
          ),
          detail:
              context.l10n.launch2_launch2InstanceLaunch2TradesProvenanceDetail,
        ),
      ],
    );
  }
}

/// 成交 after graduation (decision 0240): the official pool's latest public
/// trades (loop-api decision 0174), or with 「只看我的」 the wallet's own
/// pool trades (decision 0148, `…/pool/trades`).
class _PoolTradesTab extends ConsumerWidget {
  const _PoolTradesTab({
    required this.detail,
    required this.walletId,
    required this.mineOnly,
    required this.onMineOnly,
  });

  final Launch2InstanceDetail detail;
  final String? walletId;
  final bool mineOnly;
  final ValueChanged<bool> onMineOnly;

  static const EdgeInsets _provenancePadding = EdgeInsets.fromLTRB(
    LoopSpacing.page,
    6,
    LoopSpacing.page,
    4,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    key: const ValueKey<String>('launch2-pool-trades'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Launch2MineOnlyToggle(
        value: mineOnly,
        onChanged: onMineOnly,
        title: !mineOnly
            ? context.l10n.launch2_launch2InstanceTitle3
            : switch (detail.viewer?.holding?.poolTradeCount) {
                final BigInt count when count > BigInt.zero =>
                  context.l10n.launch2_launch2InstanceZero(
                    loopGroupedFigure(count.toString()),
                  ),
                _ => context.l10n.launch2_launch2InstanceLaunch2MineOnlyToggle,
              },
      ),
      if (mineOnly) ..._mine(ref) else ..._everyone(ref),
    ],
  );

  List<Widget> _everyone(WidgetRef ref) {
    final provider = launch2RecentPoolTradesControllerProvider(
      detail.instanceId,
    );
    final state = ref.watch(provider);
    launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
    final page = state.value;
    if (page == null) {
      return <Widget>[
        if (state.phase == LoopChainViewPhase.loading)
          const LoopSkeleton(
            key: ValueKey<String>('launch2-pool-trades-loading'),
            type: LoopSkeletonType.list,
            rows: 3,
          )
        else
          LoopInlineUnavailable(
            key: const ValueKey<String>('launch2-pool-trades-failed'),
            message: LoopL10n.current
                .launch2_launch2InstanceLaunch2PoolTradesFailedMessage(
                  state.failureKind == LoopChainFailureKind.rateLimited
                      ? LoopL10n.current.launch2_poolTradesRateLimited
                      : loopChainFailureReason(state.failureKind),
                ),
            onRetry: state.mode == LoopChainGatewayMode.unavailable
                ? null
                : () => unawaited(ref.read(provider.notifier).reload()),
          ),
      ];
    }
    return <Widget>[
      if (page.items.isEmpty)
        LoopEmptyState(
          key: ValueKey<String>('launch2-pool-trades-empty'),
          illustration: LoopIllustration.chartEmpty,
          title: LoopL10n
              .current
              .launch2_launch2InstanceLaunch2PoolTradesEmptyTitle,
          compact: true,
        )
      else
        for (final (index, trade) in page.items.indexed)
          Launch2PublicTradeRow(
            key: ValueKey<String>(
              'launch2-pool-trade-${trade.txHash}-${trade.blockNumber}-$index',
            ),
            trade: trade,
            ticker: detail.row.ticker,
          ),
      LoopProvenanceLine(
        key: const ValueKey<String>('launch2-pool-trades-provenance'),
        sources: <String>[
          LoopL10n.current.launch2_launch2InstanceLoopProvenanceLine,
        ],
        observedAt: page.observedAt,
        padding: _provenancePadding,
        detail: LoopL10n.current
            .launch2_launch2InstanceLaunch2PoolTradesProvenanceDetail(
              launch2RecentPoolTradesLimit,
            ),
      ),
    ];
  }

  List<Widget> _mine(WidgetRef ref) {
    final count = detail.viewer?.holding?.poolTradeCount;
    final wallet = walletId;
    if (wallet == null || detail.viewer == null) {
      return <Widget>[
        LoopInlineUnavailable(
          key: ValueKey<String>('launch2-my-pool-trades-no-wallet'),
          icon: 'info',
          message: LoopL10n
              .current
              .launch2_launch2InstanceLaunch2MyPoolTradesNoWalletMessage,
        ),
      ];
    }
    if (count == null) {
      return <Widget>[
        LoopInlineUnavailable(
          key: ValueKey<String>('launch2-my-pool-trades-unsupported'),
          icon: 'info',
          message: LoopL10n
              .current
              .launch2_launch2InstanceLaunch2MyPoolTradesUnsupportedMessage,
        ),
      ];
    }
    if (count == BigInt.zero) {
      return <Widget>[
        LoopEmptyState(
          key: ValueKey<String>('launch2-my-pool-trades-none'),
          illustration: LoopIllustration.chartEmpty,
          title: LoopL10n
              .current
              .launch2_launch2InstanceLaunch2MyPoolTradesNoneTitle,
          compact: true,
        ),
      ];
    }
    final provider = launch2PoolTradesControllerProvider((
      instanceId: detail.instanceId,
      walletId: wallet,
      count: count,
    ));
    final state = ref.watch(provider);
    launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
    final page = state.value;
    final ticker = detail.row.ticker;
    return <Widget>[
      if (page == null)
        state.phase == LoopChainViewPhase.loading
            ? const LoopSkeleton(
                key: ValueKey<String>('launch2-my-pool-trades-loading'),
                type: LoopSkeletonType.list,
                rows: 2,
              )
            : LoopInlineUnavailable(
                key: const ValueKey<String>('launch2-my-pool-trades-failed'),
                message: LoopL10n.current
                    .launch2_launch2InstanceLaunch2MyPoolTradesFailedMessage(
                      loopChainFailureReason(state.failureKind),
                    ),
                onRetry: () => unawaited(ref.read(provider.notifier).reload()),
              )
      else if (page.trades.isEmpty)
        LoopInlineUnavailable(
          key: ValueKey<String>('launch2-my-pool-trades-empty'),
          icon: 'info',
          message: LoopL10n
              .current
              .launch2_launch2InstanceLaunch2MyPoolTradesEmptyMessage,
        )
      else
        for (final trade in page.trades)
          LoopKeyValue(
            key: ValueKey<String>('launch2-my-pool-trade-${trade.poolTradeId}'),
            label:
                '${trade.side == Launch2Side.buy ? LoopL10n.current.common_buy : LoopL10n.current.common_sell} · '
                '${loopDateTimeLabel(trade.tradedAt)}',
            value: launch2PoolTradeFigure(trade, ticker),
            valueUp: trade.side == Launch2Side.buy,
          ),
      if (page != null)
        LoopProvenanceLine(
          key: const ValueKey<String>('launch2-my-pool-trades-provenance'),
          sources: <String>[
            LoopL10n.current.launch2_launch2InstanceLoopProvenanceLine,
          ],
          observedAt: ref.read(provider.notifier).valueObservedAt,
          padding: _provenancePadding,
          detail: LoopL10n.current
              .launch2_launch2InstanceLaunch2MyPoolTradesProvenanceDetail(
                launch2MyPoolTradesShown,
              ),
        ),
    ];
  }
}

/// 官方池 in the 信息 tab (decision 0240; the K line moved to the price
/// area): the pool's facts behind (i), the graduation time and price and the
/// pool tax.
class _GraduatedInfo extends StatelessWidget {
  const _GraduatedInfo({required this.detail});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final graduation = detail.graduation;
    return Column(
      key: const ValueKey<String>('launch2-graduated'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Launch2SectionLabel(
          context.l10n.launch2_launch2InstanceLaunch2PoolInfo,
          info: LoopIconButton(
            key: const ValueKey<String>('launch2-pool-info'),
            icon: 'info',
            label: context.l10n.launch2_launch2InstanceLaunch2PoolInfoLabel,
            color: LoopColors.text2,
            onPressed: () => unawaited(
              showLoopInfoSheet(
                context,
                title: context.l10n.launch2_launch2InstanceLaunch2PoolInfo,
                sheetKey: 'launch2-pool-sheet',
                notes: <LoopInfoNote>[
                  if (graduation != null) ...<LoopInfoNote>[
                    LoopInfoNote(
                      key: const ValueKey<String>('launch2-pool-id'),
                      title: context
                          .l10n
                          .launch2_launch2InstanceLaunch2PoolIdTitle,
                      body: graduation.officialPoolId,
                    ),
                    LoopInfoNote(title: 'Hook', body: graduation.hookAddress),
                    LoopInfoNote(
                      title: context.l10n.launch2_launch2InstanceTitle4,
                      body: context.l10n.launch2_launch2InstanceBody4(
                        launch2BpsLabel(graduation.lpFee ~/ 100),
                        graduation.tickSpacing,
                      ),
                    ),
                  ],
                  LoopInfoNote(
                    key: const ValueKey<String>('launch2-pool-tax'),
                    title: context.l10n
                        .launch2_launch2InstanceLaunch2PoolTaxTitle(
                          launch2BpsLabel(
                            graduation?.officialPoolTaxBps ??
                                detail.template.officialPoolTaxBps,
                          ),
                        ),
                    body:
                        context.l10n.launch2_launch2InstanceLaunch2PoolTaxBody,
                  ),
                ],
              ),
            ),
          ),
        ),
        LoopKeyValue(
          label: context.l10n.launch2_launch2InstanceLabel7,
          value: graduation == null
              ? context.l10n.common_loading
              : loopDateTimeLabel(graduation.graduatedAt),
        ),
        LoopKeyValue(
          label: context.l10n.launch2_launch2InstanceLabel8,
          value: launch2PriceLabel(detail.row.curve.priceUsd1),
        ),
        LoopKeyValue(
          label: context.l10n.launch2_launch2InstanceLabel4,
          value: launch2BpsLabel(
            graduation?.officialPoolTaxBps ??
                detail.template.officialPoolTaxBps,
          ),
        ),
      ],
    );
  }
}

/// 回购面板 (contract §3.6): escrow, the running total, the latest order and
/// why the next one would not go through now. Refused attempts are not
/// listed — they revert without a log.
/// Decision 0150: the merged hold on two lines — the reason (wraps, never
/// cut) and 「来源 · 时间」 — styled as [LoopInlineUnavailable], which is one
/// line only and cut the retry time off at 360 wide.
/// 「最近一笔」 value (S257): `MM-DD HH:mm，100 USD1，成交` in local time.
/// The year is dropped and the parts are joined with 「，」 rather than
/// middle dots (docs/42 附C) so the line fits one row at 360–430 wide.
String launch2BuybackLatestText({
  required DateTime executedAt,
  required Decimal usd1Spent,
  required String outcome,
}) {
  return '${launch2ShortDateTime(executedAt)}'
      '${LoopL10n.current.common_listSeparator}${launch2Usd1Label(usd1Spent)}'
      '${LoopL10n.current.common_listSeparator}$outcome';
}

/// 「最近一笔」 as a stacked row (S257): the label on its own line and the
/// value across the full width, so the sentence never wraps against a
/// half-width column.
class _BuybackLatestRow extends StatelessWidget {
  const _BuybackLatestRow({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.launch2_launch2InstanceBuild2,
            style: LoopType.captionSm.copyWith(color: LoopColors.text2),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            key: const ValueKey<String>('launch2-buyback-latest-value'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoopTypography.withWeight(
              LoopType.figureXs,
              FontWeight.w500,
            ).copyWith(color: LoopColors.chalk),
          ),
        ],
      ),
    );
  }
}

class _BuybackHeldRow extends StatelessWidget {
  const _BuybackHeldRow({required this.line, super.key});

  final Launch2BuybackHeldLine line;

  @override
  Widget build(BuildContext context) {
    final auxiliary = LoopGround.auxiliaryOf(context);
    final style = LoopType.captionSm.copyWith(color: auxiliary);
    final detail = line.detail;
    return Semantics(
      container: true,
      label: line.text.replaceAll('\n', LoopL10n.current.common_listSeparator),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: LoopInlineUnavailable.height - 24,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: LoopIcon('clock', size: 15, color: auxiliary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      line.reason,
                      key: const ValueKey<String>(
                        'launch2-buyback-held-reason',
                      ),
                      style: style,
                    ),
                    if (detail != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        key: const ValueKey<String>(
                          'launch2-buyback-held-detail',
                        ),
                        style: style,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuybackPanel extends ConsumerWidget {
  const _BuybackPanel({required this.detail});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = launch2BuybacksControllerProvider(detail.instanceId);
    final state = ref.watch(provider);
    launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
    final page = state.value;
    final summary = page?.summary ?? detail.buyback;
    final live = page?.live;
    final latest = summary.latest;
    final keeper = launch2KeeperLine(summary);
    // Decision 0148: both sources held → one line naming them.
    final held = page == null || live == null
        ? null
        : launch2BuybackHeldLine(
            liveBlockedReason: live.nextOrderBlockedReason,
            keeper: keeper,
          );
    return Column(
      key: const ValueKey<String>('launch2-buyback'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Launch2SectionLabel(
          context.l10n.launch2_launch2InstancePartsBuyback,
          info: LoopIconButton(
            key: const ValueKey<String>('launch2-buyback-info'),
            icon: 'info',
            label: context.l10n.launch2_launch2InstanceLaunch2BuybackInfoLabel,
            color: LoopColors.text2,
            onPressed: () => unawaited(
              showLoopInfoSheet(
                context,
                title: context.l10n.launch2_launch2InstancePartsBuyback,
                sheetKey: 'launch2-buyback-sheet',
                notes: <LoopInfoNote>[
                  LoopInfoNote(
                    key: ValueKey<String>('launch2-buyback-not-burn'),
                    title: context
                        .l10n
                        .launch2_launch2InstanceLaunch2BuybackNotBurnTitle,
                    body: context
                        .l10n
                        .launch2_launch2InstanceLaunch2BuybackNotBurnBody,
                  ),
                  LoopInfoNote(
                    title: context.l10n.launch2_launch2InstanceTitle5,
                    body: context.l10n.launch2_launch2InstanceBody5(
                      detail.template.buybackMinIntervalSeconds,
                      launch2Usd1Label(detail.template.buybackOrderUsd1),
                    ),
                  ),
                  LoopInfoNote(
                    title: context.l10n.launch2_launch2InstanceTitle6,
                    body: summary.recipient,
                  ),
                ],
              ),
            ),
          ),
        ),
        LoopKeyValue(
          key: const ValueKey<String>('launch2-buyback-escrow'),
          label: context.l10n.launch2_launch2InstanceLaunch2BuybackEscrowLabel,
          value: launch2Usd1Label(
            live?.escrowAvailableUsd1 ?? summary.escrowAvailableUsd1,
          ),
        ),
        LoopKeyValue(
          key: const ValueKey<String>('launch2-buyback-total'),
          label: context.l10n.launch2_launch2InstanceLaunch2BuybackTotalLabel,
          value: context.l10n.launch2_launch2InstanceLaunch2BuybackTotalValue(
            summary.executedCount,
            launch2Usd1Label(summary.totalUsd1),
          ),
        ),
        _BuybackLatestRow(
          key: const ValueKey<String>('launch2-buyback-latest'),
          value: latest == null
              ? context.l10n.launch2_launch2InstanceLaunch2BuybackLatestValue
              : launch2BuybackLatestText(
                  executedAt: latest.executedAt,
                  usd1Spent: latest.usd1Spent,
                  outcome: latest.executed
                      ? context.l10n.launch2_buybackExecuted
                      : launch2BuybackBlockedText(latest.reasonCode),
                ),
        ),
        if (held != null)
          _BuybackHeldRow(
            key: const ValueKey<String>('launch2-buyback-held'),
            line: held,
          )
        else if (page != null && live != null)
          LoopKeyValue(
            key: const ValueKey<String>('launch2-buyback-next'),
            label: context.l10n.launch2_launch2InstanceLaunch2BuybackNextLabel,
            value: launch2BuybackBlockedText(live.nextOrderBlockedReason),
          )
        else if (page?.liveUnavailableReason case final String reason)
          LoopInlineUnavailable(
            key: const ValueKey<String>('launch2-buyback-live-unavailable'),
            message: context.l10n
                .launch2_launch2InstanceLaunch2BuybackLiveUnavailableMessage(
                  launch2ReasonText(reason),
                ),
          )
        else if (page == null &&
            state.phase != LoopChainViewPhase.loading &&
            state.failureKind != null)
          LoopInlineUnavailable(
            key: const ValueKey<String>('launch2-buyback-unavailable'),
            message: context.l10n
                .launch2_launch2InstanceLaunch2BuybackUnavailableMessage(
                  loopChainFailureReason(state.failureKind),
                ),
            onRetry: () => unawaited(ref.read(provider.notifier).reload()),
          ),
        // Decision 0146: the keeper's state, one line.
        if (keeper != null && held == null)
          LoopInlineUnavailable(
            key: const ValueKey<String>('launch2-buyback-keeper'),
            icon: keeper.held ? 'clock' : 'refresh',
            message: keeper.text,
          ),
        if (summary.paused)
          LoopInlineUnavailable(
            key: ValueKey<String>('launch2-buyback-paused'),
            icon: 'info',
            message: context.l10n.launch2_launch2FormatSwitch4,
          ),
      ],
    );
  }
}

/// The module-wide marker loop-api puts on `launch2` while it is enabled and
/// no BSC Testnet run is recorded (`v2Launch2EvidencePendingReasonCode`). The
/// server never lifts it (its evidence is `pending` by construction and the
/// client refuses `confirmed` on `launch2`, decision 0137 §3).
const String launch2TestnetEvidencePendingCode =
    'LAUNCH2_TESTNET_EVIDENCE_PENDING';

/// Whether the project page says 「测试网合约还在核对」 (decision 0200).
///
/// Only for a pending reason other than the module-wide marker: that marker
/// is a constant of the module, not a fact about this instance's contracts,
/// and showing it made the line permanent on every project page. The
/// instance's own guard is the trading hold (decision 0161).
bool launch2EvidenceNoticeShown(LoopCapabilityProjection capability) =>
    capability.evidencePending &&
    capability.evidenceReasonCode != launch2TestnetEvidencePendingCode;
