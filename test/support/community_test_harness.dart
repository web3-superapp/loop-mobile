import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

const testCommunityId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const testOwnerId = '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f';
const testAdminId = '8b2e1f3d-4a5b-4c6d-8e7f-9a0b1c2d3e4f';
const testMemberId = '7a3d2e4c-5b6c-4d7e-8f90-1a2b3c4d5e60';
const testRequestId = '1d2c3b4a-5e6f-4a7b-8c9d-0e1f2a3b4c5d';

const testMiningPower = LoopUnavailableFact('MINING_FORMULA_BASELINE_PENDING');
const testPresence = LoopUnavailableFact('STREAM_PRESENCE_NOT_CONNECTED');

CommunitySummary testCommunity({
  String communityId = testCommunityId,
  String name = 'Frog Holders',
  int memberCount = 128,
  CommunityVerification verification = CommunityVerification.verified,
  String? boundAssetKey,
}) => CommunitySummary(
  communityId: communityId,
  name: name,
  slug: 'frog-holders',
  description: null,
  logoRef: null,
  verificationStatus: verification,
  boundAssetKey: boundAssetKey,
  memberCount: memberCount,
  createdAt: DateTime.utc(2026, 6),
  configVersion: 'communityV1',
);

LoopPublicProfile testProfile({
  String? publicProfileId = testOwnerId,
  String loopId = 'LOOP-7HJKMNPQ',
  String? alias = 'frog_maxi',
}) => LoopPublicProfile(
  publicProfileId: publicProfileId,
  loopId: loopId,
  alias: alias,
  avatarRef: null,
);

CommunityViewer testViewer({
  CommunityRole? role = CommunityRole.owner,
  CommunityMemberStatus status = CommunityMemberStatus.active,
  bool canInviteAdmin = true,
  bool canMute = true,
  bool canBan = true,
}) => CommunityViewer(
  membership: role == null
      ? null
      : CommunityMembership(
          role: role,
          status: status,
          joinedAt: DateTime.utc(2026, 7),
        ),
  canInviteAdmin: canInviteAdmin,
  canMute: canMute,
  canBan: canBan,
);

const testChatUnavailable = CommunityChatSection(
  status: CommunityChatStatus.unavailable,
  channelCid: null,
  memberState: null,
  reasonCode: 'COMMUNITY_CHANNEL_NOT_PROVISIONED',
);

const testChatAvailable = CommunityChatSection(
  status: CommunityChatStatus.available,
  channelCid: 'messaging:loop_community_0123456789abcdef0123456789abcdef',
  memberState: CommunityChatMemberState.synced,
  reasonCode: null,
);

const testChatSyncing = CommunityChatSection(
  status: CommunityChatStatus.syncing,
  channelCid: null,
  memberState: CommunityChatMemberState.pending,
  reasonCode: 'COMMUNITY_CHANNEL_MEMBER_SYNCING',
);

const testVoiceUnavailable = CommunityVoiceSection(
  status: CommunityVoiceStatus.unavailable,
  currentRoomId: null,
  reasonCode: 'COMMUNITY_VOICE_ROOM_NOT_LIVE',
);

CommunityDetail testDetail({
  CommunitySummary? community,
  CommunityViewer? viewer,
  CommunityChatSection chat = testChatUnavailable,
  CommunityVoiceSection voice = testVoiceUnavailable,
}) => CommunityDetail(
  community: community ?? testCommunity(),
  viewer: viewer ?? testViewer(),
  miningPower: testMiningPower,
  onlineCount: testPresence,
  announcements: const LoopUnavailableFact('COMMUNITY_ANNOUNCEMENTS_DEFERRED'),
  officialLinks: const LoopUnavailableFact('COMMUNITY_LINKS_DEFERRED'),
  chat: chat,
  voice: voice,
);

CommunityMemberEntry testMember({
  required CommunityRole role,
  String? publicProfileId = testMemberId,
  String loopId = 'LOOP-3HJKMNPQ',
  String? alias = 'frog_member',
  CommunityMemberStatus status = CommunityMemberStatus.active,
  bool isSelf = false,
}) => CommunityMemberEntry(
  profile: testProfile(
    publicProfileId: publicProfileId,
    loopId: loopId,
    alias: alias,
  ),
  role: role,
  status: status,
  joinedAt: DateTime.utc(2026, 7),
  isSelf: isSelf,
  miningPower: testMiningPower,
);

CommunityMemberDirectory testDirectory({
  List<CommunityMemberEntry>? items,
  CommunityViewer? viewer,
  String? nextCursor,
}) => CommunityMemberDirectory(
  community: testCommunity(),
  viewer: viewer ?? testViewer(),
  counts: CommunityMemberCounts(
    all: 128,
    owner: 1,
    admin: 3,
    online: testPresence,
  ),
  items:
      items ?? <CommunityMemberEntry>[testMember(role: CommunityRole.member)],
  nextCursor: nextCursor,
);

ReferralRules testReferralRules() => ReferralRules(
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

/// A deterministic community port. Every method either returns the configured
/// value or fails with the configured kind; nothing is invented.
final class FakeCommunityGateway implements CommunityGateway {
  FakeCommunityGateway({
    this.mode = CommunityGatewayMode.production,
    this.failure,
    this.writeFailure,
    this.home,
    this.directoryPage,
    this.detail,
    this.members,
    this.createdDetail,
    this.membersByFilter =
        const <CommunityMemberFilter, CommunityMemberDirectory>{},
  });

  @override
  CommunityGatewayMode mode;

  /// Never completes: the page must keep its loading state.
  bool pending = false;
  CommunityFailureKind? failure;
  CommunityFailureKind? writeFailure;
  CommunityHome? home;
  CommunityDirectoryPage? directoryPage;
  CommunityDetail? detail;
  CommunityMemberDirectory? members;

  /// Per-filter directories. A missing entry falls back to [members], so an
  /// existing test keeps its single-view behaviour.
  Map<CommunityMemberFilter, CommunityMemberDirectory> membersByFilter;

  /// Set when the application must be accepted; otherwise `writeFailure`
  /// (or `failure`) decides the refusal.
  CommunityDetail? createdDetail;

  final List<String> commands = <String>[];

  Future<T> _read<T>(T? value) {
    if (pending) return Completer<T>().future;
    final kind = failure;
    if (kind != null) {
      return Future<T>.error(CommunityGatewayException(kind));
    }
    if (value == null) {
      return Future<T>.error(
        const CommunityGatewayException(CommunityFailureKind.notFound),
      );
    }
    return Future<T>.value(value);
  }

  Future<T> _write<T>(String command, T? value) {
    commands.add(command);
    final kind = writeFailure ?? failure;
    if (kind != null) {
      return Future<T>.error(CommunityGatewayException(kind));
    }
    if (value == null) {
      return Future<T>.error(
        const CommunityGatewayException(CommunityFailureKind.notFound),
      );
    }
    return Future<T>.value(value);
  }

  @override
  Future<CommunityHome> loadHome() => _read(home);

  @override
  Future<CommunityDirectoryPage> listCommunities({
    CommunityDirectorySort sort = CommunityDirectorySort.members,
    CommunityVerificationFilter verification =
        CommunityVerificationFilter.verified,
    CommunityMembershipFilter membership = CommunityMembershipFilter.all,
    String? cursor,
  }) {
    commands.add('list:${sort.wireName}:${membership.wireName}:$cursor');
    return _read(directoryPage);
  }

  @override
  Future<CommunityDetail> createCommunity(CommunityApplication application) =>
      _write('create:${application.slug}', createdDetail);

  @override
  Future<CommunityDetail> loadCommunity(String communityId) => _read(detail);

  @override
  Future<CommunityDetail> join(String communityId) =>
      _write('join:$communityId', detail);

  @override
  Future<CommunityDetail> leave(String communityId) =>
      _write('leave:$communityId', detail);

  @override
  Future<CommunityDetail> editProfile(
    String communityId,
    CommunityProfileEdit edit,
  ) => _write('edit:$communityId:${edit.name}', detail);

  @override
  Future<CommunityMemberDirectory> listMembers(
    String communityId, {
    CommunityMemberFilter role = CommunityMemberFilter.all,
    String? cursor,
  }) {
    commands.add('members:${role.wireName}:$cursor');
    return _read(membersByFilter[role] ?? members);
  }

  @override
  Future<CommunityMemberDirectory> changeMemberRole({
    required String communityId,
    required String publicProfileId,
    required CommunityRole role,
  }) => _write('role:$publicProfileId:${role.wireName}', members);

  @override
  Future<CommunityMemberDirectory> setMuted({
    required String communityId,
    required String publicProfileId,
    required bool muted,
  }) => _write('mute:$publicProfileId:$muted', members);

  @override
  Future<CommunityMemberDirectory> setBanned({
    required String communityId,
    required String publicProfileId,
    required bool banned,
  }) => _write('ban:$publicProfileId:$banned', members);

  @override
  Future<ReferralRules> loadReferralRules() => _read(testReferralRules());
}

final class FakeSocialGateway implements SocialGateway {
  FakeSocialGateway({
    this.mode = CommunityGatewayMode.production,
    this.failure,
    this.writeFailure,
    this.connections,
    this.blocks,
    this.requests,
    this.outcome,
  });

  @override
  CommunityGatewayMode mode;

  bool pending = false;
  CommunityFailureKind? failure;
  CommunityFailureKind? writeFailure;
  ConnectionPage? connections;
  BlockPage? blocks;
  MessageRequestPage? requests;
  MessageRequestEntry? sentRequest;
  MessageRequestOutcome? outcome;

  final List<String> commands = <String>[];

  Future<T> _read<T>(T? value) {
    if (pending) return Completer<T>().future;
    final kind = failure;
    if (kind != null) {
      return Future<T>.error(CommunityGatewayException(kind));
    }
    if (value == null) {
      return Future<T>.error(
        const CommunityGatewayException(CommunityFailureKind.notFound),
      );
    }
    return Future<T>.value(value);
  }

  @override
  Future<ConnectionPage> listConnections({
    ConnectionDirection direction = ConnectionDirection.following,
    String? cursor,
  }) {
    commands.add('connections:${direction.wireName}');
    return _read(connections);
  }

  @override
  Future<FollowOutcome> setFollowing({
    required String publicProfileId,
    required bool following,
  }) {
    commands.add('follow:$publicProfileId:$following');
    final kind = writeFailure;
    if (kind != null) {
      return Future<FollowOutcome>.error(CommunityGatewayException(kind));
    }
    return Future<FollowOutcome>.value(
      FollowOutcome(
        profile: testProfile(publicProfileId: publicProfileId),
        viewerFollows: following,
      ),
    );
  }

  @override
  Future<BlockPage> listBlocks({
    BlockKind kind = BlockKind.user,
    String? cursor,
  }) {
    commands.add('blocks:${kind.wireName}');
    if (!kind.isSupported) {
      return Future<BlockPage>.error(
        const CommunityGatewayException(CommunityFailureKind.unavailable),
      );
    }
    return _read(blocks);
  }

  @override
  Future<void> setBlocked({
    required BlockKind kind,
    required String stableId,
    required bool blocked,
  }) {
    commands.add('block:${kind.wireName}:$stableId:$blocked');
    final failureKind = writeFailure;
    if (failureKind != null) {
      return Future<void>.error(CommunityGatewayException(failureKind));
    }
    blocks = BlockPage(
      kind: BlockKind.user,
      items: const <BlockEntry>[],
      userCount: 0,
      nextCursor: null,
    );
    return Future<void>.value();
  }

  @override
  Future<MessageRequestPage> listMessageRequests({String? cursor}) =>
      _read(requests);

  @override
  Future<MessageRequestEntry> sendMessageRequest(String publicProfileId) {
    commands.add('message-request:$publicProfileId');
    final kind = writeFailure;
    if (kind != null) {
      return Future<MessageRequestEntry>.error(CommunityGatewayException(kind));
    }
    return Future<MessageRequestEntry>.value(
      sentRequest ??
          MessageRequestEntry(
            messageRequestId: '1d2c3b4a-5e6f-4a7b-8c9d-0e1f2a3b4c5d',
            profile: testProfile(publicProfileId: publicProfileId),
            createdAt: DateTime.utc(2026, 9, 8),
            expiresAt: DateTime.utc(2026, 9, 15),
            preview: const LoopUnavailableFact('MESSAGE_PREVIEW_DEFERRED'),
            aiModeration: const LoopUnavailableFact('AI_MODERATION_DEFERRED'),
          ),
    );
  }

  @override
  Future<MessageRequestOutcome> decideMessageRequest({
    required String messageRequestId,
    required MessageRequestDecision decision,
  }) {
    commands.add('decision:$messageRequestId:${decision.wireName}');
    final kind = writeFailure;
    if (kind != null) {
      return Future<MessageRequestOutcome>.error(
        CommunityGatewayException(kind),
      );
    }
    return Future<MessageRequestOutcome>.value(
      outcome ??
          MessageRequestOutcome(
            messageRequestId: messageRequestId,
            decision: decision,
            blocked: decision == MessageRequestDecision.report,
          ),
    );
  }
}

final class FakeSearchGateway implements SearchGateway {
  FakeSearchGateway({
    this.mode = CommunityGatewayMode.production,
    this.failure,
    this.pages = const <SearchDomain, SearchPage>{},
  });

  @override
  CommunityGatewayMode mode;

  bool pending = false;
  CommunityFailureKind? failure;
  Map<SearchDomain, SearchPage> pages;

  final List<String> queries = <String>[];

  @override
  Future<SearchPage> search({
    required SearchDomain domain,
    required String query,
    String? cursor,
  }) {
    queries.add('${domain.wireName}:$query');
    if (pending) return Completer<SearchPage>().future;
    final kind = failure;
    if (kind != null) {
      return Future<SearchPage>.error(CommunityGatewayException(kind));
    }
    final page = pages[domain];
    if (page == null) {
      return Future<SearchPage>.error(
        const CommunityGatewayException(CommunityFailureKind.notFound),
      );
    }
    return Future<SearchPage>.value(page);
  }
}

/// A capability document that reports every id as `available`, so a page's
/// own state is what the test observes.
LoopV2MetaSnapshot testMetaSnapshot({
  LoopV2CapabilityAvailability community =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability search = LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability communityChat =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability voiceRooms =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability communityAi =
      LoopV2CapabilityAvailability.deferred,
  bool voiceRoomEvidencePending = false,
}) {
  return LoopV2MetaSnapshot(
    clientPolicy: LoopV2ClientPolicy(
      contractVersion: '2.0',
      configVersion: 'productPolicyV2.2026-09-01',
      effectiveAt: DateTime.utc(2026, 9),
      defaultRoute: LoopV2PrimaryTab.community,
      navigation: LoopV2Navigation(primaryTabs: LoopV2PrimaryTab.values),
      versionGate: const LoopV2VersionGate.unavailable(
        reasonCode: 'CLIENT_VERSION_POLICY_UNAVAILABLE',
      ),
      regionGate: const LoopV2RegionGate(
        status: LoopV2RegionGateStatus.unavailable,
        reasonCode: 'REGION_POLICY_UNAVAILABLE',
        supportUrl: null,
        readOnlyAssetAccess: null,
      ),
      termsGate: const LoopV2TermsGate(
        status: LoopV2TermsGateStatus.unavailable,
        requiredVersion: null,
        reasonCode: 'TERMS_POLICY_UNAVAILABLE',
      ),
    ),
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: 'productPolicyV2.2026-09-01',
      effectiveAt: DateTime.utc(2026, 9),
      capabilities: <LoopV2Capability>[
        for (final id in LoopV2CapabilityId.values)
          LoopV2Capability(
            id: id,
            availability: switch (id) {
              LoopV2CapabilityId.community => community,
              LoopV2CapabilityId.search => search,
              LoopV2CapabilityId.communityChat => communityChat,
              LoopV2CapabilityId.voiceRooms => voiceRooms,
              LoopV2CapabilityId.communityAi => communityAi,
              _ => LoopV2CapabilityAvailability.unavailable,
            },
            reasonCode: switch (id) {
              LoopV2CapabilityId.community =>
                community == LoopV2CapabilityAvailability.available
                    ? null
                    : 'COMMUNITY_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.search =>
                search == LoopV2CapabilityAvailability.available
                    ? null
                    : 'SEARCH_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.communityChat =>
                communityChat == LoopV2CapabilityAvailability.available
                    ? null
                    : 'COMMUNICATION_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.voiceRooms =>
                voiceRooms == LoopV2CapabilityAvailability.available
                    ? null
                    : 'COMMUNICATION_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.communityAi =>
                communityAi == LoopV2CapabilityAvailability.available
                    ? null
                    : 'COMMUNITY_AI_RUNTIME_DEFERRED',
              _ => 'NOT_CONNECTED',
            },
            // Decision 0005 keeps a provider-evidence flag on `voiceRooms`
            // only; every other capability carries `notApplicable`.
            evidence:
                id == LoopV2CapabilityId.voiceRooms && voiceRoomEvidencePending
                ? const LoopV2CapabilityEvidence(
                    status: LoopV2CapabilityEvidenceStatus.pending,
                    reasonCode: 'AUDIO_ROOM_USER_ROLE_EVIDENCE_PENDING',
                  )
                : const LoopV2CapabilityEvidence(
                    status: LoopV2CapabilityEvidenceStatus.notApplicable,
                    reasonCode: null,
                  ),
          ),
      ],
    ),
  );
}

/// Pumps one S3 page with the toast host the action paths require.
Future<void> pumpCommunityPage(
  WidgetTester tester,
  Widget page, {
  CommunityGateway? community,
  SocialGateway? social,
  SearchGateway? search,
  ChatV2Gateway? chat,
  VoiceRoomGateway? voiceRoom,
  GroupAliasResolverGateway? groupAliasResolver,
  LoopV2MetaSnapshot? meta,
  Size size = const Size(390, 1400),
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (community != null)
          communityGatewayProvider.overrideWithValue(community),
        if (social != null) socialGatewayProvider.overrideWithValue(social),
        if (search != null) searchGatewayProvider.overrideWithValue(search),
        if (chat != null) chatV2GatewayProvider.overrideWithValue(chat),
        if (voiceRoom != null)
          voiceRoomGatewayProvider.overrideWithValue(voiceRoom),
        if (groupAliasResolver != null)
          groupAliasResolverGatewayProvider.overrideWithValue(
            groupAliasResolver,
          ),
        loopV2MetaSnapshotProvider.overrideWith(
          (ref) async => meta ?? testMetaSnapshot(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: page,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // A never-completing read keeps the skeleton animating, so the frame is
    // pumped a fixed number of times instead of settled.
    await tester.pump();
    await tester.pump();
  }
}

/// Scrolls the page's own collection until [finder] is built and visible.
///
/// The pages are lazy slivers, so a section below the fold does not exist
/// until it is scrolled into view.
Future<void> scrollToCommunitySection(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).first,
  );
}
