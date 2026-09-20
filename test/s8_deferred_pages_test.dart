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

    // The prototype keeps the viewfinder's room with the reason in it, rather
    // than dropping the page to two lines of copy (visual audit §A.14). It is
    // a placeholder, not a preview: no camera, no field, no action.
    expect(
      find.byKey(const ValueKey<String>('pay-unavailable')),
      findsOneWidget,
    );
    expect(find.text('扫码支付'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.textContaining('还没有开放'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(LoopButton), findsNothing);
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

  testWidgets('bridge-status keeps its skeleton and invents no step', (
    tester,
  ) async {
    await pumpS8Page(tester, const BridgeStatusScreen());

    // The page keeps its skeleton — primary, 步骤 heading, reason — because
    // the shape is what says which page this is (visual audit §A.13, item 4).
    // What it must not do is put a state on a step.
    expect(
      find.byKey(const ValueKey<String>('bridge-status-page-block')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('bridge-status-folio')),
      findsOneWidget,
    );
    expect(find.text('步骤'), findsOneWidget);
    // No step is presented in any state: nothing is transferring, so 等待 was
    // a run this page invented, and 完成 / 进行中 never existed.
    for (var index = 1; index <= 3; index += 1) {
      expect(
        find.byKey(ValueKey<String>('bridge-status-step-$index')),
        findsNothing,
        reason: 'step $index',
      );
    }
    for (final state in <String>['等待', '完成', '进行中']) {
      expect(find.text(state), findsNothing, reason: state);
    }
    // 读不到 would say LOOP tried; nothing was tried.
    expect(find.textContaining('读不到跨链进度'), findsNothing);
    expect(find.text('跨链进度尚未开放'), findsOneWidget);
  });

  testWidgets('bridge-status keeps the one step that leads anywhere', (
    tester,
  ) async {
    var opened = 0;
    await pumpS8Page(
      tester,
      BridgeStatusScreen(onOpenWallet: () => opened += 1),
    );

    final back = find.byKey(
      const ValueKey<String>('bridge-status-back-to-wallet'),
    );
    expect(back, findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(opened, 1);
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
      // Neither action exists as a control: a dead 签名请求 painted as the
      // page's primary action answered the tap with nothing at all.
      expect(find.byKey(const ValueKey<String>('dapp-connect')), findsNothing);
      expect(find.byKey(const ValueKey<String>('dapp-sign')), findsNothing);
      expect(find.text('签名请求'), findsNothing);
      // Nothing was typed, so nothing was looked up and the reputation group
      // does not exist yet: a second empty group saying so was one more
      // placeholder on a page the audit already found full of them.
      expect(find.text('域名信誉'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('dapp-reputation-unavailable')),
        findsNothing,
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
      expect(find.byKey(const ValueKey<String>('dapp-connect')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('dapp-execution-unavailable')),
        findsOneWidget,
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

      // The sentence is behind the prototype's own disclosure now; it is
      // still exactly one tap away and still says the same thing.
      final summary = find.byKey(
        const ValueKey<String>('dapp-scope-disclosure'),
      );
      await scrollToS8Section(tester, summary);
      await tester.tap(
        find.descendant(
          of: summary,
          matching: find.byKey(
            const ValueKey<String>('loop-disclosure-summary'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final notice = find.byKey(const ValueKey<String>('dapp-no-fetch-notice'));
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
