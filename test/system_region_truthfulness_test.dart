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
    'production I5 route stays unknown without an eligibility decision',
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
      router.go('/system/region');
      await tester.pumpAndSettle();

      expect(find.text('Availability status unavailable'), findsOneWidget);
      expect(find.text('Some features are unavailable'), findsNothing);
      expect(find.text('Spot order execution'), findsNothing);
      expect(find.text('Deposits and withdrawals'), findsNothing);
      expect(find.text('Continue to LOOP'), findsNothing);
      expect(find.text('View eligibility policy'), findsNothing);

      await tester.tap(find.text('Return to LOOP'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('naked I5 never infers a restriction or authorizes its actions', (
    tester,
  ) async {
    var returned = false;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        onPrimaryAction: () => fail('generic primary must not authorize I5'),
        onRegionContinue: () => fail('I5 continue requires a decision'),
        onRegionPolicy: () => fail('I5 policy requires a decision'),
        onSecondaryAction: () => returned = true,
      ),
    );

    expect(find.text('Availability status unavailable'), findsOneWidget);
    expect(find.text('Some features are unavailable'), findsNothing);
    expect(find.text('Continue to LOOP'), findsNothing);
    expect(find.text('View eligibility policy'), findsNothing);
    expect(
      tester
          .widget<PopScope<void>>(
            find.byKey(const ValueKey<String>('system-state-dismissible')),
          )
          .canPop,
      isTrue,
    );

    await tester.tap(find.text('Return to LOOP'));
    expect(returned, isTrue);
  });

  testWidgets('explicit I5 decision renders only its bounded projection', (
    tester,
  ) async {
    await _pump(
      tester,
      const SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction: LoopFeatureAvailabilityRestriction(),
      ),
    );

    expect(find.text('Some features are unavailable'), findsOneWidget);
    expect(find.text('Availability status unavailable'), findsNothing);
    expect(
      find.text(
        'Feature access is currently limited. Check each feature for its current availability.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'This page does not provide a location, reason, or affected features. It does not confirm that any other feature is available.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'location and account information currently on record',
      ),
      findsNothing,
    );
    expect(find.text('Spot order execution'), findsNothing);
    expect(find.text('Deposits and withdrawals'), findsNothing);
    expect(find.text('What still works'), findsNothing);
    expect(
      find.text(
        'You can review supported markets, use eligible wallet views, and continue permitted conversations.',
      ),
      findsNothing,
    );
    expect(find.text('Read availability policy'), findsNothing);
    expect(find.text('Continue to LOOP'), findsNothing);
    expect(find.text('View eligibility policy'), findsNothing);
  });

  testWidgets('I5 dedicated actions appear independently', (tester) async {
    var continues = 0;
    var policyOpens = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction:
            const LoopFeatureAvailabilityRestriction(),
        onRegionContinue: () => continues += 1,
      ),
    );

    await tester.tap(find.text('Continue to LOOP'));
    expect(continues, 1);
    expect(find.text('View eligibility policy'), findsNothing);

    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction:
            const LoopFeatureAvailabilityRestriction(),
        onRegionPolicy: () => policyOpens += 1,
      ),
    );

    expect(find.text('Continue to LOOP'), findsNothing);
    await tester.tap(find.text('View eligibility policy'));
    expect(policyOpens, 1);
  });

  testWidgets('explicit I5 decision never accepts generic system actions', (
    tester,
  ) async {
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction:
            const LoopFeatureAvailabilityRestriction(),
        onRetry: () => fail('generic retry must stay isolated from I5'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );

    expect(find.text('Continue to LOOP'), findsNothing);
    expect(find.text('View eligibility policy'), findsNothing);
    expect(find.text('Return to LOOP'), findsNothing);
  });

  testWidgets('I5 states expose accessible exact actions', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var returns = 0;
      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'region-restricted',
          onSecondaryAction: () => returns += 1,
        ),
      );

      final unknownTitle = tester.getSemantics(
        find.text('Availability status unavailable'),
      );
      final returnAction = tester.getSemantics(
        find.widgetWithText(TextButton, 'Return to LOOP'),
      );
      expect(unknownTitle.flagsCollection.isHeader, isTrue);
      expect(returnAction.label, 'Return to LOOP');
      expect(returnAction.flagsCollection.isButton, isTrue);
      expect(
        returnAction.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(find.text('Return to LOOP'));
      expect(returns, 1);

      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'region-restricted',
          featureAvailabilityRestriction:
              const LoopFeatureAvailabilityRestriction(),
          onRegionContinue: () {},
          onRegionPolicy: () {},
        ),
      );

      final title = tester.getSemantics(
        find.text('Some features are unavailable'),
      );
      final continueAction = tester.getSemantics(
        find.widgetWithText(FilledButton, 'Continue to LOOP'),
      );
      final policyAction = tester.getSemantics(
        find.widgetWithText(TextButton, 'View eligibility policy'),
      );
      expect(title.flagsCollection.isHeader, isTrue);
      expect(continueAction.label, 'Continue to LOOP');
      expect(continueAction.flagsCollection.isButton, isTrue);
      expect(
        continueAction.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(policyAction.label, 'View eligibility policy');
      expect(policyAction.flagsCollection.isButton, isTrue);
      expect(
        policyAction.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('unknown I5 remains usable at large text', (tester) async {
    var returns = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
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

  testWidgets('active I5 actions remain usable at large text', (tester) async {
    var continues = 0;
    var policyOpens = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction:
            const LoopFeatureAvailabilityRestriction(),
        onRegionContinue: () => continues += 1,
        onRegionPolicy: () => policyOpens += 1,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    await tester.ensureVisible(find.text('Continue to LOOP'));
    await tester.tap(find.text('Continue to LOOP'));
    await tester.ensureVisible(find.text('View eligibility policy'));
    await tester.tap(find.text('View eligibility policy'));
    expect(continues, 1);
    expect(policyOpens, 1);
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
