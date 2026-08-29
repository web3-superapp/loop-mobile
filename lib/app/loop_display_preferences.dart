import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LoopDisplayPreferencesPersistence { available, saving, unavailable }

const loopDisplayPreferencesIoTimeout = Duration(seconds: 1);

/// Non-sensitive display preferences for this app installation.
///
/// These values are not account resources and must never contain identity,
/// wallet, credential, protection, or provider state.
@immutable
class LoopDisplayPreferences {
  const LoopDisplayPreferences({
    this.reduceMotion = false,
    this.persistence = LoopDisplayPreferencesPersistence.unavailable,
  });

  final bool reduceMotion;
  final LoopDisplayPreferencesPersistence persistence;

  LoopDisplayPreferences copyWith({
    bool? reduceMotion,
    LoopDisplayPreferencesPersistence? persistence,
  }) {
    return LoopDisplayPreferences(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      persistence: persistence ?? this.persistence,
    );
  }
}

abstract interface class LoopDisplayPreferencesStore {
  Future<bool?> readReduceMotion();

  Future<void> writeReduceMotion(bool value);
}

typedef LoopDisplayPreferencesBootstrap = ({
  LoopDisplayPreferences initial,
  LoopDisplayPreferencesStore store,
});

class UnavailableLoopDisplayPreferencesStore
    implements LoopDisplayPreferencesStore {
  const UnavailableLoopDisplayPreferencesStore();

  @override
  Future<bool?> readReduceMotion() => Future<bool?>.error(
    UnsupportedError('local_display_preferences_unavailable'),
  );

  @override
  Future<void> writeReduceMotion(bool value) => Future<void>.error(
    UnsupportedError('local_display_preferences_unavailable'),
  );
}

final loopDisplayPreferencesStoreProvider =
    Provider<LoopDisplayPreferencesStore>(
      (ref) => const UnavailableLoopDisplayPreferencesStore(),
    );

final loopDisplayPreferencesInitialProvider = Provider<LoopDisplayPreferences>(
  (ref) => const LoopDisplayPreferences(),
);

final loopDisplayPreferencesIoTimeoutProvider = Provider<Duration>(
  (ref) => loopDisplayPreferencesIoTimeout,
);

Future<LoopDisplayPreferences> loadLoopDisplayPreferences(
  LoopDisplayPreferencesStore store, {
  Duration timeout = loopDisplayPreferencesIoTimeout,
}) async {
  try {
    final reduceMotion = await store.readReduceMotion().timeout(timeout);
    return LoopDisplayPreferences(
      reduceMotion: reduceMotion ?? false,
      persistence: LoopDisplayPreferencesPersistence.available,
    );
  } on Object {
    return const LoopDisplayPreferences();
  }
}

class _LoopDisplayPreferencesWriteQueue {
  _LoopDisplayPreferencesWriteQueue(this._store);

  final LoopDisplayPreferencesStore _store;
  Future<void> _writeTail = Future<void>.value();

  Future<void> write(bool value, {required Duration timeout}) {
    final previous = _writeTail;
    final operation = () async {
      try {
        await previous;
      } on Object {
        // An explicit later choice still gets one independent write attempt.
      }
      await _store.writeReduceMotion(value);
    }();
    _writeTail = operation;
    return operation.timeout(timeout);
  }
}

final _loopDisplayPreferencesWriteQueueProvider =
    Provider<_LoopDisplayPreferencesWriteQueue>(
      (ref) => _LoopDisplayPreferencesWriteQueue(
        ref.watch(loopDisplayPreferencesStoreProvider),
      ),
    );

enum _LoopDisplayPreferencesRetry { read, write }

class LoopDisplayPreferencesController
    extends Notifier<LoopDisplayPreferences> {
  late LoopDisplayPreferencesStore _store;
  late _LoopDisplayPreferencesWriteQueue _writeQueue;
  late Duration _ioTimeout;
  int _writeRevision = 0;
  Object? _generation;
  _LoopDisplayPreferencesRetry? _retry;

  @override
  LoopDisplayPreferences build() {
    _store = ref.watch(loopDisplayPreferencesStoreProvider);
    _writeQueue = ref.watch(_loopDisplayPreferencesWriteQueueProvider);
    _ioTimeout = ref.watch(loopDisplayPreferencesIoTimeoutProvider);
    final generation = Object();
    _generation = generation;
    _writeRevision = 0;
    final initial = ref.watch(loopDisplayPreferencesInitialProvider);
    _retry =
        initial.persistence == LoopDisplayPreferencesPersistence.unavailable
        ? _LoopDisplayPreferencesRetry.read
        : null;
    ref.onDispose(() {
      if (identical(_generation, generation)) _generation = null;
    });
    return initial;
  }

  Future<void> setReduceMotion(bool value) {
    if (state.reduceMotion == value) return Future<void>.value();
    return _persistReduceMotion(value);
  }

  Future<void> retryPersistence() {
    if (state.persistence != LoopDisplayPreferencesPersistence.unavailable) {
      return Future<void>.value();
    }
    if (_retry == _LoopDisplayPreferencesRetry.read) {
      return _retryRead();
    }
    return _persistReduceMotion(state.reduceMotion);
  }

  Future<void> _retryRead() async {
    final store = _store;
    final generation = _generation;
    final revision = ++_writeRevision;
    state = state.copyWith(
      persistence: LoopDisplayPreferencesPersistence.saving,
    );

    try {
      final reduceMotion = await store.readReduceMotion().timeout(_ioTimeout);
      if (identical(_generation, generation) && revision == _writeRevision) {
        _retry = null;
        state = LoopDisplayPreferences(
          reduceMotion: reduceMotion ?? false,
          persistence: LoopDisplayPreferencesPersistence.available,
        );
      }
    } on Object {
      if (identical(_generation, generation) && revision == _writeRevision) {
        _retry = _LoopDisplayPreferencesRetry.read;
        state = state.copyWith(
          persistence: LoopDisplayPreferencesPersistence.unavailable,
        );
      }
    }
  }

  Future<void> _persistReduceMotion(bool value) async {
    final generation = _generation;
    final revision = ++_writeRevision;
    state = state.copyWith(
      reduceMotion: value,
      persistence: LoopDisplayPreferencesPersistence.saving,
    );

    try {
      await _writeQueue.write(value, timeout: _ioTimeout);
    } on Object {
      if (identical(_generation, generation) && revision == _writeRevision) {
        _retry = _LoopDisplayPreferencesRetry.write;
        state = state.copyWith(
          persistence: LoopDisplayPreferencesPersistence.unavailable,
        );
      }
      return;
    }

    if (identical(_generation, generation) && revision == _writeRevision) {
      _retry = null;
      state = state.copyWith(
        persistence: LoopDisplayPreferencesPersistence.available,
      );
    }
  }
}

final loopDisplayPreferencesProvider =
    NotifierProvider<LoopDisplayPreferencesController, LoopDisplayPreferences>(
      LoopDisplayPreferencesController.new,
    );
