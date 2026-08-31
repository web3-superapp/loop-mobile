import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_models.dart';

/// Explicit in-memory implementation for deterministic Preview or tests.
///
/// It is intentionally not composed by the production provider.
final class MemorySocialPrivacyGateway implements SocialPrivacyGateway {
  MemorySocialPrivacyGateway({
    SocialPrivacyResource? initialResource,
    DateTime Function()? clock,
  }) : _resource = SocialPrivacyResource.copyOf(
         initialResource ?? SocialPrivacyResource.empty(),
       ),
       _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  SocialPrivacyResource _resource;

  @override
  SocialPrivacyMode get mode => SocialPrivacyMode.preview;

  @override
  Future<SocialPrivacyResource> load() async =>
      SocialPrivacyResource.copyOf(_resource);

  @override
  Future<SocialPrivacyResource> replace({
    required int expectedVersion,
    required SocialPrivacyValues values,
  }) async {
    if (expectedVersion < 0 || expectedVersion > socialPrivacyMaximumVersion) {
      throw const SocialPrivacyGatewayException(
        SocialPrivacyGatewayFailureKind.invalidData,
      );
    }
    final candidate = SocialPrivacyValues.copyOf(values);

    // A missing row is version zero. Submitting expected version zero creates
    // version one even when the submitted values equal fail-closed defaults.
    if (_resource.version == 0) {
      if (expectedVersion == 0) {
        _resource = SocialPrivacyResource(
          version: 1,
          values: candidate,
          updatedAt: _clock().toUtc(),
        );
        return SocialPrivacyResource.copyOf(_resource);
      }
      if (candidate == _resource.values) {
        return SocialPrivacyResource.copyOf(_resource);
      }
      throw const SocialPrivacyGatewayException(
        SocialPrivacyGatewayFailureKind.versionConflict,
      );
    }

    // Identical already-applied retries converge before optimistic-version
    // comparison, matching the backend transaction contract.
    if (candidate == _resource.values) {
      return SocialPrivacyResource.copyOf(_resource);
    }
    if (expectedVersion != _resource.version) {
      throw const SocialPrivacyGatewayException(
        SocialPrivacyGatewayFailureKind.versionConflict,
      );
    }
    if (_resource.version == socialPrivacyMaximumVersion) {
      throw const SocialPrivacyGatewayException(
        SocialPrivacyGatewayFailureKind.unavailable,
      );
    }

    _resource = SocialPrivacyResource(
      version: _resource.version + 1,
      values: candidate,
      updatedAt: _clock().toUtc(),
    );
    return SocialPrivacyResource.copyOf(_resource);
  }
}
