import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';

/// Maps the frozen V2 error catalogue onto the narrow S5 feature kinds.
///
/// `lib/features/` never sees an HTTP status, a `code` string or a provider
/// detail; it only branches on [LoopChainFailureKind].
LoopChainFailureKind loopChainFailureKindForV2(LoopBackendFailure failure) {
  return switch (failure.code) {
    'PERMISSION_DENIED' ||
    'POLICY_BLOCKED' => LoopChainFailureKind.permissionDenied,
    // A jurisdiction rule, not an account one. It is kept apart so the copy
    // never suggests switching account or asset.
    'REGION_BLOCKED' => LoopChainFailureKind.regionBlocked,
    // The command needs a second factor the product has not delivered; it is
    // a permanent refusal, never a retryable failure.
    'AUTH_STEP_UP_REQUIRED' => LoopChainFailureKind.stepUpRequired,
    'NOT_FOUND' || 'SESSION_NOT_FOUND' => LoopChainFailureKind.notFound,
    'VERSION_CONFLICT' || 'DATA_STALE' => LoopChainFailureKind.versionConflict,
    'ACCOUNT_BOOTSTRAP_REQUIRED' => LoopChainFailureKind.bootstrapRequired,
    'IDEMPOTENCY_CONFLICT' => LoopChainFailureKind.idempotencyConflict,
    'VALIDATION_FAILED' => LoopChainFailureKind.validationFailed,
    'CHAIN_MISMATCH' => LoopChainFailureKind.chainMismatch,
    'RATE_LIMITED' => LoopChainFailureKind.rateLimited,
    // The indexer has never run: the list is unknown, never empty.
    'INDEXING_DELAYED' => LoopChainFailureKind.indexingDelayed,
    'CAPABILITY_UNAVAILABLE' ||
    'PROVIDER_DISCONNECTED' => LoopChainFailureKind.unavailable,
    'INVALID_REQUEST' => LoopChainFailureKind.invalidData,
    'INSUFFICIENT_BALANCE' => LoopChainFailureKind.insufficientBalance,
    'SIMULATION_FAILED' => LoopChainFailureKind.simulationFailed,
    'QUOTE_EXPIRED' => LoopChainFailureKind.quoteExpired,
    // The server already accepted one submission whose outcome is unresolved.
    // The client must poll it; a second attempt is forbidden.
    'SUBMISSION_UNKNOWN' => LoopChainFailureKind.submissionUnknown,
    _ => switch (failure.kind) {
      LoopBackendFailureKind.connection ||
      LoopBackendFailureKind.timeout => LoopChainFailureKind.offline,
      LoopBackendFailureKind.cancelled => LoopChainFailureKind.cancelled,
      // A payload the client could not parse leaves a write unresolved: the
      // server may already have applied it.
      LoopBackendFailureKind.invalidPayload =>
        LoopChainFailureKind.outcomeUnknown,
      LoopBackendFailureKind.unavailable ||
      LoopBackendFailureKind.authentication ||
      LoopBackendFailureKind.invalidConfiguration =>
        LoopChainFailureKind.unavailable,
      _ => LoopChainFailureKind.unexpected,
    },
  };
}

/// Projects one backend failure onto the feature-facing exception, carrying the
/// server's own rule name and the two figures it compared.
///
/// The rule is what makes a refusal explainable: "blocked by policy" is not an
/// explanation, "this asset is not in the canary allowlist" is. Nothing outside
/// the allowlisted scalar slots crosses this boundary.
LoopChainException loopChainExceptionForV2(LoopBackendFailure failure) {
  final details = failure.detailsSafe;
  return LoopChainException(
    loopChainFailureKindForV2(failure),
    reasonCode: details?.reasonCode,
    exposureUsd: details?.exposureUsd,
    ceilingUsd: details?.ceilingUsd,
  );
}

/// Runs one authenticated S5 request and maps every transport failure onto the
/// narrow feature-facing kind. No provider detail ever escapes.
Future<T> executeChainRequest<T>(
  LoopAuthenticatedSession session,
  Future<T> Function(String accessToken) request,
) async {
  try {
    return await session.execute(request);
  } on LoopBackendFailure catch (failure) {
    throw loopChainExceptionForV2(failure);
  } on LoopChainException {
    rethrow;
  } catch (_) {
    throw const LoopChainException(LoopChainFailureKind.unexpected);
  }
}
