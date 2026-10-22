// S288 · decision 0237 「S288 补丁」: self-review shots of 设置 and 安全中心
// after the two seams were closed.
//
// Not a check: it writes 390-wide renders to docs/integration/S288/shots/
// (or `LOOP_SHOTS_DIR`). It runs only with `--dart-define=LOOP_SHOTS=true`;
// a plain `flutter test` skips every case and writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s8_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'docs/integration/S288/shots',
);

const Size _tall = Size(390, 2000);

void main() {
  loopWatchGround();

  testWidgets('设置', skip: !_shots, (tester) async {
    await pumpCommunityPage(
      tester,
      ProfileSurfaceScreen.fromId('settings', onNavigate: (_) {}),
      community: FakeCommunityGateway(
        home: CommunityHome(
          joined: <JoinedCommunity>[
            JoinedCommunity(
              community: testCommunity(
                communityId: '3fa85f64-5717-4562-b3fc-2c963f66af11',
                name: 'Builders Guild',
              ),
              membership: CommunityMembership(
                role: CommunityRole.member,
                status: CommunityMemberStatus.active,
                joinedAt: DateTime.utc(2026, 7),
              ),
            ),
          ],
          joinedTruncated: false,
          discover: const <CommunitySummary>[],
          unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
          liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
          observedAt: DateTime.utc(2026, 10, 22),
          source: 'database',
          recommendation: const CommunityRecommendation(
            recommendationId: '22222222-2222-4222-8222-222222222222',
            ruleVersion: 'rule:verified-members-v1',
          ),
        ),
      ),
      size: _tall,
    );
    await loopShot(tester, 'settings', slice: 2000, dir: _dir);
  });

  testWidgets('安全中心', skip: !_shots, (tester) async {
    await pumpS8Page(
      tester,
      SecurityCenterScreen(onNavigate: (_) {}),
      security: FakeSecurityGateway(),
      size: _tall,
    );
    await loopShot(tester, 'security-center', slice: 2000, dir: _dir);
  });
}
