// S288 · decision 0237 「S288 补丁」: the two seams build45 showed after the
// block grounds — 我加入的 stacked under 账号 as its own block, and the
// step-up row on 安全中心 standing on no block at all.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/features/security/step_up/step_up_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';
import 'support/s8_harness.dart';

CommunityHome _home() => CommunityHome(
  joined: const <JoinedCommunity>[],
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
);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// The [LoopRecordGroup] that draws the block around [row].
Finder _groupOf(Finder row) =>
    find.ancestor(of: row, matching: find.byType(LoopRecordGroup));

void main() {
  testWidgets('设置 · 账号 is one block of five rows, 我加入的 last', (tester) async {
    await pumpCommunityPage(
      tester,
      ProfileSurfaceScreen.fromId('settings', onNavigate: (_) {}),
      community: FakeCommunityGateway(home: _home()),
    );
    await scrollToCommunitySection(tester, _key('profile-open-communities'));

    const account = <String>[
      'profile-open-wallets',
      'profile-open-connections',
      'profile-open-friend-requests',
      'profile-open-referral',
      'profile-open-communities',
    ];
    final group = _groupOf(_key(account.first));
    expect(group, findsOneWidget);
    final rows = tester.widget<LoopRecordGroup>(group).rows;
    expect(
      rows.map((row) => (row.key! as ValueKey<String>).value).toList(),
      account,
    );
    expect(tester.widget<LoopRecordRow>(_key(account.last)).title, '我加入的');
    expect(
      tester.widget<LoopRecordRow>(_key(account.last)).position,
      LoopRowPosition.last,
    );
    for (final key in account) {
      expect(
        find.descendant(of: group, matching: _key(key)),
        findsOneWidget,
        reason: key,
      );
    }

    // 隐私与安全: 通知中心 sits in the same block as 安全中心 and 通知设置.
    final safety = _groupOf(_key('profile-open-security'));
    expect(safety, findsOneWidget);
    for (final key in <String>[
      'profile-open-privacy',
      'profile-open-notification-inbox',
      'profile-open-notifications',
    ]) {
      expect(
        find.descendant(of: safety, matching: _key(key)),
        findsOneWidget,
        reason: key,
      );
    }
  });

  testWidgets('安全中心 · 大额交易二次验证 stands on a block', (tester) async {
    final destinations = <String>[];
    await pumpS8Page(
      tester,
      SecurityCenterScreen(onNavigate: destinations.add),
      security: FakeSecurityGateway(),
    );

    final row = find.byKey(LoopStepUpSettingRow.rowKey);
    await scrollToS8Section(tester, row);
    expect(row, findsOneWidget);
    final group = _groupOf(row);
    expect(group, findsOneWidget);
    expect(
      tester.widget(group).key,
      const ValueKey<String>('security-step-up-group'),
    );
    // The block is the shared one, with the row's (i) still on the row.
    expect(
      find.descendant(of: group, matching: _key('loop-record-group-block')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: _key('security-step-up-info')),
      findsOneWidget,
    );
  });
}
