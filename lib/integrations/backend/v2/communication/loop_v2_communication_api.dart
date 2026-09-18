import 'package:dio/dio.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_communication_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';

/// Strict V2 transport for the `communication` module (loop-api decision
/// 0032).
///
/// It carries LOOP's own chat and voice-room resources only. Messages,
/// history, unread state and presence never travel through here: those stay
/// with the official Stream SDK.
abstract interface class LoopV2CommunicationApi {
  Future<ChatOperation> openDirectChannel({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String targetPublicProfileId,
  });

  Future<ChatOperation> getOperation({
    required String accessToken,
    required String clientVersion,
    required String operationId,
  });

  Future<void> leaveGroup({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String groupId,
  });

  Future<VoiceRoomCurrent> getCurrentVoiceRoom({
    required String accessToken,
    required String clientVersion,
    required String communityId,
  });

  /// Opens a community voice room. Owner or admin only; the Stream call is
  /// created by the server, never by the client.
  Future<VoiceRoomSnapshot> createVoiceRoom({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
  });

  Future<VoiceRoomSnapshot> getVoiceRoom({
    required String accessToken,
    required String clientVersion,
    required String voiceRoomId,
  });

  Future<List<VoiceRoomHandRaiseEntry>> listHandRaises({
    required String accessToken,
    required String clientVersion,
    required String voiceRoomId,
  });

  /// One page of the speaker or the listener roster. `limit` and `cursor` are
  /// mutually exclusive: the cursor already carries the page size, and it is
  /// bound to the view it was issued for.
  Future<VoiceRoomMemberPage> listMembers({
    required String accessToken,
    required String clientVersion,
    required String voiceRoomId,
    required VoiceRoomRosterView role,
    int? limit,
    String? cursor,
  });

  /// One of the room commands that answer with the full room resource.
  Future<VoiceRoomSnapshot> command({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String voiceRoomId,
    required VoiceRoomCommand command,
    String? publicProfileId,
  });
}

/// The room commands the client may issue. Each maps to exactly one path and
/// HTTP method; nothing is assembled from display copy.
enum VoiceRoomCommand {
  join('join', 'POST'),
  leave('leave', 'POST'),
  raiseHand('hand-raise', 'POST'),
  cancelHandRaise('hand-raise', 'DELETE'),
  inviteSpeaker('speakers', 'POST', targetsProfile: true),
  removeSpeaker('speakers', 'DELETE', targetsProfile: true),
  // Per-member mute (decision 0052) hangs off the same speaker resource, so
  // it is the one targeted command with a trailing segment of its own.
  muteSpeaker('speakers', 'POST', targetsProfile: true, suffix: '/mute'),
  // Decision 0053: the same resource, deleted. It is the only targeted
  // command a viewer that is not the host may send, and only against itself.
  unmuteSpeaker('speakers', 'DELETE', targetsProfile: true, suffix: '/mute'),
  muteAll('mute-all', 'POST'),
  endRoom('end', 'POST');

  const VoiceRoomCommand(
    this.segment,
    this.method, {
    this.targetsProfile = false,
    this.suffix = '',
  });

  final String segment;
  final String method;
  final bool targetsProfile;
  final String suffix;
}

final class DioLoopV2CommunicationApi implements LoopV2CommunicationApi {
  DioLoopV2CommunicationApi(this._dio);

  static const directChannelsPath = '/v2/chat/direct-channels';
  static const operationsPath = '/v2/chat/operations';
  static const groupsPath = '/v2/chat/groups';
  static const communitiesPath = '/v2/communities';
  static const voiceRoomsPath = '/v2/voice-rooms';

  /// The shared read catalogue already carries the `403` triple and `429`
  /// (R3-2), which is exactly what the Stream-backed paths answer with.
  static const readErrors = LoopV2ModuleRequest.readErrors;

  static const writeErrors = <int, Set<String>>{
    ...LoopV2ModuleRequest.writeErrors,
    429: <String>{'RATE_LIMITED'},
  };

  final Dio _dio;

  static String _requireId(String value) {
    if (!LoopV2Contract.uuidPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  /// A persistent operation answers `200` when it is terminal or an exact
  /// replay, and `202` while it is still running. Both are success; anything
  /// else is an invalid payload.
  static void _validateOperationStatus(Response<Object?> response) {
    final status = response.statusCode;
    if (status != 200 && status != 202) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    LoopV2Contract.validateSuccess(response, statusCode: status!);
  }

  ChatOperation _operation(Response<Object?> response) {
    _validateOperationStatus(response);
    final root = LoopV2Contract.strictMap(
      response.data,
      LoopV2CommunicationCodec.operationKeys,
    );
    final operation = LoopV2CommunicationCodec.operation(root);
    // A non-terminal answer must also address the poll location, so a lost
    // first response cannot leave the client without a next step.
    if (!operation.terminal && response.statusCode == 202) {
      final location = response.headers['location'];
      if (location == null ||
          location.length != 1 ||
          location.single != '$operationsPath/${operation.operationId}') {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
    }
    return operation;
  }

  @override
  Future<ChatOperation> openDirectChannel({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String targetPublicProfileId,
  }) async {
    final target = _requireId(targetPublicProfileId);
    try {
      final response = await _dio.post<Object?>(
        directChannelsPath,
        data: <String, Object?>{'targetPublicProfileId': target},
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
        ).copyWith(validateStatus: _acceptsAccepted),
      );
      final operation = _operation(response);
      if (operation.operationId != idempotencyKey ||
          operation.kind != ChatOperationKind.directGetOrCreate ||
          (operation.directResult != null &&
              operation.directResult!.targetPublicProfileId != target)) {
        LoopV2ProjectionCodec.invalid();
      }
      return operation;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  @override
  Future<ChatOperation> getOperation({
    required String accessToken,
    required String clientVersion,
    required String operationId,
  }) async {
    final id = _requireId(operationId);
    try {
      final response = await _dio.get<Object?>(
        '$operationsPath/$id',
        options: LoopV2ModuleRequest.readOptions(
          accessToken,
          clientVersion,
        ).copyWith(validateStatus: _acceptsAccepted),
      );
      final operation = _operation(response);
      if (operation.operationId != id) LoopV2ProjectionCodec.invalid();
      return operation;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  @override
  Future<void> leaveGroup({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String groupId,
  }) async {
    final id = _requireId(groupId);
    try {
      final response = await _dio.delete<Object?>(
        '$groupsPath/$id/membership',
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'groupId',
        'membership',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      // The server confirms the removal by echoing the group and a null
      // membership. Anything else is not a confirmed leave.
      if (root['groupId'] != id || root['membership'] != null) {
        LoopV2ProjectionCodec.invalid();
      }
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  @override
  Future<VoiceRoomCurrent> getCurrentVoiceRoom({
    required String accessToken,
    required String clientVersion,
    required String communityId,
  }) async {
    final id = _requireId(communityId);
    try {
      final response = await _dio.get<Object?>(
        '$communitiesPath/$id/voice-rooms/current',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'current',
        'reasonCode',
        'contractVersion',
      });
      final current = LoopV2CommunicationCodec.current(root);
      final snapshot = current.snapshot;
      if (snapshot != null && snapshot.room.communityId != id) {
        LoopV2ProjectionCodec.invalid();
      }
      return current;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  @override
  Future<VoiceRoomSnapshot> createVoiceRoom({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
  }) async {
    final id = _requireId(communityId);
    try {
      final response = await _dio.post<Object?>(
        '$communitiesPath/$id/voice-rooms',
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
        ),
      );
      // The room resource is created, so the only success is `201`.
      LoopV2Contract.validateSuccess(response, statusCode: 201);
      final root = LoopV2Contract.strictMap(
        response.data,
        LoopV2CommunicationCodec.snapshotKeys,
      );
      final snapshot = LoopV2CommunicationCodec.snapshot(root);
      // A room for another community would put the viewer in a room the page
      // never asked for.
      if (snapshot.room.communityId != id) LoopV2ProjectionCodec.invalid();
      return snapshot;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  @override
  Future<VoiceRoomSnapshot> getVoiceRoom({
    required String accessToken,
    required String clientVersion,
    required String voiceRoomId,
  }) async {
    final id = _requireId(voiceRoomId);
    try {
      final response = await _dio.get<Object?>(
        '$voiceRoomsPath/$id',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      return _snapshot(response, id);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  @override
  Future<List<VoiceRoomHandRaiseEntry>> listHandRaises({
    required String accessToken,
    required String clientVersion,
    required String voiceRoomId,
  }) async {
    final id = _requireId(voiceRoomId);
    try {
      final response = await _dio.get<Object?>(
        '$voiceRoomsPath/$id/hand-raises',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(
        response.data,
        LoopV2CommunicationCodec.handRaisePageKeys,
      );
      return LoopV2CommunicationCodec.handRaises(root);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  @override
  Future<VoiceRoomMemberPage> listMembers({
    required String accessToken,
    required String clientVersion,
    required String voiceRoomId,
    required VoiceRoomRosterView role,
    int? limit,
    String? cursor,
  }) async {
    final id = _requireId(voiceRoomId);
    // The cursor carries the page size, so asking for both is a request the
    // server would reject; it is refused here rather than sent.
    if (cursor != null && limit != null) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    if (limit != null && (limit < 1 || limit > 100)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    if (cursor != null &&
        (cursor.length < 3 ||
            cursor.length > LoopV2ProjectionCodec.maximumCursorLength ||
            !LoopV2ProjectionCodec.cursorPattern.hasMatch(cursor))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        '$voiceRoomsPath/$id/members',
        queryParameters: <String, Object?>{
          'role': role.wireName,
          'limit': ?limit,
          'cursor': ?cursor,
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(
        response.data,
        LoopV2CommunicationCodec.memberPageKeys,
      );
      final page = LoopV2CommunicationCodec.members(root);
      // A page of the other view would be rendered under this one's heading.
      if (page.view != role) LoopV2ProjectionCodec.invalid();
      return page;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  @override
  Future<VoiceRoomSnapshot> command({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String voiceRoomId,
    required VoiceRoomCommand command,
    String? publicProfileId,
  }) async {
    final id = _requireId(voiceRoomId);
    if (command.targetsProfile != (publicProfileId != null)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    final path = command.targetsProfile
        ? '$voiceRoomsPath/$id/${command.segment}/'
              '${_requireId(publicProfileId!)}${command.suffix}'
        : '$voiceRoomsPath/$id/${command.segment}';
    final options = LoopV2ModuleRequest.writeOptions(
      accessToken,
      clientVersion,
      idempotencyKey,
    );
    try {
      final response = command.method == 'DELETE'
          ? await _dio.delete<Object?>(path, options: options)
          : await _dio.post<Object?>(path, options: options);
      return _snapshot(response, id);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  VoiceRoomSnapshot _snapshot(Response<Object?> response, String voiceRoomId) {
    LoopV2Contract.validateSuccess(response, statusCode: 200);
    final root = LoopV2Contract.strictMap(
      response.data,
      LoopV2CommunicationCodec.snapshotKeys,
    );
    final snapshot = LoopV2CommunicationCodec.snapshot(root);
    if (snapshot.room.voiceRoomId != voiceRoomId) {
      LoopV2ProjectionCodec.invalid();
    }
    return snapshot;
  }

  /// `202 Accepted` is a success for the persistent-operation endpoints, so
  /// Dio must not raise it as a bad response.
  static bool _acceptsAccepted(int? status) => status == 200 || status == 202;
}
