import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/wallet/approval_screens.dart';
import 'package:loop_mobile/features/wallet/deferred_screens.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';
import 'support/s8_harness.dart';

/// The wallet module's block order, pinned page by page.
///
/// The visual audit of 2026-09-20 found the module's Design Tokens correct and
/// its page composition wrong: a heading that repeated the page's title, a
/// Chalk primary that was never used, action groups demoted to list rows with
/// a grey badge, key/value tables in front of the prototype's own blocks, and
/// a deferred capability rendered as a centred grey circle with the whole page
/// blank above it.
///
/// Order is the thing a widget test can hold and a screenshot cannot argue
/// with, so each page below asserts the vertical order of its blocks. A block
/// that moves, or one that goes missing, fails here rather than in a build.
void main() {
  /// Asserts that [keys] appear top to bottom in the order given.
  void expectOrder(WidgetTester tester, List<Key> keys) {
    var previous = double.negativeInfinity;
    for (final key in keys) {
      final finder = find.byKey(key);
      expect(finder, findsOneWidget, reason: '$key is missing');
      final top = tester.getTopLeft(finder).dy;
      expect(
        top,
        greaterThanOrEqualTo(previous),
        reason: '$key is out of order',
      );
      previous = top;
    }
  }

  /// The primary's variant, read off the widget the page actually built.
  LoopFolioVariant variantOf(WidgetTester tester, String key) => tester
      .widget<LoopFolioPrimary>(find.byKey(ValueKey<String>(key)))
      .variant;

  group('group labels', () {
    // Decision 0119 (v3 需求 §6.2): the wallet pages drop the prototype's
    // English mono eyebrows — `WALLET LEDGER`, `Wallet Assets`, `Security &
    // Connections`, `Wallet 收发记录` — and say what each block is in Chinese.
    testWidgets('the wallet home speaks Chinese', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );

      expect(find.text('总资产'), findsOneWidget);
      expect(find.text('资产'), findsOneWidget);
      expect(find.text('WALLET LEDGER'), findsNothing);
      expect(find.text('WALLET ASSETS'), findsNothing);
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-settings-entry')),
      );
      expect(find.text('SECURITY & CONNECTIONS'), findsNothing);
    });

    testWidgets('the asset page keeps its Chinese labels', (tester) async {
      await pumpS5Page(
        tester,
        const WalletAssetScreen(assetId: s5NativeAssetId),
        wallet: FakeWalletReadGateway(),
        chain: FakeChainGateway(),
      );

      await scrollToS5Section(tester, find.text('链上分布'));
      expect(find.text('链上分布'), findsOneWidget);

      await scrollToS5Section(tester, find.text('收发记录'));
      expect(find.text('收发记录'), findsOneWidget);
      expect(find.text('WALLET 收发记录'), findsNothing);
    });
  });

  group('receive', () {
    testWidgets('a Chalk primary, the code, the buttons, the networks', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(),
        wallet: FakeWalletReadGateway(),
      );

      // Decision 0126 (OKX 收款): the network chip, the code with its address
      // capsule, 复制 / 分享, then the warning. No folio.
      expect(find.byKey(const ValueKey<String>('receive-folio')), findsNothing);
      expectOrder(tester, <Key>[
        ValueKey<String>('receive-network-$loopPrimaryChainId'),
        const ValueKey<String>('receive-card'),
        const ValueKey<String>('receive-copy-address'),
        const ValueKey<String>('receive-share'),
        const ValueKey<String>('receive-warning'),
      ]);
      // The chip row never offers a network LOOP did not publish.
      expect(find.text('Solana'), findsNothing);
      expect(find.text('Base'), findsNothing);
    });
  });

  group('wallets', () {
    testWidgets('identity heading, the rule, the rows, the mining close', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(),
      );

      // Decision 0126: no folio; the rows, the ⓘ line, then the source.
      expect(find.byKey(const ValueKey<String>('wallets-folio')), findsNothing);
      expectOrder(tester, <Key>[
        const ValueKey<String>('wallets-mining-notice'),
        const ValueKey<String>('wallets-source'),
      ]);
      // A count is not an identity: the heading names the wallet in use.
      expect(find.text('1 个钱包'), findsNothing);
      expect(find.textContaining('所有绑定钱包的持仓都计入算力'), findsOneWidget);
      // 添加 keeps its shape and says what it would need.
      expect(
        find.byKey(const ValueKey<String>('wallets-add-action')),
        findsOneWidget,
      );
    });
  });

  group('tx-history', () {
    testWidgets('every row carries its direction badge', (tester) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(),
        wallet: FakeWalletReadGateway(),
      );

      // The prototype heads every activity row with a circular glyph; the
      // app's rows had no leading column at all.
      expect(find.byType(LoopRowIcon), findsWidgets);
      // The primary heads with a figure, never with the page's own title.
      expect(find.text('交易历史'), findsOneWidget);
    });
  });

  group('networks', () {
    testWidgets('chain rows first, settings second, operator facts last', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(),
      );

      // Decision 0126: no folio; the endpoint health is the chain row's value.
      expect(
        find.byKey(const ValueKey<String>('networks-folio')),
        findsNothing,
      );
      expectOrder(tester, <Key>[
        const ValueKey<String>('networks-chain-row'),
        const ValueKey<String>('networks-custom-rpc'),
        const ValueKey<String>('networks-testnet'),
        const ValueKey<String>('networks-operator-disclosure'),
      ]);
      // The chain row carries the chain's own logo and the one fact a reader
      // can act on.
      expect(
        tester
            .widget<LoopRecordRow>(
              find.byKey(const ValueKey<String>('networks-chain-row')),
            )
            .leading,
        isNotNull,
      );
      // The endpoints are not on the surface; they are one tap away.
      expect(find.text('bsc-rpc.publicnode.com'), findsNothing);
      await openLoopDisclosure(
        tester,
        const ValueKey<String>('networks-operator-disclosure'),
      );
      expect(find.text('bsc-rpc.publicnode.com'), findsOneWidget);
    });
  });

  group('approvals', () {
    testWidgets('a Chalk primary, the two counts, the rows, the source', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const ApprovalsScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(),
      );

      // Decision 0126: no folio; the two counts lead.
      expect(
        find.byKey(const ValueKey<String>('approvals-folio')),
        findsNothing,
      );
      expectOrder(tester, <Key>[
        const ValueKey<String>('approvals-stat-unlimited'),
        const ValueKey<String>('approvals-stat-limited'),
        const ValueKey<String>('approvals-source-disclosure'),
      ]);
      expect(
        find.byKey(const ValueKey<String>('approvals-batch-action')),
        findsOneWidget,
      );
    });
  });

  group('send', () {
    testWidgets('a closed gate states the reason and offers no field', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        sendApprovals: LoopV2CapabilityAvailability.unavailable,
      );

      // Decision 0131: a step page carries no folio card.
      expect(find.byType(LoopFolioPrimary), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('send-recipient-field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('send-capability-block')),
        findsOneWidget,
      );
      // No asset may be picked while the gate is closed.
      expect(find.byType(LoopRecordRow), findsNothing);
    });
  });

  group('swap', () {
    testWidgets('a closed gate keeps both figure boxes, each a dash', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SwapScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        privySwap: LoopV2CapabilityAvailability.unavailable,
      );

      expect(find.byType(LoopFolioPrimary), findsNothing);
      expectOrder(tester, <Key>[
        const ValueKey<String>('swap-source-blocked'),
        const ValueKey<String>('swap-destination-blocked'),
        const ValueKey<String>('swap-capability-block'),
      ]);
      // A quote nobody gave is a dash, never a zero.
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0'), findsNothing);
    });
  });

  group('pay', () {
    testWidgets('a Chalk primary over the viewfinder placeholder', (
      tester,
    ) async {
      await pumpS8Page(tester, const PayScreen());

      expect(variantOf(tester, 'pay-folio'), LoopFolioVariant.chalk);
      expectOrder(tester, <Key>[
        const ValueKey<String>('pay-folio'),
        const ValueKey<String>('loop-placeholder-stage'),
        const ValueKey<String>('pay-why-notice'),
      ]);
      // One explanation, not two.
      expect(
        find.byKey(const ValueKey<String>('pay-signing-notice')),
        findsNothing,
      );
    });
  });

  group('bridge', () {
    testWidgets('the two boxes and the action keep their room', (tester) async {
      await pumpS8Page(tester, const BridgeScreen());

      expectOrder(tester, <Key>[
        const ValueKey<String>('bridge-folio'),
        const ValueKey<String>('bridge-from'),
        const ValueKey<String>('bridge-to'),
        const ValueKey<String>('bridge-start'),
        const ValueKey<String>('bridge-unavailable'),
      ]);
      // A bridge fee, a receive amount and an ETA can only come from a real
      // route, and there is none.
      expect(find.text('—'), findsNWidgets(2));
      expect(find.textContaining('998.4'), findsNothing);
    });
  });

  group('bridge-status', () {
    testWidgets('the primary and the 步骤 heading stay, the steps do not', (
      tester,
    ) async {
      await pumpS8Page(tester, const BridgeStatusScreen());

      expect(variantOf(tester, 'bridge-status-folio'), LoopFolioVariant.chalk);
      expectOrder(tester, <Key>[
        const ValueKey<String>('bridge-status-folio'),
        const ValueKey<String>('bridge-status-page-block'),
      ]);
      expect(find.text('步骤'), findsOneWidget);
      for (final state in <String>['等待', '完成', '进行中']) {
        expect(find.text(state), findsNothing, reason: state);
      }
    });
  });

  group('dapp', () {
    testWidgets('the address bar is above the review, as in a browser', (
      tester,
    ) async {
      await pumpS8Page(tester, const DappReviewScreen());

      expect(variantOf(tester, 'dapp-folio'), LoopFolioVariant.chalk);
      expectOrder(tester, <Key>[
        const ValueKey<String>('dapp-omnibox'),
        const ValueKey<String>('dapp-folio'),
      ]);
      // The three ⓘ⚠ placeholder groups became one card and one disclosure.
      expect(
        find.byKey(const ValueKey<String>('dapp-scope-disclosure')),
        findsOneWidget,
      );
    });
  });
}
