import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/stream_voice_room_page.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class VoiceRoomPage extends ConsumerWidget {
  const VoiceRoomPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateway = ref.watch(communicationGatewayProvider);
    if (gateway.mode == CommunicationMode.production) {
      return const StreamVoiceRoomPage();
    }
    return _PreviewVoiceRoomPage(gateway: gateway);
  }
}

class _PreviewVoiceRoomPage extends ConsumerStatefulWidget {
  const _PreviewVoiceRoomPage({required this.gateway});

  final CommunicationGateway gateway;

  @override
  ConsumerState<_PreviewVoiceRoomPage> createState() =>
      _PreviewVoiceRoomPageState();
}

class _PreviewVoiceRoomPageState extends ConsumerState<_PreviewVoiceRoomPage> {
  var _handRaised = false;
  var _speakerOn = true;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(voiceSessionControllerProvider);
    final room = session.room ?? ChatContent.voiceRoom;
    final gateway = widget.gateway;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: 'Back',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => _showRoomMenu(context),
            tooltip: 'Room options',
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.3, -0.72),
            radius: 1.25,
            colors: <Color>[
              Color(0xFF352513),
              LoopColors.abyss,
              LoopColors.abyss,
            ],
            stops: <double>[0, 0.5, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                      sliver: SliverList.list(
                        children: <Widget>[
                          Center(
                            child: VoicePhasePill(
                              phase: session.phase,
                              mode: gateway.mode,
                              configured: gateway.isConfigured,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            room.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            room.topic,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.headphones_rounded,
                                size: 15,
                                color: LoopColors.vapor,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Offline preview · simulated room layout',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _FeaturedSpeaker(
                            participant: room.participants.first,
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'SIMULATED SEATS',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(letterSpacing: 1.1),
                                ),
                              ),
                              Text(
                                '${room.participants.length} preview participants',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 600;
                              final itemWidth = wide
                                  ? (constraints.maxWidth - 24) / 3
                                  : (constraints.maxWidth - 12) / 2;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: room.participants
                                    .skip(1)
                                    .take(5)
                                    .map((participant) {
                                      return SizedBox(
                                        width: itemWidth,
                                        child: _SpeakerCard(
                                          participant: participant,
                                        ),
                                      );
                                    })
                                    .toList(growable: false),
                              );
                            },
                          ),
                          if (session.phase ==
                              VoiceConnectionPhase.error) ...<Widget>[
                            const SizedBox(height: 20),
                            LoopStateCard(
                              title: 'Room connection interrupted',
                              message:
                                  session.errorMessage ??
                                  'Check your connection, then join again.',
                              tone: LoopTone.danger,
                              icon: Icons.wifi_off_rounded,
                              action: OutlinedButton.icon(
                                onPressed: () => ref
                                    .read(
                                      voiceSessionControllerProvider.notifier,
                                    )
                                    .retry(),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try again'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _VoiceControlDock(
                session: session,
                handRaised: _handRaised,
                speakerOn: _speakerOn,
                onJoin: () => ref
                    .read(voiceSessionControllerProvider.notifier)
                    .join(room),
                onMicrophone: () => ref
                    .read(voiceSessionControllerProvider.notifier)
                    .toggleMicrophone(),
                onHand: () => setState(() => _handRaised = !_handRaised),
                onSpeaker: () => setState(() => _speakerOn = !_speakerOn),
                onLeave: () async {
                  await ref
                      .read(voiceSessionControllerProvider.notifier)
                      .leave();
                  if (context.mounted) context.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedSpeaker extends StatelessWidget {
  const _FeaturedSpeaker({required this.participant});

  final VoiceParticipant participant;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: <Widget>[
          Container(
            width: 118,
            height: 118,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: LoopColors.line),
            ),
            child: ChatAvatar(
              label: participant.alias,
              size: 98,
              colorSeed: participant.colorSeed,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                participant.alias,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (participant.isHost) ...<Widget>[
                const SizedBox(width: 7),
                const LoopStatusPill(
                  label: 'HOST',
                  tone: LoopTone.conversation,
                  icon: Icons.stars_rounded,
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Simulated participant',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _SpeakerCard extends StatelessWidget {
  const _SpeakerCard({required this.participant});

  final VoiceParticipant participant;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LoopColors.basalt.withValues(alpha: 0.82),
        borderRadius: LoopRadius.medium,
        border: Border.all(color: LoopColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                ChatAvatar(
                  label: participant.alias,
                  size: 40,
                  colorSeed: participant.colorSeed,
                ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: LoopColors.elevated,
                      border: Border.all(color: LoopColors.line),
                    ),
                    child: Icon(
                      Icons.mic_off_rounded,
                      size: 10,
                      color: LoopColors.vapor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    participant.alias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Simulated participant',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceControlDock extends StatelessWidget {
  const _VoiceControlDock({
    required this.session,
    required this.handRaised,
    required this.speakerOn,
    required this.onJoin,
    required this.onMicrophone,
    required this.onHand,
    required this.onSpeaker,
    required this.onLeave,
  });

  final VoiceSessionState session;
  final bool handRaised;
  final bool speakerOn;
  final VoidCallback onJoin;
  final VoidCallback onMicrophone;
  final VoidCallback onHand;
  final VoidCallback onSpeaker;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (session.phase == VoiceConnectionPhase.idle) {
      return LoopActionDock(
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.mic_off_rounded),
            label: const Text('Open offline preview'),
            style: FilledButton.styleFrom(
              backgroundColor: LoopColors.chat,
              foregroundColor: LoopColors.abyss,
            ),
          ),
        ),
      );
    }
    if (session.phase == VoiceConnectionPhase.joining) {
      return LoopActionDock(
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 11),
              const Text('Opening simulated room…'),
            ],
          ),
        ),
      );
    }
    return LoopActionDock(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _RoundControl(
            icon: session.microphoneMuted
                ? Icons.mic_off_rounded
                : Icons.mic_rounded,
            label: session.microphoneMuted ? 'Preview muted' : 'Preview mic',
            selected: !session.microphoneMuted,
            onTap: onMicrophone,
          ),
          _RoundControl(
            icon: handRaised
                ? Icons.back_hand_rounded
                : Icons.back_hand_outlined,
            label: handRaised ? 'Simulated up' : 'Simulate hand',
            selected: handRaised,
            onTap: onHand,
          ),
          _RoundControl(
            icon: speakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: speakerOn ? 'Preview audio' : 'Preview quiet',
            selected: speakerOn,
            onTap: onSpeaker,
          ),
          _RoundControl(
            icon: Icons.call_end_rounded,
            label: 'Close preview',
            danger: true,
            onTap: onLeave,
          ),
        ],
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? LoopColors.danger
        : selected
        ? LoopColors.mint
        : LoopColors.chalk;
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: SizedBox(
          width: 66,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: danger
                      ? LoopColors.danger.withValues(alpha: 0.14)
                      : selected
                      ? LoopColors.mint.withValues(alpha: 0.14)
                      : LoopColors.elevated,
                  border: Border.all(
                    color: danger
                        ? LoopColors.danger.withValues(alpha: 0.4)
                        : selected
                        ? LoopColors.mint.withValues(alpha: 0.4)
                        : LoopColors.line,
                  ),
                ),
                child: Icon(
                  icon,
                  color: onTap == null ? LoopColors.vapor : color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 9,
                  color: onTap == null ? LoopColors.vapor : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showRoomMenu(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Room details'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: LoopColors.danger,
                ),
                title: const Text('Report room'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
