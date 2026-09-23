// S77d · the two voice room pages, laid out the way the frozen prototype
// lays them out.
//
// The 2026-09-23 walkthrough read the voice room as the page furthest from
// `docs/prototype/screens/voiceroom.html` and `voiceroom-full.html`: a table
// of five figures on both views, two paragraphs repeating each other under
// it, a hero whose count and a top bar whose counts disagreed because neither
// of them held the host, a bare `ENDED`, and a lobby that said it could not
// read the room above a block that said there was none. One test per
// difference, so a regression is named rather than measured.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';

LoopFolioPrimary _folio(WidgetTester tester) =>
    tester.widget<LoopFolioPrimary>(find.byType(LoopFolioPrimary));

/// The room the review devices had: a host, three speakers, forty-two
/// listeners, forty-six in the room.
FakeVoiceRoomGateway _gateway({
  VoiceRoomRole? role = VoiceRoomRole.listener,
  bool host = false,
  VoiceRoomState state = VoiceRoomState.live,
  VoiceRoomHandRaise? handRaise,
  List<VoiceRoomMember> speakers = const <VoiceRoomMember>[],
  List<VoiceRoomMember> listeners = const <VoiceRoomMember>[],
  List<VoiceRoomHandRaiseEntry> handRaises = const <VoiceRoomHandRaiseEntry>[],
}) =>
    FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(
          role: role,
          host: host,
          state: state,
          handRaise: handRaise,
        ),
        handRaises: handRaises,
      )
      ..rosters = <VoiceRoomRosterView, VoiceRoomMemberPage>{
        VoiceRoomRosterView.speaker: testVoiceRoomMemberPage(
          view: VoiceRoomRosterView.speaker,
          items: speakers,
        ),
        VoiceRoomRosterView.listener: testVoiceRoomMemberPage(
          view: VoiceRoomRosterView.listener,
          items: listeners,
        ),
      };

/// The blocks the lobby used to carry and the prototype never had.
const _removedBlocks = <String>[
  'voiceroom-live',
  'voiceroom-observed',
  'voiceroom-joined',
  'voiceroom-role-intent',
  'voiceroom-role',
  'voiceroom-back-note',
];

void main() {
  group('S77d · the three figures of a room add up', () {
    test('the host is counted as one of the people who may be heard', () {
      final headcount = VoiceRoomHeadcount.of(testVoiceRoomSnapshot());
      expect(headcount.inRoom, 46);
      // 3 speakers + the host. The server's own `speakerCount` is 3 and does
      // not carry the host at all (decision 0051).
      expect(headcount.speaking, 4);
      expect(headcount.listening, 42);
      expect(headcount.speaking + headcount.listening, headcount.inRoom);
    });

    test('a room with only a host is one person, on the microphone', () {
      final snapshot = testVoiceRoomSnapshot(
        role: VoiceRoomRole.host,
        host: true,
        joinedCount: 1,
      );
      // The review device's own room: 「1 人在房间里」 used to stand over
      // 「发言 0 · 听众 0」, and then the 正在发言 grid showed the host.
      expect(VoiceRoomHeadcount.of(snapshot).inRoom, 1);
      expect(voiceRoomTopbarLine(snapshot), isNot(contains('发言 0')));
    });

    test('a total the server withheld is counted from the roles', () {
      final headcount = VoiceRoomHeadcount.of(
        testVoiceRoomSnapshot(joinedCount: null),
      );
      expect(headcount.inRoom, 46);
      expect(headcount.speaking, 4);
    });

    test('a total below its own parts never produces a negative figure', () {
      // Nothing in the contract produces this; a client that divides one
      // count by another still must not print 「发言 -6」.
      final headcount = VoiceRoomHeadcount.of(
        testVoiceRoomSnapshot(joinedCount: 36),
      );
      expect(headcount.speaking, greaterThanOrEqualTo(3));
    });
  });

  group('S77d · the lobby is `#scr-voiceroom`', () {
    testWidgets('a listener gets the grid, the count and the three controls', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _gateway(),
      );

      final folio = _folio(tester);
      expect(folio.kicker, 'VOICE LOBBY');
      expect(folio.heading, '46 人在房间里');
      expect(folio.stamp, '46 LIVE');
      expect(find.text('进行中 · 发言 4 · 听众 42'), findsOneWidget);
      expect(find.text('正在发言'), findsOneWidget);
      expect(find.text('听众 42'), findsOneWidget);

      final leave = find.byKey(const ValueKey<String>('voiceroom-leave'));
      await scrollToCommunitySection(tester, leave);
      expect(leave, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-raise-hand')),
        findsOneWidget,
      );
      // `#scr-voiceroom` closes on one `.notice` about the provider.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-provider-note')),
        findsOneWidget,
      );
      expect(find.byType(LoopNotice), findsOneWidget);
    });

    testWidgets('the table of figures and the repeated notes are gone', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _gateway(),
      );

      for (final key in _removedBlocks) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing);
      }
      expect(find.text('返回不等于离开'), findsNothing);
      expect(find.textContaining('由 LOOP 授予'), findsNothing);
      expect(find.textContaining('服务商允许进入的账号'), findsNothing);
      // The one line 「返回不等于离开」 was a whole notice for is in the hero.
      expect(_folio(tester).caption, '返回会把房间收起在顶部，随时点开回来。');
    });

    testWidgets('the host is given 结束房间, not a paragraph about 离开', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _gateway(role: VoiceRoomRole.host, host: true),
      );

      final end = find.byKey(const ValueKey<String>('voiceroom-end'));
      await scrollToCommunitySection(tester, end);
      expect(end, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-leave')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-host-no-leave')),
        findsNothing,
      );
      // The host's controls belong to the session page (`voiceroom-full`).
      expect(
        find.byKey(const ValueKey<String>('voiceroom-host-controls')),
        findsNothing,
      );
    });

    testWidgets('a reader who has not joined is told what to check first', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _gateway(role: null),
      );

      expect(_folio(tester).caption, '进入前确认主持人、在线人数与录音说明。');
      expect(
        find.byKey(const ValueKey<String>('voiceroom-join')),
        findsOneWidget,
      );
    });

    testWidgets('an ended room says so in words, and asks nothing', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _gateway(state: VoiceRoomState.ended),
      );

      final folio = _folio(tester);
      expect(folio.heading, '已结束');
      // 「ENDED」 was the one bare English word standing for a state.
      expect(folio.stamp, '已结束');
      expect(find.text('ENDED'), findsNothing);
      expect(folio.caption, '主持人已经结束这个语音房。');
      // The pre-entry checklist belongs to a room somebody can still enter.
      expect(find.textContaining('进入前确认'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-ended')),
        findsOneWidget,
      );
    });
  });

  group('S77d · the hero and the block under it are one answer', () {
    testWidgets('a community with no live room says so in both places', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          notLiveReasonCode: 'COMMUNITY_VOICE_ROOM_NOT_LIVE',
        ),
      );

      final folio = _folio(tester);
      expect(folio.heading, '当前没有语音房');
      expect(folio.caption, '这个社区现在没有进行中的语音房。');
      expect(folio.stamp, isNull);
      expect(find.text('当前没有进行中的语音房'), findsOneWidget);
      // The sentence that contradicted the block under it.
      expect(find.textContaining('语音房状态'), findsNothing);
    });

    testWidgets('a read that failed says that, and only that', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          failure: CommunityFailureKind.unexpected,
        ),
      );

      final folio = _folio(tester);
      expect(folio.heading, '语音房状态读不到');
      expect(folio.caption, '这次没有读到语音房的状态，下面可以重试。');
      expect(find.text('当前没有进行中的语音房'), findsNothing);
    });
  });

  group('S77d · the session page is `#scr-voiceroom-full`', () {
    testWidgets('the host gets the speakers, the queue and the controls', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: _gateway(
          role: VoiceRoomRole.host,
          host: true,
          speakers: <VoiceRoomMember>[
            testVoiceRoomMember(
              view: VoiceRoomRosterView.speaker,
              alias: 'pepe_maxi',
              muted: true,
              commands: const <VoiceRoomMemberCommand>[
                VoiceRoomMemberCommand.removeSpeaker,
                VoiceRoomMemberCommand.unmute,
              ],
            ),
          ],
          handRaises: <VoiceRoomHandRaiseEntry>[
            testHandRaiseEntry(alias: 'fox_trader', sequence: '3'),
          ],
        ),
      );

      final folio = _folio(tester);
      expect(folio.kicker, 'VOICE SESSION');
      // `#scr-voiceroom-full` opens on 「13 人在麦上」.
      expect(folio.heading, '4 人在麦上');
      expect(folio.stamp, 'ON AIR');

      // 发言人, and the host on it: LOOP's roster never carries the host.
      expect(find.text('发言人 4'), findsOneWidget);
      final hostRow = find.byKey(
        const ValueKey<String>('voiceroom-speaker-host'),
      );
      await scrollToCommunitySection(tester, hostRow);
      expect(hostRow, findsOneWidget);
      expect(tester.widget<LoopRecordRow>(hostRow).subtitle, '主持人');
      expect(find.text('已静音'), findsOneWidget);

      // 举手队列, with the position on the row.
      final queue = find.text('举手队列 1');
      await scrollToCommunitySection(tester, queue);
      expect(queue, findsOneWidget);
      expect(find.textContaining('第 3 位 · 等待邀请'), findsOneWidget);

      // 主持人控制, and the exit under it.
      final controls = find.byKey(
        const ValueKey<String>('voiceroom-host-controls'),
      );
      await scrollToCommunitySection(tester, controls);
      expect(controls, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-mute-all')),
        findsOneWidget,
      );
      final listeners = find.text('听众 42');
      await scrollToCommunitySection(tester, listeners);
      expect(listeners, findsOneWidget);
      final end = find.byKey(const ValueKey<String>('voiceroom-end'));
      await scrollToCommunitySection(tester, end);
      expect(end, findsOneWidget);
    });

    testWidgets('a listener sees the room and none of the host controls', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: _gateway(
          handRaise: VoiceRoomHandRaise(
            handRaiseId: testRequestId,
            sequence: '2',
            state: VoiceRoomHandRaiseState.pending,
            createdAt: DateTime.utc(2026, 9, 8, 12, 20),
          ),
          speakers: <VoiceRoomMember>[
            testVoiceRoomMember(
              view: VoiceRoomRosterView.speaker,
              alias: 'pepe_maxi',
            ),
          ],
        ),
      );

      expect(_folio(tester).heading, '4 人在麦上');
      // The room has a host and this reader is not it: the row states the
      // one thing that is certain, and names nobody.
      final hostRow = find.byKey(
        const ValueKey<String>('voiceroom-speaker-host'),
      );
      await scrollToCommunitySection(tester, hostRow);
      expect(tester.widget<LoopRecordRow>(hostRow).title, '主持人');

      final own = find.byKey(const ValueKey<String>('voiceroom-queue-self'));
      await scrollToCommunitySection(tester, own);
      expect(tester.widget<LoopRecordRow>(own).subtitle, '第 2 位 · 等待邀请');
      // The whole queue is a host read: a listener has no figure for it, and
      // 「举手队列 0」 over 「第 2 位」 would be one more contradiction.
      expect(find.text('举手队列'), findsOneWidget);

      expect(
        find.byKey(const ValueKey<String>('voiceroom-host-controls')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-mute-all')),
        findsNothing,
      );
      final cancel = find.byKey(
        const ValueKey<String>('voiceroom-cancel-hand'),
      );
      await scrollToCommunitySection(tester, cancel);
      expect(cancel, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-leave')),
        findsOneWidget,
      );
      // The session page carries no provider note: `#scr-voiceroom-full` has
      // none, and the lobby already said it.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-provider-note')),
        findsNothing,
      );
    });

    testWidgets('a room whose only voice is the host is not an empty list', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: _gateway(role: VoiceRoomRole.host, host: true),
      );

      final hostRow = find.byKey(
        const ValueKey<String>('voiceroom-speaker-host'),
      );
      await scrollToCommunitySection(tester, hostRow);
      expect(hostRow, findsOneWidget);
      expect(tester.widget<LoopRecordRow>(hostRow).title, '我');
      expect(
        find.byKey(const ValueKey<String>('voiceroom-roster-speaker-empty')),
        findsNothing,
      );
      // The listener view is read and empty, which is a different answer.
      final empty = find.byKey(
        const ValueKey<String>('voiceroom-roster-listener-empty'),
      );
      await scrollToCommunitySection(tester, empty);
      expect(empty, findsOneWidget);
    });
  });
}
