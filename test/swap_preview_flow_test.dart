import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/swap_preview_snapshot.dart';
import 'package:loop_mobile/features/wallet/trade_screens.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

void main() {
  testWidgets(
    'editing invalidates every derived Swap fact until atomic restore',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: LoopTheme.dark, home: const SwapScreen()),
      );

      expect(find.text('2302.18'), findsOneWidget);
      expect(find.text(SwapPreviewSnapshot.demo.rate), findsOneWidget);
      expect(find.text('QUOTE · 演示数据'), findsOneWidget);
      expect(_quoteDetailsCard(), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0.75');
      await tester.pump();

      expect(find.text('2302.18'), findsNothing);
      expect(find.text(SwapPreviewSnapshot.demo.rate), findsNothing);
      expect(find.text('QUOTE · 演示数据'), findsNothing);
      expect(_quoteDetailsCard(), findsNothing);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('Demo snapshot invalidated'), findsOneWidget);
      expect(find.text('Restore demo snapshot'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0.50');
      await tester.pump();
      expect(find.text('Restore demo snapshot'), findsOneWidget);
      expect(find.text('2302.18'), findsNothing);

      await tester.tap(find.text('Restore demo snapshot'));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, SwapPreviewSnapshot.demo.payAmount);
      expect(find.text('2302.18'), findsOneWidget);
      expect(find.text(SwapPreviewSnapshot.demo.rate), findsOneWidget);
      expect(find.text('Review demo draft'), findsOneWidget);
      expect(_quoteDetailsCard(), findsOneWidget);
    },
  );

  testWidgets('rapid review taps derive one intent from the current snapshot', (
    tester,
  ) async {
    SigningIntent? captured;
    var revisionCalls = 0;
    var reviewBuilds = 0;
    final router = GoRouter(
      initialLocation: '/swap',
      routes: <RouteBase>[
        GoRoute(
          path: '/swap',
          builder: (context, state) => SwapScreen(
            revisionFactory: () {
              revisionCalls += 1;
              return 'swap-preview-$revisionCalls';
            },
            clock: () => DateTime.utc(2026, 8, 26, 8),
          ),
        ),
        GoRoute(
          path: '/preview/signing-review',
          builder: (context, state) {
            reviewBuilds += 1;
            captured = state.extra! as SigningIntent;
            return const Scaffold(body: Text('Captured swap review'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: LoopTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();

    final review = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Review demo draft'),
    );
    review.onPressed!();
    review.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Captured swap review'), findsOneWidget);
    expect(revisionCalls, 1);
    expect(reviewBuilds, 1);
    expect(captured, isNotNull);
    expect(captured!.revision, 'swap-preview-1');
    expect(captured!.origin, IntentOrigin.localPreview);
    expect(captured!.allowsWalletHandoff, isFalse);
    expect(
      <String, String>{
        for (final field in captured!.fields) field.label: field.value,
      },
      <String, String>{
        'You pay': SwapPreviewSnapshot.demo.payLabel,
        'You receive': SwapPreviewSnapshot.demo.receiveLabel,
        'Rate': SwapPreviewSnapshot.demo.rate,
        'Provider fee': SwapPreviewSnapshot.demo.providerFee,
      },
    );
  });

  testWidgets('quote details consume only the typed snapshot', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const SwapRouteScreen(snapshot: SwapPreviewSnapshot.demo),
      ),
    );

    expect(find.text(SwapPreviewSnapshot.demo.payLabel), findsOneWidget);
    expect(find.text(SwapPreviewSnapshot.demo.receiveLabel), findsOneWidget);
    expect(
      find.text(SwapPreviewSnapshot.demo.minimumReceiveLabel),
      findsOneWidget,
    );
    expect(find.text(SwapPreviewSnapshot.demo.allFees), findsOneWidget);
    expect(find.textContaining('No provider quote exists'), findsOneWidget);
  });
}

Finder _quoteDetailsCard() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is LoopCard && widget.semanticLabel == 'Open swap quote details',
  );
}
