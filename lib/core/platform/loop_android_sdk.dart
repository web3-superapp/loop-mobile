import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The one channel `MainActivity` answers platform facts on. Mirrored there
/// as `PLATFORM_CHANNEL`.
const loopPlatformChannelName = 'com.cywd.loop/platform';

/// The Android API level of this device, or `null` anywhere else.
///
/// Read once per run over [loopPlatformChannelName] and kept: the level
/// cannot change while the App is running. A host with no native side — a
/// widget test, iOS — answers `null`, which every caller treats as "not a
/// device that draws its own clipboard confirmation".
abstract final class LoopAndroidSdk {
  static const MethodChannel _channel = MethodChannel(loopPlatformChannelName);
  static Future<int?>? _level;

  /// Android 13 (API 33) draws its own confirmation whenever an App writes
  /// to the clipboard.
  static const int systemClipboardConfirmation = 33;

  static Future<int?> level() => _level ??= _read().then((level) {
    _known = level;
    return level;
  });

  static int? _known;

  /// The level if it has already been read, else `null`. Synchronous, so a
  /// caller can decide in the same frame as the tap.
  static int? get knownLevel => _known;

  /// Whether this device is already known to confirm clipboard writes
  /// itself. `false` until [level] has answered.
  static bool get knownToConfirmClipboardWrites {
    final level = _known;
    return level != null && level >= systemClipboardConfirmation;
  }

  static Future<int?> _read() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMethod<int>('sdkInt');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Pins the answer for a test; `null` forgets it so the next read asks the
  /// channel again.
  @visibleForTesting
  static set debugLevel(int? level) {
    _known = level;
    _level = level == null ? null : Future<int?>.value(level);
  }
}
