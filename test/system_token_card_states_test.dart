import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_showcase_preview.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production token-card-states route shows no fixture cards', (
    tester,
  ) async {
    await expectProductionUnavailable(
      tester,
      location: '/system/token-card',
      unavailableKey: 'token-card-showcase-unavailable',
      absentClaims: <String>['PEPE', r'$5.4B', '演示数据', 'GRADUATED'],
    );
  });

  testWidgets('preview showcase renders the five states labelled 演示数据', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = await pumpProductionApp(
      tester,
      overrides: [
        loopSystemShowcaseProvider.overrideWithValue(
          buildLoopSystemShowcasePreview(),
        ),
      ],
    );
    router.go('/system/token-card');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('token-card-showcase-label')),
      findsOneWidget,
    );
    expect(find.text('演示数据 · 开发预览'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('token-card-showcase-unavailable')),
      findsNothing,
    );
    expect(find.text('态 1 · 正常'.toUpperCase()), findsOneWidget);
    for (final state in LoopTokenCardState.values) {
      final key = ValueKey<String>('loop-token-card-${state.name}');
      await scrollPageTo(tester, find.byKey(key));
      expect(find.byKey(key), findsOneWidget, reason: state.name);
    }
    expect(find.text('态 5 · 风险事实红条'.toUpperCase()), findsOneWidget);
    await scrollPageTo(
      tester,
      find.byKey(const ValueKey<String>('loop-token-card-risk-facts')),
    );
    expect(find.textContaining('来源 GoPlus'), findsOneWidget);
    // The risk card lists facts only; the word appears solely in the
    // explanatory notice that says verdicts are never given.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('loop-token-card-risk')),
        matching: find.textContaining('危险'),
      ),
      findsNothing,
    );
    // Showcase actions are inert: they never navigate or sign.
    await tester.tap(find.text('确认事实后买入'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/system/token-card',
    );
  });

  testWidgets('token-card page remains usable at 2x text', (tester) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'token-card-states',
        showcase: buildLoopSystemShowcasePreview(),
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
