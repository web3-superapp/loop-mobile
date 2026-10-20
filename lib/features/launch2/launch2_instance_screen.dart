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
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_mint.dart';
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
import 'package:loop_mobile/widgets/loop_pressable.dart';
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
      confirmation: launch2ReadModelConfirmation(ref, detail, intent),
    );
    if (!mounted || outcome == null) return;
    _record(detail, intent, outcome);
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
          LoopEmptyState(
            key: ValueKey<String>('launch2-invalid-identity'),
            illustration: LoopIllustration.launchpad,
            title: '路由中没有可用的项目标识',
            message: '没有请求任何数据，也没有回退到其他项目。',
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
      title: detail == null ? 'MEME v2' : loopTickerLabel(detail.row.ticker),
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
                ? '已持有勋章'
                : _preparingNft
                ? '正在准备…'
                : '铸造勋章',
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
      _InstanceFolio(
        detail: detail,
        onCopy: () => unawaited(
          LoopCopy.text(context, detail.row.memeAddress, message: '已复制代币地址'),
        ),
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
      if (launch2EvidenceNoticeShown(capability) && !paused)
        const LoopInlineUnavailable(
          key: ValueKey<String>('launch2-evidence-pending'),
          icon: 'info',
          message: '合约核对中，交易可能暂时不可用',
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
      const LoopLabel('勋章铸造'),
      _Figures(
        keyName: 'launch2-upcoming',
        rows: <(String, String)>[
          ('铸造开始', loopDateTimeLabel(detail.row.nftSale.startAt)),
          ('铸造价格', launch2Usd1Label(detail.row.nftSale.priceUsd1)),
          ('铸造时长', launch2SaleDurationLabel(detail.row.nftSale)),
        ],
      ),
      _TemplateCard(detail: detail),
    ],
    Launch2Stage.nftSale => <Widget>[
      _NftSaleBlock(
        detail: detail,
        onOpenMintPage: () => _open(Launch2Route.nft(detail.instanceId)),
      ),
    ],
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
          ('已铸', '${detail.row.nftSale.soldCount} 枚'),
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
      // Decision 0202: the published list, without its addresses.
      if (launch2SnapshotPublishedShown(detail))
        Launch2SnapshotPublishedBlock(detail: detail),
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
      if (dynamicPool != null)
        Launch2DynamicFeeSummaryCard(
          state: dynamicPool,
          ticker: detail.row.ticker,
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
      if (launch2SnapshotPublishedShown(detail))
        Launch2SnapshotPublishedBlock(detail: detail),
    ],
    Launch2Stage.paused => <Widget>[_TemplateCard(detail: detail)],
  };
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

/// Whether the folio heading carries the accent: the stage takes orders,
/// mints, or trades in the official pool (decision 0166). Every waiting or
/// held stage is stated in Chalk.
bool launch2InstanceHeadingLit(Launch2Stage stage) => switch (stage) {
  Launch2Stage.nftSale ||
  Launch2Stage.priority ||
  Launch2Stage.public ||
  Launch2Stage.graduated => true,
  Launch2Stage.upcoming ||
  Launch2Stage.snapshotPending ||
  Launch2Stage.closedNoHolders ||
  Launch2Stage.paused => false,
};

/// The words before the folio stamp's countdown (decision 0166).
String launch2InstanceStampPrefix(Launch2Stage stage) =>
    stage == Launch2Stage.upcoming ? '距铸造 ' : '剩 ';

/// The folio caption (decision 0166): the project's name, then the stage's
/// line without the countdown words the stamp now carries.
String launch2InstanceFolioCaption(Launch2InstanceDetail detail) {
  final row = detail.row;
  final line = switch (row.stage) {
    Launch2Stage.upcoming =>
      '${launch2Usd1Label(row.nftSale.priceUsd1)} / 枚 · '
          '铸造期 ${launch2SaleDurationLabel(row.nftSale)}',
    Launch2Stage.nftSale => '每地址 1 枚 · 已铸 ${row.nftSale.soldCount} 枚',
    Launch2Stage.priority => '持有人优先',
    Launch2Stage.snapshotPending ||
    Launch2Stage.closedNoHolders ||
    Launch2Stage.public ||
    Launch2Stage.graduated ||
    Launch2Stage.paused => launch2StageCaption(row.stage),
  };
  return '${row.name} · $line';
}

/// `.ledger-card.ledger-quiet.folio-primary` (decision 0166, after the
/// 共识勋章 page of decision 0164): the stage as the kicker, the ticker as the
/// heading with the logo beside it, the name and the stage's line as the
/// caption, the token address under it and the countdown in the stamp. It
/// takes the place of decision 0163's identity row and grey stage bar; the
/// stamp is the page's one moving figure and only it redraws every second.
class _InstanceFolio extends StatelessWidget {
  const _InstanceFolio({
    required this.detail,
    required this.onCopy,
    required this.onElapsed,
  });

  final Launch2InstanceDetail detail;
  final VoidCallback onCopy;
  final VoidCallback onElapsed;

  @override
  Widget build(BuildContext context) {
    final row = detail.row;
    final next = row.nextChangeAt;
    Widget folio(String? stamp) => LoopFolioPrimary(
      key: const ValueKey<String>('launch2-instance-folio'),
      archetype: LoopFolioArchetype.record,
      ring: false,
      headingTone: launch2InstanceHeadingLit(row.stage)
          ? LoopFolioHeadingTone.accent
          : LoopFolioHeadingTone.neutral,
      kicker: launch2InstanceStageLabel(detail),
      heading: launch2HeroTicker(row.ticker),
      headingMaxLines: 1,
      trailing: MemeLogo(
        symbol: row.ticker,
        imageUrl: row.logoUrl,
        identity: detail.instanceId,
      ),
      caption: launch2InstanceFolioCaption(detail),
      captionMaxLines: 3,
      footer: Row(
        key: const ValueKey<String>('launch2-identity'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              launch2ShortAddress(row.memeAddress),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopType.codeSm.copyWith(color: LoopColors.text2),
            ),
          ),
          LoopIconButton(
            key: const ValueKey<String>('launch2-copy-address'),
            icon: 'copy',
            label: '复制代币地址',
            color: LoopColors.text2,
            onPressed: onCopy,
          ),
        ],
      ),
      stamp: stamp,
    );
    if (next == null) return folio(null);
    final prefix = launch2InstanceStampPrefix(row.stage);
    return KeyedSubtree(
      key: const ValueKey<String>('launch2-countdown'),
      child: Launch2CountdownBuilder(
        target: next,
        onElapsed: onElapsed,
        builder: (context, text) => folio('$prefix$text'),
      ),
    );
  }
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
                '铸造期内没有人铸造。这个项目使用旧版合约，'
                '名单无法生成，提前购和公开内盘不会开始。',
            compact: true,
          ),
          _Figures(
            keyName: 'launch2-closed-figures',
            rows: <(String, String)>[
              ('已铸', '${detail.row.nftSale.soldCount} 枚'),
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
          '发射规则',
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
                    title: '三段发射',
                    body:
                        '勋章铸造（${launch2Usd1Label(t.nftPriceUsd1)} 一枚，每个地址终身 1 枚）→ '
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
              // Decision 0197: the instance's own cap, whole tokens.
              '${launch2CurveCapFigure(t.perAddressCap)} 枚（${launch2BpsLabel(t.perAddressCapBps)}）',
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
        ? '读取中'
        : '已过 ${(elapsed * 100).floor()}%';
    return Column(
      key: const ValueKey<String>('launch2-nft-sale'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Launch2SectionLabel(
          '项目 NFT',
          info: LoopIconButton(
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
                        '每个地址终身只能铸 1 枚。铸造结束时持有勋章的地址进入快照名单，'
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
        ),
        MemeStatFigures(
          hero: true,
          stats: <LoopStat>[
            LoopStat(
              label: '价格 / 枚',
              value: launch2Usd1Label(sale.priceUsd1),
              statKey: const ValueKey<String>('launch2-nft-price'),
            ),
            LoopStat(
              label: '已铸',
              value: '${sale.soldCount} 枚',
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
                  Text(
                    '铸造进度',
                    style: LoopType.captionSm.copyWith(color: LoopColors.text2),
                  ),
                  const Spacer(),
                  Text(elapsedText, style: LoopType.figure),
                ],
              ),
              const SizedBox(height: 11),
              LoopProgressBar(
                value: elapsed,
                semanticLabel: '铸造时间$elapsedText',
              ),
              const SizedBox(height: 3),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '截止 ${loopDateTimeLabel(sale.endAt)}',
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
          label: '我的持有',
          value: viewer == null ? '未激活钱包' : '${viewer.nftHeld} / 1',
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
    label: '铸造页',
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
                '铸造页',
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

/// 内盘 (decision 0166): the current price (and this wallet's curve
/// position) as a `.stat-grid`, the share sold as a `.record-card` with its
/// 6 px `.bar`.
class _CurveBlock extends StatelessWidget {
  const _CurveBlock({required this.detail});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final curve = detail.row.curve;
    final viewer = detail.viewer;
    final holding = viewer != null && viewer.curve.net > Decimal.zero
        ? viewer.curve.net
        : null;
    return Column(
      key: const ValueKey<String>('launch2-curve'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('内盘'),
        MemeStatFigures(
          hero: true,
          stats: <LoopStat>[
            LoopStat(
              label: '当前价 · USD1',
              value: launch2PriceLabel(curve.priceUsd1),
              statKey: const ValueKey<String>('launch2-curve-price'),
            ),
            if (holding != null)
              LoopStat(
                label: '我的内盘持仓',
                value: launch2MemeLabel(holding, detail.row.ticker),
                statKey: const ValueKey<String>('launch2-curve-holding'),
              )
            else
              LoopStat(label: '内盘已售', value: launch2BpsLabel(curve.soldBps)),
          ],
        ),
        LoopRecordCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '内盘进度',
                    style: LoopType.captionSm.copyWith(color: LoopColors.text2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${launch2BpsLabel(curve.soldBps)} · '
                      '${launch2MemeCompact(curve.soldSupply)} / '
                      '${launch2MemeCompact(curve.saleSupply)}',
                      key: const ValueKey<String>('launch2-curve-progress'),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopType.figure,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              LoopProgressBar(
                value: launch2Fraction(curve.soldBps),
                semanticLabel: '内盘进度 ${launch2BpsLabel(curve.soldBps)}',
              ),
              const SizedBox(height: 7),
              Text(
                '卖满 ${launch2MemeCompact(curve.saleSupply)} 自动建官方池毕业',
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One curve trade. S239: with the trader's LOOP account attached (loop-api
/// decision 0162 §A) the line names the account and its face opens the
/// account's page; a bare address opens nothing.
Widget _tradeRow(Launch2Trade trade) {
  final account = trade.account;
  final side = trade.side == Launch2Side.buy ? '买入' : '卖出';
  final value =
      '${launch2MemeCompact(trade.memeAmount)} · '
      '${launch2Usd1Label(trade.usd1Gross)}';
  if (account == null) {
    return LoopKeyValue(
      key: ValueKey<String>('launch2-trade-${trade.tradeId}'),
      label: '$side · ${launch2ShortAddress(trade.traderAddress)}',
      value: value,
      valueUp: trade.side == Launch2Side.buy,
    );
  }
  final name = account.displayName ?? launch2ShortAddress(trade.traderAddress);
  return Row(
    key: ValueKey<String>('launch2-trade-${trade.tradeId}'),
    children: <Widget>[
      const SizedBox(width: LoopSpacing.page - 8),
      LoopProfileFaceLink(
        key: ValueKey<String>('launch2-trade-face-${trade.tradeId}'),
        publicProfileId: account.publicProfileId,
        name: name,
        child: LoopProfileAvatar(
          avatarRef: account.avatarRef,
          alias: account.displayName,
          size: 24,
        ),
      ),
      Expanded(
        child: LoopKeyValue(
          label: '$side · $name',
          value: value,
          valueUp: trade.side == Launch2Side.buy,
          padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
        ),
      ),
    ],
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
        const LoopLabel('最新成交'),
        if (trades.isEmpty)
          const LoopEmptyState(
            key: ValueKey<String>('launch2-trades-empty'),
            illustration: LoopIllustration.chartEmpty,
            title: '还没有成交',
            compact: true,
          )
        else
          for (final trade in trades) _tradeRow(trade),
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
        Launch2SectionLabel(
          '我的外盘成交',
          trailing: Text(
            '共 ${loopGroupedFigure(count.toString())} 笔',
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
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
        Launch2SectionLabel(
          '官方池',
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
/// 「最近一笔」 value (S257): `MM-DD HH:mm，100 USD1，成交` in local time.
/// The year is dropped and the parts are joined with 「，」 rather than
/// middle dots (docs/42 附C) so the line fits one row at 360–430 wide.
String launch2BuybackLatestText({
  required DateTime executedAt,
  required Decimal usd1Spent,
  required String outcome,
}) {
  final local = executedAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}，'
      '${launch2Usd1Label(usd1Spent)}，$outcome';
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
            '最近一笔',
            style: LoopType.captionSm.copyWith(color: LoopColors.text2),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            key: const ValueKey<String>('launch2-buyback-latest-value'),
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
        Launch2SectionLabel(
          '回购',
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
        _BuybackLatestRow(
          key: const ValueKey<String>('launch2-buyback-latest'),
          value: latest == null
              ? '还没有'
              : launch2BuybackLatestText(
                  executedAt: latest.executedAt,
                  usd1Spent: latest.usd1Spent,
                  outcome: latest.executed
                      ? '成交'
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
