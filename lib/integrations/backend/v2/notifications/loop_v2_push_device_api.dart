import 'package:dio/dio.dart';
import 'package:loop_mobile/features/notifications/push_device_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/security/loop_v2_security_api.dart';

/// Strict V2 transport for the account's push device token (decision 0067).
///
/// Both routes belong to the `/v2/devices` family and carry the whole logout
/// header set: bearer, contract version, client version, platform, device id,
/// the caller's own session id and one fresh `Idempotency-Key`. A missing key
/// is `400 INVALID_REQUEST`, so the key is not optional here the way it is on
/// a compare-and-set write.
abstract interface class LoopV2PushDeviceApi {
  Future<LoopPushTokenRegistration> registerToken({
    required String accessToken,
    required String clientVersion,
    required LoopPushPlatform platform,
    required String token,
    required String appVersion,
    required LoopV2SessionCommand command,
  });

  Future<LoopPushTokenRevocation> revokeToken({
    required String accessToken,
    required String clientVersion,
    required LoopV2SessionCommand command,
  });
}

final class DioLoopV2PushDeviceApi implements LoopV2PushDeviceApi {
  const DioLoopV2PushDeviceApi(this._dio);

  static const pushTokenPath = '/v2/devices/push-token';

  /// FCM registration tokens are ~160 characters today; the provider
  /// documents no maximum. The bound exists so a payload that is no longer a
  /// token cannot be sent as one.
  static const maximumTokenLength = 1024;
  static const minimumTokenLength = 32;

  /// A provider token is opaque, but it is never whitespace, never control
  /// characters and never a URL. Anything else is refused here rather than
  /// handed to the server.
  static final RegExp tokenPattern = RegExp(r'^[A-Za-z0-9_:.\-]+$');

  /// The device-command catalogue. `404 SESSION_NOT_FOUND` is this family's
  /// own answer — the session id in the header is not an active session of
  /// this account, or its recorded device and platform disagree with the
  /// headers — and `503 CAPABILITY_UNAVAILABLE` is the backend saying it has
  /// no Firebase credentials (`PUSH_RUNTIME_DEFERRED`). Only `POST` can meet
  /// the latter; `DELETE` stays available either way.
  static const pushDeviceErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    404: <String>{'SESSION_NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'VERSION_CONFLICT',
    },
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  final Dio _dio;

  @override
  Future<LoopPushTokenRegistration> registerToken({
    required String accessToken,
    required String clientVersion,
    required LoopPushPlatform platform,
    required String token,
    required String appVersion,
    required LoopV2SessionCommand command,
  }) async {
    // `async`, so a local refusal is a failed Future like every other one on
    // this transport rather than a synchronous throw the caller would have to
    // guard separately.
    _validateToken(token);
    if (!LoopV2ModuleRequest.clientVersionPattern.hasMatch(appVersion)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    // The server answers `400` when the body and the header disagree. Sending
    // a request that cannot be accepted only burns an idempotency key.
    if (platform.wireName != command.platform.wireName) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    final headers = _headers(accessToken, clientVersion, command);
    try {
      final response = await _dio.post<Object?>(
        pushTokenPath,
        data: <String, Object?>{
          'platform': platform.wireName,
          'token': token,
          'appVersion': appVersion,
        },
        options: Options(
          headers: headers,
          contentType: Headers.jsonContentType,
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'registered',
        'pushTokenId',
        'platform',
        'provider',
        'appVersion',
        'observedAt',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      // The server's own answer, not the status code, decides whether this
      // device is addressable, and it has to be an answer about the device
      // that asked: another platform or another application version means the
      // reply belongs to a different registration.
      LoopV2ChainCodec.requireTrue(root, 'registered');
      if (root['platform'] != platform.wireName ||
          root['provider'] != LoopPushTokenRegistration.firebaseProvider ||
          root['appVersion'] != appVersion) {
        LoopV2ChainCodec.invalid();
      }
      return LoopPushTokenRegistration(
        registered: true,
        pushTokenId: LoopV2Contract.requiredString(
          root,
          'pushTokenId',
          pattern: LoopV2Contract.uuidPattern,
        ),
        platform: platform,
        provider: LoopPushTokenRegistration.firebaseProvider,
        appVersion: appVersion,
        observedAt: LoopV2ChainCodec.requireTimestamp(root, 'observedAt'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: pushDeviceErrors);
    }
  }

  @override
  Future<LoopPushTokenRevocation> revokeToken({
    required String accessToken,
    required String clientVersion,
    required LoopV2SessionCommand command,
  }) async {
    final headers = _headers(accessToken, clientVersion, command);
    try {
      // No body and no token: the route drops whatever this device session
      // registered. A body is `400`, and the token is already the server's to
      // look up — repeating it here would only be a second place to get wrong.
      final response = await _dio.delete<Object?>(
        pushTokenPath,
        options: Options(
          headers: headers,
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'registered',
        'revokedAt',
        'observedAt',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      LoopV2ChainCodec.requireFalse(root, 'registered');
      return LoopPushTokenRevocation(
        registered: false,
        // Null is the idempotent answer: there was no token on this session.
        revokedAt: LoopV2ChainCodec.optionalTimestamp(root, 'revokedAt'),
        observedAt: LoopV2ChainCodec.requireTimestamp(root, 'observedAt'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: pushDeviceErrors);
    }
  }

  static Map<String, String> _headers(
    String accessToken,
    String clientVersion,
    LoopV2SessionCommand command,
  ) => <String, String>{
    ...LoopV2ModuleRequest.readHeaders(accessToken, clientVersion),
    ...command.headers,
  };

  static void _validateToken(String token) {
    if (token.length < minimumTokenLength ||
        token.length > maximumTokenLength ||
        !tokenPattern.hasMatch(token)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
  }
}
