import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_specimens.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production token-card-states route draws all five cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = await pumpProductionApp(tester);
    router.go('/system/token-card');
    await tester.pumpAndSettle();

    // The page is the component's specification, so the cards are the page.
    expect(find.text(loopComponentSpecimenLabel), findsOneWidget);
    expect(find.text('演示数据 · 开发预览'), findsNothing);
    for (final state in LoopTokenCardState.values) {
      final key = ValueKey<String>('loop-token-card-${state.name}');
      await scrollPageTo(tester, find.byKey(key));
      expect(find.byKey(key), findsOneWidget, reason: state.name);
    }
    // 5 STATES in the hero and five cards under it.
    expect(find.byType(LoopTokenCard), findsNWidgets(5));
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

    expect(find.text('演示数据 · 开发预览'), findsOneWidget);
    expect(find.text(loopComponentSpecimenLabel), findsNothing);
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

  testWidgets('the component-appearance note follows the first card', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      const SystemSurfaceScreen.fromId('token-card-states'),
    );
    final disclosure = tester.getTopLeft(find.text('查看组件出现位置')).dy;
    final firstCard = tester.getTopLeft(
      find.byKey(const ValueKey<String>('loop-token-card-normal')),
    );
    expect(disclosure, greaterThan(firstCard.dy));
  });
}
