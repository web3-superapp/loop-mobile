import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:privy_flutter/privy_flutter.dart';

/// Reads and changes the account's second factor at Privy.
///
/// Kept apart from [PrivyAuthGateway] for the same reason
/// [PrivyCredentialGateway] is: a test double for the session does not have
/// to know about MFA, and the SDK's types stay out of the session surface.
abstract interface class PrivyMfaAccountGateway {
  Future<LoopSecondFactorFacts> readSecondFactor();

  Future<LoopTotpSecret> beginTotpEnrollment();

  Future<LoopSecondFactorFacts> completeTotpEnrollment(String code);

  Future<LoopSecondFactorFacts> removeTotp();

  Future<LoopSecondFactorFacts> linkPasskey(String relyingParty);

  Future<LoopSecondFactorFacts> unlinkPasskey(String credentialId);

  Future<LoopSecondFactorFacts> enrollPasskeyMfa(List<String> credentialIds);

  Future<LoopSecondFactorFacts> removePasskeyMfa();
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
    return _PrivyMfaGateway(
      gateway as PrivyMfaAccountGateway,
      // A passkey belongs to a domain. This build either has one configured
      // — published at that domain and registered at Privy — or it has none,
      // and then the gateway refuses every passkey call itself instead of
      // letting the platform fail with a sentence nobody can act on.
      ref.watch(appConfigProvider).passkeyRelyingPartyForCurrentBuild,
    );
  }
  return const UnavailableLoopMfaGateway();
});

final class _PrivyMfaGateway implements LoopMfaGateway {
  const _PrivyMfaGateway(this._account, this._relyingParty);

  final PrivyMfaAccountGateway _account;
  final String _relyingParty;

  @override
  String? get passkeyRelyingParty =>
      _relyingParty.isEmpty ? null : _relyingParty;

  @override
  Future<LoopSecondFactorFacts> readSecondFactor() =>
      _account.readSecondFactor();

  @override
  Future<LoopTotpSecret> beginTotpEnrollment() =>
      _account.beginTotpEnrollment();

  @override
  Future<LoopSecondFactorFacts> completeTotpEnrollment(String code) =>
      _account.completeTotpEnrollment(code);

  @override
  Future<LoopSecondFactorFacts> removeTotp() => _account.removeTotp();

  @override
  Future<LoopSecondFactorFacts> linkPasskey() =>
      _account.linkPasskey(_requireRelyingParty());

  @override
  Future<LoopSecondFactorFacts> unlinkPasskey(String credentialId) {
    _requireRelyingParty();
    return _account.unlinkPasskey(credentialId);
  }

  @override
  Future<LoopSecondFactorFacts> enrollPasskeyMfa(List<String> credentialIds) {
    _requireRelyingParty();
    return _account.enrollPasskeyMfa(credentialIds);
  }

  @override
  Future<LoopSecondFactorFacts> removePasskeyMfa() {
    _requireRelyingParty();
    return _account.removePasskeyMfa();
  }

  String _requireRelyingParty() {
    if (_relyingParty.isEmpty) {
      throw const LoopMfaException(
        LoopMfaFailureKind.passkeyDomainUnconfigured,
      );
    }
    return _relyingParty;
  }
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

  /// What the platform says when the owner walked away from its own prompt.
  ///
  /// Android's Credential Manager and iOS's AuthorizationServices both report
  /// a dismissal as an error, and the SDK forwards its message with no code
  /// attached. These are the words those two use.
  static const cancelledMarkers = <String>[
    'cancel',
    'user canceled',
    'user cancelled',
    'notallowederror',
    'aborted',
    'error 1001',
  ];

  /// What the platform says when it has no passkey provider to offer.
  static const unsupportedMarkers = <String>[
    'not supported',
    'unsupported',
    'no create option',
    'no provider',
    'provider configuration',
    'requires api',
    'no credential available',
  ];

  /// What the platform says when the domain has not vouched for this App.
  ///
  /// This is the failure a missing `assetlinks.json`, a missing Apple App
  /// Site Association, an unsigned build or an unregistered relying party all
  /// arrive as. It is LOOP's side of the arrangement, not the owner's.
  static const domainMarkers = <String>[
    'relying party',
    'origin',
    'asset link',
    'assetlinks',
    'associated domain',
    'webcredentials',
    'well-known',
    'apk-key-hash',
    'rp id',
    'rpid',
    'domain',
  ];

  /// One passkey answer, which fails for reasons TOTP never has.
  static LoopMfaFailureKind ofPasskey(PrivyException error) {
    final message = error.message.toLowerCase();
    for (final marker in cancelledMarkers) {
      if (message.contains(marker)) return LoopMfaFailureKind.cancelled;
    }
    for (final marker in domainMarkers) {
      if (message.contains(marker)) {
        return LoopMfaFailureKind.passkeyDomainUnconfigured;
      }
    }
    for (final marker in unsupportedMarkers) {
      if (message.contains(marker)) return LoopMfaFailureKind.deviceUnsupported;
    }
    return of(error);
  }

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

  /// The SDK instance passkeys are linked through. Passkey linking is a
  /// login-method operation and lives on `Privy`, not on `PrivyUser`.
  Privy get mfaPrivy;

  @override
  Future<LoopSecondFactorFacts> readSecondFactor() async {
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
    return _facts(mfaUser ?? user);
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
  Future<LoopSecondFactorFacts> completeTotpEnrollment(String code) async {
    final result = await _require().mfa.totp.enroll.submit(code);
    return _applied(result);
  }

  @override
  Future<LoopSecondFactorFacts> removeTotp() async {
    final result = await _require().mfa.totp.unenroll();
    return _applied(result);
  }

  /// Creates a passkey for this account at [relyingParty].
  ///
  /// The SDK runs the platform's own creation prompt inside this call, so a
  /// dismissal comes back as a failure rather than as an empty success. What
  /// is published afterwards is the credential list the provider returned.
  @override
  Future<LoopSecondFactorFacts> linkPasskey(String relyingParty) async {
    _require();
    final result = await mfaPrivy.passkey.link(
      relyingParty: relyingParty,
      displayName: 'LOOP',
    );
    return _applied(result, passkey: true);
  }

  @override
  Future<LoopSecondFactorFacts> unlinkPasskey(String credentialId) async {
    _require();
    final result = await mfaPrivy.passkey.unlink(credentialId: credentialId);
    return _applied(result, passkey: true);
  }

  @override
  Future<LoopSecondFactorFacts> enrollPasskeyMfa(
    List<String> credentialIds,
  ) async {
    final result = await _require().mfa.passkeys.enroll.submit(credentialIds);
    return _applied(result, passkey: true);
  }

  /// Stops Privy accepting a passkey as a second factor.
  ///
  /// `removeForLogin: false` is the whole point of this call: the second
  /// factor is being switched off, not the owner's way back into the
  /// account. Removing the login method too would take away a credential
  /// nobody asked to lose.
  @override
  Future<LoopSecondFactorFacts> removePasskeyMfa() async {
    final result = await _require().mfa.passkeys.unenroll(
      removeForLogin: false,
    );
    return _applied(result, passkey: true);
  }

  LoopSecondFactorFacts _applied(
    Result<PrivyUser> result, {
    bool passkey = false,
  }) {
    switch (result) {
      case Success<PrivyUser>(value: final user):
        return _facts(user);
      case Failure<PrivyUser>(error: final error):
        throw LoopMfaException(
          passkey
              ? PrivyMfaFailureClassifier.ofPasskey(error)
              : PrivyMfaFailureClassifier.of(error),
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

  /// One provider answer, read into LOOP's two lists.
  ///
  /// Both come off the same `PrivyUser`: the methods it says it accepts and
  /// the passkeys it says it holds. Nothing here is remembered between calls.
  static LoopSecondFactorFacts _facts(PrivyUser user) {
    return LoopSecondFactorFacts(
      enrollments: _enrollments(user),
      passkeys: List.unmodifiable(<LoopPasskeyCredential>[
        for (final account in user.linkedAccounts)
          if (account is PasskeyAccount)
            LoopPasskeyCredential(
              credentialId: account.credentialId,
              label:
                  account.createdWithDevice ??
                  account.authenticatorName ??
                  account.createdWithOs,
              enrolledInMfa: account.enrolledInMfa,
              verifiedAt: _secondsToDate(account.verifiedAt),
            ),
      ]),
    );
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
    return _secondsToDate(seconds);
  }

  static DateTime? _secondsToDate(int seconds) {
    if (seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
}
