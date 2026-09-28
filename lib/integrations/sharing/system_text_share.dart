import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands plain text to the operating system's share sheet.
///
/// Returns false when the sheet could not be shown. LOOP learns nothing about
/// where the text went, and nothing is sent to a LOOP service.
typedef LoopTextShare = Future<bool> Function(String text, {String? subject});

final loopTextShareProvider = Provider<LoopTextShare>(
  (ref) => (text, {subject}) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  },
);
