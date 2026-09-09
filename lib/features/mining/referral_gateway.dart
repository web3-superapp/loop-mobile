import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';

/// Feature-facing port for the `referral` module. It exposes no transport
/// type, no `/v2/` literal and no idempotency detail.
abstract interface class ReferralGateway {
  LaunchGatewayMode get mode;

  /// Reading also issues this account's single invite code on the server.
  Future<ReferralOverview> loadOverview();

  /// Binds one invite code. Allowed only inside the activation window and only
  /// once; every refusal is the server's own decision.
  Future<ReferralBinding> claim(String inviteCode);
}

/// Production default: every call fails closed with `unavailable`. No fixture
/// ever replaces a missing invite code or relationship count.
final class UnavailableReferralGateway implements ReferralGateway {
  const UnavailableReferralGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.unavailable;

  Future<Never> _unavailable() =>
      Future<Never>.error(const LaunchException(LaunchFailureKind.unavailable));

  @override
  Future<ReferralOverview> loadOverview() => _unavailable();

  @override
  Future<ReferralBinding> claim(String inviteCode) => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
final referralGatewayProvider = Provider<ReferralGateway>(
  (ref) => const UnavailableReferralGateway(),
);
