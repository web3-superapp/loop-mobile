import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/time/loop_foreground_poll.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_link.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_member_faces.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_voice_room_open.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/features/social/qr/loop_qr_card.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_round_key.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `community-profile` · one community record.
///
/// The page follows the frozen prototype's own order, which is the order a
/// community is read in: who this is (folio and identity), what can be done
/// with it (chat, AI, voice), what it is worth (the bound asset's Token Card
/// and the mining block), and what it published about itself (announcements
/// and official links). Membership is the last thing on the page rather than
/// the second, because leaving a community is not what a reader came for.
class CommunityProfileScreen extends ConsumerStatefulWidget {
  const CommunityProfileScreen({
    required this.communityId,
    super.key,
    this.onBack,
    this.onOpenMembers,
    this.onOpenChat,
    this.onOpenAi,
    this.onOpenVoiceRoom,
    this.onOpenMiningPanel,
    this.onOpenToken,
    this.onOpenChart,
    this.openLiveRoomOnArrival = false,
  });

  final String? communityId;

  /// True when this page was opened by a room link (`/c/{id}/room`,
  /// decision 0105 · 4): once the record is read, the live room is opened
  /// over it, or the reader is told there is none.
  final bool openLiveRoomOnArrival;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenMembers;
  final ValueChanged<String>? onOpenChat;

  /// Opens this community's `community-ai` page.
  ///
  /// The page it opens is entirely unavailable, and that is the point: the
  /// reason belongs on a page the reader can read, not in a toast that takes
  /// it away again (device report 2026-09-22).
  final ValueChanged<String>? onOpenAi;

  final ValueChanged<String>? onOpenVoiceRoom;

  /// The community's own mining panel, where the per-account figures the
  /// record does not carry are read.
  final ValueChanged<String>? onOpenMiningPanel;

  /// Opens the market `token` page for the bound asset's canonical id.
  final ValueChanged<String>? onOpenToken;

  /// Opens `chart-full` for the same key. The card's two actions are the two
  /// the market module can actually honour for an asset: 买入 / 卖出 would
  /// open a Swap with nothing selected, which is an action LOOP cannot state
  /// it started.
  final ValueChanged<String>? onOpenChart;

  @override
  ConsumerState<CommunityProfileScreen> createState() =>
      _CommunityProfileScreenState();
}

class _CommunityProfileScreenState
    extends ConsumerState<CommunityProfileScreen> {
  /// Reads the community's voice row again while this page is on screen.
  ///
  /// Whether a room is live is the one fact on this page that changes because
  /// of somebody else, and it was read once: a reader standing here while a
  /// room opened saw a dark control for as long as they looked at it. Five
  /// seconds is the room's own scale — it is opened and entered in the same
  /// minute — and the read stops with the page and with the app going behind
  /// something else.
  late final LoopForegroundPoll _voicePoll = LoopForegroundPoll(
    interval: const Duration(seconds: 5),
    read: _readVoiceRow,
  );

  @override
  void dispose() {
    _voicePoll.stop();
    super.dispose();
  }

  /// Whether a room link's arrival has been answered. It is answered once:
  /// coming back from the room lands on the record, not in the room again.
  var _arrivalAnswered = false;

  void _answerRoomLinkArrival(CommunityDetail detail) {
    if (!widget.openLiveRoomOnArrival || _arrivalAnswered) return;
    _arrivalAnswered = true;
    scheduleMicrotask(() {
      if (!mounted) return;
      final message = voiceRoomArrivalOutcome(detail);
      if (message == null) {
        widget.onOpenVoiceRoom?.call(detail.community.communityId);
        return;
      }
      LoopToast.show(context, message: message, kind: LoopToastKind.warn);
    });
  }

  /// One read of `GET …/voice-rooms/current` for the community on screen.
  ///
  /// Only a member may read it, and only a page that knows which community it
  /// is showing asks: a viewer the server has not let in gets nothing from
  /// this and the poll makes no request on their behalf.
  Future<void> _readVoiceRow() async {
    final id = widget.communityId;
    if (id == null || !mounted) return;
    await ref.read(communityVoiceLiveControllerProvider.notifier).read(id);
  }

  /// True once the reader asked for a voice room from this page.
  ///
  /// Opening a room is `POST …/voice-rooms` — a LOOP row, and then two writes
  /// against the provider — and only after all of it did the room page start
  /// asking for this device's own voice session. The two have nothing to say
  /// to each other: the session needs the account, not the room. So the ask
  /// starts at the tap and runs beside the creation, and the page holds it
  /// until the room page takes it over. Nothing is joined and no microphone is
  /// touched by it (S77d).
  var _warmingVoiceSession = false;

  void _warmVoiceSession() {
    if (_warmingVoiceSession || !mounted) return;
    setState(() => _warmingVoiceSession = true);
  }

  /// The community whose mining reads this page has already started.
  String? _miningReadFor;

  /// Starts the two mining reads the card's three cells are printed from.
  ///
  /// Exactly once per community, and only for a community that has a token to
  /// mine: a page that asked on every rebuild would retry a failed read for as
  /// long as the reader stood here. Both providers are the ones the mining
  /// panel itself uses, so opening the panel from this card costs no second
  /// request.
  void _bindMiningReads(CommunitySummary? community) {
    if (community == null || !community.hasBoundAsset) return;
    if (_miningReadFor == community.communityId) return;
    _miningReadFor = community.communityId;
    scheduleMicrotask(() {
      if (!mounted) return;
      unawaited(
        ref
            .read(miningCommunityControllerProvider.notifier)
            .open(community.communityId),
      );
      unawaited(ref.read(miningAssetsControllerProvider.notifier).load());
    });
  }

  /// What the 社区 tab already knows about [communityId], if it listed it.
  ///
  /// Decision 0101: the record read is one round trip, and the bound asset's
  /// quote and the mining reads used to wait for it — a second round trip for
  /// facts the tab's own rows already carried. When the reader arrived from
  /// that list the three reads start beside the record read. The hint only
  /// ever starts reads this page makes anyway; the record's own answer still
  /// decides what is drawn. An absent aggregate is not created here.
  CommunitySummary? _listedCommunity(String communityId) {
    if (!ref.exists(communityHomeControllerProvider)) return null;
    final home = ref.read(communityHomeControllerProvider).value;
    if (home == null) return null;
    for (final entry in home.joined) {
      if (entry.community.communityId == communityId) return entry.community;
    }
    for (final entry in home.owned) {
      if (entry.community.communityId == communityId) return entry.community;
    }
    return null;
  }

  /// Holds and starts the bound asset's quote from a hint, while the record
  /// that will name the same asset is still being read (same provider as the
  /// `token` page, so a later visit shares the read).
  void _prefetchBoundAsset(String assetKey) {
    final quote = marketAssetControllerProvider(assetKey);
    ref.listen(quote, (_, _) {});
    if (ref.read(quote).phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(ref.read(quote.notifier).load());
      });
    }
  }

  /// Keeps the poll armed for exactly the page that can use it.
  void _bindVoicePoll({required bool watching, required bool visible}) {
    _voicePoll.setVisible(visible);
    if (watching) {
      _voicePoll.start();
    } else {
      _voicePoll.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(communityProfileControllerProvider);
    final controller = ref.read(communityProfileControllerProvider.notifier);
    final id = widget.communityId;
    if (!communityCapabilityBlocks(mode, capability) &&
        id != null &&
        state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(id));
      });
    }

    final detail = state.value;
    final community = detail?.community;
    // A page that has not read the community yet, or is showing somebody
    // else's, asks nothing; a member's page reads the voice row on its own
    // interval for as long as it is here.
    _bindVoicePoll(
      watching:
          id != null &&
          detail != null &&
          detail.community.communityId == id &&
          detail.viewer.hasJoined,
      // Covered by a chat, a room, or another tab, the page is not looked
      // at; it reads once when it is uncovered (decision 0125).
      visible: LoopForegroundPoll.pageVisible(context),
    );
    // Held, not read: the value is the room page's business. Watching it here
    // is what keeps the session alive across the push, so the work done at
    // the tap is still there when the room page asks.
    if (_warmingVoiceSession) ref.watch(streamVideoAuthorizationProvider);
    if (detail == null &&
        id != null &&
        !communityCapabilityBlocks(mode, capability)) {
      final listed = _listedCommunity(id);
      final assetKey = listed?.boundAssetKey;
      if (assetKey != null) _prefetchBoundAsset(assetKey);
      _bindMiningReads(listed);
    }
    _bindMiningReads(detail?.community);
    // A restored snapshot can be minutes old: a room link is answered from
    // the server's own read, not from what the page remembered.
    if (detail != null &&
        detail.community.communityId == id &&
        !state.refreshing) {
      _answerRoomLinkArrival(detail);
    }
    final joinable =
        detail != null &&
        detail.community.communityId == id &&
        !detail.viewer.hasJoined &&
        detail.viewer.membership?.status != CommunityMemberStatus.banned;
    return LoopDashboardPage(
      key: const ValueKey<String>('community-profile-screen'),
      archetype: LoopPageArchetype.record,
      // Decision 0127: the bar says where the reader is; the name is the
      // header's, once, at 22.
      title: '社区',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      primary: community == null
          ? null
          : _CommunityHeader(
              community: community,
              onlineCount: detail?.onlineCount,
              onExplainPresence: switch (detail?.onlineCount) {
                CommunityOnlineCountObserved(:final count, :final observedAt) =>
                  () => unawaited(
                    showCommunityPresenceMeaningSheet(
                      context,
                      count: count,
                      observedAt: observedAt,
                    ),
                  ),
                _ => null,
              },
            ),
      block: id != null && communityCapabilityBlocks(mode, capability)
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>(
                'community-profile-capability-unavailable',
              ),
              capability: capability,
              title: '社区模块当前不可用',
            )
          : null,
      onRefresh: id == null ? null : controller.reload,
      updating: state.refreshing,
      // Decision 0127: a reader who has not joined has one thing to do here,
      // and it stands at the foot of the screen at full width.
      bottomBar: joinable
          ? _JoinBar(
              busy: state.busy,
              onJoin: () => _changeMembership(controller, joined: true),
            )
          : null,
      sections: <Widget>[
        CommunityPreviewNotice(mode: mode, resource: '社区档案'),
        if (id == null)
          const LoopEmpty(
            key: ValueKey<String>('community-profile-missing-id'),
            icon: 'warn',
            message: '缺少社区标识',
            reason: '请从社区列表或搜索结果进入，本页不会猜测要打开哪个社区。',
          )
        else if (detail == null)
          CommunityStateBlock(
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '找不到这个社区',
            emptyReason: '它可能已被移除，或对当前账号不可见。',
            empty: const LoopEmptyState(
              key: ValueKey<String>('community-profile-not-found'),
              illustration: LoopIllustration.holders,
              title: '找不到这个社区',
              message: '它可能已被移除，或对当前账号不可见。',
            ),
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          // The owner's own review, directly under the header. Every other
          // viewer is sent no `application` and sees nothing here.
          CommunityApplicationStatusCard(
            review: detail.application,
            viewer: detail.viewer,
            busy: state.busy,
            onResubmit: () => unawaited(_resubmit(controller, detail)),
          ),
          // The round keys: 进群聊 / 语音房 / 分享, and 管理 for an owner or
          // an admin (decision 0127, OKX 4908).
          _CommunityKeys(
            detail: detail,
            opening: ref.watch(voiceRoomOpenControllerProvider),
            onOpenChat: () =>
                widget.onOpenChat?.call(detail.community.communityId),
            onOpenVoiceRoom: () {
              _warmVoiceSession();
              widget.onOpenVoiceRoom?.call(detail.community.communityId);
            },
            onCreateVoiceRoom: () {
              _warmVoiceSession();
              unawaited(_createVoiceRoom(detail));
            },
            onShare: () => unawaited(
              showLoopQrCardSheet(
                context,
                LoopCommunityQrCard(
                  communityId: detail.community.communityId,
                  name: detail.community.name,
                  memberCount: detail.community.memberCount,
                  logoRef: detail.community.logoRef,
                  description: detail.community.description,
                ),
              ),
            ),
            onManage: () => unawaited(
              context.push<void>(
                communityManageLocation(detail.community.communityId),
              ),
            ),
          ),
          if (state.failureKind != null)
            LoopNotice(
              key: const ValueKey<String>('community-profile-action-failure'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '上一次操作没有完成',
              body: communityFailureReason(state.failureKind),
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          // 绑定代币: one OKX quote row.
          if (detail.community.hasBoundAsset)
            _BoundAssetSection(
              assetKey: detail.community.boundAssetKey!,
              onOpenToken: widget.onOpenToken,
            ),
          // 成员: the directory's first faces, sideways.
          _MembersSection(
            detail: detail,
            onOpenMembers: widget.onOpenMembers == null
                ? null
                : () => widget.onOpenMembers!(detail.community.communityId),
          ),
          // 社区 AI: one entry row.
          _AiEntryRow(
            onOpen: () => widget.onOpenAi?.call(detail.community.communityId),
          ),
          const LoopSectionTitle('挖矿'),
          CommunityMiningSummaryCard(
            fact: detail.miningPower,
            account: _accountReading(detail),
            onOpenPanel: widget.onOpenMiningPanel == null
                ? null
                : () => widget.onOpenMiningPanel!(detail.community.communityId),
          ),
          // What the community published about itself — only when it has.
          if (_hasAnnouncements(detail)) ...<Widget>[
            const LoopSectionTitle('公告'),
            CommunityAnnouncementBoard(
              feed: detail.announcements,
              onOpen: detail.chat.isAvailable || detail.chat.isSyncing
                  ? () => widget.onOpenChat?.call(detail.community.communityId)
                  : null,
            ),
          ],
          if (_hasLinks(detail)) ...<Widget>[
            const LoopSectionTitle('官方链接'),
            CommunityOfficialLinkRow(
              links: detail.officialLinks,
              onCopy: _copyLink,
            ),
          ],
          // Membership, last: it is the page's exit, not its subject.
          _MembershipFooter(
            detail: detail,
            busy: state.busy,
            onLeave: () => _changeMembership(controller, joined: false),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  static bool _hasAnnouncements(CommunityDetail detail) =>
      switch (detail.announcements) {
        CommunityAnnouncementFeedPublished(:final items) => items.isNotEmpty,
        CommunityAnnouncementFeedUnavailable() => false,
      };

  static bool _hasLinks(CommunityDetail detail) =>
      switch (detail.officialLinks) {
        CommunityOfficialLinksPublished(:final items) => items.isNotEmpty,
        CommunityOfficialLinksUnavailable() => false,
      };

  /// The reader's own three cells on this community's bound asset.
  ///
  /// They are two reads the mining module already owns — the community panel
  /// this card opens (`GET /v2/mining/communities/{id}`, decision 0045) and
  /// the power composition (`GET /v2/mining/assets`) — so the panel opened
  /// from here costs no second request. Nothing is computed on the device: a
  /// figure is the server's or it is the reason there is none.
  CommunityMiningAccountReading _accountReading(CommunityDetail detail) {
    if (!detail.community.hasBoundAsset) {
      return CommunityMiningAccountReading.unread('这个社区没有绑定代币，这三格没有可读的数。');
    }
    final panel = ref.watch(miningCommunityControllerProvider);
    final composition = ref.watch(miningAssetsControllerProvider);
    if (panel.phase == LaunchViewPhase.loading ||
        composition.phase == LaunchViewPhase.loading) {
      return CommunityMiningAccountReading.unread('我的持仓、算力与预估正在读取。');
    }
    final community = panel.value;
    final assets = composition.value;
    if (community == null || assets == null) {
      return CommunityMiningAccountReading.unread('这次没有读到我的挖矿数据，可以进面板重试。');
    }
    final boundAssetId = community.community.boundAssetId;
    final row = boundAssetId == null
        ? null
        : assets.included
              .where((item) => item.assetId == boundAssetId)
              .firstOrNull;
    return CommunityMiningAccountReading(
      // A wallet that holds none of the community's token holds 0 of it —
      // that is a reading, not an absence — and the row says so only when a
      // settlement actually counted this asset.
      holding: row == null
          ? const CommunityMiningCell.missing('这次结算没有算到这个代币的持仓。')
          : CommunityMiningCell.value(
              row.symbol == null
                  ? loopGroupedFigure(row.holding)
                  : '${loopGroupedFigure(row.holding)} ${row.symbol}',
            ),
      power: switch (community.myContribution) {
        MiningFigureValue(:final value) => CommunityMiningCell.value(
          loopGroupedFigure(value),
        ),
        MiningFigureUnavailable(:final reasonCode) =>
          CommunityMiningCell.missing(launchReasonCodeText(reasonCode)),
      },
      // The daily estimate LOOP settles is one account's across every asset
      // (`GET /v2/mining/summary.estimatedToday`); no endpoint states it per
      // community, and this card does not divide one to invent it.
      estimatedDaily: const CommunityMiningCell.missing('每日预估按账号总算力结算，在挖矿页读。'),
    );
  }

  /// LOOP opens no browser here, so the pill hands over the address itself.
  Future<void> _copyLink(CommunityOfficialLink link) async {
    await Clipboard.setData(ClipboardData(text: link.url));
    if (!mounted) return;
    LoopToast.show(context, message: '已复制 ${link.label} 链接');
  }

  /// 修改资料后重新提交: the edit, and then the new review.
  ///
  /// They are two commands and they are kept two. The owner edits the profile
  /// first — `PATCH` never touches the review state — and only a saved edit is
  /// followed by `POST …/resubmit`. An edit that failed does not ask for a
  /// review of the version that was refused, and an owner who decides the
  /// refusal was about nothing they wrote may submit the same profile again:
  /// whether that is acceptable is the operator's call, not this page's.
  Future<void> _resubmit(
    CommunityProfileController controller,
    CommunityDetail detail,
  ) async {
    final edit = await showCommunityProfileEditSheet(
      context,
      community: detail.community,
    );
    if (edit == null || !mounted) return;
    final confirmed = await confirmCommunityAction(
      context,
      title: '重新提交社区申请？',
      body: '资料会先保存，然后重新进入审核队列。短链接与验证状态不能在这里修改。',
      confirmLabel: '提交',
      sheetKey: 'community-resubmit-confirm-sheet',
    );
    if (!confirmed) return;
    if (!edit.isEmpty) {
      final editFailure = await controller.editProfile(edit);
      if (!mounted) return;
      if (editFailure != null) {
        LoopToast.show(
          context,
          message: communityFailureReason(editFailure),
          kind: LoopToastKind.err,
        );
        return;
      }
    }
    final failure = await controller.resubmitApplication();
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: '已重新提交，状态回到审核中');
      return;
    }
    LoopToast.show(
      context,
      message: failure == CommunityFailureKind.stale
          ? '这份申请已经不是「已驳回」了，页面已刷新，请查看最新状态。'
          : communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
    if (failure == CommunityFailureKind.stale) {
      unawaited(controller.reload());
    }
  }

  /// Opens a room for this community (shared with the manage center,
  /// decision 0113).
  Future<void> _createVoiceRoom(CommunityDetail detail) =>
      openCommunityVoiceRoom(
        context,
        ref,
        detail,
        onOpened: widget.onOpenVoiceRoom,
      );

  Future<void> _changeMembership(
    CommunityProfileController controller, {
    required bool joined,
  }) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: joined ? '加入这个社区？' : '退出这个社区？',
      body: joined ? '加入后你会出现在成员列表里。' : '退出后你将从成员目录中移除。社区所有者需要先转让所有权才能退出。',
      confirmLabel: joined ? '加入' : '退出',
      sheetKey: 'community-membership-sheet',
    );
    if (!confirmed) return;
    final failure = await controller.setMembership(joined: joined);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: joined ? '已加入社区' : '已退出社区');
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
  }
}

/// The record's header (decision 0127): the logo at 72, the name at 22 with
/// its verification as a small mark, one grey line of counts and the bound
/// token's ticker, and the community's own description.
class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({
    required this.community,
    required this.onlineCount,
    this.onExplainPresence,
  });

  final CommunitySummary community;
  final CommunityOnlineCount? onlineCount;
  final VoidCallback? onExplainPresence;

  @override
  Widget build(BuildContext context) {
    final observed = onlineCount is CommunityOnlineCountObserved
        ? onlineCount! as CommunityOnlineCountObserved
        : null;
    final symbol = community.boundAsset?.symbol;
    final counts = <InlineSpan>[
      TextSpan(text: '${communityCountLabel(community.memberCount)} 成员'),
      if (observed != null) ...<InlineSpan>[
        const TextSpan(text: ' · '),
        TextSpan(
          text: '${communityCountLabel(observed.count)} 在线',
          style: LoopTypography.figure(14, color: LoopColors.lime),
        ),
      ],
      if (symbol != null) TextSpan(text: ' · \$$symbol'),
    ];
    final countLine = Text.rich(
      TextSpan(
        children: counts,
        style: LoopTypography.figure(
          14,
          weight: FontWeight.w400,
          color: LoopColors.text2,
        ),
      ),
      key: const ValueKey<String>('community-profile-counts'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final verification = community.verificationStatus;
    final description = community.description;
    return Padding(
      key: const ValueKey<String>('community-profile-header'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CommunityLogo(
                key: const ValueKey<String>('community-profile-logo'),
                identity: community.communityId,
                name: community.name,
                logoRef: community.logoRef,
                size: 72,
                radius: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            community.name,
                            key: const ValueKey<String>(
                              'community-profile-name',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LoopTypography.heading(
                              22,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // The verification state, in words, once.
                        LoopTag(
                          communityVerificationLabel(verification),
                          key: const ValueKey<String>(
                            'community-profile-verification',
                          ),
                          lime: verification == CommunityVerification.verified,
                          icon: verification == CommunityVerification.verified
                              ? 'check'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (observed != null && onExplainPresence != null)
                      // The online figure says how it was counted when it is
                      // tapped; the line is the control, 44 tall.
                      Semantics(
                        button: true,
                        label: '在线人数是怎么数的',
                        child: GestureDetector(
                          key: const ValueKey<String>(
                            'community-online-count-explain',
                          ),
                          behavior: HitTestBehavior.opaque,
                          onTap: onExplainPresence,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: 1,
                              child: countLine,
                            ),
                          ),
                        ),
                      )
                    else
                      countLine,
                  ],
                ),
              ),
            ],
          ),
          if (description != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              description,
              key: const ValueKey<String>('community-profile-description'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.body(14, color: LoopColors.text2),
            ),
          ],
        ],
      ),
    );
  }
}

/// The record's round keys (decision 0127): 进群聊 / 语音房 / 分享, and 管理
/// for an owner or an admin.
///
/// Each key states its own condition. The voice key is an entry while a room
/// is live, an opening for an owner or an admin when none is, and the
/// server's own reason for anybody else. Every key that cannot act says why,
/// once, in the one line under the row.
class _CommunityKeys extends ConsumerWidget {
  const _CommunityKeys({
    required this.detail,
    required this.opening,
    required this.onOpenChat,
    required this.onOpenVoiceRoom,
    required this.onCreateVoiceRoom,
    required this.onShare,
    required this.onManage,
  });

  final CommunityDetail detail;

  /// An open-room command is in flight, so the key must not start another.
  final bool opening;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenVoiceRoom;
  final VoidCallback onCreateVoiceRoom;
  final VoidCallback onShare;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = detail.chat;
    final voice = detail.voice;
    // The record's own voice row was read when the page opened. While the
    // page is on screen that row is read again, so a room somebody else
    // opened lights this key up without the reader touching anything; a room
    // that ended takes the entry with it (it replaces the record's row, for
    // this community only).
    final watched = ref.watch(communityVoiceLiveControllerProvider);
    final voiceLive =
        watched != null && watched.communityId == detail.community.communityId
        ? watched.isLive
        : voice.isLive;
    final joined = detail.viewer.hasJoined;
    final chatOpenable = joined && (chat.isAvailable || chat.isSyncing);
    final mayOpenRoom = detail.viewer.mayOpenVoiceRoom && !voiceLive;
    // A reader who has not joined is told so by the join bar at the foot;
    // the keys do not repeat it.
    final chatReason = chatOpenable || !joined
        ? null
        : communicationUnavailableReason(chat.reasonCode);
    final voiceReason = voiceLive || mayOpenRoom || !joined
        ? null
        : communicationUnavailableReason(voice.reasonCode);
    final reasons = <String>[?chatReason, ?voiceReason];
    final Widget voiceKey;
    if (voiceLive) {
      voiceKey = LoopRoundKey(
        key: const ValueKey<String>('community-profile-open-voice'),
        icon: 'voice',
        label: '直播中',
        semanticLabel: '进入语音房 · 进行中',
        onPressed: onOpenVoiceRoom,
      );
    } else if (mayOpenRoom) {
      voiceKey = LoopRoundKey(
        key: const ValueKey<String>('community-profile-create-voice-room'),
        icon: 'voice',
        label: '开语音房',
        semanticLabel: '开启语音房',
        onPressed: opening ? null : onCreateVoiceRoom,
      );
    } else {
      voiceKey = const LoopRoundKey(
        key: ValueKey<String>('community-profile-open-voice'),
        icon: 'voice-off',
        label: '语音房',
        semanticLabel: '语音房',
        onPressed: null,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRoundKeyRow(
          key: const ValueKey<String>('community-profile-keys'),
          keys: <Widget>[
            LoopRoundKey(
              key: const ValueKey<String>('community-profile-open-chat'),
              icon: 'chat',
              label: '进群聊',
              onPressed: chatOpenable ? onOpenChat : null,
            ),
            voiceKey,
            LoopRoundKey(
              key: const ValueKey<String>('community-profile-share'),
              icon: 'share',
              label: '分享',
              semanticLabel: '分享社区',
              onPressed: onShare,
            ),
            // Decision 0113: only the owner and admins are offered the
            // manage center, which is where the profile is edited.
            if (detail.viewer.mayManage)
              LoopRoundKey(
                key: const ValueKey<String>('community-profile-manage'),
                icon: 'settings',
                label: '管理',
                onPressed: onManage,
              ),
          ],
        ),
        if (reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              reasons.join(' '),
              key: const ValueKey<String>('community-profile-action-reasons'),
              textAlign: TextAlign.center,
              style: LoopTypography.caption(11, color: LoopColors.text3),
            ),
          ),
      ],
    );
  }
}

/// 加入社区, at full width at the foot of a record the reader has not joined.
class _JoinBar extends StatelessWidget {
  const _JoinBar({required this.busy, required this.onJoin});

  final bool busy;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: LoopColors.ink),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: LoopWideButton(
        key: const ValueKey<String>('community-join-action'),
        label: busy ? '正在加入…' : '加入社区',
        busy: busy,
        onPressed: onJoin,
      ),
    ),
  );
}

/// 成员: a section title with 「查看全部」 and the directory's first faces.
class _MembersSection extends ConsumerWidget {
  const _MembersSection({required this.detail, required this.onOpenMembers});

  final CommunityDetail detail;
  final VoidCallback? onOpenMembers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = detail.community;
    // The directory is a member's read: a reader who has not joined is not
    // asked for it, and the strip is simply not drawn.
    final faces = detail.viewer.hasJoined
        ? ref.watch(communityMemberFacesProvider(community.communityId))
        : null;
    final members = faces?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSectionTitle(
          '成员 ${communityCountLabel(community.memberCount)}',
          trailing: LoopSeeAll(
            key: const ValueKey<String>('community-profile-open-members'),
            onPressed: onOpenMembers,
          ),
        ),
        if (members != null && members.isNotEmpty)
          CommunityMemberStrip(
            members: members,
            onOpenProfile: (publicProfileId) => unawaited(
              context.push<void>(userProfileLocation(publicProfileId)),
            ),
          ),
      ],
    );
  }
}

/// 社区 AI, as one entry row. The page it opens states what the AI will do
/// and, while the capability is closed, why it cannot yet; the row's grey
/// line says the same in one sentence.
class _AiEntryRow extends ConsumerWidget {
  const _AiEntryRow({required this.onOpen});

  final VoidCallback onOpen;

  static const _aiDeferred = 'COMMUNITY_AI_RUNTIME_DEFERRED';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityAi),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LoopPersonRow(
        key: const ValueKey<String>('community-profile-open-ai'),
        leading: const LoopEntryIcon('ai'),
        title: '社区 AI',
        subtitle: capability.isAvailable
            ? '问问这个社区的事'
            : communicationUnavailableReason(
                capability.reasonCode ?? _aiDeferred,
              ),
        chevron: true,
        onTap: onOpen,
        semanticLabel: '社区 AI',
      ),
    );
  }
}

/// 绑定代币: one OKX quote row (decision 0127) — the token's logo, its
/// ticker over its name, the price over 「24h」 and the 24h change pill.
///
/// Every figure comes from `GET /v2/market/assets/{assetKey}`, the same read
/// the `token` page makes; an unread price is the server's reason in the
/// grey line, never a zero.
class _BoundAssetSection extends ConsumerStatefulWidget {
  const _BoundAssetSection({required this.assetKey, this.onOpenToken});

  final String assetKey;
  final ValueChanged<String>? onOpenToken;

  @override
  ConsumerState<_BoundAssetSection> createState() => _BoundAssetSectionState();
}

class _BoundAssetSectionState extends ConsumerState<_BoundAssetSection> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketAssetControllerProvider(widget.assetKey));
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(marketAssetControllerProvider(widget.assetKey).notifier)
                .load(),
          );
        }
      });
    }
    final detail = state.value;
    final symbol =
        detail?.asset.settled?.symbol ?? loopTruncatedAssetId(widget.assetKey);
    final name = detail?.asset.settled?.name;
    final price = detail?.price;
    final change = detail?.priceChange24h;
    final priced = price != null && price.isAvailable;
    final open = widget.onOpenToken;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopSectionTitle('绑定代币'),
        LoopQuoteRow(
          key: const ValueKey<String>('community-bound-asset'),
          leading: LoopTokenLogo(
            assetSymbol: symbol,
            logoUrl: detail?.logoUrl,
            size: 36,
          ),
          title: symbol,
          subtitle: priced
              ? (name == null || name == symbol
                    ? loopTruncatedAssetId(widget.assetKey)
                    : name)
              : price == null
              ? (detail == null ? '行情读取中' : '暂无价格')
              : loopReasonCodeSummaryText(price.reasonCode),
          value: priced
              ? loopFoldedZerosPrice(loopFormatUsd(price.value!))
              : null,
          valueKey: const ValueKey<String>('community-bound-asset-price'),
          valueCaption: priced ? const Text('24h') : null,
          trailing: LoopChangePill(
            change: change != null && change.isAvailable ? change.value : null,
          ),
          onTap: open == null ? null : () => open(widget.assetKey),
          semanticLabel: priced
              ? '$symbol，${loopFormatUsd(price.value!)}'
              : symbol,
        ),
      ],
    );
  }
}

/// Membership, at the foot of the record: a quiet 退出社区 row for a member
/// who may leave, one grey line for an owner who may not, and the ban stated
/// for a banned account.
class _MembershipFooter extends StatelessWidget {
  const _MembershipFooter({
    required this.detail,
    required this.busy,
    required this.onLeave,
  });

  final CommunityDetail detail;
  final bool busy;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final membership = detail.viewer.membership;
    if (membership == null) return const SizedBox.shrink();
    if (membership.status == CommunityMemberStatus.banned) {
      return const LoopNotice(
        key: ValueKey<String>('community-membership-banned'),
        icon: 'shield',
        tone: LoopNoticeTone.danger,
        title: '你已被该社区封禁',
        body: '社区聊天与治理动作对你不可用。只有所有者或管理员可以解除封禁，解除后无需重新加入。',
        margin: EdgeInsets.fromLTRB(16, 22, 16, 0),
      );
    }
    if (membership.role == CommunityRole.owner) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Text(
          '所有者需要先在「成员」页转让所有者，降为 Admin 后才能退出。',
          key: const ValueKey<String>('community-owner-cannot-leave'),
          style: LoopTypography.caption(11, color: LoopColors.text3),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LoopPersonRow(
        key: const ValueKey<String>('community-leave-action'),
        leading: const LoopEntryIcon('close'),
        title: '退出社区',
        titleColor: LoopColors.fall,
        subtitle: '我的身份 · ${communityMembershipLabel(membership)}',
        onTap: busy ? null : onLeave,
        semanticLabel: '退出社区',
      ),
    );
  }
}

/// What a room link (decision 0105 · 4) does once the record is read: null
/// opens the live room, anything else is the sentence the reader is shown
/// instead, on the record page.
String? voiceRoomArrivalOutcome(CommunityDetail detail) {
  if (!detail.viewer.hasJoined) return '加入社区后才能进入语音房';
  if (!detail.voice.isLive) return '语音房已结束';
  return null;
}
