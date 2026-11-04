import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/reown/external_wallet_credential_gateway.dart';
import 'package:loop_mobile/integrations/reown/reown_external_wallet_connector.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

enum EmailAuthStep { enterEmail, enterCode }

/// What the last failure was about.
///
/// The Privy gateway returns one sanitized message and no transport
/// classification, so this records which command failed, never why.
enum EmailAuthFailureKind {
  /// A verification attempt was rejected.
  rejected,

  /// A send or resend did not complete. Whether a code went out is unknown.
  deliveryUnconfirmed,
}

/// Client-owned resend cooldown. It is a local rate limit on this device only
/// and never claims a provider-side quota.
const Duration emailAuthResendCooldown = Duration(seconds: 48);

/// Local verification attempts before the client stops submitting. The
/// provider remains authoritative; this only prevents pointless requests.
const int emailAuthMaximumAttempts = 3;

enum IdentityAuthOperation {
  sendEmailCode,
  verifyEmailCode,
  resendEmailCode,
  google,
  apple,
  externalWalletLogin,
  externalWalletLink,
  externalWalletUnlink,
}

/// What one [EmailAuthController.connectExternalWallet] call ended in.
enum ExternalWalletConnectOutcome {
  /// Another identity operation was running; nothing was attempted.
  ignored,

  /// A signed-out session logged in with the wallet.
  loggedIn,

  /// The wallet was linked to the current account.
  linked,

  /// The owner closed the wallet sheet or refused to sign. Not an error.
  cancelled,

  /// Something failed; the sentence is in [EmailAuthState.errorMessage].
  failed,
}

final isIosIdentityPlatformProvider = Provider<bool>((ref) {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
});

/// The device clock used by the local resend cooldown.
///
/// It is a provider rather than a mutable field so a test can substitute an
/// instant without giving production code a writable clock.
final loopDeviceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

@immutable
class EmailAuthState {
  const EmailAuthState({
    this.step = EmailAuthStep.enterEmail,
    this.submittedEmail,
    this.activeOperation,
    this.errorMessage,
    this.successMessage,
    this.resendAvailableAt,
    this.failedAttempts = 0,
    this.failureKind,
  });

  final EmailAuthStep step;
  final String? submittedEmail;
  final IdentityAuthOperation? activeOperation;
  final String? errorMessage;
  final String? successMessage;

  /// Local instant after which a resend may be requested again. Null before a
  /// code has been sent on this device.
  final DateTime? resendAvailableAt;

  /// Rejected verification attempts for the current code on this device.
  final int failedAttempts;

  final EmailAuthFailureKind? failureKind;

  bool get isBusy => activeOperation != null;

  bool get attemptsExhausted => failedAttempts >= emailAuthMaximumAttempts;

  /// True when a send or resend did not confirm delivery. It never claims the
  /// code was wrong, and never claims it was delivered either.
  bool get deliveryUnconfirmed =>
      failureKind == EmailAuthFailureKind.deliveryUnconfirmed;

  int get remainingAttempts => (emailAuthMaximumAttempts - failedAttempts)
      .clamp(0, emailAuthMaximumAttempts);

  /// Whole seconds left in the local cooldown, computed against [now].
  int resendCooldownSeconds(DateTime now) {
    final target = resendAvailableAt;
    if (target == null) return 0;
    final remaining = target.difference(now);
    if (remaining.isNegative) return 0;
    return (remaining.inMilliseconds / 1000).ceil();
  }

  bool canResend(DateTime now) =>
      !isBusy &&
      step == EmailAuthStep.enterCode &&
      resendCooldownSeconds(now) == 0;
}

class EmailAuthController extends Notifier<EmailAuthState> {
  DateTime _now() => ref.read(loopDeviceClockProvider)();

  @override
  EmailAuthState build() => const EmailAuthState();

  Future<void> sendCode(String input) async {
    if (state.isBusy) return;
    final config = ref.read(appConfigProvider);
    if (!config.canInitializePrivy) {
      state = EmailAuthState(
        errorMessage: LoopL10n.current.account_emailAuthControllerErrorMessage,
      );
      return;
    }

    final email = input.trim();
    if (!_isValidEmail(email)) {
      state = EmailAuthState(
        errorMessage: LoopL10n.current.account_emailAuthControllerErrorMessage2,
      );
      return;
    }

    state = EmailAuthState(
      activeOperation: IdentityAuthOperation.sendEmailCode,
      submittedEmail: email,
    );
    try {
      await ref.read(privyAuthGatewayProvider).sendEmailCode(email);
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
        resendAvailableAt: _now().add(emailAuthResendCooldown),
      );
    } on PrivyGatewayException catch (error) {
      state = EmailAuthState(
        submittedEmail: email,
        errorMessage: error.userMessage,
        failureKind: EmailAuthFailureKind.deliveryUnconfirmed,
      );
    }
  }

  Future<void> verifyCode(String input) async {
    if (state.isBusy) return;
    final code = input.trim();
    final email = state.submittedEmail;
    final resendAvailableAt = state.resendAvailableAt;
    final failedAttempts = state.failedAttempts;
    if (email == null) {
      state = EmailAuthState(
        errorMessage: LoopL10n.current.account_emailAuthControllerErrorMessage3,
      );
      return;
    }
    if (state.attemptsExhausted) {
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
        resendAvailableAt: resendAvailableAt,
        failedAttempts: failedAttempts,
        errorMessage: LoopL10n.current.account_emailAuthControllerErrorMessage4,
      );
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
        resendAvailableAt: resendAvailableAt,
        failedAttempts: failedAttempts,
        errorMessage: LoopL10n.current.account_emailAuthControllerErrorMessage5,
      );
      return;
    }

    state = EmailAuthState(
      step: EmailAuthStep.enterCode,
      submittedEmail: email,
      resendAvailableAt: resendAvailableAt,
      failedAttempts: failedAttempts,
      activeOperation: IdentityAuthOperation.verifyEmailCode,
    );
    try {
      final account = await ref
          .read(privyAuthGatewayProvider)
          .verifyEmailCode(email: email, code: code);
      _acceptLoginResult(account);
      state = EmailAuthState(submittedEmail: email);
    } on PrivyGatewayException catch (error) {
      final attempts = failedAttempts + 1;
      final exhausted = attempts >= emailAuthMaximumAttempts;
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
        resendAvailableAt: resendAvailableAt,
        failedAttempts: attempts,
        failureKind: EmailAuthFailureKind.rejected,
        errorMessage: exhausted
            ? LoopL10n.current.account_emailAuthControllerErrorMessage6(
                error.userMessage,
              )
            : LoopL10n.current.account_emailAuthControllerErrorMessage7(
                emailAuthMaximumAttempts - attempts,
                error.userMessage,
              ),
      );
    }
  }

  Future<void> resendCode() async {
    final email = state.submittedEmail;
    if (email == null || state.isBusy) return;
    final now = _now();
    if (state.resendCooldownSeconds(now) > 0) return;
    state = EmailAuthState(
      step: EmailAuthStep.enterCode,
      submittedEmail: email,
      resendAvailableAt: state.resendAvailableAt,
      failedAttempts: state.failedAttempts,
      activeOperation: IdentityAuthOperation.resendEmailCode,
    );
    try {
      await ref.read(privyAuthGatewayProvider).sendEmailCode(email);
      // A newly delivered code resets both the local cooldown and the local
      // attempt budget for that code.
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
        resendAvailableAt: _now().add(emailAuthResendCooldown),
      );
    } on PrivyGatewayException catch (error) {
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
        resendAvailableAt: state.resendAvailableAt,
        failedAttempts: state.failedAttempts,
        failureKind: EmailAuthFailureKind.deliveryUnconfirmed,
        errorMessage: error.userMessage,
      );
    }
  }

  void changeEmail() {
    if (state.isBusy) return;
    state = const EmailAuthState();
  }

  Future<void> loginWithGoogle() =>
      _loginWithOAuth(PrivyOAuthLoginProvider.google);

  Future<void> loginWithApple() async {
    if (!ref.read(isIosIdentityPlatformProvider)) {
      state = EmailAuthState(
        errorMessage: LoopL10n.current.account_emailAuthControllerErrorMessage8,
      );
      return;
    }
    await _loginWithOAuth(PrivyOAuthLoginProvider.apple);
  }

  Future<void> _loginWithOAuth(PrivyOAuthLoginProvider provider) async {
    if (state.isBusy) return;
    final session = ref.read(loopSessionProvider);
    if (session.mode != LoopSessionMode.signedOut) {
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: LoopL10n.current.account_emailAuthControllerErrorMessage9,
      );
      return;
    }
    final config = ref.read(appConfigProvider);
    if (!config.canInitializePrivy) {
      state = EmailAuthState(
        errorMessage:
            LoopL10n.current.account_emailAuthControllerErrorMessage10,
      );
      return;
    }

    final operation = provider == PrivyOAuthLoginProvider.google
        ? IdentityAuthOperation.google
        : IdentityAuthOperation.apple;
    state = EmailAuthState(
      step: state.step,
      submittedEmail: state.submittedEmail,
      activeOperation: operation,
    );
    try {
      final account = await ref
          .read(privyCredentialGatewayProvider)
          .loginWithOAuth(provider);
      if (!ref.mounted) return;
      _acceptLoginResult(account);
      state = const EmailAuthState();
    } on PrivyGatewayException catch (error) {
      if (!ref.mounted) return;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: error.userMessage,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage:
            LoopL10n.current.account_emailAuthControllerErrorMessage11,
      );
    }
  }

  /// Connects an external EVM wallet through Reown and hands the proof to
  /// Privy: a signed-out session logs in with it, an authenticated one links
  /// it to the current account (S306, decision 0246).
  ///
  /// The returned outcome is what the page acts on; [state] still carries the
  /// sentence. While linking, a wallet sheet the owner closed or a signature
  /// the owner refused is not a failure and leaves no message (S306).
  Future<ExternalWalletConnectOutcome> connectExternalWallet(
    BuildContext context,
  ) async {
    if (state.isBusy) return ExternalWalletConnectOutcome.ignored;
    final config = ref.read(appConfigProvider);
    if (!config.canConnectExternalWallet) {
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: config.canInitializePrivy
            ? LoopL10n.current.account_emailAuthControllerErrorMessage12
            : LoopL10n.current.account_emailAuthControllerErrorMessage13,
      );
      return ExternalWalletConnectOutcome.failed;
    }

    final requestedSession = ref.read(loopSessionProvider);
    final (
      intent,
      expectedPrincipal,
      operation,
    ) = switch (requestedSession.mode) {
      LoopSessionMode.signedOut => (
        ExternalWalletCredentialIntent.login,
        null,
        IdentityAuthOperation.externalWalletLogin,
      ),
      LoopSessionMode.authenticated when requestedSession.account != null => (
        ExternalWalletCredentialIntent.link,
        requestedSession.account!.privyUserId,
        IdentityAuthOperation.externalWalletLink,
      ),
      _ => (null, null, null),
    };
    if (intent == null || operation == null) {
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage:
            LoopL10n.current.account_emailAuthControllerErrorMessage14,
      );
      return ExternalWalletConnectOutcome.failed;
    }

    state = EmailAuthState(
      step: state.step,
      submittedEmail: state.submittedEmail,
      activeOperation: operation,
    );
    try {
      final account = await ref
          .read(externalWalletCredentialGatewayProvider)
          .authenticate(
            context: context,
            intent: intent,
            expectedPrivyUserId: expectedPrincipal,
          );
      if (!ref.mounted) return ExternalWalletConnectOutcome.failed;
      if (intent == ExternalWalletCredentialIntent.login) {
        _acceptLoginResult(account);
        state = const EmailAuthState();
        return ExternalWalletConnectOutcome.loggedIn;
      }

      ref
          .read(loopSessionProvider.notifier)
          .acceptLinkedAccount(
            account,
            expectedPrivyUserId: expectedPrincipal!,
          );
      state = EmailAuthState(
        successMessage:
            LoopL10n.current.account_emailAuthControllerSuccessMessage,
      );
      return ExternalWalletConnectOutcome.linked;
    } on ExternalWalletConnectorException catch (error) {
      if (!ref.mounted) return ExternalWalletConnectOutcome.failed;
      if (intent == ExternalWalletCredentialIntent.link &&
          (error.kind == ExternalWalletConnectorFailure.cancelled ||
              error.kind == ExternalWalletConnectorFailure.rejected)) {
        state = EmailAuthState(
          step: state.step,
          submittedEmail: state.submittedEmail,
        );
        return ExternalWalletConnectOutcome.cancelled;
      }
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: error.userMessage,
      );
      return ExternalWalletConnectOutcome.failed;
    } on PrivyGatewayException catch (error) {
      if (!ref.mounted) return ExternalWalletConnectOutcome.failed;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: error.userMessage,
      );
      return ExternalWalletConnectOutcome.failed;
    } catch (_) {
      if (!ref.mounted) return ExternalWalletConnectOutcome.failed;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage:
            LoopL10n.current.account_emailAuthControllerErrorMessage15,
      );
      return ExternalWalletConnectOutcome.failed;
    }
  }

  /// Unlinks one external EVM wallet from the current Privy account (S306).
  ///
  /// [address] is the address the wallet list shows. When the session's own
  /// Privy credentials carry the same wallet, Privy's spelling of it is the
  /// one sent, so a checksum difference can never make the request miss.
  /// Returns `true` once Privy confirmed; the sentence is in [state].
  Future<bool> unlinkExternalWallet(String address) async {
    if (state.isBusy) return false;
    final session = ref.read(loopSessionProvider);
    final account = session.account;
    if (session.mode != LoopSessionMode.authenticated || account == null) {
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage:
            LoopL10n.current.account_emailAuthControllerErrorMessage16,
      );
      return false;
    }
    final target = address.trim();
    var privyAddress = target;
    for (final credential in account.externalEvmCredentials) {
      if (credential.address.toLowerCase() == target.toLowerCase()) {
        privyAddress = credential.address;
        break;
      }
    }
    state = EmailAuthState(
      step: state.step,
      submittedEmail: state.submittedEmail,
      activeOperation: IdentityAuthOperation.externalWalletUnlink,
    );
    try {
      final updated = await ref
          .read(privyCredentialGatewayProvider)
          .unlinkSiwe(
            address: privyAddress,
            expectedPrivyUserId: account.privyUserId,
          );
      if (!ref.mounted) return false;
      ref
          .read(loopSessionProvider.notifier)
          .acceptLinkedAccount(
            updated,
            expectedPrivyUserId: account.privyUserId,
          );
      state = EmailAuthState(
        successMessage:
            LoopL10n.current.account_emailAuthControllerSuccessMessage2,
      );
      return true;
    } on PrivyGatewayException catch (error) {
      if (!ref.mounted) return false;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: error.userMessage,
      );
      return false;
    } catch (_) {
      if (!ref.mounted) return false;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage:
            LoopL10n.current.account_emailAuthControllerErrorMessage17,
      );
      return false;
    }
  }

  void clearFeedback() {
    if (state.isBusy) return;
    state = EmailAuthState(
      step: state.step,
      submittedEmail: state.submittedEmail,
    );
  }

  void _acceptLoginResult(PrivyAccountSummary account) {
    final current = ref.read(loopSessionProvider);
    final isPreAuthentication =
        current.isRestoring || current.mode == LoopSessionMode.signedOut;
    final alreadyAcceptedSamePrincipal =
        current.mode == LoopSessionMode.authenticated &&
        current.account?.privyUserId == account.privyUserId;
    if (!isPreAuthentication && !alreadyAcceptedSamePrincipal) {
      throw PrivyGatewayException(
        LoopL10n.current.account_emailAuthControllerErrorMessage9,
      );
    }
    ref.read(loopSessionProvider.notifier).acceptAuthenticated(account);
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }
}

final emailAuthProvider = NotifierProvider<EmailAuthController, EmailAuthState>(
  EmailAuthController.new,
);
