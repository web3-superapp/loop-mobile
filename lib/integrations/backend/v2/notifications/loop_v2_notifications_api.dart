import 'package:dio/dio.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';

/// Strict V2 transport for the context notification feed and the ten
/// notification preference categories.
///
/// `POST …/read` carries an `Idempotency-Key`; the preferences `PUT` is a
/// version CAS and carries none.
abstract interface class LoopV2NotificationsApi {
  Future<LoopNotificationFeed> getFeed({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  });

  Future<LoopNotificationEntry> markRead({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String notificationId,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopNotificationPreferences> getPreferences({
    required String accessToken,
    required String clientVersion,
  });

  Future<LoopNotificationPreferences> putPreferences({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required Map<LoopNotificationCategory, bool> categories,
    LoopV2WriteOrigin? origin,
  });
}

final class DioLoopV2NotificationsApi implements LoopV2NotificationsApi {
  DioLoopV2NotificationsApi(this._dio);

  static const feedPath = '/v2/notifications/feed';
  static const notificationsPath = '/v2/notifications';
  static const preferencesPath = '/v2/notification-preferences';
  static const maximumVersion = 2147483647;

  static final RegExp _entityRefPattern = RegExp(
    r'^[a-z][A-Za-z0-9]{0,31}:[A-Za-z0-9._:-]{1,160}$',
  );
  static final RegExp _contextRoutePattern = RegExp(r'^[a-z][a-z0-9-]{0,63}$');
  static final RegExp _sourcePattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

  final Dio _dio;

  @override
  Future<LoopNotificationFeed> getFeed({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  }) async {
    if (cursor != null &&
        (cursor.length < 3 ||
            cursor.length > LoopV2ChainCodec.maximumCursorLength ||
            !LoopV2ChainCodec.cursorPattern.hasMatch(cursor))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        feedPath,
        queryParameters: cursor == null
            ? null
            : <String, Object?>{'cursor': cursor},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'items',
        'nextCursor',
        'unreadCount',
        'push',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      final items = <LoopNotificationEntry>[];
      final seen = <String>{};
      for (final raw in LoopV2ChainCodec.requireList(
        root['items'],
        maximum: 50,
      )) {
        final entry = _entry(raw);
        if (!seen.add(entry.notificationId)) LoopV2ChainCodec.invalid();
        items.add(entry);
      }
      return LoopNotificationFeed(
        items: items,
        nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
        unreadCount: LoopV2ChainCodec.requireInt(root, 'unreadCount'),
        push: LoopV2ChainCodec.unavailable(root['push']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<LoopNotificationEntry> markRead({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String notificationId,
    LoopV2WriteOrigin? origin,
  }) async {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(notificationId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        '$notificationsPath/$notificationId/read',
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'notification',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      final entry = _entry(root['notification']);
      if (entry.notificationId != notificationId) LoopV2ChainCodec.invalid();
      // A read receipt must actually carry a read time.
      if (entry.readAt == null) LoopV2ChainCodec.invalid();
      return entry;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainIdempotentWriteErrors,
      );
    }
  }

  @override
  Future<LoopNotificationPreferences> getPreferences({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        preferencesPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _preferences(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<LoopNotificationPreferences> putPreferences({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required Map<LoopNotificationCategory, bool> categories,
    LoopV2WriteOrigin? origin,
  }) async {
    if (expectedVersion < 0 || expectedVersion > maximumVersion) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    // All ten keys are mandatory, and `security.event` must be `true`: the
    // server rejects the request rather than ignoring a `false`.
    if (categories.length != LoopNotificationCategory.values.length ||
        !LoopNotificationCategory.values.every(categories.containsKey) ||
        categories[LoopNotificationCategory.securityEvent] != true) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.put<Object?>(
        preferencesPath,
        data: <String, Object?>{
          'expectedVersion': expectedVersion,
          'categories': <String, Object?>{
            for (final category in LoopNotificationCategory.values)
              category.wireName: categories[category],
          },
        },
        options: LoopV2ModuleRequest.casOptions(
          accessToken,
          clientVersion,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _preferences(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.casWriteErrors,
      );
    }
  }

  static LoopNotificationPreferences _preferences(Object? data) {
    final root = LoopV2Contract.strictMap(data, const <String>{
      'version',
      'updatedAt',
      'categories',
      'push',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final categories = LoopV2Contract.strictMap(root['categories'], <String>{
      for (final category in LoopNotificationCategory.values) category.wireName,
    });
    final parsed = <LoopNotificationCategory, LoopNotificationCategoryState>{};
    for (final category in LoopNotificationCategory.values) {
      final map = LoopV2Contract.strictMap(
        categories[category.wireName],
        const <String>{'enabled', 'locked'},
      );
      final enabled = LoopV2ChainCodec.requireBool(map, 'enabled');
      final locked = LoopV2ChainCodec.requireBool(map, 'locked');
      // The security category is pinned on and locked by the contract.
      if (category == LoopNotificationCategory.securityEvent &&
          (!enabled || !locked)) {
        LoopV2ChainCodec.invalid();
      }
      parsed[category] = LoopNotificationCategoryState(
        enabled: enabled,
        locked: locked,
      );
    }
    return LoopNotificationPreferences(
      version: LoopV2ChainCodec.requireInt(root, 'version'),
      updatedAt: LoopV2ChainCodec.optionalTimestamp(root, 'updatedAt'),
      categories: parsed,
      push: LoopV2ChainCodec.unavailable(root['push']),
    );
  }

  static LoopNotificationEntry _entry(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'notificationId',
      'type',
      'entityRef',
      'contextRoute',
      'contextParams',
      'payload',
      'source',
      'observedAt',
      'readAt',
      'createdAt',
    });
    final rawType = map['type'];
    if (rawType is! String) LoopV2ChainCodec.invalid();
    final type = LoopNotificationCategory.tryParse(rawType);
    if (type == null) LoopV2ChainCodec.invalid();
    return LoopNotificationEntry(
      notificationId: LoopV2ChainCodec.requireString(
        map,
        'notificationId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      type: type,
      entityRef: LoopV2ChainCodec.requireString(
        map,
        'entityRef',
        pattern: _entityRefPattern,
        maxLength: 200,
      ),
      contextRoute: LoopV2ChainCodec.requireString(
        map,
        'contextRoute',
        pattern: _contextRoutePattern,
        maxLength: 64,
      ),
      contextParams: _stringMap(map['contextParams'], maximum: 8),
      payload: _payloadMap(map['payload']),
      source: LoopV2ChainCodec.optionalString(
        map,
        'source',
        pattern: _sourcePattern,
        maxLength: 64,
      ),
      observedAt: LoopV2ChainCodec.optionalTimestamp(map, 'observedAt'),
      readAt: LoopV2ChainCodec.optionalTimestamp(map, 'readAt'),
      createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
    );
  }

  static Map<String, String> _stringMap(Object? raw, {required int maximum}) {
    if (raw is! Map || raw.length > maximum) LoopV2ChainCodec.invalid();
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String ||
          key.isEmpty ||
          key.length > 64 ||
          value is! String ||
          value.length > 256) {
        LoopV2ChainCodec.invalid();
      }
      result[key] = value;
    }
    return result;
  }

  static Map<String, String?> _payloadMap(Object? raw) {
    if (raw is! Map || raw.length > 16) LoopV2ChainCodec.invalid();
    final result = <String, String?>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String ||
          key.isEmpty ||
          key.length > 64 ||
          (value != null && (value is! String || value.length > 256))) {
        LoopV2ChainCodec.invalid();
      }
      result[key] = value;
    }
    return result;
  }
}
