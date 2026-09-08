import 'package:flutter/foundation.dart';

import 'package:loop_mobile/features/chat/v2/chat_merge_export.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the operating system's share sheet with one in-memory PNG.
///
/// The image is passed as bytes, so it never becomes a file the application
/// keeps, and it is never uploaded to a LOOP service. LOOP learns only whether
/// the sheet was used; it never learns the destination.
final class SystemChatMergeExportSink implements ChatMergeExportSink {
  const SystemChatMergeExportSink();

  @override
  Future<ChatMergeExportOutcome> shareImage({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    if (pngBytes.isEmpty) return ChatMergeExportOutcome.failed;
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
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
      return switch (result.status) {
        ShareResultStatus.success => ChatMergeExportOutcome.shared,
        ShareResultStatus.dismissed => ChatMergeExportOutcome.dismissed,
        ShareResultStatus.unavailable => ChatMergeExportOutcome.unavailable,
      };
    } catch (_) {
      // A platform failure is not a partial success: nothing was shared.
      return ChatMergeExportOutcome.failed;
    }
  }
}
