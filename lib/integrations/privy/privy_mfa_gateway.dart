import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:privy_flutter/privy_flutter.dart';

/// Reads and changes the account's second factor at Privy.
///
/// Kept apart from [PrivyAuthGateway] for the same reason
/// [PrivyCredentialGateway] is: a test double for the session does not have
/// to know about MFA, and the SDK's types stay out of the session surface.
abstract interface class PrivyMfaAccountGateway {
  Future<List<LoopMfaEnrollment>> readEnrollments();

  Future<LoopTotpSecret> beginTotpEnrollment();

  Future<List<LoopMfaEnrollment>> completeTotpEnrollment(String code);

  Future<List<LoopMfaEnrollment>> removeTotp();
}

/// The `LoopMfaGateway` the product reads, resolved from whatever Privy
/// gateway this composition installed.
///
/// A run with no SDK session — the Development Preview, an unconfigured
/// build, a widget test — gets the unavailable gateway, which answers
/// "not known" rather than "you have no MFA".
final loopPrivyMfaGatewayProvider = Provider<LoopMfaGateway>((ref) {
  final gateway = ref.watch(privyAuthGatewayProvider);
  if (gateway is PrivyMfaAccountGateway) {
    return _PrivyMfaGateway(gateway as PrivyMfaAccountGateway);
  }
  return const UnavailableLoopMfaGateway();
});

final class _PrivyMfaGateway implements LoopMfaGateway {
  const _PrivyMfaGateway(this._account);

  final PrivyMfaAccountGateway _account;

  @override
  Future<List<LoopMfaEnrollment>> readEnrollments() =>
      _account.readEnrollments();

  @override
  Future<LoopTotpSecret> beginTotpEnrollment() =>
      _account.beginTotpEnrollment();

  @override
  Future<List<LoopMfaEnrollment>> completeTotpEnrollment(String code) =>
      _account.completeTotpEnrollment(code);

  @override
  Future<List<LoopMfaEnrollment>> removeTotp() => _account.removeTotp();
}

/// Turns one Privy MFA answer into LOOP's own vocabulary.
///
/// The provider's sentence travels with the failure so it can be logged, and
/// is never shown as LOOP's explanation. `notEnabled` is the one that matters
/// most: an application whose dashboard has MFA switched off refuses every
/// call, and no amount of retrying on this device will change it.
abstract final class PrivyMfaFailureClassifier {
  static const notEnabledMarkers = <String>[
    'not enabled',
    'not allowed',
    'disabled',
    'not configured',
    'unsupported',
    'mfa is not',
  ];

  static LoopMfaFailureKind of(PrivyException error) {
    if (error is MfaMissingOrInvalidException ||
        error is MfaMaxAttemptsReachedException ||
        error is MfaChallengeExpiredException) {
      return LoopMfaFailureKind.invalidCode;
    }
    if (error is MfaSdkTimeoutException) return LoopMfaFailureKind.rejected;
    final message = error.message.toLowerCase();
    for (final marker in notEnabledMarkers) {
      if (message.contains(marker)) return LoopMfaFailureKind.notEnabled;
    }
    return switch (PrivyFailureClassifier.of(error.message)) {
      PrivyFailureKind.authentication => LoopMfaFailureKind.notAuthenticated,
      PrivyFailureKind.network => LoopMfaFailureKind.unavailable,
      PrivyFailureKind.unknown => LoopMfaFailureKind.unknown,
    };
  }
}

/// What LOOP does when Privy blocks an operation on MFA.
///
/// The SDK holds the operation until `resumeBlockedActions` is called, and
/// fails it after five minutes if nobody does. LOOP has no verification
/// prompt for a blocked wallet operation — there is no on-chain write in this
/// build that could raise one — so the block is released immediately with a
/// stated error. The operation fails in a second with a reason instead of
/// hanging for five minutes with none, and the provider's call is logged so
/// the first one that ever fires can be read rather than guessed at.
final class LoopReleasingMfaListener implements MfaListener {
  const LoopReleasingMfaListener(this._privy);

  static const releasedMessage = 'LOOP 还没有为被二次验证拦住的操作提供输入验证码的入口，这次操作已经取消。';

  final Privy _privy;

  @override
  void onMfaRequired(PrivyUser user) {
    debugPrint(
      'LOOP MFA: the provider blocked an operation for user ${user.id}; '
      'LOOP has no verification prompt, so the block is released as a failure',
    );
    unawaited(
      _privy.mfa.resumeBlockedActions(
        Exception(LoopReleasingMfaListener.releasedMessage),
      ),
    );
  }
}

/// The SDK half, mixed into the gateway that owns the `Privy` instance.
///
/// Every enrolment it returns is read off the `PrivyUser` the call answered
/// with; nothing here records, caches or infers an enrolment of its own.
mixin PrivySdkMfaAccount implements PrivyMfaAccountGateway {
  /// The user Privy currently reports, or `null` when there is no session.
  PrivyUser? get mfaUser;

  @override
  Future<List<LoopMfaEnrollment>> readEnrollments() async {
    final user = _require();
    // A session restored before the account changed elsewhere would answer
    // from a stale user, so the account is refreshed first. A refusal here is
    // reported, never read as "no methods".
    final refreshed = await user.refresh();
    switch (refreshed) {
      case Success<void>():
        break;
      case Failure<void>(error: final error):
        throw LoopMfaException(
          PrivyMfaFailureClassifier.of(error),
          providerMessage: error.message,
        );
    }
    return _enrollments(mfaUser ?? user);
  }

  @override
  Future<LoopTotpSecret> beginTotpEnrollment() async {
    final result = await _require().mfa.totp.enroll.generateSecret();
    switch (result) {
      case Success<TotpSecret>(value: final secret):
        return LoopTotpSecret(secret: secret.secret, authUrl: secret.authUrl);
      case Failure<TotpSecret>(error: final error):
        throw LoopMfaException(
          PrivyMfaFailureClassifier.of(error),
          providerMessage: error.message,
        );
    }
  }

  @override
  Future<List<LoopMfaEnrollment>> completeTotpEnrollment(String code) async {
    final result = await _require().mfa.totp.enroll.submit(code);
    return _applied(result);
  }

  @override
  Future<List<LoopMfaEnrollment>> removeTotp() async {
    final result = await _require().mfa.totp.unenroll();
    return _applied(result);
  }

  List<LoopMfaEnrollment> _applied(Result<PrivyUser> result) {
    switch (result) {
      case Success<PrivyUser>(value: final user):
        return _enrollments(user);
      case Failure<PrivyUser>(error: final error):
        throw LoopMfaException(
          PrivyMfaFailureClassifier.of(error),
          providerMessage: error.message,
        );
    }
  }

  PrivyUser _require() {
    final user = mfaUser;
    if (user == null) {
      throw const LoopMfaException(LoopMfaFailureKind.notAuthenticated);
    }
    return user;
  }

  static List<LoopMfaEnrollment> _enrollments(PrivyUser user) {
    return List.unmodifiable(<LoopMfaEnrollment>[
      for (final method in user.mfaMethods)
        LoopMfaEnrollment(
          kind: switch (method) {
            MfaMethodTotp() => LoopMfaMethodKind.totp,
            MfaMethodSms() => LoopMfaMethodKind.sms,
            MfaMethodPasskey() => LoopMfaMethodKind.passkey,
          },
          verifiedAt: _verifiedAt(method),
        ),
    ]);
  }

  static DateTime? _verifiedAt(MfaMethod method) {
    final seconds = switch (method) {
      MfaMethodTotp(verifiedAt: final value) => value,
      MfaMethodSms(verifiedAt: final value) => value,
      MfaMethodPasskey(verifiedAt: final value) => value,
    };
    if (seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
}
