import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (parseLoopStreamChannelCid(cid) == null) {
      return const _ChannelStateBlock(
        key: ValueKey<String>('loop-stream-channel-invalid'),
        message: '这个会话链接不是 LOOP 支持的频道地址，本页没有发起任何连接。',
        icon: 'warn',
      );
    }
    return ref
        .watch(streamChatAuthorizationProvider)
        .when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          loading: () => const _ChannelStateBlock(
            key: ValueKey<String>('loop-stream-channel-connecting'),
            message: '正在恢复服务端授权的聊天会话…',
            loading: true,
          ),
          error: (error, stackTrace) => _ChannelStateBlock(
            key: const ValueKey<String>('loop-stream-channel-error'),
            message: '聊天授权没有恢复成功，本页没有发起任何消息操作。',
            icon: 'warn',
            onRetry: () => ref.invalidate(streamChatAuthorizationProvider),
          ),
          data: (authorization) {
            final session = ref.watch(streamChatSdkSessionProvider);
            final currentUser = session?.client.state.currentUser;
            if (authorization != StreamSessionAuthorization.authorized ||
                session == null ||
                currentUser == null) {
              return _ChannelStateBlock(
                key: const ValueKey<String>(
                  'loop-stream-channel-not-connected',
                ),
                message: notConnectedMessage,
                icon: 'warn',
                onRetry: () => ref.invalidate(streamChatAuthorizationProvider),
              );
            }
            return _MemberChannelBody(
              key: ValueKey<String>(
                'loop-stream-channel-$cid-${currentUser.id}',
              ),
              client: session.client,
              cid: cid,
              userId: currentUser.id,
              composerHint: composerHint,
              header: header,
              banner: banner,
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
    super.key,
  });

  final StreamChatClient client;
  final String cid;
  final String userId;
  final String composerHint;
  final Widget? header;
  final Widget? banner;

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
          return const _ChannelStateBlock(
            key: ValueKey<String>('loop-stream-channel-confirming'),
            message: '正在确认这个频道以及你的成员身份…',
            loading: true,
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _ChannelStateBlock(
            key: const ValueKey<String>('loop-stream-channel-unavailable'),
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
  });

  final String message;
  final String icon;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: LoopSkeleton(type: LoopSkeletonType.list, rows: 4),
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

/// Lime Ledger colours for the official Stream widgets. Stream 10.3 derives
/// most of its palette from the ambient Material theme, so only the surfaces
/// it owns outright are restated here.
StreamChatThemeData loopStreamChatThemeData() => StreamChatThemeData(
  messageListViewTheme: const StreamMessageListViewThemeData(
    backgroundColor: LoopColors.ink,
    messageHighlightColor: LoopColors.limeSoft,
  ),
);
