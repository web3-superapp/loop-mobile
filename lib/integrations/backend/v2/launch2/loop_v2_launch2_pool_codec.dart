import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
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

  /// loop-api S151 (decision 0127): the market-only totals, without the
  /// instance's buyback swaps. Optional as a group (client decision 0150):
  /// all absent = a server before S151; some absent = invalid.
  static const userSummaryKeys = <String>{
    'userTradeCount',
    'userBuyVolumeUsd1',
    'userSellVolumeUsd1',
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

  /// Decision 0159 (§3.12.2): a LoopDynamic pool's quote adds one optional
  /// `dynamic` object; an OfficialTax quote has no such key.
  static const dynamicQuoteKeys = <String>{'dynamic'};

  static const dynamicKeys = <String>{
    'hookKind',
    'hook',
    'priceTiming',
    'baseTaxBps',
    'baseTaxAmount',
    'dynamicTaxBps',
    'dynamicTaxAmount',
    'armed',
    'roundId',
    'rewardWeight',
  };

  /// Decision 0197 (loop-api 0152): `dynamic.baseTaxToken`, the token of
  /// `baseTaxAmount`. A server before S209 omits it: the buy fee is MEME.
  static const dynamicOptionalKeys = <String>{'baseTaxToken'};

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
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      summaryKeys,
      userSummaryKeys,
    );
    final present = userSummaryKeys.where(map.containsKey).length;
    if (present != 0 && present != userSummaryKeys.length) _invalid();
    final tradeCount = LoopV2Launch2Codec.integer(map, 'tradeCount');
    final buyVolume = LoopV2Launch2Codec.amount(map, 'buyVolumeUsd1');
    final sellVolume = LoopV2Launch2Codec.amount(map, 'sellVolumeUsd1');
    final userTradeCount = present == 0
        ? null
        : LoopV2Launch2Codec.integer(map, 'userTradeCount');
    final userBuyVolume = present == 0
        ? null
        : LoopV2Launch2Codec.amount(map, 'userBuyVolumeUsd1');
    final userSellVolume = present == 0
        ? null
        : LoopV2Launch2Codec.amount(map, 'userSellVolumeUsd1');
    if ((userTradeCount != null && userTradeCount > tradeCount) ||
        (userBuyVolume != null && userBuyVolume > buyVolume) ||
        (userSellVolume != null && userSellVolume > sellVolume)) {
      _invalid();
    }
    return Launch2PoolSummary(
      poolId: LoopV2Launch2Codec.hash(map, 'poolId'),
      router: map['router'] == null
          ? null
          : LoopV2Launch2Codec.anyCaseAddress(map, 'router'),
      tradeCount: tradeCount,
      buyCount: LoopV2Launch2Codec.integer(map, 'buyCount'),
      sellCount: LoopV2Launch2Codec.integer(map, 'sellCount'),
      buyVolumeUsd1: buyVolume,
      sellVolumeUsd1: sellVolume,
      volume24hUsd1: LoopV2Launch2Codec.amount(map, 'volume24hUsd1'),
      taxUsd1: LoopV2Launch2Codec.amount(map, 'taxUsd1'),
      taxMeme: LoopV2Launch2Codec.amount(map, 'taxMeme'),
      lastPriceUsd1: map['lastPriceUsd1'] == null
          ? null
          : LoopV2Launch2Codec.amount(map, 'lastPriceUsd1'),
      lastTradeAt: LoopV2ChainCodec.optionalTimestamp(map, 'lastTradeAt'),
      userTradeCount: userTradeCount,
      userBuyVolumeUsd1: userBuyVolume,
      userSellVolumeUsd1: userSellVolume,
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
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      quoteKeys,
      dynamicQuoteKeys,
    );
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
    if (taxToken == null) _invalid();
    final balance = LoopV2Contract.strictMap(map['balance'], const <String>{
      'usd1',
      'meme',
    });
    final poolKey = LoopV2Contract.strictMap(map['poolKey'], poolKeyKeys);
    for (final key in const <String>['currency0', 'currency1', 'hooks']) {
      LoopV2Launch2Codec.anyCaseAddress(poolKey, key);
    }
    final taxBps = LoopV2Launch2Codec.bps(map, 'taxBps');
    final loopDynamic = map.containsKey('dynamic')
        ? _dynamicQuote(
            map['dynamic'],
            side: side,
            mode: mode,
            taxBps: taxBps,
            hooks: LoopV2Launch2Codec.anyCaseAddress(poolKey, 'hooks'),
          )
        : null;
    final taxAmount = LoopV2Launch2Codec.amount(map, 'taxAmount');
    final taxUsd1 = LoopV2Launch2Codec.amount(map, 'taxUsd1');
    // A sell is taxed in USD1. A buy is taxed in MEME from the output —
    // except on an S209 LoopDynamic Hook, whose `dynamic.baseTaxToken` says
    // USD1 from the input (decision 0197); then `taxUsd1` is that fee.
    final buyTaxToken = loopDynamic?.baseTaxToken ?? Launch2PoolTaxToken.meme;
    if (taxToken !=
            (side == Launch2Side.buy
                ? buyTaxToken
                : Launch2PoolTaxToken.usd1) ||
        (side == Launch2Side.buy &&
            taxToken == Launch2PoolTaxToken.usd1 &&
            taxUsd1 != taxAmount)) {
      _invalid();
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
      taxBps: taxBps,
      taxAmount: taxAmount,
      taxToken: taxToken,
      taxUsd1: taxUsd1,
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
      loopDynamic: loopDynamic,
    );
  }

  /// `quote.dynamic`: exactIn only; its base rate is the quote's `taxBps`;
  /// its Hook is the pool key's. A buy pays no dynamic tax, a sell earns no
  /// weight.
  static Launch2PoolDynamicQuote _dynamicQuote(
    Object? raw, {
    required Launch2Side side,
    required Launch2PoolMode mode,
    required int taxBps,
    required String hooks,
  }) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      dynamicKeys,
      dynamicOptionalKeys,
    );
    // Decision 0197: absent = a server before S209 (buy: MEME). A sell is
    // always USD1.
    final Launch2PoolTaxToken baseTaxToken;
    if (map.containsKey('baseTaxToken')) {
      final text = map['baseTaxToken'];
      baseTaxToken =
          (text is String ? Launch2PoolTaxToken.tryParse(text) : null) ??
          _invalid();
    } else {
      baseTaxToken = side == Launch2Side.buy
          ? Launch2PoolTaxToken.meme
          : Launch2PoolTaxToken.usd1;
    }
    if (side == Launch2Side.sell && baseTaxToken != Launch2PoolTaxToken.usd1) {
      _invalid();
    }
    final timingText = map['priceTiming'];
    final timing = timingText is String
        ? Launch2PriceTiming.tryParse(timingText)
        : null;
    final hook = LoopV2Launch2Codec.anyCaseAddress(map, 'hook');
    final baseTaxBps = LoopV2Launch2Codec.bps(map, 'baseTaxBps');
    final dynamicTaxBps = LoopV2Launch2Codec.bps(map, 'dynamicTaxBps');
    final dynamicTaxAmount = LoopV2Launch2Codec.amount(map, 'dynamicTaxAmount');
    final rewardWeight = LoopV2Launch2Codec.amount(map, 'rewardWeight');
    if (map['hookKind'] != 'loopDynamic' ||
        timing == null ||
        mode != Launch2PoolMode.exactIn ||
        hook != hooks ||
        baseTaxBps != taxBps ||
        (side == Launch2Side.buy &&
            (dynamicTaxBps != 0 || dynamicTaxAmount != Decimal.zero)) ||
        (side == Launch2Side.sell && rewardWeight != Decimal.zero)) {
      _invalid();
    }
    return Launch2PoolDynamicQuote(
      hook: hook,
      priceTiming: timing,
      baseTaxBps: baseTaxBps,
      baseTaxAmount: LoopV2Launch2Codec.amount(map, 'baseTaxAmount'),
      baseTaxToken: baseTaxToken,
      dynamicTaxBps: dynamicTaxBps,
      dynamicTaxAmount: dynamicTaxAmount,
      armed: LoopV2ChainCodec.requireBool(map, 'armed'),
      roundId: LoopV2Launch2Codec.optionalInteger(map, 'roundId'),
      rewardWeight: rewardWeight,
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
      dynamicTaxBps: side == Launch2Side.sell
          ? quote.loopDynamic?.dynamicTaxBps
          : null,
      buyTaxUsd1:
          side == Launch2Side.buy && quote.taxToken == Launch2PoolTaxToken.usd1
          ? quote.taxUsd1
          : null,
      dynamicBuyTaxToken: side == Launch2Side.buy
          ? quote.loopDynamic?.baseTaxToken
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
    // A buy is USD1 → MEME, a sell the other way. A sell is taxed in USD1;
    // a buy in MEME, or in USD1 on an S209 LoopDynamic Hook (decision 0197).
    if (map['inputToken'] != (buy ? 'usd1' : 'meme') ||
        map['outputToken'] != (buy ? 'meme' : 'usd1')) {
      _invalid();
    }
    final taxText = map['taxToken'];
    final taxToken = taxText is String
        ? Launch2PoolTaxToken.tryParse(taxText)
        : null;
    if (taxToken == null || (!buy && taxToken != Launch2PoolTaxToken.usd1)) {
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
