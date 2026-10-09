// S121f (decision 0127): the community, voice-room and social secondary pages
// in the OKX shape — structure keys, the five states, the main action, and
// the copy rules (no Emoji, no English eyebrow, no 「没有更多」).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_stage.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_manage_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/connections_screen.dart';
import 'package:loop_mobile/features/social/dm_requests_screen.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_round_key.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';

final RegExp _emoji = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F000}-\u{1F2FF}]',
  unicode: true,
);

/// Words the decision took off these pages.
const List<String> _retired = <String>[
  '没有更多',
  'COMMUNITY RECORD',
  'MEMBER DIRECTORY',
  'MANAGE',
  'SOCIAL CONNECTIONS',
  'MESSAGE REQUESTS',
  'DISCOVERY DESK',
  'NEW GROUP',
  'VOICE LOBBY',
];

/// Every string on screen: no Emoji, no retired word, and no all-caps
/// English eyebrow.
void _expectCleanCopy(WidgetTester tester) {
  final strings = <String>[
    for (final widget in tester.widgetList<Text>(find.byType(Text)))
      widget.data ?? widget.textSpan?.toPlainText() ?? '',
    for (final widget in tester.widgetList<RichText>(find.byType(RichText)))
      widget.text.toPlainText(),
  ];
  for (final text in strings) {
    expect(_emoji.hasMatch(text), isFalse, reason: 'Emoji in 「$text」');
    for (final word in _retired) {
      expect(text.contains(word), isFalse, reason: '「$word」 in 「$text」');
    }
    expect(
      RegExp(r'^[A-Z][A-Z ]{5,}$').hasMatch(text.trim()),
      isFalse,
      reason: 'English eyebrow 「$text」',
    );
  }
}

Finder _key(String value) => find.byKey(ValueKey<String>(value));

void main() {
  group('S121f · community-profile', () {
    testWidgets('header, round keys and sections for an owner', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        size: const Size(390, 2400),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: testCommunity(
              boundAssetKey:
                  'eip155:56:0x00000000000000000000000000000000000000aa',
            ),
            chat: testChatAvailable,
          ),
          members: testDirectory(),
        ),
      );

      // Header: the logo at 72, the name at 22, verification as a mark.
      expect(
        tester.getSize(_key('community-profile-logo')),
        const Size(72, 72),
      );
      expect(
        tester.widget<Text>(_key('community-profile-name')).style?.fontSize,
        22,
      );
      expect(_key('community-profile-verification'), findsOneWidget);
      expect(find.text('已验证'), findsOneWidget);
      // Four round keys for an owner: 进群聊 / 语音房 / 分享 / 管理, each a 56
      // disc with its word under it.
      final keys = find.descendant(
        of: _key('community-profile-keys'),
        matching: find.byType(LoopRoundKey),
      );
      expect(keys, findsNWidgets(4));
      for (final label in <String>['进群聊', '开语音房', '分享', '管理']) {
        expect(
          find.descendant(of: keys, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      expect(
        tester
            .widget<LoopRoundKey>(_key('community-profile-open-chat'))
            .onPressed,
        isNotNull,
      );
      // 绑定代币 is one quote row; 成员 a strip with 查看全部; 社区 AI a row.
      expect(_key('community-bound-asset'), findsOneWidget);
      expect(_key('community-profile-open-members'), findsOneWidget);
      expect(_key('community-profile-member-strip'), findsOneWidget);
      expect(_key('community-profile-open-ai'), findsOneWidget);
      // A member's page draws no join bar.
      expect(_key('community-join-action'), findsNothing);
      // No top-bar action at all; the bar is 返回 + 社区.
      expect(_key('community-profile-share'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LoopTopbar),
          matching: find.byType(LoopIconButton),
        ),
        findsNothing,
      );
      _expectCleanCopy(tester);
    });

    testWidgets('a reader who has not joined gets the full-width 加入社区', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(viewer: testViewer(role: null)),
        ),
      );

      final join = _key('community-join-action');
      expect(join, findsOneWidget);
      expect(tester.widget<LoopWideButton>(join).label, '加入社区');
      expect(tester.getSize(join).height, 52);
      expect(_key('community-profile-manage'), findsNothing);
      // Without membership the directory is not read and no strip drawn.
      expect(_key('community-profile-member-strip'), findsNothing);
      await tester.tap(join);
      await tester.pumpAndSettle();
      expect(_key('community-membership-sheet'), findsOneWidget);
    });

    testWidgets('loading is a skeleton', (tester) async {
      final pending = FakeCommunityGateway()..pending = true;
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: pending,
        settle: false,
      );
      expect(find.byType(LoopSkeleton), findsWidgets);
    });

    testWidgets('offline, error, permission and unavailable', (tester) async {
      for (final (kind, key) in <(CommunityFailureKind, String)>[
        (CommunityFailureKind.offline, 'community-state-offline'),
        (CommunityFailureKind.invalidData, 'community-state-error'),
        (CommunityFailureKind.permissionDenied, 'community-state-permission'),
        (CommunityFailureKind.unavailable, 'community-state-unavailable'),
      ]) {
        await pumpCommunityPage(
          tester,
          const CommunityProfileScreen(communityId: testCommunityId),
          community: FakeCommunityGateway(failure: kind),
        );
        expect(_key(key), findsOneWidget, reason: kind.name);
      }
    });
  });

  group('S121f · community-members', () {
    testWidgets('OKX rows: a 36 face, the role mark, 管理 on the right', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          members: testDirectory(
            items: <CommunityMemberEntry>[
              testMember(role: CommunityRole.admin, alias: 'frog_admin'),
              testMember(
                role: CommunityRole.member,
                publicProfileId: 'pp-member-2',
                alias: 'frog_member',
              ),
            ],
          ),
        ),
      );

      final row = _key('member-row-$testMemberId');
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
      expect(
        find.descendant(of: row, matching: find.text('Admin')),
        findsOneWidget,
      );
      expect(_key('member-manage-$testMemberId'), findsOneWidget);
      expect(find.byType(LoopFolioPrimary), findsNothing);
      _expectCleanCopy(tester);
    });

    testWidgets('an empty filter is the centred members drawing', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          members: testDirectory(items: const <CommunityMemberEntry>[]),
        ),
      );
      expect(find.byType(LoopEmptyState), findsOneWidget);
      expect(_key('loop-empty-illustration-members'), findsOneWidget);
    });

    testWidgets('offline, error and permission stay distinct', (tester) async {
      for (final (kind, key) in <(CommunityFailureKind, String)>[
        (CommunityFailureKind.offline, 'community-state-offline'),
        (CommunityFailureKind.invalidData, 'community-state-error'),
        (CommunityFailureKind.permissionDenied, 'community-state-permission'),
      ]) {
        await pumpCommunityPage(
          tester,
          const CommunityMembersScreen(communityId: testCommunityId),
          community: FakeCommunityGateway(failure: kind),
        );
        expect(_key(key), findsOneWidget, reason: kind.name);
      }
    });
  });

  group('S121f · community-manage', () {
    testWidgets('three sections of entry rows, no hero card', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        size: const Size(390, 2000),
        community: FakeCommunityGateway(
          detail: testDetail(),
          members: testDirectory(),
        ),
      );

      expect(_key('community-manage-header'), findsOneWidget);
      for (final title in <String>['资料', '成员', '语音房']) {
        expect(
          find.widgetWithText(LoopSectionTitle, title),
          findsOneWidget,
          reason: title,
        );
      }
      for (final key in <String>[
        'community-manage-edit-profile',
        'community-manage-members',
        'community-manage-voice-open',
      ]) {
        expect(
          tester.widget<LoopPersonRow>(_key(key)).chevron,
          isTrue,
          reason: key,
        );
      }
      expect(find.byType(LoopFolioPrimary), findsNothing);
      _expectCleanCopy(tester);
    });

    testWidgets('a member without the right is told so', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(viewer: testViewer(role: CommunityRole.member)),
        ),
      );
      expect(_key('community-manage-permission'), findsOneWidget);
    });
  });

  group('S121f · voice room', () {
    testWidgets('host 88, 「主持」, round keys with the end key in fall', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
        ),
      );

      final host = _key('voiceroom-host');
      expect(host, findsOneWidget);
      expect(voiceRoomHostAvatar, 88);
      expect(voiceRoomSpeakerAvatar, 56);
      expect(voiceRoomListenerAvatar, 44);
      expect(voiceRoomSpeakerColumns, 4);
      expect(voiceRoomListenerColumns, 5);
      // The bar: four 56 round keys, 结束 on the fall colour.
      final bar = _key('voiceroom-control-bar');
      expect(
        find.descendant(of: bar, matching: find.byType(LoopRoundKey)),
        findsNWidgets(4),
      );
      final end = find.descendant(
        of: _key('voiceroom-end'),
        matching: find.byType(LoopRoundKey),
      );
      expect(tester.widget<LoopRoundKey>(end).tone, LoopRoundKeyTone.fall);
      // The top bar: one icon (分享); the room's (i) is on the stage.
      expect(
        find.descendant(
          of: _key('voiceroom-topbar'),
          matching: find.byKey(const ValueKey<String>('voiceroom-info')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: host, matching: find.byType(LoopIconButton)),
        findsNothing,
      );
      expect(_key('voiceroom-info'), findsOneWidget);
      expect(find.textContaining(' 在听 · '), findsOneWidget);
      _expectCleanCopy(tester);
    });

    testWidgets('empty grids are the compact drawings', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
        ),
      );
      final speakers = _key('voiceroom-speakers-empty');
      await tester.scrollUntilVisible(
        speakers,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<LoopEmptyState>(speakers).compact, isTrue);
    });

    test('the live line counts the room and its age', () {
      final opened = DateTime.utc(2026, 10, 9, 10);
      expect(
        voiceRoomLiveLine(
          inRoom: 12,
          openedAt: opened,
          now: opened.add(const Duration(minutes: 23)),
        ),
        '12 在听 · 开播 23 分钟',
      );
      expect(
        voiceRoomLiveLine(
          inRoom: 3,
          openedAt: opened,
          now: opened.subtract(const Duration(minutes: 1)),
        ),
        '3 在听 · 刚开播',
      );
    });
  });

  group('S121f · connections and requests', () {
    testWidgets('a connection row is 56 tall with a 40 face and a capsule', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: FakeSocialGateway(
          connections: ConnectionPage(
            direction: ConnectionDirection.following,
            items: <ConnectionEntry>[
              ConnectionEntry(
                profile: testProfile(
                  publicProfileId: testMemberId,
                  alias: 'frog_member',
                ),
                createdAt: DateTime.utc(2026, 8),
                viewerFollows: false,
                miningPower: testMiningPower,
              ),
            ],
            counts: const ConnectionCounts(following: 1, followers: 0),
            nextCursor: null,
          ),
        ),
      );

      final row = _key('connection-row-$testMemberId');
      expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
      final follow = _key('connection-follow-$testMemberId');
      expect(tester.widget<LoopPillAction>(follow).label, '关注');
      expect(tester.widget<LoopPillAction>(follow).primary, isTrue);
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(_key('connections-follow-sheet'), findsOneWidget);
      expect(find.byType(LoopFolioPrimary), findsNothing);
      _expectCleanCopy(tester);
    });

    testWidgets('an empty list is the friends drawing', (tester) async {
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: FakeSocialGateway(
          connections: const ConnectionPage(
            direction: ConnectionDirection.following,
            items: <ConnectionEntry>[],
            counts: ConnectionCounts(following: 0, followers: 0),
            nextCursor: null,
          ),
        ),
      );
      expect(_key('loop-empty-illustration-friends'), findsOneWidget);
    });

    testWidgets('a request row ends in the Lime 接受', (tester) async {
      final gateway = FakeSocialGateway(
        requests: MessageRequestPage(
          items: <MessageRequestEntry>[
            MessageRequestEntry(
              messageRequestId: testRequestId,
              profile: testProfile(alias: 'fox_trader'),
              createdAt: DateTime.utc(2026, 9, 7),
              expiresAt: DateTime.utc(2026, 9, 14),
              preview: const LoopUnavailableFact('MESSAGE_PREVIEW_DEFERRED'),
              aiModeration: const LoopUnavailableFact('AI_MODERATION_DEFERRED'),
            ),
          ],
          nextCursor: null,
        ),
      );
      await pumpCommunityPage(
        tester,
        const MessageRequestsScreen(),
        social: gateway,
      );

      final accept = _key('dm-request-accept-$testRequestId');
      expect(tester.widget<LoopPillAction>(accept).label, '接受');
      await tester.tap(accept);
      await tester.pumpAndSettle();
      await tester.tap(_key('community-confirm-accept'));
      await tester.pumpAndSettle();
      expect(gateway.commands, contains('decision:$testRequestId:accept'));
      _expectCleanCopy(tester);
    });

    testWidgets('requests: offline and error stay distinct', (tester) async {
      for (final (kind, key) in <(CommunityFailureKind, String)>[
        (CommunityFailureKind.offline, 'community-state-offline'),
        (CommunityFailureKind.invalidData, 'community-state-error'),
      ]) {
        await pumpCommunityPage(
          tester,
          const MessageRequestsScreen(),
          social: FakeSocialGateway(failure: kind),
        );
        expect(_key(key), findsOneWidget, reason: kind.name);
      }
    });
  });

  group('S121f · 创建社区', () {
    testWidgets('logo 72, 52 fields and one Lime button', (tester) async {
      await pumpCommunityPage(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showCommunityApplySheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(_key('community-apply-sheet'), findsOneWidget);
      expect(
        tester.getSize(_key('community-apply-logo-empty')),
        const Size(72, 72),
      );
      for (final key in <String>[
        'community-apply-name',
        'community-apply-slug',
        'community-apply-asset-key',
      ]) {
        expect(
          tester.getSize(_key(key)).height,
          greaterThanOrEqualTo(52),
          reason: key,
        );
      }
      expect(
        tester.widget<LoopWideButton>(_key('community-apply-submit')).label,
        '提交申请',
      );
      // Picking a mark puts it in the 72 slot.
      await tester.tap(_key('community-apply-logo-avatar:preset/community-03'));
      await tester.pumpAndSettle();
      expect(
        _key('community-apply-logo-preview-avatar:preset/community-03'),
        findsOneWidget,
      );
      _expectCleanCopy(tester);
    });
  });
}
