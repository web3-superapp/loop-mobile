import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_wallet.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `launch2-dynamic-rewards` · 外盘奖励 (archetype `index`, layout
/// `dashboard`, client decision 0157).
///
/// One LoopDynamic instance's reward rounds, newest first: when each ran,
/// the reader's weight against the round's, what is claimable and what was
/// claimed, and 「领取」 through the MEME v2 signing exit. An instance the
/// server does not answer as LoopDynamic draws no rounds — only a line that
/// it has no 外盘奖励.
class Launch2DynamicRewardsScreen extends ConsumerStatefulWidget {
  const Launch2DynamicRewardsScreen({
    required this.instanceId,
    super.key,
    this.onBack,
  });

  final String? instanceId;
  final VoidCallback? onBack;

  @override
  ConsumerState<Launch2DynamicRewardsScreen> createState() =>
      _Launch2DynamicRewardsScreenState();
}

class _Launch2DynamicRewardsScreenState
    extends ConsumerState<Launch2DynamicRewardsScreen> {
  /// The round a claim is being prepared for.
  BigInt? _preparing;

  /// Rounds whose claim we broadcast: no second signature this visit.
  final Set<BigInt> _broadcast = <BigInt>{};

  /// Rounds whose report came back `confirmed` (decision 0159).
  final Set<BigInt> _confirmed = <BigInt>{};

  /// One refusal, said above the button of the round it came from.
  (BigInt, String)? _failure;

  /// What the last trip through the signing exit said.
  String? _pending;
  bool _pendingLocked = false;
  Timer? _poll;
  int _settleReads = 0;

  static const int _settleLimit = 36;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _reload(Launch2DynamicRewardsKey? key, String id) =>
      Future.wait(<Future<void>>[
        ref.read(launch2PoolKindControllerProvider(id).notifier).reload(),
        if (key != null)
          ref
              .read(launch2DynamicRewardsControllerProvider(key).notifier)
              .reload(),
      ]);

  static String get _confirmedText =>
      LoopL10n.current.launch2_launch2DynamicRewardsConfirmedText;

  /// After a broadcast the rounds are read again until the claimed one
  /// shows it, then the page stops asking.
  void _armSettle(Launch2DynamicRewardsKey id) {
    _poll?.cancel();
    if (!_pendingLocked) return;
    final interval = ref.read(launch2PollingProvider).tradingInterval;
    _poll = Timer(interval, () {
      _poll = null;
      if (!mounted) return;
      _settleReads += 1;
      unawaited(
        ref.read(launch2DynamicRewardsControllerProvider(id).notifier).reload(),
      );
    });
  }

  void _settle(Launch2DynamicRewardsKey id, Launch2DynamicRewards rewards) {
    if (!_pendingLocked) return;
    final done = rewards.rounds.any(
      (round) => _broadcast.contains(round.roundId) && round.alreadyClaimed,
    );
    if (done) {
      setState(() {
        _pending = _confirmedText;
        _pendingLocked = false;
      });
      return;
    }
    if (_settleReads >= _settleLimit) {
      setState(() {
        _pending = LoopL10n.current.launch2_launch2DynamicRewardsPending;
        _pendingLocked = false;
      });
      return;
    }
    _armSettle(id);
  }

  Future<void> _claim(
    Launch2InstanceDetail detail,
    Launch2DynamicPoolState pool,
    Launch2DynamicRewardsKey key,
    Launch2DynamicRound round,
  ) async {
    final wallet = memeReadActiveWallet(ref);
    final walletId = key.walletId;
    setState(() {
      _preparing = round.roundId;
      _failure = null;
    });
    final Launch2DynamicClaimPrepared prepared;
    try {
      prepared = await ref
          .read(launch2DynamicPoolGatewayProvider)
          .prepareClaim(
            instanceId: detail.instanceId,
            walletId: walletId,
            roundId: round.roundId,
          );
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _preparing = null;
        _failure = (round.roundId, launch2PoolFailureText(failure));
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preparing = null;
        _failure = (
          round.roundId,
          loopChainFailureReason(LoopChainFailureKind.unexpected),
        );
      });
      return;
    }
    if (!mounted) return;
    setState(() => _preparing = null);
    final intent = prepared.intent;
    // The claim goes to the project's own Hook and to nothing else.
    if (intent.contractAddress.toLowerCase() != pool.hook ||
        prepared.claim.hook != pool.hook ||
        intent.approval != null) {
      setState(
        () => _failure = (
          round.roundId,
          launch2SignReasonText('REVIEW_PAYLOAD_MISMATCH'),
        ),
      );
      return;
    }
    final outcome = await showLaunch2SignSheet(
      context,
      intent: intent,
      signer: ref.read(launch2IntentSignerProvider),
      fromAddress: wallet.address,
      ticker: detail.row.ticker,
      clock: ref.read(launch2ClockProvider),
    );
    if (!mounted || outcome == null) return;
    if (!outcome.broadcast) {
      setState(() {
        _pending = launch2SignReasonText(outcome.reasonCode);
        _pendingLocked = false;
      });
      return;
    }
    var text = launch2BroadcastText(outcome, intent.kind);
    var confirmed = false;
    final hash = outcome.txHash;
    if (hash != null) {
      try {
        final report = await ref
            .read(launch2DynamicPoolGatewayProvider)
            .reportClaim(
              instanceId: detail.instanceId,
              walletId: walletId,
              roundId: round.roundId,
              intentId: intent.intentId,
              transactionHash: hash,
            );
        // §3.12.5: `confirmed` is the indexed RewardClaimed; `submitted`
        // reads as 「领取已提交」 until the rounds say claimed.
        confirmed = report.confirmed;
        text = confirmed
            ? _confirmedText
            : LoopL10n.current.launch2_launch2DynamicRewardsConfirmedText2(
                launch2ShortAddress(hash),
              );
      } catch (_) {
        text = LoopL10n.current.launch2_launch2DynamicRewardsText(text);
      }
    }
    if (!mounted) return;
    setState(() {
      _broadcast.add(round.roundId);
      if (confirmed) _confirmed.add(round.roundId);
      _pending = text;
      _pendingLocked = !confirmed;
      _settleReads = 0;
    });
    unawaited(
      ref.read(launch2DynamicRewardsControllerProvider(key).notifier).reload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.instanceId;
    if (!Launch2Route.isInstanceId(id)) {
      return LoopFocusPage(
        key: const ValueKey<String>('launch2-dyn-rewards-invalid-route'),
        archetype: LoopPageArchetype.listing,
        title: context
            .l10n
            .launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidRouteTitle,
        onBack: widget.onBack,
        body: <Widget>[
          LoopEmptyState(
            key: ValueKey<String>('launch2-dyn-rewards-invalid-identity'),
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
    final detailProvider = launch2InstanceControllerProvider(instanceId);
    final detailState = blocked ? null : ref.watch(detailProvider);
    if (detailState != null) {
      launch2LoadOnce(
        ref,
        detailState,
        () => ref.read(detailProvider.notifier).load(),
      );
    }
    final kindProvider = launch2PoolKindControllerProvider(instanceId);
    final kindState = blocked ? null : ref.watch(kindProvider);
    if (kindState != null &&
        kindState.mode != LoopChainGatewayMode.unavailable) {
      launch2LoadOnce(
        ref,
        kindState,
        () => ref.read(kindProvider.notifier).load(),
      );
    }
    final kind = kindState?.value;
    final pool = kind is Launch2LoopDynamicPool ? kind.state : null;
    final detail = detailState?.value;
    // `…/rewards` needs the wallet (§3.12.3): the active one, else the
    // detail's viewer.
    final walletId = blocked
        ? null
        : memeActiveWallet(ref).walletId ?? detail?.viewer?.walletId;
    final rewardsKey = pool == null || walletId == null
        ? null
        : (instanceId: instanceId, walletId: walletId);
    if (rewardsKey != null) {
      final rewardsProvider = launch2DynamicRewardsControllerProvider(
        rewardsKey,
      );
      launch2LoadOnce(
        ref,
        ref.watch(rewardsProvider),
        () => ref.read(rewardsProvider.notifier).load(),
      );
      ref.listen<LoopChainResourceState<Launch2DynamicRewards>>(
        rewardsProvider,
        (previous, next) {
          final value = next.value;
          if (value != null && !identical(previous?.value, value)) {
            _settle(rewardsKey, value);
          }
        },
      );
    }
    final rewardsState = rewardsKey == null
        ? null
        : ref.watch(launch2DynamicRewardsControllerProvider(rewardsKey));
    return LoopDashboardPage(
      key: ValueKey<String>('launch2-dyn-rewards-$instanceId'),
      archetype: LoopPageArchetype.listing,
      title: context
          .l10n
          .launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidRouteTitle,
      subtitle: detail == null ? null : loopTickerLabel(detail.row.ticker),
      onBack: widget.onBack,
      updating:
          (rewardsState?.refreshing ?? false) ||
          (kindState?.refreshing ?? false),
      onRefresh: blocked || pool == null
          ? null
          : () => _reload(rewardsKey, instanceId),
      block: blocked
          ? LoopPageBlock(
              key: const ValueKey<String>('launch2-dyn-rewards-blocked'),
              title: context
                  .l10n
                  .launch2_launch2DynamicRewardsLaunch2DynRewardsBlockedTitle,
              message: launch2CapabilityText(capability),
            )
          : null,
      sections: <Widget>[
        if (!blocked)
          ..._sections(instanceId, kindState, detail, pool, rewardsKey),
      ],
    );
  }

  List<Widget> _sections(
    String instanceId,
    LoopChainResourceState<Launch2PoolKind>? kindState,
    Launch2InstanceDetail? detail,
    Launch2DynamicPoolState? pool,
    Launch2DynamicRewardsKey? rewardsKey,
  ) {
    final kind = kindState?.value;
    // The adapter is absent or the server answered OfficialTax: there is
    // nothing here for this project.
    if (kindState == null ||
        kindState.mode == LoopChainGatewayMode.unavailable ||
        kind is Launch2OfficialTaxPool) {
      return <Widget>[
        LoopEmptyState(
          key: ValueKey<String>('launch2-dyn-rewards-none'),
          illustration: LoopIllustration.history,
          title: LoopL10n
              .current
              .launch2_launch2DynamicRewardsLaunch2DynRewardsNoneTitle,
          message: LoopL10n
              .current
              .launch2_launch2DynamicRewardsLaunch2DynRewardsNoneMessage,
          compact: true,
        ),
      ];
    }
    // Decision 0159: a LoopDynamic Hook that cannot be read now.
    if (kind is Launch2LoopDynamicUnavailable ||
        kind is Launch2LoopDynamicNotGraduated) {
      return <Widget>[
        Launch2DynamicUnavailableBlock(
          reason: kind is Launch2LoopDynamicUnavailable
              ? launch2PoolReasonText(kind.reasonCode)
              : LoopL10n.current.launch2_launch2DynamicRewardsReason,
          onRetry: () => unawaited(
            ref
                .read(launch2PoolKindControllerProvider(instanceId).notifier)
                .reload(),
          ),
        ),
      ];
    }
    if (pool == null) {
      return <Widget>[
        LoopChainStateBlock(
          keyPrefix: 'launch2-dyn-rewards-kind',
          phase: kindState.phase,
          failureKind: kindState.failureKind,
          onRetry: () => unawaited(
            ref
                .read(launch2PoolKindControllerProvider(instanceId).notifier)
                .reload(),
          ),
        ),
      ];
    }
    if (rewardsKey == null) {
      return <Widget>[
        LoopEmptyState(
          key: ValueKey<String>('launch2-dyn-rewards-no-wallet'),
          illustration: LoopIllustration.profile,
          title: LoopL10n
              .current
              .launch2_launch2DynamicRewardsLaunch2DynRewardsNoWalletTitle,
          message: LoopL10n
              .current
              .launch2_launch2DynamicRewardsLaunch2DynRewardsNoWalletMessage,
          compact: true,
        ),
      ];
    }
    final provider = launch2DynamicRewardsControllerProvider(rewardsKey);
    final state = ref.watch(provider);
    final rewards = state.value;
    final widgets = <Widget>[
      if (_pending case final String text)
        LoopNotice(
          key: const ValueKey<String>('launch2-dyn-claim-pending'),
          icon: _pendingLocked ? 'clock' : 'info',
          body: text,
        ),
    ];
    if (rewards == null || detail == null) {
      return <Widget>[
        ...widgets,
        LoopChainStateBlock(
          keyPrefix: 'launch2-dyn-rewards',
          phase: rewards == null ? state.phase : LoopChainViewPhase.loading,
          failureKind: state.failureKind,
          onRetry: () => unawaited(ref.read(provider.notifier).reload()),
        ),
      ];
    }
    // Decision 0202: the project's rounds, the reader's own and the ones
    // it has no weight in; the empty state only while no round ever ran.
    final entries = launch2DynamicRewardEntries(rewards, pool);
    if (entries.isEmpty) {
      return <Widget>[
        ...widgets,
        Launch2DynamicFeeSummaryCard(state: pool, ticker: detail.row.ticker),
        LoopEmptyState(
          key: ValueKey<String>('launch2-dyn-rewards-empty'),
          illustration: LoopIllustration.history,
          title: LoopL10n
              .current
              .launch2_launch2DynamicRewardsLaunch2DynRewardsEmptyTitle,
          message: LoopL10n.current
              .launch2_launch2DynamicRewardsLaunch2DynRewardsEmptyMessage(
                launch2DynamicIdleText,
              ),
          compact: true,
        ),
      ];
    }
    // Decision 0161: a held instance claims nothing; without the detail the
    // server's refusal code says the same.
    final hold = detail.tradingHold;
    return <Widget>[
      ...widgets,
      if (hold != null) Launch2TradingHoldBanner(hold: hold),
      // Decision 0197: the Hook's fee totals, the buy fee by its token.
      Launch2DynamicFeeSummaryCard(state: pool, ticker: detail.row.ticker),
      for (final entry in entries)
        if (entry.round case final Launch2DynamicRound round)
          _RoundRow(
            key: ValueKey<String>('launch2-dyn-round-${round.roundId}'),
            round: round,
            preparing: _preparing == round.roundId,
            busy: _preparing != null || hold != null,
            broadcast: _broadcast.contains(round.roundId),
            confirmed: _confirmed.contains(round.roundId),
            failure: _failure != null && _failure!.$1 == round.roundId
                ? _failure!.$2
                : null,
            onClaim: () => unawaited(_claim(detail, pool, rewardsKey, round)),
          )
        else
          _NoWeightRoundRow(
            key: ValueKey<String>('launch2-dyn-round-${entry.roundId}'),
            entry: entry,
          ),
      LoopProvenanceLine(
        key: const ValueKey<String>('launch2-dyn-rewards-provenance'),
        sources: const <String>['LoopHook'],
        observedAt: ref.read(provider.notifier).valueObservedAt,
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          6,
          LoopSpacing.page,
          4,
        ),
        detail: LoopL10n
            .current
            .launch2_launch2DynamicRewardsLaunch2DynRewardsProvenanceDetail,
      ),
    ];
  }
}

/// One round: when, the weights, what can be claimed and the button.
class _RoundRow extends StatelessWidget {
  const _RoundRow({
    required this.round,
    required this.preparing,
    required this.busy,
    required this.broadcast,
    required this.onClaim,
    super.key,
    this.confirmed = false,
    this.failure,
  });

  final Launch2DynamicRound round;
  final bool preparing;

  /// Another round's claim is being prepared.
  final bool busy;

  /// We broadcast this round's claim this visit.
  final bool broadcast;

  /// Its report came back `confirmed`.
  final bool confirmed;
  final String? failure;
  final VoidCallback onClaim;

  /// The Hook's own 5-minute candle ids; the device does not turn them
  /// into clock times.
  String get _span {
    final end = round.endCandle;
    final start = LoopL10n.current.launch2_launch2DynamicRewardsStart(
      round.startCandle,
    );
    return end == null
        ? LoopL10n.current.launch2_launch2DynamicRewardsSpan(start)
        : '$start – #$end';
  }

  String get _label => preparing
      ? LoopL10n.current.launch2_launch2DynamicRewardsLabel
      : round.alreadyClaimed || confirmed
      ? LoopL10n.current.launch2_launch2DynamicRewardsLabel2
      : broadcast
      ? LoopL10n.current.launch2_launch2DynamicRewardsLabel3
      : switch (round.status) {
          Launch2DynamicRoundStatus.open =>
            LoopL10n.current.launch2_launch2DynamicRewardsOpen,
          Launch2DynamicRoundStatus.noReward => launch2DynamicNoRewardText,
          _ =>
            round.canClaim
                ? LoopL10n.current.common_claim
                : LoopL10n.current.launch2_launch2DynamicRewardsS,
        };

  static const EdgeInsets _kvPadding = EdgeInsets.symmetric(vertical: 6);

  @override
  Widget build(BuildContext context) {
    final id = round.roundId.toString();
    String usd1(Decimal value) => launch2Usd1Label(value, maxFractionDigits: 4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Decision 0166: the `.label` the project page uses (the 20 / 700
          // heading style is gone).
          Launch2SectionLabel(
            context.l10n.launch2_launch2DynamicRewardsLaunch2SectionLabel(id),
            trailing: LoopBadge(
              round.closed
                  ? context.l10n.common_ended
                  : context.l10n.common_inProgress,
              kind: round.closed ? LoopBadgeKind.mute : LoopBadgeKind.launch,
            ),
          ),
          // Decision 0169: the round's facts in one `.record-card` under the
          // `.label`, as the project page groups its own.
          LoopRecordCard(
            key: ValueKey<String>('launch2-dyn-round-$id-card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LoopKeyValue(
                  padding: _kvPadding,
                  key: ValueKey<String>('launch2-dyn-round-$id-span'),
                  label: context.l10n.launch2_launch2DynamicRewardsLabel4,
                  value: _span,
                ),
                LoopKeyValue(
                  padding: _kvPadding,
                  key: ValueKey<String>('launch2-dyn-round-$id-weight'),
                  label: context.l10n.launch2_launch2DynamicRewardsLabel5,
                  value:
                      '${loopFormatDecimal(round.weightUsd1, maxFractionDigits: 4)} / '
                      '${usd1(round.totalBuyWeightUsd1)}',
                ),
                LoopKeyValue(
                  padding: _kvPadding,
                  key: ValueKey<String>('launch2-dyn-round-$id-allocation'),
                  label: context.l10n.launch2_launch2DynamicRewardsLabel6,
                  value: round.allocationUsd1 == null
                      ? context.l10n.launch2_launch2DynamicRewardsValue
                      : usd1(round.allocationUsd1!),
                ),
                LoopKeyValue(
                  padding: _kvPadding,
                  key: ValueKey<String>('launch2-dyn-round-$id-claimable'),
                  label: context.l10n.launch2_launch2DynamicRewardsLabel7,
                  value: usd1(round.claimableUsd1),
                ),
                LoopKeyValue(
                  padding: _kvPadding,
                  key: ValueKey<String>('launch2-dyn-round-$id-claimed'),
                  label: context.l10n.launch2_launch2DynamicRewardsLabel8,
                  value: round.claimedUsd1 != null
                      ? usd1(round.claimedUsd1!)
                      : usd1(Decimal.zero),
                ),
              ],
            ),
          ),
          if (failure case final String text)
            Launch2ActionFailureLine(
              key: ValueKey<String>('launch2-dyn-claim-failed-$id'),
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                0,
                LoopSpacing.page,
                0,
              ),
              message: text,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              2,
              LoopSpacing.page,
              0,
            ),
            child: LoopButton(
              key: ValueKey<String>('launch2-dyn-claim-$id'),
              label: _label,
              primary: round.canClaim && !broadcast && !confirmed,
              block: true,
              onPressed: round.canClaim && !broadcast && !confirmed && !busy
                  ? onClaim
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// A round's line when the reader has nothing to claim in it (decision 0202).
String get launch2DynamicNoRewardText =>
    LoopL10n.current.launch2_launch2DynamicRewardsLaunch2DynamicNoRewardText;

/// A round the reader has no weight in (decision 0202): its number, whether
/// it still runs, and that there is nothing to claim.
class _NoWeightRoundRow extends StatelessWidget {
  const _NoWeightRoundRow({required this.entry, super.key});

  final Launch2DynamicRewardEntry entry;

  @override
  Widget build(BuildContext context) {
    final id = entry.roundId.toString();
    final open = entry.open;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Launch2SectionLabel(
            context.l10n.launch2_launch2DynamicRewardsLaunch2SectionLabel(id),
            trailing: LoopBadge(
              open ? context.l10n.common_inProgress : context.l10n.common_ended,
              kind: open ? LoopBadgeKind.launch : LoopBadgeKind.mute,
            ),
          ),
          LoopRecordCard(
            key: ValueKey<String>('launch2-dyn-round-$id-none'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  open
                      ? context.l10n.launch2_launch2DynamicRewardsBuild
                      : launch2DynamicNoRewardText,
                  style: LoopType.bodySm,
                ),
                const SizedBox(height: 4),
                Text(
                  open
                      ? context.l10n.launch2_launch2DynamicRewardsBuild2
                      : context.l10n.launch2_launch2DynamicRewardsS2,
                  style: LoopType.caption.copyWith(color: LoopColors.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
