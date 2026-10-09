import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
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
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_faces.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/social_controllers.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The 「发起」 button and the margin above it: 56 + 32 (decision 0123).
const double chatInboxFabClearance = 88;

/// The room under the last conversation row. The list already ends at the
/// page's bottom inset, and the button stands [LoopLayout.tabPageBottomReserve]
/// above that inset, so the last row ends 32 above the button and is never
/// under it (measured on the emulator: with 88 alone the last row sat under
/// the button).
const double chatInboxListBottomPadding =
    LoopLayout.tabPageBottomReserve + chatInboxFabClearance;

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

  /// The chip's sprite glyph (decision 0122).
  String get icon => switch (this) {
    ChatInboxFilter.all => 'chat',
    ChatInboxFilter.communities => 'community',
    ChatInboxFilter.friends => 'users',
  };

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
  const StreamChatInboxPage({
    super.key,
    this.onOpenProfile,
    this.onOpenVoiceRoom,
  });

  /// Opens 我 (`/profile`).
  final VoidCallback? onOpenProfile;

  /// Returns to the live room of one community (`/chat/voice?id=`).
  final ValueChanged<String>? onOpenVoiceRoom;

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

    final page = LoopStreamPage(
      key: const ValueKey<String>('chat-tab-screen'),
      archetype: LoopPageArchetype.listing,
      title: '聊天',
      tabPage: true,
      leading: _ChatOwnerAvatar(onPressed: widget.onOpenProfile),
      // OKX social head (decision 0122): the owner's face and one search
      // field across the bar; 「发起」 is the round Lime key at the foot.
      titleField: const _ChatSearchEntry(),
      filters: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The room this account is in, as this client knows it (decision
          // 0111): the way back that the retired community message panel
          // used to carry. Only while there is a room to go back to.
          _VoiceRoomReturnEntry(onOpenVoiceRoom: widget.onOpenVoiceRoom),
          // `#scr-community` puts 「陌生人请求」 above the conversations. A
          // request that has not been accepted is not a conversation and
          // never enters the list, so the row stands here — and only while
          // there is something waiting. The Development Preview reads its
          // requests from memory, so the row is not drawn there at all: a
          // count with no 演示数据 mark beside it would read as real.
          if (!preview) const _MessageRequestsEntry(),
          LoopSegBar(
            key: const ValueKey<String>('chat-inbox-filters'),
            labels: <String>[
              for (final filter in ChatInboxFilter.values) filter.label,
            ],
            icons: <String>[
              for (final filter in ChatInboxFilter.values) filter.icon,
            ],
            selectedIndex: _filter.index,
            onSelected: (index) =>
                setState(() => _filter = ChatInboxFilter.values[index]),
          ),
        ],
      ),
      collection: content,
    );
    return Stack(
      children: <Widget>[
        Positioned.fill(child: page),
        Positioned(
          right: LoopSpacing.page,
          bottom:
              MediaQuery.paddingOf(context).bottom +
              LoopLayout.tabPageBottomReserve,
          child: const ChatCreateMenuButton(floating: true),
        ),
      ],
    );
  }
}

/// The search field across the head of 聊天; it opens 聊天搜索.
class _ChatSearchEntry extends StatelessWidget {
  const _ChatSearchEntry();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '搜索聊天',
    excludeSemantics: true,
    child: Material(
      color: LoopColors.card2,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const ValueKey<String>('chat-search-entry'),
        customBorder: const StadiumBorder(),
        onTap: () => unawaited(context.push<void>('/chat/search')),
        child: SizedBox(
          height: LoopTouch.minimum,
          child: Row(
            children: <Widget>[
              const SizedBox(width: 14),
              const LoopIcon('search', size: 18, color: LoopColors.text2),
              const SizedBox(width: 8),
              Text(
                '搜索聊天',
                style: LoopType.body.copyWith(color: LoopColors.text3),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}

/// The way back into the voice room this account is in (decision 0111).
///
/// Read from the same session the shell's room strip stands on; drawn only
/// while that session exists.
class _VoiceRoomReturnEntry extends ConsumerWidget {
  const _VoiceRoomReturnEntry({required this.onOpenVoiceRoom});

  final ValueChanged<String>? onOpenVoiceRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(voiceRoomSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final open = onOpenVoiceRoom;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: LoopRecordGroup(
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('chat-voice-room-return-entry'),
            leading: CommunityLogo(
              identity: session.communityId,
              name: session.communityName,
            ),
            title: '正在语音房 · ${session.communityName}',
            trailing: '返回',
            semanticLabel: '正在语音房，${session.communityName}，返回房间',
            onTap: open == null ? null : () => open(session.communityId),
          ),
        ],
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
    // Decision 0112: with the group Alias hidden there is nothing for the
    // membership gate to unlock, so it is not run.
    if (!ref.watch(loopFeatureSwitchesProvider).groupAliasVisible) {
      return const GroupAliasPausedPage();
    }
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
                  onChannelAvatarPressed:
                      groupAliasChannelId == null ||
                          !loopFeatureSwitchesOf(context).groupAliasVisible
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
    // The community rows draw the community's own logo (decision 0122). The
    // channel carries none, so the inbox reads the community home aggregate
    // once — it lists every community this account is in — and the rows
    // take their faces from what it, and the directory, already answered.
    final home = ref.watch(communityHomeControllerProvider);
    if (home.phase == CommunityViewPhase.loading && home.value == null) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(communityHomeControllerProvider.notifier).load());
        }
      });
    }
    final faces = ref.watch(communityFacesProvider);
    // No filled panel around the list: it is laid out in the page's whole
    // remaining height, so one conversation came out as a single row at the
    // top of an 1100px empty box. The rows sit on the page itself.
    return CommunityFacesScope(
      faces: faces,
      child: LoopDirectChannelDirectoryScope(
        directory: directory,
        child: ChatInboxFilterEmptyGate(
          controller: controller,
          filter: widget.filter,
          child: KeyedSubtree(
            key: const ValueKey<String>('stream-chat-channel-list'),
            child: StreamChannelListView(
              controller: controller,
              // Decision 0123: the last row ends above the 「发起」 button
              // (56 + its 32 margin), never under it.
              padding: const EdgeInsets.fromLTRB(
                0,
                8,
                0,
                chatInboxListBottomPadding,
              ),
              // The filter hides rows rather than re-querying: Stream cannot
              // filter channels by an ID prefix, and one shared list keeps the
              // order, unread state and pagination of every row in one place.
              itemBuilder: (context, channels, index, defaultItem) =>
                  widget.filter.includes(channels[index].cid)
                  ? loopStreamChannelListIdentityItem(defaultItem)
                  : const SizedBox.shrink(),
              // OKX's conversation list has no hairlines (decision 0123).
              // Rows are told apart by the tile's own vertical padding — about
              // 38 between two avatars; an extra 12 made the list loose.
              separatorBuilder: (context, channels, index) =>
                  const SizedBox.shrink(),
              emptyBuilder: (context) => SingleChildScrollView(
                child: LoopEmptyState(
                  key: const ValueKey<String>('stream-chat-empty'),
                  illustration: LoopIllustration.chat,
                  title: '还没有会话',
                  message: '加入社区或添加好友后，会话会出现在这里',
                  action: LoopButton(
                    key: const ValueKey<String>(
                      'stream-chat-empty-find-friends',
                    ),
                    label: '找朋友',
                    icon: 'users',
                    primary: true,
                    onPressed: () => unawaited(context.push<void>('/search')),
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
              onChannelTap: (channel) =>
                  _openChannel(context, channel, directory),
            ),
          ),
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

/// Whether a narrowed inbox has read every page and kept no row (S106b).
///
/// The filter hides rows instead of re-querying, so Stream's own empty state
/// never fires for it: a list of communities read under 好友 was a blank
/// page. Only a finished list says so — while a next page exists, the list
/// view reads it as the end comes into view.
@visibleForTesting
bool chatInboxFilterLeftNothing(
  ChatInboxFilter filter,
  PagedValue<int, Channel> value,
) {
  if (filter == ChatInboxFilter.all || !value.isSuccess) return false;
  final page = value.asSuccess;
  if (page.items.isEmpty || page.nextPageKey != null) return false;
  return !page.items.any((channel) => filter.includes(channel.cid));
}

/// Replaces the list with the filter's own empty state once
/// [chatInboxFilterLeftNothing] holds; otherwise draws [child].
@visibleForTesting
class ChatInboxFilterEmptyGate extends StatelessWidget {
  const ChatInboxFilterEmptyGate({
    required this.controller,
    required this.filter,
    required this.child,
    super.key,
  });

  final ValueListenable<PagedValue<int, Channel>> controller;
  final ChatInboxFilter filter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PagedValue<int, Channel>>(
      valueListenable: controller,
      child: child,
      builder: (context, value, list) {
        final empty = chatInboxFilterLeftNothing(filter, value);
        final communities = filter == ChatInboxFilter.communities;
        // The list stays mounted under the empty state, so switching back
        // to 全部 neither re-queries nor loses the scroll position.
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: Offstage(offstage: empty, child: list),
            ),
            if (empty)
              SingleChildScrollView(
                child: LoopEmptyState(
                  key: ValueKey<String>(
                    'chat-inbox-filter-empty-${filter.name}',
                  ),
                  illustration: LoopIllustration.chat,
                  title: communities ? '还没有社区会话' : '还没有好友会话',
                  message: communities
                      ? '加入社区后，社区群聊会出现在这里'
                      : '和好友私聊或建群后，会话会出现在这里',
                ),
              ),
          ],
        );
      },
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
