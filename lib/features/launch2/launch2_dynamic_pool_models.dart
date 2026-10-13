import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// MEME v2 · the LoopDynamic 外盘 Hook kind (client decision 0157, loop-api
// S166 `GET …/dynamic-pool`, `…/dynamic-pool/rewards`,
// `POST …/dynamic-pool/claim/prepare|report`)
// ---------------------------------------------------------------------------
//
// A graduated instance's official pool carries one of two Hooks: the
// original OfficialTaxHook (2% each way, the S146 panel) or a per-project
// LoopHook (2% each way plus a dynamic sell tax while a round is armed, and
// a buy-weighted reward pot per round). The App learns which from one read:
// `dynamic-pool` answering 200 is LoopDynamic, a 404 or a closed capability
// is OfficialTax and the page stays exactly as it was. Amounts are exact
// whole-unit [Decimal]s; on-chain integers are [BigInt]s.

/// `currentDropWad` is a WAD fraction: 10^18 = 100%.
final BigInt launch2Wad = BigInt.from(10).pow(18);

/// When the LoopHook prices the dynamic tax: after the swap moved the price
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

/// `GET /v2/launch2/instances/{id}/dynamic-pool`: the LoopHook's round as
/// the server read it.
@immutable
final class Launch2DynamicPoolState {
  const Launch2DynamicPoolState({
    required this.hookAddress,
    required this.armed,
    required this.currentDropWad,
    required this.pot,
    required this.totalBuyWeight,
    required this.priceTiming,
    required this.baseSellFeePpm,
    required this.routingPolicy,
    this.currentRoundId,
    this.myBuyWeight,
  });

  /// The project's own LoopHook (lower case); a reward claim goes to it.
  final String hookAddress;

  /// A round is running: the price fell more than the trigger within five
  /// minutes, the dynamic sell tax and the buy rewards are on.
  final bool armed;

  /// The running round, `null` while none is armed.
  final BigInt? currentRoundId;

  /// How far the price is below the round's reference, as a WAD fraction.
  final BigInt currentDropWad;

  /// The round's reward pot in USD1.
  final Decimal pot;

  /// Every account's buy weight in the running round (USD1).
  final Decimal totalBuyWeight;

  /// The signed-in account's buy weight in the running round (USD1); `null`
  /// when the server has no account to attribute.
  final Decimal? myBuyWeight;
  final Launch2PriceTiming priceTiming;

  /// The base sell fee in parts per million (20000 = 2%).
  final int baseSellFeePpm;

  /// Which routers the Hook credits (opaque server wording).
  final String routingPolicy;

  /// [currentDropWad] as a percentage, exact (10^16 WAD = 1%).
  Decimal get dropPercent =>
      (Decimal.fromBigInt(currentDropWad) /
              Decimal.fromBigInt(launch2Wad ~/ BigInt.from(100)))
          .toDecimal(scaleOnInfinitePrecision: 4);

  /// [baseSellFeePpm] in basis points.
  int get baseSellFeeBps => baseSellFeePpm ~/ 100;
}

/// Which Hook an instance's official pool carries.
@immutable
sealed class Launch2PoolKind {
  const Launch2PoolKind();
}

/// The original OfficialTaxHook: the S146 panel, unchanged.
final class Launch2OfficialTaxPool extends Launch2PoolKind {
  const Launch2OfficialTaxPool();
}

/// A per-project LoopHook with its round state.
final class Launch2LoopDynamicPool extends Launch2PoolKind {
  const Launch2LoopDynamicPool(this.state);

  final Launch2DynamicPoolState state;
}

/// One reward round of `GET …/dynamic-pool/rewards`.
@immutable
final class Launch2DynamicRound {
  const Launch2DynamicRound({
    required this.roundId,
    required this.startCandle,
    required this.closed,
    required this.myWeight,
    required this.totalWeight,
    required this.claimable,
    required this.alreadyClaimed,
    this.endCandle,
    this.allocation,
    this.claimedAmount,
  });

  final BigInt roundId;

  /// The id of the 5-minute candle that armed the round (the Hook's own
  /// candle counter, loop-api S166 `start_candle`). Never turned into a
  /// clock time on the device.
  final BigInt startCandle;

  /// The green candle that closed it; `null` while the round runs.
  final BigInt? endCandle;
  final bool closed;

  /// What the round's pot pays out in total (USD1); `null` while open.
  final Decimal? allocation;
  final Decimal myWeight;
  final Decimal totalWeight;

  /// What the signed-in account can claim now (USD1).
  final Decimal claimable;

  /// The account claimed this round.
  final bool alreadyClaimed;

  /// What it claimed (USD1), when the server says an amount.
  final Decimal? claimedAmount;

  bool get canClaim => closed && !alreadyClaimed && claimable > Decimal.zero;
}

@immutable
final class Launch2DynamicRewards {
  const Launch2DynamicRewards({required this.rounds});

  /// Newest first, as the server sent them.
  final List<Launch2DynamicRound> rounds;
}

/// `POST …/dynamic-pool/claim/report`: what the server recorded about our
/// broadcast. Never a result — only the rewards read says a round is
/// claimed.
@immutable
final class Launch2DynamicClaimReport {
  const Launch2DynamicClaimReport({
    required this.roundId,
    required this.status,
  });

  final BigInt roundId;

  /// `submitted`, `confirmed` or `failed`.
  final String status;
}
