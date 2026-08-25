import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';

/// Explicit in-memory implementation for deterministic Preview or tests.
///
/// It is intentionally not composed by the production provider.
final class MemoryPrivacyGateway implements PrivacyGateway {
  MemoryPrivacyGateway({
    PrivacyResource? initialResource,
    DateTime Function()? clock,
  }) : _resource = PrivacyResource.copyOf(
         initialResource ?? PrivacyResource.empty(),
       ),
       _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  PrivacyResource _resource;

  @override
  PrivacyMode get mode => PrivacyMode.preview;

  @override
  Future<PrivacyResource> load() async => PrivacyResource.copyOf(_resource);

  @override
  Future<PrivacyResource> replace({
    required int expectedVersion,
    required PrivacyValues values,
  }) async {
    if (expectedVersion < 0 || expectedVersion > privacyMaximumVersion) {
      throw const PrivacyGatewayException(
        PrivacyGatewayFailureKind.invalidData,
      );
    }
    final candidate = PrivacyValues.copyOf(values);

    // A missing row is version zero. Submitting expected version zero creates
    // version one even when the submitted values equal fail-closed defaults.
    if (_resource.version == 0) {
      if (expectedVersion == 0) {
        _resource = PrivacyResource(
          version: 1,
          values: candidate,
          updatedAt: _clock().toUtc(),
        );
        return PrivacyResource.copyOf(_resource);
      }
      if (candidate == _resource.values) {
        return PrivacyResource.copyOf(_resource);
      }
      throw const PrivacyGatewayException(
        PrivacyGatewayFailureKind.versionConflict,
      );
    }

    // Identical already-applied retries converge before optimistic-version
    // comparison, matching the backend transaction contract.
    if (candidate == _resource.values) {
      return PrivacyResource.copyOf(_resource);
    }
    if (expectedVersion != _resource.version) {
      throw const PrivacyGatewayException(
        PrivacyGatewayFailureKind.versionConflict,
      );
    }
    if (_resource.version == privacyMaximumVersion) {
      throw const PrivacyGatewayException(
        PrivacyGatewayFailureKind.unavailable,
      );
    }

    _resource = PrivacyResource(
      version: _resource.version + 1,
      values: candidate,
      updatedAt: _clock().toUtc(),
    );
    return PrivacyResource.copyOf(_resource);
  }
}
