import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';

/// Feature-facing port for the `launch2` module (MEME v2, client decision
/// 0139). No transport type, no route literal and no idempotency detail
/// crosses it; every failure is a [LoopChainException] carrying the server's
/// own `detailsSafe.reasonCode` when it named one.
abstract interface class Launch2Gateway {
  LoopChainGatewayMode get mode;

  /// One page of instances. A `503` is unavailable, never an empty list.
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  });

  Future<Launch2InstanceDetail> loadInstance(String instanceId);

  /// Only asked in `priority` / `public` (contract §3.3). [amount] is USD1 in
  /// for a buy (tax included) and MEME in for a sell.
  Future<Launch2Quote> quote({
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
    required String walletId,
  });

  Future<Launch2Intent> prepareNftMint({
    required String instanceId,
    required String walletId,
  });

  /// [amount], [minOut] and [deadline] are the quote's, unchanged.
  Future<Launch2Intent> prepareTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Decimal amount,
    required Decimal minOut,
    required DateTime deadline,
  });

  Future<Launch2BuybackPage> loadBuybacks(String instanceId);

  Future<Launch2Positions> loadPositions();

  /// 外盘 · only a `graduated` instance is quoted (decision 0145). [amount]
  /// is what [mode] fixes: paid for `exactIn`, received for `exactOut`.
  Future<Launch2PoolQuote> poolQuote({
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
    required String walletId,
  });

  /// The router swap as one server intent, any approval of the router
  /// included. [amount] and [slippageBps] are the quote's, unchanged.
  Future<Launch2PoolPrepared> preparePoolTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
  });

  /// Decision 0148: the wallet's own official-pool trades, newest first.
  Future<Launch2PoolTrades> loadPoolTrades({
    required String instanceId,
    required String walletId,
    int limit = launch2PoolTradesShown,
  });
}

/// How many of the wallet's own pool trades the project page shows.
const int launch2PoolTradesShown = 5;

/// Production default: every call fails closed with `unavailable`. No fixture
/// ever replaces a missing MEME v2 fact.
final class UnavailableLaunch2Gateway implements Launch2Gateway {
  const UnavailableLaunch2Gateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) => _unavailable();

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) =>
      _unavailable();

  @override
  Future<Launch2Quote> quote({
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2Intent> prepareNftMint({
    required String instanceId,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2Intent> prepareTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Decimal amount,
    required Decimal minOut,
    required DateTime deadline,
  }) => _unavailable();

  @override
  Future<Launch2BuybackPage> loadBuybacks(String instanceId) => _unavailable();

  @override
  Future<Launch2Positions> loadPositions() => _unavailable();

  @override
  Future<Launch2PoolQuote> poolQuote({
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2PoolPrepared> preparePoolTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
  }) => _unavailable();

  @override
  Future<Launch2PoolTrades> loadPoolTrades({
    required String instanceId,
    required String walletId,
    int limit = launch2PoolTradesShown,
  }) => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final launch2GatewayProvider = Provider<Launch2Gateway>(
  (ref) => const UnavailableLaunch2Gateway(),
);
