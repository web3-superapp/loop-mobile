import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_models.dart';

void main() {
  group('Notification preference models', () {
    test('round-trips only the four notification event wire values', () {
      const exactEvents = <NotificationPreferenceEvent, String>{
        NotificationPreferenceEvent.priceAlertTriggered:
            'price_alert_triggered',
        NotificationPreferenceEvent.providerActivityProjected:
            'provider_activity_projected',
        NotificationPreferenceEvent.securityNotice: 'security_notice',
        NotificationPreferenceEvent.supportUpdate: 'support_update',
      };

      expect(NotificationPreferenceEvent.values, exactEvents.keys.toList());
      for (final entry in exactEvents.entries) {
        expect(entry.key.wireValue, entry.value);
        expect(NotificationPreferenceEvent.fromWire(entry.value), entry.key);
      }
      for (final invalid in <String>[
        '',
        'price_alert',
        'Price_alert_triggered',
        'security_notice ',
        'orders_and_fills',
      ]) {
        expect(
          () => NotificationPreferenceEvent.fromWire(invalid),
          throwsA(isA<InvalidNotificationPreferencesContractException>()),
        );
      }
    });

    test('uses the exact disabled backend defaults', () {
      const values = NotificationPreferenceValues.disabled();
      final resource = NotificationPreferencesResource.empty();

      expect(values.priceAlertTriggered, isFalse);
      expect(values.providerActivityProjected, isFalse);
      expect(values.securityNotice, isFalse);
      expect(values.supportUpdate, isFalse);
      expect(values.enabledCount, 0);
      for (final event in NotificationPreferenceEvent.values) {
        expect(values.enabledFor(event), isFalse);
      }
      expect(resource.version, 0);
      expect(resource.values, values);
      expect(resource.delivery, NotificationDeliveryState.unavailable);
    });

    test('keeps delivery permanently unavailable', () {
      expect(NotificationDeliveryState.values, <NotificationDeliveryState>[
        NotificationDeliveryState.unavailable,
      ]);
      expect(NotificationDeliveryState.unavailable.wireValue, 'unavailable');
      expect(
        NotificationDeliveryState.fromWire('unavailable'),
        NotificationDeliveryState.unavailable,
      );
      expect(
        NotificationPreferencesResource(
          version: 1,
          values: const NotificationPreferenceValues.disabled(),
          delivery: NotificationDeliveryState.unavailable,
        ).delivery,
        NotificationDeliveryState.unavailable,
      );
      expect(
        () => NotificationDeliveryState.fromWire('available'),
        throwsA(isA<InvalidNotificationPreferencesContractException>()),
      );
    });

    test('edits one event without mutating the complete preference set', () {
      const disabled = NotificationPreferenceValues.disabled();
      final security = disabled.withEvent(
        NotificationPreferenceEvent.securityNotice,
        true,
      );
      final twoEnabled = security.withEvent(
        NotificationPreferenceEvent.priceAlertTriggered,
        true,
      );
      final securityDisabled = twoEnabled.withEvent(
        NotificationPreferenceEvent.securityNotice,
        false,
      );

      expect(disabled.enabledCount, 0);
      expect(security.enabledCount, 1);
      expect(
        security.enabledFor(NotificationPreferenceEvent.securityNotice),
        isTrue,
      );
      expect(
        security.enabledFor(NotificationPreferenceEvent.priceAlertTriggered),
        isFalse,
      );
      expect(twoEnabled.enabledCount, 2);
      expect(
        twoEnabled.enabledFor(
          NotificationPreferenceEvent.providerActivityProjected,
        ),
        isFalse,
      );
      expect(securityDisabled.enabledCount, 1);
      expect(
        securityDisabled.enabledFor(
          NotificationPreferenceEvent.priceAlertTriggered,
        ),
        isTrue,
      );
      expect(disabled, const NotificationPreferenceValues.disabled());
    });

    test('defensively copies values and supports value equality', () {
      const first = NotificationPreferenceValues(
        priceAlertTriggered: true,
        providerActivityProjected: false,
        securityNotice: true,
        supportUpdate: false,
      );
      const same = NotificationPreferenceValues(
        priceAlertTriggered: true,
        providerActivityProjected: false,
        securityNotice: true,
        supportUpdate: false,
      );
      const different = NotificationPreferenceValues(
        priceAlertTriggered: true,
        providerActivityProjected: false,
        securityNotice: false,
        supportUpdate: false,
      );

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(different));

      final copiedValues = NotificationPreferenceValues.copyOf(first);
      expect(copiedValues, first);
      expect(identical(copiedValues, first), isFalse);

      final resource = NotificationPreferencesResource(
        version: 3,
        values: first,
        delivery: NotificationDeliveryState.unavailable,
      );
      final copiedResource = NotificationPreferencesResource.copyOf(resource);
      expect(resource.values, first);
      expect(identical(resource.values, first), isFalse);
      expect(copiedResource, resource);
      expect(copiedResource.hashCode, resource.hashCode);
      expect(identical(copiedResource, resource), isFalse);
      expect(identical(copiedResource.values, resource.values), isFalse);
    });

    test('enforces notification preference resource version bounds', () {
      expect(
        NotificationPreferencesResource(
          version: notificationPreferencesMaximumVersion,
          values: const NotificationPreferenceValues.disabled(),
          delivery: NotificationDeliveryState.unavailable,
        ).version,
        notificationPreferencesMaximumVersion,
      );

      for (final action in <void Function()>[
        () => NotificationPreferencesResource(
          version: -1,
          values: const NotificationPreferenceValues.disabled(),
          delivery: NotificationDeliveryState.unavailable,
        ),
        () => NotificationPreferencesResource(
          version: notificationPreferencesMaximumVersion + 1,
          values: const NotificationPreferenceValues.disabled(),
          delivery: NotificationDeliveryState.unavailable,
        ),
        () => NotificationPreferencesResource(
          version: 0,
          values: const NotificationPreferenceValues.disabled().withEvent(
            NotificationPreferenceEvent.supportUpdate,
            true,
          ),
          delivery: NotificationDeliveryState.unavailable,
        ),
      ]) {
        expect(
          action,
          throwsA(isA<InvalidNotificationPreferencesContractException>()),
        );
      }
    });

    test('keeps contract failures sanitized', () {
      const failure = InvalidNotificationPreferencesContractException();

      expect(failure.code, 'invalid_notification_preferences_contract');
      expect(
        failure.toString(),
        'The notification preferences contract is invalid',
      );
      expect(failure.toString(), isNot(contains('security_notice')));
    });
  });
}
