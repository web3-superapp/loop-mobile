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
    'production I2 route stays unknown without request-error evidence',
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
      router.go('/system/error');
      await tester.pumpAndSettle();

      expect(find.text('Service error status unavailable'), findsOneWidget);
      expect(find.text('LOOP couldn’t confirm the result'), findsNothing);
      expect(find.textContaining('L-2048'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Contact support'), findsNothing);

      await tester.tap(find.text('Return to LOOP'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('naked I2 surface never infers a request error', (tester) async {
    var continued = false;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'server-error',
        onRetry: () => fail('generic retry must not authorize I2'),
        onSecondaryAction: () => continued = true,
        onServiceRetry: () => fail('I2 retry requires an observation'),
        onServiceSupport: () => fail('I2 support requires an observation'),
      ),
    );

    expect(find.text('Service error status unavailable'), findsOneWidget);
    expect(find.text('LOOP couldn’t confirm the result'), findsNothing);
    expect(find.textContaining('Support reference'), findsNothing);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsNothing);

    await tester.tap(find.text('Return to LOOP'));
    expect(continued, isTrue);
  });

  testWidgets('explicit I2 evidence exposes only exact bound actions', (
    tester,
  ) async {
    var retries = 0;
    var supportOpens = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'server-error',
        serviceErrorObservation: const LoopServiceErrorObservation(),
        onServiceRetry: () => retries += 1,
        onServiceSupport: () => supportOpens += 1,
      ),
    );

    expect(find.text('LOOP couldn’t confirm the result'), findsOneWidget);
    expect(
      find.textContaining('Do not assume success or failure'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Support references remain hidden until their exact source and format are reviewed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Service error status unavailable'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.tap(find.text('Contact support'));
    expect(retries, 1);
    expect(supportOpens, 1);
  });

  testWidgets('explicit I2 evidence never accepts generic system actions', (
    tester,
  ) async {
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'server-error',
        serviceErrorObservation: const LoopServiceErrorObservation(),
        onRetry: () => fail('generic retry must stay isolated from I2'),
        onPrimaryAction: () =>
            fail('generic primary must stay isolated from I2'),
        onSecondaryAction: () =>
            fail('generic secondary must stay isolated from I2'),
      ),
    );

    expect(find.text('Try again'), findsNothing);
    expect(find.text('Contact support'), findsNothing);
    expect(find.text('Return to LOOP'), findsNothing);
  });

  testWidgets('unknown I2 exposes a labelled return action to accessibility', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        SystemSurfaceScreen.fromId('server-error', onSecondaryAction: () {}),
      );

      final title = tester.getSemantics(
        find.text('Service error status unavailable'),
      );
      final returnButton = tester.getSemantics(
        find.widgetWithText(TextButton, 'Return to LOOP'),
      );
      expect(title.flagsCollection.isHeader, isTrue);
      expect(returnButton.label, 'Return to LOOP');
      expect(returnButton.flagsCollection.isButton, isTrue);
      expect(
        returnButton.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  for (final testCase in <({String name, Widget screen})>[
    (name: 'unknown', screen: const SystemSurfaceScreen.fromId('server-error')),
    (
      name: 'observed',
      screen: const SystemSurfaceScreen.fromId(
        'server-error',
        serviceErrorObservation: LoopServiceErrorObservation(),
      ),
    ),
  ]) {
    testWidgets('${testCase.name} I2 remains usable at large text', (
      tester,
    ) async {
      await _pump(
        tester,
        testCase.screen,
        size: const Size(390, 844),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  }
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
