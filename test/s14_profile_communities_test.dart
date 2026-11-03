import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/me_surface.dart';
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

Finder _key(String key) => find.byKey(ValueKey<String>(key));

/// Pumps 我's community section with only the community port overridden:
/// the profile resource itself stays closed, so what the test observes is
/// the section's own answer (S349 · decision 0271 Amendment: 我的 · 社区
/// lists the communities, as another account's 社区 does).
Future<void> _pumpProfile(
  WidgetTester tester, {
  required FakeCommunityGateway community,
  ValueChanged<String>? onNavigate,
  LoopV2MetaSnapshot? meta,
  bool settle = true,
}) async {
  await pumpCommunityPage(
    tester,
    loopMeSurface(onNavigate: onNavigate ?? (_) {}),
    community: community,
    meta: meta,
    settle: settle,
  );
  if (settle) {
    await scrollToCommunitySection(tester, _key('me-communities-section'));
  }
}

void main() {
  group('我的 · 社区', () {
    testWidgets('one row per joined community, opening its record', (
      tester,
    ) async {
      final destinations = <String>[];
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(joined: <JoinedCommunity>[_builders, _frogs, _writers]),
        ),
        onNavigate: destinations.add,
      );

      for (final entry in <JoinedCommunity>[_builders, _frogs, _writers]) {
        final row = tester.widget<LoopRecordRow>(
          _key('me-joined-${entry.community.communityId}'),
        );
        expect(row.title, entry.community.name);
        expect(row.subtitle, '128 名成员');
      }
      // The retired copy must not survive anywhere on the page.
      expect(find.text('社区成员关系尚未接入'), findsNothing);
      expect(_key('profile-open-communities'), findsNothing);

      await tester.tap(_key('me-joined-${_frogs.community.communityId}'));
      await tester.pumpAndSettle();
      expect(destinations, <String>[
        'community-profile:${_frogs.community.communityId}',
      ]);
    });

    testWidgets('a truncated aggregate ends on the full list', (tester) async {
      final destinations = <String>[];
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(
          home: _home(
            joined: <JoinedCommunity>[_builders, _frogs],
            truncated: true,
          ),
        ),
        onNavigate: destinations.add,
      );

      await tester.ensureVisible(_key('me-joined-all'));
      await tester.tap(_key('me-joined-all'));
      await tester.pumpAndSettle();
      expect(destinations, <String>['community-joined']);
    });

    testWidgets('no membership is one line', (tester) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway(home: _home()),
      );

      expect(_key('me-communities-empty'), findsOneWidget);
      expect(find.text('还没有加入社区'), findsOneWidget);
    });

    testWidgets('an unread aggregate shows no list while it loads', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        community: FakeCommunityGateway()..pending = true,
        settle: false,
      );

      expect(_key('me-communities-state'), findsOneWidget);
      expect(_key('me-communities'), findsNothing);
    });

    for (final failure in <CommunityFailureKind>[
      CommunityFailureKind.offline,
      CommunityFailureKind.unexpected,
    ]) {
      testWidgets('a ${failure.name} read is a state, never an empty list', (
        tester,
      ) async {
        await _pumpProfile(
          tester,
          community: FakeCommunityGateway(failure: failure),
        );

        expect(_key('me-communities-state'), findsOneWidget);
        expect(_key('me-communities-empty'), findsNothing);
      });
    }

    testWidgets('a closed capability claims nothing', (tester) async {
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

      expect(_key('me-communities-unavailable'), findsOneWidget);
      expect(
        _key('me-joined-${_builders.community.communityId}'),
        findsNothing,
      );
    });
  });
}
