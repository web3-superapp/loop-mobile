import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/loop_routing_error_log.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/bridge_preview_snapshot.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  testWidgets('navigates the five primary destinations with one shell', (
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

    expect(
      find.byKey(const ValueKey<String>('community-screen')),
      findsOneWidget,
    );
    for (final destination in <String>['挖矿', 'Launch', '行情', '钱包', '社区']) {
      await tester.tap(find.widgetWithText(LoopTabItem, destination));
      await tester.pumpAndSettle();
    }
    expect(
      find.byKey(const ValueKey<String>('community-screen')),
      findsOneWidget,
    );
  });

  testWidgets('primary navigation exposes no Perp entry', (tester) async {
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

    await tester.tap(find.widgetWithText(LoopTabItem, '行情'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('market-screen')), findsOneWidget);
    expect(find.textContaining('Perp trading'), findsNothing);
    expect(find.textContaining('Live perpetual markets'), findsNothing);

    await tester.tap(find.widgetWithText(LoopTabItem, '钱包'));
    await tester.pumpAndSettle();
    expect(find.text('Trading account'), findsNothing);
    expect(find.textContaining('Hyperliquid margin'), findsNothing);

    await tester.tap(find.widgetWithText(LoopTabItem, '社区'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PERP EQUITY'), findsNothing);
    expect(find.textContaining('Spot to perp'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('community-search-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('community-search-panel')),
      findsOneWidget,
    );
    expect(find.text('ETH'), findsNothing);
    expect(find.text('ETH-PERP'), findsNothing);
  });

  testWidgets(
    'retained Perp paths are unmounted and fall back to Community with a logged error',
    (tester) async {
      final routingErrors = LoopRoutingErrorLog();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(),
            ),
            loopRoutingErrorLogProvider.overrideWithValue(routingErrors),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();

      final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));
      final perpPaths = LoopRouteManifest.retiredPaths
          .where((path) => path.startsWith('/perp'))
          .toList(growable: false);
      expect(perpPaths, hasLength(12));
      for (final path in perpPaths) {
        router.go(path);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, '/community');
        expect(routingErrors.last?.location, path, reason: path);
        expect(find.text('Perpetuals'), findsNothing, reason: path);
        expect(find.text('Positions'), findsNothing, reason: path);
      }
      expect(routingErrors.entries, hasLength(12));
    },
  );

  testWidgets('incomplete Send deep links return to asset selection', (
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

    final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));
    router.go('/wallet/send/to');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');

    router.go('/wallet/send/to', extra: 'wrong draft type');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');

    router.go('/wallet/send/confirm');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');

    router.go('/wallet/send/confirm', extra: 'wrong draft type');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');

    // A draft without a checked recipient and an amount is incomplete: the
    // confirmation page must never prepare an intent from it.
    router.go(
      '/wallet/send/confirm',
      extra: const SendDraft(
        walletId: 'd64786bb-408d-415d-8a69-6277d56c921b',
        assetId: 'eip155:56:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
        symbol: 'WBNB',
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');

    router.go(
      '/wallet/send/confirm',
      extra: const SendDraft(
        walletId: 'd64786bb-408d-415d-8a69-6277d56c921b',
        assetId: 'eip155:56:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
        symbol: 'WBNB',
        recipientAddress: '0x000000000000000000000000000000000000dEaD',
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');
  });

  testWidgets('the Swap quote detail requires the exact typed quote', (
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

    final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));
    router.go('/wallet/swap/route');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/swap');

    // The detail page renders one server quote object and nothing else, so a
    // wrong extra returns to Swap instead of rendering a shaped placeholder.
    router.go('/wallet/swap/route', extra: 'wrong quote type');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/swap');
  });

  testWidgets('the approval guard requires a typed request', (tester) async {
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

    final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));
    router.go('/wallet/approval-guard');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/wallet/approvals');
  });

  testWidgets('Bridge status route requires the exact typed snapshot', (
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

    final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));
    router.go('/wallet/bridge/status');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/bridge');

    router.go('/wallet/bridge/status', extra: 'wrong Bridge snapshot type');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/bridge');

    final claimSnapshot = BridgePreviewSnapshot.demo.withNeedsClaim(true);
    router.go('/wallet/bridge/status', extra: claimSnapshot);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/wallet/bridge/status',
    );
    expect(find.text(claimSnapshot.sourceConfirmationLabel), findsOneWidget);
    expect(find.text(claimSnapshot.destinationStepDetail), findsOneWidget);
    expect(find.text('Manual claim required'), findsOneWidget);
  });

  testWidgets('communication preview is persistently identified as offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
          communicationGatewayProvider.overrideWithValue(
            MemoryCommunicationGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(
      tester.element(find.byKey(const ValueKey<String>('community-screen'))),
    );
    router.go('/chat');
    await tester.pumpAndSettle();

    expect(find.text('Offline preview · not connected'), findsWidgets);
    expect(find.byKey(const ValueKey('communication-mode-status')), findsOne);
    expect(find.textContaining('126 online'), findsNothing);
    expect(find.textContaining('listening'), findsNothing);
  });

  testWidgets('default production communication mode stays unconfigured', (
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

    final router = GoRouter.of(
      tester.element(find.byKey(const ValueKey<String>('community-screen'))),
    );
    router.go('/chat');
    await tester.pumpAndSettle();

    expect(find.text('Stream not connected'), findsOneWidget);
    expect(find.textContaining('Offline preview'), findsNothing);
    expect(find.text('Glyph Hunters'), findsNothing);
  });

  testWidgets('mobile voice preview never presents a connected room', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
          communicationGatewayProvider.overrideWithValue(
            MemoryCommunicationGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byKey(const ValueKey<String>('community-screen'))),
    );
    router.go('/chat');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ETH Macro Room'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ETH Macro Room'));
    await tester.pumpAndSettle();

    expect(find.text('Offline preview'), findsOneWidget);
    expect(
      find.text('Offline preview · simulated room layout'),
      findsOneWidget,
    );
    expect(find.text('Open offline preview'), findsOneWidget);
    expect(find.textContaining('listening'), findsNothing);
    expect(find.textContaining('speaking'), findsNothing);

    await tester.tap(find.text('Open offline preview'));
    await tester.pumpAndSettle();

    expect(find.text('Offline preview'), findsOneWidget);
    expect(find.text('SIMULATED SEATS'), findsOneWidget);
    expect(find.text('Close preview'), findsOneWidget);
  });
}
