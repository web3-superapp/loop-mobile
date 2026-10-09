import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands one in-memory PNG, with an optional caption, to the operating
/// system's share sheet (decision 0130, audit 2026-10-09 m12).
///
/// The bytes are never written to a location LOOP keeps and never uploaded.
/// Returns false when the sheet could not be shown; LOOP learns nothing about
/// where the picture went.
typedef LoopImageShare = Future<bool> Function({
  required Uint8List pngBytes,
  required String fileName,
  String? text,
  String? subject,
});

final loopImageShareProvider = Provider<LoopImageShare>(
  (ref) => ({required pngBytes, required fileName, text, subject}) async {
    if (pngBytes.isEmpty) return false;
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          files: <XFile>[
            XFile.fromData(
              pngBytes,
              mimeType: 'image/png',
              name: fileName,
              length: pngBytes.length,
            ),
          ],
          fileNameOverrides: <String>[fileName],
        ),
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  },
);
