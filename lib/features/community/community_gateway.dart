import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';

/// Feature-facing port for the `community` module. It exposes no transport
/// type, no `/v2/` literal and no idempotency detail.
abstract interface class CommunityGateway {
  CommunityGatewayMode get mode;

  Future<CommunityHome> loadHome();

  Future<CommunityDirectoryPage> listCommunities({
    CommunityDirectorySort sort,
    CommunityVerificationFilter verification,
    CommunityMembershipFilter membership,
    String? cursor,
  });

  /// Applies for a new community. The applicant becomes its owner and the
  /// result is always `pending`: there is no self-service verification.
  Future<CommunityDetail> createCommunity(CommunityApplication application);

  Future<CommunityDetail> loadCommunity(String communityId);

  Future<CommunityDetail> join(String communityId);

  Future<CommunityDetail> leave(String communityId);

  Future<CommunityDetail> editProfile(
    String communityId,
    CommunityProfileEdit edit,
  );

  /// Lists the member directory. `q` narrows the page to a member alias
  /// prefix; the server owns the normalization and the length bound. A cursor
  /// is bound to the query it was issued for, so a caller that changes `q`
  /// must start again at the first page.
  Future<CommunityMemberDirectory> listMembers(
    String communityId, {
    CommunityMemberFilter role,
    String? q,
    String? cursor,
  });

  Future<CommunityMemberDirectory> changeMemberRole({
    required String communityId,
    required String publicProfileId,
    required CommunityRole role,
  });

  Future<CommunityMemberDirectory> setMuted({
    required String communityId,
    required String publicProfileId,
    required bool muted,
  });

  Future<CommunityMemberDirectory> setBanned({
    required String communityId,
    required String publicProfileId,
    required bool banned,
  });

  Future<ReferralRules> loadReferralRules();
}

/// Production default: every call fails closed with `unavailable`. No fixture
/// ever replaces a missing community fact.
final class UnavailableCommunityGateway implements CommunityGateway {
  const UnavailableCommunityGateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const CommunityGatewayException(CommunityFailureKind.unavailable),
  );

  @override
  Future<CommunityHome> loadHome() => _unavailable();

  @override
  Future<CommunityDirectoryPage> listCommunities({
    CommunityDirectorySort sort = CommunityDirectorySort.members,
    CommunityVerificationFilter verification =
        CommunityVerificationFilter.verified,
    CommunityMembershipFilter membership = CommunityMembershipFilter.all,
    String? cursor,
  }) => _unavailable();

  @override
  Future<CommunityDetail> createCommunity(CommunityApplication application) =>
      _unavailable();

  @override
  Future<CommunityDetail> loadCommunity(String communityId) => _unavailable();

  @override
  Future<CommunityDetail> join(String communityId) => _unavailable();

  @override
  Future<CommunityDetail> leave(String communityId) => _unavailable();

  @override
  Future<CommunityDetail> editProfile(
    String communityId,
    CommunityProfileEdit edit,
  ) => _unavailable();

  @override
  Future<CommunityMemberDirectory> listMembers(
    String communityId, {
    CommunityMemberFilter role = CommunityMemberFilter.all,
    String? q,
    String? cursor,
  }) => _unavailable();

  @override
  Future<CommunityMemberDirectory> changeMemberRole({
    required String communityId,
    required String publicProfileId,
    required CommunityRole role,
  }) => _unavailable();

  @override
  Future<CommunityMemberDirectory> setMuted({
    required String communityId,
    required String publicProfileId,
    required bool muted,
  }) => _unavailable();

  @override
  Future<CommunityMemberDirectory> setBanned({
    required String communityId,
    required String publicProfileId,
    required bool banned,
  }) => _unavailable();

  @override
  Future<ReferralRules> loadReferralRules() => _unavailable();
}

/// Overridden by the composition root (production adapter) and by
/// `main_preview.dart` (labelled memory adapter).
final communityGatewayProvider = Provider<CommunityGateway>(
  (ref) => const UnavailableCommunityGateway(),
);
