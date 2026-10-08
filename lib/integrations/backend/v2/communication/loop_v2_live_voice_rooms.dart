import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/square/live_voice_rooms.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';

/// Strict codec for `GET /v2/voice-rooms/live` (S106 §7, decision 0110).
///
/// Every key is required and no other key is accepted: a page the client
/// cannot fully read renders as a failed read, never as a partial list.
abstract final class LoopV2LiveVoiceRoomCodec {
  static const pageKeys = <String>{
    'items',
    'nextCursor',
    'observedAt',
    'contractVersion',
  };

  static const itemKeys = <String>{
    'voiceRoomId',
    'communityId',
    'communityName',
    'communityLogoRef',
    'title',
    'host',
    'listenerCount',
    'speakerCount',
    'countsObservedAt',
    'startedAt',
    'joinable',
  };

  static const hostKeys = <String>{
    'publicProfileId',
    'displayName',
    'avatarRef',
  };

  static const maximumPageSize = 50;

  static LiveVoiceRoomPage page(Object? raw) {
    final root = LoopV2Contract.strictMap(raw, pageKeys);
    LoopV2ProjectionCodec.requireContractVersion(root);
    final items = LoopV2ProjectionCodec.requireList(
      root['items'],
      maximum: maximumPageSize,
    );
    final rooms = <LiveVoiceRoom>[for (final item in items) room(item)];
    final ids = rooms.map((room) => room.voiceRoomId).toSet();
    if (ids.length != rooms.length) LoopV2ProjectionCodec.invalid();
    return LiveVoiceRoomPage(
      items: List<LiveVoiceRoom>.unmodifiable(rooms),
      nextCursor: LoopV2ProjectionCodec.cursor(root, 'nextCursor'),
      observedAt: LoopV2ProjectionCodec.requireTimestamp(root, 'observedAt'),
    );
  }

  static LiveVoiceRoom room(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, itemKeys);
    final countsObservedAt = map['countsObservedAt'] == null
        ? null
        : LoopV2ProjectionCodec.requireTimestamp(map, 'countsObservedAt');
    return LiveVoiceRoom(
      voiceRoomId: _uuid(map, 'voiceRoomId'),
      communityId: _uuid(map, 'communityId'),
      communityName: LoopV2ProjectionCodec.requireText(map, 'communityName'),
      communityLogoRef: LoopV2ProjectionCodec.optionalPattern(
        map,
        'communityLogoRef',
        LoopV2ProjectionCodec.communityLogoPattern,
      ),
      title: LoopV2ProjectionCodec.optionalText(map, 'title'),
      host: host(map['host']),
      listenerCount: LoopV2ProjectionCodec.requireCount(map, 'listenerCount'),
      speakerCount: LoopV2ProjectionCodec.requireCount(map, 'speakerCount'),
      countsObservedAt: countsObservedAt,
      startedAt: LoopV2ProjectionCodec.requireTimestamp(map, 'startedAt'),
      joinable: LoopV2ProjectionCodec.requireBool(map, 'joinable'),
    );
  }

  /// An anonymous host carries no name, and then no address and no face
  /// either: a row may not point at a person it cannot name.
  static LiveVoiceRoomHost host(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, hostKeys);
    final displayName = LoopV2ProjectionCodec.optionalText(map, 'displayName');
    final publicProfileId = map['publicProfileId'] == null
        ? null
        : _uuid(map, 'publicProfileId');
    final avatarRef = LoopV2ProjectionCodec.optionalPattern(
      map,
      'avatarRef',
      LoopV2ProjectionCodec.avatarRefPattern,
    );
    if (displayName == null && (publicProfileId != null || avatarRef != null)) {
      LoopV2ProjectionCodec.invalid();
    }
    return LiveVoiceRoomHost(
      publicProfileId: publicProfileId,
      displayName: displayName,
      avatarRef: avatarRef,
    );
  }

  static String _uuid(Map<String, Object?> map, String key) =>
      LoopV2Contract.requiredString(
        map,
        key,
        pattern: LoopV2Contract.uuidPattern,
      );
}

/// Transport for the live list. Reading the provider issues no request.
final class DioLoopV2LiveVoiceRoomApi {
  DioLoopV2LiveVoiceRoomApi(this._dio);

  static const livePath = '/v2/voice-rooms/live';

  final Dio _dio;

  Future<LiveVoiceRoomPage> listLive({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  }) async {
    // The cursor carries the page size, so only the first page names one.
    if (cursor != null &&
        (cursor.length < 3 ||
            cursor.length > LoopV2ProjectionCodec.maximumCursorLength ||
            !LoopV2ProjectionCodec.cursorPattern.hasMatch(cursor))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        livePath,
        queryParameters: <String, Object?>{'cursor': ?cursor},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2LiveVoiceRoomCodec.page(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }
}

/// Authenticated adapter of [LiveVoiceRoomGateway].
///
/// A server that does not serve the route yet (`404`) or has the capability
/// closed (`503`) is the same answer to the reader: the list is unavailable.
/// Neither ever becomes an empty list or a fixture.
final class DioLoopV2LiveVoiceRoomGateway implements LiveVoiceRoomGateway {
  DioLoopV2LiveVoiceRoomGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final DioLoopV2LiveVoiceRoomApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<LiveVoiceRoomPage> listLive({String? cursor}) async {
    try {
      return await _session.execute(
        (accessToken) => _api.listLive(
          accessToken: accessToken,
          clientVersion: _clientMetadata.clientVersion,
          cursor: cursor,
        ),
      );
    } on LoopBackendFailure catch (failure) {
      throw CommunityGatewayException(
        liveVoiceRoomFailureKind(failure),
        reasonCode: failure.detailsSafe?.reasonCode,
      );
    } on CommunityGatewayException {
      rethrow;
    } catch (_) {
      throw const CommunityGatewayException(CommunityFailureKind.unexpected);
    }
  }
}

/// `404` and `503` close the list; everything else keeps the community
/// module's own reading of the failure.
CommunityFailureKind liveVoiceRoomFailureKind(LoopBackendFailure failure) {
  final status = failure.statusCode;
  if (status == 404 || status == 503) return CommunityFailureKind.unavailable;
  return communityFailureKindForV2(failure, write: false);
}

final loopV2LiveVoiceRoomApiProvider = Provider<DioLoopV2LiveVoiceRoomApi?>((
  ref,
) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2LiveVoiceRoomApi(dio);
});

/// Production live-room gateway for the current verified principal. It stays
/// unavailable, never a fixture, while any input is absent.
final loopV2LiveVoiceRoomGatewayProvider = Provider<LiveVoiceRoomGateway>((
  ref,
) {
  final api = ref.watch(loopV2LiveVoiceRoomApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableLiveVoiceRoomGateway();
  }
  return DioLoopV2LiveVoiceRoomGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});
