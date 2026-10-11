import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders for the official-pool half of `launch2` (loop-api S146,
/// client decision 0145): the detail's `pool` object, `GET …/pool/quote` and
/// `POST …/pool/trade/prepare`. Same rules as [LoopV2Launch2Codec]: every
/// object is `additionalProperties: false` with every key required.
abstract final class LoopV2Launch2PoolCodec {
  static const summaryKeys = <String>{
    'poolId',
    'router',
    'tradeCount',
    'buyCount',
    'sellCount',
    'buyVolumeUsd1',
    'sellVolumeUsd1',
    'volume24hUsd1',
    'taxUsd1',
    'taxMeme',
    'lastPriceUsd1',
    'lastTradeAt',
  };

  static const quoteKeys = <String>{
    'instanceId',
    'walletId',
    'venue',
    'side',
    'mode',
    'stage',
    'requestedAmount',
    'amountIn',
    'maxIn',
    'expectedOut',
    'minOut',
    'slippageBps',
    'taxBps',
    'taxAmount',
    'taxToken',
    'taxUsd1',
    'priceBeforeUsd1',
    'averagePriceUsd1',
    'balance',
    'exceedsBalance',
    'router',
    'poolId',
    'poolKey',
    'zeroForOne',
    'deadline',
    'expiresAt',
    'quotedAt',
    'quotedAtBlock',
    'basis',
  };

  static const poolKeyKeys = <String>{
    'currency0',
    'currency1',
    'fee',
    'tickSpacing',
    'hooks',
  };

  static Never _invalid() => LoopV2Launch2Codec.invalid();

  /// The detail's `pool`: `null` before graduation (or from a server before
  /// S146, which omits the key).
  static Launch2PoolSummary? summary(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, summaryKeys);
    return Launch2PoolSummary(
      poolId: LoopV2Launch2Codec.hash(map, 'poolId'),
      router: map['router'] == null
          ? null
          : LoopV2Launch2Codec.anyCaseAddress(map, 'router'),
      tradeCount: LoopV2Launch2Codec.integer(map, 'tradeCount'),
      buyCount: LoopV2Launch2Codec.integer(map, 'buyCount'),
      sellCount: LoopV2Launch2Codec.integer(map, 'sellCount'),
      buyVolumeUsd1: LoopV2Launch2Codec.amount(map, 'buyVolumeUsd1'),
      sellVolumeUsd1: LoopV2Launch2Codec.amount(map, 'sellVolumeUsd1'),
      volume24hUsd1: LoopV2Launch2Codec.amount(map, 'volume24hUsd1'),
      taxUsd1: LoopV2Launch2Codec.amount(map, 'taxUsd1'),
      taxMeme: LoopV2Launch2Codec.amount(map, 'taxMeme'),
      lastPriceUsd1: map['lastPriceUsd1'] == null
          ? null
          : LoopV2Launch2Codec.amount(map, 'lastPriceUsd1'),
      lastTradeAt: LoopV2ChainCodec.optionalTimestamp(map, 'lastTradeAt'),
    );
  }

  /// One `quote` object, checked against what was asked.
  static Launch2PoolQuote quoteBody(
    Object? raw, {
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required String walletId,
  }) {
    final map = LoopV2Contract.strictMap(raw, quoteKeys);
    final rawSide = map['side'];
    final rawMode = map['mode'];
    final parsedSide = rawSide is String ? Launch2Side.tryParse(rawSide) : null;
    final parsedMode = rawMode is String
        ? Launch2PoolMode.tryParse(rawMode)
        : null;
    if (parsedSide != side ||
        parsedMode != mode ||
        map['venue'] != 'official_pool' ||
        map['stage'] != 'graduated' ||
        LoopV2Launch2Codec.uuid(map, 'instanceId') != instanceId ||
        LoopV2Launch2Codec.uuid(map, 'walletId') != walletId) {
      _invalid();
    }
    final rawTax = map['taxToken'];
    final taxToken = rawTax is String
        ? Launch2PoolTaxToken.tryParse(rawTax)
        : null;
    // The tax is taken from the output token: MEME on a buy, USD1 on a sell.
    if (taxToken == null ||
        taxToken !=
            (side == Launch2Side.buy
                ? Launch2PoolTaxToken.meme
                : Launch2PoolTaxToken.usd1)) {
      _invalid();
    }
    final balance = LoopV2Contract.strictMap(map['balance'], const <String>{
      'usd1',
      'meme',
    });
    final poolKey = LoopV2Contract.strictMap(map['poolKey'], poolKeyKeys);
    for (final key in const <String>['currency0', 'currency1', 'hooks']) {
      LoopV2Launch2Codec.anyCaseAddress(poolKey, key);
    }
    LoopV2ChainCodec.requireInt(poolKey, 'fee', maximum: 1000000);
    LoopV2ChainCodec.requireInt(poolKey, 'tickSpacing', maximum: 32767);
    final basis = LoopV2Contract.strictMap(map['basis'], const <String>{
      'blockNumber',
      'blockHash',
    });
    LoopV2Launch2Codec.hash(basis, 'blockHash');
    LoopV2Launch2Codec.integer(basis, 'blockNumber');
    final amountIn = LoopV2Launch2Codec.amount(map, 'amountIn');
    final maxIn = LoopV2Launch2Codec.amount(map, 'maxIn');
    final expectedOut = LoopV2Launch2Codec.amount(map, 'expectedOut');
    final minOut = LoopV2Launch2Codec.amount(map, 'minOut');
    // The slippage bound points the safe way.
    if (maxIn < amountIn || minOut > expectedOut) _invalid();
    return Launch2PoolQuote(
      instanceId: instanceId,
      walletId: walletId,
      side: side,
      mode: mode,
      requestedAmount: LoopV2Launch2Codec.amount(map, 'requestedAmount'),
      amountIn: amountIn,
      maxIn: maxIn,
      expectedOut: expectedOut,
      minOut: minOut,
      slippageBps: LoopV2ChainCodec.requireInt(
        map,
        'slippageBps',
        maximum: 5000,
      ),
      taxBps: LoopV2Launch2Codec.bps(map, 'taxBps'),
      taxAmount: LoopV2Launch2Codec.amount(map, 'taxAmount'),
      taxToken: taxToken,
      taxUsd1: LoopV2Launch2Codec.amount(map, 'taxUsd1'),
      priceBeforeUsd1: LoopV2Launch2Codec.amount(map, 'priceBeforeUsd1'),
      averagePriceUsd1: LoopV2Launch2Codec.amount(map, 'averagePriceUsd1'),
      balanceUsd1: LoopV2Launch2Codec.amount(balance, 'usd1'),
      balanceMeme: LoopV2Launch2Codec.amount(balance, 'meme'),
      exceedsBalance: LoopV2ChainCodec.requireBool(map, 'exceedsBalance'),
      router: LoopV2Launch2Codec.anyCaseAddress(map, 'router'),
      poolId: LoopV2Launch2Codec.hash(map, 'poolId'),
      zeroForOne: LoopV2ChainCodec.requireBool(map, 'zeroForOne'),
      deadline: LoopV2ChainCodec.requireTimestamp(map, 'deadline'),
      expiresAt: LoopV2ChainCodec.requireTimestamp(map, 'expiresAt'),
      quotedAt: LoopV2ChainCodec.requireTimestamp(map, 'quotedAt'),
      quotedAtBlock: LoopV2Launch2Codec.integer(map, 'quotedAtBlock'),
    );
  }

  /// `GET …/pool/quote`.
  static Launch2PoolQuote quote(
    Object? raw, {
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required String walletId,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'quote',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    return quoteBody(
      root['quote'],
      instanceId: instanceId,
      side: side,
      mode: mode,
      walletId: walletId,
    );
  }

  /// `POST …/pool/trade/prepare`: the intent must be for this instance,
  /// wallet and side, sent to the quote's router; any approval names the
  /// router as spender (the intent codec already ties it to the target).
  static Launch2PoolPrepared prepared(
    Object? raw, {
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required String walletId,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'launch2Intent',
      'quote',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final quote = quoteBody(
      root['quote'],
      instanceId: instanceId,
      side: side,
      mode: mode,
      walletId: walletId,
    );
    final intent = LoopV2Launch2Codec.intentBody(
      root['launch2Intent'],
      venue: Launch2Venue.officialPool,
      taxBps: quote.taxBps,
      taxMeme: quote.taxToken == Launch2PoolTaxToken.meme
          ? quote.taxAmount
          : null,
    );
    final kind = side == Launch2Side.buy
        ? Launch2IntentKind.buy
        : Launch2IntentKind.sell;
    if (intent.instanceId != instanceId ||
        intent.walletId != walletId ||
        intent.kind != kind ||
        intent.contractAddress != quote.router) {
      _invalid();
    }
    return Launch2PoolPrepared(intent: intent, quote: quote);
  }

  // -------------------------------------------------------------------------
  // the wallet's own pool trades (decision 0148, loop-api S150)
  // -------------------------------------------------------------------------

  static const tradesKeys = <String>{
    'instanceId',
    'walletId',
    'poolTradeCount',
    'lastPoolTradeAt',
    'trades',
    'contractVersion',
  };

  static const tradeKeys = <String>{
    'poolTradeId',
    'side',
    'inputToken',
    'outputToken',
    'amountIn',
    'amountOut',
    'usd1Amount',
    'memeAmount',
    'taxAmount',
    'taxToken',
    'priceUsd1',
    'recipientAddress',
    'tradedAt',
    'transactionHash',
    'logIndex',
    'blockNumber',
  };

  /// `GET …/pool/trades`: must be for the instance and wallet asked about.
  static Launch2PoolTrades trades(
    Object? raw, {
    required String instanceId,
    required String walletId,
  }) {
    final root = LoopV2Contract.strictMap(raw, tradesKeys);
    LoopV2ChainCodec.requireContractVersion(root);
    if (LoopV2Launch2Codec.uuid(root, 'instanceId') != instanceId ||
        LoopV2Launch2Codec.uuid(root, 'walletId') != walletId) {
      _invalid();
    }
    final items = LoopV2ChainCodec.requireList(root['trades'], maximum: 50);
    return Launch2PoolTrades(
      instanceId: instanceId,
      walletId: walletId,
      poolTradeCount: LoopV2Launch2Codec.integer(root, 'poolTradeCount'),
      lastPoolTradeAt: LoopV2ChainCodec.optionalTimestamp(
        root,
        'lastPoolTradeAt',
      ),
      trades: List<Launch2PoolTrade>.unmodifiable(<Launch2PoolTrade>[
        for (final item in items) _trade(item),
      ]),
    );
  }

  static Launch2PoolTrade _trade(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, tradeKeys);
    final sideText = map['side'];
    final side = switch (sideText) {
      'buy' => Launch2Side.buy,
      'sell' => Launch2Side.sell,
      _ => _invalid(),
    };
    final buy = side == Launch2Side.buy;
    // A buy is USD1 → MEME and is taxed in MEME; a sell the other way.
    if (map['inputToken'] != (buy ? 'usd1' : 'meme') ||
        map['outputToken'] != (buy ? 'meme' : 'usd1')) {
      _invalid();
    }
    final taxText = map['taxToken'];
    final taxToken = taxText is String
        ? Launch2PoolTaxToken.tryParse(taxText)
        : null;
    if (taxToken == null ||
        taxToken !=
            (buy ? Launch2PoolTaxToken.meme : Launch2PoolTaxToken.usd1)) {
      _invalid();
    }
    LoopV2Launch2Codec.anyCaseAddress(map, 'recipientAddress');
    LoopV2ChainCodec.requireInt(map, 'logIndex');
    return Launch2PoolTrade(
      poolTradeId: LoopV2Launch2Codec.uuid(map, 'poolTradeId'),
      side: side,
      amountIn: LoopV2Launch2Codec.amount(map, 'amountIn'),
      amountOut: LoopV2Launch2Codec.amount(map, 'amountOut'),
      usd1Amount: LoopV2Launch2Codec.amount(map, 'usd1Amount'),
      memeAmount: LoopV2Launch2Codec.amount(map, 'memeAmount'),
      taxAmount: LoopV2Launch2Codec.amount(map, 'taxAmount'),
      taxToken: taxToken,
      priceUsd1: LoopV2Launch2Codec.amount(map, 'priceUsd1'),
      tradedAt: LoopV2ChainCodec.requireTimestamp(map, 'tradedAt'),
      transactionHash: LoopV2Launch2Codec.hash(map, 'transactionHash'),
      blockNumber: LoopV2Launch2Codec.integer(map, 'blockNumber'),
    );
  }
}
