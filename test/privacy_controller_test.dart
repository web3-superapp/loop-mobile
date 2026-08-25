import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_controller.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/integrations/personalization/memory_privacy_gateway.dart';

void main() {
  group('MemoryPrivacyGateway', () {
    test('mirrors first-write and identical-retry semantics', () async {
      final now = DateTime.utc(2026, 8, 25, 4);
      var clockCalls = 0;
      final gateway = MemoryPrivacyGateway(
        clock: () {
          clockCalls += 1;
          return now;
        },
      );
      const defaults = PrivacyValues.defaults();

      expect(gateway.mode, PrivacyMode.preview);
      expect(await gateway.load(), PrivacyResource.empty());

      // A stale default request against an absent row converges on version zero.
      expect(
        await gateway.replace(expectedVersion: 99, values: defaults),
        PrivacyResource.empty(),
      );
      expect(clockCalls, 0);

      // An explicit version-zero replacement creates a row even for defaults.
      final created = await gateway.replace(
        expectedVersion: 0,
        values: defaults,
      );
      expect(created.version, 1);
      expect(created.values, defaults);
      expect(created.updatedAt, now);
      expect(clockCalls, 1);

      final identicalStaleRetry = await gateway.replace(
        expectedVersion: 0,
        values: defaults,
      );
      expect(identicalStaleRetry, created);
      expect(clockCalls, 1);

      final updated = await gateway.replace(
        expectedVersion: 1,
        values: _values(
          discoverable: true,
          visibility: CopyTradeVisibility.followers,
        ),
      );
      expect(updated.version, 2);
      expect(updated.values.discoverable, isTrue);
      expect(updated.values.copyTradeVisibility, CopyTradeVisibility.followers);
      expect(clockCalls, 2);
    });

    test('rejects stale different values with a version conflict', () async {
      final gateway = MemoryPrivacyGateway();
      await gateway.replace(
        expectedVersion: 0,
        values: _values(discoverable: true),
      );

      await expectLater(
        gateway.replace(
          expectedVersion: 0,
          values: _values(visibility: CopyTradeVisibility.public),
        ),
        throwsA(_gatewayFailure(PrivacyGatewayFailureKind.versionConflict)),
      );
    });

    test('fails closed at invalid and exhausted versions', () async {
      final maximum = _resource(
        privacyMaximumVersion,
        discoverable: true,
        visibility: CopyTradeVisibility.followers,
      );
      final gateway = MemoryPrivacyGateway(initialResource: maximum);

      expect(
        await gateway.replace(expectedVersion: 0, values: maximum.values),
        maximum,
      );
      await expectLater(
        gateway.replace(
          expectedVersion: privacyMaximumVersion,
          values: _values(visibility: CopyTradeVisibility.public),
        ),
        throwsA(_gatewayFailure(PrivacyGatewayFailureKind.unavailable)),
      );
      await expectLater(
        gateway.replace(expectedVersion: -1, values: maximum.values),
        throwsA(_gatewayFailure(PrivacyGatewayFailureKind.invalidData)),
      );
      await expectLater(
        gateway.replace(
          expectedVersion: privacyMaximumVersion + 1,
          values: maximum.values,
        ),
        throwsA(_gatewayFailure(PrivacyGatewayFailureKind.invalidData)),
      );
    });
  });

  group('PrivacyController', () {
    test('production defaults directly unavailable', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(privacyControllerProvider);
      expect(initial.mode, PrivacyMode.unavailable);
      expect(initial.phase, PrivacyPhase.unavailable);
      expect(initial.resource, isNull);
      expect(initial.draft, const PrivacyValues.defaults());
      expect(initial.canEdit, isFalse);

      await container.read(privacyControllerProvider.notifier).load();
      expect(
        container.read(privacyControllerProvider).failureCode,
        'privacy_unavailable',
      );
    });

    test('loads, edits both exact values, and discards', () async {
      final initial = _resource(2, visibility: CopyTradeVisibility.followers);
      final container = _container(
        MemoryPrivacyGateway(initialResource: initial),
      );
      addTearDown(container.dispose);
      final controller = container.read(privacyControllerProvider.notifier);

      await controller.load();
      var state = container.read(privacyControllerProvider);
      expect(state.phase, PrivacyPhase.ready);
      expect(state.isDirty, isFalse);
      expect(state.expectedVersion, 2);

      controller.editDiscoverable(true);
      controller.editCopyTradeVisibility(CopyTradeVisibility.public);
      state = container.read(privacyControllerProvider);
      expect(state.draft.discoverable, isTrue);
      expect(state.draft.copyTradeVisibility, CopyTradeVisibility.public);
      expect(state.isDirty, isTrue);
      expect(state.canSave, isTrue);

      controller.discard();
      state = container.read(privacyControllerProvider);
      expect(state.phase, PrivacyPhase.ready);
      expect(state.draft, initial.values);
      expect(state.isDirty, isFalse);
    });

    test('load and save are single-flight and save complete values', () async {
      final loadGate = Completer<PrivacyResource>();
      final saveGate = Completer<PrivacyResource>();
      final gateway = _TestPrivacyGateway(
        onLoad: () => loadGate.future,
        onReplace: (_, _) => saveGate.future,
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(privacyControllerProvider.notifier);

      final firstLoad = controller.load();
      final secondLoad = controller.load();
      expect(identical(firstLoad, secondLoad), isTrue);
      expect(gateway.loadCalls, 1);
      expect(
        container.read(privacyControllerProvider).phase,
        PrivacyPhase.loading,
      );

      final loaded = _resource(7, visibility: CopyTradeVisibility.followers);
      loadGate.complete(loaded);
      await firstLoad;

      await controller.save();
      expect(gateway.replaceCalls, 0);
      controller.editDiscoverable(true);
      final firstSave = controller.save();
      final secondSave = controller.save();
      expect(identical(firstSave, secondSave), isTrue);
      expect(gateway.replaceCalls, 1);
      expect(gateway.expectedVersions, <int>[7]);
      expect(gateway.candidates.single.discoverable, isTrue);
      expect(
        gateway.candidates.single.copyTradeVisibility,
        CopyTradeVisibility.followers,
      );
      expect(
        container.read(privacyControllerProvider).phase,
        PrivacyPhase.saving,
      );

      final reloadWhileSaving = controller.reload();
      expect(identical(reloadWhileSaving, firstSave), isTrue);
      expect(gateway.loadCalls, 1);
      expect(() => controller.editDiscoverable(false), throwsStateError);
      controller.discard();
      expect(
        container.read(privacyControllerProvider).phase,
        PrivacyPhase.saving,
      );

      saveGate.complete(
        _resource(
          8,
          discoverable: true,
          visibility: CopyTradeVisibility.followers,
        ),
      );
      await firstSave;
      final saved = container.read(privacyControllerProvider);
      expect(saved.phase, PrivacyPhase.ready);
      expect(saved.resource!.version, 8);
      expect(saved.isDirty, isFalse);
    });

    test('failed save keeps the complete local draft retryable', () async {
      final loaded = _resource(1);
      final gateway = _TestPrivacyGateway(
        onLoad: () async => loaded,
        onReplace: (_, _) async => throw const PrivacyGatewayException(
          PrivacyGatewayFailureKind.unavailable,
        ),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(privacyControllerProvider.notifier);
      await controller.load();
      controller.editDiscoverable(true);
      controller.editCopyTradeVisibility(CopyTradeVisibility.followers);
      final draft = container.read(privacyControllerProvider).draft;

      await controller.save();
      final failed = container.read(privacyControllerProvider);
      expect(failed.phase, PrivacyPhase.failure);
      expect(failed.failureCode, 'privacy_unavailable');
      expect(failed.resource, loaded);
      expect(failed.draft, draft);
      expect(failed.canSave, isTrue);
    });

    test('version conflict freezes the draft until reload succeeds', () async {
      final local = _resource(3);
      final remote = _resource(
        4,
        discoverable: true,
        visibility: CopyTradeVisibility.public,
      );
      var loadCalls = 0;
      var reloadFails = true;
      final gateway = _TestPrivacyGateway(
        onLoad: () async {
          if (loadCalls++ == 0) return local;
          if (reloadFails) {
            throw const PrivacyGatewayException(
              PrivacyGatewayFailureKind.unavailable,
            );
          }
          return remote;
        },
        onReplace: (_, _) async => throw const PrivacyGatewayException(
          PrivacyGatewayFailureKind.versionConflict,
        ),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(privacyControllerProvider.notifier);
      await controller.load();
      controller.editDiscoverable(true);
      controller.editCopyTradeVisibility(CopyTradeVisibility.followers);
      final draft = container.read(privacyControllerProvider).draft;

      await controller.save();
      var conflicted = container.read(privacyControllerProvider);
      expect(conflicted.phase, PrivacyPhase.conflict);
      expect(conflicted.failureCode, 'privacy_version_conflict');
      expect(conflicted.requiresReload, isTrue);
      expect(conflicted.resource, local);
      expect(conflicted.draft, draft);
      expect(conflicted.canEdit, isFalse);
      expect(conflicted.canSave, isFalse);
      expect(
        () => controller.editCopyTradeVisibility(CopyTradeVisibility.public),
        throwsStateError,
      );

      await controller.reload();
      conflicted = container.read(privacyControllerProvider);
      expect(conflicted.phase, PrivacyPhase.conflict);
      expect(conflicted.failureCode, 'privacy_unavailable');
      expect(conflicted.requiresReload, isTrue);
      expect(conflicted.resource, local);
      expect(conflicted.draft, draft);

      controller.discard();
      expect(container.read(privacyControllerProvider).draft, draft);
      await controller.save();
      expect(gateway.replaceCalls, 1);

      reloadFails = false;
      await controller.reload();
      final reloaded = container.read(privacyControllerProvider);
      expect(reloaded.phase, PrivacyPhase.ready);
      expect(reloaded.requiresReload, isFalse);
      expect(reloaded.resource, remote);
      expect(reloaded.draft, remote.values);
    });

    test('mismatched and non-advancing save responses fail closed', () async {
      final loaded = _resource(4);
      var mismatchValues = true;
      final gateway = _TestPrivacyGateway(
        onLoad: () async => loaded,
        onReplace: (_, values) async => mismatchValues
            ? _resource(5, visibility: CopyTradeVisibility.public)
            : PrivacyResource(
                version: 4,
                values: values,
                updatedAt: DateTime.utc(2026, 8, 25, 5),
              ),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(privacyControllerProvider.notifier);
      await controller.load();
      controller.editDiscoverable(true);
      final draft = container.read(privacyControllerProvider).draft;

      await controller.save();
      var failed = container.read(privacyControllerProvider);
      expect(failed.phase, PrivacyPhase.failure);
      expect(failed.failureKind, PrivacyGatewayFailureKind.invalidData);
      expect(failed.resource, loaded);
      expect(failed.draft, draft);

      mismatchValues = false;
      await controller.save();
      failed = container.read(privacyControllerProvider);
      expect(failed.phase, PrivacyPhase.failure);
      expect(failed.failureKind, PrivacyGatewayFailureKind.invalidData);
      expect(failed.resource, loaded);
      expect(failed.draft, draft);
    });

    test('an ambiguous save retries the same version and converges', () async {
      final memory = MemoryPrivacyGateway(
        clock: () => DateTime.utc(2026, 8, 25, 6),
      );
      var firstReplace = true;
      final gateway = _TestPrivacyGateway(
        onLoad: memory.load,
        onReplace: (expectedVersion, values) async {
          final committed = await memory.replace(
            expectedVersion: expectedVersion,
            values: values,
          );
          if (firstReplace) {
            firstReplace = false;
            throw const PrivacyGatewayException(
              PrivacyGatewayFailureKind.unavailable,
            );
          }
          return committed;
        },
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(privacyControllerProvider.notifier);
      await controller.load();
      controller.editDiscoverable(true);

      await controller.save();
      final ambiguous = container.read(privacyControllerProvider);
      expect(ambiguous.phase, PrivacyPhase.failure);
      expect(ambiguous.resource!.version, 0);
      expect(ambiguous.isDirty, isTrue);

      await controller.save();
      final reconciled = container.read(privacyControllerProvider);
      expect(gateway.expectedVersions, <int>[0, 0]);
      expect(reconciled.phase, PrivacyPhase.ready);
      expect(reconciled.resource!.version, 1);
      expect(reconciled.isDirty, isFalse);
    });

    test(
      'gateway rotation retires old load and accepts only the new owner',
      () async {
        final oldLoad = Completer<PrivacyResource>();
        final newLoad = Completer<PrivacyResource>();
        final oldGateway = _TestPrivacyGateway(onLoad: () => oldLoad.future);
        final newGateway = _TestPrivacyGateway(
          mode: PrivacyMode.production,
          onLoad: () => newLoad.future,
        );
        final container = _container(oldGateway);
        addTearDown(container.dispose);
        final controller = container.read(privacyControllerProvider.notifier);

        final retired = controller.load();
        container.updateOverrides([
          privacyGatewayProvider.overrideWithValue(newGateway),
        ]);
        expect(
          container.read(privacyControllerProvider).mode,
          PrivacyMode.production,
        );
        expect(container.read(privacyControllerProvider).resource, isNull);

        final active = controller.load();
        expect(newGateway.loadCalls, 1);
        oldLoad.complete(_resource(1, discoverable: true));
        await retired;
        expect(container.read(privacyControllerProvider).resource, isNull);

        final stillActive = controller.load();
        expect(identical(active, stillActive), isTrue);
        final newResource = _resource(
          5,
          visibility: CopyTradeVisibility.followers,
        );
        newLoad.complete(newResource);
        await active;
        expect(container.read(privacyControllerProvider).resource, newResource);
      },
    );

    test(
      'gateway rotation retires an old save without clearing a new save',
      () async {
        final initial = _resource(1);
        final oldSave = Completer<PrivacyResource>();
        final oldGateway = _TestPrivacyGateway(
          onLoad: () async => initial,
          onReplace: (_, _) => oldSave.future,
        );
        final newInitial = _resource(
          9,
          visibility: CopyTradeVisibility.followers,
        );
        final newSave = Completer<PrivacyResource>();
        final newGateway = _TestPrivacyGateway(
          mode: PrivacyMode.production,
          onLoad: () async => newInitial,
          onReplace: (_, _) => newSave.future,
        );
        final container = _container(oldGateway);
        addTearDown(container.dispose);
        final controller = container.read(privacyControllerProvider.notifier);
        await controller.load();
        controller.editDiscoverable(true);
        final retired = controller.save();

        container.updateOverrides([
          privacyGatewayProvider.overrideWithValue(newGateway),
        ]);
        await controller.load();
        controller.editDiscoverable(true);
        final active = controller.save();

        oldSave.complete(_resource(2, discoverable: true));
        await retired;
        final stillActive = controller.save();
        expect(identical(active, stillActive), isTrue);
        expect(newGateway.replaceCalls, 1);

        final saved = _resource(
          10,
          discoverable: true,
          visibility: CopyTradeVisibility.followers,
        );
        newSave.complete(saved);
        await active;
        expect(container.read(privacyControllerProvider).resource, saved);
        expect(container.read(privacyControllerProvider).isDirty, isFalse);
      },
    );

    test('invalidation and disposal retire late work safely', () async {
      final invalidatedLoad = Completer<PrivacyResource>();
      final invalidatedGateway = _TestPrivacyGateway(
        onLoad: () => invalidatedLoad.future,
      );
      final container = _container(invalidatedGateway);
      final controller = container.read(privacyControllerProvider.notifier);
      final pending = controller.load();

      container.invalidate(privacyControllerProvider);
      expect(
        container.read(privacyControllerProvider).phase,
        PrivacyPhase.initial,
      );
      invalidatedLoad.complete(_resource(1, discoverable: true));
      await pending;
      expect(container.read(privacyControllerProvider).resource, isNull);
      container.dispose();

      final disposedLoad = Completer<PrivacyResource>();
      final disposedContainer = _container(
        _TestPrivacyGateway(onLoad: () => disposedLoad.future),
      );
      final disposedController = disposedContainer.read(
        privacyControllerProvider.notifier,
      );
      final disposedPending = disposedController.load();
      disposedContainer.dispose();
      disposedLoad.complete(_resource(2, discoverable: true));
      await expectLater(disposedPending, completes);
    });
  });
}

ProviderContainer _container(PrivacyGateway gateway) {
  return ProviderContainer(
    overrides: [privacyGatewayProvider.overrideWithValue(gateway)],
  );
}

PrivacyValues _values({
  bool discoverable = false,
  CopyTradeVisibility visibility = CopyTradeVisibility.private,
}) {
  return PrivacyValues(
    discoverable: discoverable,
    copyTradeVisibility: visibility,
  );
}

PrivacyResource _resource(
  int version, {
  bool discoverable = false,
  CopyTradeVisibility visibility = CopyTradeVisibility.private,
}) {
  return PrivacyResource(
    version: version,
    values: _values(discoverable: discoverable, visibility: visibility),
    updatedAt: version == 0 ? null : DateTime.utc(2026, 8, 25, 1, version % 60),
  );
}

Matcher _gatewayFailure(PrivacyGatewayFailureKind kind) {
  return isA<PrivacyGatewayException>().having(
    (error) => error.kind,
    'kind',
    kind,
  );
}

final class _TestPrivacyGateway implements PrivacyGateway {
  _TestPrivacyGateway({
    this.mode = PrivacyMode.preview,
    required this.onLoad,
    Future<PrivacyResource> Function(int expectedVersion, PrivacyValues values)?
    onReplace,
  }) : onReplace =
           onReplace ??
           ((_, _) async => throw const PrivacyGatewayException(
             PrivacyGatewayFailureKind.unavailable,
           ));

  @override
  final PrivacyMode mode;
  final Future<PrivacyResource> Function() onLoad;
  final Future<PrivacyResource> Function(
    int expectedVersion,
    PrivacyValues values,
  )
  onReplace;
  int loadCalls = 0;
  int replaceCalls = 0;
  final List<int> expectedVersions = <int>[];
  final List<PrivacyValues> candidates = <PrivacyValues>[];

  @override
  Future<PrivacyResource> load() {
    loadCalls += 1;
    return onLoad();
  }

  @override
  Future<PrivacyResource> replace({
    required int expectedVersion,
    required PrivacyValues values,
  }) {
    replaceCalls += 1;
    expectedVersions.add(expectedVersion);
    final copied = PrivacyValues.copyOf(values);
    candidates.add(copied);
    return onReplace(expectedVersion, copied);
  }
}
