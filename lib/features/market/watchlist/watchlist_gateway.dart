import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';

/// Feature-facing port for the `watchlist` module.
///
/// The whole resource is replaced under a version CAS; there is no per-item
/// mutation and no `Idempotency-Key` (the server rejects one).
abstract interface class WatchlistGateway {
  LoopChainGatewayMode get mode;

  Future<WatchlistSnapshot> load();

  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  });
}

/// Production-safe default while the authenticated transport is absent.
final class UnavailableWatchlistGateway implements WatchlistGateway {
  const UnavailableWatchlistGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<WatchlistSnapshot> load() => Future<WatchlistSnapshot>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  }) => Future<WatchlistSnapshot>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

final watchlistGatewayProvider = Provider<WatchlistGateway>(
  (ref) => const UnavailableWatchlistGateway(),
);
