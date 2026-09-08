import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_client_policy.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';

void main() {
  const promptKey = ValueKey<String>('loop-soft-update-prompt');

  testWidgets('an unknown version gate shows nothing', (tester) async {
    await _pump(tester, const LoopVersionPolicyProjection.unknown());
    expect(find.byKey(promptKey), findsNothing);
  });

  testWidgets('a supported client shows nothing', (tester) async {
    await _pump(
      tester,
      const LoopVersionPolicyProjection(
        decision: LoopVersionPolicyDecision.supported,
        configVersion: 'cfg-1',
        effectiveAt: null,
      ),
    );
    expect(find.byKey(promptKey), findsNothing);
  });

  testWidgets('a required update keeps its own blocking page', (tester) async {
    await _pump(
      tester,
      const LoopVersionPolicyProjection(
        decision: LoopVersionPolicyDecision.updateRequired,
        configVersion: 'cfg-1',
        effectiveAt: null,
        minimumVersion: '1.2.0',
      ),
    );
    // The soft prompt must never stand in for the force-update surface.
    expect(find.byKey(promptKey), findsNothing);
  });

  testWidgets('a recommended update names the floor and can be dismissed', (
    tester,
  ) async {
    await _pump(
      tester,
      const LoopVersionPolicyProjection(
        decision: LoopVersionPolicyDecision.updateRecommended,
        configVersion: 'cfg-1',
        effectiveAt: null,
        minimumVersion: '1.2.0',
      ),
    );

    expect(find.byKey(promptKey), findsOneWidget);
    expect(find.textContaining('1.2.0'), findsOneWidget);
    expect(find.textContaining('仍然可以继续使用'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('loop-soft-update-dismiss')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(promptKey), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  LoopVersionPolicyProjection projection,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loopVersionPolicyProvider.overrideWithValue(projection)],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: const Scaffold(body: LoopSoftUpdatePrompt()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
