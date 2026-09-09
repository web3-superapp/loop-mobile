import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
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
    final joinedCount = home?.joined.length;
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
                  child: LoopIconButton(
                    key: const ValueKey<String>('community-search-toggle'),
                    icon: 'search',
                    label: _panel == CommunityPanel.search ? '关闭搜索' : '打开全局搜索',
                    onPressed: () => _toggle(CommunityPanel.search),
                  ),
                ),
                Focus(
                  focusNode: _messageToggleFocus,
                  child: LoopIconButton(
                    key: const ValueKey<String>('community-message-toggle'),
                    icon: 'bell',
                    label: _panel == CommunityPanel.messages
                        ? '关闭消息面板'
                        : '打开消息面板',
                    onPressed: () => _toggle(CommunityPanel.messages),
                  ),
                ),
                LoopIconButton(
                  key: const ValueKey<String>('community-profile-action'),
                  icon: 'user',
                  label: '查看个人中心',
                  onPressed: () => _open('/profile'),
                ),
              ],
              primary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // The discover hero sits above the index card, as in the frozen
                  // prototype, and only ever states a server-counted figure.
                  if (home != null)
                    _DiscoverHero(
                      discoverCount: home.discover.length,
                      onTap: () => _open('/community/discover'),
                    ),
                  LoopFolioPrimary(
                    key: const ValueKey<String>('community-folio'),
                    variant: LoopFolioVariant.lime,
                    archetype: LoopFolioArchetype.listing,
                    kicker: 'COMMUNITY INDEX',
                    heading: joinedCount == null
                        ? communityMissingFigure
                        : '$joinedCount 个已加入的社区',
                    caption: home == null
                        ? '社区聚合尚未读取成功，本页不展示任何推测数字。'
                        : '发现 ${home.discover.length} 个已验证社区 · '
                              '数据观察于 ${communityObservedAtLabel(home.observedAt)}',
                    stamp: home == null ? null : 'DATABASE',
                  ),
                ],
              ),
              sections: <Widget>[
                CommunityPreviewNotice(mode: mode, resource: '社区聚合'),
                if (communityCapabilityBlocks(mode, capability))
                  _CommunityCapabilityBlock(
                    reasonCode: capability.reasonCode,
                    decision: capability.decision,
                  )
                else if (state.phase != CommunityViewPhase.ready ||
                    home == null)
                  CommunityStateBlock(
                    phase: state.phase,
                    failureKind: state.failureKind,
                    emptyMessage: '还没有加入任何社区',
                    emptyReason: '加入社区后，这里会列出服务端确认的成员关系。',
                    onRetry: () => unawaited(
                      ref
                          .read(communityHomeControllerProvider.notifier)
                          .reload(),
                    ),
                  )
                else ...<Widget>[
                  const LoopLabel('已加入的社区'),
                  if (home.joined.isEmpty)
                    const LoopEmpty(
                      key: ValueKey<String>('community-joined-empty'),
                      message: '还没有加入任何社区',
                      reason: '从"发现社区"开始，加入后这里会显示服务端确认的成员关系。',
                    )
                  else
                    LoopRecordGroup(
                      rows: <LoopRecordRow>[
                        for (
                          var index = 0;
                          index < home.joined.length;
                          index += 1
                        )
                          _joinedRow(home.joined, index),
                      ],
                    ),
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
                        '推荐列表由版本化规则 ${home.recommendation.ruleVersion} 生成，'
                        '只使用成员数与创建时间等可核查事实，不是个性化算法推荐。',
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  ),
                ],
                const SizedBox(height: 20),
              ],
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
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  LoopRecordRow _joinedRow(List<JoinedCommunity> items, int index) {
    final entry = items[index];
    final community = entry.community;
    final status = switch (entry.membership.status) {
      CommunityMemberStatus.active => entry.membership.role.label,
      CommunityMemberStatus.muted => '已禁言',
      CommunityMemberStatus.banned => '已封禁',
    };
    return LoopRecordRow(
      key: ValueKey<String>('community-joined-${community.communityId}'),
      leading: CommunityLogoTile(name: community.name),
      title: community.name,
      subtitle: '${community.memberCount} 名成员 · $status',
      onTap: () => _open('/community/profile?id=${community.communityId}'),
      position: communityRowPosition(index, items.length),
      semanticLabel: '${community.name}，$status，${community.memberCount} 名成员',
    );
  }
}

class _CommunityCapabilityBlock extends StatelessWidget {
  const _CommunityCapabilityBlock({
    required this.reasonCode,
    required this.decision,
  });

  final String? reasonCode;
  final LoopCapabilityDecision decision;

  @override
  Widget build(BuildContext context) {
    return LoopEmpty(
      key: const ValueKey<String>('community-capability-unavailable'),
      icon: 'warn',
      message: '社区模块当前不可用',
      reason: switch (decision) {
        LoopCapabilityDecision.unknown => '尚未读取到能力清单，本页不请求社区数据，也不展示任何数字。',
        LoopCapabilityDecision.deferred => '服务端尚未启用 community 模块。',
        _ => reasonCode == null ? '服务端已声明该模块当前不可用。' : '服务端原因：$reasonCode。',
      },
    );
  }
}

class _DiscoverHero extends StatelessWidget {
  const _DiscoverHero({required this.discoverCount, required this.onTap});

  final int discoverCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LoopSurfaceCard(
      key: const ValueKey<String>('community-discover-hero'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      background: LoopColors.lime,
      borderColor: LoopColors.lime,
      onTap: onTap,
      semanticLabel: '发现新社区，当前有 $discoverCount 个推荐',
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'DISCOVER',
                  style: LoopTypography.mono(
                    size: 9.5,
                    weight: FontWeight.w600,
                    color: LoopColors.ink.withValues(alpha: 0.6),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '发现新社区',
                  style: LoopTypography.sora(
                    size: 19,
                    weight: FontWeight.w800,
                    color: LoopColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '按成员数或创建时间浏览已验证社区。$discoverCount 个推荐来自本次聚合。',
                  style: LoopTypography.sora(
                    size: 12,
                    weight: FontWeight.w500,
                    color: LoopColors.ink.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const LoopIcon('chevron', size: 18, color: LoopColors.ink),
        ],
      ),
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
            decoration: const InputDecoration(
              labelText: '搜索社区或用户',
              hintText: '输入至少 2 个字符',
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

class _CommunityMessagePanel extends StatelessWidget {
  const _CommunityMessagePanel({
    required this.home,
    required this.onClose,
    required this.onOpenChat,
    required this.onOpenRequests,
    required this.onOpenMessageSearch,
  });

  final CommunityHome? home;
  final VoidCallback onClose;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenMessageSearch;

  @override
  Widget build(BuildContext context) {
    final unread = home?.unread;
    final liveVoice = home?.liveVoice;
    return LoopSurfaceCard(
      key: const ValueKey<String>('community-message-panel'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'MESSAGE CENTER',
            style: LoopTypography.mono(
              size: 9.5,
              weight: FontWeight.w600,
              color: LoopColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          if (unread != null)
            CommunityUnavailableCard(
              key: const ValueKey<String>('community-unread-unavailable'),
              label: '未读消息',
              fact: unread,
              margin: EdgeInsets.zero,
            ),
          if (liveVoice != null) ...<Widget>[
            const SizedBox(height: 10),
            CommunityUnavailableCard(
              key: const ValueKey<String>('community-live-voice-unavailable'),
              label: '语音房',
              fact: liveVoice,
              margin: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 12),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('community-open-chat'),
                title: '聊天',
                subtitle: '打开会话收件箱',
                position: LoopRowPosition.first,
                onTap: onOpenChat,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('community-open-requests'),
                title: '陌生人请求',
                subtitle: '接受、忽略或举报',
                position: LoopRowPosition.middle,
                onTap: onOpenRequests,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('community-open-message-search'),
                title: '搜索消息',
                subtitle: '在已接通的会话里检索',
                position: LoopRowPosition.last,
                onTap: onOpenMessageSearch,
              ),
            ],
          ),
          const SizedBox(height: 12),
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
