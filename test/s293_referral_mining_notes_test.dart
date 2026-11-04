import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';

import 'support/referral_center_host.dart';

import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// S293 · decision 0243 (需求方 2026-10-23 #01 / #03 / #04 / #05): the
/// explanations on 邀请中心, 情报 · 我的邀请 and 我的挖矿 are behind the
/// header (i); the binding button stays, disabled, with one line saying why.

ReferralOverview _withStats({ReferralBinding? binding}) {
  final base = s7Referral(binding: binding);
  return ReferralOverview(
    inviteCode: base.inviteCode,
    binding: base.binding,
    levels: base.levels,
    boost: base.boost,
    rules: base.rules,
    inviteLink: 'https://api-staging.example.com/i/LOOP-7HJKM',
    stats: ReferralStats(
      directCount: 3,
      validCount: 1,
      level2to5Count: 4,
      validAsOf: DateTime.utc(2026, 10, 23, 3),
    ),
  );
}

/// The page's own text, sheets excluded.
Iterable<String> _pageTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');

void main() {
  group('邀请中心 · #01 / #05', () {
    testWidgets('the page body carries no explanation', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(value: _withStats()),
        ),
      );

      final texts = _pageTexts(tester).join('\n');
      for (final gone in <String>[
        '邀请好友 · 只计入挖矿算力',
        '个有效关系',
        '个待验证',
        '有效成员截至',
        '被邀请人本人在这一小时有算力',
        '推广榜',
        '关系深度如何计算',
        '只计入挖矿算力',
        '不是收入、佣金或返佣',
        '分享完成不代表关系成立',
        '绑定窗口开放中',
        '一个账号只能绑定一次',
        '作用于',
        '最大深度',
        '返回挖矿',
      ]) {
        expect(texts.contains(gone), isFalse, reason: gone);
      }
      expect(
        find.byKey(const ValueKey<String>('referral-rules-footer')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-mining-only')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-claim-window')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('intel-referral-board')),
        findsNothing,
      );
      // S348: 我的邀请 and the five-depth strip are gone; the two tabs stand.
      // S353b · decision 0279 (主代理 11-04): the Figma's three counts stand
      // under the invite card as one plain card, no explanation.
      expect(
        find.byKey(const ValueKey<String>('referral-stats')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-levels')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-levels')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey<String>('referral-tabs')), findsOne);

      // While the window is open: only the button, enabled, no line.
      final claim = find.byKey(const ValueKey<String>('referral-claim'));
      await scrollToS7Section(tester, claim);
      expect(tester.widget<LoopButton>(claim).onPressed, isNotNull);
      for (final key in <String>[
        'referral-claim-closed',
        'referral-claim-unavailable',
        'referral-claim-bound-note',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing, reason: key);
      }
    });

    testWidgets('S293b / UX-012: one invite card, the tabs under it', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(value: _withStats()),
        ),
      );
      final hero = find.byKey(const ValueKey<String>('referral-hero'));
      final card = find.descendant(
        of: hero,
        matching: find.byKey(const ValueKey<String>('referral-invite-card')),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const ValueKey<String>('referral-invite-code')),
        ),
        findsOneWidget,
      );
      // S348: the two tabs start where the invite card ends.
      expect(
        tester.getRect(find.byKey(const ValueKey<String>('referral-tabs'))).top,
        greaterThanOrEqualTo(tester.getRect(card).bottom),
      );
    });

    testWidgets('the (i) says every rule, one heading each', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(value: _withStats()),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('referral-explain-action')),
      );
      await tester.pumpAndSettle();

      final sheet = find.byKey(
        const ValueKey<String>('referral-explain-sheet'),
      );
      expect(sheet, findsOneWidget);
      String note(String key) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(ValueKey<String>(key)),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data ?? '')
          .join('\n');

      expect(
        note('referral-info-mining-only'),
        contains(
          'Invite boost counts only toward mining power. It isn\'t income, commission or a rebate.',
        ),
      );
      expect(
        note('referral-info-relationship'),
        contains("Sharing doesn't create a relation until it's verified"),
      );
      expect(
        note('referral-info-relationship'),
        contains('0 active · 3 pending verification'),
      );
      expect(note('referral-info-depth'), contains('people L1 invites are L2'));
      expect(note('referral-info-depth'), contains('up to L5'));
      expect(note('referral-level-1'), contains('L1 · Boost 10%'));
      // S293b: one title and one description per level; no status counts
      // and no second 「L1 ·」.
      expect(
        note('referral-level-1'),
        'L1 · Boost 10%\nPeople I invited directly and verified',
      );
      expect(note('referral-level-2'), contains('People my L1 invited'));
      expect(note('referral-level-1'), isNot(contains('Pending wallet link')));
      expect(note('referral-level-1'), isNot(contains('Active 0')));
      expect(
        note('referral-info-valid-member'),
        contains(
          'An invitee is an active member only if they had power in the latest settled hour',
        ),
      );
      expect(
        note('referral-info-valid-member'),
        contains('Figures as of 2026-10-23 03:00 UTC'),
      );
      // S298: binding has no time limit; no day count, no deadline.
      expect(
        note('referral-info-binding'),
        contains('Invitees can bind any time after activating their LOOP ID'),
      );
      expect(
        note('referral-info-binding'),
        contains('each account can bind only once'),
      );
      expect(note('referral-info-binding'), isNot(contains('days')));
      expect(note('referral-info-binding'), isNot(contains('window')));
      expect(note('referral-info-binding'), isNot(contains('deadline')));
      final rules = note('referral-info-rules');
      expect(rules, contains('Effective 2026-09-01 00:00 UTC'));
      expect(rules, contains('max depth L5'));
      expect(rules, isNot(contains('window')));
      expect(rules, isNot(contains('7 days')));
      expect(rules, contains('applies to mining power'));
      expect(rules, isNot(contains('miningPower')));
    });

    testWidgets('closed / bound: the button is disabled with one line', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            value: _withStats(
              binding: ReferralBinding(
                isBound: false,
                inviter: null,
                claimWindow: ReferralClaimWindowTimed(
                  isOpen: false,
                  activatedAt: DateTime.utc(2026, 10, 21),
                  closesAt: DateTime.utc(2026, 10, 28, 8, 59),
                ),
              ),
            ),
          ),
        ),
      );
      final claim = find.byKey(const ValueKey<String>('referral-claim'));
      await scrollToS7Section(tester, claim);
      expect(tester.widget<LoopButton>(claim).onPressed, isNull);
      expect(
        find.text(
          'You can\'t bind an invite code right now. Refresh and try again later',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('2026-10-28'), findsNothing);

      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            value: _withStats(binding: s7BoundBinding()),
          ),
        ),
      );
      await scrollToS7Section(tester, claim);
      expect(tester.widget<LoopButton>(claim).onPressed, isNull);
      expect(
        find.text(
          'Inviter bound. The relation is locked and can\'t be changed',
        ),
        findsOneWidget,
      );
      // The inviter row is kept.
      expect(
        find.byKey(const ValueKey<String>('referral-bound-row')),
        findsOneWidget,
      );
    });
  });

  group('情报 · 算力 · 邀请 · #03', () {
    testWidgets('no sentence under the code or the counts; (i) has them', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(value: _withStats()),
        ),
        size: const Size(390, 4000),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('mining-power-tabs')),
          matching: find.text('Invitation'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('referral-invite-code')),
        findsOneWidget,
      );
      expect(find.textContaining('有效成员截至'), findsNothing);
      expect(
        find.textContaining("It isn't income, commission or a rebate"),
        findsNothing,
      );

      // S325 · decision 0255: the tab's notes join the page's one (i).
      await tester.tap(
        find.byKey(const ValueKey<String>('mining-rules-action')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('mining-info-sheet')),
        findsOneWidget,
      );
      expect(
        find.textContaining("It isn't income, commission or a rebate"),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'An invitee is an active member only if they had power in the latest settled hour',
        ),
        findsOneWidget,
      );
    });
  });

  group('我的挖矿 · #04', () {
    testWidgets('formula, snapshot and the no-estimate card are in the (i)', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              formula: s7EffectiveFormula(),
              snapshot: s7MiningSnapshot(),
            ),
          ),
        ),
      );

      for (final gone in <String>['公式版本', '算力快照', '不做本地估算']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(
        find.byKey(const ValueKey<String>('mining-formula')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-truth-notice')),
        findsNothing,
      );
      // S348: 有权重的社区币 is gone.
      expect(
        find.byKey(const ValueKey<String>('mining-open-market')),
        findsNothing,
      );
      // Decision 0272: 算力榜 opens from the network card's icon.
      expect(
        find.byKey(const ValueKey<String>('mining-open-rank')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-network-rank-action')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('mining-rules-action')),
      );
      await tester.pumpAndSettle();
      expect(find.text('About mining'), findsOneWidget);
      expect(find.text('Formula version'), findsOneWidget);
      expect(find.textContaining('Formula version in effect'), findsOneWidget);
      expect(find.text('Latest power snapshot'), findsOneWidget);
      expect(find.textContaining('when power was calculated'), findsOneWidget);
      expect(find.textContaining('Block '), findsOneWidget);
      expect(find.text('No local estimates'), findsOneWidget);
    });

    testWidgets('without a summary the (i) says nothing was read', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(failure: LaunchFailureKind.offline),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('mining-state-offline')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('mining-rules-action')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Mining summary not loaded yet'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No power snapshot loaded yet'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Not loaded doesn\'t mean "zero power"'),
        findsOneWidget,
      );
    });
  });
}
