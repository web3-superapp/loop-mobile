import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';

abstract interface class LoopPerpRepository {
  Future<PerpWalletBinding> getWalletBinding({required String accessToken});

  Future<PerpWalletBinding> bindWallet({
    required String accessToken,
    required String expectedBindingVersion,
  });

  Future<PerpWalletBinding> unbindWallet({
    required String accessToken,
    required String expectedBindingVersion,
  });

  Future<PerpConfig> getConfig({required String accessToken});

  Future<PerpAccount> getAccount({required String accessToken});

  Future<PerpPage<PerpPosition>> listPositions({
    required String accessToken,
    int? limit,
    String? cursor,
  });

  Future<PerpPage<PerpOrder>> listOrders({
    required String accessToken,
    int? limit,
    String? cursor,
  });

  Future<PerpPage<PerpFill>> listFills({
    required String accessToken,
    int? limit,
    String? cursor,
  });

  Future<PerpPage<PerpFundingEntry>> listFunding({
    required String accessToken,
    int? limit,
    String? cursor,
  });
}

/// Strict native adapter for LOOP's private Testnet Core-perpetual reads.
///
/// This repository neither owns token refresh nor retries a 401. Every method
/// receives one current access token for one immediate request.
final class DioLoopPerpRepository implements LoopPerpRepository {
  DioLoopPerpRepository(this._dio, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const walletBindingPath = '/v1/perp/wallet-binding';
  static const configPath = '/v1/perp/config';
  static const accountPath = '/v1/perp/account';
  static const positionsPath = '/v1/perp/positions';
  static const ordersPath = '/v1/perp/orders';
  static const fillsPath = '/v1/perp/fills';
  static const fundingPath = '/v1/perp/funding';

  static final BigInt _maximumBindingVersion = BigInt.parse(
    '9223372036854775807',
  );
  static final BigInt _maximumUnsigned64 = BigInt.parse('18446744073709551615');
  static const _positionsDefaultLimit = 3;
  static const _positionsMaximumLimit = 3;
  static const _privateListDefaultLimit = 20;
  static const _privateListMaximumLimit = 50;
  static const _walletBindingReadConflictCodes = <String>{'bootstrap_required'};
  static const _walletBindingMutationConflictCodes = <String>{
    'bootstrap_required',
    'version_conflict',
    'wallet_binding_required',
  };
  static const _privateReadConflictCodes = <String>{
    'bootstrap_required',
    'wallet_binding_required',
  };

  static final RegExp _bindingVersionPattern = RegExp(
    r'^(?:0|[1-9][0-9]{0,18})$',
  );
  static final RegExp _decimalPattern = RegExp(
    r'^(?:(?:0|[1-9][0-9]*)(?:\.[0-9]+)?|-(?:[1-9][0-9]*(?:\.[0-9]+)?|0\.[0-9]*[1-9][0-9]*))$',
  );
  static final RegExp _positiveDecimalPattern = RegExp(
    r'^(?:[1-9][0-9]*(?:\.[0-9]+)?|0\.[0-9]*[1-9][0-9]*)$',
  );
  static final RegExp _positiveIntegerPattern = RegExp(r'^[1-9][0-9]{0,18}$');
  static final RegExp _unsignedIntegerPattern = RegExp(
    r'^(?:0|[1-9][0-9]{0,19})$',
  );
  static final RegExp _clientOrderIdPattern = RegExp(r'^0x[0-9a-f]{32}$');
  static final RegExp _transactionHashPattern = RegExp(r'^0x[0-9a-f]{64}$');
  static final RegExp _cursorPattern = RegExp(
    r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
  );
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _rfc3339Pattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(?:Z|[+-](\d{2}):(\d{2}))$',
  );
  static final Set<String> _stableErrorCodes = <String>{
    'authentication_required',
    'invalid_access_token',
    'invalid_request',
    'bootstrap_required',
    'wallet_binding_required',
    'version_conflict',
    'authentication_unavailable',
    'perp_unavailable',
    'request_timeout',
    'internal_error',
  };

  final Dio _dio;
  final DateTime Function() _now;

  @override
  Future<PerpWalletBinding> getWalletBinding({
    required String accessToken,
  }) async {
    _validateAccessToken(accessToken);
    late final Response<Object?> response;
    try {
      response = await _dio.get<Object?>(
        walletBindingPath,
        options: _options(accessToken),
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error, _walletBindingReadConflictCodes);
    }
    return _parseSuccess(response, _parseWalletBinding);
  }

  @override
  Future<PerpWalletBinding> bindWallet({
    required String accessToken,
    required String expectedBindingVersion,
  }) async {
    _validateAccessToken(accessToken);
    _validateBindingVersionInput(expectedBindingVersion);
    late final Response<Object?> response;
    try {
      response = await _dio.put<Object?>(
        walletBindingPath,
        data: <String, String>{
          'expected_binding_version': expectedBindingVersion,
        },
        options: _options(accessToken, sendsJson: true),
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error, _walletBindingMutationConflictCodes);
    }
    return _parseBindingMutationSuccess(
      response,
      expectedBindingVersion: expectedBindingVersion,
      expectedState: PerpWalletBindingState.bound,
    );
  }

  @override
  Future<PerpWalletBinding> unbindWallet({
    required String accessToken,
    required String expectedBindingVersion,
  }) async {
    _validateAccessToken(accessToken);
    _validateBindingVersionInput(expectedBindingVersion);
    late final Response<Object?> response;
    try {
      response = await _dio.delete<Object?>(
        walletBindingPath,
        queryParameters: <String, String>{
          'expected_binding_version': expectedBindingVersion,
        },
        options: _options(accessToken),
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error, _walletBindingMutationConflictCodes);
    }
    return _parseBindingMutationSuccess(
      response,
      expectedBindingVersion: expectedBindingVersion,
      expectedState: PerpWalletBindingState.unbound,
    );
  }

  @override
  Future<PerpConfig> getConfig({required String accessToken}) async {
    _validateAccessToken(accessToken);
    late final Response<Object?> response;
    try {
      response = await _dio.get<Object?>(
        configPath,
        options: _options(accessToken),
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error, _privateReadConflictCodes);
    }
    return _parseSuccess(response, _parseConfig);
  }

  @override
  Future<PerpAccount> getAccount({required String accessToken}) async {
    _validateAccessToken(accessToken);
    late final Response<Object?> response;
    try {
      response = await _dio.get<Object?>(
        accountPath,
        options: _options(accessToken),
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error, _privateReadConflictCodes);
    }
    return _parseSuccess(response, _parseAccount);
  }

  @override
  Future<PerpPage<PerpPosition>> listPositions({
    required String accessToken,
    int? limit,
    String? cursor,
  }) => _fetchList(
    accessToken: accessToken,
    path: positionsPath,
    dataset: PerpSourceDataset.positions,
    maximumLimit: _positionsMaximumLimit,
    defaultLimit: _positionsDefaultLimit,
    limit: limit,
    cursor: cursor,
    itemParser: _parsePosition,
  );

  @override
  Future<PerpPage<PerpOrder>> listOrders({
    required String accessToken,
    int? limit,
    String? cursor,
  }) => _fetchList(
    accessToken: accessToken,
    path: ordersPath,
    dataset: PerpSourceDataset.orders,
    maximumLimit: _privateListMaximumLimit,
    defaultLimit: _privateListDefaultLimit,
    limit: limit,
    cursor: cursor,
    itemParser: _parseOrder,
  );

  @override
  Future<PerpPage<PerpFill>> listFills({
    required String accessToken,
    int? limit,
    String? cursor,
  }) => _fetchList(
    accessToken: accessToken,
    path: fillsPath,
    dataset: PerpSourceDataset.fills,
    maximumLimit: _privateListMaximumLimit,
    defaultLimit: _privateListDefaultLimit,
    limit: limit,
    cursor: cursor,
    includeCoverage: true,
    itemParser: _parseFill,
  );

  @override
  Future<PerpPage<PerpFundingEntry>> listFunding({
    required String accessToken,
    int? limit,
    String? cursor,
  }) => _fetchList(
    accessToken: accessToken,
    path: fundingPath,
    dataset: PerpSourceDataset.funding,
    maximumLimit: _privateListMaximumLimit,
    defaultLimit: _privateListDefaultLimit,
    limit: limit,
    cursor: cursor,
    includeCoverage: true,
    itemParser: _parseFunding,
  );

  Future<PerpPage<T>> _fetchList<T>({
    required String accessToken,
    required String path,
    required PerpSourceDataset dataset,
    required int maximumLimit,
    required int defaultLimit,
    required int? limit,
    required String? cursor,
    required T Function(Map<String, Object?>) itemParser,
    bool includeCoverage = false,
  }) async {
    _validateAccessToken(accessToken);
    final query = _listQuery(
      maximumLimit: maximumLimit,
      limit: limit,
      cursor: cursor,
    );
    late final Response<Object?> response;
    try {
      response = await _dio.get<Object?>(
        path,
        queryParameters: query,
        options: _options(accessToken),
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error, _privateReadConflictCodes);
    }
    return _parseSuccess(
      response,
      (payload) => _parsePage<T>(
        payload,
        dataset: dataset,
        maximumItems: maximumLimit,
        requestedLimit: cursor == null ? (limit ?? defaultLimit) : null,
        includeCoverage: includeCoverage,
        itemParser: itemParser,
      ),
    );
  }

  Options _options(String accessToken, {bool sendsJson = false}) => Options(
    headers: <String, String>{
      'authorization': 'Bearer $accessToken',
      'accept': Headers.jsonContentType,
    },
    contentType: sendsJson ? Headers.jsonContentType : null,
    followRedirects: false,
    responseType: ResponseType.json,
  );

  T _parseSuccess<T>(Response<Object?> response, T Function(Object?) parser) {
    if (response.statusCode != 200 ||
        !_hasNoStore(response.headers) ||
        _requestIdHeader(response.headers) == null) {
      return _invalidPayload();
    }
    return parser(response.data);
  }

  PerpWalletBinding _parseBindingMutationSuccess(
    Response<Object?> response, {
    required String expectedBindingVersion,
    required PerpWalletBindingState expectedState,
  }) {
    final binding = _parseSuccess(response, _parseWalletBinding);
    final expected = BigInt.parse(expectedBindingVersion);
    final observed = BigInt.parse(binding.bindingVersion);
    if (binding.state != expectedState ||
        (observed != expected && observed != expected + BigInt.one)) {
      return _invalidPayload();
    }
    return binding;
  }

  PerpWalletBinding _parseWalletBinding(Object? payload) {
    final root = _strictMap(payload, const <String>{
      'state',
      'binding_version',
      'account_kind',
      'last_verified_at',
    });
    final state = switch (root['state']) {
      'bound' => PerpWalletBindingState.bound,
      'unbound' => PerpWalletBindingState.unbound,
      _ => _invalidPayload<PerpWalletBindingState>(),
    };
    final bindingVersion = _bindingVersion(root['binding_version']);
    final accountKind = switch (root['account_kind']) {
      'master' => PerpAccountKind.master,
      null => null,
      _ => _invalidPayload<PerpAccountKind?>(),
    };
    final rawVerifiedAt = root['last_verified_at'];
    final lastVerifiedAt = rawVerifiedAt == null
        ? null
        : _timestamp(rawVerifiedAt);
    if ((state == PerpWalletBindingState.unbound &&
            (accountKind != null || lastVerifiedAt != null)) ||
        (state == PerpWalletBindingState.bound &&
            (bindingVersion == '0' ||
                accountKind != PerpAccountKind.master ||
                lastVerifiedAt == null))) {
      return _invalidPayload();
    }
    return PerpWalletBinding(
      state: state,
      bindingVersion: bindingVersion,
      accountKind: accountKind,
      lastVerifiedAt: lastVerifiedAt,
    );
  }

  PerpConfig _parseConfig(Object? payload) {
    final root = _strictMap(payload, const <String>{
      'scope',
      'assets',
      'fees',
      'capabilities',
      'source',
    });
    final scopeMap = _strictMap(root['scope'], const <String>{
      'network',
      'market',
      'dex',
      'coins',
    });
    if (scopeMap['network'] != 'testnet' ||
        scopeMap['market'] != 'core_perps' ||
        scopeMap['dex'] != '') {
      return _invalidPayload();
    }
    final scopeCoins = _wireList(scopeMap['coins']);
    if (!_wireCoinsMatch(scopeCoins)) return _invalidPayload();

    final rawAssets = _wireList(root['assets']);
    if (rawAssets.length != 3) return _invalidPayload();
    final assets = <PerpAssetConfig>[];
    for (var index = 0; index < rawAssets.length; index += 1) {
      final asset = _parseAsset(
        _strictMap(rawAssets[index], const <String>{
          'coin',
          'size_decimals',
          'size_increment',
          'max_leverage',
          'margin_mode',
          'minimum_order_notional_usdc',
        }),
      );
      if (asset.coin != PerpCoin.values[index]) return _invalidPayload();
      assets.add(asset);
    }

    final feeMap = _strictMap(root['fees'], const <String>{
      'maker_rate',
      'taker_rate',
    });
    final capabilityMap = _strictMap(root['capabilities'], const <String>{
      'private_reads',
      'trading_mutations',
    });
    if (capabilityMap['private_reads'] != 'available' ||
        capabilityMap['trading_mutations'] != 'disabled') {
      return _invalidPayload();
    }
    return PerpConfig(
      scope: PerpScope(coins: PerpCoin.values),
      assets: assets,
      fees: PerpFees(
        makerRate: _decimalFact(feeMap['maker_rate']),
        takerRate: _decimalFact(feeMap['taker_rate']),
      ),
      capabilities: const PerpCapabilities(
        privateReadsAvailable: true,
        tradingMutationsEnabled: false,
      ),
      source: _source(root['source'], PerpSourceDataset.config),
    );
  }

  PerpAssetConfig _parseAsset(Map<String, Object?> map) {
    final sizeDecimals = map['size_decimals'];
    if (sizeDecimals is! int || sizeDecimals < 0 || sizeDecimals > 18) {
      return _invalidPayload();
    }
    final marginMode = switch (map['margin_mode']) {
      'cross_and_isolated' => PerpMarginMode.crossAndIsolated,
      'isolated_only' => PerpMarginMode.isolatedOnly,
      _ => _invalidPayload<PerpMarginMode>(),
    };
    return PerpAssetConfig(
      coin: _coin(map['coin']),
      sizeDecimals: sizeDecimals,
      sizeIncrement: _decimal(map['size_increment'], positive: true),
      maxLeverage: _decimal(map['max_leverage'], positiveInteger: true),
      marginMode: marginMode,
      minimumOrderNotionalUsdc: _decimalFact(
        map['minimum_order_notional_usdc'],
        positive: true,
      ),
    );
  }

  PerpAccount _parseAccount(Object? payload) {
    final root = _strictMap(payload, const <String>{
      'margin_summary',
      'cross_margin_summary',
      'withdrawable',
      'cross_maintenance_margin_used',
      'source',
    });
    return PerpAccount(
      marginSummary: _marginSummary(root['margin_summary']),
      crossMarginSummary: _marginSummary(root['cross_margin_summary']),
      withdrawable: _decimal(root['withdrawable']),
      crossMaintenanceMarginUsed: _nullableDecimal(
        root['cross_maintenance_margin_used'],
      ),
      source: _source(root['source'], PerpSourceDataset.account),
    );
  }

  PerpMarginSummary _marginSummary(Object? payload) {
    final map = _strictMap(payload, const <String>{
      'account_value',
      'total_margin_used',
      'total_notional_position',
      'total_raw_usd',
    });
    return PerpMarginSummary(
      accountValue: _decimal(map['account_value']),
      totalMarginUsed: _decimal(map['total_margin_used']),
      totalNotionalPosition: _decimal(map['total_notional_position']),
      totalRawUsd: _decimal(map['total_raw_usd']),
    );
  }

  PerpPage<T> _parsePage<T>(
    Object? payload, {
    required PerpSourceDataset dataset,
    required int maximumItems,
    required int? requestedLimit,
    required bool includeCoverage,
    required T Function(Map<String, Object?>) itemParser,
  }) {
    final expectedKeys = <String>{
      'items',
      if (includeCoverage) 'coverage',
      'source',
      'next_cursor',
    };
    final root = _strictMap(payload, expectedKeys);
    final source = _source(root['source'], dataset);
    final coverage = includeCoverage
        ? _coverage(root['coverage'], source)
        : null;
    final rawItems = _wireList(root['items']);
    if (rawItems.length > maximumItems ||
        (requestedLimit != null && rawItems.length > requestedLimit)) {
      return _invalidPayload();
    }
    final items = rawItems
        .map((item) => itemParser(_strictMapForItem(item)))
        .toList(growable: false);
    final nextCursor = _nullableCursor(root['next_cursor']);
    if (nextCursor != null &&
        requestedLimit != null &&
        items.length != requestedLimit) {
      return _invalidPayload();
    }
    switch (dataset) {
      case PerpSourceDataset.positions:
        _validatePositionOrder(items.cast<PerpPosition>());
      case PerpSourceDataset.orders:
        _validateOrders(items.cast<PerpOrder>(), source);
      case PerpSourceDataset.fills:
        _validateFills(items.cast<PerpFill>(), coverage ?? _invalidPayload());
      case PerpSourceDataset.funding:
        _validateFunding(
          items.cast<PerpFundingEntry>(),
          coverage ?? _invalidPayload(),
        );
      case PerpSourceDataset.config || PerpSourceDataset.account:
        return _invalidPayload();
    }
    return PerpPage<T>(
      items: items,
      source: source,
      nextCursor: nextCursor,
      coverage: coverage,
    );
  }

  Map<String, Object?> _strictMapForItem(Object? value) {
    if (value is! Map) return _invalidPayload();
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String || result.containsKey(entry.key)) {
        return _invalidPayload();
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  PerpPosition _parsePosition(Map<String, Object?> loose) {
    final map = _strictMap(loose, const <String>{
      'coin',
      'side',
      'size',
      'entry_price',
      'leverage',
      'liquidation_price',
      'margin_used',
      'position_value',
      'return_on_equity',
      'unrealized_pnl',
      'position_mode',
    });
    final leverage = _strictMap(map['leverage'], const <String>{
      'mode',
      'value',
      'raw_usd',
    });
    return PerpPosition(
      coin: _coin(map['coin']),
      side: switch (map['side']) {
        'long' => PerpPositionSide.long,
        'short' => PerpPositionSide.short,
        _ => _invalidPayload<PerpPositionSide>(),
      },
      size: _decimal(map['size'], positive: true),
      entryPrice: _nullableDecimal(map['entry_price']),
      leverage: PerpLeverage(
        mode: switch (leverage['mode']) {
          'cross' => PerpLeverageMode.cross,
          'isolated' => PerpLeverageMode.isolated,
          _ => _invalidPayload<PerpLeverageMode>(),
        },
        value: _decimal(leverage['value'], positiveInteger: true),
        rawUsd: _nullableDecimal(leverage['raw_usd']),
      ),
      liquidationPrice: _nullableDecimal(map['liquidation_price']),
      marginUsed: _decimal(map['margin_used']),
      positionValue: _decimal(map['position_value']),
      returnOnEquity: _decimal(map['return_on_equity']),
      unrealizedPnl: _decimal(map['unrealized_pnl']),
      positionMode: map['position_mode'] == 'one_way'
          ? PerpPositionMode.oneWay
          : _invalidPayload(),
    );
  }

  PerpOrder _parseOrder(Map<String, Object?> loose) {
    final map = _strictMap(loose, const <String>{
      'order_id',
      'client_order_id',
      'coin',
      'side',
      'order_type',
      'time_in_force',
      'limit_price',
      'original_size',
      'remaining_size',
      'reduce_only',
      'status',
      'created_at',
      'status_at',
    });
    final reduceOnly = map['reduce_only'];
    if (reduceOnly is! bool) return _invalidPayload();
    final clientOrderId = map['client_order_id'];
    if (clientOrderId != null &&
        (clientOrderId is! String ||
            !_clientOrderIdPattern.hasMatch(clientOrderId))) {
      return _invalidPayload();
    }
    return PerpOrder(
      orderId: _unsigned64(map['order_id']),
      clientOrderId: clientOrderId as String?,
      coin: _coin(map['coin']),
      side: _orderSide(map['side']),
      orderType: map['order_type'] == 'limit'
          ? PerpOrderType.limit
          : _invalidPayload(),
      timeInForce: switch (map['time_in_force']) {
        'gtc' => PerpTimeInForce.gtc,
        'alo' => PerpTimeInForce.alo,
        'ioc' => PerpTimeInForce.ioc,
        _ => _invalidPayload<PerpTimeInForce>(),
      },
      limitPrice: _decimal(map['limit_price'], positive: true),
      originalSize: _decimal(map['original_size'], positive: true),
      remainingSize: _decimal(map['remaining_size'], positive: true),
      reduceOnly: reduceOnly,
      status: map['status'] == 'open'
          ? PerpOrderStatus.open
          : _invalidPayload(),
      createdAt: _timestamp(map['created_at']),
      statusAt: _timestamp(map['status_at']),
    );
  }

  PerpFill _parseFill(Map<String, Object?> loose) {
    final map = _strictMap(loose, const <String>{
      'trade_id',
      'order_id',
      'transaction_hash',
      'coin',
      'side',
      'price',
      'size',
      'start_position',
      'closed_pnl',
      'fee',
      'fee_asset',
      'crossed',
      'filled_at',
    });
    final crossed = map['crossed'];
    if (crossed is! bool) return _invalidPayload();
    return PerpFill(
      tradeId: _unsigned64(map['trade_id']),
      orderId: _unsigned64(map['order_id']),
      transactionHash: _transactionHash(map['transaction_hash']),
      coin: _coin(map['coin']),
      side: _orderSide(map['side']),
      price: _decimal(map['price'], positive: true),
      size: _decimal(map['size'], positive: true),
      startPosition: _decimal(map['start_position']),
      closedPnl: _decimal(map['closed_pnl']),
      fee: _decimal(map['fee']),
      feeAsset: map['fee_asset'] == 'USDC'
          ? PerpFeeAsset.usdc
          : _invalidPayload(),
      crossed: crossed,
      filledAt: _timestamp(map['filled_at']),
    );
  }

  PerpFundingEntry _parseFunding(Map<String, Object?> loose) {
    final map = _strictMap(loose, const <String>{
      'transaction_hash',
      'coin',
      'funding_rate',
      'position_size',
      'payment_usdc',
      'settled_at',
    });
    return PerpFundingEntry(
      transactionHash: _transactionHash(map['transaction_hash']),
      coin: _coin(map['coin']),
      fundingRate: _decimal(map['funding_rate']),
      positionSize: _decimal(map['position_size']),
      paymentUsdc: _decimal(map['payment_usdc']),
      settledAt: _timestamp(map['settled_at']),
    );
  }

  PerpDataSource _source(Object? payload, PerpSourceDataset dataset) {
    final map = _strictMap(payload, const <String>{
      'provider',
      'network',
      'market',
      'dex',
      'dataset',
      'fetched_at',
      'expires_at',
    });
    if (map['provider'] != 'hyperliquid' ||
        map['network'] != 'testnet' ||
        map['market'] != 'core_perps' ||
        map['dex'] != '' ||
        map['dataset'] != dataset.name) {
      return _invalidPayload();
    }
    final fetchedAt = _timestamp(map['fetched_at']);
    final expiresAt = _timestamp(map['expires_at']);
    final now = _now().toUtc();
    final maximumTtl = dataset == PerpSourceDataset.config
        ? const Duration(seconds: 60)
        : const Duration(seconds: 2);
    if (fetchedAt.isAfter(now) ||
        !expiresAt.isAfter(now) ||
        !expiresAt.isAfter(fetchedAt) ||
        expiresAt.difference(fetchedAt) > maximumTtl) {
      return _invalidPayload();
    }
    return PerpDataSource(
      dataset: dataset,
      fetchedAt: fetchedAt,
      expiresAt: expiresAt,
    );
  }

  PerpRecentWindowCoverage _coverage(Object? payload, PerpDataSource source) {
    final map = _strictMap(payload, const <String>{
      'kind',
      'started_at',
      'ended_at',
      'truncated',
    });
    final truncated = map['truncated'];
    if (map['kind'] != 'recent_window' || truncated is! bool) {
      return _invalidPayload();
    }
    final startedAt = _timestamp(map['started_at']);
    final endedAt = _timestamp(map['ended_at']);
    if (startedAt.isAfter(endedAt) || endedAt.isAfter(source.fetchedAt)) {
      return _invalidPayload();
    }
    return PerpRecentWindowCoverage(
      kind: PerpCoverageKind.recentWindow,
      startedAt: startedAt,
      endedAt: endedAt,
      truncated: truncated,
    );
  }

  void _validatePositionOrder(List<PerpPosition> items) {
    var previous = -1;
    for (final item in items) {
      final index = item.coin.index;
      if (index <= previous) return _invalidPayload();
      previous = index;
    }
  }

  void _validateOrders(List<PerpOrder> items, PerpDataSource source) {
    final orderIds = <String>{};
    final clientOrderIds = <String>{};
    DateTime? previousTime;
    BigInt? previousId;
    for (final item in items) {
      final id = BigInt.parse(item.orderId);
      if (!orderIds.add(item.orderId) ||
          (item.clientOrderId != null &&
              !clientOrderIds.add(item.clientOrderId!)) ||
          item.statusAt.isBefore(item.createdAt) ||
          item.createdAt.isAfter(source.fetchedAt) ||
          item.statusAt.isAfter(source.fetchedAt) ||
          item.remainingSize > item.originalSize ||
          (previousTime != null && item.createdAt.isAfter(previousTime)) ||
          (previousTime == item.createdAt &&
              previousId != null &&
              id >= previousId)) {
        return _invalidPayload();
      }
      previousTime = item.createdAt;
      previousId = id;
    }
  }

  void _validateFills(List<PerpFill> items, PerpRecentWindowCoverage coverage) {
    final ids = <String>{};
    DateTime? previousTime;
    BigInt? previousId;
    for (final item in items) {
      final id = BigInt.parse(item.tradeId);
      if (!ids.add(item.tradeId) ||
          item.filledAt.isBefore(coverage.startedAt) ||
          item.filledAt.isAfter(coverage.endedAt) ||
          (previousTime != null && item.filledAt.isAfter(previousTime)) ||
          (previousTime == item.filledAt &&
              previousId != null &&
              id >= previousId)) {
        return _invalidPayload();
      }
      previousTime = item.filledAt;
      previousId = id;
    }
  }

  void _validateFunding(
    List<PerpFundingEntry> items,
    PerpRecentWindowCoverage coverage,
  ) {
    final keys = <String>{};
    DateTime? previousTime;
    int? previousCoin;
    for (final item in items) {
      final key = '${item.transactionHash}\u0000${item.coin.name}';
      if (!keys.add(key) ||
          item.settledAt.isBefore(coverage.startedAt) ||
          item.settledAt.isAfter(coverage.endedAt) ||
          (previousTime != null && item.settledAt.isAfter(previousTime)) ||
          (previousTime == item.settledAt &&
              previousCoin != null &&
              item.coin.index <= previousCoin)) {
        return _invalidPayload();
      }
      previousTime = item.settledAt;
      previousCoin = item.coin.index;
    }
  }

  PerpDecimalFact _decimalFact(Object? payload, {bool positive = false}) {
    if (payload is! Map) return _invalidPayload();
    final state = payload['state'];
    if (state == 'unavailable') {
      _strictMap(payload, const <String>{'state'});
      return const PerpDecimalFact.unavailable();
    }
    if (state == 'available') {
      final map = _strictMap(payload, const <String>{'state', 'value'});
      return PerpDecimalFact.available(
        _decimal(map['value'], positive: positive),
      );
    }
    return _invalidPayload();
  }

  Decimal _nullableDecimalValue(Object? value) => _decimal(value);

  Decimal? _nullableDecimal(Object? value) =>
      value == null ? null : _nullableDecimalValue(value);

  Decimal _decimal(
    Object? value, {
    bool positive = false,
    bool positiveInteger = false,
  }) {
    if (value is! String || value.length > 128) return _invalidPayload();
    final pattern = positiveInteger
        ? _positiveIntegerPattern
        : positive
        ? _positiveDecimalPattern
        : _decimalPattern;
    if (!pattern.hasMatch(value)) return _invalidPayload();
    final parsed = Decimal.tryParse(value);
    return parsed ?? _invalidPayload();
  }

  String _bindingVersion(Object? value) {
    if (value is! String || !_bindingVersionPattern.hasMatch(value)) {
      return _invalidPayload();
    }
    final parsed = BigInt.tryParse(value);
    if (parsed == null || parsed > _maximumBindingVersion) {
      return _invalidPayload();
    }
    return value;
  }

  String _unsigned64(Object? value) {
    if (value is! String || !_unsignedIntegerPattern.hasMatch(value)) {
      return _invalidPayload();
    }
    final parsed = BigInt.tryParse(value);
    if (parsed == null || parsed > _maximumUnsigned64) {
      return _invalidPayload();
    }
    return value;
  }

  String _transactionHash(Object? value) {
    if (value is! String || !_transactionHashPattern.hasMatch(value)) {
      return _invalidPayload();
    }
    return value;
  }

  String? _nullableCursor(Object? value) {
    if (value == null) return null;
    if (value is! String ||
        value.length < 45 ||
        value.length > 1536 ||
        !_cursorPattern.hasMatch(value)) {
      return _invalidPayload();
    }
    return value;
  }

  DateTime _timestamp(Object? value) {
    if (value is! String) {
      return _invalidPayload();
    }
    final match = _rfc3339Pattern.firstMatch(value);
    if (match == null) return _invalidPayload();
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final offsetHour = int.tryParse(match.group(7) ?? '0')!;
    final offsetMinute = int.tryParse(match.group(8) ?? '0')!;
    final calendarDate = DateTime.utc(year, month, day);
    if (calendarDate.year != year ||
        calendarDate.month != month ||
        calendarDate.day != day ||
        hour > 23 ||
        minute > 59 ||
        second > 59 ||
        offsetHour > 23 ||
        offsetMinute > 59) {
      return _invalidPayload();
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return _invalidPayload();
    return parsed.toUtc();
  }

  PerpCoin _coin(Object? value) => switch (value) {
    'BTC' => PerpCoin.btc,
    'ETH' => PerpCoin.eth,
    'SOL' => PerpCoin.sol,
    _ => _invalidPayload<PerpCoin>(),
  };

  PerpOrderSide _orderSide(Object? value) => switch (value) {
    'buy' => PerpOrderSide.buy,
    'sell' => PerpOrderSide.sell,
    _ => _invalidPayload<PerpOrderSide>(),
  };

  bool _wireCoinsMatch(List<Object?> values) =>
      values.length == 3 &&
      values[0] == 'BTC' &&
      values[1] == 'ETH' &&
      values[2] == 'SOL';

  Map<String, Object?> _strictMap(Object? value, Set<String> expectedKeys) {
    if (value is! Map) return _invalidPayload();
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || result.containsKey(key)) {
        return _invalidPayload();
      }
      result[key] = entry.value;
    }
    if (result.length != expectedKeys.length ||
        !expectedKeys.every(result.containsKey)) {
      return _invalidPayload();
    }
    return result;
  }

  List<Object?> _wireList(Object? value) {
    if (value is! List) return _invalidPayload();
    return List<Object?>.of(value);
  }

  Map<String, Object?> _listQuery({
    required int maximumLimit,
    required int? limit,
    required String? cursor,
  }) {
    if ((limit != null && cursor != null) ||
        (limit != null && (limit < 1 || limit > maximumLimit)) ||
        (cursor != null &&
            (cursor.length < 45 ||
                cursor.length > 1536 ||
                !_cursorPattern.hasMatch(cursor)))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    if (limit != null) return <String, Object?>{'limit': limit};
    if (cursor != null) return <String, Object?>{'cursor': cursor};
    return const <String, Object?>{};
  }

  void _validateAccessToken(String accessToken) {
    if (accessToken.isEmpty || accessToken != accessToken.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
  }

  void _validateBindingVersionInput(String value) {
    try {
      _bindingVersion(value);
    } on LoopBackendFailure {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
  }

  bool _hasNoStore(Headers headers) {
    final directives = headers['cache-control']
        ?.expand((value) => value.split(','))
        .map((value) => value.trim().toLowerCase());
    return directives?.contains('no-store') ?? false;
  }

  String? _requestIdHeader(Headers headers) {
    final values = headers['x-request-id'];
    if (values == null || values.length != 1) return null;
    final value = values.single;
    return _uuidPattern.hasMatch(value) ? value : null;
  }

  LoopBackendFailure _mapDioFailure(
    DioException error,
    Set<String> allowedConflictCodes,
  ) {
    final statusCode = error.response?.statusCode;
    final metadata = _errorMetadata(error.response, allowedConflictCodes);
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => LoopBackendFailureKind.timeout,
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => LoopBackendFailureKind.connection,
      DioExceptionType.cancel => LoopBackendFailureKind.cancelled,
      DioExceptionType.badResponse when !metadata.valid =>
        LoopBackendFailureKind.invalidPayload,
      DioExceptionType.badResponse => switch (statusCode) {
        400 => LoopBackendFailureKind.invalidRequest,
        401 => LoopBackendFailureKind.authentication,
        409 when metadata.code != null => LoopBackendFailureKind.invalidRequest,
        503 when metadata.code == 'request_timeout' =>
          LoopBackendFailureKind.timeout,
        503 => LoopBackendFailureKind.unavailable,
        final status when status != null && status >= 500 =>
          LoopBackendFailureKind.unavailable,
        _ => LoopBackendFailureKind.unexpected,
      },
      DioExceptionType.unknown => LoopBackendFailureKind.unexpected,
    };
    return LoopBackendFailure(
      kind,
      statusCode: statusCode,
      code: metadata.valid ? metadata.code : null,
      requestId: metadata.valid ? metadata.requestId : null,
    );
  }

  ({bool valid, String? code, String? requestId}) _errorMetadata(
    Response<Object?>? response,
    Set<String> allowedConflictCodes,
  ) {
    if (response == null || !_hasNoStore(response.headers)) {
      return (valid: false, code: null, requestId: null);
    }
    final headerRequestId = _requestIdHeader(response.headers);
    final data = response.data;
    if (headerRequestId == null || data is! Map || data.length != 3) {
      return (valid: false, code: null, requestId: null);
    }
    final keys = data.keys;
    if (!keys.every((key) => key is String) ||
        !data.containsKey('code') ||
        !data.containsKey('message') ||
        !data.containsKey('request_id')) {
      return (valid: false, code: null, requestId: null);
    }
    final code = data['code'];
    final message = data['message'];
    final requestId = data['request_id'];
    if (code is! String ||
        !_stableErrorCodes.contains(code) ||
        message is! String ||
        message.isEmpty ||
        requestId is! String ||
        !_uuidPattern.hasMatch(requestId) ||
        requestId != headerRequestId ||
        !_codeMatchesStatus(response.statusCode, code, allowedConflictCodes)) {
      return (valid: false, code: null, requestId: null);
    }
    return (valid: true, code: code, requestId: requestId);
  }

  bool _codeMatchesStatus(
    int? statusCode,
    String code,
    Set<String> allowedConflictCodes,
  ) => switch (statusCode) {
    400 => code == 'invalid_request',
    401 => code == 'authentication_required' || code == 'invalid_access_token',
    409 => allowedConflictCodes.contains(code),
    500 => code == 'internal_error',
    503 =>
      code == 'authentication_unavailable' ||
          code == 'perp_unavailable' ||
          code == 'request_timeout',
    _ => false,
  };

  T _invalidPayload<T>() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
}
