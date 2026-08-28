import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  testWidgets('production I1 route stays unknown without a mounted source', (
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
    router.go('/system/offline');
    await tester.pumpAndSettle();

    expect(find.text('Connectivity status unavailable'), findsOneWidget);
    expect(find.text('You’re offline'), findsNothing);
    expect(find.text('Try again'), findsNothing);
    expect(find.byType(LoopConnectivityBanner), findsNothing);
  });

  testWidgets('naked I1 surface does not infer an offline state', (
    tester,
  ) async {
    var continued = false;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'offline',
        onSecondaryAction: () => continued = true,
      ),
    );

    expect(find.text('Connectivity status unavailable'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('connectivity-source-unavailable')),
      findsOneWidget,
    );
    expect(find.text('You’re offline'), findsNothing);
    expect(find.text('Market data is unavailable'), findsNothing);
    expect(find.text('Trading is temporarily unavailable'), findsNothing);
    expect(find.text('Try again'), findsNothing);

    await tester.tap(find.text('Return to LOOP'));
    expect(continued, isTrue);
  });

  for (final testCase in <({LoopConnectivityScope scope, String title})>[
    (scope: LoopConnectivityScope.fullyOffline, title: 'You’re offline'),
    (
      scope: LoopConnectivityScope.marketDataUnavailable,
      title: 'Market data is unavailable',
    ),
    (
      scope: LoopConnectivityScope.tradingServiceUnavailable,
      title: 'Trading is temporarily unavailable',
    ),
  ]) {
    testWidgets('explicit ${testCase.scope.name} signal renders its I1 state', (
      tester,
    ) async {
      var retried = false;
      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'offline',
          connectivityScope: testCase.scope,
          onRetry: () => retried = true,
        ),
      );

      expect(find.text(testCase.title), findsOneWidget);
      expect(find.text('Connectivity status unavailable'), findsNothing);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });
  }

  testWidgets('explicit connectivity banner supports large text and retry', (
    tester,
  ) async {
    var retried = false;
    await _pump(
      tester,
      LoopConnectivityBanner(
        scope: LoopConnectivityScope.marketDataUnavailable,
        onRetry: () => retried = true,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.text('Market data unavailable · prices may be stale'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown I1 source remains responsive at large text', (
    tester,
  ) async {
    await _pump(
      tester,
      const SystemSurfaceScreen.fromId('offline'),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('Connectivity status unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit I1 outage remains responsive at large text', (
    tester,
  ) async {
    await _pump(
      tester,
      const SystemSurfaceScreen.fromId(
        'offline',
        connectivityScope: LoopConnectivityScope.fullyOffline,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('You’re offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(900, 1400),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}
