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
      expect(find.textContaining('账号设置尚未写入过（版本 0'), findsOneWidget);
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

    testWidgets('the register lists licences without a version', (
      tester,
    ) async {
      await pumpS8Page(tester, const AboutScreen(), about: FakeAboutGateway());

      final entry = find.byKey(
        const ValueKey<String>('about-open-source-Fastify'),
      );
      await scrollToS8Section(tester, entry);
      expect(entry, findsOneWidget);
      expect(find.text('MIT'), findsOneWidget);
      final row = tester.widget<LoopRecordRow>(entry);
      expect(row.subtitle, 'HTTP server and route lifecycle');
      expect(row.trailing, 'MIT');
    });

    testWidgets('every published rule snapshot is shown', (tester) async {
      await pumpS8Page(tester, const AboutScreen(), about: FakeAboutGateway());

      for (final module in <String>['productPolicy', 'support']) {
        final row = find.byKey(ValueKey<String>('about-config-$module'));
        await scrollToS8Section(tester, row);
        expect(row, findsOneWidget, reason: module);
      }
      expect(find.textContaining('productPolicyV2.2026-09-01'), findsOneWidget);
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
      await tester.tap(find.text('挖矿'));
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
  });
}
