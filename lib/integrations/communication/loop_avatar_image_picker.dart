import 'dart:typed_data';

import 'package:loop_mobile/features/profile/presentation/avatar_upload.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'package:loop_mobile/integrations/communication/loop_avatar_web_picker_stub.dart'
    if (dart.library.js_interop) 'package:loop_mobile/integrations/communication/loop_avatar_web_picker.dart'
    as browser;

/// Reuses the installed platform gallery handler; never invokes Stream upload.
class LoopAvatarImagePicker implements AvatarImagePicker {
  const LoopAvatarImagePicker();
  @override
  Future<Uint8List?> pick() async {
    if (browser.avatarWebPickerAvailable) {
      return browser.pickAvatarWebImage(avatarImageMaxBytes);
    }
    final attachment = await StreamAttachmentHandler.instance.pickImage(
      source: .gallery,
    );
    if (attachment == null) return null;
    final file = attachment.file;
    if (file == null) throw const FormatException('image file missing');
    if ((file.size ?? 0) > avatarImageMaxBytes) {
      return Uint8List(avatarImageMaxBytes + 1);
    }
    if (file.bytes case final bytes?) return bytes;
    final stream = (await file.toMultipartFile()).finalize();
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
      if (builder.length > avatarImageMaxBytes) {
        return Uint8List(avatarImageMaxBytes + 1);
      }
    }
    return builder.takeBytes();
  }
}
