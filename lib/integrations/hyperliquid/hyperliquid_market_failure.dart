enum HyperliquidMarketFailureKind {
  restrictedSession,
  invalidPayload,
  timeout,
  connection,
  unavailable,
  cancelled,
  unexpected,
}

/// A sanitized failure from the public Hyperliquid market-data boundary.
final class HyperliquidMarketFailure implements Exception {
  const HyperliquidMarketFailure(this.kind, {this.statusCode});

  final HyperliquidMarketFailureKind kind;
  final int? statusCode;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'HyperliquidMarketFailure(${kind.name})$status';
  }
}
