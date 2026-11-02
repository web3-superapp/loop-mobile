import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_gateway.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';

/// Wire codec for the S332 feedback routes (docs/52 §二, decision 0262).
///
/// The routes are new and their API lands alongside this client, so the
/// codec requires exactly the keys the contract names and ignores any other
/// key the server adds (`contractVersion`, a width) — a new optional key
/// must never break a shipped build (feedback 2026-10-19).
abstract final class LoopV2FeedbackCodec {
  static Never invalid() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static final RegExp _cursor = RegExp(r'^[A-Za-z0-9_\-.~:+/=]+$');

  static const int maximumCursorLength = 1536;
  static const int maximumUrlLength = 2048;
  static const int maximumPageItems = 100;

  static Map<String, Object?> map(Object? raw) {
    if (raw is! Map) invalid();
    final result = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) invalid();
      result[key] = entry.value;
    }
    return result;
  }

  static String uuid(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! String || !_uuid.hasMatch(value)) invalid();
    return value.toLowerCase();
  }

  static DateTime timestamp(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! String || value.length > 64) invalid();
    final parsed = DateTime.tryParse(value);
    if (parsed == null) invalid();
    return parsed.toUtc();
  }

  static String? cursor(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value == null) return null;
    if (value is! String ||
        value.isEmpty ||
        value.length > maximumCursorLength ||
        !_cursor.hasMatch(value)) {
      invalid();
    }
    return value;
  }

  static bool isValidCursor(String value) =>
      value.isNotEmpty &&
      value.length <= maximumCursorLength &&
      _cursor.hasMatch(value);

  /// An absolute `http(s)` address, or a `/v2/media/…` path resolved
  /// against [origin].
  static String url(Object? raw, Uri origin) {
    if (raw is! String || raw.isEmpty || raw.length > maximumUrlLength) {
      invalid();
    }
    if (raw.startsWith('/v2/media/')) {
      return origin.replace(path: raw, query: null, fragment: null).toString();
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      invalid();
    }
    return raw;
  }

  static BetaFeedbackUploadedImage uploadedImage(Object? raw, Uri origin) {
    final root = map(raw);
    return BetaFeedbackUploadedImage(
      mediaId: uuid(root, 'mediaId'),
      url: url(root['url'], origin),
    );
  }

  static BetaFeedbackStatus status(Map<String, Object?> source) {
    final value = source['status'];
    if (value is! String) invalid();
    return BetaFeedbackStatus.tryParse(value) ?? invalid();
  }

  static BetaFeedbackReceipt receipt(Object? raw) {
    final root = map(raw);
    final feedback = map(root['feedback']);
    return BetaFeedbackReceipt(
      id: uuid(feedback, 'id'),
      status: status(feedback),
      createdAt: timestamp(feedback, 'createdAt'),
    );
  }

  static BetaFeedbackItem item(Object? raw, Uri origin) {
    final source = map(raw);
    final rawCategory = source['category'];
    if (rawCategory is! String) invalid();
    final category = BetaFeedbackCategory.tryParse(rawCategory) ?? invalid();
    final body = source['body'];
    if (body is! String ||
        body.isEmpty ||
        body.length > BetaFeedbackPolicy.maximumWireBodyLength) {
      invalid();
    }
    final rawImages = source['images'];
    if (rawImages is! List ||
        rawImages.length > BetaFeedbackPolicy.maximumImages) {
      invalid();
    }
    return BetaFeedbackItem(
      id: uuid(source, 'id'),
      category: category,
      body: body,
      status: status(source),
      createdAt: timestamp(source, 'createdAt'),
      images: <String>[for (final image in rawImages) url(image, origin)],
    );
  }

  static BetaFeedbackPage page(Object? raw, Uri origin) {
    final root = map(raw);
    final rawItems = root['items'];
    if (rawItems is! List || rawItems.length > maximumPageItems) invalid();
    final items = <BetaFeedbackItem>[];
    final seen = <String>{};
    for (final rawItem in rawItems) {
      final decoded = item(rawItem, origin);
      if (!seen.add(decoded.id)) invalid();
      items.add(decoded);
    }
    return BetaFeedbackPage(
      items: items,
      nextCursor: cursor(root, 'nextCursor'),
    );
  }
}

/// Strict V2 transport for the feedback routes.
final class DioLoopV2FeedbackApi {
  DioLoopV2FeedbackApi(this._dio);

  static const uploadPath = '/v2/media/feedback-images';
  static const feedbackPath = '/v2/feedback';
  static const minePath = '/v2/feedback/mine';

  static const writeErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED', 'REGION_BLOCKED'},
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

  Uri get _origin => Uri.parse(_dio.options.baseUrl);

  static int _successStatus(Response<Object?> response) {
    final statusCode = response.statusCode;
    if (statusCode != 200 && statusCode != 201) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    LoopV2Contract.validateSuccess(response, statusCode: statusCode!);
    return statusCode;
  }

  Future<BetaFeedbackUploadedImage> uploadImage({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required BetaFeedbackImage image,
  }) async {
    final subtype = switch (image.contentType) {
      'image/jpeg' => 'jpeg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => null,
    };
    if (subtype == null ||
        image.bytes.isEmpty ||
        image.bytes.length > BetaFeedbackPolicy.maximumImageBytes) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        uploadPath,
        data: FormData.fromMap(<String, Object?>{
          'file': MultipartFile.fromBytes(
            image.bytes,
            filename: 'feedback.$subtype',
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
      _successStatus(response);
      return LoopV2FeedbackCodec.uploadedImage(response.data, _origin);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  Future<BetaFeedbackReceipt> submit({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required BetaFeedbackSubmission submission,
    LoopV2WriteOrigin? origin,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        feedbackPath,
        data: <String, Object?>{
          'category': submission.category.wireName,
          'body': submission.body,
          'mediaIds': submission.mediaIds,
          'context': submission.context.toJson(),
        },
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      // `201` is new feedback; `200` the idempotent replay of the same one.
      _successStatus(response);
      return LoopV2FeedbackCodec.receipt(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  Future<BetaFeedbackPage> listMine({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  }) async {
    if (cursor != null && !LoopV2FeedbackCodec.isValidCursor(cursor)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        minePath,
        queryParameters: cursor == null
            ? null
            : <String, Object?>{'cursor': cursor},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2FeedbackCodec.page(response.data, _origin);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }
}

/// How one feedback failure reads. The status decides first: a route the
/// server does not serve (`404`) and a closed switch (`503`,
/// `BETA_FEEDBACK_ENABLED` off) are both "not available", whatever body
/// came with them.
LoopChainException loopV2FeedbackFailure(
  LoopBackendFailure failure, {
  required bool write,
}) {
  // The server's rule name (`detailsSafe.reasonCode`) travels with every
  // refusal: `MEDIA_NOT_OWNED` / `FEEDBACK_MEDIA_IN_USE` tell the form its
  // uploaded pictures can no longer be used (S332 F2).
  final reasonCode = failure.detailsSafe?.reasonCode;
  final status = failure.statusCode;
  if (status == 404 || status == 503) {
    return LoopChainException(
      LoopChainFailureKind.unavailable,
      reasonCode: reasonCode,
    );
  }
  if (status == 429) {
    return LoopChainException(
      LoopChainFailureKind.rateLimited,
      reasonCode: reasonCode,
    );
  }
  if (status == 413 || status == 415 || status == 422) {
    return LoopChainException(
      LoopChainFailureKind.validationFailed,
      reasonCode: reasonCode,
    );
  }
  return loopChainExceptionForV2(failure, write: write);
}

final class DioLoopV2BetaFeedbackGateway implements BetaFeedbackGateway {
  DioLoopV2BetaFeedbackGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    this._originSource,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final DioLoopV2FeedbackApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2WriteOriginSource? _originSource;
  final LoopV2CommandKeyring _keyring;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<T> _execute<T>(
    Future<T> Function(String accessToken) request, {
    required bool write,
  }) async {
    try {
      return await _session.execute(request);
    } on LoopBackendFailure catch (failure) {
      throw loopV2FeedbackFailure(failure, write: write);
    } on LoopChainException {
      rethrow;
    } catch (_) {
      throw LoopChainException(
        write
            ? LoopChainFailureKind.unexpected
            : LoopChainFailureKind.readFailed,
      );
    }
  }

  /// One key per logical write; an unresolved outcome keeps it for the
  /// identical retry, every other outcome releases it.
  Future<T> _write<T>(
    String signature,
    Future<T> Function(String accessToken, String idempotencyKey) request,
  ) async {
    final key = _keyring.reserve(signature);
    try {
      final result = await _execute(
        (accessToken) => request(accessToken, key),
        write: true,
      );
      _keyring.release(signature);
      return result;
    } on LoopChainException catch (failure) {
      if (!loopChainOutcomeIsUnresolved(failure.kind)) {
        _keyring.release(signature);
      }
      rethrow;
    } catch (_) {
      _keyring.release(signature);
      rethrow;
    }
  }

  @override
  Future<BetaFeedbackUploadedImage> uploadImage(BetaFeedbackImage image) =>
      _write(
        'beta-feedback-image:${image.localId}:${image.bytes.length}:'
        '${Object.hashAll(image.bytes)}',
        (accessToken, key) => _api.uploadImage(
          accessToken: accessToken,
          clientVersion: _clientMetadata.clientVersion,
          idempotencyKey: key,
          image: image,
        ),
      );

  @override
  Future<BetaFeedbackReceipt> submit(BetaFeedbackSubmission submission) async {
    final origin = await _originSource?.resolve();
    return _write(
      submission.signature,
      (accessToken, key) => _api.submit(
        accessToken: accessToken,
        clientVersion: _clientMetadata.clientVersion,
        idempotencyKey: key,
        submission: submission,
        origin: origin,
      ),
    );
  }

  @override
  Future<BetaFeedbackPage> listMine({String? cursor}) => _execute(
    (accessToken) => _api.listMine(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
      cursor: cursor,
    ),
    write: false,
  );
}

final loopV2BetaFeedbackGatewayProvider = Provider<BetaFeedbackGateway>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || metadata == null || session == null) {
    return const UnavailableBetaFeedbackGateway();
  }
  return DioLoopV2BetaFeedbackGateway(
    api: DioLoopV2FeedbackApi(dio),
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});
