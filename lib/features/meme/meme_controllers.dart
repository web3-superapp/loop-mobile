import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';

LoopChainGatewayMode _memeMode(Ref ref) =>
    ref.watch(memeGatewayProvider.select((gateway) => gateway.mode));

/// A read that continues a page at a time as the reader scrolls (v3 需求
/// 6.2 · 4). The rows read so far stay when a later page fails.
abstract base class MemePagedController<T> extends LoopChainReadController<T> {
  bool _appendFailed = false;

  /// The last page request failed; the rows read so far stay.
  bool get appendFailed => _appendFailed;

  String? cursorOf(T value);

  Future<T> fetchAfter(String cursor);

  T append(T current, T next);

  @override
  LoopChainGatewayMode watchMode() => _memeMode(ref);

  Future<T> fetchFirst();

  @override
  Future<T> fetch() {
    _appendFailed = false;
    return fetchFirst();
  }

  /// Reads the page after the rows on screen. A cursor the server no longer
  /// accepts (`400`) sends the list back to its first page.
  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current == null ? null : cursorOf(current);
    if (current == null || cursor == null || state.busy) return;
    _appendFailed = false;
    state = state.working(true);
    try {
      final page = await fetchAfter(cursor);
      if (!ref.mounted) return;
      state = state.working(false).ready(append(current, page));
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
      state = state.working(false).failed(LoopChainFailureKind.readFailed);
    }
  }
}

/// MEME · 发射台 · one chip (`GET /v2/meme/tokens?tab=`).
final class MemeListController extends MemePagedController<MemeTokenPage> {
  MemeListController(this.tab);

  final MemeListTab tab;

  @override
  Future<MemeTokenPage> fetchFirst() =>
      ref.read(memeGatewayProvider).listTokens(tab);

  @override
  Future<MemeTokenPage> fetchAfter(String cursor) =>
      ref.read(memeGatewayProvider).listTokens(tab, cursor: cursor);

  @override
  String? cursorOf(MemeTokenPage value) => value.nextCursor;

  @override
  MemeTokenPage append(MemeTokenPage current, MemeTokenPage next) =>
      current.append(next);
}

final memeListControllerProvider = NotifierProvider.autoDispose
    .family<
      MemeListController,
      LoopChainResourceState<MemeTokenPage>,
      MemeListTab
    >(MemeListController.new);

/// `meme-token` · `GET /v2/meme/tokens/{id}`.
final class MemeTokenController
    extends LoopChainReadController<MemeTokenDetail> {
  MemeTokenController(this.memeTokenId);

  final String memeTokenId;

  /// The page shows what it reads now, not what the last visit read: the
  /// curve moves with every trade.
  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _memeMode(ref);

  @override
  Future<MemeTokenDetail> fetch() =>
      ref.read(memeGatewayProvider).loadToken(memeTokenId);
}

final memeTokenControllerProvider = NotifierProvider.autoDispose
    .family<
      MemeTokenController,
      LoopChainResourceState<MemeTokenDetail>,
      String
    >(MemeTokenController.new);

/// 动态 · `GET /v2/meme/tokens/{id}/trades`, newest first.
final class MemeTradesController extends MemePagedController<MemeTradePage> {
  MemeTradesController(this.memeTokenId);

  final String memeTokenId;

  @override
  bool get retainsAnswer => false;

  @override
  Future<MemeTradePage> fetchFirst() =>
      ref.read(memeGatewayProvider).loadTrades(memeTokenId);

  @override
  Future<MemeTradePage> fetchAfter(String cursor) =>
      ref.read(memeGatewayProvider).loadTrades(memeTokenId, cursor: cursor);

  @override
  String? cursorOf(MemeTradePage value) => value.nextCursor;

  @override
  MemeTradePage append(MemeTradePage current, MemeTradePage next) =>
      current.append(next);
}

final memeTradesControllerProvider = NotifierProvider.autoDispose
    .family<
      MemeTradesController,
      LoopChainResourceState<MemeTradePage>,
      String
    >(MemeTradesController.new);

/// 持有者 · `GET /v2/meme/tokens/{id}/holders`, largest first.
final class MemeHoldersController extends MemePagedController<MemeHolderPage> {
  MemeHoldersController(this.memeTokenId);

  final String memeTokenId;

  @override
  bool get retainsAnswer => false;

  @override
  Future<MemeHolderPage> fetchFirst() =>
      ref.read(memeGatewayProvider).loadHolders(memeTokenId);

  @override
  Future<MemeHolderPage> fetchAfter(String cursor) =>
      ref.read(memeGatewayProvider).loadHolders(memeTokenId, cursor: cursor);

  @override
  String? cursorOf(MemeHolderPage value) => value.nextCursor;

  @override
  MemeHolderPage append(MemeHolderPage current, MemeHolderPage next) =>
      current.append(next);
}

final memeHoldersControllerProvider = NotifierProvider.autoDispose
    .family<
      MemeHoldersController,
      LoopChainResourceState<MemeHolderPage>,
      String
    >(MemeHoldersController.new);

@immutable
final class MemeCandleRequest {
  const MemeCandleRequest({required this.memeTokenId, required this.interval});

  final String memeTokenId;
  final MemeCandleInterval interval;

  @override
  bool operator ==(Object other) =>
      other is MemeCandleRequest &&
      other.memeTokenId == memeTokenId &&
      other.interval == interval;

  @override
  int get hashCode => Object.hash(memeTokenId, interval);
}

/// 图表 · `GET /v2/meme/tokens/{id}/candles?interval=`.
final class MemeCandlesController
    extends LoopChainReadController<MemeCandleSeries> {
  MemeCandlesController(this.request);

  final MemeCandleRequest request;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => _memeMode(ref);

  @override
  Future<MemeCandleSeries> fetch() => ref
      .read(memeGatewayProvider)
      .loadCandles(request.memeTokenId, request.interval);
}

final memeCandlesControllerProvider = NotifierProvider.autoDispose
    .family<
      MemeCandlesController,
      LoopChainResourceState<MemeCandleSeries>,
      MemeCandleRequest
    >(MemeCandlesController.new);

/// How often a page re-reads a token whose state is about to move: an
/// intent waiting for its confirmation, or a full curve waiting for its
/// graduation (contract §8.4, §10).
@immutable
final class MemePolling {
  const MemePolling({
    this.intentInterval = const Duration(seconds: 3),
    this.intentMaxAttempts = 60,
    this.tokenInterval = const Duration(seconds: 5),
  });

  final Duration intentInterval;
  final int intentMaxAttempts;
  final Duration tokenInterval;
}

final memePollingProvider = Provider<MemePolling>((ref) => const MemePolling());
