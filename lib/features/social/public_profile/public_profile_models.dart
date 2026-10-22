import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

/// Another account, as `GET /v2/profiles/{id}` states it (S107 §3,
/// decision 0112).
///
/// The record is the server's whole answer and nothing more: no wallet
/// address, no figure the server did not send. Relationship facts are the
/// server's own and every action re-reads them rather than assuming its own
/// effect.
enum ProfileFriendship {
  none('none'),
  pendingOut('pending_out'),
  pendingIn('pending_in'),
  friends('friends');

  const ProfileFriendship(this.wireName);

  final String wireName;

  static ProfileFriendship? tryParse(Object? value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

@immutable
final class PublicProfileCounts {
  const PublicProfileCounts({
    required this.followers,
    required this.following,
    required this.communities,
  });

  final int followers;
  final int following;
  final int communities;
}

@immutable
final class PublicProfileRelationship {
  const PublicProfileRelationship({
    required this.following,
    required this.followedBy,
    required this.friendship,
    required this.blocked,
    required this.blockedBy,
  });

  /// The viewer follows this account.
  final bool following;

  /// This account follows the viewer.
  final bool followedBy;
  final ProfileFriendship friendship;

  /// The viewer blocked this account.
  final bool blocked;

  /// This account blocked the viewer. The server answers `404` instead of a
  /// record in that case; a record that says `true` is still honoured.
  final bool blockedBy;

  PublicProfileRelationship copyWith({
    bool? following,
    ProfileFriendship? friendship,
    bool? blocked,
  }) => PublicProfileRelationship(
    following: following ?? this.following,
    followedBy: followedBy,
    friendship: friendship ?? this.friendship,
    blocked: blocked ?? this.blocked,
    blockedBy: blockedBy,
  );
}

@immutable
final class PublicProfileVisibility {
  const PublicProfileVisibility({required this.holdings, required this.trades});

  final bool holdings;
  final bool trades;
}

@immutable
final class PublicProfileRecord {
  const PublicProfileRecord({
    required this.publicProfileId,
    required this.loopId,
    required this.alias,
    required this.avatarRef,
    required this.bio,
    required this.joinedAt,
    required this.counts,
    required this.relationship,
    required this.visibility,
  });

  final String publicProfileId;
  final String loopId;
  final String? alias;
  final String? avatarRef;
  final String? bio;
  final DateTime joinedAt;
  final PublicProfileCounts counts;
  final PublicProfileRelationship relationship;
  final PublicProfileVisibility visibility;

  /// `alias ?? loopId`, the one name every surface uses.
  String get displayName => alias ?? loopId;

  PublicProfileRecord withRelationship(PublicProfileRelationship value) =>
      PublicProfileRecord(
        publicProfileId: publicProfileId,
        loopId: loopId,
        alias: alias,
        avatarRef: avatarRef,
        bio: bio,
        joinedAt: joinedAt,
        counts: counts,
        relationship: value,
        visibility: visibility,
      );
}

/// Whether one section of another account's profile can be shown.
enum ProfileSectionStatus {
  /// The server read it and sends it.
  available('available'),

  /// The account keeps it to itself (`visibility … = self`).
  hidden('hidden'),

  /// The server could not read it (no chain read, no index). Never a zero.
  unavailable('unavailable');

  const ProfileSectionStatus(this.wireName);

  final String wireName;

  static ProfileSectionStatus? tryParse(Object? value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

@immutable
final class ProfileHolding {
  const ProfileHolding({
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.logoUrl,
    required this.balance,
    required this.usdValue,
  });

  final String assetId;
  final String symbol;
  final String name;
  final String? logoUrl;
  final Decimal balance;

  /// `null` when the asset has no price the server could read.
  final Decimal? usdValue;
}

/// The two Launch-chain holding kinds `/holdings` may merge (decision 0218,
/// loop-api S260). A kind this build does not know is skipped by the
/// decoder, never turned into one of these.
enum ProfileLaunch2HoldingKind {
  meme('launch2_meme'),
  nft('launch2_nft');

  const ProfileLaunch2HoldingKind(this.wireName);

  final String wireName;

  static ProfileLaunch2HoldingKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// One Launch-chain MEME v2 holding of another account (decision 0218).
///
/// A MEME row carries [amountMeme]; a medal (NFT) row carries [nftCount].
/// [valueUsd1] is the server's own valuation in USD1, `null` when it has
/// none — never a zero. [stage] is `null` for a stage this build does not
/// name yet; the row then says only 「Launch 链」.
@immutable
final class ProfileLaunch2Holding {
  const ProfileLaunch2Holding({
    required this.kind,
    required this.chainId,
    required this.instanceId,
    required this.ticker,
    required this.name,
    required this.logoUrl,
    required this.amountMeme,
    required this.nftCount,
    required this.stage,
    required this.valueUsd1,
  });

  final ProfileLaunch2HoldingKind kind;
  final String chainId;
  final String instanceId;
  final String ticker;
  final String name;
  final String? logoUrl;
  final Decimal? amountMeme;
  final int? nftCount;
  final Launch2Stage? stage;
  final Decimal? valueUsd1;

  /// Stable list key; never collides with a mainnet `assetId`.
  String get rowId => 'launch2:$chainId:$instanceId:${kind.wireName}';
}

/// One row of the merged holdings list, in server order.
@immutable
sealed class ProfileHoldingRow {
  const ProfileHoldingRow();
}

final class ProfileAssetHoldingRow extends ProfileHoldingRow {
  const ProfileAssetHoldingRow(this.holding);

  final ProfileHolding holding;
}

final class ProfileLaunch2HoldingRow extends ProfileHoldingRow {
  const ProfileLaunch2HoldingRow(this.holding);

  final ProfileLaunch2Holding holding;
}

@immutable
final class ProfileHoldings {
  /// [items] lists the mainnet holdings (the page before decision 0218);
  /// [rows], when given, is the merged list in server order and [items] is
  /// derived from it.
  ProfileHoldings({
    required this.status,
    required this.totalUsd,
    List<ProfileHolding> items = const <ProfileHolding>[],
    List<ProfileHoldingRow>? rows,
    required this.observedAt,
    this.reasonCode,
    this.launch2,
  }) : assert(rows == null || items.isEmpty, 'pass items or rows, not both'),
       rows = List<ProfileHoldingRow>.unmodifiable(
         rows ??
             <ProfileHoldingRow>[
               for (final item in items) ProfileAssetHoldingRow(item),
             ],
       ),
       items = List<ProfileHolding>.unmodifiable(
         rows == null
             ? items
             : <ProfileHolding>[
                 for (final row in rows)
                   if (row is ProfileAssetHoldingRow) row.holding,
               ],
       );

  final ProfileSectionStatus status;
  final Decimal? totalUsd;

  /// The mainnet holdings among [rows], in the same order.
  final List<ProfileHolding> items;

  /// Every row, mainnet and Launch chain, as the server merged them.
  final List<ProfileHoldingRow> rows;
  final DateTime? observedAt;

  /// `null` when the server did not merge the Launch chain (switch
  /// `PROFILE_LAUNCH2_EMIT` off). Reuses the wallet activity block's shape
  /// (loop-api 0167 §C), which this root key copies.
  final LoopWalletLaunch2Leg? launch2;

  /// Why an `unavailable` section is unavailable (`WALLET_NOT_BOUND`,
  /// `BSC_READ_UNAVAILABLE`, …); `null` for every other status.
  final String? reasonCode;
}

enum ProfileTradeKind {
  buy('buy', '买入'),
  sell('sell', '卖出'),
  transferIn('transfer_in', '转入'),
  transferOut('transfer_out', '转出');

  const ProfileTradeKind(this.wireName, this.label);

  final String wireName;
  final String label;

  static ProfileTradeKind? tryParse(Object? value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

@immutable
final class ProfileTrade {
  const ProfileTrade({
    required this.eventId,
    required this.kind,
    required this.assetId,
    required this.symbol,
    required this.amount,
    required this.usdValue,
    required this.blockTimestamp,
    required this.txHash,
    this.blockNumber,
  });

  final String eventId;
  final ProfileTradeKind kind;
  final String assetId;
  final String symbol;
  final Decimal amount;
  final Decimal? usdValue;

  /// `null` when the server indexed no block time for the transfer's block
  /// (backend decision 0095); the row then names its block instead.
  final DateTime? blockTimestamp;
  final String txHash;
  final String? blockNumber;
}

/// One row of the merged trades list, in server order (decision 0218).
@immutable
sealed class ProfileTradeRow {
  const ProfileTradeRow();

  /// Stable list key and de-duplication identity across pages.
  String get rowId;
}

final class ProfileAssetTradeRow extends ProfileTradeRow {
  const ProfileAssetTradeRow(this.trade);

  final ProfileTrade trade;

  @override
  String get rowId => trade.eventId;
}

/// A Launch-chain MEME v2 fact: the same fourteen-key row the wallet's
/// activity tape carries (decision 0213), decoded into the wallet's model so
/// the row is drawn by the wallet's own row builder.
final class ProfileLaunch2TradeRow extends ProfileTradeRow {
  const ProfileLaunch2TradeRow(this.entry);

  final LoopWalletLaunch2ActivityEntry entry;

  @override
  String get rowId => entry.entryId;
}

@immutable
final class ProfileTradesPage {
  /// [items] lists the mainnet trades; [rows], when given, is the merged page
  /// in server order and [items] is derived from it.
  ProfileTradesPage({
    required this.status,
    List<ProfileTrade> items = const <ProfileTrade>[],
    List<ProfileTradeRow>? rows,
    required this.nextCursor,
    this.reasonCode,
    this.launch2,
  }) : assert(rows == null || items.isEmpty, 'pass items or rows, not both'),
       rows = List<ProfileTradeRow>.unmodifiable(
         rows ??
             <ProfileTradeRow>[
               for (final item in items) ProfileAssetTradeRow(item),
             ],
       ),
       items = List<ProfileTrade>.unmodifiable(
         rows == null
             ? items
             : <ProfileTrade>[
                 for (final row in rows)
                   if (row is ProfileAssetTradeRow) row.trade,
               ],
       );

  final ProfileSectionStatus status;

  /// The mainnet trades among [rows], in the same order.
  final List<ProfileTrade> items;

  /// Every row of the page, mainnet and Launch chain, in server order.
  final List<ProfileTradeRow> rows;
  final String? nextCursor;

  /// `null` when the server did not merge the Launch chain.
  final LoopWalletLaunch2Leg? launch2;

  /// See [ProfileHoldings.reasonCode].
  final String? reasonCode;
}

/// A community's verification as `/v2/profiles/{id}/communities` states it
/// (decision 0218). Only two values: the list is of communities the account
/// is in, and a review in progress is the owner's business, not a viewer's.
enum ProfileCommunityVerification {
  verified('verified'),
  unverified('unverified');

  const ProfileCommunityVerification(this.wireName);

  final String wireName;

  static ProfileCommunityVerification? tryParse(Object? value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// One community another account has joined.
@immutable
final class ProfileCommunity {
  const ProfileCommunity({
    required this.communityId,
    required this.name,
    required this.slug,
    required this.logoRef,
    required this.memberCount,
    required this.verificationStatus,
    required this.joinedAt,
    this.label,
  });

  final String communityId;
  final String name;
  final String slug;
  final String? logoRef;
  final int memberCount;
  final ProfileCommunityVerification verificationStatus;
  final DateTime joinedAt;

  /// The operator's free-text mark (decision 0239); `null` is no mark.
  final String? label;
}

/// One page of `/v2/profiles/{id}/communities`.
///
/// `hidden` is the account keeping its list to itself
/// (`PROFILE_COMMUNITIES_HIDDEN`); such a page carries no rows and no cursor.
@immutable
final class ProfileCommunitiesPage {
  const ProfileCommunitiesPage.available({
    required this.items,
    required this.nextCursor,
  }) : hidden = false,
       reasonCode = null;

  const ProfileCommunitiesPage.hidden(String this.reasonCode)
    : hidden = true,
      items = const <ProfileCommunity>[],
      nextCursor = null;

  final bool hidden;
  final String? reasonCode;
  final List<ProfileCommunity> items;
  final String? nextCursor;
}

/// How the profile page was asked for.
@immutable
sealed class PublicProfileTarget {
  const PublicProfileTarget();

  String get key;
}

final class PublicProfileById extends PublicProfileTarget {
  const PublicProfileById(this.publicProfileId);

  final String publicProfileId;

  @override
  String get key => 'id:$publicProfileId';

  @override
  bool operator ==(Object other) =>
      other is PublicProfileById && other.publicProfileId == publicProfileId;

  @override
  int get hashCode => publicProfileId.hashCode;
}

final class PublicProfileByLoopId extends PublicProfileTarget {
  const PublicProfileByLoopId(this.loopId);

  final String loopId;

  @override
  String get key => 'loop:$loopId';

  @override
  bool operator ==(Object other) =>
      other is PublicProfileByLoopId && other.loopId == loopId;

  @override
  int get hashCode => loopId.hashCode;
}
