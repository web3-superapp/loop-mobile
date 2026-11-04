import 'package:flutter/foundation.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// Narrow, feature-facing failure taxonomy shared by the three S7 ports
/// (`launch`, `mining` and `referral`).
///
/// It carries no transport detail: the adapters map the frozen V2 error
/// catalogue onto these kinds, so `lib/features/` never branches on an HTTP
/// status or a `/v2/` literal. It lives with `launch` for the same reason the
/// S5 taxonomy lives with `chain`: the first module of the step owns it.
enum LaunchFailureKind {
  offline,

  /// A **read** that went out and got no answer in time. The same page phase
  /// as [offline]; only the wording differs (S88d). A write never carries it.
  timedOut,

  /// The request was cancelled in flight. A write may or may not have been
  /// applied, so its idempotency key must survive an identical retry.
  cancelled,

  /// A response the client could not parse. The server may already have
  /// applied a write, so this is an unresolved outcome too.
  outcomeUnknown,

  /// The capability, the module or the runtime is not assembled. For the
  /// step-7 write paths this is also how `503 CAPABILITY_UNAVAILABLE` — the
  /// permanent answer of `POST …/intents` — reaches the page.
  unavailable,

  /// `403 PERMISSION_DENIED`.
  permissionDenied,

  /// `403 POLICY_BLOCKED`: the account is known but the policy window has
  /// closed. Kept apart from [permissionDenied] because the next step differs.
  policyBlocked,
  notFound,

  /// `409 DATA_STALE`: the resource is no longer in a state that accepts this
  /// command (an already-submitted application, an already-bound invite).
  stale,

  /// `409 VERSION_CONFLICT`: reload and merge before retrying.
  versionConflict,

  /// `409 PROFILE_ACTIVATION_REQUIRED`: the account has no LOOP ID yet.
  activationRequired,
  bootstrapRequired,
  validationFailed,
  idempotencyConflict,

  /// `409 INSUFFICIENT_BALANCE` on a purchase intent (decision 0089): the
  /// USD1 balance, the USD1 allowance or the network fee is short, named by
  /// `detailsSafe.reasonCode`. A known refusal, never an unresolved outcome.
  insufficientBalance,
  invalidData,
  unexpected,
}

final class LaunchException implements Exception {
  const LaunchException(this.kind, {this.reasonCode});

  final LaunchFailureKind kind;

  /// The server's `detailsSafe.reasonCode`, when the refusal named one. It is
  /// a stable identifier the page maps to copy; never provider detail.
  final String? reasonCode;

  @override
  String toString() => 'LaunchException(${kind.name})';
}

/// Delivery mode of one port implementation. There is no `preview` mode in
/// step 7: no Launch, Mining or Referral fixture may ever be rendered.
enum LaunchGatewayMode { production, unavailable }

/// The `{ "status": "unavailable", "reasonCode": … }` projection.
///
/// A field carrying this object renders an unavailable explanation. It never
/// renders `0` or a fixture. An [launchMissingFigure] em dash may accompany
/// the explanation as the empty metric, never replace it.
@immutable
final class LaunchUnavailable {
  const LaunchUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LaunchUnavailable && other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

/// The em dash used wherever an S7 figure has no source. Never `0`.
///
/// Step 7 has neither a Launch contract baseline nor an approved Mining
/// formula, so every on-chain and every formula-derived number renders as this
/// placeholder next to the server's own `reasonCode`.
const String launchMissingFigure = '—';

/// The same absence, said in words, where a folio heading would carry the
/// figure.
///
/// [launchMissingFigure] still owns every metric cell, row end and sentence:
/// at 11–20px, next to its own label, an em dash reads as "nothing here". A
/// hero heading prints at 25–30px in Lime, and there the same dash reads as a
/// stray green rule rather than as a placeholder. The heading therefore says
/// it: never `0`, never blank, and still the plain statement that this page
/// has no number to show yet.
String get launchMissingHeading =>
    LoopL10n.current.launch_contractLaunchMissingHeading;

/// The same placeholder for a heading that was never a number. A missing
/// project name is not a missing figure, and neither is a missing eligibility
/// result; saying 暂无数值 there would describe the wrong kind of gap.
String get launchMissingName =>
    LoopL10n.current.launch_contractLaunchMissingName;
String get launchMissingResult =>
    LoopL10n.current.launch_contractLaunchMissingResult;

/// What a configuration slot says while no version of it is confirmed.
///
/// The version that will confirm it is a backend identifier. It says nothing a
/// reader can act on, so the slot states the status alone.
String get launchPendingConfirmationLabel =>
    LoopL10n.current.common_pendingConfirmation;

/// zh-CN copy for a failed S7 operation. It states what did not happen; it
/// never claims a result the server did not confirm.
String launchFailureReason(LaunchFailureKind? kind) => switch (kind) {
  LaunchFailureKind.offline => LoopL10n.current.launch_contractOffline,
  LaunchFailureKind.timedOut => LoopL10n.current.launch_contractTimedOut,
  LaunchFailureKind.cancelled => LoopL10n.current.launch_contractCancelled,
  LaunchFailureKind.outcomeUnknown =>
    LoopL10n.current.launch_contractOutcomeUnknown,
  LaunchFailureKind.unavailable => LoopL10n.current.launch_contractUnavailable,
  LaunchFailureKind.permissionDenied =>
    LoopL10n.current.launch_contractPermissionDenied,
  LaunchFailureKind.policyBlocked =>
    LoopL10n.current.launch_contractPolicyBlocked,
  LaunchFailureKind.notFound => LoopL10n.current.launch_contractNotFound,
  LaunchFailureKind.stale => LoopL10n.current.launch_contractStale,
  LaunchFailureKind.versionConflict =>
    LoopL10n.current.launch_contractVersionConflict,
  LaunchFailureKind.activationRequired =>
    LoopL10n.current.launch_contractActivationRequired,
  LaunchFailureKind.bootstrapRequired =>
    LoopL10n.current.launch_contractBootstrapRequired,
  LaunchFailureKind.validationFailed =>
    LoopL10n.current.launch_contractValidationFailed,
  LaunchFailureKind.idempotencyConflict =>
    LoopL10n.current.launch_contractIdempotencyConflict,
  LaunchFailureKind.insufficientBalance =>
    LoopL10n.current.launch_contractInsufficientBalance,
  LaunchFailureKind.invalidData => LoopL10n.current.launch_contractInvalidData,
  LaunchFailureKind.unexpected => LoopL10n.current.launch_contractUnexpected,
  null => LoopL10n.current.common_actionIncomplete,
};

/// Whether a write's outcome is unknown, so its idempotency key must be
/// replayed rather than replaced.
bool launchOutcomeIsUnresolved(LaunchFailureKind kind) =>
    kind == LaunchFailureKind.offline ||
    kind == LaunchFailureKind.timedOut ||
    kind == LaunchFailureKind.cancelled ||
    kind == LaunchFailureKind.outcomeUnknown;

/// zh-CN explanation for one server `reasonCode`.
///
/// An unknown code keeps a neutral sentence rather than inventing a cause. No
/// entry restates a rate, a cap, a supply or a tax: those numbers do not exist
/// until the contract and formula baselines are delivered.
String launchReasonCodeText(String? reasonCode) => switch (reasonCode) {
  // launch · contract baseline
  'LAUNCH_CONTRACT_BASELINE_PENDING' => LoopL10n.current.launch_contractSwitch,
  // launch · contract adapter (loop-api decision 0076)
  'LAUNCH_CONTRACT_VERIFICATION_PENDING' =>
    LoopL10n.current.launch_contractSwitch2,
  'LAUNCH_CONTRACT_CODE_MISSING' => LoopL10n.current.launch_contractSwitch3,
  'LAUNCH_CONTRACT_VERSION_UNSUPPORTED' =>
    LoopL10n.current.launch_contractSwitch4,
  'LAUNCH_CHAIN_RPC_NOT_CONFIGURED' => LoopL10n.current.launch_contractSwitch5,
  'LAUNCH_CHAIN_ID_MISMATCH' => LoopL10n.current.launch_contractSwitch6,
  'LAUNCH_CHAIN_RPC_UNREACHABLE' => LoopL10n.current.launch_contractSwitch7,
  'LAUNCH_SALE_NOT_REGISTERED' => LoopL10n.current.launch_contractSwitch8,
  'LAUNCH_SALE_CONTRACT_MISMATCH' => LoopL10n.current.launch_contractSwitch9,
  'LAUNCH_SALE_NOT_FOUND' => LoopL10n.current.launch_contractSwitch10,
  'LAUNCH_CONFIG_VERSION_MISMATCH' => LoopL10n.current.launch_contractSwitch11,
  'LAUNCH_USD1_ADDRESS_MISMATCH' => LoopL10n.current.launch_contractSwitch12,
  'LAUNCH_CONTRACT_READ_FAILED' => LoopL10n.current.launch_contractSwitch13,
  // launch · purchase preflight (loop-api decision 0077, client 0089). Each
  // one leads back to its own guidance on the trade page.
  'LAUNCH_USD1_ALLOWANCE_INSUFFICIENT' =>
    LoopL10n.current.launch_contractSwitch14,
  'LAUNCH_USD1_BALANCE_INSUFFICIENT' =>
    LoopL10n.current.launch_contractSwitch15,
  'LAUNCH_GAS_INSUFFICIENT' => LoopL10n.current.launch_contractSwitch16,
  'LAUNCH_CONTRACT_READ_INVALID' => LoopL10n.current.launch_contractSwitch17,
  'LAUNCH_SNAPSHOT_REORGED' => LoopL10n.current.launch_contractSwitch18,
  'LAUNCH_ONCHAIN_STATE_NOT_INDEXED' =>
    LoopL10n.current.launch_contractSwitch19,
  'LAUNCH_CONFIG_PENDING_CONFIRMATION' =>
    LoopL10n.current.launch_contractSwitch20,
  'LAUNCH_POOL_EVIDENCE_UNAVAILABLE' =>
    LoopL10n.current.launch_contractSwitch21,
  'LAUNCH_ECONOMY_CONTRACT_PENDING' => LoopL10n.current.launch_contractSwitch22,
  'LAUNCH_RUNTIME_UNAVAILABLE' => LoopL10n.current.launch_contractSwitch23,
  // launch · project ↔ community binding (loop-api decision 0125, client 0147)
  'LAUNCH_COMMUNITY_NOT_OWNED' => LoopL10n.current.launch_contractSwitch24,
  'TIER_MODE_PENDING' => LoopL10n.current.launch_contractSwitch25,
  'STAKING_CONTRACT_PENDING' => LoopL10n.current.launch_contractSwitch26,
  'KYB_PROVIDER_NOT_SELECTED' => LoopL10n.current.launch_contractSwitch27,
  'ATTACHMENT_STORAGE_NOT_SELECTED' => LoopL10n.current.launch_contractSwitch28,
  // mining · formula baseline
  'MINING_FORMULA_BASELINE_PENDING' => LoopL10n.current.launch_contractSwitch29,
  // The boost has a code of its own (Decision 0046): it says that the
  // effective version has not approved the boost, and nothing about the
  // figures beside it. Restating the whole formula here would contradict a
  // page that is printing settled power at the same time.
  'MINING_REFERRAL_BOOST_PENDING' => LoopL10n.current.launch_contractSwitch30,
  'MINING_SNAPSHOT_NOT_AVAILABLE' => LoopL10n.current.launch_contractSwitch31,
  'MINING_SNAPSHOT_STALE' => LoopL10n.current.launch_contractSwitch32,
  // Decision 0057: a run that cannot value a held asset is not published, so
  // reading nothing is never published as a zero. These three say which of
  // 「还没算完」/「还没轮到这个钱包」/「这个资产没有报价」 it is.
  'MINING_SNAPSHOT_INCOMPLETE' => LoopL10n.current.launch_contractText,
  'MINING_SNAPSHOT_PENDING' => LoopL10n.current.launch_contractText2,
  'MINING_PRICE_PAIR_NOT_FOUND' => LoopL10n.current.launch_contractText3,
  'MINING_SNAPSHOT_PUBLISHED_INCOMPLETE' =>
    LoopL10n.current.launch_contractText4,
  'MINING_ACCOUNT_NOT_IN_SNAPSHOT' => LoopL10n.current.launch_contractText5,
  'MINING_NETWORK_POWER_ZERO' => LoopL10n.current.launch_contractText6,
  'MINING_DAILY_OUTPUT_NOT_CONFIGURED' => LoopL10n.current.launch_contractText7,
  'MINING_RANK_NOT_RANKED' => LoopL10n.current.launch_contractText8,
  'MINING_RANK_NOT_APPLICABLE' => LoopL10n.current.launch_contractText9,
  'MINING_POWER_PRIVATE' => LoopL10n.current.launch_contractText10,
  'MINING_PRICE_NOT_FRESH' => LoopL10n.current.launch_contractText11,
  'MINING_PRICE_PROXY_NOT_DECLARED' => LoopL10n.current.launch_contractText12,
  'MINING_ASSET_WEIGHT_NOT_CONFIGURED' =>
    LoopL10n.current.launch_contractText13,
  'COMMUNITY_ASSET_NOT_BOUND' => LoopL10n.current.launch_contractText14,
  'COMMUNITY_WEIGHT_AMBIGUOUS' => LoopL10n.current.launch_contractText15,
  'MINING_RUNTIME_UNAVAILABLE' => LoopL10n.current.launch_contractText16,
  'REWARD_AUTHORITY_PENDING' => LoopL10n.current.launch_contractText17,
  'COMMUNITY_WEIGHT_PENDING_REVIEW' => LoopL10n.current.launch_contractText18,
  // referral
  'REFERRAL_RUNTIME_UNAVAILABLE' => LoopL10n.current.launch_contractText19,
  'PROFILE_ACTIVATION_REQUIRED' => LoopL10n.current.launch_contractText20,
  null => LoopL10n.current.common_itemUnavailable,
  _ => LoopL10n.current.common_itemUnavailable,
};

/// Decision 0097: `LAUNCH_CONTRACT_BASELINE_PENDING` on a resource the
/// server has not opened for reading yet, said without contradicting the
/// capability document.
///
/// Once the `launch` capability's evidence is `confirmed` the contract is
/// live, so the sentence names the resource that is not readable yet
/// ([whenLive]) instead of claiming the contract is missing. Any other code,
/// or evidence that is not confirmed, keeps [launchReasonCodeText].
String launchBaselineReasonText(
  String? reasonCode, {
  required bool contractLive,
  required String whenLive,
}) => contractLive && reasonCode == 'LAUNCH_CONTRACT_BASELINE_PENDING'
    ? whenLive
    : launchReasonCodeText(reasonCode);

/// The 已毕业 card's reason for an `unavailable` list (S83b7b).
///
/// The list is one read of the indexer's projection, so a projection that
/// could not be read or has no checkpoint yet says the list cannot be read
/// right now; `LAUNCH_CONTRACT_BASELINE_PENDING` keeps decision 0097's
/// evidence override; every other (adapter) code keeps
/// [launchReasonCodeText].
String launchGraduatedReasonText(
  String reasonCode, {
  required bool contractLive,
}) => switch (reasonCode) {
  'LAUNCH_ONCHAIN_STATE_READ_FAILED' =>
    LoopL10n.current.launch_contractSwitch33,
  'LAUNCH_ONCHAIN_STATE_NOT_INDEXED' =>
    LoopL10n.current.launch_contractSwitch34,
  _ => launchBaselineReasonText(
    reasonCode,
    contractLive: contractLive,
    whenLive: LoopL10n.current.launch_contractWhenLive,
  ),
};

/// The ledger's reason for supply, distribution and ecosystem tax (S91
/// ruling). Once the `launch` evidence is `confirmed` the contract is live,
/// so `LAUNCH_ECONOMY_CONTRACT_PENDING` no longer says to wait for it; before
/// that, and for any other code, [launchReasonCodeText] stands (as 0097).
String launchEconomyReasonText(
  String? reasonCode, {
  required bool contractLive,
}) => contractLive && reasonCode == 'LAUNCH_ECONOMY_CONTRACT_PENDING'
    ? LoopL10n.current.launch_contractSwitch35
    : launchReasonCodeText(reasonCode);

/// Copy for a refused purchase intent (decision 0088).
///
/// A named `reasonCode` wins. A code this build has no sentence for keeps a
/// neutral sentence, and the page shows the code itself in a disclosure
/// ([launchUnexplainedReasonCode]) so the refusal stays reportable without a
/// backend identifier inside the sentence. Without a code the refusal falls
/// back to its kind.
String launchPurchaseRefusalText(LaunchFailureKind? kind, String? reasonCode) {
  if (reasonCode != null) {
    if (launchUnexplainedReasonCode(reasonCode) == null) {
      return launchReasonCodeText(reasonCode);
    }
    return LoopL10n.current.launch_contractIf;
  }
  return launchFailureReason(kind);
}

/// The code itself when this build has no sentence for it, else `null`.
String? launchUnexplainedReasonCode(String? reasonCode) =>
    reasonCode == null ||
        launchReasonCodeText(reasonCode) != launchReasonCodeText(null)
    ? null
    : reasonCode;

/// The reviewed page states for an S7 surface.
enum LaunchViewPhase {
  loading,
  ready,
  empty,
  error,
  offline,
  unavailable,
  permission,
}

LaunchViewPhase launchPhaseForFailure(LaunchFailureKind? kind) =>
    switch (kind) {
      LaunchFailureKind.offline ||
      LaunchFailureKind.timedOut => LaunchViewPhase.offline,
      LaunchFailureKind.unavailable => LaunchViewPhase.unavailable,
      LaunchFailureKind.permissionDenied ||
      LaunchFailureKind.policyBlocked ||
      LaunchFailureKind.activationRequired => LaunchViewPhase.permission,
      null => LaunchViewPhase.empty,
      _ => LaunchViewPhase.error,
    };

/// One loaded resource plus the honest phase for the block that renders it.
@immutable
final class LaunchResourceState<T> {
  const LaunchResourceState({
    required this.mode,
    required this.phase,
    this.value,
    this.failureKind,
    this.busy = false,
    this.refreshing = false,
  });

  factory LaunchResourceState.initial(LaunchGatewayMode mode) {
    final closed = mode == LaunchGatewayMode.unavailable;
    return LaunchResourceState<T>(
      mode: mode,
      phase: closed ? LaunchViewPhase.unavailable : LaunchViewPhase.loading,
      failureKind: closed ? LaunchFailureKind.unavailable : null,
    );
  }

  final LaunchGatewayMode mode;
  final LaunchViewPhase phase;
  final T? value;
  final LaunchFailureKind? failureKind;

  /// A write is in flight. The page keeps rendering the last server truth and
  /// only disables its actions.
  final bool busy;

  /// A read is in flight over a value this block already holds.
  ///
  /// The page keeps what it read last time and marks it 更新中; it does not
  /// fall back to a skeleton, because replacing readable data with a grey
  /// placeholder loses information the user already had. Only a block with no
  /// value at all loads as a skeleton.
  final bool refreshing;

  bool get isReady => phase == LaunchViewPhase.ready && value != null;

  LaunchResourceState<T> loading() => LaunchResourceState<T>(
    mode: mode,
    phase: value == null ? LaunchViewPhase.loading : LaunchViewPhase.ready,
    value: value,
    busy: busy,
    refreshing: value != null,
  );

  LaunchResourceState<T> ready(T next) => LaunchResourceState<T>(
    mode: mode,
    phase: LaunchViewPhase.ready,
    value: next,
  );

  LaunchResourceState<T> failed(LaunchFailureKind kind) =>
      LaunchResourceState<T>(
        mode: mode,
        phase: value == null
            ? launchPhaseForFailure(kind)
            : LaunchViewPhase.ready,
        value: value,
        failureKind: kind,
      );

  LaunchResourceState<T> working(bool next) => LaunchResourceState<T>(
    mode: mode,
    phase: phase,
    value: value,
    refreshing: refreshing,
    failureKind: next ? null : failureKind,
    busy: next,
  );
}
