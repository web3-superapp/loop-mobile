import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

typedef _ForegroundCallViewData = ({
  CallStatus status,
  int participantCount,
  bool microphoneEnabled,
});

/// Foreground call UI driven only by the official Stream [CallState].
///
/// This widget is intentionally not mounted by the current production route:
/// the backend room/callee contract and native media permissions are missing.
/// Once a real [Call] is supplied, [PartialCallStateBuilder] remains the sole
/// phase/participant truth source and no parallel LOOP call state is created.
class StreamForegroundCallView extends StatelessWidget {
  const StreamForegroundCallView({required this.call, super.key, this.onLeft});

  final Call call;
  final VoidCallback? onLeft;

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder<_ForegroundCallViewData>(
      call: call,
      selector: (state) => (
        status: state.status,
        participantCount: state.callParticipants.length,
        microphoneEnabled: state.localParticipant?.isAudioEnabled ?? false,
      ),
      builder: (context, data) {
        return Column(
          children: <Widget>[
            LoopStatusPill(
              label: data.status.toStatusString(),
              tone: _toneFor(data.status),
              icon: _iconFor(data.status),
            ),
            const SizedBox(height: 12),
            Text(
              '${data.participantCount} participants',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            LoopActionDock(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: Icon(
                        data.microphoneEnabled
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                      ),
                      label: const Text('Media permissions pending'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: () async {
                      await call.leave();
                      onLeft?.call();
                    },
                    tooltip: 'Leave call',
                    style: IconButton.styleFrom(
                      backgroundColor: LoopColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.call_end_rounded),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static LoopTone _toneFor(CallStatus status) {
    if (status.isConnected || status.isJoined) return LoopTone.positive;
    if (status.isReconnecting || status.isConnecting || status.isJoining) {
      return LoopTone.warning;
    }
    if (status.isDisconnected) return LoopTone.danger;
    return LoopTone.conversation;
  }

  static IconData _iconFor(CallStatus status) {
    if (status.isConnected || status.isJoined) {
      return Icons.graphic_eq_rounded;
    }
    if (status.isReconnecting || status.isConnecting || status.isJoining) {
      return Icons.sync_rounded;
    }
    if (status.isDisconnected) return Icons.call_end_rounded;
    return Icons.phone_in_talk_outlined;
  }
}
