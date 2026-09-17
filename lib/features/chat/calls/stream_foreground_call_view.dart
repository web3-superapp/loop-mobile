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
    this.inline = false,
  });

  final Call call;

  /// True when the view is one section of the LOOP voice room page.
  ///
  /// The page owns the only scrolling region, so an inline view adds neither a
  /// scroll view of its own nor a pinned dock: it lays out at its content
  /// height and its controls travel with the section above them.
  final bool inline;
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
          '${data.participantCount} 人在通话',
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
        _ParticipantGrid(participants: data.participants),
        SizedBox(height: widget.inline ? 14 : 22),
        Text(
          retirementStarted && !data.microphoneEnabled
              ? '正在退出这次通话。麦克风不会再启动；如有需要先静音，再重试退出。'
              : data.canSendAudio &&
                    _microphoneEnableRequested &&
                    !data.microphoneEnabled
              ? '麦克风已关闭。本版本要求先退出再重新进入，才能再次发言。'
              : data.canSendAudio
              ? '你以静音状态进入。准备好后点「发言」，系统麦克风权限只在开始采集时申请。'
              : '你在这个房间是只收听的角色。',
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
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    !_microphoneBusy && !_leaveBusy && canRequestMicrophone
                    ? () => _setMicrophone(enabled: !data.microphoneEnabled)
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
                      ? '重新进入后再发言'
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
            ? '麦克风没能启动。请检查房间权限与系统麦克风权限，退出后重新进入再试。'
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
        title: '读不到通话成员',
        message: '服务商还没有给出这次通话的成员明细。',
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
        ? '我'
        : '成员';
    final role = participant.isLocal
        ? '我'
        : participant.isSpeaking
        ? '正在发言'
        : participant.isAudioEnabled
        ? '麦克风已开'
        : '已静音';
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
