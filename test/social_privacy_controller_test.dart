import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_controller.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_models.dart';
import 'package:loop_mobile/integrations/personalization/memory_social_privacy_gateway.dart';

void main() {
  group('MemorySocialPrivacyGateway', () {
    test('mirrors first-write and identical-retry semantics', () async {
      final now = DateTime.utc(2026, 8, 31, 4);
      var clockCalls = 0;
      final gateway = MemorySocialPrivacyGateway(
        clock: () {
          clockCalls += 1;
          return now;
        },
      );
      const defaults = SocialPrivacyValues.defaults();

      expect(gateway.mode, SocialPrivacyMode.preview);
      expect(await gateway.load(), SocialPrivacyResource.empty());
      expect(
        await gateway.replace(expectedVersion: 99, values: defaults),
        SocialPrivacyResource.empty(),
      );
      expect(clockCalls, 0);

      final created = await gateway.replace(
        expectedVersion: 0,
        values: defaults,
      );
      expect(created.version, 1);
      expect(created.updatedAt, now);
      expect(clockCalls, 1);

      expect(
        await gateway.replace(expectedVersion: 0, values: defaults),
        created,
      );
      expect(clockCalls, 1);

      final updated = await gateway.replace(
        expectedVersion: 1,
        values: _values(friendRequestsEnabled: true, groupInvites: true),
      );
      expect(updated.version, 2);
      expect(updated.values.friendRequests, FriendRequestsPreference.enabled);
      expect(updated.values.groupInvites, GroupInvitesPreference.friends);
      expect(clockCalls, 2);
    });

    test('rejects stale different values and exhausted versions', () async {
      final gateway = MemorySocialPrivacyGateway();
      await gateway.replace(
        expectedVersion: 0,
        values: _values(friendRequestsEnabled: true),
      );
      await expectLater(
        gateway.replace(
          expectedVersion: 0,
          values: _values(directMessages: true),
        ),
        throwsA(
          _gatewayFailure(SocialPrivacyGatewayFailureKind.versionConflict),
        ),
      );

      final maximum = _resource(
        socialPrivacyMaximumVersion,
        friendRequestsEnabled: true,
      );
      final exhausted = MemorySocialPrivacyGateway(initialResource: maximum);
      await expectLater(
        exhausted.replace(
          expectedVersion: socialPrivacyMaximumVersion,
          values: _values(groupInvites: true),
        ),
        throwsA(_gatewayFailure(SocialPrivacyGatewayFailureKind.unavailable)),
      );
      await expectLater(
        exhausted.replace(expectedVersion: -1, values: maximum.values),
        throwsA(_gatewayFailure(SocialPrivacyGatewayFailureKind.invalidData)),
      );
    });
  });

  group('SocialPrivacyController', () {
    test('production defaults directly unavailable', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(socialPrivacyControllerProvider);
      expect(initial.mode, SocialPrivacyMode.unavailable);
      expect(initial.phase, SocialPrivacyPhase.unavailable);
      expect(initial.resource, isNull);
      expect(initial.draft, const SocialPrivacyValues.defaults());
      expect(initial.canEdit, isFalse);

      await container.read(socialPrivacyControllerProvider.notifier).load();
      expect(
        container.read(socialPrivacyControllerProvider).failureCode,
        'social_privacy_unavailable',
      );
    });

    test('loads, edits the complete fixed set, and discards', () async {
      final initial = _resource(2, groupInvites: true);
      final container = _container(
        MemorySocialPrivacyGateway(initialResource: initial),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        socialPrivacyControllerProvider.notifier,
      );

      await controller.load();
      controller.editFriendRequests(FriendRequestsPreference.enabled);
      controller.editGroupInvites(GroupInvitesPreference.disabled);
      controller.editDirectMessages(DirectMessagesPreference.friends);
      var state = container.read(socialPrivacyControllerProvider);
      expect(state.expectedVersion, 2);
      expect(state.isDirty, isTrue);
      expect(state.canSave, isTrue);
      expect(state.draft.friendRequests, FriendRequestsPreference.enabled);
      expect(state.draft.groupInvites, GroupInvitesPreference.disabled);
      expect(state.draft.directMessages, DirectMessagesPreference.friends);

      controller.discard();
      state = container.read(socialPrivacyControllerProvider);
      expect(state.phase, SocialPrivacyPhase.ready);
      expect(state.draft, initial.values);
      expect(state.isDirty, isFalse);
    });

    test('load and save are single-flight and save complete values', () async {
      final loadGate = Completer<SocialPrivacyResource>();
      final saveGate = Completer<SocialPrivacyResource>();
      final gateway = _TestSocialPrivacyGateway(
        onLoad: () => loadGate.future,
        onReplace: (_, _) => saveGate.future,
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(
        socialPrivacyControllerProvider.notifier,
      );

      final firstLoad = controller.load();
      expect(identical(firstLoad, controller.load()), isTrue);
      expect(gateway.loadCalls, 1);
      loadGate.complete(_resource(7, groupInvites: true));
      await firstLoad;

      controller.editFriendRequests(FriendRequestsPreference.enabled);
      final firstSave = controller.save();
      expect(identical(firstSave, controller.save()), isTrue);
      expect(gateway.replaceCalls, 1);
      expect(gateway.expectedVersions, <int>[7]);
      expect(
        gateway.candidates.single.groupInvites,
        GroupInvitesPreference.friends,
      );
      expect(identical(controller.reload(), firstSave), isTrue);
      expect(
        () => controller.editDirectMessages(DirectMessagesPreference.friends),
        throwsStateError,
      );

      saveGate.complete(
        _resource(8, friendRequestsEnabled: true, groupInvites: true),
      );
      await firstSave;
      final saved = container.read(socialPrivacyControllerProvider);
      expect(saved.phase, SocialPrivacyPhase.ready);
      expect(saved.resource!.version, 8);
      expect(saved.isDirty, isFalse);
    });

    test('version conflict freezes the draft until reload succeeds', () async {
      final local = _resource(3);
      final remote = _resource(4, directMessages: true);
      var loadCalls = 0;
      var reloadFails = true;
      final gateway = _TestSocialPrivacyGateway(
        onLoad: () async {
          if (loadCalls++ == 0) return local;
          if (reloadFails) {
            throw const SocialPrivacyGatewayException(
              SocialPrivacyGatewayFailureKind.unavailable,
            );
          }
          return remote;
        },
        onReplace: (_, _) async => throw const SocialPrivacyGatewayException(
          SocialPrivacyGatewayFailureKind.versionConflict,
        ),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(
        socialPrivacyControllerProvider.notifier,
      );
      await controller.load();
      controller.editFriendRequests(FriendRequestsPreference.enabled);
      final draft = container.read(socialPrivacyControllerProvider).draft;

      await controller.save();
      var conflicted = container.read(socialPrivacyControllerProvider);
      expect(conflicted.phase, SocialPrivacyPhase.conflict);
      expect(conflicted.failureCode, 'social_privacy_version_conflict');
      expect(conflicted.requiresReload, isTrue);
      expect(conflicted.draft, draft);
      expect(conflicted.canEdit, isFalse);

      await controller.reload();
      conflicted = container.read(socialPrivacyControllerProvider);
      expect(conflicted.phase, SocialPrivacyPhase.conflict);
      expect(conflicted.failureCode, 'social_privacy_unavailable');
      expect(conflicted.requiresReload, isTrue);

      reloadFails = false;
      await controller.reload();
      final reloaded = container.read(socialPrivacyControllerProvider);
      expect(reloaded.phase, SocialPrivacyPhase.ready);
      expect(reloaded.requiresReload, isFalse);
      expect(reloaded.resource, remote);
      expect(reloaded.draft, remote.values);
    });

    test('mismatched and non-advancing save responses fail closed', () async {
      final loaded = _resource(4);
      var mismatch = true;
      final gateway = _TestSocialPrivacyGateway(
        onLoad: () async => loaded,
        onReplace: (_, values) async => mismatch
            ? _resource(5, groupInvites: true)
            : SocialPrivacyResource(
                version: 4,
                values: values,
                updatedAt: DateTime.utc(2026, 8, 31, 5),
              ),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(
        socialPrivacyControllerProvider.notifier,
      );
      await controller.load();
      controller.editFriendRequests(FriendRequestsPreference.enabled);
      final draft = container.read(socialPrivacyControllerProvider).draft;

      await controller.save();
      var failed = container.read(socialPrivacyControllerProvider);
      expect(failed.failureKind, SocialPrivacyGatewayFailureKind.invalidData);
      expect(failed.resource, loaded);
      expect(failed.draft, draft);

      mismatch = false;
      await controller.save();
      failed = container.read(socialPrivacyControllerProvider);
      expect(failed.failureKind, SocialPrivacyGatewayFailureKind.invalidData);
      expect(failed.resource, loaded);
      expect(failed.draft, draft);
    });

    test('an ambiguous save retries the same version and converges', () async {
      final memory = MemorySocialPrivacyGateway();
      var firstReplace = true;
      final gateway = _TestSocialPrivacyGateway(
        onLoad: memory.load,
        onReplace: (expectedVersion, values) async {
          final committed = await memory.replace(
            expectedVersion: expectedVersion,
            values: values,
          );
          if (firstReplace) {
            firstReplace = false;
            throw const SocialPrivacyGatewayException(
              SocialPrivacyGatewayFailureKind.unavailable,
            );
          }
          return committed;
        },
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(
        socialPrivacyControllerProvider.notifier,
      );
      await controller.load();
      controller.editDirectMessages(DirectMessagesPreference.friends);

      await controller.save();
      expect(
        container.read(socialPrivacyControllerProvider).phase,
        SocialPrivacyPhase.failure,
      );
      await controller.save();
      final reconciled = container.read(socialPrivacyControllerProvider);
      expect(gateway.expectedVersions, <int>[0, 0]);
      expect(reconciled.phase, SocialPrivacyPhase.ready);
      expect(reconciled.resource!.version, 1);
      expect(reconciled.isDirty, isFalse);
    });

    test(
      'gateway rotation retires old load and accepts only the new owner',
      () async {
        final oldLoad = Completer<SocialPrivacyResource>();
        final newLoad = Completer<SocialPrivacyResource>();
        final oldGateway = _TestSocialPrivacyGateway(
          onLoad: () => oldLoad.future,
        );
        final newGateway = _TestSocialPrivacyGateway(
          mode: SocialPrivacyMode.production,
          onLoad: () => newLoad.future,
        );
        final container = _container(oldGateway);
        addTearDown(container.dispose);
        final controller = container.read(
          socialPrivacyControllerProvider.notifier,
        );

        final retired = controller.load();
        container.updateOverrides([
          socialPrivacyGatewayProvider.overrideWithValue(newGateway),
        ]);
        expect(
          container.read(socialPrivacyControllerProvider).mode,
          SocialPrivacyMode.production,
        );
        expect(
          container.read(socialPrivacyControllerProvider).resource,
          isNull,
        );

        final active = controller.load();
        oldLoad.complete(_resource(1, friendRequestsEnabled: true));
        await retired;
        expect(
          container.read(socialPrivacyControllerProvider).resource,
          isNull,
        );

        expect(identical(active, controller.load()), isTrue);
        final newResource = _resource(5, groupInvites: true);
        newLoad.complete(newResource);
        await active;
        expect(
          container.read(socialPrivacyControllerProvider).resource,
          newResource,
        );
      },
    );

    test(
      'gateway rotation retires an old save without clearing a new save',
      () async {
        final oldSave = Completer<SocialPrivacyResource>();
        final oldGateway = _TestSocialPrivacyGateway(
          onLoad: () async => _resource(1),
          onReplace: (_, _) => oldSave.future,
        );
        final newSave = Completer<SocialPrivacyResource>();
        final newGateway = _TestSocialPrivacyGateway(
          mode: SocialPrivacyMode.production,
          onLoad: () async => _resource(9, groupInvites: true),
          onReplace: (_, _) => newSave.future,
        );
        final container = _container(oldGateway);
        addTearDown(container.dispose);
        final controller = container.read(
          socialPrivacyControllerProvider.notifier,
        );
        await controller.load();
        controller.editFriendRequests(FriendRequestsPreference.enabled);
        final retired = controller.save();

        container.updateOverrides([
          socialPrivacyGatewayProvider.overrideWithValue(newGateway),
        ]);
        await controller.load();
        controller.editDirectMessages(DirectMessagesPreference.friends);
        final active = controller.save();

        oldSave.complete(_resource(2, friendRequestsEnabled: true));
        await retired;
        expect(identical(active, controller.save()), isTrue);
        expect(newGateway.replaceCalls, 1);

        final saved = _resource(10, groupInvites: true, directMessages: true);
        newSave.complete(saved);
        await active;
        expect(container.read(socialPrivacyControllerProvider).resource, saved);
      },
    );

    test('invalidation and disposal retire late work safely', () async {
      final invalidatedLoad = Completer<SocialPrivacyResource>();
      final container = _container(
        _TestSocialPrivacyGateway(onLoad: () => invalidatedLoad.future),
      );
      final controller = container.read(
        socialPrivacyControllerProvider.notifier,
      );
      final pending = controller.load();

      container.invalidate(socialPrivacyControllerProvider);
      expect(
        container.read(socialPrivacyControllerProvider).phase,
        SocialPrivacyPhase.initial,
      );
      invalidatedLoad.complete(_resource(1, friendRequestsEnabled: true));
      await pending;
      expect(container.read(socialPrivacyControllerProvider).resource, isNull);
      container.dispose();

      final disposedLoad = Completer<SocialPrivacyResource>();
      final disposedContainer = _container(
        _TestSocialPrivacyGateway(onLoad: () => disposedLoad.future),
      );
      final disposedController = disposedContainer.read(
        socialPrivacyControllerProvider.notifier,
      );
      final disposedPending = disposedController.load();
      disposedContainer.dispose();
      disposedLoad.complete(_resource(2, directMessages: true));
      await expectLater(disposedPending, completes);
    });
  });
}

ProviderContainer _container(SocialPrivacyGateway gateway) {
  return ProviderContainer(
    overrides: [socialPrivacyGatewayProvider.overrideWithValue(gateway)],
  );
}

SocialPrivacyValues _values({
  bool friendRequestsEnabled = false,
  bool groupInvites = false,
  bool directMessages = false,
}) {
  return SocialPrivacyValues(
    friendRequests: friendRequestsEnabled
        ? FriendRequestsPreference.enabled
        : FriendRequestsPreference.disabled,
    groupInvites: groupInvites
        ? GroupInvitesPreference.friends
        : GroupInvitesPreference.disabled,
    directMessages: directMessages
        ? DirectMessagesPreference.friends
        : DirectMessagesPreference.disabled,
  );
}

SocialPrivacyResource _resource(
  int version, {
  bool friendRequestsEnabled = false,
  bool groupInvites = false,
  bool directMessages = false,
}) {
  return SocialPrivacyResource(
    version: version,
    values: _values(
      friendRequestsEnabled: friendRequestsEnabled,
      groupInvites: groupInvites,
      directMessages: directMessages,
    ),
    updatedAt: version == 0 ? null : DateTime.utc(2026, 8, 31, 1, version % 60),
  );
}

Matcher _gatewayFailure(SocialPrivacyGatewayFailureKind kind) {
  return isA<SocialPrivacyGatewayException>().having(
    (error) => error.kind,
    'kind',
    kind,
  );
}

final class _TestSocialPrivacyGateway implements SocialPrivacyGateway {
  _TestSocialPrivacyGateway({
    this.mode = SocialPrivacyMode.preview,
    required this.onLoad,
    Future<SocialPrivacyResource> Function(
      int expectedVersion,
      SocialPrivacyValues values,
    )?
    onReplace,
  }) : onReplace =
           onReplace ??
           ((_, _) async => throw const SocialPrivacyGatewayException(
             SocialPrivacyGatewayFailureKind.unavailable,
           ));

  @override
  final SocialPrivacyMode mode;
  final Future<SocialPrivacyResource> Function() onLoad;
  final Future<SocialPrivacyResource> Function(
    int expectedVersion,
    SocialPrivacyValues values,
  )
  onReplace;
  int loadCalls = 0;
  int replaceCalls = 0;
  final List<int> expectedVersions = <int>[];
  final List<SocialPrivacyValues> candidates = <SocialPrivacyValues>[];

  @override
  Future<SocialPrivacyResource> load() {
    loadCalls += 1;
    return onLoad();
  }

  @override
  Future<SocialPrivacyResource> replace({
    required int expectedVersion,
    required SocialPrivacyValues values,
  }) {
    replaceCalls += 1;
    expectedVersions.add(expectedVersion);
    final copied = SocialPrivacyValues.copyOf(values);
    candidates.add(copied);
    return onReplace(expectedVersion, copied);
  }
}
