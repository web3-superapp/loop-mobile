// The 我的 tab and another account's page, filled for structure tests and
// screenshots (S349, S350c). Moved out of `s349_me_profile_structure_test`
// so the S350c shots mount the same pages with the same data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_gateway.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_profile_communities.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/social/loop_v2_public_profiles.dart';

import 'community_test_harness.dart';
import 's5_fixtures.dart';
import 's5_page_harness.dart';

const meJoinedA = '3fa85f64-5717-4562-b3fc-2c963f66a001';
const meJoinedB = '3fa85f64-5717-4562-b3fc-2c963f66a002';
const meOwnedId = '3fa85f64-5717-4562-b3fc-2c963f66a011';

ProfileResource meResource({String? bio}) => ProfileResource(
  version: 1,
  values: ProfileValues(alias: 'Boo123133', avatarRef: null, bio: bio),
  updatedAt: DateTime.utc(2026, 10, 9),
  loopId: 'LOOP-GBZM3XAT',
  profileStatus: ProfileStatus.active,
  activatedAt: DateTime.utc(2026, 10, 9, 12),
);

final class MeProfileGateway implements ProfileGateway {
  MeProfileGateway({this.bio});

  final String? bio;

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() async => meResource(bio: bio);

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) async => meResource(bio: bio);
}

CommunityMembership _membership(CommunityRole role) => CommunityMembership(
  role: role,
  status: CommunityMemberStatus.active,
  joinedAt: DateTime.utc(2026, 7),
);

CommunityHome meHome({
  List<JoinedCommunity>? joined,
  List<OwnedCommunity>? owned,
}) => CommunityHome(
  joined:
      joined ??
      <JoinedCommunity>[
        JoinedCommunity(
          community: testCommunity(
            communityId: meJoinedA,
            name: 'Frog Holders',
            label: '官方',
          ),
          membership: _membership(CommunityRole.member),
        ),
        JoinedCommunity(
          community: testCommunity(
            communityId: meJoinedB,
            name: 'Moon Cats',
            memberCount: 2048,
          ),
          membership: _membership(CommunityRole.member),
        ),
      ],
  joinedTruncated: false,
  owned:
      owned ??
      <OwnedCommunity>[
        OwnedCommunity(
          community: testCommunity(
            communityId: meOwnedId,
            name: 'Builders Guild',
            verification: CommunityVerification.pending,
          ),
          membership: _membership(CommunityRole.owner),
          application: CommunityApplicationReview(
            status: CommunityVerification.pending,
            submittedAt: DateTime.utc(2026, 11, 1, 3),
            reviewedAt: null,
            rejectedReason: null,
          ),
        ),
      ],
  ownedTruncated: false,
  discover: const <CommunitySummary>[],
  unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
  liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
  observedAt: DateTime.utc(2026, 11, 3, 1),
  source: 'database',
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);

/// A tape long enough to scroll, ending on [nextCursor].
LoopWalletActivityPage meLongTape({String? nextCursor = 'cursor-2'}) {
  final first = s5Activity().items.single;
  return s5Activity(
    nextCursor: nextCursor,
    items: <LoopWalletActivityEntry>[
      for (var i = 0; i < 30; i++)
        LoopWalletActivityEntry(
          assetId: first.assetId,
          symbol: first.symbol,
          decimals: first.decimals,
          direction: i.isEven
              ? LoopTransferDirection.incoming
              : LoopTransferDirection.outgoing,
          counterpartyAddress: first.counterpartyAddress,
          rawValue: first.rawValue,
          displayValue: first.displayValue,
          transactionHash: first.transactionHash,
          logIndex: i,
          blockNumber: first.blockNumber - BigInt.from(i * 1000),
          blockHash: first.blockHash,
          confirmations: first.confirmations,
          status: first.status,
          observedAt: DateTime.utc(2026, 9, 8).subtract(Duration(hours: i)),
        ),
    ],
  );
}

/// 我的 (`/wallet`) with a person, a wallet, its tape and its communities.
Future<FakeWalletReadGateway> pumpMePage(
  WidgetTester tester, {
  ValueChanged<String>? onNavigate,
  LoopWalletActivityPage? activity,
  LoopWalletBalances? balances,
  CommunityHome? home,
  LoopV2MetaSnapshot? meta,
  String? bio,
  Size size = const Size(390, 2400),
}) async {
  final wallet = FakeWalletReadGateway(
    activity: S5Answer<LoopWalletActivityPage>(value: activity ?? s5Activity()),
    balances: balances == null
        ? null
        : S5Answer<LoopWalletBalances>(value: balances),
  );
  await pumpS5Page(
    tester,
    WalletScreen(onNavigate: onNavigate),
    size: size,
    wallet: wallet,
    meta:
        meta ??
        s5MetaSnapshot(community: LoopV2CapabilityAvailability.available),
    overrides: [
      profileGatewayProvider.overrideWithValue(MeProfileGateway(bio: bio)),
      socialGatewayProvider.overrideWithValue(
        FakeSocialGateway(
          connections: const ConnectionPage(
            direction: ConnectionDirection.following,
            items: <ConnectionEntry>[],
            counts: ConnectionCounts(following: 3, followers: 12),
            nextCursor: null,
          ),
        ),
      ),
      communityGatewayProvider.overrideWithValue(
        FakeCommunityGateway(home: home ?? meHome()),
      ),
    ],
  );
  return wallet;
}

// ---------------------------------------------------------------------------
// Another account's page (`user-profile`)
// ---------------------------------------------------------------------------

const otherProfileId = '7d1c5f64-5717-4562-b3fc-2c963f66a001';

PublicProfileRecord _otherRecord() => PublicProfileRecord(
  publicProfileId: otherProfileId,
  loopId: 'LOOP-7KQ2M9XA',
  alias: 'frog_maxi',
  avatarRef: null,
  bio: '只做 BSC 上的社区币',
  joinedAt: DateTime.utc(2026, 9),
  counts: const PublicProfileCounts(
    followers: 1284,
    following: 32,
    communities: 2,
  ),
  relationship: const PublicProfileRelationship(
    following: false,
    followedBy: false,
    friendship: ProfileFriendship.none,
    blocked: false,
    blockedBy: false,
  ),
  visibility: const PublicProfileVisibility(holdings: true, trades: true),
);

Map<String, Object?> _holdingsBody({required bool empty}) => <String, Object?>{
  'status': 'available',
  'reasonCode': null,
  'totalUsd': empty ? '0' : '1046.02',
  'items': empty
      ? <Object?>[]
      : <Object?>[
          <String, Object?>{
            'assetId': 'eip155:56:native',
            'symbol': 'BNB',
            'name': 'BNB',
            'logoUrl': null,
            'balance': '1.2',
            'usdValue': '784.52',
          },
          <String, Object?>{
            'assetId': 'eip155:56:0x55d398326f99059ff775485246999027b3197955',
            'symbol': 'USDT',
            'name': 'Tether USD',
            'logoUrl': null,
            'balance': '261.5',
            'usdValue': '261.5',
          },
        ],
  'observedAt': '2026-10-20T04:00:00.000Z',
  'contractVersion': '2.0',
};

Map<String, Object?> _tradesBody({required bool empty}) => <String, Object?>{
  'status': 'available',
  'reasonCode': null,
  'items': empty
      ? <Object?>[]
      : <Object?>[
          for (var i = 0; i < 4; i++)
            <String, Object?>{
              'eventId': 'evt_$i',
              'kind': i.isEven ? 'buy' : 'sell',
              'assetId': 'eip155:56:native',
              'symbol': 'BNB',
              'amount': '0.4',
              'usdValue': '261.5',
              'blockTimestamp': '2026-10-0${8 - i}T01:00:00.000Z',
              'blockNumber': '${300 - i}',
              'txHash': '0x${'$i' * 64}',
            },
        ],
  'nextCursor': null,
  'contractVersion': '2.0',
};

Map<String, Object?> _communitiesBody({required bool empty}) =>
    <String, Object?>{
      'status': 'available',
      'items': empty
          ? <Object?>[]
          : <Object?>[
              <String, Object?>{
                'communityId': meJoinedA,
                'name': '星夜社区',
                'slug': 'star-night',
                'logoRef': null,
                'memberCount': 1284,
                'verificationStatus': 'verified',
                'joinedAt': '2026-10-01T00:00:00.000Z',
                'label': '算力社区',
              },
              <String, Object?>{
                'communityId': meJoinedB,
                'name': 'Night Owls',
                'slug': 'night-owls',
                'logoRef': null,
                'memberCount': 86,
                'verificationStatus': 'unverified',
                'joinedAt': '2026-10-01T00:00:00.000Z',
              },
            ],
      'nextCursor': null,
      'contractVersion': '2.0',
    };

final class OtherProfileGateway implements PublicProfileGateway {
  OtherProfileGateway({this.empty = false});

  /// Every section answers with nothing in it.
  final bool empty;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<PublicProfileRecord> load(PublicProfileTarget target) async =>
      _otherRecord();

  @override
  Future<ProfileHoldings> holdings(String publicProfileId) async =>
      LoopV2PublicProfileCodec.holdings(_holdingsBody(empty: empty));

  @override
  Future<ProfileTradesPage> trades(
    String publicProfileId, {
    String? cursor,
  }) async => LoopV2PublicProfileCodec.trades(_tradesBody(empty: empty));

  @override
  Future<ProfileCommunitiesPage> communities(
    String publicProfileId, {
    String? cursor,
  }) async =>
      LoopV2ProfileCommunitiesCodec.page(_communitiesBody(empty: empty));

  @override
  Future<void> removeFriend(String publicProfileId) async {}
}

/// `user-profile` for [otherProfileId].
Future<void> pumpOtherProfile(
  WidgetTester tester, {
  bool empty = false,
  Size size = const Size(390, 1500),
}) => pumpCommunityPage(
  tester,
  UserProfileScreen(
    target: const PublicProfileById(otherProfileId),
    onNavigate: (_) {},
  ),
  social: FakeSocialGateway(),
  size: size,
  overrides: <Override>[
    publicProfileGatewayProvider.overrideWithValue(
      OtherProfileGateway(empty: empty),
    ),
  ],
);
