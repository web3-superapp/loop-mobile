import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/security/loop_v2_security_api.dart';

import 's8_harness.dart';

export 's8_harness.dart'
    show
        s8Capabilities,
        s8CurrentDeviceId,
        s8CurrentSessionId,
        s8Directory,
        s8OtherDeviceId,
        s8OtherSessionId,
        s8Summary;

/// Exact wire bodies from `loop-api/docs/frontend-v2-security-settings-api.md`.
///
/// Every fixture is a fresh mutable map so one test can corrupt a single field
/// without leaking the change into the next.

const s8AccessToken = 'privy-access-token';
const s8ClientVersion = '1.0.0';
const s8RequestId = '11111111-1111-4111-8111-111111111111';
const s8PrincipalKey = 'did:privy:owner-1';
const s8IdempotencyKey = '6f5e4d3c-2b1a-4098-8765-4321fedcba98';
const s8TicketId = '4f605172-8d9e-4f0a-8b12-3d4e5f607182';
const s8TicketBody = '为什么我的币没有权重';
const s8WalletId = '5a716283-9e0f-4a1b-8c23-4e5f60718293';
const s8SecurityEventId = '7c938405-af21-4c3d-8e45-60718293a4b5';

const s8ClientMetadata = LoopV2ClientMetadata(
  clientVersion: s8ClientVersion,
  platform: LoopV2Platform.ios,
);

final s8InvalidPayload = isA<LoopBackendFailure>().having(
  (failure) => failure.kind,
  'kind',
  LoopBackendFailureKind.invalidPayload,
);

LoopV2SessionCommand s8Command() => const LoopV2SessionCommand(
  platform: LoopV2Platform.ios,
  deviceId: s8CurrentDeviceId,
  sessionId: s8CurrentSessionId,
  idempotencyKey: s8IdempotencyKey,
);

LoopV2OwnerJournal s8Journal() => const LoopV2OwnerJournal(
  activeSession: LoopV2ActiveSession(
    accountId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
    sessionId: s8CurrentSessionId,
    streamUserId: 'loop_6d12a86e413447e69312c5ef75a30f55',
    deviceId: s8CurrentDeviceId,
  ),
);

// ---------------------------------------------------------------------------
// transport doubles
// ---------------------------------------------------------------------------

Dio s8Dio(void Function(RequestOptions, RequestInterceptorHandler) onRequest) {
  return Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
}

Response<Object?> s8Response(
  RequestOptions options,
  Object? data, {
  int statusCode = 200,
  String cacheControl = 'no-store',
  String requestId = s8RequestId,
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': <String>[cacheControl],
      'x-request-id': <String>[requestId],
    }),
  );
}

DioException s8ErrorResponse(
  RequestOptions options, {
  required int statusCode,
  required String code,
  String category = 'availability',
  bool retryable = true,
  String userMessageKey = 'errors.capability.unavailable',
}) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: statusCode,
      data: <String, Object?>{
        'code': code,
        'category': category,
        'retryable': retryable,
        'userMessageKey': userMessageKey,
        'correlationId': s8RequestId,
        'detailsSafe': null,
        'providerReferenceSafe': null,
      },
      headers: Headers.fromMap(<String, List<String>>{
        'cache-control': const <String>['no-store'],
        'x-request-id': const <String>[s8RequestId],
        if (statusCode == 401)
          'www-authenticate': const <String>['Bearer realm="loop-api"'],
      }),
    ),
  );
}

// ---------------------------------------------------------------------------
// wire fixtures
// ---------------------------------------------------------------------------

Map<String, Object?> s8DeviceRow({
  String sessionId = s8CurrentSessionId,
  String deviceId = s8CurrentDeviceId,
  String platform = 'ios',
  bool isCurrent = true,
}) => <String, Object?>{
  'sessionId': sessionId,
  'deviceId': deviceId,
  'platform': platform,
  'clientVersion': '1.0.0',
  'status': 'active',
  'authStrength': 'providerAuthenticated',
  'isCurrent': isCurrent,
  'createdAt': '2026-09-08T20:00:00.000Z',
  'lastSeenAt': '2026-09-08T20:00:00.000Z',
  'revokedAt': null,
};

Map<String, Object?> s8RiskPolicyBody() => <String, Object?>{
  'configVersion': 'deviceRiskV1',
  'windowHours': 24,
  'newSessionThreshold': 2,
};

Map<String, Object?> s8DevicesBody() => <String, Object?>{
  'devices': <Object?>[
    s8DeviceRow(),
    s8DeviceRow(
      sessionId: s8OtherSessionId,
      deviceId: s8OtherDeviceId,
      platform: 'android',
      isCurrent: false,
    ),
  ],
  'currentSessionId': s8CurrentSessionId,
  'riskSignals': <String, Object?>{
    'newSessions24h': 1,
    'highRiskNewDevice': false,
    'policy': s8RiskPolicyBody(),
  },
  'revokeAll': <String, Object?>{
    'status': 'unavailable',
    'reasonCode': 'AUTH_STEP_UP_REQUIRED',
  },
  'truncated': false,
  'observedAt': '2026-09-09T02:00:00.000Z',
  'contractVersion': '2.0',
};

Map<String, Object?> s8RevokeBody() => <String, Object?>{
  'session': <String, Object?>{
    'sessionId': s8OtherSessionId,
    'status': 'revoked',
    'revokedAt': '2026-09-09T03:00:00.000Z',
  },
  'effect': 'auditOnly',
  'providerAccessTerminated': false,
  'contractVersion': '2.0',
};

Map<String, Object?> s8CapabilitiesBody() => <String, Object?>{
  'items': <Object?>[
    for (final (id, reason) in <(String, String)>[
      ('mfa', 'PRIVY_MFA_EVIDENCE_PENDING'),
      ('passkey', 'PRIVY_PASSKEY_EVIDENCE_PENDING'),
      ('recoveryPassword', 'PRIVY_RECOVERY_PASSWORD_EVIDENCE_PENDING'),
      ('autoRecovery', 'PRIVY_AUTO_RECOVERY_EVIDENCE_PENDING'),
      ('socialRecovery', 'PRIVY_SOCIAL_RECOVERY_EVIDENCE_PENDING'),
      ('keyExport', 'PRIVY_KEY_EXPORT_EVIDENCE_PENDING'),
    ])
      <String, Object?>{
        'capabilityId': id,
        'status': 'unavailable',
        'reasonCode': reason,
        'evidence': <String, Object?>{
          'status': 'pending',
          'reasonCode': reason,
        },
        'guideKey': 'security.capability.$id.howToEnable',
      },
  ],
  'contractVersion': '2.0',
};

Map<String, Object?> s8SecurityEvent({String type = 'security.event'}) =>
    <String, Object?>{
      'notificationId': s8SecurityEventId,
      'type': type,
      'entityRef': 'deviceSession:$s8OtherSessionId',
      'contextRoute': 'devices',
      'contextParams': <String, Object?>{'sessionId': s8OtherSessionId},
      'payload': <String, Object?>{
        'event': 'session_revoked',
        'platform': 'android',
      },
      'source': 'loop_session',
      'observedAt': null,
      'readAt': null,
      'createdAt': '2026-09-09T01:00:00.000Z',
    };

Map<String, Object?> s8SummaryBody() => <String, Object?>{
  'devices': <String, Object?>{
    'status': 'available',
    'deviceCount': 2,
    'activeSessionCount': 2,
    'newSessions24h': 1,
    'highRiskNewDevice': false,
    'policy': s8RiskPolicyBody(),
  },
  'approvals': <String, Object?>{
    'status': 'available',
    'walletId': s8WalletId,
    'activeCount': 3,
    'unlimitedCount': 1,
    'freshness': <String, Object?>{
      'indexerBlockNumber': '120659683',
      'approvalCoverageFromBlockNumber': '120600000',
      'headBlockNumber': '120661145',
      'observedAt': '2026-09-09T02:00:00.000Z',
    },
  },
  'notifications': <String, Object?>{
    'securityEvents': <String, Object?>{
      'category': 'security.event',
      'enabled': true,
      'locked': true,
    },
  },
  'recentSecurityEvents': <String, Object?>{
    'status': 'available',
    'items': <Object?>[],
  },
  'observedAt': '2026-09-09T02:00:00.000Z',
  'contractVersion': '2.0',
};

Map<String, Object?> s8SettingsBody({int version = 0}) => <String, Object?>{
  'settings': <String, Object?>{'displayCurrency': 'USD', 'language': 'zh-CN'},
  'version': version,
  'updatedAt': version == 0 ? null : '2026-09-09T02:00:00.000Z',
  'policy': <String, Object?>{
    'configVersion': 'accountSettingsV1',
    'fixed': <String, Object?>{'displayCurrency': 'USD', 'language': 'zh-CN'},
    'localOnly': <Object?>['reduceMotion', 'theme'],
  },
  'contractVersion': '2.0',
};

Map<String, Object?> s8AboutBody() => <String, Object?>{
  'contractVersion': '2.0',
  'configVersions': <Object?>[
    <String, Object?>{
      'module': 'productPolicy',
      'configVersion': 'productPolicyV2.2026-09-01',
      'effectiveAt': '2026-09-01T00:00:00.000Z',
    },
    <String, Object?>{
      'module': 'support',
      'configVersion': 'supportPolicyV1',
      'effectiveAt': null,
    },
  ],
  'termsGate': <String, Object?>{
    'status': 'unavailable',
    'requiredVersion': null,
    'reasonCode': 'TERMS_POLICY_UNAVAILABLE',
  },
  'openSource': <String, Object?>{
    'source': 'docs/open-source-attribution.md',
    'summary': 'This register covers the direct runtime dependencies.',
    'entries': <Object?>[
      <String, Object?>{
        'name': 'Fastify',
        'purpose': 'HTTP server and route lifecycle',
        'license': 'MIT',
      },
    ],
  },
  'clientBuild': <String, Object?>{
    'status': 'local',
    'reasonCode': 'CLIENT_BUILD_IS_DEVICE_LOCAL',
  },
};

Map<String, Object?> s8SupportPolicyBody() => <String, Object?>{
  'configVersion': 'supportPolicyV1',
  'responseWindowHours': 24,
  'businessDaysOnly': true,
  'escalationChannel': 'copy',
};

Map<String, Object?> s8TicketRow() => <String, Object?>{
  'ticketId': s8TicketId,
  'category': 'mining',
  'body': s8TicketBody,
  'status': 'open',
  'createdAt': '2026-09-09T00:00:00.000Z',
  'updatedAt': '2026-09-09T00:00:00.000Z',
  'lastEventAt': '2026-09-09T00:00:00.000Z',
  'events': <Object?>[
    <String, Object?>{
      'eventVersion': 0,
      'eventType': 'created',
      'actor': 'user',
      'note': null,
      'occurredAt': '2026-09-09T00:00:00.000Z',
    },
  ],
};

Map<String, Object?> s8TicketPageBody({String? nextCursor}) =>
    <String, Object?>{
      'items': <Object?>[s8TicketRow()],
      'nextCursor': nextCursor,
      'attachments': <String, Object?>{
        'status': 'unavailable',
        'reasonCode': 'SUPPORT_ATTACHMENTS_UNAVAILABLE',
      },
      'policy': s8SupportPolicyBody(),
      'contractVersion': '2.0',
    };

Map<String, Object?> s8TicketResultBody() => <String, Object?>{
  'ticket': s8TicketRow(),
  'attachments': <String, Object?>{
    'status': 'unavailable',
    'reasonCode': 'SUPPORT_ATTACHMENTS_UNAVAILABLE',
  },
  'policy': s8SupportPolicyBody(),
  'contractVersion': '2.0',
};
