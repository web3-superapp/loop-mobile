import 'package:decimal/decimal.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders for the `launch2` module (MEME v2; loop-api decision 0114
/// / 0117, `docs/frontend-v2-launch2-api.md`, OpenAPI tag `launch2`).
///
/// Every object in the published schema is `additionalProperties: false`
/// with every key required (nullable where the schema says so), so each goes
/// through [LoopV2Contract.strictMap] with its exact key set: an unknown or a
/// missing field is an invalid payload. The two transaction objects are the
/// one exception the schema itself makes (`additionalProperties: true`); they
/// are read with the meme transaction key set, which is what the server
/// builds. Amounts become exact [Decimal]s; no `double` is involved.
abstract final class LoopV2Launch2Codec {
  static final RegExp amountPattern = RegExp(
    r'^(0|[1-9][0-9]{0,40})(\.[0-9]{1,18})?$',
  );
  static final RegExp integerPattern = RegExp(r'^(0|[1-9][0-9]{0,77})$');
  static final RegExp bytes32Pattern = RegExp(r'^0x[0-9a-f]{64}$');
  static final RegExp digestPattern = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp hexDataPattern = RegExp(r'^0x([0-9a-f]{2})*$');
  static final RegExp quantityPattern = RegExp(
    r'^0x(0|[1-9a-f][0-9a-f]{0,63})$',
  );

  /// A launch ticker: four.meme's 1–20 rule, as sent (decision 0206).
  static String ticker(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || !loopTokenTickerIsWellFormed(value)) invalid();
    return value;
  }

  /// `/v2/media/{mediaId}.webp`: a logo our own media service serves.
  static final RegExp mediaPathPattern = RegExp(
    r'^/v2/media/([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.webp$',
  );

  static const rowKeys = <String>{
    'instanceId',
    'projectId',
    'launchId',
    'chainId',
    'name',
    'ticker',
    'logoUrl',
    'memeAddress',
    'stage',
    'nextChangeAt',
    'holdReason',
    'activatedAt',
    'nftSale',
    'curve',
    'graduatedAt',
  };

  /// Keys a row may carry or omit (loop-api S180, decision 0163): the
  /// project summary and its links. Missing, `null` or unreadable values are
  /// read as none — they are display extras, never a reason to refuse a row.
  static const rowOptionalKeys = <String>{'summary', 'links'};

  static const detailKeys = <String>{
    ...rowKeys,
    'viewerIsProjectOwner',
    'projectOwnerAddress',
    'configVersion',
    'configHash',
    'buybackRecipient',
    'template',
    'contracts',
    'snapshot',
    'graduation',
    'buyback',
    'recentTrades',
    'viewer',
    'projectedAt',
  };

  /// Keys a server may omit: `pool` (loop-api S146, decision 0145).
  static const detailOptionalKeys = <String>{
    'pool',
    'tradingHold',
    ...rowOptionalKeys,
  };

  static const nftSaleKeys = <String>{
    'priceUsd1',
    'soldCount',
    'startAt',
    'endAt',
  };

  static const curveKeys = <String>{
    'saleSupply',
    'soldSupply',
    'soldBps',
    'reserveUsd1',
    'graduationReserveUsd1',
    'reserveBps',
    'priceUsd1',
  };

  static const templateKeys = <String>{
    'templateVersion',
    'memeTotalSupply',
    'curveSaleSupply',
    'initialLiquiditySupply',
    'graduationReserveUsd1',
    'curveBuyTaxBps',
    'curveSellTaxBps',
    'officialPoolTaxBps',
    'lpFee',
    'tickSpacing',
    'perAddressCap',
    'perAddressCapBps',
    'nftPriceUsd1',
    'nftSaleSeconds',
    'earlyRoundSeconds',
    'buybackOrderUsd1',
    'buybackMinIntervalSeconds',
  };

  static const contractKeys = <String>{
    'factory',
    'meme',
    'hook',
    'nft',
    'curve',
    'gate',
    'escrow',
    'snapshots',
    'graduationAdapter',
    'buybackAdapter',
    'priceRecorder',
    'buybackExecutor',
  };

  static const snapshotKeys = <String>{
    'status',
    'verification',
    'root',
    'dataHash',
    'cutoffBlockNumber',
    'cutoffBlockHash',
    'publishedAt',
    'earlyRoundEndsAt',
    'memberCount',
    'signers',
    // Decision 0120: required, `null` unless the sale closed with no holder.
    'closure',
  };

  static const graduationKeys = <String>{
    'graduatedAt',
    'officialPoolId',
    'hookAddress',
    'lpFee',
    'tickSpacing',
    'officialPoolTaxBps',
    'transactionHash',
  };

  static const buybackSummaryKeys = <String>{
    'recipient',
    'paused',
    'executedCount',
    'totalUsd1',
    'totalMeme',
    'lastExecutedAt',
    'escrowRecordedUsd1',
    'escrowAvailableUsd1',
    'latest',
  };

  static const buybackRecordKeys = <String>{
    'buybackId',
    'outcome',
    'reasonCode',
    'usd1Spent',
    'memeDelivered',
    'minMemeOut',
    'referencePriceUsd1',
    'spotPriceUsd1',
    'executedAt',
    'transactionHash',
    'blockNumber',
  };

  static const tradeKeys = <String>{
    'tradeId',
    'side',
    'traderAddress',
    'memeAmount',
    'usd1Gross',
    'usd1Net',
    'taxUsd1',
    'tradedAt',
    'transactionHash',
    'blockNumber',
  };

  static const curvePositionKeys = <String>{
    'bought',
    'sold',
    'net',
    'cumulativeBought',
    'remainingQuota',
    'usd1Spent',
    'usd1Received',
    'taxUsd1',
  };

  static const viewerKeys = <String>{'walletId', 'nft', 'snapshot', 'curve'};

  /// Decision 0148 (loop-api S150): the wallet's balances and own pool
  /// trades, on the viewer and on every position. Optional as a group — an
  /// older server sends none — but one present means all present.
  static const walletHoldingKeys = <String>{
    'memeBalance',
    'usd1Balance',
    'balanceStatus',
    'balanceReasonCode',
    'balanceBlockNumber',
    'poolTradeCount',
    'lastPoolTradeAt',
  };

  static const quoteKeys = <String>{
    'instanceId',
    'walletId',
    'side',
    'stage',
    'requestedAmount',
    'exceedsMax',
    'amountIn',
    'maxIn',
    'expectedOut',
    'minOut',
    'slippageBps',
    'taxUsd1',
    'taxBps',
    'refundUsd1',
    'priceBeforeUsd1',
    'priceAfterUsd1',
    'max',
    'quota',
    'inventory',
    'eligibility',
    'deadline',
    'quotedAt',
    'basis',
  };

  static const intentKeys = <String>{
    'intentId',
    'kind',
    'state',
    'instanceId',
    'walletId',
    'chainId',
    'chainReference',
    'contractAddress',
    'amountIn',
    'expectedOut',
    'minOut',
    'taxUsd1',
    'refundUsd1',
    'deadline',
    'expiresAt',
    'createdAt',
    'calldata',
    'unsignedTransaction',
    'approval',
    'payloadDigest',
    'snapshotBlockNumber',
    'snapshotBlockHash',
    'simulation',
    'policy',
    'signing',
  };

  /// What the server builds for `unsignedTransaction` (loop-api
  /// `unsignedTransactionFor`); the schema leaves the object open.
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

  static const buybackLiveKeys = <String>{
    'paused',
    'lastSuccessfulAt',
    'escrowRecordedUsd1',
    'escrowSpentUsd1',
    'escrowAvailableUsd1',
    'nextOrderUsd1',
    'nextOrderBlockedReason',
  };

  static const positionKeys = <String>{
    'instanceId',
    'name',
    'ticker',
    'logoUrl',
    'memeAddress',
    'stage',
    'walletId',
    'nft',
    'snapshotMember',
    'curve',
    'lastActivityAt',
  };

  static Never invalid() => LoopV2ChainCodec.invalid();

  // -------------------------------------------------------------------------
  // scalars
  // -------------------------------------------------------------------------

  static Decimal amount(Map<String, Object?> map, String key) {
    final value = LoopV2ChainCodec.requireString(
      map,
      key,
      pattern: amountPattern,
      maxLength: 60,
    );
    return Decimal.parse(value);
  }

  static BigInt integer(Map<String, Object?> map, String key) => BigInt.parse(
    LoopV2ChainCodec.requireString(
      map,
      key,
      pattern: integerPattern,
      maxLength: 78,
    ),
  );

  static BigInt? optionalInteger(Map<String, Object?> map, String key) =>
      map[key] == null ? null : integer(map, key);

  static String address(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: LoopV2ChainCodec.addressPattern,
        maxLength: 42,
      );

  /// An address the server may print in checksum case (the approval's
  /// token); compared lower-case.
  static String anyCaseAddress(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value)) {
      invalid();
    }
    return value.toLowerCase();
  }

  static String hash(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: bytes32Pattern,
        maxLength: 66,
      );

  static String? optionalHash(Map<String, Object?> map, String key) =>
      map[key] == null ? null : hash(map, key);

  static String uuid(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      );

  static int bps(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.requireInt(map, key, maximum: 10000);

  static String chainId(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || !loopKnownChainIds.contains(value)) invalid();
    return value;
  }

  static Launch2Stage stage(Map<String, Object?> map, String key) {
    final value = map[key];
    final stage = value is String ? Launch2Stage.tryParse(value) : null;
    if (stage == null) invalid();
    return stage;
  }

  static String? reasonCode(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.optionalReasonCode(map, key);

  /// A creator's logo is a picture, not a fact: an address the client will
  /// not fetch costs the row its picture (the monogram), never the page.
  static String? logoUrl(
    Map<String, Object?> map,
    String key, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String || value.length > 2048) invalid();
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final media = mediaPathPattern.firstMatch(uri.path);
    if (media != null && mediaUrl(media.group(1)!) == value) return value;
    return LoopV2ChainCodec.isAcceptedLogoUrl(uri) ? value : null;
  }

  // -------------------------------------------------------------------------
  // rows and the detail
  // -------------------------------------------------------------------------

  static Launch2NftSale _nftSale(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, nftSaleKeys);
    final startAt = LoopV2ChainCodec.requireTimestamp(map, 'startAt');
    final endAt = LoopV2ChainCodec.requireTimestamp(map, 'endAt');
    if (endAt.isBefore(startAt)) invalid();
    return Launch2NftSale(
      priceUsd1: amount(map, 'priceUsd1'),
      soldCount: integer(map, 'soldCount'),
      startAt: startAt,
      endAt: endAt,
    );
  }

  static Launch2Curve _curve(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, curveKeys);
    return Launch2Curve(
      saleSupply: amount(map, 'saleSupply'),
      soldSupply: amount(map, 'soldSupply'),
      soldBps: bps(map, 'soldBps'),
      reserveUsd1: amount(map, 'reserveUsd1'),
      graduationReserveUsd1: amount(map, 'graduationReserveUsd1'),
      reserveBps: bps(map, 'reserveBps'),
      priceUsd1: amount(map, 'priceUsd1'),
    );
  }

  static Launch2InstanceRow _rowFrom(
    Map<String, Object?> map, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final holdRaw = map['holdReason'];
    Launch2HoldReason? hold;
    if (holdRaw != null) {
      hold = holdRaw is String ? Launch2HoldReason.tryParse(holdRaw) : null;
      if (hold == null) invalid();
    }
    final ticker = LoopV2Launch2Codec.ticker(map, 'ticker');
    final stageValue = stage(map, 'stage');
    final nextChangeAt = LoopV2ChainCodec.optionalTimestamp(
      map,
      'nextChangeAt',
    );
    // A terminal stage has nothing to count down to (decision 0120).
    if (stageValue.terminal && nextChangeAt != null) invalid();
    return Launch2InstanceRow(
      instanceId: uuid(map, 'instanceId'),
      projectId: uuid(map, 'projectId'),
      launchId: hash(map, 'launchId'),
      chainId: chainId(map, 'chainId'),
      name: LoopV2ChainCodec.providerText(map, 'name', maxLength: 64),
      ticker: ticker,
      logoUrl: logoUrl(map, 'logoUrl', mediaUrl: mediaUrl),
      memeAddress: address(map, 'memeAddress'),
      stage: stageValue,
      nextChangeAt: nextChangeAt,
      holdReason: hold,
      activatedAt: LoopV2ChainCodec.optionalTimestamp(map, 'activatedAt'),
      nftSale: _nftSale(map['nftSale']),
      curve: _curve(map['curve']),
      graduatedAt: LoopV2ChainCodec.optionalTimestamp(map, 'graduatedAt'),
      summary: _summary(map['summary']),
      links: _links(map['links']),
    );
  }

  /// The longest summary drawn; the server sends at most 60 characters.
  static const int summaryMaxRunes = 120;

  static String? _summary(Object? raw) {
    if (raw is! String) return null;
    final text = LoopV2ChainCodec.sanitizeProviderText(raw);
    if (text.isEmpty || text.runes.length > summaryMaxRunes) return null;
    return text;
  }

  /// Absolute `https` links only; anything else is dropped.
  static List<String> _links(Object? raw) {
    if (raw is! List) return const <String>[];
    final links = <String>[
      for (final item in raw.take(8))
        if (item is String && item.length <= 2048)
          if (Uri.tryParse(item) case final Uri uri
              when uri.scheme == 'https' && uri.host.isNotEmpty)
            item,
    ];
    return List<String>.unmodifiable(links);
  }

  static Launch2InstanceRow row(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) => _rowFrom(
    LoopV2Contract.strictMapWithOptional(raw, rowKeys, rowOptionalKeys),
    mediaUrl: mediaUrl,
  );

  /// `GET /v2/launch2/instances`.
  static Launch2InstancePage page(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'instances',
      'nextCursor',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final items = LoopV2ChainCodec.requireList(root['instances'], maximum: 50);
    final rows = <Launch2InstanceRow>[
      for (final item in items) row(item, mediaUrl: mediaUrl),
    ];
    final ids = <String>{for (final row in rows) row.instanceId};
    if (ids.length != rows.length) invalid();
    return Launch2InstancePage(
      items: List<Launch2InstanceRow>.unmodifiable(rows),
      nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
    );
  }

  /// The instance's template grows with each contract generation (0197 added
  /// `perAddressCap`): its known keys are strict, a key a later generation
  /// adds is ignored rather than failing the whole project page (decision
  /// 0198).
  static Launch2Template _template(Object? raw) {
    final map = LoopV2Contract.knownKeysMap(raw, templateKeys);
    if (map['templateVersion'] != 'hooks_launch_v1') invalid();
    return Launch2Template(
      templateVersion: 'hooks_launch_v1',
      memeTotalSupply: amount(map, 'memeTotalSupply'),
      curveSaleSupply: amount(map, 'curveSaleSupply'),
      initialLiquiditySupply: amount(map, 'initialLiquiditySupply'),
      graduationReserveUsd1: amount(map, 'graduationReserveUsd1'),
      curveBuyTaxBps: bps(map, 'curveBuyTaxBps'),
      curveSellTaxBps: bps(map, 'curveSellTaxBps'),
      officialPoolTaxBps: bps(map, 'officialPoolTaxBps'),
      lpFee: LoopV2ChainCodec.requireInt(map, 'lpFee', maximum: 1000000),
      tickSpacing: LoopV2ChainCodec.requireInt(
        map,
        'tickSpacing',
        minimum: 1,
        maximum: 32767,
      ),
      perAddressCap: amount(map, 'perAddressCap'),
      perAddressCapBps: bps(map, 'perAddressCapBps'),
      nftPriceUsd1: amount(map, 'nftPriceUsd1'),
      nftSaleSeconds: LoopV2ChainCodec.requireInt(
        map,
        'nftSaleSeconds',
        minimum: 1,
      ),
      earlyRoundSeconds: LoopV2ChainCodec.requireInt(
        map,
        'earlyRoundSeconds',
        minimum: 1,
      ),
      buybackOrderUsd1: amount(map, 'buybackOrderUsd1'),
      buybackMinIntervalSeconds: LoopV2ChainCodec.requireInt(
        map,
        'buybackMinIntervalSeconds',
      ),
    );
  }

  static Map<String, String> _contracts(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, contractKeys);
    return Map<String, String>.unmodifiable(<String, String>{
      for (final key in contractKeys) key: address(map, key),
    });
  }

  /// loop-api decision 0118 added `publication` to the snapshot; a server
  /// from before it omits the key, which reads as no attempt yet. Decision
  /// 0122 added `openedWithoutHolders` the same way (optional in the schema,
  /// always present in answers).
  static const snapshotOptionalKeys = <String>{
    'publication',
    'openedWithoutHolders',
  };

  static Launch2OpenedWithoutHolders? _openedWithoutHolders(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'openedAt',
      'blockNumber',
      'transactionHash',
    });
    return Launch2OpenedWithoutHolders(
      openedAt: LoopV2ChainCodec.requireTimestamp(map, 'openedAt'),
      blockNumber: integer(map, 'blockNumber'),
      transactionHash: hash(map, 'transactionHash'),
    );
  }

  static const publicationKeys = <String>{
    'status',
    'txHash',
    'cutoffBlock',
    'memberCount',
  };

  static Launch2SnapshotPublication? _publication(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, publicationKeys);
    final status = map['status'];
    final parsed = status is String
        ? Launch2PublicationStatus.tryParse(status)
        : null;
    if (parsed == null) invalid();
    return Launch2SnapshotPublication(
      status: parsed,
      txHash: optionalHash(map, 'txHash'),
      cutoffBlock: integer(map, 'cutoffBlock'),
      memberCount: LoopV2ChainCodec.requireInt(map, 'memberCount', minimum: 1),
    );
  }

  static Launch2SnapshotClosure? _closure(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'reason',
      'cutoffBlock',
      'closedAt',
    });
    if (map['reason'] != 'no_holders') invalid();
    return Launch2SnapshotClosure(
      cutoffBlock: integer(map, 'cutoffBlock'),
      closedAt: LoopV2ChainCodec.requireTimestamp(map, 'closedAt'),
    );
  }

  static Launch2Snapshot _snapshot(Object? raw) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      snapshotKeys,
      snapshotOptionalKeys,
    );
    final status = map['status'];
    if (status != 'pending' &&
        status != 'published' &&
        status != 'opened_without_holders') {
      invalid();
    }
    final opened = _openedWithoutHolders(map['openedWithoutHolders']);
    // Decision 0122: the opening status and its record arrive together, and
    // an opening has no list, no publication and no closure.
    if ((status == 'opened_without_holders') != (opened != null)) invalid();
    if (opened != null &&
        (map['root'] != null ||
            map['publication'] != null ||
            map['closure'] != null)) {
      invalid();
    }
    final rawVerification = map['verification'];
    final verification = switch (rawVerification) {
      null => null,
      'pending' => Launch2SnapshotVerification.pending,
      'verified' => Launch2SnapshotVerification.verified,
      'mismatch' => Launch2SnapshotVerification.mismatch,
      _ => invalid(),
    };
    optionalHash(map, 'dataHash');
    optionalHash(map, 'cutoffBlockHash');
    final signers = map['signers'];
    if (signers != null) {
      for (final signer in LoopV2ChainCodec.requireList(signers, maximum: 16)) {
        if (signer is! String ||
            !LoopV2ChainCodec.addressPattern.hasMatch(signer)) {
          invalid();
        }
      }
    }
    return Launch2Snapshot(
      published: status == 'published',
      verification: verification,
      root: optionalHash(map, 'root'),
      cutoffBlockNumber: optionalInteger(map, 'cutoffBlockNumber'),
      publishedAt: LoopV2ChainCodec.optionalTimestamp(map, 'publishedAt'),
      earlyRoundEndsAt: LoopV2ChainCodec.optionalTimestamp(
        map,
        'earlyRoundEndsAt',
      ),
      memberCount: LoopV2ChainCodec.optionalInt(map, 'memberCount', minimum: 0),
      publication: _publication(map['publication']),
      closure: _closure(map['closure']),
      openedWithoutHolders: opened,
    );
  }

  static Launch2Graduation? _graduation(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, graduationKeys);
    return Launch2Graduation(
      graduatedAt: LoopV2ChainCodec.requireTimestamp(map, 'graduatedAt'),
      officialPoolId: hash(map, 'officialPoolId'),
      hookAddress: address(map, 'hookAddress'),
      lpFee: LoopV2ChainCodec.requireInt(map, 'lpFee', maximum: 1000000),
      tickSpacing: LoopV2ChainCodec.requireInt(
        map,
        'tickSpacing',
        minimum: 1,
        maximum: 32767,
      ),
      officialPoolTaxBps: bps(map, 'officialPoolTaxBps'),
      transactionHash: optionalHash(map, 'transactionHash'),
    );
  }

  static Decimal? _optionalAmount(Map<String, Object?> map, String key) =>
      map[key] == null ? null : amount(map, key);

  static Launch2BuybackRecord _buybackRecord(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, buybackRecordKeys);
    final outcome = map['outcome'];
    if (outcome != 'executed' && outcome != 'rejected') invalid();
    final protection = (
      _optionalAmount(map, 'minMemeOut'),
      _optionalAmount(map, 'referencePriceUsd1'),
      _optionalAmount(map, 'spotPriceUsd1'),
    );
    final set = <bool>[
      protection.$1 != null,
      protection.$2 != null,
      protection.$3 != null,
    ];
    if (set.toSet().length != 1) invalid();
    return Launch2BuybackRecord(
      buybackId: LoopV2ChainCodec.requireString(
        map,
        'buybackId',
        pattern: RegExp(r'^[A-Za-z0-9:_-]{1,128}$'),
        maxLength: 128,
      ),
      executed: outcome == 'executed',
      reasonCode: reasonCode(map, 'reasonCode'),
      usd1Spent: amount(map, 'usd1Spent'),
      memeDelivered: amount(map, 'memeDelivered'),
      // Decision 0122: a v3 execution has no price protection; the three
      // figures are all set (v2) or all null (v3).
      minMemeOut: protection.$1,
      referencePriceUsd1: protection.$2,
      spotPriceUsd1: protection.$3,
      executedAt: LoopV2ChainCodec.requireTimestamp(map, 'executedAt'),
      transactionHash: hash(map, 'transactionHash'),
      blockNumber: integer(map, 'blockNumber'),
    );
  }

  /// loop-api decision 0121: optional in the schema, always present in
  /// answers.
  static const buybackSummaryOptionalKeys = <String>{'keeper'};

  static Launch2BuybackKeeper? _keeper(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'lastAttemptAt',
      'lastResult',
      'reasonCode',
      'nextEligibleAt',
    });
    final result = Launch2KeeperResult.tryParse(map['lastResult']);
    if (result == null) invalid();
    return Launch2BuybackKeeper(
      lastAttemptAt: LoopV2ChainCodec.requireTimestamp(map, 'lastAttemptAt'),
      lastResult: result,
      reasonCode: reasonCode(map, 'reasonCode'),
      nextEligibleAt: LoopV2ChainCodec.optionalTimestamp(map, 'nextEligibleAt'),
    );
  }

  static Launch2BuybackSummary _buybackSummary(Object? raw) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      buybackSummaryKeys,
      buybackSummaryOptionalKeys,
    );
    return Launch2BuybackSummary(
      recipient: address(map, 'recipient'),
      paused: LoopV2ChainCodec.requireBool(map, 'paused'),
      executedCount: integer(map, 'executedCount'),
      totalUsd1: amount(map, 'totalUsd1'),
      totalMeme: amount(map, 'totalMeme'),
      lastExecutedAt: LoopV2ChainCodec.optionalTimestamp(map, 'lastExecutedAt'),
      escrowRecordedUsd1: amount(map, 'escrowRecordedUsd1'),
      escrowAvailableUsd1: amount(map, 'escrowAvailableUsd1'),
      latest: map['latest'] == null ? null : _buybackRecord(map['latest']),
      keeper: _keeper(map['keeper']),
    );
  }

  static Launch2Trade _trade(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, tradeKeys);
    final side = map['side'];
    final parsed = side is String ? Launch2Side.tryParse(side) : null;
    if (parsed == null) invalid();
    return Launch2Trade(
      tradeId: LoopV2ChainCodec.requireString(
        map,
        'tradeId',
        pattern: RegExp(r'^[A-Za-z0-9:_-]{1,128}$'),
        maxLength: 128,
      ),
      side: parsed,
      traderAddress: address(map, 'traderAddress'),
      memeAmount: amount(map, 'memeAmount'),
      usd1Gross: amount(map, 'usd1Gross'),
      usd1Net: amount(map, 'usd1Net'),
      taxUsd1: amount(map, 'taxUsd1'),
      tradedAt: LoopV2ChainCodec.requireTimestamp(map, 'tradedAt'),
      transactionHash: hash(map, 'transactionHash'),
      blockNumber: integer(map, 'blockNumber'),
    );
  }

  static Launch2CurvePosition curvePosition(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, curvePositionKeys);
    return Launch2CurvePosition(
      bought: amount(map, 'bought'),
      sold: amount(map, 'sold'),
      // Curve bought − sold, never negative on the wire.
      net: amount(map, 'net'),
      cumulativeBought: amount(map, 'cumulativeBought'),
      remainingQuota: amount(map, 'remainingQuota'),
      usd1Spent: amount(map, 'usd1Spent'),
      usd1Received: amount(map, 'usd1Received'),
      taxUsd1: amount(map, 'taxUsd1'),
    );
  }

  static ({BigInt? mintedTokenId, int held}) _nftHolding(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'mintedTokenId',
      'held',
    });
    return (
      mintedTokenId: optionalInteger(map, 'mintedTokenId'),
      held: LoopV2ChainCodec.requireInt(map, 'held'),
    );
  }

  /// The holding group of a viewer or a position (decision 0148), `null`
  /// when the server sent none of its keys.
  static Launch2WalletHolding? walletHolding(Map<String, Object?> map) {
    final present = walletHoldingKeys.where(map.containsKey).length;
    if (present == 0) return null;
    if (present != walletHoldingKeys.length) invalid();
    final statusText = map['balanceStatus'];
    final status = statusText is String
        ? Launch2BalanceStatus.tryParse(statusText)
        : null;
    if (status == null) invalid();
    final meme = map['memeBalance'] == null ? null : amount(map, 'memeBalance');
    final usd1 = map['usd1Balance'] == null ? null : amount(map, 'usd1Balance');
    final block = optionalInteger(map, 'balanceBlockNumber');
    final reason = reasonCode(map, 'balanceReasonCode');
    // Read means both balances at one block; anything else carries none.
    final read = status == Launch2BalanceStatus.available;
    if (read != (meme != null) || read != (usd1 != null)) invalid();
    if (read && block == null) invalid();
    if (read && reason != null) invalid();
    return Launch2WalletHolding(
      status: status,
      memeBalance: meme,
      usd1Balance: usd1,
      reasonCode: reason,
      blockNumber: block,
      poolTradeCount: integer(map, 'poolTradeCount'),
      lastPoolTradeAt: LoopV2ChainCodec.optionalTimestamp(
        map,
        'lastPoolTradeAt',
      ),
    );
  }

  static Launch2Viewer? _viewer(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      viewerKeys,
      walletHoldingKeys,
    );
    final nft = _nftHolding(map['nft']);
    final snapshot = LoopV2Contract.strictMap(map['snapshot'], const <String>{
      'member',
      'eligibleNow',
    });
    return Launch2Viewer(
      walletId: uuid(map, 'walletId'),
      mintedTokenId: nft.mintedTokenId,
      nftHeld: nft.held,
      snapshotMember: LoopV2ChainCodec.requireBool(snapshot, 'member'),
      eligibleNow: LoopV2ChainCodec.requireBool(snapshot, 'eligibleNow'),
      curve: curvePosition(map['curve']),
      holding: walletHolding(map),
    );
  }

  /// `GET /v2/launch2/instances/{id}`.
  static Launch2InstanceDetail detail(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'instance',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    // Decision 0145: `pool` (loop-api S146) is optional in the schema.
    final map = LoopV2Contract.strictMapWithOptional(
      root['instance'],
      detailKeys,
      detailOptionalKeys,
    );
    final trades = LoopV2ChainCodec.requireList(
      map['recentTrades'],
      maximum: 100,
    );
    final graduation = _graduation(map['graduation']);
    final rowValue = _rowFrom(map, mediaUrl: mediaUrl);
    final snapshot = _snapshot(map['snapshot']);
    // Decision 0120: the closed stage always names its closure; a closure
    // shows under no other stage than that one or an integrity hold.
    final closed = rowValue.stage == Launch2Stage.closedNoHolders;
    if (closed != (snapshot.closure != null) &&
        !(rowValue.stage == Launch2Stage.paused && snapshot.closure != null)) {
      invalid();
    }
    // Decision 0122: an opening without holders is the public round, which
    // can then graduate or be held; it never precedes the sale's end.
    if (snapshot.openedWithoutHolders != null &&
        rowValue.stage != Launch2Stage.public &&
        rowValue.stage != Launch2Stage.graduated &&
        rowValue.stage != Launch2Stage.paused) {
      invalid();
    }
    return Launch2InstanceDetail(
      row: rowValue,
      viewerIsProjectOwner: LoopV2ChainCodec.requireBool(
        map,
        'viewerIsProjectOwner',
      ),
      projectOwnerAddress: address(map, 'projectOwnerAddress'),
      configVersion: LoopV2ChainCodec.requireInt(map, 'configVersion'),
      configHash: hash(map, 'configHash'),
      buybackRecipient: address(map, 'buybackRecipient'),
      template: _template(map['template']),
      contracts: _contracts(map['contracts']),
      snapshot: snapshot,
      graduation: graduation,
      buyback: _buybackSummary(map['buyback']),
      recentTrades: List<Launch2Trade>.unmodifiable(<Launch2Trade>[
        for (final trade in trades) _trade(trade),
      ]),
      viewer: _viewer(map['viewer']),
      projectedAt: LoopV2ChainCodec.requireTimestamp(map, 'projectedAt'),
      pool: LoopV2Launch2PoolCodec.summary(map['pool']),
      tradingHold: tradingHold(map['tradingHold']),
    );
  }

  /// `instance.tradingHold` (decision 0161). Absent or `null` means no hold;
  /// a value this build cannot read (unknown kind, not an object) is also
  /// read as none rather than failing the whole page — the server still
  /// refuses the writes with `LAUNCH2_USD1_PAUSED` / `LAUNCH2_ADDRESS_FROZEN`.
  static Launch2TradingHold? tradingHold(Object? raw) {
    if (raw is! Map) return null;
    final kind = Launch2TradingHoldKind.tryParse(raw['kind']);
    if (kind == null) return null;
    final since = raw['since'];
    final parsed = since is String && since.length <= 64
        ? DateTime.tryParse(since)?.toUtc()
        : null;
    return Launch2TradingHold(kind: kind, since: parsed);
  }

  // -------------------------------------------------------------------------
  // quote
  // -------------------------------------------------------------------------

  /// `GET …/quote`. The answer must be for the instance, side and wallet that
  /// were asked about.
  static Launch2Quote quote(
    Object? raw, {
    required String instanceId,
    required Launch2Side side,
    required String walletId,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'quote',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final map = LoopV2Contract.strictMap(root['quote'], quoteKeys);
    final rawSide = map['side'];
    final parsedSide = rawSide is String ? Launch2Side.tryParse(rawSide) : null;
    if (parsedSide != side ||
        uuid(map, 'instanceId') != instanceId ||
        uuid(map, 'walletId') != walletId) {
      invalid();
    }
    final max = LoopV2Contract.strictMap(map['max'], const <String>{
      'amountIn',
      'amountOut',
      'limitedBy',
    });
    final rawLimited = max['limitedBy'];
    final limitedBy = rawLimited is String
        ? Launch2LimitedBy.tryParse(rawLimited)
        : null;
    if (limitedBy == null) invalid();
    final quota = LoopV2Contract.strictMap(map['quota'], const <String>{
      'capMeme',
      'usedMeme',
      'remainingMeme',
    });
    final inventory = LoopV2Contract.strictMap(map['inventory'], const <String>{
      'saleSupply',
      'soldSupply',
      'remainingMeme',
    });
    final eligibility = LoopV2Contract.strictMap(
      map['eligibility'],
      const <String>{'required', 'eligible', 'reasonCode'},
    );
    final eligible = eligibility['eligible'];
    if (eligible != null && eligible is! bool) invalid();
    final basis = LoopV2Contract.strictMap(map['basis'], const <String>{
      'blockNumber',
      'blockHash',
    });
    hash(basis, 'blockHash');
    amount(inventory, 'saleSupply');
    amount(inventory, 'soldSupply');
    return Launch2Quote(
      instanceId: instanceId,
      walletId: walletId,
      side: side,
      stage: stage(map, 'stage'),
      requestedAmount: amount(map, 'requestedAmount'),
      exceedsMax: LoopV2ChainCodec.requireBool(map, 'exceedsMax'),
      amountIn: amount(map, 'amountIn'),
      maxIn: amount(map, 'maxIn'),
      expectedOut: amount(map, 'expectedOut'),
      minOut: amount(map, 'minOut'),
      slippageBps: LoopV2ChainCodec.requireInt(
        map,
        'slippageBps',
        maximum: 5000,
      ),
      taxUsd1: amount(map, 'taxUsd1'),
      taxBps: bps(map, 'taxBps'),
      refundUsd1: amount(map, 'refundUsd1'),
      priceBeforeUsd1: amount(map, 'priceBeforeUsd1'),
      priceAfterUsd1: amount(map, 'priceAfterUsd1'),
      maxAmountIn: amount(max, 'amountIn'),
      maxAmountOut: amount(max, 'amountOut'),
      limitedBy: limitedBy,
      quotaCap: amount(quota, 'capMeme'),
      quotaUsed: amount(quota, 'usedMeme'),
      quotaRemaining: amount(quota, 'remainingMeme'),
      inventoryRemaining: amount(inventory, 'remainingMeme'),
      eligibilityRequired: LoopV2ChainCodec.requireBool(
        eligibility,
        'required',
      ),
      eligible: eligible as bool?,
      eligibilityReasonCode: reasonCode(eligibility, 'reasonCode'),
      deadline: LoopV2ChainCodec.requireTimestamp(map, 'deadline'),
      quotedAt: LoopV2ChainCodec.requireTimestamp(map, 'quotedAt'),
      basisBlockNumber: integer(basis, 'blockNumber'),
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
      to: anyCaseAddress(map, 'to'),
      data: LoopV2ChainCodec.requireString(
        map,
        'data',
        pattern: hexDataPattern,
        maxLength: 100000,
      ),
    );
  }

  static Launch2UnsignedTransaction _transaction(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, transactionKeys);
    final chain = map['chainId'];
    if (chain != 56 && chain != 97) invalid();
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
    if (type == 'legacy' && map['gasPrice'] == null) invalid();
    if (type == 'eip1559' &&
        (map['maxFeePerGas'] == null || map['maxPriorityFeePerGas'] == null)) {
      invalid();
    }
    final data = LoopV2ChainCodec.requireString(
      map,
      'data',
      pattern: hexDataPattern,
      maxLength: 100000,
    );
    return Launch2UnsignedTransaction(
      chainId: chain! as int,
      to: anyCaseAddress(map, 'to'),
      data: data,
      from: anyCaseAddress(map, 'from'),
      wire: Map<String, Object?>.unmodifiable(map),
    );
  }

  /// `POST …/nft/prepare` and `POST …/trade/prepare`.
  static Launch2Intent intent(Object? raw) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'launch2Intent',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    return intentBody(root['launch2Intent']);
  }

  /// One `launch2Intent` object. [venue] and [taxBps] are what the route it
  /// came from says (decision 0145): the pool prepare answers the same
  /// object next to its quote.
  static Launch2Intent intentBody(
    Object? raw, {
    Launch2Venue venue = Launch2Venue.curve,
    int? taxBps,
    Decimal? taxMeme,
    int? dynamicTaxBps,
  }) {
    final map = LoopV2Contract.strictMap(raw, intentKeys);
    final rawKind = map['kind'];
    // The pool route answers `pool_buy` / `pool_sell` (loop-api S146) and
    // no other kind; the curve routes never answer those two.
    final kind = switch ((venue, rawKind)) {
      (Launch2Venue.officialPool, 'pool_buy') => Launch2IntentKind.buy,
      (Launch2Venue.officialPool, 'pool_sell') => Launch2IntentKind.sell,
      (Launch2Venue.officialPool, _) => null,
      // Decision 0157: the claim route answers one kind, no other route
      // answers it.
      (Launch2Venue.loopDynamicRewards, 'dynamic_claim') =>
        Launch2IntentKind.rewardClaim,
      (Launch2Venue.loopDynamicRewards, _) => null,
      (Launch2Venue.curve, final String value) =>
        switch (Launch2IntentKind.tryParse(value)) {
          Launch2IntentKind.rewardClaim => null,
          final parsed => parsed,
        },
      (Launch2Venue.curve, _) => null,
    };
    final state = map['state'];
    if (kind == null || (state != 'prepared' && state != 'expired')) invalid();
    final chain = chainId(map, 'chainId');
    final reference = map['chainReference'];
    if (reference != 56 && reference != 97) invalid();
    if (chain != 'eip155:$reference') invalid();
    final contractAddress = address(map, 'contractAddress');
    final calldata = _calldata(map['calldata']);
    final transaction = _transaction(map['unsignedTransaction']);
    Launch2Approval? approval;
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
      approval = Launch2Approval(
        token: anyCaseAddress(a, 'token'),
        spender: anyCaseAddress(a, 'spender'),
        amount: amount(a, 'amount'),
        unsignedTransaction: approvalTransaction,
      );
      approvalMatches =
          approvalTransaction.to == approval.token &&
          approvalCalldata.to == approval.token &&
          approvalTransaction.data == approvalCalldata.data &&
          approvalTransaction.chainId == reference &&
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
    if (policy['priceSource'] != 'usd1_par') invalid();
    for (final key in const <String>['configVersion', 'canaryMaxUsd']) {
      final value = policy[key];
      if (value is! String || value.isEmpty || value.length > 64) invalid();
    }
    final valueUsd = policy['valueUsd'];
    if (valueUsd is! String || !amountPattern.hasMatch(valueUsd)) invalid();
    final signing = LoopV2Contract.strictMap(map['signing'], const <String>{
      'mode',
      'allowed',
      'reasonCode',
    });
    if (signing['mode'] != 'device_eth_send_transaction') invalid();
    hash(map, 'snapshotBlockHash');
    final mainMatches =
        transaction.to == contractAddress &&
        calldata.to == contractAddress &&
        transaction.data == calldata.data &&
        transaction.chainId == reference;
    return Launch2Intent(
      intentId: uuid(map, 'intentId'),
      kind: kind,
      expired: state == 'expired',
      instanceId: uuid(map, 'instanceId'),
      walletId: uuid(map, 'walletId'),
      chainId: chain,
      contractAddress: contractAddress,
      amountIn: amount(map, 'amountIn'),
      expectedOut: amount(map, 'expectedOut'),
      minOut: amount(map, 'minOut'),
      taxUsd1: amount(map, 'taxUsd1'),
      refundUsd1: amount(map, 'refundUsd1'),
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
      snapshotBlockNumber: integer(map, 'snapshotBlockNumber'),
      simulationStatus: simulationStatus! as String,
      simulationReasonCode: reasonCode(simulation, 'reasonCode'),
      valueUsd: valueUsd,
      signingAllowed: LoopV2ChainCodec.requireBool(signing, 'allowed'),
      signingReasonCode: reasonCode(signing, 'reasonCode'),
      payloadMatchesReview: mainMatches && approvalMatches,
      venue: venue,
      taxBps: taxBps,
      taxMeme: taxMeme,
      dynamicTaxBps: dynamicTaxBps,
    );
  }

  // -------------------------------------------------------------------------
  // buybacks and positions
  // -------------------------------------------------------------------------

  /// `GET …/buybacks`.
  static Launch2BuybackPage buybacks(
    Object? raw, {
    required String instanceId,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'instanceId',
      'summary',
      'live',
      'liveUnavailable',
      'buybacks',
      'nextCursor',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    if (uuid(root, 'instanceId') != instanceId) invalid();
    Launch2BuybackLive? live;
    if (root['live'] != null) {
      final map = LoopV2Contract.strictMap(root['live'], buybackLiveKeys);
      final next = map['nextOrderUsd1'];
      live = Launch2BuybackLive(
        paused: LoopV2ChainCodec.requireBool(map, 'paused'),
        lastSuccessfulAt: LoopV2ChainCodec.optionalTimestamp(
          map,
          'lastSuccessfulAt',
        ),
        escrowRecordedUsd1: amount(map, 'escrowRecordedUsd1'),
        escrowSpentUsd1: amount(map, 'escrowSpentUsd1'),
        escrowAvailableUsd1: amount(map, 'escrowAvailableUsd1'),
        nextOrderUsd1: next == null ? null : amount(map, 'nextOrderUsd1'),
        nextOrderBlockedReason: reasonCode(map, 'nextOrderBlockedReason'),
      );
    }
    String? liveUnavailable;
    if (root['liveUnavailable'] != null) {
      final map = LoopV2Contract.strictMap(
        root['liveUnavailable'],
        const <String>{'reasonCode'},
      );
      liveUnavailable = LoopV2ChainCodec.requireReasonCode(map, 'reasonCode');
    }
    // Exactly one of the two answers the live read.
    if ((live == null) == (liveUnavailable == null)) invalid();
    final items = LoopV2ChainCodec.requireList(root['buybacks'], maximum: 100);
    return Launch2BuybackPage(
      instanceId: instanceId,
      summary: _buybackSummary(root['summary']),
      live: live,
      liveUnavailableReason: liveUnavailable,
      buybacks: List<Launch2BuybackRecord>.unmodifiable(<Launch2BuybackRecord>[
        for (final item in items) _buybackRecord(item),
      ]),
      nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
    );
  }

  /// `GET /v2/launch2/me/positions`.
  static Launch2Positions positions(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'positions',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final items = LoopV2ChainCodec.requireList(root['positions'], maximum: 500);
    return Launch2Positions(
      items: List<Launch2Position>.unmodifiable(<Launch2Position>[
        for (final item in items) _position(item, mediaUrl: mediaUrl),
      ]),
    );
  }

  static Launch2Position _position(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      positionKeys,
      walletHoldingKeys,
    );
    final nft = _nftHolding(map['nft']);
    return Launch2Position(
      instanceId: uuid(map, 'instanceId'),
      name: LoopV2ChainCodec.providerText(map, 'name', maxLength: 64),
      ticker: LoopV2ChainCodec.providerText(
        map,
        'ticker',
        maxLength: loopTokenTextMaxUnits,
        keepEmojiJoiners: true,
      ),
      logoUrl: logoUrl(map, 'logoUrl', mediaUrl: mediaUrl),
      memeAddress: address(map, 'memeAddress'),
      stage: stage(map, 'stage'),
      walletId: uuid(map, 'walletId'),
      mintedTokenId: nft.mintedTokenId,
      nftHeld: nft.held,
      snapshotMember: LoopV2ChainCodec.requireBool(map, 'snapshotMember'),
      curve: curvePosition(map['curve']),
      lastActivityAt: LoopV2ChainCodec.optionalTimestamp(map, 'lastActivityAt'),
      holding: walletHolding(map),
    );
  }
}
