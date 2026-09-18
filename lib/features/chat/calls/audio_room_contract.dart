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
enum AudioRoomViewerRole { listener, speaker, host }

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
    required this.connected,
    required this.participantCount,
  });

  /// The provider room this reading belongs to. A reading never travels to
  /// another room.
  final String roomId;

  /// Whether this device is in the call right now.
  final bool connected;

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
          other.connected == connected &&
          other.participantCount == participantCount;

  @override
  int get hashCode => Object.hash(roomId, connected, participantCount);
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
