import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:uuid/uuid.dart';

/// `GET /v2/media/{mediaId}.webp` on the configured backend (S107 §1).
///
/// The route is public and immutable, so the address is the whole story: no
/// header, no token, and no request goes through Dio — the avatar widget
/// hands it to Flutter's image pipeline, which caches the decoded picture.
final class LoopV2MediaUrlResolver implements LoopMediaUrlResolver {
  LoopV2MediaUrlResolver(this._origin);

  static const mediaPathPrefix = '/v2/media/';

  final Uri _origin;

  @override
  String? urlFor(String mediaId) {
    if (!LoopV2Contract.uuidPattern.hasMatch(mediaId)) return null;
    return _origin.replace(path: '$mediaPathPrefix$mediaId.webp').toString();
  }
}

final loopV2MediaUrlResolverProvider = Provider<LoopMediaUrlResolver>((ref) {
  final endpoint = ref.watch(loopBackendEndpointProvider);
  if (endpoint == null) return const NoLoopMediaUrlResolver();
  return LoopV2MediaUrlResolver(endpoint.uri);
});

/// Strict codec for the `201` of `POST /v2/media/avatars`.
abstract final class LoopV2AvatarUploadCodec {
  static const keys = <String>{
    'mediaId',
    'ref',
    'url',
    'width',
    'height',
    'contractVersion',
  };

  static UploadedAvatar decode(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, keys);
    LoopV2ProjectionCodec.requireContractVersion(map);
    final mediaId = LoopV2Contract.requiredString(
      map,
      'mediaId',
      pattern: LoopV2Contract.uuidPattern,
    );
    // The reference and the address are both derived from the id, and a
    // response whose three disagree is not one this client can store.
    if (map['ref'] != 'avatar:media/$mediaId' ||
        map['url'] !=
            '${LoopV2MediaUrlResolver.mediaPathPrefix}$mediaId.webp') {
      LoopV2ProjectionCodec.invalid();
    }
    final width = LoopV2ProjectionCodec.requireCount(map, 'width');
    final height = LoopV2ProjectionCodec.requireCount(map, 'height');
    if (width == 0 || height == 0) LoopV2ProjectionCodec.invalid();
    return UploadedAvatar(
      mediaId: mediaId,
      avatarRef: 'avatar:media/$mediaId',
      width: width,
      height: height,
    );
  }
}

/// Transport for the avatar upload. One multipart field, `file`.
final class DioLoopV2AvatarUploadApi {
  DioLoopV2AvatarUploadApi(this._dio, {this._uuid = const Uuid()});

  static const uploadPath = '/v2/media/avatars';

  static const _errors = <int, Set<String>>{
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
  final Uuid _uuid;

  Future<UploadedAvatar> upload({
    required String accessToken,
    required String clientVersion,
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
        uploadPath,
        data: FormData.fromMap(<String, Object?>{
          'file': MultipartFile.fromBytes(
            bytes,
            filename: 'avatar.$subtype',
            contentType: DioMediaType('image', subtype),
          ),
        }),
        options: Options(
          headers: LoopV2ModuleRequest.writeHeaders(
            accessToken,
            clientVersion,
            _uuid.v4(),
          ),
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 201);
      return LoopV2AvatarUploadCodec.decode(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: _errors);
    }
  }
}

/// How one upload failure reads to the person who chose the picture.
///
/// The status decides: a route the server does not serve yet (`404`) and a
/// closed capability (`503`) are both "upload is not available", whatever
/// body came with them.
AvatarUploadFailureKind avatarUploadFailureKind(LoopBackendFailure failure) {
  final status = failure.statusCode;
  if (status == 404 || status == 503) {
    return AvatarUploadFailureKind.unavailable;
  }
  if (status == 429) return AvatarUploadFailureKind.rateLimited;
  if (status == 400 || status == 413 || status == 415 || status == 422) {
    return AvatarUploadFailureKind.rejected;
  }
  return switch (failure.kind) {
    LoopBackendFailureKind.connection ||
    LoopBackendFailureKind.timeout => AvatarUploadFailureKind.offline,
    LoopBackendFailureKind.invalidPayload =>
      AvatarUploadFailureKind.invalidData,
    LoopBackendFailureKind.invalidRequest => AvatarUploadFailureKind.rejected,
    LoopBackendFailureKind.unavailable ||
    LoopBackendFailureKind.authentication ||
    LoopBackendFailureKind.invalidConfiguration =>
      AvatarUploadFailureKind.unavailable,
    _ => AvatarUploadFailureKind.unexpected,
  };
}

final class DioLoopV2AvatarUploadGateway implements AvatarUploadGateway {
  DioLoopV2AvatarUploadGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final DioLoopV2AvatarUploadApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  AvatarUploadMode get mode => AvatarUploadMode.production;

  @override
  Future<UploadedAvatar> upload({
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      return await _session.execute(
        (accessToken) => _api.upload(
          accessToken: accessToken,
          clientVersion: _clientMetadata.clientVersion,
          bytes: bytes,
          contentType: contentType,
        ),
      );
    } on LoopBackendFailure catch (failure) {
      throw AvatarUploadException(avatarUploadFailureKind(failure));
    } on AvatarUploadException {
      rethrow;
    } catch (_) {
      throw const AvatarUploadException(AvatarUploadFailureKind.unexpected);
    }
  }
}

final loopV2AvatarUploadGatewayProvider = Provider<AvatarUploadGateway>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || metadata == null || session == null) {
    return const UnavailableAvatarUploadGateway();
  }
  return DioLoopV2AvatarUploadGateway(
    api: DioLoopV2AvatarUploadApi(dio),
    clientMetadata: metadata,
    session: session,
  );
});
