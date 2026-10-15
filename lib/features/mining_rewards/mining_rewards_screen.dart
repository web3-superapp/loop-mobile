import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_foreground_poll.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_controllers.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_display.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';

// ---------------------------------------------------------------------------
// S138 · `mining-rewards` · 挖矿奖励 (decisions 0140, 0141)
// ---------------------------------------------------------------------------
//
// Archetype `record`, layout `dashboard`. Six modules in the requirer's order
// of meaning (§8.1): the minute display is the page's one large figure — the
// thing a reader remembers is a number that steps once a minute — and the
// rest stays quiet: 奖励汇总, 领取, NFT 轨道, Meme 币轨道, 五级邀请, then the
// claim record.

/// How often the page asks again while the next hour is being settled.
const Duration miningSettlingRetry = Duration(seconds: 30);

class MiningRewardsHourlyScreen extends ConsumerStatefulWidget {
  const MiningRewardsHourlyScreen({
    super.key,
    this.onBack,
    this.onOpenSwap,
    this.onOpenReceive,
  });

  final VoidCallback? onBack;

  /// 「去兑换」: the wallet's swap page with the suggested pair selected.
  final void Function(MiningSuggestedSwap? swap)? onOpenSwap;

  /// 「去充值」: the wallet's receive page.
  final VoidCallback? onOpenReceive;

  @override
  ConsumerState<MiningRewardsHourlyScreen> createState() =>
      _MiningRewardsHourlyScreenState();
}

class _MiningRewardsHourlyScreenState
    extends ConsumerState<MiningRewardsHourlyScreen>
    with WidgetsBindingObserver {
  Timer? _tick;
  DateTime? _tickFor;
  LoopForegroundPoll? _settlingPoll;
  bool _loadRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _settlingPoll?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background the figure is derived again from the clock;
    // nothing was being counted while away.
    if (state == AppLifecycleState.resumed && mounted) {
      _tick?.cancel();
      _tickFor = null;
      setState(() {});
    }
  }

  DateTime _deviceNow() => ref.read(loopReadClockProvider)().toUtc();

  /// The server clock now, from the answer on screen.
  DateTime _serverNow(MiningRewardsView view) {
    final controller = ref.read(miningRewardsViewControllerProvider.notifier);
    final receivedAt = controller.valueObservedAt ?? _deviceNow();
    return miningServerNow(
      serverTime: view.serverTime,
      receivedAt: receivedAt,
      deviceNow: _deviceNow(),
    );
  }

  /// Arms one timer for the next minute boundary. It only repaints: the
  /// figure is derived again, never incremented.
  void _schedule(MiningMinuteProgress progress, DateTime serverNow) {
    final next = progress.nextUpdateAt;
    if (next == null) {
      _tick?.cancel();
      _tickFor = null;
      return;
    }
    if (_tickFor == next && (_tick?.isActive ?? false)) return;
    _tick?.cancel();
    _tickFor = next;
    var wait = next.difference(serverNow);
    if (wait.isNegative) wait = Duration.zero;
    _tick = Timer(wait + const Duration(milliseconds: 50), () {
      if (mounted) setState(() {});
    });
  }

  void _syncSettlingPoll(bool settling, bool visible) {
    if (!settling) {
      _settlingPoll?.stop();
      _settlingPoll = null;
      return;
    }
    if (_settlingPoll == null) {
      final controller = ref.read(miningRewardsViewControllerProvider.notifier);
      _settlingPoll = LoopForegroundPoll(
        interval: miningSettlingRetry,
        read: controller.reload,
      )..start();
      // The hour just closed: ask once now rather than a whole interval
      // later.
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.reload());
      });
    }
    _settlingPoll!.setVisible(visible);
  }

  Future<void> _refresh() async {
    await Future.wait(<Future<void>>[
      ref.read(miningRewardsViewControllerProvider.notifier).reload(),
      ref.read(miningClaimsControllerProvider.notifier).reload(),
    ]);
  }

  Future<void> _claim(MiningClaimWallet wallet) async {
    final walletId = wallet.walletId;
    if (walletId == null) return;
    final controller = ref.read(miningClaimControllerProvider.notifier);
    final intent = await controller.prepare(walletId: walletId);
    if (!mounted) return;
    final state = ref.read(miningClaimControllerProvider);
    if (intent == null) {
      switch (state.phase) {
        case MiningClaimPhase.gasInsufficient:
          await _openGasSheet(state, swapAvailable: true);
        case MiningClaimPhase.noGasSource:
          await _openGasSheet(state, swapAvailable: false);
        default:
          break;
      }
      return;
    }
    final outcome = await showMiningClaimSignSheet(
      context,
      intent: intent,
      signer: ref.read(miningClaimSignerProvider),
      fromAddress: wallet.address,
      clock: () => ref.read(loopReadClockProvider)(),
    );
    if (!mounted) return;
    controller.recordOutcome(outcome);
  }

  Future<void> _openGasSheet(
    MiningClaimState state, {
    required bool swapAvailable,
  }) async {
    final controller = ref.read(miningClaimControllerProvider.notifier);
    final go = await showLoopSheet<bool>(
      context,
      builder: (context) => MiningClaimGasSheet(
        swapAvailable: swapAvailable,
        swap: state.gasSwap,
        requiredNative: state.requiredNative,
      ),
    );
    if (!mounted) return;
    // Nothing was prepared: the balance stays as it was.
    controller.reset();
    if (go != true) return;
    if (swapAvailable) {
      widget.onOpenSwap?.call(state.gasSwap);
    } else {
      widget.onOpenReceive?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(miningRewardsViewControllerProvider);
    final controller = ref.read(miningRewardsViewControllerProvider.notifier);
    final claims = ref.watch(miningClaimsControllerProvider);
    final claim = ref.watch(miningClaimControllerProvider);
    final wallet = miningClaimWallet(ref);
    if (!_loadRequested) {
      _loadRequested = true;
      scheduleMicrotask(() {
        if (!mounted) return;
        unawaited(controller.load());
        unawaited(ref.read(miningClaimsControllerProvider.notifier).reload());
      });
    }
    final view = state.value;
    // Decision 0184: before the LOOP token is live the page counts power
    // only — no hourly reward, no balance, no claim.
    final live = miningTokenLive(view);
    final restored = controller.restoredObservedAt != null;
    final visible = LoopForegroundPoll.pageVisible(context);

    MiningMinuteProgress? progress;
    if (view != null) {
      final serverNow = _serverNow(view);
      progress = miningMinuteProgress(view, serverNow: serverNow);
      _schedule(progress, serverNow);
      _syncSettlingPoll(
        progress.phase == MiningMinutePhase.settling && !restored,
        visible,
      );
      // A claim the server already has in flight is followed, not resent.
      if (!restored && view.claim.status.inFlight) {
        final claimController = ref.read(
          miningClaimControllerProvider.notifier,
        );
        scheduleMicrotask(() {
          if (mounted) claimController.follow(view.claim);
        });
      }
    } else {
      _syncSettlingPoll(false, visible);
    }

    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('mining-rewards-hourly-screen'),
        archetype: LoopPageArchetype.record,
        title: '挖矿奖励',
        onBack: widget.onBack,
        onRefresh: _refresh,
        updating: state.refreshing,
        primary: view == null || progress == null
            ? null
            : MiningMinuteHero(
                progress: progress,
                epoch: view.lastEpoch,
                awaitingReason: miningAwaitingReason(view),
                live: live,
                nftPower: view.nft?.totalPower,
                assetPower: view.asset?.totalPower,
              ),
        block: view == null && state.phase != LoopChainViewPhase.loading
            ? Center(
                child: LoopChainStateBlock(
                  key: const ValueKey<String>('mining-rewards-state'),
                  keyPrefix: 'mining-rewards',
                  phase: state.phase,
                  failureKind: state.failureKind,
                  emptyMessage: '还没有奖励记录',
                  onRetry: () => unawaited(controller.reload()),
                ),
              )
            : null,
        sections: view == null
            ? <Widget>[
                const LoopSkeleton(
                  key: ValueKey<String>('mining-rewards-state-loading'),
                  type: LoopSkeletonType.list,
                  rows: 6,
                ),
              ]
            : <Widget>[
                if (view.display.state == MiningDisplayState.unavailable)
                  LoopInlineUnavailable(
                    key: const ValueKey<String>('mining-rewards-unavailable'),
                    message: miningDisplayReasonText(
                      view.display.reasonCode,
                      live: live,
                    ),
                    onRetry: () => unawaited(controller.reload()),
                  ),
                if (!live) ...<Widget>[
                  const LoopLabel('算力汇总'),
                  MiningPowerSummary(view: view),
                  // The claim block, whole, is this one line (decision 0184).
                  const LoopNotice(
                    key: ValueKey<String>('mining-power-only-notice'),
                    icon: 'mine',
                    body: miningPowerOnlyNotice,
                    margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
                  ),
                ] else ...<Widget>[
                  const LoopLabel('奖励汇总'),
                  MiningRewardsSummary(view: view),
                  const LoopLabel('领取'),
                  MiningClaimPanel(
                    view: view,
                    claim: claim,
                    restored: restored,
                    wallet: wallet,
                    onClaim: () => unawaited(_claim(wallet)),
                    onRetryReport: () => unawaited(
                      ref
                          .read(miningClaimControllerProvider.notifier)
                          .retryReport(),
                    ),
                    onResume: () => ref
                        .read(miningClaimControllerProvider.notifier)
                        .resumePolling(),
                    onDismiss: () => ref
                        .read(miningClaimControllerProvider.notifier)
                        .reset(),
                  ),
                ],
                const LoopLabel('NFT 轨道'),
                MiningNftTrackCard(track: view.nft, live: live),
                const LoopLabel('Meme 币轨道'),
                MiningAssetTrackCard(track: view.asset, live: live),
                const LoopLabel('五级邀请'),
                MiningInviteTable(invites: view.invites),
                if (live) ...<Widget>[
                  const LoopLabel('领取记录'),
                  MiningClaimRecords(
                    state: claims,
                    onRetry: () => unawaited(
                      ref
                          .read(miningClaimsControllerProvider.notifier)
                          .reload(),
                    ),
                    onLoadMore: () => unawaited(
                      ref
                          .read(miningClaimsControllerProvider.notifier)
                          .loadMore(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                LoopProvenanceLine(
                  key: const ValueKey<String>('mining-rewards-provenance'),
                  sources: const <String>['LOOP 小时结算'],
                  observedAt: controller.valueObservedAt,
                  prefix: restored ? '上次读取' : null,
                  detail: live
                      ? '每个整点（UTC）结算上一小时的 NFT 与 Meme 币两条轨道；'
                            '结算完成后该小时奖励即可领取。分钟增长只是展示上一小时的奖励，'
                            '不改变可领取数量。'
                      : '每个整点（UTC）统计上一小时 NFT 与 Meme 币两条轨道的算力；'
                            'LOOP 代币上线前只统计算力，上线后开始正式开挖。',
                ),
                const SizedBox(height: 24),
              ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 分钟增长 · the page's one large figure
// ---------------------------------------------------------------------------

/// zh-CN for why the page has no settled figures (contract §3.1, §3.4, §7).
/// Three causes are told apart: the settlement store is down, no approved
/// parameter version is in force, or the rules are in force but no hour has
/// settled yet (decision 0143).
String miningDisplayReasonText(String? reasonCode, {bool live = true}) =>
    switch (reasonCode) {
      'MINING_PARAMETERS_PENDING' => '挖矿规则待生效，暂时没有结算。',
      // Decision 0184: before the token is live nothing is shown by the minute
      // and nothing is claimed; the hour's power is what appears.
      'MINING_NOTHING_SETTLED' when !live => '挖矿规则已生效。每个整点统计上一小时的算力，统计后显示在这里。',
      'MINING_SETTLEMENT_UNAVAILABLE' => '结算服务暂时不可用，下面的数字可能不是最新的。',
      // Loop-api 0125 (client 0147): judged on the caller's own hours — no hour
      // with power or reward has settled for this account yet, whatever the
      // network has settled.
      // Decision 0149: the hero's title now says the state (「你有算力的小时还没有
      // 结算」), so this line no longer repeats it — it says what happens next.
      'MINING_NOTHING_SETTLED' => '挖矿规则已生效。每个整点结算上一小时，结算后这里按分钟展示，并可领取。',
      _ => '结算数据暂时读不到，下面的数字可能不是最新的。',
    };

/// The awaiting hero's title (decision 0149). Judged on the caller's own
/// hours (loop-api 0125 / client 0147) it is the account's state, not the
/// network's: the network may have settled many hours already.
String miningAwaitingTitle(String? awaitingReason, {bool live = true}) =>
    awaitingReason == 'MINING_NOTHING_SETTLED'
    ? '你有算力的小时还没有结算'
    : (live ? '首个小时结算后开始展示奖励' : '首个小时结算后开始展示算力');

/// Why nothing has settled yet: `hourly.reasonCode` when the server names
/// one (`MINING_PARAMETERS_PENDING`), otherwise `MINING_NOTHING_SETTLED` from
/// the claim gate (loop-api decision 0123), otherwise none.
String? miningAwaitingReason(MiningRewardsView view) =>
    view.display.reasonCode ??
    (view.claim.reasonCode == 'MINING_NOTHING_SETTLED'
        ? 'MINING_NOTHING_SETTLED'
        : null);

/// The folio's kicker in every phase (decision 0167).
const String miningMinuteKicker = '上一小时奖励';

/// The kicker while the token is not live (decision 0184).
const String miningPowerKicker = '上一小时算力';

/// The page's one primary (decision 0167, docs/33 H2): the prototype's
/// `mining-rewards` lime ledger folio welded into a `.ledger-composite`.
///
/// While an hour is being shown the folio is full Lime — kicker 上一小时奖励,
/// the stepping figure as its heading in Ink, 「n/60 · 下次 HH:mm」 as its
/// caption, 「结算中」 as its stamp while the next hour settles — and the
/// minute progress sits in the strip beneath. Before the first settlement and
/// when the result cannot be read the folio is the quiet ledger with a
/// neutral heading: neither is good news, and neither is Lime.
class MiningMinuteHero extends StatelessWidget {
  const MiningMinuteHero({
    required this.progress,
    this.epoch,
    this.awaitingReason,
    this.live = true,
    this.nftPower,
    this.assetPower,
    super.key,
  });

  final MiningMinuteProgress progress;
  final MiningRewardEpoch? epoch;

  /// [miningAwaitingReason]; read only while awaiting the first settlement.
  final String? awaitingReason;

  /// [miningTokenLive]. While false the folio states the last hour's power
  /// and never a LOOP amount (decision 0184).
  final bool live;

  /// The last settled hour's two track powers, drawn while [live] is false.
  final Decimal? nftPower;
  final Decimal? assetPower;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final kicker = live ? miningMinuteKicker : miningPowerKicker;
    switch (progress.phase) {
      case MiningMinutePhase.awaitingFirstSettlement:
        return LoopLedgerComposite(
          key: const ValueKey<String>('mining-minute-awaiting'),
          primary: LoopFolioPrimary(
            key: const ValueKey<String>('mining-minute-awaiting-title'),
            variant: LoopFolioVariant.quiet,
            archetype: LoopFolioArchetype.record,
            ring: false,
            margin: EdgeInsets.zero,
            squareBottom: true,
            headingTone: LoopFolioHeadingTone.neutral,
            kicker: kicker,
            heading: miningAwaitingTitle(awaitingReason, live: live),
            caption: miningMinuteAwaitingCaption(awaitingReason, live: live),
          ),
          detail: const <Widget>[],
        );
      case MiningMinutePhase.unavailable:
        return LoopLedgerComposite(
          key: const ValueKey<String>('mining-minute-unavailable'),
          primary: LoopFolioPrimary(
            variant: LoopFolioVariant.quiet,
            archetype: LoopFolioArchetype.record,
            ring: false,
            margin: EdgeInsets.zero,
            squareBottom: true,
            headingTone: LoopFolioHeadingTone.neutral,
            kicker: kicker,
            heading: '暂时读不到结算结果',
          ),
          detail: const <Widget>[],
        );
      case MiningMinutePhase.displaying:
      case MiningMinutePhase.settling:
        final settling = progress.phase == MiningMinutePhase.settling;
        if (!live) return _powerFolio(settling: settling);
        final figure = miningLoopFigure(progress.shown);
        return LoopLedgerComposite(
          key: ValueKey<String>(
            settling ? 'mining-minute-settling' : 'mining-minute-displaying',
          ),
          primary: LoopFolioPrimary(
            variant: LoopFolioVariant.lime,
            archetype: LoopFolioArchetype.record,
            ring: false,
            margin: EdgeInsets.zero,
            squareBottom: true,
            kicker: miningMinuteKicker,
            heading: '$figure LOOP',
            headingMaxLines: 1,
            headingBuilder: (heading) => Semantics(
              label: '已展示 $figure LOOP',
              excludeSemantics: true,
              child: _MinuteFigure(
                figure: figure,
                reduceMotion: reduceMotion,
                child: heading,
              ),
            ),
            caption: settling
                ? '下一小时结算后更新'
                : '${progress.completedMinutes}/60 · 下次 ${loopClockLabel(progress.nextUpdateAt!)}',
            stamp: settling ? '结算中' : null,
          ),
          detail: <Widget>[
            LoopProgressBar(
              key: const ValueKey<String>('mining-minute-bar'),
              value: progress.completedMinutes / 60,
              semanticLabel: '第 ${progress.completedMinutes} / 60 分钟',
            ),
            const SizedBox(height: 12),
            LoopCompositeDetailNote(
              '上一小时 ${miningLoopFigure(progress.total)} LOOP',
              key: const ValueKey<String>('mining-minute-total'),
            ),
            if (epoch case final MiningRewardEpoch hour) ...<Widget>[
              const SizedBox(height: 4),
              LoopCompositeDetailNote(
                '结算时段 ${loopClockLabel(hour.epochStart)}–${loopClockLabel(hour.epochEnd)} · '
                '本小时奖励结算后已全部计入可领取',
                key: const ValueKey<String>('mining-minute-epoch'),
              ),
            ],
          ],
        );
    }
  }

  /// The settled hour as power (decision 0184): the folio's heading is the
  /// hour's power, its caption whether the hour counted, and the strip the
  /// two tracks and the settled period. Nothing steps by the minute — the
  /// minute display is a reward's, and there is none yet.
  Widget _powerFolio({required bool settling}) {
    final total = nftPower == null && assetPower == null
        ? null
        : (nftPower ?? Decimal.zero) + (assetPower ?? Decimal.zero);
    final figure = total == null ? loopFigureDash : miningPowerFigure(total);
    final counted = total != null && total > Decimal.zero;
    return LoopLedgerComposite(
      key: ValueKey<String>(
        settling ? 'mining-power-settling' : 'mining-power-displaying',
      ),
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('mining-power-folio'),
        variant: LoopFolioVariant.lime,
        archetype: LoopFolioArchetype.record,
        ring: false,
        margin: EdgeInsets.zero,
        squareBottom: true,
        kicker: miningPowerKicker,
        heading: '$figure 算力',
        headingMaxLines: 1,
        caption: settling
            ? '下一小时结算后更新'
            : (counted ? '上一小时有效，已计入算力统计' : '上一小时没有算力'),
        stamp: settling ? '结算中' : null,
      ),
      detail: <Widget>[
        LoopCompositeDetailNote(
          'NFT 算力 ${nftPower == null ? loopFigureDash : miningPowerFigure(nftPower!)} · '
          'Meme 币算力 ${assetPower == null ? loopFigureDash : miningPowerFigure(assetPower!)}',
          key: const ValueKey<String>('mining-power-tracks'),
        ),
        if (epoch case final MiningRewardEpoch hour) ...<Widget>[
          const SizedBox(height: 4),
          LoopCompositeDetailNote(
            '统计时段 ${loopClockLabel(hour.epochStart)}–${loopClockLabel(hour.epochEnd)} · '
            '每个整点统计一次',
            key: const ValueKey<String>('mining-power-epoch'),
          ),
        ],
      ],
    );
  }
}

/// The awaiting folio's caption: what happens next.
String miningMinuteAwaitingCaption(
  String? awaitingReason, {
  bool live = true,
}) => awaitingReason == null
    ? (live ? '每个整点结算上一小时，下一小时按分钟展示。' : '每个整点统计上一小时的算力。')
    : miningDisplayReasonText(awaitingReason, live: live);

/// The stepping number. Each new minute slides the folio's heading up once;
/// under reduced motion it simply changes.
class _MinuteFigure extends StatelessWidget {
  const _MinuteFigure({
    required this.figure,
    required this.reduceMotion,
    required this.child,
  });

  final String figure;
  final bool reduceMotion;

  /// The heading [Text] as the folio paints it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = KeyedSubtree(
      key: ValueKey<String>('mining-minute-figure-$figure'),
      child: child,
    );
    if (reduceMotion) return label;
    return AnimatedSwitcher(
      duration: LoopMotion.contentFadeIn,
      switchInCurve: LoopMotion.contentFadeCurve,
      transitionBuilder: (child, animation) => ClipRect(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[...previous, ?current],
      ),
      child: label,
    );
  }
}

// ---------------------------------------------------------------------------
// 奖励汇总
// ---------------------------------------------------------------------------

/// 奖励汇总 as the prototype's `.stat-grid` (decision 0167, docs/33 M4).
class MiningRewardsSummary extends StatelessWidget {
  const MiningRewardsSummary({required this.view, super.key});

  final MiningRewardsView view;

  @override
  Widget build(BuildContext context) {
    return LoopStatGrid(
      stats: <LoopStat>[
        LoopStat(
          statKey: const ValueKey<String>('mining-summary-settled'),
          label: '累计已结算 LOOP',
          value: miningLoopFigure(view.settledTotal),
        ),
        LoopStat(
          statKey: const ValueKey<String>('mining-summary-claimed'),
          label: '累计已领取 LOOP',
          value: miningLoopFigure(view.claimedTotal),
        ),
        LoopStat(
          statKey: const ValueKey<String>('mining-summary-claimable'),
          label: '当前可领取 LOOP',
          value: miningLoopFigure(view.claimable),
          // Decision 0149: Lime marks something to take; 0.0000 is not.
          tone: view.claimable > BigInt.zero
              ? LoopStatTone.up
              : LoopStatTone.neutral,
        ),
      ],
    );
  }
}

/// 算力汇总: the 奖励汇总 grid while the token is not live (decision 0184).
/// Power, the two tracks and the invites the server counted — no LOOP.
class MiningPowerSummary extends StatelessWidget {
  const MiningPowerSummary({required this.view, super.key});

  final MiningRewardsView view;

  @override
  Widget build(BuildContext context) {
    final total = miningLastHourPower(view);
    final nft = view.nft?.totalPower;
    final asset = view.asset?.totalPower;
    final invites = view.invites?.total.activeMembers;
    return LoopStatGrid(
      key: const ValueKey<String>('mining-power-summary'),
      stats: <LoopStat>[
        LoopStat(
          statKey: const ValueKey<String>('mining-power-summary-total'),
          label: '上一小时算力',
          value: total == null ? loopFigureDash : miningPowerFigure(total),
          tone: total != null && total > Decimal.zero
              ? LoopStatTone.up
              : LoopStatTone.neutral,
        ),
        LoopStat(
          statKey: const ValueKey<String>('mining-power-summary-nft'),
          label: 'NFT 算力',
          value: nft == null ? loopFigureDash : miningPowerFigure(nft),
        ),
        LoopStat(
          statKey: const ValueKey<String>('mining-power-summary-asset'),
          label: 'Meme 币算力',
          value: asset == null ? loopFigureDash : miningPowerFigure(asset),
        ),
        LoopStat(
          statKey: const ValueKey<String>('mining-power-summary-invites'),
          label: '有效邀请',
          value: invites == null ? loopFigureDash : '$invites 人',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 领取
// ---------------------------------------------------------------------------

/// The five states the requirer names, as the reader sees them.
String miningClaimStatusLabel(MiningClaimStatus status, {required bool any}) =>
    switch (status) {
      MiningClaimStatus.none ||
      MiningClaimStatus.claimable => any ? '可领取' : '暂无可领取',
      MiningClaimStatus.submitting => '提交中',
      MiningClaimStatus.confirming => '链上确认中',
      MiningClaimStatus.succeeded => '成功',
      MiningClaimStatus.failed => '失败',
      MiningClaimStatus.expired => '凭证已过期',
    };

/// What the page says about the claim in progress on this device.
String? miningClaimPhaseText(MiningClaimState state) {
  return switch (state.phase) {
    MiningClaimPhase.idle || MiningClaimPhase.prepared => null,
    MiningClaimPhase.preparing => '正在生成领取凭证，还没有打开钱包。',
    MiningClaimPhase.prepareFailed => miningClaimPrepareFailureText(
      state.failure,
    ),
    MiningClaimPhase.gasInsufficient => 'BNB 不足以支付网络费，先用 USDT 兑换。',
    MiningClaimPhase.noGasSource => '钱包里没有 BNB 支付网络费，先充值 BNB。',
    MiningClaimPhase.signRefused => miningClaimSignReasonText(
      state.outcome?.reasonCode ?? '',
    ),
    MiningClaimPhase.waiting => switch (state.record?.status) {
      MiningClaimStatus.confirming => '已上链，正在等待确认。不要重复领取。',
      _ => '已提交，正在等待上链（已读取 ${state.attempts} 次）。不要重复领取。',
    },
    MiningClaimPhase.locked =>
      state.outcome == null
          ? '这笔领取已锁定，不要重复领取。'
          : miningClaimBroadcastText(state.outcome!),
    MiningClaimPhase.pollTimedOut => '已广播，但还没有读到确认。它可能仍在确认中，请稍后再查；不要重复领取。',
    MiningClaimPhase.succeeded => '领取成功，LOOP 已到账。',
    MiningClaimPhase.failed =>
      '链上领取失败，可领取余额没有减少。'
          '${switch (state.record?.failureReasonCode) {
            null || miningClaimContractNotConfiguredCode => '',
            final String code => '（$code）',
          }}',
    MiningClaimPhase.expired => '领取凭证已过期，没有发放，可领取余额不变。可以重新领取。',
  };
}

/// zh-CN for `hourly.claim.reasonCode` while `executable` is false, in the
/// contract's order (§3.4, loop-api decision 0123; decision 0143). The
/// claimable balance is shown as it is either way. [minimum] is
/// `parameters.minimumClaimRaw`, named by the below-minimum line.
String miningClaimUnavailableText(String? reasonCode, {BigInt? minimum}) =>
    switch (reasonCode) {
      'MINING_SETTLEMENT_UNAVAILABLE' => '结算服务暂时不可用，暂不能领取',
      'MINING_PARAMETERS_PENDING' => '挖矿规则待生效，暂不能领取',
      'MINING_NOTHING_SETTLED' => '有算力的小时结算后可领取',
      'MINING_CLAIM_NOTHING_TO_CLAIM' => '暂无可领取',
      'MINING_CLAIM_BELOW_MINIMUM' =>
        minimum != null && minimum > BigInt.zero
            ? '满 ${miningLoopFigure(minimum)} LOOP 可领取'
            : '可领取数量未达到最低领取数量',
      'MINING_CLAIM_IN_FLIGHT' => '上一笔领取还在处理中，完成后再领取',
      // Decisions 0155 / 0184: not an outage — the token is not on chain
      // yet. The page shows its power-only notice; no configuration wording.
      miningClaimContractNotConfiguredCode => miningPowerOnlyNotice,
      'MINING_CLAIM_CHAIN_NOT_CONFIGURED' => '领取所在的链尚未配置，暂不能领取',
      'MINING_CLAIM_SIGNER_NOT_CONFIGURED' => '领取凭证签发尚未配置，暂不能领取',
      'MINING_CLAIM_WRITES_DISABLED' => '链上写入暂时关闭，暂不能领取',
      'MINING_CLAIM_MAINNET_CLOSED' => '主网领取尚未开放',
      // Loop-api 0125 §8.2: read from the chain only once the first seven
      // gates pass (decision 0147).
      'MINING_CLAIM_CONTRACT_PAUSED' => '领取合约已暂停，暂不能领取',
      'MINING_CLAIM_CHAIN_READ_FAILED' => '领取合约暂时读不到，暂不能领取',
      'MINING_CLAIM_FUNDING_INSUFFICIENT' => '领取合约余额不足，暂不能领取',
      _ => '领取暂不可用',
    };

String miningClaimPrepareFailureText(LoopChainException? failure) {
  final reason = failure?.reasonCode;
  return switch (reason) {
    'MINING_CLAIM_NOTHING_TO_CLAIM' => '现在没有可领取的 LOOP。',
    'MINING_CLAIM_BELOW_MINIMUM' => '可领取数量低于最低领取数量。',
    'MINING_CLAIM_IN_FLIGHT' => '上一笔领取还在处理中，完成后再领取。',
    miningClaimContractNotConfiguredCode => miningPowerOnlyNotice,
    'MINING_CLAIM_SIMULATION_REVERTED' => '试算没有通过，这笔领取在链上会被拒绝。没有提交任何交易。',
    'MINING_CLAIM_CONTRACT_PAUSED' => '领取合约已暂停，余额不变。',
    'MINING_CLAIM_CHAIN_READ_FAILED' => '领取合约暂时读不到，没有生成领取凭证，余额不变。',
    'MINING_CLAIM_FUNDING_INSUFFICIENT' => '领取合约余额不足，暂时不能领取，余额不变。',
    'MINING_CLAIM_EXPIRED' => '领取凭证已过期，没有提交任何交易。请重新领取。',
    'MINING_CLAIM_WALLET_NOT_EMBEDDED' => '只能领取到 LOOP 内置钱包。',
    _ => switch (failure?.kind) {
      LoopChainFailureKind.offline ||
      LoopChainFailureKind.timedOut => '网络不可用，没有生成领取凭证。',
      LoopChainFailureKind.unavailable => '领取暂不可用，余额不变。',
      _ => '没有生成领取凭证，没有提交任何交易。',
    },
  };
}

class MiningClaimPanel extends StatelessWidget {
  const MiningClaimPanel({
    required this.view,
    required this.claim,
    required this.restored,
    required this.wallet,
    required this.onClaim,
    required this.onRetryReport,
    required this.onResume,
    required this.onDismiss,
    super.key,
  });

  final MiningRewardsView view;
  final MiningClaimState claim;

  /// The figures are a stored copy from an earlier run.
  final bool restored;
  final MiningClaimWallet wallet;
  final VoidCallback onClaim;
  final VoidCallback onRetryReport;
  final VoidCallback onResume;
  final VoidCallback onDismiss;

  /// The status the reader sees: this device's attempt when there is one,
  /// otherwise the server's latest claim.
  MiningClaimStatus get _status {
    switch (claim.phase) {
      case MiningClaimPhase.preparing:
      case MiningClaimPhase.prepared:
      case MiningClaimPhase.locked:
      case MiningClaimPhase.pollTimedOut:
        return MiningClaimStatus.submitting;
      case MiningClaimPhase.waiting:
        return claim.record?.status == MiningClaimStatus.confirming
            ? MiningClaimStatus.confirming
            : MiningClaimStatus.submitting;
      case MiningClaimPhase.succeeded:
        return MiningClaimStatus.succeeded;
      case MiningClaimPhase.failed:
        return MiningClaimStatus.failed;
      case MiningClaimPhase.expired:
        return MiningClaimStatus.expired;
      case MiningClaimPhase.idle:
      case MiningClaimPhase.prepareFailed:
      case MiningClaimPhase.gasInsufficient:
      case MiningClaimPhase.noGasSource:
      case MiningClaimPhase.signRefused:
        return view.claim.status;
    }
  }

  String? get _disabledReason {
    if (restored) return '正在读取最新的可领取数量';
    if (claim.busy || claim.locked) return null;
    if (view.claim.status.inFlight) {
      return miningClaimUnavailableText('MINING_CLAIM_IN_FLIGHT');
    }
    if (!view.claim.executable) {
      return miningClaimUnavailableText(
        view.claim.reasonCode,
        minimum: view.minimumClaim,
      );
    }
    if (view.claimable <= BigInt.zero) return '现在没有可领取的 LOOP';
    final minimum = view.minimumClaim;
    if (minimum != null && view.claimable < minimum) {
      return '满 ${miningLoopFigure(minimum)} LOOP 可领取';
    }
    if (wallet.walletId == null) {
      return wallet.loading ? '正在读取钱包' : '没有可用的钱包';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final any = view.claimable > BigInt.zero;
    final disabled = _disabledReason;
    final canClaim =
        disabled == null &&
        !claim.busy &&
        !claim.locked &&
        claim.phase != MiningClaimPhase.prepared;
    final note = miningClaimPhaseText(claim);
    final tx = switch (claim.record) {
      final MiningClaimRecord record
          when record.status == MiningClaimStatus.succeeded =>
        record.tx,
      _ =>
        view.claim.status == MiningClaimStatus.succeeded
            ? view.claim.lastTx
            : null,
    };
    return LoopRecordCard(
      key: const ValueKey<String>('mining-claim-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('领取状态', style: LoopType.eyebrow)),
              // Status, never a price move: no rise / fall (0117).
              LoopBadge(
                miningClaimStatusLabel(status, any: any),
                key: ValueKey<String>('mining-claim-status-${status.wireName}'),
                kind: miningClaimStatusBadge(status, any: any),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LoopKeyValue(
            key: const ValueKey<String>('mining-claim-amount'),
            label: '本次可领取',
            value: '${miningLoopFigure(view.claimable)} LOOP',
            padding: const EdgeInsets.symmetric(vertical: 6),
          ),
          if (view.minimumClaim case final BigInt minimum
              when minimum > BigInt.zero)
            LoopKeyValue(
              key: const ValueKey<String>('mining-claim-minimum'),
              label: '最低领取',
              value: '${miningLoopFigure(minimum)} LOOP',
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          const SizedBox(height: 14),
          if (claim.phase == MiningClaimPhase.locked &&
              claim.outcome?.status == MoneySignStatus.reportRefused)
            LoopButton(
              key: const ValueKey<String>('mining-claim-retry-report'),
              label: '重新上报',
              block: true,
              onPressed: onRetryReport,
            )
          else if (claim.phase == MiningClaimPhase.pollTimedOut)
            LoopButton(
              key: const ValueKey<String>('mining-claim-resume'),
              label: '继续查询',
              block: true,
              onPressed: onResume,
            )
          else
            LoopButton(
              key: const ValueKey<String>('mining-claim-button'),
              label: claim.busy || claim.locked ? '领取处理中' : '领取',
              // The folio above is the screen's one full Lime (docs/33
              // §1.5): the claim is the quiet block button.
              block: true,
              onPressed: canClaim ? onClaim : null,
              semanticLabel: canClaim ? '领取' : '领取，当前不可用',
            ),
          if (note != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              note,
              key: const ValueKey<String>('mining-claim-note'),
              style: LoopType.caption,
            ),
          ] else if (disabled != null && !claim.locked) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              disabled,
              key: const ValueKey<String>('mining-claim-disabled'),
              style: LoopType.caption,
            ),
          ],
          if (tx != null) ...<Widget>[
            const SizedBox(height: 8),
            _ClaimTxLink(tx: tx),
          ],
        ],
      ),
    );
  }
}

/// The claim status as a `.badge` (decision 0167): Lime-soft for a claim
/// that is moving or done, the neutral pair for one that did not land or
/// has nothing to take.
LoopBadgeKind miningClaimStatusBadge(
  MiningClaimStatus status, {
  required bool any,
}) => switch (status) {
  MiningClaimStatus.succeeded => LoopBadgeKind.up,
  MiningClaimStatus.submitting ||
  MiningClaimStatus.confirming => LoopBadgeKind.mining,
  MiningClaimStatus.failed || MiningClaimStatus.expired => LoopBadgeKind.down,
  MiningClaimStatus.none || MiningClaimStatus.claimable =>
    any ? LoopBadgeKind.mining : LoopBadgeKind.mute,
};

class _ClaimTxLink extends StatelessWidget {
  const _ClaimTxLink({required this.tx});

  final MiningClaimTx tx;

  @override
  Widget build(BuildContext context) {
    return LoopRecordRow(
      key: const ValueKey<String>('mining-claim-tx'),
      leading: const LoopRowIcon(icon: 'link'),
      title: '成功交易 ${miningShortHash(tx.txHash)}',
      subtitle: '复制 BscScan 链接',
      onTap: () => unawaited(
        LoopCopy.text(context, tx.explorerUrl, message: 'BscScan 链接已复制'),
      ),
    );
  }
}

/// 「BNB 不足」 and 「没有 BNB」: one sheet, one next step.
class MiningClaimGasSheet extends StatelessWidget {
  const MiningClaimGasSheet({
    required this.swapAvailable,
    super.key,
    this.swap,
    this.requiredNative,
  });

  final bool swapAvailable;
  final MiningSuggestedSwap? swap;
  final String? requiredNative;

  @override
  Widget build(BuildContext context) {
    final need = requiredNative == null ? '' : '这次领取约需 $requiredNative BNB。';
    final from = swap?.fromSymbol ?? 'USDT';
    final to = swap?.toSymbol ?? 'BNB';
    return Column(
      key: ValueKey<String>(
        swapAvailable ? 'mining-claim-gas-swap' : 'mining-claim-gas-none',
      ),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSheetHeading(swapAvailable ? '网络费不足' : '需要 BNB 支付网络费'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            swapAvailable
                ? 'BNB 不足以支付网络费，先用 $from 兑换 $to。$need'
                      '兑换完成后回来再领取，可领取余额不变。'
                : '钱包里没有 BNB，也没有可兑换的 USDT。$need'
                      '先向钱包充值少量 BNB，再回来领取。',
            style: LoopType.body.copyWith(color: LoopColors.text2),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LoopButton(
            key: const ValueKey<String>('mining-claim-gas-go'),
            label: swapAvailable ? '去兑换' : '去充值',
            primary: true,
            block: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LoopButton(
            key: const ValueKey<String>('mining-claim-gas-cancel'),
            label: '取消',
            block: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The two tracks
// ---------------------------------------------------------------------------

/// `.kv` inside a track card: no gutter of its own, the card has one.
const EdgeInsets _factPadding = EdgeInsets.symmetric(vertical: 7);

LoopKeyValue _fact(String label, String value, {Key? key}) =>
    LoopKeyValue(key: key, label: label, value: value, padding: _factPadding);

/// The NFT / Meme / invite blocks as `.record-card` (decision 0167).
class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LoopRecordCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

Widget _trackPending(String key) => Padding(
  key: ValueKey<String>(key),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Text(
    // Decision 0149: the hero names whose hour (「你有算力的小时」); the
    // track lines no longer repeat 「首个小时」 under it.
    '有算力的小时结算后显示',
    style: LoopType.caption,
  ),
);

class MiningNftTrackCard extends StatelessWidget {
  const MiningNftTrackCard({required this.track, this.live = true, super.key});

  final MiningNftTrack? track;

  /// [miningTokenLive]: the hour's LOOP reward line is drawn only then.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final nft = track;
    if (nft == null) return _trackPending('mining-nft-pending');
    return _TrackCard(
      key: const ValueKey<String>('mining-nft-track'),
      children: <Widget>[
        // The real count and the weighted power are two facts; an invite
        // power never reads as NFTs held (requirer §8.1).
        _fact(
          '持有 NFT（真实数量）',
          nft.realCount.toString(),
          key: const ValueKey<String>('mining-nft-real-count'),
        ),
        _fact('本人加权算力', miningPowerFigure(nft.ownPower)),
        _fact('邀请算力', miningPowerFigure(nft.invitePower)),
        _fact('总算力', miningPowerFigure(nft.totalPower)),
        if (live) ...<Widget>[
          const LoopHairline(margin: EdgeInsets.symmetric(vertical: 4)),
          _fact(
            '上一小时奖励',
            '${miningLoopFigure(nft.reward)} LOOP',
            key: const ValueKey<String>('mining-nft-reward'),
          ),
        ],
      ],
    );
  }
}

/// zh-CN for `tracks.asset.excludedAssets[].reasonCode`. Decision 0148
/// (loop-api S150 / 0126): quantity-basis hours name a balance still being
/// synced, never a price; the unreadable code is left for replayed
/// pre-0123 hours. A code without a line is 「暂不计入」, never the code.
String miningExcludedReasonText(String reasonCode) => switch (reasonCode) {
  'MINING_ASSET_GRADUATED_BALANCE_PENDING' => '已毕业，外盘持有数量还在同步',
  'MINING_ASSET_GRADUATED_UNREADABLE' => '已毕业，外盘持有数量暂读不到',
  'MINING_ASSET_WEIGHT_NOT_CONFIGURED' => '还没有配置挖矿权重',
  _ => '暂不计入',
};

class MiningAssetTrackCard extends StatelessWidget {
  const MiningAssetTrackCard({
    required this.track,
    this.live = true,
    super.key,
  });

  final MiningAssetTrack? track;

  /// [miningTokenLive]: the hour's LOOP reward line is drawn only then.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final asset = track;
    if (asset == null) return _trackPending('mining-asset-pending');
    return _TrackCard(
      key: const ValueKey<String>('mining-asset-track'),
      children: <Widget>[
        if (asset.assets.isEmpty)
          Padding(
            key: const ValueKey<String>('mining-asset-empty'),
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text('上一小时没有计入挖矿的 Meme 币', style: LoopType.caption),
          )
        else
          for (final item in asset.assets)
            _fact(
              item.label,
              miningPowerFigure(item.power),
              key: ValueKey<String>('mining-asset-${item.assetId}'),
            ),
        // An asset that left the pool is named with the reason, never
        // silently dropped (contract §3.3, loop-api decision 0116 §5).
        for (final item in asset.excluded)
          _fact(
            item.label,
            '已退出（${miningExcludedReasonText(item.reasonCode)}）',
            key: ValueKey<String>('mining-asset-excluded-${item.assetId}'),
          ),
        const LoopHairline(margin: EdgeInsets.symmetric(vertical: 4)),
        // Decision 0123 (loop-api): asset power is the hour's average holding
        // quantity times the approved mining weight; no price enters it.
        Padding(
          key: const ValueKey<String>('mining-asset-basis'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('按持有数量加权：算力 = 该小时平均持有数量 × 挖矿权重', style: LoopType.caption),
        ),
        _fact('本人算力', miningPowerFigure(asset.ownPower)),
        _fact('邀请算力', miningPowerFigure(asset.invitePower)),
        _fact('总算力', miningPowerFigure(asset.totalPower)),
        if (live) ...<Widget>[
          const LoopHairline(margin: EdgeInsets.symmetric(vertical: 4)),
          _fact(
            '上一小时奖励',
            '${miningLoopFigure(asset.reward)} LOOP',
            key: const ValueKey<String>('mining-asset-reward'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 五级邀请
// ---------------------------------------------------------------------------

class MiningInviteTable extends StatelessWidget {
  const MiningInviteTable({required this.invites, super.key});

  final MiningInvites? invites;

  static const List<int> _flex = <int>[3, 2, 2, 3, 3];

  Widget _row(
    List<String> cells, {
    Key? key,
    bool head = false,
    bool strong = false,
  }) {
    // The head row is the prototype's `.label` (mono 10, uppercase, Text3);
    // figures are the `.kv` mono, the 合计 row in Chalk.
    final style = head
        ? LoopType.kicker
        : strong
        ? LoopTypography.withWeight(
            LoopType.figureXs,
            FontWeight.w600,
          ).copyWith(color: LoopColors.chalk)
        : LoopTypography.withWeight(LoopType.figureXs, FontWeight.w500);
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          for (final (index, cell) in cells.indexed)
            Expanded(
              flex: _flex[index],
              child: Text(
                cell,
                textAlign: index == 0 ? TextAlign.left : TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: index == 0 && !head
                    ? LoopType.captionSm.copyWith(color: LoopColors.text2)
                    : style,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = invites;
    if (data == null) return _trackPending('mining-invite-pending');
    return _TrackCard(
      key: const ValueKey<String>('mining-invite-table'),
      children: <Widget>[
        _row(const <String>['层级', '比例', '有效人数', 'NFT 算力', '资产算力'], head: true),
        for (final level in data.levels)
          _row(<String>[
            '第 ${level.level} 级',
            miningRateLabel(level.ratePercent),
            '${level.activeMembers}',
            miningPowerFigure(level.nftPower),
            miningPowerFigure(level.assetPower),
          ], key: ValueKey<String>('mining-invite-level-${level.level}')),
        const LoopHairline(margin: EdgeInsets.symmetric(vertical: 2)),
        _row(
          <String>[
            '合计',
            '',
            '${data.total.activeMembers}',
            miningPowerFigure(data.total.nftPower),
            miningPowerFigure(data.total.assetPower),
          ],
          key: const ValueKey<String>('mining-invite-total'),
          strong: true,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            '只计下级本人算力，本人算力为 0 的下级不计；等效 NFT 算力只用于奖励计算。',
            style: LoopType.caption,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 领取记录
// ---------------------------------------------------------------------------

class MiningClaimRecords extends StatelessWidget {
  const MiningClaimRecords({
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
    super.key,
  });

  final MiningClaimsState state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      if (state.phase == LoopChainViewPhase.empty) {
        return const LoopEmptyState(
          key: ValueKey<String>('mining-claims-empty'),
          illustration: LoopIllustration.history,
          title: '还没有领取记录',
          compact: true,
        );
      }
      return LoopChainStateBlock(
        keyPrefix: 'mining-claims',
        phase: state.phase,
        failureKind: state.failureKind,
        rows: 2,
        onRetry: onRetry,
      );
    }
    final rows = <LoopRecordRow>[
      for (final item in state.items)
        LoopRecordRow(
          key: ValueKey<String>('mining-claim-record-${item.claimId}'),
          leading: const LoopRowIcon(icon: 'parachute'),
          title: '领取 ${miningLoopFigure(item.amount)} LOOP',
          subtitle: <String>[
            miningClaimStatusLabel(item.status, any: true),
            loopDateTimeLabel(item.createdAt),
            if (item.txHash != null) miningShortHash(item.txHash!),
          ].join(' · '),
          chevron: item.tx != null,
          readOnly: item.tx == null,
          onTap: item.tx == null
              ? null
              : () => unawaited(
                  LoopCopy.text(
                    context,
                    item.tx!.explorerUrl,
                    message: 'BscScan 链接已复制',
                  ),
                ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(rows: rows),
        if (state.nextCursor case final String cursor)
          state.moreFailed
              ? LoopInlineUnavailable(message: '更早的记录没有读到', onRetry: onLoadMore)
              : LoopLoadMoreSentinel(cursor: cursor, onLoadMore: onLoadMore),
      ],
    );
  }
}
