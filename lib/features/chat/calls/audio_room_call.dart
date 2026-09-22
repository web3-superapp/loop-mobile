import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_foreground_call_view.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

enum AudioRoomCallFailureKind { join, leave }

/// Why the provider did not put this device in the room.
///
/// A join that came back refused used to leave the surface one sentence for
/// every cause there is, and the provider's own answer was dropped on the
/// floor — a reader looking at 「没能连上这个语音房」 could not tell a room that
/// is not open to listeners from a network that never reached it, and neither
/// could anyone reading the device afterwards. Each kind now carries its own
/// next step, and the provider's wording stays in the log where it belongs:
/// it is an SDK string, not something a reader can act on.
enum AudioRoomJoinRefusal {
  /// The account is not allowed into this call as it stands.
  permission,

  /// The call itself cannot be joined: it is gone, ended, or not a room.
  roomUnavailable,

  /// The attempt never reached the provider.
  network,

  /// The provider did not accept this device's credentials.
  session,

  /// The answer named no cause this client recognises.
  unknown,
}

/// Classifies one provider answer without ever showing it.
///
/// The markers are the vocabulary the SDK composes its errors from (an HTTP
/// status, a Twirp message, a socket fault). Order matters: a credential
/// refusal names authentication, an admission refusal names permission, and
/// only an answer that names neither is read as a transport fault.
abstract final class AudioRoomJoinRefusalMapping {
  static const List<String> _session = <String>[
    'unauthenticated',
    'authentication',
    'token',
    'jwt',
    '401',
  ];
  static const List<String> _permission = <String>[
    'permission',
    'forbidden',
    'not allowed',
    'denied',
    'backstage',
    '403',
  ];
  static const List<String> _roomUnavailable = <String>[
    'not found',
    'does not exist',
    'has ended',
    'call ended',
    'not live',
    '404',
    '410',
  ];
  static const List<String> _network = <String>[
    'timeout',
    'timed out',
    'network',
    'socket',
    'connection',
    'unreachable',
    'host lookup',
    'offline',
  ];

  static AudioRoomJoinRefusal fromDetail(String? detail) {
    final answer = detail?.toLowerCase().trim();
    if (answer == null || answer.isEmpty) return AudioRoomJoinRefusal.unknown;
    bool names(List<String> markers) =>
        markers.any((marker) => answer.contains(marker));
    if (names(_session)) return AudioRoomJoinRefusal.session;
    if (names(_permission)) return AudioRoomJoinRefusal.permission;
    if (names(_roomUnavailable)) return AudioRoomJoinRefusal.roomUnavailable;
    if (names(_network)) return AudioRoomJoinRefusal.network;
    return AudioRoomJoinRefusal.unknown;
  }
}

final class AudioRoomCallFailure implements Exception {
  const AudioRoomCallFailure(
    this.kind, {
    this.refusal = AudioRoomJoinRefusal.unknown,
    this.detail,
  });

  final AudioRoomCallFailureKind kind;

  /// What the provider refused, as far as its answer says.
  final AudioRoomJoinRefusal refusal;

  /// The provider's own answer. It goes to the debug log and nowhere else.
  final String? detail;

  @override
  String toString() {
    final answer = detail;
    return 'Audio Room command failed: ${kind.name} · ${refusal.name}'
        '${answer == null ? '' : ' · $answer'}';
  }
}

/// Creates the explicit audio-only options used for every first join.
///
/// All local publishing tracks stay disabled until a later, deliberate user
/// microphone action succeeds. Dashboard defaults cannot turn them on.
CallConnectOptions mutedAudioRoomConnectOptions() {
  return CallConnectOptions(
    camera: TrackOption.disabled(),
    microphone: TrackOption.disabled(),
    screenShare: TrackOption.disabled(),
    // This controls the audio output route only; it does not publish media.
    speakerDefaultOn: true,
  );
}

abstract interface class AudioRoomCallHandle {
  String get roomId;

  bool get retirementStarted;

  /// What this call is doing right now.
  AudioRoomCallReading get reading;

  /// Every change to [reading], for as long as this call exists.
  ///
  /// The mounted call view reads the provider's state for itself. Everything
  /// else — the strip that says the account is still in a room while the
  /// reader looks at another tab, and whoever holds the call across a page
  /// that came off the screen — has no view to read it from, and a reading
  /// taken before the page closed is not what the call is doing now.
  Stream<AudioRoomCallReading> get readings;

  /// Every provider event that means a LOOP record about this room is stale.
  ///
  /// The page reads the record; nothing here composes state out of an event.
  Stream<AudioRoomRoomSignal> get roomSignals;

  Future<void> joinMuted();

  Future<AudioRoomMicrophoneOutcome> setMicrophoneEnabled({
    required bool enabled,
  });

  /// Retires the foreground-only Call after the app leaves the foreground.
  Future<void> retireForBackground();

  Future<void> leave();

  /// [inline] asks for the section layout used inside the LOOP voice room
  /// page, which owns the only scrolling region on that screen.
  ///
  /// [onMicrophoneEnabled] is called after the device actually opened the
  /// microphone, and only then. It is the LOOP side's cue, not a media
  /// command: it never decides whether the microphone opens.
  ///
  /// [onPresence] publishes the call's own phase and head count to the
  /// surfaces outside this view — the room facts above it and the shell strip
  /// — so one screen never carries two different numbers under one word. A
  /// null count is a connection that has not counted anyone yet; it is never
  /// published as 0.
  ///
  /// [onDisconnected] is called once this call stopped for good and nothing is
  /// putting it back: a call that ended is not a surface the reader can act
  /// on, so the page takes it down and offers the connection again. It is
  /// never called while the SDK is reconnecting, and never for a call this
  /// device is already retiring.
  ///
  /// [onSpeakAgainRequested] is asked when a member who already spoke in this
  /// call wants the microphone back. One call starts one microphone, so that
  /// is a new call — a decision that belongs to whoever owns the call, never
  /// to this handle.
  Widget buildForeground({
    required Future<void> Function() onLeaveRequested,
    bool inline,
    Future<void> Function()? onMicrophoneEnabled,
    void Function({
      required AudioRoomLivePhase phase,
      required int? participantCount,
      required List<AudioRoomSpeaker> speakers,
    })?
    onPresence,
    VoidCallback? onDisconnected,
    Future<void> Function()? onSpeakAgainRequested,
  });
}

/// Serializes foreground microphone commands with one terminal retirement.
///
/// Stream Video 1.4.3 does not make concurrent `leave()` calls single-flight,
/// and an in-flight unmute can asynchronously recreate a stopped track. Once
/// retirement begins, native suspension, a final mute, and leave are all
/// started immediately without waiting for a possibly stuck media command.
/// The injected leave callback remains responsible for confirming that the
/// Call has disappeared from the SDK client's active Calls.
final class AudioRoomCallCommandCoordinator {
  AudioRoomCallCommandCoordinator(
    this._setMicrophone,
    this._leave,
    this._suspendAudio,
  );

  final Future<AudioRoomMicrophoneOutcome> Function(bool enabled)
  _setMicrophone;
  final Future<void> Function() _leave;
  final Future<void> Function() _suspendAudio;

  Future<void> _microphoneTail = Future<void>.value();
  Future<void>? _retirement;
  var _retiring = false;
  var _microphoneEnableRequested = false;

  bool get retirementStarted => _retiring;

  Future<AudioRoomMicrophoneOutcome> setMicrophoneEnabled({
    required bool enabled,
  }) {
    if (_retiring) {
      // A failed leave keeps the official Call view mounted. Capture may
      // still be stopped, but it can never be restarted on a retiring Call.
      return enabled
          ? Future<AudioRoomMicrophoneOutcome>.value(
              const AudioRoomMicrophoneOutcome.refused(
                AudioRoomMicrophoneRefusal.callClosed,
              ),
            )
          : _runDetachedMicrophoneDisable();
    }
    // Stream Video 1.4.3 can recreate a previously stopped track after its
    // Call has already been disposed. Audio Room v1 therefore permits only
    // the initial muted -> speaking transition on each Call. After Mute, the
    // user leaves and rejoins before another Speak attempt.
    //
    // The latch is spent by a microphone that opened, not by an attempt. A
    // Speak the device refused created no track — `_setMicrophone` proves
    // that for itself before every enable — so the member may answer the
    // system's microphone question and try again from inside the room.
    if (enabled && _microphoneEnableRequested) {
      return Future<AudioRoomMicrophoneOutcome>.value(
        const AudioRoomMicrophoneOutcome.refused(
          AudioRoomMicrophoneRefusal.callClosed,
        ),
      );
    }
    final predecessor = _microphoneTail;
    final operation = _runMicrophoneCommand(predecessor, enabled);
    _microphoneTail = operation.then<void>((_) {});
    return operation;
  }

  Future<void> retire() {
    _retiring = true;
    final active = _retirement;
    if (active != null) return active;
    final operation = _runRetirement();
    _retirement = operation;
    return operation;
  }

  Future<AudioRoomMicrophoneOutcome> _runMicrophoneCommand(
    Future<void> predecessor,
    bool enabled,
  ) async {
    await predecessor;
    // Re-read after the queue: a command that waited its turn may find the
    // call retiring, or a Speak already carried out by the one ahead of it.
    if (_retiring || (enabled && _microphoneEnableRequested)) {
      return const AudioRoomMicrophoneOutcome.refused(
        AudioRoomMicrophoneRefusal.callClosed,
      );
    }
    try {
      final outcome = await _setMicrophone(enabled);
      if (enabled && outcome.opened) _microphoneEnableRequested = true;
      return outcome;
    } catch (error) {
      return AudioRoomMicrophoneOutcome.refused(
        AudioRoomMicrophoneRefusalMapping.fromDetail('$error'),
        detail: '$error',
      );
    }
  }

  Future<void> _runRetirement() async {
    try {
      // Both operations are best-effort and deliberately detached. A native
      // suspend or an SDK microphone command may never resolve. Neither is
      // allowed to delay terminal Call cleanup.
      unawaited(_suspendAudioIgnoringFailure());
      unawaited(_muteIgnoringFailure());
      await _leave();
      // The leave above is intentionally not delayed by a stuck command. The
      // lobby, however, stays fail-closed until that command settles and a
      // second terminal mute has run. Combined with one Speak attempt per
      // Call, this avoids Stream 1.4.3's late stopped-track recreation path.
      await _microphoneTail;
      await _muteIgnoringFailure();
    } catch (_) {
      // A completed failure may be retried, but concurrent callers always
      // observe this same attempt rather than starting a second SDK leave.
      _retirement = null;
      rethrow;
    }
  }

  Future<void> _suspendAudioIgnoringFailure() async {
    try {
      await _suspendAudio();
    } catch (_) {
      // The detached final mute and confirmed leave still run.
    }
  }

  Future<void> _muteIgnoringFailure() async {
    try {
      await _setMicrophone(false);
    } catch (_) {
      // Confirmed Call removal remains the authoritative media cleanup. The
      // SDK discards tracks that finish publishing while its RTC manager is
      // being disposed.
    }
  }

  Future<AudioRoomMicrophoneOutcome> _runDetachedMicrophoneDisable() async {
    try {
      return await _setMicrophone(false);
    } catch (error) {
      return AudioRoomMicrophoneOutcome.refused(
        AudioRoomMicrophoneRefusalMapping.fromDetail('$error'),
        detail: '$error',
      );
    }
  }
}

abstract interface class AudioRoomCallFactory {
  AudioRoomCallHandle create(AudioRoomTarget target);
}

/// The one place a call is made from, and only from a client this device is
/// currently authorized to hold.
///
/// The authorization is watched, not merely assumed by the caller: a retry
/// retires the session and asks for a token again, and the client that answers
/// arrives some hundreds of milliseconds after the retry dropped this
/// provider. Reading the session alone, this rebuilt once — while the retired
/// client was gone and the new one had not been built — cached null, and never
/// rebuilt again, so 「重试会话」 left the surface holding no factory and the
/// reader with no way forward except leaving the page. Watching the
/// authorization makes the landing of a new session the moment this is
/// computed again.
final audioRoomCallFactoryProvider =
    Provider.autoDispose<AudioRoomCallFactory?>((ref) {
      final authorized =
          ref.watch(streamVideoAuthorizationProvider).value ==
          StreamVideoSessionAuthorization.authorized;
      final client = authorized
          ? ref.watch(streamVideoSdkSessionProvider)?.officialClient
          : null;
      return client == null ? null : StreamAudioRoomCallFactory(client);
    });

final class StreamAudioRoomCallFactory implements AudioRoomCallFactory {
  const StreamAudioRoomCallFactory(this._client);

  final StreamVideo _client;

  @override
  AudioRoomCallHandle create(AudioRoomTarget target) {
    final call = _client.makeCall(
      callType: StreamCallType.audioRoom(),
      id: target.roomId,
    );
    return _StreamAudioRoomCallHandle(_client, target.roomId, call);
  }
}

final class _StreamAudioRoomCallHandle implements AudioRoomCallHandle {
  _StreamAudioRoomCallHandle(this._client, this.roomId, this._call) {
    _commands = AudioRoomCallCommandCoordinator(
      _setMicrophone,
      _leaveCall,
      _call.suspendAudio,
    );
  }

  @override
  final String roomId;

  final StreamVideo _client;
  final Call _call;
  late final AudioRoomCallCommandCoordinator _commands;

  @override
  bool get retirementStarted => _commands.retirementStarted;

  @override
  AudioRoomCallReading get reading => _readingOf(_call.state.value);

  @override
  Stream<AudioRoomCallReading> get readings => _call.partialState(_readingOf);

  @override
  Stream<AudioRoomRoomSignal> get roomSignals => _call.callEvents
      .asStream()
      .map(_signalOf)
      .where((signal) => signal != null)
      .cast<AudioRoomRoomSignal>();

  /// Reads one provider event as the LOOP record it invalidates, or nothing.
  ///
  /// Only two of the SDK's events say something LOOP holds has changed: the
  /// custom event the server sends after a hand raise (decision 0069), and the
  /// four that say the people in the room are not the ones this device was
  /// told about. Everything else belongs to the call, which the call view
  /// reads for itself.
  static AudioRoomRoomSignal? _signalOf(StreamCallEvent event) {
    if (event is StreamCallCustomEvent) {
      return event.custom?['loop_event_kind'] == _handRaiseEventKind
          ? AudioRoomRoomSignal.handRaise
          : null;
    }
    if (event is StreamCallSessionParticipantJoinedEvent ||
        event is StreamCallSessionParticipantLeftEvent ||
        event is StreamCallMemberAddedEvent ||
        event is StreamCallMemberRemovedEvent) {
      return AudioRoomRoomSignal.participants;
    }
    return null;
  }

  /// The one custom event LOOP sends into a room (decision 0069).
  static const _handRaiseEventKind = 'voiceRoomHandRaise';

  /// The same figures the call panel prints, from the same official state.
  static AudioRoomCallReading _readingOf(CallState state) {
    final connected = state.status.isConnected;
    return AudioRoomCallReading(
      phase: StreamCallStatusPresentation.livePhase(state.status),
      participantCount: StreamCallParticipantPresentation.liveCount(
        connected: connected,
        participantCount: state.participantCount,
        knownParticipants: state.callParticipants.length,
      ),
      // The same people the call panel draws, for the surfaces that have no
      // panel to read: a room page whose call view is not the thing on
      // screen still says who can be heard.
      speakers: StreamCallParticipantPresentation.speaking(
        connected: connected,
        participants: state.callParticipants,
      ),
    );
  }

  @override
  Future<void> joinMuted() async {
    final result = await _call.join(
      connectOptions: mutedAudioRoomConnectOptions(),
    );
    if (!result.isFailure) return;
    // The SDK answers with one `Result`; the refusal inside it is the only
    // account of why this device is not in the room, and dropping it left
    // the page with nothing to say and the device with nothing to read.
    final detail = result is Failure ? _describeFailure(result) : null;
    throw AudioRoomCallFailure(
      AudioRoomCallFailureKind.join,
      refusal: AudioRoomJoinRefusalMapping.fromDetail(detail),
      detail: detail,
    );
  }

  static String? _describeFailure(Failure failure) {
    final message = failure.error.message.trim();
    return message.isEmpty ? failure.error.toString() : message;
  }

  @override
  Future<AudioRoomMicrophoneOutcome> setMicrophoneEnabled({
    required bool enabled,
  }) {
    return _commands.setMicrophoneEnabled(enabled: enabled);
  }

  Future<AudioRoomMicrophoneOutcome> _setMicrophone(bool enabled) {
    if (!enabled) return _runMicrophoneCommand(false);
    // The system's microphone question is answered outside this command, so
    // the first answer may be a failure the SDK could not attribute. One
    // re-attempt keeps the member in the room instead of sending them out and
    // back in.
    return audioRoomEnableMicrophoneWithRetry(
      () => _runMicrophoneCommand(true),
    );
  }

  Future<AudioRoomMicrophoneOutcome> _runMicrophoneCommand(bool enabled) async {
    if (enabled) {
      final trackIdPrefix = _call.state.value.localParticipant?.trackIdPrefix;
      if (trackIdPrefix == null || trackIdPrefix.isEmpty) {
        return const AudioRoomMicrophoneOutcome.refused(
          AudioRoomMicrophoneRefusal.callClosed,
        );
      }
      // A local audio track means this would enter the unsafe stopped-track
      // recreate path. A new Call is required before speaking again.
      if (_call.getTrack(trackIdPrefix, SfuTrackType.audio) != null) {
        return const AudioRoomMicrophoneOutcome.refused(
          AudioRoomMicrophoneRefusal.callClosed,
        );
      }
    }
    final result = await _call.setMicrophoneEnabled(enabled: enabled);
    if (result.isSuccess) return const AudioRoomMicrophoneOutcome.opened();
    final detail = result is Failure ? _describeFailure(result) : null;
    if (kDebugMode) {
      // The provider's own words stay here. They are the only account of
      // what the device refused, and they are not a sentence for a reader.
      debugPrint('LOOP microphone refused: $roomId · $detail');
    }
    return AudioRoomMicrophoneOutcome.refused(
      AudioRoomMicrophoneRefusalMapping.fromDetail(detail),
      detail: detail,
    );
  }

  @override
  Future<void> retireForBackground() {
    return _commands.retire();
  }

  Future<void> _leaveCall() async {
    final result = await _call.leave();
    if (result.isFailure) {
      throw AudioRoomCallFailure(
        AudioRoomCallFailureKind.leave,
        detail: result is Failure ? _describeFailure(result) : null,
      );
    }

    // Call.leave() can return success when another SDK disconnect is already
    // clearing this Call. The active-call removal happens later, after RTC
    // disposal. Waiting for object identity here prevents a same-CID rejoin
    // from being unlocked while the old cleanup can still remove it.
    await _client.state.activeCalls.asStream().firstWhere(
      (calls) => calls.every((candidate) => !identical(candidate, _call)),
    );
  }

  @override
  Future<void> leave() {
    return _commands.retire();
  }

  @override
  Widget buildForeground({
    required Future<void> Function() onLeaveRequested,
    bool inline = false,
    Future<void> Function()? onMicrophoneEnabled,
    void Function({
      required AudioRoomLivePhase phase,
      required int? participantCount,
      required List<AudioRoomSpeaker> speakers,
    })?
    onPresence,
    VoidCallback? onDisconnected,
    Future<void> Function()? onSpeakAgainRequested,
  }) {
    return StreamForegroundCallView(
      call: _call,
      onPresence: onPresence,
      onDisconnected: onDisconnected,
      onSpeakAgainRequested: onSpeakAgainRequested,
      retirementStarted: () => retirementStarted,
      onMicrophoneRequested: onMicrophoneEnabled == null
          ? setMicrophoneEnabled
          : ({required bool enabled}) async {
              final outcome = await setMicrophoneEnabled(enabled: enabled);
              // The cue follows the device, not the request: a microphone
              // that did not open reports nothing to LOOP.
              if (outcome.opened && enabled) await onMicrophoneEnabled();
              return outcome;
            },
      onLeaveRequested: onLeaveRequested,
      inline: inline,
    );
  }
}
