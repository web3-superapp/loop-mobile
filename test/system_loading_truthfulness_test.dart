import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production skeleton-states route shows samples only', (
    tester,
  ) async {
    final router = await pumpProductionApp(tester);
    router.go('/preview/loading');
    // The skeleton pulse never settles; pump a bounded number of frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey<String>('loading-source-unavailable')),
      findsOneWidget,
    );
    expect(find.text('当前加载'), findsNothing);
    expect(find.byType(LoopSkeletonView), findsNothing);
    expect(find.text('列表骨架'.toUpperCase()), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('loop-skeleton-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('loop-skeleton-detail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('loop-skeleton-chart')),
      findsOneWidget,
    );
    for (final claim in <String>['8 results', 'ETH', 'Price', 'Provider']) {
      expect(find.text(claim), findsNothing);
    }
    await tester.tap(find.byKey(const ValueKey<String>('loop-topbar-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.routeInformationProvider.value.uri.path, '/community');
  });

  testWidgets('invalid list density fails closed in page and renderer', (
    tester,
  ) async {
    for (final count in <int>[0, 9]) {
      await pumpSystemSurface(
        tester,
        SystemSurfaceScreen.fromId(
          'loading',
          loadingPresentation: LoopLoadingPresentation.list(
            placeholderCount: count,
          ),
        ),
      );
      expect(find.text('当前加载'), findsNothing, reason: '$count');
      expect(find.byType(LoopSkeletonView), findsNothing, reason: '$count');
      await pumpSystemSurface(
        tester,
        Scaffold(
          body: LoopSkeletonView(
            presentation: LoopLoadingPresentation.list(placeholderCount: count),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('invalid-loading-presentation')),
        findsOneWidget,
      );
    }
  });

  testWidgets('an explicit presentation renders exactly one bounded skeleton', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final (presentation, key, label)
        in <(LoopLoadingPresentation, String, String)>[
          (
            const LoopLoadingPresentation.list(placeholderCount: 2),
            'loop-skeleton-list',
            '列表加载中',
          ),
          (
            const LoopLoadingPresentation.detail(),
            'loop-skeleton-detail',
            '详情加载中',
          ),
          (
            const LoopLoadingPresentation.chart(),
            'loop-skeleton-chart',
            '图表加载中',
          ),
        ]) {
      await pumpSystemSurface(
        tester,
        SystemSurfaceScreen.fromId(
          'loading',
          loadingPresentation: presentation,
          onRetry: () {},
          onSecondaryAction: () {},
        ),
      );
      expect(find.text('当前加载'), findsOneWidget, reason: key);
      expect(find.byType(LoopSkeletonView), findsOneWidget, reason: key);
      expect(find.bySemanticsLabel(label), findsWidgets, reason: key);
      expect(find.text('重试'), findsNothing);
      expect(find.text('返回 LOOP'), findsNothing);
      final live = find.descendant(
        of: find.byType(LoopSkeletonView),
        matching: find.byKey(ValueKey<String>(key)),
      );
      expect(live, findsOneWidget, reason: key);
      expect(
        find.descendant(
          of: find.byType(LoopSkeletonView),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    }
    semantics.dispose();
  });

  testWidgets('skeleton page remains usable at 2x text', (tester) async {
    await pumpSystemSurface(
      tester,
      const SystemSurfaceScreen.fromId(
        'loading',
        loadingPresentation: LoopLoadingPresentation.chart(),
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('loop-skeleton-chart')).last,
    );
    expect(find.byType(LoopSkeleton), findsWidgets);
  });
}
