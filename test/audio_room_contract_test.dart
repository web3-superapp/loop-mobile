import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

void main() {
  group('AudioRoomTarget', () {
    test('accepts only the fixed call type and normalized safe room IDs', () {
      final target = AudioRoomTarget.tryParse(
        callType: AudioRoomTarget.callType,
        roomId: 'loop_daily-01',
      );

      expect(target?.roomId, 'loop_daily-01');
      expect(AudioRoomTarget.callType, 'audio_room');
    });

    test('rejects client-selected call types and malformed room IDs', () {
      final tooLong = List<String>.filled(65, 'a').join();
      for (final candidate in <({Object? type, Object? id})>[
        (type: 'default', id: 'loop-daily'),
        (type: AudioRoomTarget.callType, id: null),
        (type: AudioRoomTarget.callType, id: ''),
        (type: AudioRoomTarget.callType, id: ' loop-daily'),
        (type: AudioRoomTarget.callType, id: 'loop-daily '),
        (type: AudioRoomTarget.callType, id: '-loop-daily'),
        (type: AudioRoomTarget.callType, id: 'loop-daily_'),
        (type: AudioRoomTarget.callType, id: 'Loop-Daily'),
        (type: AudioRoomTarget.callType, id: 'audio_room:loop-daily'),
        (type: AudioRoomTarget.callType, id: 'loop/daily'),
        (type: AudioRoomTarget.callType, id: tooLong),
      ]) {
        expect(
          AudioRoomTarget.tryParse(
            callType: candidate.type,
            roomId: candidate.id,
          ),
          isNull,
          reason: 'unexpectedly accepted ${candidate.id}',
        );
      }
    });
  });

  test('first join disables publishing tracks and enables room output', () {
    final options = mutedAudioRoomConnectOptions();

    expect(options.camera.isDisabled, isTrue);
    expect(options.microphone.isDisabled, isTrue);
    expect(options.screenShare.isDisabled, isTrue);
    expect(options.speakerDefaultOn, isTrue);
  });
}
