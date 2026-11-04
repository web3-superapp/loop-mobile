import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_specimens.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';

import 'support/system_surface_harness.dart';
import 'support/test_hints.dart';

import 'package:loop_mobile/widgets/loop_inline_states.dart';

void main() {
  // S237 · decision 0204: these cases pin the testnet / specimen behaviour.
  loopShowTestHints();

  testWidgets('production offline route draws both specimen states', (
    tester,
  ) async {
    await expectProductionSpecimen(
      tester,
      location: '/system/offline',
      kicker: loopStateSpecimenLabel,
      specimenKeys: <String>[
        'connectivity-specimen',
        'connectivity-specimen-retry',
      ],
      specimenText: <String>[
        'Fully offline',
        "BSC network isn't available right now",
        'Why tell these two apart',
      ],
    );
  });

  testWidgets('the offline specimen is labelled and never claims now', (
    tester,
  ) async {
    var retries = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'offline',
        onRetry: () => retries += 1,
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('a specimen page has no 返回 LOOP'),
      ),
    );
    // The prototype page, drawn in full — under a bar that says it is one.
    expect(find.text(loopStateSpecimenLabel), findsOneWidget);
    expect(find.text('This device is offline'), findsOneWidget);
    expect(find.text('Last sync 09:38'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Can\'t connect to the server'), findsOneWidget);
    expect(find.text('Partial outage (another state)'), findsOneWidget);
    expect(find.text('BSC network isn\'t available right now'), findsOneWidget);
    // No banner is raised over the rest of the app by a specimen, and the
    // page keeps no generic 返回 LOOP.
    expect(find.byType(LoopConnectivityBanner), findsNothing);
    expect(find.text('Back to LOOP'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('system-state-dismissible')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('explicit scopes render their exact notice and actions', (
    tester,
  ) async {
    final cases = <(LoopConnectivityScope, String, String)>[
      (
        LoopConnectivityScope.fullyOffline,
        'This device is offline',
        'Fully offline',
      ),
      (
        LoopConnectivityScope.marketDataUnavailable,
        'Market data unavailable',
        'Market data unavailable',
      ),
      (
        LoopConnectivityScope.tradingServiceUnavailable,
        'Trading service unavailable',
        'Trading service unavailable',
      ),
    ];
    for (final (scope, heading, notice) in cases) {
      var retries = 0;
      var continues = 0;
      await pumpSystemSurface(
        tester,
        SystemSurfaceScreen.fromId(
          'offline',
          connectivityObservation: LoopConnectivityObservation(scope: scope),
          onRetry: () => retries += 1,
          onPrimaryAction: () => fail('generic primary must stay isolated'),
          onSecondaryAction: () => continues += 1,
        ),
      );
      expect(find.text(heading), findsWidgets, reason: scope.name);
      expect(find.text(notice), findsWidgets, reason: scope.name);
      expect(
        find.text(loopStateSpecimenLabel),
        findsNothing,
        reason: scope.name,
      );
      expect(find.text('Back to LOOP'), findsNothing, reason: scope.name);
      // No lastSyncAt and no per-chain source: neither may be invented.
      expect(
        find.textContaining('Last sync'),
        findsNothing,
        reason: scope.name,
      );
      await scrollPageTo(
        tester,
        find.byKey(const ValueKey<String>('partial-outage-source-unavailable')),
      );
      expect(
        find.byKey(const ValueKey<String>('partial-outage-notice')),
        findsNothing,
        reason: scope.name,
      );
      if (scope == LoopConnectivityScope.fullyOffline) {
        expect(find.byType(LoopInlineUnavailable), findsOneWidget);
        expect(find.text('Can\'t connect to the server'), findsWidgets);
        expect(find.text('Offline'), findsOneWidget);
      }
      // Decision 0281 transition: the fully-offline retry is the shared
      // lib/widgets inline control, not migrated yet.
      final retry = scope == LoopConnectivityScope.fullyOffline
          ? '重试'
          : 'Retry';
      await tester.ensureVisible(find.text(retry));
      await tester.tap(find.text(retry));
      expect(retries, 1, reason: scope.name);
      await tester.tap(
        find.text(
          scope == LoopConnectivityScope.fullyOffline
              ? 'View cached content'
              : 'Keep using available features',
        ),
      );
      expect(continues, 1, reason: scope.name);
    }
  });

  testWidgets('lastSyncAt and a named outage are shown only when supplied', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'offline',
        connectivityObservation: LoopConnectivityObservation(
          scope: LoopConnectivityScope.fullyOffline,
          lastSyncAt: DateTime(2026, 9, 7, 9, 38),
          partialOutage: const LoopPartialOutage(networkLabel: 'BSC'),
        ),
      ),
    );

    expect(find.text('Last sync 09:38'), findsOneWidget);
    expect(find.text('Device offline'), findsNothing);
    await scrollPageTo(
      tester,
      find.byKey(const ValueKey<String>('partial-outage-notice')),
    );
    expect(find.text('Partial outage (another state)'), findsOneWidget);
    expect(find.text('BSC network isn\'t available right now'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('partial-outage-source-unavailable')),
      findsNothing,
    );
  });

  testWidgets('offline without lastSyncAt states the device state only', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'offline',
        connectivityObservation: const LoopConnectivityObservation(
          scope: LoopConnectivityScope.fullyOffline,
        ),
      ),
    );

    expect(find.text('Device offline'), findsOneWidget);
    expect(find.textContaining('Last sync'), findsNothing);
  });

  testWidgets('connectivity banner announces and retries', (tester) async {
    final semantics = tester.ensureSemantics();
    var retries = 0;
    await pumpSystemSurface(
      tester,
      Scaffold(
        body: LoopConnectivityBanner(
          scope: LoopConnectivityScope.marketDataUnavailable,
          onRetry: () => retries += 1,
        ),
      ),
      textScale: 2,
    );
    expect(
      find.text('Market data unavailable, prices may be stale'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Market data unavailable')),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    semantics.dispose();
  });

  testWidgets('offline states remain usable at 2x text', (tester) async {
    for (final observation in <LoopConnectivityObservation?>[
      null,
      const LoopConnectivityObservation(
        scope: LoopConnectivityScope.fullyOffline,
      ),
    ]) {
      await pumpSystemSurface(
        tester,
        SystemSurfaceScreen.fromId(
          'offline',
          connectivityObservation: observation,
          onRetry: () {},
          onSecondaryAction: () {},
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      final action = find.text(
        observation == null ? 'Retry' : 'View cached content',
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
    }
  });
}
