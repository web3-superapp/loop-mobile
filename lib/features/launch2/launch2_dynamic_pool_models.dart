import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// MEME v2 · the LoopDynamic 外盘 Hook kind (client decisions 0157 / 0159,
// loop-api `frontend-v2-launch2-api.md` §3.12: `GET …/dynamic-pool`,
// `…/dynamic-pool/rewards`, `POST …/dynamic-pool/claim/prepare|report`)
// ---------------------------------------------------------------------------
//
// A graduated instance's official pool carries one of two Hooks: the
// original OfficialTaxHook (2% each way, the S146 panel) or a per-project
// LoopDynamicHook (2% each way plus a dynamic sell tax while a round is
// armed, and a buy-weighted reward pot per round). `dynamic-pool` answers
// every instance with its `hookKind` (decision 0159): `officialTax` /
// `not_applicable` keeps the page exactly as it was. Amounts are exact
// whole-unit [Decimal]s (the server's 18-decimal strings); on-chain ids are
// [BigInt]s; counts and bps are [int]s.

/// When the Hook prices the dynamic tax: after the swap moved the price
/// (`POST_SWAP`, the 2026-10-13 ruling) or before it.
enum Launch2PriceTiming {
  postSwap('POST_SWAP'),
  preSwap('PRE_SWAP');

  const Launch2PriceTiming(this.wireName);

  final String wireName;

  static Launch2PriceTiming? tryParse(String value) {
    for (final timing in values) {
      if (timing.wireName == value) return timing;
    }
    return null;
  }
}

/// Which routers the Hook accepts (`routingPolicy`). Shown nowhere; kept so
/// a later batch can decide on the wallet Swap without a new codec.
enum Launch2RoutingPolicy {
  loopRouterOnly('loopRouterOnly'),
  open('open');

  const Launch2RoutingPolicy(this.wireName);

  final String wireName;

  static Launch2RoutingPolicy? tryParse(String value) {
    for (final policy in values) {
      if (policy.wireName == value) return policy;
    }
    return null;
  }
}

/// `viewer` of `GET …/dynamic-pool`: the wallet the read was made for.
@immutable
final class Launch2DynamicViewer {
  const Launch2DynamicViewer({
    required this.walletId,
    required this.currentRoundWeightUsd1,
  });

  final String walletId;

  /// This wallet's buy weight in the armed round (USD1).
  final Decimal currentRoundWeightUsd1;
}

/// `summary` of `GET …/dynamic-pool`: the indexed rounds so far.
@immutable
final class Launch2DynamicSummary {
  const Launch2DynamicSummary({
    required this.roundCount,
    required this.closedRoundCount,
    required this.allocatedUsd1,
    required this.claimedUsd1,
    required this.dynamicFeesUsd1,
    required this.baseSellFeesUsd1,
    required this.buyFeesMeme,
  });

  final int roundCount;
  final int closedRoundCount;
  final Decimal allocatedUsd1;
  final Decimal claimedUsd1;
  final Decimal dynamicFeesUsd1;
  final Decimal baseSellFeesUsd1;
  final Decimal buyFeesMeme;
}

/// `GET /v2/launch2/instances/{id}/dynamic-pool` with `status: active`: the
/// bound Hook read at one block.
@immutable
final class Launch2DynamicPoolState {
  const Launch2DynamicPoolState({
    required this.instanceId,
    required this.hook,
    required this.poolId,
    required this.router,
    required this.routerRegistry,
    required this.routingPolicy,
    required this.priceTiming,
    required this.buyTaxBps,
    required this.baseSellTaxBps,
    required this.excludeBuybackFromRewards,
    required this.armed,
    required this.candleId,
    required this.candleSeconds,
    required this.candleEndsAt,
    required this.rollPending,
    required this.currentDropWad,
    required this.currentDropBps,
    required this.potUsd1,
    required this.carryUsd1,
    required this.roundExtraFeesUsd1,
    required this.roundTotalBuyWeightUsd1,
    required this.reservedRewardsUsd1,
    required this.priceUsd1,
    required this.summary,
    required this.basisBlockNumber,
    this.currentRoundId,
    this.viewer,
  });

  final String instanceId;

  /// The project's own LoopDynamicHook (lower case); a reward claim goes to
  /// it and nowhere else.
  final String hook;
  final String poolId;

  /// LoopRouter: the swap and approve target of a LoopDynamic trade.
  final String router;
  final String routerRegistry;
  final Launch2RoutingPolicy routingPolicy;
  final Launch2PriceTiming priceTiming;
  final int buyTaxBps;
  final int baseSellTaxBps;
  final bool excludeBuybackFromRewards;

  /// A round is running: a 5-minute candle closed more than 10% down; the
  /// dynamic sell tax and the buy rewards are on.
  final bool armed;

  /// The armed round, `null` while none is armed.
  final BigInt? currentRoundId;
  final BigInt candleId;

  /// Always 300 in this contract.
  final int candleSeconds;

  /// When the current candle ends.
  final DateTime candleEndsAt;

  /// The candle already ended; the next trade, poke or claim closes it.
  final bool rollPending;

  /// `currentDropWad()` as a decimal fraction (0.3 = 30% below the candle
  /// open); 0 while not armed or while a roll is pending.
  final Decimal currentDropWad;

  /// The same drop in basis points; the round card shows this one.
  final int currentDropBps;

  /// Carry plus the armed round's dynamic fees (USD1).
  final Decimal potUsd1;
  final Decimal carryUsd1;
  final Decimal roundExtraFeesUsd1;

  /// Every wallet's buy weight in the armed round (USD1).
  final Decimal roundTotalBuyWeightUsd1;
  final Decimal reservedRewardsUsd1;
  final Decimal priceUsd1;

  /// The wallet the read was made for; `null` without one.
  final Launch2DynamicViewer? viewer;
  final Launch2DynamicSummary summary;
  final BigInt basisBlockNumber;

  /// The viewer's share of the round's weight, as a percentage; `null`
  /// without a viewer or while the round has no weight.
  Decimal? get viewerSharePercent {
    final mine = viewer?.currentRoundWeightUsd1;
    if (mine == null || roundTotalBuyWeightUsd1 <= Decimal.zero) return null;
    return (mine * Decimal.fromInt(100) / roundTotalBuyWeightUsd1).toDecimal(
      scaleOnInfinitePrecision: 4,
    );
  }
}

/// What `dynamic-pool` said about an instance's official pool.
@immutable
sealed class Launch2PoolKind {
  const Launch2PoolKind();
}

/// `hookKind: officialTax` (`status: not_applicable`), or a server that has
/// no `dynamic-pool` route at all (404): the S146 panel, unchanged.
final class Launch2OfficialTaxPool extends Launch2PoolKind {
  const Launch2OfficialTaxPool();
}

/// `hookKind: loopDynamic`, `status: not_graduated`: no Hook bound yet. The
/// curve panel as before; on a page that already reads graduated it is a
/// lag, and the pool panel is not offered until the Hook is read.
final class Launch2LoopDynamicNotGraduated extends Launch2PoolKind {
  const Launch2LoopDynamicNotGraduated();
}

/// `hookKind: loopDynamic`, `status: active`, with its round state.
final class Launch2LoopDynamicPool extends Launch2PoolKind {
  const Launch2LoopDynamicPool(this.state);

  final Launch2DynamicPoolState state;
}

/// A `503` whose `reasonCode` is one of the LoopDynamic ones (§3.12.6):
/// only a LoopDynamic instance gets those, so the page says 「外盘暂不可用」
/// with a retry and never falls back to the OfficialTax panel.
final class Launch2LoopDynamicUnavailable extends Launch2PoolKind {
  const Launch2LoopDynamicUnavailable(this.reasonCode);

  final String reasonCode;
}

/// A round's `status` in `GET …/dynamic-pool/rewards`.
enum Launch2DynamicRoundStatus {
  /// Running; claimable once it closes.
  open('open'),
  claimable('claimable'),

  /// The indexer has this wallet's `RewardClaimed` for the round.
  claimed('claimed'),
  noReward('no_reward');

  const Launch2DynamicRoundStatus(this.wireName);

  final String wireName;

  static Launch2DynamicRoundStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// One round of `GET …/dynamic-pool/rewards` for one wallet.
@immutable
final class Launch2DynamicRound {
  const Launch2DynamicRound({
    required this.roundId,
    required this.status,
    required this.weightUsd1,
    required this.totalBuyWeightUsd1,
    required this.claimableUsd1,
    required this.startCandle,
    required this.activatedAt,
    this.allocationUsd1,
    this.claimedUsd1,
    this.claimTransactionHash,
    this.claimedAt,
    this.endCandle,
    this.closedAt,
  });

  final BigInt roundId;
  final Launch2DynamicRoundStatus status;

  /// This wallet's buy weight in the round (USD1).
  final Decimal weightUsd1;
  final Decimal totalBuyWeightUsd1;

  /// What the round pays out in total (USD1); `null` while it is open.
  final Decimal? allocationUsd1;

  /// What this wallet can claim (USD1); the prepare re-checks on chain.
  final Decimal claimableUsd1;

  /// What this wallet claimed in this round (USD1); `null` while unclaimed.
  final Decimal? claimedUsd1;
  final String? claimTransactionHash;
  final DateTime? claimedAt;

  /// The Hook's own 5-minute candle ids; never turned into clock times.
  final BigInt startCandle;

  /// The green candle that closed it; `null` while the round runs.
  final BigInt? endCandle;
  final DateTime activatedAt;
  final DateTime? closedAt;

  bool get closed => status != Launch2DynamicRoundStatus.open;

  bool get alreadyClaimed => status == Launch2DynamicRoundStatus.claimed;

  bool get canClaim =>
      status == Launch2DynamicRoundStatus.claimable &&
      claimableUsd1 > Decimal.zero;
}

@immutable
final class Launch2DynamicRewards {
  const Launch2DynamicRewards({
    required this.walletId,
    required this.claimableUsd1,
    required this.claimedUsd1,
    required this.rounds,
  });

  final String walletId;

  /// This wallet's claimable total over the listed rounds (USD1).
  final Decimal claimableUsd1;

  /// This wallet's claimed total (USD1).
  final Decimal claimedUsd1;

  /// Rounds where this wallet has weight, newest first, as sent.
  final List<Launch2DynamicRound> rounds;
}

/// `claim` of `POST …/dynamic-pool/claim/prepare`: what the server
/// simulated for the round.
@immutable
final class Launch2DynamicClaim {
  const Launch2DynamicClaim({
    required this.roundId,
    required this.hook,
    required this.claimableUsd1,
  });

  final BigInt roundId;

  /// The Hook the claim is sent to (lower case).
  final String hook;
  final Decimal claimableUsd1;
}

/// `dynamicClaimReport.status`.
enum Launch2DynamicClaimStatus {
  /// The hash is recorded; the indexer has not seen `RewardClaimed` yet.
  submitted('submitted'),

  /// The indexer has the round's `RewardClaimed` for this wallet.
  confirmed('confirmed');

  const Launch2DynamicClaimStatus(this.wireName);

  final String wireName;

  static Launch2DynamicClaimStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// `POST …/dynamic-pool/claim/report`: what the server recorded about our
/// broadcast. `confirmed` comes from the indexed log, never from the report
/// itself.
@immutable
final class Launch2DynamicClaimReport {
  const Launch2DynamicClaimReport({
    required this.intentId,
    required this.roundId,
    required this.transactionHash,
    required this.status,
    required this.reportedAt,
    this.amountUsd1,
    this.claimedAt,
    this.blockNumber,
  });

  final String intentId;
  final BigInt roundId;
  final String transactionHash;
  final Launch2DynamicClaimStatus status;
  final DateTime reportedAt;

  /// What `RewardClaimed` paid (USD1); set once confirmed.
  final Decimal? amountUsd1;
  final DateTime? claimedAt;
  final BigInt? blockNumber;

  bool get confirmed => status == Launch2DynamicClaimStatus.confirmed;
}
