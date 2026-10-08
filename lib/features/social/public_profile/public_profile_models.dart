import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

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

@immutable
final class ProfileHoldings {
  const ProfileHoldings({
    required this.status,
    required this.totalUsd,
    required this.items,
    required this.observedAt,
    this.reasonCode,
  });

  final ProfileSectionStatus status;
  final Decimal? totalUsd;
  final List<ProfileHolding> items;
  final DateTime? observedAt;

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

@immutable
final class ProfileTradesPage {
  const ProfileTradesPage({
    required this.status,
    required this.items,
    required this.nextCursor,
    this.reasonCode,
  });

  final ProfileSectionStatus status;
  final List<ProfileTrade> items;
  final String? nextCursor;

  /// See [ProfileHoldings.reasonCode].
  final String? reasonCode;
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
