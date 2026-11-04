import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// The one sentence a failed feedback read or send shows (S332 · decision
/// 0262). The chain wording (`loopChainFailureReason`) speaks of on-chain
/// data and is wrong here.
String betaFeedbackFailureReason(
  LoopChainFailureKind? kind, {
  required bool write,
}) => switch (kind) {
  LoopChainFailureKind.offline || LoopChainFailureKind.timedOut =>
    write
        ? LoopL10n.current.betaFeedback_copySubmitOffline
        : LoopL10n.current.betaFeedback_copyLoadOffline,
  LoopChainFailureKind.cancelled ||
  LoopChainFailureKind.outcomeUnknown ||
  LoopChainFailureKind.submissionUnknown =>
    LoopL10n.current.betaFeedback_copySubmissionUnknown,
  LoopChainFailureKind.unavailable =>
    LoopL10n.current.betaFeedback_copyUnavailable,
  LoopChainFailureKind.permissionDenied || LoopChainFailureKind.regionBlocked =>
    LoopL10n.current.betaFeedback_copyRegionBlocked,
  LoopChainFailureKind.rateLimited =>
    LoopL10n.current.betaFeedback_copyRateLimited,
  LoopChainFailureKind.validationFailed =>
    LoopL10n.current.betaFeedback_copyValidationFailed,
  LoopChainFailureKind.bootstrapRequired =>
    LoopL10n.current.betaFeedback_copyBootstrapRequired,
  LoopChainFailureKind.invalidData =>
    write
        ? LoopL10n.current.betaFeedback_copySubmitMalformed
        : LoopL10n.current.betaFeedback_copyLoadMalformed,
  _ =>
    write
        ? LoopL10n.current.betaFeedback_copySubmitFailed
        : LoopL10n.current.betaFeedback_copyLoadFailed,
};

/// `2026-11-02 14:05`, in the device's time zone.
String betaFeedbackTime(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
