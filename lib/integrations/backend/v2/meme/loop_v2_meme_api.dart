import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';
import 'package:loop_mobile/integrations/backend/v2/meme/loop_v2_meme_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/media/loop_v2_media.dart';

/// Strict V2 transport for the `meme` module (loop-api decision 0101).
///
/// Reads carry no `Idempotency-Key`; the three writes carry exactly one
/// canonical UUIDv4 supplied by the caller. Every success is checked for
/// `Cache-Control: no-store` and an `X-Request-ID`, and every refusal is read
/// against the route's own published catalogue.
final class DioLoopV2MemeApi {
  DioLoopV2MemeApi(this._dio, {required this.mediaUrl});

  static const tokensPath = '/v2/meme/tokens';
  static const quotePath = '/v2/meme/quote';
  static const intentsPath = '/v2/meme/intents';
  static const logoUploadPath = '/v2/media/community-logos';

  /// The reads (OpenAPI tag `meme`): the read catalogue plus the two codes
  /// these routes add — `409 DATA_STALE` (a curve that stopped trading, a
  /// token not yet on chain) and `422 VALIDATION_FAILED`.
  static const readErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED', 'REGION_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'DATA_STALE',
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

  /// The three writes: create, prepare, report.
  static const writeErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'DATA_STALE',
      'IDEMPOTENCY_CONFLICT',
      'INSUFFICIENT_BALANCE',
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

  static const uploadErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'IDEMPOTENCY_CONFLICT'},
    413: <String>{'PAYLOAD_TOO_LARGE', 'VALIDATION_FAILED'},
    415: <String>{'UNSUPPORTED_MEDIA_TYPE', 'VALIDATION_FAILED'},
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

  Future<Object?> _get(
    String path, {
    required String accessToken,
    required String clientVersion,
    Map<String, Object?>? query,
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
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  Future<Object?> _post(
    String path, {
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required Map<String, Object?> body,
    required int statusCode,
    LoopV2WriteOrigin? origin,
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
      LoopV2Contract.validateSuccess(response, statusCode: statusCode);
      return response.data;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  Future<MemeTokenPage> listTokens({
    required String accessToken,
    required String clientVersion,
    required MemeListTab tab,
    String? cursor,
  }) async {
    // `cursor` and `limit` are mutually exclusive (contract §3).
    final data = await _get(
      tokensPath,
      accessToken: accessToken,
      clientVersion: clientVersion,
      query: <String, Object?>{
        'tab': tab.wireName,
        if (cursor != null) 'cursor': cursor else 'limit': 30,
      },
    );
    final page = LoopV2MemeCodec.tokenPage(data, mediaUrl: mediaUrl);
    if (page.tab != tab) LoopV2MemeCodec.invalid();
    return page;
  }

  Future<MemeTokenDetail> getToken({
    required String accessToken,
    required String clientVersion,
    required String memeTokenId,
  }) async {
    final data = await _get(
      '$tokensPath/${_id(memeTokenId)}',
      accessToken: accessToken,
      clientVersion: clientVersion,
    );
    final detail = LoopV2MemeCodec.detail(data, mediaUrl: mediaUrl);
    if (detail.memeTokenId != memeTokenId) LoopV2MemeCodec.invalid();
    return detail;
  }

  Future<MemeTradePage> getTrades({
    required String accessToken,
    required String clientVersion,
    required String memeTokenId,
    String? cursor,
  }) async {
    final data = await _get(
      '$tokensPath/${_id(memeTokenId)}/trades',
      accessToken: accessToken,
      clientVersion: clientVersion,
      query: <String, Object?>{
        if (cursor != null) 'cursor': cursor else 'limit': 50,
      },
    );
    return LoopV2MemeCodec.tradePage(data, memeTokenId: memeTokenId);
  }

  Future<MemeHolderPage> getHolders({
    required String accessToken,
    required String clientVersion,
    required String memeTokenId,
    String? cursor,
  }) async {
    final data = await _get(
      '$tokensPath/${_id(memeTokenId)}/holders',
      accessToken: accessToken,
      clientVersion: clientVersion,
      query: <String, Object?>{
        if (cursor != null) 'cursor': cursor else 'limit': 50,
      },
    );
    return LoopV2MemeCodec.holderPage(data, memeTokenId: memeTokenId);
  }

  Future<MemeCandleSeries> getCandles({
    required String accessToken,
    required String clientVersion,
    required String memeTokenId,
    required MemeCandleInterval interval,
  }) async {
    final data = await _get(
      '$tokensPath/${_id(memeTokenId)}/candles',
      accessToken: accessToken,
      clientVersion: clientVersion,
      query: <String, Object?>{'interval': interval.wireName, 'limit': 200},
    );
    return LoopV2MemeCodec.candles(
      data,
      memeTokenId: memeTokenId,
      interval: interval,
    );
  }

  Future<MemeQuote> getQuote({
    required String accessToken,
    required String clientVersion,
    required String memeTokenId,
    required MemeTradeSide side,
    required String amount,
    String? walletId,
  }) async {
    if (memeRawFromInput(amount) == null) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    final data = await _get(
      quotePath,
      accessToken: accessToken,
      clientVersion: clientVersion,
      query: <String, Object?>{
        'tokenId': _id(memeTokenId),
        'side': side.wireName,
        'amount': amount,
        if (walletId != null) 'walletId': _id(walletId),
      },
    );
    return LoopV2MemeCodec.quote(data, memeTokenId: memeTokenId, side: side);
  }

  Future<MemeTokenDetail> postToken({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required MemeCreateDraft draft,
    LoopV2WriteOrigin? origin,
  }) async {
    final links = <String, Object?>{
      'twitter': ?draft.links.twitter,
      'telegram': ?draft.links.telegram,
      'website': ?draft.links.website,
    };
    final data = await _post(
      tokensPath,
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      statusCode: 201,
      origin: origin,
      body: <String, Object?>{
        'name': draft.name,
        'symbol': draft.symbol,
        if (draft.description.isNotEmpty) 'description': draft.description,
        'imageMediaId': ?draft.imageMediaId,
        if (links.isNotEmpty) 'links': links,
      },
    );
    return LoopV2MemeCodec.detail(data, mediaUrl: mediaUrl);
  }

  Future<MemeIntent> postIntent({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String memeTokenId,
    required MemeIntentKind kind,
    required String walletId,
    String? usd1Amount,
    String? tokenAmount,
    int? slippageBps,
    LoopV2WriteOrigin? origin,
  }) async {
    final data = await _post(
      '$tokensPath/${_id(memeTokenId)}/intents',
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      statusCode: 201,
      origin: origin,
      body: <String, Object?>{
        'kind': kind.wireName,
        'walletId': _id(walletId),
        'usd1Amount': ?usd1Amount,
        'tokenAmount': ?tokenAmount,
        'slippageBps': ?slippageBps,
      },
    );
    final intent = LoopV2MemeCodec.intent(data);
    if (intent.memeTokenId != memeTokenId ||
        intent.kind != kind ||
        intent.walletId != walletId) {
      LoopV2MemeCodec.invalid();
    }
    return intent;
  }

  Future<MemeIntent> postBroadcastReport({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String memeTokenId,
    required String memeIntentId,
    required String txHash,
    LoopV2WriteOrigin? origin,
  }) async {
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(txHash)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    final data = await _post(
      '$tokensPath/${_id(memeTokenId)}/intents/${_id(memeIntentId)}'
      '/broadcast-report',
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      statusCode: 200,
      origin: origin,
      body: <String, Object?>{'txHash': txHash.toLowerCase()},
    );
    final intent = LoopV2MemeCodec.intent(data);
    if (intent.memeIntentId != memeIntentId) LoopV2MemeCodec.invalid();
    return intent;
  }

  Future<MemeIntent> getIntent({
    required String accessToken,
    required String clientVersion,
    required String memeIntentId,
  }) async {
    final data = await _get(
      '$intentsPath/${_id(memeIntentId)}',
      accessToken: accessToken,
      clientVersion: clientVersion,
    );
    final intent = LoopV2MemeCodec.intent(data);
    if (intent.memeIntentId != memeIntentId) LoopV2MemeCodec.invalid();
    return intent;
  }

  Future<MemeUploadedImage> uploadLogo({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final subtype = switch (contentType) {
      'image/jpeg' => 'jpeg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => null,
    };
    if (subtype == null ||
        bytes.isEmpty ||
        bytes.length > avatarUploadMaximumBytes) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        logoUploadPath,
        data: FormData.fromMap(<String, Object?>{
          'file': MultipartFile.fromBytes(
            bytes,
            filename: 'logo.$subtype',
            contentType: DioMediaType('image', subtype),
          ),
        }),
        options: Options(
          headers: LoopV2ModuleRequest.writeHeaders(
            accessToken,
            clientVersion,
            idempotencyKey,
          ),
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 201);
      return LoopV2MemeCodec.uploadedImage(response.data, mediaUrl: mediaUrl);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: uploadErrors);
    }
  }
}

/// The authenticated `meme` adapter behind [MemeGateway].
///
/// The access token is supplied by [LoopAuthenticatedSession] for exactly one
/// request. The adapter owns no credential cache and no transport retry; it
/// owns only the idempotency key of each write, which is replayed only while
/// the outcome of that write is unresolved.
final class DioLoopV2MemeGateway implements MemeGateway {
  DioLoopV2MemeGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    this._originSource,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final DioLoopV2MemeApi _api;
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
  Future<MemeTokenPage> listTokens(MemeListTab tab, {String? cursor}) => _read(
    (accessToken) => _api.listTokens(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      tab: tab,
      cursor: cursor,
    ),
  );

  @override
  Future<MemeTokenDetail> loadToken(String memeTokenId) => _read(
    (accessToken) => _api.getToken(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      memeTokenId: memeTokenId,
    ),
  );

  @override
  Future<MemeTradePage> loadTrades(String memeTokenId, {String? cursor}) =>
      _read(
        (accessToken) => _api.getTrades(
          accessToken: accessToken,
          clientVersion: _clientVersion,
          memeTokenId: memeTokenId,
          cursor: cursor,
        ),
      );

  @override
  Future<MemeHolderPage> loadHolders(String memeTokenId, {String? cursor}) =>
      _read(
        (accessToken) => _api.getHolders(
          accessToken: accessToken,
          clientVersion: _clientVersion,
          memeTokenId: memeTokenId,
          cursor: cursor,
        ),
      );

  @override
  Future<MemeCandleSeries> loadCandles(
    String memeTokenId,
    MemeCandleInterval interval,
  ) => _read(
    (accessToken) => _api.getCandles(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      memeTokenId: memeTokenId,
      interval: interval,
    ),
  );

  @override
  Future<MemeQuote> quote({
    required String memeTokenId,
    required MemeTradeSide side,
    required String amount,
    String? walletId,
  }) => _read(
    (accessToken) => _api.getQuote(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      memeTokenId: memeTokenId,
      side: side,
      amount: amount,
      walletId: walletId,
    ),
  );

  @override
  Future<MemeUploadedImage> uploadImage({
    required Uint8List bytes,
    required String contentType,
  }) => _write(
    // Each picture is its own upload; only an unresolved one replays.
    'meme:logo:${bytes.length}:${Object.hashAll(bytes)}',
    (accessToken, key) => _api.uploadLogo(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      bytes: bytes,
      contentType: contentType,
    ),
  );

  @override
  Future<MemeTokenDetail> createToken(MemeCreateDraft draft) async {
    final origin = await _origin();
    return _write(
      'meme:create:${draft.signature}',
      (accessToken, key) => _api.postToken(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        draft: draft,
        origin: origin,
      ),
    );
  }

  @override
  Future<MemeIntent> prepareIntent({
    required String memeTokenId,
    required MemeIntentKind kind,
    required String walletId,
    String? usd1Amount,
    String? tokenAmount,
    int? slippageBps,
  }) async {
    final origin = await _origin();
    return _write(
      'meme:intent:$memeTokenId:${kind.wireName}:$walletId:'
      '${usd1Amount ?? ''}:${tokenAmount ?? ''}:${slippageBps ?? ''}',
      (accessToken, key) => _api.postIntent(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        memeTokenId: memeTokenId,
        kind: kind,
        walletId: walletId,
        usd1Amount: usd1Amount,
        tokenAmount: tokenAmount,
        slippageBps: slippageBps,
        origin: origin,
      ),
    );
  }

  @override
  Future<MemeIntent> reportBroadcast({
    required String memeTokenId,
    required String memeIntentId,
    required String txHash,
  }) async {
    final origin = await _origin();
    return _write(
      'meme:report:$memeIntentId:$txHash',
      (accessToken, key) => _api.postBroadcastReport(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        memeTokenId: memeTokenId,
        memeIntentId: memeIntentId,
        txHash: txHash,
        origin: origin,
      ),
    );
  }

  @override
  Future<MemeIntent> loadIntent(String memeIntentId) => _read(
    (accessToken) => _api.getIntent(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      memeIntentId: memeIntentId,
    ),
  );
}

/// Reading a provider issues no request; a missing Dio client, client
/// metadata or authenticated session keeps the port at its fail-closed
/// default (the S5 / S7 pattern).
final loopV2MemeApiProvider = Provider<DioLoopV2MemeApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  if (dio == null) return null;
  final resolver = ref.watch(loopV2MediaUrlResolverProvider);
  return DioLoopV2MemeApi(dio, mediaUrl: resolver.urlFor);
});

final loopV2MemeGatewayProvider = Provider<MemeGateway>((ref) {
  final api = ref.watch(loopV2MemeApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableMemeGateway();
  }
  return DioLoopV2MemeGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});
