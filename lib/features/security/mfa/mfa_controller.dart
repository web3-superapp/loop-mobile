import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
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
    this.passkeys = const <LoopPasskeyCredential>[],
    this.passkeyRelyingParty,
    this.step = LoopMfaEnrollmentStep.idle,
    this.secret,
    this.failure,
    this.providerMessage,
    this.removing = false,
    this.passkeyWorking = false,
  });

  final LoopMfaPhase phase;

  /// What the provider said it holds. Empty means the provider said "none",
  /// which is only true while [phase] is [LoopMfaPhase.known].
  final List<LoopMfaEnrollment> enrollments;

  /// The passkeys the provider holds for this account. Like [enrollments],
  /// empty is only true while [phase] is [LoopMfaPhase.known].
  final List<LoopPasskeyCredential> passkeys;

  /// The domain a passkey would belong to, or `null` when this build has no
  /// domain credential and can offer none.
  final String? passkeyRelyingParty;

  final LoopMfaEnrollmentStep step;

  /// The secret the owner is adding to their authenticator, if any. It is
  /// never stored: it lives for the length of the sheet and no longer.
  final LoopTotpSecret? secret;

  /// Why the last call did not do what was asked.
  final LoopMfaFailureKind? failure;

  /// The provider's own sentence for that failure, kept for the debug log.
  final String? providerMessage;

  final bool removing;

  /// A passkey call is running. The system's own prompt may be on screen.
  final bool passkeyWorking;

  bool get isEnrolled => enrollments.isNotEmpty;

  bool get isBusy =>
      removing ||
      passkeyWorking ||
      phase == LoopMfaPhase.reading ||
      step == LoopMfaEnrollmentStep.starting ||
      step == LoopMfaEnrollmentStep.submitting;

  /// The account has a TOTP method, as the provider reported it.
  bool get hasTotp =>
      enrollments.any((one) => one.kind == LoopMfaMethodKind.totp);

  /// This build has the domain credential a passkey needs. It says nothing
  /// about whether the account has one.
  bool get canUsePasskey => (passkeyRelyingParty ?? '').isNotEmpty;

  /// The provider holds at least one passkey for this account.
  bool get hasPasskey => passkeys.isNotEmpty;

  /// The provider will accept a passkey as a second factor.
  bool get hasPasskeyMfa =>
      enrollments.any((one) => one.kind == LoopMfaMethodKind.passkey);

  LoopMfaState copyWith({
    LoopMfaPhase? phase,
    List<LoopMfaEnrollment>? enrollments,
    List<LoopPasskeyCredential>? passkeys,
    LoopMfaEnrollmentStep? step,
    LoopTotpSecret? secret,
    LoopMfaFailureKind? failure,
    String? providerMessage,
    bool? removing,
    bool? passkeyWorking,
    bool clearSecret = false,
    bool clearFailure = false,
  }) {
    return LoopMfaState(
      phase: phase ?? this.phase,
      enrollments: enrollments ?? this.enrollments,
      passkeys: passkeys ?? this.passkeys,
      passkeyRelyingParty: passkeyRelyingParty,
      step: step ?? this.step,
      secret: clearSecret ? null : (secret ?? this.secret),
      failure: clearFailure ? null : (failure ?? this.failure),
      providerMessage: clearFailure
          ? null
          : (providerMessage ?? this.providerMessage),
      removing: removing ?? this.removing,
      passkeyWorking: passkeyWorking ?? this.passkeyWorking,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopMfaState &&
          other.phase == phase &&
          listEquals(other.enrollments, enrollments) &&
          listEquals(other.passkeys, passkeys) &&
          other.passkeyRelyingParty == passkeyRelyingParty &&
          other.passkeyWorking == passkeyWorking &&
          other.step == step &&
          other.secret == secret &&
          other.failure == failure &&
          other.providerMessage == providerMessage &&
          other.removing == removing;

  @override
  int get hashCode => Object.hash(
    phase,
    Object.hashAll(enrollments),
    Object.hashAll(passkeys),
    passkeyRelyingParty,
    passkeyWorking,
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
  LoopMfaState build() => LoopMfaState(
    // Whether a passkey can be offered at all is a property of the build,
    // not of the account, so it is known before anybody is asked anything.
    passkeyRelyingParty: ref.watch(loopMfaGatewayProvider).passkeyRelyingParty,
  );

  /// Publishes exactly what one provider answer contained.
  ///
  /// Every read, enrolment, link and removal ends here. There is one place
  /// that may set [LoopMfaPhase.known], and it copies the provider's two
  /// lists verbatim — nothing in this controller assembles a method or a
  /// credential of its own.
  void _publish(
    LoopSecondFactorFacts facts, {
    LoopMfaEnrollmentStep? step,
    bool? removing,
    bool? passkeyWorking,
    bool clearSecret = false,
  }) {
    state = state.copyWith(
      phase: LoopMfaPhase.known,
      enrollments: List.unmodifiable(facts.enrollments),
      passkeys: List.unmodifiable(facts.passkeys),
      step: step,
      removing: removing,
      passkeyWorking: passkeyWorking,
      clearSecret: clearSecret,
    );
  }

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
      final facts = await ref.read(loopMfaGatewayProvider).readSecondFactor();
      if (!ref.mounted) return;
      _publish(facts);
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
      final facts = await ref
          .read(loopMfaGatewayProvider)
          .completeTotpEnrollment(code.trim());
      if (!ref.mounted) return false;
      _publish(facts, step: LoopMfaEnrollmentStep.idle, clearSecret: true);
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
      final facts = await ref.read(loopMfaGatewayProvider).removeTotp();
      if (!ref.mounted) return false;
      _publish(facts, removing: false);
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

  /// Creates a passkey on this device and links it to the account.
  ///
  /// The platform runs its own prompt inside the provider's call: the face,
  /// the fingerprint or the screen lock behind them. LOOP sees none of that
  /// and holds nothing afterwards — what it publishes is the credential list
  /// the provider answered with.
  Future<bool> linkPasskey() =>
      _passkeyCall((gateway) => gateway.linkPasskey());

  /// Removes one passkey from the account, after the device says the owner
  /// is present.
  ///
  /// Taking away a way back in is as consequential as adding one, so the
  /// same proof the App lock uses is asked for first. A device that has
  /// nothing to ask with cannot be made to: it is not treated as a refusal,
  /// because that would trap an owner who wants their credential gone.
  Future<bool> unlinkPasskey(String credentialId) async {
    if (state.isBusy) return false;
    final authenticated = await _confirmOwnerPresent('解绑 Passkey 前先验证一次身份');
    if (!authenticated) return false;
    return _passkeyCall((gateway) => gateway.unlinkPasskey(credentialId));
  }

  /// Makes a passkey the account's second factor.
  ///
  /// An account with no passkey gets one first — the provider can only enrol
  /// credentials it already holds — and the credentials that are enrolled are
  /// the ones the link call itself returned, never a list this controller
  /// assembled.
  Future<bool> enablePasskeyMfa() async {
    if (state.isBusy) return false;
    if (!_passkeyConfigured()) return false;
    state = state.copyWith(passkeyWorking: true, clearFailure: true);
    try {
      final gateway = ref.read(loopMfaGatewayProvider);
      var facts = state.hasPasskey
          ? LoopSecondFactorFacts(
              enrollments: state.enrollments,
              passkeys: state.passkeys,
            )
          : await gateway.linkPasskey();
      final credentialIds = <String>[
        for (final passkey in facts.passkeys) passkey.credentialId,
      ];
      if (credentialIds.isEmpty) {
        // The provider answered with no credential, so there is nothing to
        // enrol. Publishing its answer is the honest end of this: the sheet
        // will show an account with no passkey rather than a claim.
        if (!ref.mounted) return false;
        _publish(facts, passkeyWorking: false);
        return false;
      }
      facts = await gateway.enrollPasskeyMfa(credentialIds);
      if (!ref.mounted) return false;
      _publish(facts, passkeyWorking: false);
      return true;
    } on LoopMfaException catch (error) {
      _fail(error, passkeyWorking: false);
      return false;
    } on Object catch (error) {
      _fail(
        LoopMfaException(
          LoopMfaFailureKind.unknown,
          providerMessage: error.toString(),
        ),
        passkeyWorking: false,
      );
      return false;
    }
  }

  /// Stops the provider accepting a passkey as a second factor. The passkey
  /// stays linked as a way back in, which is a different thing.
  Future<bool> disablePasskeyMfa() async {
    if (state.isBusy || !state.hasPasskeyMfa) return false;
    return _passkeyCall((gateway) => gateway.removePasskeyMfa());
  }

  Future<bool> _passkeyCall(
    Future<LoopSecondFactorFacts> Function(LoopMfaGateway gateway) call,
  ) async {
    if (state.isBusy) return false;
    if (!_passkeyConfigured()) return false;
    state = state.copyWith(passkeyWorking: true, clearFailure: true);
    try {
      final facts = await call(ref.read(loopMfaGatewayProvider));
      if (!ref.mounted) return false;
      _publish(facts, passkeyWorking: false);
      return true;
    } on LoopMfaException catch (error) {
      _fail(error, passkeyWorking: false);
      return false;
    } on Object catch (error) {
      _fail(
        LoopMfaException(
          LoopMfaFailureKind.unknown,
          providerMessage: error.toString(),
        ),
        passkeyWorking: false,
      );
      return false;
    }
  }

  /// Refuses a passkey call this build cannot make, without asking the
  /// platform a question it can only answer with an error.
  bool _passkeyConfigured() {
    if (state.canUsePasskey) return true;
    _fail(const LoopMfaException(LoopMfaFailureKind.passkeyDomainUnconfigured));
    return false;
  }

  /// Asks the device to prove the owner is present, when it can be asked.
  Future<bool> _confirmOwnerPresent(String reason) async {
    final authenticator = ref.read(loopDeviceAuthenticatorProvider);
    final capability = await authenticator.readCapability();
    if (!capability.isAvailable) return true;
    final result = await authenticator.authenticate(reason: reason);
    if (result.succeeded) return true;
    _fail(
      LoopMfaException(
        LoopMfaFailureKind.cancelled,
        providerMessage:
            result.systemMessage ?? 'device auth ${result.outcome.name}',
      ),
    );
    return false;
  }

  void _fail(
    LoopMfaException error, {
    LoopMfaPhase? phase,
    LoopMfaEnrollmentStep? step,
    bool? removing,
    bool? passkeyWorking,
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
      passkeyWorking: passkeyWorking ?? state.passkeyWorking,
      failure: error.kind,
      providerMessage: message,
    );
  }
}

final loopMfaProvider = NotifierProvider<LoopMfaController, LoopMfaState>(
  LoopMfaController.new,
);
