import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';

/// One `GET /v2/community/home` answer, carrying only the `joined` block the
/// 我的社区 row reads.
CommunityHome _home({
  List<JoinedCommunity> joined = const <JoinedCommunity>[],
  bool truncated = false,
}) => CommunityHome(
  joined: joined,
  joinedTruncated: truncated,
  discover: const <CommunitySummary>[],
  unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
  liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
  observedAt: DateTime.utc(2026, 9, 10, 1),
  source: 'database',
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);

JoinedCommunity _joined({
  required String communityId,
  required String name,
  CommunityRole role = CommunityRole.member,
  CommunityMemberStatus status = CommunityMemberStatus.active,
}) => JoinedCommunity(
  community: testCommunity(communityId: communityId, name: name),
  membership: CommunityMembership(
    role: role,
    status: status,
    joinedAt: DateTime.utc(2026, 7),
  ),
);

final _builders = _joined(
  communityId: '3fa85f64-5717-4562-b3fc-2c963f66af11',
  name: 'Builders Guild',
  role: CommunityRole.owner,
);
final _frogs = _joined(
  communityId: '3fa85f64-5717-4562-b3fc-2c963f66af22',
  name: 'Frog Holders',
);
final _writers = _joined(
  communityId: '3fa85f64-5717-4562-b3fc-2c963f66af33',
  name: 'Writers Room',
  role: CommunityRole.admin,
);

Finder get _row =>
    find.byKey(const ValueKey<String>('profile-open-communities'));

LoopRecordRow _rowWidget(WidgetTester tester) =>
    tester.widget<LoopRecordRow>(_row);

/// Pumps `profile` with only the community port overridden: the profile
/// resource itself stays closed, so what the test observes is the membership
/// row's own answer.
Future<void> _pumpProfile(
  WidgetTester tester, {
  required FakeCommunityGateway community,
  ValueChanged<String>? onNavigate,
  LoopV2MetaSnapshot? meta,
}) async {
  await pumpCommunityPage(
    tester,
    ProfileSurfaceScreen.fromId('profile', onNavigate: onNavigate ?? (_) {}),
    community: community,
    meta: meta,
  );
  await scrollToCommunitySection(tester, _row);
}

void main() {
  group('profile · 我的社区', () {
    testWidgets('one membership shows the count, the name and the role', (
      tester,
    ) async {
      final destinations = <String>[];
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(joined: <JoinedCommunity>[_builders]),
        ),
        onNavigate: destinations.add,
      );

      final row = _rowWidget(tester);
      expect(row.trailing, '1 个已加入');
      expect(row.subtitle, 'Builders Guild（Owner）');
      // The retired copy must not survive anywhere on the page.
      expect(find.text('社区成员关系尚未接入'), findsNothing);

      await tester.tap(_row);
      await tester.pumpAndSettle();
      expect(destinations, <String>['community-joined']);
    });

    testWidgets('the subtitle names at most two communities', (tester) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(joined: <JoinedCommunity>[_builders, _frogs, _writers]),
        ),
      );

      final row = _rowWidget(tester);
      expect(row.trailing, '3 个已加入');
      expect(row.subtitle, 'Builders Guild（Owner） · Frog Holders（成员）');
      expect(row.subtitle, isNot(contains('Writers Room')));
    });

    testWidgets('a truncated aggregate marks the count as a floor', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(
            joined: <JoinedCommunity>[_builders, _frogs],
            truncated: true,
          ),
        ),
      );

      expect(_rowWidget(tester).trailing, '2+ 个已加入');
    });

    testWidgets('a suspended membership reads as its state, not its role', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(
            joined: <JoinedCommunity>[
              _joined(
                communityId: '3fa85f64-5717-4562-b3fc-2c963f66af44',
                name: 'Muted Hall',
                role: CommunityRole.admin,
                status: CommunityMemberStatus.muted,
              ),
            ],
          ),
        ),
      );

      expect(_rowWidget(tester).subtitle, 'Muted Hall（已禁言）');
    });

    testWidgets('no membership says so and points at discovery', (
      tester,
    ) async {
      final destinations = <String>[];
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(home: _home()),
        onNavigate: destinations.add,
      );

      final row = _rowWidget(tester);
      expect(row.trailing, '0 个已加入');
      expect(row.subtitle, '还没有加入社区，从发现社区开始');

      await tester.tap(_row);
      await tester.pumpAndSettle();
      expect(destinations, <String>['community-discover']);
    });

    testWidgets('an unread aggregate shows no figure while it loads', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway()..pending = true,
      );

      final row = _rowWidget(tester);
      expect(row.trailing, '—');
      expect(row.subtitle, '正在读取社区成员关系');
    });

    testWidgets('offline says the membership was not read', (tester) async {
      final destinations = <String>[];
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(failure: CommunityFailureKind.offline),
        onNavigate: destinations.add,
      );

      final row = _rowWidget(tester);
      expect(row.trailing, '—');
      expect(row.subtitle, '设备已离线，没有读到社区成员关系');

      // The entry point survives the failure and hands the owner to the page
      // that owns the retry.
      await tester.tap(_row);
      await tester.pumpAndSettle();
      expect(destinations, <String>['community-discover']);
    });

    testWidgets('a refused read reports the failure, never a count', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          failure: CommunityFailureKind.unexpected,
        ),
      );

      final row = _rowWidget(tester);
      expect(row.trailing, '—');
      expect(row.subtitle, '社区成员关系读取失败，打开社区目录可重试');
    });

    testWidgets('a closed capability keeps the row from claiming anything', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        home: _home(joined: <JoinedCommunity>[_builders]),
      );
      await _pumpProfile(
        tester,
        community: gateway,
        meta: testMetaSnapshot(
          community: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      final row = _rowWidget(tester);
      expect(row.trailing, '—');
      expect(row.subtitle, '社区模块当前不可用，未读取成员关系');
    });
  });
}
