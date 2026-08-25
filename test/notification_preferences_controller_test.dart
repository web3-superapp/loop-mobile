import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_controller.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_gateway.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_models.dart';
import 'package:loop_mobile/integrations/personalization/memory_notification_preferences_gateway.dart';

void main() {
  group('MemoryNotificationPreferencesGateway', () {
    test(
      'keeps identical version-zero defaults and creates on first change',
      () async {
        final gateway = MemoryNotificationPreferencesGateway();
        const defaults = NotificationPreferenceValues.disabled();

        expect(gateway.mode, NotificationPreferencesMode.preview);
        expect(await gateway.load(), NotificationPreferencesResource.empty());

        // A missing row remains the non-writing version-zero default even when
        // the identical request carries a stale expected version.
        expect(
          await gateway.replace(expectedVersion: 99, values: defaults),
          NotificationPreferencesResource.empty(),
        );

        final desired = defaults.withEvent(
          NotificationPreferenceEvent.priceAlertTriggered,
          true,
        );
        final created = await gateway.replace(
          expectedVersion: 0,
          values: desired,
        );
        expect(created.version, 1);
        expect(created.values, desired);
        expect(created.delivery, NotificationDeliveryState.unavailable);

        final identicalStaleRetry = await gateway.replace(
          expectedVersion: 0,
          values: desired,
        );
        expect(identicalStaleRetry, created);
      },
    );

    test('rejects stale different values with a version conflict', () async {
      final gateway = MemoryNotificationPreferencesGateway();
      await gateway.replace(
        expectedVersion: 0,
        values: _values(priceAlertTriggered: true),
      );

      await expectLater(
        gateway.replace(
          expectedVersion: 0,
          values: _values(securityNotice: true),
        ),
        throwsA(
          _gatewayFailure(
            NotificationPreferencesGatewayFailureKind.versionConflict,
          ),
        ),
      );
    });

    test('fails closed at invalid and exhausted versions', () async {
      final maximum = _resource(
        notificationPreferencesMaximumVersion,
        securityNotice: true,
      );
      final gateway = MemoryNotificationPreferencesGateway(
        initialResource: maximum,
      );

      expect(
        await gateway.replace(expectedVersion: 0, values: maximum.values),
        maximum,
      );
      await expectLater(
        gateway.replace(
          expectedVersion: notificationPreferencesMaximumVersion,
          values: _values(supportUpdate: true),
        ),
        throwsA(
          _gatewayFailure(
            NotificationPreferencesGatewayFailureKind.unavailable,
          ),
        ),
      );
      await expectLater(
        gateway.replace(expectedVersion: -1, values: maximum.values),
        throwsA(
          _gatewayFailure(
            NotificationPreferencesGatewayFailureKind.invalidData,
          ),
        ),
      );
      await expectLater(
        gateway.replace(
          expectedVersion: notificationPreferencesMaximumVersion + 1,
          values: maximum.values,
        ),
        throwsA(
          _gatewayFailure(
            NotificationPreferencesGatewayFailureKind.invalidData,
          ),
        ),
      );
    });
  });

  group('NotificationPreferencesController', () {
    test('production defaults directly unavailable', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(notificationPreferencesControllerProvider);
      expect(initial.mode, NotificationPreferencesMode.unavailable);
      expect(initial.phase, NotificationPreferencesPhase.unavailable);
      expect(initial.resource, isNull);
      expect(initial.draft, const NotificationPreferenceValues.disabled());
      expect(initial.canEdit, isFalse);

      await container
          .read(notificationPreferencesControllerProvider.notifier)
          .load();
      expect(
        container.read(notificationPreferencesControllerProvider).failureCode,
        'notification_preferences_unavailable',
      );
    });

    test('loads, edits exact events, and discards immutable drafts', () async {
      final initial = _resource(2, providerActivityProjected: true);
      final container = _container(
        MemoryNotificationPreferencesGateway(initialResource: initial),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        notificationPreferencesControllerProvider.notifier,
      );

      await controller.load();
      var state = container.read(notificationPreferencesControllerProvider);
      expect(state.phase, NotificationPreferencesPhase.ready);
      expect(state.isDirty, isFalse);
      expect(state.expectedVersion, 2);

      controller.edit(NotificationPreferenceEvent.priceAlertTriggered, true);
      controller.edit(NotificationPreferenceEvent.securityNotice, true);
      state = container.read(notificationPreferencesControllerProvider);
      expect(state.draft.priceAlertTriggered, isTrue);
      expect(state.draft.providerActivityProjected, isTrue);
      expect(state.draft.securityNotice, isTrue);
      expect(state.draft.supportUpdate, isFalse);
      expect(state.draft.enabledCount, 3);
      expect(state.isDirty, isTrue);
      expect(state.canSave, isTrue);
      expect(initial.values.priceAlertTriggered, isFalse);

      controller.discard();
      state = container.read(notificationPreferencesControllerProvider);
      expect(state.phase, NotificationPreferencesPhase.ready);
      expect(state.draft, initial.values);
      expect(state.isDirty, isFalse);
    });

    test(
      'load and save are single-flight and save the complete fixed set',
      () async {
        final loadGate = Completer<NotificationPreferencesResource>();
        final saveGate = Completer<NotificationPreferencesResource>();
        final gateway = _TestNotificationPreferencesGateway(
          onLoad: () => loadGate.future,
          onReplace: (_, _) => saveGate.future,
        );
        final container = _container(gateway);
        addTearDown(container.dispose);
        final controller = container.read(
          notificationPreferencesControllerProvider.notifier,
        );

        final firstLoad = controller.load();
        final secondLoad = controller.load();
        expect(identical(firstLoad, secondLoad), isTrue);
        expect(gateway.loadCalls, 1);
        expect(
          container.read(notificationPreferencesControllerProvider).phase,
          NotificationPreferencesPhase.loading,
        );

        final loaded = _resource(7, providerActivityProjected: true);
        loadGate.complete(loaded);
        await firstLoad;

        await controller.save();
        expect(gateway.replaceCalls, 0);
        controller.edit(NotificationPreferenceEvent.priceAlertTriggered, true);
        final firstSave = controller.save();
        final secondSave = controller.save();
        expect(identical(firstSave, secondSave), isTrue);
        expect(gateway.replaceCalls, 1);
        expect(gateway.expectedVersions, <int>[7]);
        expect(gateway.candidates.single.priceAlertTriggered, isTrue);
        expect(gateway.candidates.single.providerActivityProjected, isTrue);
        expect(gateway.candidates.single.securityNotice, isFalse);
        expect(gateway.candidates.single.supportUpdate, isFalse);
        expect(
          container.read(notificationPreferencesControllerProvider).phase,
          NotificationPreferencesPhase.saving,
        );

        final reloadWhileSaving = controller.reload();
        expect(identical(reloadWhileSaving, firstSave), isTrue);
        expect(gateway.loadCalls, 1);
        expect(
          () =>
              controller.edit(NotificationPreferenceEvent.supportUpdate, true),
          throwsStateError,
        );
        controller.discard();
        expect(
          container.read(notificationPreferencesControllerProvider).phase,
          NotificationPreferencesPhase.saving,
        );

        saveGate.complete(
          _resource(
            8,
            priceAlertTriggered: true,
            providerActivityProjected: true,
          ),
        );
        await firstSave;
        final saved = container.read(notificationPreferencesControllerProvider);
        expect(saved.phase, NotificationPreferencesPhase.ready);
        expect(saved.resource!.version, 8);
        expect(saved.isDirty, isFalse);
      },
    );

    test('a failed load is explicitly retryable', () async {
      var loadCalls = 0;
      final loaded = _resource(1, supportUpdate: true);
      final gateway = _TestNotificationPreferencesGateway(
        onLoad: () async {
          loadCalls += 1;
          if (loadCalls == 1) {
            throw const NotificationPreferencesGatewayException(
              NotificationPreferencesGatewayFailureKind.unavailable,
            );
          }
          return loaded;
        },
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(
        notificationPreferencesControllerProvider.notifier,
      );

      await controller.load();
      expect(
        container.read(notificationPreferencesControllerProvider).phase,
        NotificationPreferencesPhase.failure,
      );
      await controller.reload();
      final retried = container.read(notificationPreferencesControllerProvider);
      expect(gateway.loadCalls, 2);
      expect(retried.phase, NotificationPreferencesPhase.ready);
      expect(retried.resource, loaded);
    });

    test('failed save keeps the complete local draft retryable', () async {
      final loaded = _resource(1, securityNotice: true);
      final gateway = _TestNotificationPreferencesGateway(
        onLoad: () async => loaded,
        onReplace: (_, _) async =>
            throw const NotificationPreferencesGatewayException(
              NotificationPreferencesGatewayFailureKind.unavailable,
            ),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(
        notificationPreferencesControllerProvider.notifier,
      );
      await controller.load();
      controller.edit(NotificationPreferenceEvent.priceAlertTriggered, true);
      controller.edit(NotificationPreferenceEvent.supportUpdate, true);
      final draft = container
          .read(notificationPreferencesControllerProvider)
          .draft;

      await controller.save();
      final failed = container.read(notificationPreferencesControllerProvider);
      expect(failed.phase, NotificationPreferencesPhase.failure);
      expect(failed.failureCode, 'notification_preferences_unavailable');
      expect(failed.resource, loaded);
      expect(failed.draft, draft);
      expect(failed.draft.securityNotice, isTrue);
      expect(failed.canSave, isTrue);
    });

    test('version conflict freezes the draft until reload succeeds', () async {
      final local = _resource(3, securityNotice: true);
      final remote = _resource(4, supportUpdate: true);
      var loadCalls = 0;
      var reloadFails = true;
      final gateway = _TestNotificationPreferencesGateway(
        onLoad: () async {
          if (loadCalls++ == 0) return local;
          if (reloadFails) {
            throw const NotificationPreferencesGatewayException(
              NotificationPreferencesGatewayFailureKind.unavailable,
            );
          }
          return remote;
        },
        onReplace: (_, _) async =>
            throw const NotificationPreferencesGatewayException(
              NotificationPreferencesGatewayFailureKind.versionConflict,
            ),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(
        notificationPreferencesControllerProvider.notifier,
      );
      await controller.load();
      controller.edit(NotificationPreferenceEvent.priceAlertTriggered, true);
      final draft = container
          .read(notificationPreferencesControllerProvider)
          .draft;

      await controller.save();
      var conflicted = container.read(
        notificationPreferencesControllerProvider,
      );
      expect(conflicted.phase, NotificationPreferencesPhase.conflict);
      expect(
        conflicted.failureCode,
        'notification_preferences_version_conflict',
      );
      expect(conflicted.requiresReload, isTrue);
      expect(conflicted.resource, local);
      expect(conflicted.draft, draft);
      expect(conflicted.canEdit, isFalse);
      expect(conflicted.canSave, isFalse);
      expect(
        () => controller.edit(NotificationPreferenceEvent.supportUpdate, true),
        throwsStateError,
      );

      await controller.reload();
      conflicted = container.read(notificationPreferencesControllerProvider);
      expect(conflicted.phase, NotificationPreferencesPhase.conflict);
      expect(conflicted.failureCode, 'notification_preferences_unavailable');
      expect(conflicted.requiresReload, isTrue);
      expect(conflicted.resource, local);
      expect(conflicted.draft, draft);

      controller.discard();
      expect(
        container.read(notificationPreferencesControllerProvider).draft,
        draft,
      );
      await controller.save();
      expect(gateway.replaceCalls, 1);

      reloadFails = false;
      await controller.reload();
      final reloaded = container.read(
        notificationPreferencesControllerProvider,
      );
      expect(reloaded.phase, NotificationPreferencesPhase.ready);
      expect(reloaded.requiresReload, isFalse);
      expect(reloaded.resource, remote);
      expect(reloaded.draft, remote.values);
    });

    test('mismatched and non-advancing save responses fail closed', () async {
      final loaded = _resource(4, securityNotice: true);
      var mismatchedValues = true;
      final gateway = _TestNotificationPreferencesGateway(
        onLoad: () async => loaded,
        onReplace: (_, values) async => mismatchedValues
            ? _resource(5, supportUpdate: true)
            : NotificationPreferencesResource(
                version: 4,
                values: values,
                delivery: NotificationDeliveryState.unavailable,
              ),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(
        notificationPreferencesControllerProvider.notifier,
      );
      await controller.load();
      controller.edit(NotificationPreferenceEvent.priceAlertTriggered, true);
      final draft = container
          .read(notificationPreferencesControllerProvider)
          .draft;

      await controller.save();
      var failed = container.read(notificationPreferencesControllerProvider);
      expect(failed.phase, NotificationPreferencesPhase.failure);
      expect(
        failed.failureKind,
        NotificationPreferencesGatewayFailureKind.invalidData,
      );
      expect(failed.resource, loaded);
      expect(failed.draft, draft);

      mismatchedValues = false;
      await controller.save();
      failed = container.read(notificationPreferencesControllerProvider);
      expect(failed.phase, NotificationPreferencesPhase.failure);
      expect(
        failed.failureKind,
        NotificationPreferencesGatewayFailureKind.invalidData,
      );
      expect(failed.resource, loaded);
      expect(failed.draft, draft);
    });

    test('an ambiguous save retries the same version and converges', () async {
      final memory = MemoryNotificationPreferencesGateway();
      var firstReplace = true;
      final gateway = _TestNotificationPreferencesGateway(
        onLoad: memory.load,
        onReplace: (expectedVersion, values) async {
          final committed = await memory.replace(
            expectedVersion: expectedVersion,
            values: values,
          );
          if (firstReplace) {
            firstReplace = false;
            throw const NotificationPreferencesGatewayException(
              NotificationPreferencesGatewayFailureKind.unavailable,
            );
          }
          return committed;
        },
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(
        notificationPreferencesControllerProvider.notifier,
      );
      await controller.load();
      controller.edit(NotificationPreferenceEvent.securityNotice, true);

      await controller.save();
      final ambiguous = container.read(
        notificationPreferencesControllerProvider,
      );
      expect(ambiguous.phase, NotificationPreferencesPhase.failure);
      expect(ambiguous.resource!.version, 0);
      expect(ambiguous.isDirty, isTrue);

      await controller.save();
      final reconciled = container.read(
        notificationPreferencesControllerProvider,
      );
      expect(gateway.expectedVersions, <int>[0, 0]);
      expect(reconciled.phase, NotificationPreferencesPhase.ready);
      expect(reconciled.resource!.version, 1);
      expect(reconciled.resource!.values.securityNotice, isTrue);
      expect(reconciled.isDirty, isFalse);
    });

    test(
      'gateway rotation retires old load and accepts only the new owner',
      () async {
        final oldLoad = Completer<NotificationPreferencesResource>();
        final newLoad = Completer<NotificationPreferencesResource>();
        final oldGateway = _TestNotificationPreferencesGateway(
          onLoad: () => oldLoad.future,
        );
        final newGateway = _TestNotificationPreferencesGateway(
          mode: NotificationPreferencesMode.production,
          onLoad: () => newLoad.future,
        );
        final container = _container(oldGateway);
        addTearDown(container.dispose);
        final controller = container.read(
          notificationPreferencesControllerProvider.notifier,
        );

        final retired = controller.load();
        container.updateOverrides([
          notificationPreferencesGatewayProvider.overrideWithValue(newGateway),
        ]);
        expect(
          container.read(notificationPreferencesControllerProvider).mode,
          NotificationPreferencesMode.production,
        );
        expect(
          container.read(notificationPreferencesControllerProvider).resource,
          isNull,
        );

        final active = controller.load();
        expect(newGateway.loadCalls, 1);
        oldLoad.complete(_resource(1, priceAlertTriggered: true));
        await retired;
        expect(
          container.read(notificationPreferencesControllerProvider).resource,
          isNull,
        );

        final stillActive = controller.load();
        expect(identical(active, stillActive), isTrue);
        final newResource = _resource(5, supportUpdate: true);
        newLoad.complete(newResource);
        await active;
        expect(
          container.read(notificationPreferencesControllerProvider).resource,
          newResource,
        );
      },
    );

    test(
      'gateway rotation retires an old save without clearing a new save',
      () async {
        final initial = _resource(1);
        final oldSave = Completer<NotificationPreferencesResource>();
        final oldGateway = _TestNotificationPreferencesGateway(
          onLoad: () async => initial,
          onReplace: (_, _) => oldSave.future,
        );
        final newInitial = _resource(9, providerActivityProjected: true);
        final newSave = Completer<NotificationPreferencesResource>();
        final newGateway = _TestNotificationPreferencesGateway(
          mode: NotificationPreferencesMode.production,
          onLoad: () async => newInitial,
          onReplace: (_, _) => newSave.future,
        );
        final container = _container(oldGateway);
        addTearDown(container.dispose);
        final controller = container.read(
          notificationPreferencesControllerProvider.notifier,
        );
        await controller.load();
        controller.edit(NotificationPreferenceEvent.securityNotice, true);
        final retired = controller.save();

        container.updateOverrides([
          notificationPreferencesGatewayProvider.overrideWithValue(newGateway),
        ]);
        await controller.load();
        controller.edit(NotificationPreferenceEvent.securityNotice, true);
        final active = controller.save();

        oldSave.complete(_resource(2, securityNotice: true));
        await retired;
        final stillActive = controller.save();
        expect(identical(active, stillActive), isTrue);
        expect(newGateway.replaceCalls, 1);

        final saved = _resource(
          10,
          providerActivityProjected: true,
          securityNotice: true,
        );
        newSave.complete(saved);
        await active;
        expect(
          container.read(notificationPreferencesControllerProvider).resource,
          saved,
        );
        expect(
          container.read(notificationPreferencesControllerProvider).isDirty,
          isFalse,
        );
      },
    );

    test('gateway rotation and disposal retire late work safely', () async {
      final invalidatedLoad = Completer<NotificationPreferencesResource>();
      final invalidatedGateway = _TestNotificationPreferencesGateway(
        onLoad: () => invalidatedLoad.future,
      );
      final container = _container(invalidatedGateway);
      final controller = container.read(
        notificationPreferencesControllerProvider.notifier,
      );
      final pending = controller.load();

      container.invalidate(notificationPreferencesControllerProvider);
      expect(
        container.read(notificationPreferencesControllerProvider).phase,
        NotificationPreferencesPhase.initial,
      );
      invalidatedLoad.complete(_resource(1, priceAlertTriggered: true));
      await pending;
      expect(
        container.read(notificationPreferencesControllerProvider).resource,
        isNull,
      );
      container.dispose();

      final disposedLoad = Completer<NotificationPreferencesResource>();
      final disposedContainer = _container(
        _TestNotificationPreferencesGateway(onLoad: () => disposedLoad.future),
      );
      final disposedController = disposedContainer.read(
        notificationPreferencesControllerProvider.notifier,
      );
      final disposedPending = disposedController.load();
      disposedContainer.dispose();
      disposedLoad.complete(_resource(2, securityNotice: true));
      await expectLater(disposedPending, completes);
    });
  });
}

ProviderContainer _container(NotificationPreferencesGateway gateway) {
  return ProviderContainer(
    overrides: [
      notificationPreferencesGatewayProvider.overrideWithValue(gateway),
    ],
  );
}

NotificationPreferenceValues _values({
  bool priceAlertTriggered = false,
  bool providerActivityProjected = false,
  bool securityNotice = false,
  bool supportUpdate = false,
}) {
  return NotificationPreferenceValues(
    priceAlertTriggered: priceAlertTriggered,
    providerActivityProjected: providerActivityProjected,
    securityNotice: securityNotice,
    supportUpdate: supportUpdate,
  );
}

NotificationPreferencesResource _resource(
  int version, {
  bool priceAlertTriggered = false,
  bool providerActivityProjected = false,
  bool securityNotice = false,
  bool supportUpdate = false,
}) {
  return NotificationPreferencesResource(
    version: version,
    values: _values(
      priceAlertTriggered: priceAlertTriggered,
      providerActivityProjected: providerActivityProjected,
      securityNotice: securityNotice,
      supportUpdate: supportUpdate,
    ),
    delivery: NotificationDeliveryState.unavailable,
  );
}

Matcher _gatewayFailure(NotificationPreferencesGatewayFailureKind kind) {
  return isA<NotificationPreferencesGatewayException>().having(
    (error) => error.kind,
    'kind',
    kind,
  );
}

final class _TestNotificationPreferencesGateway
    implements NotificationPreferencesGateway {
  _TestNotificationPreferencesGateway({
    this.mode = NotificationPreferencesMode.preview,
    required this.onLoad,
    Future<NotificationPreferencesResource> Function(
      int expectedVersion,
      NotificationPreferenceValues values,
    )?
    onReplace,
  }) : onReplace =
           onReplace ??
           ((_, _) async => throw const NotificationPreferencesGatewayException(
             NotificationPreferencesGatewayFailureKind.unavailable,
           ));

  @override
  final NotificationPreferencesMode mode;
  final Future<NotificationPreferencesResource> Function() onLoad;
  final Future<NotificationPreferencesResource> Function(
    int expectedVersion,
    NotificationPreferenceValues values,
  )
  onReplace;
  int loadCalls = 0;
  int replaceCalls = 0;
  final List<int> expectedVersions = <int>[];
  final List<NotificationPreferenceValues> candidates =
      <NotificationPreferenceValues>[];

  @override
  Future<NotificationPreferencesResource> load() {
    loadCalls += 1;
    return onLoad();
  }

  @override
  Future<NotificationPreferencesResource> replace({
    required int expectedVersion,
    required NotificationPreferenceValues values,
  }) {
    replaceCalls += 1;
    expectedVersions.add(expectedVersion);
    final copied = NotificationPreferenceValues.copyOf(values);
    candidates.add(copied);
    return onReplace(expectedVersion, copied);
  }
}
