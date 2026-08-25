import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';

/// Explicit in-memory implementation for deterministic Preview or tests.
///
/// It is intentionally not composed by the production provider.
final class MemoryWatchlistGateway implements WatchlistGateway {
  MemoryWatchlistGateway({
    WatchlistSnapshot? initialSnapshot,
    DateTime Function()? clock,
  }) : _snapshot = WatchlistSnapshot.copyOf(
         initialSnapshot ?? WatchlistSnapshot.empty(),
       ),
       _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  WatchlistSnapshot _snapshot;

  @override
  WatchlistMode get mode => WatchlistMode.preview;

  @override
  Future<WatchlistSnapshot> load() async {
    return WatchlistSnapshot.copyOf(_snapshot);
  }

  @override
  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  }) async {
    late final List<WatchlistGroup> candidate;
    try {
      if (expectedVersion < 0 || expectedVersion > watchlistMaximumVersion) {
        throw const InvalidWatchlistContractException();
      }
      candidate = validateWatchlistGroups(groups);
    } on InvalidWatchlistContractException {
      throw const WatchlistGatewayException(
        WatchlistGatewayFailureKind.invalidData,
      );
    }

    // The backend checks normalized equality before its optimistic version.
    // This makes an identical, already-applied retry deterministic even when
    // the caller still holds the previous version.
    if (watchlistGroupsEqual(_snapshot.groups, candidate)) {
      return WatchlistSnapshot.copyOf(_snapshot);
    }
    if (expectedVersion != _snapshot.version) {
      throw const WatchlistGatewayException(
        WatchlistGatewayFailureKind.versionConflict,
      );
    }
    if (_snapshot.version == watchlistMaximumVersion) {
      throw const WatchlistGatewayException(
        WatchlistGatewayFailureKind.unavailable,
      );
    }

    _snapshot = WatchlistSnapshot(
      version: _snapshot.version + 1,
      groups: candidate,
      updatedAt: _clock().toUtc(),
    );
    return WatchlistSnapshot.copyOf(_snapshot);
  }
}
