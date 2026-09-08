import 'dart:async';

import 'package:flutter/material.dart';
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
}) {
  return showLoopSheet<MoneySignOutcome>(
    context,
    isDismissible: true,
    builder: (context) => MoneySignSheet(
      intent: intent,
      signer: signer,
      clock: clock,
      onAdjustPolicy: onAdjustPolicy,
    ),
  );
}

/// The stateful body of the signing exit.
class MoneySignSheet extends StatefulWidget {
  const MoneySignSheet({
    required this.intent,
    required this.signer,
    super.key,
    this.clock,
    this.onAdjustPolicy,
  });

  final LoopWalletIntent intent;
  final MoneyActionSigner signer;
  final DateTime Function()? clock;
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

  LoopSignSheetState _initialState() {
    final intent = widget.intent;
    if (!intent.canSignAt(_now) || !intent.payloadMatchesReview) {
      final reason = intent.payloadMatchesReview
          ? intent.blockedReasonAt(_now)
          : 'REVIEW_PAYLOAD_MISMATCH';
      _reason = loopReasonCodeText(reason);
      // A canary ceiling refusal is a policy decision, not a failure, and gets
      // its own state so the copy can say which rule stopped it.
      return reason == 'POLICY_BLOCKED'
          ? LoopSignSheetState.policyRejected
          : LoopSignSheetState.simulationFailed;
    }
    return LoopSignSheetState.pending;
  }

  Future<void> _confirm() async {
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _state = LoopSignSheetState.signing;
      _reason = null;
    });
    final outcome = await widget.signer.sign(widget.intent, now: _now);
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
    return LoopSignSheet(
      key: const ValueKey<String>('money-sign-sheet'),
      state: _state,
      title: moneyActionTitle(widget.intent.kind),
      facts: <LoopSignFact>[
        for (final IntentField field in fields)
          LoopSignFact(
            field.label,
            field.value,
            down:
                field.label == '模拟结果' &&
                widget.intent.simulation.status != LoopSimulationStatus.passed,
          ),
      ],
      reason: _reason,
      onConfirm: _confirm,
      onCancel: () => Navigator.of(context).pop(_outcome),
      onAdjustPolicy: widget.onAdjustPolicy,
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
                    key: ValueKey<String>('money-review-\${field.label}'),
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
