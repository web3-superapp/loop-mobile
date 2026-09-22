import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

typedef _ForegroundCallViewData = ({
  CallStatus status,
  int participantCount,
  int knownParticipants,
  List<CallParticipantState> participants,
  bool microphoneEnabled,
  bool canSendAudio,
  bool audioSuspended,
});

/// What this device's media connection is doing, in the only four shapes the
/// surfaces around it have to answer for.
///
/// It is a reading of Stream's [CallStatus], never a second state machine: it
/// is computed from the status on every rebuild and stored nowhere. The badge
/// still prints the status's own label; this decides what the screen may say
/// about the people in the call, and whether the page has to offer a way back
/// in.
enum StreamCallPhase {
  /// The connection has not been established yet: idle, joining, joined or
  /// connecting for the first time.
  connecting,

  /// This device is in the call and hears it.
  connected,

  /// The connection dropped and the SDK is putting it back on its own.
  /// Nothing collapses the call here — a retry in progress is not a failure.
  reconnecting,

  /// The call ended for this device and the SDK is not retrying: disconnected,
  /// or reconnection given up.
  disconnected,
}

/// Presentation-only mapping for Stream's official call status.
///
/// The mapping never becomes a second call state machine; every rebuild still
/// reads the current [CallStatus] from the SDK's [CallState].
abstract final class StreamCallStatusPresentation {
  /// Reads the status as one of the four phases the screen answers for.
  ///
  /// Order matters: the SDK's reconnecting and migrating statuses extend
  /// `CallStatusConnecting`, and a reconnection that gave up is its own class
  /// rather than a disconnect.
  static StreamCallPhase phase(CallStatus status) {
    if (status.isConnected) return StreamCallPhase.connected;
    if (status is CallStatusReconnectionFailed || status.isDisconnected) {
      return StreamCallPhase.disconnected;
    }
    if (status.isReconnecting || status.isMigrating) {
      return StreamCallPhase.reconnecting;
    }
    return StreamCallPhase.connecting;
  }

  /// The same reading, in the shape the surfaces outside the call view read.
  static AudioRoomLivePhase livePhase(CallStatus status) =>
      switch (phase(status)) {
        StreamCallPhase.connecting => AudioRoomLivePhase.connecting,
        StreamCallPhase.connected => AudioRoomLivePhase.connected,
        StreamCallPhase.reconnecting => AudioRoomLivePhase.reconnecting,
        StreamCallPhase.disconnected => AudioRoomLivePhase.disconnected,
      };

  static String label(CallStatus status) {
    if (status is CallStatusReconnectionFailed) return '重连失败';
    if (status.isIdle) return '等待中';
    if (status.isJoining) return '加入中';
    if (status.isJoined) return '媒体连接中';
    if (status.isConnected) return '已连接';
    if (status.isReconnecting) return '重连中';
    if (status.isMigrating) return '切换连接';
    if (status.isConnecting) return '连接中';
    if (status.isDisconnected) return '已断开';
    return '通话不可用';
  }

  static LoopTone tone(CallStatus status) {
    if (status.isConnected) return LoopTone.positive;
    if (status is CallStatusReconnectionFailed || status.isDisconnected) {
      return LoopTone.danger;
    }
    if (status.isReconnecting ||
        status.isMigrating ||
        status.isConnecting ||
        status.isJoining ||
        status.isJoined) {
      return LoopTone.warning;
    }
    return LoopTone.conversation;
  }

  static IconData icon(CallStatus status) {
    if (status.isConnected) {
      return Icons.graphic_eq_rounded;
    }
    if (status is CallStatusReconnectionFailed || status.isDisconnected) {
      return Icons.wifi_off_rounded;
    }
    if (status.isReconnecting ||
        status.isMigrating ||
        status.isConnecting ||
        status.isJoining ||
        status.isJoined) {
      return Icons.sync_rounded;
    }
    return Icons.headphones_rounded;
  }
}

/// When a stopped connection stops being the call's own business.
///
/// The SDK retries on its own, and a retry in progress is not a failure: while
/// it reconnects the call stays exactly where it is. Once the SDK has given up
/// — disconnected, or reconnection failed — nobody is putting the audio back,
/// and a red badge on a screen whose only controls are 举手 and 离开 is a dead
/// end: on the review device it stood for more than ninety seconds with no way
/// forward except leaving the page and coming back through the banner. That
/// call is handed to the page, which retires it and offers 「重新连接语音」.
///
/// A call this device is already taking down — the reader's 离开, the page's
/// exit, a background retirement — reaches the same statuses on its way out
/// and is not a disconnection anybody has to be offered a way back from.
abstract final class StreamCallDisconnectPolicy {
  static bool collapses({
    required CallStatus status,
    required bool retirementStarted,
  }) {
    if (retirementStarted) return false;
    return StreamCallStatusPresentation.phase(status) ==
        StreamCallPhase.disconnected;
  }
}

/// Command gating derived from the current official [CallState] snapshot.
abstract final class StreamMicrophoneControlPolicy {
  static bool canRequest({
    required CallStatus status,
    required bool microphoneEnabled,
    required bool canSendAudio,
    required bool audioSuspended,
    required bool microphoneEnableRequested,
    required bool retirementStarted,
  }) {
    // Turning capture off is always safe, including while reconnecting or
    // disconnected. Turning it on requires a live foreground media session.
    if (microphoneEnabled) return true;
    return status.isConnected &&
        canSendAudio &&
        !audioSuspended &&
        !microphoneEnableRequested &&
        !retirementStarted;
  }
}

/// Presentation-only mapping for the people inside the call.
abstract final class StreamCallParticipantPresentation {
  /// The live count this device is connected to, named for that.
  ///
  /// The LOOP room facts above this view carry a second count, taken when
  /// LOOP last looked. Both were called 「在线」, so 「当前在线 0」 and
  /// 「1 人在通话」 stood on one screen contradicting each other. They are not
  /// the same reading and neither is wrong: one is what was seen at a past
  /// moment, the other is what this call holds now. Each says when.
  ///
  /// A null count is a connection whose head count has not arrived yet; it is
  /// never printed as 0. See [liveCount].
  static String countLabel(int? count) =>
      count == null ? '此刻在通话里的人数正在统计' : '此刻在通话里 $count 人';

  /// The whole line about the people in the call, for the phase it is in.
  ///
  /// Only a connection states a number. Everything else says what it is
  /// waiting for: a call that is still connecting has counted nobody yet, and
  /// a call that dropped is holding a reading taken before it dropped. On the
  /// review device the red 「已断开」 badge stood above 「此刻在通话里 1 人」
  /// and above 「读不到通话成员」 — three sentences about one room, two of them
  /// answering a moment that had passed.
  static String countLine({
    required StreamCallPhase phase,
    required int? count,
  }) => switch (phase) {
    StreamCallPhase.connected => countLabel(count),
    StreamCallPhase.connecting => '此刻在通话里的人数正在统计',
    // The two sentences a screen may carry twice — the room facts above this
    // panel print the same line for the same phase — are written once, in the
    // contract both surfaces read.
    StreamCallPhase.reconnecting => audioRoomLivePhaseNote(
      AudioRoomLivePhase.reconnecting,
    )!,
    StreamCallPhase.disconnected => audioRoomLivePhaseNote(
      AudioRoomLivePhase.disconnected,
    )!,
  };

  /// How many people this device can count in the call, or null while it
  /// cannot count anyone yet.
  ///
  /// `participantCount` is the figure the SFU publishes, and for the first
  /// ten to fifteen seconds of a connection it has not published one: the
  /// badge said 「已连接」 while the count beside it said 0, which is the exact
  /// shape of 「我已加入语音房，但是人数还是 0」. A connected device is in the
  /// call it is connected to, so its own participant is a floor under the
  /// count; before even that participant exists the count is not stated at
  /// all. Either way a connected call never shows 0.
  ///
  /// Without a connection there is no count at all. The figures this device
  /// still holds were true while it was connected, and printing them under
  /// 「已断开」 or 「重连中」 states a past moment as if it were now; printing
  /// 0 instead states an empty room. [countLine] says which reading is
  /// missing and why.
  static int? liveCount({
    required bool connected,
    required int participantCount,
    required int knownParticipants,
  }) {
    if (!connected) return null;
    final counted = participantCount > knownParticipants
        ? participantCount
        : knownParticipants;
    return counted > 0 ? counted : null;
  }

  /// The row title: the alias Stream carries, or the one word left when the
  /// provider carries none.
  static String name({required String suppliedName, required bool isLocal}) {
    final alias = suppliedName.trim();
    if (alias.isNotEmpty) return alias;
    return isLocal ? '我' : '成员';
  }

  /// Whether the row gets the 「我」 badge beside its title.
  ///
  /// The row used to read 「我 / 我」: the title fell back to 我 because Stream
  /// carried no alias, and the caption said 我 again instead of the one thing
  /// the caption is for — whether this person's microphone is live. The badge
  /// marks the reader's own row, and it is withheld when the title is already
  /// the word 我, which would only say it twice again.
  static bool marksSelf({
    required String suppliedName,
    required bool isLocal,
  }) => isLocal && suppliedName.trim().isNotEmpty;

  /// The caption: microphone state, for every row including the reader's own.
  static String microphoneState({
    required bool isSpeaking,
    required bool isAudioEnabled,
  }) {
    if (isSpeaking) return '正在发言';
    return isAudioEnabled ? '麦克风已开' : '已静音';
  }
}

/// Whether the one control this view has left is another call.
///
/// Stream Video 1.4.3 starts one microphone per Call: after a mute the track
/// stays in the session, and a second Speak would enter the SDK's stopped
/// track recreation path, which this app never enters (decision 0005). The
/// control therefore had nothing to offer a member who muted their own
/// microphone and said 「重新进入后再发言」 — on the review device that is what
/// a host saw the moment they pressed 静音. A call the page can put back is an
/// answer; without a page that can put one back there is none.
abstract final class StreamSpeakAgainPolicy {
  static bool offers({
    required bool pageCanReconnect,
    required bool speakSpent,
    required bool microphoneEnabled,
    required bool canSendAudio,
    required bool retirementStarted,
  }) =>
      pageCanReconnect &&
      speakSpent &&
      !microphoneEnabled &&
      canSendAudio &&
      !retirementStarted;
}

/// What this account's microphone is doing, and what it can do next.
///
/// Four situations used to share two sentences, and the one a host met most
/// often — muting their own microphone — landed on the sentence written for an
/// account that had lost the seat entirely. [everCouldSendAudio] is what tells
/// those two apart: a permission that is gone now and was there a moment ago
/// is a seat the host took back, and coming back into the room does not return
/// it.
String streamMicrophoneNote({
  required bool retiring,
  required bool microphoneEnabled,
  required bool canSendAudio,
  required bool everCouldSendAudio,
  required bool speakSpent,
}) {
  if (retiring && !microphoneEnabled) {
    return '正在退出这次通话。麦克风不会再启动；如有需要先静音，再重试退出。';
  }
  if (microphoneEnabled) return '你的麦克风已打开，房间里的人能听到你。点「静音」随时关掉。';
  if (!canSendAudio) {
    return everCouldSendAudio
        ? '你已被移出发言席，现在只能收听。要再发言，请等主持人重新邀请。'
        : '你在这个房间是只收听的角色。';
  }
  if (speakSpent) return '你已静音。要再次发言，点「重新连接后发言」把这次语音重新接一遍。';
  return '你以静音状态进入。准备好后点「发言」，系统麦克风权限只在开始采集时申请。';
}

/// Foreground Audio Room UI driven directly by Stream's official [CallState].
///
/// Only microphone/leave command progress and sanitized command errors are
/// local. Connection, participant, capability, and microphone truth is never
/// copied into LOOP state.
/// What a Speak that did not open is allowed to say.
///
/// One sentence per cause, and each names the next step that belongs to it.
/// The old single sentence sent every member to the system settings and then
/// out of the room, which is neither true for a room role nor necessary for a
/// permission that was just granted.
String audioRoomMicrophoneRefusalText(AudioRoomMicrophoneRefusal refusal) =>
    switch (refusal) {
      AudioRoomMicrophoneRefusal.systemPermission =>
        '没有麦克风权限，去系统设置里允许 LOOP 使用麦克风后再试。',
      AudioRoomMicrophoneRefusal.roomPermission => '这个房间还没有让你发言，麦克风没有打开。',
      AudioRoomMicrophoneRefusal.callClosed => '这次通话已经不能再发言了，请退出后重新进入。',
      AudioRoomMicrophoneRefusal.unknown => '麦克风没能打开，请再试一次。',
    };

class StreamForegroundCallView extends StatefulWidget {
  const StreamForegroundCallView({
    required this.call,
    required this.retirementStarted,
    required this.onMicrophoneRequested,
    required this.onLeaveRequested,
    super.key,
    this.inline = false,
    this.onPresence,
    this.onDisconnected,
    this.onSpeakAgainRequested,
  });

  final Call call;

  /// Told once this call stopped for good, so the page can take it down and
  /// offer the way back in.
  ///
  /// It fires on the phase, not on a badge: while the SDK reconnects nothing
  /// is reported, because the connection is being put back without anybody
  /// asking. See [StreamCallDisconnectPolicy].
  final VoidCallback? onDisconnected;

  /// Publishes this call's own connection and head count, once per change.
  ///
  /// The count below already says 「此刻在通话里 N 人」; the room facts above it
  /// and the shell strip had no way to read the same figure and printed an
  /// older observation beside it, so one screen carried 「在线 0」 above 「1 人
  /// 在通话」. The reading leaves here after the frame that produced it: a
  /// state write during a build is not allowed.
  /// A null count is a connection that has not counted anyone yet; the
  /// surfaces outside say so instead of printing 0 under 「已连接」.
  final void Function({
    required AudioRoomLivePhase phase,
    required int? participantCount,
  })?
  onPresence;

  /// True when the view is one section of the LOOP voice room page.
  ///
  /// The page owns the only scrolling region, so an inline view adds neither a
  /// scroll view of its own nor a pinned dock: it lays out at its content
  /// height and its controls travel with the section above them.
  final bool inline;
  final bool Function() retirementStarted;
  final Future<AudioRoomMicrophoneOutcome> Function({required bool enabled})
  onMicrophoneRequested;
  final Future<void> Function() onLeaveRequested;

  /// Asked when a member who has already spoken in this call wants the
  /// microphone back.
  ///
  /// Stream Video 1.4.3 starts one microphone per Call: a track that was muted
  /// stays in the session and a second Speak would enter the SDK's stopped
  /// track recreation path, which this app never enters (decision 0005). So
  /// the way back to speaking is another call, not another command — and it is
  /// the page that owns the call, not this view. Without it the control had
  /// nothing to offer and said so as 「重新进入后再发言」, which on the review
  /// device was what a host saw the moment they muted themselves.
  final Future<void> Function()? onSpeakAgainRequested;

  @override
  State<StreamForegroundCallView> createState() =>
      _StreamForegroundCallViewState();
}

class _StreamForegroundCallViewState extends State<StreamForegroundCallView> {
  var _microphoneBusy = false;
  var _leaveBusy = false;
  var _microphoneEnableRequested = false;

  /// True while this call is being put back so the reader can speak again.
  var _speakAgainBusy = false;

  /// True once this call ever let this account send audio.
  ///
  /// Losing that permission mid-call is the host taking the seat back, and it
  /// is the one state 「重新进入后再发言」 was written for. An account that was
  /// never a speaker is simply a listener, and the two must not share a
  /// sentence: a host who muted their own microphone was being told to leave
  /// the room and come back.
  var _hadSendAudio = false;
  String? _commandError;
  ({AudioRoomLivePhase phase, int? participantCount})? _published;

  /// One report per stopped call: the page takes this call down when it
  /// arrives, and a second frame on the same dead call must not ask twice.
  var _disconnectReported = false;

  /// Hands one reading out, after the frame that read it and only when it
  /// changed. A call that is still joining is not a connection, so it is
  /// published as one this device does not hold yet.
  void _publishPresence(_ForegroundCallViewData data) {
    final report = widget.onPresence;
    if (report == null) return;
    final connected = data.status.isConnected;
    final reading = (
      phase: StreamCallStatusPresentation.livePhase(data.status),
      // The same figure the panel prints, so the room facts and the shell
      // strip never disagree with the line right below them.
      participantCount: StreamCallParticipantPresentation.liveCount(
        connected: connected,
        participantCount: data.participantCount,
        knownParticipants: data.knownParticipants,
      ),
    );
    if (_published == reading) return;
    _published = reading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      report(phase: reading.phase, participantCount: reading.participantCount);
    });
  }

  /// Hands the stopped call to the page, after the frame that read it.
  void _reportDisconnection(_ForegroundCallViewData data) {
    final report = widget.onDisconnected;
    if (report == null || _disconnectReported) return;
    if (!StreamCallDisconnectPolicy.collapses(
      status: data.status,
      retirementStarted: widget.retirementStarted(),
    )) {
      return;
    }
    _disconnectReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      report();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder<_ForegroundCallViewData>(
      call: widget.call,
      selector: (state) {
        final participants = List<CallParticipantState>.of(
          state.callParticipants,
        )..sort(CallParticipantSortingPresets.livestreamOrAudioRoom);
        return (
          status: state.status,
          participantCount: state.participantCount,
          // What this device can see for itself, local participant included.
          knownParticipants: state.callParticipants.length,
          participants: participants.take(8).toList(growable: false),
          microphoneEnabled: state.localParticipant?.isAudioEnabled ?? false,
          canSendAudio: state.ownCapabilities.contains(
            CallPermission.sendAudio,
          ),
          audioSuspended: state.isAudioSuspended,
        );
      },
      builder: (context, data) {
        _publishPresence(data);
        _reportDisconnection(data);
        // Remembered, never derived backwards: a permission that is gone now
        // and was there a moment ago is a seat the host took back.
        if (data.canSendAudio) _hadSendAudio = true;
        final retirementStarted = widget.retirementStarted();
        final canRequestMicrophone = StreamMicrophoneControlPolicy.canRequest(
          status: data.status,
          microphoneEnabled: data.microphoneEnabled,
          canSendAudio: data.canSendAudio,
          audioSuspended: data.audioSuspended,
          microphoneEnableRequested: _microphoneEnableRequested,
          retirementStarted: retirementStarted,
        );
        final facts = _facts(
          context,
          data: data,
          retirementStarted: retirementStarted,
        );
        final controls = _controls(
          context,
          data: data,
          retirementStarted: retirementStarted,
          canRequestMicrophone: canRequestMicrophone,
        );
        if (widget.inline) {
          // 内联面板不带自己的滚动层：语音房整页只有一层滚动，这里只按内容
          // 高度展开。
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[facts, const SizedBox(height: 16), controls],
            ),
          );
        }
        return Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: facts,
                  ),
                ),
              ),
            ),
            LoopActionDock(child: controls),
          ],
        );
      },
    );
  }

  Widget _facts(
    BuildContext context, {
    required _ForegroundCallViewData data,
    required bool retirementStarted,
  }) {
    final phase = StreamCallStatusPresentation.phase(data.status);
    return Column(
      crossAxisAlignment: widget.inline
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Align(
          alignment: widget.inline ? Alignment.centerLeft : Alignment.center,
          child: LoopStatusPill(
            label: StreamCallStatusPresentation.label(data.status),
            tone: StreamCallStatusPresentation.tone(data.status),
            icon: StreamCallStatusPresentation.icon(data.status),
          ),
        ),
        if (!widget.inline) ...<Widget>[
          const SizedBox(height: 18),
          Text(
            '语音房',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          StreamCallParticipantPresentation.countLine(
            phase: phase,
            count: StreamCallParticipantPresentation.liveCount(
              connected: phase == StreamCallPhase.connected,
              participantCount: data.participantCount,
              knownParticipants: data.knownParticipants,
            ),
          ),
          textAlign: widget.inline ? TextAlign.start : TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (data.audioSuspended) ...<Widget>[
          const SizedBox(height: 14),
          Align(
            alignment: widget.inline ? Alignment.centerLeft : Alignment.center,
            child: const LoopStatusPill(
              label: '系统已暂停音频',
              tone: LoopTone.warning,
              icon: Icons.pause_circle_outline_rounded,
            ),
          ),
        ],
        SizedBox(height: widget.inline ? 16 : 30),
        _ParticipantGrid(participants: data.participants, phase: phase),
        SizedBox(height: widget.inline ? 14 : 22),
        Text(
          streamMicrophoneNote(
            retiring: retirementStarted,
            microphoneEnabled: data.microphoneEnabled,
            canSendAudio: data.canSendAudio,
            everCouldSendAudio: _hadSendAudio,
            speakSpent: _microphoneEnableRequested,
          ),
          textAlign: widget.inline ? TextAlign.start : TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _controls(
    BuildContext context, {
    required _ForegroundCallViewData data,
    required bool retirementStarted,
    required bool canRequestMicrophone,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_commandError != null) ...<Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              _commandError!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: LoopColors.danger),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: <Widget>[
            // A microphone this call cannot open again is not a dead label:
            // the way back to speaking is another call, and this is where the
            // reader asks for one.
            Expanded(
              child:
                  StreamSpeakAgainPolicy.offers(
                    pageCanReconnect: widget.onSpeakAgainRequested != null,
                    speakSpent: _microphoneEnableRequested,
                    microphoneEnabled: data.microphoneEnabled,
                    canSendAudio: data.canSendAudio,
                    retirementStarted: retirementStarted,
                  )
                  ? OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'voiceroom-media-speak-again',
                      ),
                      onPressed:
                          _speakAgainBusy || _leaveBusy || _microphoneBusy
                          ? null
                          : _requestSpeakAgain,
                      icon: _speakAgainBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(_speakAgainBusy ? '正在重新连接语音' : '重新连接后发言'),
                    )
                  : OutlinedButton.icon(
                      onPressed:
                          !_microphoneBusy &&
                              !_leaveBusy &&
                              !_speakAgainBusy &&
                              canRequestMicrophone
                          ? () =>
                                _setMicrophone(enabled: !data.microphoneEnabled)
                          : null,
                      icon: _microphoneBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              data.microphoneEnabled
                                  ? Icons.mic_off_rounded
                                  : data.canSendAudio &&
                                        !_microphoneEnableRequested &&
                                        !retirementStarted
                                  ? Icons.mic_rounded
                                  : Icons.headphones_rounded,
                            ),
                      label: Text(
                        _microphoneBusy
                            ? '正在切换麦克风'
                            : data.microphoneEnabled
                            ? '静音'
                            : data.canSendAudio &&
                                  !_microphoneEnableRequested &&
                                  !retirementStarted
                            ? '发言'
                            : retirementStarted
                            ? '需要先重试退出'
                            : data.canSendAudio
                            ? '这次通话不能再开麦'
                            : '仅收听',
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: _leaveBusy ? null : _leave,
              tooltip: '断开语音连接',
              style: IconButton.styleFrom(
                minimumSize: const Size.square(48),
                backgroundColor: LoopColors.danger,
                foregroundColor: Colors.white,
                disabledBackgroundColor: LoopColors.danger.withValues(
                  alpha: 0.35,
                ),
              ),
              icon: _leaveBusy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.call_end_rounded),
            ),
          ],
        ),
      ],
    );
  }

  /// Hands the page the one decision that can give the microphone back.
  Future<void> _requestSpeakAgain() async {
    final speakAgain = widget.onSpeakAgainRequested;
    if (speakAgain == null || _speakAgainBusy) return;
    setState(() {
      _speakAgainBusy = true;
      _commandError = null;
    });
    try {
      await speakAgain();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speakAgainBusy = false;
        _commandError = '语音没能重新接上，请再试一次。';
      });
      return;
    }
    // A call that was put back takes this view down with it; one the page
    // could not replace leaves it here, and the control has to work again.
    if (mounted) setState(() => _speakAgainBusy = false);
  }

  Future<void> _setMicrophone({required bool enabled}) async {
    if (_microphoneBusy || _leaveBusy) return;
    setState(() {
      _microphoneBusy = true;
      _commandError = null;
    });

    var outcome = const AudioRoomMicrophoneOutcome.refused(
      AudioRoomMicrophoneRefusal.unknown,
    );
    try {
      outcome = await widget.onMicrophoneRequested(enabled: enabled);
    } catch (error) {
      outcome = AudioRoomMicrophoneOutcome.refused(
        AudioRoomMicrophoneRefusalMapping.fromDetail('$error'),
        detail: '$error',
      );
    }
    if (!mounted) return;
    setState(() {
      _microphoneBusy = false;
      // This call's one Speak is spent by a microphone that opened, not by
      // an attempt. A member who has just allowed the system's microphone
      // question presses 发言 again where they stand.
      if (enabled && outcome.opened) _microphoneEnableRequested = true;
      if (!outcome.opened) {
        _commandError = enabled
            ? audioRoomMicrophoneRefusalText(outcome.refusal)
            : '麦克风没能静音。请重试，或退出这个房间。';
      }
    });
  }

  Future<void> _leave() async {
    if (_leaveBusy) return;
    setState(() {
      _leaveBusy = true;
      _commandError = null;
    });
    try {
      await widget.onLeaveRequested();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _leaveBusy = false;
        _commandError = '这次通话没能干净地退出，请重试。';
      });
      return;
    }
    // A leave that took the call down unmounts this view. One that asked the
    // page first can come back with the question declined, and the control
    // has to be usable again.
    if (mounted) setState(() => _leaveBusy = false);
  }
}

class _ParticipantGrid extends StatelessWidget {
  const _ParticipantGrid({required this.participants, required this.phase});

  final List<CallParticipantState> participants;

  /// What the connection is doing. The roster belongs to a call this device
  /// holds: without one, the rows it still carries are a list of who was
  /// there before it dropped, and 「读不到通话成员」 blamed the provider for a
  /// connection that is simply not up.
  final StreamCallPhase phase;

  @override
  Widget build(BuildContext context) {
    if (phase != StreamCallPhase.connected) {
      return switch (phase) {
        StreamCallPhase.reconnecting => const LoopStateCard(
          title: '正在重新连接',
          message: '这次通话掉线了，正在自动接回来。成员明细会在连上后重新读出。',
          icon: Icons.sync_rounded,
        ),
        StreamCallPhase.disconnected => const LoopStateCard(
          title: '语音已断开',
          message: '这次通话已经断开，成员明细要重新连接语音之后才能读出。',
          icon: Icons.headset_off_rounded,
        ),
        _ => const LoopStateCard(
          title: '正在连接语音',
          message: '还没有连上这次通话，成员明细会在连上后读出。',
          icon: Icons.sync_rounded,
        ),
      };
    }
    if (participants.isEmpty) {
      return const LoopStateCard(
        title: '正在读取通话成员',
        message: '这次通话刚连上，服务商还没有给出成员明细。',
        icon: Icons.sync_rounded,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 520;
        final width = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: participants
              .map(
                (participant) => SizedBox(
                  width: width,
                  child: _ParticipantCard(participant: participant),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.participant});

  final CallParticipantState participant;

  @override
  Widget build(BuildContext context) {
    final suppliedName = participant.name;
    final isLocal = participant.isLocal;
    final name = StreamCallParticipantPresentation.name(
      suppliedName: suppliedName,
      isLocal: isLocal,
    );
    final marksSelf = StreamCallParticipantPresentation.marksSelf(
      suppliedName: suppliedName,
      isLocal: isLocal,
    );
    final role = StreamCallParticipantPresentation.microphoneState(
      isSpeaking: participant.isSpeaking,
      isAudioEnabled: participant.isAudioEnabled,
    );
    final accent = participant.isSpeaking ? LoopColors.chat : LoopColors.line;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LoopColors.basalt.withValues(alpha: 0.86),
        borderRadius: LoopRadius.medium,
        border: Border.all(color: accent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LoopColors.chat.withValues(alpha: 0.12),
                border: Border.all(
                  color: LoopColors.chat.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                name.characters.first.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: LoopColors.chat),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (marksSelf) ...<Widget>[
                        const SizedBox(width: 8),
                        const LoopBadge('我', kind: LoopBadgeKind.mute),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(role, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              participant.isAudioEnabled
                  ? Icons.mic_rounded
                  : Icons.mic_off_rounded,
              size: 18,
              color: participant.isSpeaking
                  ? LoopColors.chat
                  : LoopColors.vapor,
            ),
          ],
        ),
      ),
    );
  }
}
