import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';

/// Local selection only. No URL, upload claim or forged avatar reference.
abstract interface class AvatarImagePicker {
  Future<Uint8List?> pick();
}

final avatarImagePickerProvider = Provider<AvatarImagePicker?>((ref) => null);
const avatarImageMaxBytes = 5 * 1024 * 1024;

/// Decode a bounded thumbnail without upscaling narrow or small images.
({int width, int height}) avatarDecodeDimensions(int width, int height) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Invalid image dimensions');
  }
  final longest = math.max(width, height);
  if (longest <= 256) return (width: width, height: height);
  return (
    width: math.max(1, width * 256 ~/ longest),
    height: math.max(1, height * 256 ~/ longest),
  );
}

/// Web's ImageDescriptor does not expose width/height. Validate by decoding
/// a bounded first frame through the supported codec API instead.
Future<void> validateAvatarWebImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 256,
    targetHeight: 256,
    allowUpscaling: false,
  );
  try {
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  } finally {
    codec.dispose();
  }
}

class AvatarUploadState {
  const AvatarUploadState({this.bytes, this.picking = false, this.message});
  final Uint8List? bytes;
  final bool picking;
  final String? message;
}

final avatarUploadControllerProvider =
    NotifierProvider<AvatarUploadController, AvatarUploadState>(
      AvatarUploadController.new,
    );

class AvatarUploadController extends Notifier<AvatarUploadState> {
  int _generation = 0;
  @override
  AvatarUploadState build() {
    // Production has no image adapter and no local bytes. Reading an avatar
    // alone must not start authentication restoration as a side effect.
    if (ref.watch(avatarImagePickerProvider) != null) {
      ref.watch(
        loopSessionProvider.select(
          (session) => (session.mode, session.account?.privyUserId),
        ),
      );
    }
    _generation++;
    return const AvatarUploadState();
  }

  Future<void> pick() async {
    if (state.picking) return;
    final picker = ref.read(avatarImagePickerProvider);
    if (picker == null || !ref.read(loopSessionProvider).isPreview) {
      state = AvatarUploadState(
        bytes: state.bytes,
        message: '头像上传暂不可用，可以先设置用户名。',
      );
      return;
    }
    final previous = state.bytes;
    final generation = _generation;
    state = AvatarUploadState(bytes: previous, picking: true);
    try {
      final bytes = await picker.pick();
      if (!ref.mounted || generation != _generation) return;
      if (bytes == null) {
        state = AvatarUploadState(bytes: previous);
        return;
      }
      if (bytes.isEmpty || bytes.length > avatarImageMaxBytes) {
        state = AvatarUploadState(bytes: previous, message: '请选择 5 MB 以内的图片。');
        return;
      }
      if (kIsWeb) {
        await validateAvatarWebImage(bytes);
      } else {
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        try {
          final descriptor = await ui.ImageDescriptor.encoded(buffer);
          try {
            if (descriptor.width > 8192 || descriptor.height > 8192) {
              throw const FormatException('image dimensions');
            }
            final target = avatarDecodeDimensions(
              descriptor.width,
              descriptor.height,
            );
            final codec = await descriptor.instantiateCodec(
              targetWidth: target.width,
              targetHeight: target.height,
            );
            try {
              final frame = await codec.getNextFrame();
              frame.image.dispose();
            } finally {
              codec.dispose();
            }
          } finally {
            descriptor.dispose();
          }
        } finally {
          buffer.dispose();
        }
      }
      if (!ref.mounted || generation != _generation) return;
      state = AvatarUploadState(
        bytes: Uint8List.fromList(bytes),
        message: '图片仅用于本次预览，尚未上传。',
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      state = AvatarUploadState(bytes: previous, message: '未能读取图片，请选择其他图片。');
    }
  }
}
