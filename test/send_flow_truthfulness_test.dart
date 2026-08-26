import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';

void main() {
  const recipient = '0x1111111111111111111111111111111111111111';

  test('transfer draft preserves the complete recipient', () {
    const selected = TransferDraft(asset: 'ETH', network: 'Ethereum');

    final completed = selected.copyWith(recipient: recipient);

    expect(completed.asset, 'ETH');
    expect(completed.network, 'Ethereum');
    expect(completed.recipient, recipient);
  });

  testWidgets('recipient screen never invents validation or screening facts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const SendRecipientScreen(
          draft: TransferDraft(asset: 'ETH', network: 'Ethereum'),
        ),
      ),
    );

    expect(find.text('Complete recipient address'), findsOneWidget);
    expect(find.text('Address or name'), findsNothing);
    expect(find.text('Not verified · backend unavailable'), findsOneWidget);
    expect(find.text('Valid'), findsNothing);
    expect(find.text('No known match'), findsNothing);
  });

  testWidgets('confirmation shows the raw recipient and no fake simulation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const SendConfirmScreen(
          draft: TransferDraft(
            asset: 'ETH',
            network: 'Ethereum',
            recipient: recipient,
          ),
        ),
      ),
    );

    final pageScrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Provider facts unavailable'),
      300,
      scrollable: pageScrollable.first,
    );

    expect(find.text(recipient), findsOneWidget);
    expect(find.text('Provider facts unavailable'), findsOneWidget);
    expect(find.text('Simulation ready'), findsNothing);
    expect(find.text('0xA1c0…88C2'), findsNothing);
  });

  testWidgets(
    'confirmation rejects noncanonical amount syntax without creating review',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const SendConfirmScreen(
            draft: TransferDraft(
              asset: 'ETH',
              network: 'Ethereum',
              recipient: recipient,
            ),
          ),
        ),
      );

      final amountField = find.byType(TextField);
      for (final invalid in <String>['0', '01', '+1', '.5', '1.', '1e3']) {
        await tester.enterText(amountField, invalid);
        await tester.pump();
        final review = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Review draft'),
        );
        expect(review.onPressed, isNull, reason: invalid);
      }
    },
  );

  testWidgets('confirmation preserves and rejects an overlong pasted amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const SendConfirmScreen(
          draft: TransferDraft(
            asset: 'ETH',
            network: 'Ethereum',
            recipient: recipient,
          ),
        ),
      ),
    );
    final overlong = List<String>.filled(129, '1').join();

    await tester.enterText(find.byType(TextField), overlong);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, overlong);
    expect(field.controller!.text, hasLength(129));
    expect(
      find.text('Use canonical positive decimal syntax (max 128 characters)'),
      findsOneWidget,
    );
    final review = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Review draft'),
    );
    expect(review.onPressed, isNull);
  });

  testWidgets(
    'confirmation preserves exact amount and opens one local review per tap burst',
    (tester) async {
      SigningIntent? captured;
      var revisionCalls = 0;
      var reviewBuilds = 0;
      final router = GoRouter(
        initialLocation: '/confirm',
        routes: <RouteBase>[
          GoRoute(
            path: '/confirm',
            builder: (context, state) => SendConfirmScreen(
              draft: const TransferDraft(
                asset: 'ETH',
                network: 'Ethereum',
                recipient: recipient,
              ),
              revisionFactory: () {
                revisionCalls += 1;
                return 'transfer-preview-$revisionCalls';
              },
              clock: () => DateTime.utc(2026, 8, 26, 8),
            ),
          ),
          GoRoute(
            path: '/preview/signing-review',
            builder: (context, state) {
              reviewBuilds += 1;
              captured = state.extra! as SigningIntent;
              return const Scaffold(body: Text('Captured review'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: LoopTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1.2500');
      await tester.pump();

      expect(find.text('1.2500 ETH'), findsOneWidget);
      final review = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Review draft'),
      );
      review.onPressed!();
      review.onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('Captured review'), findsOneWidget);
      expect(revisionCalls, 1);
      expect(reviewBuilds, 1);
      expect(captured, isNotNull);
      expect(captured!.revision, 'transfer-preview-1');
      expect(captured!.origin, IntentOrigin.localPreview);
      expect(captured!.allowsWalletHandoff, isFalse);
      expect(
        captured!.fields.firstWhere((field) => field.label == 'Amount').value,
        '1.2500 ETH',
      );
      expect(
        captured!.fields
            .firstWhere((field) => field.label == 'Recipient')
            .value,
        recipient,
      );
    },
  );

  testWidgets('transaction result catalog never claims a transfer occurred', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: LoopTheme.dark, home: const TransactionResultScreen()),
    );

    expect(
      find.text('No request was sent or submitted. No pending receipt exists.'),
      findsOneWidget,
    );
    expect(find.textContaining('wallet submitted'), findsNothing);
    expect(find.textContaining('reached 0x'), findsNothing);
    expect(find.text('Not submitted'), findsOneWidget);
  });
}
