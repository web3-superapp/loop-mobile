import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/scan/loop_qr_scanner.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The device QR scanner, through `mobile_scanner` 7 (decision 0113).
///
/// Only QR symbols are decoded. The live camera is the plugin's own preview;
/// a picture from the photo library is picked with `image_picker` (already a
/// direct dependency, decision 0112) and decoded on device by the same
/// plugin. Nothing — no frame, no picture, no payload — leaves the device
/// here; the page decides what a payload means.
final class MobileScannerQrScanner implements LoopQrScanner {
  MobileScannerQrScanner({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  bool get available => true;

  @override
  LoopQrCameraSession openCamera() => _MobileScannerSession();

  @override
  Future<LoopQrImageScan> scanImage() async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      return error.code == 'photo_access_denied'
          ? const LoopQrImagePermissionDenied()
          : const LoopQrImageFailed();
    } catch (_) {
      return const LoopQrImageFailed();
    }
    if (file == null) return const LoopQrImageCancelled();
    // `analyzeImage` goes straight to the platform; it needs no running
    // camera, so a controller that never starts is enough to ask.
    final controller = MobileScannerController(
      autoStart: false,
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    );
    try {
      final capture = await controller.analyzeImage(
        file.path,
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
      final text = capture?.barcodes
          .map((barcode) => barcode.rawValue)
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .firstOrNull;
      return text == null ? const LoopQrImageNoCode() : LoopQrImageFound(text);
    } catch (_) {
      return const LoopQrImageFailed();
    } finally {
      unawaited(controller.dispose());
    }
  }
}

final class _MobileScannerSession implements LoopQrCameraSession {
  _MobileScannerSession()
    : _controller = MobileScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      ) {
    _controller.addListener(_sync);
  }

  final MobileScannerController _controller;
  final ValueNotifier<LoopQrCameraState> _state =
      ValueNotifier<LoopQrCameraState>(const LoopQrCameraState());

  void _sync() {
    final value = _controller.value;
    final error = value.error;
    final status = error != null
        ? switch (error.errorCode) {
            MobileScannerErrorCode.permissionDenied =>
              LoopQrCameraStatus.permissionDenied,
            MobileScannerErrorCode.unsupported =>
              LoopQrCameraStatus.unsupported,
            _ => LoopQrCameraStatus.failed,
          }
        : value.isRunning
        ? LoopQrCameraStatus.running
        : LoopQrCameraStatus.starting;
    final torch = switch (value.torchState) {
      TorchState.on => LoopQrTorch.on,
      TorchState.off || TorchState.auto => LoopQrTorch.off,
      TorchState.unavailable => LoopQrTorch.unavailable,
    };
    _state.value = LoopQrCameraState(status: status, torch: torch);
  }

  @override
  ValueListenable<LoopQrCameraState> get state => _state;

  @override
  Stream<String> get codes => _controller.barcodes
      .expand((capture) => capture.barcodes)
      .map((barcode) => barcode.rawValue)
      .where((value) => value != null && value.isNotEmpty)
      .cast<String>();

  @override
  Widget buildPreview(BuildContext context) => MobileScanner(
    controller: _controller,
    // The page draws every state in its own words; the plugin's own error
    // icon and placeholder would be a second, English-free but unexplained
    // version of the same fact.
    errorBuilder: (context, error) => const ColoredBox(color: LoopColors.ink),
    placeholderBuilder: (context) => const ColoredBox(color: LoopColors.ink),
  );

  @override
  Future<void> toggleTorch() => _controller.toggleTorch();

  @override
  Future<void> retry() => _controller.start();

  @override
  Future<void> dispose() async {
    _controller.removeListener(_sync);
    _state.dispose();
    await _controller.dispose();
  }
}
