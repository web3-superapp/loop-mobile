import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';

enum WatchlistMode { unavailable, preview, production }

enum WatchlistGatewayFailureKind {
  unavailable,
  versionConflict,
  invalidData,
  unexpected,
}

final class WatchlistGatewayException implements Exception {
  const WatchlistGatewayException(this.kind);

  final WatchlistGatewayFailureKind kind;

  String get code => switch (kind) {
    WatchlistGatewayFailureKind.unavailable => 'watchlist_unavailable',
    WatchlistGatewayFailureKind.versionConflict => 'version_conflict',
    WatchlistGatewayFailureKind.invalidData => 'invalid_watchlist_data',
    WatchlistGatewayFailureKind.unexpected => 'watchlist_request_failed',
  };

  @override
  String toString() => code;
}

abstract interface class WatchlistGateway {
  WatchlistMode get mode;

  Future<WatchlistSnapshot> load();

  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  });
}

/// Production-safe default while the authenticated mobile transport is absent.
final class UnavailableWatchlistGateway implements WatchlistGateway {
  const UnavailableWatchlistGateway();

  @override
  WatchlistMode get mode => WatchlistMode.unavailable;

  @override
  Future<WatchlistSnapshot> load() => Future<WatchlistSnapshot>.error(
    const WatchlistGatewayException(WatchlistGatewayFailureKind.unavailable),
  );

  @override
  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  }) => Future<WatchlistSnapshot>.error(
    const WatchlistGatewayException(WatchlistGatewayFailureKind.unavailable),
  );
}

final watchlistGatewayProvider = Provider<WatchlistGateway>(
  (ref) => const UnavailableWatchlistGateway(),
);
