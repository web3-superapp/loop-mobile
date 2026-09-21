import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/profile/about/about_models.dart';
import 'package:loop_mobile/features/profile/about/about_screen.dart';
import 'package:loop_mobile/features/profile/settings/settings_models.dart';
import 'package:loop_mobile/features/profile/settings/settings_screen.dart';
import 'package:loop_mobile/features/profile/support/support_models.dart';
import 'package:loop_mobile/features/profile/support/support_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s8_harness.dart';

/// `settings`, `about`, `support` (D20).
void main() {
  group('settings', () {
    testWidgets('loading', (tester) async {
      await pumpS8Page(
        tester,
        GeneralSettingsScreen(onNavigate: (_) {}),
        settings: FakeAccountSettingsGateway(
          settings: S8Answer<LoopAccountSettings>(pending: true),
        ),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-state-loading')),
        findsOneWidget,
      );
    });

    for (final (kind, key) in <(LoopChainFailureKind, String)>[
      (LoopChainFailureKind.unexpected, 'settings-state-error'),
      (LoopChainFailureKind.offline, 'settings-state-offline'),
      (LoopChainFailureKind.unavailable, 'settings-state-unavailable'),
      (LoopChainFailureKind.permissionDenied, 'settings-state-permission'),
    ]) {
      testWidgets(kind.name, (tester) async {
        await pumpS8Page(
          tester,
          GeneralSettingsScreen(onNavigate: (_) {}),
          settings: FakeAccountSettingsGateway(
            settings: S8Answer<LoopAccountSettings>(failure: kind),
          ),
        );
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      });
    }

    testWidgets('capability block', (tester) async {
      await pumpS8Page(
        tester,
        GeneralSettingsScreen(onNavigate: (_) {}),
        settings: FakeAccountSettingsGateway(
          mode: LoopChainGatewayMode.unavailable,
        ),
        meta: s8MetaSnapshot(
          settings: LoopV2CapabilityAvailability.unavailable,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('settings-capability-block')),
        findsOneWidget,
      );
    });

    testWidgets('the two fixed account values are read-only', (tester) async {
      await pumpS8Page(
        tester,
        GeneralSettingsScreen(onNavigate: (_) {}),
        settings: FakeAccountSettingsGateway(),
      );

      final language = find.byKey(const ValueKey<String>('settings-language'));
      final currency = find.byKey(
        const ValueKey<String>('settings-display-currency'),
      );
      expect(tester.widget<LoopRecordRow>(language).onTap, isNull);
      expect(tester.widget<LoopRecordRow>(currency).onTap, isNull);
      expect(find.text('简体中文'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      // The CAS version and whether a row exists are write-path mechanics,
      // not facts about the account.
      expect(find.text('当前使用默认设置'), findsOneWidget);
      expect(find.textContaining('版本 0'), findsNothing);
      expect(find.textContaining('尚未写入过'), findsNothing);
    });

    testWidgets('the privacy entry names rows the privacy page has', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        GeneralSettingsScreen(onNavigate: (_) {}),
        settings: FakeAccountSettingsGateway(),
      );

      final row = find.byKey(const ValueKey<String>('settings-open-privacy'));
      await scrollToS8Section(tester, row);
      // Copytrade is retired and the V2 privacy contract carries no facet for
      // it; the page also has no row called 可被搜索.
      expect(find.textContaining('跟单'), findsNothing);
      expect(find.textContaining('可被搜索'), findsNothing);
      // The prototype's account rows are a title, a value and a chevron. This
      // page reads no privacy state, so the row carries no second line rather
      // than a description of the destination (audit 2026-09-21 §D+ #11).
      expect(tester.widget<LoopRecordRow>(row).subtitle, isNull);
      expect(tester.widget<LoopRecordRow>(row).onTap, isNotNull);
    });

    testWidgets('sign out is offered only when the composition provides it', (
      tester,
    ) async {
      var signedOut = 0;
      await pumpS8Page(
        tester,
        GeneralSettingsScreen(
          onNavigate: (_) {},
          onSignOut: () async => signedOut += 1,
        ),
        settings: FakeAccountSettingsGateway(),
      );

      final button = find.byKey(const ValueKey<String>('settings-sign-out'));
      await scrollToS8Section(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(signedOut, 1);
    });
  });

  group('about', () {
    testWidgets('loading', (tester) async {
      await pumpS8Page(
        tester,
        const AboutScreen(),
        about: FakeAboutGateway(about: S8Answer<LoopAbout>(pending: true)),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('about-state-loading')),
        findsOneWidget,
      );
    });

    for (final (kind, key) in <(LoopChainFailureKind, String)>[
      (LoopChainFailureKind.unexpected, 'about-state-error'),
      (LoopChainFailureKind.offline, 'about-state-offline'),
      (LoopChainFailureKind.unavailable, 'about-state-unavailable'),
      (LoopChainFailureKind.permissionDenied, 'about-state-permission'),
    ]) {
      testWidgets(kind.name, (tester) async {
        await pumpS8Page(
          tester,
          const AboutScreen(),
          about: FakeAboutGateway(about: S8Answer<LoopAbout>(failure: kind)),
        );
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      });
    }

    testWidgets('one dropped first read is not 「操作没有完成」', (tester) async {
      // 关于 greeted its first open with 暂时无法完成 while the manual retry
      // always worked. The dropped socket arrives here as `unexpected`, not
      // `offline`: Dio reports a connection the peer closed mid-response as
      // `unknown`. A first read gets one silent re-attempt either way.
      final gateway = FakeAboutGateway(
        about: S8Answer<LoopAbout>(
          value: s8About(),
          transientFailure: LoopChainFailureKind.unexpected,
        ),
      );
      await pumpS8Page(tester, const AboutScreen(), about: gateway);

      expect(gateway.about.resolves, 2);
      expect(
        find.byKey(const ValueKey<String>('about-state-error')),
        findsNothing,
      );
      expect(find.text('操作没有完成，请稍后再试。'), findsNothing);
      expect(find.text('本应用使用的开源组件'), findsOneWidget);
    });

    testWidgets('the legal rows are a version slot, never a document link', (
      tester,
    ) async {
      await pumpS8Page(tester, const AboutScreen(), about: FakeAboutGateway());

      expect(
        find.byKey(const ValueKey<String>('about-terms-unavailable')),
        findsOneWidget,
      );
      expect(find.text('用户协议'), findsNothing);
      expect(find.text('隐私政策'), findsNothing);
      expect(find.text('风险披露'), findsNothing);
    });

    testWidgets('the register is the client\'s own, never the backend\'s', (
      tester,
    ) async {
      await pumpS8Page(tester, const AboutScreen(), about: FakeAboutGateway());

      // The server publishes the backend's register. It named a repository
      // path as a card title and listed Fastify; neither belongs on a phone.
      expect(
        find.byKey(const ValueKey<String>('about-open-source-Fastify')),
        findsNothing,
      );
      expect(find.text('docs/open-source-attribution.md'), findsNothing);
      expect(find.text('本应用使用的开源组件'), findsOneWidget);

      final entry = find.byKey(const ValueKey<String>('about-open-source-dio'));
      await scrollToS8Section(tester, entry);
      expect(entry, findsOneWidget);
      final row = tester.widget<LoopRecordRow>(entry);
      expect(row.subtitle, '网络请求 · MIT');
      expect(row.trailing, isNull);
    });

    testWidgets('every published rule is listed, none under its key', (
      tester,
    ) async {
      await pumpS8Page(tester, const AboutScreen(), about: FakeAboutGateway());

      // The Chinese names are the table in
      // loop-api/docs/frontend-v2-meta-api.md.
      for (final (module, name) in <(String, String)>[
        ('productPolicy', '产品策略'),
        ('support', '客服工单规则'),
        ('bscWriteCanary', '链上写入灰度规则'),
      ]) {
        final row = find.byKey(ValueKey<String>('about-config-$module'));
        await scrollToS8Section(tester, row);
        expect(row, findsOneWidget, reason: module);
        expect(tester.widget<LoopRecordRow>(row).title, name);
      }
      // A rule this client cannot translate is still in force: the row stays
      // and carries its version, and only the identifier is withheld.
      final unknown = find.byKey(
        const ValueKey<String>('about-config-futureRuleKey'),
      );
      await scrollToS8Section(tester, unknown);
      expect(tester.widget<LoopRecordRow>(unknown).title, '其他规则');
      expect(
        tester.widget<LoopRecordRow>(unknown).subtitle,
        contains('版本 rulesV9'),
      );
      // The identifier itself is never a title or a line of copy. (The
      // published版本 strings are the server's own and are shown verbatim.)
      expect(find.textContaining('futureRuleKey'), findsNothing);
      expect(find.text('productPolicy'), findsNothing);
      expect(find.text('bscWriteCanary'), findsNothing);
      expect(
        find.textContaining('版本 productPolicyV2.2026-09-01'),
        findsOneWidget,
      );
    });
  });

  group('support', () {
    testWidgets('loading', (tester) async {
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: FakeSupportGateway(
          page: S8Answer<LoopSupportTicketPage>(pending: true),
        ),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('support-state-loading')),
        findsOneWidget,
      );
    });

    for (final (kind, key) in <(LoopChainFailureKind, String)>[
      (LoopChainFailureKind.unexpected, 'support-state-error'),
      (LoopChainFailureKind.offline, 'support-state-offline'),
      (LoopChainFailureKind.unavailable, 'support-state-unavailable'),
      (LoopChainFailureKind.permissionDenied, 'support-state-permission'),
    ]) {
      testWidgets(kind.name, (tester) async {
        await pumpS8Page(
          tester,
          SupportScreen(onNavigate: (_) {}),
          support: FakeSupportGateway(
            page: S8Answer<LoopSupportTicketPage>(failure: kind),
          ),
        );
        final state = find.byKey(ValueKey<String>(key));
        await scrollToS8Section(tester, state);
        expect(state, findsOneWidget);
      });
    }

    testWidgets('capability block hides the form entirely', (tester) async {
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: FakeSupportGateway(mode: LoopChainGatewayMode.unavailable),
        meta: s8MetaSnapshot(support: LoopV2CapabilityAvailability.unavailable),
      );
      expect(
        find.byKey(const ValueKey<String>('support-capability-block')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('support-body-field')),
        findsNothing,
      );
    });

    testWidgets('empty', (tester) async {
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: FakeSupportGateway(
          page: S8Answer<LoopSupportTicketPage>(
            value: s8TicketPage(items: const <LoopSupportTicket>[]),
          ),
        ),
      );
      final empty = find.byKey(const ValueKey<String>('support-tickets-empty'));
      await scrollToS8Section(tester, empty);
      expect(empty, findsOneWidget);
    });

    testWidgets('the bundled answer describes where a figure comes from, not '
        'the state of a version', (tester) async {
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: FakeSupportGateway(),
      );

      final answer = find.byKey(
        const ValueKey<String>('support-answer-算力是怎么算的'),
      );
      await scrollToS8Section(tester, answer);
      await tester.tap(answer);
      await tester.pumpAndSettle();

      // Bundled copy is read long after it was written, so it may not assert
      // what the mining pages are showing today.
      expect(find.textContaining('挖矿公式还没有'), findsNothing);
      expect(find.textContaining('暂时不显示算力'), findsNothing);
      expect(find.textContaining('公式批准后'), findsNothing);
      expect(find.textContaining('算力来自最近一次算力快照'), findsOneWidget);
    });

    testWidgets('an empty body cannot be submitted', (tester) async {
      final gateway = FakeSupportGateway();
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: gateway,
      );

      final submit = find.byKey(const ValueKey<String>('support-submit'));
      await scrollToS8Section(tester, submit);
      expect(tester.widget<LoopButton>(submit).onPressed, isNull);
      expect(gateway.created, isEmpty);
    });

    testWidgets('an unsendable body says why, and a newline cannot be typed', (
      tester,
    ) async {
      final gateway = FakeSupportGateway();
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: gateway,
      );

      final field = find.byKey(const ValueKey<String>('support-body-field'));
      await scrollToS8Section(tester, field);
      // A zero-width space is invisible but is a format character the server
      // refuses, so the page names the rule instead of disabling in silence.
      await tester.enterText(field, '权重\u200b问题');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('support-body-problem')),
        findsOneWidget,
      );
      expect(find.textContaining('控制字符或不可见字符'), findsOneWidget);
      final submit = find.byKey(const ValueKey<String>('support-submit'));
      await scrollToS8Section(tester, submit);
      expect(tester.widget<LoopButton>(submit).onPressed, isNull);

      // The formatter keeps a newline out of the field in the first place.
      await tester.enterText(field, '第一行\n第二行');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '第一行第二行');
      expect(
        find.byKey(const ValueKey<String>('support-body-problem')),
        findsNothing,
      );
    });

    testWidgets('a ticket is submitted with the chosen category', (
      tester,
    ) async {
      final gateway = FakeSupportGateway();
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: gateway,
      );

      final field = find.byKey(const ValueKey<String>('support-body-field'));
      await scrollToS8Section(tester, field);
      await tester.enterText(field, '  为什么我的币没有权重  ');
      await tester.pumpAndSettle();
      // The category bar scrolls horizontally; the Mining chip sits past the
      // right edge at 390pt once the labels take the label band (decision
      // 0069).
      final miningChip = find.text('挖矿');
      await tester.scrollUntilVisible(
        miningChip,
        60,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey<String>('support-category-bar')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(miningChip);
      await tester.pumpAndSettle();

      final submit = find.byKey(const ValueKey<String>('support-submit'));
      await scrollToS8Section(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(gateway.created, hasLength(1));
      expect(gateway.created.single.category, LoopSupportCategory.mining);
      // The body is trimmed before it is sent.
      expect(gateway.created.single.body, '为什么我的币没有权重');
    });

    testWidgets('the reply window keeps a space between its two words', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: FakeSupportGateway(),
      );

      // 「工作日24 小时内回复」 ran a Chinese word straight into a Latin digit.
      // The sentence now lives in the page's closing disclosure, which is the
      // prototype's own home for it.
      await tester.tap(
        find.byKey(const ValueKey<String>('support-policy-disclosure')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('工作日 24 小时内回复'), findsOneWidget);
      expect(find.textContaining('工作日24'), findsNothing);
    });

    testWidgets('a refused submit is reported and the list is untouched', (
      tester,
    ) async {
      final gateway = FakeSupportGateway(
        createFailure: LoopChainFailureKind.rateLimited,
      );
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: gateway,
      );

      final field = find.byKey(const ValueKey<String>('support-body-field'));
      await scrollToS8Section(tester, field);
      await tester.enterText(field, '权重问题');
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey<String>('support-submit'));
      await scrollToS8Section(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      final error = find.byKey(const ValueKey<String>('support-command-error'));
      await scrollToS8Section(tester, error);
      expect(error, findsOneWidget);
      expect(find.textContaining('请求过于频繁'), findsOneWidget);
    });

    testWidgets('attachments stay unavailable and the reply is quoted', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: FakeSupportGateway(
          page: S8Answer<LoopSupportTicketPage>(
            value: s8TicketPage(
              items: <LoopSupportTicket>[
                s8Ticket(status: LoopSupportTicketStatus.answered),
              ],
            ),
          ),
        ),
      );

      final attachments = find.byKey(
        const ValueKey<String>('support-attachments-unavailable'),
      );
      await scrollToS8Section(tester, attachments);
      expect(attachments, findsOneWidget);

      final ticket = find.byKey(
        ValueKey<String>('support-ticket-$s8NotificationId'),
      );
      await scrollToS8Section(tester, ticket);
      expect(
        tester.widget<LoopRecordRow>(ticket).subtitle,
        '客服回复：已核对，权重需要资产先完成登记。',
      );
      // The prototype's member count and online state have no source.
      expect(find.textContaining('48,120'), findsNothing);
      expect(find.textContaining('有人在线'), findsNothing);
    });

    testWidgets('a ticket opens the whole exchange in time order', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: FakeSupportGateway(
          page: S8Answer<LoopSupportTicketPage>(
            value: s8TicketPage(
              items: <LoopSupportTicket>[
                s8Ticket(status: LoopSupportTicketStatus.answered),
              ],
            ),
          ),
        ),
      );

      final ticket = find.byKey(
        ValueKey<String>('support-ticket-$s8NotificationId'),
      );
      await scrollToS8Section(tester, ticket);
      // The summary row never truncates the reply into one line any more.
      expect(tester.widget<LoopRecordRow>(ticket).subtitleMaxLines, 2);

      await tester.tap(ticket);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('support-ticket-detail')),
        findsOneWidget,
      );
      // The question as it was typed, and the operator's reply in full.
      expect(
        find.byKey(const ValueKey<String>('support-ticket-detail-body')),
        findsOneWidget,
      );
      expect(find.text('已核对，权重需要资产先完成登记。'), findsOneWidget);
      // Both rounds are listed, oldest first.
      final created = tester.getTopLeft(
        find.byKey(const ValueKey<String>('support-ticket-event-0')),
      );
      final answered = tester.getTopLeft(
        find.byKey(const ValueKey<String>('support-ticket-event-1')),
      );
      expect(created.dy, lessThan(answered.dy));
      expect(find.text('LOOP 客服 · 客服回复 · 刚刚'), findsNothing);
    });

    testWidgets('an unanswered ticket says so instead of showing nothing', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: FakeSupportGateway(
          page: S8Answer<LoopSupportTicketPage>(
            value: s8TicketPage(
              items: <LoopSupportTicket>[
                s8Ticket(status: LoopSupportTicketStatus.open),
              ],
            ),
          ),
        ),
      );

      final ticket = find.byKey(
        ValueKey<String>('support-ticket-$s8NotificationId'),
      );
      await scrollToS8Section(tester, ticket);
      await tester.tap(ticket);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('support-ticket-detail-open')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('support-ticket-event-1')),
        findsNothing,
      );
    });
  });
}
