import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/account/onboarding_communities.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_gateway.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';

/// Development Preview adapter for `user-profile` (decision 0112).
///
/// Mounted only by `main_preview.dart`. Its mode is `preview`, so the page
/// carries the 演示数据 notice above everything it draws. One account
/// answers for any id; nothing is read from or written to a server.
final class MemoryPublicProfileGateway implements PublicProfileGateway {
  MemoryPublicProfileGateway({DateTime? now})
    : _now = now ?? DateTime.now().toUtc();

  static const previewProfileId = '7d1c5f64-5717-4562-b3fc-2c963f66a001';

  final DateTime _now;
  var _friendship = ProfileFriendship.none;
  var _following = false;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.preview;

  @override
  Future<PublicProfileRecord> load(PublicProfileTarget target) async =>
      PublicProfileRecord(
        publicProfileId: previewProfileId,
        loopId: 'LOOP-7KQ2M9XA',
        alias: '预览用户',
        avatarRef: null,
        bio: '开发预览账号，资料与持仓都是演示数据。',
        joinedAt: DateTime.utc(2026, 9, 1),
        counts: const PublicProfileCounts(
          followers: 128,
          following: 36,
          communities: 4,
        ),
        relationship: PublicProfileRelationship(
          following: _following,
          followedBy: false,
          friendship: _friendship,
          blocked: false,
          blockedBy: false,
        ),
        visibility: const PublicProfileVisibility(holdings: true, trades: true),
      );

  @override
  Future<ProfileHoldings> holdings(String publicProfileId) async =>
      ProfileHoldings(
        status: ProfileSectionStatus.available,
        totalUsd: Decimal.parse('1284.52'),
        items: <ProfileHolding>[
          ProfileHolding(
            assetId: 'eip155:56:native',
            symbol: 'BNB',
            name: 'BNB',
            logoUrl: null,
            balance: Decimal.parse('1.2'),
            usdValue: Decimal.parse('784.52'),
          ),
          ProfileHolding(
            assetId: 'eip155:56:0x55d398326f99059ff775485246999027b3197955',
            symbol: 'USDT',
            name: 'Tether USD',
            logoUrl: null,
            balance: Decimal.parse('500'),
            usdValue: Decimal.parse('500'),
          ),
        ],
        observedAt: _now,
      );

  @override
  Future<ProfileTradesPage> trades(
    String publicProfileId, {
    String? cursor,
  }) async => ProfileTradesPage(
    status: ProfileSectionStatus.available,
    items: <ProfileTrade>[
      ProfileTrade(
        eventId: 'preview-1',
        kind: ProfileTradeKind.buy,
        assetId: 'eip155:56:native',
        symbol: 'BNB',
        amount: Decimal.parse('0.4'),
        usdValue: Decimal.parse('261.5'),
        blockTimestamp: _now.subtract(const Duration(hours: 3)),
        txHash: '0x${'a' * 64}',
      ),
    ],
    nextCursor: null,
  );

  @override
  Future<void> removeFriend(String publicProfileId) async {
    _friendship = ProfileFriendship.none;
  }

  /// Preview only: what the follow and friend commands of the other memory
  /// gateways would have changed here.
  void debugSet({bool? following, ProfileFriendship? friendship}) {
    _following = following ?? _following;
    _friendship = friendship ?? _friendship;
  }
}

/// Development Preview adapter for `onboarding-communities`: the first
/// directory page of the Preview community gateway, five of them ticked.
final class MemoryRecommendedCommunitiesGateway
    implements RecommendedCommunitiesGateway {
  const MemoryRecommendedCommunitiesGateway(this._communities);

  final CommunityGateway _communities;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.preview;

  @override
  Future<RecommendedCommunities> load() async {
    final page = await _communities.listCommunities();
    final items = page.items.take(8).toList(growable: false);
    return RecommendedCommunities(
      items: items,
      defaultSelectedIds: <String>[
        for (final item in items.take(5)) item.communityId,
      ],
    );
  }
}
