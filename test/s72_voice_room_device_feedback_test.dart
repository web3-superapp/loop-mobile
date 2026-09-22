import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
