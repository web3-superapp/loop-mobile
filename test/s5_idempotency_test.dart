import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/alerts/loop_v2_alerts_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_gateways.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_notifications_api.dart';

import 'support/s5_fixtures.dart';

/// One logical write reserves exactly one `Idempotency-Key`.
///
/// The key is replayed only while the outcome is genuinely unknown, so the
/// server can recognise the duplicate. Any resolved outcome — a success or a
/// terminal rejection — releases it, because the next attempt is a new logical
/// operation and must never collide with a recorded one.
LoopAuthenticatedSession _immediateSession() {
  const principalKey = 'did:privy:owner-1';
  return LoopAuthenticatedSession(
    principalKey: principalKey,
    bootstrapSession: LoopBootstrapSession(
      principalKey: principalKey,
      accessTokens: _StaticAccessTokens(),
      repository: _BootstrapRepository(),
    ),
    accessTokens: _StaticAccessTokens(),
  );
}

final class _StaticAccessTokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => 'current-token';
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    return const LoopBootstrapIdentity(
      loopUserId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
      streamUserId: 'loop_6d12a86e413447e69312c5ef75a30f55',
    );
  }
}

const _clientMetadata = LoopV2ClientMetadata(
  clientVersion: s5ClientVersion,
  platform: LoopV2Platform.ios,
);

/// An alerts transport that records each key and can be switched between a
/// success, an unresolved transport failure and a terminal rejection.
final class _KeyRecordingAlertsApi implements LoopV2AlertsApi {
  final List<String> keys = <String>[];
  Object? failure;

  @override
  Future<LoopAlertPage> listAlerts({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  }) async => LoopAlertPage(items: const <LoopPriceAlert>[], nextCursor: null);

  @override
  Future<LoopPriceAlert> createAlert({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required LoopAlertDraft draft,
    LoopV2WriteOrigin? origin,
  }) async {
    keys.add(idempotencyKey);
    final pending = failure;
    if (pending != null) throw pending;
    return s5Alert();
  }

  @override
  Future<LoopPriceAlert> updateAlert({
    required String accessToken,
    required String clientVersion,
    required String alertId,
    required int expectedVersion,
    required LoopAlertDraft draft,
    LoopV2WriteOrigin? origin,
  }) async => s5Alert();

  @override
  Future<void> deleteAlert({
    required String accessToken,
    required String clientVersion,
    required String alertId,
    required int expectedVersion,
    LoopV2WriteOrigin? origin,
  }) async {}
}

final class _KeyRecordingNotificationsApi implements LoopV2NotificationsApi {
  final List<String> keys = <String>[];
  Object? failure;

  @override
  Future<LoopNotificationFeed> getFeed({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  }) async => s5Feed();

  @override
  Future<LoopNotificationEntry> markRead({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String notificationId,
    LoopV2WriteOrigin? origin,
  }) async {
    keys.add(idempotencyKey);
    final pending = failure;
    if (pending != null) throw pending;
    return s5Notification(readAt: DateTime.utc(2026, 9, 8, 8));
  }

  @override
  Future<LoopNotificationPreferences> getPreferences({
    required String accessToken,
    required String clientVersion,
  }) async => s5Preferences();

  @override
  Future<LoopNotificationPreferences> putPreferences({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required Map<LoopNotificationCategory, bool> categories,
    LoopV2WriteOrigin? origin,
  }) async => s5Preferences(version: expectedVersion + 1);
}

const _draft = LoopAlertDraft(
  assetId: s5WbnbAssetId,
  condition: LoopAlertCondition.atOrAbove,
  threshold: '800.5',
  expiresAt: null,
);

const _otherDraft = LoopAlertDraft(
  assetId: s5WbnbAssetId,
  condition: LoopAlertCondition.atOrAbove,
  threshold: '900',
  expiresAt: null,
);

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// A lost connection as the transport reports it. The transport is the only
/// place a `DioException` lives; everything above it sees this failure.
const _connectionFailure = LoopBackendFailure(
  LoopBackendFailureKind.connection,
);

void main() {
  group('createAlert key lifecycle', () {
    test('an offline attempt replays the same key', () async {
      final api = _KeyRecordingAlertsApi()..failure = _connectionFailure;
      final gateway = DioLoopV2AlertsGateway(
        api: api,
        clientMetadata: _clientMetadata,
        session: _immediateSession(),
      );

      for (var attempt = 0; attempt < 3; attempt += 1) {
        await expectLater(
          gateway.createAlert(_draft),
          throwsA(
            isA<LoopChainException>().having(
              (failure) => failure.kind,
              'kind',
              LoopChainFailureKind.offline,
            ),
          ),
        );
      }

      // The server may already have created the alert, so the same key must
      // go out again for it to recognise the duplicate.
      expect(api.keys, hasLength(3));
      expect(api.keys.toSet(), hasLength(1));
      expect(_uuidV4.hasMatch(api.keys.first), isTrue);
    });

    test(
      'a success releases the key, and a new draft takes a new one',
      () async {
        final api = _KeyRecordingAlertsApi();
        final gateway = DioLoopV2AlertsGateway(
          api: api,
          clientMetadata: _clientMetadata,
          session: _immediateSession(),
        );

        await gateway.createAlert(_draft);
        // The same draft again is a new logical operation once the first one
        // resolved: reusing the key would make the server replay the old alert.
        await gateway.createAlert(_draft);
        await gateway.createAlert(_otherDraft);

        expect(api.keys, hasLength(3));
        expect(api.keys.toSet(), hasLength(3));
        expect(api.keys.every(_uuidV4.hasMatch), isTrue);
      },
    );

    test('a terminal rejection releases the key', () async {
      final api = _KeyRecordingAlertsApi()
        ..failure = const LoopBackendFailure(
          LoopBackendFailureKind.invalidRequest,
          statusCode: 422,
          code: 'VALIDATION_FAILED',
        );
      final gateway = DioLoopV2AlertsGateway(
        api: api,
        clientMetadata: _clientMetadata,
        session: _immediateSession(),
      );

      await expectLater(
        gateway.createAlert(_draft),
        throwsA(
          isA<LoopChainException>().having(
            (failure) => failure.kind,
            'kind',
            LoopChainFailureKind.validationFailed,
          ),
        ),
      );
      api.failure = null;
      await gateway.createAlert(_draft);

      // The server refused the request outright, so nothing was recorded
      // against the first key and the retry must not replay it.
      expect(api.keys, hasLength(2));
      expect(api.keys.toSet(), hasLength(2));
    });

    test('a draft the contract refuses never reserves a key', () async {
      final api = _KeyRecordingAlertsApi();
      final gateway = DioLoopV2AlertsGateway(
        api: api,
        clientMetadata: _clientMetadata,
        session: _immediateSession(),
      );

      await expectLater(
        gateway.createAlert(
          const LoopAlertDraft(
            assetId: s5WbnbAssetId,
            condition: LoopAlertCondition.above,
            threshold: '0',
            expiresAt: null,
          ),
        ),
        throwsA(
          isA<LoopChainException>().having(
            (failure) => failure.kind,
            'kind',
            LoopChainFailureKind.validationFailed,
          ),
        ),
      );

      expect(api.keys, isEmpty);
    });
  });

  group('markRead key lifecycle', () {
    test('an offline attempt replays the same key', () async {
      final api = _KeyRecordingNotificationsApi()..failure = _connectionFailure;
      final gateway = DioLoopV2NotificationsGateway(
        api: api,
        clientMetadata: _clientMetadata,
        session: _immediateSession(),
      );

      for (var attempt = 0; attempt < 2; attempt += 1) {
        await expectLater(
          gateway.markRead(s5NotificationId),
          throwsA(isA<LoopChainException>()),
        );
      }

      expect(api.keys, hasLength(2));
      expect(api.keys.toSet(), hasLength(1));
    });

    test('a success releases the key for the next notification', () async {
      final api = _KeyRecordingNotificationsApi();
      final gateway = DioLoopV2NotificationsGateway(
        api: api,
        clientMetadata: _clientMetadata,
        session: _immediateSession(),
      );

      await gateway.markRead(s5NotificationId);
      await gateway.markRead(s5NotificationId);

      expect(api.keys, hasLength(2));
      expect(api.keys.toSet(), hasLength(2));
    });

    test('two notifications never share one key', () async {
      final api = _KeyRecordingNotificationsApi()..failure = _connectionFailure;
      final gateway = DioLoopV2NotificationsGateway(
        api: api,
        clientMetadata: _clientMetadata,
        session: _immediateSession(),
      );

      await expectLater(
        gateway.markRead(s5NotificationId),
        throwsA(isA<LoopChainException>()),
      );
      await expectLater(
        gateway.markRead(s5AlertId),
        throwsA(isA<LoopChainException>()),
      );

      // The keyring is scoped to the logical operation, not to the gateway:
      // two unresolved reads must not be recorded as the same one.
      expect(api.keys, hasLength(2));
      expect(api.keys.toSet(), hasLength(2));
    });
  });
}
