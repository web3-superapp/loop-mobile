import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';

/// 「每周最佳交易」 (decision 0176, loop-api 0142): one (wallet, token) pair
/// that realised a profit on the curve in the last seven days.
@immutable
final class MemeBestTrade {
  const MemeBestTrade({
    required this.rank,
    required this.publicProfileId,
    required this.loopId,
    required this.alias,
    required this.avatarRef,
    required this.memeTokenId,
    required this.symbol,
    required this.logoUrl,
    required this.realizedUsd1,
  });

  final int rank;

  /// The public profile id, never the internal account id.
  final String publicProfileId;
  final String loopId;
  final String? alias;

  /// The stored `avatar:` reference, rendered like the public profile's.
  final String? avatarRef;
  final String memeTokenId;
  final String symbol;

  /// The address this build loads the token picture from, or `null`.
  final String? logoUrl;

  /// Always positive: the server lists profits only.
  final Decimal realizedUsd1;

  /// The name a card shows: the alias, else the LOOP ID.
  String get displayName {
    final value = alias?.trim();
    return value == null || value.isEmpty ? loopId : value;
  }
}

/// `GET /v2/meme/best-trades?window=7d`: at most ten rows, best first.
@immutable
final class MemeBestTradesBoard {
  MemeBestTradesBoard({
    required List<MemeBestTrade> items,
    required this.observedAt,
  }) : items = List<MemeBestTrade>.unmodifiable(items);

  /// The most the server returns and the most the strip draws.
  static const int limit = 10;

  final List<MemeBestTrade> items;
  final DateTime observedAt;
}

/// Feature-facing port for the best-trades board. No transport type and no
/// route literal crosses it.
abstract interface class MemeBestTradesGateway {
  LoopChainGatewayMode get mode;

  Future<MemeBestTradesBoard> loadWeekly();
}

/// Production default: unavailable, so the strip is simply not drawn.
final class UnavailableMemeBestTradesGateway implements MemeBestTradesGateway {
  const UnavailableMemeBestTradesGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<MemeBestTradesBoard> loadWeekly() => Future<MemeBestTradesBoard>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

/// Overridden by the composition root with the authenticated V2 adapter.
final memeBestTradesGatewayProvider = Provider<MemeBestTradesGateway>(
  (ref) => const UnavailableMemeBestTradesGateway(),
);

/// How old the board may be before a pull on the list re-reads it too. The
/// server itself recomputes it every five minutes.
const Duration memeBestTradesRefreshFloor = Duration(seconds: 60);

/// 每周最佳交易 · the board, read once and kept while the Tab lives.
final class MemeBestTradesController
    extends LoopChainReadController<MemeBestTradesBoard> {
  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(memeBestTradesGatewayProvider.select((g) => g.mode));

  @override
  Future<MemeBestTradesBoard> fetch() =>
      ref.read(memeBestTradesGatewayProvider).loadWeekly();

  /// The list was pulled: the board follows when its answer is at least
  /// [memeBestTradesRefreshFloor] old (or there is none).
  Future<void> refreshWithList(DateTime now) {
    final readAt = valueObservedAt;
    if (readAt != null &&
        state.value != null &&
        now.difference(readAt) < memeBestTradesRefreshFloor) {
      return Future<void>.value();
    }
    return reload();
  }
}

final memeBestTradesControllerProvider =
    NotifierProvider.autoDispose<
      MemeBestTradesController,
      LoopChainResourceState<MemeBestTradesBoard>
    >(MemeBestTradesController.new);
