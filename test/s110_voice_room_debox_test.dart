// S110 · the voice room relaid out after DeBox (decision 0115).
//
// The host on a stage, the speakers four to a row, the listeners six to a
// row with a 「+N」 after eighteen, and the controls in a bar fixed at the
// bottom — one bar per part LOOP granted. The plaza card names the room by
// its title and stacks the host and the speakers. The 开播 sheet sends the
// title, and nothing when it was left empty.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_foreground_call_view.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_presentation.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_stage.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/square/live_voice_rooms.dart';
import 'package:loop_mobile/features/square/square_screen.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_live_voice_rooms.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';

const _listenerId = 'c0a8012e-0000-4000-8000-0000000000';

/// [count] listener rows, each with its own address.
List<VoiceRoomMember> _listeners(int count) => <VoiceRoomMember>[
  for (var index = 0; index < count; index += 1)
    testVoiceRoomMember(
      view: VoiceRoomRosterView.listener,
      publicProfileId: '$_listenerId${index.toString().padLeft(2, '0')}',
      alias: 'listener_$index',
    ),
];

FakeVoiceRoomGateway _room({
  VoiceRoomRole? role = VoiceRoomRole.listener,
  bool host = false,
  String? title,
  List<VoiceRoomMember> speakers = const <VoiceRoomMember>[],
  List<VoiceRoomMember> listeners = const <VoiceRoomMember>[],
  String? listenerCursor,
  CommunityFailureKind? rosterFailure,
  VoiceRoomPerson? hostPerson,
}) {
  final snapshot = testVoiceRoomSnapshot(role: role, host: host);
  final titled = VoiceRoomSnapshot(
    room: VoiceRoomRecord(
      voiceRoomId: snapshot.room.voiceRoomId,
      communityId: snapshot.room.communityId,
      communityName: snapshot.room.communityName,
      callCid: snapshot.room.callCid,
      state: snapshot.room.state,
      provisionState: snapshot.room.provisionState,
      backstage: snapshot.room.backstage,
      createdAt: snapshot.room.createdAt,
      endedAt: snapshot.room.endedAt,
      title: title,
    ),
    viewer: snapshot.viewer,
    participants: snapshot.participants,
    providerSync: snapshot.providerSync,
    host: hostPerson,
  );
  return FakeVoiceRoomGateway(snapshot: titled)
    ..rosterFailure = rosterFailure
    ..rosters = <VoiceRoomRosterView, VoiceRoomMemberPage>{
      VoiceRoomRosterView.speaker: testVoiceRoomMemberPage(
        view: VoiceRoomRosterView.speaker,
        items: speakers,
      ),
      VoiceRoomRosterView.listener: testVoiceRoomMemberPage(
        view: VoiceRoomRosterView.listener,
        items: listeners,
        nextCursor: listenerCursor,
      ),
    };
}

Finder _inBar(String key) => find.descendant(
  of: find.byKey(const ValueKey<String>('voiceroom-control-bar')),
  matching: find.byKey(ValueKey<String>(key)),
);

void main() {
  group('S110 · the bottom bar has one shape per part', () {
    testWidgets('a listener: 举手 and 离开', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room(),
      );

      expect(_inBar('voiceroom-raise-hand'), findsOneWidget);
      expect(_inBar('voiceroom-leave'), findsOneWidget);
      expect(_inBar('voiceroom-bar-mic'), findsNothing);
      expect(_inBar('voiceroom-step-down'), findsNothing);
      expect(_inBar('voiceroom-end'), findsNothing);
      // Every slot is a target a thumb can hit.
      final slot = tester.getSize(_inBar('voiceroom-raise-hand'));
      expect(slot.height, greaterThanOrEqualTo(44));
      expect(slot.width, greaterThanOrEqualTo(44));
    });

    testWidgets('a listener with a hand up is offered 取消举手', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(
          handRaise: VoiceRoomHandRaise(
            handRaiseId: testRequestId,
            sequence: '2',
            state: VoiceRoomHandRaiseState.pending,
            createdAt: DateTime.utc(2026, 9, 8, 12, 20),
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      expect(_inBar('voiceroom-cancel-hand'), findsOneWidget);
      await tester.tap(_inBar('voiceroom-cancel-hand'));
      await tester.pumpAndSettle();
      expect(voice.commands, contains('cancel-hand-raise'));
    });

    testWidgets('a speaker: 麦克风, 下麦 and 离开; 下麦 steps down', (tester) async {
      final voice = _room(role: VoiceRoomRole.speaker);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      expect(_inBar('voiceroom-bar-mic'), findsOneWidget);
      expect(_inBar('voiceroom-step-down'), findsOneWidget);
      expect(_inBar('voiceroom-leave'), findsOneWidget);
      expect(_inBar('voiceroom-raise-hand'), findsNothing);
      // No call on the page: the slot says so and cannot be pressed.
      expect(
        find.descendant(
          of: _inBar('voiceroom-bar-mic'),
          matching: find.text('未连接'),
        ),
        findsOneWidget,
      );

      // The server answers with the room, this account a listener now.
      voice.snapshot = testVoiceRoomSnapshot();
      await tester.tap(_inBar('voiceroom-step-down'));
      await tester.pumpAndSettle();
      expect(voice.commands, contains('step-down'));
      expect(find.text('已下麦，回到听众'), findsOneWidget);
      expect(_inBar('voiceroom-raise-hand'), findsOneWidget);
      expect(_inBar('voiceroom-step-down'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('a server without 下麦 says so and claims nothing', (
      tester,
    ) async {
      final voice = _room(role: VoiceRoomRole.speaker);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );
      voice.failure = CommunityFailureKind.unavailable;
      await tester.tap(_inBar('voiceroom-step-down'));
      await tester.pumpAndSettle();
      expect(voice.commands, contains('step-down'));
      expect(find.text('下麦暂不可用'), findsOneWidget);
      // Still a speaker, and the control stays where it was.
      expect(_inBar('voiceroom-step-down'), findsOneWidget);
      expect(find.text('已下麦，回到听众'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('a host: 麦克风, 邀请发言, 全体静音 and 结束房间', (tester) async {
      final opened = <String>[];
      final voice = _room(role: VoiceRoomRole.host, host: true)
        ..handRaises = <VoiceRoomHandRaiseEntry>[testHandRaiseEntry()];
      await pumpCommunityPage(
        tester,
        VoiceRoomScreen(
          communityId: testCommunityId,
          onOpenExpanded: opened.add,
        ),
        voiceRoom: voice,
      );

      expect(_inBar('voiceroom-bar-mic'), findsOneWidget);
      expect(_inBar('voiceroom-invite-open'), findsOneWidget);
      expect(_inBar('voiceroom-mute-all'), findsOneWidget);
      expect(_inBar('voiceroom-end'), findsOneWidget);
      expect(_inBar('voiceroom-leave'), findsNothing);
      // The queue's count rides on 邀请发言.
      expect(
        find.descendant(
          of: _inBar('voiceroom-invite-open'),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(_inBar('voiceroom-invite-open'));
      await tester.pumpAndSettle();
      expect(opened, <String>[testCommunityId]);

      await tester.tap(_inBar('voiceroom-mute-all'));
      await tester.pumpAndSettle();
      expect(voice.commands, contains('mute-all'));

      await tester.tap(_inBar('voiceroom-end'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-end-sheet')),
        findsOneWidget,
      );
    });

    testWidgets('a reader who has not joined gets 加入语音房 alone', (tester) async {
      final voice = _room(role: null);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      expect(_inBar('voiceroom-join'), findsOneWidget);
      expect(_inBar('voiceroom-leave'), findsNothing);
      await tester.tap(_inBar('voiceroom-join'));
      await tester.pumpAndSettle();
      expect(voice.commands, contains('join'));
    });

    testWidgets('the microphone slot is the call view\'s own control', (
      tester,
    ) async {
      final media = _ProbeFactory();
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room(role: VoiceRoomRole.speaker),
        audioRoomCallFactory: media,
      );

      // The call view was asked for no tiles of its own.
      expect(media.presentations.last?.showsParticipants, isFalse);
      expect(media.presentations.last?.microphone, isNotNull);

      final publish = find.byKey(const ValueKey<String>('probe-publish'));
      await scrollToCommunitySection(tester, publish);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _inBar('voiceroom-bar-mic'),
          matching: find.text('取消静音'),
        ),
        findsOneWidget,
      );
      await tester.tap(_inBar('voiceroom-bar-mic'));
      await tester.pumpAndSettle();
      expect(media.presses, 1);
    });

    test('a view that goes away takes its control back, later', () async {
      final bridge = VoiceMicrophoneBridge();
      final owner = Object();
      var told = 0;
      bridge
        ..addListener(() => told += 1)
        ..publish(
          owner,
          const VoiceMicrophoneControl(
            label: '静音',
            open: true,
            busy: false,
            enabled: true,
          ),
          () {},
        );
      expect(told, 1);
      // Somebody else's withdrawal changes nothing.
      bridge.withdraw(Object());
      expect(bridge.control, isNotNull);
      bridge.withdraw(owner);
      expect(bridge.control, isNull);
      // Told after the teardown, not during it.
      expect(told, 1);
      await Future<void>.delayed(Duration.zero);
      expect(told, 2);
      bridge.dispose();
    });

    test('the bar\'s words follow the call view\'s states', () {
      String label({
        bool speakAgain = false,
        bool open = false,
        bool canSend = true,
        bool spent = false,
        bool retiring = false,
      }) => streamBarMicrophoneLabel(
        speakAgain: speakAgain,
        speakAgainBusy: false,
        microphoneBusy: false,
        microphoneEnabled: open,
        canSendAudio: canSend,
        speakSpent: spent,
        retiring: retiring,
      );
      expect(label(open: true), '静音');
      expect(label(), '取消静音');
      expect(label(speakAgain: true), '重新发言');
      expect(label(canSend: false), '仅收听');
      expect(label(spent: true), '不能开麦');
      expect(label(retiring: true), '正在退出');
    });
  });

  group('S110 · the three sections', () {
    testWidgets('more than fifteen listeners end on 「+N」', (tester) async {
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        VoiceRoomScreen(
          communityId: testCommunityId,
          onOpenExpanded: opened.add,
        ),
        voiceRoom: _room(listeners: _listeners(20)),
      );

      final grid = find.byKey(const ValueKey<String>('voiceroom-listeners'));
      await scrollToCommunitySection(tester, grid);
      // Fourteen faces and the count — three rows of five (decision 0127):
      // the room holds 42 listeners.
      expect(
        find.descendant(
          of: grid,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'voiceroom-listener-tile-',
                ),
          ),
        ),
        findsNWidgets(14),
      );
      expect(find.text('+28'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-listeners-more')),
      );
      await tester.pumpAndSettle();
      expect(opened, <String>[testCommunityId]);
    });

    test('fifteen or fewer are all drawn, with no count', () {
      expect(VoiceRoomListenerGrid.layout(rows: 15, total: 15, more: false), (
        faces: 15,
        more: null,
      ));
      expect(VoiceRoomListenerGrid.layout(rows: 5, total: 5, more: false), (
        faces: 5,
        more: null,
      ));
      // A roster with another page counts as more than it holds.
      expect(VoiceRoomListenerGrid.layout(rows: 15, total: 0, more: true), (
        faces: 14,
        more: 2,
      ));
      expect(voiceRoomListenerGridLimit, 15);
      expect(voiceRoomListenerColumns, 5);
    });

    testWidgets('speakers carry the microphone mark, muted with the slash', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room(
          speakers: <VoiceRoomMember>[
            testVoiceRoomMember(
              view: VoiceRoomRosterView.speaker,
              alias: 'pepe_maxi',
              muted: true,
            ),
            testVoiceRoomMember(
              view: VoiceRoomRosterView.speaker,
              publicProfileId: testAdminId,
              alias: 'fox_trader',
            ),
          ],
        ),
      );

      final grid = find.byKey(const ValueKey<String>('voiceroom-speakers'));
      expect(grid, findsOneWidget);
      expect(find.text('发言者 3'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('pepe_maxi，已静音')), findsOneWidget);
    });

    testWidgets('a roster that cannot be read says which way', (tester) async {
      for (final (kind, key) in <(CommunityFailureKind, String)>[
        (CommunityFailureKind.offline, 'offline'),
        (CommunityFailureKind.permissionDenied, 'permission'),
        (CommunityFailureKind.unavailable, 'unavailable'),
        (CommunityFailureKind.unexpected, 'error'),
      ]) {
        await pumpCommunityPage(
          tester,
          const VoiceRoomScreen(communityId: testCommunityId),
          voiceRoom: _room(rosterFailure: kind),
        );
        expect(
          find.byKey(ValueKey<String>('voiceroom-speakers-$key')),
          findsOneWidget,
          reason: '$kind',
        );
        expect(
          find.byKey(ValueKey<String>('voiceroom-listeners-$key')),
          findsOneWidget,
          reason: '$kind',
        );
      }
    });

    testWidgets('a roster still being read is a skeleton, not a 0', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room()..rosterPending = true,
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-speakers-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-listeners-loading')),
        findsOneWidget,
      );
    });

    testWidgets('the host the plaza named is on the stage', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room(),
        overrides: <Override>[
          liveVoiceRoomGatewayProvider.overrideWithValue(
            _LiveGateway(<LiveVoiceRoom>[
              _liveRoom(
                voiceRoomId: testVoiceRoomId,
                host: const LiveVoiceRoomHost(
                  publicProfileId: testOwnerId,
                  displayName: 'frog_maxi',
                  avatarRef: null,
                ),
              ),
            ]),
          ),
        ],
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('voiceroom-host')),
          matching: find.text('frog_maxi'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a plaza read without this room is read again once', (
      tester,
    ) async {
      final plaza = _LiveGateway(<LiveVoiceRoom>[
        _liveRoom(voiceRoomId: testRequestId),
      ]);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room(),
        overrides: <Override>[
          liveVoiceRoomGatewayProvider.overrideWithValue(plaza),
        ],
      );
      await tester.pumpAndSettle();
      expect(plaza.reads, 2);
    });

    testWidgets('without the plaza the host is 主持人, never a guess', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room(),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('voiceroom-host')),
          matching: find.text('主持人'),
        ),
        findsWidgets,
      );
    });
  });

  group('S110 · who is heard is never guessed', () {
    VoiceRoomMember speaker(
      String alias, {
      bool muted = false,
      bool self = false,
    }) => testVoiceRoomMember(
      view: VoiceRoomRosterView.speaker,
      alias: alias,
      muted: muted,
      isSelf: self,
    );
    const voice = AudioRoomSpeaker(
      key: 's1',
      name: 'pepe',
      isLocal: false,
      isSpeaking: true,
    );

    test('one voice with one name is that speaker', () {
      final state = voiceRoomMemberMicState(speaker('pepe'), <AudioRoomSpeaker>[
        voice,
      ]);
      expect(state.open, isTrue);
      expect(state.speaking, isTrue);
    });

    test('no match, a shared name or an anonymous row claim nothing', () {
      // Not in the call: the name may simply differ, so no slash is drawn.
      expect(
        voiceRoomMemberMicState(speaker('fox'), <AudioRoomSpeaker>[voice]).open,
        isNull,
      );
      // LOOP's own mute mark is still a fact.
      expect(
        voiceRoomMemberMicState(speaker('fox', muted: true), <AudioRoomSpeaker>[
          voice,
        ]).open,
        isFalse,
      );
      expect(
        voiceRoomMemberMicState(speaker('pepe'), <AudioRoomSpeaker>[
          voice,
        ], nameUnique: false).open,
        isNull,
      );
      expect(
        voiceRoomMemberMicState(speaker('pepe'), <AudioRoomSpeaker>[
          voice,
          const AudioRoomSpeaker(
            key: 's2',
            name: 'pepe',
            isLocal: false,
            isSpeaking: false,
          ),
        ]).open,
        isNull,
      );
      final anonymous = testVoiceRoomMember(
        view: VoiceRoomRosterView.speaker,
        publicProfileId: null,
        alias: null,
      );
      expect(
        voiceRoomMemberMicState(anonymous, <AudioRoomSpeaker>[
          const AudioRoomSpeaker(
            key: 's3',
            name: '匿名成员',
            isLocal: false,
            isSpeaking: true,
          ),
        ]).speaking,
        isFalse,
      );
    });

    test('the reader\'s own row is the local voice, either way', () {
      expect(
        voiceRoomMemberMicState(speaker('me', self: true), <AudioRoomSpeaker>[
          voice,
        ]).open,
        isFalse,
      );
      expect(
        voiceRoomMemberMicState(speaker('me', self: true), <AudioRoomSpeaker>[
          const AudioRoomSpeaker(
            key: 'local',
            name: '我',
            isLocal: true,
            isSpeaking: true,
          ),
        ]).speaking,
        isTrue,
      );
    });

    Future<void> hear(
      WidgetTester tester,
      List<AudioRoomSpeaker> speakers,
    ) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VoiceRoomScreen)),
      );
      container
          .read(audioRoomLivePresenceProvider.notifier)
          .report(
            AudioRoomLivePresence(
              roomId: testVoiceRoomSnapshot().room.roomId!,
              phase: AudioRoomLivePhase.connected,
              participantCount: 3,
              speakers: speakers,
            ),
          );
      await tester.pumpAndSettle();
    }

    Finder hostSays(String text) => find.descendant(
      of: find.byKey(const ValueKey<String>('voiceroom-host')),
      matching: find.text(text),
    );

    testWidgets('an unnamed host is not whoever else is talking', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room(),
      );
      await hear(tester, <AudioRoomSpeaker>[
        const AudioRoomSpeaker(
          key: 'x',
          name: 'stranger',
          isLocal: false,
          isSpeaking: true,
        ),
      ]);
      expect(hostSays('正在发言'), findsNothing);
      expect(hostSays('已静音'), findsNothing);
    });

    testWidgets('the room\'s own host is named, and heard by that name', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room(
          hostPerson: const VoiceRoomPerson(
            publicProfileId: testOwnerId,
            displayName: 'frog_maxi',
            avatarRef: null,
          ),
        ),
      );
      expect(hostSays('frog_maxi'), findsOneWidget);
      await hear(tester, <AudioRoomSpeaker>[
        const AudioRoomSpeaker(
          key: 'h',
          name: 'frog_maxi',
          isLocal: false,
          isSpeaking: true,
        ),
      ]);
      expect(hostSays('正在发言'), findsOneWidget);
    });
  });

  group('S110 · the room has a title', () {
    testWidgets('a room without one is the community\'s room', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room(),
      );
      final bar = find.byKey(const ValueKey<String>('voiceroom-topbar'));
      expect(
        find.descendant(
          of: bar,
          matching: find.text('$testVoiceRoomCommunityName 语音房'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.textContaining('46 在听 · ')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-community-logo')),
        findsOneWidget,
      );
    });

    testWidgets('a titled room says its title and then whose it is', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: _room(title: '周五 AMA'),
      );
      final bar = find.byKey(const ValueKey<String>('voiceroom-topbar'));
      expect(
        find.descendant(of: bar, matching: find.text('周五 AMA')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bar,
          matching: find.textContaining(
            '$testVoiceRoomCommunityName · 46 在听 · ',
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('S110 · 开播 sends the title', () {
    Future<FakeVoiceRoomGateway> open(WidgetTester tester, String typed) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      );
      VoiceRoomOpenOutcome? outcome;
      await pumpCommunityPage(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey<String>('probe-open'),
              onPressed: () async {
                outcome = await showVoiceRoomStartSheet(
                  context,
                  testCommunityId,
                );
              },
              child: const Text('开播'),
            ),
          ),
        ),
        voiceRoom: voice,
      );
      await tester.tap(find.byKey(const ValueKey<String>('probe-open')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('voiceroom-start-title')),
        typed,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-start-submit')),
      );
      await tester.pumpAndSettle();
      expect(outcome?.isOpen, isTrue);
      return voice;
    }

    testWidgets('a title is sent trimmed', (tester) async {
      final voice = await open(tester, '  周五 AMA  ');
      expect(voice.createTitles, <String?>['周五 AMA']);
    });

    testWidgets('an empty title sends nothing', (tester) async {
      final voice = await open(tester, '   ');
      expect(voice.createTitles, <String?>[null]);
    });

    testWidgets('closing the sheet opens nothing', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      );
      await pumpCommunityPage(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey<String>('probe-open'),
              onPressed: () =>
                  unawaited(showVoiceRoomStartSheet(context, testCommunityId)),
              child: const Text('开播'),
            ),
          ),
        ),
        voiceRoom: voice,
      );
      await tester.tap(find.byKey(const ValueKey<String>('probe-open')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-start-cancel')),
      );
      await tester.pumpAndSettle();
      expect(voice.commands, isEmpty);
    });

    testWidgets('the field holds forty code points', (tester) async {
      final voice = await open(tester, '语' * 45);
      expect(voice.createTitles.single?.runes.length, 40);
    });

    testWidgets('an unfinished opening shows its first title, locked', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      )..pendingOpenAnswer = const VoiceRoomPendingOpen(title: '周五 AMA');
      await pumpCommunityPage(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey<String>('probe-open'),
              onPressed: () =>
                  unawaited(showVoiceRoomStartSheet(context, testCommunityId)),
              child: const Text('开播'),
            ),
          ),
        ),
        voiceRoom: voice,
      );
      await tester.tap(find.byKey(const ValueKey<String>('probe-open')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('voiceroom-start-title')),
      );
      expect(field.controller?.text, '周五 AMA');
      expect(field.enabled, isFalse);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-start-pending')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-start-submit')),
      );
      await tester.pumpAndSettle();
      expect(voice.createTitles, <String?>['周五 AMA']);
    });

    testWidgets('the sheet does not close while the room is being opened', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      )..pending = true;
      await pumpCommunityPage(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey<String>('probe-open'),
              onPressed: () =>
                  unawaited(showVoiceRoomStartSheet(context, testCommunityId)),
              child: const Text('开播'),
            ),
          ),
        ),
        voiceRoom: voice,
      );
      await tester.tap(find.byKey(const ValueKey<String>('probe-open')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-start-submit')),
      );
      await tester.pump();
      expect(find.text('正在开播…'), findsOneWidget);
      // The system back, a tap outside and a drag all leave it standing.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('community-open-voice-room-sheet')),
        findsOneWidget,
      );
    });

    test('the title rule', () {
      expect(voiceRoomStartTitle(''), isNull);
      expect(voiceRoomStartTitle(' \n '), isNull);
      expect(voiceRoomStartTitle(' AMA '), 'AMA');
    });
  });

  group('S110 · the plaza card', () {
    Future<void> pumpCard(WidgetTester tester, LiveVoiceRoom room) =>
        pumpCommunityPage(
          tester,
          LiveVoiceRoomList(
            onOpenCommunity: (_) {},
            onOpenVoiceRoom: (_) {},
            now: () => DateTime.utc(2026, 10, 8, 4),
          ),
          overrides: <Override>[
            liveVoiceRoomGatewayProvider.overrideWithValue(
              _LiveGateway(<LiveVoiceRoom>[room]),
            ),
          ],
        );

    Finder faces() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'square-voice-room-face-',
          ),
    );

    testWidgets('a title, the community, four faces at most', (tester) async {
      await pumpCard(
        tester,
        _liveRoom(
          title: '周五 AMA',
          preview: const <LiveVoiceRoomHost>[
            LiveVoiceRoomHost(
              publicProfileId: testOwnerId,
              displayName: 'frog_maxi',
              avatarRef: null,
            ),
            LiveVoiceRoomHost(
              publicProfileId: testAdminId,
              displayName: 'pepe',
              avatarRef: null,
            ),
            LiveVoiceRoomHost(
              publicProfileId: testMemberId,
              displayName: 'fox',
              avatarRef: null,
            ),
            LiveVoiceRoomHost(
              publicProfileId: null,
              displayName: null,
              avatarRef: null,
            ),
            LiveVoiceRoomHost(
              publicProfileId: testRequestId,
              displayName: 'fifth',
              avatarRef: null,
            ),
          ],
        ),
      );
      expect(find.text('周五 AMA'), findsOneWidget);
      expect(find.text('Builders Guild'), findsOneWidget);
      expect(faces(), findsNWidgets(4));
      expect(find.text('6 在听 · 开播 1 小时'), findsOneWidget);
    });

    testWidgets('no title is the community\'s room; no preview is the host', (
      tester,
    ) async {
      await pumpCard(tester, _liveRoom());
      expect(find.text('Builders Guild 语音房'), findsOneWidget);
      expect(faces(), findsOneWidget);
      expect(find.text('主持 frog_maxi'), findsOneWidget);
    });

    testWidgets('an anonymous host and an anonymous face name nobody', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _liveRoom(
          host: const LiveVoiceRoomHost(
            publicProfileId: null,
            displayName: null,
            avatarRef: null,
          ),
          preview: const <LiveVoiceRoomHost>[
            LiveVoiceRoomHost(
              publicProfileId: null,
              displayName: null,
              avatarRef: null,
            ),
          ],
        ),
      );
      expect(find.text('主持 匿名成员'), findsOneWidget);
      expect(faces(), findsOneWidget);
    });
  });

  group('S110 · GET /v2/voice-rooms/live speakersPreview', () {
    Map<String, Object?> row({Object? preview = _absent, Object? title}) =>
        <String, Object?>{
          'voiceRoomId': testVoiceRoomId,
          'communityId': testCommunityId,
          'communityName': 'Builders Guild',
          'communityLogoRef': null,
          'host': <String, Object?>{
            'publicProfileId': testOwnerId,
            'displayName': 'frog_maxi',
            'avatarRef': null,
          },
          'listenerCount': 4,
          'speakerCount': 1,
          'countsObservedAt': null,
          'startedAt': '2026-10-08T03:00:00.000Z',
          'joinable': true,
          if (!identical(preview, _absent)) 'speakersPreview': preview,
          'title': ?title,
        };

    test('a server without S109b reads as no title and no faces', () {
      final room = LoopV2LiveVoiceRoomCodec.room(row());
      expect(room.title, isNull);
      expect(room.speakersPreview, isEmpty);
    });

    test('faces are read host first, anonymous ones carry nothing', () {
      final room = LoopV2LiveVoiceRoomCodec.room(
        row(
          title: '周五 AMA',
          preview: <Object?>[
            <String, Object?>{
              'publicProfileId': testOwnerId,
              'displayName': 'frog_maxi',
              'avatarRef': null,
            },
            <String, Object?>{
              'publicProfileId': null,
              'displayName': null,
              'avatarRef': null,
            },
          ],
        ),
      );
      expect(room.title, '周五 AMA');
      expect(room.speakersPreview, hasLength(2));
      expect(room.speakersPreview.first.displayName, 'frog_maxi');
      expect(room.speakersPreview.last.displayName, isNull);
    });

    test('null is none, five keep four, a half-named face is refused', () {
      expect(
        LoopV2LiveVoiceRoomCodec.room(row(preview: null)).speakersPreview,
        isEmpty,
      );
      final five = <Object?>[
        for (var index = 0; index < 5; index += 1)
          <String, Object?>{
            'publicProfileId': null,
            'displayName': 'p$index',
            'avatarRef': null,
          },
      ];
      expect(
        LoopV2LiveVoiceRoomCodec.room(row(preview: five)).speakersPreview,
        hasLength(4),
      );
      expect(
        () => LoopV2LiveVoiceRoomCodec.room(
          row(
            preview: <Object?>[
              <String, Object?>{
                'publicProfileId': testOwnerId,
                'displayName': null,
                'avatarRef': null,
              },
            ],
          ),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2LiveVoiceRoomCodec.room(row(preview: 'faces')),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });
}

const Object _absent = Object();

LiveVoiceRoom _liveRoom({
  String voiceRoomId = testVoiceRoomId,
  String? title,
  LiveVoiceRoomHost host = const LiveVoiceRoomHost(
    publicProfileId: testOwnerId,
    displayName: 'frog_maxi',
    avatarRef: null,
  ),
  List<LiveVoiceRoomHost> preview = const <LiveVoiceRoomHost>[],
}) => LiveVoiceRoom(
  voiceRoomId: voiceRoomId,
  communityId: testCommunityId,
  communityName: 'Builders Guild',
  communityLogoRef: null,
  title: title,
  host: host,
  speakersPreview: preview,
  listenerCount: 4,
  speakerCount: 1,
  countsObservedAt: null,
  startedAt: DateTime.utc(2026, 10, 8, 3),
  joinable: true,
);

final class _LiveGateway implements LiveVoiceRoomGateway {
  _LiveGateway(this.items);

  final List<LiveVoiceRoom> items;
  var reads = 0;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<LiveVoiceRoomPage> listLive({String? cursor}) async {
    reads += 1;
    return LiveVoiceRoomPage(
      items: items,
      nextCursor: null,
      observedAt: DateTime.utc(2026, 10, 8, 4),
    );
  }
}

/// A call whose foreground is a probe of the room page's presentation: it
/// records what the page asked for and publishes a microphone control the
/// way the official call view does.
final class _ProbeFactory implements AudioRoomCallFactory {
  final List<VoiceMediaPresentation?> presentations =
      <VoiceMediaPresentation?>[];
  var presses = 0;

  @override
  AudioRoomCallHandle create(AudioRoomTarget target) =>
      _ProbeCall(target.roomId, this);
}

final class _ProbeCall implements AudioRoomCallHandle {
  _ProbeCall(this.roomId, this._factory);

  @override
  final String roomId;
  final _ProbeFactory _factory;

  @override
  bool get retirementStarted => false;

  @override
  AudioRoomCallReading get reading => const AudioRoomCallReading(
    phase: AudioRoomLivePhase.connecting,
    participantCount: null,
  );

  @override
  Stream<AudioRoomCallReading> get readings =>
      const Stream<AudioRoomCallReading>.empty();

  @override
  Stream<AudioRoomRoomSignal> get roomSignals =>
      const Stream<AudioRoomRoomSignal>.empty();

  @override
  Future<void> joinMuted() async {}

  @override
  Future<AudioRoomMicrophoneOutcome> setMicrophoneEnabled({
    required bool enabled,
  }) async => const AudioRoomMicrophoneOutcome.opened();

  @override
  bool get microphoneOpen => false;

  @override
  Future<void> applyOutputPreference(
    AudioRoomOutputPreference preference,
  ) async {}

  @override
  Future<void> leave() async {}

  @override
  Widget buildForeground({
    required Future<void> Function() onLeaveRequested,
    bool inline = false,
    Future<void> Function()? onMicrophoneEnabled,
    void Function({
      required AudioRoomLivePhase phase,
      required int? participantCount,
      required List<AudioRoomSpeaker> speakers,
    })?
    onPresence,
    VoidCallback? onDisconnected,
    Future<void> Function()? onSpeakAgainRequested,
    AudioRoomOutputPreference outputPreference =
        AudioRoomOutputPreference.speaker,
    ValueChanged<AudioRoomOutputPreference>? onOutputSelected,
  }) => Builder(
    builder: (context) {
      final presentation = VoiceMediaPresentation.maybeOf(context);
      _factory.presentations.add(presentation);
      return TextButton(
        key: const ValueKey<String>('probe-publish'),
        onPressed: () => presentation?.microphone?.publish(
          this,
          const VoiceMicrophoneControl(
            label: '取消静音',
            open: false,
            busy: false,
            enabled: true,
          ),
          () => _factory.presses += 1,
        ),
        child: const Text('发布麦克风'),
      );
    },
  );
}
