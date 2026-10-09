import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

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

/// `meme-token` · one MEME curve token (archetype `record`, layout
/// `dashboard`), laid out on the S113 token skeleton (decision 0118).
///
/// The bar names `$SYMBOL` and shares; under it the identity line, the price
/// with its one-hour move and the market cap, the holding row when the
/// active wallet holds some, the curve's progress, the chart of the curve's
/// own trades, then 持有者 / 动态 / 关于. The bottom bar follows the token's
/// state (contract §10): 买入 / 卖出 while trading, a disabled line while
/// full or paused, 「去兑换」 once graduated. A full curve is re-read until
/// it graduates, and the graduation is marked once.
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
  MemeCandleInterval _interval = MemeCandleInterval.fifteenMinutes;
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

  Future<void> _trade(MemeTokenDetail detail, MemeTradeSide side) async {
    final request = await showMemeTradePanel(
      context,
      detail: detail,
      side: side,
    );
    if (request == null || !mounted) return;
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
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    LoopToast.show(context, message: done);
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
          LoopEmpty(
            key: ValueKey<String>('meme-token-invalid-identity'),
            icon: 'warn',
            message: '路由中没有可用的代币标识',
            reason: '没有请求任何数据，也没有回退到其他代币。',
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

    return LoopDashboardPage(
      key: ValueKey<String>('meme-token-screen-$memeTokenId'),
      archetype: LoopPageArchetype.record,
      title: detail == null ? '代币' : '\$${detail.row.symbol}',
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
        onBuy: () => unawaited(_trade(detail, MemeTradeSide.buy)),
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
    final address = row.tokenAddress ?? detail.predictedAddress;
    final statusText = memeSubmissionText(
      submission,
      submission.intent?.kind ?? MemeIntentKind.buy,
    );
    final chartHeight = (MediaQuery.sizeOf(context).height * 0.32).clamp(
      180.0,
      340.0,
    );
    return <Widget>[
      _IdentityLine(
        detail: detail,
        address: address,
        onCopy: address == null
            ? null
            : () => unawaited(_copy(address, '已复制合约地址')),
      ),
      _PriceBlock(detail: detail),
      if (detail.viewer case final viewer? when viewer.balance > BigInt.zero)
        _HoldingRow(detail: detail, balance: viewer.balance),
      if (detail.viewerUnavailableReason case final reason?)
        LoopInlineUnavailable(
          key: const ValueKey<String>('meme-token-viewer-unavailable'),
          icon: 'info',
          message: '我的持仓暂时读不到 · ${memeReasonText(reason)}',
        ),
      if (statusText != null)
        LoopNotice(
          key: ValueKey<String>('meme-token-status-${submission.phase.name}'),
          icon: submission.phase == MemeSubmissionPhase.confirmed
              ? 'check'
              : 'clock',
          body: statusText,
          trailing: _statusAction(submission, detail.memeTokenId),
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
      _ProgressBlock(detail: detail),
      if (capability.evidencePending)
        const LoopInlineUnavailable(
          key: ValueKey<String>('meme-token-evidence-pending'),
          icon: 'info',
          message: '发射台合约还在核对，交易可能暂时不可用',
        ),
      _ChartSection(
        memeTokenId: detail.memeTokenId,
        interval: _interval,
        height: chartHeight,
        onIntervalChanged: (value) => setState(() => _interval = value),
      ),
      MarketTabBar(
        key: const ValueKey<String>('meme-token-tabs'),
        keyPrefix: 'meme-token-tab',
        labels: <String>[for (final tab in MemeTokenTab.values) tab.label],
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
    required this.onBuy,
    required this.onSell,
  });

  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) => _BarShell(
    child: Row(
      children: <Widget>[
        Expanded(
          child: LoopButton(
            key: const ValueKey<String>('meme-token-sell'),
            label: '卖出',
            block: true,
            onPressed: busy ? null : onSell,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LoopButton(
            key: const ValueKey<String>('meme-token-buy'),
            label: '买入',
            primary: true,
            block: true,
            onPressed: busy ? null : onBuy,
          ),
        ),
      ],
    ),
  );
}

class _IdentityLine extends StatelessWidget {
  const _IdentityLine({
    required this.detail,
    required this.address,
    required this.onCopy,
  });

  final MemeTokenDetail detail;
  final String? address;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey<String>('meme-token-identity'),
    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
    child: Row(
      children: <Widget>[
        MemeLogo(
          symbol: detail.row.symbol,
          imageUrl: detail.row.imageUrl,
          identity: detail.row.memeTokenId,
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
                address == null ? '还没有地址' : memeShortAddress(address!),
                style: LoopType.codeSm.copyWith(color: LoopColors.text2),
              ),
            ],
          ),
        ),
        if (onCopy != null)
          LoopIconButton(
            key: const ValueKey<String>('meme-token-copy-address'),
            icon: 'copy',
            label: '复制合约地址',
            onPressed: onCopy,
          ),
      ],
    ),
  );
}

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
              style: LoopType.figureXl,
            ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              if (row.isGraduated)
                Text(
                  '外盘价格',
                  style: LoopType.caption.copyWith(color: LoopColors.text3),
                )
              else
                MemeChangeLabel(change: row.change1hPct, suffix: ' · 1h'),
              const SizedBox(width: 12),
              if (cap != null)
                Text(
                  '市值 ${memeCapLabel(cap)}',
                  key: const ValueKey<String>('meme-token-cap'),
                  style: LoopType.caption.copyWith(color: LoopColors.text2),
                ),
            ],
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
        ],
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

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.detail});

  final MemeTokenDetail detail;

  @override
  Widget build(BuildContext context) {
    final row = detail.row;
    final curve = detail.curve;
    final graduated = row.isGraduated;
    final target = curve.fillTargetUsd1;
    return Padding(
      key: const ValueKey<String>('meme-token-progress'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                graduated
                    ? '内盘进度 100%'
                    : '内盘进度 ${memeBpsLabel(row.progressBps)}',
                key: const ValueKey<String>('meme-token-progress-label'),
                style: LoopType.title,
              ),
              const Spacer(),
              if (graduated) const MemeGraduatedTag(),
            ],
          ),
          const SizedBox(height: 8),
          MemeProgressBar(
            progressBps: graduated ? 10000 : row.progressBps,
            thickness: 8,
          ),
          const SizedBox(height: 8),
          Text(
            target == null
                ? '已募 ${memeUsd1Label(curve.realUsd1, maxFractionDigits: 0)}'
                : '已募 ${memeUsd1Label(curve.realUsd1, maxFractionDigits: 0)} '
                      '/ ≈${memeUsd1Label(target, maxFractionDigits: 0)}',
            key: const ValueKey<String>('meme-token-raised'),
            style: LoopType.figureSm.copyWith(color: LoopColors.text2),
          ),
          const SizedBox(height: 2),
          Text(switch (row.status) {
            MemeTokenStatus.graduated => '已上 PancakeSwap，外盘开盘价略低于内盘末价',
            MemeTokenStatus.full => '已打满，正在上 PancakeSwap',
            MemeTokenStatus.paused => '交易已暂停',
            _ => '打满后自动上 PancakeSwap',
          }, style: LoopType.caption.copyWith(color: LoopColors.text3)),
        ],
      ),
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
        semanticLabel:
            '${series.candles.length} 根${widget.interval.label}'
            '${_style == LoopChartStyle.line ? '收盘价折线' : 'K 线'}，单位 USD1',
      );
    }
    return Column(
      key: const ValueKey<String>('meme-chart-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(
            children: <Widget>[
              Text(
                '曲线成交',
                style: LoopType.caption.copyWith(color: LoopColors.text3),
              ),
              const Spacer(),
              LoopSeg(
                key: const ValueKey<String>('meme-chart-style'),
                label: _style == LoopChartStyle.line ? 'K线' : '折线',
                selected: false,
                onSelected: () => setState(
                  () => _style = _style == LoopChartStyle.line
                      ? LoopChartStyle.candles
                      : LoopChartStyle.line,
                ),
              ),
            ],
          ),
        ),
        body,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: <Widget>[
              for (final interval in MemeCandleInterval.values) ...<Widget>[
                LoopSeg(
                  key: ValueKey<String>('meme-interval-${interval.wireName}'),
                  label: interval.label,
                  selected: interval == widget.interval,
                  onSelected: () => widget.onIntervalChanged(interval),
                ),
                const SizedBox(width: 6),
              ],
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
      for (final (index, holder) in page.items.indexed)
        _HolderRow(
          key: ValueKey<String>('$keyPrefix-${holder.wallet}'),
          rank: index + 1,
          holder: holder,
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
      detail: '持仓 = 曲线买入减卖出的净额，钱包之间的转账不计；占比以 10 亿总量为分母。',
    ),
  ];
}

class _HolderRow extends StatelessWidget {
  const _HolderRow({
    required this.rank,
    required this.holder,
    required this.symbol,
    required this.onOpenProfile,
    super.key,
  });

  final int rank;
  final MemeHolder holder;
  final String symbol;
  final void Function(String publicProfileId) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final account = holder.account;
    final name = account?.displayName ?? memeShortAddress(holder.wallet);
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
              width: 28,
              child: Text(
                '$rank',
                style: LoopType.figureSm.copyWith(color: LoopColors.text3),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(name, style: LoopType.body),
                  if (holder.isCreator) const LoopBadge('创建者'),
                  if (holder.isViewer)
                    const LoopBadge('我', kind: LoopBadgeKind.up),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  memeTokenCompact(holder.balance),
                  style: LoopType.figureSm,
                ),
                Text(
                  memeBpsLabel(holder.shareBps),
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
    return LoopSheet(
      title: '分享代币',
      child: Padding(
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
          LoopEmpty(
            icon: 'warn',
            message: '路由中没有可用的代币标识',
            reason: '没有请求任何数据，也没有回退到其他代币。',
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
