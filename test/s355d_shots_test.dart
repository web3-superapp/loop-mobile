// S355d · decision 0281: the wallet / chain / security pages in English at
// 360 × 800, to read truncation and overflow after the ARB migration. Runs
// only with `--dart-define=LOOP_SHOTS=true`; the PNGs go to `LOOP_SHOTS_DIR`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/approval_screens.dart';
import 'package:loop_mobile/features/wallet/deferred_screens.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/tx_result_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';

import 'support/loop_shots.dart';
import 'support/me_page_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';
import 'support/s8_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment('LOOP_SHOTS_DIR');
const Size _size = Size(360, 800);

const _guardRequest = ApprovalGuardRequest(
  walletId: s5WalletId,
  assetId: s5UsdtAssetId,
  symbol: 'USDT',
  spenderAddress: s6SpenderChecksum,
  suggestedAmount: '5',
);

DateTime _fresh() => DateTime.utc(2026, 9, 9, 13, 35, 45);

Future<void> _shot(WidgetTester tester, String name) async {
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
  testWidgets('me / wallet', skip: !_shots, (tester) async {
    await pumpMePage(tester, size: _size);
    await _shot(tester, 'wallet-me');
  });

  testWidgets('wallet asset', skip: !_shots, (tester) async {
    await pumpS5Page(
      tester,
      const WalletAssetScreen(assetId: s5NativeAssetId),
      wallet: FakeWalletReadGateway(),
      chain: FakeChainGateway(),
      size: _size,
    );
    await _shot(tester, 'wallet-asset');
  });

  testWidgets('receive', skip: !_shots, (tester) async {
    await pumpS5Page(
      tester,
      const ReceiveScreen(walletId: s5WalletId),
      wallet: FakeWalletReadGateway(),
      size: _size,
    );
    await _shot(tester, 'wallet-receive');
  });

  testWidgets('wallet manager', skip: !_shots, (tester) async {
    await pumpS5Page(
      tester,
      const WalletManagerScreen(),
      wallet: FakeWalletReadGateway(),
      size: _size,
    );
    await _shot(tester, 'wallet-manager');
  });

  testWidgets('tx history', skip: !_shots, (tester) async {
    await pumpS5Page(
      tester,
      const TransactionHistoryScreen(walletId: s5WalletId),
      wallet: FakeWalletReadGateway(),
      size: _size,
    );
    await _shot(tester, 'wallet-tx-history');
  });

  testWidgets('networks', skip: !_shots, (tester) async {
    await pumpS5Page(
      tester,
      const NetworksScreen(),
      chain: FakeChainGateway(),
      size: _size,
    );
    await _shot(tester, 'wallet-networks');
  });

  testWidgets('approvals', skip: !_shots, (tester) async {
    await pumpS6Page(
      tester,
      const ApprovalsScreen(),
      wallet: FakeWalletReadGateway(),
      intents: FakeWalletIntentsGateway(),
      approvals: FakeApprovalsGateway(),
      size: _size,
    );
    await _shot(tester, 'wallet-approvals');
  });

  testWidgets('approval guard', skip: !_shots, (tester) async {
    await pumpS6Page(
      tester,
      ApprovalGuardScreen(request: _guardRequest, clock: _fresh),
      wallet: FakeWalletReadGateway(),
      intents: FakeWalletIntentsGateway(prepared: s6ApprovalIntent()),
      size: _size,
    );
    await _shot(tester, 'wallet-approval-guard');
  });

  testWidgets('swap', skip: !_shots, (tester) async {
    await pumpS6Page(
      tester,
      SwapScreen(clock: _fresh),
      wallet: FakeWalletReadGateway(),
      quotes: FakeSwapQuoteGateway(),
      size: _size,
    );
    await _shot(tester, 'wallet-swap');
  });

  testWidgets('swap route', skip: !_shots, (tester) async {
    await pumpS6Page(
      tester,
      SwapRouteScreen(quote: s6QuoteView()),
      wallet: FakeWalletReadGateway(),
      size: _size,
    );
    await _shot(tester, 'wallet-swap-route');
  });

  testWidgets('tx result', skip: !_shots, (tester) async {
    await pumpS6Page(
      tester,
      const TransactionResultScreen(intentId: s6IntentId),
      wallet: FakeWalletReadGateway(),
      intents: FakeWalletIntentsGateway(reported: s6Intent(state: 'submitted')),
      size: _size,
      settle: false,
    );
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, 'wallet-tx-result');
  });

  testWidgets('bridge', skip: !_shots, (tester) async {
    await pumpS8Page(tester, BridgeScreen(onOpenStatus: () {}), size: _size);
    await _shot(tester, 'wallet-bridge');
  });

  testWidgets('dapp review', skip: !_shots, (tester) async {
    await pumpS8Page(tester, const DappReviewScreen(), size: _size);
    await _shot(tester, 'wallet-dapp-review');
  });

  testWidgets('pay', skip: !_shots, (tester) async {
    await pumpS8Page(tester, const PayScreen(), size: _size);
    await _shot(tester, 'wallet-pay');
  });
}
