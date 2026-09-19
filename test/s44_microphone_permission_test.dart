import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_foreground_call_view.dart';

/// Real-device report 2026-09-19 · F3.
///
/// The first Speak in a voice room raises the system's microphone question.
/// The answer lands outside the command it interrupted, so the command came
/// back refused — and the page both blamed the member's authorisation and
/// spent this call's one Speak, which is why leaving the room and coming back
/// was the only way to talk.
void main() {
  group('a microphone answer names its own cause', () {
    test(
      'the system permission and the room role are not the same refusal',
      () {
        expect(
          AudioRoomMicrophoneRefusalMapping.fromDetail(
            'DOMException, NotAllowedError',
          ),
          AudioRoomMicrophoneRefusal.systemPermission,
        );
        // stream_video-1.4.3 `call.dart:3669`. This is a room role, and no
        // system setting changes it.
        expect(
          AudioRoomMicrophoneRefusalMapping.fromDetail(
            'Missing permission to send audio',
          ),
          AudioRoomMicrophoneRefusal.roomPermission,
        );
        expect(
          AudioRoomMicrophoneRefusalMapping.fromDetail(
            'Unable to set microphone, Call not connected',
          ),
          AudioRoomMicrophoneRefusal.callClosed,
        );
        expect(
          AudioRoomMicrophoneRefusalMapping.fromDetail(null),
          AudioRoomMicrophoneRefusal.unknown,
        );
      },
    );

    test('each refusal carries the next step that belongs to it', () {
      expect(
        audioRoomMicrophoneRefusalText(
          AudioRoomMicrophoneRefusal.systemPermission,
        ),
        '没有麦克风权限，去系统设置里允许 LOOP 使用麦克风后再试。',
      );
      // The old sentence sent everyone to the system settings and then out of
      // the room. Neither belongs to a room role.
      expect(
        audioRoomMicrophoneRefusalText(
          AudioRoomMicrophoneRefusal.roomPermission,
        ),
        isNot(contains('系统设置')),
      );
      expect(
        audioRoomMicrophoneRefusalText(AudioRoomMicrophoneRefusal.unknown),
        isNot(contains('退出')),
      );
    });
  });

  group('a permission answered late gets one more attempt', () {
    test('an answer that named no cause is tried once more', () async {
      final answers = <AudioRoomMicrophoneOutcome>[
        const AudioRoomMicrophoneOutcome.refused(
          AudioRoomMicrophoneRefusal.unknown,
        ),
        const AudioRoomMicrophoneOutcome.opened(),
      ];
      var attempts = 0;

      final outcome = await audioRoomEnableMicrophoneWithRetry(() async {
        attempts += 1;
        return answers.removeAt(0);
      }, retryDelay: Duration.zero);

      expect(attempts, 2);
      expect(outcome.opened, isTrue);
    });

    test('a refusal that named its cause is never asked twice', () async {
      for (final refusal in <AudioRoomMicrophoneRefusal>[
        AudioRoomMicrophoneRefusal.systemPermission,
        AudioRoomMicrophoneRefusal.roomPermission,
        AudioRoomMicrophoneRefusal.callClosed,
      ]) {
        var attempts = 0;
        final outcome = await audioRoomEnableMicrophoneWithRetry(() async {
          attempts += 1;
          return AudioRoomMicrophoneOutcome.refused(refusal);
        }, retryDelay: Duration.zero);

        expect(attempts, 1, reason: refusal.name);
        expect(outcome.refusal, refusal);
      }
    });

    test('a microphone that opened is not asked twice', () async {
      var attempts = 0;
      await audioRoomEnableMicrophoneWithRetry(() async {
        attempts += 1;
        return const AudioRoomMicrophoneOutcome.opened();
      }, retryDelay: Duration.zero);

      expect(attempts, 1);
    });
  });

  group(
    "this call's one Speak is spent by a microphone, not by an attempt",
    () {
      test('a refused Speak may be tried again in the same room', () async {
        var refusal = AudioRoomMicrophoneRefusal.systemPermission;
        var enableCalls = 0;
        final commands = AudioRoomCallCommandCoordinator(
          (enabled) async {
            if (!enabled) return const AudioRoomMicrophoneOutcome.opened();
            enableCalls += 1;
            return refusal == AudioRoomMicrophoneRefusal.unknown &&
                    enableCalls > 1
                ? const AudioRoomMicrophoneOutcome.opened()
                : AudioRoomMicrophoneOutcome.refused(refusal);
          },
          () async {},
          () async {},
        );

        final declined = await commands.setMicrophoneEnabled(enabled: true);
        expect(declined.opened, isFalse);
        expect(declined.refusal, AudioRoomMicrophoneRefusal.systemPermission);

        // The member allows the microphone in the system settings and presses
        // 发言 again, from inside the room.
        refusal = AudioRoomMicrophoneRefusal.unknown;
        final opened = await commands.setMicrophoneEnabled(enabled: true);
        expect(opened.opened, isTrue);
        expect(enableCalls, 2);

        // And the one that did open still spends it.
        expect(
          (await commands.setMicrophoneEnabled(enabled: true)).opened,
          isFalse,
        );
        expect(enableCalls, 2);
      });

      test(
        'a retiring call refuses a Speak and says which state it is in',
        () async {
          final commands = AudioRoomCallCommandCoordinator(
            (enabled) async => const AudioRoomMicrophoneOutcome.opened(),
            () async {},
            () async {},
          );
          unawaited(commands.retire());

          final outcome = await commands.setMicrophoneEnabled(enabled: true);
          expect(outcome.opened, isFalse);
          expect(outcome.refusal, AudioRoomMicrophoneRefusal.callClosed);
        },
      );
    },
  );
}
