import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';

// ---------------------------------------------------------------------------
// MEME v2 · the official pool after graduation (client decision 0145,
// loop-api S146 `…/pool/quote` and `…/pool/trade/prepare`)
// ---------------------------------------------------------------------------
//
// A graduated instance trades in its official Uniswap v4 pool through the
// router the server names. The shapes mirror the curve's (decision 0139):
// one quote, one prepared intent, the same signing exit. Amounts are exact
// whole-unit [Decimal]s; nothing is a `double`.

/// Which side of the trade the amount field fixes.
enum Launch2PoolMode {
  /// The reader types what they pay (USD1 for a buy, MEME for a sell).
  exactIn('exactIn'),

  /// The reader types what they receive (MEME for a buy, USD1 for a sell).
  exactOut('exactOut');

  const Launch2PoolMode(this.wireName);

  final String wireName;

  static Launch2PoolMode? tryParse(String value) => switch (value) {
    'exactIn' => exactIn,
    'exactOut' => exactOut,
    _ => null,
  };
}

/// The token a pool tax is taken in: the output side (decision 0145).
enum Launch2PoolTaxToken {
  meme('meme'),
  usd1('usd1');

  const Launch2PoolTaxToken(this.wireName);

  final String wireName;

  static Launch2PoolTaxToken? tryParse(String value) => switch (value) {
    'meme' => meme,
    'usd1' => usd1,
    _ => null,
  };
}

/// `pool` on the instance detail: what the read model indexed from the
/// official pool's swap logs (every caller: the in-App router, the buyback
/// executor, anyone else). `null` before graduation.
@immutable
final class Launch2PoolSummary {
  const Launch2PoolSummary({
    required this.poolId,
    required this.tradeCount,
    required this.buyCount,
    required this.sellCount,
    required this.buyVolumeUsd1,
    required this.sellVolumeUsd1,
    required this.volume24hUsd1,
    required this.taxUsd1,
    required this.taxMeme,
    this.router,
    this.lastPriceUsd1,
    this.lastTradeAt,
    this.userTradeCount,
    this.userBuyVolumeUsd1,
    this.userSellVolumeUsd1,
  });

  final String poolId;

  /// The router the App trades through; `null` when the server has none
  /// configured (the pool quote and prepare are then unavailable).
  final String? router;
  final BigInt tradeCount;
  final BigInt buyCount;
  final BigInt sellCount;
  final Decimal buyVolumeUsd1;
  final Decimal sellVolumeUsd1;
  final Decimal volume24hUsd1;

  /// Pool tax taken so far: USD1 from sells, MEME from buys.
  final Decimal taxUsd1;
  final Decimal taxMeme;

  /// The pool price after the latest indexed swap; `null` before the first.
  final Decimal? lastPriceUsd1;
  final DateTime? lastTradeAt;

  /// loop-api S151 (decision 0127, client decision 0150): the same totals
  /// without the swaps the instance's buyback adapter / executor sent, i.e.
  /// market trades only. All three `null` = a server before S151.
  final BigInt? userTradeCount;
  final Decimal? userBuyVolumeUsd1;
  final Decimal? userSellVolumeUsd1;

  /// Buyback swaps indexed in the pool (`tradeCount - userTradeCount`);
  /// `null` from a server before S151.
  BigInt? get buybackTradeCount {
    final user = userTradeCount;
    return user == null ? null : tradeCount - user;
  }
}

/// `GET /v2/launch2/instances/{id}/pool/quote`.
@immutable
final class Launch2PoolQuote {
  const Launch2PoolQuote({
    required this.instanceId,
    required this.walletId,
    required this.side,
    required this.mode,
    required this.requestedAmount,
    required this.amountIn,
    required this.maxIn,
    required this.expectedOut,
    required this.minOut,
    required this.slippageBps,
    required this.taxBps,
    required this.taxAmount,
    required this.taxToken,
    required this.taxUsd1,
    required this.priceBeforeUsd1,
    required this.averagePriceUsd1,
    required this.balanceUsd1,
    required this.balanceMeme,
    required this.exceedsBalance,
    required this.router,
    required this.poolId,
    required this.zeroForOne,
    required this.deadline,
    required this.expiresAt,
    required this.quotedAt,
    required this.quotedAtBlock,
    this.dynamicTaxBps,
    this.rewardWeight,
  });

  final String instanceId;
  final String walletId;
  final Launch2Side side;
  final Launch2PoolMode mode;

  /// Decision 0157 · a LoopDynamic pool: the dynamic sell tax on top of
  /// [taxBps] when the server could price it (a `POST_SWAP` Hook prices it
  /// after the swap, so it may be absent). `null` from an OfficialTax pool.
  final int? dynamicTaxBps;

  /// Decision 0157 · a LoopDynamic buy: the USD1 weight this buy adds to the
  /// running round. `null` from an OfficialTax pool or without a round.
  final Decimal? rewardWeight;

  /// The typed amount; the prepare body carries it unchanged.
  final Decimal requestedAmount;

  /// What goes in: USD1 for a buy, MEME for a sell (`exactOut`: simulated).
  final Decimal amountIn;

  /// `exactOut`: the most that may go in under the slippage; `exactIn`:
  /// [amountIn].
  final Decimal maxIn;

  /// Net of the 2% pool tax: MEME for a buy, USD1 for a sell.
  final Decimal expectedOut;

  /// `exactIn`: the least that comes out under the slippage; `exactOut`:
  /// [expectedOut].
  final Decimal minOut;
  final int slippageBps;

  /// The official pool's tax (2%), taken from the output token.
  final int taxBps;
  final Decimal taxAmount;
  final Launch2PoolTaxToken taxToken;

  /// [taxAmount] for a sell; `0` for a buy (taxed in MEME).
  final Decimal taxUsd1;
  final Decimal priceBeforeUsd1;
  final Decimal averagePriceUsd1;

  /// The wallet's balances at the quote block.
  final Decimal balanceUsd1;
  final Decimal balanceMeme;

  /// [maxIn] is above the input-token balance: a prepare would be refused.
  final bool exceedsBalance;

  /// The router the swap goes to (and any approval names).
  final String router;
  final String poolId;
  final bool zeroForOne;
  final DateTime deadline;

  /// The quote is good until then (= [deadline]); past it the panel asks
  /// again.
  final DateTime expiresAt;
  final DateTime quotedAt;
  final BigInt quotedAtBlock;

  /// The input token's balance for this side.
  Decimal get inputBalance =>
      side == Launch2Side.buy ? balanceUsd1 : balanceMeme;
}

/// `POST …/pool/trade/prepare`: the curve-shaped intent (approval for the
/// router included) and the quote it was built from.
@immutable
final class Launch2PoolPrepared {
  const Launch2PoolPrepared({required this.intent, required this.quote});

  final Launch2Intent intent;
  final Launch2PoolQuote quote;
}

/// One of the wallet's own official-pool swaps, attributed through the
/// router's `Swap(payer)` (decision 0148, loop-api S150
/// `GET …/pool/trades`). Swaps that did not go through the router (the
/// buyback, other routers) are never in it.
@immutable
final class Launch2PoolTrade {
  const Launch2PoolTrade({
    required this.poolTradeId,
    required this.side,
    required this.amountIn,
    required this.amountOut,
    required this.usd1Amount,
    required this.memeAmount,
    required this.taxAmount,
    required this.taxToken,
    required this.priceUsd1,
    required this.tradedAt,
    required this.transactionHash,
    required this.blockNumber,
  });

  final String poolTradeId;
  final Launch2Side side;

  /// What went in and came out through the router (net of the tax): USD1
  /// in / MEME out for a buy, MEME in / USD1 out for a sell.
  final Decimal amountIn;
  final Decimal amountOut;

  /// The pool side, the output gross of the tax.
  final Decimal usd1Amount;
  final Decimal memeAmount;
  final Decimal taxAmount;
  final Launch2PoolTaxToken taxToken;

  /// The pool price after the swap.
  final Decimal priceUsd1;
  final DateTime tradedAt;
  final String transactionHash;
  final BigInt blockNumber;
}

/// `GET /v2/launch2/instances/{id}/pool/trades?walletId=` (newest first).
@immutable
final class Launch2PoolTrades {
  const Launch2PoolTrades({
    required this.instanceId,
    required this.walletId,
    required this.poolTradeCount,
    required this.trades,
    this.lastPoolTradeAt,
  });

  final String instanceId;
  final String walletId;
  final BigInt poolTradeCount;
  final DateTime? lastPoolTradeAt;
  final List<Launch2PoolTrade> trades;
}
