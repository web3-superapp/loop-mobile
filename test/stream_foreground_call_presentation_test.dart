import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/calls/stream_foreground_call_view.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

void main() {
  test('joined waits for official media connection before showing live', () {
    final status = CallStatus.joined();

    expect(StreamCallStatusPresentation.label(status), 'Connecting media');
    expect(StreamCallStatusPresentation.tone(status), LoopTone.warning);
  });

  test('connected status is presented as official live state', () {
    final status = CallStatus.connected();

    expect(StreamCallStatusPresentation.label(status), 'Live');
    expect(StreamCallStatusPresentation.tone(status), LoopTone.positive);
  });

  test('reconnecting status stays a warning', () {
    final status = CallStatus.reconnecting(1);

    expect(StreamCallStatusPresentation.label(status), 'Reconnecting');
    expect(StreamCallStatusPresentation.tone(status), LoopTone.warning);
  });

  test('reconnection failure never collapses to an empty SDK label', () {
    final status = CallStatus.reconnectingFailed();

    expect(status.toStatusString(), isEmpty);
    expect(StreamCallStatusPresentation.label(status), 'Reconnect failed');
    expect(StreamCallStatusPresentation.tone(status), LoopTone.danger);
  });

  test('an enabled microphone can always be muted while reconnecting', () {
    expect(
      StreamMicrophoneControlPolicy.canRequest(
        status: CallStatus.reconnecting(1),
        microphoneEnabled: true,
        canSendAudio: true,
        audioSuspended: false,
        microphoneEnableRequested: true,
        retirementStarted: true,
      ),
      isTrue,
    );
  });

  test('starting capture requires connected, authorized, active audio', () {
    expect(
      StreamMicrophoneControlPolicy.canRequest(
        status: CallStatus.reconnecting(1),
        microphoneEnabled: false,
        canSendAudio: true,
        audioSuspended: false,
        microphoneEnableRequested: false,
        retirementStarted: false,
      ),
      isFalse,
    );
    expect(
      StreamMicrophoneControlPolicy.canRequest(
        status: CallStatus.connected(),
        microphoneEnabled: false,
        canSendAudio: false,
        audioSuspended: false,
        microphoneEnableRequested: false,
        retirementStarted: false,
      ),
      isFalse,
    );
    expect(
      StreamMicrophoneControlPolicy.canRequest(
        status: CallStatus.connected(),
        microphoneEnabled: false,
        canSendAudio: true,
        audioSuspended: true,
        microphoneEnableRequested: false,
        retirementStarted: false,
      ),
      isFalse,
    );
    expect(
      StreamMicrophoneControlPolicy.canRequest(
        status: CallStatus.connected(),
        microphoneEnabled: false,
        canSendAudio: true,
        audioSuspended: false,
        microphoneEnableRequested: false,
        retirementStarted: false,
      ),
      isTrue,
    );
  });

  test('a consumed Speak requires a new Call before capture can restart', () {
    expect(
      StreamMicrophoneControlPolicy.canRequest(
        status: CallStatus.connected(),
        microphoneEnabled: false,
        canSendAudio: true,
        audioSuspended: false,
        microphoneEnableRequested: true,
        retirementStarted: false,
      ),
      isFalse,
    );
  });

  test('retirement blocks Speak while leaving Mute available', () {
    expect(
      StreamMicrophoneControlPolicy.canRequest(
        status: CallStatus.connected(),
        microphoneEnabled: false,
        canSendAudio: true,
        audioSuspended: false,
        microphoneEnableRequested: false,
        retirementStarted: true,
      ),
      isFalse,
    );
    expect(
      StreamMicrophoneControlPolicy.canRequest(
        status: CallStatus.reconnecting(1),
        microphoneEnabled: true,
        canSendAudio: true,
        audioSuspended: true,
        microphoneEnableRequested: true,
        retirementStarted: true,
      ),
      isTrue,
    );
  });
}
