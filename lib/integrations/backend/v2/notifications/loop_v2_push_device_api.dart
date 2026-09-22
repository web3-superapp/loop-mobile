import 'package:dio/dio.dart';
import 'package:loop_mobile/features/notifications/push_device_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';

/// Strict V2 transport for the account's push device token.
///
/// The registration is a full replacement keyed by `(account, platform,
/// token)`, so it carries no `Idempotency-Key`: repeating it is the same
/// statement, not a second one, and the provider reissues the same token on
/// every cold start. The revoke is the same statement with the opposite
/// answer.
abstract interface class LoopV2PushDeviceApi {
  Future<LoopPushTokenRegistration> registerToken({
    required String accessToken,
    required String clientVersion,
    required LoopPushPlatform platform,
    required String token,
    required String appVersion,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopPushTokenRegistration> revokeToken({
    required String accessToken,
    required String clientVersion,
    required LoopPushPlatform platform,
    required String token,
    LoopV2WriteOrigin? origin,
  });
}

final class DioLoopV2PushDeviceApi implements LoopV2PushDeviceApi {
  const DioLoopV2PushDeviceApi(this._dio);

  static const pushTokenPath = '/v2/devices/push-token';

  /// FCM registration tokens are ~160 characters today and APNs-derived ones
  /// are longer; the provider documents no maximum. The bound exists so a
  /// payload that is no longer a token cannot be sent as one.
  static const maximumTokenLength = 1024;
  static const minimumTokenLength = 32;

  /// A provider token is opaque, but it is never whitespace, never control
  /// characters and never a URL. Anything else is refused here rather than
  /// handed to the server.
  static final RegExp tokenPattern = RegExp(r'^[A-Za-z0-9_:.\-]+$');

  final Dio _dio;

  @override
  Future<LoopPushTokenRegistration> registerToken({
    required String accessToken,
    required String clientVersion,
    required LoopPushPlatform platform,
    required String token,
    required String appVersion,
    LoopV2WriteOrigin? origin,
  }) async {
    // `async`, so a malformed token is a failed Future like every other
    // refusal on this transport rather than a synchronous throw the caller
    // would have to guard separately.
    _validateToken(token);
    if (!LoopV2ModuleRequest.clientVersionPattern.hasMatch(appVersion)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return _exchange(
      accessToken: accessToken,
      clientVersion: clientVersion,
      origin: origin,
      expectRegistered: true,
      send: (options) => _dio.post<Object?>(
        pushTokenPath,
        data: <String, Object?>{
          'platform': platform.wireName,
          'token': token,
          'appVersion': appVersion,
        },
        options: options,
      ),
    );
  }

  @override
  Future<LoopPushTokenRegistration> revokeToken({
    required String accessToken,
    required String clientVersion,
    required LoopPushPlatform platform,
    required String token,
    LoopV2WriteOrigin? origin,
  }) async {
    _validateToken(token);
    return _exchange(
      accessToken: accessToken,
      clientVersion: clientVersion,
      origin: origin,
      expectRegistered: false,
      // The token travels in the body rather than the query string: it
      // addresses one device, and a query string is the part of a request that
      // ends up in access logs and proxy traces.
      send: (options) => _dio.delete<Object?>(
        pushTokenPath,
        data: <String, Object?>{'platform': platform.wireName, 'token': token},
        options: options,
      ),
    );
  }

  Future<LoopPushTokenRegistration> _exchange({
    required String accessToken,
    required String clientVersion,
    required LoopV2WriteOrigin? origin,
    required bool expectRegistered,
    required Future<Response<Object?>> Function(Options options) send,
  }) async {
    try {
      final response = await send(
        LoopV2ModuleRequest.casOptions(
          accessToken,
          clientVersion,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMapWithOptional(
        response.data,
        const <String>{'registered', 'observedAt'},
        const <String>{'contractVersion'},
      );
      if (root.containsKey('contractVersion')) {
        LoopV2ChainCodec.requireContractVersion(root);
      }
      // The server's own answer, not the status code, decides whether this
      // device is addressable. A `200` that says `registered: false` after a
      // registration is a refusal LOOP must not read as success.
      if (LoopV2ChainCodec.requireBool(root, 'registered') !=
          expectRegistered) {
        LoopV2ChainCodec.invalid();
      }
      return LoopPushTokenRegistration(
        registered: expectRegistered,
        observedAt: LoopV2ChainCodec.requireTimestamp(root, 'observedAt'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.writeErrors,
      );
    }
  }

  static void _validateToken(String token) {
    if (token.length < minimumTokenLength ||
        token.length > maximumTokenLength ||
        !tokenPattern.hasMatch(token)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
  }
}
