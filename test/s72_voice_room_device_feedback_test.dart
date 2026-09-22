import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/time/loop_foreground_poll.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';

/// Two devices in one room, reported from the review devices on 2026-09-22.
///
/// Every test here answers one line of that report: a room that was created
/// and then not entered, a member count that stood still, a speaker grid that
/// was empty while somebody was speaking, and a queue nobody re-read.
void main() {
  group('a page that is on screen keeps reading', () {
    testWidgets('the interval runs while the page is here, and not after', (
      tester,
    ) async {
      var reads = 0;
      final poll = LoopForegroundPoll(
        interval: const Duration(seconds: 5),
        read: () async => reads += 1,
      );
      addTearDown(poll.stop);

      poll.start();
      expect(reads, 0, reason: 'the page has just read for itself');

      await tester.pump(const Duration(seconds: 5));
      expect(reads, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(reads, 2);

      // Something told the page the answer changed; the interval is a floor,
      // never the speed at which the page answers.
      poll.readNow();
      await tester.pump();
      expect(reads, 3);

      poll.stop();
      await tester.pump(const Duration(seconds: 30));
      expect(reads, 3);
    });

    testWidgets('a phone in a pocket asks for nothing', (tester) async {
      var reads = 0;
      final poll = LoopForegroundPoll(
        interval: const Duration(seconds: 5),
        read: () async => reads += 1,
      );
      addTearDown(poll.stop);
      poll.start();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      expect(reads, 0);

      // Back in front of the reader: the page is not left showing the moment
      // it was put away.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(reads, 1);

      poll.stop();
    });

    testWidgets('one read at a time, however long it takes', (tester) async {
      final gate = Completer<void>();
      var reads = 0;
      final poll = LoopForegroundPoll(
        interval: const Duration(seconds: 5),
        read: () async {
          reads += 1;
          await gate.future;
        },
      );
      addTearDown(poll.stop);
      poll.start();

      await tester.pump(const Duration(seconds: 5));
      expect(reads, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(reads, 1, reason: 'the first read has not come back');

      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(reads, 2);

      poll.stop();
    });
  });

  group('one provider event, one LOOP read', () {
    final cid = StreamCallCid(cid: 'audio_room:loop_voice_room');
    final createdAt = DateTime.utc(2026, 9, 22, 17, 7);

    test('the hand-raise event is the one LOOP sends, by name', () {
      // Decision 0069: the server writes its own kind into `custom`, and the
      // event carries no identity — who raised the hand comes from the LOOP
      // queue. An event this client does not recognise is not a cue at all.
      StreamCallCustomEvent custom(Map<String, Object>? payload) =>
          StreamCallCustomEvent(
            cid,
            senderUserId: 'loop_host',
            createdAt: createdAt,
            eventType: 'custom',
            users: const <String, CallUser>{},
            custom: payload,
          );

      expect(
        audioRoomRoomSignalOf(
          custom(const <String, Object>{
            audioRoomEventKindKey: audioRoomHandRaiseEventKind,
            'loop_event_schema_version': 1,
            'voice_room_id': 'room',
            'hand_raise_id': 'raise',
            'sequence': '7',
            'state': 'pending',
          }),
        ),
        AudioRoomRoomSignal.handRaise,
      );
      // The name the server writes, spelled the way the contract spells it.
      expect(audioRoomEventKindKey, 'loop_event_kind');
      expect(audioRoomHandRaiseEventKind, 'voiceRoomHandRaise');

      expect(
        audioRoomRoomSignalOf(
          custom(const <String, Object>{
            audioRoomEventKindKey: 'somethingElse',
          }),
        ),
        isNull,
      );
      expect(audioRoomRoomSignalOf(custom(null)), isNull);
    });

    test('the four events about who is in the room are one cue', () {
      final user = CallUser.empty();
      const participant = CallParticipant(
        userSessionId: 'session-1',
        userId: 'loop_listener',
        role: 'listener',
      );
      final metadata = CallMetadata(
        cid: cid,
        details: CallDetails(
          createdBy: user,
          team: '',
          ownCapabilities: const <CallPermission>[],
          blockedUserIds: const <String>[],
          broadcasting: false,
          recording: false,
          backstage: false,
          transcribing: false,
          captioning: false,
          egress: const CallEgress(),
          custom: const <String, Object>{},
          rtmpIngress: '',
        ),
        settings: const CallSettings(),
        session: const CallSessionData(),
        users: const <String, CallUser>{},
        members: const <String, CallMember>{},
      );

      for (final event in <StreamCallEvent>[
        StreamCallSessionParticipantJoinedEvent(
          cid,
          createdAt: createdAt,
          sessionId: 'session',
          user: user,
          participant: participant,
        ),
        StreamCallSessionParticipantLeftEvent(
          cid,
          createdAt: createdAt,
          sessionId: 'session',
          user: user,
          participant: participant,
          duration: const Duration(minutes: 1),
        ),
        StreamCallMemberAddedEvent(
          cid,
          createdAt: createdAt,
          members: const <CallMember>[],
          metadata: metadata,
        ),
        StreamCallMemberRemovedEvent(
          cid,
          createdAt: createdAt,
          metadata: metadata,
          removedMemberIds: const <String>['loop_listener'],
        ),
      ]) {
        expect(
          audioRoomRoomSignalOf(event),
          AudioRoomRoomSignal.participants,
          reason: '${event.runtimeType}',
        );
      }
    });

    test('an event about the call itself is nobody else to read', () {
      // The call view reads the call's own state for itself; only a record
      // LOOP holds is worth a request.
      expect(
        audioRoomRoomSignalOf(
          StreamCallSessionParticipantCountUpdatedEvent(
            cid,
            createdAt: createdAt,
            sessionId: 'session',
            participantsCountByRole: const <String, int>{'listener': 2},
            anonymousParticipantCount: 0,
          ),
        ),
        isNull,
      );
    });
  });

  group('a read never retires a command', () {
    test('a refresh that lands mid-command leaves the page usable', () async {
      // The fifteen-second read, and the cues under it, used to take the
      // generation the command was holding. The command then returned
      // "nothing went wrong" — a success toast — without ever clearing 忙,
      // and every control on the page stayed disabled until it was left.
      final gateway = FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot());
      final container = ProviderContainer(
        overrides: [voiceRoomGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      container.listen(voiceRoomControllerProvider, (_, _) {});
      final controller = container.read(voiceRoomControllerProvider.notifier);
      await controller.open(testCommunityId);

      // 加入 is in flight and the server has not answered yet.
      final gate = Completer<void>();
      gateway.membershipGate = gate;
      final joined = testVoiceRoomSnapshot(role: VoiceRoomRole.speaker);
      gateway.snapshot = joined;
      gateway.loadSnapshot = joined;
      final command = controller.leave();
      await Future<void>.value();
      expect(container.read(voiceRoomControllerProvider).busy, isTrue);

      // A cue arrives, and the page reads the room beside the command.
      await controller.refreshRoom();
      await controller.refreshHandRaises();

      gate.complete();
      final failure = await command;

      final state = container.read(voiceRoomControllerProvider);
      expect(failure, isNull, reason: 'the command was never superseded');
      expect(state.busy, isFalse);
      expect(state.snapshot?.viewer.role, VoiceRoomRole.speaker);
    });

    test(
      'a command that was superseded clears 忙 and reports no success',
      () async {
        final gateway = FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot());
        final container = ProviderContainer(
          overrides: [voiceRoomGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);
        container.listen(voiceRoomControllerProvider, (_, _) {});
        final controller = container.read(voiceRoomControllerProvider.notifier);
        await controller.open(testCommunityId);

        final gate = Completer<void>();
        gateway.membershipGate = gate;
        final command = controller.leave();
        await Future<void>.value();

        // A whole reload takes the page: the command in flight no longer owns
        // it, and whatever it answers is not this page's answer.
        await controller.reload();
        gate.complete();

        expect(await command, CommunityFailureKind.cancelled);
        expect(container.read(voiceRoomControllerProvider).busy, isFalse);
      },
    );
  });

  group('a created room is read again', () {
    test('opening the same community reads the room every time', () async {
      // The room record outlives nothing: a host who ends a room and opens a
      // new one for the same community used to reach a page holding the old
      // answer, and `GET …/voice-rooms/current` was never sent at all — a
      // create with a 201 behind it that looks like a failure on screen.
      final gateway = FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot());
      final container = ProviderContainer(
        overrides: [voiceRoomGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      container.listen(voiceRoomControllerProvider, (_, _) {});
      final controller = container.read(voiceRoomControllerProvider.notifier);

      await controller.open(testCommunityId);
      expect(container.read(voiceRoomControllerProvider).isReady, isTrue);

      await controller.open(testCommunityId);

      expect(
        gateway.commands.where((command) => command.startsWith('current:')),
        hasLength(2),
      );
    });
  });
}
