import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';

/// Explicit in-memory implementation for deterministic Preview or tests.
///
/// It is intentionally not composed by the production provider.
final class MemoryProfileGateway implements ProfileGateway {
  MemoryProfileGateway({
    ProfileResource? initialResource,
    DateTime Function()? clock,
  }) : _resource = ProfileResource.copyOf(
         initialResource ?? ProfileResource.empty(),
       ),
       _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  ProfileResource _resource;

  @override
  ProfileMode get mode => ProfileMode.preview;

  @override
  Future<ProfileResource> load() async {
    return ProfileResource.copyOf(_resource);
  }

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) async {
    late final ProfileValues candidate;
    try {
      if (expectedVersion < 0 || expectedVersion > profileMaximumVersion) {
        throw const InvalidProfileContractException();
      }
      candidate = ProfileValues.copyOf(values);
    } on InvalidProfileContractException {
      throw const ProfileGatewayException(
        ProfileGatewayFailureKind.invalidData,
      );
    }

    // A missing backend row is represented as version zero. Unlike an
    // existing row, expectedVersion zero always creates version one, even if
    // the submitted values are still the defaults.
    if (_resource.version == 0) {
      if (expectedVersion == 0) {
        _resource = ProfileResource(
          version: 1,
          values: candidate,
          updatedAt: _clock().toUtc(),
        );
        return ProfileResource.copyOf(_resource);
      }
      if (candidate == _resource.values) {
        return ProfileResource.copyOf(_resource);
      }
      throw const ProfileGatewayException(
        ProfileGatewayFailureKind.versionConflict,
      );
    }

    // Existing resources compare normalized values before their optimistic
    // version, making an identical already-applied retry deterministic.
    if (candidate == _resource.values) {
      return ProfileResource.copyOf(_resource);
    }
    if (expectedVersion != _resource.version) {
      throw const ProfileGatewayException(
        ProfileGatewayFailureKind.versionConflict,
      );
    }
    if (_resource.version == profileMaximumVersion) {
      throw const ProfileGatewayException(
        ProfileGatewayFailureKind.unavailable,
      );
    }

    _resource = ProfileResource(
      version: _resource.version + 1,
      values: candidate,
      updatedAt: _clock().toUtc(),
    );
    return ProfileResource.copyOf(_resource);
  }
}
