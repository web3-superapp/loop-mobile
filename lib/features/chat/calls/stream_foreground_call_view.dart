import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_presentation.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_state_card.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
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
  AudioRoomOutputRoute? output,
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
    if (status is CallStatusReconnectionFailed) {
      return LoopL10n.current.chatCalls_streamForegroundViewLabel;
    }
    if (status.isIdle) {
      return LoopL10n.current.chatCalls_streamForegroundViewLabel2;
    }
    if (status.isJoining) {
      return LoopL10n.current.chatCalls_streamForegroundViewLabel3;
    }
    if (status.isJoined) {
      return LoopL10n.current.chatCalls_streamForegroundViewLabel4;
    }
    if (status.isConnected) {
      return LoopL10n.current.chatCalls_streamForegroundViewLabel5;
    }
    if (status.isReconnecting) {
      return LoopL10n.current.chatCalls_streamForegroundViewLabel6;
    }
    if (status.isMigrating) {
      return LoopL10n.current.chatCalls_streamForegroundViewLabel7;
    }
    if (status.isConnecting) {
      return LoopL10n.current.chatCalls_streamForegroundViewLabel8;
    }
    if (status.isDisconnected) return LoopL10n.current.common_disconnected;
    return LoopL10n.current.chatCalls_streamForegroundViewLabel9;
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

  /// The `.badge` the status is shown in (decision 0170): the Lime pair
  /// while the call is live or on its way, the neutral pair once it stopped
  /// or before it started. The prototype has no amber and no red.
  static LoopBadgeKind badgeKind(CallStatus status) => switch (tone(status)) {
    LoopTone.positive => LoopBadgeKind.up,
    LoopTone.warning => LoopBadgeKind.mining,
    LoopTone.danger => LoopBadgeKind.down,
    _ => LoopBadgeKind.mute,
  };
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

/// Reads the provider's current audio output as one of the three routes the
/// room's control names (decision 0106).
///
/// iOS reports the built-in speaker as `Speaker` and the receiver with the
/// port type `Receiver`, and the provider adds an `earpiece` entry of its
/// own. Android names its routes `speaker`, `earpiece`, `wired-headset` and
/// `bluetooth`. Anything else is a device the reader plugged in or paired.
AudioRoomOutputRoute? audioRoomOutputRouteOf(RtcMediaDevice? device) {
  if (device == null) return null;
  final id = device.id.toLowerCase();
  final group = device.groupId?.toLowerCase();
  if (id == 'speaker' || group == 'speaker') {
    return const AudioRoomOutputRoute(AudioRoomOutputKind.speaker);
  }
  if (id == 'earpiece' || group == 'receiver' || group == 'earpiece') {
    return const AudioRoomOutputRoute(AudioRoomOutputKind.earpiece);
  }
  return AudioRoomOutputRoute(
    AudioRoomOutputKind.external,
    label: device.label,
  );
}

/// What one tap on the output control asks for.
///
/// The control toggles between the two built-in routes, starting from the
/// route the provider reports rather than from the last choice: a reader who
/// hears the receiver and taps the control expects the speaker. While an
/// external device carries the sound there is nothing to toggle.
AudioRoomOutputPreference? audioRoomOutputToggle({
  required AudioRoomOutputRoute? current,
  required AudioRoomOutputPreference preference,
}) {
  switch (current?.kind) {
    case AudioRoomOutputKind.external:
      return null;
    case AudioRoomOutputKind.speaker:
      return AudioRoomOutputPreference.earpiece;
    case AudioRoomOutputKind.earpiece:
      return AudioRoomOutputPreference.speaker;
    case null:
      return preference == AudioRoomOutputPreference.speaker
          ? AudioRoomOutputPreference.earpiece
          : AudioRoomOutputPreference.speaker;
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
  static String countLabel(int? count) => count == null
      ? LoopL10n.current.chatCalls_streamForegroundViewCanRequest
      : LoopL10n.current.chatCalls_streamForegroundViewS(count);

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
    StreamCallPhase.connecting =>
      LoopL10n.current.chatCalls_streamForegroundViewCanRequest,
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
    return isLocal
        ? LoopL10n.current.common_me
        : LoopL10n.current.chatGroupAlias_neutralMember;
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

  /// Who can be heard in this call right now, in the shape the surfaces
  /// outside the call view read.
  ///
  /// A tile exists because a microphone is open — that is the question 「正在
  /// 发言」 asks, and it is the only one the provider answers. LOOP's own
  /// speaker roster answers a different one: which parts it granted, without
  /// the host in it at all (decision 0052), which is why the grid was empty on
  /// the review device while the host was talking.
  ///
  /// A call that is not connected has nobody in it to hear: the rows this
  /// device still holds describe a moment that has passed.
  static List<AudioRoomSpeaker> speaking({
    required bool connected,
    required List<CallParticipantState> participants,
  }) {
    if (!connected) return const <AudioRoomSpeaker>[];
    return <AudioRoomSpeaker>[
      for (final participant in participants)
        if (participant.isAudioEnabled || participant.isSpeaking)
          AudioRoomSpeaker(
            key: participant.sessionId,
            name: name(
              suppliedName: participant.name,
              isLocal: participant.isLocal,
            ),
            isLocal: participant.isLocal,
            isSpeaking: participant.isSpeaking,
          ),
    ];
  }

  /// The caption: microphone state, for every row including the reader's own.
  static String microphoneState({
    required bool isSpeaking,
    required bool isAudioEnabled,
  }) {
    if (isSpeaking) {
      return LoopL10n.current.chatCalls_streamForegroundViewMicrophoneState;
    }
    return isAudioEnabled
        ? LoopL10n.current.chatCalls_streamForegroundViewMicrophoneState2
        : LoopL10n.current.common_muted;
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
  String? speakLabel,
  String? speakAgainLabel,
}) {
  if (retiring && !microphoneEnabled) {
    return LoopL10n.current.chatCalls_streamForegroundViewIf;
  }
  if (microphoneEnabled) {
    return LoopL10n.current.chatCalls_streamForegroundViewIf2;
  }
  if (!canSendAudio) {
    return everCouldSendAudio
        ? LoopL10n.current.chatCalls_streamForegroundViewIf3
        : LoopL10n.current.chatCalls_streamForegroundViewS2;
  }
  if (speakSpent) {
    return LoopL10n.current.chatCalls_streamForegroundViewIf4(
      speakAgainLabel ??
          LoopL10n.current.chatCalls_streamForegroundViewSpeakAgainLabel,
    );
  }
  return LoopL10n.current.chatCalls_streamForegroundViewIf5(
    speakLabel ?? LoopL10n.current.chatCalls_streamForegroundViewSpeakLabel,
  );
}

/// The microphone control's short words for the room page's bottom bar
/// (decision 0115): the same states as the call view's own button, said in
/// the four characters a bar slot holds.
String streamBarMicrophoneLabel({
  required bool speakAgain,
  required bool speakAgainBusy,
  required bool microphoneBusy,
  required bool microphoneEnabled,
  required bool canSendAudio,
  required bool speakSpent,
  required bool retiring,
}) {
  if (speakAgain) {
    return speakAgainBusy
        ? LoopL10n
              .current
              .chatCalls_streamForegroundViewStreamBarMicrophoneLabel
        : LoopL10n.current.chatCalls_streamForegroundViewS3;
  }
  if (microphoneBusy) {
    return LoopL10n
        .current
        .chatCalls_streamForegroundViewStreamBarMicrophoneLabel2;
  }
  if (microphoneEnabled) return LoopL10n.current.common_mute;
  if (canSendAudio && !speakSpent && !retiring) {
    return LoopL10n.current.common_unmute;
  }
  if (retiring) {
    return LoopL10n
        .current
        .chatCalls_streamForegroundViewStreamBarMicrophoneLabel3;
  }
  return canSendAudio
      ? LoopL10n.current.chatCalls_streamForegroundViewStreamBarMicrophoneLabel4
      : LoopL10n.current.chatCalls_streamForegroundViewS4;
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
        LoopL10n.current.chatCalls_streamForegroundViewSystemPermission,
      AudioRoomMicrophoneRefusal.roomPermission =>
        LoopL10n.current.chatCalls_streamForegroundViewRoomPermission,
      AudioRoomMicrophoneRefusal.callClosed =>
        LoopL10n.current.chatCalls_streamForegroundViewCallClosed,
      AudioRoomMicrophoneRefusal.unknown =>
        LoopL10n.current.chatCalls_streamForegroundViewUnknown,
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
    this.outputPreference = AudioRoomOutputPreference.speaker,
    this.onOutputSelected,
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
    required List<AudioRoomSpeaker> speakers,
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

  /// The built-in route the reader chose (decision 0106).
  final AudioRoomOutputPreference outputPreference;

  /// Records a new choice. Null hides the control: a view with nobody to
  /// keep the choice offers none.
  final ValueChanged<AudioRoomOutputPreference>? onOutputSelected;

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
  AudioRoomCallReading? _published;

  /// One report per stopped call: the page takes this call down when it
  /// arrives, and a second frame on the same dead call must not ask twice.
  var _disconnectReported = false;

  /// The bar this view hands its microphone to, when the page asked for one.
  VoiceMicrophoneBridge? _bridge;

  @override
  void dispose() {
    _bridge?.withdraw(this);
    _bridge = null;
    super.dispose();
  }

  /// Hands the microphone control to the page's bar, after the frame that
  /// read it. The press is always the newest closure; a change of words is
  /// what makes the bar repaint.
  void _publishMicrophone(
    VoiceMicrophoneBridge? bridge,
    VoiceMicrophoneControl control,
    VoidCallback? onPressed,
  ) {
    final previous = _bridge;
    if (!identical(previous, bridge)) {
      previous?.withdraw(this);
      _bridge = bridge;
    }
    if (bridge == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_bridge, bridge)) return;
      bridge.publish(this, control, onPressed);
    });
  }

  /// Hands one reading out, after the frame that read it and only when it
  /// changed. A call that is still joining is not a connection, so it is
  /// published as one this device does not hold yet.
  void _publishPresence(_ForegroundCallViewData data) {
    final report = widget.onPresence;
    if (report == null) return;
    final connected = data.status.isConnected;
    // Held as the reading itself rather than as a record: two readings differ
    // when the people in them differ, and a list is not the same list twice.
    final reading = AudioRoomCallReading(
      phase: StreamCallStatusPresentation.livePhase(data.status),
      // The same figure the panel prints, so the room facts and the shell
      // strip never disagree with the line right below them.
      participantCount: StreamCallParticipantPresentation.liveCount(
        connected: connected,
        participantCount: data.participantCount,
        knownParticipants: data.knownParticipants,
      ),
      // The page above this view draws 「正在发言」 from the same reading, so
      // the grid and the rows below it are one account of one moment.
      speakers: StreamCallParticipantPresentation.speaking(
        connected: connected,
        participants: data.participants,
      ),
    );
    if (_published == reading) return;
    _published = reading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      report(
        phase: reading.phase,
        participantCount: reading.participantCount,
        speakers: reading.speakers,
      );
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
          // Where the sound actually goes, as the provider reads it back —
          // never the choice the reader made.
          output: audioRoomOutputRouteOf(state.audioOutputDevice),
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
        final presentation = VoiceMediaPresentation.maybeOf(context);
        final bridge = presentation?.microphone;
        final facts = _facts(
          context,
          data: data,
          retirementStarted: retirementStarted,
          showsParticipants: presentation?.showsParticipants ?? true,
          barMicrophone: bridge != null,
        );
        final controls = _controls(
          context,
          data: data,
          retirementStarted: retirementStarted,
          canRequestMicrophone: canRequestMicrophone,
          bridge: bridge,
        );
        if (widget.inline) {
          // 内联面板不带自己的滚动层：语音房整页只有一层滚动，这里只按内容
          // 高度展开。
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              4,
              LoopSpacing.page,
              0,
            ),
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
    bool showsParticipants = true,
    bool barMicrophone = false,
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
          child: Semantics(
            label: StreamCallStatusPresentation.label(data.status),
            excludeSemantics: true,
            child: LoopBadge(
              StreamCallStatusPresentation.label(data.status),
              key: const ValueKey<String>('voiceroom-media-status'),
              kind: StreamCallStatusPresentation.badgeKind(data.status),
            ),
          ),
        ),
        if (!widget.inline) ...<Widget>[
          const SizedBox(height: 18),
          Text(
            context.l10n.common_voiceRooms,
            textAlign: TextAlign.center,
            // M43 R31 a centred state title: titleLg 16 (decision 0191).
            style: LoopType.titleLg,
          ),
        ],
        if (showsParticipants) ...<Widget>[
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
        ],
        if (data.audioSuspended) ...<Widget>[
          const SizedBox(height: 14),
          Align(
            alignment: widget.inline ? Alignment.centerLeft : Alignment.center,
            child: LoopBadge(
              context
                  .l10n
                  .chatCalls_streamForegroundViewVoiceroomMediaAudioSuspended,
              key: ValueKey<String>('voiceroom-media-audio-suspended'),
              kind: LoopBadgeKind.mining,
            ),
          ),
        ],
        if (showsParticipants) ...<Widget>[
          SizedBox(height: widget.inline ? 16 : 30),
          _ParticipantGrid(participants: data.participants, phase: phase),
          SizedBox(height: widget.inline ? 14 : 22),
        ] else
          const SizedBox(height: 10),
        Text(
          streamMicrophoneNote(
            retiring: retirementStarted,
            microphoneEnabled: data.microphoneEnabled,
            canSendAudio: data.canSendAudio,
            everCouldSendAudio: _hadSendAudio,
            speakSpent: _microphoneEnableRequested,
            speakLabel: barMicrophone
                ? context.l10n.common_unmute
                : context.l10n.chatCalls_streamForegroundViewSpeakLabel,
            speakAgainLabel: barMicrophone
                ? context.l10n.chatCalls_streamForegroundViewS3
                : context.l10n.chatCalls_streamForegroundViewSpeakAgainLabel,
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
    VoiceMicrophoneBridge? bridge,
  }) {
    final speakAgain = StreamSpeakAgainPolicy.offers(
      pageCanReconnect: widget.onSpeakAgainRequested != null,
      speakSpent: _microphoneEnableRequested,
      microphoneEnabled: data.microphoneEnabled,
      canSendAudio: data.canSendAudio,
      retirementStarted: retirementStarted,
    );
    // Decision 0115: on the room page the microphone is a slot of the fixed
    // bottom bar. The command behind it is this view's, unchanged.
    final VoidCallback? microphonePress = speakAgain
        ? (_speakAgainBusy || _leaveBusy || _microphoneBusy
              ? null
              : _requestSpeakAgain)
        : (!_microphoneBusy &&
                  !_leaveBusy &&
                  !_speakAgainBusy &&
                  canRequestMicrophone
              ? () => _setMicrophone(enabled: !data.microphoneEnabled)
              : null);
    _publishMicrophone(
      bridge,
      VoiceMicrophoneControl(
        label: streamBarMicrophoneLabel(
          speakAgain: speakAgain,
          speakAgainBusy: _speakAgainBusy,
          microphoneBusy: _microphoneBusy,
          microphoneEnabled: data.microphoneEnabled,
          canSendAudio: data.canSendAudio,
          speakSpent: _microphoneEnableRequested,
          retiring: retirementStarted,
        ),
        open: data.microphoneEnabled,
        busy: _microphoneBusy || _speakAgainBusy,
        enabled: microphonePress != null,
      ),
      microphonePress,
    );
    if (bridge != null) {
      // The bar carries the microphone and the way out (离开 / 结束房间);
      // what is left here is where the sound goes.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_commandError != null) ...<Widget>[
            Semantics(
              liveRegion: true,
              child: Text(
                _commandError!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: LoopColors.chalk),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.onOutputSelected != null)
            Align(
              alignment: Alignment.centerLeft,
              child: _OutputControl(
                current: data.output,
                preference: widget.outputPreference,
                onSelected: widget.onOutputSelected!,
              ),
            ),
        ],
      );
    }
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
                  ?.copyWith(color: LoopColors.chalk),
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
                  ? LoopButton(
                      key: const ValueKey<String>(
                        'voiceroom-media-speak-again',
                      ),
                      block: true,
                      icon: 'refresh',
                      label: _speakAgainBusy
                          ? context
                                .l10n
                                .chatCalls_streamForegroundViewVoiceroomMediaSpeakAgainLabel
                          : context
                                .l10n
                                .chatCalls_streamForegroundViewSpeakAgainLabel,
                      onPressed:
                          _speakAgainBusy || _leaveBusy || _microphoneBusy
                          ? null
                          : _requestSpeakAgain,
                    )
                  : LoopButton(
                      key: const ValueKey<String>('voiceroom-media-microphone'),
                      block: true,
                      onPressed:
                          !_microphoneBusy &&
                              !_leaveBusy &&
                              !_speakAgainBusy &&
                              canRequestMicrophone
                          ? () =>
                                _setMicrophone(enabled: !data.microphoneEnabled)
                          : null,
                      icon: data.microphoneEnabled
                          ? 'voice-off'
                          : data.canSendAudio &&
                                !_microphoneEnableRequested &&
                                !retirementStarted
                          ? 'mic'
                          : 'voice',
                      label: _microphoneBusy
                          ? context
                                .l10n
                                .chatCalls_streamForegroundViewVoiceroomMediaMicrophoneLabel
                          : data.microphoneEnabled
                          ? context.l10n.common_mute
                          : data.canSendAudio &&
                                !_microphoneEnableRequested &&
                                !retirementStarted
                          ? context
                                .l10n
                                .chatCalls_streamForegroundViewSpeakLabel
                          : retirementStarted
                          ? context
                                .l10n
                                .chatCalls_streamForegroundViewVoiceroomMediaMicrophoneLabel2
                          : data.canSendAudio
                          ? context
                                .l10n
                                .chatCalls_streamForegroundViewVoiceroomMediaMicrophoneLabel3
                          : context.l10n.chatCalls_streamForegroundViewS4,
                    ),
            ),
            if (widget.onOutputSelected != null) ...<Widget>[
              const SizedBox(width: 8),
              // A `LoopButton` measures its label inside the width it is
              // given; a bare Row child is given none.
              Flexible(
                child: _OutputControl(
                  current: data.output,
                  preference: widget.outputPreference,
                  onSelected: widget.onOutputSelected!,
                ),
              ),
            ],
            const SizedBox(width: 12),
            // Decision 0170: the prototype's `.btn-danger` — flat Chalk
            // with an Ink glyph. The pink disc is gone.
            Tooltip(
              message: context
                  .l10n
                  .chatCalls_streamForegroundViewVoiceroomMediaDisconnectMessage,
              excludeFromSemantics: true,
              child: LoopButton(
                key: const ValueKey<String>('voiceroom-media-disconnect'),
                primary: true,
                tone: LoopButtonTone.danger,
                icon: 'phone',
                label: '',
                semanticLabel: context
                    .l10n
                    .chatCalls_streamForegroundViewVoiceroomMediaDisconnectMessage,
                onPressed: _leaveBusy ? null : _leave,
              ),
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
        _commandError =
            LoopL10n.current.chatCalls_streamForegroundViewCommandError;
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
            : LoopL10n.current.chatCalls_streamForegroundViewSetState;
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
        _commandError =
            LoopL10n.current.chatCalls_streamForegroundViewCommandError2;
      });
      return;
    }
    // A leave that took the call down unmounts this view. One that asked the
    // page first can come back with the question declined, and the control
    // has to be usable again.
    if (mounted) setState(() => _leaveBusy = false);
  }
}

/// Speaker or receiver, and which one the sound is actually coming out of.
///
/// The label is the route the provider reads back. One tap asks for the other
/// built-in route; with a headset or a Bluetooth device connected the control
/// names that device and asks for nothing, because the sound goes there
/// whatever is chosen.
class _OutputControl extends StatelessWidget {
  const _OutputControl({
    required this.current,
    required this.preference,
    required this.onSelected,
  });

  final AudioRoomOutputRoute? current;
  final AudioRoomOutputPreference preference;
  final ValueChanged<AudioRoomOutputPreference> onSelected;

  @override
  Widget build(BuildContext context) {
    final next = audioRoomOutputToggle(
      current: current,
      preference: preference,
    );
    final label = audioRoomOutputLabel(current);
    final icon = switch (current?.kind) {
      AudioRoomOutputKind.earpiece => 'phone',
      AudioRoomOutputKind.speaker ||
      AudioRoomOutputKind.external ||
      null => 'voice',
    };
    final hint = next == null
        ? context.l10n.chatCalls_streamForegroundViewSwitch
        : next == AudioRoomOutputPreference.speaker
        ? context.l10n.chatCalls_streamForegroundViewSwitch2
        : context.l10n.chatCalls_streamForegroundViewS5;
    return Semantics(
      button: true,
      label: context.l10n
          .chatCalls_streamForegroundViewVoiceroomMediaOutputLabel(label),
      hint: hint,
      excludeSemantics: true,
      child: Tooltip(
        message: hint,
        child: LoopButton(
          key: const ValueKey<String>('voiceroom-media-output'),
          icon: icon,
          label: label,
          onPressed: next == null ? null : () => onSelected(next),
        ),
      ),
    );
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
        StreamCallPhase.reconnecting => VoiceMediaStateCard(
          title: context.l10n.chatCalls_streamForegroundViewTitle,
          message: context.l10n.chatCalls_streamForegroundViewMessage,
          icon: 'refresh',
        ),
        StreamCallPhase.disconnected => VoiceMediaStateCard(
          title: context.l10n.chatCalls_streamForegroundViewTitle2,
          message: context.l10n.chatCalls_streamForegroundViewMessage2,
          icon: 'voice-off',
        ),
        _ => VoiceMediaStateCard(
          title: context.l10n.chatCalls_streamForegroundViewTitle3,
          message: context.l10n.chatCalls_streamForegroundViewMessage3,
          icon: 'refresh',
        ),
      };
    }
    if (participants.isEmpty) {
      return VoiceMediaStateCard(
        title: context.l10n.chatCalls_streamForegroundViewTitle4,
        message: context.l10n.chatCalls_streamForegroundViewMessage4,
        icon: 'refresh',
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
    // Decision 0170: the `.record-card` ground. A speaker is marked by a
    // Lime hairline and a Lime glyph, never by the amber conversation accent.
    final accent = participant.isSpeaking ? LoopColors.purple : LoopColors.line;
    return DecoratedBox(
      key: ValueKey<String>(
        participant.isSpeaking
            ? 'voiceroom-participant-speaking'
            : 'voiceroom-participant',
      ),
      decoration: BoxDecoration(
        color: LoopColors.card,
        borderRadius: LoopRadius.card,
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
                color: LoopColors.card2,
                border: Border.all(color: LoopColors.line),
              ),
              child: Text(
                name.characters.first.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: LoopColors.chalk),
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
                        LoopBadge(
                          context.l10n.common_me,
                          kind: LoopBadgeKind.mute,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(role, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
            const SizedBox(width: 8),
            LoopIcon(
              participant.isAudioEnabled ? 'mic' : 'voice-off',
              size: 18,
              color: participant.isSpeaking
                  ? LoopColors.lime
                  : LoopColors.text3,
            ),
          ],
        ),
      ),
    );
  }
}
