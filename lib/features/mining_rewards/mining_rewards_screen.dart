import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_foreground_poll.dart';
import 'package:loop_mobile/features/meme/meme_design.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_controllers.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_display.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_provenance_scope.dart';
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
        title: context.l10n.mining_widgetsMiningSummaryHeroClaimLabel,
        onBack: widget.onBack,
        // S336 · decision 0265: the page's one (i) holds its explanations,
        // then the settlement source the foot reports.
        actions: <Widget>[
          LoopPageInfoAction(
            key: const ValueKey<String>('mining-rewards-info-action'),
            title:
                context.l10n.miningRewards_screenMiningRewardsInfoActionTitle,
            label:
                context.l10n.miningRewards_screenMiningRewardsInfoActionTitle,
            notes: miningRewardsInfoNotes(
              view,
              live: live,
              settling: progress?.phase == MiningMinutePhase.settling,
              progress: progress,
            ),
            sheetKey: 'mining-rewards-info-sheet',
          ),
        ],
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
                  emptyMessage: context
                      .l10n
                      .miningRewards_screenMiningRewardsStateEmptyMessage,
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
                  LoopLabel(context.l10n.miningRewards_screenLoopLabel),
                  MiningPowerSummary(view: view),
                  // S336 · decision 0265: 「LOOP 代币上线后开始正式开挖…」
                  // is said in the page's (i), not under the grid.
                ] else ...<Widget>[
                  LoopLabel(context.l10n.miningRewards_screenLoopLabel2),
                  MiningRewardsSummary(view: view),
                  LoopLabel(context.l10n.common_claim),
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
                LoopLabel(context.l10n.miningRewards_screenLoopLabel3),
                MiningNftTrackCard(track: view.nft, live: live),
                LoopLabel(context.l10n.miningRewards_screenLoopLabel4),
                MiningAssetTrackCard(track: view.asset, live: live),
                LoopLabel(context.l10n.miningRewards_screenLoopLabel5),
                MiningInviteTable(invites: view.invites),
                if (live) ...<Widget>[
                  LoopLabel(context.l10n.miningRewards_screenLoopLabel6),
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
                  sources: <String>[
                    context.l10n.miningRewards_screenLoopProvenanceLine,
                  ],
                  observedAt: controller.valueObservedAt,
                  prefix: restored
                      ? context
                            .l10n
                            .miningRewards_screenMiningRewardsProvenancePrefix
                      : null,
                  detail: live
                      ? context
                            .l10n
                            .miningRewards_screenMiningRewardsProvenanceDetail
                      : context
                            .l10n
                            .miningRewards_screenMiningRewardsProvenanceDetail2,
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
      'MINING_PARAMETERS_PENDING' =>
        LoopL10n.current.miningRewards_screenSwitch,
      // Decision 0184: before the token is live nothing is shown by the minute
      // and nothing is claimed; the hour's power is what appears.
      'MINING_NOTHING_SETTLED' when !live =>
        LoopL10n.current.miningRewards_screenSwitch2,
      'MINING_SETTLEMENT_UNAVAILABLE' =>
        LoopL10n.current.miningRewards_screenSwitch3,
      // Loop-api 0125 (client 0147): judged on the caller's own hours — no hour
      // with power or reward has settled for this account yet, whatever the
      // network has settled.
      // Decision 0149: the hero's title now says the state (「你有算力的小时还没有
      // 结算」), so this line no longer repeats it — it says what happens next.
      'MINING_NOTHING_SETTLED' => LoopL10n.current.miningRewards_screenSwitch4,
      _ => LoopL10n.current.miningRewards_screenSwitch5,
    };

/// The awaiting hero's title (decision 0149). Judged on the caller's own
/// hours (loop-api 0125 / client 0147) it is the account's state, not the
/// network's: the network may have settled many hours already.
String miningAwaitingTitle(String? awaitingReason, {bool live = true}) =>
    awaitingReason == 'MINING_NOTHING_SETTLED'
    ? LoopL10n.current.miningRewards_screenSwitch6
    : (live
          ? LoopL10n.current.miningRewards_screenSwitch7
          : LoopL10n.current.miningRewards_screenS);

/// Why nothing has settled yet: `hourly.reasonCode` when the server names
/// one (`MINING_PARAMETERS_PENDING`), otherwise `MINING_NOTHING_SETTLED` from
/// the claim gate (loop-api decision 0123), otherwise none.
String? miningAwaitingReason(MiningRewardsView view) =>
    view.display.reasonCode ??
    (view.claim.reasonCode == 'MINING_NOTHING_SETTLED'
        ? 'MINING_NOTHING_SETTLED'
        : null);

/// The folio's kicker in every phase (decision 0167).
String get miningMinuteKicker =>
    LoopL10n.current.miningRewards_screenMiningMinuteKicker;

/// The kicker while the token is not live (decision 0184).
String get miningPowerKicker => LoopL10n.current.mining_screenLabel3;

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
            heading: context.l10n.miningRewards_screenHeading,
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
            variant: LoopFolioVariant.quiet,
            archetype: LoopFolioArchetype.record,
            ring: false,
            margin: EdgeInsets.zero,
            squareBottom: true,
            kicker: miningMinuteKicker,
            heading: '$figure LOOP',
            headingMaxLines: 1,
            headingBuilder: (heading) => Semantics(
              label: context.l10n.miningRewards_screenLabel(figure),
              excludeSemantics: true,
              child: _MinuteFigure(
                figure: figure,
                reduceMotion: reduceMotion,
                child: heading,
              ),
            ),
            caption: settling
                ? context.l10n.miningRewards_screenCaption
                : context.l10n.miningRewards_screenCaption2(
                    loopClockLabel(progress.nextUpdateAt!),
                    progress.completedMinutes,
                  ),
            stamp: settling ? context.l10n.miningRewards_screenStamp : null,
          ),
          detail: <Widget>[
            // S336 · decision 0265: the strip is the minute bar alone; the
            // hour's total and period are said in the page's (i).
            LoopProgressBar(
              key: const ValueKey<String>('mining-minute-bar'),
              value: progress.completedMinutes / 60,
              semanticLabel: context.l10n
                  .miningRewards_screenMiningMinuteBarSemanticLabel(
                    progress.completedMinutes,
                  ),
            ),
          ],
        );
    }
  }

  /// The settled hour as power (decision 0184): the folio's heading is the
  /// hour's power. Nothing steps by the minute — the minute display is a
  /// reward's, and there is none yet. S336 · decision 0265: the hour's
  /// explanation (whether it counted, the two tracks, the period) moved to
  /// the page's (i), [miningRewardsInfoNotes]; the folio stands alone.
  Widget _powerFolio({required bool settling}) {
    final total = nftPower == null && assetPower == null
        ? null
        : (nftPower ?? Decimal.zero) + (assetPower ?? Decimal.zero);
    final figure = total == null ? loopFigureDash : miningPowerFigure(total);
    final counted = total != null && total > Decimal.zero;
    final caption = settling
        ? LoopL10n.current.miningRewards_screenCaption
        : (counted ? null : LoopL10n.current.miningRewards_screenNull);
    return LoopLedgerComposite(
      key: ValueKey<String>(
        settling ? 'mining-power-settling' : 'mining-power-displaying',
      ),
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('mining-power-folio'),
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        ring: false,
        margin: EdgeInsets.zero,
        kicker: miningPowerKicker,
        heading: LoopL10n.current.miningRewards_screenMiningPowerFolioHeading(
          figure,
        ),
        headingMaxLines: 1,
        caption: caption,
        // With no caption the card closes under its heading (as 邀请中心,
        // decision 0243 S293b).
        minHeight: caption == null ? 0 : null,
        stamp: settling ? LoopL10n.current.miningRewards_screenStamp : null,
      ),
      detail: const <Widget>[],
    );
  }
}

/// The awaiting folio's caption: what happens next.
String miningMinuteAwaitingCaption(
  String? awaitingReason, {
  bool live = true,
}) => awaitingReason == null
    ? (live
          ? LoopL10n.current.miningRewards_screenPowerFolio
          : LoopL10n.current.miningRewards_screenS2)
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
    return MemeStatFigures(
      stats: <LoopStat>[
        LoopStat(
          statKey: const ValueKey<String>('mining-summary-settled'),
          label: context.l10n.miningRewards_screenLabel2,
          value: miningLoopFigure(view.settledTotal),
        ),
        LoopStat(
          statKey: const ValueKey<String>('mining-summary-claimed'),
          label: context.l10n.miningRewards_screenLabel3,
          value: miningLoopFigure(view.claimedTotal),
        ),
        LoopStat(
          statKey: const ValueKey<String>('mining-summary-claimable'),
          label: context.l10n.miningRewards_screenLabel4,
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
    return MemeStatFigures(
      key: const ValueKey<String>('mining-power-summary'),
      stats: <LoopStat>[
        LoopStat(
          statKey: const ValueKey<String>('mining-power-summary-total'),
          label: context.l10n.mining_screenLabel3,
          value: total == null ? loopFigureDash : miningPowerFigure(total),
          tone: total != null && total > Decimal.zero
              ? LoopStatTone.up
              : LoopStatTone.neutral,
        ),
        LoopStat(
          statKey: const ValueKey<String>('mining-power-summary-nft'),
          label: context.l10n.mining_screenCell2,
          value: nft == null ? loopFigureDash : miningPowerFigure(nft),
        ),
        LoopStat(
          statKey: const ValueKey<String>('mining-power-summary-asset'),
          label: context.l10n.miningRewards_screenLabel6,
          value: asset == null ? loopFigureDash : miningPowerFigure(asset),
        ),
        LoopStat(
          statKey: const ValueKey<String>('mining-power-summary-invites'),
          label: context.l10n.mining_screenLabel4,
          value: invites == null
              ? loopFigureDash
              : context.l10n.mining_screenValue(invites),
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
      MiningClaimStatus.none || MiningClaimStatus.claimable =>
        any
            ? LoopL10n.current.miningRewards_screenSwitch8
            : LoopL10n.current.miningRewards_screenS3,
      MiningClaimStatus.submitting => LoopL10n.current.common_submitting,
      MiningClaimStatus.confirming =>
        LoopL10n.current.miningRewards_screenConfirming,
      MiningClaimStatus.succeeded => LoopL10n.current.common_success,
      MiningClaimStatus.failed => LoopL10n.current.common_failed,
      MiningClaimStatus.expired => LoopL10n.current.miningRewards_screenExpired,
    };

/// What the page says about the claim in progress on this device.
String? miningClaimPhaseText(MiningClaimState state) {
  return switch (state.phase) {
    MiningClaimPhase.idle || MiningClaimPhase.prepared => null,
    MiningClaimPhase.preparing =>
      LoopL10n.current.miningRewards_screenPreparing,
    MiningClaimPhase.prepareFailed => miningClaimPrepareFailureText(
      state.failure,
    ),
    MiningClaimPhase.gasInsufficient =>
      LoopL10n.current.miningRewards_screenGasInsufficient,
    MiningClaimPhase.noGasSource =>
      LoopL10n.current.miningRewards_screenNoGasSource,
    MiningClaimPhase.signRefused => miningClaimSignReasonText(
      state.outcome?.reasonCode ?? '',
    ),
    MiningClaimPhase.waiting => switch (state.record?.status) {
      MiningClaimStatus.confirming =>
        LoopL10n.current.miningRewards_screenConfirming2,
      _ => LoopL10n.current.miningRewards_screenSwitch9(state.attempts),
    },
    MiningClaimPhase.locked =>
      state.outcome == null
          ? LoopL10n.current.miningRewards_screenSwitch10
          : miningClaimBroadcastText(state.outcome!),
    MiningClaimPhase.pollTimedOut =>
      LoopL10n.current.miningRewards_screenPollTimedOut,
    MiningClaimPhase.succeeded =>
      LoopL10n.current.miningRewards_screenSucceeded,
    MiningClaimPhase.failed => LoopL10n.current.miningRewards_screenFailed(
      switch (state.record?.failureReasonCode) {
        null || miningClaimContractNotConfiguredCode => '',
        final String code => LoopL10n.current.miningRewards_screenFailedCode(
          code,
        ),
      },
    ),
    MiningClaimPhase.expired => LoopL10n.current.miningRewards_screenExpired2,
  };
}

/// zh-CN for `hourly.claim.reasonCode` while `executable` is false, in the
/// contract's order (§3.4, loop-api decision 0123; decision 0143). The
/// claimable balance is shown as it is either way. [minimum] is
/// `parameters.minimumClaimRaw`, named by the below-minimum line.
String miningClaimUnavailableText(
  String? reasonCode, {
  BigInt? minimum,
}) => switch (reasonCode) {
  'MINING_SETTLEMENT_UNAVAILABLE' =>
    LoopL10n.current.miningRewards_screenSwitch11,
  'MINING_PARAMETERS_PENDING' => LoopL10n.current.miningRewards_screenSwitch12,
  'MINING_NOTHING_SETTLED' => LoopL10n.current.miningRewards_screenSwitch13,
  'MINING_CLAIM_NOTHING_TO_CLAIM' => LoopL10n.current.miningRewards_screenS3,
  'MINING_CLAIM_BELOW_MINIMUM' =>
    minimum != null && minimum > BigInt.zero
        ? LoopL10n.current.miningRewards_screenSwitch14(
            miningLoopFigure(minimum),
          )
        : LoopL10n.current.miningRewards_screenS4,
  'MINING_CLAIM_IN_FLIGHT' => LoopL10n.current.miningRewards_screenSwitch15,
  // Decisions 0155 / 0184: not an outage — the token is not on chain
  // yet. The page shows its power-only notice; no configuration wording.
  miningClaimContractNotConfiguredCode => miningPowerOnlyNotice,
  'MINING_CLAIM_CHAIN_NOT_CONFIGURED' =>
    LoopL10n.current.miningRewards_screenSwitch16,
  'MINING_CLAIM_SIGNER_NOT_CONFIGURED' =>
    LoopL10n.current.miningRewards_screenSwitch17,
  'MINING_CLAIM_WRITES_DISABLED' =>
    LoopL10n.current.miningRewards_screenSwitch18,
  'MINING_CLAIM_MAINNET_CLOSED' =>
    LoopL10n.current.miningRewards_screenSwitch19,
  // Loop-api 0125 §8.2: read from the chain only once the first seven
  // gates pass (decision 0147).
  'MINING_CLAIM_CONTRACT_PAUSED' =>
    LoopL10n.current.miningRewards_screenSwitch20,
  'MINING_CLAIM_CHAIN_READ_FAILED' =>
    LoopL10n.current.miningRewards_screenSwitch21,
  'MINING_CLAIM_FUNDING_INSUFFICIENT' =>
    LoopL10n.current.miningRewards_screenSwitch22,
  _ => LoopL10n.current.miningRewards_screenSwitch23,
};

String miningClaimPrepareFailureText(LoopChainException? failure) {
  final reason = failure?.reasonCode;
  return switch (reason) {
    'MINING_CLAIM_NOTHING_TO_CLAIM' =>
      LoopL10n.current.miningRewards_screenSwitch24,
    'MINING_CLAIM_BELOW_MINIMUM' =>
      LoopL10n.current.miningRewards_screenSwitch25,
    'MINING_CLAIM_IN_FLIGHT' => LoopL10n.current.miningRewards_screenSwitch26,
    miningClaimContractNotConfiguredCode => miningPowerOnlyNotice,
    'MINING_CLAIM_SIMULATION_REVERTED' =>
      LoopL10n.current.miningRewards_screenSwitch27,
    'MINING_CLAIM_CONTRACT_PAUSED' =>
      LoopL10n.current.miningRewards_screenSwitch28,
    'MINING_CLAIM_CHAIN_READ_FAILED' =>
      LoopL10n.current.miningRewards_screenSwitch29,
    'MINING_CLAIM_FUNDING_INSUFFICIENT' =>
      LoopL10n.current.miningRewards_screenSwitch30,
    'MINING_CLAIM_EXPIRED' => LoopL10n.current.miningRewards_screenSwitch31,
    'MINING_CLAIM_WALLET_NOT_EMBEDDED' =>
      LoopL10n.current.miningRewards_screenSwitch32,
    _ => switch (failure?.kind) {
      LoopChainFailureKind.offline || LoopChainFailureKind.timedOut =>
        LoopL10n.current.miningRewards_screenTimedOut,
      LoopChainFailureKind.unavailable =>
        LoopL10n.current.miningRewards_screenUnavailable,
      _ => LoopL10n.current.miningRewards_screenSwitch33,
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
    if (restored) return LoopL10n.current.miningRewards_screenDisabledReason;
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
    if (view.claimable <= BigInt.zero) {
      return LoopL10n.current.miningRewards_screenIf;
    }
    final minimum = view.minimumClaim;
    if (minimum != null && view.claimable < minimum) {
      return LoopL10n.current.miningRewards_screenSwitch14(
        miningLoopFigure(minimum),
      );
    }
    if (wallet.walletId == null) {
      return wallet.loading
          ? LoopL10n.current.miningRewards_screenIf2
          : LoopL10n.current.miningRewards_screenS5;
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
              Expanded(
                child: Text(
                  context.l10n.miningRewards_screenSwitch34,
                  style: LoopType.eyebrow,
                ),
              ),
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
            label: context.l10n.miningRewards_screenMiningClaimAmountLabel,
            value: '${miningLoopFigure(view.claimable)} LOOP',
            padding: const EdgeInsets.symmetric(vertical: 6),
          ),
          if (view.minimumClaim case final BigInt minimum
              when minimum > BigInt.zero)
            LoopKeyValue(
              key: const ValueKey<String>('mining-claim-minimum'),
              label: context.l10n.miningRewards_screenMiningClaimMinimumLabel,
              value: '${miningLoopFigure(minimum)} LOOP',
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          const SizedBox(height: 14),
          if (claim.phase == MiningClaimPhase.locked &&
              claim.outcome?.status == MoneySignStatus.reportRefused)
            LoopButton(
              key: const ValueKey<String>('mining-claim-retry-report'),
              label:
                  context.l10n.miningRewards_screenMiningClaimRetryReportLabel,
              block: true,
              onPressed: onRetryReport,
            )
          else if (claim.phase == MiningClaimPhase.pollTimedOut)
            LoopButton(
              key: const ValueKey<String>('mining-claim-resume'),
              label: context.l10n.miningRewards_screenMiningClaimResumeLabel,
              block: true,
              onPressed: onResume,
            )
          else
            LoopButton(
              key: const ValueKey<String>('mining-claim-button'),
              label: claim.busy || claim.locked
                  ? context.l10n.miningRewards_screenMiningClaimButtonLabel
                  : context.l10n.common_claim,
              // The folio above is the screen's one full Lime (docs/33
              // §1.5): the claim is the quiet block button.
              block: true,
              onPressed: canClaim ? onClaim : null,
              semanticLabel: canClaim
                  ? context.l10n.common_claim
                  : context
                        .l10n
                        .miningRewards_screenMiningClaimButtonSemanticLabel,
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
      title: context.l10n.miningRewards_screenMiningClaimTxTitle(
        miningShortHash(tx.txHash),
      ),
      subtitle: context.l10n.miningRewards_screenMiningClaimTxSubtitle,
      onTap: () => unawaited(
        LoopCopy.text(
          context,
          tx.explorerUrl,
          message: context.l10n.miningRewards_screenMessage,
        ),
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
    final need = requiredNative == null
        ? ''
        : context.l10n.miningRewards_screenS6(requiredNative);
    final from = swap?.fromSymbol ?? 'USDT';
    final to = swap?.toSymbol ?? 'BNB';
    return Column(
      key: ValueKey<String>(
        swapAvailable ? 'mining-claim-gas-swap' : 'mining-claim-gas-none',
      ),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSheetHeading(
          swapAvailable
              ? context.l10n.miningRewards_screenLoopSheetHeading
              : context.l10n.miningRewards_screenS7,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            swapAvailable
                ? context.l10n.miningRewards_screenBuild(from, need, to)
                : context.l10n.miningRewards_screenS8(need),
            style: LoopType.body.copyWith(color: LoopColors.text2),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LoopButton(
            key: const ValueKey<String>('mining-claim-gas-go'),
            label: swapAvailable
                ? context.l10n.miningRewards_screenMiningClaimGasGoLabel
                : context.l10n.miningRewards_screenMiningClaimGasGoLabel2,
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
            label: context.l10n.common_cancel,
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
    LoopL10n.current.miningRewards_screenBuild2,
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
          context.l10n.miningRewards_screenMiningNftRealCount,
          nft.realCount.toString(),
          key: const ValueKey<String>('mining-nft-real-count'),
        ),
        _fact(
          context.l10n.miningRewards_screenFact,
          miningPowerFigure(nft.ownPower),
        ),
        _fact(
          context.l10n.miningRewards_screenFact2,
          miningPowerFigure(nft.invitePower),
        ),
        _fact(
          context.l10n.mining_screenKicker,
          miningPowerFigure(nft.totalPower),
        ),
        if (live) ...<Widget>[
          const LoopHairline(margin: EdgeInsets.symmetric(vertical: 4)),
          _fact(
            context.l10n.miningRewards_screenMiningMinuteKicker,
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
  'MINING_ASSET_GRADUATED_BALANCE_PENDING' =>
    LoopL10n.current.miningRewards_screenSwitch35,
  'MINING_ASSET_GRADUATED_UNREADABLE' =>
    LoopL10n.current.miningRewards_screenSwitch36,
  'MINING_ASSET_WEIGHT_NOT_CONFIGURED' =>
    LoopL10n.current.miningRewards_screenSwitch37,
  _ => LoopL10n.current.miningRewards_screenSwitch38,
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
            child: Text(
              context.l10n.miningRewards_screenBuild3,
              style: LoopType.caption,
            ),
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
            context.l10n.miningRewards_screenFact4(
              miningExcludedReasonText(item.reasonCode),
            ),
            key: ValueKey<String>('mining-asset-excluded-${item.assetId}'),
          ),
        // S336 · decision 0265: the three formula lines (decisions 0123,
        // 0183) are said in the page's (i) — [miningRewardsInfoNotes].
        const LoopHairline(margin: EdgeInsets.symmetric(vertical: 4)),
        _fact(
          context.l10n.miningRewards_screenFact5,
          miningPowerFigure(asset.ownPower),
        ),
        _fact(
          context.l10n.miningRewards_screenFact2,
          miningPowerFigure(asset.invitePower),
        ),
        _fact(
          context.l10n.mining_screenKicker,
          miningPowerFigure(asset.totalPower),
        ),
        if (live) ...<Widget>[
          const LoopHairline(margin: EdgeInsets.symmetric(vertical: 4)),
          _fact(
            context.l10n.miningRewards_screenMiningMinuteKicker,
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

  /// S336 · decision 0265: 层级 and 比例 are narrow; the three figure
  /// columns share the rest equally, so 「有效邀请」「NFT 算力」「资产算力」
  /// read whole at 390 wide.
  static const List<int> _flex = <int>[9, 7, 10, 10, 10];

  /// The head row's step: 12, and a second line before an ellipsis.
  static final TextStyle _headStyle = LoopType.kicker.copyWith(fontSize: 12);

  Widget _row(
    List<String> cells, {
    Key? key,
    bool head = false,
    bool strong = false,
  }) {
    // Figures are the `.kv` mono, the 合计 row in Chalk.
    final style = strong
        ? LoopTypography.withWeight(
            LoopType.figureXs,
            FontWeight.w600,
          ).copyWith(color: LoopColors.chalk)
        : LoopTypography.withWeight(LoopType.figureXs, FontWeight.w500);
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final (index, cell) in cells.indexed)
            Expanded(
              flex: _flex[index],
              child: Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                child: head
                    // A head never ellipsises: it may take a second line.
                    ? Text(
                        cell,
                        key: ValueKey<String>('mining-invite-head-$index'),
                        textAlign: index == 0
                            ? TextAlign.left
                            : TextAlign.right,
                        maxLines: 2,
                        softWrap: true,
                        style: _headStyle,
                      )
                    : index == 0
                    ? Text(
                        cell,
                        maxLines: 1,
                        softWrap: false,
                        style: LoopType.captionSm.copyWith(
                          color: LoopColors.text2,
                        ),
                      )
                    // A long figure shrinks to its column instead of losing
                    // digits.
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          cell,
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          style: style,
                        ),
                      ),
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
        _row(miningInviteHeads, head: true),
        for (final level in data.levels)
          _row(<String>[
            context.l10n.miningRewards_screenRow(level.level),
            miningRateLabel(level.ratePercent),
            '${level.activeMembers}',
            miningPowerFigure(level.nftPower),
            miningPowerFigure(level.assetPower),
          ], key: ValueKey<String>('mining-invite-level-${level.level}')),
        const LoopHairline(margin: EdgeInsets.symmetric(vertical: 2)),
        _row(
          <String>[
            context.l10n.miningRewards_screenRow2,
            '',
            '${data.total.activeMembers}',
            miningPowerFigure(data.total.nftPower),
            miningPowerFigure(data.total.assetPower),
          ],
          key: const ValueKey<String>('mining-invite-total'),
          strong: true,
        ),
        // S336 · decision 0265: the footnote is [miningInviteNote], in the
        // page's (i).
      ],
    );
  }
}

/// The 五级邀请 table's column heads.
List<String> get miningInviteHeads => <String>[
  LoopL10n.current.miningRewards_screenBuild4,
  LoopL10n.current.miningRewards_screenBuild5,
  LoopL10n.current.miningRewards_inviteHeadActive,
  LoopL10n.current.miningRewards_inviteHeadNft,
  LoopL10n.current.miningRewards_inviteHeadAsset,
];

/// What the 五级邀请 table counts (the footnote that stood under it).
String get miningInviteNote =>
    LoopL10n.current.miningRewards_screenMiningInviteNote;

/// The Meme 币 track's basis (decision 0123, loop-api): the hour's average
/// holding quantity times the approved mining weight; no price enters it.
String get miningAssetBasisNote =>
    LoopL10n.current.miningRewards_screenMiningAssetBasisNote;

/// The NFT track's basis (decision 0183).
String get miningNftBasisNote =>
    LoopL10n.current.miningRewards_screenMiningNftBasisNote;

/// The conditions (decision 0183).
String get miningConditionsNote =>
    LoopL10n.current.mining_copyMiningConditionsShort;

/// The hour that counted, as the hero's caption used to say it.
String get miningHourCountedNote =>
    LoopL10n.current.miningRewards_screenMiningHourCountedNote;

/// S336 · decision 0265: everything the page used to explain on its face —
/// the hero's caption and strip, the power-only line, the Meme 币 track's
/// three formula lines and the invite footnote — said once, in the page's
/// (i). The page itself carries no explanatory sentence.
List<LoopInfoNote> miningRewardsInfoNotes(
  MiningRewardsView? view, {
  required bool live,
  bool settling = false,
  MiningMinuteProgress? progress,
}) {
  final shown =
      progress != null &&
      (progress.phase == MiningMinutePhase.displaying ||
          progress.phase == MiningMinutePhase.settling);
  final nftPower = view?.nft?.totalPower;
  final assetPower = view?.asset?.totalPower;
  final hasPower = nftPower != null || assetPower != null;
  final total = (nftPower ?? Decimal.zero) + (assetPower ?? Decimal.zero);
  final epoch = view?.lastEpoch;
  return <LoopInfoNote>[
    // Live: what the minute folio's strip used to say under its bar.
    if (live && view != null) ...<LoopInfoNote>[
      if (shown)
        LoopInfoNote(
          key: const ValueKey<String>('mining-minute-total'),
          body: LoopL10n.current.miningRewards_screenMiningMinuteTotalBody(
            miningLoopFigure(progress.total),
          ),
        ),
      if (epoch != null)
        LoopInfoNote(
          key: const ValueKey<String>('mining-minute-epoch'),
          body: LoopL10n.current.miningRewards_screenMiningMinuteEpochBody(
            loopClockLabel(epoch.epochStart),
            loopClockLabel(epoch.epochEnd),
          ),
        ),
    ],
    if (!live && view != null) ...<LoopInfoNote>[
      if (hasPower && !settling && total > Decimal.zero)
        LoopInfoNote(
          key: ValueKey<String>('mining-info-hour-counted'),
          body: miningHourCountedNote,
        ),
      if (hasPower)
        LoopInfoNote(
          key: const ValueKey<String>('mining-power-tracks'),
          body: LoopL10n.current.miningRewards_screenMiningPowerTracksBody(
            assetPower == null ? loopFigureDash : miningPowerFigure(assetPower),
            nftPower == null ? loopFigureDash : miningPowerFigure(nftPower),
          ),
        ),
      if (epoch != null)
        LoopInfoNote(
          key: const ValueKey<String>('mining-power-epoch'),
          body: LoopL10n.current.miningRewards_screenMiningPowerEpochBody(
            loopClockLabel(epoch.epochStart),
            loopClockLabel(epoch.epochEnd),
          ),
        ),
    ],
    if (!live)
      LoopInfoNote(
        key: ValueKey<String>('mining-power-only-notice'),
        body: miningPowerOnlyNotice,
      ),
    LoopInfoNote(
      key: ValueKey<String>('mining-asset-basis'),
      body: miningAssetBasisNote,
    ),
    LoopInfoNote(
      key: ValueKey<String>('mining-asset-basis-nft'),
      body: miningNftBasisNote,
    ),
    LoopInfoNote(
      key: ValueKey<String>('mining-asset-basis-conditions'),
      body: miningConditionsNote,
    ),
    LoopInfoNote(
      key: ValueKey<String>('mining-invite-note'),
      body: miningInviteNote,
    ),
  ];
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
        return LoopEmptyState(
          key: ValueKey<String>('mining-claims-empty'),
          illustration: LoopIllustration.history,
          title: context.l10n.miningRewards_screenMiningClaimsEmptyTitle,
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
          title: context.l10n.miningRewards_screenTitle(
            miningLoopFigure(item.amount),
          ),
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
                    message: context.l10n.miningRewards_screenMessage,
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
              ? LoopInlineUnavailable(
                  message: context.l10n.miningRewards_screenMessage2,
                  onRetry: onLoadMore,
                )
              : LoopLoadMoreSentinel(cursor: cursor, onLoadMore: onLoadMore),
      ],
    );
  }
}
