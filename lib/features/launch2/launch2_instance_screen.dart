import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_trade_panel.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_trade_panel.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_wallet.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_sheet.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `launch2-instance` · one MEME v2 project (archetype `record`, layout
/// `dashboard`, client decision 0139).
///
/// One page for every stage: the stage bar and its countdown on top, then the
/// stage's own content, swapped in place with one 150 ms fade when the server
/// says the stage moved — never a new page. The page counts down to the
/// server's `nextChangeAt` and re-reads; it never advances a stage itself.
///
/// - `upcoming` — 开售时间 and the fixed template behind (i).
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

class _Launch2InstanceScreenState extends ConsumerState<Launch2InstanceScreen> {
  Timer? _poll;
  _Pending? _pending;

  /// Our own last action's refusal (decision 0153): said in the body and
  /// right above the button that started it.
  Launch2ActionFailure? _actionFailure;
  bool _preparingNft = false;
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
    ]);
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
    _poll = Timer(fast ? polling.tradingInterval : polling.detailInterval, () {
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
      final noun = launch2IntentNoun(pending.kind);
      setState(() {
        _pending = _Pending(
          kind: pending.kind,
          venue: pending.venue,
          text: pending.venue != Launch2Venue.officialPool
              ? '$noun已在链上确认。'
              : _ownPoolSignal(detail)
              ? '你的外盘$noun已在链上确认。'
              : '官方池已记录新成交，你的外盘$noun应已确认；数量以钱包余额为准。',
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
          text:
              '已广播，但还没有读到确认。它可能仍在确认中，请稍后再查；'
              '不要重复${launch2IntentNoun(pending.kind)}。',
          locked: false,
          baseline: pending.baseline,
        );
      });
    }
  }

  /// Hands one prepared intent to the signing exit and records what it
  /// answered.
  Future<void> _sign(
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
    );
    if (!mounted || outcome == null) return;
    final noun = launch2IntentNoun(intent.kind);
    setState(() {
      _settleReads = 0;
      _pending = _Pending(
        kind: intent.kind,
        venue: intent.venue,
        text: outcome.broadcast
            ? launch2BroadcastText(outcome, intent.kind)
            : launch2StoppedAtRefresh(outcome)
            ? launch2RefreshReasonText(outcome, noun)
            : outcome.approvalTxHash != null
            ? launch2ApprovalOnlyText(outcome.reasonCode, noun)
            : launch2SignReasonText(outcome.reasonCode),
        locked: outcome.broadcast,
        baseline: _viewerSignature(detail),
      );
    });
    if (outcome.broadcast) {
      _poll?.cancel();
      _poll = null;
      unawaited(
        ref
            .read(launch2InstanceControllerProvider(detail.instanceId).notifier)
            .reload(),
      );
    }
  }

  Future<void> _buyNft(Launch2InstanceDetail detail) async {
    final confirmed = await showLaunch2NftConfirmSheet(
      context,
      ticker: detail.row.ticker,
      priceLabel: launch2Usd1Label(detail.row.nftSale.priceUsd1),
    );
    if (!confirmed || !mounted) return;
    final wallet = memeReadActiveWallet(ref);
    final walletId = wallet.walletId ?? detail.viewer?.walletId;
    if (walletId == null) {
      setState(
        () => _actionFailure = const Launch2ActionFailure('还没有可用的钱包，激活钱包后再购买'),
      );
      return;
    }
    setState(() {
      _preparingNft = true;
      _actionFailure = null;
    });
    try {
      final intent = await ref
          .read(launch2GatewayProvider)
          .prepareNftMint(instanceId: detail.instanceId, walletId: walletId);
      if (!mounted) return;
      setState(() => _preparingNft = false);
      await _sign(detail, intent);
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _preparingNft = false;
        _actionFailure = launch2ActionFailure(
          failure,
          usd1Balance: _readUsd1(detail),
        );
      });
      // The stage moved under the page (the sale ended, possibly closed
      // with no holder): one line here and a fresh read, never an error
      // page (decision 0142).
      if (failure.reasonCode == launch2StageMismatchCode) {
        unawaited(
          ref
              .read(
                launch2InstanceControllerProvider(detail.instanceId).notifier,
              )
              .reload(),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preparingNft = false;
        _actionFailure = Launch2ActionFailure(
          loopChainFailureReason(LoopChainFailureKind.unexpected),
        );
      });
    }
  }

  /// The wallet's USD1 when the server read it at a block (after
  /// graduation, decision 0148); `null` otherwise — never a guess.
  static Decimal? _readUsd1(Launch2InstanceDetail detail) {
    final holding = detail.viewer?.holding;
    return holding != null && holding.balancesRead ? holding.usd1Balance : null;
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
        onGranted: () => unawaited(
          ref
              .read(
                launch2InstanceControllerProvider(detail.instanceId).notifier,
              )
              .reload(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.instanceId;
    if (!Launch2Route.isInstanceId(id)) {
      return LoopFocusPage(
        key: const ValueKey<String>('launch2-invalid-route'),
        archetype: LoopPageArchetype.record,
        title: '无法打开这个项目',
        onBack: widget.onBack,
        body: const <Widget>[
          LoopEmpty(
            key: ValueKey<String>('launch2-invalid-identity'),
            icon: 'warn',
            message: '路由中没有可用的项目标识',
            reason: '没有请求任何数据，也没有回退到其他项目。',
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
    return LoopDashboardPage(
      key: ValueKey<String>('launch2-instance-$instanceId'),
      archetype: LoopPageArchetype.record,
      title: detail == null ? 'MEME v2' : '\$${detail.row.ticker}',
      onBack: widget.onBack,
      updating: state?.refreshing ?? false,
      onRefresh: blocked ? null : () => _reload(instanceId),
      block: blocked
          ? LoopPageBlock(
              key: const ValueKey<String>('launch2-instance-blocked'),
              title: 'MEME v2 暂时不可用',
              message: launch2CapabilityText(capability),
            )
          : null,
      bottomBar: detail == null || paused ? null : _bottomBar(detail),
      sections: <Widget>[
        if (state == null || detail == null)
          LoopChainStateBlock(
            keyPrefix: 'launch2-instance',
            phase: state?.phase ?? LoopChainViewPhase.unavailable,
            failureKind: state?.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '项目不存在',
            onRetry: () => unawaited(ref.read(provider.notifier).reload()),
          )
        else
          ..._sections(detail, capability),
      ],
    );
  }

  Widget? _bottomBar(Launch2InstanceDetail detail) {
    switch (detail.stage) {
      case Launch2Stage.nftSale:
        final held = (detail.viewer?.nftHeld ?? 0) > 0;
        final hold = detail.tradingHold;
        final busy =
            _preparingNft || (_pending?.locked ?? false) || hold != null;
        final failure = held || _preparingNft || hold != null
            ? null
            : _actionFailure;
        return _BarShell(
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
                ? '已持有 NFT'
                : _preparingNft
                ? '正在准备…'
                : '购买 NFT',
            primary: true,
            block: true,
            onPressed: held || busy ? null : () => unawaited(_buyNft(detail)),
          ),
        );
      case Launch2Stage.graduated:
        // Decision 0145: trading moved into the page (外盘交易 panel); the
        // wallet Swap stays one secondary link under it.
        return null;
      case Launch2Stage.upcoming:
      case Launch2Stage.snapshotPending:
      case Launch2Stage.closedNoHolders:
      case Launch2Stage.priority:
      case Launch2Stage.public:
      case Launch2Stage.paused:
        return null;
    }
  }

  List<Widget> _sections(
    Launch2InstanceDetail detail,
    LoopCapabilityProjection capability,
  ) {
    final pending = _pending;
    final paused = detail.stage == Launch2Stage.paused;
    final body = <Widget>[
      _Identity(
        detail: detail,
        onCopy: () => unawaited(
          LoopCopy.text(context, detail.row.memeAddress, message: '已复制代币地址'),
        ),
      ),
      _StageBar(
        detail: detail,
        onElapsed: () => unawaited(
          ref
              .read(
                launch2InstanceControllerProvider(detail.instanceId).notifier,
              )
              .reload(),
        ),
      ),
      // Decision 0161: the chain guard's hold, above every trade panel.
      if (detail.tradingHold case final Launch2TradingHold hold)
        Launch2TradingHoldBanner(hold: hold),
      if (capability.evidencePending && !paused)
        const LoopInlineUnavailable(
          key: ValueKey<String>('launch2-evidence-pending'),
          icon: 'info',
          message: '测试网合约还在核对，交易可能暂时不可用',
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
            children: _stageContent(detail),
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
        title: '项目已暂停',
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

  List<Widget> _stageContent(Launch2InstanceDetail detail) {
    // Decision 0157: only a graduated pool has a Hook kind; the read is not
    // made for any other stage, and `null` (OfficialTax, unknown, absent
    // adapter) draws the S146 page unchanged.
    final kind = detail.stage == Launch2Stage.graduated
        ? launch2PoolKindOf(ref, detail.instanceId)
        : null;
    return _stageWidgets(
      detail,
      kind is Launch2LoopDynamicPool ? kind.state : null,
      dynamicBlocked: switch (kind) {
        // Decision 0159: a LoopDynamic Hook that cannot be read now never
        // falls back to the OfficialTax panel.
        Launch2LoopDynamicUnavailable(:final reasonCode) =>
          launch2PoolReasonText(reasonCode),
        Launch2LoopDynamicNotGraduated() => '外盘池子正在同步，请稍后再试',
        _ => null,
      },
    );
  }

  List<Widget> _stageWidgets(
    Launch2InstanceDetail detail,
    Launch2DynamicPoolState? dynamicPool, {
    String? dynamicBlocked,
  }) => switch (detail.stage) {
    Launch2Stage.upcoming => <Widget>[
      _Figures(
        keyName: 'launch2-upcoming',
        rows: <(String, String)>[
          ('开售时间', loopDateTimeLabel(detail.row.nftSale.startAt)),
          ('NFT 价格', launch2Usd1Label(detail.row.nftSale.priceUsd1)),
          ('发售时长', _durationLabel(detail.row.nftSale)),
        ],
      ),
      _TemplateCard(detail: detail),
    ],
    Launch2Stage.nftSale => <Widget>[_NftSaleBlock(detail: detail)],
    Launch2Stage.snapshotPending => <Widget>[
      LoopEmptyState(
        key: const ValueKey<String>('launch2-snapshot-pending'),
        illustration: LoopIllustration.holders,
        title: launch2SnapshotPendingTitle(detail.snapshot),
        message: launch2SnapshotPendingMessage(detail.snapshot),
        compact: true,
      ),
      _Figures(
        keyName: 'launch2-snapshot-figures',
        rows: <(String, String)>[
          ('NFT 已售', '${detail.row.nftSale.soldCount} 枚'),
          (
            '我的 NFT',
            detail.viewer == null ? '未激活钱包' : '${detail.viewer!.nftHeld} / 1',
          ),
        ],
      ),
    ],
    Launch2Stage.closedNoHolders => <Widget>[_ClosedBlock(detail: detail)],
    Launch2Stage.priority || Launch2Stage.public => <Widget>[
      if (detail.stage == Launch2Stage.public &&
          detail.snapshot.openedWithoutHolders != null)
        const LoopNotice(
          key: ValueKey<String>('launch2-opened-without-holders'),
          icon: 'info',
          // Decision 0149: one line at 360–412 dp (「卖。」 was left alone on a
          // second line); 「人人可买」 is already the stage bar's line.
          body: '$launch2OpenedWithoutHoldersText，跳过提前购。',
        ),
      _CurveBlock(detail: detail),
      Launch2TradePanel(
        key: ValueKey<String>('launch2-panel-${detail.instanceId}'),
        detail: detail,
        walletId: memeReadActiveWallet(ref).walletId ?? detail.viewer?.walletId,
        locked: _pending?.locked ?? false,
        onPrepared: (intent) => _sign(detail, intent),
        onTopUp: () => _openTopUp(detail),
        onFaucet: _faucetAction(detail),
        onStageMoved: () => unawaited(
          ref
              .read(
                launch2InstanceControllerProvider(detail.instanceId).notifier,
              )
              .reload(),
        ),
      ),
      _RecentTrades(detail: detail),
    ],
    Launch2Stage.graduated => <Widget>[
      _GraduatedBlock(detail: detail),
      if (dynamicPool != null)
        Launch2DynamicRoundCard(
          state: dynamicPool,
          observedAt: ref
              .read(
                launch2PoolKindControllerProvider(detail.instanceId).notifier,
              )
              .valueObservedAt,
          onOpenRewards: () =>
              _open(Launch2Route.dynamicRewards(detail.instanceId)),
        ),
      Launch2PoolStats(detail: detail),
      if (dynamicBlocked != null)
        Launch2DynamicUnavailableBlock(
          reason: dynamicBlocked,
          onRetry: () => unawaited(
            ref
                .read(
                  launch2PoolKindControllerProvider(detail.instanceId).notifier,
                )
                .reload(),
          ),
        )
      else
        Launch2PoolTradePanel(
          key: ValueKey<String>('launch2-pool-panel-${detail.instanceId}'),
          detail: detail,
          walletId:
              memeReadActiveWallet(ref).walletId ?? detail.viewer?.walletId,
          locked: _pending?.locked ?? false,
          onPrepared: (intent, refresh) =>
              _sign(detail, intent, refresh: refresh),
          onTopUp: () => _openTopUp(detail),
          onFaucet: _faucetAction(detail),
          dynamicPool: dynamicPool,
        ),
      _MyPoolTrades(
        detail: detail,
        walletId: memeReadActiveWallet(ref).walletId ?? detail.viewer?.walletId,
      ),
      // Decision 0157: a LoopDynamic Hook credits rewards only to buys it
      // can attribute; the wallet Swap may route elsewhere, so the link is
      // not offered there.
      if (dynamicPool == null && dynamicBlocked == null)
        Launch2PoolSwapLink(
          onOpen: () => _open(
            Launch2Route.swap(
              chainId: detail.row.chainId,
              memeAddress: detail.row.memeAddress,
            ),
          ),
        ),
      _BuybackPanel(detail: detail),
    ],
    Launch2Stage.paused => <Widget>[_TemplateCard(detail: detail)],
  };

  static String _durationLabel(Launch2NftSale sale) {
    final hours = sale.endAt.difference(sale.startAt).inMinutes / 60;
    if (hours >= 24 && hours % 24 == 0) return '${hours ~/ 24} 天';
    if (hours == hours.roundToDouble()) return '${hours.toInt()} 小时';
    return '${sale.endAt.difference(sale.startAt).inMinutes} 分钟';
  }
}

class _BarShell extends StatelessWidget {
  const _BarShell({required this.child, this.failure});

  final Widget child;

  /// The last refusal of [child]'s action, directly above it, so it shows
  /// wherever the page is scrolled (decision 0153).
  final Widget? failure;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: LoopColors.ink,
      border: Border(top: BorderSide(color: LoopColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (failure case final Widget line) ...<Widget>[
              line,
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    ),
  );
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
        const LoopBadge('你是项目方', kind: LoopBadgeKind.launch),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '你看到的是用户看到的项目页',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
        ),
      ],
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity({required this.detail, required this.onCopy});

  final Launch2InstanceDetail detail;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey<String>('launch2-identity'),
    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
    child: Row(
      children: <Widget>[
        MemeLogo(
          symbol: detail.row.ticker,
          imageUrl: detail.row.logoUrl,
          identity: detail.instanceId,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                detail.row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.titleLg,
              ),
              Text(
                launch2ShortAddress(detail.row.memeAddress),
                style: LoopType.codeSm.copyWith(color: LoopColors.text2),
              ),
            ],
          ),
        ),
        LoopIconButton(
          key: const ValueKey<String>('launch2-copy-address'),
          icon: 'copy',
          label: '复制代币地址',
          onPressed: onCopy,
        ),
      ],
    ),
  );
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
          const LoopEmptyState(
            illustration: LoopIllustration.holders,
            title: launch2ClosedNoHoldersText,
            message:
                'NFT 发售结束时没有人认购。这个项目使用旧版合约，'
                '名单无法生成，提前购和公开内盘不会开始。',
            compact: true,
          ),
          _Figures(
            keyName: 'launch2-closed-figures',
            rows: <(String, String)>[
              ('NFT 已售', '${detail.row.nftSale.soldCount} 枚'),
              if (closure != null) ...<(String, String)>[
                (
                  '截止块',
                  '#${loopGroupedFigure(closure.cutoffBlock.toString())}',
                ),
                ('关闭时间', loopDateTimeLabel(closure.closedAt)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The stage and its countdown, the page's one moving figure.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.detail, required this.onElapsed});

  final Launch2InstanceDetail detail;
  final VoidCallback onElapsed;

  @override
  Widget build(BuildContext context) {
    final stage = detail.stage;
    final next = detail.row.nextChangeAt;
    final live =
        stage == Launch2Stage.nftSale ||
        stage == Launch2Stage.priority ||
        stage == Launch2Stage.public;
    return Padding(
      key: const ValueKey<String>('launch2-stage-bar'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: const BoxDecoration(
          color: LoopColors.card,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: live
                    ? LoopColors.lime
                    : stage == Launch2Stage.paused
                    ? LoopColors.warning
                    : LoopColors.text3,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    launch2StageLabel(stage),
                    key: const ValueKey<String>('launch2-stage-label'),
                    style: LoopTypography.title(16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    launch2StageCaption(stage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.caption.copyWith(color: LoopColors.text2),
                  ),
                ],
              ),
            ),
            if (next != null)
              Launch2Countdown(
                target: next,
                onElapsed: onElapsed,
                style: LoopTypography.figure(20, weight: FontWeight.w700),
              ),
          ],
        ),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.info, this.trailing});

  final String title;
  final Widget? info;

  /// A quiet figure at the end of the heading.
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 16, 4, 4),
    child: Row(
      children: <Widget>[
        Text(title, style: launch2PanelHeadingStyle),
        const Spacer(),
        if (trailing case final String text)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              text,
              style: LoopType.caption.copyWith(color: LoopColors.text2),
            ),
          ),
        ?info,
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
        _SectionHeading(
          title: '发射规则',
          info: LoopIconButton(
            key: const ValueKey<String>('launch2-template-info'),
            icon: 'info',
            label: '关于发射规则',
            color: LoopColors.text2,
            onPressed: () => unawaited(
              showLoopInfoSheet(
                context,
                title: '发射规则',
                sheetKey: 'launch2-template-sheet',
                notes: <LoopInfoNote>[
                  const LoopInfoNote(
                    title: '由平台模板固定',
                    body: '每个 v2 项目用同一套参数，项目方不能修改。',
                  ),
                  LoopInfoNote(
                    title: '三段发售',
                    body:
                        'NFT 发售（${launch2Usd1Label(t.nftPriceUsd1)} 一枚，每个地址终身 1 枚）→ '
                        '快照名单与 1 小时提前购 → 公开内盘。任何一轮卖满 '
                        '${launch2MemeCompact(t.curveSaleSupply)} 枚即自动建官方池毕业。',
                  ),
                  const LoopInfoNote(
                    key: ValueKey<String>('launch2-template-risk'),
                    title: '风险',
                    body: '$launch2NftRiskSentence。',
                  ),
                ],
              ),
            ),
          ),
        ),
        LoopKeyValue(label: '总量', value: launch2MemeCompact(t.memeTotalSupply)),
        LoopKeyValue(label: '内盘', value: launch2MemeCompact(t.curveSaleSupply)),
        LoopKeyValue(
          label: '毕业储备',
          value: launch2Usd1Label(
            t.graduationReserveUsd1,
            maxFractionDigits: 3,
          ),
        ),
        LoopKeyValue(label: '内盘买卖税', value: launch2BpsLabel(t.curveBuyTaxBps)),
        LoopKeyValue(
          label: '外盘税',
          value: launch2BpsLabel(t.officialPoolTaxBps),
        ),
        LoopKeyValue(
          label: '单地址上限',
          value:
              '${launch2MemeCompact(t.perAddressCap)}（${launch2BpsLabel(t.perAddressCapBps)}）',
        ),
      ],
    );
  }
}

class _NftSaleBlock extends StatelessWidget {
  const _NftSaleBlock({required this.detail});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final sale = detail.row.nftSale;
    final viewer = detail.viewer;
    return Column(
      key: const ValueKey<String>('launch2-nft-sale'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                launch2Usd1Label(sale.priceUsd1),
                key: const ValueKey<String>('launch2-nft-price'),
                style: LoopType.figureXl,
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ 枚',
                  style: LoopType.caption.copyWith(color: LoopColors.text2),
                ),
              ),
              const Spacer(),
              LoopIconButton(
                key: const ValueKey<String>('launch2-nft-info'),
                icon: 'info',
                label: '关于项目 NFT',
                color: LoopColors.text2,
                onPressed: () => unawaited(
                  showLoopInfoSheet(
                    context,
                    title: '项目 NFT',
                    sheetKey: 'launch2-nft-sheet',
                    notes: const <LoopInfoNote>[
                      LoopInfoNote(
                        body:
                            '每个地址终身只能买 1 枚。发售结束时持有 NFT 的地址进入快照名单，'
                            '名单发布后有 1 小时提前购。',
                      ),
                      LoopInfoNote(
                        key: ValueKey<String>('launch2-nft-risk-note'),
                        title: '风险',
                        body: '$launch2NftRiskSentence。',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        LoopKeyValue(
          key: const ValueKey<String>('launch2-nft-held'),
          label: '我的持有',
          value: viewer == null ? '未激活钱包' : '${viewer.nftHeld} / 1',
        ),
        LoopKeyValue(
          key: const ValueKey<String>('launch2-nft-sold'),
          label: '已售',
          value: '${sale.soldCount} 枚',
        ),
        LoopKeyValue(label: '截止', value: loopDateTimeLabel(sale.endAt)),
      ],
    );
  }
}

class _CurveBlock extends StatelessWidget {
  const _CurveBlock({required this.detail});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final curve = detail.row.curve;
    final viewer = detail.viewer;
    return Padding(
      key: const ValueKey<String>('launch2-curve'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            launch2PriceLabel(curve.priceUsd1),
            key: const ValueKey<String>('launch2-curve-price'),
            style: LoopType.figureXl,
          ),
          const SizedBox(height: 2),
          Text(
            '当前价 · USD1',
            style: LoopType.caption.copyWith(color: LoopColors.text3),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                '内盘进度',
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
              const Spacer(),
              Text(
                '${launch2BpsLabel(curve.soldBps)} · '
                '${launch2MemeCompact(curve.soldSupply)} / '
                '${launch2MemeCompact(curve.saleSupply)}',
                key: const ValueKey<String>('launch2-curve-progress'),
                style: LoopTypography.figure(13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LoopProgressBar(
            value: launch2Fraction(curve.soldBps),
            semanticLabel: '内盘进度 ${launch2BpsLabel(curve.soldBps)}',
          ),
          if (viewer != null && viewer.curve.net > Decimal.zero) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '我的内盘持仓 ${launch2MemeLabel(viewer.curve.net, detail.row.ticker)}',
              key: const ValueKey<String>('launch2-curve-holding'),
              style: LoopType.body.copyWith(color: LoopColors.text2),
            ),
          ],
        ],
      ),
    );
  }
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
        const _SectionHeading(title: '最新成交'),
        if (trades.isEmpty)
          const LoopEmptyState(
            key: ValueKey<String>('launch2-trades-empty'),
            illustration: LoopIllustration.chartEmpty,
            title: '还没有成交',
            compact: true,
          )
        else
          for (final trade in trades)
            LoopKeyValue(
              key: ValueKey<String>('launch2-trade-${trade.tradeId}'),
              label:
                  '${trade.side == Launch2Side.buy ? '买入' : '卖出'} · '
                  '${launch2ShortAddress(trade.traderAddress)}',
              value:
                  '${launch2MemeCompact(trade.memeAmount)} · '
                  '${launch2Usd1Label(trade.usd1Gross)}',
              valueUp: trade.side == Launch2Side.buy,
            ),
        LoopProvenanceLine(
          key: const ValueKey<String>('launch2-trades-provenance'),
          sources: const <String>['LOOP 链上索引'],
          observedAt: detail.projectedAt,
          padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 6, 16, 4),
          detail: '最近 20 笔内盘成交，金额含 10% 税。',
        ),
      ],
    );
  }
}

/// 我的外盘成交 (decision 0148): the wallet's own last five official-pool
/// trades, read only once the viewer says it has any
/// (`viewer.poolTradeCount`, loop-api S150) and again whenever that count
/// moves. A failed read is one quiet line; nothing is drawn before the
/// first trade or from a server without the count.
class _MyPoolTrades extends ConsumerWidget {
  const _MyPoolTrades({required this.detail, required this.walletId});

  final Launch2InstanceDetail detail;
  final String? walletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = detail.viewer?.holding?.poolTradeCount;
    final wallet = walletId;
    if (count == null || count == BigInt.zero || wallet == null) {
      return const SizedBox.shrink();
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
    return Column(
      key: const ValueKey<String>('launch2-my-pool-trades'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeading(
          title: '我的外盘成交',
          trailing: '共 ${loopGroupedFigure(count.toString())} 笔',
        ),
        if (page == null)
          state.phase == LoopChainViewPhase.loading
              ? const LoopSkeleton(
                  key: ValueKey<String>('launch2-my-pool-trades-loading'),
                  type: LoopSkeletonType.list,
                  rows: 2,
                )
              : LoopInlineUnavailable(
                  key: const ValueKey<String>('launch2-my-pool-trades-failed'),
                  message:
                      '我的外盘成交暂时读不到 · '
                      '${loopChainFailureReason(state.failureKind)}',
                  onRetry: () =>
                      unawaited(ref.read(provider.notifier).reload()),
                )
        else if (page.trades.isEmpty)
          const LoopInlineUnavailable(
            key: ValueKey<String>('launch2-my-pool-trades-empty'),
            icon: 'info',
            message: '成交还在同步，稍后刷新',
          )
        else
          for (final trade in page.trades.take(launch2PoolTradesShown))
            LoopKeyValue(
              key: ValueKey<String>(
                'launch2-my-pool-trade-${trade.poolTradeId}',
              ),
              label:
                  '${trade.side == Launch2Side.buy ? '买入' : '卖出'} · '
                  '${loopDateTimeLabel(trade.tradedAt)}',
              value: launch2PoolTradeFigure(trade, ticker),
              valueUp: trade.side == Launch2Side.buy,
            ),
        if (page != null)
          LoopProvenanceLine(
            key: const ValueKey<String>('launch2-my-pool-trades-provenance'),
            sources: const <String>['LOOP 链上索引'],
            observedAt: ref.read(provider.notifier).valueObservedAt,
            padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 6, 16, 4),
            detail: '只含经官方池路由成交的记录，最近 $launch2PoolTradesShown 笔；数量已扣 2% 外盘税。',
          ),
      ],
    );
  }
}

class _GraduatedBlock extends StatelessWidget {
  const _GraduatedBlock({required this.detail});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final graduation = detail.graduation;
    return Column(
      key: const ValueKey<String>('launch2-graduated'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeading(
          title: '官方池',
          info: LoopIconButton(
            key: const ValueKey<String>('launch2-pool-info'),
            icon: 'info',
            label: '关于官方池',
            color: LoopColors.text2,
            onPressed: () => unawaited(
              showLoopInfoSheet(
                context,
                title: '官方池',
                sheetKey: 'launch2-pool-sheet',
                notes: <LoopInfoNote>[
                  if (graduation != null) ...<LoopInfoNote>[
                    LoopInfoNote(
                      key: const ValueKey<String>('launch2-pool-id'),
                      title: '池 ID（Uniswap v4，没有池地址）',
                      body: graduation.officialPoolId,
                    ),
                    LoopInfoNote(title: 'Hook', body: graduation.hookAddress),
                    LoopInfoNote(
                      title: '费率',
                      body:
                          'LP 费 ${launch2BpsLabel(graduation.lpFee ~/ 100)}，'
                          'tickSpacing ${graduation.tickSpacing}',
                    ),
                  ],
                  LoopInfoNote(
                    key: const ValueKey<String>('launch2-pool-tax'),
                    title:
                        '外盘税 ${launch2BpsLabel(graduation?.officialPoolTaxBps ?? detail.template.officialPoolTaxBps)}',
                    body: '在官方池买卖都收取，由 Hook 计入回购托管，用来按规则回购。',
                  ),
                ],
              ),
            ),
          ),
        ),
        LoopKeyValue(
          label: '毕业时间',
          value: graduation == null
              ? '读取中'
              : loopDateTimeLabel(graduation.graduatedAt),
        ),
        LoopKeyValue(
          label: '毕业价',
          value: launch2PriceLabel(detail.row.curve.priceUsd1),
        ),
        LoopKeyValue(
          label: '外盘税',
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
      label: line.text.replaceAll('\n', '，'),
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
        _SectionHeading(
          title: '回购',
          info: LoopIconButton(
            key: const ValueKey<String>('launch2-buyback-info'),
            icon: 'info',
            label: '关于回购',
            color: LoopColors.text2,
            onPressed: () => unawaited(
              showLoopInfoSheet(
                context,
                title: '回购',
                sheetKey: 'launch2-buyback-sheet',
                notes: <LoopInfoNote>[
                  const LoopInfoNote(
                    key: ValueKey<String>('launch2-buyback-not-burn'),
                    title: '回购不等于销毁',
                    body: '回购买到的代币转给项目登记的收币地址，不会销毁。',
                  ),
                  LoopInfoNote(
                    title: '规则',
                    body:
                        '每笔 ${launch2Usd1Label(detail.template.buybackOrderUsd1)}，'
                        '两笔间隔至少 ${detail.template.buybackMinIntervalSeconds} 秒；'
                        '官方池 USD1 本金不足 10,000 或单笔超过本金 1% 时不执行，'
                        '被拒的尝试不留记录。',
                  ),
                  LoopInfoNote(title: '收币地址', body: summary.recipient),
                ],
              ),
            ),
          ),
        ),
        LoopKeyValue(
          key: const ValueKey<String>('launch2-buyback-escrow'),
          label: '托管余额',
          value: launch2Usd1Label(
            live?.escrowAvailableUsd1 ?? summary.escrowAvailableUsd1,
          ),
        ),
        LoopKeyValue(
          key: const ValueKey<String>('launch2-buyback-total'),
          label: '累计回购',
          value:
              '${launch2Usd1Label(summary.totalUsd1)} · ${summary.executedCount} 笔',
        ),
        LoopKeyValue(
          key: const ValueKey<String>('launch2-buyback-latest'),
          label: '最近一笔',
          value: latest == null
              ? '还没有'
              : '${loopDateTimeLabel(latest.executedAt)} · '
                    '${launch2Usd1Label(latest.usd1Spent)} · '
                    '${latest.executed ? '成交' : launch2BuybackBlockedText(latest.reasonCode)}',
        ),
        if (held != null)
          _BuybackHeldRow(
            key: const ValueKey<String>('launch2-buyback-held'),
            line: held,
          )
        else if (page != null && live != null)
          LoopKeyValue(
            key: const ValueKey<String>('launch2-buyback-next'),
            label: '下一笔',
            value: launch2BuybackBlockedText(live.nextOrderBlockedReason),
          )
        else if (page?.liveUnavailableReason case final String reason)
          LoopInlineUnavailable(
            key: const ValueKey<String>('launch2-buyback-live-unavailable'),
            message: '链上实时读数暂时取不到 · ${launch2ReasonText(reason)}',
          )
        else if (page == null &&
            state.phase != LoopChainViewPhase.loading &&
            state.failureKind != null)
          LoopInlineUnavailable(
            key: const ValueKey<String>('launch2-buyback-unavailable'),
            message: '回购明细暂时读不到 · ${loopChainFailureReason(state.failureKind)}',
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
          const LoopInlineUnavailable(
            key: ValueKey<String>('launch2-buyback-paused'),
            icon: 'info',
            message: '回购已暂停',
          ),
      ],
    );
  }
}
