// S378 · decision 0302 (需求方 2026-11-05「这种快照统一移除」): no power page
// prints a snapshot's time — not 算力榜's plate, not the 情报 · 算力 hero, not
// a community's power row. The hero's way into 算力榜 moved to the right end
// of the figure's row with words beside the crown, and 有效邀请 left the hero.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';

import 'support/s350b_pages.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// 「快照 10-15 04:00」, "snapshot 09-15 22:58", "Snapshot · 2026-09-15 …",
/// 「最近一次算力快照 · 22:58」: a snapshot word followed by a clock.
final RegExp _snapshotTime = RegExp(
  r'(快照|snapshot)[^\n]{0,24}\d{1,2}:\d{2}',
  caseSensitive: false,
);

/// Every text on screen that names a snapshot's time.
List<String> _snapshotTimes(WidgetTester tester) => <String>[
  for (final widget in tester.widgetList<Text>(find.byType(Text)))
    if ((widget.data ?? widget.textSpan?.toPlainText() ?? '') case final text
        when _snapshotTime.hasMatch(text))
      text,
  for (final widget in tester.widgetList<RichText>(find.byType(RichText)))
    if (widget.text.toPlainText() case final text
        when _snapshotTime.hasMatch(text))
      text,
];

void main() {
  group('算力榜 · 我的名次 plate', () {
    testWidgets('the kicker is the bare board name; no empty line', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: FakeMiningGateway(
          rank: S7Answer<MiningRank>(
            value: s7MiningRank(
              scope: MiningRankScope.communities,
              snapshot: s7MiningSnapshot(),
              me: const MiningRankMe(
                rank: 12,
                value: '1240',
                communityId: 'mine',
              ),
            ),
          ),
        ),
      );
      final kicker = tester.widget<Text>(_key('intel-rank-me-kicker'));
      expect(kicker.data, 'Power Ranking');
      expect(_snapshotTimes(tester), isEmpty);
      // The kicker still holds one line of text, not a blank row.
      expect(
        tester.getSize(_key('intel-rank-me-kicker')).height,
        greaterThan(0),
      );
    });

    test('kicker copy: no time on the power boards', () {
      for (final scope in <MiningRankScope>[
        MiningRankScope.communities,
        MiningRankScope.users,
      ]) {
        expect(
          intelRankLedgerKicker(
            s7MiningRank(scope: scope, snapshot: s7MiningSnapshot()),
          ),
          'Power Ranking',
        );
      }
    });
  });

  group('情报 · 算力 · the hero', () {
    testWidgets('no snapshot time; no top-right caption on a fresh snapshot', (
      tester,
    ) async {
      await s350bPumpPower(tester);
      expect(_key('mining-summary-hero'), findsOneWidget);
      expect(_key('mining-summary-hero-caption'), findsNothing);
      expect(_snapshotTimes(tester), isEmpty);
    });

    testWidgets('the rank entry sits at the right of the figure row, centred', (
      tester,
    ) async {
      var opened = 0;
      await s350bPumpPower(
        tester,
        page: MiningScreen(embedded: true, onOpenRank: () => opened += 1),
      );
      final figure = tester.getRect(_key('mining-summary-hero-power'));
      final entry = tester.getRect(_key('mining-network-rank-action'));
      final network = tester.getRect(_key('mining-network-card'));
      // Right of the figure, flush with the hero's content edge (全网's).
      expect(entry.left, greaterThanOrEqualTo(figure.right));
      expect((network.right - entry.right).abs(), lessThanOrEqualTo(2));
      // 全网 follows the figure row; only 上一小时算力 (when settled) may sit
      // between them — 有效邀请 no longer does.
      final hour = _key('mining-summary-hero-last-hour-power');
      final above = hour.evaluate().isEmpty
          ? entry.bottom
          : tester.getRect(hour).bottom;
      expect(network.top, greaterThanOrEqualTo(above));
      // The strip's own 12 bottom and 全网's hairline band (decision 0279).
      expect(network.top - above, lessThanOrEqualTo(32));
      // Same row: centre lines within 2 px.
      expect((entry.center.dy - figure.center.dy).abs(), lessThanOrEqualTo(2));
      expect(entry.height, greaterThanOrEqualTo(LoopTouch.minimum));
      // 「My rank #12」 + crown.
      expect(
        tester.widget<Text>(_key('mining-summary-hero-rank-label')).data,
        'My rank',
      );
      expect(
        tester
            .widget<Text>(_key('mining-summary-hero-rank'))
            .textSpan!
            .toPlainText(),
        '#12',
      );
      expect(
        find.descendant(
          of: _key('mining-network-rank-action'),
          matching: _key('mining-summary-hero-crown'),
        ),
        findsOneWidget,
      );
      // Only one entry, and it opens 算力榜.
      expect(_key('mining-network-rank-action'), findsOneWidget);
      await tester.tap(_key('mining-network-rank-action'));
      expect(opened, 1);
    });

    testWidgets('有效邀请 is gone; 全网 follows the figure row', (tester) async {
      await s350bPumpPower(tester);
      expect(_key('mining-summary-hero-active-invites'), findsNothing);
      expect(
        find.descendant(
          of: _key('mining-summary-hero'),
          matching: find.text('Active invites'),
        ),
        findsNothing,
      );
      expect(find.textContaining('Valid invite'), findsNothing);
    });

    testWidgets('no place: 「No rank yet」 with the crown', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(embedded: true),
        mining: FakeMiningGateway(),
      );
      expect(
        tester.widget<Text>(_key('mining-summary-hero-rank-label')).data,
        'No rank yet',
      );
      expect(_key('mining-summary-hero-rank'), findsNothing);
      expect(_key('mining-summary-hero-crown'), findsOneWidget);
      // Nothing between the figure row and 全网 when no cell is read.
      if (_key('mining-summary-hero-last-hour-power').evaluate().isEmpty &&
          _key('mining-network-card').evaluate().isNotEmpty) {
        final entry = tester.getRect(_key('mining-network-rank-action'));
        final network = tester.getRect(_key('mining-network-card'));
        expect(network.top - entry.bottom, inInclusiveRange(0, 32));
      }
    });
  });

  group('社区 · power row', () {
    for (final stale in <bool>[false, true]) {
      testWidgets('no 「最近一次算力快照 · time」 (stale: $stale)', (tester) async {
        await pumpS7Page(
          tester,
          Scaffold(
            body: ListView(
              children: <Widget>[
                CommunityMiningPowerCard(
                  label: 'Power',
                  fact: LoopAccountMiningPower(
                    power: '1240',
                    snapshotId: 'snap-1',
                    formulaVersion: 'v1',
                    computedAt: DateTime.utc(2026, 11, 5, 10),
                    scope: MiningFormulaScope.product,
                    stale: stale,
                  ),
                ),
              ],
            ),
          ),
        );
        expect(_key('community-mining-power-row'), findsOneWidget);
        expect(_snapshotTimes(tester), isEmpty);
        expect(find.textContaining('Latest power snapshot'), findsNothing);
        if (stale) {
          expect(
            find.textContaining('Showing the last complete power snapshot'),
            findsOneWidget,
          );
        }
      });
    }
  });
}
