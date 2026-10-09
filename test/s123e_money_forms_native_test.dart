import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/scan/loop_qr_scanner.dart';
import 'package:loop_mobile/features/scan/scan_screen.dart';
import 'package:loop_mobile/features/wallet/money_asset_picker.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';

/// Decision 0131 (audit 2026-10-09 M8 M9 M10): money forms behave like a
/// wallet app's — the recipient is checked by itself, the asset list leads
/// with what can be spent, a swap quotes as it is typed.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

LoopButton _button(WidgetTester tester, String key) =>
    tester.widget<LoopButton>(_key(key));

LoopAssetBalanceRow _zeroWbnb() => s5Row(
  assetId: s5WbnbAssetId,
  balance: LoopBalanceAvailable(
    rawValue: '0',
    displayBalance: s5Decimal('0'),
    availableBalance: s5Decimal('0'),
    spendableBalance: s5Decimal('0'),
    gasReserve: s5Decimal('0'),
  ),
);

FakeWalletReadGateway _wallet(List<LoopAssetBalanceRow> rows) =>
    FakeWalletReadGateway(
      balances: S5Answer<LoopWalletBalances>(value: s5Balances(rows: rows)),
    );

void _mockClipboard(WidgetTester tester, String text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => call.method == 'Clipboard.getData'
        ? <String, Object?>{'text': text}
        : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  loopWatchGround();
  group('send · step 1 收款地址', () {
    testWidgets('opens on the field with no folio and step dots 1 of 3', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );
      expect(find.byType(LoopFolioPrimary), findsNothing);
      final dots = tester.widget<LoopStepDots>(find.byType(LoopStepDots));
      expect(dots.step, 1);
      expect(dots.total, 3);
      expect(dots.label, '收款地址');
      expect(_key('send-recipient-paste'), findsOneWidget);
      expect(_key('send-recipient-scan'), findsOneWidget);
      // No 校验地址 button exists any more.
      expect(_key('send-recipient-check'), findsNothing);
      final field = tester.widget<TextField>(_key('send-recipient-field'));
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
    });

    testWidgets('粘贴 fills the field and checks it at once', (tester) async {
      _mockClipboard(tester, s6RecipientChecksum);
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );
      expect(_button(tester, 'send-address-next').onPressed, isNull);
      await tester.tap(_key('send-recipient-paste'));
      await tester.pumpAndSettle();
      expect(_key('send-recipient-checks'), findsOneWidget);
      expect(find.text('地址已校验 · BNB Smart Chain'), findsOneWidget);
      expect(_button(tester, 'send-address-next').onPressed, isNotNull);
    });

    testWidgets('leaving the field checks what was typed', (tester) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );
      await tester.enterText(_key('send-recipient-field'), s6RecipientChecksum);
      // Before the debounce runs, the field loses focus.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump();
      expect(_key('send-recipient-checks'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a malformed address is said once the field is left', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );
      await tester.enterText(_key('send-recipient-field'), '0x12');
      await tester.pumpAndSettle();
      expect(find.text('地址格式不对：0x 开头，共 42 位'), findsNothing);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('地址格式不对：0x 开头，共 42 位'), findsOneWidget);
      expect(_button(tester, 'send-address-next').onPressed, isNull);
    });

    testWidgets('扫码 hands the scanned address back into the field', (
      tester,
    ) async {
      var scans = 0;
      await pumpS6Page(
        tester,
        SendAssetScreen(
          onScan: () async {
            scans += 1;
            return s6RecipientChecksum;
          },
        ),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );
      await tester.tap(_key('send-recipient-scan'));
      await tester.pumpAndSettle();
      expect(scans, 1);
      final field = tester.widget<TextField>(_key('send-recipient-field'));
      expect(field.controller!.text, s6RecipientChecksum);
      expect(_button(tester, 'send-address-next').onPressed, isNotNull);
    });
  });

  group('send · step 2 金额与资产', () {
    testWidgets('全部 fills the spendable balance, gas reserve kept', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: _wallet(<LoopAssetBalanceRow>[s5Row(), _zeroWbnb()]),
        intents: FakeWalletIntentsGateway(),
      );
      await sendToAmountStep(tester);
      final dots = tester.widget<LoopStepDots>(find.byType(LoopStepDots));
      expect(dots.step, 2);
      expect(find.byType(LoopFolioPrimary), findsNothing);
      // The only asset with something to send is chosen without asking.
      expect(find.textContaining('可动用 6.995 BNB'), findsOneWidget);
      await tester.tap(_key('send-amount-max'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(_key('send-amount-field'));
      expect(field.controller!.text, '6.995');
      expect(field.keyboardType, isA<TextInputType>());
      expect(field.keyboardType.decimal, isTrue);
      expect(field.inputFormatters, isNotEmpty);
      expect(_button(tester, 'send-amount-next').onPressed, isNotNull);
    });

    testWidgets('the picker folds zero balances and cannot choose them', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: _wallet(<LoopAssetBalanceRow>[s5Row(), _zeroWbnb()]),
        intents: FakeWalletIntentsGateway(),
      );
      await sendToAmountStep(tester);
      await tester.tap(_key('send-asset-selector'));
      await tester.pumpAndSettle();
      expect(find.byType(LoopSheet), findsOneWidget);
      expect(_key('send-asset-zero'), findsOneWidget);
      expect(find.textContaining('余额为 0 的资产 · 1 个'), findsOneWidget);
      expect(_key('send-asset-$s5WbnbAssetId'), findsNothing);
      // The chosen row carries the check, not a chevron.
      final chosen = tester.widget<LoopRecordRow>(
        _key('send-asset-$s5NativeAssetId'),
      );
      expect(chosen.selected, isTrue);
      expect(chosen.chevron, isFalse);
      await openLoopDisclosure(
        tester,
        const ValueKey<String>('send-asset-zero'),
      );
      final zero = tester.widget<LoopRecordRow>(
        _key('send-asset-$s5WbnbAssetId'),
      );
      expect(zero.onTap, isNull);
    });

    testWidgets('system back on step 2 returns to step 1', (tester) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );
      await sendToAmountStep(tester);
      expect(_key('send-amount-screen'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_key('send-address-screen'), findsOneWidget);
      // The checked address is still there.
      expect(_button(tester, 'send-address-next').onPressed, isNotNull);
    });

    testWidgets('下一步 carries the checked recipient to the confirm step', (
      tester,
    ) async {
      final opened = <Object?>[];
      await pumpS6Page(
        tester,
        SendAssetScreen(onNavigate: (location, {extra}) => opened.add(extra)),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );
      await sendToAmountStep(tester);
      await tester.enterText(_key('send-amount-field'), '0.5');
      await tester.pumpAndSettle();
      await tester.tap(_key('send-amount-next'));
      await tester.pumpAndSettle();
      final draft = opened.single! as SendDraft;
      expect(draft.recipientAddress, s6RecipientChecksum);
      expect(draft.amount, '0.5');
      expect(draft.assetId, s5NativeAssetId);
    });
  });

  group('send · step 3', () {
    testWidgets('the confirm step shows dots 3 of 3 and no folio', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(
          draft: const SendDraft(
            walletId: s5WalletId,
            assetId: s5NativeAssetId,
            symbol: 'BNB',
            recipientAddress: s6RecipientChecksum,
            amount: '0.01',
          ),
          clock: () => DateTime.utc(2026, 9, 9, 13, 35, 45),
        ),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );
      final dots = tester.widget<LoopStepDots>(find.byType(LoopStepDots));
      expect(dots.step, 3);
      expect(find.byType(LoopFolioPrimary), findsNothing);
      expect(_key('send-confirm-sign'), findsOneWidget);
    });
  });

  group('swap', () {
    Future<FakeSwapQuoteGateway> pumpSwap(WidgetTester tester) async {
      final quotes = FakeSwapQuoteGateway();
      await pumpS6Page(
        tester,
        SwapScreen(clock: () => DateTime.utc(2026, 9, 9, 13, 35, 45)),
        wallet: _wallet(<LoopAssetBalanceRow>[
          s5Row(),
          s5Row(assetId: s5WbnbAssetId),
        ]),
        intents: FakeWalletIntentsGateway(),
        quotes: quotes,
      );
      return quotes;
    }

    Future<void> pick(WidgetTester tester, String side, String asset) async {
      await tester.tap(_key('swap-$side-pick'));
      await tester.pumpAndSettle();
      await tester.tap(_key('swap-pick-$asset'));
      await tester.pumpAndSettle();
    }

    testWidgets('typing quotes by itself after the debounce', (tester) async {
      final quotes = await pumpSwap(tester);
      expect(find.byType(LoopFolioPrimary), findsNothing);
      await pick(tester, 'source', s5NativeAssetId);
      await pick(tester, 'destination', s5WbnbAssetId);
      await tester.enterText(_key('swap-source-amount'), '0.005');
      await tester.pump(const Duration(milliseconds: 200));
      expect(quotes.quoteCalls, 0);
      await tester.pump(swapQuoteDebounce);
      await tester.pumpAndSettle();
      expect(quotes.quoteCalls, 1);
      expect(_key('swap-quote-facts'), findsOneWidget);
      // There is no 获取报价 to press.
      expect(find.text('获取报价'), findsNothing);
    });

    testWidgets('互换 turns the pair around and quotes again', (tester) async {
      final quotes = await pumpSwap(tester);
      await pick(tester, 'source', s5NativeAssetId);
      await pick(tester, 'destination', s5WbnbAssetId);
      await tester.enterText(_key('swap-source-amount'), '0.005');
      await tester.pump(swapQuoteDebounce);
      await tester.pumpAndSettle();
      await tester.tap(_key('swap-flip'));
      await tester.pump();
      expect(tester.widget<LoopButton>(_key('swap-source-pick')).label, 'WBNB');
      expect(
        tester.widget<LoopButton>(_key('swap-destination-pick')).label,
        'BNB',
      );
      await tester.pump(swapQuoteDebounce);
      await tester.pumpAndSettle();
      expect(quotes.quoteCalls, 2);
    });

    testWidgets('the picker searches and shows each balance', (tester) async {
      await pumpSwap(tester);
      await tester.tap(_key('swap-source-pick'));
      await tester.pumpAndSettle();
      expect(_key('swap-pick-search'), findsOneWidget);
      final row = tester.widget<LoopRecordRow>(
        _key('swap-pick-$s5NativeAssetId'),
      );
      expect(row.trailing, '7');
      expect(row.chevron, isFalse);
      await tester.enterText(_key('swap-pick-search'), 'wrapped');
      await tester.pumpAndSettle();
      expect(_key('swap-pick-$s5NativeAssetId'), findsNothing);
      expect(_key('swap-pick-$s5WbnbAssetId'), findsOneWidget);
    });
  });

  group('scan · return mode', () {
    testWidgets('an address is popped back to the page that asked', (
      tester,
    ) async {
      final scanner = _FakeScanner();
      String? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [loopQrScannerProvider.overrideWithValue(scanner)],
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<String>(
                    MaterialPageRoute<String>(
                      builder: (_) => const ScanScreen(returnsRecipient: true),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      scanner.session.emit(s6RecipientChecksum);
      await tester.pumpAndSettle();
      expect(result, s6RecipientChecksum);
      expect(find.byType(ScanScreen), findsNothing);
    });
  });

  test(
    'showMoneyAssetPicker rows with nothing spendable are not spendable',
    () {
      expect(moneyRowHasSpendable(s5Row()), isTrue);
      expect(moneyRowHasSpendable(_zeroWbnb()), isFalse);
      expect(
        moneyRowHasSpendable(
          s5Row(balance: const LoopBalanceUnavailable('BSC_RPC_UNREACHABLE')),
        ),
        isFalse,
      );
    },
  );
}

final class _FakeSession implements LoopQrCameraSession {
  final ValueNotifier<LoopQrCameraState> _state =
      ValueNotifier<LoopQrCameraState>(
        const LoopQrCameraState(
          status: LoopQrCameraStatus.running,
          torch: LoopQrTorch.off,
        ),
      );
  final StreamController<String> _codes = StreamController<String>.broadcast(
    sync: true,
  );

  void emit(String code) => _codes.add(code);

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  ValueListenable<LoopQrCameraState> get state => _state;

  @override
  Stream<String> get codes => _codes.stream;

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: LoopColors.ink);

  @override
  Future<void> toggleTorch() async {}

  @override
  Future<void> retry() async {}

  @override
  Future<void> dispose() async {}
}

final class _FakeScanner implements LoopQrScanner {
  final _FakeSession session = _FakeSession();

  @override
  bool get available => true;

  @override
  LoopQrCameraSession openCamera() => session;

  @override
  Future<LoopQrImageScan> scanImage() async => const LoopQrImageCancelled();
}
