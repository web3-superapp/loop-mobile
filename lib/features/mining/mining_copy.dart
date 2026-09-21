import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';

/// Copy shared by the mining pages, where one sentence would otherwise be
/// written three times and drift in two of them.

/// The section that dates a mining-power snapshot, and the row inside it.
///
/// `computedAt` is when the snapshot worker computed the power — the lane
/// writes one every few minutes — not when anything was settled, owed or
/// paid. 「最近一次结算」 read as a payout on pages whose every figure is
/// power, so the word names the computation it actually is.
/// The expression the whole module is about, as the prototype writes it.
///
/// It is a conclusion, not a page title: 算力明细 heads its card with the
/// expression and prints the total it produces underneath.
const String miningPowerFormulaHeading = '持有量 × 参考价 × 权重';

const String miningSnapshotSectionLabel = '算力快照';
const String miningSnapshotRowTitle = '最近一次算力快照';

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
  'MINING_SNAPSHOT_NOT_AVAILABLE' => '还没有算力快照',
  // Runs happened and none of them completed, so there is nothing to fall
  // back to. It is a different sentence from 「还没有算过」 (Decision 0057).
  'MINING_SNAPSHOT_INCOMPLETE' => '还没有完整的算力快照',
  'MINING_SNAPSHOT_PENDING' => '下一次算力快照之后显示',
  _ => '暂时读不到算力快照',
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
    return '下一次算力快照之后，这里会显示区块与时间。';
  }
  if (reasonCode == 'MINING_SNAPSHOT_INCOMPLETE') {
    final cause = attempt == null
        ? null
        : miningAttemptCause(attempt, symbols: symbols);
    return cause == null
        ? '最近一次计算没有完成，没有可以回退的完整快照。'
        : '最近一次计算没有完成（$cause），没有可以回退的完整快照。';
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
    'MINING_PRICE_PAIR_NOT_FOUND' => '$label 暂时没有可用报价',
    'MINING_PRICE_NOT_FRESH' => '$label 的参考价不够新',
    'MINING_PRICE_PROXY_NOT_DECLARED' => '$label 的参考价来自未登记的代币',
    _ => '$label 的参考价这次读不到',
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
        .join('、');
    final rest = attempt.unreadInputs.length - limit;
    return rest > 0 ? '$named，另有 $rest 个资产' : named;
  }
  return switch (attempt.status) {
    MiningSnapshotAttemptStatus.incomplete => '有资产的参考价这次读不到',
    MiningSnapshotAttemptStatus.invalidated =>
      attempt.reasonCode == 'MINING_SNAPSHOT_PUBLISHED_INCOMPLETE'
          ? '那次快照的数据不完整'
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
/// [computedAtLabel] is the caller's own UTC label, so the page and this line
/// date the same snapshot the same way.
String miningStaleLine({
  required String computedAtLabel,
  MiningSnapshotAttempt? attempt,
  Map<String, String> symbols = const <String, String>{},
}) {
  final tail = attempt != null && attempt.isInvalidated
      ? '最近一次快照已作废'
      : '最近一次快照未完成';
  final cause = attempt == null
      ? null
      : miningAttemptCause(attempt, symbols: symbols);
  final head = '显示的是 $computedAtLabel 的算力快照';
  return cause == null ? '$head · $tail' : '$head · $tail（$cause）';
}
