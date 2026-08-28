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
  testWidgets('production I3 route stays unknown without a version policy', (
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
    router.go('/system/update');
    await tester.pumpAndSettle();

    expect(find.text('Update status unavailable'), findsOneWidget);
    expect(find.text('Update LOOP to continue'), findsNothing);
    expect(find.text('Update now'), findsNothing);
    expect(find.textContaining('cannot be skipped'), findsNothing);

    await tester.tap(find.text('Return to LOOP'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('naked I3 never infers or blocks for an update requirement', (
    tester,
  ) async {
    var continued = false;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'force-update',
        onPrimaryAction: () => fail('generic primary must not authorize I3'),
        onForceUpdate: () => fail('I3 action requires a requirement'),
        onSecondaryAction: () => continued = true,
      ),
    );

    expect(find.text('Update status unavailable'), findsOneWidget);
    expect(find.text('Update LOOP to continue'), findsNothing);
    expect(find.text('Update now'), findsNothing);
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

  testWidgets('explicit I3 requirement blocks and invokes only its action', (
    tester,
  ) async {
    var updates = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'force-update',
        forceUpdateRequirement: const LoopForceUpdateRequirement(),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onForceUpdate: () => updates += 1,
      ),
    );

    expect(find.text('Update LOOP to continue'), findsOneWidget);
    expect(find.text('Update status unavailable'), findsNothing);
    expect(find.textContaining('approved version policy'), findsOneWidget);
    expect(find.textContaining('protect account'), findsNothing);
    expect(find.textContaining('latest version'), findsNothing);
    expect(
      tester
          .widget<PopScope<void>>(
            find.byKey(const ValueKey<String>('system-state-blocking')),
          )
          .canPop,
      isFalse,
    );

    await tester.tap(find.text('Update now'));
    expect(updates, 1);
  });

  testWidgets('required I3 hides update when no reviewed store action exists', (
    tester,
  ) async {
    await _pump(
      tester,
      const SystemSurfaceScreen.fromId(
        'force-update',
        forceUpdateRequirement: LoopForceUpdateRequirement(),
      ),
    );

    expect(find.text('Update LOOP to continue'), findsOneWidget);
    expect(find.text('Update now'), findsNothing);
    expect(
      find.textContaining('no reviewed store action is connected'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PopScope<void>>(
            find.byKey(const ValueKey<String>('system-state-blocking')),
          )
          .canPop,
      isFalse,
    );
  });

  testWidgets('force-update dialog requires the same explicit evidence', (
    tester,
  ) async {
    var updates = 0;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showLoopForceUpdateDialog(
            context,
            requirement: const LoopForceUpdateRequirement(),
            onUpdate: () => updates += 1,
          ),
          child: const Text('Open verified update'),
        ),
      ),
    );

    await tester.tap(find.text('Open verified update'));
    await tester.pumpAndSettle();
    expect(find.text('Update LOOP to continue'), findsOneWidget);
    expect(find.textContaining('approved version policy'), findsOneWidget);
    expect(find.textContaining('protect account'), findsNothing);
    expect(find.textContaining('latest version'), findsNothing);
    expect(
      tester
          .widgetList<PopScope<void>>(find.byType(PopScope))
          .any((scope) => !scope.canPop),
      isTrue,
    );

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Update LOOP to continue'), findsOneWidget);

    await tester.tap(find.text('Update now'));
    expect(updates, 1);
  });

  testWidgets('required I3 exposes an accessible blocking action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'force-update',
          forceUpdateRequirement: const LoopForceUpdateRequirement(),
          onForceUpdate: () {},
        ),
      );

      final title = tester.getSemantics(find.text('Update LOOP to continue'));
      final updateButton = tester.getSemantics(
        find.widgetWithText(FilledButton, 'Update now'),
      );
      expect(title.flagsCollection.isHeader, isTrue);
      expect(updateButton.label, 'Update now');
      expect(updateButton.flagsCollection.isButton, isTrue);
      expect(
        updateButton.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  for (final testCase in <({String name, Widget screen})>[
    (name: 'unknown', screen: const SystemSurfaceScreen.fromId('force-update')),
    (
      name: 'required',
      screen: const SystemSurfaceScreen.fromId(
        'force-update',
        forceUpdateRequirement: LoopForceUpdateRequirement(),
      ),
    ),
  ]) {
    testWidgets('${testCase.name} I3 remains usable at large text', (
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
