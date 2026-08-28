import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  testWidgets(
    'production I4 route stays unknown without a maintenance notice',
    (tester) async {
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
      router.go('/system/maintenance');
      await tester.pumpAndSettle();

      expect(find.text('Maintenance status unavailable'), findsOneWidget);
      expect(find.text('Maintenance notice is active'), findsNothing);
      expect(find.textContaining('01:00–01:30 UTC'), findsNothing);
      expect(find.text('Check again'), findsNothing);
      expect(find.text('View service status'), findsNothing);

      await tester.tap(find.text('Return to LOOP'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('naked I4 never infers maintenance or authorizes its actions', (
    tester,
  ) async {
    var continued = false;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        onRetry: () => fail('generic retry must not authorize I4'),
        onMaintenanceRecheck: () => fail('I4 recheck requires a notice'),
        onMaintenanceStatus: () => fail('I4 status requires a notice'),
        onSecondaryAction: () => continued = true,
      ),
    );

    expect(find.text('Maintenance status unavailable'), findsOneWidget);
    expect(find.text('Maintenance notice is active'), findsNothing);
    expect(find.textContaining('Maintenance window'), findsNothing);
    expect(find.text('Check again'), findsNothing);
    expect(find.text('View service status'), findsNothing);
    expect(
      tester
          .widget<PopScope<void>>(
            find.byKey(const ValueKey<String>('system-state-dismissible')),
          )
          .canPop,
      isTrue,
    );

    await tester.tap(find.text('Return to LOOP'));
    expect(continued, isTrue);
  });

  testWidgets('explicit I4 notice exposes only exact maintenance actions', (
    tester,
  ) async {
    var rechecks = 0;
    var statusOpens = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        maintenanceNotice: const LoopMaintenanceNotice(),
        onMaintenanceRecheck: () => rechecks += 1,
        onMaintenanceStatus: () => statusOpens += 1,
      ),
    );

    expect(find.text('Maintenance notice is active'), findsOneWidget);
    expect(find.text('Maintenance status unavailable'), findsNothing);
    expect(
      find.text(
        'An approved maintenance notice is active. Feature availability still comes from each feature’s own current state.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'This notice does not include a maintenance window or affected services.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('01:00–01:30 UTC'), findsNothing);
    expect(find.textContaining('short pause'), findsNothing);
    expect(find.textContaining('temporarily unavailable'), findsNothing);
    for (final service in <String>['Account', 'Wallet', 'Trading', 'Chat']) {
      expect(find.text(service), findsNothing);
    }

    await tester.tap(find.text('Check again'));
    await tester.tap(find.text('View service status'));
    expect(rechecks, 1);
    expect(statusOpens, 1);
  });

  testWidgets('explicit I4 notice never accepts generic system actions', (
    tester,
  ) async {
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        maintenanceNotice: const LoopMaintenanceNotice(),
        onRetry: () => fail('generic retry must stay isolated from I4'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );

    expect(find.text('Check again'), findsNothing);
    expect(find.text('View service status'), findsNothing);
    expect(find.text('Return to LOOP'), findsNothing);
  });

  testWidgets('active I4 exposes accessible exact actions', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'maintenance',
          maintenanceNotice: const LoopMaintenanceNotice(),
          onMaintenanceRecheck: () {},
          onMaintenanceStatus: () {},
        ),
      );

      final title = tester.getSemantics(
        find.text('Maintenance notice is active'),
      );
      final recheck = tester.getSemantics(
        find.widgetWithText(FilledButton, 'Check again'),
      );
      final status = tester.getSemantics(
        find.widgetWithText(TextButton, 'View service status'),
      );
      expect(title.flagsCollection.isHeader, isTrue);
      expect(recheck.label, 'Check again');
      expect(recheck.flagsCollection.isButton, isTrue);
      expect(recheck.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(status.label, 'View service status');
      expect(status.flagsCollection.isButton, isTrue);
      expect(status.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('unknown I4 remains usable at large text', (tester) async {
    var returns = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        onSecondaryAction: () => returns += 1,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    await tester.ensureVisible(find.text('Return to LOOP'));
    await tester.tap(find.text('Return to LOOP'));
    expect(returns, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active I4 actions remain usable at large text', (tester) async {
    var rechecks = 0;
    var statusOpens = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        maintenanceNotice: const LoopMaintenanceNotice(),
        onMaintenanceRecheck: () => rechecks += 1,
        onMaintenanceStatus: () => statusOpens += 1,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    await tester.ensureVisible(find.text('Check again'));
    await tester.tap(find.text('Check again'));
    await tester.ensureVisible(find.text('View service status'));
    await tester.tap(find.text('View service status'));
    expect(rechecks, 1);
    expect(statusOpens, 1);
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
