import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

typedef _ForegroundCallViewData = ({
  CallStatus status,
  int participantCount,
  List<CallParticipantState> participants,
  bool microphoneEnabled,
  bool canSendAudio,
  bool audioSuspended,
});

/// Presentation-only mapping for Stream's official call status.
///
/// The mapping never becomes a second call state machine; every rebuild still
/// reads the current [CallStatus] from the SDK's [CallState].
abstract final class StreamCallStatusPresentation {
  static String label(CallStatus status) {
    if (status is CallStatusReconnectionFailed) return 'Reconnect failed';
    if (status.isIdle) return 'Waiting';
    if (status.isJoining) return 'Joining';
    if (status.isJoined) return 'Connecting media';
    if (status.isConnected) return 'Live';
    if (status.isReconnecting) return 'Reconnecting';
    if (status.isMigrating) return 'Moving connection';
    if (status.isConnecting) return 'Connecting';
    if (status.isDisconnected) return 'Disconnected';
    return 'Call unavailable';
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

/// Foreground Audio Room UI driven directly by Stream's official [CallState].
///
/// Only microphone/leave command progress and sanitized command errors are
/// local. Connection, participant, capability, and microphone truth is never
/// copied into LOOP state.
class StreamForegroundCallView extends StatefulWidget {
  const StreamForegroundCallView({
    required this.call,
    required this.retirementStarted,
    required this.onMicrophoneRequested,
    required this.onLeaveRequested,
    super.key,
  });

  final Call call;
  final bool Function() retirementStarted;
  final Future<bool> Function({required bool enabled}) onMicrophoneRequested;
  final Future<void> Function() onLeaveRequested;

  @override
  State<StreamForegroundCallView> createState() =>
      _StreamForegroundCallViewState();
}

class _StreamForegroundCallViewState extends State<StreamForegroundCallView> {
  var _microphoneBusy = false;
  var _leaveBusy = false;
  var _microphoneEnableRequested = false;
  String? _commandError;

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
          participants: participants.take(8).toList(growable: false),
          microphoneEnabled: state.localParticipant?.isAudioEnabled ?? false,
          canSendAudio: state.ownCapabilities.contains(
            CallPermission.sendAudio,
          ),
          audioSuspended: state.isAudioSuspended,
        );
      },
      builder: (context, data) {
        final retirementStarted = widget.retirementStarted();
        final canRequestMicrophone = StreamMicrophoneControlPolicy.canRequest(
          status: data.status,
          microphoneEnabled: data.microphoneEnabled,
          canSendAudio: data.canSendAudio,
          audioSuspended: data.audioSuspended,
          microphoneEnableRequested: _microphoneEnableRequested,
          retirementStarted: retirementStarted,
        );
        return Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      children: <Widget>[
                        LoopStatusPill(
                          label: StreamCallStatusPresentation.label(
                            data.status,
                          ),
                          tone: StreamCallStatusPresentation.tone(data.status),
                          icon: StreamCallStatusPresentation.icon(data.status),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Loop Audio Room',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${data.participantCount} '
                          '${data.participantCount == 1 ? 'participant' : 'participants'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (data.audioSuspended) ...<Widget>[
                          const SizedBox(height: 14),
                          const LoopStatusPill(
                            label: 'Audio paused by system',
                            tone: LoopTone.warning,
                            icon: Icons.pause_circle_outline_rounded,
                          ),
                        ],
                        const SizedBox(height: 30),
                        _ParticipantGrid(participants: data.participants),
                        const SizedBox(height: 22),
                        Text(
                          retirementStarted && !data.microphoneEnabled
                              ? 'Room departure has started. Capture cannot restart; mute if needed, then retry Leave.'
                              : data.canSendAudio &&
                                    _microphoneEnableRequested &&
                                    !data.microphoneEnabled
                              ? 'Microphone capture is off. For foreground Audio Room v1 safety, leave and rejoin before speaking again.'
                              : data.canSendAudio
                              ? 'You joined muted. Tap Speak when you are ready; system microphone permission is requested only when capture starts.'
                              : 'Your Stream role is listen-only in this room.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            LoopActionDock(
              child: Column(
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
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              !_microphoneBusy &&
                                  !_leaveBusy &&
                                  canRequestMicrophone
                              ? () => _setMicrophone(
                                  enabled: !data.microphoneEnabled,
                                )
                              : null,
                          icon: _microphoneBusy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                                ? 'Updating microphone'
                                : data.microphoneEnabled
                                ? 'Mute'
                                : data.canSendAudio &&
                                      !_microphoneEnableRequested &&
                                      !retirementStarted
                                ? 'Speak'
                                : retirementStarted
                                ? 'Leave retry required'
                                : data.canSendAudio
                                ? 'Rejoin to speak'
                                : 'Listen only',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: _leaveBusy ? null : _leave,
                        tooltip: 'Leave audio room',
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
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setMicrophone({required bool enabled}) async {
    if (_microphoneBusy || _leaveBusy) return;
    setState(() {
      _microphoneBusy = true;
      if (enabled) _microphoneEnableRequested = true;
      _commandError = null;
    });

    var succeeded = false;
    try {
      succeeded = await widget.onMicrophoneRequested(enabled: enabled);
    } catch (_) {
      succeeded = false;
    }
    if (!mounted) return;
    setState(() {
      _microphoneBusy = false;
      if (!succeeded) {
        _commandError = enabled
            ? 'Microphone could not start. Check room access and system permission, then leave and rejoin before trying again.'
            : 'Microphone could not be muted. Try again or leave the room.';
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
        _commandError = 'The room could not be closed cleanly. Try again.';
      });
    }
  }
}

class _ParticipantGrid extends StatelessWidget {
  const _ParticipantGrid({required this.participants});

  final List<CallParticipantState> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const LoopStateCard(
        title: 'Participant details unavailable',
        message: 'Stream has not published participant details for the current call state yet.',
        icon: Icons.people_outline_rounded,
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
    final suppliedName = participant.name.trim();
    final name = suppliedName.isNotEmpty
        ? suppliedName
        : participant.isLocal
        ? 'You'
        : 'Participant';
    final role = participant.isLocal
        ? 'You'
        : participant.isSpeaking
        ? 'Speaking'
        : participant.isAudioEnabled
        ? 'Microphone on'
        : 'Muted';
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
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
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
