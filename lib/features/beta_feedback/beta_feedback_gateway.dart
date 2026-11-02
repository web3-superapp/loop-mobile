import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

/// `beta-feedback` port (S332 · decision 0262): upload one picture, send one
/// piece of feedback, list the account's own.
abstract interface class BetaFeedbackGateway {
  LoopChainGatewayMode get mode;

  /// `POST /v2/media/feedback-images`.
  Future<BetaFeedbackUploadedImage> uploadImage(BetaFeedbackImage image);

  /// `POST /v2/feedback`, under one idempotency key per logical submission.
  Future<BetaFeedbackReceipt> submit(BetaFeedbackSubmission submission);

  /// `GET /v2/feedback/mine`.
  Future<BetaFeedbackPage> listMine({String? cursor});
}

final class UnavailableBetaFeedbackGateway implements BetaFeedbackGateway {
  const UnavailableBetaFeedbackGateway();

  static Future<T> _closed<T>() => Future<T>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<BetaFeedbackUploadedImage> uploadImage(BetaFeedbackImage image) =>
      _closed();

  @override
  Future<BetaFeedbackReceipt> submit(BetaFeedbackSubmission submission) =>
      _closed();

  @override
  Future<BetaFeedbackPage> listMine({String? cursor}) => _closed();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final betaFeedbackGatewayProvider = Provider<BetaFeedbackGateway>(
  (ref) => const UnavailableBetaFeedbackGateway(),
);

/// Why a picture could not be taken.
enum BetaFeedbackPickFailure {
  /// The system refused access to the library or the camera.
  permissionDenied,

  /// This build or device has no picker (a test, a simulator's camera).
  unavailable,
}

final class BetaFeedbackPickException implements Exception {
  const BetaFeedbackPickException(this.failure);

  final BetaFeedbackPickFailure failure;

  @override
  String toString() => 'beta_feedback_pick_${failure.name}';
}

/// The photo library and the camera.
abstract interface class BetaFeedbackImagePicker {
  /// Up to [limit] pictures from the library; empty when the person chose
  /// none.
  Future<List<BetaFeedbackPickedImage>> pickFromLibrary({required int limit});

  /// One photo from the camera, or `null` when the person cancelled.
  Future<BetaFeedbackPickedImage?> takePhoto();
}

final class UnavailableBetaFeedbackImagePicker
    implements BetaFeedbackImagePicker {
  const UnavailableBetaFeedbackImagePicker();

  @override
  Future<List<BetaFeedbackPickedImage>> pickFromLibrary({required int limit}) =>
      Future<List<BetaFeedbackPickedImage>>.error(
        const BetaFeedbackPickException(BetaFeedbackPickFailure.unavailable),
      );

  @override
  Future<BetaFeedbackPickedImage?> takePhoto() =>
      Future<BetaFeedbackPickedImage?>.error(
        const BetaFeedbackPickException(BetaFeedbackPickFailure.unavailable),
      );
}

final betaFeedbackImagePickerProvider = Provider<BetaFeedbackImagePicker>(
  (ref) => const UnavailableBetaFeedbackImagePicker(),
);

/// Reads this build's version and the device's facts.
abstract interface class BetaFeedbackEnvironmentSource {
  Future<BetaFeedbackEnvironment> read();
}

/// No reader: every fact is empty and the block says so. The composition
/// root replaces it with the device reader.
final class UnknownBetaFeedbackEnvironmentSource
    implements BetaFeedbackEnvironmentSource {
  const UnknownBetaFeedbackEnvironmentSource();

  @override
  Future<BetaFeedbackEnvironment> read() async => const BetaFeedbackEnvironment(
    appVersion: '',
    build: '',
    platform: '',
    osVersion: '',
    deviceModel: '',
  );
}

final betaFeedbackEnvironmentSourceProvider =
    Provider<BetaFeedbackEnvironmentSource>(
      (ref) => const UnknownBetaFeedbackEnvironmentSource(),
    );

/// The environment, read once per run.
final betaFeedbackEnvironmentProvider = FutureProvider<BetaFeedbackEnvironment>(
  (ref) => ref.watch(betaFeedbackEnvironmentSourceProvider).read(),
);
