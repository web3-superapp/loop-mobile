import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_gateway.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_models.dart';

/// Explicit in-memory implementation for deterministic Preview or tests.
///
/// It stores owner intent only and never represents provider delivery.
final class MemoryNotificationPreferencesGateway
    implements NotificationPreferencesGateway {
  MemoryNotificationPreferencesGateway({
    NotificationPreferencesResource? initialResource,
  }) : _resource = NotificationPreferencesResource.copyOf(
         initialResource ?? NotificationPreferencesResource.empty(),
       );

  NotificationPreferencesResource _resource;

  @override
  NotificationPreferencesMode get mode => NotificationPreferencesMode.preview;

  @override
  Future<NotificationPreferencesResource> load() async =>
      NotificationPreferencesResource.copyOf(_resource);

  @override
  Future<NotificationPreferencesResource> replace({
    required int expectedVersion,
    required NotificationPreferenceValues values,
  }) async {
    if (expectedVersion < 0 ||
        expectedVersion > notificationPreferencesMaximumVersion) {
      throw const NotificationPreferencesGatewayException(
        NotificationPreferencesGatewayFailureKind.invalidData,
      );
    }
    final candidate = NotificationPreferenceValues.copyOf(values);

    // Identical requests converge before optimistic-version comparison. At
    // version zero, disabled defaults remain a non-persisted default resource.
    if (candidate == _resource.values) {
      return NotificationPreferencesResource.copyOf(_resource);
    }
    if (expectedVersion != _resource.version) {
      throw const NotificationPreferencesGatewayException(
        NotificationPreferencesGatewayFailureKind.versionConflict,
      );
    }
    if (_resource.version == notificationPreferencesMaximumVersion) {
      throw const NotificationPreferencesGatewayException(
        NotificationPreferencesGatewayFailureKind.unavailable,
      );
    }

    _resource = NotificationPreferencesResource(
      version: _resource.version + 1,
      values: candidate,
      delivery: NotificationDeliveryState.unavailable,
    );
    return NotificationPreferencesResource.copyOf(_resource);
  }
}
