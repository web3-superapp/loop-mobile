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

/// The scalar slots the envelope's `detailsSafe` may carry.
///
/// The wire type is an open object, so it is read through a fixed allowlist
/// rather than echoed: an unlisted key never reaches a page, and a value that
/// is not a bounded scalar is dropped instead of rendered. The three slots
/// below are the only ones the frozen contract defines (`docs/api-v2-conventions`
/// §7.1): the rule that refused the request, the figures that rule compared,
/// and — on a quota refusal — which budget was exhausted.
final class LoopFailureDetails {
  const LoopFailureDetails({
    this.reasonCode,
    this.exposureUsd,
    this.ceilingUsd,
    this.spentUsd,
    this.remainingUsd,
    this.scope,
  });

  static final RegExp _reasonCodePattern = RegExp(r'^[A-Z][A-Z0-9_]{0,63}$');
  static final RegExp _scopePattern = RegExp(r'^[a-z][a-zA-Z0-9]{0,31}$');
  static final RegExp _decimalPattern = RegExp(
    r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,30})?$',
  );

  /// Reads the allowlisted keys from an already-validated `detailsSafe` map.
  /// Returns `null` when nothing usable is present, so a caller can keep
  /// treating an absent object as absent.
  static LoopFailureDetails? tryRead(Object? raw) {
    if (raw is! Map) return null;
    String? scalar(String key, RegExp pattern, int maxLength) {
      final value = raw[key];
      if (value is! String ||
          value.length > maxLength ||
          !pattern.hasMatch(value)) {
        return null;
      }
      return value;
    }

    final details = LoopFailureDetails(
      reasonCode: scalar('reasonCode', _reasonCodePattern, 64),
      exposureUsd: scalar('exposureUsd', _decimalPattern, 110),
      ceilingUsd: scalar('ceilingUsd', _decimalPattern, 110),
      spentUsd: scalar('spentUsd', _decimalPattern, 110),
      remainingUsd: scalar('remainingUsd', _decimalPattern, 110),
      scope: scalar('scope', _scopePattern, 32),
    );
    return details.isEmpty ? null : details;
  }

  /// The server's own rule name, e.g. `CANARY_CEILING_EXCEEDED`.
  final String? reasonCode;

  /// Exact decimal strings; never parsed into a `double`.
  final String? exposureUsd;
  final String? ceilingUsd;

  /// Only the rolling-24-hour ceiling sends these: how much of the day's
  /// budget is already committed, and what is left of it. They are the two
  /// figures that make that refusal actionable — without them the owner knows
  /// the request was too big but not by how much (S77b §7.1.1).
  final String? spentUsd;
  final String? remainingUsd;

  /// Which budget a `RATE_LIMITED` refusal was measured against — the
  /// caller's own minute, or the whole community's day. They are two
  /// different waits, so they are two different sentences.
  final String? scope;

  bool get isEmpty =>
      reasonCode == null &&
      exposureUsd == null &&
      ceilingUsd == null &&
      spentUsd == null &&
      remainingUsd == null &&
      scope == null;

  /// True only when both figures the ceiling rules compare are present.
  bool get hasCeilingFigures => exposureUsd != null && ceilingUsd != null;
}

/// Sanitized mobile-facing failure for LOOP backend boundaries.
///
/// Response bodies, access tokens, provider errors, and request headers are
/// deliberately excluded. [code] is limited to the backend's stable public
/// error code and validated request ID when they are available.
final class LoopBackendFailure implements Exception {
  const LoopBackendFailure(
    this.kind, {
    this.statusCode,
    this.code,
    this.requestId,
    this.category,
    this.retryable,
    this.userMessageKey,
    this.detailsSafe,
  });

  final LoopBackendFailureKind kind;
  final int? statusCode;
  final String? code;
  final String? requestId;
  final String? category;
  final bool? retryable;
  final String? userMessageKey;

  /// The allowlisted scalar slots the server attached to this refusal.
  final LoopFailureDetails? detailsSafe;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'LOOP backend request failed: ${kind.name}$status';
  }
}
