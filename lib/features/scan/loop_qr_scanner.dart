import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the live camera stands (decision 0113).
enum LoopQrCameraStatus {
  /// The camera is being opened; nothing has been decoded yet.
  starting,

  /// Frames are arriving and being decoded.
  running,

  /// The system refused the camera. Only a settings change will fix it.
  permissionDenied,

  /// This device has no camera LOOP can use.
  unsupported,

  /// The camera was granted and still did not start.
  failed,
}

/// The torch as the camera reports it. `unavailable` is a device without one.
enum LoopQrTorch { unavailable, off, on }

@immutable
final class LoopQrCameraState {
  const LoopQrCameraState({
    this.status = LoopQrCameraStatus.starting,
    this.torch = LoopQrTorch.unavailable,
  });

  final LoopQrCameraStatus status;
  final LoopQrTorch torch;

  @override
  bool operator ==(Object other) =>
      other is LoopQrCameraState &&
      other.status == status &&
      other.torch == torch;

  @override
  int get hashCode => Object.hash(status, torch);
}

/// One open camera. The page owns it and disposes it when it leaves.
abstract interface class LoopQrCameraSession {
  ValueListenable<LoopQrCameraState> get state;

  /// Every decoded QR payload, as raw text. Nothing is interpreted here.
  Stream<String> get codes;

  /// The live preview, sized by its parent.
  Widget buildPreview(BuildContext context);

  Future<void> toggleTorch();

  /// Asks the camera to start again after a failure.
  Future<void> retry();

  Future<void> dispose();
}

/// The outcome of decoding one picture from the photo library.
sealed class LoopQrImageScan {
  const LoopQrImageScan();
}

final class LoopQrImageFound extends LoopQrImageScan {
  const LoopQrImageFound(this.text);

  final String text;
}

/// A picture was read and carries no QR symbol.
final class LoopQrImageNoCode extends LoopQrImageScan {
  const LoopQrImageNoCode();
}

/// The reader backed out of the photo library.
final class LoopQrImageCancelled extends LoopQrImageScan {
  const LoopQrImageCancelled();
}

/// The system refused the photo library.
final class LoopQrImagePermissionDenied extends LoopQrImageScan {
  const LoopQrImagePermissionDenied();
}

/// The picture could not be opened or decoded.
final class LoopQrImageFailed extends LoopQrImageScan {
  const LoopQrImageFailed();
}

/// Feature-facing port for the device QR scanner.
///
/// `lib/features/` never imports the camera plugin: `main.dart` and
/// `main_preview.dart` compose the `mobile_scanner` adapter, and a test
/// composes a fake that decodes whatever it is told to.
abstract interface class LoopQrScanner {
  /// False when this build composed no camera adapter. The page then states
  /// that scanning is unavailable rather than opening anything.
  bool get available;

  LoopQrCameraSession openCamera();

  /// Lets the reader pick one picture and decodes the first QR symbol in it.
  Future<LoopQrImageScan> scanImage();
}

/// The default until a composition root supplies the device adapter.
final class UnavailableLoopQrScanner implements LoopQrScanner {
  const UnavailableLoopQrScanner();

  @override
  bool get available => false;

  @override
  LoopQrCameraSession openCamera() =>
      throw StateError('No QR scanner is composed in this build');

  @override
  Future<LoopQrImageScan> scanImage() async => const LoopQrImageFailed();
}

final loopQrScannerProvider = Provider<LoopQrScanner>(
  (ref) => const UnavailableLoopQrScanner(),
);
