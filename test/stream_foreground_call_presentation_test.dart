import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/calls/stream_foreground_call_view.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

void main() {
  test('joined waits for official media connection before showing live', () {
    final status = CallStatus.joined();

    expect(StreamCallStatusPresentation.label(status), '媒体连接中');
    expect(StreamCallStatusPresentation.tone(status), LoopTone.warning);
  });

  test('connected status is presented as official live state', () {
    final status = CallStatus.connected();

    expect(StreamCallStatusPresentation.label(status), '已连接');
    expect(StreamCallStatusPresentation.tone(status), LoopTone.positive);
  });

  test('reconnecting status stays a warning', () {
    final status = CallStatus.reconnecting(1);

    expect(StreamCallStatusPresentation.label(status), '重连中');
    expect(StreamCallStatusPresentation.tone(status), LoopTone.warning);
  });

  test('reconnection failure never collapses to an empty SDK label', () {
    final status = CallStatus.reconnectingFailed();

    expect(status.toStatusString(), isEmpty);
    expect(StreamCallStatusPresentation.label(status), '重连失败');
    expect(StreamCallStatusPresentation.tone(status), LoopTone.danger);
  });

  test('the live count says it is the one happening now', () {
    // The room count on the same screen was taken when LOOP last looked and
    // keeps its own name; neither of them is 「在线」 on its own any more.
    expect(StreamCallParticipantPresentation.countLabel(1), '此刻在通话里 1 人');
    expect(
      StreamCallParticipantPresentation.countLabel(0),
      isNot(contains('在线')),
    );
  });

  test('R5-3: a connected call never says nobody is in it', () {
    // The first ten to fifteen seconds of a connection: the badge is already
    // 「已连接」 and the SFU has published no figure. This device is in the
    // call it is connected to, so its own participant is the floor.
    expect(
      StreamCallParticipantPresentation.liveCount(
        connected: true,
        participantCount: 0,
        knownParticipants: 1,
      ),
      1,
    );
    // Not even the local participant has arrived: the count is not stated,
    // and the line says it is still being taken rather than printing 0.
    expect(
      StreamCallParticipantPresentation.liveCount(
        connected: true,
        participantCount: 0,
        knownParticipants: 0,
      ),
      isNull,
    );
    expect(StreamCallParticipantPresentation.countLabel(null), '此刻在通话里的人数正在统计');
    expect(
      StreamCallParticipantPresentation.countLabel(null),
      isNot(contains('0')),
    );
    // Once the SFU speaks, its figure is the one printed — it counts people
    // this device carries no participant for.
    expect(
      StreamCallParticipantPresentation.liveCount(
        connected: true,
        participantCount: 5,
        knownParticipants: 1,
      ),
      5,
    );
    // A call this device does not hold is passed through as it is: 0 there is
    // a fact about a connection that does not exist.
    expect(
      StreamCallParticipantPresentation.liveCount(
        connected: false,
        participantCount: 0,
        knownParticipants: 0,
      ),
      0,
    );
  });

  test('the reader own row never says 我 twice', () {
    // Stream carries no alias in this deployment, so the title falls back to
    // 我 — and the caption must then be the microphone state, not 我 again.
    expect(
      StreamCallParticipantPresentation.name(suppliedName: '', isLocal: true),
      '我',
    );
    expect(
      StreamCallParticipantPresentation.marksSelf(
        suppliedName: '',
        isLocal: true,
      ),
      isFalse,
    );
    expect(
      StreamCallParticipantPresentation.microphoneState(
        isSpeaking: false,
        isAudioEnabled: false,
      ),
      '已静音',
    );
  });

  test('an alias keeps the alias and takes the 我 badge', () {
    expect(
      StreamCallParticipantPresentation.name(
        suppliedName: ' voyager ',
        isLocal: true,
      ),
      'voyager',
    );
    expect(
      StreamCallParticipantPresentation.marksSelf(
        suppliedName: 'voyager',
        isLocal: true,
      ),
      isTrue,
    );
    expect(
      StreamCallParticipantPresentation.marksSelf(
        suppliedName: 'voyager',
        isLocal: false,
      ),
      isFalse,
    );
    expect(
      StreamCallParticipantPresentation.name(suppliedName: '', isLocal: false),
      '成员',
    );
  });

  test('speaking outranks the plain microphone state', () {
    expect(
      StreamCallParticipantPresentation.microphoneState(
        isSpeaking: true,
        isAudioEnabled: true,
      ),
      '正在发言',
    );
    expect(
      StreamCallParticipantPresentation.microphoneState(
        isSpeaking: false,
        isAudioEnabled: true,
      ),
      '麦克风已开',
    );
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
