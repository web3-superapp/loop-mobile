import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/cache/loop_read_retention.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/friends/chat_create_menu_button.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_screen.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/social_controllers.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
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

/// The 聊天 tab's three filters (decision 0110, S106 §2). 好友 is every
/// conversation that is not a community's official channel: direct messages
/// and small groups.
enum ChatInboxFilter {
  all('全部'),
  communities('社区'),
  friends('好友');

  const ChatInboxFilter(this.label);

  final String label;

  /// Whether one channel row belongs under this filter. The surface is read
  /// from the server-assigned CID prefix, never from a display name; a CID
  /// LOOP cannot classify appears only under 全部.
  bool includes(String? cid) {
    if (this == ChatInboxFilter.all) return true;
    final surface = cid == null ? null : loopChatSurfaceForCid(cid);
    return switch (this) {
      ChatInboxFilter.all => true,
      ChatInboxFilter.communities => surface == LoopChatSurface.communityChat,
      ChatInboxFilter.friends =>
        surface == LoopChatSurface.direct || surface == LoopChatSurface.group,
    };
  }
}

/// `chat` · 聊天, the first tab (decision 0110, S106 §2).
///
/// One list of every conversation this account is in — community channels,
/// direct messages and small groups — ordered by Stream by the latest
/// message, with a filter strip over it. The owner's own avatar opens 我,
/// and 「＋」 holds every way to start something new.
///
/// The list is Stream's own: it is drawn only for a server-authorized Stream
/// session. A Development Preview build and a session that is not connected
/// both close the list and say so; neither ever shows a fixture conversation.
class StreamChatInboxPage extends ConsumerStatefulWidget {
  const StreamChatInboxPage({super.key, this.onOpenProfile});

  /// Opens 我 (`/profile`).
  final VoidCallback? onOpenProfile;

  @override
  ConsumerState<StreamChatInboxPage> createState() =>
      _StreamChatInboxPageState();
}

class _StreamChatInboxPageState extends ConsumerState<StreamChatInboxPage> {
  var _filter = ChatInboxFilter.all;

  @override
  Widget build(BuildContext context) {
    final preview =
        ref.watch(communicationGatewayProvider).mode ==
        CommunicationMode.preview;
    final Widget content;
    if (preview) {
      // The Preview build has no Stream session. Its fixture conversations
      // stay on their own guarded pages and never enter this list.
      content = const _StreamUnavailableCard(
        message: '这个版本没有连接聊天服务，会话不会显示在这里。',
      );
    } else {
      content = ref
          .watch(streamChatAuthorizationProvider)
          .when(
            // Never keep an old authorized UI mounted while logout, account
            // switch, or an explicit retry is revalidating the principal.
            skipLoadingOnReload: false,
            skipLoadingOnRefresh: false,
            loading: () => const _StreamStatusCard(
              key: ValueKey<String>('stream-chat-connecting'),
              title: '正在连接会话',
              message: '正在恢复这个账号的会话。',
              icon: Icons.sync_rounded,
            ),
            error: (error, stackTrace) => _StreamUnavailableCard(
              message: '会话没有恢复成功，这一页没有执行任何消息操作。',
              onRetry: () => ref.invalidate(streamChatAuthorizationProvider),
            ),
            data: (authorization) {
              final session = ref.watch(streamChatSdkSessionProvider);
              final currentUser = session?.client.state.currentUser;
              if (authorization != StreamSessionAuthorization.authorized ||
                  session == null ||
                  currentUser == null) {
                return _StreamUnavailableCard(
                  message: '聊天服务还没有连接，稍后再试。',
                  onRetry: () =>
                      ref.invalidate(streamChatAuthorizationProvider),
                );
              }
              return _StreamChannelListBody(
                key: ValueKey<String>('stream-chat-list-${currentUser.id}'),
                client: session.client,
                userId: currentUser.id,
                filter: _filter,
              );
            },
          );
    }

    return LoopStreamPage(
      key: const ValueKey<String>('chat-tab-screen'),
      archetype: LoopPageArchetype.listing,
      title: '聊天',
      tabPage: true,
      leading: _ChatOwnerAvatar(onPressed: widget.onOpenProfile),
      actions: const <Widget>[ChatCreateMenuButton()],
      filters: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // `#scr-community` puts 「陌生人请求」 above the conversations. A
          // request that has not been accepted is not a conversation and
          // never enters the list, so the row stands here — and only while
          // there is something waiting.
          const _MessageRequestsEntry(),
          LoopSegBar(
            key: const ValueKey<String>('chat-inbox-filters'),
            labels: <String>[
              for (final filter in ChatInboxFilter.values) filter.label,
            ],
            selectedIndex: _filter.index,
            onSelected: (index) =>
                setState(() => _filter = ChatInboxFilter.values[index]),
          ),
        ],
      ),
      collection: content,
    );
  }
}

/// The owner's own face at the head of 聊天, the way into 我.
///
/// It is read from the same profile resource 我 renders; before that read
/// lands it is the monogram, never another account's picture.
class _ChatOwnerAvatar extends ConsumerWidget {
  const _ChatOwnerAvatar({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    if (state.phase == ProfilePhase.initial) {
      scheduleMicrotask(() {
        if (context.mounted) {
          unawaited(ref.read(profileControllerProvider.notifier).load());
        }
      });
    }
    final values = state.resource?.values;
    return Semantics(
      button: true,
      label: '我',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey<String>('chat-open-profile'),
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: LoopTouch.minimum,
          child: Center(
            child: LoopProfileAvatar(
              avatarRef: values?.avatarRef,
              alias: values?.alias,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }
}

/// The inbox's entry to the stranger requests waiting on this account.
///
/// Drawn only when the request list was read and is not empty: an entry
/// with nothing behind it would be one more row to read on every visit.
class _MessageRequestsEntry extends ConsumerWidget {
  const _MessageRequestsEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messageRequestsControllerProvider);
    if (state.phase == CommunityViewPhase.loading && !state.refreshing) {
      scheduleMicrotask(() {
        if (context.mounted) {
          unawaited(
            ref.read(messageRequestsControllerProvider.notifier).load(),
          );
        }
      });
    }
    if (state.phase != CommunityViewPhase.ready || state.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final count = state.items.length;
    final label = state.nextCursor == null ? '$count' : '$count+';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: LoopRecordGroup(
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('stream-chat-message-requests-entry'),
            leading: const LoopRowIcon(
              icon: 'mail',
              tone: LoopRowIconTone.accent,
            ),
            title: '陌生人请求',
            subtitle: '$label 条待处理',
            semanticLabel: '陌生人请求，$label 条待处理',
            onTap: () => unawaited(context.push<void>('/chat/requests')),
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

class _StreamChannelListBody extends ConsumerStatefulWidget {
  const _StreamChannelListBody({
    required this.client,
    required this.userId,
    required this.filter,
    super.key,
  });

  final StreamChatClient client;
  final String userId;
  final ChatInboxFilter filter;

  @override
  ConsumerState<_StreamChannelListBody> createState() =>
      _StreamChannelListBodyState();
}

/// The inbox's channel list, kept across visits (decision 0101).
///
/// The list used to be created with the page and disposed with it, so every
/// visit to 会话 started from an empty controller. Held here, a return visit
/// draws the rows it had — still subscribed to Stream's events, so they did
/// not go stale while away — and the list view's own initial load re-queries
/// behind them without clearing them. Released
/// `LoopSnapshotPolicy.memoryRetention` after the last visit; a different
/// client or user is a different key, so no account sees another's list.
final loopStreamChannelListControllerProvider = Provider.autoDispose
    .family<
      StreamChannelListController,
      ({StreamChatClient client, String userId})
    >((ref, key) {
      loopRetainRead(ref, onRevisit: () {});
      final controller = createLoopStreamChannelListController(
        client: key.client,
        userId: key.userId,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

class _StreamChannelListBodyState
    extends ConsumerState<_StreamChannelListBody> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(
      loopStreamChannelListControllerProvider((
        client: widget.client,
        userId: widget.userId,
      )),
    );
    // Who each direct conversation is with, read once from LOOP's own index
    // (decision 0056). A failed or still-running read publishes the empty
    // index, and every direct row then keeps its neutral label: the inbox
    // never borrows a name from Stream.
    final directory =
        ref.watch(directChannelDirectoryProvider).value ??
        LoopDirectChannelDirectory.empty();
    // No filled panel around the list: it is laid out in the page's whole
    // remaining height, so one conversation came out as a single row at the
    // top of an 1100px empty box. The rows sit on the page itself.
    return LoopDirectChannelDirectoryScope(
      directory: directory,
      child: KeyedSubtree(
        key: const ValueKey<String>('stream-chat-channel-list'),
        child: StreamChannelListView(
          controller: controller,
          padding: const EdgeInsets.symmetric(vertical: 8),
          // The filter hides rows rather than re-querying: Stream cannot
          // filter channels by an ID prefix, and one shared list keeps the
          // order, unread state and pagination of every row in one place.
          itemBuilder: (context, channels, index, defaultItem) =>
              widget.filter.includes(channels[index].cid)
              ? loopStreamChannelListIdentityItem(defaultItem)
              : const SizedBox.shrink(),
          separatorBuilder: (context, channels, index) =>
              widget.filter.includes(channels[index].cid)
              ? defaultChannelListViewSeparatorBuilder(context, channels, index)
              : const SizedBox.shrink(),
          emptyBuilder: (context) => const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LoopStateCard(
                title: '还没有会话',
                message: '加入社区或添加好友后，会话会出现在这里。',
                icon: Icons.chat_bubble_outline_rounded,
              ),
            ),
          ),
          errorBuilder: (context, error) => Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LoopStateCard(
                title: '会话列表读不到',
                message: '这一页没有读到会话列表，本地已有的历史没有被删除。',
                icon: Icons.cloud_off_outlined,
                tone: LoopTone.warning,
                action: OutlinedButton.icon(
                  onPressed: () => controller.refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              ),
            ),
          ),
          onChannelTap: (channel) => _openChannel(context, channel, directory),
        ),
      ),
    );
  }

  static void _openChannel(
    BuildContext context,
    Channel channel,
    LoopDirectChannelDirectory directory,
  ) {
    final destination = loopInboxChannelDestination(
      cid: channel.cid,
      directory: directory,
    );
    if (destination == null) return;
    unawaited(
      context.push<void>(destination.location, extra: destination.target),
    );
  }
}

/// Where one inbox row goes, and what it may carry there.
///
/// A direct row LOOP can name travels the same way the 「关注与粉丝」 entry
/// does: the peer's public profile rides as typed navigation state, so the
/// conversation header and the `@` candidate read the same person from the
/// same source (device report 2026-09-20 · R15-1). The identity is never put
/// in the URL — a deep link must not be able to name a conversation — so a
/// row LOOP cannot name opens through the plain CID link, exactly as before,
/// and the page then stays neutral.
@visibleForTesting
({String location, DirectMessageTarget? target})? loopInboxChannelDestination({
  required String? cid,
  required LoopDirectChannelDirectory directory,
}) {
  if (cid == null || parseLoopStreamChannelCid(cid) == null) return null;
  final encoded = Uri.encodeComponent(cid);
  final peer = loopStreamChannelUsesGroupMessageAlias(cid)
      ? null
      : resolveLoopDirectRowIdentity(cid: cid, directory: directory).peer;
  final publicProfileId = peer?.publicProfileId;
  if (peer != null && publicProfileId != null) {
    return (
      location: '/chat/dm?cid=$encoded',
      target: DirectMessageTarget(
        publicProfileId: publicProfileId,
        identity: peer,
      ),
    );
  }
  return (location: '/chat/channel/$encoded', target: null);
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
  const _StreamUnavailableCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: LoopStateCard(
        key: const ValueKey<String>('stream-chat-unavailable'),
        title: '会话还没有连接',
        message: message,
        icon: Icons.cloud_off_outlined,
        tone: LoopTone.neutral,
        action: onRetry == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
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
