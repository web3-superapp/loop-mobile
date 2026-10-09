import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/platform/loop_android_sdk.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The one way LOOP puts text on the clipboard and says so (decision 0130).
///
/// It writes [text], plays [LoopHaptic.light], and shows [message] as a
/// [LoopToast] — except on Android 13 and later, where the system already
/// draws its own clipboard confirmation for every write. Two confirmations
/// stacked at the foot of the screen read as a glitch (audit 2026-10-09 m4),
/// and the system's is the one the owner cannot turn off, so LOOP's steps
/// aside.
///
/// Returns once the clipboard has been written.
abstract final class LoopCopy {
  static Future<void> text(
    BuildContext context,
    String text, {
    required String message,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    LoopHaptics.light();
    // Read synchronously: the level was fetched when the toast host mounted.
    if (LoopAndroidSdk.knownToConfirmClipboardWrites) return;
    if (!context.mounted) return;
    LoopToast.show(context, message: message, kind: LoopToastKind.ok);
  }
}
