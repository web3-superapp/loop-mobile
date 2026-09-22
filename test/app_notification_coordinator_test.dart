import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/loop_routing_error_log.dart';
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
import 'support/loop_ground_probe.dart';

void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

  const identity = LoopBootstrapIdentity(
    loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
    streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
  );

  testWidgets(
    'root coordinator ignores delivery and navigates a verified interaction',
    (tester) async {
      final source = _TestNotificationSource();
      final routingErrors = LoopRoutingErrorLog();
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
            loopRoutingErrorLogProvider.overrideWithValue(routingErrors),
            hyperliquidMarketRepositoryProvider.overrideWithValue(
              const _EmptyMarketRepository(),
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('community-screen')),
        findsOneWidget,
      );

      final data = _securityEventPayload();
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
      expect(
        find.byKey(const ValueKey<String>('community-screen')),
        findsOneWidget,
      );

      source.add(
        LoopNotificationSourceEvent(
          kind: LoopNotificationSourceEventKind.interaction,
          data: data,
        ),
      );
      await tester.pumpAndSettle();

      // Decision 0067 replaced the speculative notification-centre intent
      // with a destination that exists in the frozen IA: a security event
      // opens device management, which re-reads `GET /v2/devices` for itself.
      expect(
        find.byKey(const ValueKey<String>('devices-screen')),
        findsOneWidget,
      );
      expect(routingErrors.entries, isEmpty);
      expect(routingErrors.errors, isEmpty);
    },
  );
}

/// The exact four-key payload of decision 0067 for a security event.
Map<String, Object?> _securityEventPayload() {
  return <String, Object?>{
    'type': LoopPushNotificationType.securityEvent.wireName,
    'entityRef': 'deviceSession:00000000-0000-4000-8000-00000000000a',
    'contextRoute': LoopNotificationContextRoute.devices.wireName,
    'eventVersion': LoopNotificationRouter.eventVersion,
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
