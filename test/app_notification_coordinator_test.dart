import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_repository.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_event_source.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  const identity = LoopBootstrapIdentity(
    loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
    streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
  );

  testWidgets(
    'root coordinator ignores delivery and navigates a verified interaction',
    (tester) async {
      final source = _TestNotificationSource();
      final bootstrap = LoopBootstrapSession(
        principalKey: 'did:privy:test-widget',
        accessTokens: const _AccessTokens(),
        repository: const _BootstrapRepository(identity),
      );
      expect(
        await bootstrap.authorize(),
        LoopBootstrapAuthorization.authorized,
      );
      addTearDown(source.close);
      addTearDown(bootstrap.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(),
            ),
            loopBootstrapSessionProvider.overrideWithValue(bootstrap),
            loopNotificationEventSourceProvider.overrideWithValue(source),
            hyperliquidMarketRepositoryProvider.overrideWithValue(
              const _EmptyMarketRepository(),
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home overview'), findsOneWidget);

      final data = _systemNoticePayload();
      source.add(
        LoopNotificationSourceEvent(
          kind: LoopNotificationSourceEventKind.foreground,
          data: data,
        ),
      );
      source.add(
        LoopNotificationSourceEvent(
          kind: LoopNotificationSourceEventKind.background,
          data: data,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home overview'), findsOneWidget);

      source.add(
        LoopNotificationSourceEvent(
          kind: LoopNotificationSourceEventKind.interaction,
          data: data,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('notifications-provider-unavailable'),
        ),
        findsOneWidget,
      );
      expect(find.text('Notifications not connected'), findsOneWidget);
    },
  );
}

Map<String, Object?> _systemNoticePayload() {
  final now = DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().toUtc().millisecondsSinceEpoch,
    isUtc: true,
  );
  return <String, Object?>{
    'loop_schema': LoopNotificationRouter.schema,
    'event_id': '123e4567-e89b-42d3-a456-426614174000',
    'recipient_stream_user_id': 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
    'kind': LoopNotificationRouter.systemNoticeKind,
    'occurred_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
    'expires_at': now.add(const Duration(minutes: 10)).toIso8601String(),
  };
}

final class _TestNotificationSource implements LoopNotificationEventSource {
  final StreamController<LoopNotificationSourceEvent> _events =
      StreamController<LoopNotificationSourceEvent>.broadcast(sync: true);

  @override
  Stream<LoopNotificationSourceEvent> get events => _events.stream;

  void add(LoopNotificationSourceEvent event) => _events.add(event);

  Future<void> close() => _events.close();

  @override
  Future<LoopNotificationSourceEvent?> loadInitialInteraction() async => null;
}

final class _AccessTokens implements LoopBackendAccessTokenSource {
  const _AccessTokens();

  @override
  Future<String> loadAccessToken() async => 'test-access-token';
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  const _BootstrapRepository(this.identity);

  final LoopBootstrapIdentity identity;

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    return identity;
  }
}

final class _EmptyMarketRepository implements HyperliquidMarketRepository {
  const _EmptyMarketRepository();

  @override
  Future<List<HyperliquidMarket>> fetchMarkets() async => const [];
}
