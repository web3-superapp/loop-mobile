import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tells Android whether the system back on LOOP's root page may finish the
/// App (decision 0106).
///
/// A finished Activity takes the voice room with it. While this device holds
/// a voice call — or is putting a dropped one back — `MainActivity` answers
/// the back that Flutter has nothing left to pop with `moveTaskToBack`, the
/// same thing the home button does. Every other back is Flutter's as before.
abstract interface class VoiceRoomBackGuard {
  Future<void> setHoldsVoiceCall(bool holds);
}

/// The one channel `MainActivity` listens on. Mirrored there as
/// `VOICE_ROOM_BACK_CHANNEL`.
const voiceRoomBackChannelName = 'com.cywd.loop/voice_room_back';

final class MethodChannelVoiceRoomBackGuard implements VoiceRoomBackGuard {
  const MethodChannelVoiceRoomBackGuard();

  static const MethodChannel _channel = MethodChannel(voiceRoomBackChannelName);

  @override
  Future<void> setHoldsVoiceCall(bool holds) async {
    // iOS has no system back that ends the App; the background audio mode
    // already keeps the room.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setHoldsVoiceCall', holds);
    } on MissingPluginException {
      // A host without the native side (a widget test) has no Activity to
      // keep.
    } on PlatformException {
      // The back simply keeps its default behaviour.
    }
  }
}

final voiceRoomBackGuardProvider = Provider<VoiceRoomBackGuard>(
  (ref) => const MethodChannelVoiceRoomBackGuard(),
);
