import 'package:loop_mobile/features/launch/launch_contract.dart';

/// Copy shared by the mining pages, where one sentence would otherwise be
/// written three times and drift in two of them.

/// What a page may state when a settlement reference came back unavailable.
///
/// 「还没有结算记录」 is a claim about the world, and only
/// `MINING_SNAPSHOT_NOT_AVAILABLE` makes it: there is an effective formula
/// version and the lane has not produced a settlement under it yet. Every
/// other code on this slot is about the read — a repository that did not
/// answer, a version that is not in effect — and tells the page nothing about
/// whether a settlement exists. Saying "there is none" there would turn a
/// failed read into a fact.
String miningSnapshotAbsenceMessage(String reasonCode) => switch (reasonCode) {
  'MINING_SNAPSHOT_NOT_AVAILABLE' => '还没有结算记录',
  _ => '暂时读不到结算记录',
};

/// The second line under [miningSnapshotAbsenceMessage].
///
/// For the one code that means "there is none" the copy table's sentence says
/// the same thing the message already said, so this line carries what happens
/// next instead; every other code keeps the server's own reason.
String miningSnapshotAbsenceReason(String reasonCode) =>
    reasonCode == 'MINING_SNAPSHOT_NOT_AVAILABLE'
    ? '下一次结算之后，这里会显示区块与时间。'
    : launchReasonCodeText(reasonCode);
