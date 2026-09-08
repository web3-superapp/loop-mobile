import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The search scopes offered by `chat-search`.
///
/// Every scope is only a channel filter on top of Stream's own membership
/// enforcement: the server never returns a channel the account cannot read.
enum ChatSearchScope {
  currentConversation('当前会话'),
  all('全部'),
  community('社区'),
  group('群聊'),
  direct('私聊');

  const ChatSearchScope(this.label);

  final String label;
}

/// The sender label one result may carry.
///
/// `message.user.name` is an account-level Stream value, so a group or
/// community hit uses the same neutral label the group message list does. A
/// direct hit carries the conversation it opens, which is the identity the
/// page already owns.
String chatSearchSenderLabel(LoopChatSurface surface) => switch (surface) {
  LoopChatSurface.communityChat ||
  LoopChatSurface.group => loopGroupMemberNeutralLabel,
  LoopChatSurface.direct => '私聊',
};

/// One decoded search hit. Stream types stop at this boundary.
@immutable
final class ChatSearchHit {
  const ChatSearchHit({
    required this.messageId,
    required this.cid,
    required this.senderLabel,
    required this.channelLabel,
    required this.text,
    required this.createdAt,
  });

  final String messageId;
  final String cid;
  final String senderLabel;
  final String channelLabel;
  final String text;
  final DateTime createdAt;
}

/// `chat-search` · message search inside the channels the account can read.
///
/// It uses Stream's own `client.search`; chat content never enters LOOP's
/// `/v2/search` domain. The default scope is the conversation the user came
/// from, matching the prototype's "只搜索当前会话".
class ChatSearchScreen extends ConsumerStatefulWidget {
  const ChatSearchScreen({super.key, this.originCid, this.onBack, this.onOpen});

  /// The conversation the user opened search from, if any.
  final String? originCid;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpen;

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  static const int _limit = 20;
  static const int _minimumQueryLength = 2;

  late final TextEditingController _query = TextEditingController();
  late ChatSearchScope _scope = widget.originCid == null
      ? ChatSearchScope.all
      : ChatSearchScope.currentConversation;

  List<ChatSearchHit>? _hits;
  bool _searching = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<ChatSearchScope> get _scopes => <ChatSearchScope>[
    if (widget.originCid != null) ChatSearchScope.currentConversation,
    ChatSearchScope.all,
    ChatSearchScope.community,
    ChatSearchScope.group,
    ChatSearchScope.direct,
  ];

  Filter? _channelFilter(String userId) {
    final origin = widget.originCid;
    final membership = Filter.in_('members', <Object>[userId]);
    return switch (_scope) {
      ChatSearchScope.currentConversation when origin != null => Filter.and(
        <Filter>[membership, Filter.equal('cid', origin)],
      ),
      ChatSearchScope.currentConversation => null,
      ChatSearchScope.all => membership,
      // The LOOP backend assigns each channel ID prefix, so the scope is a
      // server-owned fact rather than a guess about the conversation.
      ChatSearchScope.community => Filter.and(<Filter>[
        membership,
        Filter.autoComplete('id', 'loop_community_'),
      ]),
      ChatSearchScope.group => Filter.and(<Filter>[
        membership,
        Filter.autoComplete('id', 'loop_group_'),
      ]),
      ChatSearchScope.direct => Filter.and(<Filter>[
        membership,
        Filter.autoComplete('id', 'loop_direct_'),
      ]),
    };
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    final session = ref.read(streamChatSdkSessionProvider);
    final userId = session?.client.state.currentUser?.id;
    if (text.length < _minimumQueryLength ||
        session == null ||
        userId == null) {
      setState(() {
        _hits = null;
        _failed = false;
        _searching = false;
      });
      return;
    }
    final filter = _channelFilter(userId);
    if (filter == null) {
      setState(() {
        _hits = const <ChatSearchHit>[];
        _failed = false;
        _searching = false;
      });
      return;
    }
    final generation = ++_generation;
    setState(() {
      _searching = true;
      _failed = false;
    });
    try {
      final response = await session.client.search(
        filter,
        query: text,
        paginationParams: const PaginationParams(limit: _limit),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _hits = <ChatSearchHit>[
          for (final result in response.results)
            if (_hit(result) case final ChatSearchHit hit) hit,
        ];
        _searching = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _failed = true;
      });
    }
  }

  ChatSearchHit? _hit(GetMessageResponse result) {
    final message = result.message;
    final cid = result.channel?.cid;
    final text = message.text;
    if (cid == null || text == null || text.isEmpty || message.isDeleted) {
      return null;
    }
    final surface = loopChatSurfaceForCid(cid);
    if (surface == null) return null;
    return ChatSearchHit(
      messageId: message.id,
      cid: cid,
      // `message.user.name` is an account-level Stream value. A community or
      // group hit therefore carries the neutral member label, exactly as the
      // group message list does; a direct hit carries the conversation's own
      // identity, which is the page the result opens.
      senderLabel: chatSearchSenderLabel(surface),
      channelLabel: switch (surface) {
        LoopChatSurface.communityChat => '社区官方群',
        LoopChatSurface.group => '群聊',
        LoopChatSurface.direct => '私聊',
      },
      text: text,
      createdAt: message.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authorization = ref.watch(streamChatAuthorizationProvider);
    final connected =
        authorization.value == StreamSessionAuthorization.authorized &&
        ref.watch(streamChatSdkSessionProvider)?.client.state.currentUser !=
            null;
    final hits = _hits;

    return LoopStreamPage(
      key: const ValueKey<String>('chat-search-screen'),
      archetype: LoopPageArchetype.listing,
      title: '搜消息',
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.listing,
        kicker: 'MESSAGE SEARCH',
        heading: hits == null ? '搜索会话内容' : '${hits.length} 条结果',
        caption: '只在你有权访问的会话里检索；全局资产与社区搜索仍从社区首页进入。',
      ),
      filters: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('chat-search-input'),
              controller: _query,
              enabled: connected,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => unawaited(_search()),
              style: LoopTypography.sora(size: 11, weight: FontWeight.w400),
              decoration: InputDecoration(
                hintText: '搜消息',
                isDense: true,
                filled: true,
                fillColor: LoopColors.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: LoopColors.line),
                ),
              ),
            ),
            const SizedBox(height: 10),
            LoopSegBar(
              key: const ValueKey<String>('chat-search-scopes'),
              labels: <String>[for (final scope in _scopes) scope.label],
              selectedIndex: _scopes.indexOf(_scope),
              onSelected: (index) {
                if (!connected) return;
                setState(() => _scope = _scopes[index]);
                unawaited(_search());
              },
            ),
          ],
        ),
      ),
      collection: _collection(connected: connected, hits: hits),
    );
  }

  Widget _collection({
    required bool connected,
    required List<ChatSearchHit>? hits,
  }) {
    if (!connected) {
      return const SingleChildScrollView(
        child: LoopEmpty(
          key: ValueKey<String>('chat-search-not-connected'),
          icon: 'warn',
          message: '聊天搜索当前不可用',
          reason: '需要服务端派发的 Stream 身份与短期 token 才能检索会话内容，本页没有发起任何请求。',
        ),
      );
    }
    if (_searching) {
      return const SingleChildScrollView(
        child: LoopSkeleton(
          key: ValueKey<String>('chat-search-loading'),
          type: LoopSkeletonType.list,
          rows: 4,
        ),
      );
    }
    if (_failed) {
      return SingleChildScrollView(
        child: LoopErrorState(
          key: const ValueKey<String>('chat-search-error'),
          reason: '这次检索没有完成，本页没有展示任何结果。',
          onRetry: () => unawaited(_search()),
        ),
      );
    }
    if (hits == null) {
      return const SingleChildScrollView(
        child: LoopEmpty(
          key: ValueKey<String>('chat-search-idle'),
          icon: 'search',
          message: '输入关键词开始搜索',
          reason: '至少输入 2 个字符。结果只来自你已加入的会话。',
        ),
      );
    }
    if (hits.isEmpty) {
      return const SingleChildScrollView(
        child: LoopEmpty(
          key: ValueKey<String>('chat-search-empty'),
          message: '没有匹配的消息',
          reason: '换一个关键词，或切换到更大的范围再试。',
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey<String>('chat-search-results'),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: hits.length,
      itemBuilder: (context, index) {
        final hit = hits[index];
        return LoopRecordRow(
          key: ValueKey<String>('chat-search-hit-${hit.messageId}'),
          title: hit.senderLabel == hit.channelLabel
              ? hit.channelLabel
              : '${hit.senderLabel} · ${hit.channelLabel}',
          subtitle: hit.text,
          trailingCaption: communityObservedAtLabel(hit.createdAt),
          position: index == 0
              ? LoopRowPosition.first
              : index == hits.length - 1
              ? LoopRowPosition.last
              : LoopRowPosition.middle,
          onTap: () => widget.onOpen?.call(hit.cid),
        );
      },
    );
  }
}
