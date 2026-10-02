import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_mining_hooks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_page_harness.dart';

void main() {
  for (final width in <double>[360, 390]) {
    testWidgets(
      'wallet $width keeps actions together and assets ahead of mining',
      (tester) async {
        final routes = <String>[];
        await pumpS5Page(
          tester,
          WalletScreen(onNavigate: routes.add),
          wallet: FakeWalletReadGateway(),
          size: Size(width, 844),
        );
        final actionKeys = <String>[
          'wallet-pay-entry',
          'wallet-swap-entry',
          'wallet-send-entry',
          'wallet-receive-entry',
          'wallet-bridge-entry',
        ];
        final top = tester
            .getTopLeft(find.byKey(ValueKey(actionKeys.first)))
            .dy;
        for (final key in actionKeys) {
          final finder = find.byKey(ValueKey(key));
          expect(tester.getTopLeft(finder).dy, top);
          expect(tester.getSize(finder).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
        }
        expect(
          tester
              .widget<LoopFolioPrimary>(
                find.byKey(const ValueKey('wallet-folio')),
              )
              .ring,
          isFalse,
        );
        expect(tester.getTopLeft(find.text('WALLET ASSETS')).dy, lessThan(520));
        await tester.tap(find.byKey(const ValueKey('wallet-receive-entry')));
        expect(routes.single, contains('/wallet/receive'));
        await scrollToS5Section(tester, find.byType(WalletHoldingsPowerHint));
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('wallet-snapshot-footer')))
              .dy,
          lessThan(tester.getTopLeft(find.byType(WalletHoldingsPowerHint)).dy),
        );
      },
    );
  }
}
