import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';

/// The four account steps that follow a verified credential.
///
/// The prototype numbers the whole opening as five: `auth-otp` is 01, and
/// these four carry 02 … 05. The numbers live here so a page can never print
/// a position the sequence does not actually put it in.
enum LoopOnboardingStep {
  walletCreate(2, 'wallet-create', '创建钱包'),
  walletBackup(3, 'wallet-recovery', '设置恢复方式'),
  security(4, 'security-setup', '安全设置'),
  loopId(5, 'loop-id-setup', '创建 LOOP ID');

  const LoopOnboardingStep(this.number, this.slug, this.label);

  /// Position in the five-step opening, as printed on the page.
  final int number;

  /// The manifest slug this step is rendered by.
  final String slug;

  final String label;

  static const total = 5;

  /// The step before this one, or `null` for the first one of the four.
  ///
  /// `walletCreate` deliberately has none: the credential is already accepted
  /// by the time it is shown, so there is no login page to go back to.
  LoopOnboardingStep? get previous => switch (this) {
    LoopOnboardingStep.walletCreate => null,
    LoopOnboardingStep.walletBackup => LoopOnboardingStep.walletCreate,
    LoopOnboardingStep.security => LoopOnboardingStep.walletBackup,
    LoopOnboardingStep.loopId => LoopOnboardingStep.security,
  };

  LoopOnboardingStep? get next => switch (this) {
    LoopOnboardingStep.walletCreate => LoopOnboardingStep.walletBackup,
    LoopOnboardingStep.walletBackup => LoopOnboardingStep.security,
    LoopOnboardingStep.security => LoopOnboardingStep.loopId,
    LoopOnboardingStep.loopId => null,
  };

  static LoopOnboardingStep? tryParse(String? name) {
    for (final step in values) {
      if (step.name == name) return step;
    }
    return null;
  }
}

/// Device-local record of how far one account got in the opening sequence.
///
/// It stores a position and nothing else. It is not an account resource, it
/// proves no enrolment, and it never decides whether the account is active —
/// that answer only ever comes from `GET /v2/profile`.
abstract interface class LoopOnboardingProgressStore {
  Future<LoopOnboardingStep?> read(String partitionKey);

  Future<void> write(String partitionKey, LoopOnboardingStep step);

  Future<void> clear(String partitionKey);
}

/// The store a run gets when device storage could not be opened.
///
/// Losing the position is not losing the sequence: the run still walks the
/// four steps, it simply restarts at 02 after the process is killed. Nothing
/// is claimed to be persisted.
final class UnavailableLoopOnboardingProgressStore
    implements LoopOnboardingProgressStore {
  const UnavailableLoopOnboardingProgressStore();

  @override
  Future<LoopOnboardingStep?> read(String partitionKey) async => null;

  @override
  Future<void> write(String partitionKey, LoopOnboardingStep step) async {}

  @override
  Future<void> clear(String partitionKey) async {}
}

/// An in-process store. Used by tests and by any composition that has no
/// device storage; it keeps the position for the run and no longer.
final class InMemoryLoopOnboardingProgressStore
    implements LoopOnboardingProgressStore {
  final Map<String, LoopOnboardingStep> _steps = <String, LoopOnboardingStep>{};

  @override
  Future<LoopOnboardingStep?> read(String partitionKey) async =>
      _steps[partitionKey];

  @override
  Future<void> write(String partitionKey, LoopOnboardingStep step) async {
    _steps[partitionKey] = step;
  }

  @override
  Future<void> clear(String partitionKey) async {
    _steps.remove(partitionKey);
  }
}

final loopOnboardingProgressStoreProvider =
    Provider<LoopOnboardingProgressStore>(
      (ref) => const UnavailableLoopOnboardingProgressStore(),
    );

@immutable
final class LoopOnboardingSequenceState {
  const LoopOnboardingSequenceState({
    this.partitionKey,
    this.step,
    this.enrolledRecoveryMethod,
  });

  const LoopOnboardingSequenceState.none()
    : partitionKey = null,
      step = null,
      enrolledRecoveryMethod = null;

  /// The account partition this position belongs to, or `null` outside the
  /// sequence. One account's position is never shown to another.
  final String? partitionKey;

  /// Where the owner is right now, or `null` when the sequence is not running.
  final LoopOnboardingStep? step;

  /// The recovery method the owner actually chose on step 03, or `null`.
  ///
  /// Kept for this run only and never written to the store: a method cannot
  /// be proven enrolled after a restart, so a resumed run claims nothing.
  /// Skipping the step leaves it `null`, which is what 稍后设置 means.
  final String? enrolledRecoveryMethod;

  bool get isActive => step != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopOnboardingSequenceState &&
          other.partitionKey == partitionKey &&
          other.step == step &&
          other.enrolledRecoveryMethod == enrolledRecoveryMethod;

  @override
  int get hashCode => Object.hash(partitionKey, step, enrolledRecoveryMethod);
}

/// Owns the 02 → 05 opening sequence for an account whose profile is pending.
///
/// The sequence is entered from one place only: a read of `GET /v2/profile`
/// that answered `pending`. An account the server calls `active` never enters
/// it, and finishing it is what [complete] records.
final class LoopOnboardingSequenceController
    extends Notifier<LoopOnboardingSequenceState> {
  Future<LoopOnboardingStep>? _entry;

  @override
  LoopOnboardingSequenceState build() =>
      const LoopOnboardingSequenceState.none();

  /// Enters or resumes the sequence for [principalKey].
  ///
  /// A position already stored for this account is resumed; anything else
  /// starts at 02. Single-flight, so two landings cannot open two sequences.
  Future<LoopOnboardingStep> begin(String principalKey) {
    final partitionKey = _partitionKeyFor(principalKey);
    if (partitionKey == null) return Future.value(_startFresh(null));
    final current = state;
    if (current.isActive && current.partitionKey == partitionKey) {
      return Future.value(current.step!);
    }
    final active = _entry;
    if (active != null) return active;
    late final Future<LoopOnboardingStep> entry;
    entry = _begin(partitionKey).whenComplete(() {
      if (identical(_entry, entry)) _entry = null;
    });
    _entry = entry;
    return entry;
  }

  Future<LoopOnboardingStep> _begin(String partitionKey) async {
    LoopOnboardingStep? stored;
    try {
      stored = await ref
          .read(loopOnboardingProgressStoreProvider)
          .read(partitionKey);
    } on Object {
      stored = null;
    }
    if (!ref.mounted) return stored ?? LoopOnboardingStep.walletCreate;
    final step = stored ?? LoopOnboardingStep.walletCreate;
    state = LoopOnboardingSequenceState(
      partitionKey: partitionKey,
      step: step,
      enrolledRecoveryMethod: state.partitionKey == partitionKey
          ? state.enrolledRecoveryMethod
          : null,
    );
    if (stored == null) unawaited(_write(partitionKey, step));
    return step;
  }

  LoopOnboardingStep _startFresh(String? partitionKey) {
    state = LoopOnboardingSequenceState(
      partitionKey: partitionKey,
      step: LoopOnboardingStep.walletCreate,
    );
    return LoopOnboardingStep.walletCreate;
  }

  /// Records the position the owner is moving to, forwards or backwards.
  ///
  /// The in-memory position changes first so navigation never waits on
  /// storage; the write follows and is allowed to fail silently, because a
  /// lost position only costs a restart at 02.
  void moveTo(LoopOnboardingStep step) {
    if (!state.isActive) return;
    state = LoopOnboardingSequenceState(
      partitionKey: state.partitionKey,
      step: step,
      enrolledRecoveryMethod: state.enrolledRecoveryMethod,
    );
    final partitionKey = state.partitionKey;
    if (partitionKey != null) unawaited(_write(partitionKey, step));
  }

  /// Records what step 03 decided. `null` is 稍后设置, and is not an enrolment.
  void recordRecoveryDecision(String? methodName) {
    if (!state.isActive) return;
    state = LoopOnboardingSequenceState(
      partitionKey: state.partitionKey,
      step: state.step,
      enrolledRecoveryMethod: methodName,
    );
  }

  /// The account is active: the sequence is over and its position is dropped.
  ///
  /// [principalKey] lets a run that never entered the sequence — an account
  /// the server already calls active — still clear a position left behind by
  /// an earlier, unfinished opening on this device.
  Future<void> complete({String? principalKey}) async {
    final partitionKey =
        state.partitionKey ??
        (principalKey == null ? null : _partitionKeyFor(principalKey));
    state = const LoopOnboardingSequenceState.none();
    if (partitionKey == null) return;
    try {
      await ref.read(loopOnboardingProgressStoreProvider).clear(partitionKey);
    } on Object {
      // A position left behind is re-read on the next pending profile only,
      // and an active account never enters the sequence again.
    }
  }

  /// Drops the in-memory position without touching the stored one, so the
  /// same account resumes where it stopped after signing in again.
  void leave() {
    _entry = null;
    state = const LoopOnboardingSequenceState.none();
  }

  Future<void> _write(String partitionKey, LoopOnboardingStep step) async {
    try {
      await ref
          .read(loopOnboardingProgressStoreProvider)
          .write(partitionKey, step);
    } on Object {
      // Storage is a convenience here, never a fact the pages read back.
    }
  }

  static String? _partitionKeyFor(String principalKey) {
    final principal = principalKey.trim();
    if (principal.isEmpty) return null;
    try {
      return LoopV2OwnerPartition.fromPrincipal(principal);
    } on Object {
      return null;
    }
  }
}

final loopOnboardingSequenceProvider =
    NotifierProvider<
      LoopOnboardingSequenceController,
      LoopOnboardingSequenceState
    >(LoopOnboardingSequenceController.new);
