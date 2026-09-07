import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';

void main() {
  testWidgets('Chalk bar reserves 90 + safe area and floats 8 + safe area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext bodyContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(bottom: 34, top: 47),
          ),
          child: LoopShell(
            location: '/community',
            child: Builder(
              builder: (context) {
                bodyContext = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(MediaQuery.paddingOf(bodyContext).bottom, 90 + 34);

    final barBox = tester.getRect(
      find.byKey(const ValueKey<String>('loop-tab-bar')),
    );
    expect(barBox.height, 90 + 34);

    final chalk = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('loop-tab-bar')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).color == LoopColors.chalk,
        ),
      ),
    );
    final chalkRect = tester.getRect(find.byWidget(chalk));
    expect(chalkRect.height, LoopTouch.tabBarHeight);
    expect(chalkRect.left, LoopLayout.tabBarInset);
    expect(chalkRect.right, 390 - LoopLayout.tabBarInset);
    expect(844 - chalkRect.bottom, 34);
    final decoration = chalk.decoration! as BoxDecoration;
    expect(decoration.borderRadius, LoopRadius.tabBar);
    expect(decoration.boxShadow, LoopDepth.tabBar);
  });

  testWidgets('selected tab uses the Lime gradient and Ink, others Ink 62%', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var selected = 3;
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: LoopTabBar(
              selectedIndex: selected,
              onSelect: (index) => setState(() => selected = index),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final items = tester.widgetList<LoopTabItem>(find.byType(LoopTabItem));
    expect(items.map((item) => item.label), <String>[
      '社区',
      '挖矿',
      'Launch',
      '行情',
      '钱包',
    ]);
    expect(items.map((item) => item.slug), <String>[
      'community',
      'mining',
      'launch',
      'market',
      'wallet',
    ]);
    expect(items.map((item) => item.selected), <bool>[
      false,
      false,
      false,
      true,
      false,
    ]);

    BoxDecoration decorationOf(String label) {
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.widgetWithText(LoopTabItem, label),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return container.decoration! as BoxDecoration;
    }

    final market = decorationOf('行情');
    expect(market.gradient, isA<LinearGradient>());
    expect((market.gradient! as LinearGradient).colors.last, LoopColors.lime);
    expect(decorationOf('钱包').gradient, isNull);

    Color labelColor(String label) => tester
        .widget<Text>(
          find.descendant(
            of: find.widgetWithText(LoopTabItem, label),
            matching: find.text(label),
          ),
        )
        .style!
        .color!;
    expect(labelColor('行情'), LoopColors.ink);
    expect(labelColor('钱包'), LoopColors.inkMuted);

    expect(
      tester.getSize(find.widgetWithText(LoopTabItem, '钱包')).height,
      greaterThanOrEqualTo(LoopTouch.tabCellMinHeight),
    );
    expect(
      tester.getSemantics(find.widgetWithText(LoopTabItem, '行情')),
      matchesSemantics(
        label: '行情',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );

    await tester.tap(find.widgetWithText(LoopTabItem, '钱包'));
    await tester.pumpAndSettle();
    expect(selected, 4);
    expect(decorationOf('钱包').gradient, isNotNull);
    semantics.dispose();
  });

  testWidgets('tab pages fade and child pages push; reduced motion disables', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/community',
      routes: <RouteBase>[
        ShellRoute(
          builder: (context, state, child) =>
              LoopShell(location: state.uri.path, child: child),
          routes: <RouteBase>[
            GoRoute(
              path: '/community',
              pageBuilder: (context, state) => LoopTabPage<void>(
                key: state.pageKey,
                child: const Center(child: Text('community')),
              ),
            ),
            GoRoute(
              path: '/wallet',
              pageBuilder: (context, state) => LoopTabPage<void>(
                key: state.pageKey,
                child: const Center(child: Text('wallet')),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/wallet/send',
          builder: (context, state) => const Scaffold(body: Text('send')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: LoopTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();

    router.go('/wallet');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(LoopTabBar), findsOneWidget);
    await tester.pumpAndSettle();

    unawaited(router.push('/wallet/send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SlideTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byType(LoopTabBar), findsNothing);
    expect(find.text('send'), findsOneWidget);

    // Reduced motion: the push builder returns the child untouched.
    await tester.pumpWidget(
      MaterialApp.router(
        theme: LoopTheme.dark,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/community');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('community'), findsOneWidget);
    await tester.pumpAndSettle();
    unawaited(router.push('/wallet/send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      find.ancestor(
        of: find.text('send'),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('wide layouts keep the rail with sprite icons and Ink ground', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const LoopShell(location: '/market', child: SizedBox.expand()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(LoopTabBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 3);
    expect(rail.backgroundColor, LoopColors.ink);
    expect(rail.indicatorColor, LoopColors.lime);
    expect(rail.destinations.map((d) => (d.label as Text).data), <String>[
      '社区',
      '挖矿',
      'Launch',
      '行情',
      '钱包',
    ]);
  });
}
