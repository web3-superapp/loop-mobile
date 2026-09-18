import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
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
    // Without a connection there is no count at all: see R6-2.
    expect(
      StreamCallParticipantPresentation.liveCount(
        connected: false,
        participantCount: 0,
        knownParticipants: 0,
      ),
      isNull,
    );
  });

  test('R6-2: a dropped call states no head count at all', () {
    // The review device carried three sentences about one room: a red
    // 「已断开」 badge, 「此刻在通话里 1 人」 under it, and 「读不到通话成员」
    // under that. The 1 was the last reading taken while the call was up.
    expect(
      StreamCallParticipantPresentation.liveCount(
        connected: false,
        participantCount: 1,
        knownParticipants: 1,
      ),
      isNull,
    );
    final disconnected = StreamCallParticipantPresentation.countLine(
      phase: StreamCallPhase.disconnected,
      count: null,
    );
    expect(disconnected, '语音已断开，人数以重新连接后为准');
    expect(disconnected, isNot(contains('此刻在通话里')));
    expect(disconnected, isNot(matches(RegExp(r'\d'))));

    final reconnecting = StreamCallParticipantPresentation.countLine(
      phase: StreamCallPhase.reconnecting,
      count: null,
    );
    expect(reconnecting, '语音正在重连，人数以重新连接后为准');
    expect(reconnecting, isNot(matches(RegExp(r'\d'))));

    // R7-2: the room facts above this panel print the same two sentences for
    // the same two phases. They are one string, read from the contract both
    // surfaces share, so a screen carrying both can never say two things.
    expect(
      audioRoomLivePhaseNote(AudioRoomLivePhase.reconnecting),
      reconnecting,
    );
    expect(
      audioRoomLivePhaseNote(AudioRoomLivePhase.disconnected),
      disconnected,
    );
    // A phase that can state a count of its own borrows no sentence here.
    expect(audioRoomLivePhaseNote(AudioRoomLivePhase.connected), isNull);
    expect(audioRoomLivePhaseNote(AudioRoomLivePhase.connecting), isNull);
    expect(audioRoomLivePhaseNote(AudioRoomLivePhase.idle), isNull);
  });

  test('R7-2: the call status reaches the surfaces outside as its phase', () {
    expect(
      StreamCallStatusPresentation.livePhase(CallStatus.reconnecting(1)),
      AudioRoomLivePhase.reconnecting,
    );
    expect(
      StreamCallStatusPresentation.livePhase(CallStatus.connected()),
      AudioRoomLivePhase.connected,
    );
    expect(
      StreamCallStatusPresentation.livePhase(CallStatus.connecting()),
      AudioRoomLivePhase.connecting,
    );
    expect(
      StreamCallStatusPresentation.livePhase(
        CallStatus.disconnected(DisconnectReason.reconnectionFailed()),
      ),
      AudioRoomLivePhase.disconnected,
    );
  });

  test('R6-3: the window before the connection counts nobody, not zero', () {
    // 「连接中」 beside 「此刻在通话里 0 人」 is the same picture the reader
    // reported, in a yellow badge instead of a green one.
    expect(
      StreamCallParticipantPresentation.countLine(
        phase: StreamCallPhase.connecting,
        count: null,
      ),
      '此刻在通话里的人数正在统计',
    );
    expect(
      StreamCallParticipantPresentation.countLine(
        phase: StreamCallPhase.connecting,
        count: null,
      ),
      isNot(contains('0')),
    );
    // A connection that counted people keeps printing the figure it counted.
    expect(
      StreamCallParticipantPresentation.countLine(
        phase: StreamCallPhase.connected,
        count: 3,
      ),
      '此刻在通话里 3 人',
    );
  });

  test('the phase reads the SDK status, reconnecting included', () {
    expect(
      StreamCallStatusPresentation.phase(CallStatus.connected()),
      StreamCallPhase.connected,
    );
    // Reconnecting and migrating extend the SDK's connecting status; neither
    // may be read as a first connection.
    expect(
      StreamCallStatusPresentation.phase(CallStatus.reconnecting(1)),
      StreamCallPhase.reconnecting,
    );
    expect(
      StreamCallStatusPresentation.phase(CallStatus.migrating()),
      StreamCallPhase.reconnecting,
    );
    expect(
      StreamCallStatusPresentation.phase(CallStatus.joining()),
      StreamCallPhase.connecting,
    );
    expect(
      StreamCallStatusPresentation.phase(CallStatus.joined()),
      StreamCallPhase.connecting,
    );
    expect(
      StreamCallStatusPresentation.phase(CallStatus.idle()),
      StreamCallPhase.connecting,
    );
    expect(
      StreamCallStatusPresentation.phase(CallStatus.reconnectingFailed()),
      StreamCallPhase.disconnected,
    );
    expect(
      StreamCallStatusPresentation.phase(
        CallStatus.disconnected(DisconnectReason.timeout()),
      ),
      StreamCallPhase.disconnected,
    );
  });

  test('R6-1: only a call nobody is putting back is handed to the page', () {
    // While the SDK reconnects, the call stays where it is: the review device
    // got its audio back twice without touching anything.
    expect(
      StreamCallDisconnectPolicy.collapses(
        status: CallStatus.reconnecting(4),
        retirementStarted: false,
      ),
      isFalse,
    );
    expect(
      StreamCallDisconnectPolicy.collapses(
        status: CallStatus.connected(),
        retirementStarted: false,
      ),
      isFalse,
    );
    // Reconnection given up, and a plain disconnect: nobody is putting these
    // back, and the page has to offer the way in again.
    expect(
      StreamCallDisconnectPolicy.collapses(
        status: CallStatus.reconnectingFailed(),
        retirementStarted: false,
      ),
      isTrue,
    );
    expect(
      StreamCallDisconnectPolicy.collapses(
        status: CallStatus.disconnected(DisconnectReason.reconnectionFailed()),
        retirementStarted: false,
      ),
      isTrue,
    );
    // The reader's own 离开 and a background retirement pass through the same
    // statuses on their way out. Neither is a disconnection to recover from.
    expect(
      StreamCallDisconnectPolicy.collapses(
        status: CallStatus.disconnected(DisconnectReason.ended()),
        retirementStarted: true,
      ),
      isFalse,
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
