enum LoopBackendFailureKind {
  invalidConfiguration,
  authentication,
  invalidRequest,
  unavailable,
  timeout,
  connection,
  cancelled,
  invalidPayload,
  unexpected,
}

/// Sanitized mobile-facing failure for LOOP backend boundaries.
///
/// Response bodies, access tokens, provider errors, and request headers are
/// deliberately excluded. [code] is limited to the backend's stable public
/// error code when one is available.
final class LoopBackendFailure implements Exception {
  const LoopBackendFailure(this.kind, {this.statusCode, this.code});

  final LoopBackendFailureKind kind;
  final int? statusCode;
  final String? code;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'LOOP backend request failed: ${kind.name}$status';
  }
}
