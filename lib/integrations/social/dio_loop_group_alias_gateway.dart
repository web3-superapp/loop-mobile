import 'package:dio/dio.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';

/// Principal-bound production adapter for immutable, group-local Aliases.
///
/// The only accepted group locator is [GroupId], which cannot represent a
/// Stream CID or a direct channel. Responses are parsed into group-local
/// models whose shape cannot carry a public profile, LOOP owner, Privy,
/// wallet, or Stream identity.
final class DioLoopGroupAliasGateway
    implements GroupAliasGateway, GroupAliasResolverGateway {
  factory DioLoopGroupAliasGateway({
    required Dio dio,
    required LoopAuthenticatedSession session,
  }) => DioLoopGroupAliasGateway._(dio, session);

  DioLoopGroupAliasGateway._(Dio dio, this._session)
    : _transport = _DioLoopGroupAliasTransport(dio);

  final _DioLoopGroupAliasTransport _transport;
  final LoopAuthenticatedSession _session;

  @override
  GroupAliasGatewayMode get mode => GroupAliasGatewayMode.production;

  @override
  Future<GroupId> resolveGroup(GroupAliasStreamChannelId channelId) => _read(
    (accessToken) =>
        _transport.resolveGroup(accessToken: accessToken, channelId: channelId),
  );

  @override
  Future<GroupAliasResource> loadCurrentAlias(GroupId groupId) => _read(
    (accessToken) =>
        _transport.loadCurrentAlias(accessToken: accessToken, groupId: groupId),
  );

  @override
  Future<GroupAliasResource> putCurrentAlias({
    required GroupId groupId,
    required String normalizedAlias,
  }) async {
    late final String candidate;
    try {
      candidate = normalizeGroupAlias(normalizedAlias);
      if (candidate != normalizedAlias) {
        throw const InvalidGroupAliasContractException();
      }
    } on InvalidGroupAliasContractException {
      throw const GroupAliasGatewayException(
        GroupAliasGatewayFailureKind.invalidData,
      );
    }

    var requestStarted = false;
    try {
      final resource = await _session.execute((accessToken) {
        requestStarted = true;
        return _transport.putCurrentAlias(
          accessToken: accessToken,
          groupId: groupId,
          normalizedAlias: candidate,
        );
      });
      if (resource.alias != candidate) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      return resource;
    } on LoopBackendFailure catch (failure) {
      throw GroupAliasGatewayException(
        _writeFailureKind(failure, requestStarted: requestStarted),
      );
    } on InvalidGroupAliasContractException {
      throw GroupAliasGatewayException(
        requestStarted
            ? GroupAliasGatewayFailureKind.outcomeUnknown
            : GroupAliasGatewayFailureKind.invalidData,
      );
    } catch (_) {
      throw GroupAliasGatewayException(
        requestStarted
            ? GroupAliasGatewayFailureKind.outcomeUnknown
            : GroupAliasGatewayFailureKind.unavailable,
      );
    }
  }

  @override
  Future<GroupAliasSearchPage> searchAliases({
    required GroupId groupId,
    required String normalizedPrefix,
    required int limit,
  }) async {
    late final String prefix;
    late final int boundedLimit;
    try {
      prefix = normalizeGroupAliasSearchPrefix(normalizedPrefix);
      boundedLimit = validateGroupAliasSearchLimit(limit);
      if (prefix != normalizedPrefix) {
        throw const InvalidGroupAliasContractException();
      }
    } on InvalidGroupAliasContractException {
      throw const GroupAliasGatewayException(
        GroupAliasGatewayFailureKind.invalidData,
      );
    }

    final page = await _read(
      (accessToken) => _transport.searchAliases(
        accessToken: accessToken,
        groupId: groupId,
        normalizedPrefix: prefix,
        limit: boundedLimit,
      ),
    );
    if (page.items.length > boundedLimit) {
      throw const GroupAliasGatewayException(
        GroupAliasGatewayFailureKind.invalidData,
      );
    }
    return page;
  }

  Future<T> _read<T>(Future<T> Function(String accessToken) request) async {
    try {
      return await _session.execute(request);
    } on LoopBackendFailure catch (failure) {
      throw GroupAliasGatewayException(_readFailureKind(failure));
    } on InvalidGroupAliasContractException {
      throw const GroupAliasGatewayException(
        GroupAliasGatewayFailureKind.invalidData,
      );
    } catch (_) {
      throw const GroupAliasGatewayException(
        GroupAliasGatewayFailureKind.unexpected,
      );
    }
  }
}

final class _DioLoopGroupAliasTransport {
  const _DioLoopGroupAliasTransport(this._dio);

  static final RegExp _requestIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _publicErrorCodePattern = RegExp(r'^[a-z0-9_]+$');

  final Dio _dio;

  Future<GroupId> resolveGroup({
    required String accessToken,
    required GroupAliasStreamChannelId channelId,
  }) async {
    final response = await _post(
      '/v1/chat/groups/resolve',
      accessToken: accessToken,
      operation: _GroupAliasOperation.resolve,
      data: <String, Object?>{'stream_channel_id': channelId.wireValue},
    );
    return _parseSuccess(response, _parseResolvedGroup);
  }

  Future<GroupAliasResource> loadCurrentAlias({
    required String accessToken,
    required GroupId groupId,
  }) async {
    final response = await _get(
      _currentAliasPath(groupId),
      accessToken: accessToken,
      operation: _GroupAliasOperation.load,
    );
    return _parseSuccess(response, _parseAliasResource);
  }

  Future<GroupAliasResource> putCurrentAlias({
    required String accessToken,
    required GroupId groupId,
    required String normalizedAlias,
  }) async {
    final response = await _put(
      _currentAliasPath(groupId),
      accessToken: accessToken,
      operation: _GroupAliasOperation.put,
      data: <String, Object?>{'alias': normalizedAlias},
    );
    return _parseSuccess(response, _parseAliasResource);
  }

  Future<GroupAliasSearchPage> searchAliases({
    required String accessToken,
    required GroupId groupId,
    required String normalizedPrefix,
    required int limit,
  }) async {
    final response = await _get(
      '/v1/chat/groups/${groupId.wireValue}/aliases',
      accessToken: accessToken,
      operation: _GroupAliasOperation.search,
      queryParameters: <String, Object?>{
        'alias_prefix': normalizedPrefix,
        'limit': limit,
      },
    );
    return _parseSuccess(response, _parseSearchPage);
  }

  String _currentAliasPath(GroupId groupId) =>
      '/v1/chat/groups/${groupId.wireValue}/me/alias';

  Future<Response<Object?>> _get(
    String path, {
    required String accessToken,
    required _GroupAliasOperation operation,
    Map<String, Object?>? queryParameters,
  }) async {
    _validateAccessToken(accessToken);
    try {
      return await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
        options: _options(accessToken),
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error, operation: operation);
    }
  }

  Future<Response<Object?>> _put(
    String path, {
    required String accessToken,
    required _GroupAliasOperation operation,
    required Map<String, Object?> data,
  }) async {
    _validateAccessToken(accessToken);
    try {
      return await _dio.put<Object?>(
        path,
        data: data,
        options: _options(accessToken, sendsJson: true),
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error, operation: operation);
    }
  }

  Future<Response<Object?>> _post(
    String path, {
    required String accessToken,
    required _GroupAliasOperation operation,
    required Map<String, Object?> data,
  }) async {
    _validateAccessToken(accessToken);
    try {
      return await _dio.post<Object?>(
        path,
        data: data,
        options: _options(accessToken, sendsJson: true),
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error, operation: operation);
    }
  }

  Options _options(String accessToken, {bool sendsJson = false}) => Options(
    headers: <String, String>{
      'authorization': 'Bearer $accessToken',
      'accept': Headers.jsonContentType,
    },
    contentType: sendsJson ? Headers.jsonContentType : null,
    followRedirects: false,
    responseType: ResponseType.json,
  );

  T _parseSuccess<T>(Response<Object?> response, T Function(Object?) parser) {
    if (response.statusCode != 200 ||
        !_hasNoStore(response.headers) ||
        _requestIdHeader(response.headers) == null) {
      return _invalidPayload();
    }
    try {
      return parser(response.data);
    } on LoopBackendFailure {
      rethrow;
    } catch (_) {
      return _invalidPayload();
    }
  }

  GroupAliasResource _parseAliasResource(Object? payload) {
    final root = _strictMap(payload, const <String>{
      'group_alias_id',
      'alias',
      'projection_state',
    });
    final rawId = root['group_alias_id'];
    final rawAlias = root['alias'];
    final rawProjection = root['projection_state'];
    if (rawId is! String || rawAlias is! String || rawProjection is! String) {
      return _invalidPayload();
    }
    final alias = normalizeGroupAlias(rawAlias);
    if (alias != rawAlias) return _invalidPayload();
    return GroupAliasResource(
      groupAliasId: GroupAliasId.fromWire(rawId),
      alias: alias,
      projectionState: switch (rawProjection) {
        'pending' => GroupAliasProjectionState.pending,
        'confirmed' => GroupAliasProjectionState.confirmed,
        _ => _invalidPayload(),
      },
    );
  }

  GroupId _parseResolvedGroup(Object? payload) {
    final root = _strictMap(payload, const <String>{'group_id'});
    final rawGroupId = root['group_id'];
    if (rawGroupId is! String) return _invalidPayload();
    return GroupId.fromWire(rawGroupId);
  }

  GroupAliasSearchPage _parseSearchPage(Object? payload) {
    final root = _strictMap(payload, const <String>{'items', 'truncated'});
    final rawItems = root['items'];
    final truncated = root['truncated'];
    if (rawItems is! List || truncated is! bool) return _invalidPayload();
    final items = <GroupAliasSearchItem>[];
    for (final rawItem in rawItems) {
      final item = _strictMap(rawItem, const <String>{
        'group_alias_id',
        'alias',
      });
      final rawId = item['group_alias_id'];
      final rawAlias = item['alias'];
      if (rawId is! String || rawAlias is! String) return _invalidPayload();
      final alias = normalizeGroupAlias(rawAlias);
      if (alias != rawAlias) return _invalidPayload();
      items.add(
        GroupAliasSearchItem(
          groupAliasId: GroupAliasId.fromWire(rawId),
          alias: alias,
        ),
      );
    }
    return GroupAliasSearchPage(items: items, truncated: truncated);
  }

  Map<String, Object?> _strictMap(Object? payload, Set<String> expectedKeys) {
    if (payload is! Map) return _invalidPayload();
    final result = <String, Object?>{};
    for (final entry in payload.entries) {
      final key = entry.key;
      if (key is! String || result.containsKey(key)) return _invalidPayload();
      result[key] = entry.value;
    }
    if (result.length != expectedKeys.length ||
        !expectedKeys.every(result.containsKey)) {
      return _invalidPayload();
    }
    return result;
  }

  void _validateAccessToken(String accessToken) {
    if (accessToken.isEmpty || accessToken != accessToken.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
  }

  LoopBackendFailure _mapDioFailure(
    DioException error, {
    required _GroupAliasOperation operation,
  }) {
    final statusCode = error.response?.statusCode;
    final metadata = error.type == DioExceptionType.badResponse
        ? _errorMetadata(error.response, operation: operation)
        : null;
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => LoopBackendFailureKind.timeout,
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => LoopBackendFailureKind.connection,
      DioExceptionType.cancel => LoopBackendFailureKind.cancelled,
      DioExceptionType.badResponse when metadata == null =>
        LoopBackendFailureKind.invalidPayload,
      DioExceptionType.badResponse => switch (statusCode) {
        400 => LoopBackendFailureKind.invalidRequest,
        401 => LoopBackendFailureKind.authentication,
        404 || 409 => LoopBackendFailureKind.invalidRequest,
        429 => LoopBackendFailureKind.unavailable,
        503 when metadata?.code == 'request_timeout' =>
          LoopBackendFailureKind.timeout,
        500 || 503 => LoopBackendFailureKind.unavailable,
        _ => LoopBackendFailureKind.unexpected,
      },
      DioExceptionType.unknown => LoopBackendFailureKind.unexpected,
    };
    return LoopBackendFailure(
      kind,
      statusCode: statusCode,
      code: metadata?.code,
      requestId: metadata?.requestId,
    );
  }

  _GroupAliasErrorMetadata? _errorMetadata(
    Response<Object?>? response, {
    required _GroupAliasOperation operation,
  }) {
    if (response == null || !_hasNoStore(response.headers)) return null;
    final headerRequestId = _requestIdHeader(response.headers);
    if (headerRequestId == null) return null;
    final root = _strictMapOrNull(response.data, const <String>{
      'code',
      'message',
      'request_id',
    });
    if (root == null) return null;

    final code = root['code'];
    final message = root['message'];
    final requestId = root['request_id'];
    if (code is! String ||
        code.isEmpty ||
        code.length > 64 ||
        !_publicErrorCodePattern.hasMatch(code) ||
        message is! String ||
        message.isEmpty ||
        message.length > 512 ||
        requestId is! String ||
        requestId != headerRequestId ||
        !_requestIdPattern.hasMatch(requestId) ||
        !_codeMatchesStatus(
          statusCode: response.statusCode,
          code: code,
          operation: operation,
        )) {
      return null;
    }
    return _GroupAliasErrorMetadata(code: code, requestId: requestId);
  }

  Map<String, Object?>? _strictMapOrNull(
    Object? payload,
    Set<String> expectedKeys,
  ) {
    if (payload is! Map) return null;
    final result = <String, Object?>{};
    for (final entry in payload.entries) {
      final key = entry.key;
      if (key is! String || result.containsKey(key)) return null;
      result[key] = entry.value;
    }
    if (result.length != expectedKeys.length ||
        !expectedKeys.every(result.containsKey)) {
      return null;
    }
    return result;
  }

  bool _codeMatchesStatus({
    required int? statusCode,
    required String code,
    required _GroupAliasOperation operation,
  }) => switch (statusCode) {
    400 => code == 'invalid_request',
    401 => code == 'authentication_required' || code == 'invalid_access_token',
    404 => code == 'not_found',
    409 =>
      code == 'bootstrap_required' ||
          (operation == _GroupAliasOperation.put &&
              (code == 'group_alias_immutable' ||
                  code == 'group_alias_unavailable')),
    429 =>
      operation == _GroupAliasOperation.search && code == 'search_rate_limited',
    500 => code == 'internal_error',
    503 =>
      code == 'authentication_unavailable' ||
          code == 'chat_group_unavailable' ||
          code == 'request_timeout',
    _ => false,
  };

  bool _hasNoStore(Headers headers) {
    final directives = headers['cache-control']
        ?.expand((value) => value.split(','))
        .map((value) => value.trim().toLowerCase());
    return directives?.contains('no-store') ?? false;
  }

  String? _requestIdHeader(Headers headers) {
    final values = headers['x-request-id'];
    if (values == null || values.length != 1) return null;
    final value = values.single;
    return _requestIdPattern.hasMatch(value) ? value : null;
  }

  T _invalidPayload<T>() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
}

enum _GroupAliasOperation { resolve, load, put, search }

final class _GroupAliasErrorMetadata {
  const _GroupAliasErrorMetadata({required this.code, required this.requestId});

  final String code;
  final String requestId;
}

GroupAliasGatewayFailureKind _readFailureKind(LoopBackendFailure failure) {
  if (failure.statusCode == 404 && failure.code == 'not_found') {
    return GroupAliasGatewayFailureKind.notFound;
  }
  if (failure.kind == LoopBackendFailureKind.invalidPayload ||
      (failure.statusCode == 400 && failure.code == 'invalid_request')) {
    return GroupAliasGatewayFailureKind.invalidData;
  }
  if (_isTemporarilyUnavailable(failure)) {
    return GroupAliasGatewayFailureKind.unavailable;
  }
  return GroupAliasGatewayFailureKind.unexpected;
}

GroupAliasGatewayFailureKind _writeFailureKind(
  LoopBackendFailure failure, {
  required bool requestStarted,
}) {
  if (failure.statusCode == 404 && failure.code == 'not_found') {
    return GroupAliasGatewayFailureKind.notFound;
  }
  if (failure.statusCode == 409 && failure.code == 'group_alias_immutable') {
    return GroupAliasGatewayFailureKind.immutable;
  }
  if (failure.statusCode == 409 && failure.code == 'group_alias_unavailable') {
    return GroupAliasGatewayFailureKind.taken;
  }
  if (failure.statusCode == 400 && failure.code == 'invalid_request') {
    return GroupAliasGatewayFailureKind.invalidData;
  }
  if (!requestStarted || _provesWriteWasRejected(failure)) {
    return GroupAliasGatewayFailureKind.unavailable;
  }
  return GroupAliasGatewayFailureKind.outcomeUnknown;
}

bool _provesWriteWasRejected(LoopBackendFailure failure) =>
    failure.kind == LoopBackendFailureKind.authentication ||
    (failure.statusCode == 409 && failure.code == 'bootstrap_required') ||
    (failure.statusCode == 503 && failure.code == 'authentication_unavailable');

bool _isTemporarilyUnavailable(LoopBackendFailure failure) =>
    failure.kind == LoopBackendFailureKind.invalidConfiguration ||
    failure.kind == LoopBackendFailureKind.authentication ||
    failure.kind == LoopBackendFailureKind.unavailable ||
    failure.kind == LoopBackendFailureKind.timeout ||
    failure.kind == LoopBackendFailureKind.connection ||
    failure.kind == LoopBackendFailureKind.cancelled ||
    (failure.statusCode == 409 && failure.code == 'bootstrap_required') ||
    (failure.statusCode == 429 && failure.code == 'search_rate_limited');
