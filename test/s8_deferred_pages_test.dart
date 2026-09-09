import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/deferred_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s8_harness.dart';

/// `pay`, `bridge`, `bridge-status`, `dapp` (D21).
///
/// Every one of these is an entry point with the server's own deferred reason.
/// `smart-money` and `community-ai` were made unavailable in earlier steps and
/// are re-checked by their own market and community suites.
void main() {
  testWidgets('pay is an entry point with the server reason and no camera', (
    tester,
  ) async {
    await pumpS8Page(tester, const PayScreen());

    expect(
      find.byKey(const ValueKey<String>('pay-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Pay 尚未开放'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(LoopButton), findsNothing);
    expect(find.textContaining('Coming soon'), findsNothing);
  });

  testWidgets('bridge offers no amount, no route and no fee', (tester) async {
    await pumpS8Page(tester, const BridgeScreen());

    expect(
      find.byKey(const ValueKey<String>('bridge-unavailable')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('USDC'), findsNothing);
    expect(find.textContaining('998.4'), findsNothing);
    expect(find.textContaining('约 2 分钟'), findsNothing);
  });

  testWidgets('bridge-status keeps all three steps pending with no source', (
    tester,
  ) async {
    await pumpS8Page(tester, const BridgeStatusScreen());

    for (var index = 1; index <= 3; index += 1) {
      expect(
        find.byKey(ValueKey<String>('bridge-status-step-$index')),
        findsOneWidget,
        reason: 'step $index',
      );
    }
    expect(find.text('等待'), findsNWidgets(3));
    expect(find.text('完成'), findsNothing);
    expect(find.text('进行中'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('bridge-status-unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('bridge-status-no-source')),
      findsOneWidget,
    );
  });

  group('dapp', () {
    testWidgets('an empty field reviews nothing and connects nothing', (
      tester,
    ) async {
      await pumpS8Page(tester, const DappReviewScreen());

      expect(
        find.byKey(const ValueKey<String>('dapp-review-empty')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('dapp-connect')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<LoopButton>(find.byKey(const ValueKey<String>('dapp-sign')))
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey<String>('dapp-reputation-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dapp-execution-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('a bare host is normalised and shown as read-only', (
      tester,
    ) async {
      await pumpS8Page(tester, const DappReviewScreen());

      await tester.enterText(
        find.byKey(const ValueKey<String>('dapp-address-field')),
        'app.example.org/swap',
      );
      await tester.pumpAndSettle();

      final canonical = find.byKey(
        const ValueKey<String>('dapp-review-canonical'),
      );
      await scrollToS8Section(tester, canonical);
      expect(
        tester.widget<LoopRecordRow>(canonical).subtitle,
        'https://app.example.org/swap',
      );
      expect(find.text('app.example.org'), findsWidgets);
      // Nothing here can be executed, even for a perfectly normal address.
      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('dapp-connect')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('a non-HTTPS address is blocked with its reason', (
      tester,
    ) async {
      await pumpS8Page(tester, const DappReviewScreen());

      await tester.enterText(
        find.byKey(const ValueKey<String>('dapp-address-field')),
        'http://app.example.org',
      );
      await tester.pumpAndSettle();

      expect(find.text('这个网址不能使用'), findsOneWidget);
      final finding = find.byKey(
        const ValueKey<String>('dapp-finding-notHttps'),
      );
      await scrollToS8Section(tester, finding);
      expect(finding, findsOneWidget);
      final canonical = find.byKey(
        const ValueKey<String>('dapp-review-canonical'),
      );
      expect(tester.widget<LoopRecordRow>(canonical).subtitle, '无法规范化，已阻止');
    });

    testWidgets('an IDN homograph is blocked and its Latin reading named', (
      tester,
    ) async {
      await pumpS8Page(tester, const DappReviewScreen());

      await tester.enterText(
        find.byKey(const ValueKey<String>('dapp-address-field')),
        'https://аpple.com',
      );
      await tester.pumpAndSettle();

      final notice = find.byKey(
        const ValueKey<String>('dapp-confusable-notice'),
      );
      await scrollToS8Section(tester, notice);
      expect(notice, findsOneWidget);
      expect(find.textContaining('看起来像 apple.com'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('dapp-finding-confusableCharacters')),
        findsOneWidget,
      );
    });

    testWidgets('the page states that it never opens the address', (
      tester,
    ) async {
      await pumpS8Page(tester, const DappReviewScreen());

      final notice = find.byKey(const ValueKey<String>('dapp-no-fetch-notice'));
      await scrollToS8Section(tester, notice);
      expect(notice, findsOneWidget);
      expect(find.textContaining('不会跟随任何跳转'), findsOneWidget);
      // The prototype's connected DApp card, allowance count and reputation
      // sentence all had no source and are absent.
      expect(find.textContaining('已连接'), findsNothing);
      expect(find.textContaining('3 个开放授权'), findsNothing);
      expect(find.textContaining('Blockaid'), findsNothing);
    });
  });
}
