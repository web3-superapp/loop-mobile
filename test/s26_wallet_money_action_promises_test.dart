import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/s5_page_harness.dart';

/// The wallet's 「资金动作」 rows may not promise a signature the destination
/// cannot give.
///
/// Three of the four rows read 「在本机签名并广播」 and 「通过 Privy 报价并在
/// 统一签名出口确认」 while the server had the write gate closed, so the tap
/// landed on 「链上操作当前已关闭，现在只能查看。」. The capability decides the
/// row's own words now.
void main() {
  group('wallet · funds actions', () {
    testWidgets('a closed write gate replaces the promise', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        // The harness default: both write gates closed, as the walked build
        // had them.
        meta: s5MetaSnapshot(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-send-entry')),
      );

      expect(find.textContaining('在本机签名并广播'), findsNothing);
      expect(find.textContaining('统一签名出口确认'), findsNothing);
      expect(find.text('不可用'), findsWidgets);
    });

    testWidgets('an open write gate keeps the promise', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        meta: s5MetaSnapshot(
          sendApprovals: LoopV2CapabilityAvailability.available,
          privySwap: LoopV2CapabilityAvailability.available,
          swapEvidencePending: false,
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-send-entry')),
      );

      expect(find.textContaining('在本机签名并广播'), findsOneWidget);
      expect(find.textContaining('统一签名出口确认'), findsOneWidget);
    });
  });
}
