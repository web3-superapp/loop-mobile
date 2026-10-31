import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
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
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(value: _withStats()),
        ),
      );

      final texts = _pageTexts(tester).join('\n');
      expect(find.text('邀请中心'), findsOneWidget);
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
      // The counts and the five depths stay.
      expect(find.byKey(const ValueKey<String>('referral-stats')), findsOne);
      expect(find.byKey(const ValueKey<String>('referral-levels')), findsOne);

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

    testWidgets('S293b / UX-012: one invite card, levels under it', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
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
      // The level band starts where the invite card ends.
      expect(
        tester
            .getRect(find.byKey(const ValueKey<String>('referral-levels')))
            .top,
        greaterThanOrEqualTo(tester.getRect(card).bottom),
      );
    });

    testWidgets('the (i) says every rule, one heading each', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
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
        contains('邀请加成只计入挖矿算力，不是收入、佣金或返佣。'),
      );
      expect(note('referral-info-relationship'), contains('分享完成不代表关系成立，还需要验证'));
      expect(note('referral-info-relationship'), contains('0 个有效关系 · 3 个待验证'));
      expect(note('referral-info-depth'), contains('L1 再邀请的人是 L2'));
      expect(note('referral-info-depth'), contains('最深到 L5'));
      expect(note('referral-level-1'), contains('L1 · 加成 10%'));
      // S293b: one title and one description per level; no status counts
      // and no second 「L1 ·」.
      expect(note('referral-level-1'), 'L1 · 加成 10%\n我直接邀请并已验证的人');
      expect(note('referral-level-2'), contains('我的 L1 再邀请的人'));
      expect(note('referral-level-1'), isNot(contains('待绑定钱包')));
      expect(note('referral-level-1'), isNot(contains('有效 0')));
      expect(
        note('referral-info-valid-member'),
        contains('被邀请人本人在最近一个结算小时有算力'),
      );
      expect(
        note('referral-info-valid-member'),
        contains('当前数字截至 2026-10-23 03:00 UTC'),
      );
      // S298: binding has no time limit; no day count, no deadline.
      expect(note('referral-info-binding'), contains('激活 LOOP ID 后随时可以绑定'));
      expect(note('referral-info-binding'), contains('一个账号只能绑定一次'));
      expect(note('referral-info-binding'), isNot(contains('天内')));
      expect(note('referral-info-binding'), isNot(contains('窗口')));
      expect(note('referral-info-binding'), isNot(contains('截止')));
      final rules = note('referral-info-rules');
      expect(rules, contains('生效于 2026-09-01 00:00 UTC'));
      expect(rules, contains('最大深度 L5'));
      expect(rules, isNot(contains('绑定窗口')));
      expect(rules, isNot(contains('7 天')));
      expect(rules, contains('作用于挖矿算力'));
      expect(rules, isNot(contains('miningPower')));
    });

    testWidgets('a read that failed still says so; the (i) still opens', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            failure: LaunchFailureKind.unexpected,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('referral-state-error')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('referral-explain-action')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('不是收入、佣金或返佣'), findsOneWidget);
      // No figure the page did not read.
      expect(find.textContaining('个待验证'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('referral-info-rules')),
        findsNothing,
      );
    });

    testWidgets('closed / bound: the button is disabled with one line', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
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
      expect(find.text('当前不能绑定邀请码，请稍后刷新再试'), findsOneWidget);
      expect(find.textContaining('2026-10-28'), findsNothing);

      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            value: _withStats(binding: s7BoundBinding()),
          ),
        ),
      );
      await scrollToS7Section(tester, claim);
      expect(tester.widget<LoopButton>(claim).onPressed, isNull);
      expect(find.text('已绑定邀请人，关系锁定后不能更换'), findsOneWidget);
      // The inviter row is kept.
      expect(
        find.byKey(const ValueKey<String>('referral-bound-row')),
        findsOneWidget,
      );
    });
  });

  group('情报 · 我的邀请 · #03', () {
    testWidgets('no sentence under the code or the counts; (i) has them', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: FakeMiningGateway(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(value: _withStats()),
        ),
      );
      await tester.tap(find.text('邀请中心'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('intel-referral-code')),
        findsOneWidget,
      );
      expect(find.textContaining('有效成员截至'), findsNothing);
      expect(find.textContaining('不是收入、佣金或返佣'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('intel-referral-open')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('intel-referral-info')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('intel-referral-info-sheet')),
        findsOneWidget,
      );
      expect(find.textContaining('不是收入、佣金或返佣'), findsOneWidget);
      expect(find.textContaining('被邀请人本人在最近一个结算小时有算力'), findsOneWidget);
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
      expect(
        find.byKey(const ValueKey<String>('mining-open-market')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-open-rank')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('mining-rules-action')),
      );
      await tester.pumpAndSettle();
      expect(find.text('挖矿说明'), findsOneWidget);
      expect(find.text('公式版本'), findsOneWidget);
      expect(find.textContaining('已生效的公式版本'), findsOneWidget);
      expect(find.text('最近一次算力快照'), findsOneWidget);
      expect(find.textContaining('这是算出算力的时间'), findsOneWidget);
      expect(find.textContaining('区块 '), findsOneWidget);
      expect(find.text('不做本地估算'), findsOneWidget);
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
      expect(find.textContaining('还没有读到挖矿摘要'), findsOneWidget);
      expect(find.textContaining('还没有读到算力快照'), findsOneWidget);
      expect(find.textContaining('读不到不等于「算力为零」'), findsOneWidget);
    });
  });
}
