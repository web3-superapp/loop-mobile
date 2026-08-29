import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_display_store.dart';

void main() {
  group('Loop display preferences', () {
    test(
      'shared-preferences adapter uses one namespaced Boolean key',
      () async {
        String? readKey;
        String? writtenKey;
        bool? writtenValue;
        final store = SharedPreferencesLoopDisplayStore.forTesting(
          (key) async {
            readKey = key;
            return true;
          },
          (key, value) async {
            writtenKey = key;
            writtenValue = value;
          },
        );

        expect(await store.readReduceMotion(), isTrue);
        await store.writeReduceMotion(false);

        expect(readKey, SharedPreferencesLoopDisplayStore.reduceMotionKey);
        expect(writtenKey, SharedPreferencesLoopDisplayStore.reduceMotionKey);
        expect(writtenValue, isFalse);
      },
    );

    test(
      'missing device value starts disabled with persistence available',
      () async {
        final loaded = await loadLoopDisplayPreferences(_MemoryDisplayStore());

        expect(loaded.reduceMotion, isFalse);
        expect(loaded.persistence, LoopDisplayPreferencesPersistence.available);
      },
    );

    test('read failure stays run-local without claiming persistence', () async {
      final loaded = await loadLoopDisplayPreferences(
        _MemoryDisplayStore(failingReads: 1),
      );

      expect(loaded.reduceMotion, isFalse);
      expect(loaded.persistence, LoopDisplayPreferencesPersistence.unavailable);
    });

    test('bootstrap catches a synchronous platform-store failure', () async {
      final bootstrap =
          await bootstrapSharedPreferencesDisplayPreferencesForTesting(
            () => throw StateError('plugin_unavailable'),
            timeout: Duration.zero,
          );

      expect(bootstrap.store, isA<UnavailableLoopDisplayPreferencesStore>());
      expect(bootstrap.initial.reduceMotion, isFalse);
      expect(
        bootstrap.initial.persistence,
        LoopDisplayPreferencesPersistence.unavailable,
      );
    });

    test(
      'read retry restores an existing value instead of overwriting it',
      () async {
        final store = _MemoryDisplayStore(value: true, failingReads: 1);
        final container = await _containerFor(store);
        addTearDown(container.dispose);

        expect(
          container.read(loopDisplayPreferencesProvider).persistence,
          LoopDisplayPreferencesPersistence.unavailable,
        );
        await container
            .read(loopDisplayPreferencesProvider.notifier)
            .retryPersistence();

        expect(
          container.read(loopDisplayPreferencesProvider).reduceMotion,
          isTrue,
        );
        expect(
          container.read(loopDisplayPreferencesProvider).persistence,
          LoopDisplayPreferencesPersistence.available,
        );
        expect(store.writes, isEmpty);
      },
    );

    test(
      'read timeout fails open without blocking application startup',
      () async {
        final readGate = Completer<bool?>();
        final loaded = await loadLoopDisplayPreferences(
          _MemoryDisplayStore(readGate: readGate),
          timeout: Duration.zero,
        );

        expect(loaded.reduceMotion, isFalse);
        expect(
          loaded.persistence,
          LoopDisplayPreferencesPersistence.unavailable,
        );
      },
    );

    test(
      'persisted Reduce motion survives a controller reconstruction',
      () async {
        final store = _MemoryDisplayStore(value: true);
        final first = await _containerFor(store);

        expect(first.read(loopDisplayPreferencesProvider).reduceMotion, isTrue);
        await first
            .read(loopDisplayPreferencesProvider.notifier)
            .setReduceMotion(false);
        first.dispose();

        final second = await _containerFor(store);
        addTearDown(second.dispose);
        expect(
          second.read(loopDisplayPreferencesProvider).reduceMotion,
          isFalse,
        );
        expect(
          second.read(loopDisplayPreferencesProvider).persistence,
          LoopDisplayPreferencesPersistence.available,
        );
      },
    );

    test(
      'rapid changes serialize writes and retain the latest value',
      () async {
        final firstWrite = Completer<void>();
        final secondWrite = Completer<void>();
        final store = _MemoryDisplayStore(
          writeGates: Queue<Completer<void>>.from(<Completer<void>>[
            firstWrite,
            secondWrite,
          ]),
        );
        final container = await _containerFor(store);
        addTearDown(container.dispose);
        final controller = container.read(
          loopDisplayPreferencesProvider.notifier,
        );

        final enable = controller.setReduceMotion(true);
        await _nextEventLoop();
        final disable = controller.setReduceMotion(false);
        await _nextEventLoop();

        expect(store.writes, <bool>[true]);
        expect(
          container.read(loopDisplayPreferencesProvider).reduceMotion,
          false,
        );
        expect(
          container.read(loopDisplayPreferencesProvider).persistence,
          LoopDisplayPreferencesPersistence.saving,
        );

        firstWrite.complete();
        await _nextEventLoop();
        expect(store.writes, <bool>[true, false]);
        secondWrite.complete();
        await Future.wait(<Future<void>>[enable, disable]);

        expect(store.value, isFalse);
        expect(
          container.read(loopDisplayPreferencesProvider).persistence,
          LoopDisplayPreferencesPersistence.available,
        );
      },
    );

    test(
      'write failure keeps the run value and exposes an exact retry',
      () async {
        final store = _MemoryDisplayStore(failingWrites: 1);
        final container = await _containerFor(store);
        addTearDown(container.dispose);
        final controller = container.read(
          loopDisplayPreferencesProvider.notifier,
        );

        await controller.setReduceMotion(true);

        expect(
          container.read(loopDisplayPreferencesProvider).reduceMotion,
          true,
        );
        expect(
          container.read(loopDisplayPreferencesProvider).persistence,
          LoopDisplayPreferencesPersistence.unavailable,
        );
        expect(store.value, isNull);

        await controller.retryPersistence();

        expect(store.value, isTrue);
        expect(
          container.read(loopDisplayPreferencesProvider).persistence,
          LoopDisplayPreferencesPersistence.available,
        );
      },
    );

    test(
      'write timeout leaves run-local truth while preserving write order',
      () async {
        final firstWrite = Completer<void>();
        final store = _MemoryDisplayStore(
          writeGates: Queue<Completer<void>>.from(<Completer<void>>[
            firstWrite,
          ]),
        );
        final container = await _containerFor(store, ioTimeout: Duration.zero);
        addTearDown(container.dispose);
        final controller = container.read(
          loopDisplayPreferencesProvider.notifier,
        );

        await controller.setReduceMotion(true);
        await controller.setReduceMotion(false);

        expect(store.writes, <bool>[true]);
        expect(
          container.read(loopDisplayPreferencesProvider).persistence,
          LoopDisplayPreferencesPersistence.unavailable,
        );

        firstWrite.complete();
        await _nextEventLoop();
        await _nextEventLoop();

        expect(store.writes, <bool>[true, false]);
        expect(store.value, isFalse);
      },
    );

    test('controller rebuild queues behind an older in-flight write', () async {
      final firstWrite = Completer<void>();
      final store = _MemoryDisplayStore(
        writeGates: Queue<Completer<void>>.from(<Completer<void>>[firstWrite]),
      );
      final container = await _containerFor(store);
      addTearDown(container.dispose);
      final oldController = container.read(
        loopDisplayPreferencesProvider.notifier,
      );

      final oldEnable = oldController.setReduceMotion(true);
      await _nextEventLoop();
      container.invalidate(loopDisplayPreferencesProvider);
      final newController = container.read(
        loopDisplayPreferencesProvider.notifier,
      );
      final newEnable = newController.setReduceMotion(true);
      final newDisable = newController.setReduceMotion(false);
      await _nextEventLoop();

      expect(store.writes, <bool>[true]);
      firstWrite.complete();
      await Future.wait(<Future<void>>[oldEnable, newEnable, newDisable]);

      expect(store.writes, <bool>[true, true, false]);
      expect(store.value, isFalse);
      expect(
        container.read(loopDisplayPreferencesProvider).persistence,
        LoopDisplayPreferencesPersistence.available,
      );
    });

    test(
      'setting the current value does not issue a duplicate write',
      () async {
        final store = _MemoryDisplayStore(value: false);
        final container = await _containerFor(store);
        addTearDown(container.dispose);

        await container
            .read(loopDisplayPreferencesProvider.notifier)
            .setReduceMotion(false);

        expect(store.writes, isEmpty);
      },
    );
  });
}

Future<ProviderContainer> _containerFor(
  _MemoryDisplayStore store, {
  Duration ioTimeout = loopDisplayPreferencesIoTimeout,
}) async {
  final initial = await loadLoopDisplayPreferences(store);
  return ProviderContainer(
    overrides: [
      loopDisplayPreferencesStoreProvider.overrideWithValue(store),
      loopDisplayPreferencesInitialProvider.overrideWithValue(initial),
      loopDisplayPreferencesIoTimeoutProvider.overrideWithValue(ioTimeout),
    ],
  );
}

Future<void> _nextEventLoop() => Future<void>.delayed(Duration.zero);

class _MemoryDisplayStore implements LoopDisplayPreferencesStore {
  _MemoryDisplayStore({
    this.value,
    this.failingReads = 0,
    this.failingWrites = 0,
    this.readGate,
    Queue<Completer<void>>? writeGates,
  }) : writeGates = writeGates ?? Queue<Completer<void>>();

  bool? value;
  int failingReads;
  int failingWrites;
  final Completer<bool?>? readGate;
  final Queue<Completer<void>> writeGates;
  final List<bool> writes = <bool>[];

  @override
  Future<bool?> readReduceMotion() async {
    if (failingReads > 0) {
      failingReads -= 1;
      throw StateError('read_failed');
    }
    if (readGate case final gate?) return gate.future;
    return value;
  }

  @override
  Future<void> writeReduceMotion(bool value) async {
    writes.add(value);
    if (failingWrites > 0) {
      failingWrites -= 1;
      throw StateError('write_failed');
    }
    if (writeGates.isNotEmpty) await writeGates.removeFirst().future;
    this.value = value;
  }
}
