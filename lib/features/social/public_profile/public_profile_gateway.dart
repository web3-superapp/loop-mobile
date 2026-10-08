import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';

/// Feature port for another account's profile page (S107 §3).
///
/// Failures are [CommunityGatewayException]s, read the social module's way:
/// `notFound` is the server's `404 PROFILE_NOT_FOUND` — no such account, or
/// one that blocked the viewer, deliberately indistinguishable — and
/// `unavailable` covers a route the server does not serve yet (`404` without
/// that code) and a closed capability (`503`).
abstract interface class PublicProfileGateway {
  CommunityGatewayMode get mode;

  Future<PublicProfileRecord> load(PublicProfileTarget target);

  Future<ProfileHoldings> holdings(String publicProfileId);

  Future<ProfileTradesPage> trades(String publicProfileId, {String? cursor});

  /// `DELETE /v2/friends/{publicProfileId}`: ends the friendship both ways.
  /// Idempotent; the page re-reads the record afterwards.
  Future<void> removeFriend(String publicProfileId);
}

final class UnavailablePublicProfileGateway implements PublicProfileGateway {
  const UnavailablePublicProfileGateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const CommunityGatewayException(CommunityFailureKind.unavailable),
  );

  @override
  Future<PublicProfileRecord> load(PublicProfileTarget target) =>
      _unavailable();

  @override
  Future<ProfileHoldings> holdings(String publicProfileId) => _unavailable();

  @override
  Future<ProfileTradesPage> trades(String publicProfileId, {String? cursor}) =>
      _unavailable();

  @override
  Future<void> removeFriend(String publicProfileId) => _unavailable();
}

final publicProfileGatewayProvider = Provider<PublicProfileGateway>(
  (ref) => const UnavailablePublicProfileGateway(),
);
