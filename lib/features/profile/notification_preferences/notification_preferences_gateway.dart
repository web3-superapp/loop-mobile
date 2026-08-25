import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_models.dart';

enum NotificationPreferencesMode { unavailable, preview, production }

enum NotificationPreferencesGatewayFailureKind {
  unavailable,
  versionConflict,
  invalidData,
  unexpected,
}

final class NotificationPreferencesGatewayException implements Exception {
  const NotificationPreferencesGatewayException(this.kind);

  final NotificationPreferencesGatewayFailureKind kind;

  String get code => switch (kind) {
    NotificationPreferencesGatewayFailureKind.unavailable =>
      'notification_preferences_unavailable',
    NotificationPreferencesGatewayFailureKind.versionConflict =>
      'notification_preferences_version_conflict',
    NotificationPreferencesGatewayFailureKind.invalidData =>
      'invalid_notification_preferences_data',
    NotificationPreferencesGatewayFailureKind.unexpected =>
      'notification_preferences_request_failed',
  };

  @override
  String toString() => code;
}

abstract interface class NotificationPreferencesGateway {
  NotificationPreferencesMode get mode;

  Future<NotificationPreferencesResource> load();

  Future<NotificationPreferencesResource> replace({
    required int expectedVersion,
    required NotificationPreferenceValues values,
  });
}

/// Production-safe default while the authenticated adapter is absent.
final class UnavailableNotificationPreferencesGateway
    implements NotificationPreferencesGateway {
  const UnavailableNotificationPreferencesGateway();

  @override
  NotificationPreferencesMode get mode =>
      NotificationPreferencesMode.unavailable;

  @override
  Future<NotificationPreferencesResource> load() =>
      Future<NotificationPreferencesResource>.error(
        const NotificationPreferencesGatewayException(
          NotificationPreferencesGatewayFailureKind.unavailable,
        ),
      );

  @override
  Future<NotificationPreferencesResource> replace({
    required int expectedVersion,
    required NotificationPreferenceValues values,
  }) => Future<NotificationPreferencesResource>.error(
    const NotificationPreferencesGatewayException(
      NotificationPreferencesGatewayFailureKind.unavailable,
    ),
  );
}

final notificationPreferencesGatewayProvider =
    Provider<NotificationPreferencesGateway>(
      (ref) => const UnavailableNotificationPreferencesGateway(),
    );
