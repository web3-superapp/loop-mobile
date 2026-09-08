import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The result of one merged-image export.
enum ChatMergeExportOutcome {
  /// The system share sheet was opened with the encoded image.
  shared,

  /// The viewer dismissed the sheet without choosing a destination.
  dismissed,

  /// Encoding or the platform share failed. Nothing left the device.
  failed,

  /// No share adapter is composed, so nothing was rendered or encoded.
  unavailable,
}

/// Hands one already-encoded PNG to the operating system's share sheet.
///
/// The bytes come from the anonymous preview the viewer can see, are never
/// uploaded to a LOOP service, and are not written to a location the app keeps.
/// The port exists so `lib/features/` never depends on a platform plugin
/// directly and a test can observe exactly what would have been shared.
abstract interface class ChatMergeExportSink {
  Future<ChatMergeExportOutcome> shareImage({
    required Uint8List pngBytes,
    required String fileName,
  });
}

/// Production-safe default until the composition root supplies an adapter.
final class UnavailableChatMergeExportSink implements ChatMergeExportSink {
  const UnavailableChatMergeExportSink();

  @override
  Future<ChatMergeExportOutcome> shareImage({
    required Uint8List pngBytes,
    required String fileName,
  }) async => ChatMergeExportOutcome.unavailable;
}

/// Overridden by `main.dart` and `main_preview.dart` with the system adapter.
final chatMergeExportSinkProvider = Provider<ChatMergeExportSink>(
  (ref) => const UnavailableChatMergeExportSink(),
);

/// zh-CN copy for one export outcome. It states only what happened.
String chatMergeExportMessage(ChatMergeExportOutcome outcome) =>
    switch (outcome) {
      ChatMergeExportOutcome.shared => '长图已生成，请在分享面板中选择去处',
      ChatMergeExportOutcome.dismissed => '已生成长图，但没有选择分享去处',
      ChatMergeExportOutcome.failed => '长图没有生成成功，没有任何内容离开这台设备',
      ChatMergeExportOutcome.unavailable => '本次运行没有装配系统分享，长图未生成',
    };
