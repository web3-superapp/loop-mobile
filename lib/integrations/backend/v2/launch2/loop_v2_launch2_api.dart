import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_candle_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';
import 'package:loop_mobile/integrations/backend/v2/media/loop_v2_media.dart';

/// Strict V2 transport for the `launch2` module (MEME v2; loop-api decision
/// 0114 / 0117, client decision 0139).
///
/// Reads carry no `Idempotency-Key`; the two prepares carry exactly one
/// canonical UUIDv4 per user action. Every success is checked for
/// `Cache-Control: no-store` and an `X-Request-ID`, and every refusal is read
/// against the route's own published catalogue (contract §4).
final class DioLoopV2Launch2Api {
  DioLoopV2Launch2Api(this._dio, {required this.mediaUrl});

  static const instancesPath = '/v2/launch2/instances';
  static const positionsPath = '/v2/launch2/me/positions';

  /// The four reads: list, detail, buybacks, positions.
  static const readErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED', 'REGION_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'DATA_STALE'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// Decision 0227 (loop-api S267): the K line read; an interval outside
  /// the six is `422 LAUNCH2_CANDLE_INTERVAL_INVALID`.
  static const candleErrors = <int, Set<String>>{
    ...readErrors,
    422: <String>{'LAUNCH2_CANDLE_INTERVAL_INVALID', 'VALIDATION_FAILED'},
  };

  /// The quote: a closed stage is `409 DATA_STALE`, a bad amount `422`.
  static const quoteErrors = <int, Set<String>>{
    ...readErrors,
    422: <String>{'VALIDATION_FAILED'},
  };

  /// The two prepares (contract §3.4–3.5, §4).
  static const writeErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'DATA_STALE',
      'QUOTE_EXPIRED',
      'INSUFFICIENT_BALANCE',
      'IDEMPOTENCY_CONFLICT',
    },
    422: <String>{'VALIDATION_FAILED'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// The pool quote (decision 0145, loop-api S146 OpenAPI): a stage that is
  /// not `graduated` and a simulation that reverted are `422`.
  static const poolQuoteErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'DATA_STALE',
      'VERSION_CONFLICT',
    },
    422: <String>{'VALIDATION_FAILED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// The pool prepare (loop-api S146 OpenAPI).
  static const poolWriteErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'DATA_STALE',
      'IDEMPOTENCY_CONFLICT',
      'INSUFFICIENT_BALANCE',
      'QUOTE_EXPIRED',
      'VERSION_CONFLICT',
    },
    422: <String>{'VALIDATION_FAILED'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  final Dio _dio;

  /// Turns a media id into the address this build loads it from.
  final String? Function(String mediaId) mediaUrl;

  static String _id(String value) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static String _amount(Decimal value) {
    final text = value.toString();
    if (!LoopV2Launch2Codec.amountPattern.hasMatch(text)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return text;
  }

  Future<Object?> _get(
    String path, {
    required String accessToken,
    required String clientVersion,
    Map<String, Object?>? query,
    Map<int, Set<String>> errors = readErrors,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: query,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return response.data;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: errors);
    }
  }

  Future<Object?> _post(
    String path, {
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required Map<String, Object?> body,
    LoopV2WriteOrigin? origin,
    Map<int, Set<String>> errors = writeErrors,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: body,
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 201);
      return response.data;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: errors);
    }
  }

  Future<Launch2InstancePage> listInstances({
    required String accessToken,
    required String clientVersion,
    Launch2Stage? stage,
    String? cursor,
  }) async {
    // `limit` and `cursor` are mutually exclusive (contract §3.1).
    final data = await _get(
      instancesPath,
      accessToken: accessToken,
      clientVersion: clientVersion,
      query: <String, Object?>{
        if (stage != null) 'stage': stage.wireName,
        if (cursor != null) 'cursor': cursor else 'limit': 30,
      },
    );
    final page = LoopV2Launch2Codec.page(data, mediaUrl: mediaUrl);
    // A `stage=` list answers that stage only (the row's stage is
    // re-derived on answer, so a row may already have moved on — never to
    // an earlier stage than graduated, which is final).
    if (stage == Launch2Stage.graduated &&
        page.items.any((row) => row.stage != Launch2Stage.graduated)) {
      LoopV2Launch2Codec.invalid();
    }
    return page;
  }

  Future<Launch2InstanceDetail> getInstance({
    required String accessToken,
    required String clientVersion,
    required String instanceId,
  }) async {
    final data = await _get(
      '$instancesPath/${_id(instanceId)}',
      accessToken: accessToken,
      clientVersion: clientVersion,
    );
    final detail = LoopV2Launch2Codec.detail(data, mediaUrl: mediaUrl);
    if (detail.instanceId != instanceId) LoopV2Launch2Codec.invalid();
    return detail;
  }

  Future<Launch2Quote> getQuote({
    required String accessToken,
    required String clientVersion,
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
    required String walletId,
  }) async {
    final data = await _get(
      '$instancesPath/${_id(instanceId)}/quote',
      accessToken: accessToken,
      clientVersion: clientVersion,
      errors: quoteErrors,
      query: <String, Object?>{
        'side': side.wireName,
        'amount': _amount(amount),
        'walletId': _id(walletId),
      },
    );
    return LoopV2Launch2Codec.quote(
      data,
      instanceId: instanceId,
      side: side,
      walletId: walletId,
    );
  }

  Future<Launch2Intent> postNftPrepare({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String instanceId,
    required String walletId,
    LoopV2WriteOrigin? origin,
  }) async {
    final data = await _post(
      '$instancesPath/${_id(instanceId)}/nft/prepare',
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: origin,
      body: <String, Object?>{'walletId': _id(walletId)},
    );
    final intent = LoopV2Launch2Codec.intent(data);
    if (intent.instanceId != instanceId ||
        intent.walletId != walletId ||
        intent.kind != Launch2IntentKind.nftMint) {
      LoopV2Launch2Codec.invalid();
    }
    return intent;
  }

  Future<Launch2Intent> postTradePrepare({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Decimal amount,
    required Decimal minOut,
    required DateTime deadline,
    LoopV2WriteOrigin? origin,
  }) async {
    final data = await _post(
      '$instancesPath/${_id(instanceId)}/trade/prepare',
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: origin,
      body: <String, Object?>{
        'walletId': _id(walletId),
        'side': side.wireName,
        'amount': _amount(amount),
        'minOut': _amount(minOut),
        'deadline': deadline.toUtc().toIso8601String(),
      },
    );
    final intent = LoopV2Launch2Codec.intent(data);
    final kind = side == Launch2Side.buy
        ? Launch2IntentKind.buy
        : Launch2IntentKind.sell;
    if (intent.instanceId != instanceId ||
        intent.walletId != walletId ||
        intent.kind != kind) {
      LoopV2Launch2Codec.invalid();
    }
    return intent;
  }

  Future<Launch2PoolQuote> getPoolQuote({
    required String accessToken,
    required String clientVersion,
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
    required String walletId,
  }) async {
    final data = await _get(
      '$instancesPath/${_id(instanceId)}/pool/quote',
      accessToken: accessToken,
      clientVersion: clientVersion,
      errors: poolQuoteErrors,
      query: <String, Object?>{
        'side': side.wireName,
        'mode': mode.wireName,
        'amount': _amount(amount),
        'walletId': _id(walletId),
        'slippageBps': _slippage(slippageBps).toString(),
      },
    );
    return LoopV2Launch2PoolCodec.quote(
      data,
      instanceId: instanceId,
      side: side,
      mode: mode,
      walletId: walletId,
    );
  }

  Future<Launch2PoolPrepared> postPoolTradePrepare({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
    LoopV2WriteOrigin? origin,
  }) async {
    final data = await _post(
      '$instancesPath/${_id(instanceId)}/pool/trade/prepare',
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: origin,
      errors: poolWriteErrors,
      body: <String, Object?>{
        'walletId': _id(walletId),
        'side': side.wireName,
        'mode': mode.wireName,
        'amount': _amount(amount),
        'slippageBps': _slippage(slippageBps),
      },
    );
    return LoopV2Launch2PoolCodec.prepared(
      data,
      instanceId: instanceId,
      side: side,
      mode: mode,
      walletId: walletId,
    );
  }

  static int _slippage(int bps) {
    if (bps < 0 || bps > 5000) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return bps;
  }

  Future<Launch2BuybackPage> getBuybacks({
    required String accessToken,
    required String clientVersion,
    required String instanceId,
  }) async {
    final data = await _get(
      '$instancesPath/${_id(instanceId)}/buybacks',
      accessToken: accessToken,
      clientVersion: clientVersion,
      query: const <String, Object?>{'limit': 10},
    );
    return LoopV2Launch2Codec.buybacks(data, instanceId: instanceId);
  }

  Future<Launch2Positions> getPositions({
    required String accessToken,
    required String clientVersion,
  }) async {
    final data = await _get(
      positionsPath,
      accessToken: accessToken,
      clientVersion: clientVersion,
    );
    return LoopV2Launch2Codec.positions(data, mediaUrl: mediaUrl);
  }

  /// Decision 0227 (loop-api S267): one page of the project's K line.
  ///
  /// A `404` that is not the published envelope (a server from before S267)
  /// is still the route missing, and reads as `notFound` so the page hides
  /// the chart instead of reporting a failure.
  Future<Launch2CandleSeries> getCandles({
    required String accessToken,
    required String clientVersion,
    required String instanceId,
    required Launch2CandleInterval interval,
    required int limit,
    DateTime? before,
  }) async {
    if (limit < 1 || limit > launch2CandleMaxLimit) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    final Object? data;
    try {
      data = await _get(
        '$instancesPath/${_id(instanceId)}/candles',
        accessToken: accessToken,
        clientVersion: clientVersion,
        errors: candleErrors,
        query: <String, Object?>{
          'interval': interval.wireName,
          'limit': limit.toString(),
          if (before != null)
            'before': (before.millisecondsSinceEpoch ~/ 1000).toString(),
        },
      );
    } on LoopBackendFailure catch (failure) {
      if (failure.statusCode == 404) {
        throw const LoopChainException(LoopChainFailureKind.notFound);
      }
      rethrow;
    }
    return LoopV2Launch2CandleCodec.series(
      data,
      instanceId: instanceId,
      requested: interval,
    );
  }

  /// Decision 0148 (loop-api S150): the wallet's own pool trades.
  Future<Launch2PoolTrades> getPoolTrades({
    required String accessToken,
    required String clientVersion,
    required String instanceId,
    required String walletId,
    required int limit,
  }) async {
    if (limit < 1 || limit > 50) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    final data = await _get(
      '$instancesPath/${_id(instanceId)}/pool/trades',
      accessToken: accessToken,
      clientVersion: clientVersion,
      errors: poolQuoteErrors,
      query: <String, Object?>{
        'walletId': _id(walletId),
        'limit': limit.toString(),
      },
    );
    return LoopV2Launch2PoolCodec.trades(
      data,
      instanceId: instanceId,
      walletId: walletId,
    );
  }
}

/// The authenticated `launch2` adapter behind [Launch2Gateway].
///
/// The access token is supplied by [LoopAuthenticatedSession] for exactly one
/// request. The adapter owns no credential cache and no transport retry; it
/// owns only the idempotency key of each prepare, replayed only while that
/// prepare's outcome is unresolved.
final class DioLoopV2Launch2Gateway implements Launch2Gateway {
  DioLoopV2Launch2Gateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    this._originSource,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final DioLoopV2Launch2Api _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2WriteOriginSource? _originSource;
  final LoopV2CommandKeyring _keyring;

  String get _clientVersion => _clientMetadata.clientVersion;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<T> _read<T>(Future<T> Function(String accessToken) request) =>
      executeChainRequest(_session, request, write: false);

  Future<LoopV2WriteOrigin?> _origin() async =>
      _originSource == null ? null : await _originSource.resolve();

  static bool _unresolved(LoopChainFailureKind kind) =>
      kind == LoopChainFailureKind.offline ||
      kind == LoopChainFailureKind.cancelled ||
      kind == LoopChainFailureKind.outcomeUnknown ||
      kind == LoopChainFailureKind.unexpected;

  Future<T> _write<T>(
    String signature,
    Future<T> Function(String accessToken, String key) request,
  ) async {
    final key = _keyring.reserve(signature);
    try {
      final result = await executeChainRequest(
        _session,
        (accessToken) => request(accessToken, key),
        write: true,
      );
      _keyring.release(signature);
      return result;
    } on LoopChainException catch (failure) {
      if (!_unresolved(failure.kind)) _keyring.release(signature);
      rethrow;
    } catch (_) {
      _keyring.release(signature);
      rethrow;
    }
  }

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) => _read(
    (accessToken) => _api.listInstances(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      stage: stage,
      cursor: cursor,
    ),
  );

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) => _read(
    (accessToken) => _api.getInstance(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      instanceId: instanceId,
    ),
  );

  @override
  Future<Launch2Quote> quote({
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
    required String walletId,
  }) => _read(
    (accessToken) => _api.getQuote(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      instanceId: instanceId,
      side: side,
      amount: amount,
      walletId: walletId,
    ),
  );

  @override
  Future<Launch2Intent> prepareNftMint({
    required String instanceId,
    required String walletId,
  }) async {
    final origin = await _origin();
    return _write(
      'launch2:nft:$instanceId:$walletId',
      (accessToken, key) => _api.postNftPrepare(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        instanceId: instanceId,
        walletId: walletId,
        origin: origin,
      ),
    );
  }

  @override
  Future<Launch2Intent> prepareTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Decimal amount,
    required Decimal minOut,
    required DateTime deadline,
  }) async {
    final origin = await _origin();
    return _write(
      'launch2:trade:$instanceId:$walletId:${side.wireName}:$amount:$minOut:'
      '${deadline.toUtc().toIso8601String()}',
      (accessToken, key) => _api.postTradePrepare(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        instanceId: instanceId,
        walletId: walletId,
        side: side,
        amount: amount,
        minOut: minOut,
        deadline: deadline,
        origin: origin,
      ),
    );
  }

  @override
  Future<Launch2PoolQuote> poolQuote({
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
    required String walletId,
  }) => _read(
    (accessToken) => _api.getPoolQuote(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      instanceId: instanceId,
      side: side,
      mode: mode,
      amount: amount,
      slippageBps: slippageBps,
      walletId: walletId,
    ),
  );

  @override
  Future<Launch2PoolPrepared> preparePoolTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
  }) async {
    final origin = await _origin();
    return _write(
      'launch2:pool:$instanceId:$walletId:${side.wireName}:${mode.wireName}:'
      '$amount:$slippageBps',
      (accessToken, key) => _api.postPoolTradePrepare(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        instanceId: instanceId,
        walletId: walletId,
        side: side,
        mode: mode,
        amount: amount,
        slippageBps: slippageBps,
        origin: origin,
      ),
    );
  }

  @override
  Future<Launch2BuybackPage> loadBuybacks(String instanceId) => _read(
    (accessToken) => _api.getBuybacks(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      instanceId: instanceId,
    ),
  );

  @override
  Future<Launch2Positions> loadPositions() => _read(
    (accessToken) => _api.getPositions(
      accessToken: accessToken,
      clientVersion: _clientVersion,
    ),
  );

  @override
  Future<Launch2PoolTrades> loadPoolTrades({
    required String instanceId,
    required String walletId,
    int limit = launch2PoolTradesShown,
  }) => _read(
    (accessToken) => _api.getPoolTrades(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      instanceId: instanceId,
      walletId: walletId,
      limit: limit,
    ),
  );

  @override
  Future<Launch2CandleSeries> candles(
    String instanceId,
    Launch2CandleInterval interval, {
    int limit = launch2CandlePageSize,
    DateTime? before,
  }) => _read(
    (accessToken) => _api.getCandles(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      instanceId: instanceId,
      interval: interval,
      limit: limit,
      before: before,
    ),
  );
}

/// Reading a provider issues no request; a missing Dio client, client
/// metadata or authenticated session keeps the port at its fail-closed
/// default (the S5 / S7 pattern).
final loopV2Launch2ApiProvider = Provider<DioLoopV2Launch2Api?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  if (dio == null) return null;
  final resolver = ref.watch(loopV2MediaUrlResolverProvider);
  return DioLoopV2Launch2Api(dio, mediaUrl: resolver.urlFor);
});

final loopV2Launch2GatewayProvider = Provider<Launch2Gateway>((ref) {
  final api = ref.watch(loopV2Launch2ApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableLaunch2Gateway();
  }
  return DioLoopV2Launch2Gateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});
