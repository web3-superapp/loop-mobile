import 'package:dio/dio.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_notifications_api.dart';

/// Strict V2 transport for `devices` and the security centre (decision 0037).
///
/// A revoke is a session command: it carries the whole logout header set,
/// including `X-Loop-Session-ID` for the caller's own session, plus one
/// canonical `Idempotency-Key`. `GET /v2/devices` carries the session id too,
/// but only so the server can mark the current row.
abstract interface class LoopV2SecurityApi {
  Future<LoopDeviceDirectory> getDevices({
    required String accessToken,
    required String clientVersion,
    String? sessionId,
  });

  Future<LoopDeviceRevocation> revokeDevice({
    required String accessToken,
    required String clientVersion,
    required String sessionId,
    required LoopV2SessionCommand command,
  });

  Future<LoopSecurityCapabilities> getCapabilities({
    required String accessToken,
    required String clientVersion,
  });

  Future<LoopSecuritySummary> getSummary({
    required String accessToken,
    required String clientVersion,
  });
}

/// The exact header set a device command must carry.
///
/// It mirrors `POST /v2/session/logout`: platform, device id, the caller's own
/// session id and one fresh idempotency key. Every value is validated before
/// dispatch so a malformed local identity never reaches the network.
final class LoopV2SessionCommand {
  const LoopV2SessionCommand({
    required this.platform,
    required this.deviceId,
    required this.sessionId,
    required this.idempotencyKey,
  });

  final LoopV2Platform platform;
  final String deviceId;
  final String sessionId;
  final String idempotencyKey;

  Map<String, String> get headers {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(deviceId) ||
        !LoopV2Contract.uuidPattern.hasMatch(sessionId) ||
        !LoopV2Contract.uuidV4Pattern.hasMatch(idempotencyKey)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return <String, String>{
      'x-loop-platform': platform.wireName,
      'x-loop-device-id': deviceId,
      'x-loop-session-id': sessionId,
      'idempotency-key': idempotencyKey,
    };
  }
}

final class DioLoopV2SecurityApi implements LoopV2SecurityApi {
  DioLoopV2SecurityApi(this._dio);

  static const devicesPath = '/v2/devices';
  static const capabilitiesPath = '/v2/security/capabilities';
  static const summaryPath = '/v2/security/summary';
  static const deviceListLimit = 100;
  static const recentSecurityEventLimit = 10;

  /// A device command adds the two codes only a session command can answer
  /// with: step-up refusal and an unknown session.
  static const commandErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'AUTH_STEP_UP_REQUIRED'},
    404: <String>{'NOT_FOUND', 'SESSION_NOT_FOUND'},
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

  static final RegExp _clientVersionPattern =
      LoopV2ModuleRequest.clientVersionPattern;
  static final RegExp _guideKeyPattern = RegExp(
    r'^security\.capability\.[a-zA-Z]+\.howToEnable$',
  );

  final Dio _dio;

  @override
  Future<LoopDeviceDirectory> getDevices({
    required String accessToken,
    required String clientVersion,
    String? sessionId,
  }) async {
    if (sessionId != null && !LoopV2Contract.uuidPattern.hasMatch(sessionId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        devicesPath,
        options: Options(
          headers: <String, String>{
            ...LoopV2ModuleRequest.readHeaders(accessToken, clientVersion),
            'x-loop-session-id': ?sessionId,
          },
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _directory(response.data, requestedSessionId: sessionId);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  @override
  Future<LoopDeviceRevocation> revokeDevice({
    required String accessToken,
    required String clientVersion,
    required String sessionId,
    required LoopV2SessionCommand command,
  }) async {
    if (!LoopV2Contract.uuidPattern.hasMatch(sessionId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    // Revoking the caller's own session is a step-up command the server always
    // refuses; local logout is `POST /v2/session/logout`. Never send it.
    if (sessionId == command.sessionId) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    final commandHeaders = command.headers;
    try {
      final response = await _dio.post<Object?>(
        '$devicesPath/$sessionId/revoke',
        options: Options(
          headers: <String, String>{
            ...LoopV2ModuleRequest.readHeaders(accessToken, clientVersion),
            ...commandHeaders,
          },
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'session',
        'effect',
        'providerAccessTerminated',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      final session = LoopV2Contract.strictMap(root['session'], const <String>{
        'sessionId',
        'status',
        'revokedAt',
      });
      final revokedSessionId = LoopV2ChainCodec.requireString(
        session,
        'sessionId',
        pattern: LoopV2Contract.uuidPattern,
        maxLength: 36,
      );
      // The response must be about the session that was asked for, must say
      // it is revoked, and must not claim the provider was signed out.
      if (revokedSessionId != sessionId ||
          session['status'] != LoopDeviceSessionStatus.revoked.wireName ||
          root['effect'] != LoopDeviceRevocation.auditOnlyEffect) {
        LoopV2ChainCodec.invalid();
      }
      LoopV2ChainCodec.requireFalse(root, 'providerAccessTerminated');
      return LoopDeviceRevocation(
        sessionId: revokedSessionId,
        revokedAt: LoopV2ChainCodec.requireTimestamp(session, 'revokedAt'),
        effect: LoopDeviceRevocation.auditOnlyEffect,
        providerAccessTerminated: false,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: commandErrors);
    }
  }

  @override
  Future<LoopSecurityCapabilities> getCapabilities({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        capabilitiesPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'items',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      final raw = LoopV2ChainCodec.requireList(
        root['items'],
        maximum: LoopSecurityCapabilityId.values.length,
      );
      if (raw.length != LoopSecurityCapabilityId.values.length) {
        LoopV2ChainCodec.invalid();
      }
      final items = <LoopSecurityCapability>[];
      for (var index = 0; index < raw.length; index += 1) {
        final map = LoopV2Contract.strictMap(raw[index], const <String>{
          'capabilityId',
          'status',
          'reasonCode',
          'evidence',
          'guideKey',
        });
        final rawId = map['capabilityId'];
        if (rawId is! String) LoopV2ChainCodec.invalid();
        final id = LoopSecurityCapabilityId.tryParse(rawId);
        if (id == null) LoopV2ChainCodec.invalid();
        // The six ids arrive in the frozen contract order.
        if (id != LoopSecurityCapabilityId.values[index]) {
          LoopV2ChainCodec.invalid();
        }
        if (map['status'] != 'unavailable') LoopV2ChainCodec.invalid();
        final evidence = LoopV2Contract.strictMap(
          map['evidence'],
          const <String>{'status', 'reasonCode'},
        );
        // `/v2/security/capabilities` is its own document: all six Privy
        // items are permanently `unavailable` with pending evidence, and the
        // `confirmed` status decision 0068 added to `/v2/meta/capabilities`
        // does not reach it. Widening this would claim a device-verified
        // Privy feature that has none.
        if (evidence['status'] != 'pending') LoopV2ChainCodec.invalid();
        items.add(
          LoopSecurityCapability(
            id: id,
            reasonCode: LoopV2ChainCodec.requireReasonCode(map, 'reasonCode'),
            evidenceReasonCode: LoopV2ChainCodec.requireReasonCode(
              evidence,
              'reasonCode',
            ),
            guideKey: LoopV2ChainCodec.requireString(
              map,
              'guideKey',
              pattern: _guideKeyPattern,
              maxLength: 96,
            ),
          ),
        );
      }
      return LoopSecurityCapabilities(items: items);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  @override
  Future<LoopSecuritySummary> getSummary({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        summaryPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'devices',
        'approvals',
        'notifications',
        'recentSecurityEvents',
        'observedAt',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      final notifications = LoopV2Contract.strictMap(
        root['notifications'],
        const <String>{'securityEvents'},
      );
      final securityEvents = LoopV2Contract.strictMap(
        notifications['securityEvents'],
        const <String>{'category', 'enabled', 'locked'},
      );
      if (securityEvents['category'] !=
          LoopNotificationCategory.securityEvent.wireName) {
        LoopV2ChainCodec.invalid();
      }
      LoopV2ChainCodec.requireTrue(securityEvents, 'enabled');
      LoopV2ChainCodec.requireTrue(securityEvents, 'locked');
      return LoopSecuritySummary(
        devices: _devicesBlock(root['devices']),
        approvals: _approvalsBlock(root['approvals']),
        securityEvents: const LoopSecurityNotificationLock(
          category: LoopNotificationCategory.securityEvent,
          enabled: true,
          locked: true,
        ),
        recentSecurityEvents: _eventsBlock(root['recentSecurityEvents']),
        observedAt: LoopV2ChainCodec.requireTimestamp(root, 'observedAt'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  static bool _isUnavailable(Object? raw) =>
      raw is Map && raw['status'] == 'unavailable';

  static LoopSecurityDevicesBlock _devicesBlock(Object? raw) {
    if (_isUnavailable(raw)) {
      return LoopSecurityDevicesUnavailable(LoopV2ChainCodec.unavailable(raw));
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'deviceCount',
      'activeSessionCount',
      'newSessions24h',
      'highRiskNewDevice',
      'policy',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    return LoopSecurityDevicesAvailable(
      deviceCount: LoopV2ChainCodec.requireInt(map, 'deviceCount'),
      activeSessionCount: LoopV2ChainCodec.requireInt(
        map,
        'activeSessionCount',
      ),
      newSessions24h: LoopV2ChainCodec.requireInt(map, 'newSessions24h'),
      highRiskNewDevice: LoopV2ChainCodec.requireBool(map, 'highRiskNewDevice'),
      policy: _riskPolicy(map['policy']),
    );
  }

  static LoopSecurityApprovalsBlock _approvalsBlock(Object? raw) {
    if (_isUnavailable(raw)) {
      return LoopSecurityApprovalsUnavailable(
        LoopV2ChainCodec.unavailable(raw),
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'walletId',
      'activeCount',
      'unlimitedCount',
      'freshness',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    final freshness = LoopV2Contract.strictMap(map['freshness'], const <String>{
      'indexerBlockNumber',
      'approvalCoverageFromBlockNumber',
      'headBlockNumber',
      'observedAt',
    });
    return LoopSecurityApprovalsAvailable(
      walletId: LoopV2ChainCodec.requireString(
        map,
        'walletId',
        pattern: LoopV2Contract.uuidPattern,
        maxLength: 36,
      ),
      activeCount: LoopV2ChainCodec.requireInt(map, 'activeCount'),
      unlimitedCount: LoopV2ChainCodec.requireInt(map, 'unlimitedCount'),
      indexerBlockNumber: LoopV2ChainCodec.requireBlockNumber(
        freshness,
        'indexerBlockNumber',
      ).toString(),
      approvalCoverageFromBlockNumber: LoopV2ChainCodec.requireBlockNumber(
        freshness,
        'approvalCoverageFromBlockNumber',
      ).toString(),
      headBlockNumber: LoopV2ChainCodec.requireBlockNumber(
        freshness,
        'headBlockNumber',
      ).toString(),
      observedAt: LoopV2ChainCodec.requireTimestamp(freshness, 'observedAt'),
    );
  }

  static LoopSecurityEventsBlock _eventsBlock(Object? raw) {
    if (_isUnavailable(raw)) {
      return LoopSecurityEventsUnavailable(LoopV2ChainCodec.unavailable(raw));
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'items',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    final items = <LoopNotificationEntry>[];
    final seen = <String>{};
    for (final entry in LoopV2ChainCodec.requireList(
      map['items'],
      maximum: recentSecurityEventLimit,
    )) {
      final notification = loopV2NotificationEntryFromMap(
        entry,
        idPattern: LoopV2Contract.uuidPattern,
      );
      // The block is defined as the `security.event` rows only.
      if (notification.type != LoopNotificationCategory.securityEvent) {
        LoopV2ChainCodec.invalid();
      }
      if (!seen.add(notification.notificationId)) LoopV2ChainCodec.invalid();
      items.add(notification);
    }
    return LoopSecurityEventsAvailable(items: items);
  }

  static LoopDeviceRiskPolicy _riskPolicy(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'configVersion',
      'windowHours',
      'newSessionThreshold',
    });
    return LoopDeviceRiskPolicy(
      configVersion: LoopV2ChainCodec.requireString(
        map,
        'configVersion',
        pattern: RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'),
        maxLength: 64,
      ),
      windowHours: LoopV2ChainCodec.requireInt(map, 'windowHours', minimum: 1),
      newSessionThreshold: LoopV2ChainCodec.requireInt(
        map,
        'newSessionThreshold',
        minimum: 1,
      ),
    );
  }

  static LoopDeviceDirectory _directory(
    Object? data, {
    required String? requestedSessionId,
  }) {
    final root = LoopV2Contract.strictMap(data, const <String>{
      'devices',
      'currentSessionId',
      'riskSignals',
      'revokeAll',
      'truncated',
      'observedAt',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final currentSessionId = LoopV2ChainCodec.optionalString(
      root,
      'currentSessionId',
      pattern: LoopV2Contract.uuidPattern,
      maxLength: 36,
    );
    // A current session can only be reported when one was offered, and it must
    // be the one that was offered.
    if (currentSessionId != null && currentSessionId != requestedSessionId) {
      LoopV2ChainCodec.invalid();
    }
    final devices = <LoopDeviceSession>[];
    final seen = <String>{};
    for (final raw in LoopV2ChainCodec.requireList(
      root['devices'],
      maximum: deviceListLimit,
    )) {
      final device = _device(raw);
      if (!seen.add(device.sessionId)) LoopV2ChainCodec.invalid();
      // Only the reported current session may be marked current, and a revoked
      // row can never be the live one.
      if (device.isCurrent &&
          (device.sessionId != currentSessionId || !device.isActive)) {
        LoopV2ChainCodec.invalid();
      }
      devices.add(device);
    }
    if (currentSessionId != null &&
        !devices.any((device) => device.isCurrent)) {
      LoopV2ChainCodec.invalid();
    }
    final riskSignals = LoopV2Contract.strictMap(
      root['riskSignals'],
      const <String>{'newSessions24h', 'highRiskNewDevice', 'policy'},
    );
    return LoopDeviceDirectory(
      devices: devices,
      currentSessionId: currentSessionId,
      riskSignals: LoopDeviceRiskSignals(
        newSessions24h: LoopV2ChainCodec.requireInt(
          riskSignals,
          'newSessions24h',
        ),
        highRiskNewDevice: LoopV2ChainCodec.requireBool(
          riskSignals,
          'highRiskNewDevice',
        ),
        policy: _riskPolicy(riskSignals['policy']),
      ),
      revokeAll: LoopV2ChainCodec.unavailable(root['revokeAll']),
      truncated: LoopV2ChainCodec.requireBool(root, 'truncated'),
      observedAt: LoopV2ChainCodec.requireTimestamp(root, 'observedAt'),
    );
  }

  static LoopDeviceSession _device(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'sessionId',
      'deviceId',
      'platform',
      'clientVersion',
      'status',
      'authStrength',
      'isCurrent',
      'createdAt',
      'lastSeenAt',
      'revokedAt',
    });
    final rawPlatform = map['platform'];
    if (rawPlatform is! String) LoopV2ChainCodec.invalid();
    final rawStatus = map['status'];
    if (rawStatus is! String) LoopV2ChainCodec.invalid();
    final rawStrength = map['authStrength'];
    if (rawStrength is! String) LoopV2ChainCodec.invalid();
    final platform = LoopDevicePlatform.tryParse(rawPlatform);
    if (platform == null) LoopV2ChainCodec.invalid();
    final status = LoopDeviceSessionStatus.tryParse(rawStatus);
    if (status == null) LoopV2ChainCodec.invalid();
    final strength = LoopDeviceAuthStrength.tryParse(rawStrength);
    if (strength == null) LoopV2ChainCodec.invalid();
    final revokedAt = LoopV2ChainCodec.optionalTimestamp(map, 'revokedAt');
    // The two projections of the same fact must agree.
    if ((status == LoopDeviceSessionStatus.revoked) != (revokedAt != null)) {
      LoopV2ChainCodec.invalid();
    }
    return LoopDeviceSession(
      sessionId: LoopV2ChainCodec.requireString(
        map,
        'sessionId',
        pattern: LoopV2Contract.uuidPattern,
        maxLength: 36,
      ),
      deviceId: LoopV2ChainCodec.requireString(
        map,
        'deviceId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      platform: platform,
      clientVersion: LoopV2ChainCodec.requireString(
        map,
        'clientVersion',
        pattern: _clientVersionPattern,
        minLength: 5,
        maxLength: 64,
      ),
      status: status,
      authStrength: strength,
      isCurrent: LoopV2ChainCodec.requireBool(map, 'isCurrent'),
      createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
      lastSeenAt: LoopV2ChainCodec.requireTimestamp(map, 'lastSeenAt'),
      revokedAt: revokedAt,
    );
  }
}
