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
