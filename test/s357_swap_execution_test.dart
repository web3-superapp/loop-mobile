// S357-mobile · decision 0282 (loop-api 0198): the wallet swap runs on
// Privy's own swap, BSC mainnet only. The page lists mainnet assets only,
// says so when there is nothing on mainnet to pay with, and — once the
// server publishes the swap evidence `confirmed` — the confirm button opens
// the one signing exit, whose execute carries the rendered `reviewSha256`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_wallet_intents_api.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_shots.dart';
import 'support/me_page_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment('LOOP_SHOTS_DIR');
const Size _phone = Size(360, 800);

const String _testnetAssetId =
    'eip155:97:0x1111111111111111111111111111111111111111';

DateTime _fresh() => DateTime.utc(2026, 9, 9, 13, 35, 45);

Finder _key(String key) => find.byKey(ValueKey<String>(key));

LoopBalanceAvailable _zero() => LoopBalanceAvailable(
  rawValue: '0',
  displayBalance: s5Decimal('0'),
  availableBalance: s5Decimal('0'),
  spendableBalance: s5Decimal('0'),
  gasReserve: s5Decimal('0'),
);

FakeWalletReadGateway _wallet(List<LoopAssetBalanceRow> rows) =>
    FakeWalletReadGateway(
      balances: S5Answer<LoopWalletBalances>(value: s5Balances(rows: rows)),
    );

/// Nothing on mainnet; a funded row on the Launch testnet that must not
/// count.
FakeWalletReadGateway _noMainnetBalance() => _wallet(<LoopAssetBalanceRow>[
  s5Row(balance: _zero()),
  s5Row(assetId: s5WbnbAssetId, balance: _zero()),
  s5Row(assetId: _testnetAssetId),
]);

FakeWalletReadGateway _funded() => _wallet(<LoopAssetBalanceRow>[
  s5Row(),
  s5Row(assetId: s5WbnbAssetId),
  s5Row(assetId: _testnetAssetId),
]);

Future<void> _quote(WidgetTester tester) async {
  await tester.tap(_key('swap-source-pick'));
  await tester.pumpAndSettle();
  await tester.tap(_key('swap-pick-$s5NativeAssetId'));
  await tester.pumpAndSettle();
  await tester.tap(_key('swap-destination-pick'));
  await tester.pumpAndSettle();
  await tester.tap(_key('swap-pick-$s5WbnbAssetId'));
  await tester.pumpAndSettle();
  await tester.enterText(_key('swap-source-amount'), '0.005');
  await tester.pump(swapQuoteDebounce + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  await tester.runAsync(loopLoadShotFonts);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  group('execute wire', () {
    Future<Object?> execute({String? reviewSha256}) async {
      RequestOptions? captured;
      final api = DioLoopV2WalletIntentsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(
            s5Response(options, s6SwapIntentBody(state: 'submitted')),
          );
        }),
      );
      await api.execute(
        accessToken: 'privy-access-token',
        clientVersion: s5ClientVersion,
        idempotencyKey: '9d0e1f2a-3b4c-4d5e-8f6a-7b8c9d0e1f2a',
        intentId: s6IntentId,
        authorizationSignature: 'MEUCIQ==',
        reviewSha256: reviewSha256,
      );
      return captured!.data;
    }

    test('the rendered review digest rides along with the signature', () async {
      expect(await execute(reviewSha256: 'c' * 64), <String, Object?>{
        'authorizationSignature': 'MEUCIQ==',
        'reviewSha256': 'c' * 64,
      });
    });

    test('without a digest the body is the 0035 body', () async {
      expect(await execute(), <String, Object?>{
        'authorizationSignature': 'MEUCIQ==',
      });
    });

    test('a malformed digest never leaves the device', () async {
      await expectLater(execute(reviewSha256: 'C' * 64), throwsA(anything));
    });
  });

  group('mainnet only', () {
    test('a Launch testnet row never reaches the swap picker', () {
      final balances = s5Balances(
        rows: <LoopAssetBalanceRow>[
          s5Row(),
          s5Row(assetId: _testnetAssetId),
        ],
      );
      final mainnet = swapMainnetBalances(balances);
      expect(mainnet.balances.map((row) => row.assetId), <String>[
        s5NativeAssetId,
      ]);
      expect(swapIsMainnetAssetId(s5UsdtAssetId), isTrue);
      expect(swapIsMainnetAssetId(_testnetAssetId), isFalse);
    });

    test('a failed read is not "no balance"', () {
      final balances = s5Balances(
        rows: <LoopAssetBalanceRow>[
          s5Row(balance: _zero()),
          s5Row(
            assetId: s5WbnbAssetId,
            balance: const LoopBalanceUnavailable('BSC_RPC_UNAVAILABLE'),
          ),
        ],
      );
      expect(swapHasNoMainnetBalance(balances), isFalse);
      expect(
        swapHasNoMainnetBalance(
          s5Balances(rows: <LoopAssetBalanceRow>[s5Row(balance: _zero())]),
        ),
        isTrue,
      );
    });

    testWidgets('no mainnet balance: one explanation and the way to Receive', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpS6Page(
        tester,
        SwapScreen(
          clock: _fresh,
          onNavigate: (location, {extra}) => opened.add(location),
        ),
        wallet: _noMainnetBalance(),
        quotes: FakeSwapQuoteGateway(),
        intents: FakeWalletIntentsGateway(),
        size: _phone,
      );

      expect(_key('swap-no-mainnet-balance'), findsOneWidget);
      expect(find.text('No BNB Chain mainnet balance'), findsOneWidget);
      expect(
        find.text('Swap supports BNB Chain mainnet assets only.'),
        findsOneWidget,
      );
      // The form and its buttons are not drawn: there is nothing to quote.
      expect(_key('swap-panel'), findsNothing);
      expect(_key('swap-quote-action'), findsNothing);
      expect(_key('swap-confirm-action'), findsNothing);
      await _shot(tester, 'swap-no-mainnet-balance');

      await tester.tap(_key('swap-receive-entry'));
      await tester.pumpAndSettle();
      expect(opened, <String>[WalletRoute.receive(s5WalletId)]);
    });

    testWidgets('a pair asked for off mainnet is dropped, and said once', (
      tester,
    ) async {
      final quotes = FakeSwapQuoteGateway();
      await pumpS6Page(
        tester,
        SwapScreen(
          clock: _fresh,
          initialSourceAssetId: _testnetAssetId,
          initialDestinationAssetId: s5WbnbAssetId,
        ),
        wallet: _funded(),
        quotes: quotes,
        intents: FakeWalletIntentsGateway(),
      );

      expect(_key('swap-mainnet-only'), findsOneWidget);
      // The source is unnamed; the mainnet destination stays.
      expect(
        find.descendant(
          of: _key('swap-source-pick'),
          matching: find.text('Choose asset'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('swap-destination-pick'),
          matching: find.text('WBNB'),
        ),
        findsOneWidget,
      );

      await tester.tap(_key('swap-source-pick'));
      await tester.pumpAndSettle();
      expect(_key('swap-pick-$_testnetAssetId'), findsNothing);
      expect(_key('swap-pick-$s5NativeAssetId'), findsOneWidget);
      expect(quotes.quoteCalls, 0);
    });
  });

  group('quote', () {
    testWidgets('with a balance the page quotes; pending evidence holds it', (
      tester,
    ) async {
      final quotes = FakeSwapQuoteGateway();
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: _funded(),
        quotes: quotes,
        intents: FakeWalletIntentsGateway(),
        size: _phone,
      );
      expect(_key('swap-no-mainnet-balance'), findsNothing);

      await _quote(tester);

      expect(quotes.quoteCalls, 1);
      expect(_key('swap-quote-facts'), findsOneWidget);
      expect(_key('swap-evidence-pending'), findsOneWidget);
      final confirm = tester.widget<LoopButton>(_key('swap-confirm-action'));
      expect(confirm.label, 'Swap is still being verified');
      expect(confirm.onPressed, isNull);
      await _shot(tester, 'swap-quote-evidence-pending');
    });
  });

  group('confirmed evidence (PRIVY_SWAP_EXECUTION_ENABLED=on)', () {
    testWidgets('confirm opens the sign sheet; execute carries the review', (
      tester,
    ) async {
      final opened = <String>[];
      final intents = FakeWalletIntentsGateway(
        prepared: s6SwapIntent(executable: true),
        reported: s6SwapIntent(state: 'submitted'),
      );
      final signing = RecordingSigningGateway(value: 'MEUCIQDsignature==');
      await pumpS6Page(
        tester,
        SwapScreen(
          clock: _fresh,
          onNavigate: (location, {extra}) => opened.add(location),
        ),
        wallet: _funded(),
        quotes: FakeSwapQuoteGateway(),
        intents: intents,
        signing: signing,
        swapEvidencePending: false,
        swapEvidenceConfirmed: true,
        size: _phone,
      );

      await _quote(tester);

      expect(_key('swap-evidence-pending'), findsNothing);
      final confirm = tester.widget<LoopButton>(_key('swap-confirm-action'));
      expect(confirm.label, startsWith('Swap ('));
      expect(confirm.onPressed, isNotNull);
      await _shot(tester, 'swap-quote-confirmed');

      await tester.tap(_key('swap-confirm-action'));
      await tester.pumpAndSettle();
      expect(intents.prepareCalls, 1);
      // The quote's simulation is unavailable; `signing.allowed` decides.
      expect(_key('loop-sign-sheet-pending'), findsOneWidget);

      await tester.ensureVisible(find.text('Confirm signature'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm signature'));
      await tester.pumpAndSettle();

      expect(signing.handoffs, hasLength(1));
      expect(intents.executeCalls, 1);
      expect(intents.signatures, <String>['MEUCIQDsignature==']);
      expect(intents.executedReviews, <String?>['c' * 64]);
      expect(_key('loop-sign-sheet-complete'), findsOneWidget);
    });

    testWidgets('an intent the server did not allow is never signed', (
      tester,
    ) async {
      final intents = FakeWalletIntentsGateway(prepared: s6SwapIntent());
      final signing = RecordingSigningGateway();
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: _funded(),
        quotes: FakeSwapQuoteGateway(),
        intents: intents,
        signing: signing,
        swapEvidencePending: false,
        swapEvidenceConfirmed: true,
      );

      await _quote(tester);
      await tester.tap(_key('swap-confirm-action'));
      await tester.pumpAndSettle();

      expect(_key('loop-sign-sheet-pending'), findsNothing);
      expect(signing.handoffs, isEmpty);
      expect(intents.executeCalls, 0);
    });
  });

  testWidgets('the Me page Swap key stays live with nothing on mainnet', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpMePage(
      tester,
      onNavigate: opened.add,
      balances: s5Balances(
        rows: <LoopAssetBalanceRow>[s5Row(balance: _zero())],
      ),
      meta: s5MetaSnapshot(
        community: LoopV2CapabilityAvailability.available,
        privySwap: LoopV2CapabilityAvailability.available,
        sendApprovals: LoopV2CapabilityAvailability.available,
      ),
    );
    final entry = find.byKey(const ValueKey<String>('wallet-swap-entry'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(opened, <String>['/wallet/swap']);
  });
}
