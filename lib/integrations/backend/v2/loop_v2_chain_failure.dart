import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';

/// Maps the frozen V2 error catalogue onto the narrow S5 feature kinds.
///
/// `lib/features/` never sees an HTTP status, a `code` string or a provider
/// detail; it only branches on [LoopChainFailureKind].
///
/// [write] is what the request was, and it decides the transport failures that
/// carry no server answer. After a write a payload the client cannot parse
/// leaves the outcome genuinely unresolved — the server may have applied it —
/// so the page must say so and warn against submitting again. After a GET
/// nothing was submitted at all: the same failure is a page that did not load,
/// and telling somebody who opened 网络与 RPC not to submit twice names a
/// submission they never made (R3-2).
LoopChainFailureKind loopChainFailureKindForV2(
  LoopBackendFailure failure, {
  required bool write,
}) {
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
      LoopBackendFailureKind.cancelled =>
        write
            ? LoopChainFailureKind.cancelled
            : LoopChainFailureKind.readFailed,
      // A payload the client could not parse leaves a write unresolved: the
      // server may already have applied it. A read has applied nothing, so it
      // is a page that did not load.
      LoopBackendFailureKind.invalidPayload =>
        write
            ? LoopChainFailureKind.outcomeUnknown
            : LoopChainFailureKind.invalidData,
      LoopBackendFailureKind.unavailable ||
      LoopBackendFailureKind.authentication ||
      LoopBackendFailureKind.invalidConfiguration =>
        LoopChainFailureKind.unavailable,
      _ =>
        write
            ? LoopChainFailureKind.unexpected
            : LoopChainFailureKind.readFailed,
    },
  };
}

/// Projects one backend failure onto the feature-facing exception, carrying the
/// server's own rule name and the two figures it compared.
///
/// The rule is what makes a refusal explainable: "blocked by policy" is not an
/// explanation, "this asset is not in the canary allowlist" is. Nothing outside
/// the allowlisted scalar slots crosses this boundary.
LoopChainException loopChainExceptionForV2(
  LoopBackendFailure failure, {
  required bool write,
}) {
  final details = failure.detailsSafe;
  return LoopChainException(
    loopChainFailureKindForV2(failure, write: write),
    reasonCode: details?.reasonCode,
    exposureUsd: details?.exposureUsd,
    ceilingUsd: details?.ceilingUsd,
    spentUsd: details?.spentUsd,
    remainingUsd: details?.remainingUsd,
  );
}

/// Runs one authenticated S5 request and maps every transport failure onto the
/// narrow feature-facing kind. No provider detail ever escapes.
///
/// [write] states whether the request could have changed anything on the
/// server. It is what separates "the outcome is unknown, do not submit again"
/// from "this did not load".
Future<T> executeChainRequest<T>(
  LoopAuthenticatedSession session,
  Future<T> Function(String accessToken) request, {
  required bool write,
}) async {
  try {
    return await session.execute(request);
  } on LoopBackendFailure catch (failure) {
    throw loopChainExceptionForV2(failure, write: write);
  } on LoopChainException {
    rethrow;
  } catch (_) {
    throw LoopChainException(
      write ? LoopChainFailureKind.unexpected : LoopChainFailureKind.readFailed,
    );
  }
}
