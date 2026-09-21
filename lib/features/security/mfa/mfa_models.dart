import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A second factor the login service can hold for this account.
///
/// These are the provider's, not LOOP's: the account is enrolled at Privy and
/// LOOP only reports what Privy says it holds.
enum LoopMfaMethodKind {
  totp('验证器 App'),
  sms('短信'),
  passkey('Passkey');

  const LoopMfaMethodKind(this.label);

  final String label;
}

@immutable
final class LoopMfaEnrollment {
  const LoopMfaEnrollment({required this.kind, this.verifiedAt});

  final LoopMfaMethodKind kind;

  /// When the provider last verified this method, if it said.
  final DateTime? verifiedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopMfaEnrollment &&
          other.kind == kind &&
          other.verifiedAt == verifiedAt;

  @override
  int get hashCode => Object.hash(kind, verifiedAt);
}

/// Why a second-factor call did not do what was asked.
enum LoopMfaFailureKind {
  /// This build has no domain credential for a passkey, so nothing was asked
  /// of the platform. A passkey belongs to a domain, not to an App, and a
  /// call made without one fails on the device every time.
  passkeyDomainUnconfigured,

  /// The owner dismissed the system's own passkey prompt.
  cancelled,

  /// This device has no passkey provider the platform would let LOOP use.
  deviceUnsupported,

  /// The login service has not opened MFA for this application. Nothing the
  /// owner does on this device can change it.
  notEnabled,

  /// There is no verified Privy session to enrol against.
  notAuthenticated,

  /// The six digits did not match.
  invalidCode,

  /// The owner or the platform stopped the flow.
  rejected,

  /// The service could not be reached, or LOOP has no adapter for it.
  unavailable,

  /// Something else. The provider's own sentence travels with it.
  unknown,
}

/// One passkey the login service says this account holds.
///
/// It is the provider's record, not a device's: the same account read on
/// another phone reports the same credentials. LOOP stores none of it.
@immutable
final class LoopPasskeyCredential {
  const LoopPasskeyCredential({
    required this.credentialId,
    this.label,
    this.enrolledInMfa = false,
    this.verifiedAt,
  });

  /// What the provider calls this credential. It is the handle an unlink is
  /// addressed to and is never shown as a name.
  final String credentialId;

  /// The device or authenticator the provider named, when it named one.
  final String? label;

  /// The provider also accepts this credential as a second factor.
  final bool enrolledInMfa;

  final DateTime? verifiedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopPasskeyCredential &&
          other.credentialId == credentialId &&
          other.label == label &&
          other.enrolledInMfa == enrolledInMfa &&
          other.verifiedAt == verifiedAt;

  @override
  int get hashCode =>
      Object.hash(credentialId, label, enrolledInMfa, verifiedAt);
}

/// Everything the provider answered about this account's second factor in
/// one reply.
///
/// The two lists are different facts and are kept apart: a passkey can be a
/// way back in without being a second factor, and a second factor can exist
/// with no passkey behind it at all.
@immutable
final class LoopSecondFactorFacts {
  const LoopSecondFactorFacts({
    this.enrollments = const <LoopMfaEnrollment>[],
    this.passkeys = const <LoopPasskeyCredential>[],
  });

  /// The methods the provider will accept as a second factor.
  final List<LoopMfaEnrollment> enrollments;

  /// The passkeys the provider holds as ways into this account.
  final List<LoopPasskeyCredential> passkeys;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopSecondFactorFacts &&
          listEquals(other.enrollments, enrollments) &&
          listEquals(other.passkeys, passkeys);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(enrollments), Object.hashAll(passkeys));
}

final class LoopMfaException implements Exception {
  const LoopMfaException(this.kind, {this.providerMessage});

  final LoopMfaFailureKind kind;

  /// What the provider said, verbatim. It is never printed as LOOP's own
  /// explanation; it exists so a failure can be read in a debug log instead
  /// of guessed at.
  final String? providerMessage;

  @override
  String toString() =>
      'LoopMfaException(${kind.name}${providerMessage == null ? '' : ', $providerMessage'})';
}

/// What an authenticator app needs to start generating codes.
@immutable
final class LoopTotpSecret {
  const LoopTotpSecret({required this.secret, required this.authUrl});

  /// The key to type in by hand.
  final String secret;

  /// `otpauth://totp/…`, for the square.
  final String authUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopTotpSecret &&
          other.secret == secret &&
          other.authUrl == authUrl;

  @override
  int get hashCode => Object.hash(secret, authUrl);
}

/// The login service's second factor, as a port.
///
/// The one implementation that talks to the Privy SDK lives in
/// `lib/integrations/privy/`. Every method either returns what the provider
/// answered or throws [LoopMfaException]; none of them may report an
/// enrolment the provider did not confirm.
abstract interface class LoopMfaGateway {
  /// The domain a passkey made through this gateway would belong to, or
  /// `null` when this build has no domain credential.
  ///
  /// It is read rather than passed in so the decision lives in one place:
  /// the page asks whether a passkey can be offered at all, and the adapter
  /// is the only thing that knows the answer.
  String? get passkeyRelyingParty;

  /// What the provider currently holds for this account.
  Future<LoopSecondFactorFacts> readSecondFactor();

  /// Asks the provider for a new TOTP secret. Nothing is enrolled yet: the
  /// account is enrolled by [completeTotpEnrollment], and only if the codes
  /// the authenticator produces actually match.
  Future<LoopTotpSecret> beginTotpEnrollment();

  /// Finishes TOTP enrolment with a code from the authenticator app.
  Future<LoopSecondFactorFacts> completeTotpEnrollment(String code);

  /// Removes TOTP from the account.
  Future<LoopSecondFactorFacts> removeTotp();

  /// Creates a passkey on this device and links it to the account as a way
  /// back in. The system's own prompt runs inside this call.
  Future<LoopSecondFactorFacts> linkPasskey();

  /// Removes one passkey from the account, by the handle the provider gave
  /// it. Nothing is removed from the device's keychain by this: the platform
  /// owns that copy, and the provider stops accepting it.
  Future<LoopSecondFactorFacts> unlinkPasskey(String credentialId);

  /// Asks the provider to also accept the named passkeys as a second factor.
  Future<LoopSecondFactorFacts> enrollPasskeyMfa(List<String> credentialIds);

  /// Stops the provider accepting passkeys as a second factor. The passkeys
  /// stay linked as ways back in.
  Future<LoopSecondFactorFacts> removePasskeyMfa();
}

/// The gateway a run gets when no Privy session is composed.
///
/// It answers "unavailable" to everything, which is what a page with no
/// provider behind it must say — never "you have no MFA".
final class UnavailableLoopMfaGateway implements LoopMfaGateway {
  const UnavailableLoopMfaGateway();

  @override
  String? get passkeyRelyingParty => null;

  @override
  Future<LoopSecondFactorFacts> readSecondFactor() =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<LoopTotpSecret> beginTotpEnrollment() =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<LoopSecondFactorFacts> completeTotpEnrollment(String code) =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<LoopSecondFactorFacts> removeTotp() =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<LoopSecondFactorFacts> linkPasskey() =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<LoopSecondFactorFacts> unlinkPasskey(String credentialId) =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<LoopSecondFactorFacts> enrollPasskeyMfa(List<String> credentialIds) =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<LoopSecondFactorFacts> removePasskeyMfa() =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);
}

final loopMfaGatewayProvider = Provider<LoopMfaGateway>(
  (ref) => const UnavailableLoopMfaGateway(),
);
