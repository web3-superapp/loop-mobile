// S355g · decision 0281: 360 × 800 English renders of the migrated mining,
// rewards, referral and Intelligence pages, to look for truncation and
// overflow after the copy moved to English.
//
// Not a check: it runs only with `--dart-define=LOOP_SHOTS=true` and writes
// to `LOOP_SHOTS_DIR` (default `.dart_tool/s355g_shots`); a plain
// `flutter test` skips every case.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_screen.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/referral_center_host.dart';
import 'support/s7_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: '.dart_tool/s355g_shots',
);

const Size _phone = Size(360, 800);

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget page, {
  List<Override> overrides = const <Override>[],
}) async {
  await tester.runAsync(loopLoadShotFonts);
  await pumpS7Page(
    tester,
    page,
    mining: FakeMiningGateway(),
    referral: FakeReferralGateway(),
    size: _phone,
    overrides: overrides,
  );
  await loopShot(tester, name, slice: 800, dir: _dir);
}

void main() {
  loopWatchGround();

  testWidgets('intel power', skip: !_shots, (tester) async {
    await _shoot(
      tester,
      'S355g-intel-power',
      IntelScreen(onNavigate: (_) {}),
      overrides: <Override>[
        miningRewardsGatewayProvider.overrideWithValue(
          S7TokenStageRewards.preToken(),
        ),
      ],
    );
  });

  testWidgets('mining', skip: !_shots, (tester) async {
    await _shoot(
      tester,
      'S355g-mining',
      const MiningScreen(),
      overrides: <Override>[
        miningRewardsGatewayProvider.overrideWithValue(
          S7TokenStageRewards.preToken(),
        ),
      ],
    );
  });

  testWidgets('power ranking', skip: !_shots, (tester) async {
    await _shoot(
      tester,
      'S355g-rank',
      IntelRankBoard(onNavigate: (_) {}, onBack: () {}),
    );
  });

  testWidgets('mining rules', skip: !_shots, (tester) async {
    await _shoot(
      tester,
      'S355g-mining-rules',
      MiningRulesScreen(onBack: () {}),
    );
  });

  testWidgets('community mining', skip: !_shots, (tester) async {
    await _shoot(
      tester,
      'S355g-community-mining',
      MiningCommunityScreen(communityId: 'community-1', onBack: () {}),
    );
  });

  testWidgets('invite center', skip: !_shots, (tester) async {
    await _shoot(tester, 'S355g-referral', const ReferralCenterHost());
  });

  testWidgets('mining rewards', skip: !_shots, (tester) async {
    await _shoot(
      tester,
      'S355g-mining-rewards',
      MiningRewardsHourlyScreen(onBack: () {}),
      overrides: <Override>[
        miningRewardsGatewayProvider.overrideWithValue(
          S7TokenStageRewards.live(),
        ),
      ],
    );
  });
}
