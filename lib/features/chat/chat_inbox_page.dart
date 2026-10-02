import 'package:flutter/material.dart';
import 'package:loop_mobile/widgets/community_chat_segment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/preview_conversation_identity.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/friends/chat_create_menu_button.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

enum _InboxFilter { all, groups, direct }

/// Primary inbox. Preview conversations stay in memory; production uses Stream.
class ChatInboxPage extends ConsumerStatefulWidget {
  const ChatInboxPage({super.key});

  @override
  ConsumerState<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends ConsumerState<ChatInboxPage> {
  var _filter = _InboxFilter.all;

  @override
  Widget build(BuildContext context) {
    final gateway = ref.watch(communicationGatewayProvider);
    if (gateway.mode != CommunicationMode.preview) {
      return const StreamChatInboxPage();
    }
    final conversations = ref.watch(conversationListProvider);
    final requests = ref.watch(messageRequestsProvider);
    final requestCount = requests.hasValue ? requests.value!.length : null;
    final requestLabel = switch (requestCount) {
      null => '好友申请',
      0 => '暂无好友申请',
      1 => '1 条好友申请',
      final count => '$count 条好友申请',
    };
    return LoopDashboardPage(
      key: const ValueKey<String>('chat-preview-inbox'),
      archetype: LoopPageArchetype.listing,
      title: '聊天',
      titleWidget: const CommunityChatSegment(location: '/chat'),
      tabPage: true,
      actions: <Widget>[
        IconButton(
          key: const ValueKey<String>('chat-friends-action'),
          tooltip: '好友',
          onPressed: () => context.push('/profile/connections'),
          icon: const Icon(Icons.people_outline_rounded),
        ),
        const ChatCreateMenuButton(),
      ],
      sections:
          <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>('chat-requests-action'),
                        onPressed: () => context.push('/chat/requests'),
                        icon: requestCount != null && requestCount > 0
                            ? Badge(
                                key: const ValueKey<String>(
                                  'chat-preview-message-request-badge',
                                ),
                                label: Text('$requestCount'),
                                backgroundColor: LoopColors.chat,
                                textColor: LoopColors.abyss,
                                child: const Icon(
                                  Icons.person_add_alt_1_outlined,
                                  size: 18,
                                ),
                              )
                            : const Icon(
                                Icons.person_add_alt_1_outlined,
                                size: 18,
                              ),
                        label: Text(requestLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/chat/search'),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('搜索消息'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SegmentedButton<_InboxFilter>(
                  segments: const <ButtonSegment<_InboxFilter>>[
                    ButtonSegment(value: _InboxFilter.all, label: Text('全部')),
                    ButtonSegment(
                      value: _InboxFilter.groups,
                      label: Text('群聊'),
                    ),
                    ButtonSegment(
                      value: _InboxFilter.direct,
                      label: Text('私聊'),
                    ),
                  ],
                  selected: <_InboxFilter>{_filter},
                  showSelectedIcon: false,
                  onSelectionChanged: (values) =>
                      setState(() => _filter = values.first),
                ),
                const SizedBox(height: 10),
                conversations.when(
                  data: (items) {
                    final visible = items
                        .where(_matchesFilter)
                        .toList(growable: false);
                    if (visible.isEmpty) {
                      return const LoopStateCard(
                        title: '还没有会话',
                        message: '添加好友，或选择其他分类查看会话。',
                        icon: Icons.chat_bubble_outline_rounded,
                      );
                    }
                    return Column(
                      children: <Widget>[
                        for (final conversation in visible) ...<Widget>[
                          ConversationRow(
                            conversation: conversation,
                            showMetadata: false,
                            onTap: () =>
                                _openConversation(context, conversation),
                          ),
                          const Divider(height: 1),
                        ],
                      ],
                    );
                  },
                  loading: () => const _ConversationLoading(),
                  error: (error, stackTrace) => LoopStateCard(
                    title: '会话暂时无法加载',
                    message: '请稍后重试。',
                    icon: Icons.cloud_off_outlined,
                    action: TextButton(
                      onPressed: () => ref.invalidate(conversationListProvider),
                      child: const Text('重试'),
                    ),
                  ),
                ),
              ]
              .map(
                (section) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: section,
                ),
              )
              .toList(growable: false),
    );
  }

  bool _matchesFilter(ConversationSummary conversation) => switch (_filter) {
    _InboxFilter.all => conversation.kind != ConversationKind.meeting,
    _InboxFilter.groups =>
      conversation.kind == ConversationKind.group ||
          conversation.kind == ConversationKind.voice,
    _InboxFilter.direct => conversation.kind == ConversationKind.direct,
  };

  static void _openConversation(
    BuildContext context,
    ConversationSummary conversation,
  ) {
    final location = PreviewConversationIdentity.locationForSummary(
      conversationId: conversation.id,
      kind: conversation.kind,
    );
    if (location == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('会话暂时无法打开，请返回列表重试。')));
      return;
    }
    context.push(location);
  }
}

class _ConversationLoading extends StatelessWidget {
  const _ConversationLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: <Widget>[
              const _Skeleton(width: 44, height: 44, radius: 24),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    _Skeleton(width: 138, height: 13),
                    SizedBox(height: 9),
                    _Skeleton(width: double.infinity, height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width, required this.height, this.radius = 7});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: LoopColors.elevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
