import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_gateway.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/integrations/personalization/memory_notification_preferences_gateway.dart';

void main() {
  testWidgets(
    'production Notification Preferences fails closed without controls or preview claims',
    (tester) async {
      await _pumpPreferences(tester);

      expect(
        find.text('Notification preferences are not connected'),
        findsOneWidget,
      );
      expect(find.byType(SwitchListTile), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>(
            'notification-preference-price_alert_triggered',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('notification-preferences-apply')),
        findsNothing,
      );
      expect(find.textContaining('开发预览'), findsNothing);
    },
  );

  testWidgets(
    'a production load failure reports the request and remains retryable',
    (tester) async {
      final gateway = _FailingProductionNotificationPreferencesGateway();
      await _pumpPreferences(tester, gateway: gateway);

      expect(gateway.loadCount, 1);
      expect(
        find.text('Notification preferences could not be loaded'),
        findsOneWidget,
      );
      expect(find.textContaining('No account request was sent'), findsNothing);
      expect(find.textContaining('are synchronized'), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('notification-preferences-retry-load'),
        ),
        findsOneWidget,
      );
      expect(find.byType(SwitchListTile), findsNothing);

      await _tap(
        tester,
        find.byKey(
          const ValueKey<String>('notification-preferences-retry-load'),
        ),
      );

      expect(gateway.loadCount, 2);
      expect(
        find.text('Notification preferences could not be loaded'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Preview edits the exact four preferences and commits only advanced evidence',
    (tester) async {
      final gateway = _previewGateway();
      await _pumpPreferences(tester, gateway: gateway);

      expect(find.text('开发预览 · in-memory preferences'), findsOneWidget);
      expect(find.text('DELIVERY UNAVAILABLE'), findsOneWidget);
      expect(find.text('VERSION 1'), findsOneWidget);
      expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
      for (final event in NotificationPreferenceEvent.values) {
        expect(_preferenceSwitch(tester, event).value, isFalse);
      }
      expect(_filledButton(tester).onPressed, isNull);
      expect(_outlinedButton(tester).onPressed, isNull);

      await _tapPreference(
        tester,
        NotificationPreferenceEvent.priceAlertTriggered,
      );
      await _tapPreference(tester, NotificationPreferenceEvent.securityNotice);

      expect(find.text('UNSAVED DRAFT'), findsOneWidget);
      expect(
        _preferenceSwitch(
          tester,
          NotificationPreferenceEvent.priceAlertTriggered,
        ).value,
        isTrue,
      );
      expect(
        _preferenceSwitch(
          tester,
          NotificationPreferenceEvent.securityNotice,
        ).value,
        isTrue,
      );
      expect(
        _preferenceSwitch(
          tester,
          NotificationPreferenceEvent.providerActivityProjected,
        ).value,
        isFalse,
      );
      expect(
        _preferenceSwitch(
          tester,
          NotificationPreferenceEvent.supportUpdate,
        ).value,
        isFalse,
      );
      expect(_filledButton(tester).onPressed, isNotNull);
      expect(_outlinedButton(tester).onPressed, isNotNull);

      await _tap(
        tester,
        find.byKey(const ValueKey<String>('notification-preferences-discard')),
      );

      expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
      for (final event in NotificationPreferenceEvent.values) {
        expect(_preferenceSwitch(tester, event).value, isFalse);
      }

      await _tapPreference(
        tester,
        NotificationPreferenceEvent.priceAlertTriggered,
      );
      await _tapPreference(tester, NotificationPreferenceEvent.securityNotice);

      await _tap(
        tester,
        find.byKey(const ValueKey<String>('notification-preferences-apply')),
      );

      final committed = await gateway.load();
      expect(committed.version, 2);
      expect(
        committed.values,
        const NotificationPreferenceValues(
          priceAlertTriggered: true,
          providerActivityProjected: false,
          securityNotice: true,
          supportUpdate: false,
        ),
      );
      expect(committed.delivery, NotificationDeliveryState.unavailable);
      expect(find.text('VERSION 2'), findsOneWidget);
      expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
      expect(find.text('DELIVERY UNAVAILABLE'), findsOneWidget);
      expect(find.text('Notification preferences saved.'), findsNothing);
    },
  );

  testWidgets('non-advanced save evidence does not commit the draft', (
    tester,
  ) async {
    await _pumpPreferences(
      tester,
      gateway: _NonAdvancedNotificationPreferencesGateway(),
    );

    await _tapPreference(
      tester,
      NotificationPreferenceEvent.priceAlertTriggered,
    );
    await _tap(
      tester,
      find.byKey(const ValueKey<String>('notification-preferences-apply')),
    );

    expect(find.text('VERSION 1'), findsOneWidget);
    expect(find.text('VERSION 2'), findsNothing);
    expect(find.text('UNSAVED DRAFT'), findsOneWidget);
    expect(
      _preferenceSwitch(
        tester,
        NotificationPreferenceEvent.priceAlertTriggered,
      ).value,
      isTrue,
    );
    expect(find.text('DELIVERY UNAVAILABLE'), findsOneWidget);
  });

  testWidgets('version conflict preserves the preference draft until reload', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpPreferences(tester, gateway: gateway);

    await _tapPreference(
      tester,
      NotificationPreferenceEvent.priceAlertTriggered,
    );
    await _tapPreference(tester, NotificationPreferenceEvent.supportUpdate);
    await gateway.replace(
      expectedVersion: 1,
      values: const NotificationPreferenceValues(
        priceAlertTriggered: false,
        providerActivityProjected: false,
        securityNotice: true,
        supportUpdate: false,
      ),
    );

    await _tap(
      tester,
      find.byKey(const ValueKey<String>('notification-preferences-apply')),
    );

    expect(
      find.byKey(const ValueKey<String>('notification-preferences-conflict')),
      findsOneWidget,
    );
    expect(find.text('UNSAVED DRAFT'), findsOneWidget);
    expect(
      _preferenceSwitch(
        tester,
        NotificationPreferenceEvent.priceAlertTriggered,
      ).value,
      isTrue,
    );
    expect(
      _preferenceSwitch(
        tester,
        NotificationPreferenceEvent.supportUpdate,
      ).value,
      isTrue,
    );
    expect(
      _preferenceSwitch(
        tester,
        NotificationPreferenceEvent.securityNotice,
      ).value,
      isFalse,
    );
    expect(_filledButton(tester).onPressed, isNull);
    expect(_outlinedButton(tester).onPressed, isNull);

    await _tap(
      tester,
      find.byKey(
        const ValueKey<String>('notification-preferences-conflict-reload'),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('notification-preferences-conflict')),
      findsNothing,
    );
    expect(find.text('VERSION 2'), findsOneWidget);
    expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
    expect(
      _preferenceSwitch(
        tester,
        NotificationPreferenceEvent.priceAlertTriggered,
      ).value,
      isFalse,
    );
    expect(
      _preferenceSwitch(
        tester,
        NotificationPreferenceEvent.securityNotice,
      ).value,
      isTrue,
    );
    expect(
      _preferenceSwitch(
        tester,
        NotificationPreferenceEvent.supportUpdate,
      ).value,
      isFalse,
    );
    expect(find.text('DELIVERY UNAVAILABLE'), findsOneWidget);
  });

  testWidgets(
    'mounted Notification Preferences replaces the old owner after gateway rotation',
    (tester) async {
      final first = MemoryNotificationPreferencesGateway(
        initialResource: _resource(
          version: 3,
          values: const NotificationPreferenceValues(
            priceAlertTriggered: true,
            providerActivityProjected: false,
            securityNotice: false,
            supportUpdate: false,
          ),
        ),
      );
      final second = MemoryNotificationPreferencesGateway(
        initialResource: _resource(
          version: 7,
          values: const NotificationPreferenceValues(
            priceAlertTriggered: false,
            providerActivityProjected: false,
            securityNotice: false,
            supportUpdate: true,
          ),
        ),
      );

      await _pumpPreferences(tester, gateway: first);
      expect(find.text('VERSION 3'), findsOneWidget);
      expect(
        _preferenceSwitch(
          tester,
          NotificationPreferenceEvent.priceAlertTriggered,
        ).value,
        isTrue,
      );
      await _tapPreference(tester, NotificationPreferenceEvent.securityNotice);
      expect(find.text('UNSAVED DRAFT'), findsOneWidget);

      await _pumpPreferences(tester, gateway: second);

      expect(find.text('VERSION 3'), findsNothing);
      expect(find.text('VERSION 7'), findsOneWidget);
      expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
      expect(
        _preferenceSwitch(
          tester,
          NotificationPreferenceEvent.priceAlertTriggered,
        ).value,
        isFalse,
      );
      expect(
        _preferenceSwitch(
          tester,
          NotificationPreferenceEvent.securityNotice,
        ).value,
        isFalse,
      );
      expect(
        _preferenceSwitch(
          tester,
          NotificationPreferenceEvent.supportUpdate,
        ).value,
        isTrue,
      );
      expect(find.text('DELIVERY UNAVAILABLE'), findsOneWidget);
    },
  );

  testWidgets(
    'Notification Preferences supports a 390pt screen at 2x Dynamic Type',
    (tester) async {
      await _pumpPreferences(
        tester,
        gateway: _previewGateway(),
        size: const Size(390, 844),
        textScaler: const TextScaler.linear(2),
      );

      for (final event in NotificationPreferenceEvent.values) {
        expect(
          find.byKey(
            ValueKey<String>('notification-preference-${event.wireValue}'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('DELIVERY UNAVAILABLE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy H9 categories and fake delivery claims are absent', (
    tester,
  ) async {
    await _pumpPreferences(tester, gateway: _previewGateway());

    for (final legacyText in <String>[
      'Price alerts',
      'Orders and fills',
      'Liquidation risk',
      'Community activity',
      'Security alerts',
      'System notices',
      'System notifications are off',
      'Open device settings',
      'Quiet hours',
    ]) {
      expect(find.text(legacyText), findsNothing);
    }
  });
}

Future<void> _pumpPreferences(
  WidgetTester tester, {
  NotificationPreferencesGateway? gateway,
  Size size = const Size(900, 1800),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationPreferencesGatewayProvider.overrideWithValue(
          gateway ?? const UnavailableNotificationPreferencesGateway(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const ProfileSurfaceScreen.fromId('notif-settings'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapPreference(
  WidgetTester tester,
  NotificationPreferenceEvent event,
) => _tap(
  tester,
  find.byKey(ValueKey<String>('notification-preference-${event.wireValue}')),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

SwitchListTile _preferenceSwitch(
  WidgetTester tester,
  NotificationPreferenceEvent event,
) => tester.widget<SwitchListTile>(
  find.byKey(ValueKey<String>('notification-preference-${event.wireValue}')),
);

FilledButton _filledButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const ValueKey<String>('notification-preferences-apply')),
);

OutlinedButton _outlinedButton(WidgetTester tester) =>
    tester.widget<OutlinedButton>(
      find.byKey(const ValueKey<String>('notification-preferences-discard')),
    );

MemoryNotificationPreferencesGateway _previewGateway() =>
    MemoryNotificationPreferencesGateway(
      initialResource: _resource(
        version: 1,
        values: const NotificationPreferenceValues.disabled(),
      ),
    );

NotificationPreferencesResource _resource({
  required int version,
  required NotificationPreferenceValues values,
}) => NotificationPreferencesResource(
  version: version,
  values: values,
  delivery: NotificationDeliveryState.unavailable,
);

final class _NonAdvancedNotificationPreferencesGateway
    implements NotificationPreferencesGateway {
  final _initial = _resource(
    version: 1,
    values: const NotificationPreferenceValues.disabled(),
  );

  @override
  NotificationPreferencesMode get mode => NotificationPreferencesMode.preview;

  @override
  Future<NotificationPreferencesResource> load() async =>
      NotificationPreferencesResource.copyOf(_initial);

  @override
  Future<NotificationPreferencesResource> replace({
    required int expectedVersion,
    required NotificationPreferenceValues values,
  }) async => NotificationPreferencesResource(
    version: expectedVersion,
    values: values,
    delivery: NotificationDeliveryState.unavailable,
  );
}

final class _FailingProductionNotificationPreferencesGateway
    implements NotificationPreferencesGateway {
  var loadCount = 0;

  @override
  NotificationPreferencesMode get mode =>
      NotificationPreferencesMode.production;

  @override
  Future<NotificationPreferencesResource> load() async {
    loadCount += 1;
    throw const NotificationPreferencesGatewayException(
      NotificationPreferencesGatewayFailureKind.unavailable,
    );
  }

  @override
  Future<NotificationPreferencesResource> replace({
    required int expectedVersion,
    required NotificationPreferenceValues values,
  }) => throw UnimplementedError();
}
