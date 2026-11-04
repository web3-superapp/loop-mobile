// S355c · decision 0281: 360 x 800 English renders of the chat and social
// pages after their copy moved to ARB, to read truncation and wrapping.
//
// Not a check: it writes renders to `LOOP_SHOTS_DIR`. It runs only with
// `--dart-define=LOOP_SHOTS=true`; a plain `flutter test` skips every case
// and writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/chat_search_screen.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/features/chat/v2/group_screens.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/social/blocklist_screen.dart';
import 'package:loop_mobile/features/social/connections_screen.dart';
import 'package:loop_mobile/features/social/dm_requests_screen.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

import 'support/community_test_harness.dart';
import 'support/communication_test_harness.dart';
import 'support/loop_shots.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'docs/integration/S355c/shots',
);

const Size _size = Size(360, 800);

Future<void> _shot(WidgetTester tester, String name) =>
    loopShot(tester, 'S355c-$name', slice: _size.height, dir: _dir);

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  FakeSocialGateway? social,
  FakeVoiceRoomGateway? voiceRoom,
}) async {
  await tester.runAsync(loopLoadShotFonts);
  await pumpCommunityPage(
    tester,
    page,
    size: _size,
    chat: FakeChatV2Gateway(),
    social: social,
    voiceRoom: voiceRoom,
    groupAliasResolver: FakeGroupAliasResolverGateway(),
  );
}

void main() {
  testWidgets('voice room lobby', skip: !_shots, (tester) async {
    await _pump(
      tester,
      const VoiceRoomScreen(communityId: testCommunityId),
      voiceRoom: FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot()),
    );
    await _shot(tester, 'voice-room');
  });

  testWidgets('voice room · empty', skip: !_shots, (tester) async {
    await _pump(
      tester,
      const VoiceRoomScreen(communityId: testCommunityId),
      voiceRoom: FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(state: VoiceRoomState.ended),
      ),
    );
    await _shot(tester, 'voice-room-ended');
  });

  testWidgets('direct message', skip: !_shots, (tester) async {
    await _pump(
      tester,
      const DirectMessageScreen(channelCid: 'messaging:loop_direct_8e7d73c5'),
    );
    await _shot(tester, 'dm');
  });

  testWidgets('chat search', skip: !_shots, (tester) async {
    await _pump(tester, ChatSearchScreen(originCid: testGroupCid));
    await _shot(tester, 'chat-search');
  });

  testWidgets('group info', skip: !_shots, (tester) async {
    await _pump(tester, GroupInfoScreen(channelCid: testGroupCid));
    await _shot(tester, 'group-info');
  });

  testWidgets('connections', skip: !_shots, (tester) async {
    await _pump(
      tester,
      const ConnectionsScreen(),
      social: FakeSocialGateway(
        connections: ConnectionPage(
          direction: ConnectionDirection.following,
          items: <ConnectionEntry>[
            ConnectionEntry(
              profile: testProfile(
                publicProfileId: testMemberId,
                loopId: 'LOOP-3HJKMNPQ',
                alias: 'frog_member',
              ),
              createdAt: DateTime.utc(2026, 8),
              viewerFollows: true,
              miningPower: testMiningPower,
            ),
          ],
          counts: const ConnectionCounts(following: 24, followers: 108),
          nextCursor: null,
        ),
      ),
    );
    await _shot(tester, 'connections');
  });

  testWidgets('block list', skip: !_shots, (tester) async {
    await _pump(
      tester,
      const BlocklistScreen(),
      social: FakeSocialGateway(
        blocks: BlockPage(
          kind: BlockKind.user,
          items: <BlockEntry>[
            BlockEntry(
              kind: BlockKind.user,
              stableId: testMemberId,
              profile: testProfile(
                publicProfileId: testMemberId,
                alias: 'spam_bot',
              ),
              reasonCode: 'message_request_report',
              createdAt: DateTime.utc(2026, 8, 20),
            ),
          ],
          userCount: 1,
          nextCursor: null,
        ),
      ),
    );
    await _shot(tester, 'blocklist');
  });

  testWidgets('message requests', skip: !_shots, (tester) async {
    await _pump(
      tester,
      const MessageRequestsScreen(),
      social: FakeSocialGateway(
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
      ),
    );
    await _shot(tester, 'message-requests');
  });
}
