import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

/// Production-only, foreground Stream Audio Room boundary.
///
/// LOOP owns authorization, locator and command progress. Once joined, the
/// mounted foreground view reads connection, participants, capabilities and
/// microphone state directly from Stream's official CallState.
class StreamVoiceRoomPage extends ConsumerWidget {
  const StreamVoiceRoomPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final principalKey = ref.watch(streamVideoPrincipalKeyProvider);
    final authorization = principalKey == null
        ? null
        : ref.watch(streamVideoAuthorizationProvider);
    final authorized =
        authorization?.value == StreamVideoSessionAuthorization.authorized;
    final target = authorized ? ref.watch(audioRoomTargetProvider) : null;
    final callFactory = authorized
        ? ref.watch(audioRoomCallFactoryProvider)
        : null;

    return _StreamVoiceRoomSurface(
      key: ValueKey<String?>(principalKey),
      principalKey: principalKey,
      authorization: authorization,
      target: target,
      callFactory: callFactory,
      onRetryAuthorization: () =>
          ref.invalidate(streamVideoAuthorizationProvider),
      onRetryTarget: () => ref.invalidate(audioRoomTargetProvider),
    );
  }
}

class _StreamVoiceRoomSurface extends StatefulWidget {
  const _StreamVoiceRoomSurface({
    required this.principalKey,
    required this.authorization,
    required this.target,
    required this.callFactory,
    required this.onRetryAuthorization,
    required this.onRetryTarget,
    super.key,
  });

  final String? principalKey;
  final AsyncValue<StreamVideoSessionAuthorization>? authorization;
  final AsyncValue<AudioRoomTarget?>? target;
  final AudioRoomCallFactory? callFactory;
  final VoidCallback onRetryAuthorization;
  final VoidCallback onRetryTarget;

  @override
  State<_StreamVoiceRoomSurface> createState() =>
      _StreamVoiceRoomSurfaceState();
}

class _StreamVoiceRoomSurfaceState extends State<_StreamVoiceRoomSurface>
    with WidgetsBindingObserver {
  AudioRoomCallHandle? _joiningCall;
  AudioRoomCallHandle? _foregroundCall;
  List<AudioRoomCallHandle> _cleanupHandles = const <AudioRoomCallHandle>[];
  Future<List<bool>>? _backgroundRetirement;
  var _appIsForeground = true;
  var _cleanupPending = false;
  var _cleanupFailed = false;
  var _joining = false;
  var _leaving = false;
  var _generation = 0;
  var _cleanupGeneration = 0;
  var _lifecycleGeneration = 0;
  String? _joinError;

  AudioRoomTarget? get _target {
    final value = widget.target;
    return value != null && value.hasValue ? value.value : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appIsForeground =
        lifecycle == null ||
        lifecycle == AppLifecycleState.resumed ||
        lifecycle == AppLifecycleState.inactive;
  }

  @override
  void didUpdateWidget(covariant _StreamVoiceRoomSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTarget = oldWidget.target;
    final oldRoomId = oldTarget != null && oldTarget.hasValue
        ? oldTarget.value?.roomId
        : null;
    final newRoomId = _target?.roomId;
    final boundRoomId = _foregroundCall?.roomId ?? _joiningCall?.roomId;
    final callFactoryChanged = !identical(
      oldWidget.callFactory,
      widget.callFactory,
    );
    if (boundRoomId != null &&
        (callFactoryChanged ||
            newRoomId != boundRoomId ||
            oldRoomId != newRoomId)) {
      _retireForTargetChange();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation += 1;
    _cleanupGeneration += 1;
    _lifecycleGeneration += 1;
    final joiningCall = _joiningCall;
    final foregroundCall = _foregroundCall;
    _joiningCall = null;
    _foregroundCall = null;
    final handles = _uniqueHandles(<AudioRoomCallHandle?>[
      joiningCall,
      foregroundCall,
      ..._cleanupHandles,
    ]);
    for (final handle in handles) {
      unawaited(_retireIgnoringFailure(handle));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      final lifecycleGeneration = ++_lifecycleGeneration;
      if (!_appIsForeground) {
        unawaited(
          _resumeAfterBackgroundRetirement(
            lifecycleGeneration,
            _backgroundRetirement,
          ),
        );
      }
      return;
    }
    final movedToBackground =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (movedToBackground) {
      _lifecycleGeneration += 1;
      if (_appIsForeground) _retireForBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    final foregroundCall = _foregroundCall;
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
          child: foregroundCall == null
              ? _buildLobby(context)
              : foregroundCall.buildForeground(
                  onLeaveRequested: _leaveForegroundCall,
                ),
        ),
      ),
    );
  }

  Widget _buildLobby(BuildContext context) {
    final content = _contentFor(
      principalKey: widget.principalKey,
      authorization: widget.authorization,
      target: widget.target,
      callFactory: widget.callFactory,
      joinError: _joinError,
      appIsForeground: _appIsForeground,
      cleanupPending: _cleanupPending,
      cleanupFailed: _cleanupFailed,
    );
    return Column(
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
                      'Foreground audio room',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 26),
                    Semantics(
                      liveRegion: content.tone == LoopTone.danger,
                      child: LoopStateCard(
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
                            : content.retryAuthorization
                            ? OutlinedButton.icon(
                                onPressed: widget.onRetryAuthorization,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry session'),
                              )
                            : content.retryTarget
                            ? OutlinedButton.icon(
                                onPressed: widget.onRetryTarget,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry room'),
                              )
                            : content.retryCleanup
                            ? OutlinedButton.icon(
                                onPressed: _retryCleanup,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry cleanup'),
                              )
                            : null,
                      ),
                    ),
                    if (content.ready) ...<Widget>[
                      const SizedBox(height: 16),
                      const _AudioRoomLobbyFacts(),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'No preview members, presence, ringing, or room activity is shown on this production surface.',
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
              onPressed:
                  content.ready &&
                      !_joining &&
                      !_cleanupPending &&
                      !_cleanupFailed
                  ? _joinMuted
                  : null,
              icon: _joining
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.headset_mic_rounded),
              label: Text(_joining ? 'Joining muted' : 'Join audio room'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _joinMuted() async {
    if (!_appIsForeground ||
        _cleanupPending ||
        _cleanupFailed ||
        _joining ||
        _foregroundCall != null) {
      return;
    }
    final target = _target;
    final factory = widget.callFactory;
    if (target == null || factory == null) return;

    final generation = ++_generation;
    AudioRoomCallHandle? handle;
    try {
      handle = factory.create(target);
      if (handle.roomId != target.roomId) {
        throw const AudioRoomCallFailure(AudioRoomCallFailureKind.join);
      }
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _joinError = 'The authorized room could not be prepared. Retry after checking your session.';
      });
      return;
    }

    final AudioRoomCallHandle callHandle = handle;
    setState(() {
      _joining = true;
      _joiningCall = callHandle;
      _foregroundCall = callHandle;
      _joinError = null;
    });

    try {
      await callHandle.joinMuted();
    } catch (_) {
      if (!mounted || generation != _generation) {
        await _retireIgnoringFailure(callHandle);
        return;
      }
      final cleanupGeneration = ++_cleanupGeneration;
      setState(() {
        _joining = false;
        _joiningCall = null;
        _foregroundCall = null;
        _cleanupHandles = <AudioRoomCallHandle>[callHandle];
        _cleanupPending = true;
        _cleanupFailed = false;
        _joinError = 'Could not join this audio room. Check room access and connection, then retry.';
      });
      await _completeCleanup(<AudioRoomCallHandle>[
        callHandle,
      ], cleanupGeneration);
      return;
    }

    if (!mounted || generation != _generation) {
      await _retireIgnoringFailure(callHandle);
      return;
    }
    setState(() {
      _joining = false;
      _joiningCall = null;
    });
  }

  Future<void> _leaveForegroundCall() async {
    if (_leaving) return;
    final handle = _foregroundCall;
    if (handle == null) return;
    _leaving = true;
    _generation += 1;
    try {
      await handle.leave();
    } catch (_) {
      if (mounted) setState(() => _leaving = false);
      rethrow;
    }
    if (!mounted) return;
    setState(() {
      if (identical(_foregroundCall, handle)) _foregroundCall = null;
      if (identical(_joiningCall, handle)) _joiningCall = null;
      _joining = false;
      _leaving = false;
      _joinError = null;
    });
  }

  void _retireForTargetChange() {
    _generation += 1;
    final joiningCall = _joiningCall;
    final foregroundCall = _foregroundCall;
    final handles = _uniqueHandles(<AudioRoomCallHandle?>[
      joiningCall,
      foregroundCall,
    ]);
    if (handles.isEmpty) return;
    final cleanupGeneration = ++_cleanupGeneration;
    setState(() {
      _joining = false;
      _leaving = false;
      _joiningCall = null;
      _foregroundCall = null;
      _cleanupHandles = handles;
      _cleanupPending = true;
      _cleanupFailed = false;
      _joinError = null;
    });
    unawaited(_completeCleanup(handles, cleanupGeneration));
  }

  void _retireForBackground() {
    _generation += 1;
    _cleanupGeneration += 1;
    final joiningCall = _joiningCall;
    final foregroundCall = _foregroundCall;
    final handles = _uniqueHandles(<AudioRoomCallHandle?>[
      joiningCall,
      foregroundCall,
      ..._cleanupHandles,
    ]);
    setState(() {
      _appIsForeground = false;
      _joining = false;
      _leaving = false;
      _joiningCall = null;
      _foregroundCall = null;
      _cleanupHandles = handles;
      _cleanupPending = handles.isNotEmpty;
      _cleanupFailed = false;
      _joinError = null;
    });
    _backgroundRetirement = Future.wait<bool>(
      handles.map((handle) => _retireIgnoringFailure(handle, background: true)),
    );
  }

  Future<void> _resumeAfterBackgroundRetirement(
    int lifecycleGeneration,
    Future<List<bool>>? retirement,
  ) async {
    final results = retirement == null ? const <bool>[] : await retirement;
    if (!mounted ||
        lifecycleGeneration != _lifecycleGeneration ||
        _appIsForeground) {
      return;
    }
    final failed = results.any((retired) => !retired);
    setState(() {
      _backgroundRetirement = null;
      _appIsForeground = true;
      _cleanupPending = false;
      _cleanupFailed = failed;
      if (!failed) _cleanupHandles = const <AudioRoomCallHandle>[];
    });
  }

  Future<void> _retryCleanup() async {
    if (_cleanupPending || _cleanupHandles.isEmpty) return;
    final handles = List<AudioRoomCallHandle>.of(_cleanupHandles);
    final cleanupGeneration = ++_cleanupGeneration;
    setState(() {
      _cleanupPending = true;
      _cleanupFailed = false;
    });
    await _completeCleanup(handles, cleanupGeneration);
  }

  Future<void> _completeCleanup(
    List<AudioRoomCallHandle> handles,
    int cleanupGeneration,
  ) async {
    final results = await Future.wait<bool>(
      handles.map(_retireIgnoringFailure),
    );
    if (!mounted || cleanupGeneration != _cleanupGeneration) return;
    final failed = results.any((retired) => !retired);
    setState(() {
      _cleanupPending = false;
      _cleanupFailed = failed;
      if (!failed) _cleanupHandles = const <AudioRoomCallHandle>[];
    });
  }

  static Future<bool> _retireIgnoringFailure(
    AudioRoomCallHandle handle, {
    bool background = false,
  }) async {
    try {
      if (background) {
        await handle.retireForBackground();
      } else {
        await handle.leave();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<AudioRoomCallHandle> _uniqueHandles(
    Iterable<AudioRoomCallHandle?> candidates,
  ) {
    final result = <AudioRoomCallHandle>[];
    for (final candidate in candidates) {
      if (candidate != null &&
          !result.any((existing) => identical(existing, candidate))) {
        result.add(candidate);
      }
    }
    return result;
  }

  static _StreamVoiceContent _contentFor({
    required String? principalKey,
    required AsyncValue<StreamVideoSessionAuthorization>? authorization,
    required AsyncValue<AudioRoomTarget?>? target,
    required AudioRoomCallFactory? callFactory,
    required String? joinError,
    required bool appIsForeground,
    required bool cleanupPending,
    required bool cleanupFailed,
  }) {
    if (principalKey == null) {
      return const _StreamVoiceContent(
        title: 'Verified login required',
        message: 'Stream Video starts only for a fully verified Privy session. Offline and unverified sessions stay restricted.',
        icon: Icons.lock_outline_rounded,
      );
    }
    if (!appIsForeground) {
      return const _StreamVoiceContent(
        title: 'Audio room paused',
        message: 'LOOP left the foreground. Microphone shutdown and room departure must be confirmed before this screen can be used again.',
        tone: LoopTone.warning,
        icon: Icons.pause_circle_outline_rounded,
      );
    }
    if (cleanupPending) {
      return const _StreamVoiceContent(
        title: 'Confirming room cleanup',
        message: 'Join stays disabled until microphone shutdown and departure from the previous Call are confirmed.',
        tone: LoopTone.warning,
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (cleanupFailed) {
      return const _StreamVoiceContent(
        title: 'Room cleanup incomplete',
        message: 'The previous Call did not confirm departure. Retry cleanup before joining any room.',
        tone: LoopTone.danger,
        icon: Icons.sync_problem_rounded,
        retryCleanup: true,
      );
    }
    if (authorization == null || authorization.isLoading) {
      return const _StreamVoiceContent(
        title: 'Preparing Stream Video',
        message: 'Requesting the backend-derived Stream identity and short-lived user token. No room is joined while this is pending.',
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (authorization.hasError ||
        authorization.value != StreamVideoSessionAuthorization.authorized) {
      return const _StreamVoiceContent(
        title: 'Stream session unavailable',
        message: 'The backend Video token source is not available. This screen stays offline and no Call is created.',
        tone: LoopTone.warning,
        icon: Icons.cloud_off_rounded,
        retryAuthorization: true,
      );
    }
    if (target == null || target.isLoading) {
      return const _StreamVoiceContent(
        title: 'Finding your audio room',
        message: 'Loading a backend-authorized Audio Room ID. Microphone capture remains off.',
        icon: Icons.meeting_room_outlined,
        loading: true,
      );
    }
    if (target.hasError) {
      return const _StreamVoiceContent(
        title: 'Audio room unavailable',
        message: 'The authorized room could not be loaded. No client-selected room or preview fallback is used.',
        tone: LoopTone.warning,
        icon: Icons.meeting_room_outlined,
        retryTarget: true,
      );
    }
    if (target.value == null) {
      return const _StreamVoiceContent(
        title: 'No authorized room assigned',
        message: 'The mobile room locator is not connected yet. Ask the backend for a pre-created room and member role before joining.',
        tone: LoopTone.warning,
        icon: Icons.meeting_room_outlined,
        retryTarget: true,
      );
    }
    if (callFactory == null) {
      return const _StreamVoiceContent(
        title: 'Media client unavailable',
        message: 'The room is authorized, but the principal-bound Stream Video client is no longer available. Re-authorize the session.',
        tone: LoopTone.warning,
        icon: Icons.sync_problem_rounded,
        retryAuthorization: true,
      );
    }
    if (joinError != null) {
      return _StreamVoiceContent(
        title: 'Join failed',
        message: joinError,
        tone: LoopTone.danger,
        icon: Icons.wifi_off_rounded,
        ready: true,
      );
    }
    return const _StreamVoiceContent(
      title: 'Audio room ready',
      message: 'A backend-authorized room is assigned. Entry is foreground-only and always starts muted.',
      tone: LoopTone.positive,
      icon: Icons.verified_user_outlined,
      ready: true,
    );
  }
}

class _AudioRoomLobbyFacts extends StatelessWidget {
  const _AudioRoomLobbyFacts();

  @override
  Widget build(BuildContext context) {
    return const LoopCard(
      child: Column(
        children: <Widget>[
          _LobbyFact(
            icon: Icons.mic_off_rounded,
            title: 'Muted on entry',
            message: 'No local audio track is published while joining.',
          ),
          Divider(height: 25),
          _LobbyFact(
            icon: Icons.security_rounded,
            title: 'Permission when needed',
            message: 'System microphone permission is requested only after you tap Speak.',
          ),
          Divider(height: 25),
          _LobbyFact(
            icon: Icons.phone_android_rounded,
            title: 'Foreground only',
            message: 'Leaving this screen retires the active room call.',
          ),
        ],
      ),
    );
  }
}

class _LobbyFact extends StatelessWidget {
  const _LobbyFact({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: LoopColors.chat),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
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
    this.retryAuthorization = false,
    this.retryTarget = false,
    this.retryCleanup = false,
    this.ready = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final LoopTone tone;
  final bool loading;
  final bool retryAuthorization;
  final bool retryTarget;
  final bool retryCleanup;
  final bool ready;
}
