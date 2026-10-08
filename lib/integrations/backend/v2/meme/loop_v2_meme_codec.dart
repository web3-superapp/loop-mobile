import 'package:decimal/decimal.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders for the `meme` module (loop-api decision 0101,
/// `docs/frontend-v2-meme-api.md`, OpenAPI tag `meme`).
///
/// Every object goes through [LoopV2Contract.strictMap] or
/// [LoopV2Contract.strictMapWithOptional] with the published key set, so an
/// unknown or missing field is an invalid payload rather than a partially
/// trusted projection. Raw amounts become [BigInt], prices [Decimal]; no
/// `double` is involved.
abstract final class LoopV2MemeCodec {
  static final RegExp uuidV4Pattern = LoopV2Contract.uuidV4Pattern;
  static final RegExp bytes32Pattern = RegExp(r'^0x[0-9a-f]{64}$');
  static final RegExp digestPattern = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp hexDataPattern = RegExp(r'^0x([0-9a-f]{2})*$');
  static final RegExp quantityPattern = RegExp(
    r'^0x(0|[1-9a-f][0-9a-f]{0,63})$',
  );
  static final RegExp percentPattern = RegExp(
    r'^-?(0|[1-9][0-9]{0,40})\.[0-9]{2}$',
  );
  static final RegExp priceDecimalPattern = RegExp(
    r'^-?(0|[1-9][0-9]{0,77})(\.[0-9]{1,18})?$',
  );

  /// `/v2/media/{mediaId}.webp`: the only shape an `imageUrl` may carry.
  static final RegExp mediaPathPattern = RegExp(
    r'^/v2/media/([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.webp$',
  );

  static const rowKeys = <String>{
    'memeTokenId',
    'tokenAddress',
    'name',
    'symbol',
    'imageUrl',
    'creator',
    'status',
    'progressBps',
    'priceUsd1',
    'marketCapUsd1',
    'change1hPct',
    'volume24hUsd1',
    'holderCount',
    'tradeCount',
    'createdAt',
    'graduatedAt',
    'pool',
    'priceSource',
  };

  static const detailKeys = <String>{
    ...rowKeys,
    'description',
    'links',
    'metadataHash',
    'salt',
    'predictedAddress',
    'vanity',
    'curve',
    'contract',
    'viewer',
    'graduation',
    'source',
  };

  /// Decision 0102 (operator console): sent together by a server that carries
  /// it; optional so a document from before it still reads.
  static const detailListingKeys = <String>{'listing', 'listingReason'};

  static const intentKeys = <String>{
    'memeIntentId',
    'kind',
    'state',
    'memeTokenId',
    'walletId',
    'chainId',
    'chainReference',
    'contractAddress',
    'tokenAddress',
    'usd1Amount',
    'tokenAmount',
    'expectedOut',
    'minOut',
    'fee',
    'refund',
    'deadline',
    'expiresAt',
    'createdAt',
    'calldata',
    'unsignedTransaction',
    'approval',
    'payloadDigest',
    'snapshotBlockNumber',
    'snapshotBlockHash',
    'transactionHash',
    'reasonCode',
    'simulation',
    'policy',
    'signing',
  };

  static const transactionKeys = <String>{
    'chainId',
    'to',
    'data',
    'value',
    'from',
    'gas',
    'nonce',
    'type',
    'maxFeePerGas',
    'maxPriorityFeePerGas',
    'gasPrice',
  };

  static Never invalid() => LoopV2ChainCodec.invalid();

  // -------------------------------------------------------------------------
  // scalars
  // -------------------------------------------------------------------------

  static BigInt raw(Map<String, Object?> map, String key) =>
      BigInt.parse(LoopV2ChainCodec.requireRawAmount(map, key));

  static BigInt? optionalRaw(Map<String, Object?> map, String key) =>
      map[key] == null ? null : raw(map, key);

  static Decimal price(Map<String, Object?> map, String key) {
    final value = LoopV2ChainCodec.requireString(
      map,
      key,
      pattern: priceDecimalPattern,
      maxLength: 120,
    );
    return Decimal.parse(value);
  }

  static Decimal? optionalPrice(Map<String, Object?> map, String key) =>
      map[key] == null ? null : price(map, key);

  static String address(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: LoopV2ChainCodec.addressPattern,
        maxLength: 42,
      );

  static String? optionalAddress(Map<String, Object?> map, String key) =>
      map[key] == null ? null : address(map, key);

  static String? optionalHash(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.optionalString(
        map,
        key,
        pattern: bytes32Pattern,
        maxLength: 66,
      );

  static String uuid(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: uuidV4Pattern,
        maxLength: 36,
      );

  static String _chainId(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || !loopKnownChainIds.contains(value)) invalid();
    return value;
  }

  static int _chainReference(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value != 56 && value != 97) invalid();
    return value! as int;
  }

  /// Free text a creator typed: bounded, and stripped of the code points that
  /// could reorder or hide the rest of a row.
  static String text(
    Map<String, Object?> map,
    String key, {
    required int maxLength,
    int minLength = 0,
  }) => LoopV2ChainCodec.providerText(
    map,
    key,
    maxLength: maxLength,
    minLength: minLength,
  );

  static String? optionalLink(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String || value.length > 256) invalid();
    final uri = Uri.tryParse(value);
    // Links are stored https-only (contract §7). Anything else is not a link
    // this client will open.
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return value;
  }

  /// The media id inside an `imageUrl`, or `null` when the address is not
  /// one of LOOP's own media paths. The client loads the picture from its own
  /// backend origin, never from the host the payload named.
  static String? imageMediaId(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String || value.length > 512) invalid();
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    return mediaPathPattern.firstMatch(uri.path)?.group(1);
  }

  static MemeAccountRef? account(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'publicProfileId',
      'displayName',
      'avatarRef',
    });
    return MemeAccountRef(
      publicProfileId: LoopV2ChainCodec.requireText(
        map,
        'publicProfileId',
        maxLength: 64,
      ),
      displayName: map['displayName'] == null
          ? null
          : text(map, 'displayName', maxLength: 64),
      avatarRef: LoopV2ChainCodec.optionalText(
        map,
        'avatarRef',
        maxLength: 128,
      ),
    );
  }

  static ({String source, DateTime observedAt}) _loopIndexerSource(
    Object? raw,
  ) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'source',
      'observedAt',
    });
    if (map['source'] != 'loop_indexer') invalid();
    return (
      source: 'loop_indexer',
      observedAt: LoopV2ChainCodec.requireTimestamp(map, 'observedAt'),
    );
  }

  // -------------------------------------------------------------------------
  // rows and pages
  // -------------------------------------------------------------------------

  static MemeTokenRow _row(
    Map<String, Object?> map, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final rawStatus = map['status'];
    final status = rawStatus is String
        ? MemeTokenStatus.tryParse(rawStatus)
        : null;
    if (status == null) invalid();
    MemePriceProvenance? provenance;
    final rawSource = map['priceSource'];
    if (rawSource != null) {
      final source = LoopV2Contract.strictMap(rawSource, const <String>{
        'source',
        'observedAt',
      });
      final kind = source['source'];
      final parsed = kind is String ? MemePriceSource.tryParse(kind) : null;
      if (parsed == null) invalid();
      provenance = MemePriceProvenance(
        source: parsed,
        observedAt: LoopV2ChainCodec.requireTimestamp(source, 'observedAt'),
      );
    }
    String? unavailableReason;
    if (map.containsKey('quoteUnavailable')) {
      final block = LoopV2Contract.strictMap(
        map['quoteUnavailable'],
        const <String>{'reasonCode'},
      );
      unavailableReason = LoopV2ChainCodec.requireReasonCode(
        block,
        'reasonCode',
      );
    }
    final priceUsd1 = optionalPrice(map, 'priceUsd1');
    final marketCapUsd1 = optionalPrice(map, 'marketCapUsd1');
    // A price that is absent says why; a price that is present says where it
    // came from. Anything else is not a figure this client may render.
    if (priceUsd1 == null && unavailableReason == null) {
      unavailableReason = 'MEME_QUOTE_NOT_REPORTED';
    }
    if (priceUsd1 != null && provenance == null) invalid();
    final mediaId = imageMediaId(map, 'imageUrl');
    final change = map['change1hPct'] == null
        ? null
        : Decimal.parse(
            LoopV2ChainCodec.requireString(
              map,
              'change1hPct',
              pattern: percentPattern,
              maxLength: 48,
            ),
          );
    return MemeTokenRow(
      memeTokenId: uuid(map, 'memeTokenId'),
      tokenAddress: optionalAddress(map, 'tokenAddress'),
      name: text(map, 'name', minLength: 1, maxLength: 64),
      symbol: text(map, 'symbol', minLength: 1, maxLength: 16),
      imageUrl: mediaId == null ? null : mediaUrl(mediaId),
      creator: account(map['creator']),
      status: status,
      progressBps: LoopV2ChainCodec.requireInt(
        map,
        'progressBps',
        maximum: 10000,
      ),
      priceUsd1: priceUsd1,
      marketCapUsd1: marketCapUsd1,
      change1hPct: change,
      volume24hUsd1: price(map, 'volume24hUsd1'),
      holderCount: LoopV2ChainCodec.requireInt(map, 'holderCount'),
      tradeCount: LoopV2ChainCodec.requireInt(map, 'tradeCount'),
      createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
      graduatedAt: LoopV2ChainCodec.optionalTimestamp(map, 'graduatedAt'),
      pool: optionalAddress(map, 'pool'),
      priceSource: provenance,
      quoteUnavailableReason: priceUsd1 == null ? unavailableReason : null,
    );
  }

  static MemeTokenRow row(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) => _row(
    LoopV2Contract.strictMapWithOptional(raw, rowKeys, const <String>{
      'quoteUnavailable',
    }),
    mediaUrl: mediaUrl,
  );

  static MemeTokenPage tokenPage(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'tab',
      'items',
      'nextCursor',
      'rules',
      'observedAt',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final rawTab = root['tab'];
    final tab = rawTab is String ? MemeListTab.tryParse(rawTab) : null;
    if (tab == null) invalid();
    final rules = LoopV2Contract.strictMap(root['rules'], const <String>{
      'configVersion',
      'effectiveAt',
      'graduatingProgressBps',
      'hotWindowSeconds',
    });
    LoopV2ChainCodec.requireText(rules, 'configVersion', maxLength: 64);
    LoopV2ChainCodec.requireTimestamp(rules, 'effectiveAt');
    LoopV2ChainCodec.requireInt(rules, 'graduatingProgressBps');
    LoopV2ChainCodec.requireInt(rules, 'hotWindowSeconds');
    return MemeTokenPage(
      tab: tab,
      items: List<MemeTokenRow>.unmodifiable(<MemeTokenRow>[
        for (final item in LoopV2ChainCodec.requireList(
          root['items'],
          maximum: 50,
        ))
          row(item, mediaUrl: mediaUrl),
      ]),
      nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
      observedAt: LoopV2ChainCodec.requireTimestamp(root, 'observedAt'),
    );
  }

  // -------------------------------------------------------------------------
  // detail
  // -------------------------------------------------------------------------

  static MemeCurve curve(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'vUsd1',
      'vToken',
      'realUsd1',
      'sold',
      'saleSupply',
      'poolSupply',
      'totalSupply',
      'graduationUsd1Estimate',
      'tradeFeeBps',
      'walletCapTokens',
      'minBuyUsd1',
    });
    return MemeCurve(
      vUsd1: LoopV2MemeCodec.raw(map, 'vUsd1'),
      vToken: LoopV2MemeCodec.raw(map, 'vToken'),
      realUsd1: LoopV2MemeCodec.raw(map, 'realUsd1'),
      sold: LoopV2MemeCodec.raw(map, 'sold'),
      saleSupply: LoopV2MemeCodec.raw(map, 'saleSupply'),
      poolSupply: LoopV2MemeCodec.raw(map, 'poolSupply'),
      totalSupply: LoopV2MemeCodec.raw(map, 'totalSupply'),
      graduationUsd1Estimate: LoopV2MemeCodec.raw(
        map,
        'graduationUsd1Estimate',
      ),
      tradeFeeBps: LoopV2ChainCodec.requireInt(
        map,
        'tradeFeeBps',
        maximum: 10000,
      ),
      walletCapTokens: LoopV2MemeCodec.raw(map, 'walletCapTokens'),
      minBuyUsd1: LoopV2MemeCodec.raw(map, 'minBuyUsd1'),
    );
  }

  static MemeTokenDetail detail(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'memeToken',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final map = LoopV2Contract.strictMapWithOptional(
      root['memeToken'],
      detailKeys,
      const <String>{
        'quoteUnavailable',
        'viewerUnavailable',
        ...detailListingKeys,
      },
    );
    final links = LoopV2Contract.strictMap(map['links'], const <String>{
      'twitter',
      'telegram',
      'website',
    });
    final contract = LoopV2Contract.strictMap(map['contract'], const <String>{
      'address',
      'version',
      'chainId',
      'chainReference',
      'explorerUrl',
    });
    final explorer = contract['explorerUrl'];
    String? explorerUrl;
    if (explorer != null) {
      if (explorer is! String || explorer.length > 512) invalid();
      final uri = Uri.tryParse(explorer);
      explorerUrl = uri != null && uri.scheme == 'https' ? explorer : null;
    }
    MemeViewer? viewer;
    if (map['viewer'] != null) {
      final v = LoopV2Contract.strictMap(map['viewer'], const <String>{
        'walletId',
        'balance',
        'usd1Balance',
        'walletCapRemaining',
        'allowanceUsd1',
        'allowanceToken',
      });
      viewer = MemeViewer(
        walletId: uuid(v, 'walletId'),
        balance: LoopV2MemeCodec.raw(v, 'balance'),
        usd1Balance: LoopV2MemeCodec.raw(v, 'usd1Balance'),
        walletCapRemaining: optionalRaw(v, 'walletCapRemaining'),
        allowanceUsd1: LoopV2MemeCodec.raw(v, 'allowanceUsd1'),
        allowanceToken: LoopV2MemeCodec.raw(v, 'allowanceToken'),
      );
    }
    String? viewerUnavailable;
    if (map.containsKey('viewerUnavailable')) {
      if (viewer != null) invalid();
      final block = LoopV2Contract.strictMap(
        map['viewerUnavailable'],
        const <String>{'reasonCode'},
      );
      viewerUnavailable = LoopV2ChainCodec.requireReasonCode(
        block,
        'reasonCode',
      );
    }
    MemeGraduation? graduation;
    if (map['graduation'] != null) {
      final g = LoopV2Contract.strictMap(map['graduation'], const <String>{
        'pool',
        'lpBurnTx',
        'lpTokenId',
        'usd1ToPool',
        'tokensToPool',
        'feeUsd1',
        'at',
        'residual',
      });
      BigInt? residualUsd1;
      BigInt? residualTokens;
      if (g['residual'] != null) {
        final r = LoopV2Contract.strictMap(g['residual'], const <String>{
          'usd1Left',
          'tokensLeft',
        });
        residualUsd1 = LoopV2MemeCodec.raw(r, 'usd1Left');
        residualTokens = LoopV2MemeCodec.raw(r, 'tokensLeft');
      }
      graduation = MemeGraduation(
        at: LoopV2ChainCodec.requireTimestamp(g, 'at'),
        pool: optionalAddress(g, 'pool'),
        lpBurnTx: optionalHash(g, 'lpBurnTx'),
        lpTokenId: g['lpTokenId'] == null
            ? null
            : LoopV2ChainCodec.requireRawAmount(g, 'lpTokenId'),
        usd1ToPool: optionalRaw(g, 'usd1ToPool'),
        tokensToPool: optionalRaw(g, 'tokensToPool'),
        feeUsd1: optionalRaw(g, 'feeUsd1'),
        residualUsd1: residualUsd1,
        residualTokens: residualTokens,
      );
    }
    final vanity = map['vanity'];
    if (vanity is! bool) invalid();
    final description = map['description'];
    if (description is! String || description.length > 2000) invalid();
    // Decision 0102: both keys are sent together; `hidden` carries a reason,
    // `listed` carries null. A document from before 0102 carries neither.
    var listing = MemeListing.listed;
    MemeListingReason? listingReason;
    if (map.containsKey('listing') || map.containsKey('listingReason')) {
      final rawListing = map['listing'];
      final parsed = rawListing is String
          ? MemeListing.tryParse(rawListing)
          : null;
      if (parsed == null) invalid();
      listing = parsed;
      final rawReason = map['listingReason'];
      if ((listing == MemeListing.hidden) != (rawReason != null)) invalid();
      if (rawReason != null) {
        final r = LoopV2Contract.strictMap(rawReason, const <String>{
          'reasonCode',
          'reasonText',
        });
        final code = r['reasonCode'];
        final text = r['reasonText'];
        if (code != null &&
            (code is! String ||
                !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(code))) {
          invalid();
        }
        if (text != null &&
            (text is! String || text.isEmpty || text.length > 280)) {
          invalid();
        }
        listingReason = MemeListingReason(
          reasonCode: code as String?,
          reasonText: text == null
              ? null
              : LoopV2ChainCodec.sanitizeProviderText(text as String),
        );
      }
    }
    return MemeTokenDetail(
      row: _row(map, mediaUrl: mediaUrl),
      listing: listing,
      listingReason: listingReason,
      description: LoopV2ChainCodec.sanitizeProviderText(description),
      links: MemeLinks(
        twitter: optionalLink(links, 'twitter'),
        telegram: optionalLink(links, 'telegram'),
        website: optionalLink(links, 'website'),
      ),
      metadataHash: LoopV2ChainCodec.requireString(
        map,
        'metadataHash',
        pattern: bytes32Pattern,
        maxLength: 66,
      ),
      salt: optionalHash(map, 'salt'),
      predictedAddress: optionalAddress(map, 'predictedAddress'),
      vanity: vanity,
      curve: curve(map['curve']),
      contract: MemeContractFacts(
        address: address(contract, 'address'),
        version: LoopV2ChainCodec.requireText(
          contract,
          'version',
          maxLength: 32,
        ),
        chainId: _chainId(contract, 'chainId'),
        chainReference: _chainReference(contract, 'chainReference'),
        explorerUrl: explorerUrl,
      ),
      viewer: viewer,
      viewerUnavailableReason: viewerUnavailable,
      graduation: graduation,
      observedAt: _loopIndexerSource(map['source']).observedAt,
    );
  }

  // -------------------------------------------------------------------------
  // trades, candles, holders
  // -------------------------------------------------------------------------

  static MemeTradePage tradePage(Object? raw, {required String memeTokenId}) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'memeTokenId',
      'items',
      'nextCursor',
      'source',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    if (root['memeTokenId'] != memeTokenId) invalid();
    final items = <MemeTrade>[
      for (final item in LoopV2ChainCodec.requireList(
        root['items'],
        maximum: 100,
      ))
        _trade(item),
    ];
    return MemeTradePage(
      items: List<MemeTrade>.unmodifiable(items),
      nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
      observedAt: _loopIndexerSource(root['source']).observedAt,
    );
  }

  static MemeTrade _trade(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'txHash',
      'logIndex',
      'blockNumber',
      'wallet',
      'account',
      'isBuy',
      'usd1Amount',
      'tokenAmount',
      'feeUsd1',
      'priceAfter',
      'at',
    });
    return MemeTrade(
      txHash: LoopV2ChainCodec.requireString(
        map,
        'txHash',
        pattern: bytes32Pattern,
        maxLength: 66,
      ),
      logIndex: LoopV2ChainCodec.requireInt(map, 'logIndex'),
      blockNumber: LoopV2ChainCodec.requireBlockNumber(
        map,
        'blockNumber',
      ).toString(),
      wallet: address(map, 'wallet'),
      account: account(map['account']),
      isBuy: LoopV2ChainCodec.requireBool(map, 'isBuy'),
      usd1Amount: LoopV2MemeCodec.raw(map, 'usd1Amount'),
      tokenAmount: LoopV2MemeCodec.raw(map, 'tokenAmount'),
      feeUsd1: LoopV2MemeCodec.raw(map, 'feeUsd1'),
      priceAfter: price(map, 'priceAfter'),
      at: LoopV2ChainCodec.requireTimestamp(map, 'at'),
    );
  }

  static MemeCandleSeries candles(
    Object? raw, {
    required String memeTokenId,
    required MemeCandleInterval interval,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'memeTokenId',
      'interval',
      'items',
      'frozenAt',
      'source',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    if (root['memeTokenId'] != memeTokenId ||
        root['interval'] != interval.wireName) {
      invalid();
    }
    final candles = <LoopCandle>[];
    DateTime? previous;
    for (final item in LoopV2ChainCodec.requireList(
      root['items'],
      maximum: 300,
    )) {
      final map = LoopV2Contract.strictMap(item, const <String>{
        'openTime',
        'open',
        'high',
        'low',
        'close',
        'volumeUsd1',
        'tradeCount',
      });
      final openTime = LoopV2ChainCodec.requireTimestamp(map, 'openTime');
      // Oldest first, one bucket per time: the chart's axis depends on it.
      if (previous != null && !openTime.isAfter(previous)) invalid();
      previous = openTime;
      final open = price(map, 'open');
      final high = price(map, 'high');
      final low = price(map, 'low');
      final close = price(map, 'close');
      if (high < low ||
          open > high ||
          open < low ||
          close > high ||
          close < low) {
        invalid();
      }
      candles.add(
        LoopCandle(
          openTime: openTime,
          closeTime: openTime.add(interval.width),
          open: open,
          high: high,
          low: low,
          close: close,
          volume: price(map, 'volumeUsd1'),
          swapCount: LoopV2ChainCodec.requireInt(map, 'tradeCount', minimum: 1),
          isOpen: false,
        ),
      );
    }
    return MemeCandleSeries(
      interval: interval,
      candles: List<LoopCandle>.unmodifiable(candles),
      frozenAt: LoopV2ChainCodec.optionalTimestamp(root, 'frozenAt'),
      observedAt: _loopIndexerSource(root['source']).observedAt,
    );
  }

  static MemeHolderPage holderPage(Object? raw, {required String memeTokenId}) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'memeTokenId',
      'holderCount',
      'frozenAt',
      'items',
      'nextCursor',
      'source',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    if (root['memeTokenId'] != memeTokenId) invalid();
    final items = <MemeHolder>[
      for (final item in LoopV2ChainCodec.requireList(
        root['items'],
        maximum: 100,
      ))
        _holder(item),
    ];
    return MemeHolderPage(
      holderCount: LoopV2ChainCodec.requireInt(root, 'holderCount'),
      frozenAt: LoopV2ChainCodec.optionalTimestamp(root, 'frozenAt'),
      items: List<MemeHolder>.unmodifiable(items),
      nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
      observedAt: _loopIndexerSource(root['source']).observedAt,
    );
  }

  static MemeHolder _holder(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'wallet',
      'account',
      'balance',
      'shareBps',
      'isCreator',
      'isViewer',
    });
    return MemeHolder(
      wallet: address(map, 'wallet'),
      account: account(map['account']),
      balance: LoopV2MemeCodec.raw(map, 'balance'),
      shareBps: LoopV2ChainCodec.requireInt(map, 'shareBps', maximum: 10000),
      isCreator: LoopV2ChainCodec.requireBool(map, 'isCreator'),
      isViewer: LoopV2ChainCodec.requireBool(map, 'isViewer'),
    );
  }

  // -------------------------------------------------------------------------
  // quote
  // -------------------------------------------------------------------------

  static MemeQuote quote(
    Object? raw, {
    required String memeTokenId,
    required MemeTradeSide side,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'quote',
      'basis',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final map = LoopV2Contract.strictMapWithOptional(
      root['quote'],
      const <String>{
        'memeTokenId',
        'side',
        'amountIn',
        'out',
        'fee',
        'priceImpactBps',
        'priceBefore',
        'priceAfter',
        'minOutAtDefaultSlippage',
        'walletCapHit',
        'walletCapRemaining',
        'belowMinBuy',
      },
      const <String>{'refund'},
    );
    if (map['memeTokenId'] != memeTokenId || map['side'] != side.wireName) {
      invalid();
    }
    // A sell carries no refund; a buy may.
    if (side == MemeTradeSide.sell && map['refund'] != null) invalid();
    final basis = LoopV2Contract.strictMap(root['basis'], const <String>{
      'source',
      'blockNumber',
      'observedAt',
    });
    final source = basis['source'];
    if (source != 'chain' && source != 'loop_indexer') invalid();
    LoopV2ChainCodec.optionalBlockNumber(basis, 'blockNumber');
    return MemeQuote(
      memeTokenId: memeTokenId,
      side: side,
      amountIn: LoopV2MemeCodec.raw(map, 'amountIn'),
      out: LoopV2MemeCodec.raw(map, 'out'),
      fee: LoopV2MemeCodec.raw(map, 'fee'),
      refund: optionalRaw(map, 'refund'),
      priceImpactBps: LoopV2ChainCodec.requireInt(map, 'priceImpactBps'),
      priceBefore: price(map, 'priceBefore'),
      priceAfter: price(map, 'priceAfter'),
      minOutAtDefaultSlippage: LoopV2MemeCodec.raw(
        map,
        'minOutAtDefaultSlippage',
      ),
      walletCapHit: LoopV2ChainCodec.requireBool(map, 'walletCapHit'),
      walletCapRemaining: optionalRaw(map, 'walletCapRemaining'),
      belowMinBuy: LoopV2ChainCodec.requireBool(map, 'belowMinBuy'),
      basisFromChain: source == 'chain',
      observedAt: LoopV2ChainCodec.requireTimestamp(basis, 'observedAt'),
    );
  }

  // -------------------------------------------------------------------------
  // intents
  // -------------------------------------------------------------------------

  static ({String to, String data}) _calldata(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'to',
      'data',
      'value',
    });
    if (map['value'] != '0') invalid();
    return (
      to: address(map, 'to'),
      data: LoopV2ChainCodec.requireString(
        map,
        'data',
        pattern: hexDataPattern,
        maxLength: 100000,
      ),
    );
  }

  static MemeUnsignedTransaction _transaction(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, transactionKeys);
    final chainId = map['chainId'];
    if (chainId != 56 && chainId != 97) invalid();
    if (map['value'] != '0x0') invalid();
    final type = map['type'];
    if (type != 'eip1559' && type != 'legacy') invalid();
    for (final key in const <String>['gas', 'nonce']) {
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: quantityPattern,
        maxLength: 66,
      );
    }
    for (final key in const <String>[
      'maxFeePerGas',
      'maxPriorityFeePerGas',
      'gasPrice',
    ]) {
      LoopV2ChainCodec.optionalString(
        map,
        key,
        pattern: quantityPattern,
        maxLength: 66,
      );
    }
    final data = LoopV2ChainCodec.requireString(
      map,
      'data',
      pattern: hexDataPattern,
      maxLength: 100000,
    );
    return MemeUnsignedTransaction(
      chainId: chainId! as int,
      to: address(map, 'to'),
      data: data,
      from: address(map, 'from'),
      wire: Map<String, Object?>.unmodifiable(map),
    );
  }

  static MemeIntent intent(Object? raw) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'memeIntent',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final map = LoopV2Contract.strictMapWithOptional(
      root['memeIntent'],
      intentKeys,
      const <String>{'predictedAddress'},
    );
    final rawKind = map['kind'];
    final kind = rawKind is String ? MemeIntentKind.tryParse(rawKind) : null;
    final rawState = map['state'];
    final state = rawState is String
        ? MemeIntentState.tryParse(rawState)
        : null;
    if (kind == null || state == null) invalid();
    final chainId = _chainId(map, 'chainId');
    final chainReference = _chainReference(map, 'chainReference');
    if (chainId != 'eip155:$chainReference') invalid();
    final contractAddress = address(map, 'contractAddress');
    final calldata = _calldata(map['calldata']);
    final transaction = _transaction(map['unsignedTransaction']);
    MemeApproval? approval;
    var approvalMatches = true;
    if (map['approval'] != null) {
      final a = LoopV2Contract.strictMap(map['approval'], const <String>{
        'token',
        'spender',
        'amount',
        'calldata',
        'unsignedTransaction',
      });
      final approvalCalldata = _calldata(a['calldata']);
      final approvalTransaction = _transaction(a['unsignedTransaction']);
      approval = MemeApproval(
        token: address(a, 'token'),
        spender: address(a, 'spender'),
        amount: LoopV2MemeCodec.raw(a, 'amount'),
        unsignedTransaction: approvalTransaction,
      );
      approvalMatches =
          approvalTransaction.to == approval.token &&
          approvalCalldata.to == approval.token &&
          approvalTransaction.data == approvalCalldata.data &&
          approvalTransaction.chainId == chainReference &&
          approvalTransaction.from == transaction.from &&
          approval.spender == contractAddress;
    }
    final simulation = LoopV2Contract.strictMap(
      map['simulation'],
      const <String>{'status', 'reasonCode'},
    );
    final simulationStatus = simulation['status'];
    if (simulationStatus != 'passed' &&
        simulationStatus != 'reverted' &&
        simulationStatus != 'unavailable') {
      invalid();
    }
    final policy = LoopV2Contract.strictMap(map['policy'], const <String>{
      'configVersion',
      'canaryMaxUsd',
      'valueUsd',
      'priceSource',
    });
    for (final key in const <String>['configVersion', 'priceSource']) {
      LoopV2ChainCodec.requireText(policy, key, maxLength: 64);
    }
    final signing = LoopV2Contract.strictMap(map['signing'], const <String>{
      'mode',
      'allowed',
      'reasonCode',
    });
    if (signing['mode'] != 'device_eth_send_transaction') invalid();
    final mainMatches =
        transaction.to == contractAddress &&
        calldata.to == contractAddress &&
        transaction.data == calldata.data &&
        transaction.chainId == chainReference;
    return MemeIntent(
      memeIntentId: uuid(map, 'memeIntentId'),
      kind: kind,
      state: state,
      memeTokenId: uuid(map, 'memeTokenId'),
      walletId: uuid(map, 'walletId'),
      chainId: chainId,
      contractAddress: contractAddress,
      tokenAddress: optionalAddress(map, 'tokenAddress'),
      predictedAddress: optionalAddress(map, 'predictedAddress'),
      usd1Amount: LoopV2MemeCodec.raw(map, 'usd1Amount'),
      tokenAmount: LoopV2MemeCodec.raw(map, 'tokenAmount'),
      expectedOut: LoopV2MemeCodec.raw(map, 'expectedOut'),
      minOut: LoopV2MemeCodec.raw(map, 'minOut'),
      fee: LoopV2MemeCodec.raw(map, 'fee'),
      refund: LoopV2MemeCodec.raw(map, 'refund'),
      deadline: LoopV2ChainCodec.requireTimestamp(map, 'deadline'),
      expiresAt: LoopV2ChainCodec.requireTimestamp(map, 'expiresAt'),
      createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
      unsignedTransaction: transaction,
      approval: approval,
      payloadDigest: LoopV2ChainCodec.requireString(
        map,
        'payloadDigest',
        pattern: digestPattern,
        maxLength: 64,
      ),
      snapshotBlockNumber: LoopV2ChainCodec.requireBlockNumber(
        map,
        'snapshotBlockNumber',
      ).toString(),
      transactionHash: optionalHash(map, 'transactionHash'),
      reasonCode: LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode'),
      simulationStatus: simulationStatus! as String,
      simulationReasonCode: LoopV2ChainCodec.optionalReasonCode(
        simulation,
        'reasonCode',
      ),
      policy: MemeIntentPolicy(
        canaryMaxUsd: LoopV2ChainCodec.requireDecimal(
          policy,
          'canaryMaxUsd',
        ).toString(),
        valueUsd: LoopV2ChainCodec.requireDecimal(
          policy,
          'valueUsd',
        ).toString(),
      ),
      signingAllowed: LoopV2ChainCodec.requireBool(signing, 'allowed'),
      signingReasonCode: LoopV2ChainCodec.optionalReasonCode(
        signing,
        'reasonCode',
      ),
      payloadMatchesReview: mainMatches && approvalMatches,
    );
  }

  // -------------------------------------------------------------------------
  // media
  // -------------------------------------------------------------------------

  static MemeUploadedImage uploadedImage(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'mediaId',
      'ref',
      'url',
      'width',
      'height',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(map);
    final mediaId = uuid(map, 'mediaId');
    if (map['ref'] != 'logo:media/$mediaId' ||
        map['url'] != '/v2/media/$mediaId.webp') {
      invalid();
    }
    final width = LoopV2ChainCodec.requireInt(map, 'width', minimum: 1);
    final height = LoopV2ChainCodec.requireInt(map, 'height', minimum: 1);
    if (width > 4096 || height > 4096) invalid();
    final url = mediaUrl(mediaId);
    if (url == null) invalid();
    return MemeUploadedImage(mediaId: mediaId, url: url);
  }
}
