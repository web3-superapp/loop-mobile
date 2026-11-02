import 'package:loop_mobile/features/chain/chain_contract.dart';

/// The one sentence a failed feedback read or send shows (S332 · decision
/// 0262). The chain wording (`loopChainFailureReason`) speaks of on-chain
/// data and is wrong here.
String betaFeedbackFailureReason(
  LoopChainFailureKind? kind, {
  required bool write,
}) => switch (kind) {
  LoopChainFailureKind.offline ||
  LoopChainFailureKind.timedOut => write ? '网络不可用，反馈没有提交。' : '网络不可用，没有读到反馈。',
  LoopChainFailureKind.cancelled ||
  LoopChainFailureKind.outcomeUnknown ||
  LoopChainFailureKind.submissionUnknown => '结果未确认，再次提交不会重复。',
  LoopChainFailureKind.unavailable => '反馈服务暂不可用。',
  LoopChainFailureKind.permissionDenied ||
  LoopChainFailureKind.regionBlocked => '当前账号不能使用内测反馈。',
  LoopChainFailureKind.rateLimited => '提交太频繁，请稍后再试。',
  LoopChainFailureKind.validationFailed => '内容或图片不符合要求，请修改后再试。',
  LoopChainFailureKind.bootstrapRequired => '账号尚未完成初始化，请稍后再试。',
  LoopChainFailureKind.invalidData => write ? '返回的数据不完整，结果未确认。' : '返回的数据不完整。',
  _ => write ? '反馈没有提交，请稍后再试。' : '没有读到反馈，请稍后再试。',
};

/// `2026-11-02 14:05`, in the device's time zone.
String betaFeedbackTime(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
