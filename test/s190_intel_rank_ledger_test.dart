import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart' show LoopProgressBar;
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

// Decision 0182: 情报 · 算力榜 as docs/35 「算力榜 · 定稿」 — the Lime ledger
// card for 我的名次, chips, 前三名 podium, B rows with a share bar.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const _powers = <String>['12960', '8420', '6115', '4870', '3210', '2045'];

MiningRankingCommunities _communities({int participants = 150}) =>
    MiningRankingCommunities(
      items: <MiningRankCommunityRow>[
        for (var index = 0; index < _powers.length; index += 1)
          MiningRankCommunityRow(
            position: index + 1,
            power: _powers[index],
            community: MiningCommunityRef(
              communityId: 'community-${index + 1}',
              name: '社区${index + 1}',
              boundAssetId: s7CakeAssetId,
            ),
            weight: index == 4 ? '1.2' : '1.0',
            participants: 30 - index,
          ),
      ],
      participants: participants,
    );

MiningRankingUsers _users({
  int participants = 240,
  int? selfAt,
}) => MiningRankingUsers(
  items: <MiningRankUserRow>[
    for (var index = 0; index < 11; index += 1)
      MiningRankUserRow(
        position: index + 1,
        power: '${3420 - index * 100}',
        powerVisibility: MiningRankAudience.everyone,
        display: MiningRankAlias(
          alias: 'member${index + 1}',
          publicProfileId:
              '8c2b7a15-4d3e-4f60-9a11-${(index + 1).toString().padLeft(12, '0')}',
          audience: MiningRankAudience.everyone,
          avatarRef: 'avatar:preset/people-01',
        ),
        isSelf: selfAt == index + 1,
      ),
  ],
  participants: participants,
);

const _referrals = MiningRankingReferrals(
  items: <MiningRankReferralRow>[
    MiningRankReferralRow(
      position: 1,
      invitedCount: 12,
      display: MiningRankAlias(
        alias: 'inviter',
        publicProfileId: s7PublicProfileId,
        audience: MiningRankAudience.everyone,
      ),
      isSelf: false,
    ),
    MiningRankReferralRow(
      position: 2,
      invitedCount: 8,
      display: MiningRankAnonymous('mining.rank.anonymousMember'),
      isSelf: false,
    ),
  ],
  participants: 40,
  ruleKey: 'mining.rank.referrals.directActiveEdges',
);

MiningRank _rank(
  MiningRankScope scope,
  MiningRanking ranking, {
  MiningRankMe? me,
  MiningSnapshotRef? snapshot,
}) => s7MiningRank(
  scope: scope,
  ranking: ranking,
  me: me,
  snapshot: snapshot ?? s7MiningSnapshot(),
);

/// A mining port that answers each board with a fixed first page.
final class _BoardMining implements MiningGateway {
  _BoardMining(this.first);

  final MiningRank Function(MiningRankScope scope) first;
  final FakeMiningGateway _inner = FakeMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) =>
      Future<MiningRank>.value(first(scope));

  @override
  Future<MiningSummary> loadSummary() => _inner.loadSummary();

  @override
  Future<MiningAssets> loadAssets() => _inner.loadAssets();

  @override
  Future<MiningCommunity> loadCommunity(String communityId) =>
      _inner.loadCommunity(communityId);

  @override
  Future<MiningRules> loadRules() => _inner.loadRules();
}

MiningRank _boards(MiningRankScope scope) => switch (scope) {
  MiningRankScope.communities => _rank(
    scope,
    _communities(),
    me: const MiningRankMe(rank: 12, value: '1240', communityId: 'mine'),
  ),
  MiningRankScope.users => _rank(
    scope,
    _users(),
    me: const MiningRankMe(rank: 12, value: '2380'),
  ),
  MiningRankScope.referrals => _rank(
    scope,
    _referrals,
    me: const MiningRankMe(rank: 3, value: '5'),
  ),
};

/// Every painted box of at least [side]² filled with [colour].
int _filledBoxes(WidgetTester tester, Color colour, {double side = 44}) {
  var count = 0;
  for (final element in find.byType(DecoratedBox).evaluate()) {
    final decoration = (element.widget as DecoratedBox).decoration;
    if (decoration is! BoxDecoration || decoration.color != colour) continue;
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    if (box.size.width >= side && box.size.height >= side) count += 1;
  }
  return count;
}

void main() {
  group('ledger card copy', () {
    test('kicker: snapshot time, 实时 on 推广, bare without a snapshot', () {
      final snapshot = s7MiningSnapshot();
      expect(
        intelRankLedgerKicker(
          _rank(MiningRankScope.communities, _communities()),
        ),
        '算力榜 · 快照 ${intelRankMonthDayClock(snapshot.computedAt)}',
      );
      expect(
        intelRankLedgerKicker(_rank(MiningRankScope.referrals, _referrals)),
        '算力榜 · 实时',
      );
      expect(
        intelRankLedgerKicker(
          _rank(
            MiningRankScope.users,
            _users(),
            snapshot: const MiningSnapshotUnavailable('X'),
          ),
        ),
        '算力榜',
      );
      expect(
        intelRankMonthDayClock(DateTime(2026, 10, 5, 4, 7)),
        '10-05 04:07',
      );
    });

    test('heading: 第 N 名, or 还没有名次', () {
      expect(
        intelRankLedgerHeading(
          _rank(
            MiningRankScope.users,
            _users(),
            me: const MiningRankMe(rank: 37, value: '320'),
          ),
        ),
        '我的名次\n第 37 名',
      );
      expect(
        intelRankLedgerHeading(_rank(MiningRankScope.users, _users())),
        '我的名次\n还没有名次',
      );
    });

    test('caption: the gap only when the place above was read', () {
      // Place 11 holds 2420; the reader at 12 holds 2380.
      final read = _rank(
        MiningRankScope.users,
        _users(),
        me: const MiningRankMe(rank: 12, value: '2380'),
      );
      expect(intelRankLedgerCaption(read, const {}), '算力 2,380 · 距第 11 名还差 40');
      // Place 36 is not on the pages read so far.
      final unread = _rank(
        MiningRankScope.users,
        _users(),
        me: const MiningRankMe(rank: 37, value: '320'),
      );
      expect(intelRankGapToNext(unread), isNull);
      expect(intelRankLedgerCaption(unread, const {}), '算力 320');
      // The leader has nobody above.
      expect(
        intelRankGapToNext(
          _rank(
            MiningRankScope.users,
            _users(),
            me: const MiningRankMe(rank: 1, value: '3420'),
          ),
        ),
        isNull,
      );
    });

    test('caption: the reader\'s community and its weight on 社区', () {
      final inRows = _rank(
        MiningRankScope.communities,
        _communities(),
        me: const MiningRankMe(
          rank: 5,
          value: '3210',
          communityId: 'community-5',
        ),
      );
      expect(
        intelRankLedgerCaption(inRows, const {}),
        '算力 3,210 · 距第 4 名还差 1,660 · 社区 社区5 权重 1.2',
      );
      final known = _rank(
        MiningRankScope.communities,
        _communities(),
        me: const MiningRankMe(rank: 12, value: '1240', communityId: 'mine'),
      );
      expect(intelRankLedgerCaption(known, const {}), '算力 1,240');
    });

    test('caption on 推广 and without a place', () {
      expect(
        intelRankLedgerCaption(
          _rank(
            MiningRankScope.referrals,
            _referrals,
            me: const MiningRankMe(rank: 3, value: '5'),
          ),
          const {},
        ),
        '直接邀请 5 人 · 距第 2 名还差 3 人',
      );
      expect(
        intelRankLedgerCaption(
          _rank(MiningRankScope.referrals, _referrals),
          const {},
        ),
        '邀请到第一位好友后上榜',
      );
      expect(
        intelRankLedgerCaption(
          _rank(MiningRankScope.users, _users()),
          const {},
        ),
        '有算力后，下一次算力快照上榜',
      );
    });

    test('stamp: TOP x% only with a place and the board size', () {
      expect(
        intelRankTopShare(
          _rank(
            MiningRankScope.communities,
            _communities(),
            me: const MiningRankMe(rank: 12, value: '1240'),
          ),
        ),
        'TOP 8%',
      );
      expect(
        intelRankTopShare(
          _rank(
            MiningRankScope.communities,
            _communities(participants: 0),
            me: const MiningRankMe(rank: 12, value: '1240'),
          ),
        ),
        isNull,
      );
      expect(intelRankTopShare(_rank(MiningRankScope.users, _users())), isNull);
      expect(
        intelRankTopShare(
          _rank(
            MiningRankScope.users,
            const MiningRankingUnavailable('X'),
            me: const MiningRankMe(rank: 3, value: '1'),
          ),
        ),
        isNull,
      );
    });

    test('share of the leader, none without a leader figure', () {
      expect(
        intelRankShare(Decimal.parse('4870'), Decimal.parse('12960')),
        closeTo(4870 / 12960, 1e-9),
      );
      expect(intelRankShare(Decimal.parse('1'), Decimal.zero), isNull);
      expect(intelRankShare(null, Decimal.parse('1')), isNull);
      expect(intelRankShare(Decimal.parse('5'), null), isNull);
    });
  });

  group('page', () {
    testWidgets('社区: the ledger card is a chrome plate, no yellow slab '
        '(S241b, decision 0221)', (tester) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: _BoardMining(_boards),
      );
      final ledger = find.descendant(
        of: _key('intel-rank-me'),
        matching: find.byType(LoopChromePlate),
      );
      expect(ledger, findsOneWidget);
      // Decision 0224: a brushed dark face inside a chrome bevel.
      final face = tester.widget<DecoratedBox>(_key('loop-chrome-plate-face'));
      expect(
        ((face.decoration as BoxDecoration).gradient! as LinearGradient).colors,
        LoopChromePlate.faceColors,
      );
      expect(find.text('我的名次\n第 12 名'), findsOneWidget);
      expect(find.text('算力 1,240'), findsOneWidget);
      expect(find.text('TOP 8%'), findsOneWidget);
      expect(
        find.text(
          '算力榜 · 快照 '
          '${intelRankMonthDayClock(s7MiningSnapshot().computedAt)}',
        ),
        findsOneWidget,
      );
      // The old capsule is gone.
      expect(_key('intel-rank-me-heading'), findsNothing);
      // The chips sit under the card.
      expect(
        tester.getRect(_key('intel-rank-scope')).top,
        greaterThanOrEqualTo(tester.getRect(_key('intel-rank-me')).bottom),
      );
      // One full Lime surface on the screen: the ledger card.
      expect(_filledBoxes(tester, LoopColors.yellow), 0);
      expect(find.text('前三名'), findsOneWidget);
      for (final place in <int>[1, 2, 3]) {
        // Decision 0224: the place is an Anton index, not a medal dot.
        expect(_key('intel-rank-medal-$place'), findsNothing);
        expect(_key('intel-rank-index-$place'), findsOneWidget);
      }
      // Decision 0224: the podium stands on the wall, not on record cards.
      expect(
        find.descendant(
          of: _key('intel-rank-podium'),
          matching: _key('intel-rank-podium-wall'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('intel-rank-community-community-2'),
          matching: find.byType(LoopRecordCard),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a B row: badge, second line and the share bar', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: _BoardMining(_boards),
      );
      expect(_key('intel-rank-list-head'), findsOneWidget);
      expect(find.text('名次 · 社区 · 权重'), findsOneWidget);
      expect(find.text('算力 · 占第一名比例'), findsOneWidget);
      final row = _key('intel-rank-community-community-4');
      expect(
        find.descendant(of: row, matching: find.text('权重 1.0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('27 人有算力')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('4,870')),
        findsOneWidget,
      );
      final bar = tester.widget<LoopProgressBar>(
        find.descendant(of: row, matching: find.byType(LoopProgressBar)),
      );
      expect(bar.value, closeTo(4870 / 12960, 1e-9));
      expect(
        tester
            .getSize(
              find.descendant(of: row, matching: find.byType(LoopProgressBar)),
            )
            .width,
        intelRankShareBarWidth,
      );
      final face = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.width == intelRankRowFaceSize &&
              widget.height == intelRankRowFaceSize,
        ),
      );
      expect(face, findsOneWidget);
    });

    testWidgets('the reader not on the pages read: one row at the end', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: _BoardMining(_boards),
      );
      final self = _key('intel-rank-self-row');
      expect(self, findsOneWidget);
      expect(
        find.descendant(of: self, matching: find.text('12')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: self, matching: find.text('1,240')),
        findsOneWidget,
      );
      // After the last row, before the source line.
      expect(
        tester.getRect(self).top,
        greaterThanOrEqualTo(
          tester.getRect(_key('intel-rank-community-community-6')).bottom,
        ),
      );
      expect(
        tester.getRect(self).bottom,
        lessThanOrEqualTo(tester.getRect(_key('intel-rank-provenance')).top),
      );
      final ground = tester.widget<Container>(
        find.descendant(of: self, matching: find.byType(Container)).first,
      );
      expect(
        (ground.decoration! as BoxDecoration).color,
        LoopColors.purpleSoft,
      );
      final position = tester.widget<Text>(
        find.descendant(of: self, matching: _key('intel-rank-row-position')),
      );
      expect(position.style!.color, LoopColors.yellow);
      final figure = tester.widget<Text>(
        find.descendant(of: self, matching: _key('intel-rank-row-figure')),
      );
      expect(figure.style!.color, LoopColors.yellow);
    });

    testWidgets('the reader on the pages read: that row lights, none added', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: _BoardMining(
          (scope) => _rank(
            scope,
            _communities(),
            me: const MiningRankMe(
              rank: 5,
              value: '3210',
              communityId: 'community-5',
            ),
          ),
        ),
      );
      expect(_key('intel-rank-self-row'), findsNothing);
      final row = _key('intel-rank-community-community-5');
      final ground = tester.widget<Container>(
        find.descendant(of: row, matching: find.byType(Container)).first,
      );
      expect(
        (ground.decoration! as BoxDecoration).color,
        LoopColors.purpleSoft,
      );
      final other = tester.widget<Container>(
        find
            .descendant(
              of: _key('intel-rank-community-community-4'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((other.decoration! as BoxDecoration).color, isNull);
      expect(
        find.text('算力 3,210 · 距第 4 名还差 1,660 · 社区 社区5 权重 1.2'),
        findsOneWidget,
      );
    });

    testWidgets('the card follows the three boards', (tester) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: _BoardMining(_boards),
      );
      expect(find.text('我的名次\n第 12 名'), findsOneWidget);

      await tester.tap(find.text('用户'));
      await tester.pumpAndSettle();
      expect(find.text('算力 2,380 · 距第 11 名还差 40'), findsOneWidget);
      expect(find.text('TOP 5%'), findsOneWidget);
      expect(find.text('名次 · 用户'), findsOneWidget);
      // No community or medal count is read for a user row: no badge.
      expect(
        find.descendant(
          of: _key('intel-rank-user-3'),
          matching: find.byType(LoopBadge),
        ),
        findsNothing,
      );
      final bar = tester.widget<LoopProgressBar>(
        find.descendant(
          of: _key('intel-rank-user-3'),
          matching: find.byType(LoopProgressBar),
        ),
      );
      expect(bar.value, closeTo(3120 / 3420, 1e-9));

      await tester.tap(find.text('邀请中心'));
      await tester.pumpAndSettle();
      expect(find.text('我的名次\n第 3 名'), findsOneWidget);
      expect(find.text('算力榜 · 实时'), findsOneWidget);
      expect(find.text('直接邀请 5 人 · 距第 2 名还差 3 人'), findsOneWidget);
      expect(find.text('TOP 8%'), findsOneWidget);
      expect(find.text('直接邀请 · 占第一名比例'), findsOneWidget);
      // 推广 rows carry no weight badge.
      expect(find.textContaining('权重'), findsNothing);
      expect(_filledBoxes(tester, LoopColors.yellow), 0);
    });

    testWidgets('no place: 还没有名次 and no stamp; empty 推广 button is quiet', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: _BoardMining(
          (scope) => _rank(
            scope,
            scope == MiningRankScope.referrals
                ? const MiningRankingReferrals(
                    items: <MiningRankReferralRow>[],
                    participants: 0,
                    ruleKey: 'mining.rank.referrals.directActiveEdges',
                  )
                : _communities(),
          ),
        ),
      );
      expect(find.textContaining('还没有名次'), findsOneWidget);
      // Decision 0224: the grey crown line where the figure would be.
      expect(
        find.byKey(const ValueKey<String>('intel-rank-me-empty-crown')),
        findsOneWidget,
      );
      expect(find.textContaining('TOP '), findsNothing);
      expect(_key('intel-rank-self-row'), findsNothing);
      await tester.tap(find.text('邀请中心'));
      await tester.pumpAndSettle();
      expect(_key('intel-rank-empty'), findsOneWidget);
      final invite = tester.widget<LoopButton>(_key('intel-rank-empty-invite'));
      expect(invite.primary, isFalse);
      expect(_filledBoxes(tester, LoopColors.yellow), 0);
    });
  });
}
