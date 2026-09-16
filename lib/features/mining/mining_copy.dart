import 'package:loop_mobile/features/launch/launch_contract.dart';

/// Copy shared by the mining pages, where one sentence would otherwise be
/// written three times and drift in two of them.

/// The section that dates a mining-power snapshot, and the row inside it.
///
/// `computedAt` is when the snapshot worker computed the power — the lane
/// writes one every few minutes — not when anything was settled, owed or
/// paid. 「最近一次结算」 read as a payout on pages whose every figure is
/// power, so the word names the computation it actually is.
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
  _ => '暂时读不到算力快照',
};

/// The second line under [miningSnapshotAbsenceMessage].
///
/// For the one code that means "there is none" the copy table's sentence says
/// the same thing the message already said, so this line carries what happens
/// next instead; every other code keeps the server's own reason.
String miningSnapshotAbsenceReason(String reasonCode) =>
    reasonCode == 'MINING_SNAPSHOT_NOT_AVAILABLE'
    ? '下一次算力快照之后，这里会显示区块与时间。'
    : launchReasonCodeText(reasonCode);
