import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_preview_route_guard.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  testWidgets('production legacy Chat routes never mount preview fixtures', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    for (final route in <String>[
      '/chat/group',
      '/chat/dm',
      '/chat/group-info',
      '/chat/requests',
      '/chat/search',
      '/preview/token-card',
      '/preview/contract-facts',
      '/preview/asset-message',
    ]) {
      router.go(route);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-preview-route-blocked')),
        findsOneWidget,
        reason: route,
      );
      expect(find.text('Offline preview only'), findsOneWidget, reason: route);
      expect(
        find.byKey(const ValueKey<String>('chat-preview-open-chats')),
        findsOneWidget,
        reason: route,
      );
      expect(find.text('Glyph Hunters'), findsNothing, reason: route);
      expect(find.text('0xSable'), findsNothing, reason: route);
      expect(find.text('GLYPH / USDC'), findsNothing, reason: route);
    }
  });

  testWidgets('explicit preview composition can mount the guarded child', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communicationGatewayProvider.overrideWithValue(
            MemoryCommunicationGateway(),
          ),
        ],
        child: const MaterialApp(
          home: ChatPreviewRouteGuard(
            surfaceLabel: 'Preview fixture',
            child: Scaffold(body: Text('Fixture child')),
          ),
        ),
      ),
    );

    expect(find.text('Fixture child'), findsOneWidget);
    final bannerFinder = find.byKey(
      const ValueKey<String>('chat-preview-route-label'),
    );
    expect(bannerFinder, findsOneWidget);
    expect(tester.widget<Banner>(bannerFinder).message, '开发预览');
    expect(
      find.byKey(const ValueKey<String>('chat-preview-route-blocked')),
      findsNothing,
    );
  });
}
