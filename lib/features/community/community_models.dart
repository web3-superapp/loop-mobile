import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';

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

/// `GET /v2/communities` sort.
///
/// The four the prototype draws all exist on the wire (decision 0061): the
/// two stored columns, the settled community power and the messages the
/// official channel was seen carrying over the last week. There is no
/// 「增长最快」 segment, because nothing measures growth.
enum CommunityDirectorySort {
  members('members'),
  newest('newest'),
  miningPower('miningPower'),
  activity('activity');

  const CommunityDirectorySort(this.wireName);

  final String wireName;

  static CommunityDirectorySort? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }

  /// True when the row carries the fact it was ordered by. The two stored
  /// sorts carry nothing extra, and an item that still did would be a
  /// projection this client cannot place.
  bool get carriesRowFact =>
      this == CommunityDirectorySort.miningPower ||
      this == CommunityDirectorySort.activity;
}

/// What a discover page was ordered by, as the server states it.
///
/// It is always answered, and it is read before the rows: an empty page under
/// an `unavailable` ordering is a question nobody could answer, not a
/// directory with no communities in it.
@immutable
sealed class CommunityOrdering {
  const CommunityOrdering({required this.sort});

  final CommunityDirectorySort sort;
}

@immutable
final class CommunityOrderingApplied extends CommunityOrdering {
  const CommunityOrderingApplied({required super.sort, required this.basis});

  final CommunityOrderingBasis basis;
}

@immutable
final class CommunityOrderingUnavailable extends CommunityOrdering {
  const CommunityOrderingUnavailable({
    required super.sort,
    required this.reasonCode,
  });

  final String reasonCode;
}

/// Where the order came from. The client never restates it as a number; it
/// only decides whether the page may carry a development-baseline label and
/// whether the figures it ranks by are older than the newest run.
@immutable
sealed class CommunityOrderingBasis {
  const CommunityOrderingBasis();
}

/// A column the community row already stores: the member count, the creation
/// time. Nothing dates it beyond the row itself.
@immutable
final class CommunityStoredBasis extends CommunityOrderingBasis {
  const CommunityStoredBasis();
}

/// The settled run every mining read resolves to, so the ranking and the
/// mining pages can never disagree about which numbers are in force.
@immutable
final class CommunityMiningBasis extends CommunityOrderingBasis {
  const CommunityMiningBasis({
    required this.snapshotId,
    required this.formulaVersion,
    required this.computedAt,
    required this.scope,
    required this.stale,
  });

  final String snapshotId;

  /// A backend identifier. It belongs in a LoopDisclosure, never in a
  /// sentence.
  final String formulaVersion;
  final DateTime computedAt;
  final MiningFormulaScope scope;

  /// True when a later run did not complete, exactly as on the mining pages.
  final bool stale;
}

/// Messages counted inside a window that the server closed itself.
@immutable
final class CommunityActivityBasis extends CommunityOrderingBasis {
  const CommunityActivityBasis({
    required this.windowDays,
    required this.observedCommunityCount,
    required this.observedAt,
  });

  final int windowDays;
  final int observedCommunityCount;
  final DateTime observedAt;
}

/// One community's message count inside the activity window.
@immutable
sealed class CommunityActivityFact {
  const CommunityActivityFact();
}

@immutable
final class CommunityActivityCount extends CommunityActivityFact {
  const CommunityActivityCount({
    required this.messageCount,
    required this.windowDays,
    required this.bounded,
    required this.observedAt,
  });

  final int messageCount;
  final int windowDays;

  /// True when the page of messages read was full and still began inside the
  /// window: more exist than were counted, so [messageCount] is a floor and
  /// the row must be rendered as one.
  final bool bounded;
  final DateTime observedAt;
}

@immutable
final class CommunityActivityUnavailable extends CommunityActivityFact {
  const CommunityActivityUnavailable(this.reasonCode);

  final String reasonCode;
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
    this.miningPower,
    this.activity,
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

  /// The community's settled power, carried only by a discover page ordered
  /// by it (decision 0061). Everywhere else it is absent — not zero, and not
  /// unavailable: the row was never asked for it.
  final LoopMiningPowerFact? miningPower;

  /// The messages the official channel was seen carrying inside the window,
  /// carried only by a discover page ordered by it.
  final CommunityActivityFact? activity;

  bool get isVerified => verificationStatus == CommunityVerification.verified;

  bool get hasBoundAsset => boundAssetKey != null;
}

/// The owner's own view of a community application's review state.
///
/// It is projected **only to the current owner** (backend decision 0073), on
/// the record and on the `owned` group of the home aggregate. Every other
/// viewer receives nothing at all, which is why its absence is never an error
/// here: a stranger reading a community is not reading a failed projection,
/// they are reading a community.
///
/// The three states pair with the review columns: `pending` has been reviewed
/// by nobody, `verified` carries the time it was reviewed and no reason, and
/// `rejected` carries the time and — when the operator gave one — the reason.
@immutable
final class CommunityApplicationReview {
  const CommunityApplicationReview({
    required this.status,
    required this.submittedAt,
    required this.reviewedAt,
    required this.rejectedReason,
  });

  final CommunityVerification status;

  /// The last submission. A resubmission moves it forward, so 「提交于」 is
  /// always the date of the version under review and never the first try.
  final DateTime submittedAt;

  /// When the operator answered. Null while the application is pending.
  final DateTime? reviewedAt;

  /// Why it was refused, in the operator's own words. Null when the
  /// application was not refused, and null when it was refused without one —
  /// the page states the refusal either way and invents no cause.
  final String? rejectedReason;

  bool get isPending => status == CommunityVerification.pending;

  bool get isVerified => status == CommunityVerification.verified;

  /// True when the owner may edit the profile and submit it again.
  bool get isRejected => status == CommunityVerification.rejected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityApplicationReview &&
          other.status == status &&
          other.submittedAt == submittedAt &&
          other.reviewedAt == reviewedAt &&
          other.rejectedReason == rejectedReason;

  @override
  int get hashCode =>
      Object.hash(status, submittedAt, reviewedAt, rejectedReason);
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

/// One governance command the server published for a member row.
///
/// `wireName` is the server's `items[].actions` value, which is the name of
/// the cell in its actor x action x target permission matrix. The client
/// parses the published list and renders it; it never decides that a command
/// is available, and it never maps a viewer-level flag onto a row.
enum CommunityGovernanceAction {
  promote('assignAdmin'),
  demote('revokeAdmin'),
  transfer('transferOwnership'),
  mute('mute'),
  unmute('unmute'),
  ban('ban'),
  unban('unban');

  const CommunityGovernanceAction(this.wireName);

  final String wireName;

  static CommunityGovernanceAction? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// Viewer-level governance standing, mirroring the server's `viewer` block.
///
/// These flags carry no target: they say whether the viewer holds a right
/// somewhere in this community, and they gate page-level affordances only
/// (the banned segment). A member row's commands are
/// `CommunityMemberEntry.actions` and nothing else.
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

  /// Owner and admin are the two roles the server admits to opening a voice
  /// room. The role is the server's own viewer projection, not a client-side
  /// reading of the permission matrix, and the server still decides the write.
  bool get mayOpenVoiceRoom =>
      membership?.role == CommunityRole.owner ||
      membership?.role == CommunityRole.admin;

  bool get canGovern => canInviteAdmin || canMute || canBan;
}

/// Whether the official community channel can be opened right now.
///
/// `syncing` is deliberately not `unavailable`: LOOP has recorded the
/// membership intent and the provider has not caught up yet, so the page says
/// so instead of claiming the feature is off.
enum CommunityChatStatus {
  available('available'),
  syncing('syncing'),
  unavailable('unavailable');

  const CommunityChatStatus(this.wireName);

  final String wireName;

  static CommunityChatStatus? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// The channel-member projection. It distinguishes copy only; it never proves
/// a Stream fact.
enum CommunityChatMemberState {
  synced('synced'),
  pending('pending'),
  removed('removed'),
  capacityPending('capacityPending');

  const CommunityChatMemberState(this.wireName);

  final String wireName;

  static CommunityChatMemberState? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// Whether the persona LOOP issued has reached the provider.
///
/// `pending` means LOOP has the name and the channel member does not carry it
/// yet, so the room still reads the neutral label for this account.
enum CommunityChatPersonaProjection {
  pending('pending'),
  confirmed('confirmed');

  const CommunityChatPersonaProjection(this.wireName);

  final String wireName;

  static CommunityChatPersonaProjection? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// The name this account is shown under inside one community's official group.
///
/// Decision 0055: every `(community, account)` pair has one server-issued,
/// immutable, community-unique persona. It is the only name LOOP may state
/// about the reader in that room, and it says nothing about anybody else —
/// another member's name is read from that member's own channel projection
/// and from nowhere else.
@immutable
final class CommunityChatPersona {
  const CommunityChatPersona({
    required this.alias,
    required this.projectionState,
  });

  final String alias;
  final CommunityChatPersonaProjection projectionState;

  bool get isPending =>
      projectionState == CommunityChatPersonaProjection.pending;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityChatPersona &&
          other.alias == alias &&
          other.projectionState == projectionState;

  @override
  int get hashCode => Object.hash(alias, projectionState);
}

/// The `chat` section of a community record.
///
/// Only [CommunityChatStatus.available] ever carries a [channelCid]; every
/// other state carries the server's own `reasonCode` and no channel.
@immutable
final class CommunityChatSection {
  const CommunityChatSection({
    required this.status,
    required this.channelCid,
    required this.memberState,
    required this.reasonCode,
    this.viewerPersona,
  });

  final CommunityChatStatus status;
  final String? channelCid;
  final CommunityChatMemberState? memberState;
  final String? reasonCode;

  /// The reader's own name in this community, when the server has issued one.
  /// `null` means it has not been generated yet, or this account is not a
  /// member — the page states neither in place of the other.
  final CommunityChatPersona? viewerPersona;

  bool get isAvailable =>
      status == CommunityChatStatus.available && channelCid != null;

  bool get isSyncing => status == CommunityChatStatus.syncing;
}

enum CommunityVoiceStatus {
  available('available'),
  unavailable('unavailable');

  const CommunityVoiceStatus(this.wireName);

  final String wireName;

  static CommunityVoiceStatus? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// The `voice` section of a community record. It only says whether a live room
/// exists; joining is still a separate server decision.
@immutable
final class CommunityVoiceSection {
  const CommunityVoiceSection({
    required this.status,
    required this.currentRoomId,
    required this.reasonCode,
  });

  final CommunityVoiceStatus status;
  final String? currentRoomId;
  final String? reasonCode;

  bool get isLive =>
      status == CommunityVoiceStatus.available && currentRoomId != null;
}

/// One announcement a community published about itself.
///
/// It is a record of something the community said, so every field on it is
/// the server's: the client never composes a title, never re-dates a post and
/// never promotes one row over another. `pinned` is the server's own flag and
/// the list arrives in the server's order.
@immutable
final class CommunityAnnouncement {
  const CommunityAnnouncement({
    required this.announcementId,
    required this.kind,
    required this.title,
    required this.byline,
    required this.publishedAt,
    required this.pinned,
  });

  final String announcementId;

  /// What sort of announcement it is, as the server named it.
  ///
  /// It is deliberately not an enum: it selects the row's glyph and nothing
  /// else — no permission, no route, no claim — so a kind this build has not
  /// seen draws the neutral glyph instead of failing a page whose title,
  /// byline and time are all perfectly readable. It is never rendered.
  final String kind;

  final String title;

  /// Who published it, when the server says who. `null` is a stated absence.
  final String? byline;
  final DateTime publishedAt;
  final bool pinned;
}

/// `announcements`: the published list, or the server's reason for not having
/// one. An available list that is empty is a reading of its own — this
/// community has announced nothing — and is never dressed as unavailable.
@immutable
sealed class CommunityAnnouncementFeed {
  const CommunityAnnouncementFeed();
}

@immutable
final class CommunityAnnouncementFeedUnavailable
    extends CommunityAnnouncementFeed {
  const CommunityAnnouncementFeedUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityAnnouncementFeedUnavailable &&
          other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

@immutable
final class CommunityAnnouncementFeedPublished
    extends CommunityAnnouncementFeed {
  const CommunityAnnouncementFeedPublished(this.items);

  /// In the server's order, pinned rows included where the server put them.
  final List<CommunityAnnouncement> items;
}

/// One official link a community publishes about itself.
@immutable
final class CommunityOfficialLink {
  const CommunityOfficialLink({required this.label, required this.url});

  final String label;

  /// `https://` only, checked on the way in.
  final String url;
}

/// `officialLinks`: the published list, or the server's reason for not having
/// one. As with the announcements, an empty available list is a reading.
@immutable
sealed class CommunityOfficialLinkList {
  const CommunityOfficialLinkList();
}

@immutable
final class CommunityOfficialLinksUnavailable
    extends CommunityOfficialLinkList {
  const CommunityOfficialLinksUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityOfficialLinksUnavailable &&
          other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

@immutable
final class CommunityOfficialLinksPublished extends CommunityOfficialLinkList {
  const CommunityOfficialLinksPublished(this.items);

  final List<CommunityOfficialLink> items;
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
    required this.chat,
    required this.voice,
    this.application,
  });

  final CommunitySummary community;
  final CommunityViewer viewer;

  /// The review state of this community's application, projected to the
  /// current owner only. `null` for every other viewer — an absence the
  /// contract states, not a read that failed.
  final CommunityApplicationReview? application;
  final LoopMiningPowerFact miningPower;

  /// Members connected to Stream at the moment this page was read, or the
  /// server's own reason for not having counted them.
  final CommunityOnlineCount onlineCount;

  /// The community's own published announcements, or the server's reason for
  /// publishing none.
  final CommunityAnnouncementFeed announcements;

  /// The links the community publishes about itself, or the server's reason
  /// for publishing none.
  final CommunityOfficialLinkList officialLinks;
  final CommunityChatSection chat;
  final CommunityVoiceSection voice;
}

@immutable
final class JoinedCommunity {
  const JoinedCommunity({required this.community, required this.membership});

  final CommunitySummary community;
  final CommunityMembership membership;
}

/// One community the reader currently owns, with the review state of its
/// application.
///
/// It is a separate group from [JoinedCommunity] because the server puts a
/// community in exactly one of the two (backend decision 0073): an owner's own
/// community is no longer listed among the ones they joined. The two are not
/// interchangeable — this one carries an application, and only its owner can
/// be handed one.
@immutable
final class OwnedCommunity {
  const OwnedCommunity({
    required this.community,
    required this.membership,
    this.application,
  });

  final CommunitySummary community;
  final CommunityMembership membership;

  /// The review state, when the aggregate carried one. A deployment that
  /// predates the review columns sends no block, and the row then states the
  /// community's own `verificationStatus` without a submission date.
  final CommunityApplicationReview? application;

  /// What the row says this application is in: the review block when there is
  /// one, and otherwise the community's stored verification state.
  CommunityVerification get status =>
      application?.status ?? community.verificationStatus;
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
    this.owned = const <OwnedCommunity>[],
    this.ownedTruncated = false,
  });

  /// The memberships that are **not** this account's own communities.
  final List<JoinedCommunity> joined;

  /// The aggregate could not carry every joined community; "view all" must go
  /// through the paginated directory.
  final bool joinedTruncated;

  /// The communities this account owns, newest submission first.
  ///
  /// Empty is the ordinary answer — most accounts have never applied — and is
  /// also what a deployment that predates the group answers. The surfaces that
  /// read it draw nothing at all when it is empty; they never draw an empty
  /// group.
  final List<OwnedCommunity> owned;

  final bool ownedTruncated;
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
    required this.ordering,
  });

  final List<CommunitySummary> items;

  /// Opaque; echoed back verbatim and never parsed.
  final String? nextCursor;
  final CommunityRecommendation recommendation;

  /// What the page was ordered by. Read it before [items]: an empty page
  /// under an unavailable ordering says the order could not be applied, and
  /// rendering it as 「没有社区」 would be a claim nobody measured.
  final CommunityOrdering ordering;

  /// True when the page could not be ordered at all.
  bool get orderingFailed => ordering is CommunityOrderingUnavailable;
}

@immutable
final class CommunityMemberEntry {
  const CommunityMemberEntry({
    required this.profile,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.isSelf,
    required this.actions,
    required this.miningPower,
  });

  final LoopPublicProfile profile;
  final CommunityRole role;
  final CommunityMemberStatus status;
  final DateTime joinedAt;
  final bool isSelf;

  /// The governance commands the server says this viewer may run against this
  /// row, in the server's order.
  ///
  /// It is the complete and only source of row-action visibility. An empty
  /// list means the row offers nothing, and the client adds no rule of its
  /// own: the owner row, the viewer's own row, a row with no public profile
  /// ID, a state a command cannot be applied to, and every cell the
  /// permission matrix denies all arrive here as an empty list.
  final List<CommunityGovernanceAction> actions;
  final LoopMiningPowerFact miningPower;
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
