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
  /// What the provider currently holds for this account.
  Future<List<LoopMfaEnrollment>> readEnrollments();

  /// Asks the provider for a new TOTP secret. Nothing is enrolled yet: the
  /// account is enrolled by [completeTotpEnrollment], and only if the codes
  /// the authenticator produces actually match.
  Future<LoopTotpSecret> beginTotpEnrollment();

  /// Finishes TOTP enrolment with a code from the authenticator app.
  Future<List<LoopMfaEnrollment>> completeTotpEnrollment(String code);

  /// Removes TOTP from the account.
  Future<List<LoopMfaEnrollment>> removeTotp();
}

/// The gateway a run gets when no Privy session is composed.
///
/// It answers "unavailable" to everything, which is what a page with no
/// provider behind it must say — never "you have no MFA".
final class UnavailableLoopMfaGateway implements LoopMfaGateway {
  const UnavailableLoopMfaGateway();

  @override
  Future<List<LoopMfaEnrollment>> readEnrollments() =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<LoopTotpSecret> beginTotpEnrollment() =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<List<LoopMfaEnrollment>> completeTotpEnrollment(String code) =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<List<LoopMfaEnrollment>> removeTotp() =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);
}

final loopMfaGatewayProvider = Provider<LoopMfaGateway>(
  (ref) => const UnavailableLoopMfaGateway(),
);
