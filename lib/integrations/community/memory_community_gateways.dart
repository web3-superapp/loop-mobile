import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';

/// Memory-only S3 adapters for the explicit Development Preview entry point.
///
/// Every surface backed by one of these renders the visible `演示数据` label.
/// Nothing here is persisted, reaches an account, or calls a provider; the
/// unavailable projections match the production contract exactly so the
/// Preview can never show a figure the real backend would withhold.
const _previewMining = LoopUnavailableFact('MINING_FORMULA_BASELINE_PENDING');
const _previewPresence = LoopUnavailableFact('STREAM_PRESENCE_NOT_CONNECTED');

CommunitySummary _community({
  required String id,
  required String name,
  required String slug,
  required int memberCount,
  CommunityVerification verification = CommunityVerification.verified,
  String? boundAssetKey,
  String? description,
}) => CommunitySummary(
  communityId: id,
  name: name,
  slug: slug,
  description: description,
  logoRef: null,
  verificationStatus: verification,
  boundAssetKey: boundAssetKey,
  memberCount: memberCount,
  createdAt: DateTime.utc(2026, 6, 1),
  configVersion: 'communityV1',
);

const _recommendation = CommunityRecommendation(
  recommendationId: '2f7c8a90-1b2c-4d3e-8f90-1a2b3c4d5e6f',
  ruleVersion: 'rule:verified-members-v1',
);

final _previewCommunities = <CommunitySummary>[
  _community(
    id: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
    name: '演示社区 · Frogs',
    slug: 'demo-frogs',
    memberCount: 128,
    description: '开发预览中的示例社区，成员数与角色都是本地内存值。',
    boundAssetKey: 'eip155:56:0x00000000000000000000000000000000000000aa',
  ),
  _community(
    id: '4bb85f64-5717-4562-b3fc-2c963f66afb7',
    name: '演示社区 · Builders',
    slug: 'demo-builders',
    memberCount: 42,
  ),
  _community(
    id: '5cc85f64-5717-4562-b3fc-2c963f66afc8',
    name: '演示社区 · 审核中',
    slug: 'demo-pending',
    memberCount: 3,
    verification: CommunityVerification.pending,
  ),
];

const _previewProfiles = <LoopPublicProfile>[
  LoopPublicProfile(
    publicProfileId: '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f',
    loopId: 'LOOP-7HJKMNPQ',
    alias: 'demo_owner',
    avatarRef: 'avatar:preset/people-03',
  ),
  LoopPublicProfile(
    publicProfileId: '8b2e1f3d-4a5b-4c6d-8e7f-9a0b1c2d3e4f',
    loopId: 'LOOP-2ABCDEFG',
    alias: 'demo_admin',
    avatarRef: null,
  ),
  LoopPublicProfile(
    publicProfileId: '7a3d2e4c-5b6c-4d7e-8f90-1a2b3c4d5e60',
    loopId: 'LOOP-3HJKMNPQ',
    alias: null,
    avatarRef: null,
  ),
];

final class MemoryCommunityGateway implements CommunityGateway {
  MemoryCommunityGateway();

  final Set<String> _joined = <String>{'3fa85f64-5717-4562-b3fc-2c963f66afa6'};

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.preview;

  CommunityDetail _detail(CommunitySummary community) {
    final joined = _joined.contains(community.communityId);
    return CommunityDetail(
      community: community,
      viewer: CommunityViewer(
        membership: joined
            ? CommunityMembership(
                role: CommunityRole.owner,
                status: CommunityMemberStatus.active,
                joinedAt: DateTime.utc(2026, 7, 1),
              )
            : null,
        canInviteAdmin: joined,
        canMute: joined,
        canBan: joined,
      ),
      miningPower: _previewMining,
      onlineCount: _previewPresence,
      announcements: const LoopUnavailableFact(
        'COMMUNITY_ANNOUNCEMENTS_DEFERRED',
      ),
      officialLinks: const LoopUnavailableFact('COMMUNITY_LINKS_DEFERRED'),
      // The Preview owns no Stream channel, so it never reports `available`
      // and never invents a channel CID.
      chat: joined
          ? const CommunityChatSection(
              status: CommunityChatStatus.syncing,
              channelCid: null,
              memberState: CommunityChatMemberState.pending,
              reasonCode: 'COMMUNITY_CHANNEL_MEMBER_SYNCING',
            )
          : const CommunityChatSection(
              status: CommunityChatStatus.unavailable,
              channelCid: null,
              memberState: null,
              reasonCode: 'COMMUNITY_MEMBERSHIP_REQUIRED',
            ),
      voice: const CommunityVoiceSection(
        status: CommunityVoiceStatus.unavailable,
        currentRoomId: null,
        reasonCode: 'COMMUNITY_VOICE_ROOM_NOT_LIVE',
      ),
    );
  }

  CommunitySummary _byId(String communityId) => _previewCommunities.firstWhere(
    (item) => item.communityId == communityId,
    orElse: () =>
        throw const CommunityGatewayException(CommunityFailureKind.notFound),
  );

  @override
  Future<CommunityHome> loadHome() async => CommunityHome(
    joined: <JoinedCommunity>[
      for (final community in _previewCommunities)
        if (_joined.contains(community.communityId))
          JoinedCommunity(
            community: community,
            membership: CommunityMembership(
              role: CommunityRole.owner,
              status: CommunityMemberStatus.active,
              joinedAt: DateTime.utc(2026, 7, 1),
            ),
          ),
    ],
    joinedTruncated: false,
    discover: <CommunitySummary>[
      for (final community in _previewCommunities)
        if (!_joined.contains(community.communityId) && community.isVerified)
          community,
    ],
    unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
    liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
    observedAt: DateTime.utc(2026, 9, 8, 1),
    source: 'database',
    recommendation: _recommendation,
  );

  @override
  Future<CommunityDirectoryPage> listCommunities({
    CommunityDirectorySort sort = CommunityDirectorySort.members,
    CommunityVerificationFilter verification =
        CommunityVerificationFilter.verified,
    CommunityMembershipFilter membership = CommunityMembershipFilter.all,
    String? cursor,
  }) async {
    final items = <CommunitySummary>[
      for (final community in _previewCommunities)
        if ((verification == CommunityVerificationFilter.all ||
                community.isVerified) &&
            (membership == CommunityMembershipFilter.all ||
                _joined.contains(community.communityId)))
          community,
    ];
    items.sort(
      sort == CommunityDirectorySort.members
          ? (a, b) => b.memberCount.compareTo(a.memberCount)
          : (a, b) => b.createdAt.compareTo(a.createdAt),
    );
    return CommunityDirectoryPage(
      items: List<CommunitySummary>.unmodifiable(items),
      nextCursor: null,
      recommendation: _recommendation,
    );
  }

  @override
  Future<CommunityDetail> createCommunity(
    CommunityApplication application,
  ) async {
    if (application.invalidField != null) {
      throw const CommunityGatewayException(
        CommunityFailureKind.validationFailed,
      );
    }
    if (_previewCommunities.any((item) => item.slug == application.slug)) {
      throw const CommunityGatewayException(
        CommunityFailureKind.resourceConflict,
      );
    }
    final created = _community(
      id: '6dd85f64-5717-4562-b3fc-2c963f66afd9',
      name: application.name,
      slug: application.slug,
      memberCount: 1,
      verification: CommunityVerification.pending,
      description: application.description,
      boundAssetKey: application.boundAssetKey,
    );
    _previewCommunities.add(created);
    _joined.add(created.communityId);
    return _detail(created);
  }

  @override
  Future<CommunityDetail> loadCommunity(String communityId) async =>
      _detail(_byId(communityId));

  @override
  Future<CommunityDetail> join(String communityId) async {
    final community = _byId(communityId);
    _joined.add(communityId);
    return _detail(community);
  }

  @override
  Future<CommunityDetail> leave(String communityId) async {
    final community = _byId(communityId);
    _joined.remove(communityId);
    return _detail(community);
  }

  @override
  Future<CommunityDetail> editProfile(
    String communityId,
    CommunityProfileEdit edit,
  ) async => _detail(_byId(communityId));

  @override
  Future<CommunityMemberDirectory> listMembers(
    String communityId, {
    CommunityMemberFilter role = CommunityMemberFilter.all,
    String? cursor,
  }) async {
    final community = _byId(communityId);
    final all = <CommunityMemberEntry>[
      CommunityMemberEntry(
        profile: _previewProfiles[0],
        role: CommunityRole.owner,
        status: CommunityMemberStatus.active,
        joinedAt: DateTime.utc(2026, 7, 1),
        isSelf: true,
        miningPower: _previewMining,
      ),
      CommunityMemberEntry(
        profile: _previewProfiles[1],
        role: CommunityRole.admin,
        status: CommunityMemberStatus.active,
        joinedAt: DateTime.utc(2026, 7, 2),
        isSelf: false,
        miningPower: _previewMining,
      ),
      CommunityMemberEntry(
        profile: _previewProfiles[2],
        role: CommunityRole.member,
        status: CommunityMemberStatus.active,
        joinedAt: DateTime.utc(2026, 7, 3),
        isSelf: false,
        miningPower: _previewMining,
      ),
    ];
    final items = <CommunityMemberEntry>[
      for (final entry in all)
        if (role == CommunityMemberFilter.all ||
            (role == CommunityMemberFilter.owner &&
                entry.role == CommunityRole.owner) ||
            (role == CommunityMemberFilter.admin &&
                entry.role == CommunityRole.admin))
          entry,
    ];
    return CommunityMemberDirectory(
      community: community,
      viewer: _detail(community).viewer,
      counts: CommunityMemberCounts(
        all: all.length,
        owner: 1,
        admin: 1,
        online: _previewPresence,
      ),
      items: List<CommunityMemberEntry>.unmodifiable(items),
      nextCursor: null,
    );
  }

  @override
  Future<CommunityMemberDirectory> changeMemberRole({
    required String communityId,
    required String publicProfileId,
    required CommunityRole role,
  }) => listMembers(communityId);

  @override
  Future<CommunityMemberDirectory> setMuted({
    required String communityId,
    required String publicProfileId,
    required bool muted,
  }) => listMembers(communityId);

  @override
  Future<CommunityMemberDirectory> setBanned({
    required String communityId,
    required String publicProfileId,
    required bool banned,
  }) => listMembers(communityId);

  @override
  Future<ReferralRules> loadReferralRules() async => ReferralRules(
    configVersion: 'referralRulesV1',
    effectiveAt: DateTime.utc(2026, 9),
    appliesTo: 'miningPower',
    levels: const <ReferralLevel>[
      ReferralLevel(
        level: 1,
        boostPercent: '10',
        descriptionKey: 'mining.referral.level1',
      ),
      ReferralLevel(
        level: 2,
        boostPercent: '5',
        descriptionKey: 'mining.referral.level2',
      ),
      ReferralLevel(
        level: 3,
        boostPercent: '3',
        descriptionKey: 'mining.referral.level3',
      ),
      ReferralLevel(
        level: 4,
        boostPercent: '2',
        descriptionKey: 'mining.referral.level4',
      ),
      ReferralLevel(
        level: 5,
        boostPercent: '1',
        descriptionKey: 'mining.referral.level5',
      ),
    ],
    edges: const LoopUnavailableFact('REFERRAL_GRAPH_DEFERRED'),
    inviteCode: const LoopUnavailableFact('INVITE_CODE_DEFERRED'),
  );
}

final class MemorySocialGateway implements SocialGateway {
  MemorySocialGateway();

  final Set<String> _following = <String>{
    '8b2e1f3d-4a5b-4c6d-8e7f-9a0b1c2d3e4f',
  };
  final List<BlockEntry> _blocks = <BlockEntry>[
    BlockEntry(
      kind: BlockKind.user,
      stableId: '7a3d2e4c-5b6c-4d7e-8f90-1a2b3c4d5e60',
      profile: _previewProfiles[2],
      reasonCode: 'user_request',
      createdAt: DateTime.utc(2026, 8, 20),
    ),
  ];
  final List<MessageRequestEntry> _requests = <MessageRequestEntry>[
    MessageRequestEntry(
      messageRequestId: '1d2c3b4a-5e6f-4a7b-8c9d-0e1f2a3b4c5d',
      profile: _previewProfiles[1],
      createdAt: DateTime.utc(2026, 9, 7),
      expiresAt: DateTime.utc(2026, 9, 14),
      preview: const LoopUnavailableFact('MESSAGE_PREVIEW_DEFERRED'),
      aiModeration: const LoopUnavailableFact('AI_MODERATION_DEFERRED'),
    ),
  ];

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.preview;

  @override
  Future<ConnectionPage> listConnections({
    ConnectionDirection direction = ConnectionDirection.following,
    String? cursor,
  }) async {
    final items = <ConnectionEntry>[
      for (final profile in _previewProfiles)
        if (direction == ConnectionDirection.followers ||
            _following.contains(profile.publicProfileId))
          ConnectionEntry(
            profile: profile,
            createdAt: DateTime.utc(2026, 8, 1),
            viewerFollows: _following.contains(profile.publicProfileId),
            miningPower: _previewMining,
          ),
    ];
    return ConnectionPage(
      direction: direction,
      items: List<ConnectionEntry>.unmodifiable(items),
      counts: ConnectionCounts(
        following: _following.length,
        followers: _previewProfiles.length,
      ),
      nextCursor: null,
    );
  }

  @override
  Future<FollowOutcome> setFollowing({
    required String publicProfileId,
    required bool following,
  }) async {
    if (following) {
      _following.add(publicProfileId);
    } else {
      _following.remove(publicProfileId);
    }
    return FollowOutcome(
      profile: _previewProfiles.firstWhere(
        (item) => item.publicProfileId == publicProfileId,
        orElse: () => _previewProfiles.first,
      ),
      viewerFollows: following,
    );
  }

  @override
  Future<BlockPage> listBlocks({
    BlockKind kind = BlockKind.user,
    String? cursor,
  }) async {
    if (!kind.isSupported) {
      throw const CommunityGatewayException(CommunityFailureKind.unavailable);
    }
    return BlockPage(
      kind: kind,
      items: List<BlockEntry>.unmodifiable(_blocks),
      userCount: _blocks.length,
      nextCursor: null,
    );
  }

  @override
  Future<void> setBlocked({
    required BlockKind kind,
    required String stableId,
    required bool blocked,
  }) async {
    if (!kind.isSupported) {
      throw const CommunityGatewayException(CommunityFailureKind.unavailable);
    }
    _blocks.removeWhere((entry) => entry.stableId == stableId);
    if (blocked) {
      _blocks.add(
        BlockEntry(
          kind: kind,
          stableId: stableId,
          profile: null,
          reasonCode: 'user_request',
          createdAt: DateTime.utc(2026, 9, 8),
        ),
      );
    }
  }

  @override
  Future<MessageRequestPage> listMessageRequests({String? cursor}) async =>
      MessageRequestPage(
        items: List<MessageRequestEntry>.unmodifiable(_requests),
        nextCursor: null,
      );

  @override
  Future<MessageRequestEntry> sendMessageRequest(String publicProfileId) async {
    final entry = MessageRequestEntry(
      messageRequestId: '2e3d4c5b-6a7b-4c8d-9e0f-1a2b3c4d5e6f',
      profile: _previewProfiles.firstWhere(
        (item) => item.publicProfileId == publicProfileId,
        orElse: () => _previewProfiles.first,
      ),
      createdAt: DateTime.utc(2026, 9, 8),
      expiresAt: DateTime.utc(2026, 9, 15),
      preview: const LoopUnavailableFact('MESSAGE_PREVIEW_DEFERRED'),
      aiModeration: const LoopUnavailableFact('AI_MODERATION_DEFERRED'),
    );
    return entry;
  }

  @override
  Future<MessageRequestOutcome> decideMessageRequest({
    required String messageRequestId,
    required MessageRequestDecision decision,
  }) async {
    _requests.removeWhere((item) => item.messageRequestId == messageRequestId);
    return MessageRequestOutcome(
      messageRequestId: messageRequestId,
      decision: decision,
      blocked: decision == MessageRequestDecision.report,
    );
  }
}

final class MemorySearchGateway implements SearchGateway {
  const MemorySearchGateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.preview;

  @override
  Future<SearchPage> search({
    required SearchDomain domain,
    required String query,
    String? cursor,
  }) async {
    switch (domain) {
      case SearchDomain.assets:
        return const SearchPage(
          domain: SearchDomain.assets,
          available: false,
          reasonCode: 'ASSET_REGISTRY_DEFERRED',
          results: <SearchResult>[],
          nextCursor: null,
        );
      case SearchDomain.launch:
        return const SearchPage(
          domain: SearchDomain.launch,
          available: false,
          reasonCode: 'LAUNCH_MODULE_DEFERRED',
          results: <SearchResult>[],
          nextCursor: null,
        );
      case SearchDomain.dapps:
        return const SearchPage(
          domain: SearchDomain.dapps,
          available: false,
          reasonCode: 'DAPP_DIRECTORY_DEFERRED',
          results: <SearchResult>[],
          nextCursor: null,
        );
      case SearchDomain.communities:
        final needle = query.trim().toLowerCase();
        return SearchPage(
          domain: domain,
          available: true,
          reasonCode: null,
          results: <SearchResult>[
            for (final community in _previewCommunities)
              if (community.isVerified &&
                  (community.name.toLowerCase().contains(needle) ||
                      community.slug.startsWith(needle)))
                SearchResult(
                  resultType: SearchResultType.community,
                  stableId: community.communityId,
                  title: community.name,
                  subtitle: community.slug,
                  avatarRef: community.logoRef,
                  memberCount: community.memberCount,
                  verificationStatus: community.verificationStatus.wireName,
                  destination: SearchDestinationKind.communityProfile,
                ),
          ],
          nextCursor: null,
        );
      case SearchDomain.users:
        final needle = query.trim().toLowerCase();
        return SearchPage(
          domain: domain,
          available: true,
          reasonCode: null,
          results: <SearchResult>[
            for (final profile in _previewProfiles)
              if (profile.publicProfileId != null &&
                  profile.displayName.toLowerCase().contains(needle))
                SearchResult(
                  resultType: SearchResultType.user,
                  stableId: profile.publicProfileId!,
                  title: profile.displayName,
                  subtitle: profile.loopId,
                  avatarRef: profile.avatarRef,
                  memberCount: null,
                  verificationStatus: null,
                  destination: SearchDestinationKind.publicProfile,
                ),
          ],
          nextCursor: null,
        );
    }
  }
}
