import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_controller.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/integrations/personalization/memory_watchlist_gateway.dart';

void main() {
  group('MemoryWatchlistGateway', () {
    test(
      'is explicit Preview state and mirrors optimistic replacement',
      () async {
        final now = DateTime.utc(2026, 8, 25, 4);
        var clockCalls = 0;
        final gateway = MemoryWatchlistGateway(
          clock: () {
            clockCalls += 1;
            return now;
          },
        );
        final favorites = _group('favorites', <String>['ETH', 'BTC']);

        expect(gateway.mode, WatchlistMode.preview);
        expect(await gateway.load(), WatchlistSnapshot.empty());
        expect(
          await gateway.replace(expectedVersion: 99, groups: const []),
          WatchlistSnapshot.empty(),
        );
        expect(clockCalls, 0);

        final committed = await gateway.replace(
          expectedVersion: 0,
          groups: <WatchlistGroup>[favorites],
        );
        expect(committed.version, 1);
        expect(committed.updatedAt, now);
        expect(committed.groups, <WatchlistGroup>[favorites]);
        expect(clockCalls, 1);

        final identicalStaleRetry = await gateway.replace(
          expectedVersion: 0,
          groups: <WatchlistGroup>[favorites],
        );
        expect(identicalStaleRetry, committed);

        await expectLater(
          gateway.replace(
            expectedVersion: 0,
            groups: <WatchlistGroup>[
              _group('favorites', <String>['SOL']),
            ],
          ),
          throwsA(
            isA<WatchlistGatewayException>().having(
              (error) => error.kind,
              'kind',
              WatchlistGatewayFailureKind.versionConflict,
            ),
          ),
        );
        expect(await gateway.load(), committed);

        final cleared = await gateway.replace(
          expectedVersion: committed.version,
          groups: const [],
        );
        expect(cleared.version, 2);
        expect(cleared.groups, isEmpty);
        expect(cleared.updatedAt, now);
        expect(clockCalls, 2);
      },
    );

    test('fails closed at invalid and exhausted versions', () async {
      final group = _group('favorites', <String>['ETH']);
      final maximum = WatchlistSnapshot(
        version: watchlistMaximumVersion,
        groups: <WatchlistGroup>[group],
        updatedAt: DateTime.utc(2026, 8, 25),
      );
      final gateway = MemoryWatchlistGateway(initialSnapshot: maximum);

      expect(
        await gateway.replace(
          expectedVersion: 0,
          groups: <WatchlistGroup>[group],
        ),
        maximum,
      );
      await expectLater(
        gateway.replace(
          expectedVersion: watchlistMaximumVersion,
          groups: const [],
        ),
        throwsA(
          isA<WatchlistGatewayException>().having(
            (error) => error.kind,
            'kind',
            WatchlistGatewayFailureKind.unavailable,
          ),
        ),
      );
      await expectLater(
        gateway.replace(expectedVersion: -1, groups: const []),
        throwsA(
          isA<WatchlistGatewayException>().having(
            (error) => error.kind,
            'kind',
            WatchlistGatewayFailureKind.invalidData,
          ),
        ),
      );
    });
  });

  group('WatchlistController', () {
    test('production defaults directly unavailable', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(watchlistControllerProvider);
      expect(initial.mode, WatchlistMode.unavailable);
      expect(initial.phase, WatchlistPhase.unavailable);
      expect(initial.snapshot, isNull);

      await container.read(watchlistControllerProvider.notifier).load();
      expect(
        container.read(watchlistControllerProvider).failureCode,
        'watchlist_unavailable',
      );
    });

    test(
      'loads, edits, reorders, removes, and discards a complete draft',
      () async {
        final initial = _snapshot(2, <WatchlistGroup>[
          _group('favorites', <String>['ETH', 'BTC']),
          _group('alts', <String>['SOL']),
        ]);
        final gateway = MemoryWatchlistGateway(initialSnapshot: initial);
        final container = _container(gateway);
        addTearDown(container.dispose);
        final controller = container.read(watchlistControllerProvider.notifier);

        await controller.load();
        expect(
          container.read(watchlistControllerProvider).phase,
          WatchlistPhase.ready,
        );

        controller.editGroup(groupKey: 'favorites', name: '  Core  ');
        controller.reorderItem(groupKey: 'favorites', fromIndex: 1, toIndex: 0);
        controller.addItem(
          groupKey: 'alts',
          item: WatchlistItem(assetKey: 'DOGE'),
        );
        controller.removeItem(groupKey: 'alts', assetKey: 'SOL');
        controller.addGroup(_group('research', <String>['ETH:PERP']));
        controller.reorderGroup(fromIndex: 2, toIndex: 0);
        controller.removeGroup('alts');

        final edited = container.read(watchlistControllerProvider);
        expect(edited.isDirty, isTrue);
        expect(edited.canSave, isTrue);
        expect(edited.expectedVersion, 2);
        expect(edited.draftGroups.map((group) => group.key), <String>[
          'research',
          'favorites',
        ]);
        expect(edited.draftGroups[1].name, 'Core');
        expect(
          edited.draftGroups[1].items.map((item) => item.assetKey),
          <String>['BTC', 'ETH'],
        );

        controller.discard();
        final discarded = container.read(watchlistControllerProvider);
        expect(discarded.phase, WatchlistPhase.ready);
        expect(discarded.isDirty, isFalse);
        expect(discarded.draftGroups, initial.groups);
      },
    );

    test(
      'invalid edits leave the existing immutable draft untouched',
      () async {
        final gateway = MemoryWatchlistGateway(
          initialSnapshot: _snapshot(1, <WatchlistGroup>[
            _group('favorites', <String>['ETH']),
          ]),
        );
        final container = _container(gateway);
        addTearDown(container.dispose);
        final controller = container.read(watchlistControllerProvider.notifier);
        await controller.load();
        final before = container.read(watchlistControllerProvider);

        expect(
          () => controller.addItem(
            groupKey: 'favorites',
            item: WatchlistItem(assetKey: 'ETH'),
          ),
          throwsA(isA<InvalidWatchlistContractException>()),
        );
        expect(
          () => controller.editGroup(
            groupKey: 'favorites',
            name: 'safe\u202eevil',
          ),
          throwsA(isA<InvalidWatchlistContractException>()),
        );
        expect(container.read(watchlistControllerProvider), before);
      },
    );

    test(
      'repeated load preserves a dirty draft until explicit reload',
      () async {
        final first = _snapshot(1, <WatchlistGroup>[
          _group('favorites', <String>['ETH']),
        ]);
        final second = _snapshot(2, <WatchlistGroup>[
          _group('favorites', <String>['SOL']),
        ]);
        var next = first;
        final gateway = _TestWatchlistGateway(onLoad: () async => next);
        final container = _container(gateway);
        addTearDown(container.dispose);
        final controller = container.read(watchlistControllerProvider.notifier);
        await controller.load();
        controller.addItem(
          groupKey: 'favorites',
          item: WatchlistItem(assetKey: 'BTC'),
        );
        final draft = container.read(watchlistControllerProvider).draftGroups;
        next = second;

        await controller.load();
        expect(gateway.loadCalls, 1);
        expect(container.read(watchlistControllerProvider).draftGroups, draft);

        await controller.reload();
        expect(gateway.loadCalls, 2);
        expect(container.read(watchlistControllerProvider).snapshot, second);
        expect(container.read(watchlistControllerProvider).isDirty, isFalse);
      },
    );

    test(
      'load and save are each single-flight and save expected version',
      () async {
        final loadGate = Completer<WatchlistSnapshot>();
        final saveGate = Completer<WatchlistSnapshot>();
        final gateway = _TestWatchlistGateway(
          onLoad: () => loadGate.future,
          onReplace: (_, _) => saveGate.future,
        );
        final container = _container(gateway);
        addTearDown(container.dispose);
        final controller = container.read(watchlistControllerProvider.notifier);

        final firstLoad = controller.load();
        final secondLoad = controller.load();
        expect(identical(firstLoad, secondLoad), isTrue);
        expect(gateway.loadCalls, 1);
        expect(
          container.read(watchlistControllerProvider).phase,
          WatchlistPhase.loading,
        );

        final loaded = _snapshot(7, <WatchlistGroup>[
          _group('favorites', <String>['ETH']),
        ]);
        loadGate.complete(loaded);
        await firstLoad;

        controller.addItem(
          groupKey: 'favorites',
          item: WatchlistItem(assetKey: 'BTC'),
        );
        final firstSave = controller.save();
        final secondSave = controller.save();
        expect(identical(firstSave, secondSave), isTrue);
        expect(gateway.replaceCalls, 1);
        expect(gateway.expectedVersions, <int>[7]);
        expect(
          container.read(watchlistControllerProvider).phase,
          WatchlistPhase.saving,
        );
        final reloadWhileSaving = controller.reload();
        expect(identical(reloadWhileSaving, firstSave), isTrue);
        expect(gateway.loadCalls, 1);
        expect(() => controller.removeGroup('favorites'), throwsStateError);
        controller.discard();
        expect(
          container.read(watchlistControllerProvider).phase,
          WatchlistPhase.saving,
        );

        saveGate.complete(
          _snapshot(8, <WatchlistGroup>[
            _group('favorites', <String>['ETH', 'BTC']),
          ]),
        );
        await firstSave;
        final saved = container.read(watchlistControllerProvider);
        expect(saved.phase, WatchlistPhase.ready);
        expect(saved.snapshot!.version, 8);
        expect(saved.isDirty, isFalse);
      },
    );

    test(
      'version conflict preserves both copies and requires reload',
      () async {
        final local = _snapshot(3, <WatchlistGroup>[
          _group('favorites', <String>['ETH']),
        ]);
        final remote = _snapshot(4, <WatchlistGroup>[
          _group('favorites', <String>['SOL']),
        ]);
        var loadCalls = 0;
        var reloadFails = true;
        final gateway = _TestWatchlistGateway(
          onLoad: () async {
            if (loadCalls++ == 0) return local;
            if (reloadFails) {
              throw const WatchlistGatewayException(
                WatchlistGatewayFailureKind.unavailable,
              );
            }
            return remote;
          },
          onReplace: (_, _) async => throw const WatchlistGatewayException(
            WatchlistGatewayFailureKind.versionConflict,
          ),
        );
        final container = _container(gateway);
        addTearDown(container.dispose);
        final controller = container.read(watchlistControllerProvider.notifier);
        await controller.load();
        controller.addItem(
          groupKey: 'favorites',
          item: WatchlistItem(assetKey: 'BTC'),
        );
        final draftBeforeSave = container
            .read(watchlistControllerProvider)
            .draftGroups;

        await controller.save();
        var conflicted = container.read(watchlistControllerProvider);
        expect(conflicted.phase, WatchlistPhase.conflict);
        expect(conflicted.failureCode, 'version_conflict');
        expect(conflicted.requiresReload, isTrue);
        expect(conflicted.snapshot, local);
        expect(conflicted.draftGroups, draftBeforeSave);
        expect(conflicted.canEdit, isFalse);
        expect(conflicted.canSave, isFalse);
        expect(() => controller.removeGroup('favorites'), throwsStateError);

        await controller.reload();
        conflicted = container.read(watchlistControllerProvider);
        expect(conflicted.phase, WatchlistPhase.conflict);
        expect(conflicted.failureCode, 'watchlist_unavailable');
        expect(conflicted.requiresReload, isTrue);
        expect(conflicted.snapshot, local);
        expect(conflicted.draftGroups, draftBeforeSave);

        controller.discard();
        conflicted = container.read(watchlistControllerProvider);
        expect(conflicted.phase, WatchlistPhase.conflict);
        expect(conflicted.requiresReload, isTrue);
        expect(conflicted.isDirty, isFalse);
        await controller.save();
        expect(gateway.replaceCalls, 1);

        reloadFails = false;
        await controller.reload();
        final reloaded = container.read(watchlistControllerProvider);
        expect(reloaded.phase, WatchlistPhase.ready);
        expect(reloaded.requiresReload, isFalse);
        expect(reloaded.snapshot, remote);
        expect(reloaded.draftGroups, remote.groups);
      },
    );

    test(
      'mismatched save response fails closed and retains the draft',
      () async {
        final loaded = _snapshot(1, <WatchlistGroup>[
          _group('favorites', <String>['ETH']),
        ]);
        final gateway = _TestWatchlistGateway(
          onLoad: () async => loaded,
          onReplace: (_, _) async => _snapshot(2, <WatchlistGroup>[
            _group('favorites', <String>['SOL']),
          ]),
        );
        final container = _container(gateway);
        addTearDown(container.dispose);
        final controller = container.read(watchlistControllerProvider.notifier);
        await controller.load();
        controller.addItem(
          groupKey: 'favorites',
          item: WatchlistItem(assetKey: 'BTC'),
        );
        final draft = container.read(watchlistControllerProvider).draftGroups;

        await controller.save();
        final failed = container.read(watchlistControllerProvider);
        expect(failed.phase, WatchlistPhase.failure);
        expect(failed.failureCode, 'invalid_watchlist_data');
        expect(failed.snapshot, loaded);
        expect(failed.draftGroups, draft);
        expect(failed.canSave, isTrue);
      },
    );

    test('non-advancing save version fails closed', () async {
      final loaded = _snapshot(4, <WatchlistGroup>[
        _group('favorites', <String>['ETH']),
      ]);
      final gateway = _TestWatchlistGateway(
        onLoad: () async => loaded,
        onReplace: (_, groups) async => WatchlistSnapshot(
          version: 4,
          groups: groups,
          updatedAt: DateTime.utc(2026, 8, 25, 5),
        ),
      );
      final container = _container(gateway);
      addTearDown(container.dispose);
      final controller = container.read(watchlistControllerProvider.notifier);
      await controller.load();
      controller.addItem(
        groupKey: 'favorites',
        item: WatchlistItem(assetKey: 'BTC'),
      );

      await controller.save();
      final failed = container.read(watchlistControllerProvider);
      expect(failed.phase, WatchlistPhase.failure);
      expect(failed.failureKind, WatchlistGatewayFailureKind.invalidData);
      expect(failed.snapshot, loaded);
      expect(failed.isDirty, isTrue);
    });

    test(
      'an ambiguous save retries the same expected version and converges',
      () async {
        final memory = MemoryWatchlistGateway(
          clock: () => DateTime.utc(2026, 8, 25, 6),
        );
        var firstReplace = true;
        final gateway = _TestWatchlistGateway(
          onLoad: memory.load,
          onReplace: (expectedVersion, groups) async {
            final committed = await memory.replace(
              expectedVersion: expectedVersion,
              groups: groups,
            );
            if (firstReplace) {
              firstReplace = false;
              throw const WatchlistGatewayException(
                WatchlistGatewayFailureKind.unavailable,
              );
            }
            return committed;
          },
        );
        final container = _container(gateway);
        addTearDown(container.dispose);
        final controller = container.read(watchlistControllerProvider.notifier);
        await controller.load();
        controller.addGroup(_group('favorites', <String>['ETH']));

        await controller.save();
        final ambiguous = container.read(watchlistControllerProvider);
        expect(ambiguous.phase, WatchlistPhase.failure);
        expect(ambiguous.snapshot!.version, 0);
        expect(ambiguous.isDirty, isTrue);

        await controller.save();
        final reconciled = container.read(watchlistControllerProvider);
        expect(gateway.expectedVersions, <int>[0, 0]);
        expect(reconciled.phase, WatchlistPhase.ready);
        expect(reconciled.snapshot!.version, 1);
        expect(reconciled.isDirty, isFalse);
      },
    );

    test(
      'provider rotation retires a late load without blocking the new gateway',
      () async {
        final oldLoad = Completer<WatchlistSnapshot>();
        final oldGateway = _TestWatchlistGateway(onLoad: () => oldLoad.future);
        final newSnapshot = _snapshot(5, <WatchlistGroup>[
          _group('new', <String>['SOL']),
        ]);
        final newGateway = _TestWatchlistGateway(
          mode: WatchlistMode.production,
          onLoad: () async => newSnapshot,
        );
        final container = _container(oldGateway);
        addTearDown(container.dispose);
        final controller = container.read(watchlistControllerProvider.notifier);

        final retired = controller.load();
        expect(oldGateway.loadCalls, 1);
        container.updateOverrides([
          watchlistGatewayProvider.overrideWithValue(newGateway),
        ]);
        expect(
          container.read(watchlistControllerProvider).mode,
          WatchlistMode.production,
        );

        await controller.load();
        expect(newGateway.loadCalls, 1);
        expect(
          container.read(watchlistControllerProvider).snapshot,
          newSnapshot,
        );

        oldLoad.completeError(
          const WatchlistGatewayException(
            WatchlistGatewayFailureKind.unavailable,
          ),
        );
        await retired;
        expect(
          container.read(watchlistControllerProvider).snapshot,
          newSnapshot,
        );
      },
    );

    test(
      'provider rotation retires a late save without clearing new work',
      () async {
        final initial = _snapshot(1, <WatchlistGroup>[
          _group('favorites', <String>['ETH']),
        ]);
        final oldSave = Completer<WatchlistSnapshot>();
        final oldGateway = _TestWatchlistGateway(
          onLoad: () async => initial,
          onReplace: (_, _) => oldSave.future,
        );
        final newSnapshot = _snapshot(9, <WatchlistGroup>[
          _group('remote', <String>['BTC']),
        ]);
        final newGateway = _TestWatchlistGateway(
          mode: WatchlistMode.production,
          onLoad: () async => newSnapshot,
        );
        final container = _container(oldGateway);
        addTearDown(container.dispose);
        final controller = container.read(watchlistControllerProvider.notifier);
        await controller.load();
        controller.addItem(
          groupKey: 'favorites',
          item: WatchlistItem(assetKey: 'SOL'),
        );
        final retired = controller.save();
        expect(oldGateway.replaceCalls, 1);

        container.updateOverrides([
          watchlistGatewayProvider.overrideWithValue(newGateway),
        ]);
        await controller.load();
        expect(
          container.read(watchlistControllerProvider).snapshot,
          newSnapshot,
        );

        oldSave.complete(
          _snapshot(2, <WatchlistGroup>[
            _group('favorites', <String>['ETH', 'SOL']),
          ]),
        );
        await retired;
        expect(
          container.read(watchlistControllerProvider).snapshot,
          newSnapshot,
        );
      },
    );

    test('disposing the provider rejects late publication', () async {
      final loadGate = Completer<WatchlistSnapshot>();
      final gateway = _TestWatchlistGateway(onLoad: () => loadGate.future);
      final container = _container(gateway);
      final controller = container.read(watchlistControllerProvider.notifier);
      final pending = controller.load();

      container.invalidate(watchlistControllerProvider);
      expect(
        container.read(watchlistControllerProvider).phase,
        WatchlistPhase.initial,
      );
      loadGate.complete(
        _snapshot(1, <WatchlistGroup>[
          _group('late', <String>['ETH']),
        ]),
      );
      await pending;
      expect(container.read(watchlistControllerProvider).snapshot, isNull);
      container.dispose();
    });
  });
}

ProviderContainer _container(WatchlistGateway gateway) {
  return ProviderContainer(
    overrides: [watchlistGatewayProvider.overrideWithValue(gateway)],
  );
}

WatchlistGroup _group(String key, List<String> assetKeys) {
  return WatchlistGroup(
    key: key,
    name: key.substring(0, 1).toUpperCase() + key.substring(1),
    items: assetKeys.map((assetKey) => WatchlistItem(assetKey: assetKey)),
  );
}

WatchlistSnapshot _snapshot(int version, List<WatchlistGroup> groups) {
  return WatchlistSnapshot(
    version: version,
    groups: groups,
    updatedAt: DateTime.utc(2026, 8, 25, 1, version),
  );
}

final class _TestWatchlistGateway implements WatchlistGateway {
  _TestWatchlistGateway({
    this.mode = WatchlistMode.preview,
    required this.onLoad,
    Future<WatchlistSnapshot> Function(
      int expectedVersion,
      List<WatchlistGroup> groups,
    )?
    onReplace,
  }) : onReplace =
           onReplace ??
           ((_, _) async => throw const WatchlistGatewayException(
             WatchlistGatewayFailureKind.unavailable,
           ));

  @override
  final WatchlistMode mode;
  final Future<WatchlistSnapshot> Function() onLoad;
  final Future<WatchlistSnapshot> Function(
    int expectedVersion,
    List<WatchlistGroup> groups,
  )
  onReplace;
  int loadCalls = 0;
  int replaceCalls = 0;
  final List<int> expectedVersions = <int>[];

  @override
  Future<WatchlistSnapshot> load() {
    loadCalls += 1;
    return onLoad();
  }

  @override
  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  }) {
    replaceCalls += 1;
    expectedVersions.add(expectedVersion);
    return onReplace(expectedVersion, validateWatchlistGroups(groups));
  }
}
