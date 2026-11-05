import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/features/security/step_up/step_up_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
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

/// The primary action's label while the capability document is re-read in
/// front of a signing exit (S88d). The action is not pressable meanwhile.
String get moneyCapabilityCheckingLabel =>
    LoopL10n.current.wallet_moneyActionsMoneyCapabilityCheckingLabel;

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
  LoopIntentState.prepared => LoopL10n.current.common_pendingConfirmation,
  LoopIntentState.awaitingSignature =>
    LoopL10n.current.common_awaitingSignature,
  LoopIntentState.submitted => LoopL10n.current.common_submitted,
  LoopIntentState.confirmed => LoopL10n.current.common_confirmed,
  LoopIntentState.reverted => LoopL10n.current.common_reverted,
  LoopIntentState.failed => LoopL10n.current.common_failed,
  LoopIntentState.unknown => LoopL10n.current.wallet_moneyActionsUnknown,
  LoopIntentState.cancelled => LoopL10n.current.common_cancelled,
  LoopIntentState.expired => LoopL10n.current.common_expired,
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
    final observed = LoopL10n.current.wallet_moneyActionsObserved(
      loopRelativeTime(intent.factsObservedAt, now: now),
    );
    return LoopProvenanceFooter(
      key: const ValueKey<String>('money-facts-footer'),
      text: balance == null
          ? observed
          : context.l10n.wallet_moneyActionsMoneyFactsFooterText(
              loopGroupedFigure(balance.blockNumber.toString()),
              observed,
            ),
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

class _MoneySignSheetState extends State<MoneySignSheet>
    with LoopStepUpSheetMixin<MoneySignSheet> {
  LoopSignSheetState _state = LoopSignSheetState.pending;
  String? _reason;
  MoneySignOutcome? _outcome;
  bool _submitted = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  @override
  WalletSigningGateway get stepUpWallet => widget.signer.wallet;

  @override
  Decimal? get stepUpUsd1 => moneyIntentStepUpUsd1(widget.intent);

  @override
  void initState() {
    super.initState();
    _state = _initialState();
    if (_state == LoopSignSheetState.pending) planStepUp();
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
    // Decision 0152: the large-amount step-up runs before the wallet. A
    // cancelled or failed prompt opened nothing, so the confirmation stays.
    final stopped = await runStepUp();
    if (!mounted) return;
    if (stopped != null) {
      setState(() {
        _state = LoopSignSheetState.pending;
        _reason = loopStepUpReasonText(stopped);
        _submitted = false;
      });
      return;
    }
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
          _reason = LoopL10n.current.wallet_moneyActionsReason;
        case MoneySignStatus.locked:
          _state = LoopSignSheetState.complete;
          _reason = LoopL10n.current.wallet_moneyActionsReason2;
        case MoneySignStatus.reportRefused:
          // The wallet already produced a result: this is not "nothing was
          // submitted", and the confirmation stays closed.
          _state = LoopSignSheetState.complete;
          _reason = outcome.txHash == null
              ? LoopL10n.current.wallet_moneyActionsSetState
              : LoopL10n.current.wallet_moneyActionsS(outcome.txHash);
        case MoneySignStatus.refused:
          _state = LoopSignSheetState.simulationFailed;
          _reason = loopReasonCodeText(outcome.reasonCode);
          // A refused attempt never reached the wallet, so it may be retried
          // after the page prepares a fresh intent.
          _submitted = false;
        case MoneySignStatus.walletRejected:
          _state = LoopSignSheetState.simulationFailed;
          _reason =
              loopStepUpReasonText(outcome.reasonCode) ??
              LoopL10n.current.wallet_moneyActionsSetState2;
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
      child: withStepUpStrip(
        signLabel: context.l10n.common_sign,
        signStatus: stepUpSignStatus(
          _state,
          locked: _outcome?.isLocked ?? false,
        ),
        LoopSignSheet(
          key: const ValueKey<String>('money-sign-sheet'),
          state: _state,
          signingTitle: stepUpSigningTitle,
          title: moneyActionTitle(widget.intent.kind),
          // Decision 0038: the sheet names the chain whenever it is not the
          // primary one. Money actions never are, so this is `null` in every
          // delivered build — the sheet reads the intent rather than assuming.
          networkBadge: loopTestnetBadgeFor(widget.intent.chainId),
          facts: <LoopSignFact>[
            for (final IntentField field in fields)
              LoopSignFact(
                field.label,
                field.value,
                down:
                    moneyFieldId(field.label) == 'simulation' &&
                    widget.intent.simulation.status !=
                        LoopSimulationStatus.passed,
              ),
          ],
          reason: _reason,
          onConfirm: _confirm,
          onCancel: () => Navigator.of(context).pop(_outcome),
          onAdjustPolicy: widget.onAdjustPolicy,
        ),
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
                context.l10n.wallet_moneyActionsBuild(
                  moneyActionName(intent.kind),
                ),
                style: LoopType.eyebrow,
              ),
              const SizedBox(height: 10),
              Text(
                review.amount.isUnlimited
                    ? context.l10n.wallet_moneyActionsBuild2(
                        review.asset.symbol,
                      )
                    : '${review.amount.display} ${review.asset.symbol}',
                style: LoopType.figureXl,
              ),
              const SizedBox(height: 8),
              Text(
                intent.policy.valueUsd == null
                    ? context.l10n.wallet_moneyActionsBuild3
                    : context.l10n.wallet_moneyActionsS2(
                        loopFormatUsd(intent.policy.valueUsd!),
                        intent.policy.priceSource ??
                            context
                                .l10n
                                .wallet_moneyActionsWalletMoneyActionsS2,
                      ),
                style: LoopType.caption,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            14,
          ),
          child: LoopSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final field in fields.skip(1))
                  LoopKeyValue(
                    key: ValueKey<String>(
                      'money-review-${moneyFieldId(field.label)}',
                    ),
                    label: field.label,
                    value: field.value,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    valueUp: moneyFieldId(field.label) == 'simulation'
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
/// is not an explanation. These are the eight the frozen contract defines
/// (`frontend-v2-wallet-intents-api.md` §7.1); an unlisted or absent rule
/// falls back to a sentence that states what did not happen and claims
/// nothing about why — in particular it never blames a limit the owner could
/// have set, because the four canary rules are the server's own.
abstract final class MoneyPolicyRule {
  static const assetNotInAllowlist = 'ASSET_NOT_IN_CANARY_ALLOWLIST';
  static const canaryCeilingExceeded = 'CANARY_CEILING_EXCEEDED';
  static const canaryDailyCeilingExceeded = 'CANARY_DAILY_CEILING_EXCEEDED';
  static const counterpartyNotInAllowlist =
      'COUNTERPARTY_NOT_IN_CANARY_ALLOWLIST';
  static const unlimitedExposureExceedsCeiling =
      'UNLIMITED_EXPOSURE_EXCEEDS_CEILING';
  static const assetBlocked = 'ASSET_BLOCKED';
  static const priceImpactBlocked = 'PRICE_IMPACT_BLOCKED';
  static const nativeAssetNotApprovable = 'NATIVE_ASSET_NOT_APPROVABLE';

  /// Only the three ceiling rules compare figures, so only they may render
  /// them.
  static bool comparesFigures(String? reasonCode) =>
      reasonCode == canaryCeilingExceeded ||
      reasonCode == canaryDailyCeilingExceeded ||
      reasonCode == unlimitedExposureExceedsCeiling;
}

/// zh-CN copy for one server refusal.
///
/// A blocked action is not an error: it names the rule that stopped it, says
/// what the rule is about, and — where the owner can do something — names the
/// one thing that would change the answer. The limits are LOOP's own grey
/// release ceilings, not a wallet setting anybody chose, so the copy never
/// offers an adjustment that does not exist and never claims a limit the
/// owner "has not opened yet".
///
/// A `reasonCode` this build has not seen yet gets the neutral sentence: it
/// states exactly what did not happen and claims nothing about why. That is
/// the only honest answer to a rule whose name the client cannot read.
String moneyPolicyRefusalText(LoopChainException failure) {
  final rule = failure.reasonCode;
  // The figures are rendered only for the rules that compared them, and only
  // when the server sent both.
  final figures =
      MoneyPolicyRule.comparesFigures(rule) && failure.hasCeilingFigures
      ? LoopL10n.current.wallet_moneyActionsMoneyPolicyRefusalText(
          failure.ceilingUsd,
          failure.exposureUsd,
        )
      : '';
  // Only the rolling-day rule reports a budget, and only when the server sent
  // both halves of it. 「已用」 without 「还剩」 is not a budget.
  final budget =
      rule == MoneyPolicyRule.canaryDailyCeilingExceeded &&
          failure.hasDailyBudgetFigures
      ? LoopL10n.current.wallet_moneyActionsMoneyPolicyRefusalText2(
          failure.remainingUsd,
          failure.spentUsd,
        )
      : '';
  return switch (rule) {
    MoneyPolicyRule.assetNotInAllowlist =>
      LoopL10n.current.wallet_moneyActionsAssetNotInAllowlist,
    MoneyPolicyRule.counterpartyNotInAllowlist =>
      LoopL10n.current.wallet_moneyActionsCounterpartyNotInAllowlist,
    MoneyPolicyRule.canaryCeilingExceeded =>
      LoopL10n.current.wallet_moneyActionsCanaryCeilingExceeded(figures),
    MoneyPolicyRule.canaryDailyCeilingExceeded =>
      LoopL10n.current.wallet_moneyActionsCanaryDailyCeilingExceeded(
        budget,
        figures,
      ),
    MoneyPolicyRule.unlimitedExposureExceedsCeiling =>
      LoopL10n.current.wallet_moneyActionsUnlimitedExposureExceedsCeiling(
        figures,
      ),
    MoneyPolicyRule.assetBlocked =>
      LoopL10n.current.wallet_moneyActionsAssetBlocked,
    MoneyPolicyRule.priceImpactBlocked =>
      LoopL10n.current.wallet_moneyActionsPriceImpactBlocked,
    MoneyPolicyRule.nativeAssetNotApprovable =>
      LoopL10n.current.wallet_moneyActionsNativeAssetNotApprovable,
    _ => LoopL10n.current.wallet_moneyActionsSwitch,
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
          ? context.l10n.wallet_moneyActionsTitle
          : failure.kind == LoopChainFailureKind.regionBlocked
          ? context.l10n.wallet_moneyActionsTitle2
          : failure.reasonCode == MoneyPolicyRule.nativeAssetNotApprovable
          ? context.l10n.wallet_moneyActionsTitle3
          : context.l10n.wallet_moneyActionsTitle4,
      purpose: stepUp
          ? context.l10n.wallet_moneyActionsPurpose
          : failure.kind == LoopChainFailureKind.regionBlocked
          ? loopChainPermissionPurpose(failure.kind)
          : moneyPolicyRefusalText(failure),
      settingsLabel: context.l10n.common_openSecurityCenter,
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
    this.failureKind,
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
      failure != null && loopChainIsOffline(failure.kind);

  /// The failure this block stands for; it only decides the wording (S88d).
  final LoopChainFailureKind? failureKind;

  @override
  Widget build(BuildContext context) => LoopOfflineState(
    key: ValueKey<String>(blockKey),
    cause: loopOfflineCauseFor(failureKind),
    pausedActions: pausedActions,
    onRetry: onRetry,
  );
}
