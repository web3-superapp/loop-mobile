import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';

/// The one provider call this device holds, and the app holds it.
///
/// The call used to belong to the room page: closing that page disposed the
/// widget and the audio went with it, so a reader who opened the wallet to
/// check a balance stopped hearing the room mid-sentence and came back to a
/// lobby. The room page is now a view of this call — it mounts one, it takes
/// it down when the reader leaves, and it makes a new one only when there is
/// none to show. Going to another tab is not a decision about the audio.
///
/// This is deliberately the foreground only. LOOP leaving the foreground still
/// ends the call, whether or not a room page is on screen; there is no
/// notification, no foreground service and no system-level session behind it.
/// Switching screens inside the app is not leaving the foreground, and that is
/// the whole of what this changes.
final class ActiveVoiceMediaController extends Notifier<AudioRoomCallHandle?> {
  /// The mounted call views. While one of them is on screen it publishes the
  /// reading itself, from the same official state, and this holder stays out
  /// of the way; the views are identity tokens and nothing else.
  final Set<Object> _views = Set<Object>.identity();

  AudioRoomCallHandle? _held;
  AudioRoomCallReading? _reading;
  StreamSubscription<AudioRoomCallReading>? _readings;
  _ActiveVoiceMediaLifecycle? _lifecycle;

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
  /// The lifetime is taken here, and only while there is a call or a mounted
  /// view to justify it. Watching them in [build] instead would make the
  /// provider session permanent for the rest of the sign-in: voice is a
  /// foreground-only feature with no session behind it, and a client kept
  /// open for an account that left the room hours ago is exactly the standing
  /// connection this feature does not have.
  List<ProviderSubscription<Object?>>? _mediaLifetime;

  @override
  AudioRoomCallHandle? build() {
    // The call belongs to the account that made it. A sign-out or an account
    // change rotates this provider, and the call goes down with it rather
    // than being left running for whoever comes next.
    ref.watch(streamVideoPrincipalKeyProvider);
    // Voice is foreground-only, and that rule used to be kept by the room
    // page's own observer. The call no longer belongs to that page, so the
    // rule is kept here as well: LOOP leaving the foreground ends a call that
    // has no page watching it.
    final lifecycle = _ActiveVoiceMediaLifecycle(_onAppLifecycle);
    _lifecycle = lifecycle;
    WidgetsBinding.instance.addObserver(lifecycle);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(lifecycle);
      if (identical(_lifecycle, lifecycle)) _lifecycle = null;
    });
    ref.onDispose(_retireOnTeardown);
    return null;
  }

  void _onAppLifecycle(AppLifecycleState state) {
    final movedToBackground =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (!movedToBackground) return;
    // A mounted room page retires its own call, with the cleanup state it has
    // to show for it. This is the call nobody is on screen for.
    if (_views.isNotEmpty) return;
    final held = _held;
    if (held == null) return;
    final roomId = held.roomId;
    _release(clearPresence: false);
    // The media stops; the membership does not. Clearing the reading as well
    // left the strip printing LOOP's joined figure as if this device had
    // never been in a call — and on the review device it left no strip at
    // all, with the account still recorded in the room and no way to leave
    // it. What stopped is the audio, so that is what is said, together with
    // the way back in.
    _publish(
      roomId,
      const AudioRoomCallReading(
        phase: AudioRoomLivePhase.disconnected,
        participantCount: null,
      ),
    );
    unawaited(_retireForBackgroundIgnoringFailure(held));
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
  /// Returns false when the provider did not confirm the leave. The caller
  /// still releases the LOOP membership: staying in a room against the
  /// reader's decision because a provider command hung is the worse answer.
  Future<bool> retire() async {
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

  /// A call view came on screen; from here it publishes the reading.
  void attachView(Object token) {
    _views.add(token);
    // The view is about to make a call out of the session, the authorization
    // and the factory. From this moment they are held here, so that the view
    // going away is not the same thing as the call going away.
    _bindMediaLifetime();
  }

  /// Holds the provider session, its authorization and the call factory for
  /// as long as this device has a call or a mounted view.
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

  /// Lets go of the session once there is neither a call nor a view.
  ///
  /// Voice is foreground-only and nothing here is kept for later: the client
  /// this device authorized goes when the last thing that needed it does, and
  /// the next room page asks for an identity, a token and a client of its own.
  void _releaseMediaLifetime() {
    if (_held != null || _views.isNotEmpty) return;
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
    if (!_views.remove(token) || _views.isNotEmpty) return;
    // A view that leaves with no call behind it takes the session with it.
    // A view that leaves while this device is in a room does not: that is
    // the whole point of the call belonging to the app.
    _releaseMediaLifetime();
    scheduleMicrotask(() {
      final held = _held;
      final reading = _reading;
      if (held == null || reading == null || _views.isNotEmpty) return;
      _publish(held.roomId, reading);
      if (reading.phase == AudioRoomLivePhase.disconnected &&
          !held.retirementStarted) {
        unawaited(_answerForStoppedCall(held));
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
    _publish(held.roomId, reading);
    if (reading.phase != AudioRoomLivePhase.disconnected ||
        held.retirementStarted) {
      return;
    }
    unawaited(_answerForStoppedCall(held));
  }

  /// Takes down a call the provider stopped while no view was on screen, and
  /// reads the room to find out what the strip should say about it.
  ///
  /// A dropped network and a room the host ended arrive here as the same
  /// disconnection. A room that is still live keeps the membership, and the
  /// strip keeps 「语音已断开」 with the way back in; a room that ended has no
  /// membership left to mark, so the strip goes with it. A read that could
  /// not finish answers neither, and the strip keeps the disconnection it can
  /// see for itself.
  Future<void> _answerForStoppedCall(AudioRoomCallHandle handle) async {
    final roomId = handle.roomId;
    _release(clearPresence: false);
    await _leaveIgnoringFailure(handle);
    final VoiceRoomSession session;
    final VoiceRoomGateway gateway;
    try {
      final current = ref.read(voiceRoomSessionProvider);
      if (current == null || current.callRoomId != roomId) return;
      session = current;
      gateway = ref.read(voiceRoomGatewayProvider);
    } catch (_) {
      // The container can be torn down before this lands; the strip goes
      // with it either way.
      return;
    }
    try {
      final snapshot = await gateway.load(session.voiceRoomId);
      if (snapshot.room.isLive) return;
    } catch (_) {
      return;
    }
    try {
      ref.read(voiceRoomSessionProvider.notifier).leave(session.communityId);
      // The strip disappearing is the whole of what the reader would see, and
      // a marker that vanishes says nothing about why. One line does.
      ref
          .read(voiceRoomEndedNoticeProvider.notifier)
          .raise(session.communityId);
    } catch (_) {
      // See above.
    }
    _clearPresence(roomId);
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

  static Future<void> _retireForBackgroundIgnoringFailure(
    AudioRoomCallHandle handle,
  ) async {
    try {
      await handle.retireForBackground();
    } catch (_) {
      // The call is unreachable from here either way; the next room page
      // starts from a call of its own.
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
