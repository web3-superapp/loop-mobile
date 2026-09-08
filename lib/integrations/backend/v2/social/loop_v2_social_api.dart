import 'package:dio/dio.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';

/// Strict V2 transport for the social graph: follow edges, blocks and
/// stranger message requests.
abstract interface class LoopV2SocialApi {
  Future<ConnectionPage> listConnections({
    required String accessToken,
    required String clientVersion,
    required ConnectionDirection direction,
    String? cursor,
  });

  Future<FollowOutcome> setFollowing({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String publicProfileId,
    required bool following,
  });

  Future<BlockPage> listBlocks({
    required String accessToken,
    required String clientVersion,
    required BlockKind kind,
    String? cursor,
  });

  Future<BlockEntry?> setBlocked({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required BlockKind kind,
    required String stableId,
    required bool blocked,
  });

  Future<MessageRequestPage> listMessageRequests({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  });

  Future<MessageRequestEntry> sendMessageRequest({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String publicProfileId,
  });

  Future<MessageRequestOutcome> decideMessageRequest({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String messageRequestId,
    required MessageRequestDecision decision,
  });
}

final class DioLoopV2SocialApi implements LoopV2SocialApi {
  DioLoopV2SocialApi(this._dio);

  static const connectionsPath = '/v2/connections';
  static const followPath = '/v2/connections/follow';
  static const blocksPath = '/v2/blocks';
  static const messageRequestsPath = '/v2/message-requests';

  final Dio _dio;

  static String _requireId(String value) {
    if (!LoopV2Contract.uuidPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static Map<String, Object?>? _cursorQuery(String? cursor) {
    if (cursor == null) return null;
    if (cursor.length < 3 ||
        cursor.length > LoopV2ProjectionCodec.maximumCursorLength ||
        !LoopV2ProjectionCodec.cursorPattern.hasMatch(cursor)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return <String, Object?>{'cursor': cursor};
  }

  static BlockEntry _blockEntry(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'kind',
      'stableId',
      'profile',
      'reasonCode',
      'createdAt',
    });
    final rawKind = map['kind'];
    final stableId = map['stableId'];
    if (rawKind is! String ||
        stableId is! String ||
        stableId.isEmpty ||
        stableId.length > 256) {
      LoopV2ProjectionCodec.invalid();
    }
    final kind = switch (rawKind) {
      'user' => BlockKind.user,
      'contract' => BlockKind.contract,
      'domain' => BlockKind.domain,
      _ => null,
    };
    if (kind == null) LoopV2ProjectionCodec.invalid();
    final rawProfile = map['profile'];
    return BlockEntry(
      kind: kind,
      stableId: stableId,
      profile: rawProfile == null
          ? null
          : LoopV2ProjectionCodec.profile(rawProfile),
      reasonCode: LoopV2Contract.requiredString(
        map,
        'reasonCode',
        pattern: LoopV2ProjectionCodec.blockReasonPattern,
      ),
      createdAt: LoopV2ProjectionCodec.requireTimestamp(map, 'createdAt'),
    );
  }

  @override
  Future<ConnectionPage> listConnections({
    required String accessToken,
    required String clientVersion,
    required ConnectionDirection direction,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        connectionsPath,
        queryParameters: <String, Object?>{
          'direction': direction.wireName,
          ...?_cursorQuery(cursor),
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'direction',
        'items',
        'counts',
        'nextCursor',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      if (root['direction'] != direction.wireName) {
        LoopV2ProjectionCodec.invalid();
      }
      final counts = LoopV2Contract.strictMap(root['counts'], const <String>{
        'following',
        'followers',
      });
      final items = <ConnectionEntry>[];
      for (final raw in LoopV2ProjectionCodec.requireList(
        root['items'],
        maximum: 50,
      )) {
        final item = LoopV2Contract.strictMap(raw, const <String>{
          'profile',
          'createdAt',
          'viewerFollows',
          'miningPower',
        });
        items.add(
          ConnectionEntry(
            profile: LoopV2ProjectionCodec.profile(item['profile']),
            createdAt: LoopV2ProjectionCodec.requireTimestamp(
              item,
              'createdAt',
            ),
            viewerFollows: LoopV2ProjectionCodec.requireBool(
              item,
              'viewerFollows',
            ),
            miningPower: LoopV2ProjectionCodec.unavailable(item['miningPower']),
          ),
        );
      }
      return ConnectionPage(
        direction: direction,
        items: List<ConnectionEntry>.unmodifiable(items),
        counts: ConnectionCounts(
          following: LoopV2ProjectionCodec.requireCount(counts, 'following'),
          followers: LoopV2ProjectionCodec.requireCount(counts, 'followers'),
        ),
        nextCursor: LoopV2ProjectionCodec.cursor(root, 'nextCursor'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  @override
  Future<FollowOutcome> setFollowing({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String publicProfileId,
    required bool following,
  }) async {
    final target = _requireId(publicProfileId);
    final path = '$followPath/$target';
    final options = LoopV2ModuleRequest.writeOptions(
      accessToken,
      clientVersion,
      idempotencyKey,
    );
    try {
      final response = following
          ? await _dio.post<Object?>(path, options: options)
          : await _dio.delete<Object?>(path, options: options);
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'profile',
        'viewerFollows',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      return FollowOutcome(
        profile: LoopV2ProjectionCodec.profile(root['profile']),
        viewerFollows: LoopV2ProjectionCodec.requireBool(root, 'viewerFollows'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.writeErrors,
      );
    }
  }

  @override
  Future<BlockPage> listBlocks({
    required String accessToken,
    required String clientVersion,
    required BlockKind kind,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        blocksPath,
        queryParameters: <String, Object?>{
          'kind': kind.wireName,
          ...?_cursorQuery(cursor),
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'kind',
        'items',
        'counts',
        'nextCursor',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      if (root['kind'] != kind.wireName) LoopV2ProjectionCodec.invalid();
      final counts = LoopV2Contract.strictMap(root['counts'], const <String>{
        'user',
      });
      final items = <BlockEntry>[
        for (final raw in LoopV2ProjectionCodec.requireList(
          root['items'],
          maximum: 50,
        ))
          _blockEntry(raw),
      ];
      if (items.any((item) => item.kind != kind)) {
        LoopV2ProjectionCodec.invalid();
      }
      return BlockPage(
        kind: kind,
        items: List<BlockEntry>.unmodifiable(items),
        userCount: LoopV2ProjectionCodec.requireCount(counts, 'user'),
        nextCursor: LoopV2ProjectionCodec.cursor(root, 'nextCursor'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  @override
  Future<BlockEntry?> setBlocked({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required BlockKind kind,
    required String stableId,
    required bool blocked,
  }) async {
    if (stableId.isEmpty || stableId.length > 256) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    final body = <String, Object?>{'kind': kind.wireName, 'stableId': stableId};
    final options = LoopV2ModuleRequest.writeOptions(
      accessToken,
      clientVersion,
      idempotencyKey,
      hasBody: true,
    );
    try {
      final response = blocked
          ? await _dio.post<Object?>(blocksPath, data: body, options: options)
          : await _dio.delete<Object?>(
              blocksPath,
              data: body,
              options: options,
            );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'block',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      final block = root['block'];
      return block == null ? null : _blockEntry(block);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.writeErrors,
      );
    }
  }

  @override
  Future<MessageRequestPage> listMessageRequests({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        messageRequestsPath,
        queryParameters: <String, Object?>{...?_cursorQuery(cursor)},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'items',
        'nextCursor',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      final items = <MessageRequestEntry>[];
      for (final raw in LoopV2ProjectionCodec.requireList(
        root['items'],
        maximum: 50,
      )) {
        items.add(
          _messageRequestEntry(
            LoopV2Contract.strictMap(raw, _messageRequestEntryKeys),
          ),
        );
      }
      return MessageRequestPage(
        items: List<MessageRequestEntry>.unmodifiable(items),
        nextCursor: LoopV2ProjectionCodec.cursor(root, 'nextCursor'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  static const _messageRequestEntryKeys = <String>{
    'messageRequestId',
    'profile',
    'createdAt',
    'expiresAt',
    'preview',
    'aiModeration',
  };

  static MessageRequestEntry _messageRequestEntry(Map<String, Object?> item) {
    return MessageRequestEntry(
      messageRequestId: LoopV2Contract.requiredString(
        item,
        'messageRequestId',
        pattern: LoopV2Contract.uuidPattern,
      ),
      profile: LoopV2ProjectionCodec.profile(item['profile']),
      createdAt: LoopV2ProjectionCodec.requireTimestamp(item, 'createdAt'),
      expiresAt: LoopV2ProjectionCodec.requireTimestamp(item, 'expiresAt'),
      preview: LoopV2ProjectionCodec.unavailable(item['preview']),
      aiModeration: LoopV2ProjectionCodec.unavailable(item['aiModeration']),
    );
  }

  @override
  Future<MessageRequestEntry> sendMessageRequest({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String publicProfileId,
  }) async {
    final target = _requireId(publicProfileId);
    try {
      final response = await _dio.post<Object?>(
        messageRequestsPath,
        data: <String, Object?>{'targetPublicProfileId': target},
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, <String>{
        ..._messageRequestEntryKeys,
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      final entry = _messageRequestEntry(root);
      // The response carries the recipient's identity; a different target
      // would mean the request did not go where the user aimed it.
      if (entry.profile.publicProfileId != target) {
        LoopV2ProjectionCodec.invalid();
      }
      return entry;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.writeErrors,
      );
    }
  }

  @override
  Future<MessageRequestOutcome> decideMessageRequest({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String messageRequestId,
    required MessageRequestDecision decision,
  }) async {
    final id = _requireId(messageRequestId);
    try {
      final response = await _dio.post<Object?>(
        '$messageRequestsPath/$id/decision',
        data: <String, Object?>{'decision': decision.wireName},
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'messageRequestId',
        'decision',
        'blocked',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      if (root['messageRequestId'] != id ||
          root['decision'] != decision.wireName) {
        LoopV2ProjectionCodec.invalid();
      }
      return MessageRequestOutcome(
        messageRequestId: id,
        decision: decision,
        blocked: LoopV2ProjectionCodec.requireBool(root, 'blocked'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.writeErrors,
      );
    }
  }
}
