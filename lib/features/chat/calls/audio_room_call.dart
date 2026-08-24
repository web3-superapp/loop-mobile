import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_foreground_call_view.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

enum AudioRoomCallFailureKind { join, leave }

final class AudioRoomCallFailure implements Exception {
  const AudioRoomCallFailure(this.kind);

  final AudioRoomCallFailureKind kind;

  @override
  String toString() => 'Audio Room command failed: ${kind.name}';
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

  Future<void> joinMuted();

  Future<bool> setMicrophoneEnabled({required bool enabled});

  /// Retires the foreground-only Call after the app leaves the foreground.
  Future<void> retireForBackground();

  Future<void> leave();

  Widget buildForeground({required Future<void> Function() onLeaveRequested});
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

  final Future<bool> Function(bool enabled) _setMicrophone;
  final Future<void> Function() _leave;
  final Future<void> Function() _suspendAudio;

  Future<void> _microphoneTail = Future<void>.value();
  Future<void>? _retirement;
  var _retiring = false;
  var _microphoneEnableRequested = false;

  bool get retirementStarted => _retiring;

  Future<bool> setMicrophoneEnabled({required bool enabled}) {
    if (_retiring) {
      // A failed leave keeps the official Call view mounted. Capture may
      // still be stopped, but it can never be restarted on a retiring Call.
      return enabled
          ? Future<bool>.value(false)
          : _runDetachedMicrophoneDisable();
    }
    // Stream Video 1.4.3 can recreate a previously stopped track after its
    // Call has already been disposed. Audio Room v1 therefore permits only
    // the initial muted -> speaking transition on each Call. After Mute, the
    // user leaves and rejoins before another Speak attempt.
    if (enabled && _microphoneEnableRequested) {
      return Future<bool>.value(false);
    }
    if (enabled) _microphoneEnableRequested = true;
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

  Future<bool> _runMicrophoneCommand(
    Future<void> predecessor,
    bool enabled,
  ) async {
    await predecessor;
    if (_retiring) return false;
    try {
      return await _setMicrophone(enabled);
    } catch (_) {
      return false;
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

  Future<bool> _runDetachedMicrophoneDisable() async {
    try {
      return await _setMicrophone(false);
    } catch (_) {
      return false;
    }
  }
}

abstract interface class AudioRoomCallFactory {
  AudioRoomCallHandle create(AudioRoomTarget target);
}

final audioRoomCallFactoryProvider =
    Provider.autoDispose<AudioRoomCallFactory?>((ref) {
      final client = ref.watch(streamVideoSdkSessionProvider)?.officialClient;
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
  Future<void> joinMuted() async {
    final result = await _call.join(
      connectOptions: mutedAudioRoomConnectOptions(),
    );
    if (result.isFailure) {
      throw const AudioRoomCallFailure(AudioRoomCallFailureKind.join);
    }
  }

  @override
  Future<bool> setMicrophoneEnabled({required bool enabled}) {
    return _commands.setMicrophoneEnabled(enabled: enabled);
  }

  Future<bool> _setMicrophone(bool enabled) async {
    if (enabled) {
      final trackIdPrefix = _call.state.value.localParticipant?.trackIdPrefix;
      if (trackIdPrefix == null || trackIdPrefix.isEmpty) return false;
      // A local audio track means this would enter the unsafe stopped-track
      // recreate path. A new Call is required before speaking again.
      if (_call.getTrack(trackIdPrefix, SfuTrackType.audio) != null) {
        return false;
      }
    }
    final result = await _call.setMicrophoneEnabled(enabled: enabled);
    return result.isSuccess;
  }

  @override
  Future<void> retireForBackground() {
    return _commands.retire();
  }

  Future<void> _leaveCall() async {
    final result = await _call.leave();
    if (result.isFailure) {
      throw const AudioRoomCallFailure(AudioRoomCallFailureKind.leave);
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
  Widget buildForeground({required Future<void> Function() onLeaveRequested}) {
    return StreamForegroundCallView(
      call: _call,
      retirementStarted: () => retirementStarted,
      onMicrophoneRequested: setMicrophoneEnabled,
      onLeaveRequested: onLeaveRequested,
    );
  }
}
