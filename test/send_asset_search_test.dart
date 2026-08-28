import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';

void main() {
  testWidgets(
    'Send asset search filters labelled Preview assets and restores canonical order',
    (tester) async {
      await _pumpSendAsset(tester);

      final eth = find.byKey(const ValueKey<String>('send-asset-preview-eth'));
      final usdc = find.byKey(
        const ValueKey<String>('send-asset-preview-usdc'),
      );
      final sol = find.byKey(const ValueKey<String>('send-asset-preview-sol'));
      final arb = find.byKey(
        const ValueKey<String>('send-asset-preview-arb-unavailable'),
      );

      expect(eth, findsOneWidget);
      expect(usdc, findsOneWidget);
      expect(sol, findsOneWidget);
      expect(arb, findsOneWidget);
      expect(tester.getTopLeft(eth).dy, lessThan(tester.getTopLeft(usdc).dy));
      expect(tester.getTopLeft(usdc).dy, lessThan(tester.getTopLeft(sol).dy));
      expect(tester.getTopLeft(sol).dy, lessThan(tester.getTopLeft(arb).dy));

      await tester.enterText(
        find.byKey(const ValueKey<String>('send-asset-preview-search')),
        '  uSd   ethereum  ',
      );
      await tester.pump();

      expect(eth, findsNothing);
      expect(usdc, findsOneWidget);
      expect(sol, findsNothing);
      expect(arb, findsNothing);

      await tester.tap(find.byTooltip('Clear asset search'));
      await tester.pump();

      expect(eth, findsOneWidget);
      expect(usdc, findsOneWidget);
      expect(sol, findsOneWidget);
      expect(arb, findsOneWidget);
    },
  );

  testWidgets(
    'filtered Send asset selection carries the exact asset and network',
    (tester) async {
      await _pumpSendAsset(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('send-asset-preview-search')),
        'sol',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('send-asset-preview-sol')),
      );
      await tester.pumpAndSettle();

      expect(find.text('SOL · Solana'), findsOneWidget);
      expect(find.text('ETH · Ethereum'), findsNothing);
    },
  );

  testWidgets('Send asset no-match remains local Preview evidence', (
    tester,
  ) async {
    await _pumpSendAsset(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('send-asset-preview-search')),
      'bitcoin',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('send-asset-preview-empty')),
      findsOneWidget,
    );
    expect(find.text('No local preview assets match'), findsOneWidget);
    expect(
      find.textContaining('No wallet provider search was performed.'),
      findsOneWidget,
    );
    expect(find.textContaining('No assets in wallet'), findsNothing);
    expect(find.text('Ethereum'), findsNothing);
    expect(find.text('USD Coin'), findsNothing);
    expect(find.text('Solana'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('send-asset-preview-arb-unavailable')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('send-asset-preview-search')),
      'arbitrum',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('send-asset-preview-empty')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('send-asset-preview-arb-unavailable')),
      findsOneWidget,
    );
    expect(
      find.textContaining(r'Arbitrum · 0 ARB · $0.00 on Arbitrum'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('send-asset-preview-arb-unavailable'),
        ),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.button == true,
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('send-asset-preview-eth')),
      findsNothing,
    );
  });

  testWidgets('Send asset Preview supports 390pt at 2x Dynamic Type', (
    tester,
  ) async {
    await _pumpSendAsset(tester, textScaler: const TextScaler.linear(2));

    final search = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('send-asset-preview-search')),
    );
    expect(search.decoration?.labelText, 'Search preview assets');

    await tester.enterText(
      find.byKey(const ValueKey<String>('send-asset-preview-search')),
      'eth',
    );
    await tester.pump();
    expect(find.byTooltip('Clear asset search'), findsOneWidget);
    final assetSemantics = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byKey(const ValueKey<String>('send-asset-preview-eth')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(assetSemantics.properties.label, contains('Ethereum'));
    expect(assetSemantics.properties.button, isTrue);
    expect(assetSemantics.properties.onTap, isNotNull);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Clear asset search'));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('send-asset-preview-arb-unavailable')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpSendAsset(
  WidgetTester tester, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const SendAssetScreen()),
      GoRoute(
        path: '/wallet/send/to',
        builder: (context, state) {
          final draft = state.extra! as TransferDraft;
          return Scaffold(body: Text('${draft.asset} · ${draft.network}'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      theme: LoopTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
