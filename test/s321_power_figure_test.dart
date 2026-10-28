import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/text/loop_power_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

// Decision 0252: every power prints as a floored whole number with thousands
// separators, and the podium's three figures share one size.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const _powers = <String>[
  '5000001',
  '2500000',
  '947955.604749012530067131',
  '860511.549340487510303083',
];

MiningRank _users(MiningRankScope scope) => s7MiningRank(
  scope: scope,
  snapshot: s7MiningSnapshot(),
  me: const MiningRankMe(rank: 4, value: '860511.549340487510303083'),
  ranking: MiningRankingUsers(
    items: <MiningRankUserRow>[
      for (var index = 0; index < _powers.length; index += 1)
        MiningRankUserRow(
          position: index + 1,
          power: _powers[index],
          powerVisibility: MiningRankAudience.everyone,
          display: MiningRankAlias(
            alias: 'member${index + 1}',
            publicProfileId:
                '8c2b7a15-4d3e-4f60-9a11-${(index + 1).toString().padLeft(12, '0')}',
            audience: MiningRankAudience.everyone,
          ),
          isSelf: index == 3,
        ),
    ],
    participants: 40,
  ),
);

final class _BoardMining implements MiningGateway {
  final FakeMiningGateway _inner = FakeMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) =>
      Future<MiningRank>.value(_users(scope));

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

void main() {
  group('loopPowerFigure', () {
    test('floors to a whole number and groups it', () {
      expect(loopPowerFigure('947955.604749012530067131'), '947,955');
      expect(loopPowerFigure('5000001'), '5,000,001');
      expect(loopPowerFigure('0'), '0');
      expect(loopPowerFigure('0.999999999999999999'), '0');
      expect(loopPowerFigure('12.999'), '12');
      expect(loopPowerFigure('999'), '999');
      expect(loopPowerFigure('1000.'), '1,000');
    });

    test('a 30-digit value stays exact', () {
      expect(
        loopPowerFigure('123456789012345678901234567890.123456789'),
        '123,456,789,012,345,678,901,234,567,890',
      );
      expect(
        loopPowerFigure('900000000000000000000000000001'),
        '900,000,000,000,000,000,000,000,000,001',
      );
    });

    test('a negative fraction floors away from zero', () {
      expect(loopPowerFigure('-12.5'), '-13');
      expect(loopPowerFigure('-1200'), '-1,200');
    });

    test('anything that is not a plain decimal prints as it arrived', () {
      expect(loopPowerFigure(''), '');
      expect(loopPowerFigure('—'), '—');
      expect(loopPowerFigure('1e5'), '1e5');
    });

    test('miningPowerFigure says the same', () {
      expect(
        miningPowerFigure(Decimal.parse('947955.604749012530067131')),
        '947,955',
      );
    });
  });

  testWidgets('算力榜: whole figures, one podium size, #1 alone in yellow', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      IntelRankBoard(onNavigate: (_) {}),
      mining: _BoardMining(),
    );
    await tester.tap(find.text('用户'));
    await tester.pumpAndSettle();

    Text figure(int place) =>
        tester.widget<Text>(_key('intel-rank-figure-$place'));
    expect(figure(1).data, '5,000,001');
    expect(figure(2).data, '2,500,000');
    expect(figure(3).data, '947,955');
    final size = figure(1).style!.fontSize;
    expect(figure(2).style!.fontSize, size);
    expect(figure(3).style!.fontSize, size);
    expect(figure(1).style!.color, LoopColors.yellow);
    expect(figure(2).style!.color, LoopColors.chalk);
    expect(figure(3).style!.color, LoopColors.chalk);
    // The three render at one scale: none is shrunk on its own.
    final heights = <double>[
      for (final place in <int>[1, 2, 3])
        tester.getSize(_key('intel-rank-figure-$place')).height,
    ];
    expect(heights[1], closeTo(heights[0], 0.01));
    expect(heights[2], closeTo(heights[0], 0.01));

    expect(find.textContaining('860,511'), findsWidgets);
    expect(find.textContaining('.549'), findsNothing);
    expect(find.textContaining('.604'), findsNothing);
    // The gap is the difference of the two whole figures on screen.
    expect(find.text('算力 860,511，距第 3 名还差 87,444'), findsOneWidget);
  });

  test('the podium style shrinks all three together', () {
    final base = LoopType.figureLg;
    final wide = intelPodiumFigureStyle(
      figures: const <String>['5,000,001', '2,500,000', '123,456,789,012,345'],
      slotWidth: 80,
    );
    expect(wide.fontSize, lessThan(base.fontSize!));
    final fits = intelPodiumFigureStyle(
      figures: const <String>['1', '2', '3'],
      slotWidth: 80,
    );
    expect(fits.fontSize, base.fontSize);
  });
}
