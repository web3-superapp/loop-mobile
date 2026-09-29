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

/// Something happened in this room that LOOP's own record has to be read for.
///
/// The provider tells a connected device the moment the room changes; LOOP
/// owns what the change means — who the person is, where they are in the
/// queue, what the host may do about them. So a signal is never state: it is
/// the cue to read the LOOP resource that holds the answer. On the review
/// devices nothing carried that cue at all, and a host sat looking at 「1 人在
/// 房间里」 with a listener in the room and a raised hand nobody was told about.
enum AudioRoomRoomSignal {
  /// Somebody raised or cancelled a hand (decision 0069). The queue itself is
  /// read from LOOP; the event carries no identity on purpose, so that an
  /// anonymous member cannot be matched to a participant tile.
  handRaise,

  /// The people in the room changed: a device joined or left the call, or the
  /// provider's member list was written.
  participants,
}

/// One person this device can hear in the call right now.
///
/// It is the provider's account of the moment, and it is the only one there
/// is: LOOP's speaker roster is a record of the parts it granted, it does not
/// include the host at all (decision 0052), and the 「正在发言」 grid built from
/// it was empty on the review device while the host was talking. A tile here
/// exists because a microphone is open, which is the question the grid asks.
@immutable
final class AudioRoomSpeaker {
  const AudioRoomSpeaker({
    required this.key,
    required this.name,
    required this.isLocal,
    required this.isSpeaking,
  });

  /// Tells two tiles apart within one reading. It is never rendered and it is
  /// never matched against a LOOP identifier.
  final String key;

  /// What the provider carries for this person, or the one word left when it
  /// carries none.
  final String name;

  final bool isLocal;

  /// Whether this person is speaking at this moment, as the provider hears
  /// it. A microphone that is open and quiet is not speaking.
  final bool isSpeaking;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioRoomSpeaker &&
          other.key == key &&
          other.name == name &&
          other.isLocal == isLocal &&
          other.isSpeaking == isSpeaking;

  @override
  int get hashCode => Object.hash(key, name, isLocal, isSpeaking);
}

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
    this.speakers = const <AudioRoomSpeaker>[],
  });

  final AudioRoomLivePhase phase;

  /// How many people the call counts, or null while it cannot count anyone.
  /// A connected reading is never 0; see [AudioRoomLivePresence].
  final int? participantCount;

  /// Who has a microphone open in the call, as the provider reports it. It is
  /// empty for a call this device is not connected to: there is nothing to
  /// hear, and the list this device still holds describes a moment that has
  /// passed.
  final List<AudioRoomSpeaker> speakers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioRoomCallReading &&
          other.phase == phase &&
          other.participantCount == participantCount &&
          listEquals(other.speakers, speakers);

  @override
  int get hashCode =>
      Object.hash(phase, participantCount, Object.hashAll(speakers));
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
    this.speakers = const <AudioRoomSpeaker>[],
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

  /// Who has a microphone open in this call right now. See
  /// [AudioRoomCallReading.speakers].
  final List<AudioRoomSpeaker> speakers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioRoomLivePresence &&
          other.roomId == roomId &&
          other.phase == phase &&
          other.participantCount == participantCount &&
          listEquals(other.speakers, speakers);

  @override
  int get hashCode =>
      Object.hash(roomId, phase, participantCount, Object.hashAll(speakers));
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

/// Which built-in route the reader chose for the room's audio (decision 0106).
///
/// 「有时候听筒有时候扬声器」 was the SDK choosing for the reader: the dashboard
/// default picked one device at join, and opening the microphone put iOS's
/// voice-chat session back on the receiver. The reader now picks, and the
/// pick is put back after every event that can move the route. A connected
/// headset or Bluetooth device is not a third choice: while one is present the
/// audio goes there, and the control says so.
enum AudioRoomOutputPreference { speaker, earpiece }

/// What kind of device the call's audio is actually routed to, as the
/// provider reads it back.
enum AudioRoomOutputKind { speaker, earpiece, external }

/// One reading of the current audio route. It is never composed from the
/// reader's own choice: [AudioRoomOutputPreference] says what was asked for,
/// this says where the sound went.
@immutable
final class AudioRoomOutputRoute {
  const AudioRoomOutputRoute(this.kind, {this.label});

  final AudioRoomOutputKind kind;

  /// The device's own name, for an external device. The built-in routes are
  /// named by LOOP, not by the platform.
  final String? label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioRoomOutputRoute &&
          other.kind == kind &&
          other.label == label;

  @override
  int get hashCode => Object.hash(kind, label);
}

/// The word the room's output control prints for the route it read back.
///
/// A route the provider has not reported yet is not guessed from the
/// preference: the control says it is still reading.
String audioRoomOutputLabel(AudioRoomOutputRoute? route) {
  if (route == null) return '声音输出';
  return switch (route.kind) {
    AudioRoomOutputKind.speaker => '扬声器',
    AudioRoomOutputKind.earpiece => '听筒',
    AudioRoomOutputKind.external => _externalOutputLabel(route.label),
  };
}

String _externalOutputLabel(String? label) {
  final name = label?.trim();
  if (name == null || name.isEmpty) return '耳机';
  return name.length > 12 ? '${name.substring(0, 12)}…' : name;
}

/// The reader's choice of output, for as long as this App process runs.
///
/// It is deliberately not persisted (decision 0106): the route is a property
/// of the room the reader is in right now, and a choice made for one
/// conversation is not a device setting.
final class AudioRoomOutputPreferenceController
    extends Notifier<AudioRoomOutputPreference> {
  @override
  AudioRoomOutputPreference build() => AudioRoomOutputPreference.speaker;

  void choose(AudioRoomOutputPreference preference) {
    if (state != preference) state = preference;
  }
}

final audioRoomOutputPreferenceProvider =
    NotifierProvider<
      AudioRoomOutputPreferenceController,
      AudioRoomOutputPreference
    >(AudioRoomOutputPreferenceController.new);

/// Where an automatic reconnection of one room stands (decision 0106).
enum AudioRoomRecoveryPhase {
  /// The provider gave up on the call and this device is putting a new one
  /// back without anyone asking. Nothing about the membership changed.
  reconnecting,

  /// A new call is in, after a recovery. It is kept only to say one thing: a
  /// microphone that was open before the drop is closed now.
  restored,
}

/// This device's own account of putting a dropped room back.
///
/// The provider's own reconnection is the call's business and shows as the
/// call's 「重连中」. This is the step after it: the provider stopped retrying,
/// and the device joins the same room again with a call of its own, backing
/// off between attempts until the reader leaves, the room ends or the account
/// is no longer in it.
@immutable
final class AudioRoomRecovery {
  const AudioRoomRecovery({
    required this.roomId,
    required this.phase,
    required this.attempt,
    required this.microphoneWasOpen,
  });

  final String roomId;
  final AudioRoomRecoveryPhase phase;

  /// How many new calls have been tried so far. 0 while the first one is
  /// still being waited for.
  final int attempt;

  /// Whether this device's microphone was open when the call dropped. A new
  /// call always enters muted; this is what the room tells the reader about.
  final bool microphoneWasOpen;

  bool get reconnecting => phase == AudioRoomRecoveryPhase.reconnecting;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioRoomRecovery &&
          other.roomId == roomId &&
          other.phase == phase &&
          other.attempt == attempt &&
          other.microphoneWasOpen == microphoneWasOpen;

  @override
  int get hashCode => Object.hash(roomId, phase, attempt, microphoneWasOpen);
}

/// How long the device waits before its [attempt]-th new call.
///
/// 1 s, 2 s, 4 s … and never more than 30 s. The first wait is not zero: the
/// provider has just given up, and the network it gave up on is usually the
/// same one a moment later.
Duration audioRoomRecoveryDelay(int attempt) {
  const ceiling = Duration(seconds: 30);
  if (attempt <= 0) return const Duration(seconds: 1);
  if (attempt >= 5) return ceiling;
  final seconds = 1 << attempt;
  return seconds >= ceiling.inSeconds ? ceiling : Duration(seconds: seconds);
}

/// The line the room prints after a recovery put a speaker back in muted.
const audioRoomRestoredMicrophoneNote = '已重新连接，点麦克风继续发言';

/// Publishes the recovery the active call holder is running.
final class AudioRoomRecoveryController extends Notifier<AudioRoomRecovery?> {
  @override
  AudioRoomRecovery? build() => null;

  void report(AudioRoomRecovery? recovery) {
    if (state != recovery) state = recovery;
  }
}

final audioRoomRecoveryProvider =
    NotifierProvider<AudioRoomRecoveryController, AudioRoomRecovery?>(
      AudioRoomRecoveryController.new,
    );

/// What the system's ongoing-call notification says and does (Android).
///
/// The notification belongs to the provider's own foreground service, which
/// is started and stopped with the call; this is only the words on it and the
/// two things it can ask of LOOP. The shell's voice strip fills the actions in,
/// because it is the one place that knows how to open the room and how to
/// leave it.
final class AudioRoomNotificationBridge {
  String title = '正在语音房';
  String? text = '点按回到语音房';

  /// Opens the room page for the room this device is in.
  Future<void> Function()? onOpen;

  /// The notification's 离开.
  Future<void> Function()? onLeave;

  Future<void> open() async {
    final open = onOpen;
    if (open != null) await open();
  }

  Future<void> leave() async {
    final leave = onLeave;
    if (leave != null) await leave();
  }
}

final audioRoomNotificationBridgeProvider =
    Provider<AudioRoomNotificationBridge>(
      (ref) => AudioRoomNotificationBridge(),
    );

/// The notification's title for the room this device is in.
String audioRoomNotificationTitle(String? communityName) {
  final name = communityName?.trim();
  if (name == null || name.isEmpty) return '正在语音房';
  return '正在语音房 · $name';
}
