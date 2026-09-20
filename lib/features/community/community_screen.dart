import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/community/community_home_widgets.dart';
import 'package:loop_mobile/features/community/search_controller.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

typedef CommunityNavigation = void Function(String location);

/// Which of the two mutually exclusive topbar panels is open.
enum CommunityPanel { none, search, messages }

/// `community` · the post-login home aggregate.
///
/// Every figure on this page comes from `GET /v2/community/home`. Unread
/// counts, live voice and stranger requests have no source before D7, so the
/// message panel states that instead of showing a badge.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, this.onNavigate});

  final CommunityNavigation? onNavigate;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final FocusNode _searchToggleFocus = FocusNode(
    debugLabel: 'community-search',
  );
  final FocusNode _messageToggleFocus = FocusNode(
    debugLabel: 'community-messages',
  );
  CommunityPanel _panel = CommunityPanel.none;

  @override
  void dispose() {
    _searchToggleFocus.dispose();
    _messageToggleFocus.dispose();
    super.dispose();
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  /// The two panels are mutually exclusive: opening one always closes the
  /// other, and Escape closes the open panel and returns focus to its toggle.
  void _toggle(CommunityPanel panel) {
    setState(() {
      _panel = _panel == panel ? CommunityPanel.none : panel;
    });
  }

  void _closePanel() {
    if (_panel == CommunityPanel.none) return;
    final restore = _panel == CommunityPanel.search
        ? _searchToggleFocus
        : _messageToggleFocus;
    setState(() => _panel = CommunityPanel.none);
    restore.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(communityHomeControllerProvider);
    if (!communityCapabilityBlocks(mode, capability) &&
        state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(communityHomeControllerProvider.notifier).load());
        }
      });
    }

    final home = state.value;
    final loading = state.phase == CommunityViewPhase.loading;
    final joined = home?.joined ?? const <JoinedCommunity>[];
    // The prototype's own heading: how many of the reader's communities are
    // bound to an asset, which is the whole of what 「在挖矿」 means here. The
    // aggregate carries the binding on every joined row, so this is a reading
    // and not a second request.
    final miningCount = joined
        .where((entry) => entry.community.hasBoundAsset)
        .length;
    final mining = <JoinedCommunity>[
      for (final entry in joined)
        if (entry.community.hasBoundAsset) entry,
    ];
    final others = <JoinedCommunity>[
      for (final entry in joined)
        if (!entry.community.hasBoundAsset) entry,
    ];
    // Ranking the reader's communities by discussion, counting live rooms and
    // totalling unread all need a Stream reading this page does not have: the
    // aggregate publishes both as unavailable facts and carries no unread per
    // joined community. So every clause is absent, and the folio says why
    // instead of printing a sentence with the numbers cut out of it.
    final activity = communityActivityCaption();
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _closePanel,
      },
      child: Focus(
        autofocus: false,
        // The two panels float over the page at `LoopZ.communityPanel`; they
        // never enter the scroll stream, so opening one does not reflow the
        // index below it.
        child: Stack(
          children: <Widget>[
            LoopDashboardPage(
              key: const ValueKey<String>('community-screen'),
              archetype: LoopPageArchetype.listing,
              title: '社区',
              kicker: communityPreviewKicker(mode),
              tabPage: true,
              actions: <Widget>[
                // The toggle keeps its own focus node so Escape can hand focus
                // back to the control that opened the panel.
                Focus(
                  focusNode: _searchToggleFocus,
                  child: CommunityToolButton(
                    key: const ValueKey<String>('community-search-toggle'),
                    icon: 'search',
                    label: _panel == CommunityPanel.search ? '关闭搜索' : '打开全局搜索',
                    toggled: _panel == CommunityPanel.search,
                    onPressed: () => _toggle(CommunityPanel.search),
                  ),
                ),
                Focus(
                  focusNode: _messageToggleFocus,
                  child: CommunityToolButton(
                    key: const ValueKey<String>('community-message-toggle'),
                    icon: 'bell',
                    label: _panel == CommunityPanel.messages
                        ? '关闭消息面板'
                        : '打开消息面板',
                    // `.community-unread-badge` has no source in this version:
                    // LOOP publishes no total unread count, so the badge slot
                    // stays empty rather than carrying a number nobody
                    // counted.
                    unreadCount: null,
                    toggled: _panel == CommunityPanel.messages,
                    onPressed: () => _toggle(CommunityPanel.messages),
                  ),
                ),
                CommunityToolButton(
                  key: const ValueKey<String>('community-profile-action'),
                  icon: 'user',
                  label: '查看个人中心',
                  onPressed: () => _open('/profile'),
                ),
              ],
              primary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // The discover hero sits above the index card, as in the
                  // frozen prototype.
                  if (home != null)
                    CommunityDiscoverHero(
                      key: const ValueKey<String>('community-discover-hero'),
                      // `discover` is a preview the server cut to a handful,
                      // so its length is not a count of verified communities
                      // and the kicker never prints it as one.
                      onTap: () => _open('/community/discover'),
                    ),
                  LoopFolioPrimary(
                    key: const ValueKey<String>('community-folio'),
                    variant: LoopFolioVariant.lime,
                    archetype: LoopFolioArchetype.listing,
                    kicker: 'COMMUNITY INDEX',
                    // A read that is still running is not a read that failed.
                    // The skeleton below was already saying 「正在读取」 while
                    // this hero said 「暂无数值 / 社区数据暂时读不到」 for the
                    // first seconds of every cold start.
                    heading: home == null
                        ? (loading ? '正在读取' : communityMissingHeading)
                        : '$miningCount 个社区在挖矿',
                    caption: home == null
                        ? loading
                              ? '已加入的社区数量读到之后显示在这里。'
                              : '社区数据暂时读不到，这一页不显示任何数字。'
                        : activity ?? '讨论热度与语音房活动还没有开放。',
                    // `.folio-stamp` is 「N LIVE」 in the prototype. Nothing
                    // here counts live rooms, so the corner stays empty; it
                    // is not a slot for the word DATABASE.
                  ),
                ],
              ),
              block: communityCapabilityBlocks(mode, capability)
                  ? CommunityCapabilityPageBlock(
                      key: const ValueKey<String>(
                        'community-capability-unavailable',
                      ),
                      capability: capability,
                      title: '社区模块当前不可用',
                      deferredMessage: '社区还没有开放。',
                      unknownMessage: '社区还没有准备好，请稍后再试。',
                    )
                  : null,
              onRefresh: () =>
                  ref.read(communityHomeControllerProvider.notifier).reload(),
              updating: state.refreshing,
              sections: <Widget>[
                CommunityPreviewNotice(mode: mode, resource: '社区数据'),
                if (state.phase != CommunityViewPhase.ready || home == null)
                  CommunityStateBlock(
                    phase: state.phase,
                    failureKind: state.failureKind,
                    emptyMessage: '还没有加入任何社区',
                    emptyReason: '加入社区后，这里会列出你的社区。',
                    onRetry: () => unawaited(
                      ref
                          .read(communityHomeControllerProvider.notifier)
                          .reload(),
                    ),
                  )
                else ...<Widget>[
                  if (joined.isEmpty) ...<Widget>[
                    const LoopLabel('已加入的社区'),
                    const LoopEmpty(
                      key: ValueKey<String>('community-joined-empty'),
                      message: '还没有加入任何社区',
                      reason: '从"发现社区"开始，加入后这里会显示你的社区。',
                    ),
                  ],
                  // Two groups, in the prototype's order: the communities that
                  // bound an asset — the ones a reader is here to mine — and
                  // then everything else.
                  if (mining.isNotEmpty) ...<Widget>[
                    // `<p class="label" style="padding-top:0">` — the first
                    // label on this page sits against the folio.
                    const LoopLabel('带币社区 · 可挖矿', tight: true),
                    LoopRecordGroup(
                      key: const ValueKey<String>('community-mining-group'),
                      rows: <LoopRecordRow>[
                        for (final entry in mining) _joinedRow(entry),
                      ],
                    ),
                  ],
                  if (others.isNotEmpty) ...<Widget>[
                    LoopLabel(
                      '其他社区',
                      followsLabel: mining.isNotEmpty,
                      tight: mining.isEmpty,
                    ),
                    LoopRecordGroup(
                      key: const ValueKey<String>('community-other-group'),
                      rows: <LoopRecordRow>[
                        for (final entry in others) _joinedRow(entry),
                      ],
                    ),
                  ],
                  if (home.joinedTruncated)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: LoopButton(
                        key: const ValueKey<String>(
                          'community-view-all-joined',
                        ),
                        label: '查看全部已加入的社区',
                        block: true,
                        onPressed: () =>
                            _open('/community/discover?membership=joined'),
                      ),
                    ),
                  LoopNotice(
                    key: const ValueKey<String>(
                      'community-recommendation-rule',
                    ),
                    icon: 'info',
                    title: '推荐依据',
                    body:
                        '推荐只按成员数与创建时间排列，'
                        '不是个性化算法推荐。',
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  ),
                  CommunityObservedFootnote(
                    key: const ValueKey<String>('community-observed-at'),
                    observedAt: home.observedAt,
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
            if (_panel != CommunityPanel.none)
              // Veils the page below the header only, so the header toggles
              // keep switching panels while a tap anywhere else closes them.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: MediaQuery.paddingOf(context).top + 72,
                child: GestureDetector(
                  key: const ValueKey<String>('community-panel-scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _closePanel,
                  child: const ExcludeSemantics(
                    child: ColoredBox(color: LoopColors.veil),
                  ),
                ),
              ),
            if (_panel != CommunityPanel.none)
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.paddingOf(context).top + 72,
                child: Material(
                  type: MaterialType.transparency,
                  child: _panel == CommunityPanel.search
                      ? _CommunitySearchPanel(
                          onSubmit: (query) {
                            _closePanel();
                            _open(
                              '/search?q=${Uri.encodeQueryComponent(query)}',
                            );
                          },
                          onClose: _closePanel,
                        )
                      : _CommunityMessagePanel(
                          home: home,
                          onClose: _closePanel,
                          onOpenChat: () {
                            _closePanel();
                            _open('/chat');
                          },
                          onOpenRequests: () {
                            _closePanel();
                            _open('/chat/requests');
                          },
                          onOpenMessageSearch: () {
                            _closePanel();
                            _open('/chat/search');
                          },
                          onOpenVoiceRoom: (communityId) {
                            _closePanel();
                            _open(
                              '/chat/voice?id='
                              '${Uri.encodeQueryComponent(communityId)}',
                            );
                          },
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// One joined community, in the prototype's own row.
  ///
  /// The second line is `48,120 成员 · <accent>`: the head count in mono, and
  /// then the one fact that decides whether this community mines. The
  /// community's approved weight lives behind a per-community mining read this
  /// page does not issue, so the accent carries the community's verification
  /// state when the operator has not verified it — and nothing at all when it
  /// is verified and the weight is simply not on this page.
  LoopRecordRow _joinedRow(JoinedCommunity entry) {
    final community = entry.community;
    final unverified =
        community.verificationStatus != CommunityVerification.verified
        ? communityVerificationLabel(community.verificationStatus)
        : null;
    // A muted or banned membership is the reader's own standing and outranks
    // everything else on the line; a plain 「成员」 told a reader nothing the
    // row did not already say.
    final standing = entry.membership.status == CommunityMemberStatus.active
        ? null
        : communityMembershipLabel(entry.membership);
    final accent = standing ?? unverified;
    final members = communityMemberCountLabel(community.memberCount);
    return LoopRecordRow(
      key: ValueKey<String>('community-joined-${community.communityId}'),
      leading: CommunityLogoAvatar(
        name: community.name,
        logoRef: community.logoRef,
      ),
      title: community.name,
      subtitle: accent == null ? members : '$members · $accent',
      subtitleSpans: <InlineSpan>[
        TextSpan(text: members, style: LoopMono.stamp),
        if (accent != null) ...<InlineSpan>[
          const TextSpan(text: ' · '),
          TextSpan(
            text: accent,
            style: LoopTypography.figure(
              13,
              weight: FontWeight.w700,
              color: LoopColors.lime,
            ),
          ),
        ],
      ],
      // `.badge.badge-up` on the right of the row. LOOP publishes no unread
      // count per community in this version, so no row carries one; a zero is
      // never drawn.
      onTap: () => _open('/community/profile?id=${community.communityId}'),
      semanticLabel:
          '${community.name}，$members'
          '${accent == null ? '' : '，$accent'}',
    );
  }
}

class _CommunitySearchPanel extends StatefulWidget {
  const _CommunitySearchPanel({required this.onSubmit, required this.onClose});

  final ValueChanged<String> onSubmit;
  final VoidCallback onClose;

  @override
  State<_CommunitySearchPanel> createState() => _CommunitySearchPanelState();
}

class _CommunitySearchPanelState extends State<_CommunitySearchPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoopSurfaceCard(
      background: LoopColors.elevated,
      borderColor: LoopColors.hairline,
      key: const ValueKey<String>('community-search-panel'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('community-search-field'),
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: widget.onSubmit,
            decoration: InputDecoration(
              labelText: searchFieldLabel,
              hintText: '输入至少 $searchMinimumRunes 个字符',
            ),
          ),
          const SizedBox(height: 12),
          const LoopNotice(
            key: ValueKey<String>('community-search-entry-note'),
            body: '全局资产与社区搜索从社区 Tab 顶部进入。这是唯一的全局搜索入口。',
            margin: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('community-search-submit'),
                label: '搜索',
                primary: true,
                onPressed: () => widget.onSubmit(_controller.text),
              ),
              LoopButton(
                key: const ValueKey<String>('community-search-close'),
                label: '关闭',
                onPressed: widget.onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunityMessagePanel extends ConsumerWidget {
  const _CommunityMessagePanel({
    required this.home,
    required this.onClose,
    required this.onOpenChat,
    required this.onOpenRequests,
    required this.onOpenMessageSearch,
    required this.onOpenVoiceRoom,
  });

  final CommunityHome? home;
  final VoidCallback onClose;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenMessageSearch;
  final ValueChanged<String> onOpenVoiceRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = home?.unread;
    final liveVoice = home?.liveVoice;
    // The room this account is in, as this client knows it. The panel does
    // not read a room of its own: what it has is the same membership the
    // strip above the router stands on.
    final session = ref.watch(voiceRoomSessionProvider);
    // Stranger requests are the one count this client can answer without a
    // new read. Outside the Development Preview the gateway is unconfigured,
    // the future fails without touching the network, and the row is absent.
    final requests = ref.watch(messageRequestsProvider);
    final requestCount = requests.asData?.value.length;
    final newCount = (session == null ? 0 : 1) + (requestCount ?? 0);
    return LoopSurfaceCard(
      key: const ValueKey<String>('community-message-panel'),
      // Floats over page content, so it needs an opaque surface: the page
      // card fill is translucent by design and would show the page through.
      background: LoopColors.elevated,
      borderColor: LoopColors.hairline,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CommunityMessagePanelHead(newCount: newCount),
          // A row exists only where a reading exists. Nothing on this panel
          // is a placeholder for a count LOOP does not publish.
          if (session != null)
            CommunityMessageRow(
              key: const ValueKey<String>('community-live-voice-row'),
              icon: 'voice',
              title: session.communityName,
              subtitle: '语音房正在进行',
              stamp: 'LIVE',
              onTap: () => onOpenVoiceRoom(session.communityId),
            ),
          if (requestCount != null && requestCount > 0)
            CommunityMessageRow(
              key: const ValueKey<String>('community-message-requests-row'),
              icon: 'mail',
              title: '陌生人请求',
              subtitle: '$requestCount 条请求待处理',
              onTap: onOpenRequests,
            ),
          CommunityMessageRow(
            key: const ValueKey<String>('community-open-chat'),
            icon: 'chat',
            title: '聊天',
            subtitle: '打开会话收件箱',
            onTap: onOpenChat,
          ),
          if (requestCount == null || requestCount == 0)
            CommunityMessageRow(
              key: const ValueKey<String>('community-open-requests'),
              icon: 'mail',
              title: '陌生人请求',
              subtitle: '接受、忽略或举报',
              onTap: onOpenRequests,
            ),
          // Two 「读不到」 cards stood here on one panel for two things that
          // had not failed: LOOP does not publish a total unread count in
          // this version, and a reader who is in no room is not a room that
          // could not be read. Each says what is actually the case; a code
          // that means something else still renders as the failure it is.
          if (unread != null) ...<Widget>[
            const SizedBox(height: 10),
            unread.reasonCode == 'STREAM_UNREAD_NOT_CONNECTED'
                ? const LoopEmpty(
                    key: ValueKey<String>('community-unread-deferred'),
                    message: '未读消息',
                    reason: '未读总数还没有开放。打开聊天可以看到每个会话的未读。',
                    margin: EdgeInsets.zero,
                  )
                : CommunityUnavailableCard(
                    key: const ValueKey<String>('community-unread-unavailable'),
                    label: '未读消息',
                    fact: unread,
                    margin: EdgeInsets.zero,
                  ),
          ],
          if (liveVoice != null &&
              liveVoice.reasonCode != 'STREAM_VOICE_NOT_CONNECTED') ...<Widget>[
            const SizedBox(height: 10),
            CommunityUnavailableCard(
              key: const ValueKey<String>('community-live-voice-unavailable'),
              label: '语音房',
              fact: liveVoice,
              margin: EdgeInsets.zero,
            ),
          ] else if (liveVoice != null && session == null) ...<Widget>[
            const SizedBox(height: 10),
            const LoopEmpty(
              key: ValueKey<String>('community-live-voice-state'),
              message: '你现在不在任何语音房里',
              reason:
                  '加入之后这里会显示你所在的房间。'
                  '某个社区有没有进行中的语音房，在它的社区页可以看到。',
              margin: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 12),
          CommunityMessageSearchButton(
            key: const ValueKey<String>('community-open-message-search'),
            onPressed: onOpenMessageSearch,
          ),
          const SizedBox(height: 10),
          LoopButton(
            key: const ValueKey<String>('community-message-close'),
            label: '关闭消息面板',
            block: true,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
