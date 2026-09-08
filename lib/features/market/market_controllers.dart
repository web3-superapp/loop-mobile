import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

LoopChainGatewayMode _marketMode(Ref ref) =>
    ref.watch(marketReadGatewayProvider.select((gateway) => gateway.mode));

/// `market` · `GET /v2/market/overview`.
final class MarketOverviewController
    extends LoopChainReadController<MarketOverview> {
  @override
  LoopChainGatewayMode watchMode() => _marketMode(ref);

  @override
  Future<MarketOverview> fetch() =>
      ref.read(marketReadGatewayProvider).loadOverview();
}

final marketOverviewControllerProvider =
    NotifierProvider.autoDispose<
      MarketOverviewController,
      LoopChainResourceState<MarketOverview>
    >(MarketOverviewController.new);

/// `token` · `GET /v2/market/assets/{assetId}`.
final class MarketAssetController
    extends LoopChainReadController<MarketAssetDetail> {
  MarketAssetController(this.assetId);

  final String assetId;

  @override
  LoopChainGatewayMode watchMode() => _marketMode(ref);

  @override
  Future<MarketAssetDetail> fetch() =>
      ref.read(marketReadGatewayProvider).loadAsset(assetId);
}

final marketAssetControllerProvider = NotifierProvider.autoDispose
    .family<
      MarketAssetController,
      LoopChainResourceState<MarketAssetDetail>,
      String
    >(MarketAssetController.new);

/// The (assetId, interval) pair that identifies one candle request.
@immutable
final class MarketCandleRequest {
  const MarketCandleRequest({required this.assetId, required this.interval});

  final String assetId;
  final LoopCandleInterval interval;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketCandleRequest &&
          other.assetId == assetId &&
          other.interval == interval;

  @override
  int get hashCode => Object.hash(assetId, interval);
}

/// `token` chart / `chart-full` · `…/candles?interval=`.
final class MarketCandlesController
    extends LoopChainReadController<MarketCandleSeries> {
  MarketCandlesController(this.request);

  final MarketCandleRequest request;

  @override
  LoopChainGatewayMode watchMode() => _marketMode(ref);

  @override
  Future<MarketCandleSeries> fetch() => ref
      .read(marketReadGatewayProvider)
      .loadCandles(request.assetId, interval: request.interval);
}

final marketCandlesControllerProvider = NotifierProvider.autoDispose
    .family<
      MarketCandlesController,
      LoopChainResourceState<MarketCandleSeries>,
      MarketCandleRequest
    >(MarketCandlesController.new);

/// `token-trades` · `…/trades`.
final class MarketTradesController
    extends LoopChainReadController<MarketTradesPage> {
  MarketTradesController(this.assetId);

  final String assetId;

  @override
  LoopChainGatewayMode watchMode() => _marketMode(ref);

  @override
  Future<MarketTradesPage> fetch() =>
      ref.read(marketReadGatewayProvider).loadTrades(assetId);
}

final marketTradesControllerProvider = NotifierProvider.autoDispose
    .family<
      MarketTradesController,
      LoopChainResourceState<MarketTradesPage>,
      String
    >(MarketTradesController.new);

/// `token-holders` · `…/holders`.
final class MarketHoldersController
    extends LoopChainReadController<MarketHolders> {
  MarketHoldersController(this.assetId);

  final String assetId;

  @override
  LoopChainGatewayMode watchMode() => _marketMode(ref);

  @override
  Future<MarketHolders> fetch() =>
      ref.read(marketReadGatewayProvider).loadHolders(assetId);
}

final marketHoldersControllerProvider = NotifierProvider.autoDispose
    .family<
      MarketHoldersController,
      LoopChainResourceState<MarketHolders>,
      String
    >(MarketHoldersController.new);

/// `new-pairs` · `GET /v2/market/new-pairs`.
final class MarketNewPairsController
    extends LoopChainReadController<MarketNewPairsPage> {
  @override
  LoopChainGatewayMode watchMode() => _marketMode(ref);

  @override
  Future<MarketNewPairsPage> fetch() =>
      ref.read(marketReadGatewayProvider).loadNewPairs();
}

final marketNewPairsControllerProvider =
    NotifierProvider.autoDispose<
      MarketNewPairsController,
      LoopChainResourceState<MarketNewPairsPage>
    >(MarketNewPairsController.new);

/// `smart-money` · always an unavailable projection in this step.
final class MarketSmartMoneyController
    extends LoopChainReadController<LoopUnavailable> {
  @override
  LoopChainGatewayMode watchMode() => _marketMode(ref);

  @override
  Future<LoopUnavailable> fetch() =>
      ref.read(marketReadGatewayProvider).loadSmartMoney();
}

final marketSmartMoneyControllerProvider =
    NotifierProvider.autoDispose<
      MarketSmartMoneyController,
      LoopChainResourceState<LoopUnavailable>
    >(MarketSmartMoneyController.new);
