import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_failure.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The Lime Ledger surface for one official Stream channel.
///
/// LOOP owns only the locator, the chrome and the copy. Message history,
/// pagination, delivery state, read state, threads, reactions and the composer
/// stay with the official Stream widgets, so no LOOP DTO ever mirrors a
/// provider fact. Attachments and voice recording are disabled application
/// wide; this surface only restates the composer placeholder.
class LoopStreamChannelSurface extends ConsumerWidget {
  const LoopStreamChannelSurface({
    required this.cid,
    required this.composerHint,
    super.key,
    this.header,
    this.banner,
    this.notConnectedMessage = '需要服务端派发的 Stream 身份与短期 token 才能打开这个会话。',
    this.keyPrefix = 'loop-stream-channel',
  });

  /// `messaging:<id>`. It is always server-supplied; the page never assembles
  /// one from display copy.
  final String cid;

  /// The composer placeholder. It says only what the composer can do.
  final String composerHint;

  /// Rendered above the message list, inside the Stream surface.
  final Widget? header;

  /// Rendered between the header and the message list (pinned notice area).
  final Widget? banner;
  final String notConnectedMessage;

  /// The key prefix for this surface's state blocks. A page passes its own
  /// slug so an acceptance assertion names that page rather than the shared
  /// surface that happened to render.
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (parseLoopStreamChannelCid(cid) == null) {
      return _ChannelStateBlock(
        key: ValueKey<String>('$keyPrefix-invalid'),
        message: '这个会话链接不是 LOOP 支持的频道地址，本页没有发起任何连接。',
        icon: 'warn',
      );
    }
    return ref
        .watch(streamChatAuthorizationProvider)
        .when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          loading: () => _ChannelStateBlock(
            key: ValueKey<String>('$keyPrefix-connecting'),
            message: '正在恢复服务端授权的聊天会话…',
            loading: true,
          ),
          // A token call that never reached the server has not refused
          // anything: the conversation is paused, not broken. Only a server
          // answer may render as an error.
          error: (error, stackTrace) => loopStreamFailureIsOffline(error)
              ? _ChannelStateBlock(
                  key: ValueKey<String>('$keyPrefix-offline'),
                  offlinePausedActions: const <String>[
                    '打开会话',
                    '发消息',
                    '搜索',
                    '转发',
                  ],
                  message: '设备当前离线，没有恢复聊天授权，也没有发送任何消息。',
                  onRetry: () =>
                      ref.invalidate(streamChatAuthorizationProvider),
                )
              : _ChannelStateBlock(
                  key: ValueKey<String>('$keyPrefix-error'),
                  message: '聊天授权没有恢复成功，本页没有发起任何消息操作。',
                  icon: 'warn',
                  onRetry: () =>
                      ref.invalidate(streamChatAuthorizationProvider),
                ),
          data: (authorization) {
            final session = ref.watch(streamChatSdkSessionProvider);
            final currentUser = session?.client.state.currentUser;
            if (authorization != StreamSessionAuthorization.authorized ||
                session == null ||
                currentUser == null) {
              return _ChannelStateBlock(
                key: ValueKey<String>('$keyPrefix-not-connected'),
                message: notConnectedMessage,
                icon: 'warn',
                onRetry: () => ref.invalidate(streamChatAuthorizationProvider),
              );
            }
            return _MemberChannelBody(
              key: ValueKey<String>('$keyPrefix-$cid-${currentUser.id}'),
              client: session.client,
              cid: cid,
              userId: currentUser.id,
              composerHint: composerHint,
              header: header,
              banner: banner,
              keyPrefix: keyPrefix,
            );
          },
        );
  }
}

/// Server-side membership proof before any official channel UI mounts.
///
/// A channel-list query cannot create a missing channel, unlike
/// `client.channel(...).watch()`. A CID the account is not a member of simply
/// resolves to nothing.
class _MemberChannelBody extends StatefulWidget {
  const _MemberChannelBody({
    required this.client,
    required this.cid,
    required this.userId,
    required this.composerHint,
    required this.header,
    required this.banner,
    required this.keyPrefix,
    super.key,
  });

  final StreamChatClient client;
  final String cid;
  final String userId;
  final String composerHint;
  final Widget? header;
  final Widget? banner;
  final String keyPrefix;

  @override
  State<_MemberChannelBody> createState() => _MemberChannelBodyState();
}

class _MemberChannelBodyState extends State<_MemberChannelBody> {
  late Future<Channel?> _channel;

  @override
  void initState() {
    super.initState();
    _channel = _load();
  }

  @override
  void didUpdateWidget(covariant _MemberChannelBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client) ||
        oldWidget.cid != widget.cid ||
        oldWidget.userId != widget.userId) {
      _channel = _load();
    }
  }

  Future<Channel?> _load() async {
    final channels = await widget.client.queryChannelsOnline(
      filter: Filter.and(<Filter>[
        Filter.equal('cid', widget.cid),
        Filter.equal('type', 'messaging'),
        Filter.in_('members', <Object>[widget.userId]),
      ]),
      state: true,
      watch: true,
      presence: true,
      memberLimit: 30,
      messageLimit: 25,
      paginationParams: const PaginationParams(limit: 1),
    );
    if (channels.length != 1) return null;
    final channel = channels.single;
    if (channel.cid != widget.cid ||
        channel.state == null ||
        channel.membership?.userId != widget.userId) {
      return null;
    }
    return channel;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Channel?>(
      future: _channel,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _ChannelStateBlock(
            key: ValueKey<String>('${widget.keyPrefix}-confirming'),
            message: '正在确认这个频道以及你的成员身份…',
            loading: true,
          );
        }
        // The membership query is the same read: a query that never reached
        // Stream did not disprove membership, so it pauses rather than
        // claiming the account is not a member.
        if (loopStreamFailureIsOffline(snapshot.error)) {
          return _ChannelStateBlock(
            key: ValueKey<String>('${widget.keyPrefix}-offline'),
            offlinePausedActions: const <String>['打开会话', '发消息', '搜索', '转发'],
            message: '设备当前离线，没有确认这个频道的成员身份，也没有发送任何消息。',
            onRetry: () => setState(() => _channel = _load()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _ChannelStateBlock(
            key: ValueKey<String>('${widget.keyPrefix}-unavailable'),
            message: '服务端没有确认你在这个频道的成员身份，LOOP 没有创建也没有打开任何频道。',
            icon: 'warn',
            onRetry: () => setState(() => _channel = _load()),
          );
        }
        return StreamChannel(
          key: ValueKey<String>(widget.cid),
          channel: snapshot.data!,
          child: _LoopChannelBody(
            composerHint: widget.composerHint,
            header: widget.header,
            banner: widget.banner,
          ),
        );
      },
    );
  }
}

class _LoopChannelBody extends StatefulWidget {
  const _LoopChannelBody({
    required this.composerHint,
    required this.header,
    required this.banner,
  });

  final String composerHint;
  final Widget? header;
  final Widget? banner;

  @override
  State<_LoopChannelBody> createState() => _LoopChannelBodyState();
}

class _LoopChannelBodyState extends State<_LoopChannelBody> {
  late final FocusNode _focusNode = FocusNode();
  late final StreamMessageComposerController _composerController =
      StreamMessageComposerController();

  @override
  void dispose() {
    _focusNode.dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _reply(Message message) {
    _composerController.quotedMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _edit(Message message) {
    _composerController.editMessage(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.header != null) widget.header!,
        if (widget.banner != null) widget.banner!,
        Expanded(
          child: StreamMessageListView(
            key: const ValueKey<String>('loop-stream-message-list'),
            builders: loopStreamMessageListViewBuilders(),
            onEditMessageTap: _edit,
            onReplyTap: _reply,
            enableSafeArea: false,
          ),
        ),
        StreamMessageComposer(
          key: const ValueKey<String>('loop-stream-message-composer'),
          focusNode: _focusNode,
          messageComposerController: _composerController,
          onQuotedMessageCleared: _composerController.clearQuotedMessage,
          // Attachments and voice recording stay off: LOOP claims no upload,
          // permission or recording capability in this step.
          disableAttachments: true,
          enableVoiceRecording: false,
          placeholderBuilder: (context, placeholder) => widget.composerHint,
        ),
      ],
    );
  }
}

class _ChannelStateBlock extends StatelessWidget {
  const _ChannelStateBlock({
    required this.message,
    super.key,
    this.icon = 'info',
    this.loading = false,
    this.onRetry,
    this.offlinePausedActions,
  });

  final String message;
  final String icon;
  final bool loading;
  final VoidCallback? onRetry;

  /// Non-null makes this the offline block: the surface names the actions it
  /// stopped instead of reporting a failure that never happened.
  final List<String>? offlinePausedActions;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: LoopSkeleton(type: LoopSkeletonType.list, rows: 4),
      );
    }
    final paused = offlinePausedActions;
    if (paused != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LoopOfflineState(pausedActions: paused, onRetry: onRetry),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: onRetry == null
          ? LoopEmpty(icon: icon, message: '会话不可用', reason: message)
          : LoopErrorState(reason: message, onRetry: onRetry),
    );
  }
}

/// The pinned-notice strip above a channel. It renders an explanation, never
/// an invented announcement.
class LoopChannelPinnedNotice extends StatelessWidget {
  const LoopChannelPinnedNotice({required this.reason, super.key});

  final String reason;

  @override
  Widget build(BuildContext context) => LoopNotice(
    key: const ValueKey<String>('loop-channel-pinned-unavailable'),
    icon: 'pin',
    title: '置顶公告',
    body: reason,
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
  );
}
