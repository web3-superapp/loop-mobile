import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loop_mobile/core/platform/loop_android_sdk.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_gateway.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';

/// The photo library and the camera for 意见反馈 (S332 · decision 0262),
/// through `image_picker`.
///
/// Pictures are scaled by the platform to at most 2048 px on the long edge
/// and re-encoded, so a screenshot stays under the upload limit; only the
/// bytes leave this adapter — no path, no metadata of the original file.
final class ImagePickerBetaFeedbackSource implements BetaFeedbackImagePicker {
  ImagePickerBetaFeedbackSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const double _maximumSide = 2048;
  static const int _quality = 85;

  @override
  Future<List<BetaFeedbackPickedImage>> pickFromLibrary({
    required int limit,
  }) async {
    if (limit <= 0) return const <BetaFeedbackPickedImage>[];
    final List<XFile> files;
    try {
      files = limit == 1
          ? <XFile>[
              ?await _picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: _maximumSide,
                maxHeight: _maximumSide,
                imageQuality: _quality,
                requestFullMetadata: false,
              ),
            ]
          : await _picker.pickMultiImage(
              maxWidth: _maximumSide,
              maxHeight: _maximumSide,
              imageQuality: _quality,
              limit: limit,
              requestFullMetadata: false,
            );
    } on PlatformException catch (error) {
      throw _pickFailure(error);
    }
    final picked = <BetaFeedbackPickedImage>[];
    for (final file in files.take(limit)) {
      final image = await _read(file);
      if (image != null) picked.add(image);
    }
    return picked;
  }

  @override
  Future<BetaFeedbackPickedImage?> takePhoto() async {
    if (!_picker.supportsImageSource(ImageSource.camera)) {
      throw const BetaFeedbackPickException(
        BetaFeedbackPickFailure.unavailable,
      );
    }
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maximumSide,
        maxHeight: _maximumSide,
        imageQuality: _quality,
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      throw _pickFailure(error);
    }
    if (file == null) return null;
    return _read(file);
  }

  static BetaFeedbackPickException _pickFailure(PlatformException error) {
    final code = error.code.toLowerCase();
    return BetaFeedbackPickException(
      code.contains('denied') || code.contains('access')
          ? BetaFeedbackPickFailure.permissionDenied
          : BetaFeedbackPickFailure.unavailable,
    );
  }

  static Future<BetaFeedbackPickedImage?> _read(XFile file) async {
    final bytes = await file.readAsBytes();
    final contentType = betaFeedbackSniffContentType(bytes);
    if (contentType == null) return null;
    return BetaFeedbackPickedImage(bytes: bytes, contentType: contentType);
  }
}

/// The build and the device, from the platform channel `MainActivity` and
/// `AppDelegate` answer `appInfo` on ([loopPlatformChannelName]): the
/// version and build the binary was built with, the model and the system
/// version. A host with no native side falls back to what Dart can read.
final class PlatformBetaFeedbackEnvironmentSource
    implements BetaFeedbackEnvironmentSource {
  const PlatformBetaFeedbackEnvironmentSource({
    this.fallbackAppVersion = '',
    this._channel = const MethodChannel(loopPlatformChannelName),
  });

  /// `LOOP_CLIENT_VERSION`, used only when the platform does not answer.
  final String fallbackAppVersion;
  final MethodChannel _channel;

  @override
  Future<BetaFeedbackEnvironment> read() async {
    var platform = '';
    var osVersion = '';
    if (!kIsWeb) {
      try {
        platform = Platform.operatingSystem;
        osVersion = Platform.operatingSystemVersion;
      } catch (_) {}
    }
    Map<Object?, Object?>? info;
    try {
      info = await _channel.invokeMethod<Map<Object?, Object?>>('appInfo');
    } on MissingPluginException {
      info = null;
    } on PlatformException {
      info = null;
    }
    String field(String key) {
      final value = info?[key];
      return value is String ? value.trim() : '';
    }

    final nativeOs = field('osVersion');
    return BetaFeedbackEnvironment(
      appVersion: field('appVersion').isEmpty
          ? fallbackAppVersion
          : field('appVersion'),
      build: field('build'),
      platform: platform,
      osVersion: nativeOs.isEmpty ? osVersion : nativeOs,
      deviceModel: field('deviceModel'),
    );
  }
}
