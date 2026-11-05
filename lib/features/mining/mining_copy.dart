import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// Copy shared by the mining pages, where one sentence would otherwise be
/// written three times and drift in two of them.

/// The section that dates a mining-power snapshot, and the row inside it.
///
/// `computedAt` is when the snapshot worker computed the power — the lane
/// writes one every few minutes — not when anything was settled, owed or
/// paid. 「最近一次结算」 read as a payout on pages whose every figure is
/// power, so the word names the computation it actually is.
/// The expression the whole module is about. Decision 0146 (loop-api 0123):
/// the asset track is weighted by quantity, no price.
///
/// It is a conclusion, not a page title: 算力明细 heads its card with the
/// expression and prints the total it produces underneath.
String get miningPowerFormulaHeading =>
    LoopL10n.current.mining_copyMiningPowerFormulaHeading;

/// The three conditions a holding must meet before it counts (loop-api
/// decision 0183, 需求方 2026-10-25), one fact per sentence. Every page that
/// says a holding produces power points at these instead of restating them.
String get miningConditionVerified =>
    LoopL10n.current.mining_copyMiningConditionVerified;
String get miningConditionMember =>
    LoopL10n.current.mining_copyMiningConditionMember;
String get miningConditionEmbedded =>
    LoopL10n.current.mining_copyMiningConditionEmbedded;

/// The conditions in one line, for a caption with room for a single clause.
String get miningConditionsShort =>
    LoopL10n.current.mining_copyMiningConditionsShort;

String get miningSnapshotSectionLabel =>
    LoopL10n.current.mining_copyMiningSnapshotSectionLabel;
String get miningSnapshotRowTitle =>
    LoopL10n.current.mining_copyMiningSnapshotRowTitle;

/// What a page may state when a snapshot reference came back unavailable.
///
/// 「还没有算力快照」 is a claim about the world, and only
/// `MINING_SNAPSHOT_NOT_AVAILABLE` makes it: there is an effective formula
/// version and the lane has not produced a snapshot under it yet. Every
/// other code on this slot is about the read — a repository that did not
/// answer, a version that is not in effect — and tells the page nothing about
/// whether a snapshot exists. Saying "there is none" there would turn a
/// failed read into a fact.
String miningSnapshotAbsenceMessage(String reasonCode) => switch (reasonCode) {
  'MINING_SNAPSHOT_NOT_AVAILABLE' => LoopL10n.current.mining_copySwitch,
  // Runs happened and none of them completed, so there is nothing to fall
  // back to. It is a different sentence from 「还没有算过」 (Decision 0057).
  'MINING_SNAPSHOT_INCOMPLETE' => LoopL10n.current.mining_copySwitch2,
  'MINING_SNAPSHOT_PENDING' => LoopL10n.current.mining_copySwitch3,
  _ => LoopL10n.current.mining_copySwitch4,
};

/// The second line under [miningSnapshotAbsenceMessage].
///
/// For the one code that means "there is none" the copy table's sentence says
/// the same thing the message already said, so this line carries what happens
/// next instead; every other code keeps the server's own reason.
/// For the codes that already said 「there is none」 in the message, this line
/// carries what happens next, or — when the server named the run that failed
/// — what stopped it.
String miningSnapshotAbsenceReason(
  String reasonCode, {
  MiningSnapshotAttempt? attempt,
  Map<String, String> symbols = const <String, String>{},
}) {
  if (reasonCode == 'MINING_SNAPSHOT_NOT_AVAILABLE' ||
      reasonCode == 'MINING_SNAPSHOT_PENDING') {
    return LoopL10n.current.mining_copyIf;
  }
  if (reasonCode == 'MINING_SNAPSHOT_INCOMPLETE') {
    final cause = attempt == null
        ? null
        : miningAttemptCause(attempt, symbols: symbols);
    return cause == null
        ? LoopL10n.current.mining_copyIf2
        : LoopL10n.current.mining_copyS(cause);
  }
  return launchReasonCodeText(reasonCode);
}

/// One holding the newest run could not value, in the reader's words.
///
/// The asset is named by the registry symbol when the page was given one, and
/// by the id it stands for otherwise; the reason is the server's, said as the
/// fact it is. 「没有可用报价」 is what `MINING_PRICE_PAIR_NOT_FOUND` means to
/// a reader: no venue LOOP reads priced this asset in this run.
String miningUnreadInputText(
  MiningUnreadInput input, {
  Map<String, String> symbols = const <String, String>{},
}) {
  final label = miningAssetTitle(
    symbol: symbols[input.assetId],
    assetId: input.assetId,
  );
  return switch (input.reasonCode) {
    'MINING_PRICE_PAIR_NOT_FOUND' => LoopL10n.current.mining_copySwitch5(label),
    'MINING_PRICE_NOT_FRESH' => LoopL10n.current.mining_copySwitch6(label),
    'MINING_PRICE_PROXY_NOT_DECLARED' => LoopL10n.current.mining_copySwitch7(
      label,
    ),
    _ => LoopL10n.current.mining_copySwitch8(label),
  };
}

/// Why the newest run did not become the numbers on the page, or `null` when
/// the server gave no cause the page may state.
///
/// A run is never published unless it valued every holding it weighs, so the
/// unread list *is* the cause and is named asset by asset. At most three are
/// listed: the sentence is a line under a figure, not a report.
String? miningAttemptCause(
  MiningSnapshotAttempt attempt, {
  Map<String, String> symbols = const <String, String>{},
}) {
  if (attempt.unreadInputs.isNotEmpty) {
    const limit = 3;
    final named = attempt.unreadInputs
        .take(limit)
        .map((input) => miningUnreadInputText(input, symbols: symbols))
        .join(LoopL10n.current.widgets_enumerationSeparator);
    final rest = attempt.unreadInputs.length - limit;
    return rest > 0 ? LoopL10n.current.mining_copyIf3(named, rest) : named;
  }
  return switch (attempt.status) {
    MiningSnapshotAttemptStatus.incomplete =>
      LoopL10n.current.mining_copyIncomplete,
    MiningSnapshotAttemptStatus.invalidated =>
      attempt.reasonCode == 'MINING_SNAPSHOT_PUBLISHED_INCOMPLETE'
          ? LoopL10n.current.mining_copySwitch9
          : null,
    MiningSnapshotAttemptStatus.complete => null,
  };
}

/// The line every page carrying a stale reading prints beside it.
///
/// It says two things and no more: which moment the numbers are from, and
/// that the run after it did not become numbers. It never withdraws the
/// figures — a published snapshot valued every holding it weighs, which is
/// exactly why the later run was not published.
///
/// S378 · decision 0302 (需求方 2026-11-05): the line no longer dates the
/// snapshot; it says the numbers are the last complete one's.
String miningStaleLine({
  MiningSnapshotAttempt? attempt,
  Map<String, String> symbols = const <String, String>{},
}) {
  final tail = attempt != null && attempt.isInvalidated
      ? LoopL10n.current.mining_copyMiningStaleLine
      : LoopL10n.current.mining_copyS2;
  final cause = attempt == null
      ? null
      : miningAttemptCause(attempt, symbols: symbols);
  final head = LoopL10n.current.mining_copyHead;
  return cause == null
      ? '$head · $tail'
      : LoopL10n.current.mining_copyStaleWithCause(cause, head, tail);
}
