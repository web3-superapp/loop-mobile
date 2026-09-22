import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/time/loop_foreground_poll.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';

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
