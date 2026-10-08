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
        // The page starts the camera itself, once, after the preview is on
        // screen; the plugin's own auto-start would race the page's retry
        // and fail it with `controllerInitializing`.
        autoStart: false,
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      ) {
    _controller.addListener(_sync);
  }

  final MobileScannerController _controller;
  final LoopQrStartGate _starts = LoopQrStartGate();
  final ValueNotifier<LoopQrCameraState> _state =
      ValueNotifier<LoopQrCameraState>(const LoopQrCameraState());
  bool _disposed = false;

  /// A start that failed before the controller could record why (it was not
  /// attached yet, or was disposed meanwhile).
  LoopQrCameraStatus? _startFailure;

  void _sync() {
    if (_disposed) return;
    final value = _controller.value;
    final error = value.error;
    final status = value.isRunning
        ? LoopQrCameraStatus.running
        : error != null
        ? switch (error.errorCode) {
            MobileScannerErrorCode.permissionDenied =>
              LoopQrCameraStatus.permissionDenied,
            MobileScannerErrorCode.unsupported =>
              LoopQrCameraStatus.unsupported,
            _ => LoopQrCameraStatus.failed,
          }
        : _startFailure ?? LoopQrCameraStatus.starting;
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
    // The page owns the lifecycle (an external controller gets no observer
    // from the plugin) and draws every state in its own words.
    useAppLifecycleState: false,
    errorBuilder: (context, error) => const ColoredBox(color: LoopColors.ink),
    placeholderBuilder: (context) => const ColoredBox(color: LoopColors.ink),
  );

  @override
  Future<void> start() => _starts.run(() async {
    if (_disposed) return;
    final value = _controller.value;
    if (value.isRunning || value.isStarting) return;
    _startFailure = null;
    try {
      // A refusal the platform reports (permission, no camera) is recorded
      // on the controller's value and read by `_sync`; only a failure
      // before that point lands here.
      await _controller.start();
    } on MobileScannerException catch (error) {
      if (error.errorCode == MobileScannerErrorCode.controllerInitializing ||
          error.errorCode == MobileScannerErrorCode.controllerDisposed) {
        return;
      }
      _startFailure = LoopQrCameraStatus.failed;
    } catch (_) {
      _startFailure = LoopQrCameraStatus.failed;
    }
    _sync();
  });

  @override
  Future<void> pause() async {
    if (_disposed || !_controller.value.hasCameraPermission) return;
    try {
      await _controller.stop();
    } catch (_) {
      // Already stopped: nothing to release.
    }
  }

  @override
  Future<void> resume() async {
    if (_disposed) return;
    final value = _controller.value;
    // A camera the system refused is asked once more: the reader may be
    // back from the settings page with the permission granted.
    if (value.hasCameraPermission ||
        _state.value.status == LoopQrCameraStatus.permissionDenied) {
      await start();
    }
  }

  @override
  Future<void> toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      // A torch that cannot switch keeps the state the camera reports.
    }
  }

  @override
  Future<void> retry() => start();

  @override
  Future<void> dispose() async {
    _disposed = true;
    _controller.removeListener(_sync);
    _state.dispose();
    await _controller.dispose();
  }
}
