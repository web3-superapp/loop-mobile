import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';

/// How long LOOP may be in the background before the lock closes again.
///
/// Switching to another App to copy an address, or taking a call, is not
/// leaving LOOP. Coming back a minute later is. The window is the whole of
/// the rule — there is no separate "locked while backgrounded" state, because
/// a locked App the owner never left would only teach them to unlock without
/// reading.
const loopAppLockGrace = Duration(seconds: 60);

/// The clock the lock measures that window with. Overridden in tests.
final loopAppLockClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

@immutable
final class LoopAppLockState {
  const LoopAppLockState({
    this.enabled = false,
    this.locked = false,
    this.busy = false,
    this.capability,
    this.lastOutcome,
    this.systemMessage,
    this.persisted = true,
  });

  /// The owner turned the lock on. It is a device-local choice and never an
  /// account fact.
  final bool enabled;

  /// The curtain is down right now and the App is not readable.
  final bool locked;

  /// A system authentication prompt is up. Nothing may be asked twice while
  /// one is running.
  final bool busy;

  /// What this device will authenticate with, or `null` while unread.
  final LoopDeviceAuthCapability? capability;

  /// How the last attempt ended, or `null` if none has run. It is never a
  /// claim about the lock's state, only about that attempt.
  final LoopDeviceAuthOutcome? lastOutcome;

  /// The platform's own words for the last attempt, when it had any.
  final String? systemMessage;

  /// The choice reached the device's storage. `false` means the lock works
  /// for this run and the next start will not remember it.
  final bool persisted;

  /// The lock can be offered at all: the device has something to ask with.
  bool get isAvailable => capability?.isAvailable ?? false;

  LoopAppLockState copyWith({
    bool? enabled,
    bool? locked,
    bool? busy,
    LoopDeviceAuthCapability? capability,
    LoopDeviceAuthOutcome? lastOutcome,
    String? systemMessage,
    bool? persisted,
    bool clearOutcome = false,
  }) {
    return LoopAppLockState(
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      busy: busy ?? this.busy,
      capability: capability ?? this.capability,
      lastOutcome: clearOutcome ? null : (lastOutcome ?? this.lastOutcome),
      systemMessage: clearOutcome
          ? null
          : (systemMessage ?? this.systemMessage),
      persisted: persisted ?? this.persisted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopAppLockState &&
          other.enabled == enabled &&
          other.locked == locked &&
          other.busy == busy &&
          other.capability == capability &&
          other.lastOutcome == lastOutcome &&
          other.systemMessage == systemMessage &&
          other.persisted == persisted;

  @override
  int get hashCode => Object.hash(
    enabled,
    locked,
    busy,
    capability,
    lastOutcome,
    systemMessage,
    persisted,
  );
}

/// The device-local application lock.
///
/// It protects what is on screen, nothing else: no key, no token and no
/// stored value is encrypted by it, and it is never presented as one. What it
/// does is ask the operating system to confirm the owner before LOOP is
/// readable again, using the face, fingerprint or passcode the owner already
/// set up. LOOP holds no PIN of its own and cannot: the system asks, the
/// system answers.
final class LoopAppLockController extends Notifier<LoopAppLockState> {
  Future<void>? _running;
  DateTime? _leftForegroundAt;

  @override
  LoopAppLockState build() => const LoopAppLockState();

  /// Reads the device capability and the stored choice.
  ///
  /// A start that finds the lock on is locked: the whole point is that the
  /// App is not readable before the owner is asked.
  Future<void> load() async {
    final capability = await _readCapability();
    bool? stored;
    try {
      stored = await ref.read(loopAppLockStoreProvider).read();
    } on Object {
      stored = null;
    }
    if (!ref.mounted) return;
    final enabled = (stored ?? false) && capability.isAvailable;
    state = state.copyWith(
      capability: capability,
      enabled: enabled,
      locked: enabled,
      persisted: true,
    );
  }

  /// Re-reads what the device will authenticate with.
  ///
  /// The owner may have added or removed a screen lock while LOOP was in the
  /// background, and neither is something LOOP can be told about.
  Future<void> refreshCapability() async {
    final capability = await _readCapability();
    if (!ref.mounted) return;
    state = state.copyWith(capability: capability);
  }

  /// Turns the lock on, but only after the device proves the owner is here.
  ///
  /// Turning on a lock that cannot be opened is the one failure that matters,
  /// so the same prompt that will be shown later is shown now.
  Future<bool> enable() => _switch(true);

  /// Turns the lock off, after the same proof. A lock anyone could switch off
  /// is not a lock.
  Future<bool> disable() => _switch(false);

  Future<bool> _switch(bool enabled) async {
    if (state.busy || state.enabled == enabled) return state.enabled == enabled;
    return _authenticated(
      reason: enabled ? '验证身份以开启应用锁' : '验证身份以关闭应用锁',
      onSuccess: (result) async {
        var persisted = true;
        try {
          await ref.read(loopAppLockStoreProvider).write(enabled);
        } on Object {
          persisted = false;
        }
        if (!ref.mounted) return;
        state = state.copyWith(
          enabled: enabled,
          locked: false,
          persisted: persisted,
          lastOutcome: result.outcome,
          systemMessage: result.systemMessage,
        );
        _leftForegroundAt = null;
      },
    );
  }

  /// Asks the device to open the curtain.
  Future<bool> unlock() async {
    if (state.busy || !state.locked) return !state.locked;
    return _authenticated(
      reason: '验证身份以进入 LOOP',
      onSuccess: (result) async {
        if (!ref.mounted) return;
        state = state.copyWith(
          locked: false,
          lastOutcome: result.outcome,
          systemMessage: result.systemMessage,
        );
        _leftForegroundAt = null;
      },
    );
  }

  Future<bool> _authenticated({
    required String reason,
    required Future<void> Function(LoopDeviceAuthResult result) onSuccess,
  }) async {
    final running = _running;
    if (running != null) {
      await running;
      return state.lastOutcome == LoopDeviceAuthOutcome.succeeded;
    }
    state = state.copyWith(busy: true, clearOutcome: true);
    final completer = Completer<void>();
    _running = completer.future;
    LoopDeviceAuthResult result;
    try {
      result = await ref
          .read(loopDeviceAuthenticatorProvider)
          .authenticate(reason: reason);
    } on Object catch (error) {
      result = LoopDeviceAuthResult(
        LoopDeviceAuthOutcome.error,
        systemMessage: error.toString(),
      );
    }
    try {
      if (!ref.mounted) return false;
      if (result.succeeded) {
        await onSuccess(result);
      } else if (result.outcome == LoopDeviceAuthOutcome.unavailable) {
        // The device lost the credential the lock depends on. A lock that
        // cannot be opened is not a protection, it is a locked-out owner, so
        // it turns itself off and says so rather than holding the App shut.
        await _forceOff(result);
      } else {
        state = state.copyWith(
          lastOutcome: result.outcome,
          systemMessage: result.systemMessage,
        );
      }
      return result.succeeded;
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
      _running = null;
      completer.complete();
    }
  }

  Future<void> _forceOff(LoopDeviceAuthResult result) async {
    var persisted = true;
    try {
      await ref.read(loopAppLockStoreProvider).write(false);
    } on Object {
      persisted = false;
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      enabled: false,
      locked: false,
      persisted: persisted,
      capability: const LoopDeviceAuthCapability.unavailable(
        LoopDeviceAuthUnavailableReason.noCredentialSet,
      ),
      lastOutcome: result.outcome,
      systemMessage: result.systemMessage,
    );
  }

  /// LOOP left the foreground. The moment is remembered, nothing else
  /// happens: an App that locked the instant it was backgrounded would be
  /// locked in the app switcher's own screenshot.
  void onLeftForeground() {
    if (!state.enabled || state.locked) return;
    // The first moment away is the one that counts. The system's own prompt
    // backgrounds LOOP too, and a later mark would quietly reset the window.
    _leftForegroundAt ??= ref.read(loopAppLockClockProvider)();
  }

  /// LOOP came back. More than [loopAppLockGrace] away closes the curtain.
  ///
  /// The mark is always cleared, whether or not it locked: a short trip that
  /// did not lock must not leave a stale moment for the next one to measure
  /// against.
  void onEnteredForeground() {
    final left = _leftForegroundAt;
    _leftForegroundAt = null;
    if (!state.enabled || state.locked || left == null) return;
    final away = ref.read(loopAppLockClockProvider)().difference(left);
    if (away >= loopAppLockGrace) {
      state = state.copyWith(locked: true, clearOutcome: true);
    }
  }

  Future<LoopDeviceAuthCapability> _readCapability() async {
    try {
      return await ref.read(loopDeviceAuthenticatorProvider).readCapability();
    } on Object {
      return const LoopDeviceAuthCapability.unavailable(
        LoopDeviceAuthUnavailableReason.unknown,
      );
    }
  }
}

final loopAppLockProvider =
    NotifierProvider<LoopAppLockController, LoopAppLockState>(
      LoopAppLockController.new,
    );
