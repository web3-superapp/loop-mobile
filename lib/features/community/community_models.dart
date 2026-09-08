import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

enum CommunityVerification {
  pending('pending'),
  verified('verified'),
  rejected('rejected');

  const CommunityVerification(this.wireName);

  final String wireName;

  static CommunityVerification? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

enum CommunityRole {
  owner('owner'),
  admin('admin'),
  member('member');

  const CommunityRole(this.wireName);

  final String wireName;

  String get label => switch (this) {
    CommunityRole.owner => 'Owner',
    CommunityRole.admin => 'Admin',
    CommunityRole.member => '成员',
  };

  static CommunityRole? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

enum CommunityMemberStatus {
  active('active'),
  muted('muted'),
  banned('banned');

  const CommunityMemberStatus(this.wireName);

  final String wireName;

  static CommunityMemberStatus? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// `GET /v2/communities` sort. Only the two server-backed orders exist; the
/// prototype's other segments have no source and stay disabled.
enum CommunityDirectorySort {
  members('members'),
  newest('newest');

  const CommunityDirectorySort(this.wireName);

  final String wireName;
}

enum CommunityVerificationFilter {
  verified('verified'),
  all('all');

  const CommunityVerificationFilter(this.wireName);

  final String wireName;
}

enum CommunityMembershipFilter {
  all('all'),
  joined('joined');

  const CommunityMembershipFilter(this.wireName);

  final String wireName;
}

/// Members directory `role` filter.
///
/// `all`, `owner` and `admin` list active and muted memberships only. `banned`
/// is the governance view of the banned rows: it is the single way to reach an
/// unban, it is open to an owner or an admin only, and the segment counts stay
/// the counts of the non-banned directory, so it carries no count badge.
enum CommunityMemberFilter {
  all('all'),
  owner('owner'),
  admin('admin'),
  banned('banned');

  const CommunityMemberFilter(this.wireName);

  final String wireName;

  /// True for the governance view the server opens to `canBan` viewers only.
  bool get isGovernanceView => this == CommunityMemberFilter.banned;
}

@immutable
final class CommunitySummary {
  const CommunitySummary({
    required this.communityId,
    required this.name,
    required this.slug,
    required this.description,
    required this.logoRef,
    required this.verificationStatus,
    required this.boundAssetKey,
    required this.memberCount,
    required this.createdAt,
    required this.configVersion,
  });

  final String communityId;
  final String name;
  final String slug;
  final String? description;
  final String? logoRef;
  final CommunityVerification verificationStatus;

  /// Stored but never resolved before D10. No price, supply, or holder fact
  /// may be derived from it.
  final String? boundAssetKey;
  final int memberCount;
  final DateTime createdAt;
  final String configVersion;

  bool get isVerified => verificationStatus == CommunityVerification.verified;

  bool get hasBoundAsset => boundAssetKey != null;
}

@immutable
final class CommunityMembership {
  const CommunityMembership({
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  final CommunityRole role;
  final CommunityMemberStatus status;
  final DateTime joinedAt;
}

/// Server-decided action visibility. The client never recomputes the matrix.
@immutable
final class CommunityViewer {
  const CommunityViewer({
    required this.membership,
    required this.canInviteAdmin,
    required this.canMute,
    required this.canBan,
  });

  final CommunityMembership? membership;
  final bool canInviteAdmin;
  final bool canMute;
  final bool canBan;

  bool get hasJoined => membership != null;

  bool get isOwner => membership?.role == CommunityRole.owner;

  bool get canGovern => canInviteAdmin || canMute || canBan;
}

@immutable
final class CommunityDetail {
  const CommunityDetail({
    required this.community,
    required this.viewer,
    required this.miningPower,
    required this.onlineCount,
    required this.announcements,
    required this.officialLinks,
  });

  final CommunitySummary community;
  final CommunityViewer viewer;
  final LoopUnavailableFact miningPower;
  final LoopUnavailableFact onlineCount;
  final LoopUnavailableFact announcements;
  final LoopUnavailableFact officialLinks;
}

@immutable
final class JoinedCommunity {
  const JoinedCommunity({required this.community, required this.membership});

  final CommunitySummary community;
  final CommunityMembership membership;
}

@immutable
final class CommunityRecommendation {
  const CommunityRecommendation({
    required this.recommendationId,
    required this.ruleVersion,
  });

  final String recommendationId;

  /// The versioned rule that produced the list. The UI cites it and never
  /// calls the result an algorithmic recommendation.
  final String ruleVersion;
}

@immutable
final class CommunityHome {
  const CommunityHome({
    required this.joined,
    required this.joinedTruncated,
    required this.discover,
    required this.unread,
    required this.liveVoice,
    required this.observedAt,
    required this.source,
    required this.recommendation,
  });

  final List<JoinedCommunity> joined;

  /// The aggregate could not carry every joined community; "view all" must go
  /// through the paginated directory.
  final bool joinedTruncated;
  final List<CommunitySummary> discover;
  final LoopUnavailableFact unread;
  final LoopUnavailableFact liveVoice;
  final DateTime observedAt;
  final String source;
  final CommunityRecommendation recommendation;
}

@immutable
final class CommunityDirectoryPage {
  const CommunityDirectoryPage({
    required this.items,
    required this.nextCursor,
    required this.recommendation,
  });

  final List<CommunitySummary> items;

  /// Opaque; echoed back verbatim and never parsed.
  final String? nextCursor;
  final CommunityRecommendation recommendation;
}

@immutable
final class CommunityMemberEntry {
  const CommunityMemberEntry({
    required this.profile,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.isSelf,
    required this.miningPower,
  });

  final LoopPublicProfile profile;
  final CommunityRole role;
  final CommunityMemberStatus status;
  final DateTime joinedAt;
  final bool isSelf;
  final LoopUnavailableFact miningPower;

  /// A row can only be a governance target when it is another account with a
  /// profile row.
  bool get isActionable => !isSelf && profile.isCommandTarget;
}

@immutable
final class CommunityMemberCounts {
  const CommunityMemberCounts({
    required this.all,
    required this.owner,
    required this.admin,
    required this.online,
  });

  final int all;
  final int owner;
  final int admin;
  final LoopUnavailableFact online;
}

@immutable
final class CommunityMemberDirectory {
  const CommunityMemberDirectory({
    required this.community,
    required this.viewer,
    required this.counts,
    required this.items,
    required this.nextCursor,
  });

  final CommunitySummary community;
  final CommunityViewer viewer;
  final CommunityMemberCounts counts;
  final List<CommunityMemberEntry> items;
  final String? nextCursor;
}

/// Partial owner-only edit. `slug` and `verificationStatus` are not editable.
@immutable
final class CommunityProfileEdit {
  const CommunityProfileEdit({
    this.name,
    this.description,
    this.clearDescription = false,
    this.logoRef,
    this.clearLogoRef = false,
  });

  final String? name;
  final String? description;
  final bool clearDescription;
  final String? logoRef;
  final bool clearLogoRef;

  bool get isEmpty =>
      name == null &&
      description == null &&
      !clearDescription &&
      logoRef == null &&
      !clearLogoRef;
}

@immutable
final class ReferralLevel {
  const ReferralLevel({
    required this.level,
    required this.boostPercent,
    required this.descriptionKey,
  });

  final int level;

  /// Decimal string straight from the server. It is never parsed into a
  /// double and reformatted.
  final String boostPercent;
  final String descriptionKey;
}

@immutable
final class ReferralRules {
  const ReferralRules({
    required this.configVersion,
    required this.effectiveAt,
    required this.appliesTo,
    required this.levels,
    required this.edges,
    required this.inviteCode,
  });

  final String configVersion;
  final DateTime effectiveAt;
  final String appliesTo;
  final List<ReferralLevel> levels;
  final LoopUnavailableFact edges;
  final LoopUnavailableFact inviteCode;
}

/// The field a [CommunityApplication] would be rejected on.
enum CommunityApplicationField { name, slug, description, boundAssetKey }

/// The exact `POST /v2/communities` body.
///
/// The five fields are all submitted; the last three may be null. The shape is
/// checked here so an obviously invalid application never leaves the device,
/// but acceptance stays the server's decision.
@immutable
final class CommunityApplication {
  const CommunityApplication({
    required this.name,
    required this.slug,
    this.description,
    this.logoRef,
    this.boundAssetKey,
  });

  static final RegExp slugPattern = RegExp(r'^[a-z0-9-]{3,32}$');
  static final RegExp boundAssetKeyPattern = RegExp(
    r'^eip155:[1-9][0-9]{0,9}:0x[0-9a-fA-F]{40}$',
  );
  static final RegExp _forbiddenText = RegExp(
    r'[\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}]',
    unicode: true,
  );

  static const nameMaximumRunes = 40;
  static const descriptionMaximumRunes = 280;

  final String name;
  final String slug;
  final String? description;
  final String? logoRef;
  final String? boundAssetKey;

  /// The first field the server would reject, or null when the shape is
  /// acceptable.
  CommunityApplicationField? get invalidField {
    final nameRunes = name.runes.length;
    if (nameRunes < 1 ||
        nameRunes > nameMaximumRunes ||
        name.trim().isEmpty ||
        _forbiddenText.hasMatch(name)) {
      return CommunityApplicationField.name;
    }
    if (!slugPattern.hasMatch(slug)) return CommunityApplicationField.slug;
    final text = description;
    if (text != null &&
        (text.isEmpty ||
            text.runes.length > descriptionMaximumRunes ||
            _forbiddenText.hasMatch(text))) {
      return CommunityApplicationField.description;
    }
    final assetKey = boundAssetKey;
    if (assetKey != null && !boundAssetKeyPattern.hasMatch(assetKey)) {
      return CommunityApplicationField.boundAssetKey;
    }
    return null;
  }
}
