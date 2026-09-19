import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/active_voice_media.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_link.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_retry.dart';
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
    this.onMicrophoneEnabled,
    this.onReconnectRequested,
    this.onCallStopped,
    this.viewerRole,
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

  /// Told after the device opened the microphone, so the page can clear the
  /// LOOP-side mute intent on its own row (decision 0053). It is never the
  /// other way round: LOOP has no command that opens a microphone.
  final Future<void> Function()? onMicrophoneEnabled;

  /// Asked before a second connection attempt, so the attempt starts from a
  /// freshly read room and a freshly issued provider session.
  ///
  /// Without it 「重新连接语音」 asked the same call object again: on the review
  /// device three taps produced no request at all and the same refusal each
  /// time. The page that owns the room does the reading; this surface only
  /// waits for it and then connects.
  final Future<void> Function()? onReconnectRequested;

  /// Asked once a call stopped on its own, before this surface says anything
  /// about it.
  ///
  /// A call can stop because the network went away, and it can stop because
  /// the host ended the room. Those are opposite answers — one is 「重新连接
  /// 语音」, the other is a room that no longer exists — and the provider's
  /// disconnection does not tell them apart. The page that owns the room reads
  /// the room record again; a room that ended stops being joinable, so this
  /// surface is taken off the screen by the page instead of offering a
  /// connection to a room nobody can enter. Until the answer lands, nothing
  /// here offers the audio back.
  final Future<void> Function()? onCallStopped;

  /// The part LOOP granted this account. It decides what the surface says
  /// about the microphone and about the way out; it grants nothing.
  final AudioRoomViewerRole? viewerRole;

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
      onMicrophoneEnabled: onMicrophoneEnabled,
      onCallStopped: onCallStopped,
      viewerRole: viewerRole,
      presence: ref.read(audioRoomLivePresenceProvider.notifier),
      // The call outlives this widget: it belongs to the app, and this
      // surface is one view of it.
      activeMedia: ref.read(activeVoiceMediaProvider.notifier),
      heldCall: ref.watch(activeVoiceMediaProvider),
      principalKey: principalKey,
      authorization: authorization,
      target: resolvedTarget,
      callFactory: callFactory,
      onRetrySession: () =>
          _retrySession(ref, hasSuppliedTarget: suppliedTarget != null),
      onRetryTarget: suppliedTarget != null
          ? null
          : () => ref.invalidate(audioRoomTargetProvider),
    );
  }

  /// The one way back from every refusal this surface can show.
  ///
  /// 「重试会话」 used to invalidate the authorization alone. The provider
  /// session answers that watch from the client it still holds, so no token
  /// was ever fetched and the call factory stayed null: on the review device
  /// three taps produced no request at all and the page had no way forward
  /// short of leaving it. The retry now takes the same three steps the page's
  /// 「重新连接语音」 takes — retire the session, drop the authorization and the
  /// factory built from it, read the room again.
  ///
  /// When the page that owns the room supplied [onReconnectRequested], that
  /// callback is those three steps with the page's own read of the room, so it
  /// is used as it is rather than run beside a second, partial one.
  Future<void> _retrySession(WidgetRef ref, {required bool hasSuppliedTarget}) {
    final pageRefresh = onReconnectRequested;
    if (pageRefresh != null) return pageRefresh();
    return refreshVoiceMediaSession(
      ref,
      refreshRoom: hasSuppliedTarget
          ? null
          : () async => ref.invalidate(audioRoomTargetProvider),
      stillMounted: () => ref.context.mounted,
    );
  }
}

class _StreamVoiceRoomSurface extends StatefulWidget {
  const _StreamVoiceRoomSurface({
    required this.inline,
    required this.autoConnect,
    required this.link,
    required this.onExitRequested,
    required this.onMicrophoneEnabled,
    required this.onCallStopped,
    required this.viewerRole,
    required this.presence,
    required this.activeMedia,
    required this.heldCall,
    required this.principalKey,
    required this.authorization,
    required this.target,
    required this.callFactory,
    required this.onRetrySession,
    required this.onRetryTarget,
    super.key,
  });

  final bool inline;
  final bool autoConnect;
  final VoiceMediaLink? link;
  final Future<void> Function()? onExitRequested;
  final Future<void> Function()? onMicrophoneEnabled;

  /// Re-reads the room after a call stopped on its own. See
  /// [StreamVoiceRoomPage.onCallStopped].
  final Future<void> Function()? onCallStopped;
  final AudioRoomViewerRole? viewerRole;

  /// Where this surface publishes the call's own head count.
  final AudioRoomLivePresenceController? presence;

  /// Who owns the call this surface shows. Closing the page is not a decision
  /// about the audio, so the handle is held here and this widget only binds a
  /// view to it.
  final ActiveVoiceMediaController? activeMedia;

  /// The call the app holds right now, as of this build.
  final AudioRoomCallHandle? heldCall;
  final String? principalKey;
  final AsyncValue<StreamVideoSessionAuthorization>? authorization;
  final AsyncValue<AudioRoomTarget?>? target;
  final AudioRoomCallFactory? callFactory;

  /// Retires the provider session, drops what was derived from it and reads
  /// the room again. Never a bare provider invalidation: see
  /// [StreamVoiceRoomPage._retrySession].
  final Future<void> Function() onRetrySession;

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
  List<AudioRoomCallHandle> _cleanupHandles = const <AudioRoomCallHandle>[];
  Future<List<bool>>? _backgroundRetirement;
  var _appIsForeground = true;
  var _cleanupPending = false;
  var _cleanupFailed = false;
  var _joining = false;
  var _leaving = false;

  /// True from the moment this account asked to leave until that exit has
  /// settled on both sides.
  ///
  /// Leaving is the reader's own decision, and for the seconds between the
  /// call going down and LOOP recording the exit the lobby is on screen. It
  /// used to be the disconnection lobby — 「语音已断开」 above a highlighted
  /// 「重新连接语音」 — which answers the opposite of what the reader had just
  /// asked for. A departure in progress says so, offers nothing to connect,
  /// and keeps the ready room from connecting on its own.
  var _exiting = false;

  /// Set once a connection failed or a call stopped on its own, so a ready
  /// room does not silently reconnect behind the reader's decision.
  var _autoConnectSuspended = false;
  var _autoConnectScheduled = false;
  var _generation = 0;
  var _cleanupGeneration = 0;
  var _lifecycleGeneration = 0;

  /// True while the page re-reads the room and the provider session for a
  /// second attempt. Nothing connects during it: the old call is exactly the
  /// one that was refused.
  var _refreshingConnection = false;

  /// True from the moment a call stopped on its own until the room record has
  /// been read again.
  ///
  /// A dropped network and a room the host ended arrive here as the same
  /// provider disconnection, and only one of them has 「重新连接语音」 as an
  /// answer. Offering it before the room was read again put a connect button
  /// under a room that no longer exists.
  var _verifyingRoom = false;
  String? _joinError;
  ({AudioRoomLivePhase phase, int? participantCount})? _reportedPresence;

  AudioRoomTarget? get _target {
    final value = widget.target;
    return value != null && value.hasValue ? value.value : null;
  }

  /// The call this surface shows, which the app owns.
  ///
  /// A page that comes back to a room the device is still in finds the call
  /// here: nothing is made, no token is asked for and nothing is joined a
  /// second time. A call the app holds for another room is not this surface's
  /// to show — [_joinMuted] takes that one down before it makes its own.
  AudioRoomCallHandle? get _foregroundCall {
    final held = widget.heldCall;
    if (held == null) return null;
    final roomId = _target?.roomId;
    if (roomId != null && held.roomId != roomId) return null;
    return held;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.activeMedia?.attachView(this);
    widget.link?.attach(_disconnectForExit, exitSettled: _exitSettled);
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
      widget.link?.attach(_disconnectForExit, exitSettled: _exitSettled);
    }
    final newRoomId = _target?.roomId;
    final boundRoomId = _foregroundCall?.roomId ?? _joiningCall?.roomId;
    // A factory that is not there yet, or has gone for a moment, is not a
    // different client: the authorization lands in two steps and the provider
    // behind it is rebuilt more than once on the way. Only a factory that was
    // replaced by another one hands out calls the old client cannot serve —
    // and only then is the call this surface holds stale.
    final callFactoryChanged =
        oldWidget.callFactory != null &&
        widget.callFactory != null &&
        !identical(oldWidget.callFactory, widget.callFactory);
    // A room this surface no longer points at, or a call the current client
    // cannot serve. A target that is not known yet is neither: the call the
    // app holds outlives the read that names the room, and coming back to the
    // page hands this surface that call before the room record has landed.
    if (boundRoomId != null &&
        (callFactoryChanged ||
            (newRoomId != null && newRoomId != boundRoomId))) {
      _retireForTargetChange();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.link?.detach(_disconnectForExit);
    final media = widget.activeMedia;
    var held = media?.call;
    // A call whose leave the provider refused is not one this page can go on
    // showing from another screen; it goes down with the page, as it did
    // before the app took ownership.
    AudioRoomCallHandle? abandoned;
    if (held != null && held.retirementStarted) {
      abandoned = held;
      // A provider write from a widget's teardown is not allowed, so the
      // hand-back waits a microtask; the retirement below does not.
      final releasing = held;
      scheduleMicrotask(() => media?.surrender(releasing));
      held = null;
    }
    // Otherwise leaving this page is not leaving the room, and it is no
    // longer leaving the call either: the app holds it, keeps the reading
    // coming and puts it on the strip. Only the calls this surface was
    // taking down go here.
    if (held == null) _withdrawPresence();
    _generation += 1;
    _cleanupGeneration += 1;
    _lifecycleGeneration += 1;
    final joiningCall = _joiningCall;
    _joiningCall = null;
    final handles = _uniqueHandles(<AudioRoomCallHandle?>[
      joiningCall,
      abandoned,
      ..._cleanupHandles,
    ]);
    for (final handle in handles) {
      if (identical(handle, held)) continue;
      unawaited(_retireIgnoringFailure(handle));
    }
    media?.detachView(this);
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
    if (foregroundCall == null) {
      // A lobby is a room this device is not in. Saying so is what keeps the
      // strip outside this page from printing a head count for a call that
      // ended, or one that never connected.
      _schedulePresenceReport(
        phase: AudioRoomLivePhase.idle,
        participantCount: null,
      );
    }
    if (widget.inline) {
      // The voice room page owns the only scrolling region on the screen, so
      // the inline surface is a plain section: no Scaffold, no app bar of its
      // own, and no second scroll view.
      return foregroundCall == null
          ? _buildLobby(context)
          : foregroundCall.buildForeground(
              onLeaveRequested: _requestExit,
              inline: true,
              onMicrophoneEnabled: widget.onMicrophoneEnabled,
              onPresence: _reportPresence,
              onDisconnected: _retireStoppedCall,
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
              : foregroundCall.buildForeground(
                  onLeaveRequested: _requestExit,
                  onMicrophoneEnabled: widget.onMicrophoneEnabled,
                  onPresence: _reportPresence,
                  onDisconnected: _retireStoppedCall,
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
      autoConnect: widget.autoConnect,
      autoConnectSuspended: _autoConnectSuspended,
      refreshingConnection: _refreshingConnection,
      exiting: _exiting,
      verifyingRoom: _verifyingRoom,
    );
    final joinEnabled =
        content.ready &&
        !_joining &&
        !_refreshingConnection &&
        !_verifyingRoom &&
        !_cleanupPending &&
        !_cleanupFailed;
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
                key: const ValueKey<String>('voiceroom-media-retry-session'),
                onPressed: _refreshingConnection
                    ? null
                    : () => unawaited(_reconnect()),
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
              audioRoomConnectionNote(widget.viewerRole),
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
        _exiting ||
        _joining ||
        _refreshingConnection ||
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
          _exiting ||
          _refreshingConnection ||
          _joinError != null) {
        return;
      }
      unawaited(_joinMuted());
    });
  }

  /// The reader's own request for the audio back after a refusal.
  ///
  /// Both retries on this surface — 「重新连接语音」 after a failed connection
  /// and 「重试会话」 after the provider session went stale — arrive here,
  /// because both refusals are held by the same things: the session this
  /// device authorized, the client built from it and the call that client
  /// handed out. The session and the room are read again first; only then does
  /// a new call get made, which is what [_joinMuted] does with the factory it
  /// is handed.
  Future<void> _reconnect() async {
    setState(() {
      _autoConnectSuspended = false;
      _joinError = null;
      _refreshingConnection = true;
    });
    try {
      await widget.onRetrySession();
    } catch (_) {
      // The page states a read it could not finish in its own block; this
      // surface only reports what the connection did.
    }
    if (!mounted) return;
    setState(() => _refreshingConnection = false);
    // With [autoConnect] the frame after this schedules the attempt on the
    // room and the client that were just read.
    if (!widget.autoConnect) await _joinMuted();
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
    // The membership is about to end; a ready room must not reconnect in the
    // window between this disconnect and the LOOP leave, and the lobby that
    // shows during it is a departure, not a dropped connection.
    _markExiting();
    if (_foregroundCall == null) return;
    await _leaveForegroundCall(pageOwnsExit: true);
  }

  void _markExiting() {
    if (_exiting) return;
    if (mounted) {
      setState(() => _exiting = true);
    } else {
      _exiting = true;
    }
  }

  /// The page's own half of the exit has settled.
  ///
  /// On a leave that went through, this surface is already unhooked and this
  /// is never called. What reaches it is an exit LOOP refused: the account is
  /// still a member of a room it can no longer hear, which is exactly the
  /// lobby that offers the audio back.
  void _exitSettled() {
    if (!_exiting) return;
    if (!mounted) {
      _exiting = false;
      return;
    }
    setState(() {
      _exiting = false;
      if (_foregroundCall == null) _autoConnectSuspended = true;
    });
  }

  Future<void> _joinMuted() async {
    if (!_appIsForeground ||
        _cleanupPending ||
        _cleanupFailed ||
        _joining ||
        _refreshingConnection ||
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
    final media = widget.activeMedia;
    // The app takes the call from here: a join still in flight when the
    // reader goes to another tab is not abandoned, and the room page that
    // comes back is handed this same call.
    media?.hold(callHandle);
    setState(() {
      _joining = true;
      _joiningCall = callHandle;
      _joinError = null;
    });

    try {
      await callHandle.joinMuted();
    } catch (error) {
      final failure = error is AudioRoomCallFailure ? error : null;
      final refusal = failure?.refusal ?? AudioRoomJoinRefusal.unknown;
      if (kDebugMode) {
        // The provider's own answer stays here: it is the only account of
        // what was refused, and it is not a sentence for a reader.
        debugPrint(
          'LOOP voice join refused: ${refusal.name} · '
          '${failure?.detail ?? error}',
        );
      }
      media?.surrender(callHandle);
      if (!mounted || generation != _generation) {
        await _retireIgnoringFailure(callHandle);
        return;
      }
      final cleanupGeneration = ++_cleanupGeneration;
      setState(() {
        _joining = false;
        _joiningCall = null;
        _cleanupHandles = <AudioRoomCallHandle>[callHandle];
        _cleanupPending = true;
        _cleanupFailed = false;
        _joinError = audioRoomJoinRefusalText(refusal);
      });
      await _completeCleanup(<AudioRoomCallHandle>[
        callHandle,
      ], cleanupGeneration);
      return;
    }

    if (!mounted || generation != _generation) {
      // A page that came off the screen mid-join leaves the call with the
      // app, which is now holding it; anything else is a call this surface
      // was already replacing.
      if (!identical(media?.call, callHandle)) {
        await _retireIgnoringFailure(callHandle);
      }
      return;
    }
    setState(() {
      _joining = false;
      _joiningCall = null;
    });
  }

  /// Takes this device's call down because the reader asked to go.
  ///
  /// [pageOwnsExit] is true when the exit arrived through [VoiceMediaLink]:
  /// the page still has the LOOP leave to send, so the departure stays on
  /// screen until it tells this surface the exit settled. Without a page
  /// there is no second half, and the exit ends here.
  Future<void> _leaveForegroundCall({bool pageOwnsExit = false}) async {
    if (_leaving) return;
    final handle = _foregroundCall;
    if (handle == null) return;
    _leaving = true;
    _generation += 1;
    // Not [_autoConnectSuspended]: that flag is the sentence for a call that
    // stopped on its own, and the lobby printed it over the reader's own
    // 离开 for as long as the LOOP leave took.
    _markExiting();
    try {
      await handle.leave();
    } catch (_) {
      // A leave the provider did not confirm keeps the call exactly where it
      // is: the call view stays mounted so the microphone can be closed and
      // the exit tried again, and the app goes on holding a call that is
      // still there.
      if (mounted) setState(() => _leaving = false);
      rethrow;
    }
    // The reader is out: the app stops holding the call, so no strip is left
    // saying the room is still being heard.
    widget.activeMedia?.surrender(handle);
    if (!mounted) return;
    setState(() {
      if (identical(_joiningCall, handle)) _joiningCall = null;
      _joining = false;
      _leaving = false;
      _joinError = null;
      if (!pageOwnsExit) {
        _exiting = false;
        _autoConnectSuspended = true;
      }
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
    if (foregroundCall != null) {
      // This runs from `didUpdateWidget`, where a provider write is not
      // allowed; the call is already on its way out either way.
      final media = widget.activeMedia;
      scheduleMicrotask(() => media?.surrender(foregroundCall));
    }
    final cleanupGeneration = ++_cleanupGeneration;
    setState(() {
      _joining = false;
      _leaving = false;
      _joiningCall = null;
      _cleanupHandles = handles;
      _cleanupPending = true;
      _cleanupFailed = false;
      _joinError = null;
      _autoConnectSuspended = false;
      // Another room, another decision: a departure from the last one does
      // not describe this one.
      _exiting = false;
    });
    unawaited(_completeCleanup(handles, cleanupGeneration));
  }

  /// Takes down a call the provider stopped, and puts the lobby back.
  ///
  /// The SDK reconnects on its own, and while it does the call view stays: a
  /// retry in progress is not a failure. What arrives here is a call nobody is
  /// putting back — on the review device the badge went red and stood there
  /// for more than ninety seconds while the whole screen was still the call
  /// view, whose only controls are the microphone and the hang-up. The
  /// membership is untouched, so this is the same lobby the reader sees after
  /// a failed connection: 「语音已断开」 and 「重新连接语音」, which reads the
  /// room and the provider session again before it connects.
  ///
  /// The call itself is retired through the one cleanup path this surface
  /// has. That leave is single-flight inside the handle, so a call the SDK
  /// already took down is not left a second time.
  ///
  /// Which of the two lobbies the reader gets is not this surface's to decide:
  /// a call also stops because the host ended the room, and 「重新连接语音」 is
  /// then an answer to a room that is gone. The page is asked to read the room
  /// again first ([_StreamVoiceRoomSurface.onCallStopped]); until it answers,
  /// nothing here offers the audio back.
  void _retireStoppedCall() {
    if (!mounted ||
        _leaving ||
        _exiting ||
        _cleanupPending ||
        _verifyingRoom ||
        _refreshingConnection) {
      return;
    }
    final stopped = _foregroundCall;
    if (stopped == null || stopped.retirementStarted) return;
    _generation += 1;
    final handles = _uniqueHandles(<AudioRoomCallHandle?>[
      _joiningCall,
      stopped,
      ..._cleanupHandles,
    ]);
    widget.activeMedia?.surrender(stopped);
    final cleanupGeneration = ++_cleanupGeneration;
    setState(() {
      _joining = false;
      _joiningCall = null;
      _cleanupHandles = handles;
      _cleanupPending = true;
      _cleanupFailed = false;
      _joinError = null;
      // This device stopped hearing the room without being asked to. Putting
      // the audio back is the reader's decision, so the ready lobby does not
      // connect again on its own.
      _autoConnectSuspended = true;
      // Whether the audio can come back at all is the room's answer, not this
      // surface's. Until the page has read the room again nothing here offers
      // a connection.
      _verifyingRoom = widget.onCallStopped != null;
    });
    unawaited(_completeCleanup(handles, cleanupGeneration));
    unawaited(_verifyRoom());
  }

  /// Waits for the page's own read of the room after a call stopped.
  ///
  /// The page owns the room record, so it is the one that can tell a dropped
  /// network from a room the host ended: a room that came back `ended` is no
  /// longer joinable and the page takes this surface off the screen, and a
  /// room that is still live keeps the disconnection lobby with the audio on
  /// offer. A read that could not finish says neither, and the surface falls
  /// back to the disconnection it can see for itself.
  Future<void> _verifyRoom() async {
    final verify = widget.onCallStopped;
    if (verify == null) return;
    try {
      await verify();
    } catch (_) {
      // The page states a read it could not finish in its own block; this
      // surface only reports what the connection did.
    }
    if (!mounted || !_verifyingRoom) return;
    setState(() => _verifyingRoom = false);
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
    // LOOP itself left the foreground, which is the one place a voice call is
    // allowed to run. The app stops holding it here too: there is no
    // background session behind this, and the strip must not say a room is
    // being heard while it is not.
    if (foregroundCall != null) widget.activeMedia?.surrender(foregroundCall);
    setState(() {
      _appIsForeground = false;
      _joining = false;
      _leaving = false;
      _joiningCall = null;
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

  /// Publishes one reading from the mounted call view.
  void _reportPresence({
    required AudioRoomLivePhase phase,
    required int? participantCount,
  }) {
    _publishPresence(phase: phase, participantCount: participantCount);
  }

  /// Publishes the lobby's own reading after this frame.
  ///
  /// A write during a build is not allowed, and the lobby is rebuilt for
  /// every step of the connection, so the reading is sent only when it is not
  /// the one already published.
  void _schedulePresenceReport({
    required AudioRoomLivePhase phase,
    required int? participantCount,
  }) {
    final reading = (phase: phase, participantCount: participantCount);
    if (_reportedPresence == reading) return;
    _reportedPresence = reading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publishPresence(
        phase: phase,
        participantCount: participantCount,
        deduplicate: false,
      );
    });
  }

  void _publishPresence({
    required AudioRoomLivePhase phase,
    required int? participantCount,
    bool deduplicate = true,
  }) {
    final presence = widget.presence;
    final roomId = _foregroundCall?.roomId ?? _target?.roomId;
    if (presence == null || roomId == null) return;
    final reading = (phase: phase, participantCount: participantCount);
    if (deduplicate && _reportedPresence == reading) return;
    _reportedPresence = reading;
    try {
      presence.report(
        AudioRoomLivePresence(
          roomId: roomId,
          phase: phase,
          participantCount: participantCount,
        ),
      );
    } catch (_) {
      // The container can be torn down before this surface is; the reading
      // goes with it either way.
    }
  }

  /// Takes this surface's reading back when it leaves the tree.
  void _withdrawPresence() {
    final presence = widget.presence;
    final roomId = _foregroundCall?.roomId ?? _target?.roomId;
    _reportedPresence = null;
    if (presence == null || roomId == null) return;
    scheduleMicrotask(() {
      try {
        presence.clear(roomId);
      } catch (_) {
        // See above: a retired container clears itself.
      }
    });
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
    required bool refreshingConnection,
    required bool exiting,
    required bool verifyingRoom,
  }) {
    if (exiting) {
      // The reader asked to go and is waiting for it. Nothing here offers a
      // connection: 「重新连接语音」 under this is an answer to a question
      // nobody asked.
      return const _StreamVoiceContent(
        title: '正在离开语音房…',
        message: '这次通话已经断开，正在把离开记到 LOOP 的房间记录里。',
        icon: Icons.logout_rounded,
        loading: true,
      );
    }
    if (verifyingRoom) {
      // A dropped network and a room the host ended arrive here as the same
      // disconnection. 「重新连接语音」 answers only one of them, so it is not
      // offered until the room itself has answered.
      return const _StreamVoiceContent(
        title: '语音已断开，正在确认房间',
        message: '正在确认这个语音房是否还在进行，之后再决定能不能把语音接回来。',
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (refreshingConnection) {
      return const _StreamVoiceContent(
        title: '正在重新连接语音',
        message: '正在重新读取这个房间并重新取得语音身份，然后再连接一次。',
        icon: Icons.sync_rounded,
        loading: true,
        ready: true,
      );
    }
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

/// One sentence for one refusal.
///
/// It says what to do next, and it never repeats the provider's own answer: a
/// reader cannot act on an SDK string, and the two most common causes here —
/// a room that is not open to listeners and a network that never arrived —
/// need opposite next steps. The answer itself is in the debug log.
String audioRoomJoinRefusalText(AudioRoomJoinRefusal refusal) =>
    switch (refusal) {
      AudioRoomJoinRefusal.permission => '这个房间还没有开放收听，请让主持人重新开启。',
      AudioRoomJoinRefusal.roomUnavailable => '这个房间已经不能加入了，请回到社区看它是否还在进行。',
      AudioRoomJoinRefusal.network => '这次连接没有接通，请检查网络后重试。',
      AudioRoomJoinRefusal.session => '这次的语音身份已经失效，请退出这一页再进来。',
      AudioRoomJoinRefusal.unknown => '没能连上这个语音房，请稍后重试。',
    };

/// What the connection means for this account, by the part it plays.
///
/// A listener never opens a microphone and a host has no 离开 at all, so one
/// sentence written for a listener told a host to use a control that is not
/// on the screen. A room whose role is not known yet keeps the listener's
/// sentence: it is the part every member starts in.
String audioRoomConnectionNote(AudioRoomViewerRole? role) => switch (role) {
  AudioRoomViewerRole.host =>
    '你是主持人，进入时同样静音，点「发言」才会申请麦克风权限；'
        '语音没连上房间也不会结束，要结束请用下面的「结束房间」。',
  AudioRoomViewerRole.speaker =>
    '你是发言人，进入时同样静音，点「发言」才会申请麦克风权限；'
        '语音没连上也不会把你移出房间，要真正退出请用下面的「离开」。',
  _ =>
    '你以听众身份静音进入，不会申请麦克风权限；'
        '语音没连上也不会把你移出房间，要真正退出请用下面的「离开」。',
};

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
