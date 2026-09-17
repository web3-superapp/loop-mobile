import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_link.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

/// Production-only, foreground Stream Audio Room boundary.
///
/// LOOP owns authorization, locator and command progress. Once joined, the
/// mounted foreground view reads connection, participants, capabilities and
/// microphone state directly from Stream's official CallState.
class StreamVoiceRoomPage extends ConsumerWidget {
  const StreamVoiceRoomPage({
    super.key,
    this.target,
    this.inline = false,
    this.autoConnect = false,
    this.link,
    this.onExitRequested,
  });

  /// A locator the caller already holds.
  ///
  /// The community voice pages resolve their room through the LOOP backend and
  /// hand the authorized room straight in, so the lobby never has to read a
  /// scoped provider. When it is null the page falls back to
  /// [audioRoomTargetProvider], whose production default performs no request.
  final AudioRoomTarget? target;

  /// Renders as one section of the LOOP voice room page instead of a page of
  /// its own. A page inside a page is what produced the second scrolling
  /// region a reader could not explain; an inline surface has none.
  final bool inline;

  /// Connects as soon as the room is ready, without a second tap.
  ///
  /// Joining a voice room is one decision: a member who was let in expects to
  /// hear the room. The caller sets this only once LOOP has granted the
  /// membership, so the connection carries an authorization that already
  /// exists. Nothing about the microphone changes — the account still enters
  /// muted and the system permission is still asked for only at 发言.
  final bool autoConnect;

  /// Publishes this surface's disconnect to the page that owns the exit.
  final VoiceMediaLink? link;

  /// Replaces the in-call hang-up with the page's single 离开 command.
  ///
  /// Dropping the media alone would leave the account a member of a room it
  /// can no longer hear, and [autoConnect] would immediately reconnect it.
  final Future<void> Function()? onExitRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final principalKey = ref.watch(streamVideoPrincipalKeyProvider);
    final authorization = principalKey == null
        ? null
        : ref.watch(streamVideoAuthorizationProvider);
    final authorized =
        authorization?.value == StreamVideoSessionAuthorization.authorized;
    final suppliedTarget = target;
    final resolvedTarget = !authorized
        ? null
        : suppliedTarget != null
        ? AsyncValue<AudioRoomTarget?>.data(suppliedTarget)
        : ref.watch(audioRoomTargetProvider);
    final callFactory = authorized
        ? ref.watch(audioRoomCallFactoryProvider)
        : null;

    return _StreamVoiceRoomSurface(
      key: ValueKey<String?>(principalKey),
      inline: inline,
      autoConnect: autoConnect,
      link: link,
      onExitRequested: onExitRequested,
      principalKey: principalKey,
      authorization: authorization,
      target: resolvedTarget,
      callFactory: callFactory,
      onRetryAuthorization: () =>
          ref.invalidate(streamVideoAuthorizationProvider),
      onRetryTarget: suppliedTarget != null
          ? null
          : () => ref.invalidate(audioRoomTargetProvider),
    );
  }
}

class _StreamVoiceRoomSurface extends StatefulWidget {
  const _StreamVoiceRoomSurface({
    required this.inline,
    required this.autoConnect,
    required this.link,
    required this.onExitRequested,
    required this.principalKey,
    required this.authorization,
    required this.target,
    required this.callFactory,
    required this.onRetryAuthorization,
    required this.onRetryTarget,
    super.key,
  });

  final bool inline;
  final bool autoConnect;
  final VoiceMediaLink? link;
  final Future<void> Function()? onExitRequested;
  final String? principalKey;
  final AsyncValue<StreamVideoSessionAuthorization>? authorization;
  final AsyncValue<AudioRoomTarget?>? target;
  final AudioRoomCallFactory? callFactory;
  final VoidCallback onRetryAuthorization;

  /// Null when the caller supplied the target: there is no provider to
  /// invalidate, so no retry is offered.
  final VoidCallback? onRetryTarget;

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

  /// Set once this account starts leaving, or once a connection failed, so a
  /// ready room does not silently reconnect behind the reader's decision.
  var _autoConnectSuspended = false;
  var _autoConnectScheduled = false;
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
    widget.link?.attach(_disconnectForExit);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appIsForeground =
        lifecycle == null ||
        lifecycle == AppLifecycleState.resumed ||
        lifecycle == AppLifecycleState.inactive;
  }

  @override
  void didUpdateWidget(covariant _StreamVoiceRoomSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.link, widget.link)) {
      oldWidget.link?.detach(_disconnectForExit);
      widget.link?.attach(_disconnectForExit);
    }
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
    widget.link?.detach(_disconnectForExit);
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
    if (widget.inline) {
      // The voice room page owns the only scrolling region on the screen, so
      // the inline surface is a plain section: no Scaffold, no app bar of its
      // own, and no second scroll view.
      return foregroundCall == null
          ? _buildLobby(context)
          : foregroundCall.buildForeground(
              onLeaveRequested: _requestExit,
              inline: true,
            );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: '返回',
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
              : foregroundCall.buildForeground(onLeaveRequested: _requestExit),
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
      autoConnect: widget.autoConnect,
      autoConnectSuspended: _autoConnectSuspended,
    );
    final joinEnabled =
        content.ready && !_joining && !_cleanupPending && !_cleanupFailed;
    if (widget.autoConnect && joinEnabled && !content.reconnect) {
      _scheduleAutoConnect();
    }
    final stateCard = Semantics(
      liveRegion: content.tone == LoopTone.danger,
      child: LoopStateCard(
        title: content.title,
        message: content.message,
        tone: content.tone,
        icon: content.icon,
        action: content.loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : content.retryAuthorization
            ? OutlinedButton.icon(
                onPressed: widget.onRetryAuthorization,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试会话'),
              )
            : content.retryTarget && widget.onRetryTarget != null
            ? OutlinedButton.icon(
                onPressed: widget.onRetryTarget,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试读取语音房'),
              )
            : content.retryCleanup
            ? OutlinedButton.icon(
                onPressed: _retryCleanup,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试收尾'),
              )
            : null,
      ),
    );
    final joinButton = SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: joinEnabled ? _joinMuted : null,
        icon: _joining
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.headset_mic_rounded),
        label: Text(_joining ? '正在静音连接' : '连接语音'),
      ),
    );
    if (widget.autoConnect) {
      // The connection is not a second decision, so the surface offers no
      // button for it. One appears only when the connection stopped: the
      // membership is still there, and this is how the reader gets the audio
      // back without leaving and joining again.
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            stateCard,
            if (content.reconnect) ...<Widget>[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey<String>('voiceroom-media-reconnect'),
                  onPressed: joinEnabled ? _reconnect : null,
                  icon: const Icon(Icons.headset_mic_rounded),
                  label: const Text('重新连接语音'),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '你以听众身份静音进入，不会申请麦克风权限；'
              '语音没连上也不会把你移出房间，要真正退出请用下面的「离开」。',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      );
    }
    if (widget.inline) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            stateCard,
            const SizedBox(height: 14),
            joinButton,
            const SizedBox(height: 10),
            Text(
              '连接只在前台进行，且始终静音进入；系统麦克风权限只在你点「发言」时申请。',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      );
    }
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
                      '语音房',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '仅前台连接',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 26),
                    stateCard,
                    if (content.ready) ...<Widget>[
                      const SizedBox(height: 16),
                      const _AudioRoomLobbyFacts(),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      '这里不展示演示成员、在线状态或房间动态。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        LoopActionDock(child: joinButton),
      ],
    );
  }

  /// Starts the connection the membership already paid for.
  ///
  /// A write is not allowed from inside `build`, so the attempt runs on the
  /// microtask after the frame that found the room ready. Every refusal
  /// [_joinMuted] already makes — not foreground, cleanup outstanding, a call
  /// in flight — still applies, and a failure sets [_joinError], which stops
  /// this from firing again until the reader asks for it.
  void _scheduleAutoConnect() {
    if (_autoConnectScheduled ||
        _autoConnectSuspended ||
        _joining ||
        _joinError != null ||
        _foregroundCall != null) {
      return;
    }
    _autoConnectScheduled = true;
    scheduleMicrotask(() {
      _autoConnectScheduled = false;
      if (!mounted ||
          !widget.autoConnect ||
          _autoConnectSuspended ||
          _joinError != null) {
        return;
      }
      unawaited(_joinMuted());
    });
  }

  /// The reader's own request for the audio back after a failed connection.
  Future<void> _reconnect() {
    setState(() {
      _autoConnectSuspended = false;
      _joinError = null;
    });
    return _joinMuted();
  }

  /// The single exit, asked for from inside the call view.
  ///
  /// When the page supplied one, leaving is its decision: it confirms, takes
  /// this call down through [VoiceMediaLink] and then releases the LOOP
  /// membership. Without a page there is only the call to retire.
  Future<void> _requestExit() {
    final exit = widget.onExitRequested;
    return exit == null ? _leaveForegroundCall() : exit();
  }

  /// Published to the page through [VoiceMediaLink].
  Future<void> _disconnectForExit() async {
    if (!_autoConnectSuspended) {
      // The membership is about to end; a ready room must not reconnect in
      // the window between this disconnect and the LOOP leave.
      if (mounted) {
        setState(() => _autoConnectSuspended = true);
      } else {
        _autoConnectSuspended = true;
      }
    }
    if (_foregroundCall == null) return;
    await _leaveForegroundCall();
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
        _joinError = '这个语音房没能准备好，请检查会话后重试。';
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
        _joinError = '没能连上这个语音房，请检查房间权限与网络后重试。';
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
    _autoConnectSuspended = true;
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
      _autoConnectSuspended = false;
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

  /// The lobby sentence for a surface that connects on its own.
  ///
  /// The diagnosis below is unchanged — the reader is told which step did not
  /// finish and is offered the same retry. What changes is the heading: this
  /// account is already a member of the room, so a media failure must never
  /// read as "you are not in the room".
  static _StreamVoiceContent _contentFor({
    required String? principalKey,
    required AsyncValue<StreamVideoSessionAuthorization>? authorization,
    required AsyncValue<AudioRoomTarget?>? target,
    required AudioRoomCallFactory? callFactory,
    required String? joinError,
    required bool appIsForeground,
    required bool cleanupPending,
    required bool cleanupFailed,
    required bool autoConnect,
    required bool autoConnectSuspended,
  }) {
    final content = _baseContentFor(
      principalKey: principalKey,
      authorization: authorization,
      target: target,
      callFactory: callFactory,
      joinError: joinError,
      appIsForeground: appIsForeground,
      cleanupPending: cleanupPending,
      cleanupFailed: cleanupFailed,
    );
    if (!autoConnect) return content;
    if (content.ready) {
      if (joinError != null) {
        return _StreamVoiceContent(
          title: '已加入，语音连接失败',
          message: '$joinError你仍然在这个房间里，没有被移出。',
          tone: LoopTone.danger,
          icon: Icons.wifi_off_rounded,
          ready: true,
          reconnect: true,
        );
      }
      if (autoConnectSuspended) {
        return const _StreamVoiceContent(
          title: '语音已断开',
          message: '这次通话已经断开，你在 LOOP 记录里仍然是这个房间的成员。',
          tone: LoopTone.warning,
          icon: Icons.headset_off_rounded,
          ready: true,
          reconnect: true,
        );
      }
      return const _StreamVoiceContent(
        title: '正在连接语音…',
        message: '已经加入房间，正在建立语音连接。你以听众身份静音进入。',
        icon: Icons.graphic_eq_rounded,
        loading: true,
        ready: true,
      );
    }
    if (content.retryAuthorization ||
        content.retryTarget ||
        content.retryCleanup) {
      return content.retitled('已加入，语音连接失败');
    }
    return content;
  }

  static _StreamVoiceContent _baseContentFor({
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
        title: '需要完成登录验证',
        message: '语音只在完成验证的登录会话里启动；离线或未验证的会话不会连接。',
        icon: Icons.lock_outline_rounded,
      );
    }
    if (!appIsForeground) {
      return const _StreamVoiceContent(
        title: '语音已暂停',
        message: 'LOOP 离开了前台。需要先确认麦克风已关闭、已退出通话，这里才能继续使用。',
        tone: LoopTone.warning,
        icon: Icons.pause_circle_outline_rounded,
      );
    }
    if (cleanupPending) {
      return const _StreamVoiceContent(
        title: '正在确认上一次通话的收尾',
        message: '在确认上一次通话已关闭麦克风并退出之前，不能再次连接。',
        tone: LoopTone.warning,
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (cleanupFailed) {
      return const _StreamVoiceContent(
        title: '上一次通话没有收尾',
        message: '上一次通话没有确认退出。请先重试收尾，再连接语音。',
        tone: LoopTone.danger,
        icon: Icons.sync_problem_rounded,
        retryCleanup: true,
      );
    }
    if (authorization == null || authorization.isLoading) {
      return const _StreamVoiceContent(
        title: '正在准备语音连接',
        message: '正在向后端申请语音身份与短时令牌。期间不会加入任何通话。',
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (authorization.hasError ||
        authorization.value != StreamVideoSessionAuthorization.authorized) {
      return const _StreamVoiceContent(
        title: '语音会话暂时不可用',
        message: '暂时拿不到语音令牌，这里保持断开，不会创建任何通话。',
        tone: LoopTone.warning,
        icon: Icons.cloud_off_rounded,
        retryAuthorization: true,
      );
    }
    if (target == null || target.isLoading) {
      return const _StreamVoiceContent(
        title: '正在读取语音房',
        message: '正在读取后端已授权的语音房。麦克风保持关闭。',
        icon: Icons.meeting_room_outlined,
        loading: true,
      );
    }
    if (target.hasError) {
      return const _StreamVoiceContent(
        title: '语音房读不到',
        message: '已授权的语音房读取失败，不会改连其他房间，也不会用演示数据顶替。',
        tone: LoopTone.warning,
        icon: Icons.meeting_room_outlined,
        retryTarget: true,
      );
    }
    if (target.value == null) {
      return const _StreamVoiceContent(
        title: '还没有拿到语音房',
        message: '这次会话还没有拿到已授权的语音房，请从社区的语音房入口进入。',
        tone: LoopTone.warning,
        icon: Icons.meeting_room_outlined,
        retryTarget: true,
      );
    }
    if (callFactory == null) {
      return const _StreamVoiceContent(
        title: '语音客户端不可用',
        message: '语音房已授权，但绑定当前账号的语音客户端已经失效，请重新授权会话。',
        tone: LoopTone.warning,
        icon: Icons.sync_problem_rounded,
        retryAuthorization: true,
      );
    }
    if (joinError != null) {
      return _StreamVoiceContent(
        title: '连接失败',
        message: joinError,
        tone: LoopTone.danger,
        icon: Icons.wifi_off_rounded,
        ready: true,
      );
    }
    return const _StreamVoiceContent(
      title: '语音可以连接',
      message: '已拿到后端授权的语音房。只在前台连接，且始终静音进入。',
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
            title: '进入即静音',
            message: '连接过程中不会发布任何本地音频。',
          ),
          Divider(height: 25),
          _LobbyFact(
            icon: Icons.security_rounded,
            title: '按需申请权限',
            message: '系统麦克风权限只在你点「发言」之后才申请。',
          ),
          Divider(height: 25),
          _LobbyFact(
            icon: Icons.phone_android_rounded,
            title: '仅前台',
            message: '离开这个界面会结束当前的语音连接。',
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
    this.reconnect = false,
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

  /// The surface connects on its own, so a connect button appears only to put
  /// a stopped connection back.
  final bool reconnect;

  _StreamVoiceContent retitled(String title) {
    return _StreamVoiceContent(
      title: title,
      message: message,
      icon: icon,
      tone: tone,
      loading: loading,
      retryAuthorization: retryAuthorization,
      retryTarget: retryTarget,
      retryCleanup: retryCleanup,
      ready: ready,
      reconnect: reconnect,
    );
  }
}
