import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/qr/loop_qr_code.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/meme/meme_controllers.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_launchpad.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_routes.dart';
import 'package:loop_mobile/features/meme/meme_signing.dart';
import 'package:loop_mobile/features/meme/meme_trade_panel.dart';
import 'package:loop_mobile/features/meme/meme_wallet.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/features/social/qr/loop_qr_card.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/sharing/system_text_share.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';

/// The three tabs under the chart, in the reference's order.
enum MemeTokenTab {
  holders('持有者'),
  activity('动态'),
  about('关于');

  const MemeTokenTab(this.label);

  final String label;
}

/// The token page's chart when fewer than two candles exist (decision 0121).
const String memeChartEmptyMessage = '还没有成交';

/// The chart's range chips under the plot (decision 0174, 代币页 B): each
/// names one bucket width the server already serves. 「ALL」 has no bucket of
/// its own and is not drawn; 5 / 15 minute buckets are no longer offered.
const List<(MemeCandleInterval, String)> memeChartRanges =
    <(MemeCandleInterval, String)>[
      (MemeCandleInterval.oneMinute, 'LIVE'),
      (MemeCandleInterval.oneHour, '1H'),
      (MemeCandleInterval.fourHours, '4H'),
      (MemeCandleInterval.oneDay, '1D'),
    ];

/// The token page's full-bleed chart height for a screen [screenHeight] tall
/// (decision 0174): 30% of it, held between 180 and 260 — 210 on a 700 pt
/// phone, as the design draws it.
double memeTokenChartHeight(double screenHeight) =>
    (screenHeight * 0.3).clamp(180.0, 260.0);

/// The badge beside the ticker in the bar.
String memeTokenStatusLabel(MemeTokenStatus status) => switch (status) {
  MemeTokenStatus.draft => '草稿',
  MemeTokenStatus.pendingChain => '创建中',
  MemeTokenStatus.trading => '内盘',
  MemeTokenStatus.full => '已打满',
  MemeTokenStatus.paused => '暂停',
  MemeTokenStatus.graduated => '已毕业',
};

/// The one-hour move as an amount: the price now less the price an hour
/// ago, where `now / (1 + pct/100)` is that earlier price. `null` when either
/// figure is missing or the percentage cannot describe a positive past price.
Decimal? memeChange1hAmount(Decimal? price, Decimal? changePct) {
  if (price == null || changePct == null) return null;
  final base = Decimal.fromInt(100) + changePct;
  if (base <= Decimal.zero) return null;
  return (price * changePct / base).toDecimal(scaleOnInfinitePrecision: 30);
}

/// Whether the curve's real USD1 reserve is under 5% of what it raises when
/// it fills (decision 0174): a large buy then moves the price a long way.
bool memeLiquidityLow(MemeTokenDetail detail) {
  if (detail.status != MemeTokenStatus.trading) return false;
  final target = detail.curve.fillTargetUsd1;
  if (target == null) return false;
  return detail.curve.realUsd1 * BigInt.from(20) < target;
}

/// `meme-token` · one MEME curve token (archetype `record`, layout
/// `dashboard`), drawn as the design's 代币页 B (decision 0174).
///
/// The bar carries the logo, the ticker with its state badge and the name ·
/// address line (tap to copy), and shares. Under it the price head — the
/// price, its one-hour move as an amount and a percentage, the market cap —
/// then the full-bleed Lime chart with its range chips, two stats (fill
/// progress and 24h volume) over the progress bar, then 持有者 N / 动态 /
/// 关于. The bottom bar follows the token's state (contract §10): one Lime
/// 买入 and the ⚡ 快买 key while trading (卖出 beside them once something is
/// held), a disabled line while full or paused, 「去兑换」 once graduated. A
/// full curve is re-read until it graduates, and the graduation is marked
/// once.
class MemeTokenScreen extends ConsumerStatefulWidget {
  const MemeTokenScreen({
    required this.memeTokenId,
    super.key,
    this.onNavigate,
    this.onBack,
    this.clock,
  });

  final String? memeTokenId;
  final void Function(String location)? onNavigate;
  final VoidCallback? onBack;
  final DateTime Function()? clock;

  /// The submission scope of one token's trades.
  static String tradeScope(String memeTokenId) => 'trade:$memeTokenId';

  @override
  ConsumerState<MemeTokenScreen> createState() => _MemeTokenScreenState();
}

class _MemeTokenScreenState extends ConsumerState<MemeTokenScreen> {
  MemeCandleInterval _interval = memeChartRanges.first.$1;
  MemeTokenTab _tab = MemeTokenTab.holders;
  Timer? _poll;
  bool _celebrate = false;

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
    context.push(location);
  }

  Future<void> _reloadAll(String id) async {
    await Future.wait(<Future<void>>[
      ref.read(memeTokenControllerProvider(id).notifier).reload(),
      ref.read(memeTradesControllerProvider(id).notifier).reload(),
      ref.read(memeHoldersControllerProvider(id).notifier).reload(),
      ref
          .read(
            memeCandlesControllerProvider(
              MemeCandleRequest(memeTokenId: id, interval: _interval),
            ).notifier,
          )
          .reload(),
    ]);
  }

  /// Re-reads a token whose state is about to move: one being created, one
  /// waiting for its graduation, or one a trade of ours is settling on.
  void _armPoll(String id, MemeTokenStatus status, bool settling) {
    final moving =
        status == MemeTokenStatus.pendingChain ||
        status == MemeTokenStatus.full ||
        settling;
    if (!moving) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    if (_poll != null) return;
    final interval = ref.read(memePollingProvider).tokenInterval;
    _poll = Timer(interval, () {
      _poll = null;
      if (!mounted) return;
      unawaited(ref.read(memeTokenControllerProvider(id).notifier).reload());
    });
  }

  Future<void> _trade(
    MemeTokenDetail detail,
    MemeTradeSide side, {
    String? initialAmount,
  }) async {
    final request = await showMemeTradePanel(
      context,
      detail: detail,
      side: side,
      initialAmount: initialAmount,
    );
    if (request == null || !mounted) return;
    if (request.side == MemeTradeSide.buy) {
      ref.read(memeQuickBuyAmountProvider.notifier).remember(request.amount);
    }
    final wallet = memeReadActiveWallet(ref);
    final walletId = wallet.walletId ?? detail.viewer?.walletId;
    if (walletId == null) {
      LoopToast.show(context, message: '还没有可用的钱包', kind: LoopToastKind.warn);
      return;
    }
    final submission = ref.read(
      memeSubmissionControllerProvider(
        MemeTokenScreen.tradeScope(detail.memeTokenId),
      ).notifier,
    );
    final intent = await submission.prepare(
      memeTokenId: detail.memeTokenId,
      kind: request.side == MemeTradeSide.buy
          ? MemeIntentKind.buy
          : MemeIntentKind.sell,
      walletId: walletId,
      usd1Amount: request.side == MemeTradeSide.buy ? request.amount : null,
      tokenAmount: request.side == MemeTradeSide.sell ? request.amount : null,
      slippageBps: request.slippageBps,
    );
    if (intent == null || !mounted) return;
    final outcome = await showMemeSignSheet(
      context,
      intent: intent,
      signer: ref.read(memeIntentSignerProvider),
      fromAddress: wallet.address,
      symbol: detail.row.symbol,
      clock: widget.clock,
    );
    if (!mounted) return;
    submission.recordOutcome(outcome);
  }

  Future<void> _copy(String text, String done) async {
    await LoopCopy.text(context, text, message: done);
  }

  Future<void> _share(MemeTokenDetail detail) async {
    final address = detail.row.tokenAddress ?? detail.predictedAddress;
    final text = <String>[
      '${detail.row.name} \$${detail.row.symbol}',
      if (address != null) '合约 $address',
      '在 LOOP 发射台查看',
    ].join('\n');
    await showLoopSheet<void>(
      context,
      builder: (context) => _MemeShareSheet(
        title: '${detail.row.name} \$${detail.row.symbol}',
        address: address,
        onCopy: () => unawaited(_copy(text, '已复制')),
        onShare: () async {
          final shown = await ref.read(loopTextShareProvider)(text);
          if (!shown && context.mounted) {
            LoopToast.show(
              context,
              message: '系统分享暂时打不开',
              kind: LoopToastKind.warn,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.memeTokenId;
    if (!MemeRoute.isTokenId(id)) {
      return LoopFocusPage(
        key: const ValueKey<String>('meme-token-invalid-route'),
        archetype: LoopPageArchetype.record,
        title: '无法打开这个代币',
        onBack: widget.onBack,
        body: const <Widget>[
          LoopEmptyState(
            key: ValueKey<String>('meme-token-invalid-identity'),
            illustration: LoopIllustration.launchpad,
            title: '路由中没有可用的代币标识',
            message: '没有请求任何数据，也没有回退到其他代币。',
            compact: true,
          ),
        ],
      );
    }
    final memeTokenId = id!;
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.meme),
    );
    final blocked = memeReadsBlocked(ref);
    final provider = memeTokenControllerProvider(memeTokenId);
    final state = blocked ? null : ref.watch(provider);
    if (state != null && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(ref.read(provider.notifier).load());
      });
    }
    final scope = MemeTokenScreen.tradeScope(memeTokenId);
    final submission = ref.watch(memeSubmissionControllerProvider(scope));
    ref.listen<MemeSubmissionState>(memeSubmissionControllerProvider(scope), (
      previous,
      next,
    ) {
      if (next.phase == MemeSubmissionPhase.confirmed &&
          previous?.phase != MemeSubmissionPhase.confirmed) {
        unawaited(_reloadAll(memeTokenId));
      }
    });
    ref.listen<LoopChainResourceState<MemeTokenDetail>>(provider, (
      previous,
      next,
    ) {
      final before = previous?.value?.status;
      final after = next.value?.status;
      if (before != null &&
          before != MemeTokenStatus.graduated &&
          after == MemeTokenStatus.graduated) {
        setState(() => _celebrate = true);
        unawaited(_reloadAll(memeTokenId));
      }
    });
    final detail = state?.value;
    if (detail != null) {
      _armPoll(memeTokenId, detail.status, submission.busy);
      // The wallet that signs is read before a trade is offered, so the
      // signing exit can compare it with the transaction's `from`.
      if (detail.status == MemeTokenStatus.trading) memeActiveWallet(ref);
    }

    final address = detail == null
        ? null
        : detail.row.tokenAddress ?? detail.predictedAddress;
    return LoopDashboardPage(
      key: ValueKey<String>('meme-token-screen-$memeTokenId'),
      archetype: LoopPageArchetype.record,
      title: detail == null ? '代币' : '\$${detail.row.symbol}',
      titleField: detail == null
          ? null
          : _TokenTitle(
              detail: detail,
              address: address,
              onCopy: address == null
                  ? null
                  : () => unawaited(_copy(address, '已复制合约地址')),
            ),
      onBack: widget.onBack,
      updating: state?.refreshing ?? false,
      onRefresh: blocked ? null : () => _reloadAll(memeTokenId),
      actions: <Widget>[
        if (detail != null)
          LoopIconButton(
            key: const ValueKey<String>('meme-token-share'),
            icon: 'share',
            label: '分享',
            onPressed: () => unawaited(_share(detail)),
          ),
      ],
      block: blocked
          ? LoopPageBlock(
              key: const ValueKey<String>('meme-token-blocked'),
              title: '发射台暂时不可用',
              message: memeCapabilityText(capability),
            )
          : null,
      bottomBar: detail == null ? null : _bottomBar(detail, submission),
      sections: <Widget>[
        if (state == null || detail == null)
          LoopChainStateBlock(
            keyPrefix: 'meme-token',
            phase: state?.phase ?? LoopChainViewPhase.unavailable,
            failureKind: state?.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '代币不存在',
            onRetry: () => unawaited(ref.read(provider.notifier).reload()),
          )
        else
          ..._sections(detail, submission, capability),
      ],
    );
  }

  Widget _bottomBar(MemeTokenDetail detail, MemeSubmissionState submission) {
    final busy = submission.busy || submission.locked;
    return switch (detail.status) {
      MemeTokenStatus.trading => _TradeBar(
        busy: busy,
        holding: (detail.viewer?.balance ?? BigInt.zero) > BigInt.zero,
        onBuy: () => unawaited(_trade(detail, MemeTradeSide.buy)),
        onQuickBuy: () => unawaited(
          _trade(
            detail,
            MemeTradeSide.buy,
            initialAmount:
                ref.read(memeQuickBuyAmountProvider) ??
                memeQuickBuyDefaultAmount,
          ),
        ),
        onSell: () => unawaited(_trade(detail, MemeTradeSide.sell)),
      ),
      // S118: the testnet has no in-app swap (`/v2/swap/quote` answers
      // CHAIN_MISMATCH), so the bar says so and offers the pool instead.
      MemeTokenStatus.graduated
          when loopIsTestnetChainId(detail.contract.chainId) =>
        _BarShell(
          child: Row(
            children: <Widget>[
              const Expanded(
                child: LoopInlineUnavailable(
                  key: ValueKey<String>('meme-token-swap-testnet'),
                  message: '测试网不支持站内兑换',
                  padding: EdgeInsets.zero,
                ),
              ),
              if (detail.graduation?.pool ?? detail.row.pool case final pool?)
                LoopButton(
                  key: const ValueKey<String>('meme-token-copy-pool'),
                  label: '复制池地址',
                  icon: 'copy',
                  onPressed: () => unawaited(_copy(pool, '已复制池地址')),
                ),
            ],
          ),
        ),
      MemeTokenStatus.graduated => _BarShell(
        child: LoopButton(
          key: const ValueKey<String>('meme-token-swap'),
          label: '去兑换',
          primary: true,
          block: true,
          onPressed: detail.row.tokenAddress == null
              ? null
              : () => _open(MemeRoute.swap(detail: detail)),
        ),
      ),
      MemeTokenStatus.draft => _BarShell(
        child: LoopButton(
          key: const ValueKey<String>('meme-token-resume'),
          label: '继续创建',
          primary: true,
          block: true,
          onPressed: () => _open(MemeRoute.resume(detail.memeTokenId)),
        ),
      ),
      MemeTokenStatus.pendingChain => const _BarShell(
        child: LoopButton(
          key: ValueKey<String>('meme-token-pending'),
          label: '创建中…',
          block: true,
        ),
      ),
      MemeTokenStatus.full => const _BarShell(
        child: LoopButton(
          key: ValueKey<String>('meme-token-full'),
          label: '打满，毕业中…',
          block: true,
        ),
      ),
      MemeTokenStatus.paused => const _BarShell(
        child: LoopButton(
          key: ValueKey<String>('meme-token-paused'),
          label: '已暂停交易',
          block: true,
        ),
      ),
    };
  }

  List<Widget> _sections(
    MemeTokenDetail detail,
    MemeSubmissionState submission,
    LoopCapabilityProjection capability,
  ) {
    final row = detail.row;
    final statusText = memeSubmissionText(
      submission,
      submission.intent?.kind ?? MemeIntentKind.buy,
    );
    final chartHeight = memeTokenChartHeight(MediaQuery.sizeOf(context).height);
    return <Widget>[
      if (statusText != null)
        LoopNotice(
          key: ValueKey<String>('meme-token-status-${submission.phase.name}'),
          icon: submission.phase == MemeSubmissionPhase.confirmed
              ? 'check'
              : 'clock',
          body: statusText,
          trailing: _statusAction(submission, detail.memeTokenId),
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        ),
      if (_celebrate)
        _GraduationBanner(onClose: () => setState(() => _celebrate = false)),
      if (detail.isHidden)
        LoopInlineUnavailable(
          key: const ValueKey<String>('meme-token-hidden'),
          icon: 'warn',
          message: switch (detail.listingReason?.reasonText) {
            final String text => '运营已将此代币从发射台隐藏 · $text',
            _ => '运营已将此代币从发射台隐藏',
          },
        ),
      _PriceBlock(detail: detail),
      // Decision 0174: the chart follows the price head directly, full
      // bleed, its range chips under it.
      _ChartSection(
        memeTokenId: detail.memeTokenId,
        interval: _interval,
        height: chartHeight,
        onIntervalChanged: (value) => setState(() => _interval = value),
      ),
      _ProgressStats(detail: detail),
      if (memeLiquidityLow(detail))
        LoopNotice(
          key: const ValueKey<String>('meme-token-liquidity-low'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body:
              '流动性低 · 内盘储备 '
              '${memeCapLabel(memeUnits(detail.curve.realUsd1))}，大额买入滑点高',
        ),
      if (detail.viewer case final viewer? when viewer.balance > BigInt.zero)
        _HoldingRow(detail: detail, balance: viewer.balance),
      if (detail.viewerUnavailableReason case final reason?)
        LoopInlineUnavailable(
          key: const ValueKey<String>('meme-token-viewer-unavailable'),
          icon: 'info',
          message: '我的持仓暂时读不到 · ${memeReasonText(reason)}',
        ),
      if (capability.evidencePending)
        const LoopInlineUnavailable(
          key: ValueKey<String>('meme-token-evidence-pending'),
          icon: 'info',
          message: '发射台合约还在核对，交易可能暂时不可用',
        ),
      if (row.priceSource case final source?)
        MemeProvenance(
          key: const ValueKey<String>('meme-token-price-provenance'),
          sources: <String>[source.source.label],
          observedAt: source.observedAt,
          detail: source.source == MemePriceSource.loopCurve
              ? '内盘价格 = 曲线虚拟储备之比，市值 = 价格 × 10 亿总量。'
              : '毕业后的价格与市值读自 DexScreener。',
        ),
      MarketTabBar(
        key: const ValueKey<String>('meme-token-tabs'),
        keyPrefix: 'meme-token-tab',
        // Decision 0174: the holder count rides in its tab's title.
        labels: <String>[
          for (final tab in MemeTokenTab.values)
            tab == MemeTokenTab.holders
                ? '${tab.label} ${row.holderCount}'
                : tab.label,
        ],
        selectedIndex: MemeTokenTab.values.indexOf(_tab),
        onSelected: (index) =>
            setState(() => _tab = MemeTokenTab.values[index]),
      ),
      const SizedBox(height: 4),
      ...switch (_tab) {
        MemeTokenTab.holders => memeHolderSections(
          ref,
          detail: detail,
          keyPrefix: 'meme-holders',
          onOpenProfile: _openProfile,
          onOpenAll: () => _open(MemeRoute.holders(detail.memeTokenId)),
        ),
        MemeTokenTab.activity => memeTradeSections(
          ref,
          detail: detail,
          keyPrefix: 'meme-trades',
          onOpenProfile: _openProfile,
          onOpenAll: () => _open(MemeRoute.trades(detail.memeTokenId)),
        ),
        MemeTokenTab.about => _aboutSections(detail),
      },
    ];
  }

  void _openProfile(String publicProfileId) =>
      _open(userProfileLocation(publicProfileId));

  Widget? _statusAction(MemeSubmissionState submission, String memeTokenId) {
    final controller = ref.read(
      memeSubmissionControllerProvider(MemeTokenScreen.tradeScope(memeTokenId))
          .notifier,
    );
    return switch (submission.phase) {
      MemeSubmissionPhase.pollTimedOut => LoopButton(
        key: const ValueKey<String>('meme-token-resume-poll'),
        label: '再查一次',
        onPressed: controller.resumePolling,
      ),
      MemeSubmissionPhase.locked
          when submission.outcome?.status == MoneySignStatus.reportRefused &&
              memeReportRetryable(submission.outcome!.reasonCode) =>
        LoopButton(
          key: const ValueKey<String>('meme-token-retry-report'),
          label: '重新上报',
          onPressed: () => unawaited(controller.retryReport()),
        ),
      MemeSubmissionPhase.confirmed ||
      MemeSubmissionPhase.failed ||
      MemeSubmissionPhase.expired ||
      MemeSubmissionPhase.signRefused ||
      MemeSubmissionPhase.prepareFailed => LoopIconButton(
        key: const ValueKey<String>('meme-token-status-close'),
        icon: 'close',
        label: '关闭',
        onPressed: controller.reset,
      ),
      _ => null,
    };
  }

  List<Widget> _aboutSections(MemeTokenDetail detail) {
    final row = detail.row;
    final creator = row.creator;
    final links = detail.links;
    final graduation = detail.graduation;
    return <Widget>[
      if (detail.description.isNotEmpty)
        Padding(
          key: const ValueKey<String>('meme-about-description'),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Text(detail.description, style: LoopType.body),
        ),
      if (!links.isEmpty)
        LoopRecordGroup(
          key: const ValueKey<String>('meme-about-links'),
          rows: <LoopRecordRow>[
            // Decision 0123: every link row has its mark, from the icons
            // the set already has (no brand marks are drawn).
            for (final (label, url, icon) in <(String, String?, String)>[
              ('X', links.twitter, 'link'),
              ('Telegram', links.telegram, 'link'),
              ('官网', links.website, 'globe'),
            ])
              if (url != null)
                LoopRecordRow(
                  key: ValueKey<String>('meme-about-link-$label'),
                  leading: LoopRowIcon(icon: icon),
                  title: label,
                  subtitle: url,
                  trailingCaption: '复制',
                  chevron: false,
                  onTap: () => unawaited(_copy(url, '已复制链接')),
                ),
          ],
        ),
      const LoopLabel('创建者'),
      LoopRecordGroup(
        key: const ValueKey<String>('meme-about-creator'),
        rows: <LoopRecordRow>[
          LoopRecordRow(
            leading: LoopProfileAvatar(
              avatarRef: creator?.avatarRef,
              alias: creator?.displayName,
              size: 36,
            ),
            title: creator?.displayName ?? '未公开资料',
            subtitle: creator == null ? '创建者没有公开资料' : '查看公开资料',
            chevron: creator != null,
            onTap: creator == null
                ? null
                : () => _openProfile(creator.publicProfileId),
          ),
        ],
      ),
      const LoopLabel('合约'),
      if (row.tokenAddress case final address?)
        LoopKeyValue(label: '代币合约', value: memeShortAddress(address)),
      LoopKeyValue(
        label: '曲线合约',
        value: memeShortAddress(detail.contract.address),
      ),
      LoopKeyValue(label: '合约版本', value: detail.contract.version),
      LoopKeyValue(label: '网络', value: loopChainName(detail.contract.chainId)),
      LoopKeyValue(
        label: '总量',
        value: '${memeTokenFigure(detail.curve.totalSupply)} 枚',
      ),
      LoopKeyValue(
        label: '交易费率',
        value: memeBpsLabel(detail.curve.tradeFeeBps),
      ),
      LoopKeyValue(
        label: '单钱包上限',
        value: graduation == null
            ? '${memeTokenFigure(detail.curve.walletCapTokens)} 枚'
            : '毕业后不限',
      ),
      if (graduation != null) ...<Widget>[
        if (graduation.pool case final pool?)
          LoopKeyValue(label: 'PancakeSwap 池', value: memeShortAddress(pool)),
        if (graduation.usd1ToPool case final usd1?)
          LoopKeyValue(label: '注入 USD1', value: memeUsd1Label(usd1)),
        if (graduation.tokensToPool case final tokens?)
          LoopKeyValue(label: '注入代币', value: '${memeTokenFigure(tokens)} 枚'),
        if (graduation.lpBurnTx case final tx?)
          LoopKeyValue(label: 'LP 已烧毁', value: memeShortAddress(tx)),
        LoopKeyValue(label: '毕业时间', value: loopDateTimeLabel(graduation.at)),
        if (graduation.hasResidual)
          const LoopInlineUnavailable(
            key: ValueKey<String>('meme-about-residual'),
            icon: 'info',
            message: '外盘池已存在，部分资金留在合约',
          ),
        if (row.tokenAddress case final address?)
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('meme-about-dex'),
                leading: const LoopRowIcon(icon: 'chart'),
                title: '外盘行情',
                subtitle: '毕业后的价格与 K 线',
                onTap: () => _open(
                  MarketAssetRoute.token('${detail.contract.chainId}:$address'),
                ),
              ),
            ],
          ),
      ],
      if (detail.contract.explorerUrl case final url?)
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('meme-about-explorer'),
              leading: const LoopRowIcon(icon: 'link'),
              title: '区块浏览器',
              subtitle: url,
              trailingCaption: '复制',
              chevron: false,
              onTap: () => unawaited(_copy(url, '已复制链接')),
            ),
          ],
        ),
      MemeProvenance(
        key: const ValueKey<String>('meme-about-provenance'),
        sources: const <String>['LOOP 链上索引'],
        observedAt: detail.observedAt,
        detail:
            '曲线状态、持有者与成交读自 LOOP 对曲线合约事件的索引；'
            '只列出经 LOOP 创建的代币。',
      ),
    ];
  }
}

class _BarShell extends StatelessWidget {
  const _BarShell({required this.child});

  final Widget child;

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
        child: child,
      ),
    ),
  );
}

class _TradeBar extends StatelessWidget {
  const _TradeBar({
    required this.busy,
    required this.holding,
    required this.onBuy,
    required this.onQuickBuy,
    required this.onSell,
  });

  final bool busy;

  /// The active wallet holds some of the token: 卖出 is offered beside 买入.
  final bool holding;
  final VoidCallback onBuy;
  final VoidCallback onQuickBuy;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) => _BarShell(
    child: Row(
      children: <Widget>[
        if (holding) ...<Widget>[
          Expanded(
            child: LoopButton(
              key: const ValueKey<String>('meme-token-sell'),
              label: '卖出',
              block: true,
              onPressed: busy ? null : onSell,
            ),
          ),
          const SizedBox(width: 10),
        ],
        // Decision 0174: the screen's one full-Lime body.
        Expanded(
          flex: holding ? 2 : 1,
          child: LoopButton(
            key: const ValueKey<String>('meme-token-buy'),
            label: '买入',
            primary: true,
            block: true,
            onPressed: busy ? null : onBuy,
          ),
        ),
        const SizedBox(width: 10),
        _QuickBuyKey(onPressed: busy ? null : onQuickBuy),
      ],
    ),
  );
}

/// `.bottombar .flash`: the 52-wide 快买 key — Card2 ground, a Chalk bolt.
/// It opens the same buy panel with the last amount filled in; it signs
/// nothing by itself.
class _QuickBuyKey extends StatelessWidget {
  const _QuickBuyKey({required this.onPressed});

  final VoidCallback? onPressed;

  static const double width = 52;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: '快买',
    child: Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Material(
        key: const ValueKey<String>('meme-token-quick-buy-surface'),
        color: LoopColors.card2,
        borderRadius: LoopRadius.control,
        child: InkWell(
          key: const ValueKey<String>('meme-token-quick-buy'),
          onTap: onPressed,
          borderRadius: LoopRadius.control,
          child: const SizedBox(
            width: width,
            height: LoopTouch.primaryButton,
            child: Center(
              child: LoopIcon('bolt', size: 20, color: LoopColors.chalk),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The bar's title column (decision 0174): the 36 logo, the ticker with its
/// state badge, and 「name · 0x8a3f…c21e」 with the copy glyph. The text
/// column is one tap target that copies the contract address.
class _TokenTitle extends StatelessWidget {
  const _TokenTitle({
    required this.detail,
    required this.address,
    required this.onCopy,
  });

  final MemeTokenDetail detail;
  final String? address;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final row = detail.row;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                row.symbol,
                key: const ValueKey<String>('meme-token-ticker'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.title,
              ),
            ),
            const SizedBox(width: 6),
            LoopBadge(
              memeTokenStatusLabel(row.status),
              key: const ValueKey<String>('meme-token-status-badge'),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                '${row.name} · '
                '${address == null ? '还没有地址' : memeShortAddress(address!)}',
                key: const ValueKey<String>('meme-token-identity'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.captionSm.copyWith(color: LoopColors.text2),
              ),
            ),
            if (onCopy != null) ...<Widget>[
              const SizedBox(width: 4),
              const LoopIcon('copy', size: 12, color: LoopColors.text2),
            ],
          ],
        ),
      ],
    );
    return Row(
      children: <Widget>[
        MemeLogo(
          symbol: row.symbol,
          imageUrl: row.imageUrl,
          identity: row.memeTokenId,
          size: 36,
          radius: LoopRadius.innerValue,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: onCopy == null
              ? text
              : Semantics(
                  button: true,
                  label: '复制合约地址',
                  child: InkWell(
                    key: const ValueKey<String>('meme-token-copy-address'),
                    onTap: onCopy,
                    borderRadius: LoopRadius.inner,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: LoopTouch.minimum,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: text,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// `.pricehead` (decision 0174): the price at the figure step, the one-hour
/// move as an amount and a percentage in rise / fall, and the market cap on
/// the right.
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.detail});

  final MemeTokenDetail detail;

  @override
  Widget build(BuildContext context) {
    final row = detail.row;
    final price = row.priceUsd1;
    final cap = row.marketCapUsd1;
    return Padding(
      key: const ValueKey<String>('meme-token-price'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (price == null)
                  Text(
                    memeQuoteUnavailableText(row.quoteUnavailableReason),
                    key: const ValueKey<String>('meme-token-price-unavailable'),
                    style: LoopType.titleLg.copyWith(color: LoopColors.text2),
                  )
                else
                  Text(
                    memePriceLabel(price),
                    key: const ValueKey<String>('meme-token-price-figure'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.figureXl,
                  ),
                const SizedBox(height: 6),
                if (row.isGraduated)
                  Text(
                    '外盘价格',
                    style: LoopType.caption.copyWith(color: LoopColors.text3),
                  )
                else
                  _ChangeLine(price: price, change: row.change1hPct),
              ],
            ),
          ),
          if (cap != null) ...<Widget>[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  memeCapLabel(cap),
                  key: const ValueKey<String>('meme-token-cap'),
                  style: LoopType.figureMd,
                ),
                const SizedBox(height: 5),
                Text(
                  '市值',
                  style: LoopType.captionSm.copyWith(color: LoopColors.text2),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 「▲ $0.0₅4797 (14.38%) · 1h」 in the 0117 rise / fall ink; only the
/// percentage when there is no price to take the amount from.
class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.price, required this.change});

  final Decimal? price;
  final Decimal? change;

  @override
  Widget build(BuildContext context) {
    final pct = change;
    if (pct == null) return const MemeChangeLabel(change: null);
    final move = LoopPriceMove.of(pct);
    final amount = memeChange1hAmount(price, pct);
    final String text;
    if (amount == null) {
      text = '${marketMoveLabel(pct)} · 1h';
    } else {
      final arrow = switch (move) {
        LoopPriceMove.up => '▲ ',
        LoopPriceMove.down => '▼ ',
        LoopPriceMove.flat || LoopPriceMove.unread => '',
      };
      final magnitude = pct < Decimal.zero ? -pct : pct;
      final absolute = amount < Decimal.zero ? -amount : amount;
      text =
          '$arrow${memePriceLabel(absolute)} '
          '(${magnitude.toStringAsFixed(2)}%) · 1h';
    }
    return Text(
      text,
      key: const ValueKey<String>('meme-token-change'),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
      style: LoopTypography.withWeight(
        LoopType.figureSm.copyWith(color: move.color),
        FontWeight.w600,
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.detail, required this.balance});

  final MemeTokenDetail detail;
  final BigInt balance;

  @override
  Widget build(BuildContext context) {
    final price = detail.row.priceUsd1;
    final value = price == null ? null : memeUnits(balance) * price;
    return Padding(
      key: const ValueKey<String>('meme-token-holding'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        <String>[
          '持有 ${memeTokenLabel(balance, '\$${detail.row.symbol}')}',
          if (value != null) '≈${loopFormatUsd(value)}',
        ].join(' · '),
        style: LoopType.body.copyWith(color: LoopColors.text2),
      ),
    );
  }
}

/// Two stats — fill progress with what is still to raise, and 24h volume —
/// over the 6 px progress bar (decision 0174; replaces the 0169 text block).
class _ProgressStats extends StatelessWidget {
  const _ProgressStats({required this.detail});

  final MemeTokenDetail detail;

  @override
  Widget build(BuildContext context) {
    final row = detail.row;
    final curve = detail.curve;
    final graduated = row.isGraduated;
    final bps = graduated ? 10000 : row.progressBps;
    final target = curve.fillTargetUsd1;
    final left = target == null ? null : target - curve.realUsd1;
    final progress = graduated
        ? '100% · 已毕业'
        : left != null && left > BigInt.zero
        ? '${memeBpsLabel(bps)} · 还差 ${memeCapLabel(memeUnits(left))}'
        : memeBpsLabel(bps);
    return Column(
      key: const ValueKey<String>('meme-token-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopStatGrid(
          key: const ValueKey<String>('meme-token-stats'),
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          stats: <LoopStat>[
            LoopStat(
              label: '打满进度',
              value: progress,
              tone: LoopStatTone.up,
              statKey: const ValueKey<String>('meme-token-stat-progress'),
            ),
            LoopStat(
              label: '24h 交易量',
              value: memeCapLabel(row.volume24hUsd1),
              statKey: const ValueKey<String>('meme-token-stat-volume'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          // Decision 0169: the family's 6 px `.bar`.
          child: LoopProgressBar(
            key: const ValueKey<String>('meme-token-progress-bar'),
            value: memeProgressFraction(bps),
            semanticLabel: '内盘进度 ${memeBpsLabel(bps)}',
          ),
        ),
      ],
    );
  }
}

/// The one-time mark of a graduation seen on this page. It unfolds unless
/// motion is reduced, in which case it simply appears.
class _GraduationBanner extends StatelessWidget {
  const _GraduationBanner({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final duration = LoopMotion.of(context, const Duration(milliseconds: 320));
    return TweenAnimationBuilder<double>(
      key: const ValueKey<String>('meme-token-graduated-banner'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      // It grows in from its top edge rather than fading: a half-transparent
      // frame is paint the reader cannot see.
      builder: (context, value, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: value,
          child: child,
        ),
      ),
      child: LoopNotice(
        icon: 'check',
        title: '已毕业',
        body: '曲线已打满，代币已上 PancakeSwap，LP 已烧毁。',
        trailing: LoopIconButton(
          key: const ValueKey<String>('meme-token-graduated-close'),
          icon: 'close',
          label: '关闭',
          onPressed: onClose,
        ),
      ),
    );
  }
}

class _ChartSection extends ConsumerStatefulWidget {
  const _ChartSection({
    required this.memeTokenId,
    required this.interval,
    required this.height,
    required this.onIntervalChanged,
  });

  final String memeTokenId;
  final MemeCandleInterval interval;
  final double height;
  final ValueChanged<MemeCandleInterval> onIntervalChanged;

  @override
  ConsumerState<_ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends ConsumerState<_ChartSection> {
  LoopChartStyle _style = LoopChartStyle.line;

  @override
  Widget build(BuildContext context) {
    final provider = memeCandlesControllerProvider(
      MemeCandleRequest(
        memeTokenId: widget.memeTokenId,
        interval: widget.interval,
      ),
    );
    final state = ref.watch(provider);
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(ref.read(provider.notifier).load());
      });
    }
    final series = state.value;
    final Widget body;
    if (series == null) {
      body = ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.height),
        child: LoopChainStateBlock(
          keyPrefix: 'meme-candles',
          phase: state.phase,
          failureKind: state.failureKind,
          skeleton: LoopSkeletonType.chart,
          emptyMessage: '还没有成交',
          onRetry: () => unawaited(ref.read(provider.notifier).reload()),
        ),
      );
    } else if (series.candles.length < 2) {
      body = SizedBox(
        height: widget.height,
        child: const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: LoopEmptyState(
            key: ValueKey<String>('meme-chart-empty'),
            illustration: LoopIllustration.chartEmpty,
            title: memeChartEmptyMessage,
            message: '多几笔成交，走势就会画出来',
            compact: true,
          ),
        ),
      );
    } else {
      body = LoopMarketChart(
        key: ValueKey<String>('meme-chart-${widget.interval.wireName}'),
        candles: series.candles,
        interval: widget.interval.axis,
        style: _style,
        height: widget.height,
        // Decision 0174: one Lime line over the page itself — no card, no
        // volume strip — with the current price as a Lime tag.
        showVolume: false,
        lineColor: LoopColors.lime,
        lastPriceTag: true,
        semanticLabel:
            '${series.candles.length} 根${widget.interval.label}'
            '${_style == LoopChartStyle.line ? '收盘价折线' : 'K 线'}，单位 USD1',
      );
    }
    return Column(
      key: const ValueKey<String>('meme-chart-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(padding: const EdgeInsets.only(top: 6, bottom: 2), child: body),
        // Decision 0174: the range chips sit under the full-bleed chart, the
        // K switch at the end of the same line (decision 0131's periods
        // above the chart are superseded; the bar's height is reserved, so
        // they are never under it).
        Padding(
          key: const ValueKey<String>('meme-interval-strip'),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Row(
            children: <Widget>[
              for (final (interval, label) in memeChartRanges) ...<Widget>[
                LoopSeg(
                  key: ValueKey<String>('meme-interval-${interval.wireName}'),
                  label: label,
                  quiet: true,
                  selected: interval == widget.interval,
                  onSelected: () => widget.onIntervalChanged(interval),
                ),
                const SizedBox(width: 4),
              ],
              const Spacer(),
              Semantics(
                label: _style == LoopChartStyle.line ? '切到 K 线' : '切到折线',
                child: LoopSeg(
                  key: const ValueKey<String>('meme-chart-style'),
                  label: 'K',
                  quiet: true,
                  selected: _style == LoopChartStyle.candles,
                  onSelected: () => setState(
                    () => _style = _style == LoopChartStyle.line
                        ? LoopChartStyle.candles
                        : LoopChartStyle.line,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (series != null)
          MemeProvenance(
            key: const ValueKey<String>('meme-candles-provenance'),
            sources: const <String>['LOOP 链上索引'],
            observedAt: series.observedAt,
            prefix: series.frozenAt == null ? '单位 USD1' : '毕业后停在毕业时',
            detail:
                '每笔曲线成交后的价格按时段聚成 K 线；空时段不补。'
                '${series.frozenAt == null ? '' : '毕业后的走势在外盘行情里看。'}',
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 持有者 / 动态, shared by the token page and their own routes
// ---------------------------------------------------------------------------

/// 持有者: a page at a time, largest first, with the creator and the reader
/// marked; after graduation the distribution is frozen.
List<Widget> memeHolderSections(
  WidgetRef ref, {
  required MemeTokenDetail detail,
  required String keyPrefix,
  required void Function(String publicProfileId) onOpenProfile,
  VoidCallback? onOpenAll,
}) {
  final provider = memeHoldersControllerProvider(detail.memeTokenId);
  final state = ref.watch(provider);
  final controller = ref.read(provider.notifier);
  if (state.phase == LoopChainViewPhase.loading) {
    scheduleMicrotask(() => unawaited(controller.load()));
  }
  final page = state.value;
  if (!state.isReady || page == null) {
    return <Widget>[
      LoopChainStateBlock(
        keyPrefix: keyPrefix,
        phase: state.phase,
        failureKind: state.failureKind,
        rows: 4,
        emptyMessage: '还没有持有者',
        onRetry: () => unawaited(controller.reload()),
      ),
    ];
  }
  final symbol = '\$${detail.row.symbol}';
  return <Widget>[
    Padding(
      key: ValueKey<String>('$keyPrefix-count'),
      padding: EdgeInsets.fromLTRB(16, 4, onOpenAll == null ? 16 : 4, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              page.frozenAt == null
                  ? '${page.holderCount} 个持有者 · 按曲线买卖统计'
                  : '${page.holderCount} 个持有者 · 按曲线买卖统计 · 分布冻结于毕业时',
              style: LoopType.caption.copyWith(color: LoopColors.text2),
            ),
          ),
          if (onOpenAll != null)
            LoopIconButton(
              key: ValueKey<String>('$keyPrefix-open-all'),
              icon: 'expand',
              label: '全部持有者',
              onPressed: onOpenAll,
            ),
        ],
      ),
    ),
    if (page.items.isEmpty)
      LoopEmptyState(
        key: ValueKey<String>('$keyPrefix-empty'),
        illustration: LoopIllustration.holders,
        title: '还没有持有者',
        message: '第一笔买入后，持有者会出现在这里',
        compact: true,
      )
    else
      // Decision 0174: one `.record-card` group of `.row`s.
      LoopRecordGroup(
        key: ValueKey<String>('$keyPrefix-rows'),
        rows: <LoopRecordRow>[
          for (final (index, holder) in page.items.indexed)
            memeHolderRow(
              key: ValueKey<String>('$keyPrefix-${holder.wallet}'),
              rank: index + 1,
              holder: holder,
              symbol: symbol,
              price: detail.row.priceUsd1,
              onOpenProfile: onOpenProfile,
            ),
        ],
      ),
    if (controller.appendFailed && !state.busy)
      LoopInlineUnavailable(
        key: ValueKey<String>('$keyPrefix-more-failed'),
        message: '下一页没有读到',
        onRetry: () => unawaited(controller.loadMore()),
      )
    else if (page.nextCursor case final cursor?) ...<Widget>[
      LoopLoadMoreSentinel(
        key: ValueKey<String>('$keyPrefix-load-more'),
        cursor: cursor,
        onLoadMore: () => unawaited(controller.loadMore()),
      ),
      if (state.busy)
        LoopSkeleton(
          key: ValueKey<String>('$keyPrefix-loading-more'),
          type: LoopSkeletonType.record,
          rows: 2,
        ),
    ] else if (page.items.isNotEmpty)
      MarketListEnd(key: ValueKey<String>('$keyPrefix-end')),
    MemeProvenance(
      key: ValueKey<String>('$keyPrefix-provenance'),
      sources: const <String>['LOOP 链上索引'],
      observedAt: page.observedAt,
      detail: '持仓 = 曲线买入减卖出的净额，钱包之间的转账不计；占比以 10 亿总量为分母。',
    ),
  ];
}

/// One holder as a `.row` (decision 0174): avatar, name, rank and amount;
/// the holding's value on the right and its share of supply under it. The
/// index keeps no cost basis, so no profit or loss is drawn.
LoopRecordRow memeHolderRow({
  required Key key,
  required int rank,
  required MemeHolder holder,
  required String symbol,
  required Decimal? price,
  required void Function(String publicProfileId) onOpenProfile,
}) {
  final account = holder.account;
  final name = account?.displayName ?? memeShortAddress(holder.wallet);
  final value = price == null ? null : memeHoldingValue(holder.balance, price);
  final badges = <Widget>[
    if (holder.isCreator) const LoopBadge('创建者'),
    if (holder.isViewer) const LoopBadge('我', kind: LoopBadgeKind.up),
  ];
  return LoopRecordRow(
    key: key,
    leading: LoopProfileAvatar(
      avatarRef: account?.avatarRef,
      alias: account?.displayName,
      size: 36,
    ),
    title: name,
    subtitle: '第 $rank · ${memeTokenCompact(holder.balance)} $symbol',
    trailingBadge: badges.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final (index, badge) in badges.indexed) ...<Widget>[
                if (index > 0) const SizedBox(width: 4),
                badge,
              ],
            ],
          ),
    trailing: value == null
        ? memeTokenCompact(holder.balance)
        : loopFormatUsd(value),
    trailingCaption: memeBpsLabel(holder.shareBps),
    chevron: false,
    onTap: account == null
        ? null
        : () => onOpenProfile(account.publicProfileId),
  );
}

/// 动态: the curve's trades, newest first, a page at a time.
List<Widget> memeTradeSections(
  WidgetRef ref, {
  required MemeTokenDetail detail,
  required String keyPrefix,
  required void Function(String publicProfileId) onOpenProfile,
  VoidCallback? onOpenAll,
}) {
  final provider = memeTradesControllerProvider(detail.memeTokenId);
  final state = ref.watch(provider);
  final controller = ref.read(provider.notifier);
  if (state.phase == LoopChainViewPhase.loading) {
    scheduleMicrotask(() => unawaited(controller.load()));
  }
  final page = state.value;
  if (!state.isReady || page == null) {
    return <Widget>[
      LoopChainStateBlock(
        keyPrefix: keyPrefix,
        phase: state.phase,
        failureKind: state.failureKind,
        rows: 4,
        emptyMessage: '还没有成交',
        onRetry: () => unawaited(controller.reload()),
      ),
    ];
  }
  final symbol = '\$${detail.row.symbol}';
  return <Widget>[
    if (onOpenAll != null)
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: LoopIconButton(
            key: ValueKey<String>('$keyPrefix-open-all'),
            icon: 'expand',
            label: '全部动态',
            onPressed: onOpenAll,
          ),
        ),
      ),
    if (page.items.isEmpty)
      LoopEmptyState(
        key: ValueKey<String>('$keyPrefix-empty'),
        illustration: LoopIllustration.chartEmpty,
        title: '还没有成交',
        message: '买入或卖出后，成交会出现在这里',
        compact: true,
      )
    else
      for (final trade in page.items)
        _TradeRow(
          key: ValueKey<String>('$keyPrefix-${trade.key}'),
          trade: trade,
          symbol: symbol,
          onOpenProfile: onOpenProfile,
        ),
    if (controller.appendFailed && !state.busy)
      LoopInlineUnavailable(
        key: ValueKey<String>('$keyPrefix-more-failed'),
        message: '下一页没有读到',
        onRetry: () => unawaited(controller.loadMore()),
      )
    else if (page.nextCursor case final cursor?) ...<Widget>[
      LoopLoadMoreSentinel(
        key: ValueKey<String>('$keyPrefix-load-more'),
        cursor: cursor,
        onLoadMore: () => unawaited(controller.loadMore()),
      ),
      if (state.busy)
        LoopSkeleton(
          key: ValueKey<String>('$keyPrefix-loading-more'),
          type: LoopSkeletonType.record,
          rows: 2,
        ),
    ] else if (page.items.isNotEmpty)
      MarketListEnd(key: ValueKey<String>('$keyPrefix-end')),
    MemeProvenance(
      key: ValueKey<String>('$keyPrefix-provenance'),
      sources: const <String>['LOOP 链上索引'],
      observedAt: page.observedAt,
      detail: '买入金额是实付（含 1% 手续费、不含退回），卖出金额是实收（已扣费）。',
    ),
  ];
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({
    required this.trade,
    required this.symbol,
    required this.onOpenProfile,
    super.key,
  });

  final MemeTrade trade;
  final String symbol;
  final void Function(String publicProfileId) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final account = trade.account;
    final name = account?.displayName ?? memeShortAddress(trade.wallet);
    final move = trade.isBuy ? LoopPriceMove.up : LoopPriceMove.down;
    return InkWell(
      onTap: account == null
          ? null
          : () => onOpenProfile(account.publicProfileId),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 36,
              child: Text(
                trade.isBuy ? '买' : '卖',
                key: ValueKey<String>(
                  'meme-trade-side-${trade.isBuy ? 'buy' : 'sell'}',
                ),
                style: LoopType.title.copyWith(color: move.color),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name, style: LoopType.body),
                  Text(
                    loopDateTimeLabel(trade.at),
                    style: LoopType.captionSm.copyWith(color: LoopColors.text3),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  memeUsd1Label(trade.usd1Amount),
                  style: LoopType.figureSm.copyWith(color: move.color),
                ),
                Text(
                  '${memeTokenCompact(trade.tokenAmount)} $symbol',
                  style: LoopType.captionSm.copyWith(color: LoopColors.text3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemeShareSheet extends StatelessWidget {
  const _MemeShareSheet({
    required this.title,
    required this.address,
    required this.onCopy,
    required this.onShare,
  });

  final String title;
  final String? address;
  final VoidCallback onCopy;
  final Future<void> Function() onShare;

  @override
  Widget build(BuildContext context) {
    final code = address == null ? null : LoopQrCode.encode(address!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopSheetHeading('分享代币'),
        Padding(
          key: const ValueKey<String>('meme-share-sheet'),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: LoopType.titleLg),
              const SizedBox(height: 12),
              if (code != null)
                Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LoopColors.chalk,
                    borderRadius: BorderRadius.circular(LoopRadius.innerValue),
                  ),
                  child: LoopQrView(code: code, semanticLabel: '代币合约地址二维码'),
                ),
              if (address != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  address!,
                  textAlign: TextAlign.center,
                  style: LoopType.codeSm.copyWith(color: LoopColors.text2),
                ),
              ],
              const SizedBox(height: 14),
              LoopButtonPair(
                padded: false,
                children: <Widget>[
                  LoopButton(
                    key: const ValueKey<String>('meme-share-copy'),
                    label: '复制',
                    onPressed: onCopy,
                  ),
                  LoopButton(
                    key: const ValueKey<String>('meme-share-system'),
                    label: '分享',
                    primary: true,
                    onPressed: () => unawaited(onShare()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `meme-token-holders` / `meme-token-trades`: one list on its own page.
class MemeTokenListScreen extends ConsumerWidget {
  const MemeTokenListScreen({
    required this.memeTokenId,
    required this.holders,
    super.key,
    this.onNavigate,
    this.onBack,
  });

  final String? memeTokenId;

  /// `true` for 持有者, `false` for 动态.
  final bool holders;
  final void Function(String location)? onNavigate;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = memeTokenId;
    final title = holders ? '持有者' : '动态';
    if (!MemeRoute.isTokenId(id)) {
      return LoopFocusPage(
        key: ValueKey<String>('meme-token-list-invalid-$holders'),
        archetype: LoopPageArchetype.listing,
        title: title,
        onBack: onBack,
        body: const <Widget>[
          LoopInlineUnavailable(
            message: '路由中没有可用的代币标识',
            detail: '没有请求任何数据，也没有回退到其他代币。',
            detailMaxLines: 3,
            maxLines: 2,
          ),
        ],
      );
    }
    void open(String location) {
      final navigate = onNavigate;
      if (navigate != null) {
        navigate(location);
        return;
      }
      context.push(location);
    }

    void openProfile(String publicProfileId) =>
        open(userProfileLocation(publicProfileId));
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.meme),
    );
    final blocked = memeReadsBlocked(ref);
    final provider = memeTokenControllerProvider(id!);
    final state = blocked ? null : ref.watch(provider);
    if (state != null && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() => unawaited(ref.read(provider.notifier).load()));
    }
    final detail = state?.value;
    final keyPrefix = holders ? 'meme-holders-page' : 'meme-trades-page';
    return LoopDashboardPage(
      key: ValueKey<String>('$keyPrefix-$id'),
      archetype: LoopPageArchetype.listing,
      title: detail == null ? title : '\$${detail.row.symbol} · $title',
      onBack: onBack,
      onRefresh: blocked
          ? null
          : () async {
              await Future.wait(<Future<void>>[
                ref.read(provider.notifier).reload(),
                if (holders)
                  ref.read(memeHoldersControllerProvider(id).notifier).reload()
                else
                  ref.read(memeTradesControllerProvider(id).notifier).reload(),
              ]);
            },
      block: blocked
          ? LoopPageBlock(
              title: '发射台暂时不可用',
              message: memeCapabilityText(capability),
            )
          : null,
      sections: <Widget>[
        if (state == null || detail == null)
          LoopChainStateBlock(
            keyPrefix: keyPrefix,
            phase: state?.phase ?? LoopChainViewPhase.unavailable,
            failureKind: state?.failureKind,
            emptyMessage: '代币不存在',
            onRetry: () => unawaited(ref.read(provider.notifier).reload()),
          )
        else if (holders)
          ...memeHolderSections(
            ref,
            detail: detail,
            keyPrefix: keyPrefix,
            onOpenProfile: openProfile,
          )
        else
          ...memeTradeSections(
            ref,
            detail: detail,
            keyPrefix: keyPrefix,
            onOpenProfile: openProfile,
          ),
      ],
    );
  }
}

/// The value of [balance] at [price], for a holding line.
Decimal memeHoldingValue(BigInt balance, Decimal price) =>
    memeUnits(balance) * price;
