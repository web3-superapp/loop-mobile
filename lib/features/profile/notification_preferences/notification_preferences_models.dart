import 'package:flutter/foundation.dart';

const int notificationPreferencesMaximumVersion = 2147483647;

/// Sanitized validation failure for data outside the reviewed contract.
final class InvalidNotificationPreferencesContractException
    implements Exception {
  const InvalidNotificationPreferencesContractException();

  String get code => 'invalid_notification_preferences_contract';

  @override
  String toString() => 'The notification preferences contract is invalid';
}

enum NotificationPreferenceEvent {
  priceAlertTriggered,
  providerActivityProjected,
  securityNotice,
  supportUpdate;

  String get wireValue => switch (this) {
    NotificationPreferenceEvent.priceAlertTriggered => 'price_alert_triggered',
    NotificationPreferenceEvent.providerActivityProjected =>
      'provider_activity_projected',
    NotificationPreferenceEvent.securityNotice => 'security_notice',
    NotificationPreferenceEvent.supportUpdate => 'support_update',
  };

  static NotificationPreferenceEvent fromWire(String value) => switch (value) {
    'price_alert_triggered' => NotificationPreferenceEvent.priceAlertTriggered,
    'provider_activity_projected' =>
      NotificationPreferenceEvent.providerActivityProjected,
    'security_notice' => NotificationPreferenceEvent.securityNotice,
    'support_update' => NotificationPreferenceEvent.supportUpdate,
    _ => throw const InvalidNotificationPreferencesContractException(),
  };
}

/// A saved preference never upgrades this capability in the current contract.
enum NotificationDeliveryState {
  unavailable;

  String get wireValue => 'unavailable';

  static NotificationDeliveryState fromWire(String value) => switch (value) {
    'unavailable' => NotificationDeliveryState.unavailable,
    _ => throw const InvalidNotificationPreferencesContractException(),
  };
}

@immutable
final class NotificationPreferenceValues {
  const NotificationPreferenceValues({
    required this.priceAlertTriggered,
    required this.providerActivityProjected,
    required this.securityNotice,
    required this.supportUpdate,
  });

  const NotificationPreferenceValues.disabled()
    : priceAlertTriggered = false,
      providerActivityProjected = false,
      securityNotice = false,
      supportUpdate = false;

  factory NotificationPreferenceValues.copyOf(
    NotificationPreferenceValues source,
  ) => NotificationPreferenceValues(
    priceAlertTriggered: source.priceAlertTriggered,
    providerActivityProjected: source.providerActivityProjected,
    securityNotice: source.securityNotice,
    supportUpdate: source.supportUpdate,
  );

  final bool priceAlertTriggered;
  final bool providerActivityProjected;
  final bool securityNotice;
  final bool supportUpdate;

  bool enabledFor(NotificationPreferenceEvent event) => switch (event) {
    NotificationPreferenceEvent.priceAlertTriggered => priceAlertTriggered,
    NotificationPreferenceEvent.providerActivityProjected =>
      providerActivityProjected,
    NotificationPreferenceEvent.securityNotice => securityNotice,
    NotificationPreferenceEvent.supportUpdate => supportUpdate,
  };

  NotificationPreferenceValues withEvent(
    NotificationPreferenceEvent event,
    bool enabled,
  ) => NotificationPreferenceValues(
    priceAlertTriggered:
        event == NotificationPreferenceEvent.priceAlertTriggered
        ? enabled
        : priceAlertTriggered,
    providerActivityProjected:
        event == NotificationPreferenceEvent.providerActivityProjected
        ? enabled
        : providerActivityProjected,
    securityNotice: event == NotificationPreferenceEvent.securityNotice
        ? enabled
        : securityNotice,
    supportUpdate: event == NotificationPreferenceEvent.supportUpdate
        ? enabled
        : supportUpdate,
  );

  int get enabledCount =>
      NotificationPreferenceEvent.values.where(enabledFor).length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferenceValues &&
          other.priceAlertTriggered == priceAlertTriggered &&
          other.providerActivityProjected == providerActivityProjected &&
          other.securityNotice == securityNotice &&
          other.supportUpdate == supportUpdate;

  @override
  int get hashCode => Object.hash(
    priceAlertTriggered,
    providerActivityProjected,
    securityNotice,
    supportUpdate,
  );
}

@immutable
final class NotificationPreferencesResource {
  factory NotificationPreferencesResource({
    required int version,
    required NotificationPreferenceValues values,
    required NotificationDeliveryState delivery,
  }) {
    if (version < 0 ||
        version > notificationPreferencesMaximumVersion ||
        (version == 0 &&
            values != const NotificationPreferenceValues.disabled()) ||
        delivery != NotificationDeliveryState.unavailable) {
      throw const InvalidNotificationPreferencesContractException();
    }
    return NotificationPreferencesResource._(
      version,
      NotificationPreferenceValues.copyOf(values),
      delivery,
    );
  }

  const NotificationPreferencesResource._(
    this.version,
    this.values,
    this.delivery,
  );

  factory NotificationPreferencesResource.empty() =>
      NotificationPreferencesResource(
        version: 0,
        values: const NotificationPreferenceValues.disabled(),
        delivery: NotificationDeliveryState.unavailable,
      );

  factory NotificationPreferencesResource.copyOf(
    NotificationPreferencesResource source,
  ) => NotificationPreferencesResource(
    version: source.version,
    values: source.values,
    delivery: source.delivery,
  );

  final int version;
  final NotificationPreferenceValues values;
  final NotificationDeliveryState delivery;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferencesResource &&
          other.version == version &&
          other.values == values &&
          other.delivery == delivery;

  @override
  int get hashCode => Object.hash(version, values, delivery);
}
