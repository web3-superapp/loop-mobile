import 'package:dio/dio.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/social/loop_social_transport_models.dart';

/// Strict authenticated transport for LOOP Social and backend-created Chat
/// channel operations. Authentication lifecycle and operation reconciliation
/// are intentionally owned by the principal-bound gateway above this class.
final class DioLoopSocialRepository {
  DioLoopSocialRepository(this._dio);

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _publicCodePattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
  static final RegExp _groupChannelIdPattern = RegExp(
    r'^loop_group_[a-z0-9_-]{8,}$',
  );
  static final RegExp _directChannelIdPattern = RegExp(
    r'^loop_direct_[a-z0-9_-]{8,}$',
  );
  static const Set<String> _socialOperationErrorCodes = <String>{
    'target_unavailable',
    'profile_required',
    'incoming_request_pending',
    'outgoing_request_pending',
    'already_friends',
    'friend_request_cooldown',
    'friend_request_not_found',
    'friend_request_already_decided',
  };

  final Dio _dio;

  Future<FriendDirectoryPage> loadFriendPage({
    required String accessToken,
    String? cursor,
  }) async {
    final response = await _get(
      '/v1/friends',
      endpoint: _LoopSocialEndpoint.friends,
      accessToken: accessToken,
      queryParameters: cursor == null
          ? const <String, Object?>{'limit': 20}
          : <String, Object?>{'cursor': cursor},
    );
    return _decodePayload(() {
      final root = _strictMap(response.data, const <String>{
        'items',
        'next_cursor',
      });
      final items = _strictList(root['items'])
          .map(_parseFriendIdentity)
          .toList(growable: false);
      return FriendDirectoryPage(
        items: items,
        nextCursor: _nullableString(root['next_cursor'], maximum: 1024),
      );
    });
  }

  Future<FriendSearchPage> searchFriends({
    required String accessToken,
    required String normalizedQuery,
  }) async {
    final response = await _get(
      '/v1/friends/search',
      endpoint: _LoopSocialEndpoint.friendSearch,
      accessToken: accessToken,
      queryParameters: <String, Object?>{
        'alias_prefix': normalizeFriendAliasQuery(normalizedQuery),
        'limit': 20,
      },
    );
    return _decodePayload(() {
      final root = _strictMap(response.data, const <String>{
        'items',
        'truncated',
      });
      final truncated = root['truncated'];
      if (truncated is! bool) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      return FriendSearchPage(
        items: _strictList(root['items']).map(_parseSearchResult),
        truncated: truncated,
      );
    });
  }

  Future<FriendRequestPage> loadFriendRequests({
    required String accessToken,
    required FriendRequestDirection direction,
    String? cursor,
  }) async {
    final directionWire = switch (direction) {
      FriendRequestDirection.incoming => 'incoming',
      FriendRequestDirection.outgoing => 'outgoing',
    };
    final query = <String, Object?>{
      'direction': directionWire,
      'status': 'pending',
      if (cursor == null) 'limit': 20 else 'cursor': cursor,
    };
    final response = await _get(
      '/v1/friend-requests',
      endpoint: _LoopSocialEndpoint.friendRequests,
      accessToken: accessToken,
      queryParameters: query,
    );
    return _decodePayload(() {
      final root = _strictMap(response.data, const <String>{
        'items',
        'next_cursor',
      });
      final items = _strictList(root['items'])
          .map((value) => _parseFriendRequest(value, direction))
          .toList(growable: false);
      return FriendRequestPage(
        items: items,
        nextCursor: _nullableString(root['next_cursor'], maximum: 1024),
      );
    });
  }

  Future<LoopSocialOperation> getSocialOperation({
    required String accessToken,
    required String operationId,
    required LoopSocialOperationKind expectedKind,
  }) async {
    validateFriendOperationId(operationId);
    final response = await _get(
      '/v1/social/operations/$operationId',
      endpoint: _LoopSocialEndpoint.socialOperation,
      accessToken: accessToken,
    );
    return _decodePayload(
      () => _parseSocialOperation(response, operationId, expectedKind),
    );
  }

  Future<LoopSocialOperation> sendFriendRequest({
    required String accessToken,
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) async {
    validateFriendOperationId(operationId);
    final response = await _post(
      '/v1/friend-requests',
      endpoint: _LoopSocialEndpoint.friendRequestSend,
      accessToken: accessToken,
      operationId: operationId,
      data: <String, Object?>{
        'target_public_profile_id': targetProfileRef.wireValue,
      },
    );
    return _decodePayload(
      () => _parseSocialOperation(
        response,
        operationId,
        LoopSocialOperationKind.friendRequestSend,
      ),
    );
  }

  Future<LoopSocialOperation> decideFriendRequest({
    required String accessToken,
    required String operationId,
    required String friendRequestId,
    required FriendRequestDecision decision,
  }) async {
    validateFriendOperationId(operationId);
    validateFriendEntityId(friendRequestId);
    final response = await _post(
      '/v1/friend-requests/$friendRequestId/decision',
      endpoint: _LoopSocialEndpoint.friendRequestDecision,
      accessToken: accessToken,
      operationId: operationId,
      data: <String, Object?>{
        'decision': switch (decision) {
          FriendRequestDecision.accept => 'accept',
          FriendRequestDecision.reject => 'reject',
        },
      },
    );
    return _decodePayload(
      () => _parseSocialOperation(
        response,
        operationId,
        LoopSocialOperationKind.friendRequestDecide,
      ),
    );
  }

  Future<LoopChatOperation> getChatOperation({
    required String accessToken,
    required String operationId,
    required LoopChatOperationKind expectedKind,
  }) async {
    validateFriendOperationId(operationId);
    final response = await _get(
      '/v1/chat/operations/$operationId',
      endpoint: _LoopSocialEndpoint.chatOperation,
      accessToken: accessToken,
      acceptedStatuses: const <int>{200, 202},
    );
    return _decodePayload(
      () => _parseChatOperation(response, operationId, expectedKind),
    );
  }

  Future<LoopChatOperation> createGroup({
    required String accessToken,
    required String operationId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) async {
    validateFriendOperationId(operationId);
    final name = normalizeFriendGroupName(normalizedName);
    final selected = validateSelectedFriendRefs(friendRefs);
    final response = await _post(
      '/v1/chat/groups',
      endpoint: _LoopSocialEndpoint.groupCreate,
      accessToken: accessToken,
      operationId: operationId,
      data: <String, Object?>{
        'name': name,
        'friend_public_profile_ids': selected
            .map((item) => item.wireValue)
            .toList(growable: false),
      },
      acceptedStatuses: const <int>{200, 202},
    );
    return _decodePayload(
      () => _parseChatOperation(
        response,
        operationId,
        LoopChatOperationKind.groupCreate,
      ),
    );
  }

  Future<LoopChatOperation> createDirectChannel({
    required String accessToken,
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) async {
    validateFriendOperationId(operationId);
    final response = await _post(
      '/v1/chat/direct-channels',
      endpoint: _LoopSocialEndpoint.directCreate,
      accessToken: accessToken,
      operationId: operationId,
      data: <String, Object?>{
        'target_public_profile_id': targetProfileRef.wireValue,
      },
      acceptedStatuses: const <int>{200, 202},
    );
    return _decodePayload(
      () => _parseChatOperation(
        response,
        operationId,
        LoopChatOperationKind.directGetOrCreate,
      ),
    );
  }

  Future<Response<Object?>> _get(
    String path, {
    required _LoopSocialEndpoint endpoint,
    required String accessToken,
    Map<String, Object?>? queryParameters,
    Set<int> acceptedStatuses = const <int>{200},
  }) {
    return _request(
      () => _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
        options: _options(accessToken),
      ),
      acceptedStatuses,
      endpoint,
    );
  }

  Future<Response<Object?>> _post(
    String path, {
    required _LoopSocialEndpoint endpoint,
    required String accessToken,
    required String operationId,
    required Map<String, Object?> data,
    Set<int> acceptedStatuses = const <int>{200},
  }) {
    return _request(
      () => _dio.post<Object?>(
        path,
        data: data,
        options: _options(accessToken, operationId: operationId),
      ),
      acceptedStatuses,
      endpoint,
    );
  }

  Future<Response<Object?>> _request(
    Future<Response<Object?>> Function() request,
    Set<int> acceptedStatuses,
    _LoopSocialEndpoint endpoint,
  ) async {
    try {
      final response = await request();
      if (!acceptedStatuses.contains(response.statusCode) ||
          !_hasNoStore(response.headers) ||
          !_hasCanonicalRequestId(response.headers)) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      return response;
    } on DioException catch (error) {
      throw _mapDioFailure(error, endpoint);
    }
  }

  Options _options(String accessToken, {String? operationId}) {
    if (accessToken.isEmpty || accessToken != accessToken.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
    if (operationId != null) validateFriendOperationId(operationId);
    return Options(
      headers: <String, String>{
        'authorization': 'Bearer $accessToken',
        'accept': Headers.jsonContentType,
        if (operationId != null) ...<String, String>{
          Headers.contentTypeHeader: Headers.jsonContentType,
          'idempotency-key': operationId,
        },
      },
      followRedirects: false,
      responseType: ResponseType.json,
    );
  }

  FriendIdentity _parseFriendIdentity(Object? value) {
    final item = _strictMap(value, const <String>{
      'public_profile_id',
      'profile_code',
      'alias',
      'avatar_ref',
      'accepted_at',
    });
    return FriendIdentity.fromBackend(
      publicProfileId: FriendProfileRef.fromPublicProfileId(
        _requiredString(item['public_profile_id'], maximum: 64),
      ),
      profileCode: _requiredString(item['profile_code'], maximum: 10),
      alias: _nullableString(item['alias'], maximum: 256),
      avatarRef: _nullableString(item['avatar_ref'], maximum: 512),
      acceptedAt: _requiredDateTime(item['accepted_at']),
    );
  }

  FriendSearchResult _parseSearchResult(Object? value) {
    final item = _strictMap(value, const <String>{
      'public_profile_id',
      'profile_code',
      'alias',
      'avatar_ref',
      'relationship',
      'friend_request_id',
    });
    final relationship = switch (item['relationship']) {
      'none' => FriendRelationship.none,
      'outgoing_pending' => FriendRelationship.outgoingPending,
      'incoming_pending' => FriendRelationship.incomingPending,
      'friend' => FriendRelationship.friend,
      _ => throw const LoopBackendFailure(
        LoopBackendFailureKind.invalidPayload,
      ),
    };
    return FriendSearchResult(
      identity: FriendIdentity.fromBackend(
        publicProfileId: FriendProfileRef.fromPublicProfileId(
          _requiredString(item['public_profile_id'], maximum: 64),
        ),
        profileCode: _requiredString(item['profile_code'], maximum: 10),
        alias: _requiredString(item['alias'], maximum: 256),
        avatarRef: _nullableString(item['avatar_ref'], maximum: 512),
      ),
      relationship: relationship,
      friendRequestId: _nullableString(item['friend_request_id'], maximum: 64),
    );
  }

  FriendRequestRecord _parseFriendRequest(
    Object? value,
    FriendRequestDirection expectedDirection,
  ) {
    final item = _strictMap(value, const <String>{
      'friend_request_id',
      'counterparty',
      'direction',
      'status',
      'created_at',
      'expires_at',
    });
    final directionWire = switch (expectedDirection) {
      FriendRequestDirection.incoming => 'incoming',
      FriendRequestDirection.outgoing => 'outgoing',
    };
    if (item['direction'] != directionWire || item['status'] != 'pending') {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final counterparty = _strictMap(item['counterparty'], const <String>{
      'public_profile_id',
      'profile_code',
      'alias',
      'avatar_ref',
    });
    return FriendRequestRecord(
      friendRequestId: _requiredString(item['friend_request_id'], maximum: 64),
      counterparty: FriendIdentity.fromBackend(
        publicProfileId: FriendProfileRef.fromPublicProfileId(
          _requiredString(counterparty['public_profile_id'], maximum: 64),
        ),
        profileCode: _requiredString(counterparty['profile_code'], maximum: 10),
        alias: _nullableString(counterparty['alias'], maximum: 256),
        avatarRef: _nullableString(counterparty['avatar_ref'], maximum: 512),
      ),
      direction: expectedDirection,
      createdAt: _requiredDateTime(item['created_at']),
      expiresAt: _requiredDateTime(item['expires_at']),
    );
  }

  LoopSocialOperation _parseSocialOperation(
    Response<Object?> response,
    String expectedOperationId,
    LoopSocialOperationKind expectedKind,
  ) {
    if (response.statusCode != 200) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final root = _strictMap(response.data, const <String>{
      'operation_id',
      'kind',
      'status',
      'terminal',
      'retry_after_ms',
      'result',
      'error',
      'created_at',
      'updated_at',
    });
    final operationId = _requiredString(root['operation_id'], maximum: 64);
    final kind = switch (root['kind']) {
      'friend_request_send' => LoopSocialOperationKind.friendRequestSend,
      'friend_request_decide' => LoopSocialOperationKind.friendRequestDecide,
      _ => throw const LoopBackendFailure(
        LoopBackendFailureKind.invalidPayload,
      ),
    };
    final status = switch (root['status']) {
      'succeeded' => LoopSocialOperationStatus.succeeded,
      'failed' => LoopSocialOperationStatus.failed,
      _ => throw const LoopBackendFailure(
        LoopBackendFailureKind.invalidPayload,
      ),
    };
    if (operationId != expectedOperationId ||
        kind != expectedKind ||
        root['terminal'] != true ||
        root['retry_after_ms'] != null) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    _requiredDateTime(root['created_at']);
    _requiredDateTime(root['updated_at']);

    LoopSocialOperationResult? result;
    if (root['result'] != null) {
      final rawResult = _strictMap(root['result'], const <String>{
        'friend_request_id',
        'status',
      });
      result = LoopSocialOperationResult(
        friendRequestId: validateFriendEntityId(
          _requiredString(rawResult['friend_request_id'], maximum: 64),
        ),
        status: switch (rawResult['status']) {
          'pending' => LoopSocialResultStatus.pending,
          'accepted' => LoopSocialResultStatus.accepted,
          'rejected' => LoopSocialResultStatus.rejected,
          'expired' => LoopSocialResultStatus.expired,
          _ => throw const LoopBackendFailure(
            LoopBackendFailureKind.invalidPayload,
          ),
        },
      );
    }
    final errorCode = _parseOperationError(root['error']);
    if (errorCode != null && !_socialOperationErrorCodes.contains(errorCode)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final validTerminal = switch (status) {
      LoopSocialOperationStatus.succeeded =>
        result != null && errorCode == null,
      LoopSocialOperationStatus.failed => result == null && errorCode != null,
    };
    if (!validTerminal) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return LoopSocialOperation(
      operationId: operationId,
      kind: kind,
      status: status,
      result: result,
      errorCode: errorCode,
    );
  }

  LoopChatOperation _parseChatOperation(
    Response<Object?> response,
    String expectedOperationId,
    LoopChatOperationKind expectedKind,
  ) {
    final root = _strictMap(response.data, const <String>{
      'operation_id',
      'kind',
      'status',
      'terminal',
      'retry_after_ms',
      'result',
      'error',
      'created_at',
      'updated_at',
    });
    final operationId = _requiredString(root['operation_id'], maximum: 64);
    final kind = switch (root['kind']) {
      'group_create' => LoopChatOperationKind.groupCreate,
      'direct_get_or_create' => LoopChatOperationKind.directGetOrCreate,
      _ => throw const LoopBackendFailure(
        LoopBackendFailureKind.invalidPayload,
      ),
    };
    final status = switch (root['status']) {
      'pending' => LoopChatOperationStatus.pending,
      'submitting' => LoopChatOperationStatus.submitting,
      'reconciling' => LoopChatOperationStatus.reconciling,
      'succeeded' => LoopChatOperationStatus.succeeded,
      'failed' => LoopChatOperationStatus.failed,
      'operator_required' => LoopChatOperationStatus.operatorRequired,
      _ => throw const LoopBackendFailure(
        LoopBackendFailureKind.invalidPayload,
      ),
    };
    final terminal = root['terminal'];
    if (operationId != expectedOperationId ||
        kind != expectedKind ||
        terminal is! bool) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    _requiredDateTime(root['created_at']);
    _requiredDateTime(root['updated_at']);

    final bodyRetry = _nullableRetryDelay(root['retry_after_ms']);
    final result = root['result'] == null
        ? null
        : _parseChatResult(root['result'], expectedKind);
    final errorCode = _parseOperationError(root['error']);
    Duration? retryDelay;

    if (response.statusCode == 202) {
      final locationValues = response.headers['location'];
      final retryValues = response.headers['retry-after'];
      final headerSeconds = retryValues?.length == 1
          ? int.tryParse(retryValues!.single)
          : null;
      final expectedLocation = '/v1/chat/operations/$expectedOperationId';
      final nonterminalStatus =
          status == LoopChatOperationStatus.pending ||
          status == LoopChatOperationStatus.submitting ||
          status == LoopChatOperationStatus.reconciling;
      if (terminal ||
          !nonterminalStatus ||
          result != null ||
          errorCode != null ||
          bodyRetry == null ||
          locationValues?.length != 1 ||
          locationValues!.single != expectedLocation ||
          headerSeconds == null ||
          headerSeconds < 1 ||
          headerSeconds > 60) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      final headerDelay = Duration(seconds: headerSeconds);
      retryDelay = headerDelay > bodyRetry ? headerDelay : bodyRetry;
    } else if (response.statusCode == 200) {
      final validTerminalStatus =
          status == LoopChatOperationStatus.succeeded ||
          status == LoopChatOperationStatus.failed ||
          status == LoopChatOperationStatus.operatorRequired;
      final validPayload = switch (status) {
        LoopChatOperationStatus.succeeded =>
          result != null && errorCode == null,
        LoopChatOperationStatus.failed ||
        LoopChatOperationStatus.operatorRequired =>
          result == null && errorCode != null,
        _ => false,
      };
      if (!terminal ||
          !validTerminalStatus ||
          bodyRetry != null ||
          !validPayload) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
    } else {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    return LoopChatOperation(
      operationId: operationId,
      kind: kind,
      status: status,
      terminal: terminal,
      retryDelay: retryDelay,
      result: result,
      errorCode: errorCode,
    );
  }

  LoopChatOperationResult _parseChatResult(
    Object? value,
    LoopChatOperationKind expectedKind,
  ) {
    return switch (expectedKind) {
      LoopChatOperationKind.groupCreate => _parseChatGroupResult(value),
      LoopChatOperationKind.directGetOrCreate => _parseChatDirectResult(value),
    };
  }

  LoopChatGroupResult _parseChatGroupResult(Object? value) {
    final result = _strictMap(value, const <String>{
      'group_id',
      'name',
      'friend_public_profile_ids',
      'stream_cid',
    });
    final refs = _strictList(result['friend_public_profile_ids'])
        .map(
          (item) => FriendProfileRef.fromPublicProfileId(
            _requiredString(item, maximum: 64),
          ),
        )
        .toList(growable: false);
    validateSelectedFriendRefs(refs);
    final streamCid = _requiredString(result['stream_cid'], maximum: 255);
    final address = parseLoopStreamChannelCid(streamCid);
    if (address == null || !_groupChannelIdPattern.hasMatch(address.id)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return LoopChatGroupResult(
      groupId: validateFriendEntityId(
        _requiredString(result['group_id'], maximum: 64),
      ),
      name: normalizeFriendGroupName(
        _requiredString(result['name'], maximum: 512),
      ),
      friendProfileRefs: List<FriendProfileRef>.unmodifiable(refs),
      streamCid: streamCid,
    );
  }

  LoopChatDirectResult _parseChatDirectResult(Object? value) {
    final result = _strictMap(value, const <String>{
      'target_public_profile_id',
      'stream_cid',
    });
    final streamCid = _requiredString(result['stream_cid'], maximum: 255);
    final address = parseLoopStreamChannelCid(streamCid);
    if (address == null || !_directChannelIdPattern.hasMatch(address.id)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return LoopChatDirectResult(
      targetProfileRef: FriendProfileRef.fromPublicProfileId(
        _requiredString(result['target_public_profile_id'], maximum: 64),
      ),
      streamCid: streamCid,
    );
  }

  String? _parseOperationError(Object? value) {
    if (value == null) return null;
    final error = _strictMap(value, const <String>{'code'});
    final code = _requiredString(error['code'], maximum: 64);
    if (!_publicCodePattern.hasMatch(code)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return code;
  }

  Duration? _nullableRetryDelay(Object? value) {
    if (value == null) return null;
    if (value is! int || value < 1 || value > 60000) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return Duration(milliseconds: value);
  }

  Exception _mapDioFailure(DioException error, _LoopSocialEndpoint endpoint) {
    final statusCode = error.response?.statusCode;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.transformTimeout) {
      return const LoopBackendFailure(LoopBackendFailureKind.timeout);
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.badCertificate) {
      return const LoopBackendFailure(LoopBackendFailureKind.connection);
    }
    if (error.type == DioExceptionType.cancel) {
      return const LoopBackendFailure(LoopBackendFailureKind.cancelled);
    }
    if (error.type != DioExceptionType.badResponse || statusCode == null) {
      return const LoopBackendFailure(LoopBackendFailureKind.unexpected);
    }
    final metadata = _parseErrorMetadata(error.response);
    if (metadata == null ||
        !_errorCodeMatchesEndpoint(
          endpoint: endpoint,
          statusCode: statusCode,
          code: metadata.code,
        )) {
      return LoopBackendFailure(
        LoopBackendFailureKind.invalidPayload,
        statusCode: statusCode,
      );
    }
    if (statusCode == 401) {
      return LoopBackendFailure(
        LoopBackendFailureKind.authentication,
        statusCode: statusCode,
        code: metadata.code,
        requestId: metadata.requestId,
      );
    }
    if (statusCode == 409 && metadata.code == 'bootstrap_required') {
      return LoopBackendFailure(
        LoopBackendFailureKind.invalidRequest,
        statusCode: statusCode,
        code: metadata.code,
        requestId: metadata.requestId,
      );
    }
    if (statusCode == 503 && metadata.code == 'request_timeout') {
      return LoopBackendFailure(
        LoopBackendFailureKind.timeout,
        statusCode: statusCode,
        code: metadata.code,
        requestId: metadata.requestId,
      );
    }
    if (statusCode >= 500) {
      return LoopBackendFailure(
        LoopBackendFailureKind.unavailable,
        statusCode: statusCode,
        code: metadata.code,
        requestId: metadata.requestId,
      );
    }
    return LoopSocialHttpFailure(
      statusCode: statusCode,
      code: metadata.code,
      requestId: metadata.requestId,
      retryAfter: statusCode == 429
          ? _parseRetryAfter(error.response?.headers)
          : null,
    );
  }

  bool _errorCodeMatchesEndpoint({
    required _LoopSocialEndpoint endpoint,
    required int statusCode,
    required String code,
  }) {
    if (statusCode == 400) return code == 'invalid_request';
    if (statusCode == 401) {
      return code == 'authentication_required' ||
          code == 'invalid_access_token';
    }
    if (statusCode == 500) return code == 'internal_error';
    if (statusCode == 503) {
      if (endpoint.isChat) {
        return code == 'authentication_unavailable' ||
            code == 'chat_unavailable' ||
            code == 'request_timeout';
      }
      return code == 'authentication_unavailable' ||
          code == 'social_unavailable' ||
          code == 'request_timeout';
    }
    if (endpoint.isChat) {
      return switch (statusCode) {
        404 when endpoint == _LoopSocialEndpoint.chatOperation =>
          code == 'chat_operation_not_found',
        404 => code == 'target_unavailable',
        409 when endpoint == _LoopSocialEndpoint.chatOperation =>
          code == 'bootstrap_required',
        409 => code == 'bootstrap_required' || code == 'idempotency_conflict',
        _ => false,
      };
    }
    return switch (statusCode) {
      404 when endpoint == _LoopSocialEndpoint.friendRequestSend =>
        code == 'target_unavailable',
      404 when endpoint == _LoopSocialEndpoint.friendRequestDecision =>
        code == 'friend_request_not_found',
      404 when endpoint == _LoopSocialEndpoint.socialOperation =>
        code == 'social_operation_not_found',
      409 => const <String>{
        'bootstrap_required',
        'version_conflict',
        'idempotency_conflict',
        'profile_required',
        'incoming_request_pending',
        'outgoing_request_pending',
        'already_friends',
        'friend_request_cooldown',
        'friend_request_already_decided',
      }.contains(code),
      429 => code == 'search_rate_limited' || code == 'social_rate_limited',
      _ => false,
    };
  }

  _LoopSocialErrorMetadata? _parseErrorMetadata(Response<Object?>? response) {
    if (response == null ||
        !_hasNoStore(response.headers) ||
        !_hasCanonicalRequestId(response.headers)) {
      return null;
    }
    Map<String, Object?> root;
    try {
      root = _strictMap(response.data, const <String>{
        'code',
        'message',
        'request_id',
      });
    } on LoopBackendFailure {
      return null;
    }
    final code = root['code'];
    final message = root['message'];
    final requestId = root['request_id'];
    final headerRequestId = response.headers['x-request-id']!.single;
    if (code is! String ||
        !_publicCodePattern.hasMatch(code) ||
        message is! String ||
        message.isEmpty ||
        message.length > 512 ||
        requestId is! String ||
        !_uuidPattern.hasMatch(requestId) ||
        requestId != headerRequestId) {
      return null;
    }
    return _LoopSocialErrorMetadata(code: code, requestId: requestId);
  }

  static Map<String, Object?> _strictMap(
    Object? value,
    Set<String> expectedKeys,
  ) {
    if (value is! Map) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || result.containsKey(key)) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      result[key] = entry.value;
    }
    if (result.length != expectedKeys.length ||
        !expectedKeys.every(result.containsKey)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return result;
  }

  static List<Object?> _strictList(Object? value) {
    if (value is! List) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return List<Object?>.unmodifiable(value);
  }

  static String _requiredString(Object? value, {required int maximum}) {
    if (value is! String ||
        value.isEmpty ||
        value != value.trim() ||
        value.length > maximum) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return value;
  }

  static String? _nullableString(Object? value, {required int maximum}) {
    if (value == null) return null;
    return _requiredString(value, maximum: maximum);
  }

  static DateTime _requiredDateTime(Object? value) {
    if (value is! String || value.length > 64 || !value.endsWith('Z')) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final parsed = DateTime.tryParse(value)?.toUtc();
    if (parsed == null) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return parsed;
  }

  static bool _hasNoStore(Headers headers) {
    final directives = headers['cache-control']
        ?.expand((value) => value.split(','))
        .map((value) => value.trim().toLowerCase());
    return directives?.contains('no-store') ?? false;
  }

  static bool _hasCanonicalRequestId(Headers headers) {
    final values = headers['x-request-id'];
    return values?.length == 1 && _uuidPattern.hasMatch(values!.single);
  }

  static Duration _parseRetryAfter(Headers? headers) {
    final values = headers?['retry-after'];
    final seconds = values?.length == 1 ? int.tryParse(values!.single) : null;
    if (seconds == null || seconds < 1 || seconds > 3600) {
      return const Duration(seconds: 60);
    }
    return Duration(seconds: seconds);
  }

  static T _decodePayload<T>(T Function() decode) {
    try {
      return decode();
    } on InvalidFriendContractException {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
  }
}

final class _LoopSocialErrorMetadata {
  const _LoopSocialErrorMetadata({required this.code, required this.requestId});

  final String code;
  final String requestId;
}

enum _LoopSocialEndpoint {
  friends,
  friendSearch,
  friendRequests,
  friendRequestSend,
  friendRequestDecision,
  socialOperation,
  groupCreate,
  directCreate,
  chatOperation;

  bool get isChat =>
      this == groupCreate || this == directCreate || this == chatOperation;
}
