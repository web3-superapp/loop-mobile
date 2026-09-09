import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';

/// Explicit Development Preview Watchlist, written against the V2 contract.
///
/// Every surface backed by it renders the visible `演示数据` label. Nothing
/// here reaches an account, a provider or a chain: the resource lives in this
/// process only, and its version behaves exactly like the server's — a replace
/// under a stale `expectedVersion` is a [LoopChainFailureKind.versionConflict],
/// never a silent overwrite.
///
/// Only `lib/main_preview.dart` may construct it. The production composition
/// root leaves [UnavailableWatchlistGateway] in place, so a production build
/// with no transport shows the fail-closed state rather than this fixture.
final class MemoryWatchlistGateway implements WatchlistGateway {
  MemoryWatchlistGateway({WatchlistSnapshot? initialSnapshot})
    : _snapshot = initialSnapshot ?? previewWatchlistSnapshot();

  WatchlistSnapshot _snapshot;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.preview;

  @override
  Future<WatchlistSnapshot> load() async => _snapshot;

  @override
  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  }) async {
    if (expectedVersion != _snapshot.version) {
      throw const LoopChainException(LoopChainFailureKind.versionConflict);
    }
    try {
      _snapshot = WatchlistSnapshot(
        version: _snapshot.version + 1,
        updatedAt: DateTime.now().toUtc(),
        groups: groups,
      );
    } on InvalidWatchlistContractException {
      // The server refuses the same shapes the model refuses.
      throw const LoopChainException(LoopChainFailureKind.validationFailed);
    }
    return _snapshot;
  }
}

/// The seeded Preview resource: two groups, one unreadable row.
///
/// The unreadable row exists on purpose — it is the contract's own case where
/// the registry can no longer read an asset, and the editor must still list it
/// so the owner can remove it.
WatchlistSnapshot previewWatchlistSnapshot() => WatchlistSnapshot(
  version: 1,
  updatedAt: DateTime.utc(2026, 9, 1, 8, 30),
  groups: <WatchlistGroup>[
    WatchlistGroup(
      key: 'default',
      name: '默认',
      items: <WatchlistItem>[
        WatchlistItem(
          assetId: 'eip155:56:native',
          asset: const LoopAssetSummary(
            symbol: 'BNB',
            name: 'BNB',
            decimals: 18,
            status: LoopAssetStatus.verified,
          ),
        ),
        WatchlistItem(
          assetId: 'eip155:56:0x55d398326f99059ff775485246999027b3197955',
          asset: const LoopAssetSummary(
            symbol: 'USDT',
            name: 'Tether USD',
            decimals: 18,
            status: LoopAssetStatus.verified,
          ),
        ),
      ],
    ),
    WatchlistGroup(
      key: 'watching',
      name: '观察中',
      items: <WatchlistItem>[
        WatchlistItem(
          assetId: 'eip155:56:0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
          asset: const LoopAssetSummary(
            symbol: 'CAKE',
            name: 'PancakeSwap Token',
            decimals: 18,
            status: LoopAssetStatus.verified,
          ),
        ),
        WatchlistItem(
          assetId: 'eip155:56:0x1111111111111111111111111111111111111111',
          reasonCode: 'ASSET_NOT_READABLE',
        ),
      ],
    ),
  ],
);
