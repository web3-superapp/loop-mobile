import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/s5_page_harness.dart';

/// The wallet's four money actions may not promise a signature the
/// destination cannot give — and may not disappear because it cannot.
///
/// They used to be list rows reading 「在本机签名并广播」 while the server had
/// the write gate closed. Naming the gate fixed the sentence and left a new
/// problem behind: four grey rows wearing a 不可用 badge where the prototype
/// has a Lime `Pay` pill, a 兑换 button and a three-up grid (visual audit
/// 2026-09-20 item 3). The shape is fixed now; the gate decides whether the
/// control runs or answers with the server's own sentence.
void main() {
  group('wallet · funds actions', () {
    testWidgets('a closed write gate keeps the shape and states the reason', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        // The harness default: both write gates closed, as the walked build
        // had them.
        meta: s5MetaSnapshot(),
      );

      final send = find.byKey(const ValueKey<String>('wallet-send-entry'));
      await scrollToS5Section(tester, send);

      // The control is still on the page, and it is still a control.
      expect(send, findsOneWidget);
      expect(find.text('发送'), findsOneWidget);
      expect(find.text('Pay'), findsOneWidget);
      expect(find.text('兑换'), findsOneWidget);
      expect(find.text('跨链'), findsOneWidget);
      // The promise the page cannot keep is gone, and so is the row that
      // carried it.
      expect(find.textContaining('在本机签名并广播'), findsNothing);
      expect(find.textContaining('统一签名出口确认'), findsNothing);
      expect(find.text('资金动作'), findsNothing);

      // Disabled semantics, not a dead rectangle.
      final semantics = tester.getSemantics(send);
      expect(
        semantics.getSemanticsData().flagsCollection.isEnabled,
        Tristate.isFalse,
      );

      // A tap answers with the server's sentence rather than in silence.
      await tester.tap(send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('链上操作'), findsWidgets);
    });

    testWidgets('an open write gate runs the action', (tester) async {
      final opened = <String>[];
      await pumpS5Page(
        tester,
        WalletScreen(onNavigate: opened.add),
        wallet: FakeWalletReadGateway(),
        meta: s5MetaSnapshot(
          sendApprovals: LoopV2CapabilityAvailability.available,
          privySwap: LoopV2CapabilityAvailability.available,
          swapEvidencePending: false,
        ),
      );

      final send = find.byKey(const ValueKey<String>('wallet-send-entry'));
      await scrollToS5Section(tester, send);
      expect(
        tester.getSemantics(send).getSemanticsData().flagsCollection.isEnabled,
        Tristate.isTrue,
      );

      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(opened, <String>['/wallet/send']);
    });
  });
}
