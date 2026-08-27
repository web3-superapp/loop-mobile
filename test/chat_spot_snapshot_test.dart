import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_preview_pages.dart';

void main() {
  testWidgets(
    'chat preview asset snapshot is spot-only and labels fixture facts',
    (tester) async {
      await _pumpSpotPreview(tester);

      expect(
        find.byKey(const ValueKey<String>('chat-spot-snapshot-card')),
        findsOneWidget,
      );
      expect(find.text('SPOT PREVIEW'), findsOneWidget);
      expect(find.text('Shared at 14:12 · 演示数据'), findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey<String>('chat-spot-snapshot-semantics')),
      );
      expect(semantics.properties.label, 'ETH Spot market snapshot · 开发预览');
      expect(find.text('ETH position snapshot'), findsNothing);
      expect(find.text('LONG'), findsNothing);
      expect(find.text('Entry'), findsNothing);
      expect(find.text('Save setup'), findsNothing);

      final watchButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey<String>('chat-spot-watch-unavailable')),
      );
      expect(watchButton.onPressed, isNull);
    },
  );

  testWidgets('chat preview spot card opens the public Spot market ledger', (
    tester,
  ) async {
    await _pumpSpotPreview(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('chat-spot-market-entry')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('chat-spot-market-entry')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('public-spot-market-ledger')),
      findsOneWidget,
    );
    expect(find.text('Public Spot market ledger'), findsOneWidget);
  });

  testWidgets('chat Spot snapshot supports 390pt at 2x Dynamic Type', (
    tester,
  ) async {
    await _pumpSpotPreview(tester, textScale: 2);

    expect(
      find.byKey(const ValueKey<String>('chat-spot-snapshot-card')),
      findsOneWidget,
    );
    expect(find.text('SPOT PREVIEW'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpSpotPreview(
  WidgetTester tester, {
  double textScale = 1,
}) async {
  _configureTestView(tester);

  final router = GoRouter(
    initialLocation: '/preview/asset-message',
    routes: <RouteBase>[
      GoRoute(
        path: '/preview/asset-message',
        builder: (context, state) => const AssetMessagePreviewPage(),
      ),
      GoRoute(
        path: '/market',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text(
              'Public Spot market ledger',
              key: ValueKey<String>('public-spot-market-ledger'),
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      theme: LoopTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _configureTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
