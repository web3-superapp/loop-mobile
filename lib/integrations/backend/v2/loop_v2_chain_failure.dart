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

/// Runs one authenticated S5 request and maps every transport failure onto the
/// narrow feature-facing kind. No provider detail ever escapes.
Future<T> executeChainRequest<T>(
  LoopAuthenticatedSession session,
  Future<T> Function(String accessToken) request,
) async {
  try {
    return await session.execute(request);
  } on LoopBackendFailure catch (failure) {
    throw LoopChainException(loopChainFailureKindForV2(failure));
  } on LoopChainException {
    rethrow;
  } catch (_) {
    throw const LoopChainException(LoopChainFailureKind.unexpected);
  }
}
