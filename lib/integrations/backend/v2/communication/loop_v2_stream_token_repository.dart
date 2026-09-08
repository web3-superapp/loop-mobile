import 'package:dio/dio.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:uuid/uuid.dart';

/// Strict V2 client for `POST /v2/chat/token` and `POST /v2/video/token`.
///
/// The V2 endpoints are writes: each request carries the contract headers and
/// exactly one canonical lowercase UUIDv4 `Idempotency-Key`. A token is minted
/// per request, never cached and never persisted; the response is parsed
/// against the frozen key set, and the recovery policy of decision 0045 — one
/// 401 refresh and one bounded bootstrap recovery — stays in the session above
/// this repository.
final class DioLoopV2StreamTokenRepository
    implements LoopStreamTokenRepository {
  DioLoopV2StreamTokenRepository(
    this._dio, {
    required String expectedApiKey,
    required String clientVersion,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _expectedApiKey = _validateApiKey(expectedApiKey),
       _clientVersion = _validateClientVersion(clientVersion),
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  static const chatPath = '/v2/chat/token';
  static const videoPath = '/v2/video/token';

  /// The contract fixes the lifetime at one hour; a longer one is a broken
  /// projection rather than a generous server.
  static const _maximumRemainingLifetime = Duration(minutes: 65);

  /// `429 RATE_LIMITED` is reachable on both token paths.
  static const tokenErrors = <int, Set<String>>{
    ...LoopV2ModuleRequest.writeErrors,
    429: <String>{'RATE_LIMITED'},
  };

  final Dio _dio;
  final String _expectedApiKey;
  final String _clientVersion;
  final DateTime Function() _now;
  final Uuid _uuid;

  @override
  Future<LoopStreamTokenCredential> issue({
    required LoopStreamTokenProduct product,
    required String expectedStreamUserId,
    required String accessToken,
  }) async {
    if (!LoopV2Contract.streamUserIdPattern.hasMatch(expectedStreamUserId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    if (accessToken.isEmpty || accessToken != accessToken.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }

    final path = switch (product) {
      LoopStreamTokenProduct.chat => chatPath,
      LoopStreamTokenProduct.video => videoPath,
    };
    try {
      final response = await _dio.post<Object?>(
        path,
        // Each attempt is its own logical operation: a token is not a
        // resource whose duplicate creation must be suppressed, and the
        // session retries only after an explicit 401 or bootstrap recovery.
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          _clientVersion,
          _uuid.v4().toLowerCase(),
        ),
      );
      return _parse(response, expectedStreamUserId);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: tokenErrors);
    }
  }

  LoopStreamTokenCredential _parse(
    Response<Object?> response,
    String expectedStreamUserId,
  ) {
    LoopV2Contract.validateSuccess(response, statusCode: 200);
    final root = LoopV2Contract.strictMap(response.data, const <String>{
      'apiKey',
      'token',
      'expiresAt',
      'user',
      'contractVersion',
    });
    LoopV2ProjectionCodec.requireContractVersion(root);
    final user = LoopV2Contract.strictMap(root['user'], const <String>{'id'});
    final apiKey = root['apiKey'];
    final token = root['token'];
    final streamUserId = user['id'];
    // The public API key must be the one this build was configured with, and
    // the identity must be the exact server-derived Stream user the caller
    // already holds. Neither is ever taken from the response alone.
    if (apiKey is! String ||
        apiKey != _expectedApiKey ||
        !_isPrintableAscii(apiKey, minimum: 1, maximum: 512) ||
        token is! String ||
        !_isPrintableAscii(token, minimum: 32, maximum: 16384) ||
        streamUserId is! String ||
        streamUserId != expectedStreamUserId ||
        !LoopV2Contract.streamUserIdPattern.hasMatch(streamUserId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    final expiresAt = LoopV2ProjectionCodec.requireTimestamp(root, 'expiresAt');
    final now = _now().toUtc();
    if (!expiresAt.isAfter(now) ||
        expiresAt.difference(now) > _maximumRemainingLifetime) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    return LoopStreamTokenCredential(token: token, expiresAt: expiresAt);
  }

  static bool _isPrintableAscii(
    String value, {
    required int minimum,
    required int maximum,
  }) {
    if (value.length < minimum || value.length > maximum) return false;
    return value.codeUnits.every((unit) => unit >= 0x21 && unit <= 0x7e);
  }

  static String _validateClientVersion(String value) {
    if (!LoopV2ModuleRequest.clientVersionPattern.hasMatch(value)) {
      throw ArgumentError('clientVersion must be a canonical semantic version');
    }
    return value;
  }

  static String _validateApiKey(String value) {
    if (value != value.trim() ||
        !_isPrintableAscii(value, minimum: 1, maximum: 512)) {
      throw ArgumentError('expectedApiKey must be a canonical public value');
    }
    return value;
  }
}
