import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
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

  static const String _confirmedText = '外盘奖励已领取，已在链上确认。';

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
        _pending = '已广播，但还没有读到确认。它可能仍在确认中，请稍后再查；不要重复领取。';
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
            : '领取已提交（${launch2ShortAddress(hash)}），正在等待链上确认。不要重复领取。';
      } catch (_) {
        text = '$text 上报没有成功，链上结果不受影响；不要重复领取。';
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
        title: '外盘奖励',
        onBack: widget.onBack,
        body: const <Widget>[
          LoopEmpty(
            key: ValueKey<String>('launch2-dyn-rewards-invalid-identity'),
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
      title: '外盘奖励',
      subtitle: detail == null ? null : '\$${detail.row.ticker}',
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
              title: 'MEME v2 暂时不可用',
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
      return const <Widget>[
        LoopEmpty(
          key: ValueKey<String>('launch2-dyn-rewards-none'),
          message: '这个项目没有外盘奖励',
          reason: '只有开启动态税的项目才有按轮次的外盘奖励。',
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
              : '外盘池子正在同步，请稍后再试',
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
      return const <Widget>[
        LoopEmpty(
          key: ValueKey<String>('launch2-dyn-rewards-no-wallet'),
          icon: 'wallet',
          message: '还没有可用的钱包',
          reason: '外盘奖励按钱包记录，激活钱包后可查看与领取。',
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
    if (rewards.rounds.isEmpty) {
      return <Widget>[
        ...widgets,
        const LoopEmptyState(
          key: ValueKey<String>('launch2-dyn-rewards-empty'),
          illustration: LoopIllustration.history,
          title: '还没有外盘奖励',
          message: '$launch2DynamicIdleText。开启后在 LOOP 里买入即计入本轮权重，本轮结束后在这里领取。',
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
      for (final round in rewards.rounds)
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
        ),
      LoopProvenanceLine(
        key: const ValueKey<String>('launch2-dyn-rewards-provenance'),
        sources: const <String>['LoopHook'],
        observedAt: ref.read(provider.notifier).valueObservedAt,
        padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 6, 16, 4),
        detail: '权重按钱包在本轮的买入金额记（USD1）；回购买入不计。领取以链上确认为准。',
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
    final start = 'K 线 #${round.startCandle}';
    return end == null ? '$start 起 · 进行中' : '$start – #$end';
  }

  String get _label => preparing
      ? '正在准备…'
      : round.alreadyClaimed || confirmed
      ? '已领取'
      : broadcast
      ? '领取确认中…'
      : switch (round.status) {
          Launch2DynamicRoundStatus.open => '本轮结束后可领',
          Launch2DynamicRoundStatus.noReward => '本轮无可领金额',
          _ => round.canClaim ? '领取' : '没有可领',
        };

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
            '第 $id 轮',
            trailing: LoopBadge(
              round.closed ? '已结束' : '进行中',
              kind: round.closed ? LoopBadgeKind.mute : LoopBadgeKind.launch,
            ),
          ),
          LoopKeyValue(
            key: ValueKey<String>('launch2-dyn-round-$id-span'),
            label: '起止',
            value: _span,
          ),
          LoopKeyValue(
            key: ValueKey<String>('launch2-dyn-round-$id-weight'),
            label: '我的权重 / 总权重',
            value:
                '${loopFormatDecimal(round.weightUsd1, maxFractionDigits: 4)} / '
                '${usd1(round.totalBuyWeightUsd1)}',
          ),
          LoopKeyValue(
            key: ValueKey<String>('launch2-dyn-round-$id-allocation'),
            label: '本轮奖金',
            value: round.allocationUsd1 == null
                ? '本轮结束后结算'
                : usd1(round.allocationUsd1!),
          ),
          LoopKeyValue(
            key: ValueKey<String>('launch2-dyn-round-$id-claimable'),
            label: '可领',
            value: usd1(round.claimableUsd1),
          ),
          LoopKeyValue(
            key: ValueKey<String>('launch2-dyn-round-$id-claimed'),
            label: '已领',
            value: round.claimedUsd1 != null
                ? usd1(round.claimedUsd1!)
                : usd1(Decimal.zero),
          ),
          if (failure case final String text)
            Launch2ActionFailureLine(
              key: ValueKey<String>('launch2-dyn-claim-failed-$id'),
              padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 6, 16, 0),
              message: text,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 8, 16, 0),
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
