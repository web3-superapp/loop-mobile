import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/community_test_harness.dart';
import 'support/communication_test_harness.dart';

Finder keyed(String key) => find.byKey(ValueKey<String>(key));

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Future<void> openManagement(WidgetTester tester) async {
  await tester.tap(keyed('community-profile-manage'));
  await tester.pumpAndSettle();
}

void main() {
  for (final role in <CommunityRole>[
    CommunityRole.owner,
    CommunityRole.admin,
  ]) {
    testWidgets('$role sees permitted entries on a narrow screen', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        detail: testDetail(viewer: testViewer(role: role)),
      );
      await pumpCommunityPage(
        tester,
        CommunityProfileScreen(
          communityId: testCommunityId,
          onBack: () {},
          onOpenMembers: (_) {},
          onOpenVoiceRoom: (_) {},
        ),
        community: gateway,
        size: const Size(320, 780),
      );
      await openManagement(tester);
      expect(gateway.reads, 2); // Initial record, then fresh admission.
      expect(keyed('community-management-members'), findsOneWidget);
      expect(keyed('community-management-voice'), findsOneWidget);
      expect(
        keyed('community-management-profile'),
        role == CommunityRole.owner ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'muted admin keeps governance and opens the existing member directory',
    (tester) async {
      final opened = <String>[];
      final gateway = FakeCommunityGateway(
        detail: testDetail(
          viewer: testViewer(
            role: CommunityRole.admin,
            status: CommunityMemberStatus.muted,
            canInviteAdmin: false,
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        CommunityProfileScreen(
          communityId: testCommunityId,
          onOpenMembers: opened.add,
        ),
        community: gateway,
      );
      await openManagement(tester);
      expect(keyed('community-management-members'), findsOneWidget);
      expect(keyed('community-management-profile'), findsNothing);
      await tester.tap(keyed('community-management-members'));
      await tester.pumpAndSettle();
      expect(gateway.reads, 3);
      expect(opened, <String>[testCommunityId]);
      expect(gateway.commands, isEmpty);
    },
  );

  for (final scenario in <String>['member', 'guest', 'banned', 'no-flags']) {
    testWidgets('$scenario has no management entry', (tester) async {
      final gateway = FakeCommunityGateway(
        detail: testDetail(
          viewer: testViewer(
            role: scenario == 'guest'
                ? null
                : scenario == 'member'
                ? CommunityRole.member
                : CommunityRole.owner,
            status: scenario == 'banned'
                ? CommunityMemberStatus.banned
                : CommunityMemberStatus.active,
            canInviteAdmin: scenario == 'banned',
            canMute: scenario == 'banned',
            canBan: scenario == 'banned',
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: gateway,
      );
      expect(keyed('community-profile-manage'), findsNothing);
    });
  }

  testWidgets('revocation before opening refuses a cached owner', (
    tester,
  ) async {
    final gateway = FakeCommunityGateway(detail: testDetail());
    await pumpCommunityPage(
      tester,
      const CommunityProfileScreen(communityId: testCommunityId),
      community: gateway,
    );
    gateway.detail = testDetail(viewer: testViewer(role: null));
    await openManagement(tester);
    expect(keyed('community-management-sheet'), findsNothing);
    expect(keyed('community-profile-manage'), findsNothing);
  });

  testWidgets('failed permission refresh never opens management', (
    tester,
  ) async {
    final gateway = FakeCommunityGateway(detail: testDetail());
    await pumpCommunityPage(
      tester,
      const CommunityProfileScreen(communityId: testCommunityId),
      community: gateway,
    );
    gateway.failure = CommunityFailureKind.offline;
    await openManagement(tester);
    expect(keyed('community-management-sheet'), findsNothing);
    expect(gateway.commands, isEmpty);
  });

  testWidgets('a permission update removes actions while the sheet is open', (
    tester,
  ) async {
    final gateway = FakeCommunityGateway(detail: testDetail());
    final opened = <String>[];
    await pumpCommunityPage(
      tester,
      CommunityProfileScreen(
        communityId: testCommunityId,
        onOpenMembers: opened.add,
      ),
      community: gateway,
    );
    await openManagement(tester);
    gateway.detail = testDetail(viewer: testViewer(role: null));
    await container(tester)
        .read(communityProfileControllerProvider.notifier)
        .reload();
    await tester.pumpAndSettle();
    expect(find.text('管理权限已更新，请返回社区查看。'), findsOneWidget);
    expect(keyed('community-management-members'), findsNothing);
    expect(keyed('community-management-profile'), findsNothing);
    expect(opened, isEmpty);
  });

  testWidgets('selection rechecks server permission before members callback', (
    tester,
  ) async {
    final gateway = FakeCommunityGateway(detail: testDetail());
    final opened = <String>[];
    await pumpCommunityPage(
      tester,
      CommunityProfileScreen(
        communityId: testCommunityId,
        onOpenMembers: opened.add,
      ),
      community: gateway,
    );
    await openManagement(tester);
    gateway.detail = testDetail(viewer: testViewer(role: null));
    await tester.tap(keyed('community-management-members'));
    await tester.pumpAndSettle();
    expect(gateway.reads, 3);
    expect(opened, isEmpty);
  });

  testWidgets('members reuse the exact community callback without a write', (
    tester,
  ) async {
    final gateway = FakeCommunityGateway(detail: testDetail());
    final opened = <String>[];
    await pumpCommunityPage(
      tester,
      CommunityProfileScreen(
        communityId: testCommunityId,
        onOpenMembers: opened.add,
      ),
      community: gateway,
    );
    await openManagement(tester);
    await tester.tap(keyed('community-management-members'));
    await tester.pumpAndSettle();
    expect(opened, <String>[testCommunityId]);
    expect(gateway.commands, isEmpty);
  });

  testWidgets('owner profile entry reuses the existing edit sheet', (
    tester,
  ) async {
    final gateway = FakeCommunityGateway(detail: testDetail());
    await pumpCommunityPage(
      tester,
      const CommunityProfileScreen(communityId: testCommunityId),
      community: gateway,
    );
    await openManagement(tester);
    await tester.tap(keyed('community-management-profile'));
    await tester.pumpAndSettle();
    expect(keyed('community-edit-name'), findsOneWidget);
    expect(gateway.commands, isEmpty);
  });

  testWidgets('voice capability revocation disables an already open entry', (
    tester,
  ) async {
    var usable = true;
    final voiceCapability = loopCapabilityProvider(
      LoopV2CapabilityId.voiceRooms,
    );
    await pumpCommunityPage(
      tester,
      CommunityProfileScreen(
        communityId: testCommunityId,
        onOpenVoiceRoom: (_) {},
      ),
      community: FakeCommunityGateway(detail: testDetail()),
      overrides: [
        voiceCapability.overrideWith(
          (ref) => LoopCapabilityProjection(
            decision: usable
                ? LoopCapabilityDecision.available
                : LoopCapabilityDecision.unavailable,
          ),
        ),
      ],
    );
    await openManagement(tester);
    expect(
      tester.widget<ListTile>(keyed('community-management-voice')).enabled,
      isTrue,
    );
    usable = false;
    container(tester).invalidate(voiceCapability);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListTile>(keyed('community-management-voice')).enabled,
      isFalse,
    );
    expect(find.text('语音房当前不可用'), findsOneWidget);
  });

  testWidgets('pending voice evidence disables creation', (tester) async {
    await pumpCommunityPage(
      tester,
      CommunityProfileScreen(
        communityId: testCommunityId,
        onOpenVoiceRoom: (_) {},
      ),
      community: FakeCommunityGateway(detail: testDetail()),
      meta: testMetaSnapshot(
        voiceRoomEvidence: LoopV2CapabilityEvidenceStatus.pending,
      ),
    );
    await openManagement(tester);
    expect(
      tester.widget<ListTile>(keyed('community-management-voice')).enabled,
      isFalse,
    );
  });

  testWidgets('an in-flight room command disables the management voice entry', (
    tester,
  ) async {
    final voice = FakeVoiceRoomGateway()..pending = true;
    await pumpCommunityPage(
      tester,
      CommunityProfileScreen(
        communityId: testCommunityId,
        onOpenVoiceRoom: (_) {},
      ),
      community: FakeCommunityGateway(detail: testDetail()),
      voiceRoom: voice,
    );
    unawaited(
      container(tester)
          .read(voiceRoomOpenControllerProvider.notifier)
          .openRoom(testCommunityId),
    );
    await openManagement(tester);
    expect(
      tester.widget<ListTile>(keyed('community-management-voice')).enabled,
      isFalse,
    );
    expect(voice.commands.where((c) => c.startsWith('create:')), hasLength(1));
  });

  testWidgets(
    'voice uses confirmation and does not claim failed creation succeeded',
    (tester) async {
      final voice = FakeVoiceRoomGateway(
        createFailure: CommunityFailureKind.permissionDenied,
      );
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        CommunityProfileScreen(
          communityId: testCommunityId,
          onOpenVoiceRoom: opened.add,
        ),
        community: FakeCommunityGateway(detail: testDetail()),
        voiceRoom: voice,
      );
      await openManagement(tester);
      await tester.tap(keyed('community-management-voice'));
      await tester.pumpAndSettle();
      expect(keyed('community-open-voice-room-sheet'), findsOneWidget);
      expect(voice.commands.where((c) => c.startsWith('create:')), isEmpty);
      await tester.tap(keyed('community-confirm-accept'));
      await tester.pumpAndSettle();
      expect(voice.commands, contains('create:$testCommunityId'));
      expect(opened, isEmpty);
      expect(find.text('语音房已开启'), findsNothing);
    },
  );

  testWidgets('live voice reuses the room callback without creating another', (
    tester,
  ) async {
    final voice = FakeVoiceRoomGateway(
      snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
    );
    final opened = <String>[];
    await pumpCommunityPage(
      tester,
      CommunityProfileScreen(
        communityId: testCommunityId,
        onOpenVoiceRoom: opened.add,
      ),
      community: FakeCommunityGateway(detail: testDetail(voice: testVoiceLive)),
      voiceRoom: voice,
    );
    await openManagement(tester);
    await tester.tap(keyed('community-management-voice'));
    await tester.pumpAndSettle();
    expect(opened, <String>[testCommunityId]);
    expect(voice.commands.where((c) => c.startsWith('create:')), isEmpty);
  });
}
