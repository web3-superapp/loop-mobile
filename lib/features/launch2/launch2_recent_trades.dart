import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';

/// One official-pool swap anyone made (S285 · decision 0240; loop-api S280
/// `GET …/pool/recent-trades`). The trader is masked by the server
/// (`0x1234…abcd`) and is `null` for a swap no LOOP route can attribute.
@immutable
final class Launch2PublicPoolTrade {
  const Launch2PublicPoolTrade({
    required this.txHash,
    required this.blockNumber,
    required this.at,
    required this.side,
    required this.memeAmount,
    required this.usd1Amount,
    required this.priceUsd1,
    this.wallet,
  });

  final String txHash;
  final BigInt blockNumber;
  final DateTime at;
  final Launch2Side side;
  final Decimal memeAmount;

  /// Paid for a buy; received (after a USD1 tax) for a sell.
  final Decimal usd1Amount;

  /// The pool price after the swap.
  final Decimal priceUsd1;

  /// The server's masked trader, or `null` (anonymous).
  final String? wallet;
}

/// `GET /v2/launch2/instances/{id}/pool/recent-trades` (newest first).
/// Before graduation the server answers an empty list.
@immutable
final class Launch2PublicPoolTrades {
  const Launch2PublicPoolTrades({
    required this.instanceId,
    required this.items,
    this.observedAt,
  });

  final String instanceId;
  final List<Launch2PublicPoolTrade> items;

  /// When the server read its index.
  final DateTime? observedAt;
}

/// How many public pool trades the project page asks for (the route allows
/// 1–50).
const int launch2RecentPoolTradesLimit = 20;

/// Feature-facing port for the public official-pool trades (decision 0240).
/// No transport type and no route literal crosses it; every failure is a
/// [LoopChainException].
abstract interface class Launch2RecentPoolTradesGateway {
  LoopChainGatewayMode get mode;

  Future<Launch2PublicPoolTrades> loadRecentPoolTrades(
    String instanceId, {
    int limit = launch2RecentPoolTradesLimit,
  });
}

/// Production default: fails closed with `unavailable`. No fixture ever
/// replaces a missing trade.
final class UnavailableLaunch2RecentPoolTradesGateway
    implements Launch2RecentPoolTradesGateway {
  const UnavailableLaunch2RecentPoolTradesGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<Launch2PublicPoolTrades> loadRecentPoolTrades(
    String instanceId, {
    int limit = launch2RecentPoolTradesLimit,
  }) => Future<Launch2PublicPoolTrades>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

/// Overridden by the composition root with the V2 adapter.
final launch2RecentPoolTradesGatewayProvider =
    Provider<Launch2RecentPoolTradesGateway>(
      (ref) => const UnavailableLaunch2RecentPoolTradesGateway(),
    );

/// 成交 tab after graduation: the pool's latest public trades.
final class Launch2RecentPoolTradesController
    extends LoopChainReadController<Launch2PublicPoolTrades> {
  Launch2RecentPoolTradesController(this.instanceId);

  final String instanceId;

  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() => ref.watch(
    launch2RecentPoolTradesGatewayProvider.select((gateway) => gateway.mode),
  );

  @override
  Future<Launch2PublicPoolTrades> fetch() => ref
      .read(launch2RecentPoolTradesGatewayProvider)
      .loadRecentPoolTrades(instanceId);
}

final launch2RecentPoolTradesControllerProvider = NotifierProvider.autoDispose
    .family<
      Launch2RecentPoolTradesController,
      LoopChainResourceState<Launch2PublicPoolTrades>,
      String
    >(Launch2RecentPoolTradesController.new);
