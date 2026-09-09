import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

/// Whether a money-action page must stop at its capability gate.
///
/// `available` only means the backend assembled the module. The Swap
/// confirmation additionally waits on `evidence`, which [LoopCapabilityProjection.isUsable]
/// already folds in.
bool moneyActionBlocks(
  LoopChainGatewayMode mode,
  LoopCapabilityProjection capability,
) => mode != LoopChainGatewayMode.preview && !capability.isAvailable;

/// Whether a money-action *read* must stop.
///
/// The write switch and the canary only govern prepare, report and execute:
/// the intent reads and the approval inventory stay readable while writing is
/// closed. A read therefore waits on nothing but its own adapter, and lets the
/// server's own answer drive every other state.
bool moneyReadBlocks(LoopChainGatewayMode mode) =>
    mode == LoopChainGatewayMode.unavailable;

/// zh-CN label for one intent state.
String moneyIntentStateLabel(LoopIntentState state) => switch (state) {
  LoopIntentState.prepared => '待确认',
  LoopIntentState.awaitingSignature => '待签名',
  LoopIntentState.submitted => '已提交',
  LoopIntentState.confirmed => '已确认',
  LoopIntentState.reverted => '已回滚',
  LoopIntentState.failed => '失败',
  LoopIntentState.unknown => '未知（已锁定）',
  LoopIntentState.cancelled => '已取消',
  LoopIntentState.expired => '已过期',
};

/// `mm:ss` for a countdown. Zero renders as `00:00`, never as an em dash.
String moneyCountdownLabel(Duration remaining) {
  final seconds = remaining.inSeconds.clamp(0, 5999);
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// A one-second ticker that drives every expiry countdown on a page.
///
/// It rebuilds nothing but its own subtree, and the value it exposes is a
/// clock reading — never a fact about the server.
class MoneyCountdown extends StatefulWidget {
  const MoneyCountdown({
    required this.expiresAt,
    required this.builder,
    super.key,
    this.clock,
  });

  final DateTime expiresAt;
  final Widget Function(BuildContext context, Duration remaining) builder;
  final DateTime Function()? clock;

  @override
  State<MoneyCountdown> createState() => _MoneyCountdownState();
}

class _MoneyCountdownState extends State<MoneyCountdown> {
  Timer? _timer;
  late Duration _remaining = _read();

  Duration _read() {
    final now = (widget.clock ?? DateTime.now)().toUtc();
    final left = widget.expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _read());
    });
  }

  @override
  void didUpdateWidget(MoneyCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      setState(() => _remaining = _read());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}

/// The provenance line every intent carries: which block the facts came from
/// and when they were observed.
class MoneyFactsFooter extends StatelessWidget {
  const MoneyFactsFooter({required this.intent, super.key, this.now});

  final LoopWalletIntent intent;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final balance = intent.review.balance;
    return LoopProvenanceFooter(
      key: const ValueKey<String>('money-facts-footer'),
      text:
          '区块 ${balance.blockNumber} · 事实观察于 '
          '${loopRelativeTime(intent.factsObservedAt, now: now)} · '
          '策略 ${intent.policy.configVersion}',
    );
  }
}

/// Opens the single signing exit for one server intent.
///
/// The sheet renders the same [SigningIntent] it hands to the wallet, so the
/// lines on screen and the payload that gets signed cannot diverge.
Future<MoneySignOutcome?> showMoneySignSheet(
  BuildContext context, {
  required LoopWalletIntent intent,
  required MoneyActionSigner signer,
  DateTime Function()? clock,
  VoidCallback? onAdjustPolicy,
}) async {
  // The latch survives the route: if the sheet is ever torn down after the
  // wallet was opened, the caller still learns that something may exist.
  final latch = MoneySignLatch();
  final outcome = await showLoopSheet<MoneySignOutcome>(
    context,
    // A signing sheet is never dismissed by a stray tap or a drag. Before the
    // wallet opens the sheet's own cancel action closes it; after it opens,
    // nothing does.
    isDismissible: false,
    builder: (context) => MoneySignSheet(
      intent: intent,
      signer: signer,
      clock: clock,
      latch: latch,
      onAdjustPolicy: onAdjustPolicy,
    ),
  );
  if (outcome != null) return outcome;
  if (!latch.enteredSigning) return null;
  // The sheet went away after the wallet was opened. Whatever happened, the
  // owner must be sent to the result page rather than back to a live
  // confirmation.
  return MoneySignOutcome(
    status: MoneySignStatus.reportRefused,
    reasonCode: 'SIGNING_INTERRUPTED',
    txHash: latch.txHash,
  );
}

/// Records that the wallet was opened, so an interrupted sheet cannot be
/// mistaken for a cancellation.
final class MoneySignLatch {
  bool enteredSigning = false;
  String? txHash;
}

/// The stateful body of the signing exit.
class MoneySignSheet extends StatefulWidget {
  const MoneySignSheet({
    required this.intent,
    required this.signer,
    super.key,
    this.clock,
    this.latch,
    this.onAdjustPolicy,
  });

  final LoopWalletIntent intent;
  final MoneyActionSigner signer;
  final DateTime Function()? clock;

  /// Set once the wallet is opened, so a torn-down sheet still reports that
  /// something may exist.
  final MoneySignLatch? latch;
  final VoidCallback? onAdjustPolicy;

  @override
  State<MoneySignSheet> createState() => _MoneySignSheetState();
}

class _MoneySignSheetState extends State<MoneySignSheet> {
  LoopSignSheetState _state = LoopSignSheetState.pending;
  String? _reason;
  MoneySignOutcome? _outcome;
  bool _submitted = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    _state = _initialState();
  }

  /// The sheet only ever opens on a server intent, and `signing.reasonCode`
  /// has its own vocabulary (`BSC_CALL_REVERTED`, `SIMULATION_UNAVAILABLE`,
  /// `GAS_ESTIMATE_UNAVAILABLE`, `INTENT_EXPIRED`, `INTENT_SUPERSEDED`,
  /// `USER_CANCELLED`, `INTENT_<STATE>`). A policy refusal never arrives here
  /// — it is a `403` on prepare, which the page renders — so there is no
  /// `policyRejected` branch to reach.
  LoopSignSheetState _initialState() {
    final intent = widget.intent;
    if (intent.canSignAt(_now) && intent.payloadMatchesReview) {
      return LoopSignSheetState.pending;
    }
    _reason = loopReasonCodeText(
      intent.payloadMatchesReview
          ? intent.blockedReasonAt(_now)
          : 'REVIEW_PAYLOAD_MISMATCH',
    );
    return LoopSignSheetState.simulationFailed;
  }

  Future<void> _confirm() async {
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _state = LoopSignSheetState.signing;
      _reason = null;
    });
    // From here the wallet is open. The sheet cannot be dismissed and the
    // confirmation cannot be re-enabled by anything below.
    widget.latch?.enteredSigning = true;
    final outcome = await widget.signer.sign(widget.intent, now: _now);
    widget.latch?.txHash = outcome.txHash;
    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      switch (outcome.status) {
        case MoneySignStatus.submitted:
          _state = LoopSignSheetState.complete;
          _reason = '已提交，等待链上回执。成功提示不代表链上已完成。';
        case MoneySignStatus.locked:
          _state = LoopSignSheetState.complete;
          _reason = '这笔操作已提交且结果未知，已锁定。请在结果页查看，不要重复提交。';
        case MoneySignStatus.reportRefused:
          // The wallet already produced a result: this is not "nothing was
          // submitted", and the confirmation stays closed.
          _state = LoopSignSheetState.complete;
          _reason = outcome.txHash == null
              ? '钱包已经签名，但服务端没有记录到这次提交。请在结果页查看状态，不要重复签名。'
              : '钱包已经广播（${outcome.txHash}），但服务端没有接受这次上报'
                    '（${outcome.reasonCode}）。这笔交易可能已经上链。'
                    '请在结果页查看并稍后重新上报，不要重复签名。';
        case MoneySignStatus.refused:
          _state = LoopSignSheetState.simulationFailed;
          _reason = loopReasonCodeText(outcome.reasonCode);
          // A refused attempt never reached the wallet, so it may be retried
          // after the page prepares a fresh intent.
          _submitted = false;
        case MoneySignStatus.walletRejected:
          _state = LoopSignSheetState.simulationFailed;
          _reason = '钱包没有完成签名，没有提交任何交易（${outcome.reasonCode}）。';
          _submitted = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final signingIntent = MoneyActionSigner.toSigningIntent(widget.intent);
    final fields = signingIntent?.fields ?? moneyActionFields(widget.intent);
    return PopScope(
      // While the wallet is open there is no way out of this sheet: a back
      // gesture must not leave a signature in flight with nothing watching it.
      canPop: _state != LoopSignSheetState.signing,
      child: LoopSignSheet(
        key: const ValueKey<String>('money-sign-sheet'),
        state: _state,
        title: moneyActionTitle(widget.intent.kind),
        // Decision 0038: the sheet names the chain whenever it is not the
        // primary one. Money actions never are, so this is `null` in every
        // delivered build — the sheet reads the intent rather than assuming.
        networkBadge: loopIsTestnetChainId(widget.intent.chainId)
            ? loopTestnetBadgeLabel
            : null,
        facts: <LoopSignFact>[
          for (final IntentField field in fields)
            LoopSignFact(
              field.label,
              field.value,
              down:
                  field.label == '模拟结果' &&
                  widget.intent.simulation.status !=
                      LoopSimulationStatus.passed,
            ),
        ],
        reason: _reason,
        onConfirm: _confirm,
        onCancel: () => Navigator.of(context).pop(_outcome),
        onAdjustPolicy: widget.onAdjustPolicy,
      ),
    );
  }
}

/// The review block every confirmation page renders.
///
/// Its lines come from [moneyActionFields] — the same builder the signing exit
/// uses — so the page and the sheet can never show different facts.
class MoneyIntentReviewCard extends StatelessWidget {
  const MoneyIntentReviewCard({required this.intent, super.key, this.clock});

  final LoopWalletIntent intent;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final fields = moneyActionFields(intent);
    final review = intent.review;
    return Column(
      key: const ValueKey<String>('money-intent-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '${moneyActionTitle(intent.kind).replaceFirst('确认', '')} · '
                'FINAL REVIEW',
                style: LoopMono.label,
              ),
              const SizedBox(height: 10),
              Text(
                review.amount.isUnlimited
                    ? '无限 ${review.asset.symbol}'
                    : '${review.amount.display} ${review.asset.symbol}',
                style: LoopMono.display,
              ),
              const SizedBox(height: 8),
              Text(
                intent.policy.valueUsd == null
                    ? '本次没有可用的新鲜行情，因此不展示估值。'
                    : '预估价值 ${loopFormatUsd(intent.policy.valueUsd!)} · '
                          '来源 ${intent.policy.priceSource ?? '未标注'}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: LoopSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final field in fields.skip(1))
                  LoopKeyValue(
                    key: ValueKey<String>('money-review-${field.label}'),
                    label: field.label,
                    value: field.value,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    valueUp: field.label == '模拟结果'
                        ? intent.simulation.passed
                        : null,
                  ),
              ],
            ),
          ),
        ),
        MoneyFactsFooter(intent: intent, now: clock?.call()),
      ],
    );
  }
}

/// The refusal rules the server names in `detailsSafe.reasonCode`.
///
/// A refusal is only explainable when the rule is named: "blocked by policy"
/// is not an explanation. These are the six the frozen contract defines; an
/// unlisted or absent rule falls back to a sentence that states what did not
/// happen and claims nothing about why.
abstract final class MoneyPolicyRule {
  static const assetNotInAllowlist = 'ASSET_NOT_IN_CANARY_ALLOWLIST';
  static const canaryCeilingExceeded = 'CANARY_CEILING_EXCEEDED';
  static const unlimitedExposureExceedsCeiling =
      'UNLIMITED_EXPOSURE_EXCEEDS_CEILING';
  static const assetBlocked = 'ASSET_BLOCKED';
  static const priceImpactBlocked = 'PRICE_IMPACT_BLOCKED';
  static const nativeAssetNotApprovable = 'NATIVE_ASSET_NOT_APPROVABLE';

  /// Only the two ceiling rules compare figures, so only they may render them.
  static bool comparesFigures(String? reasonCode) =>
      reasonCode == canaryCeilingExceeded ||
      reasonCode == unlimitedExposureExceedsCeiling;
}

/// zh-CN copy for one server refusal.
///
/// A blocked action is not an error: it names the rule that stopped it, and
/// says the ceiling is the server's grey-release limit rather than a wallet
/// setting the owner chose — the security centre's own limit is not delivered,
/// so the copy never offers an adjustment that does not exist.
String moneyPolicyRefusalText(LoopChainException failure) {
  final rule = failure.reasonCode;
  // The two figures are rendered only for the rules that compared them, and
  // only when the server sent both.
  final figures =
      MoneyPolicyRule.comparesFigures(rule) && failure.hasCeilingFigures
      ? '本次敞口 \$${failure.exposureUsd} · 上限 \$${failure.ceilingUsd}。'
      : '';
  return switch (rule) {
    MoneyPolicyRule.assetNotInAllowlist =>
      '这个资产不在本步的灰度名单里，服务端拒绝了这笔操作。名单由服务端配置，'
          '客户端无法调整；请换一个已登记的资产。',
    MoneyPolicyRule.canaryCeilingExceeded =>
      '$figures这笔操作超过了服务端配置的灰度单笔上限。'
          '这不是你的钱包策略：安全中心的自定义上限尚未交付，本步暂不可调，请降低本次金额。',
    MoneyPolicyRule.unlimitedExposureExceedsCeiling =>
      '$figures无限授权按实际敞口（min(额度, 当前余额)）计算，已超过服务端的灰度上限。'
          '安全中心的自定义上限尚未交付，本步暂不可调；请改用限额授权，或先降低该资产余额。',
    MoneyPolicyRule.assetBlocked => '该资产在注册表里已被标记为 blocked，服务端不接受针对它的任何资金动作。',
    MoneyPolicyRule.priceImpactBlocked =>
      '这笔兑换的价格影响达到了硬阻断阈值，服务端拒绝执行。请减小金额或稍后再试。',
    MoneyPolicyRule.nativeAssetNotApprovable =>
      '原生 BNB 没有授权面：它不是 ERC-20，没有 allowance 可以授权或回收。'
          '这一步不适用于原生资产。',
    _ =>
      '服务端按当前策略拒绝了这笔操作，没有提交任何交易。'
          '安全中心的自定义上限尚未交付，本步暂不可调。',
  };
}

/// The block a money-action page renders when the server refused it.
///
/// A refusal is the Permission state of a funds page: the request arrived, was
/// understood, and was answered "no". It is rendered as a [LoopPermissionState]
/// rather than an error, because a retry would claim the answer might change.
/// The block always states which rule or policy stopped the step, what did not
/// happen, and the one route that exists — the security centre for a step-up,
/// and nothing at all for a policy ceiling the client cannot adjust.
///
/// [blockKey] is the page's own key, so an assertion names this page rather
/// than a shared block that happened to render.
class MoneyPolicyNotice extends StatelessWidget {
  const MoneyPolicyNotice({
    required this.failure,
    super.key,
    this.blockKey = 'money-policy-blocked',
    this.onOpenSecurity,
  });

  final LoopChainException failure;
  final String blockKey;
  final VoidCallback? onOpenSecurity;

  /// True when this failure should be rendered as a named refusal rather than
  /// a retryable error.
  static bool covers(LoopChainException? failure) =>
      failure != null &&
      (failure.kind == LoopChainFailureKind.permissionDenied ||
          failure.kind == LoopChainFailureKind.regionBlocked ||
          failure.kind == LoopChainFailureKind.stepUpRequired ||
          (failure.kind == LoopChainFailureKind.validationFailed &&
              failure.reasonCode == MoneyPolicyRule.nativeAssetNotApprovable));

  @override
  Widget build(BuildContext context) {
    final stepUp = failure.kind == LoopChainFailureKind.stepUpRequired;
    return LoopPermissionState(
      key: ValueKey<String>(blockKey),
      icon: 'shield',
      denied: true,
      title: stepUp
          ? '这一步需要二次验证，没有提交任何交易'
          : failure.kind == LoopChainFailureKind.regionBlocked
          ? '当前地区不能执行此操作，没有提交任何交易'
          : failure.reasonCode == MoneyPolicyRule.nativeAssetNotApprovable
          ? '原生资产不能授权'
          : '被策略拒绝，没有提交任何交易',
      purpose: stepUp
          ? '这一步需要二次验证。二次验证尚未开放，服务端已拒绝，'
                '没有签名、没有广播，也没有提交任何交易。'
                '请到安全中心查看当前可用的验证方式。'
          : failure.kind == LoopChainFailureKind.regionBlocked
          ? loopChainPermissionPurpose(failure.kind)
          : moneyPolicyRefusalText(failure),
      settingsLabel: '前往安全中心',
      onOpenSettings: stepUp ? onOpenSecurity : null,
    );
  }
}

/// The paused state a funds step renders when it went offline **before**
/// anything was handed to a wallet.
///
/// 01 §9 and the S6 ruling split the offline story in two:
///
/// * before the handoff — a preflight, a quote or a prepare that never reached
///   the server has signed, broadcast and reported nothing. The step pauses,
///   says which actions are paused, and offers a retry. It is not an error and
///   it must not read as a refusal.
/// * after the handoff — the wallet has already produced a hash or an
///   authorization signature, so an offline report is
///   [MoneySignStatus.reportRefused]: a locked state that keeps the produced
///   value, never an offline state and never "nothing was submitted".
///
/// Every page that owns a pre-handoff failure therefore checks [covers] before
/// it falls through to its error block.
class MoneyOfflinePause extends StatelessWidget {
  const MoneyOfflinePause({
    required this.blockKey,
    required this.pausedActions,
    super.key,
    this.onRetry,
  });

  /// The page's own key, so the assertion names this page and not a shared
  /// block that happened to render.
  final String blockKey;

  /// The exact actions this step stopped doing. They are named, so the pause
  /// cannot be read as "the transaction failed".
  final List<String> pausedActions;
  final VoidCallback? onRetry;

  /// True when the failure happened before any wallet handoff and is a
  /// connectivity observation rather than a server answer.
  static bool covers(LoopChainException? failure) =>
      failure != null && failure.kind == LoopChainFailureKind.offline;

  @override
  Widget build(BuildContext context) => LoopOfflineState(
    key: ValueKey<String>(blockKey),
    pausedActions: pausedActions,
    onRetry: onRetry,
  );
}
