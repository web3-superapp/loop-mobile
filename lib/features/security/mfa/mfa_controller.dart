import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';

/// Where the account's second factor stands, as LOOP last heard it.
enum LoopMfaPhase {
  /// The provider has not been asked yet.
  unknown,

  /// A read is running.
  reading,

  /// The provider answered. [LoopMfaState.enrollments] is that answer.
  known,

  /// The provider could not answer. It is not "no MFA": it is "not known".
  unavailable,
}

/// How far a TOTP enrolment has got.
enum LoopMfaEnrollmentStep {
  /// Nothing is being enrolled.
  idle,

  /// The provider is being asked for a secret.
  starting,

  /// A secret exists and the owner is entering the first code.
  confirming,

  /// The code is being checked.
  submitting,
}

@immutable
final class LoopMfaState {
  const LoopMfaState({
    this.phase = LoopMfaPhase.unknown,
    this.enrollments = const <LoopMfaEnrollment>[],
    this.step = LoopMfaEnrollmentStep.idle,
    this.secret,
    this.failure,
    this.providerMessage,
    this.removing = false,
  });

  final LoopMfaPhase phase;

  /// What the provider said it holds. Empty means the provider said "none",
  /// which is only true while [phase] is [LoopMfaPhase.known].
  final List<LoopMfaEnrollment> enrollments;

  final LoopMfaEnrollmentStep step;

  /// The secret the owner is adding to their authenticator, if any. It is
  /// never stored: it lives for the length of the sheet and no longer.
  final LoopTotpSecret? secret;

  /// Why the last call did not do what was asked.
  final LoopMfaFailureKind? failure;

  /// The provider's own sentence for that failure, kept for the debug log.
  final String? providerMessage;

  final bool removing;

  bool get isEnrolled => enrollments.isNotEmpty;

  bool get isBusy =>
      removing ||
      phase == LoopMfaPhase.reading ||
      step == LoopMfaEnrollmentStep.starting ||
      step == LoopMfaEnrollmentStep.submitting;

  /// The account has a TOTP method, as the provider reported it.
  bool get hasTotp =>
      enrollments.any((one) => one.kind == LoopMfaMethodKind.totp);

  LoopMfaState copyWith({
    LoopMfaPhase? phase,
    List<LoopMfaEnrollment>? enrollments,
    LoopMfaEnrollmentStep? step,
    LoopTotpSecret? secret,
    LoopMfaFailureKind? failure,
    String? providerMessage,
    bool? removing,
    bool clearSecret = false,
    bool clearFailure = false,
  }) {
    return LoopMfaState(
      phase: phase ?? this.phase,
      enrollments: enrollments ?? this.enrollments,
      step: step ?? this.step,
      secret: clearSecret ? null : (secret ?? this.secret),
      failure: clearFailure ? null : (failure ?? this.failure),
      providerMessage: clearFailure
          ? null
          : (providerMessage ?? this.providerMessage),
      removing: removing ?? this.removing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopMfaState &&
          other.phase == phase &&
          listEquals(other.enrollments, enrollments) &&
          other.step == step &&
          other.secret == secret &&
          other.failure == failure &&
          other.providerMessage == providerMessage &&
          other.removing == removing;

  @override
  int get hashCode => Object.hash(
    phase,
    Object.hashAll(enrollments),
    step,
    secret,
    failure,
    providerMessage,
    removing,
  );
}

/// The account's second factor at the login service.
///
/// Every enrolment fact here came back from Privy in the same call that
/// changed it. Nothing is assumed: a code that was submitted is not an
/// enrolment until the provider returns an account that has one.
final class LoopMfaController extends Notifier<LoopMfaState> {
  Future<void>? _reading;

  @override
  LoopMfaState build() => const LoopMfaState();

  /// Reads what the provider holds. Single-flight; safe to call on every open.
  Future<void> load() {
    final running = _reading;
    if (running != null) return running;
    final reading = _load().whenComplete(() => _reading = null);
    _reading = reading;
    return reading;
  }

  Future<void> _load() async {
    state = state.copyWith(phase: LoopMfaPhase.reading, clearFailure: true);
    try {
      final enrollments = await ref
          .read(loopMfaGatewayProvider)
          .readEnrollments();
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: LoopMfaPhase.known,
        enrollments: List.unmodifiable(enrollments),
      );
    } on LoopMfaException catch (error) {
      _fail(error, phase: LoopMfaPhase.unavailable);
    } on Object catch (error) {
      _fail(
        LoopMfaException(
          LoopMfaFailureKind.unknown,
          providerMessage: error.toString(),
        ),
        phase: LoopMfaPhase.unavailable,
      );
    }
  }

  /// Asks the provider for a secret and opens the confirmation step.
  Future<void> beginTotp() async {
    if (state.isBusy || state.step != LoopMfaEnrollmentStep.idle) return;
    state = state.copyWith(
      step: LoopMfaEnrollmentStep.starting,
      clearFailure: true,
      clearSecret: true,
    );
    try {
      final secret = await ref
          .read(loopMfaGatewayProvider)
          .beginTotpEnrollment();
      if (!ref.mounted) return;
      state = state.copyWith(
        step: LoopMfaEnrollmentStep.confirming,
        secret: secret,
      );
    } on LoopMfaException catch (error) {
      _fail(error, step: LoopMfaEnrollmentStep.idle);
    } on Object catch (error) {
      _fail(
        LoopMfaException(
          LoopMfaFailureKind.unknown,
          providerMessage: error.toString(),
        ),
        step: LoopMfaEnrollmentStep.idle,
      );
    }
  }

  /// Sends one code. A wrong code leaves the step open so it can be retyped;
  /// it never closes the sheet claiming anything.
  Future<bool> submitTotp(String code) async {
    if (state.step != LoopMfaEnrollmentStep.confirming || state.isBusy) {
      return false;
    }
    state = state.copyWith(
      step: LoopMfaEnrollmentStep.submitting,
      clearFailure: true,
    );
    try {
      final enrollments = await ref
          .read(loopMfaGatewayProvider)
          .completeTotpEnrollment(code.trim());
      if (!ref.mounted) return false;
      state = state.copyWith(
        phase: LoopMfaPhase.known,
        enrollments: List.unmodifiable(enrollments),
        step: LoopMfaEnrollmentStep.idle,
        clearSecret: true,
      );
      return true;
    } on LoopMfaException catch (error) {
      _fail(error, step: LoopMfaEnrollmentStep.confirming);
      return false;
    } on Object catch (error) {
      _fail(
        LoopMfaException(
          LoopMfaFailureKind.unknown,
          providerMessage: error.toString(),
        ),
        step: LoopMfaEnrollmentStep.confirming,
      );
      return false;
    }
  }

  /// Drops a secret the owner did not finish with. Nothing was enrolled, so
  /// there is nothing to undo at the provider.
  void cancelTotp() {
    if (state.step == LoopMfaEnrollmentStep.idle) return;
    state = state.copyWith(
      step: LoopMfaEnrollmentStep.idle,
      clearSecret: true,
      clearFailure: true,
    );
  }

  /// Removes TOTP at the provider and republishes what it says is left.
  Future<bool> removeTotp() async {
    if (state.isBusy || !state.hasTotp) return false;
    state = state.copyWith(removing: true, clearFailure: true);
    try {
      final enrollments = await ref.read(loopMfaGatewayProvider).removeTotp();
      if (!ref.mounted) return false;
      state = state.copyWith(
        phase: LoopMfaPhase.known,
        enrollments: List.unmodifiable(enrollments),
        removing: false,
      );
      return true;
    } on LoopMfaException catch (error) {
      _fail(error, removing: false);
      return false;
    } on Object catch (error) {
      _fail(
        LoopMfaException(
          LoopMfaFailureKind.unknown,
          providerMessage: error.toString(),
        ),
        removing: false,
      );
      return false;
    }
  }

  void _fail(
    LoopMfaException error, {
    LoopMfaPhase? phase,
    LoopMfaEnrollmentStep? step,
    bool? removing,
  }) {
    if (!ref.mounted) return;
    // The provider's own words go to the debug log and nowhere else: the page
    // says what LOOP can stand behind, and the log keeps what was actually
    // returned so a failure can be read rather than guessed at.
    final message = error.providerMessage;
    if (message != null && message.isNotEmpty) {
      debugPrint('LOOP MFA ${error.kind.name}: $message');
    }
    state = state.copyWith(
      phase: phase ?? state.phase,
      step: step ?? state.step,
      removing: removing ?? state.removing,
      failure: error.kind,
      providerMessage: message,
    );
  }
}

final loopMfaProvider = NotifierProvider<LoopMfaController, LoopMfaState>(
  LoopMfaController.new,
);
