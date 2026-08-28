import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

import 'support/authenticated_test_privy_gateway.dart';

const _legacyLoadingClaims = <String>[
  'Content is on the way',
  'Skeletons preserve the shape of each surface without implying that data has loaded.',
  'List',
  'Detail',
  'Chart',
  'Loading content',
];

void main() {
  testWidgets('production I8 route stays unknown without loading context', (
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
    router.go('/preview/loading');
    await tester.pumpAndSettle();

    expect(find.text('Loading context unavailable'), findsOneWidget);
    expect(find.byType(LoopSkeletonView), findsNothing);
    for (final claim in _legacyLoadingClaims) {
      expect(find.text(claim), findsNothing);
    }

    await tester.tap(find.text('Return to LOOP'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('naked I8 never infers load or consumes generic actions', (
    tester,
  ) async {
    var returns = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'loading',
        onRetry: () => fail('generic retry must not authorize I8'),
        onPrimaryAction: () => fail('generic primary must not authorize I8'),
        onSecondaryAction: () => returns += 1,
      ),
    );

    expect(find.text('Loading context unavailable'), findsOneWidget);
    expect(find.byType(LoopSkeletonView), findsNothing);
    expect(find.text('Try again'), findsNothing);

    await tester.tap(find.text('Return to LOOP'));
    expect(returns, 1);
  });

  testWidgets('I8 rejects invalid list placeholder counts at runtime', (
    tester,
  ) async {
    for (final count in <int>[
      -1,
      0,
      LoopLoadingPresentation.maxListPlaceholders + 1,
      1 << 30,
    ]) {
      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'loading',
          loadingPresentation: LoopLoadingPresentation.list(
            placeholderCount: count,
          ),
        ),
      );

      expect(find.text('Loading context unavailable'), findsOneWidget);
      expect(find.byType(LoopSkeletonView), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('direct I8 renderer also fails closed for invalid density', (
    tester,
  ) async {
    for (final count in <int>[
      -1,
      0,
      LoopLoadingPresentation.maxListPlaceholders + 1,
    ]) {
      await _pump(
        tester,
        LoopSkeletonView(
          presentation: LoopLoadingPresentation.list(placeholderCount: count),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('invalid-loading-presentation')),
        findsOneWidget,
      );
      expect(find.byType(LoopCard), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('I8 renders one exact bounded skeleton presentation', (
    tester,
  ) async {
    const cases =
        <
          ({
            LoopLoadingPresentation presentation,
            String name,
            String semanticLabel,
            int cardCount,
          })
        >[
          (
            presentation: LoopLoadingPresentation.list(placeholderCount: 1),
            name: 'list',
            semanticLabel: 'Loading list content',
            cardCount: 1,
          ),
          (
            presentation: LoopLoadingPresentation.list(),
            name: 'list',
            semanticLabel: 'Loading list content',
            cardCount: 4,
          ),
          (
            presentation: LoopLoadingPresentation.list(
              placeholderCount: LoopLoadingPresentation.maxListPlaceholders,
            ),
            name: 'list',
            semanticLabel: 'Loading list content',
            cardCount: LoopLoadingPresentation.maxListPlaceholders,
          ),
          (
            presentation: LoopLoadingPresentation.detail(),
            name: 'detail',
            semanticLabel: 'Loading detail content',
            cardCount: 1,
          ),
          (
            presentation: LoopLoadingPresentation.chart(),
            name: 'chart',
            semanticLabel: 'Loading chart content',
            cardCount: 1,
          ),
        ];

    final semantics = tester.ensureSemantics();
    try {
      for (final item in cases) {
        await _pump(
          tester,
          SystemSurfaceScreen.fromId(
            'loading',
            loadingPresentation: item.presentation,
          ),
        );

        expect(find.text('Loading in progress'), findsOneWidget);
        expect(
          find.text(
            'The owning feature selected a ${item.name} placeholder for its current pending state.',
          ),
          findsOneWidget,
        );
        expect(find.text('Loading context unavailable'), findsNothing);
        expect(find.byType(LoopSkeletonView), findsOneWidget);
        expect(find.byType(LoopCard), findsNWidgets(item.cardCount));

        final skeleton = tester.widget<LoopSkeletonView>(
          find.byType(LoopSkeletonView),
        );
        expect(skeleton.presentation.kind, item.presentation.kind);
        final skeletonSemantics = tester.getSemantics(
          find.byType(LoopSkeletonView),
        );
        expect(skeletonSemantics.label, item.semanticLabel);
        expect(skeletonSemantics.flagsCollection.isLiveRegion, isTrue);

        for (final claim in _legacyLoadingClaims) {
          expect(find.text(claim), findsNothing);
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('I8 skeleton semantics expose no decorative or result facts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        const SystemSurfaceScreen.fromId(
          'loading',
          loadingPresentation: LoopLoadingPresentation.list(
            placeholderCount: 8,
          ),
        ),
      );

      final skeletonSemantics = tester.getSemantics(
        find.byType(LoopSkeletonView),
      );
      expect(skeletonSemantics.label, 'Loading list content');
      expect(skeletonSemantics.flagsCollection.isLiveRegion, isTrue);
      expect(find.text('8 results'), findsNothing);
      expect(find.text('ETH'), findsNothing);
      expect(find.text('Price'), findsNothing);
      expect(find.text('Provider'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('explicit I8 loading ignores generic system actions', (
    tester,
  ) async {
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'loading',
        loadingPresentation: const LoopLoadingPresentation.detail(),
        onRetry: () => fail('generic retry must stay isolated from I8'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );

    expect(find.text('Loading in progress'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Return to LOOP'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('unknown I8 remains usable at large text', (tester) async {
    var returns = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'loading',
        onSecondaryAction: () => returns += 1,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    await tester.ensureVisible(find.text('Return to LOOP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return to LOOP'));
    expect(returns, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all explicit I8 skeletons fit at large text without animation', (
    tester,
  ) async {
    const presentations = <LoopLoadingPresentation>[
      LoopLoadingPresentation.list(
        placeholderCount: LoopLoadingPresentation.maxListPlaceholders,
      ),
      LoopLoadingPresentation.detail(),
      LoopLoadingPresentation.chart(),
    ];

    for (final presentation in presentations) {
      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'loading',
          loadingPresentation: presentation,
        ),
        size: const Size(390, 844),
        textScaler: const TextScaler.linear(2),
      );

      await tester.ensureVisible(find.byType(LoopSkeletonView));
      await tester.pumpAndSettle();
      expect(find.byType(LoopSkeletonView), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
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
