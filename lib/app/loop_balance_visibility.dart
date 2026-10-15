import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device could keep the 「隐藏余额」 choice (decision 0175).
///
/// [unknown] until the one bounded read has answered; [unavailable] once a
/// read or a write failed or timed out, which leaves the choice run-local.
enum LoopBalanceVisibilityPersistence { unknown, available, unavailable }

/// Timeout for the one read and every write, the same second the display
/// preferences use (AGENTS rule 23).
const loopBalanceVisibilityIoTimeout = Duration(seconds: 1);

/// The installation's 「隐藏余额」 choice on 我 (decision 0175).
///
/// It is a display choice and nothing else: no account resource, no wallet
/// data, no identity. Fail-open means "shown": a device that cannot read the
/// stored value starts with the figures visible.
@immutable
class LoopBalanceVisibility {
  const LoopBalanceVisibility({
    this.hidden = false,
    this.persistence = LoopBalanceVisibilityPersistence.unknown,
  });

  final bool hidden;
  final LoopBalanceVisibilityPersistence persistence;

  LoopBalanceVisibility copyWith({
    bool? hidden,
    LoopBalanceVisibilityPersistence? persistence,
  }) => LoopBalanceVisibility(
    hidden: hidden ?? this.hidden,
    persistence: persistence ?? this.persistence,
  );
}

/// The narrow port; the only production adapter is
/// `SharedPreferencesLoopBalanceVisibilityStore`.
abstract interface class LoopBalanceVisibilityStore {
  Future<bool?> readHideBalance();

  Future<void> writeHideBalance(bool value);
}

class UnavailableLoopBalanceVisibilityStore
    implements LoopBalanceVisibilityStore {
  const UnavailableLoopBalanceVisibilityStore();

  @override
  Future<bool?> readHideBalance() => Future<bool?>.error(
    UnsupportedError('local_balance_visibility_unavailable'),
  );

  @override
  Future<void> writeHideBalance(bool value) => Future<void>.error(
    UnsupportedError('local_balance_visibility_unavailable'),
  );
}

final loopBalanceVisibilityStoreProvider = Provider<LoopBalanceVisibilityStore>(
  (ref) => const UnavailableLoopBalanceVisibilityStore(),
);

final loopBalanceVisibilityIoTimeoutProvider = Provider<Duration>(
  (ref) => loopBalanceVisibilityIoTimeout,
);

/// Reads the stored choice once and writes every later one in order.
///
/// A choice the reader makes before the read answers wins: the read only
/// reports whether the device could be reached, it never overwrites a value
/// set in this run.
class LoopBalanceVisibilityController extends Notifier<LoopBalanceVisibility> {
  late LoopBalanceVisibilityStore _store;
  late Duration _ioTimeout;
  Future<void> _writeTail = Future<void>.value();
  bool _chosenThisRun = false;
  int _writeRevision = 0;

  @override
  LoopBalanceVisibility build() {
    _store = ref.watch(loopBalanceVisibilityStoreProvider);
    _ioTimeout = ref.watch(loopBalanceVisibilityIoTimeoutProvider);
    _chosenThisRun = false;
    _writeRevision = 0;
    unawaited(_read());
    return const LoopBalanceVisibility();
  }

  Future<void> _read() async {
    try {
      final stored = await Future<bool?>.sync(_store.readHideBalance)
          .timeout(_ioTimeout);
      if (!ref.mounted) return;
      state = _chosenThisRun
          ? state.copyWith(
              persistence:
                  state.persistence ==
                      LoopBalanceVisibilityPersistence.unavailable
                  ? LoopBalanceVisibilityPersistence.unavailable
                  : LoopBalanceVisibilityPersistence.available,
            )
          : LoopBalanceVisibility(
              hidden: stored ?? false,
              persistence: LoopBalanceVisibilityPersistence.available,
            );
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(
        persistence: LoopBalanceVisibilityPersistence.unavailable,
      );
    }
  }

  /// Flips the choice now and stores it after every earlier write.
  Future<void> toggle() => setHidden(!state.hidden);

  Future<void> setHidden(bool hidden) async {
    if (state.hidden == hidden) return;
    _chosenThisRun = true;
    final revision = ++_writeRevision;
    state = state.copyWith(hidden: hidden);
    final previous = _writeTail;
    final operation = () async {
      try {
        await previous;
      } on Object {
        // A later choice still gets its own write attempt.
      }
      await Future<void>.sync(() => _store.writeHideBalance(hidden));
    }();
    _writeTail = operation;
    try {
      await operation.timeout(_ioTimeout);
      if (ref.mounted && revision == _writeRevision) {
        state = state.copyWith(
          persistence: LoopBalanceVisibilityPersistence.available,
        );
      }
    } on Object {
      if (ref.mounted && revision == _writeRevision) {
        state = state.copyWith(
          persistence: LoopBalanceVisibilityPersistence.unavailable,
        );
      }
    }
  }
}

final loopBalanceVisibilityProvider =
    NotifierProvider<LoopBalanceVisibilityController, LoopBalanceVisibility>(
      LoopBalanceVisibilityController.new,
    );
