import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/network/loop_connectivity_signal.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';

/// The one provider call this device holds, and the app holds it.
///
/// The call used to belong to the room page: closing that page disposed the
/// widget and the audio went with it, so a reader who opened the wallet to
/// check a balance stopped hearing the room mid-sentence and came back to a
/// lobby. The room page is now a view of this call — it mounts one, it takes
/// it down when the reader leaves, and it makes a new one only when there is
/// none to show. Going to another tab is not a decision about the audio.
///
/// Decision 0106 takes the same rule one step further: LOOP leaving the
/// screen is not a decision about the audio either. A room keeps playing, and
/// a speaker keeps being heard, while the reader is on the home screen or in
/// another App — on iOS through the `audio` background mode, on Android
/// through the provider's call service and its ongoing notification. Only the
/// reader's own 离开, the room ending, the account changing, or the App being
/// taken down (`detached`) ends the call.
///
/// The provider reconnects a dropped call on its own. When it gives up, this
/// holder puts a new call into the same room without being asked, backing off
/// between attempts (see [audioRoomRecoveryDelay]) and trying again at once
/// when the network comes back, for as long as the account is still in the
/// room.
final class ActiveVoiceMediaController extends Notifier<AudioRoomCallHandle?> {
  /// The mounted call views, each with what it asks to be told when the call
  /// is taken down from somewhere else. While one of them is on screen it
  /// publishes the reading itself, from the same official state, and this
  /// holder stays out of the way.
  final Map<Object, VoidCallback?> _views =
      Map<Object, VoidCallback?>.identity();

  AudioRoomCallHandle? _held;
  AudioRoomCallReading? _reading;
  StreamSubscription<AudioRoomCallReading>? _readings;
  _ActiveVoiceMediaLifecycle? _lifecycle;

  /// The automatic reconnection in progress, if any. See [recover].
  _Recovery? _recovery;
  var _recoveryGeneration = 0;
  StreamSubscription<void>? _connectivity;

  /// What the call is made of, held for exactly as long as the call is.
  ///
  /// The handle is only the near end of a chain: the provider session, the
  /// authorization that built its client and the factory that handed out the
  /// call all live in `autoDispose` providers, and the room page was the only
  /// thing in the app watching any of them. Holding the handle here while the
  /// page went off the screen therefore held a call whose client was being
  /// torn down in the same frame — on the review device the WebRTC stack was
  /// closed the moment the page was popped, and the strip said 「语音已断开」
  /// a second later.
  ///
  /// The lifetime is taken here, and only while there is a call, a recovery
  /// or a mounted view to justify it. Watching them in [build] instead would
  /// make the provider session permanent for the rest of the sign-in: a
  /// client kept open for an account that left the room hours ago is exactly
  /// the standing connection this feature does not have.
  List<ProviderSubscription<Object?>>? _mediaLifetime;

  @override
  AudioRoomCallHandle? build() {
    // The call belongs to the account that made it. A sign-out or an account
    // change rotates this provider, and the call goes down with it rather
    // than being left running for whoever comes next.
    ref.watch(streamVideoPrincipalKeyProvider);
    final lifecycle = _ActiveVoiceMediaLifecycle(_onAppLifecycle);
    _lifecycle = lifecycle;
    WidgetsBinding.instance.addObserver(lifecycle);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(lifecycle);
      if (identical(_lifecycle, lifecycle)) _lifecycle = null;
    });
    // The reader's route is put on every call this device holds, now and
    // whenever it changes.
    ref.listen<AudioRoomOutputPreference>(audioRoomOutputPreferenceProvider, (
      _,
      next,
    ) {
      final held = _held;
      if (held != null) unawaited(_applyOutputIgnoringFailure(held, next));
    });
    // The notification names the room, and a recovery ends with the
    // membership it was recovering.
    ref.listen<VoiceRoomSession?>(voiceRoomSessionProvider, (_, next) {
      _nameNotification(next);
      final recovery = _recovery;
      if (recovery != null &&
          (next == null || next.callRoomId != recovery.roomId)) {
        _endRecovery(clearPresence: true);
      }
    }, fireImmediately: true);
    ref.onDispose(_retireOnTeardown);
    return null;
  }

  void _onAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Coming back is one of the moments a route moves, and a recovery
        // waiting out its back-off has no reason to keep waiting.
        final held = _held;
        if (held != null) {
          unawaited(
            _applyOutputIgnoringFailure(
              held,
              ref.read(audioRoomOutputPreferenceProvider),
            ),
          );
        }
        _recovery?.wake();
      case AppLifecycleState.detached:
        // The App is being taken down. Nothing is left to hold the call.
        _endRecovery(clearPresence: true);
        final held = _held;
        if (held == null) return;
        _release(clearPresence: true);
        unawaited(_leaveIgnoringFailure(held));
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Decision 0106: the room keeps running behind the home screen.
        break;
    }
  }

  /// The call this device already holds for [roomId], when it is still usable.
  AudioRoomCallHandle? callFor(String roomId) {
    final held = _held;
    if (held == null || held.roomId != roomId || held.retirementStarted) {
      return null;
    }
    return held;
  }

  /// The call this device holds, whichever room it belongs to.
  AudioRoomCallHandle? get call => _held;

  /// Whether this device is putting a dropped call to [roomId] back.
  bool recovering(String roomId) => _recovery?.roomId == roomId;

  /// Takes ownership of a call the room page just made.
  ///
  /// One device holds one call: a call for another room is taken down here,
  /// because two rooms playing at once is not something a reader asked for.
  void hold(AudioRoomCallHandle handle) {
    final previous = _held;
    if (identical(previous, handle)) return;
    _bindMediaLifetime();
    if (previous != null) {
      _clearPresence(previous.roomId);
      unawaited(_leaveIgnoringFailure(previous));
    }
    final recovery = _recovery;
    if (recovery != null && recovery.roomId != handle.roomId) {
      _endRecovery(clearPresence: true);
    }
    _readings?.cancel();
    _held = handle;
    _reading = handle.reading;
    state = handle;
    _readings = handle.readings.listen(
      _onReading,
      onError: (Object _, StackTrace _) {
        // A reading that failed to arrive says nothing; the call itself is
        // unchanged and the next one is taken as it comes.
      },
    );
    unawaited(
      _applyOutputIgnoringFailure(
        handle,
        ref.read(audioRoomOutputPreferenceProvider),
      ),
    );
  }

  /// Hands the call back to a caller that is taking it down itself.
  ///
  /// The room page owns the exit and the cleanup it has to show for it, so a
  /// leave it started stays its own; this only stops holding the call.
  void surrender(AudioRoomCallHandle handle) {
    if (!identical(_held, handle)) return;
    _release(clearPresence: true);
  }

  /// Takes the held call down, from wherever the reader asked for it.
  ///
  /// A recovery in progress stops with it, and every mounted view is told,
  /// so a room page behind the one that asked does not connect again on its
  /// own. Returns false when the provider did not confirm the leave. The
  /// caller still releases the LOOP membership: staying in a room against the
  /// reader's decision because a provider command hung is the worse answer.
  Future<bool> retire() async {
    _endRecovery(clearPresence: true);
    for (final retired in List<VoidCallback?>.of(_views.values)) {
      retired?.call();
    }
    final held = _held;
    if (held == null) return true;
    _release(clearPresence: true);
    try {
      await held.leave();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops putting [roomId] back, because the reader is leaving it.
  void cancelRecovery(String roomId) {
    if (_recovery?.roomId != roomId) return;
    _endRecovery(clearPresence: true);
  }

  /// Forgets that a recovery closed a microphone, once the reader has seen
  /// the line about it or opened the microphone again.
  void acknowledgeRestored(String roomId) {
    final published = _readRecovery();
    if (published == null ||
        published.roomId != roomId ||
        published.phase != AudioRoomRecoveryPhase.restored) {
      return;
    }
    _reportRecovery(null);
  }

  /// A call view came on screen; from here it publishes the reading.
  ///
  /// [onRetiredElsewhere] is called when the call is taken down by something
  /// other than this view — the shell's strip or the system notification —
  /// so the view stops offering to connect again on its own.
  void attachView(Object token, {VoidCallback? onRetiredElsewhere}) {
    _views[token] = onRetiredElsewhere;
    // The view is about to make a call out of the session, the authorization
    // and the factory. From this moment they are held here, so that the view
    // going away is not the same thing as the call going away.
    _bindMediaLifetime();
  }

  /// Holds the provider session, its authorization and the call factory for
  /// as long as this device has a call, a recovery or a mounted view.
  ///
  /// The subscriptions do no work of their own: what they do is count as a
  /// consumer, which is the whole of what an `autoDispose` provider needs to
  /// stay where it is. They are opened only when the page is already watching
  /// the same providers, so nothing is authorized and no token is asked for
  /// on their account.
  void _bindMediaLifetime() {
    if (_mediaLifetime != null) return;
    try {
      _mediaLifetime = <ProviderSubscription<Object?>>[
        ref.listen(streamVideoSdkSessionProvider, (_, _) {}),
        ref.listen(streamVideoAuthorizationProvider, (_, _) {}),
        ref.listen(audioRoomCallFactoryProvider, (_, _) {}),
      ];
    } catch (_) {
      // A container that is being torn down holds nothing worth holding.
      _mediaLifetime = null;
    }
  }

  /// Lets go of the session once there is neither a call, a recovery nor a
  /// view.
  void _releaseMediaLifetime() {
    if (_held != null || _views.isNotEmpty || _recovery != null) return;
    final links = _mediaLifetime;
    _mediaLifetime = null;
    if (links == null) return;
    for (final link in links) {
      try {
        link.close();
      } catch (_) {
        // A subscription the container already closed is already closed.
      }
    }
  }

  /// A call view came off screen.
  ///
  /// The strip on the next screen has to say what the call is doing, and the
  /// widget that was saying it has just gone. The reading is published from
  /// here after this frame: a provider write during a widget's teardown is
  /// not allowed.
  void detachView(Object token) {
    if (!_views.containsKey(token)) return;
    _views.remove(token);
    if (_views.isNotEmpty) return;
    // A view that leaves with no call behind it takes the session with it.
    // A view that leaves while this device is in a room does not: that is
    // the whole point of the call belonging to the app.
    _releaseMediaLifetime();
    scheduleMicrotask(() {
      if (_views.isNotEmpty) return;
      final recovery = _recovery;
      if (recovery != null && _held == null) {
        _publish(recovery.roomId, _reconnectingReading);
        return;
      }
      final held = _held;
      final reading = _reading;
      if (held == null || reading == null) return;
      _publish(held.roomId, reading);
      if (reading.phase == AudioRoomLivePhase.disconnected &&
          !held.retirementStarted) {
        recover(held);
      }
    });
  }

  void _onReading(AudioRoomCallReading reading) {
    final held = _held;
    if (held == null) return;
    _reading = reading;
    // A mounted view answers for the call it shows, including the moment it
    // stops. Two owners for one stopped call would read the room twice.
    if (_views.isNotEmpty) return;
    if (_recovery != null && reading.phase != AudioRoomLivePhase.connected) {
      // A new call on its way in is still the recovery, and the strip keeps
      // saying so rather than 「连接中」 for a room it was already in.
      _publish(held.roomId, _reconnectingReading);
    } else {
      _publish(held.roomId, reading);
    }
    if (reading.phase != AudioRoomLivePhase.disconnected ||
        held.retirementStarted) {
      return;
    }
    recover(held);
  }

  static const _reconnectingReading = AudioRoomCallReading(
    phase: AudioRoomLivePhase.reconnecting,
    participantCount: null,
  );

  /// Puts a call the provider gave up on back into the same room.
  ///
  /// The provider's own reconnection is over when this is called: the call
  /// is disconnected or its reconnection failed, and nothing is retrying it.
  /// A dropped network and a room the host ended arrive here as the same
  /// disconnection, so every attempt reads the room first — a room that
  /// ended, or an account that is no longer in it, stops the recovery; a
  /// read that could not finish is one more failed attempt, not an answer.
  ///
  /// The new call enters muted like every call (decision 0005 still holds:
  /// one Speak per call, and this is a new call). When the microphone was
  /// open at the moment of the drop the room says so once it is back,
  /// instead of opening it again on the reader's behalf.
  void recover(AudioRoomCallHandle stopped) {
    if (!identical(_held, stopped) || stopped.retirementStarted) return;
    final roomId = stopped.roomId;
    final running = _recovery;
    if (running != null && running.roomId == roomId) {
      // A new call that dropped on its way in is the recovery's own failed
      // attempt, not a second drop: the back-off it is in stays where it is.
      _release(clearPresence: false);
      unawaited(_leaveIgnoringFailure(stopped));
      _publish(roomId, _reconnectingReading);
      return;
    }
    var microphoneWasOpen = false;
    try {
      microphoneWasOpen = stopped.microphoneOpen;
    } catch (_) {
      // A call whose state cannot be read had nothing to say about it.
    }
    _endRecovery(clearPresence: false);
    _bindMediaLifetime();
    // The recovery is in place before the call is let go, so the session
    // and the client the next call needs are still held when it is.
    final recovery = _Recovery(
      roomId: roomId,
      generation: ++_recoveryGeneration,
      microphoneWasOpen: microphoneWasOpen,
      pendingLeave: _leaveIgnoringFailure(stopped),
    );
    _recovery = recovery;
    _release(clearPresence: false);
    _startRecovery(recovery);
  }

  void _startRecovery(_Recovery recovery) {
    final roomId = recovery.roomId;
    _publish(roomId, _reconnectingReading);
    _reportRecovery(recovery.reading);
    try {
      _connectivity = ref
          .read(loopConnectivitySignalProvider)
          .onRestored
          .listen((_) => _recovery?.wake(), onError: (Object _, _) {});
    } catch (_) {
      // A radio signal that cannot be read leaves the back-off to itself.
    }
    unawaited(_runRecovery(recovery));
  }

  bool _isCurrent(_Recovery recovery) =>
      identical(_recovery, recovery) &&
      recovery.generation == _recoveryGeneration;

  Future<void> _runRecovery(_Recovery recovery) async {
    // The old call has to be gone from the provider before the same room is
    // joined again (decision 0005's rejoin rule); its leave is bounded so a
    // provider that never answers does not hold the room hostage.
    try {
      await recovery.pendingLeave.timeout(const Duration(seconds: 10));
    } catch (_) {
      // Carried on regardless: the leave is single-flight and keeps going.
    }
    while (_isCurrent(recovery)) {
      await recovery.sleep(audioRoomRecoveryDelay(recovery.attempt));
      if (!_isCurrent(recovery)) return;
      final outcome = await _attempt(recovery);
      if (!_isCurrent(recovery)) return;
      switch (outcome) {
        case _AttemptOutcome.joined:
          return;
        case _AttemptOutcome.stop:
          _endRecovery(clearPresence: true);
          return;
        case _AttemptOutcome.retry:
          recovery.attempt += 1;
          _reportRecovery(recovery.reading);
      }
    }
  }

  Future<_AttemptOutcome> _attempt(_Recovery recovery) async {
    // The room first: whether there is anything to go back to.
    final VoiceRoomSession session;
    final VoiceRoomGateway gateway;
    try {
      final current = ref.read(voiceRoomSessionProvider);
      if (current == null || current.callRoomId != recovery.roomId) {
        return _AttemptOutcome.stop;
      }
      session = current;
      gateway = ref.read(voiceRoomGatewayProvider);
    } catch (_) {
      return _AttemptOutcome.stop;
    }
    final VoiceRoomSnapshot snapshot;
    try {
      snapshot = await gateway.load(session.voiceRoomId);
    } catch (_) {
      return _AttemptOutcome.retry;
    }
    if (!_isCurrent(recovery)) return _AttemptOutcome.stop;
    if (!snapshot.room.isLive) {
      _answerEndedRoom(session);
      return _AttemptOutcome.stop;
    }
    if (!snapshot.viewer.hasJoined || snapshot.room.roomId != recovery.roomId) {
      _forgetSession(session);
      return _AttemptOutcome.stop;
    }
    // A room the provider holds backstage is live and cannot be heard; it is
    // waited out like a network.
    if (!snapshot.room.audioOpen) return _AttemptOutcome.retry;

    // The session next. After a failed attempt the client is asked for again,
    // because a refusal is held by the client that was refused.
    if (recovery.attempt > 0) {
      try {
        await ref.read(streamVideoSdkSessionProvider)?.retireForRetry();
        if (!_isCurrent(recovery)) return _AttemptOutcome.stop;
        ref
          ..invalidate(streamVideoAuthorizationProvider)
          ..invalidate(audioRoomCallFactoryProvider);
      } catch (_) {
        return _AttemptOutcome.retry;
      }
    }
    try {
      final authorization = await ref.read(
        streamVideoAuthorizationProvider.future,
      );
      if (authorization != StreamVideoSessionAuthorization.authorized) {
        return _AttemptOutcome.retry;
      }
    } catch (_) {
      return _AttemptOutcome.retry;
    }
    if (!_isCurrent(recovery)) return _AttemptOutcome.stop;
    final AudioRoomCallFactory? factory;
    try {
      factory = ref.read(audioRoomCallFactoryProvider);
    } catch (_) {
      return _AttemptOutcome.retry;
    }
    final target = AudioRoomTarget.tryParse(
      callType: AudioRoomTarget.callType,
      roomId: recovery.roomId,
    );
    if (factory == null || target == null) return _AttemptOutcome.retry;

    final AudioRoomCallHandle handle;
    try {
      handle = factory.create(target);
    } catch (_) {
      return _AttemptOutcome.retry;
    }
    if (handle.roomId != recovery.roomId) {
      unawaited(_leaveIgnoringFailure(handle));
      return _AttemptOutcome.retry;
    }
    // Held before it is joined, so a room page on screen shows the new call
    // coming in rather than an empty lobby.
    hold(handle);
    try {
      await handle.joinMuted();
    } catch (_) {
      if (identical(_held, handle)) _release(clearPresence: false);
      await _leaveIgnoringFailure(handle);
      if (_isCurrent(recovery)) _publish(recovery.roomId, _reconnectingReading);
      return _isCurrent(recovery)
          ? _AttemptOutcome.retry
          : _AttemptOutcome.stop;
    }
    if (!_isCurrent(recovery)) {
      // The reader left, or another room took this one's place, while it was
      // joining. It is not this recovery's to keep.
      if (!identical(_held, handle)) unawaited(_leaveIgnoringFailure(handle));
      return _AttemptOutcome.stop;
    }
    if (!identical(_held, handle)) {
      // The new call dropped again before its join answered.
      unawaited(_leaveIgnoringFailure(handle));
      return _AttemptOutcome.retry;
    }
    _finishRecovery(recovery);
    return _AttemptOutcome.joined;
  }

  void _finishRecovery(_Recovery recovery) {
    _recovery = null;
    _recoveryGeneration += 1;
    unawaited(_connectivity?.cancel());
    _connectivity = null;
    _reportRecovery(
      recovery.microphoneWasOpen
          ? AudioRoomRecovery(
              roomId: recovery.roomId,
              phase: AudioRoomRecoveryPhase.restored,
              attempt: recovery.attempt,
              microphoneWasOpen: true,
            )
          : null,
    );
    final held = _held;
    final reading = _reading;
    if (held != null && reading != null && _views.isEmpty) {
      _publish(held.roomId, reading);
    }
  }

  void _endRecovery({required bool clearPresence}) {
    final recovery = _recovery;
    _recovery = null;
    _recoveryGeneration += 1;
    unawaited(_connectivity?.cancel());
    _connectivity = null;
    if (recovery == null) return;
    recovery.wake();
    _reportRecovery(null);
    if (clearPresence && _held == null) _clearPresence(recovery.roomId);
    _releaseMediaLifetime();
  }

  /// A room the host ended while this device was putting it back.
  void _answerEndedRoom(VoiceRoomSession session) {
    try {
      ref.read(voiceRoomSessionProvider.notifier).leave(session.communityId);
      // A reader looking at the room page is told by the page; a marker that
      // simply vanishes from another tab needs one line.
      if (_views.isEmpty) {
        ref
            .read(voiceRoomEndedNoticeProvider.notifier)
            .raise(session.communityId);
      }
    } catch (_) {
      // The container can be torn down before this lands.
    }
  }

  void _forgetSession(VoiceRoomSession session) {
    try {
      ref.read(voiceRoomSessionProvider.notifier).leave(session.communityId);
    } catch (_) {
      // See above.
    }
  }

  void _nameNotification(VoiceRoomSession? session) {
    try {
      ref.read(audioRoomNotificationBridgeProvider).title =
          audioRoomNotificationTitle(session?.communityName);
    } catch (_) {
      // Nothing to name while the container goes down.
    }
  }

  AudioRoomRecovery? _readRecovery() {
    try {
      return ref.read(audioRoomRecoveryProvider);
    } catch (_) {
      return null;
    }
  }

  void _reportRecovery(AudioRoomRecovery? recovery) {
    try {
      ref.read(audioRoomRecoveryProvider.notifier).report(recovery);
    } catch (_) {
      // A retired container clears the reading itself.
    }
  }

  void _release({required bool clearPresence}) {
    final held = _held;
    _readings?.cancel();
    _readings = null;
    _held = null;
    _reading = null;
    state = null;
    _releaseMediaLifetime();
    if (held != null && clearPresence) _clearPresence(held.roomId);
  }

  void _retireOnTeardown() {
    final held = _held;
    _recovery?.wake();
    _recovery = null;
    _recoveryGeneration += 1;
    unawaited(_connectivity?.cancel());
    _connectivity = null;
    _readings?.cancel();
    _readings = null;
    _held = null;
    _reading = null;
    // The subscriptions belong to the ref that is being torn down, and this
    // notifier is reused when the principal rotates; the next call opens its
    // own.
    _mediaLifetime = null;
    if (held == null) return;
    _clearPresence(held.roomId);
    unawaited(_leaveIgnoringFailure(held));
  }

  static Future<void> _applyOutputIgnoringFailure(
    AudioRoomCallHandle handle,
    AudioRoomOutputPreference preference,
  ) async {
    try {
      await handle.applyOutputPreference(preference);
    } catch (_) {
      // The route the platform kept is what the control reads back.
    }
  }

  static Future<void> _leaveIgnoringFailure(AudioRoomCallHandle handle) async {
    try {
      await handle.leave();
    } catch (_) {
      // The handle's own leave is single-flight; a failure here leaves the
      // call exactly where the provider left it.
    }
  }

  void _publish(String roomId, AudioRoomCallReading reading) {
    try {
      ref
          .read(audioRoomLivePresenceProvider.notifier)
          .report(
            AudioRoomLivePresence(
              roomId: roomId,
              phase: reading.phase,
              participantCount: reading.participantCount,
              speakers: reading.speakers,
            ),
          );
    } catch (_) {
      // A retired container clears the reading itself.
    }
  }

  void _clearPresence(String roomId) {
    try {
      ref.read(audioRoomLivePresenceProvider.notifier).clear(roomId);
    } catch (_) {
      // See above.
    }
  }
}

final activeVoiceMediaProvider =
    NotifierProvider<ActiveVoiceMediaController, AudioRoomCallHandle?>(
      ActiveVoiceMediaController.new,
    );

enum _AttemptOutcome { joined, retry, stop }

/// One automatic reconnection: which room, how far it got, and how to cut its
/// wait short.
final class _Recovery {
  _Recovery({
    required this.roomId,
    required this.generation,
    required this.microphoneWasOpen,
    required this.pendingLeave,
  });

  final String roomId;
  final int generation;
  final bool microphoneWasOpen;
  final Future<void> pendingLeave;
  int attempt = 0;
  Completer<void>? _wake;

  AudioRoomRecovery get reading => AudioRoomRecovery(
    roomId: roomId,
    phase: AudioRoomRecoveryPhase.reconnecting,
    attempt: attempt,
    microphoneWasOpen: microphoneWasOpen,
  );

  /// Waits out [delay], or less when [wake] is called: the network came
  /// back, LOOP came back to the screen, or the recovery was cancelled.
  Future<void> sleep(Duration delay) {
    final wake = Completer<void>();
    _wake = wake;
    final timer = Timer(delay, () {
      if (!wake.isCompleted) wake.complete();
    });
    return wake.future.whenComplete(timer.cancel);
  }

  void wake() {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }
}

/// One announcement that a voice room ended while the reader was elsewhere.
///
/// The membership goes with the room, and with it the strip that was the only
/// sign the account was in one. A marker that simply vanishes tells the reader
/// nothing: the audio stopped, the way back in is gone, and nothing on the
/// screen accounts for either. This is raised once per room that ended, and
/// only for a room no page was on screen for — a reader looking at the room
/// page is already being told by the page.
@immutable
final class VoiceRoomEndedNotice {
  const VoiceRoomEndedNotice({
    required this.communityId,
    required this.sequence,
  });

  final String communityId;

  /// Makes two ends of the same room two announcements. Without it a second
  /// one would be equal to the first and nothing would be said.
  final int sequence;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceRoomEndedNotice &&
          other.communityId == communityId &&
          other.sequence == sequence;

  @override
  int get hashCode => Object.hash(communityId, sequence);
}

final class VoiceRoomEndedNoticeController
    extends Notifier<VoiceRoomEndedNotice?> {
  var _sequence = 0;

  @override
  VoiceRoomEndedNotice? build() => null;

  void raise(String communityId) {
    _sequence += 1;
    state = VoiceRoomEndedNotice(communityId: communityId, sequence: _sequence);
  }
}

final voiceRoomEndedNoticeProvider =
    NotifierProvider<VoiceRoomEndedNoticeController, VoiceRoomEndedNotice?>(
      VoiceRoomEndedNoticeController.new,
    );

/// One binding observer for the holder, and nothing else.
class _ActiveVoiceMediaLifecycle with WidgetsBindingObserver {
  _ActiveVoiceMediaLifecycle(this._onChanged);

  final void Function(AppLifecycleState state) _onChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _onChanged(state);
}
