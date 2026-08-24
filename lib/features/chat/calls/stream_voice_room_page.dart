import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

/// Production-only foreground Stream Video boundary.
///
/// This slice authorizes a delayed SDK session but deliberately mounts no
/// `Call` yet. A backend room/callee contract and reviewed native media
/// permissions are both required before a call can exist. Once a call is
/// introduced, widgets in this module must subscribe directly to its official
/// `CallState` instead of copying phases into LOOP state.
class StreamVoiceRoomPage extends ConsumerWidget {
  const StreamVoiceRoomPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final principalKey = ref.watch(streamVideoPrincipalKeyProvider);
    final authorization = principalKey == null
        ? null
        : ref.watch(streamVideoAuthorizationProvider);
    final content = _contentFor(principalKey, authorization);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.25, -0.8),
            radius: 1.2,
            colors: <Color>[
              Color(0xFF182C2B),
              LoopColors.abyss,
              LoopColors.abyss,
            ],
            stops: <double>[0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: LoopColors.chat.withValues(alpha: 0.12),
                              border: Border.all(
                                color: LoopColors.chat.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.graphic_eq_rounded,
                              size: 42,
                              color: LoopColors.chat,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Loop Audio',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Foreground Stream Video session',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 26),
                          LoopStateCard(
                            title: content.title,
                            message: content.message,
                            tone: content.tone,
                            icon: content.icon,
                            action: content.loading
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : content.retry
                                ? OutlinedButton.icon(
                                    onPressed: () => ref.invalidate(
                                      streamVideoAuthorizationProvider,
                                    ),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Retry'),
                                  )
                                : null,
                          ),
                          if (content.ready) ...<Widget>[
                            const SizedBox(height: 16),
                            const LoopStatusPill(
                              label: 'Media permissions pending',
                              tone: LoopTone.warning,
                              icon: Icons.mic_off_rounded,
                            ),
                          ],
                          const SizedBox(height: 20),
                          Text(
                            'No preview members, room activity, ringing, or '
                            'presence is shown on this production surface.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              LoopActionDock(
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.headset_mic_rounded),
                    label: const Text('Join audio room'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _StreamVoiceContent _contentFor(
    String? principalKey,
    AsyncValue<StreamVideoSessionAuthorization>? authorization,
  ) {
    if (principalKey == null) {
      return const _StreamVoiceContent(
        title: 'Verified login required',
        message:
            'Stream Video starts only for a fully verified Privy session. '
            'Offline and unverified sessions stay restricted.',
        icon: Icons.lock_outline_rounded,
      );
    }
    if (authorization == null || authorization.isLoading) {
      return const _StreamVoiceContent(
        title: 'Preparing Stream Video',
        message:
            'Requesting the backend-derived Stream identity and short-lived '
            'user token. No call is created while this is pending.',
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (authorization.hasError ||
        authorization.value != StreamVideoSessionAuthorization.authorized) {
      return const _StreamVoiceContent(
        title: 'Stream session unavailable',
        message:
            'The public API key is present, but the backend Video identity and '
            'token source are not available. This screen remains offline.',
        tone: LoopTone.warning,
        icon: Icons.cloud_off_rounded,
        retry: true,
      );
    }
    return const _StreamVoiceContent(
      title: 'Foreground SDK ready',
      message:
          'The principal-bound Stream Video client is authorized. Joining '
          'stays disabled until a backend room contract and reviewed native '
          'media permissions are supplied.',
      tone: LoopTone.positive,
      icon: Icons.verified_user_outlined,
      ready: true,
    );
  }
}

class _StreamVoiceContent {
  const _StreamVoiceContent({
    required this.title,
    required this.message,
    required this.icon,
    this.tone = LoopTone.neutral,
    this.loading = false,
    this.retry = false,
    this.ready = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final LoopTone tone;
  final bool loading;
  final bool retry;
  final bool ready;
}
