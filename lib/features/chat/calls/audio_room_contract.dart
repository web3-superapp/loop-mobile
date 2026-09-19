import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';

/// One backend-authorized Stream Audio Room target.
///
/// The call type is fixed in Flutter. A route, user input, or backend response
/// cannot select another Stream call type or pass a complete CID.
@immutable
final class AudioRoomTarget {
  const AudioRoomTarget._(this.roomId);

  static const String callType = 'audio_room';
  static final RegExp _roomIdPattern = RegExp(
    r'^[a-z0-9](?:[a-z0-9_-]{0,62}[a-z0-9])?$',
  );

  final String roomId;

  static AudioRoomTarget? tryParse({
    required Object? callType,
    required Object? roomId,
  }) {
    if (callType != AudioRoomTarget.callType ||
        roomId is! String ||
        roomId != roomId.trim() ||
        !_roomIdPattern.hasMatch(roomId)) {
      return null;
    }
    return AudioRoomTarget._(roomId);
  }
}

/// Resolves the room already authorized for the current verified principal.
///
/// The production implementation will call the LOOP backend with a current
/// Privy access token. It must return only a room ID; role and capability truth
/// remain in Stream's official CallState.
abstract interface class AudioRoomTargetSource {
  Future<AudioRoomTarget?> loadTarget();
}

final audioRoomTargetSourceProvider = Provider<AudioRoomTargetSource>(
  (ref) => const _UnavailableAudioRoomTargetSource(),
);

/// Principal-bound, fail-closed Audio Room locator.
///
/// Watching the verified principal makes Riverpod discard an old locator
/// result on logout or account switch. The default source performs no request.
final audioRoomTargetProvider = FutureProvider.autoDispose<AudioRoomTarget?>((
  ref,
) async {
  final principalKey = ref.watch(streamVideoPrincipalKeyProvider);
  if (principalKey == null) return null;
  return ref.watch(audioRoomTargetSourceProvider).loadTarget();
}, retry: (retryCount, error) => null);

final class _UnavailableAudioRoomTargetSource implements AudioRoomTargetSource {
  const _UnavailableAudioRoomTargetSource();

  @override
  Future<AudioRoomTarget?> loadTarget() async => null;
}

/// Which part this account plays in the room, as LOOP granted it.
///
/// The media surface says one thing about the microphone and one thing about
/// the way out, and both depend on this: a listener never opens a microphone,
/// a speaker does, and a host has no 离开 at all. One sentence written for a
/// listener stood on all three screens, telling a host to use a control the
/// host does not have.
/// Why the device did not open the microphone.
///
/// A Speak that did not open used to have one sentence for every cause, and
/// it told the member to leave the room and come back — which is what they
/// then had to do, because a failed attempt also spent this call's one Speak.
/// The system's own microphone question is answered outside LOOP and lands
/// after the command it interrupted, so the most common cause was the one the
/// copy could not name.
enum AudioRoomMicrophoneRefusal {
  /// This device has not granted LOOP the system microphone permission.
  systemPermission,

  /// The room does not let this account send audio.
  roomPermission,

  /// This call is retiring, gone, or already holds a local audio track.
  callClosed,

  /// The answer named no cause this client recognises.
  unknown,
}

/// Reads one microphone answer, without ever showing it.
///
/// Order matters: the provider's own "missing permission to send audio" is a
/// room role, not a device setting, and `NotAllowedError` is the WebRTC
/// spelling of a system permission the member declined
/// (`stream_webrtc_flutter-3.0.2` `GetUserMediaImpl.java:575`).
abstract final class AudioRoomMicrophoneRefusalMapping {
  static const List<String> _roomPermission = <String>[
    'permission to send audio',
    'send audio',
    'video moderation',
  ];
  static const List<String> _systemPermission = <String>[
    'notallowederror',
    'not allowed',
    'permissiondeniederror',
    'permission denied',
    'denied',
    'record_audio',
    'microphone permission',
  ];
  static const List<String> _callClosed = <String>[
    'not connected',
    'session is null',
    'disposed',
    'call ended',
  ];

  static AudioRoomMicrophoneRefusal fromDetail(String? detail) {
    final answer = detail?.toLowerCase().trim();
    if (answer == null || answer.isEmpty) {
      return AudioRoomMicrophoneRefusal.unknown;
    }
    bool names(List<String> markers) =>
        markers.any((marker) => answer.contains(marker));
    if (names(_roomPermission)) {
      return AudioRoomMicrophoneRefusal.roomPermission;
    }
    if (names(_systemPermission)) {
      return AudioRoomMicrophoneRefusal.systemPermission;
    }
    if (names(_callClosed)) return AudioRoomMicrophoneRefusal.callClosed;
    return AudioRoomMicrophoneRefusal.unknown;
  }
}

/// One answer to one microphone command.
@immutable
final class AudioRoomMicrophoneOutcome {
  const AudioRoomMicrophoneOutcome.opened()
    : opened = true,
      refusal = AudioRoomMicrophoneRefusal.unknown,
      detail = null;

  const AudioRoomMicrophoneOutcome.refused(this.refusal, {this.detail})
    : opened = false;

  /// Whether the device carried the command out. For `enabled: false` this is
  /// a microphone that is now closed.
  final bool opened;

  /// What stopped it, when it did not.
  final AudioRoomMicrophoneRefusal refusal;

  /// The provider's own answer. It goes to the debug log and nowhere else.
  final String? detail;
}

/// Runs one microphone enable, and runs it a second time when the first
/// answer named no cause at all.
///
/// The system microphone question is asked by the platform the first time a
/// room member speaks, and it is answered outside this call. An answer that
/// lands while the command is already running leaves the SDK with a failure
/// it cannot attribute — the member sees a microphone that did not open even
/// though they just allowed it, and today the only way out is leaving the
/// room and coming back. One re-attempt, once, after the question is off the
/// screen, is the whole fix. A refusal that names its cause is never retried:
/// a denied permission and a room that does not let this account speak do not
/// change by asking again.
Future<AudioRoomMicrophoneOutcome> audioRoomEnableMicrophoneWithRetry(
  Future<AudioRoomMicrophoneOutcome> Function() attempt, {
  Duration retryDelay = const Duration(milliseconds: 450),
}) async {
  final first = await attempt();
  if (first.opened || first.refusal != AudioRoomMicrophoneRefusal.unknown) {
    return first;
  }
  await Future<void>.delayed(retryDelay);
  return attempt();
}

enum AudioRoomViewerRole { listener, speaker, host }

/// What this device's own call is doing, for the surfaces outside the call
/// view.
///
/// It is the same reading the call panel prints, carried one level up so the
/// room facts and the shell strip never answer a different moment than the
/// line right below them. A call that is putting itself back is not an
/// absence: 「重连中」 used to reach those surfaces as plain 「not connected」,
/// and the room facts fell back to LOOP's earlier observation — a 0 standing
/// above a panel that had just said the count is coming back.
enum AudioRoomLivePhase {
  /// This device holds no call at all: the lobby, before or after one.
  idle,

  /// A first connection that has not been established yet.
  connecting,

  /// This device is in the call and hears it.
  connected,

  /// The connection dropped and it is being put back without anyone asking.
  reconnecting,

  /// The call stopped for this device and nothing is retrying it.
  disconnected,
}

/// The one sentence about the people in a call this device cannot hear.
///
/// It is the line the call panel prints for the same phase, so a screen that
/// carries both never says two things about one room. A phase that can state
/// a count of its own gets nothing here.
String? audioRoomLivePhaseNote(AudioRoomLivePhase phase) => switch (phase) {
  AudioRoomLivePhase.reconnecting => '语音正在重连，人数以重新连接后为准',
  AudioRoomLivePhase.disconnected => '语音已断开，人数以重新连接后为准',
  AudioRoomLivePhase.idle ||
  AudioRoomLivePhase.connecting ||
  AudioRoomLivePhase.connected => null,
};

/// One reading of one call, taken from the provider's own call state.
///
/// The call view reads that state for itself, but it is the only thing that
/// can: a strip on another tab, and whoever keeps the call alive while no
/// view is mounted, have no widget to read it from. The call hands out the
/// same reading the panel prints, so nothing outside has to keep a second
/// account of what the connection is doing.
@immutable
final class AudioRoomCallReading {
  const AudioRoomCallReading({
    required this.phase,
    required this.participantCount,
  });

  final AudioRoomLivePhase phase;

  /// How many people the call counts, or null while it cannot count anyone.
  /// A connected reading is never 0; see [AudioRoomLivePresence].
  final int? participantCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioRoomCallReading &&
          other.phase == phase &&
          other.participantCount == participantCount;

  @override
  int get hashCode => Object.hash(phase, participantCount);
}

/// What this device's own provider call reports, while it holds one.
///
/// It is the only live count in the client: the room resource carries what
/// LOOP saw when it last looked, which is a different reading taken at a
/// different moment. Anything that wants "how many are in the call right now"
/// reads this, and states nothing when it is absent.
@immutable
final class AudioRoomLivePresence {
  const AudioRoomLivePresence({
    required this.roomId,
    required this.phase,
    required this.participantCount,
  });

  /// The provider room this reading belongs to. A reading never travels to
  /// another room.
  final String roomId;

  /// What this device's call is doing, in the shapes the surfaces outside it
  /// answer for.
  final AudioRoomLivePhase phase;

  /// Whether this device is in the call right now.
  bool get connected => phase == AudioRoomLivePhase.connected;

  /// How many people the call counts, or null while a connected call has not
  /// counted anyone yet. A connected reading is never 0: the SFU publishes its
  /// figure some seconds after the connection, and 「已连接」 beside 「0 人」 was
  /// read as an empty room.
  final int? participantCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioRoomLivePresence &&
          other.roomId == roomId &&
          other.phase == phase &&
          other.participantCount == participantCount;

  @override
  int get hashCode => Object.hash(roomId, phase, participantCount);
}

/// Publishes the live call reading to the surfaces outside the call view.
final class AudioRoomLivePresenceController
    extends Notifier<AudioRoomLivePresence?> {
  @override
  AudioRoomLivePresence? build() => null;

  void report(AudioRoomLivePresence presence) {
    if (state != presence) state = presence;
  }

  /// Withdraws the reading for one room. A reading another room published is
  /// left alone.
  void clear(String roomId) {
    if (state?.roomId == roomId) state = null;
  }
}

final audioRoomLivePresenceProvider =
    NotifierProvider<AudioRoomLivePresenceController, AudioRoomLivePresence?>(
      AudioRoomLivePresenceController.new,
    );
