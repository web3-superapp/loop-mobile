import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/time/loop_foreground_poll.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_card_chart.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

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
  });

  final String? communityId;
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

  /// Keeps the poll armed for exactly the page that can use it.
  void _bindVoicePoll({required bool watching}) {
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
    );
    // Held, not read: the value is the room page's business. Watching it here
    // is what keeps the session alive across the push, so the work done at
    // the tap is still there when the room page asks.
    if (_warmingVoiceSession) ref.watch(streamVideoAuthorizationProvider);
    return LoopDashboardPage(
      key: const ValueKey<String>('community-profile-screen'),
      archetype: LoopPageArchetype.record,
      title: community?.name ?? communityMissingName,
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      actions: <Widget>[
        // A top-bar action is an icon on the 44 grid like every other one
        // (audit 2026-09-20 · B.2). 成员 wore a `LoopSeg`, which is the
        // segmented control this page uses to switch sections — a control
        // that reads as "you are here" next to one that leaves the page.
        // The spoken label still says 成员.
        if (community != null)
          LoopIconButton(
            key: const ValueKey<String>('community-profile-open-members'),
            icon: 'users',
            label: '成员',
            framed: true,
            onPressed: widget.onOpenMembers == null
                ? null
                : () => widget.onOpenMembers!(community.communityId),
          ),
      ],
      primary: _CommunityFolio(community: community),
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
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          // 1 · identity: the logo, the name, one mono line of counts and the
          // community's own description.
          CommunityIdentityBlock(
            community: detail.community,
            onlineCount: detail.onlineCount,
            onExplainPresence: switch (detail.onlineCount) {
              CommunityOnlineCountObserved(:final count, :final observedAt) =>
                () => unawaited(
                  showCommunityPresenceMeaningSheet(
                    context,
                    count: count,
                    observedAt: observedAt,
                  ),
                ),
              CommunityOnlineCountUnavailable() => null,
            },
          ),
          const SizedBox(height: 14),
          // 2 · the three things a community record can start: the official
          // group, Community AI and the voice room.
          _CommunityActionPair(
            detail: detail,
            busy: state.busy,
            opening: ref.watch(voiceRoomOpenControllerProvider),
            onOpenChat: () =>
                widget.onOpenChat?.call(detail.community.communityId),
            onOpenAi: () => widget.onOpenAi?.call(detail.community.communityId),
            onOpenVoiceRoom: () {
              _warmVoiceSession();
              widget.onOpenVoiceRoom?.call(detail.community.communityId);
            },
            onCreateVoiceRoom: () {
              _warmVoiceSession();
              unawaited(_createVoiceRoom(detail));
            },
            onJoin: () => _changeMembership(controller, joined: true),
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
          // 3 · the community's token.
          if (!detail.community.hasBoundAsset) ...<Widget>[
            const LoopLabel('社区币'),
            const CommunityQuietLine(
              key: ValueKey<String>('community-profile-no-asset'),
              text: '未绑定社区币',
            ),
          ] else
            _BoundAssetSection(
              assetKey: detail.community.boundAssetKey!,
              onOpenToken: widget.onOpenToken,
              onOpenChart: widget.onOpenChart,
            ),
          // 4 · mining.
          const LoopLabel('挖矿'),
          CommunityMiningSummaryCard(
            fact: detail.miningPower,
            onOpenPanel: widget.onOpenMiningPanel == null
                ? null
                : () => widget.onOpenMiningPanel!(detail.community.communityId),
          ),
          // 5 · what the community published about itself.
          const LoopLabel('公告'),
          CommunityAnnouncementBoard(
            feed: detail.announcements,
            onOpen: detail.chat.isAvailable || detail.chat.isSyncing
                ? () => widget.onOpenChat?.call(detail.community.communityId)
                : null,
          ),
          const LoopLabel('官方链接'),
          CommunityOfficialLinkRow(
            links: detail.officialLinks,
            onCopy: _copyLink,
          ),
          // 6 · membership, last: it is the page's exit, not its subject.
          _MembershipFooter(
            detail: detail,
            busy: state.busy,
            onLeave: () => _changeMembership(controller, joined: false),
            onEditProfile: () => unawaited(_editProfile(controller, detail)),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// LOOP opens no browser here, so the pill hands over the address itself.
  Future<void> _copyLink(CommunityOfficialLink link) async {
    await Clipboard.setData(ClipboardData(text: link.url));
    if (!mounted) return;
    LoopToast.show(context, message: '已复制 ${link.label} 链接');
  }

  Future<void> _editProfile(
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
      title: '提交社区资料修改？',
      body: '短链接与验证状态不能在这里修改。',
      confirmLabel: '提交',
      sheetKey: 'community-edit-confirm-sheet',
    );
    if (!confirmed) return;
    final failure = await controller.editProfile(edit);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: '社区资料已更新');
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
  }

  /// Opens a room for this community. The button exists only for a viewer the
  /// server reports as owner or admin, but the admission is still the
  /// server's: this states what came back and never claims a room that was
  /// not confirmed.
  Future<void> _createVoiceRoom(CommunityDetail detail) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: '开启语音房？',
      body:
          '房间会立刻对社区成员可见，任何成员都能进来收听。你是主持人，'
          '邀请发言、全体静音和结束房间都由你或其他管理员操作；麦克风默认关闭。',
      confirmLabel: '开启',
      sheetKey: 'community-open-voice-room-sheet',
    );
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(voiceRoomOpenControllerProvider.notifier)
        .openRoom(detail.community.communityId);
    if (!mounted) return;
    final failure = outcome.failure;
    if (failure == null) {
      if (outcome.isOpen) {
        LoopToast.show(context, message: '语音房已开启');
        unawaited(
          ref.read(communityProfileControllerProvider.notifier).reload(),
        );
        widget.onOpenVoiceRoom?.call(detail.community.communityId);
        return;
      }
      // The room row exists and the call behind it does not, so nobody can be
      // let in — including the host who just opened it. This is the state the
      // review device met as a room it entered and could not hear. The page
      // stays where it is and 「开启语音房」 stays on it: the next tap repeats
      // the provider half of the same command, which is the one recovery
      // there is. Asking for a second room would be refused — the room that
      // cannot be entered is still the community's one live room.
      LoopToast.show(
        context,
        message: voiceRoomOpenUnfinishedText(outcome.unconfirmedReason),
        kind: LoopToastKind.warn,
      );
      return;
    }
    LoopToast.show(
      context,
      message: failure == CommunityFailureKind.resourceConflict
          // The shared copy for this code is about a taken slug; here the
          // conflict is a room that is already live.
          ? '这个社区已经有进行中的语音房，没有重复创建。请刷新后进入。'
          : communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
    if (failure == CommunityFailureKind.resourceConflict) {
      unawaited(ref.read(communityProfileControllerProvider.notifier).reload());
    }
  }

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

/// `.ledger-card.ledger-quiet.folio-primary` — the record's own heading.
///
/// It carries the community's logo at the top right and its verification at
/// the bottom right, which is the one place the state is stated: the identity
/// block below it carries the same fact in no other form.
class _CommunityFolio extends StatelessWidget {
  const _CommunityFolio({required this.community});

  final CommunitySummary? community;

  @override
  Widget build(BuildContext context) {
    final resolved = community;
    return LoopFolioPrimary(
      variant: LoopFolioVariant.quiet,
      archetype: LoopFolioArchetype.record,
      kicker: 'COMMUNITY RECORD',
      heading: resolved?.name ?? communityMissingName,
      caption: resolved == null
          ? '社区资料暂时读不到，这里不显示数字。'
          : '成员、资产、Mining 与官方信息汇合为一份社区档案。',
      // The stamp says the state in words rather than in an English status
      // name, and it is now the only carrier of it (S22b): the identity card
      // that used to repeat it as 「已验证」 is gone.
      stamp: resolved == null
          ? null
          : communityVerificationLabel(resolved.verificationStatus),
      trailing: resolved == null
          ? null
          : CommunityLogo(
              key: const ValueKey<String>('community-folio-logo'),
              identity: resolved.communityId,
              name: resolved.name,
              logoRef: resolved.logoRef,
              size: 72,
              radius: LoopRadius.shellValue,
              bordered: true,
            ),
    );
  }
}

/// `.btn-pair` — 进入聊天 / AI / 语音, in the prototype's own order.
///
/// Each button states its own condition. A reader who has not joined is
/// offered the join first, because the official group is not open to them
/// until the server says it is; AI opens the community's AI page, which
/// carries the reason it is closed on the page itself; the voice control is
/// an entry while a room is live, an opening for an owner or an admin when
/// none is, and the server's own reason for anybody else.
class _CommunityActionPair extends ConsumerWidget {
  const _CommunityActionPair({
    required this.detail,
    required this.busy,
    required this.opening,
    required this.onOpenChat,
    required this.onOpenAi,
    required this.onOpenVoiceRoom,
    required this.onCreateVoiceRoom,
    required this.onJoin,
  });

  final CommunityDetail detail;

  /// A membership write is in flight.
  final bool busy;

  /// An open-room command is in flight, so the button must not start another.
  final bool opening;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenVoiceRoom;
  final VoidCallback onCreateVoiceRoom;
  final VoidCallback onJoin;

  static const _aiDeferred = 'COMMUNITY_AI_RUNTIME_DEFERRED';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = detail.chat;
    final voice = detail.voice;
    // The record's own voice row was read when the page opened. While the
    // page is on screen that row is read again, so a room somebody else
    // opened lights this control up without the reader touching anything.
    final watched = ref.watch(communityVoiceLiveControllerProvider);
    // A room that ended has to take the control with it: an entry left
    // standing over a room nobody is in is a door into 「房间已结束」, and the
    // owner cannot open the next room while it is there. So the watched row
    // replaces the record's own rather than being added to it — for this
    // community, and never for another one's answer.
    final voiceLive =
        watched != null && watched.communityId == detail.community.communityId
        ? watched.isLive
        : voice.isLive;
    final joined = detail.viewer.hasJoined;
    final banned =
        detail.viewer.membership?.status == CommunityMemberStatus.banned;
    final chatOpenable = chat.isAvailable || chat.isSyncing;
    final aiCapability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityAi),
    );
    // The AI button explains itself only while the capability is closed. An
    // open one kept printing 「Community AI 还没有开放」 under a control that
    // opens a working page, which is a sentence the page itself contradicts.
    final aiReason = aiCapability.isAvailable
        ? null
        : communicationUnavailableReason(
            aiCapability.reasonCode ?? _aiDeferred,
          );
    final mayOpenRoom = detail.viewer.mayOpenVoiceRoom && !voiceLive;
    final chatReason = chatOpenable
        ? null
        : communicationUnavailableReason(chat.reasonCode);
    final voiceReason = voiceLive || mayOpenRoom
        ? null
        : communicationUnavailableReason(voice.reasonCode);
    final reasons = <String>[?chatReason, ?voiceReason, ?aiReason];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopButtonPair(
          children: <Widget>[
            if (!joined && !banned)
              LoopButton(
                key: const ValueKey<String>('community-join-action'),
                label: '加入社区',
                primary: true,
                onPressed: busy ? null : onJoin,
              )
            else
              LoopButton(
                key: const ValueKey<String>('community-profile-open-chat'),
                label: '进入聊天',
                primary: true,
                onPressed: chatOpenable ? onOpenChat : null,
              ),
            LoopButton(
              key: const ValueKey<String>('community-profile-open-ai'),
              label: 'AI',
              icon: 'ai',
              // The capability is closed, and for a while the tap answered
              // with a toast that took the sentence away again — which read
              // as a button that does nothing. It opens the page instead:
              // `community-ai` states what the AI will do, what it cannot do
              // yet, and why, and it stays on screen to be read.
              onPressed: onOpenAi,
            ),
            if (voiceLive)
              // A room that is running says so on the control itself. The
              // glyph alone changed nothing a reader could see: on the review
              // device the only mark of a live room was the strip at the top
              // of the app, and the community page it was standing on looked
              // exactly as it had a moment before (walkthrough 2026-09-23 ·
              // a34 / community-profile).
              LoopButton(
                key: const ValueKey<String>('community-profile-open-voice'),
                label: 'LIVE',
                icon: 'voice',
                semanticLabel: '进入语音房 · 进行中',
                onPressed: onOpenVoiceRoom,
              )
            else if (mayOpenRoom)
              LoopButton(
                key: const ValueKey<String>(
                  'community-profile-create-voice-room',
                ),
                label: '',
                icon: 'voice',
                semanticLabel: '开启语音房',
                onPressed: opening ? null : onCreateVoiceRoom,
              )
            else
              LoopButton(
                key: const ValueKey<String>('community-profile-open-voice'),
                label: '',
                icon: 'voice-off',
                semanticLabel: '语音房',
                onPressed: null,
              ),
          ],
        ),
        // Every control that cannot act says why, once, under the row it
        // belongs to. A row on which all three can act says nothing at all,
        // rather than keeping an empty line where a reason used to be.
        if (reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              reasons.join(' '),
              key: const ValueKey<String>('community-profile-action-reasons'),
              style: LoopTypography.caption(11, color: LoopColors.text3),
            ),
          ),
      ],
    );
  }
}

/// `社区币 · <symbol>` and the signature Token Card under it.
///
/// Every figure on the card comes from `GET /v2/market/assets/{assetKey}` —
/// the same read the `token` page makes — and an unavailable one renders the
/// server's reason instead of a number. The community module still knows only
/// the address; it derives nothing from it.
class _BoundAssetSection extends ConsumerStatefulWidget {
  const _BoundAssetSection({
    required this.assetKey,
    this.onOpenToken,
    this.onOpenChart,
  });

  final String assetKey;
  final ValueChanged<String>? onOpenToken;
  final ValueChanged<String>? onOpenChart;

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
    final candles = ref.watch(
      marketCandlesControllerProvider(
        MarketCandleRequest(
          assetId: widget.assetKey,
          interval: LoopCandleInterval.oneHour,
        ),
      ),
    );
    final absence = tokenCardSparklineAbsence(candles);
    final price = detail?.price;
    final change = detail?.priceChange24h;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopLabel('社区币 · $symbol'),
        KeyedSubtree(
          key: const ValueKey<String>('community-bound-asset'),
          child: LoopTokenCard(
            state: LoopTokenCardState.normal,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            model: LoopTokenCardModel(
              symbol: symbol,
              identifier: loopTruncatedAssetId(widget.assetKey),
              price: price != null && price.isAvailable
                  ? loopFormatUsd(price.value!)
                  : null,
              priceReason: price == null
                  ? '暂无价格'
                  : price.isAvailable
                  ? null
                  : loopReasonCodeSummaryText(price.reasonCode),
              change: change != null && change.isAvailable
                  ? loopFormatPercent(change.value!)
                  : null,
              changeUp: change != null && change.isAvailable
                  ? change.value! >= Decimal.zero
                  : null,
              metrics: <LoopTokenMetric>[
                _metric('市值', detail?.marketCap),
                _metric('流动性', detail?.liquidityUsd),
                _metric('持有人', detail?.holderCount, usd: false),
              ],
              communityIcon: 'info',
              communityLine: detail == null
                  ? '这个地址由社区所有者登记，行情暂时读不到，卡片上不显示数字。'
                  : price != null && price.isAvailable
                  ? '报价 ${loopFactProvenance(price)}'
                  : '这张卡片的每个数字都取自行情页的同一份数据，读不到的一项会说明原因，不会显示 0。',
              chartRangeLabel: absence == null
                  ? '1H · 最近 $loopSparklineWindow 根收盘价'
                  : null,
              chart: absence == null
                  ? TokenCardSparkline(
                      assetId: widget.assetKey,
                      keyPrefix: 'community-bound-asset-chart',
                    )
                  : null,
            ),
            actions: <LoopTokenCardAction>[
              LoopTokenCardAction(
                '行情',
                onTap: widget.onOpenToken == null
                    ? null
                    : () => widget.onOpenToken!(widget.assetKey),
              ),
              LoopTokenCardAction(
                '图表',
                onTap: widget.onOpenChart == null
                    ? null
                    : () => widget.onOpenChart!(widget.assetKey),
              ),
            ],
          ),
        ),
        if (absence != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '暂无走势：${absence.text}',
              key: const ValueKey<String>('community-bound-asset-chart-note'),
              style: LoopTypography.caption(11, color: LoopColors.text3),
            ),
          ),
      ],
    );
  }

  /// One metric cell. A figure with no read behind it states the reason it
  /// has none; it never falls back to a zero.
  LoopTokenMetric _metric(String label, LoopFact? fact, {bool usd = true}) {
    if (fact == null) return LoopTokenMetric(label, communityMissingFigure);
    return LoopTokenMetric(
      label,
      fact.isAvailable
          ? loopFormatCompactFigure(fact.value!, usd: usd)
          : loopReasonCodeSummaryText(fact.reasonCode),
    );
  }
}

/// Membership, at the foot of the record.
///
/// It is one line saying what this account is here, and one quiet control for
/// the one thing that line allows. A banned membership says so and offers
/// nothing; an owner is told why the control is not there, because the server
/// refuses the write until ownership is transferred.
class _MembershipFooter extends StatelessWidget {
  const _MembershipFooter({
    required this.detail,
    required this.busy,
    required this.onLeave,
    required this.onEditProfile,
  });

  final CommunityDetail detail;
  final bool busy;
  final VoidCallback onLeave;
  final VoidCallback onEditProfile;

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
        body:
            '社区聊天与治理动作对你不可用，你也不在默认成员目录里。'
            '只有社区的所有者或管理员可以解除封禁；解除后你会恢复为活跃成员，无需重新加入。',
        margin: EdgeInsets.fromLTRB(16, 22, 16, 0),
      );
    }
    final isOwner = membership.role == CommunityRole.owner;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: Text(
            '我的身份 · ${communityMembershipLabel(membership)}',
            key: const ValueKey<String>('community-membership-status'),
            style: LoopTypography.caption(12, color: LoopColors.text3),
          ),
        ),
        LoopButtonPair(
          children: <Widget>[
            if (isOwner)
              LoopButton(
                key: const ValueKey<String>('community-edit-profile-action'),
                label: '编辑社区资料',
                onPressed: busy ? null : onEditProfile,
              )
            else
              LoopButton(
                key: const ValueKey<String>('community-leave-action'),
                label: '退出社区',
                onPressed: busy ? null : onLeave,
              ),
          ],
        ),
        if (isOwner)
          // The role the transfer actually leaves behind is Admin, which is
          // what the members page's own confirmation states.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '所有者不能直接退出：先在「成员」页对某位成员执行「转让所有者」，'
              '你会降为 Admin，之后才能退出。',
              key: const ValueKey<String>('community-owner-cannot-leave'),
              style: LoopTypography.caption(11, color: LoopColors.text3),
            ),
          ),
      ],
    );
  }
}
