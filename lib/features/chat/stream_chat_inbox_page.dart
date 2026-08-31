import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/friends/chat_create_menu_button.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_screen.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Creates LOOP's official, bounded Stream channel-list controller.
///
/// Stream owns channel ordering, pagination, unread state, presence, and local
/// persistence. LOOP deliberately does not mirror these records into its
/// preview conversation DTOs.
@visibleForTesting
StreamChannelListController createLoopStreamChannelListController({
  required StreamChatClient client,
  required String userId,
}) {
  if (userId.isEmpty || userId != userId.trim()) {
    throw ArgumentError.value(userId, 'userId', 'must be non-empty');
  }
  return StreamChannelListController(
    client: client,
    filter: Filter.and(<Filter>[
      Filter.equal('type', 'messaging'),
      Filter.in_('members', <Object>[userId]),
    ]),
    channelStateSort: const <SortOption<ChannelState>>[
      SortOption<ChannelState>.desc(ChannelSortKey.lastUpdated),
    ],
    presence: true,
    limit: 20,
    messageLimit: 25,
    memberLimit: 30,
  );
}

/// Exact server-side lookup used before a string-addressed channel route mounts
/// official Stream UI. Unlike `client.channel(...).watch()`, a channel-list
/// query cannot create a missing channel.
@visibleForTesting
Filter createLoopStreamChannelMembershipFilter({
  required String cid,
  required String userId,
}) => Filter.and(<Filter>[
  Filter.equal('cid', cid),
  Filter.equal('type', 'messaging'),
  Filter.in_('members', <Object>[userId]),
]);

Future<Channel?> _loadExistingMemberChannel({
  required StreamChatClient client,
  required String cid,
  required String userId,
}) async {
  final channels = await client.queryChannelsOnline(
    filter: createLoopStreamChannelMembershipFilter(cid: cid, userId: userId),
    state: true,
    watch: true,
    presence: true,
    memberLimit: 30,
    messageLimit: 25,
    paginationParams: const PaginationParams(limit: 1),
  );
  if (channels.length != 1) return null;
  final channel = channels.single;
  final channelState = channel.state;
  if (channel.cid != cid ||
      channelState == null ||
      channel.membership?.userId != userId) {
    return null;
  }
  return channel;
}

/// Production Chat entry point backed directly by official Stream UI/state.
class StreamChatInboxPage extends ConsumerWidget {
  const StreamChatInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorization = ref.watch(streamChatAuthorizationProvider);
    final content = authorization.when(
      // Never keep an old authorized UI mounted while logout, account switch,
      // or an explicit retry is revalidating the principal.
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: false,
      loading: () => const _StreamStatusCard(
        key: ValueKey<String>('stream-chat-connecting'),
        title: 'Connecting to Stream',
        message: 'LOOP is restoring the server-authorized chat session.',
        icon: Icons.sync_rounded,
      ),
      error: (error, stackTrace) => _StreamUnavailableCard(
        message: 'Stream authorization could not be restored. No message operation was attempted.',
        onRetry: () => ref.invalidate(streamChatAuthorizationProvider),
      ),
      data: (authorization) {
        final session = ref.watch(streamChatSdkSessionProvider);
        final currentUser = session?.client.state.currentUser;
        if (authorization != StreamSessionAuthorization.authorized ||
            session == null ||
            currentUser == null) {
          return _StreamUnavailableCard(
            message: 'The LOOP backend must return a server-derived Stream user ID and short-lived token before chat can connect.',
            onRetry: () => ref.invalidate(streamChatAuthorizationProvider),
          );
        }
        return _StreamChannelListBody(
          key: ValueKey<String>('stream-chat-list-${currentUser.id}'),
          client: session.client,
          userId: currentUser.id,
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              key: const ValueKey<String>('stream-audio-room-entry'),
              onPressed: () => unawaited(context.push<void>('/chat/voice')),
              icon: const Icon(Icons.graphic_eq_rounded),
              label: const Text('Audio Room'),
              style: TextButton.styleFrom(foregroundColor: LoopColors.chat),
            ),
          ),
          const ChatCreateMenuButton(),
        ],
      ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: LoopBackdrop()),
          SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'DISCUSS',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: LoopColors.mint,
                              letterSpacing: 1.4,
                            ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Chats',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Official Stream conversations, delivery state, and history.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// String-addressed route into the official Stream channel UI.
///
/// Global routing carries only a CID. Stream SDK types remain inside Chat.
class StreamChatChannelRoutePage extends ConsumerWidget {
  const StreamChatChannelRoutePage({required this.cid, super.key});

  final String cid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = parseLoopStreamChannelCid(cid);
    if (address == null) {
      return const _StreamChannelUnavailablePage(
        title: 'Invalid chat link',
        message: 'This link does not identify a supported LOOP conversation.',
      );
    }

    return ref
        .watch(streamChatAuthorizationProvider)
        .when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          loading: () => const _StreamChannelUnavailablePage(
            title: 'Restoring chat',
            message: 'LOOP is restoring the server-authorized Stream session.',
            loading: true,
          ),
          error: (error, stackTrace) => const _StreamChannelUnavailablePage(
            title: 'Chat unavailable',
            message: 'Stream authorization could not be restored.',
          ),
          data: (authorization) {
            final session = ref.watch(streamChatSdkSessionProvider);
            if (authorization != StreamSessionAuthorization.authorized ||
                session?.client.state.currentUser == null) {
              return const _StreamChannelUnavailablePage(
                title: 'Stream not connected',
                message: 'A server-derived Stream identity and short-lived token are required before opening this conversation.',
              );
            }
            return _ExistingMemberStreamChannelPage(
              key: ValueKey<String>('stream-chat-member-route-$cid'),
              client: session!.client,
              cid: address.cid,
              userId: session.client.state.currentUser!.id,
            );
          },
        );
  }
}

/// Stream-owned gate for the public group-Alias channel route.
///
/// A deep link carries only an untrusted CID. The LOOP group resolver is not
/// mounted until the current server-authorized Stream identity can query one
/// exact existing channel membership. Account/session rotation rebuilds this
/// gate with the new client and user ID, so an old proof cannot authorize a
/// new principal.
class StreamGroupAliasChannelRoutePage extends ConsumerWidget {
  const StreamGroupAliasChannelRoutePage({required this.cid, super.key});

  final String cid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      GroupAliasStreamChannelId.fromCid(cid);
    } on InvalidGroupAliasContractException {
      return const _StreamChannelUnavailablePage(
        title: 'Invalid group link',
        message: 'This link does not identify a supported LOOP group.',
      );
    }

    return ref
        .watch(streamChatAuthorizationProvider)
        .when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          loading: () => const _StreamChannelUnavailablePage(
            title: 'Restoring chat',
            message: 'LOOP is restoring the server-authorized Stream session.',
            loading: true,
          ),
          error: (error, stackTrace) => const _StreamChannelUnavailablePage(
            title: 'Group identity unavailable',
            message: 'Stream authorization could not be restored.',
          ),
          data: (authorization) {
            final session = ref.watch(streamChatSdkSessionProvider);
            final currentUser = session?.client.state.currentUser;
            if (authorization != StreamSessionAuthorization.authorized ||
                session == null ||
                currentUser == null) {
              return const _StreamChannelUnavailablePage(
                title: 'Stream not connected',
                message: 'Current Stream membership must be confirmed before resolving a LOOP group.',
              );
            }
            return _ExistingMemberGroupAliasPage(
              key: ValueKey<String>(
                'stream-group-alias-member-route-$cid-${currentUser.id}',
              ),
              client: session.client,
              cid: cid,
              userId: currentUser.id,
            );
          },
        );
  }
}

class _ExistingMemberGroupAliasPage extends StatefulWidget {
  const _ExistingMemberGroupAliasPage({
    required this.client,
    required this.cid,
    required this.userId,
    super.key,
  });

  final StreamChatClient client;
  final String cid;
  final String userId;

  @override
  State<_ExistingMemberGroupAliasPage> createState() =>
      _ExistingMemberGroupAliasPageState();
}

class _ExistingMemberGroupAliasPageState
    extends State<_ExistingMemberGroupAliasPage> {
  late Future<Channel?> _channel;

  @override
  void initState() {
    super.initState();
    _channel = _load();
  }

  @override
  void didUpdateWidget(covariant _ExistingMemberGroupAliasPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client) ||
        oldWidget.cid != widget.cid ||
        oldWidget.userId != widget.userId) {
      _channel = _load();
    }
  }

  Future<Channel?> _load() => _loadExistingMemberChannel(
    client: widget.client,
    cid: widget.cid,
    userId: widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Channel?>(
      future: _channel,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StreamChannelUnavailablePage(
            title: 'Confirming group',
            message: 'LOOP is confirming this exact Stream channel membership.',
            loading: true,
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const _StreamChannelUnavailablePage(
            title: 'Group unavailable',
            message: 'No existing Stream group membership was confirmed. LOOP did not resolve a group.',
          );
        }
        return GroupAliasChannelRoutePage(routeCid: widget.cid);
      },
    );
  }
}

class _ExistingMemberStreamChannelPage extends StatefulWidget {
  const _ExistingMemberStreamChannelPage({
    required this.client,
    required this.cid,
    required this.userId,
    super.key,
  });

  final StreamChatClient client;
  final String cid;
  final String userId;

  @override
  State<_ExistingMemberStreamChannelPage> createState() =>
      _ExistingMemberStreamChannelPageState();
}

class _ExistingMemberStreamChannelPageState
    extends State<_ExistingMemberStreamChannelPage> {
  late Future<Channel?> _channel;

  @override
  void initState() {
    super.initState();
    _channel = _load();
  }

  @override
  void didUpdateWidget(covariant _ExistingMemberStreamChannelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client) ||
        oldWidget.cid != widget.cid ||
        oldWidget.userId != widget.userId) {
      _channel = _load();
    }
  }

  Future<Channel?> _load() => _loadExistingMemberChannel(
    client: widget.client,
    cid: widget.cid,
    userId: widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Channel?>(
      future: _channel,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StreamChannelUnavailablePage(
            title: 'Opening chat',
            message: 'LOOP is confirming this channel and your membership.',
            loading: true,
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const _StreamChannelUnavailablePage(
            title: 'Conversation unavailable',
            message: 'No existing Stream channel membership was confirmed. LOOP did not create or open a channel.',
          );
        }
        GroupAliasStreamChannelId? groupAliasChannelId;
        try {
          groupAliasChannelId = GroupAliasStreamChannelId.fromCid(widget.cid);
        } on InvalidGroupAliasContractException {
          // Known direct channels and invalid IDs intentionally have no group
          // Alias action. Stream message UI remains available.
        }
        final usesGroupIdentity = loopStreamChannelUsesGroupMessageAlias(
          widget.cid,
        );
        return StreamChannel(
          key: ValueKey<String>(widget.cid),
          channel: snapshot.data!,
          child: usesGroupIdentity
              ? LoopStreamGroupChannelPage(
                  onChannelAvatarPressed: groupAliasChannelId == null
                      ? null
                      : (context, channel) => unawaited(
                          context.push<void>(
                            '/chat/channel/${Uri.encodeComponent(widget.cid)}/alias',
                          ),
                        ),
                )
              : const StreamChannelPage(),
        );
      },
    );
  }
}

class _StreamChannelListBody extends StatefulWidget {
  const _StreamChannelListBody({
    required this.client,
    required this.userId,
    super.key,
  });

  final StreamChatClient client;
  final String userId;

  @override
  State<_StreamChannelListBody> createState() => _StreamChannelListBodyState();
}

class _StreamChannelListBodyState extends State<_StreamChannelListBody> {
  late final StreamChannelListController _controller =
      createLoopStreamChannelListController(
        client: widget.client,
        userId: widget.userId,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const ValueKey<String>('stream-chat-channel-list'),
      borderRadius: LoopRadius.medium,
      child: ColoredBox(
        color: LoopColors.basalt,
        child: StreamChannelListView(
          controller: _controller,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, channels, index, defaultItem) =>
              loopStreamChannelListIdentityItem(defaultItem),
          emptyBuilder: (context) => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LoopStateCard(
                title: 'No conversations yet',
                message:
                    'Channels created for this LOOP account will appear here.',
                icon: Icons.chat_bubble_outline_rounded,
              ),
            ),
          ),
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LoopStateCard(
                title: 'Chats are unavailable',
                message: 'Stream could not load the channel page. Existing local history was not deleted.',
                icon: Icons.cloud_off_outlined,
                tone: LoopTone.warning,
                action: OutlinedButton.icon(
                  onPressed: () => _controller.refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ),
            ),
          ),
          onChannelTap: (channel) => _openChannel(context, channel),
        ),
      ),
    );
  }

  static void _openChannel(BuildContext context, Channel channel) {
    final cid = channel.cid;
    if (cid == null || parseLoopStreamChannelCid(cid) == null) return;
    unawaited(context.push<void>('/chat/channel/${Uri.encodeComponent(cid)}'));
  }
}

class _StreamChannelUnavailablePage extends StatelessWidget {
  const _StreamChannelUnavailablePage({
    required this.title,
    required this.message,
    this.loading = false,
  });

  final String title;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: 'Discuss',
      title: 'Chat',
      children: <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('stream-chat-channel-unavailable'),
          title: title,
          message: message,
          icon: loading ? Icons.sync_rounded : Icons.cloud_off_outlined,
          tone: LoopTone.neutral,
        ),
      ],
    );
  }
}

class _StreamUnavailableCard extends StatelessWidget {
  const _StreamUnavailableCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: LoopStateCard(
        key: const ValueKey<String>('stream-chat-unavailable'),
        title: 'Stream not connected',
        message: message,
        icon: Icons.cloud_off_outlined,
        tone: LoopTone.neutral,
        action: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ),
    );
  }
}

class _StreamStatusCard extends StatelessWidget {
  const _StreamStatusCard({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: LoopStateCard(title: title, message: message, icon: icon),
    );
  }
}
