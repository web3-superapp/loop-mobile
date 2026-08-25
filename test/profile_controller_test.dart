import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/integrations/personalization/memory_profile_gateway.dart';

void main() {
  group('MemoryProfileGateway', () {
    test('mirrors missing-row and deterministic replay semantics', () async {
      final now = DateTime.utc(2026, 8, 25, 4);
      var clockCalls = 0;
      final gateway = MemoryProfileGateway(
        clock: () {
          clockCalls += 1;
          return now;
        },
      );
      final defaults = ProfileValues.empty();

      expect(gateway.mode, ProfileMode.preview);
      expect(await gateway.load(), ProfileResource.empty());

      // A stale default request against an absent row is an identical read.
      expect(
        await gateway.replace(expectedVersion: 99, values: defaults),
        ProfileResource.empty(),
      );
      expect(clockCalls, 0);

      // Version zero explicitly creates a row even when values stay default.
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

      await expectLater(
        gateway.replace(expectedVersion: 0, values: _values('Different')),
        throwsA(
          isA<ProfileGatewayException>().having(
            (error) => error.kind,
            'kind',
            ProfileGatewayFailureKind.versionConflict,
          ),
        ),
      );

      final updated = await gateway.replace(
        expectedVersion: 1,
        values: _values('  Alice  ', avatarRef: 'avatar:alice/main'),
      );
      expect(updated.version, 2);
      expect(updated.values.alias, 'Alice');
      expect(updated.values.avatarRef, 'avatar:alice/main');

      final cleared = await gateway.replace(
        expectedVersion: 2,
        values: defaults,
      );
      expect(cleared.version, 3);
      expect(cleared.values, defaults);
      expect(cleared.updatedAt, isNotNull);
      expect(clockCalls, 3);
    });

    test(
      'serializes concurrent first writes through version semantics',
      () async {
        final sameGateway = MemoryProfileGateway();
        final same = _values('Alice');
        final sameResults = await Future.wait(<Future<ProfileResource>>[
          sameGateway.replace(expectedVersion: 0, values: same),
          sameGateway.replace(expectedVersion: 0, values: same),
        ]);
        expect(sameResults[0], sameResults[1]);
        expect(sameResults[0].version, 1);

        final differentGateway = MemoryProfileGateway();
        final first = differentGateway.replace(
          expectedVersion: 0,
          values: _values('Alice'),
        );
        final second = differentGateway.replace(
          expectedVersion: 0,
          values: _values('Bob'),
        );
        final secondExpectation = expectLater(
          second,
          throwsA(
            isA<ProfileGatewayException>().having(
              (error) => error.kind,
              'kind',
              ProfileGatewayFailureKind.versionConflict,
            ),
          ),
        );
        expect((await first).version, 1);
        await secondExpectation;
      },
    );

    test('fails closed at invalid and exhausted versions', () async {
      final values = _values('Alice');
      final maximum = ProfileResource(
        version: profileMaximumVersion,
        values: values,
        updatedAt: DateTime.utc(2026, 8, 25),
      );
      final gateway = MemoryProfileGateway(initialResource: maximum);

      expect(
        await gateway.replace(expectedVersion: 0, values: values),
        maximum,
      );
      await expectLater(
        gateway.replace(
          expectedVersion: profileMaximumVersion,
          values: _values('Bob'),
        ),
        throwsA(
          isA<ProfileGatewayException>().having(
            (error) => error.kind,
            'kind',
            ProfileGatewayFailureKind.unavailable,
          ),
        ),
      );
      await expectLater(
        gateway.replace(expectedVersion: -1, values: values),
        throwsA(
          isA<ProfileGatewayException>().having(
            (error) => error.kind,
            'kind',
            ProfileGatewayFailureKind.invalidData,
          ),
        ),
      );
    });
  });

  group('ProfileController', () {
    test('production defaults directly unavailable', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(profileControllerProvider);
      expect(initial.mode, ProfileMode.unavailable);
      expect(initial.phase, ProfilePhase.unavailable);
      expect(initial.resource, isNull);
      expect(initial.canEdit, isFalse);

      await container.read(profileControllerProvider.notifier).load();
      expect(
        container.read(profileControllerProvider).failureCode,
        'profile_unavailable',
      );
    });

    test(
      'loads, edits nullable Alias, preserves Avatar, and discards',
      () async {
        final initial = _resource(
          2,
          alias: 'Alice',
          avatarRef: 'avatar:alice/main',
        );
        final container = _container(
          MemoryProfileGateway(initialResource: initial),
        );
        addTearDown(container.dispose);
        final controller = container.read(profileControllerProvider.notifier);

        await controller.load();
        var state = container.read(profileControllerProvider);
        expect(state.phase, ProfilePhase.ready);
        expect(state.isDirty, isFalse);
        expect(state.expectedVersion, 2);

        controller.editAlias('  LOOP 昵称 😀  ');
        state = container.read(profileControllerProvider);
        expect(state.draft.alias, 'LOOP 昵称 😀');
        expect(state.draft.avatarRef, 'avatar:alice/main');
        expect(state.isDirty, isTrue);
        expect(state.canSave, isTrue);

        controller.editAlias(null);
        expect(container.read(profileControllerProvider).draft.alias, isNull);
        expect(
          container.read(profileControllerProvider).draft.avatarRef,
          'avatar:alice/main',
        );

        controller.discard();
        state = container.read(profileControllerProvider);
        expect(state.phase, ProfilePhase.ready);
        expect(state.draft, initial.values);
        expect(state.isDirty, isFalse);
      },
    );

    test(
      'invalid Alias leaves state untouched and does not echo input',
      () async {
        final container = _container(
          MemoryProfileGateway(initialResource: _resource(1, alias: 'Alice')),
        );
        addTearDown(container.dispose);
        final controller = container.read(profileControllerProvider.notifier);
        await controller.load();
        final before = container.read(profileControllerProvider);
        const invalid = 'safe\u202eevil';

        Object? failure;
        try {
          controller.editAlias(invalid);
        } catch (error) {
          failure = error;
        }
        expect(failure, isA<InvalidProfileContractException>());
        expect(failure.toString(), isNot(contains(invalid)));
        expect(container.read(profileControllerProvider), before);
      },
    );

    test(
      'repeated load preserves a dirty draft until explicit reload',
      () async {
        final first = _resource(1, alias: 'Alice');
        final second = _resource(2, alias: 'Remote');
        var next = first;
        final gateway = _TestProfileGateway(onLoad: () async => next);
        final container = _container(gateway);
        addTearDown(container.dispose);
        final controller = container.read(profileControllerProvider.notifier);

        await controller.load();
        controller.editAlias('Local');
        final draft = container.read(profileControllerProvider).draft;
        next = second;

        await controller.load();
        expect(gateway.loadCalls, 1);
        expect(container.read(profileControllerProvider).draft, draft);

        await controller.reload();
        expect(gateway.loadCalls, 2);
        expect(container.read(profileControllerProvider).resource, second);
        expect(container.read(profileControllerProvider).isDirty, isFalse);
      },
    );

    test('failed initial load can retry without exposing the error', () async {
      var shouldFail = true;
      final gateway = _TestProfileGateway(
        onLoad: () async {
          if (shouldFail) throw StateError('private transport detail');
          return ProfileResource.empty();
        },
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(profileControllerProvider.notifier);

      await controller.load();
      expect(
        container.read(profileControllerProvider).failureCode,
        'profile_request_failed',
      );
      expect(container.read(profileControllerProvider).resource, isNull);

      shouldFail = false;
      await controller.load();
      expect(
        container.read(profileControllerProvider).phase,
        ProfilePhase.ready,
      );
      expect(gateway.loadCalls, 2);
    });

    test('load and save are single-flight and save complete values', () async {
      final loadGate = Completer<ProfileResource>();
      final saveGate = Completer<ProfileResource>();
      final gateway = _TestProfileGateway(
        onLoad: () => loadGate.future,
        onReplace: (_, _) => saveGate.future,
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(profileControllerProvider.notifier);

      final firstLoad = controller.load();
      final secondLoad = controller.load();
      expect(identical(firstLoad, secondLoad), isTrue);
      expect(gateway.loadCalls, 1);
      expect(
        container.read(profileControllerProvider).phase,
        ProfilePhase.loading,
      );

      final loaded = _resource(
        7,
        alias: 'Alice',
        avatarRef: 'avatar:alice/main',
      );
      loadGate.complete(loaded);
      await firstLoad;

      await controller.save();
      expect(gateway.replaceCalls, 0);
      controller.editAlias('Bob');
      final firstSave = controller.save();
      final secondSave = controller.save();
      expect(identical(firstSave, secondSave), isTrue);
      expect(gateway.replaceCalls, 1);
      expect(gateway.expectedVersions, <int>[7]);
      expect(gateway.candidates.single.alias, 'Bob');
      expect(gateway.candidates.single.avatarRef, 'avatar:alice/main');
      expect(
        container.read(profileControllerProvider).phase,
        ProfilePhase.saving,
      );

      final reloadWhileSaving = controller.reload();
      expect(identical(reloadWhileSaving, firstSave), isTrue);
      expect(gateway.loadCalls, 1);
      expect(() => controller.editAlias('Blocked'), throwsStateError);
      controller.discard();
      expect(
        container.read(profileControllerProvider).phase,
        ProfilePhase.saving,
      );

      saveGate.complete(
        _resource(8, alias: 'Bob', avatarRef: 'avatar:alice/main'),
      );
      await firstSave;
      final saved = container.read(profileControllerProvider);
      expect(saved.phase, ProfilePhase.ready);
      expect(saved.resource!.version, 8);
      expect(saved.isDirty, isFalse);
    });

    test(
      'version conflict freezes both copies until reload succeeds',
      () async {
        final local = _resource(3, alias: 'Alice');
        final remote = _resource(4, alias: 'Remote');
        var loadCalls = 0;
        var reloadFails = true;
        final gateway = _TestProfileGateway(
          onLoad: () async {
            if (loadCalls++ == 0) return local;
            if (reloadFails) {
              throw const ProfileGatewayException(
                ProfileGatewayFailureKind.unavailable,
              );
            }
            return remote;
          },
          onReplace: (_, _) async => throw const ProfileGatewayException(
            ProfileGatewayFailureKind.versionConflict,
          ),
        );
        final container = _container(gateway);
        addTearDown(container.dispose);
        final controller = container.read(profileControllerProvider.notifier);
        await controller.load();
        controller.editAlias('Local draft');
        final draft = container.read(profileControllerProvider).draft;

        await controller.save();
        var conflicted = container.read(profileControllerProvider);
        expect(conflicted.phase, ProfilePhase.conflict);
        expect(conflicted.failureCode, 'profile_version_conflict');
        expect(conflicted.requiresReload, isTrue);
        expect(conflicted.resource, local);
        expect(conflicted.draft, draft);
        expect(conflicted.canEdit, isFalse);
        expect(conflicted.canSave, isFalse);
        expect(() => controller.editAlias('Blocked'), throwsStateError);

        await controller.reload();
        conflicted = container.read(profileControllerProvider);
        expect(conflicted.phase, ProfilePhase.conflict);
        expect(conflicted.failureCode, 'profile_unavailable');
        expect(conflicted.requiresReload, isTrue);
        expect(conflicted.resource, local);
        expect(conflicted.draft, draft);

        controller.discard();
        conflicted = container.read(profileControllerProvider);
        expect(conflicted.phase, ProfilePhase.conflict);
        expect(conflicted.draft, draft);
        expect(conflicted.isDirty, isTrue);
        expect(conflicted.requiresReload, isTrue);
        await controller.save();
        expect(gateway.replaceCalls, 1);

        reloadFails = false;
        await controller.reload();
        final reloaded = container.read(profileControllerProvider);
        expect(reloaded.phase, ProfilePhase.ready);
        expect(reloaded.requiresReload, isFalse);
        expect(reloaded.resource, remote);
        expect(reloaded.draft, remote.values);
      },
    );

    test('mismatched save response fails closed and keeps the draft', () async {
      final loaded = _resource(1, alias: 'Alice');
      final gateway = _TestProfileGateway(
        onLoad: () async => loaded,
        onReplace: (_, _) async => _resource(2, alias: 'Different'),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(profileControllerProvider.notifier);
      await controller.load();
      controller.editAlias('Local');
      final draft = container.read(profileControllerProvider).draft;

      await controller.save();
      final failed = container.read(profileControllerProvider);
      expect(failed.phase, ProfilePhase.failure);
      expect(failed.failureCode, 'invalid_profile_data');
      expect(failed.resource, loaded);
      expect(failed.draft, draft);
      expect(failed.canSave, isTrue);
    });

    test('non-advancing save response fails closed', () async {
      final loaded = _resource(4, alias: 'Alice');
      final gateway = _TestProfileGateway(
        onLoad: () async => loaded,
        onReplace: (_, values) async => ProfileResource(
          version: 4,
          values: values,
          updatedAt: DateTime.utc(2026, 8, 25, 5),
        ),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(profileControllerProvider.notifier);
      await controller.load();
      controller.editAlias('Bob');

      await controller.save();
      final failed = container.read(profileControllerProvider);
      expect(failed.phase, ProfilePhase.failure);
      expect(failed.failureKind, ProfileGatewayFailureKind.invalidData);
      expect(failed.resource, loaded);
      expect(failed.isDirty, isTrue);
    });

    test('an ambiguous save retries the same version and converges', () async {
      final memory = MemoryProfileGateway(
        clock: () => DateTime.utc(2026, 8, 25, 6),
      );
      var firstReplace = true;
      final gateway = _TestProfileGateway(
        onLoad: memory.load,
        onReplace: (expectedVersion, values) async {
          final committed = await memory.replace(
            expectedVersion: expectedVersion,
            values: values,
          );
          if (firstReplace) {
            firstReplace = false;
            throw const ProfileGatewayException(
              ProfileGatewayFailureKind.unavailable,
            );
          }
          return committed;
        },
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(profileControllerProvider.notifier);
      await controller.load();
      controller.editAlias('Alice');

      await controller.save();
      final ambiguous = container.read(profileControllerProvider);
      expect(ambiguous.phase, ProfilePhase.failure);
      expect(ambiguous.resource!.version, 0);
      expect(ambiguous.isDirty, isTrue);

      await controller.save();
      final reconciled = container.read(profileControllerProvider);
      expect(gateway.expectedVersions, <int>[0, 0]);
      expect(reconciled.phase, ProfilePhase.ready);
      expect(reconciled.resource!.version, 1);
      expect(reconciled.isDirty, isFalse);
    });

    test(
      'gateway rotation retires old load and preserves new single-flight',
      () async {
        final oldLoad = Completer<ProfileResource>();
        final newLoad = Completer<ProfileResource>();
        final oldGateway = _TestProfileGateway(onLoad: () => oldLoad.future);
        final newGateway = _TestProfileGateway(
          mode: ProfileMode.production,
          onLoad: () => newLoad.future,
        );
        final container = _container(oldGateway);
        addTearDown(container.dispose);
        final controller = container.read(profileControllerProvider.notifier);

        final retired = controller.load();
        container.updateOverrides([
          profileGatewayProvider.overrideWithValue(newGateway),
        ]);
        expect(
          container.read(profileControllerProvider).mode,
          ProfileMode.production,
        );

        final active = controller.load();
        expect(newGateway.loadCalls, 1);
        oldLoad.completeError(
          const ProfileGatewayException(ProfileGatewayFailureKind.unavailable),
        );
        await retired;

        final stillActive = controller.load();
        expect(identical(active, stillActive), isTrue);
        expect(newGateway.loadCalls, 1);
        final newResource = _resource(5, alias: 'New account');
        newLoad.complete(newResource);
        await active;
        expect(container.read(profileControllerProvider).resource, newResource);
      },
    );

    test(
      'gateway rotation retires old save without clearing new save',
      () async {
        final initial = _resource(1, alias: 'Old');
        final oldSave = Completer<ProfileResource>();
        final oldGateway = _TestProfileGateway(
          onLoad: () async => initial,
          onReplace: (_, _) => oldSave.future,
        );
        final newInitial = _resource(9, alias: 'New');
        final newSave = Completer<ProfileResource>();
        final newGateway = _TestProfileGateway(
          mode: ProfileMode.production,
          onLoad: () async => newInitial,
          onReplace: (_, _) => newSave.future,
        );
        final container = _container(oldGateway);
        addTearDown(container.dispose);
        final controller = container.read(profileControllerProvider.notifier);
        await controller.load();
        controller.editAlias('Old draft');
        final retired = controller.save();

        container.updateOverrides([
          profileGatewayProvider.overrideWithValue(newGateway),
        ]);
        await controller.load();
        controller.editAlias('New draft');
        final active = controller.save();

        oldSave.complete(_resource(2, alias: 'Old draft'));
        await retired;
        final stillActive = controller.save();
        expect(identical(active, stillActive), isTrue);
        expect(newGateway.replaceCalls, 1);

        final saved = _resource(10, alias: 'New draft');
        newSave.complete(saved);
        await active;
        expect(container.read(profileControllerProvider).resource, saved);
        expect(container.read(profileControllerProvider).isDirty, isFalse);
      },
    );

    test('invalidating the provider rejects late publication', () async {
      final loadGate = Completer<ProfileResource>();
      final gateway = _TestProfileGateway(onLoad: () => loadGate.future);
      final container = _container(gateway);
      final controller = container.read(profileControllerProvider.notifier);
      final pending = controller.load();

      container.invalidate(profileControllerProvider);
      expect(
        container.read(profileControllerProvider).phase,
        ProfilePhase.initial,
      );
      loadGate.complete(_resource(1, alias: 'Late'));
      await pending;
      expect(container.read(profileControllerProvider).resource, isNull);
      container.dispose();
    });
  });
}

ProviderContainer _container(ProfileGateway gateway) {
  return ProviderContainer(
    overrides: [profileGatewayProvider.overrideWithValue(gateway)],
  );
}

ProfileValues _values(String? alias, {String? avatarRef}) {
  return ProfileValues(alias: alias, avatarRef: avatarRef);
}

ProfileResource _resource(
  int version, {
  required String? alias,
  String? avatarRef,
}) {
  return ProfileResource(
    version: version,
    values: _values(alias, avatarRef: avatarRef),
    updatedAt: version == 0 ? null : DateTime.utc(2026, 8, 25, 1, version % 60),
  );
}

final class _TestProfileGateway implements ProfileGateway {
  _TestProfileGateway({
    this.mode = ProfileMode.preview,
    required this.onLoad,
    Future<ProfileResource> Function(int expectedVersion, ProfileValues values)?
    onReplace,
  }) : onReplace =
           onReplace ??
           ((_, _) async => throw const ProfileGatewayException(
             ProfileGatewayFailureKind.unavailable,
           ));

  @override
  final ProfileMode mode;
  final Future<ProfileResource> Function() onLoad;
  final Future<ProfileResource> Function(
    int expectedVersion,
    ProfileValues values,
  )
  onReplace;
  int loadCalls = 0;
  int replaceCalls = 0;
  final List<int> expectedVersions = <int>[];
  final List<ProfileValues> candidates = <ProfileValues>[];

  @override
  Future<ProfileResource> load() {
    loadCalls += 1;
    return onLoad();
  }

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) {
    replaceCalls += 1;
    expectedVersions.add(expectedVersion);
    final copied = ProfileValues.copyOf(values);
    candidates.add(copied);
    return onReplace(expectedVersion, copied);
  }
}
