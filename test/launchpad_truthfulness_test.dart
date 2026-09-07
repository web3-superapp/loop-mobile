import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launchpad/launchpad_screen.dart';

void main() {
  test('Launch keeps only its tab page implemented in this release', () {
    final launch = LoopRouteManifest.forModule(LoopRouteModule.launch);

    expect(launch, hasLength(11));
    expect(launch.first.slug, 'launch');
    expect(launch.first.path, '/launch');
    expect(launch.first.tab, isTrue);
    expect(launch.first.status, LoopRouteStatus.implemented);
    expect(
      launch.skip(1).every((entry) => entry.status == LoopRouteStatus.pending),
      isTrue,
    );
    expect(
      launch.map((entry) => entry.path),
      everyElement(startsWith('/launch')),
    );
  });

  testWidgets('Launchpad is truthful and exposes no participation action', (
    tester,
  ) async {
    await _pumpLaunchpad(tester);

    expect(find.text('Launch'), findsOneWidget);
    expect(find.text('Coming later'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('launchpad-unavailable')),
      findsOneWidget,
    );
    expect(find.text('NOT CONNECTED'), findsNWidgets(3));
    expect(find.textContaining('does not accept funds'), findsOneWidget);
    expect(find.text('No live launches'), findsNothing);

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Launchpad remains usable at phone width and 2x text scale', (
    tester,
  ) async {
    await _pumpLaunchpad(
      tester,
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('launchpad-unavailable')),
      220,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLaunchpad(
  WidgetTester tester, {
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
      home: const LaunchpadScreen(),
    ),
  );
  await tester.pumpAndSettle();
}
