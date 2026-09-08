import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

/// Feature-facing port for the `market` module. Reads only; there is no order,
/// quote or execution path anywhere behind it.
abstract interface class MarketReadGateway {
  LoopChainGatewayMode get mode;

  Future<MarketOverview> loadOverview();

  Future<MarketAssetDetail> loadAsset(String assetId);

  Future<MarketCandleSeries> loadCandles(
    String assetId, {
    required LoopCandleInterval interval,
    int? limit,
  });

  Future<MarketTradesPage> loadTrades(String assetId, {String? cursor});

  Future<MarketHolders> loadHolders(String assetId);

  Future<MarketNewPairsPage> loadNewPairs();

  /// Always resolves to an unavailable projection in this step.
  Future<LoopUnavailable> loadSmartMoney();
}

final class UnavailableMarketReadGateway implements MarketReadGateway {
  const UnavailableMarketReadGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<MarketOverview> loadOverview() => _unavailable();

  @override
  Future<MarketAssetDetail> loadAsset(String assetId) => _unavailable();

  @override
  Future<MarketCandleSeries> loadCandles(
    String assetId, {
    required LoopCandleInterval interval,
    int? limit,
  }) => _unavailable();

  @override
  Future<MarketTradesPage> loadTrades(String assetId, {String? cursor}) =>
      _unavailable();

  @override
  Future<MarketHolders> loadHolders(String assetId) => _unavailable();

  @override
  Future<MarketNewPairsPage> loadNewPairs() => _unavailable();

  @override
  Future<LoopUnavailable> loadSmartMoney() => _unavailable();
}

final marketReadGatewayProvider = Provider<MarketReadGateway>(
  (ref) => const UnavailableMarketReadGateway(),
);
