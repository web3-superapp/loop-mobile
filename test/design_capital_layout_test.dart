import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_mining_hooks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_page_harness.dart';

void main() {
  for (final width in <double>[320, 390]) {
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
        final folio = tester.widget<LoopFolioPrimary>(
          find.byKey(const ValueKey('wallet-folio')),
        );
        expect(folio.kicker, '资产净值（USD）');
        expect(folio.headingTone, LoopFolioHeadingTone.neutral);
        final amount = tester.widget<Text>(find.text(folio.heading));
        expect(amount.style?.fontSize, 36);
        expect(amount.style?.color, LoopColors.chalk);
        expect(find.textContaining('净值不是可用余额'), findsOneWidget);
        expect(tester.getTopLeft(find.text('我的资产')).dy, lessThan(520));
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

  testWidgets('account tools remain reachable when balances fail', (
    tester,
  ) async {
    final routes = <String>[];
    await pumpS5Page(
      tester,
      WalletScreen(onNavigate: routes.add),
      size: const Size(320, 844),
      wallet: FakeWalletReadGateway(
        balances: S5Answer<LoopWalletBalances>(
          failure: LoopChainFailureKind.offline,
        ),
      ),
    );
    for (final (key, route) in <(String, String)>[
      ('wallet-management-entry', '/wallet/manage'),
      ('wallet-settings-entry', '/profile/settings'),
      ('wallet-mining-entry', '/mining'),
      ('wallet-referral-entry', '/profile/referral'),
      ('wallet-security-entry', '/profile/security'),
      ('wallet-approvals-entry', '/wallet/approvals'),
      ('wallet-networks-entry', '/wallet/networks'),
      ('wallet-dapp-entry', '/wallet/dapp'),
    ]) {
      final entry = find.byKey(ValueKey<String>(key));
      await scrollToS5Section(tester, entry);
      expect(tester.getSize(entry).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(entry).width, greaterThanOrEqualTo(44));
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(routes.last, route);
    }
    expect(routes, hasLength(8));
    expect(tester.takeException(), isNull);
  });
}
