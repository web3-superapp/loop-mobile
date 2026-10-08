import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
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
  String? get snapshotResource => LoopSnapshotResource.marketOverview;

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
  const MarketCandleRequest({
    required this.assetId,
    required this.interval,
    this.limit,
  });

  final String assetId;
  final LoopCandleInterval interval;

  /// How many buckets to ask for (1–300); `null` takes the server's default.
  /// The token chart asks for [chartLimit] so it can be panned and zoomed
  /// without a second read (decision 0118).
  final int? limit;

  /// The most buckets one candle read returns.
  static const int chartLimit = 300;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketCandleRequest &&
          other.assetId == assetId &&
          other.interval == interval &&
          other.limit == limit;

  @override
  int get hashCode => Object.hash(assetId, interval, limit);
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
      .loadCandles(
        request.assetId,
        interval: request.interval,
        limit: request.limit,
      );
}

final marketCandlesControllerProvider = NotifierProvider.autoDispose
    .family<
      MarketCandlesController,
      LoopChainResourceState<MarketCandleSeries>,
      MarketCandleRequest
    >(MarketCandlesController.new);

/// `token-trades` · `…/trades`, read a cursor page at a time.
final class MarketTradesController
    extends LoopChainReadController<MarketTradesPage> {
  MarketTradesController(this.assetId);

  final String assetId;
  bool _appendFailed = false;

  /// The last page request failed; the trades read so far stay.
  bool get appendFailed => _appendFailed;

  @override
  LoopChainGatewayMode watchMode() => _marketMode(ref);

  @override
  Future<MarketTradesPage> fetch() {
    _appendFailed = false;
    return ref.read(marketReadGatewayProvider).loadTrades(assetId);
  }

  /// Reads the page after the trades on screen (decision 0118: lists scroll
  /// on). Does nothing while a page is in flight or when the list is whole.
  Future<void> loadMore() async {
    final current = state.value;
    final block = current?.trades;
    if (current == null || block is! MarketTradesAvailable || state.busy) {
      return;
    }
    final cursor = block.nextCursor;
    if (cursor == null) return;
    _appendFailed = false;
    state = state.working(true);
    try {
      final page = await ref
          .read(marketReadGatewayProvider)
          .loadTrades(assetId, cursor: cursor);
      if (!ref.mounted) return;
      final next = page.trades;
      if (next is! MarketTradesAvailable) {
        // The feed closed between two pages: the rows read so far stay, and
        // the list ends where it is rather than in a retry loop.
        state = state
            .working(false)
            .ready(
              MarketTradesPage(
                assetId: assetId,
                trades: MarketTradesAvailable(
                  source: block.source,
                  items: block.items,
                  nextCursor: null,
                  freshness: block.freshness,
                ),
              ),
            );
        return;
      }
      final held = <String>{for (final trade in block.items) trade.tradeId};
      state = state
          .working(false)
          .ready(
            MarketTradesPage(
              assetId: assetId,
              trades: MarketTradesAvailable(
                source: block.source,
                items: <MarketTrade>[
                  ...block.items,
                  for (final trade in next.items)
                    if (held.add(trade.tradeId)) trade,
                ],
                nextCursor: next.nextCursor,
                freshness: next.freshness,
              ),
            ),
          );
    } on LoopChainException catch (error) {
      if (!ref.mounted) return;
      _appendFailed = true;
      state = state.working(false).failed(error.kind);
    } catch (_) {
      if (!ref.mounted) return;
      _appendFailed = true;
      state = state.working(false).failed(LoopChainFailureKind.unexpected);
    }
  }
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

/// 情报 · 行情 · one category list (decision 0100 / 0118), read a cursor
/// page at a time as the reader scrolls. The server orders it by market cap.
final class MarketCategoryController
    extends LoopChainReadController<MarketCategoryPage> {
  MarketCategoryController(this.category);

  final MarketCategory category;
  bool _appendFailed = false;

  /// The last page request failed; the rows read so far stay.
  bool get appendFailed => _appendFailed;

  @override
  LoopChainGatewayMode watchMode() => _marketMode(ref);

  @override
  Future<MarketCategoryPage> fetch() {
    _appendFailed = false;
    return ref.read(marketReadGatewayProvider).loadCategory(category);
  }

  /// Reads the page after the rows on screen.
  ///
  /// A cursor is bound to the account, the category and the order and lives
  /// ten minutes; one the server refuses (400) sends the list back to its
  /// first page rather than ending it in an error.
  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || state.busy) return;
    _appendFailed = false;
    state = state.working(true);
    try {
      final page = await ref
          .read(marketReadGatewayProvider)
          .loadCategory(category, sort: current.sort, cursor: cursor);
      if (!ref.mounted) return;
      state = state.working(false).ready(current.append(page));
    } on LoopChainException catch (error) {
      if (!ref.mounted) return;
      if (error.kind == LoopChainFailureKind.invalidData) {
        state = state.working(false);
        await reload();
        return;
      }
      _appendFailed = true;
      state = state.working(false).failed(error.kind);
    } catch (_) {
      if (!ref.mounted) return;
      _appendFailed = true;
      state = state.working(false).failed(LoopChainFailureKind.unexpected);
    }
  }
}

final marketCategoryControllerProvider = NotifierProvider.autoDispose
    .family<
      MarketCategoryController,
      LoopChainResourceState<MarketCategoryPage>,
      MarketCategory
    >(MarketCategoryController.new);

/// 情报 · 活动位 · `GET /v2/intel/promotions`.
final class IntelPromotionsController
    extends LoopChainReadController<IntelPromotions> {
  @override
  LoopChainGatewayMode watchMode() => _marketMode(ref);

  @override
  Future<IntelPromotions> fetch() =>
      ref.read(marketReadGatewayProvider).loadPromotions();
}

final intelPromotionsControllerProvider =
    NotifierProvider.autoDispose<
      IntelPromotionsController,
      LoopChainResourceState<IntelPromotions>
    >(IntelPromotionsController.new);
