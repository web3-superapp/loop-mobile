import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/cache/loop_read_retention.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_inbox_row_actions.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/friends/chat_create_menu_button.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_screen.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/chat/widgets/group_mosaic_avatar.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_faces.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart'
    show confirmCommunityAction;
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_sdk_session.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_deleted_message_reconciler.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_search_entry.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The room under the last conversation row: the floating tab bar's reserve.
/// S343 · decision 0271: 「发起」 moved to the bar's 「＋」, so nothing else
/// floats over the list.
const double chatInboxListBottomPadding = LoopLayout.tabPageBottomReserve;

/// The search field under the title (docs/58 §3.1: 8 from the title block)
/// and the room between it and the first row.
const double chatInboxSearchTop = 8;
const double chatInboxSearchBottom = 10;

/// One conversation row (docs/58 §3.2 / §5.6): 67 high, a 48 face, the name
/// 2 over the preview, the content inside the page gutter.
const double chatInboxRowHeight = 67;

/// Creates LOOP's official, bounded Stream channel-list controller.
///
/// Stream owns channel ordering, pagination, unread state, presence, and local
/// persistence. LOOP deliberately does not mirror these records into its
/// preview conversation DTOs.
///
/// S348: one Stream query, one list — community rooms and conversations
/// with friends side by side, pinned first, then the latest message.
///
/// [initialChannels] — what the local list already drew (decision 0132) —
/// becomes the first value, so the live list opens on those rows and its own
/// initial load replaces them without a skeleton in between.
@visibleForTesting
StreamChannelListController createLoopStreamChannelListController({
  required StreamChatClient client,
  required String userId,
  List<Channel>? initialChannels,
}) {
  if (userId.isEmpty || userId != userId.trim()) {
    throw ArgumentError.value(userId, 'userId', 'must be non-empty');
  }
  if (initialChannels != null && initialChannels.isNotEmpty) {
    return StreamChannelListController.fromValue(
      PagedValue<int, Channel>(items: initialChannels),
      client: client,
      filter: loopStreamInboxFilter(userId),
      channelStateSort: loopStreamInboxSort,
      presence: true,
      limit: loopStreamInboxPageSize,
      messageLimit: 25,
      memberLimit: 30,
    );
  }
  return StreamChannelListController(
    client: client,
    filter: loopStreamInboxFilter(userId),
    channelStateSort: loopStreamInboxSort,
    presence: true,
    limit: loopStreamInboxPageSize,
    messageLimit: 25,
    memberLimit: 30,
  );
}

/// The inbox query: every messaging channel this account is a member of.
Filter loopStreamInboxFilter(String userId) => Filter.and(<Filter>[
  Filter.equal('type', 'messaging'),
  Filter.in_('members', <Object>[userId]),
]);

/// A pinned conversation stands above the rest (decision 0129); below it
/// Stream keeps the newest message first.
const List<SortOption<ChannelState>> loopStreamInboxSort =
    <SortOption<ChannelState>>[
      SortOption<ChannelState>.desc(ChannelSortKey.pinnedAt),
      SortOption<ChannelState>.desc(ChannelSortKey.lastUpdated),
    ];

/// One page of the inbox.
const int loopStreamInboxPageSize = 20;

/// The rows Stream's own first read asks for: its initial-page multiplier
/// over [loopStreamInboxPageSize], capped at its backend limit of 30. The
/// local read asks for the same, so it reads the very rows the live list
/// will.
const int loopStreamInboxFirstRead = 30;

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

/// `chat` · 聊天, the first tab (decision 0110, S106 §2).
///
/// One list of every conversation this account is in — community rooms,
/// direct messages and small groups side by side (S348) — pinned first,
/// then ordered by Stream by the latest message. 「＋」 at the top right holds every way to start something new.
///
/// The list is Stream's own: it is drawn only for a server-authorized Stream
/// session. A Development Preview build and a session that is not connected
/// both close the list and say so; neither ever shows a fixture conversation.
class StreamChatInboxPage extends ConsumerStatefulWidget {
  const StreamChatInboxPage({super.key, this.onOpenVoiceRoom});

  /// Returns to the live room of one community (`/chat/voice?id=`).
  final ValueChanged<String>? onOpenVoiceRoom;

  @override
  ConsumerState<StreamChatInboxPage> createState() =>
      _StreamChatInboxPageState();
}

class _StreamChatInboxPageState extends ConsumerState<StreamChatInboxPage> {
  @override
  Widget build(BuildContext context) {
    final preview =
        ref.watch(communicationGatewayProvider).mode ==
        CommunicationMode.preview;
    final Widget content;
    if (preview) {
      // The Preview build has no Stream session. Its fixture conversations
      // stay on their own guarded pages and never enter this list.
      content = _StreamUnavailableCard(
        message: context.l10n.chat_streamInboxMessage,
      );
    } else {
      final authorization = ref.watch(streamChatAuthorizationProvider);
      final session = ref.watch(streamChatSdkSessionProvider);
      final localHistory = session?.authorizer.localHistoryUserId;
      Widget body(String? localUserId) => _authorizedContent(
        authorization: authorization,
        session: session,
        localUserId: localUserId,
      );
      // Decision 0132: while the token and the websocket are on their way
      // the inbox draws this device's own copy of the conversations.
      content = localHistory == null
          ? body(null)
          : ValueListenableBuilder<String?>(
              valueListenable: localHistory,
              builder: (context, localUserId, _) => body(localUserId),
            );
    }

    final page = LoopStreamPage(
      key: const ValueKey<String>('chat-tab-screen'),
      archetype: LoopPageArchetype.listing,
      title: context.l10n.common_chat,
      tabPage: true,
      scrollsUnderTabBar: true,
      // Decision 0221: the wall under 聊天 — Purple fog top right, Yellow
      // bottom left — and the faded crown behind the bar's field.
      backdrop: const LoopWallBackdrop(
        key: ValueKey<String>('chat-atmo-backdrop'),
        fog: LoopWallFog.chat,
        keyPrefix: 'chat-atmo',
      ),
      // S343 · decision 0271: 「＋」 at the top right; the bell and the
      // owner's face moved to 我的 (docs/56 §四, so the Figma's bell is not
      // drawn here).
      actions: const <Widget>[ChatCreateMenuButton()],
      // S353a · decision 0278 (docs/58 §5.1): the bar carries the page title
      // over the Purple doodle, and the 44 search field stands under it, 8
      // below, across the page gutter.
      filters: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(
              LoopSpacing.page,
              chatInboxSearchTop,
              LoopSpacing.page,
              chatInboxSearchBottom,
            ),
            child: LoopTitleCrown(
              crownKey: ValueKey<String>('chat-atmo-title-crown'),
              left: 40,
              top: -22,
              width: 80,
              child: _ChatSearchEntry(),
            ),
          ),
          // The room this account is in, as this client knows it (decision
          // 0111): the way back that the retired community message panel
          // used to carry. Only while there is a room to go back to.
          _VoiceRoomReturnEntry(onOpenVoiceRoom: widget.onOpenVoiceRoom),
        ],
      ),
      collection: content,
    );
    return LoopAtmoPrecache(child: page);
  }
}

extension on _StreamChatInboxPageState {
  Widget _authorizedContent({
    required AsyncValue<StreamSessionAuthorization> authorization,
    required StreamChatSdkSession? session,
    required String? localUserId,
  }) {
    return authorization.when(
      // Never keep an old authorized UI mounted while logout, account
      // switch, or an explicit retry is revalidating the principal.
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: false,
      loading: () {
        // Decision 0132: the identity is known and its own copy is open, so
        // the list draws what this device already holds — the same list, by
        // the same key, that the live one takes over once it connects.
        if (session != null && localUserId != null) {
          return _StreamChannelListBody(
            key: ValueKey<String>('stream-chat-list-$localUserId'),
            client: session.client,
            userId: localUserId,
            localOnly: true,
          );
        }
        // Nothing on this device yet: rows in the shape they arrive in, not
        // a card about connecting.
        return const ChatInboxRowsSkeleton(
          key: ValueKey<String>('stream-chat-connecting'),
        );
      },
      error: (error, stackTrace) => _StreamUnavailableCard(
        message: LoopL10n.current.chat_streamInboxMessage2,
        onRetry: () => ref.invalidate(streamChatAuthorizationProvider),
      ),
      data: (authorization) {
        final currentUser = session?.client.state.currentUser;
        if (authorization != StreamSessionAuthorization.authorized ||
            session == null ||
            currentUser == null) {
          return _StreamUnavailableCard(
            message: LoopL10n.current.chat_streamInboxMessage3,
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
  }
}

/// The inbox before anything is known about its conversations (decision
/// 0132): conversation rows in the shape the list draws them — 67 high, a
/// 48 face (decision 0260) on the page gutter, the name with the time at its
/// end over the preview line (S353a) — so nothing moves when the rows land. The list view loads in the same shape.
class ChatInboxRowsSkeleton extends StatelessWidget {
  const ChatInboxRowsSkeleton({super.key, this.rows = 7});

  final int rows;

  static const List<double> _titles = <double>[0.46, 0.34, 0.52, 0.4];
  static const List<double> _previews = <double>[0.7, 0.56, 0.64, 0.5];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.chat_streamInboxLabel,
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: chatInboxListBottomPadding),
          child: Column(
            children: <Widget>[
              for (var index = 0; index < rows; index++)
                Padding(
                  // The row's measures (docs/58 §5.6): 67 high, the face on
                  // the page gutter.
                  padding: const EdgeInsets.symmetric(
                    horizontal: LoopSpacing.page,
                    vertical: (chatInboxRowHeight - chatListAvatarSize) / 2,
                  ),
                  child: Row(
                    children: <Widget>[
                      const LoopSkeletonBlock(
                        width: chatListAvatarSize,
                        height: chatListAvatarSize,
                        radius: chatListAvatarRadius,
                      ),
                      const SizedBox(width: ChatInboxRowMetrics.gap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: LoopSkeletonLine(
                                    style: LoopType.rowTitleLg,
                                    widthFactor: _titles[index % 4],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const LoopSkeletonBlock(width: 40, height: 10),
                              ],
                            ),
                            const SizedBox(height: ChatInboxRowMetrics.outer),
                            LoopSkeletonLine(
                              style: LoopType.captionMd,
                              widthFactor: _previews[index % 4],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The search field across the head of 聊天; it opens 聊天搜索.
class _ChatSearchEntry extends StatelessWidget {
  const _ChatSearchEntry();

  @override
  Widget build(BuildContext context) => LoopSearchEntry(
    // Decision 0277: the Figma's 44 search field.
    placeholder: context.l10n.chat_streamInboxPlaceholder,
    inkKey: const ValueKey<String>('chat-search-entry'),
    onTap: () => unawaited(context.push<void>('/chat/search')),
  );
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
            title: context.l10n.chat_streamInboxChatVoiceRoomReturnEntryTitle(
              session.communityName,
            ),
            trailing: context.l10n.common_back,
            semanticLabel: context.l10n
                .chat_streamInboxChatVoiceRoomReturnEntrySemanticLabel(
                  session.communityName,
                ),
            onTap: open == null ? null : () => open(session.communityId),
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
      return _StreamChannelUnavailablePage(
        title: context.l10n.chat_streamInboxTitle,
        message: context.l10n.chat_streamInboxMessage4,
      );
    }

    return ref
        .watch(streamChatAuthorizationProvider)
        .when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          loading: () => _StreamChannelUnavailablePage(
            title: context.l10n.chat_streamInboxTitle2,
            message: context.l10n.chat_streamInboxMessage5,
            loading: true,
          ),
          error: (error, stackTrace) => _StreamChannelUnavailablePage(
            title: context.l10n.chat_streamInboxTitle3,
            message: context.l10n.chat_streamInboxMessage6,
          ),
          data: (authorization) {
            final session = ref.watch(streamChatSdkSessionProvider);
            if (authorization != StreamSessionAuthorization.authorized ||
                session?.client.state.currentUser == null) {
              return _StreamChannelUnavailablePage(
                title: context.l10n.chat_streamInboxTitle4,
                message: context.l10n.chat_streamInboxMessage7,
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
      return _StreamChannelUnavailablePage(
        title: context.l10n.chat_streamInboxTitle5,
        message: context.l10n.chat_streamInboxMessage8,
      );
    }

    return ref
        .watch(streamChatAuthorizationProvider)
        .when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          loading: () => _StreamChannelUnavailablePage(
            title: context.l10n.chat_streamInboxTitle2,
            message: context.l10n.chat_streamInboxMessage5,
            loading: true,
          ),
          error: (error, stackTrace) => _StreamChannelUnavailablePage(
            title: context.l10n.chat_streamInboxTitle6,
            message: context.l10n.chat_streamInboxMessage9,
          ),
          data: (authorization) {
            final session = ref.watch(streamChatSdkSessionProvider);
            final currentUser = session?.client.state.currentUser;
            if (authorization != StreamSessionAuthorization.authorized ||
                session == null ||
                currentUser == null) {
              return _StreamChannelUnavailablePage(
                title: context.l10n.chat_streamInboxTitle4,
                message: context.l10n.chat_streamInboxMessage10,
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
          return _StreamChannelUnavailablePage(
            title: context.l10n.chat_streamInboxTitle7,
            message: context.l10n.chat_streamInboxMessage11,
            loading: true,
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _StreamChannelUnavailablePage(
            title: context.l10n.chat_streamInboxTitle8,
            message: context.l10n.chat_streamInboxMessage12,
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
          return _StreamChannelUnavailablePage(
            title: context.l10n.chat_streamInboxTitle9,
            message: context.l10n.chat_streamInboxMessage13,
            loading: true,
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _StreamChannelUnavailablePage(
            title: context.l10n.chat_streamInboxTitle10,
            message: context.l10n.chat_streamInboxMessage14,
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
    super.key,
    this.localOnly = false,
  });

  final StreamChatClient client;
  final String userId;

  /// Draw only this device's own copy (decision 0132): the session is not
  /// connected yet, so the rows open their conversations but offer no
  /// action, and pulling does not re-read.
  final bool localOnly;

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
      final seed = loopInboxLocalSeed(key.client, key.userId);
      // A seed opens one live list; a later one reads for itself.
      _inboxLocalSeeds[key.client] = null;
      final controller = createLoopStreamChannelListController(
        client: key.client,
        userId: key.userId,
        initialChannels: seed,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

/// The inbox drawn from this device's own copy while the session connects
/// (decision 0132).
///
/// It reads Stream's local store with the very query the live list makes, and
/// nothing else: no network read, no event subscription, no next page. What
/// it read is handed to the live list as its first value, so the switch to
/// the live list shows the same rows with no skeleton in between.
final loopStreamLocalChannelListControllerProvider = Provider.autoDispose
    .family<
      StreamChannelListController,
      ({StreamChatClient client, String userId})
    >((ref, key) {
      final controller = LoopLocalChannelListController(
        client: key.client,
        userId: key.userId,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

/// How many inbox rows one pull reconciles with the server (decision 0216).
const int loopInboxReconcileRows = 8;

/// Compares the first [loopInboxReconcileRows] conversations of [channels]
/// with the server, one after another, and drops what it deleted.
Future<void> loopReconcileInboxChannels(
  StreamChatClient client,
  List<Channel> channels, {
  LoopStreamDeletedMessageReconciler? reconciler,
}) async {
  final using = reconciler ?? loopStreamDeletedMessageReconcilerFor(client);
  for (final channel in channels.take(loopInboxReconcileRows)) {
    await using.reconcile(channel);
  }
}

final Expando<({String userId, List<Channel> channels})> _inboxLocalSeeds =
    Expando<({String userId, List<Channel> channels})>('loop-inbox-seed');

/// The rows the local list read for [userId] on [client], or `null`.
@visibleForTesting
List<Channel>? loopInboxLocalSeed(StreamChatClient client, String userId) {
  final seed = _inboxLocalSeeds[client];
  if (seed == null || seed.userId != userId) return null;
  return seed.channels;
}

/// See [loopStreamLocalChannelListControllerProvider].
@visibleForTesting
final class LoopLocalChannelListController extends StreamChannelListController {
  LoopLocalChannelListController({
    required super.client,
    required this.userId,
    this.read,
  }) : super(
         filter: loopStreamInboxFilter(userId),
         channelStateSort: loopStreamInboxSort,
         presence: true,
         limit: loopStreamInboxPageSize,
         messageLimit: 25,
         memberLimit: 30,
       );

  final String userId;

  /// The local read. Defaults to Stream's own store; a test supplies its own.
  final Future<List<Channel>> Function()? read;

  @override
  Future<void> doInitialLoad() async {
    List<Channel> channels;
    try {
      channels =
          await (read ??
              () => client.queryChannelsOffline(
                filter: filter,
                channelStateSort: channelStateSort,
                messageLimit: messageLimit,
                paginationParams: const PaginationParams(
                  limit: loopStreamInboxFirstRead,
                ),
              ))();
    } catch (_) {
      // No copy is no copy: the rows stay in their loading shape.
      return;
    }
    // An empty copy is not "no conversations" — only the server may say
    // that — so the list keeps its loading shape until it answers.
    if (channels.isEmpty) return;
    _inboxLocalSeeds[client] = (userId: userId, channels: channels);
    value = PagedValue<int, Channel>(items: channels);
  }

  @override
  Future<void> loadMore(int nextPageKey) async {}
}

class _StreamChannelListBodyState
    extends ConsumerState<_StreamChannelListBody> {
  @override
  Widget build(BuildContext context) {
    final key = (client: widget.client, userId: widget.userId);
    final localOnly = widget.localOnly;
    final controller = ref.watch(
      localOnly
          ? loopStreamLocalChannelListControllerProvider(key)
          : loopStreamChannelListControllerProvider(key),
    );
    // Who each direct conversation is with, read once from LOOP's own index
    // (decision 0056). A failed or still-running read publishes the empty
    // index, and every direct row then keeps its neutral label: the inbox
    // never borrows a name from Stream.
    final directory =
        ref.watch(directChannelDirectoryProvider).value ??
        LoopDirectChannelDirectory.empty();
    // The community rows draw their members' mosaic like every group
    // (decision 0260); the community home aggregate is still read once — it
    // lists every community this account is in — for the quiet row's first
    // sentence and the opened community conversation's title.
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
        child: KeyedSubtree(
          key: const ValueKey<String>('stream-chat-channel-list'),
          // Pull to re-read the list (S123 M2). The rows stay on screen
          // while Stream answers: the refresh does not reset the value.
          child: loopRefreshable(
            onRefresh: localOnly
                ? () async {}
                : () async {
                    await controller.refresh(resetValue: false);
                    // Decision 0216: a pull also asks the server which
                    // messages it deleted, for the rows at the top.
                    unawaited(
                      loopReconcileInboxChannels(
                        widget.client,
                        controller.value.isSuccess
                            ? controller.currentItems
                            : const <Channel>[],
                      ),
                    );
                  },
            child: ChatInboxSwipeScope(
              child: StreamChannelListView(
                controller: controller,
                padding: const EdgeInsets.only(
                  bottom: chatInboxListBottomPadding,
                ),
                // S348: one list, community rooms and friends side by
                // side in Stream's order.
                itemBuilder: (context, channels, index, defaultItem) {
                  final channel = channels[index];
                  // Decision 0221: on the wall the rows form one opaque
                  // card board; the rows stay undecorated.
                  return _boardRow(
                    channels,
                    index,
                    // S350a · decision 0274: a pinned row is told apart by
                    // its lifted ground, live as the pin changes (S353a:
                    // the Figma's Card step).
                    StreamBuilder<bool>(
                      initialData: channel.isPinned,
                      stream: channel.isPinnedStream,
                      builder: (context, pinned) => ChatInboxSwipeRow(
                        key: ValueKey<String>('chat-inbox-row-${channel.cid}'),
                        pinned: pinned.data ?? false,
                        // Not connected yet: no action can be carried out.
                        actions: () => localOnly
                            ? const <ChatInboxRowAction>[]
                            : chatInboxRowActions(
                                ChatInboxRowFacts.of(channel),
                              ),
                        onAction: (action) =>
                            unawaited(_runAction(channel, action, controller)),
                        child: ChatInboxRowMetrics(
                          child: loopStreamChannelListIdentityItem(defaultItem),
                        ),
                      ),
                    ),
                  );
                },
                // S353a · decision 0278: the hairline between two rows is
                // drawn by the row itself ([_boardRow]), so nothing more.
                separatorBuilder: (context, channels, index) =>
                    const SizedBox.shrink(),
                // Decision 0132: the same rows-shaped placeholder the
                // inbox draws while it connects.
                loadingBuilder: (context) => const ChatInboxRowsSkeleton(
                  key: ValueKey<String>('stream-chat-list-loading'),
                ),
                // Decision 0221 (0220 §9's way): the grey crown, one
                // sentence and a Yellow action, on a card board.
                emptyBuilder: (context) => SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16),
                  child: LoopAtmoEmpty(
                    key: const ValueKey<String>('stream-chat-empty'),
                    crownKey: const ValueKey<String>('stream-chat-empty-crown'),
                    // Decision 0248: one fact, no how-to.
                    message:
                        context.l10n.chat_streamInboxStreamChatEmptyMessage,
                    actionLabel:
                        context.l10n.chat_streamInboxStreamChatEmptyActionLabel,
                    actionKey: const ValueKey<String>(
                      'stream-chat-empty-find-friends',
                    ),
                    onAction: () => unawaited(context.push<void>('/search')),
                  ),
                ),
                errorBuilder: (context, error) => SingleChildScrollView(
                  child: LoopEmptyState(
                    key: const ValueKey<String>('stream-chat-list-error'),
                    illustration: LoopIllustration.chat,
                    title:
                        context.l10n.chat_streamInboxStreamChatListErrorTitle,
                    message:
                        context.l10n.chat_streamInboxStreamChatListErrorMessage,
                    action: LoopButton(
                      key: const ValueKey<String>('stream-chat-list-retry'),
                      label: context.l10n.common_retry,
                      icon: 'refresh',
                      onPressed: () => controller.refresh(),
                    ),
                  ),
                ),
                onChannelTap: (channel) =>
                    _openChannel(context, channel, directory, faces),
                onChannelLongPress: localOnly
                    ? null
                    : (channel) =>
                          unawaited(_openRowSheet(channel, controller)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The long-press menu: the swipe's actions, in a sheet (S123 M2).
  Future<void> _openRowSheet(
    Channel channel,
    StreamChannelListController controller,
  ) async {
    final actions = chatInboxRowActions(ChatInboxRowFacts.of(channel));
    if (actions.isEmpty) return;
    final choice = await showChatInboxRowActionSheet(
      context,
      title: LoopL10n.current.chat_streamInboxTitle11,
      actions: actions,
    );
    if (choice == null || !mounted) return;
    await _runAction(channel, choice, controller);
  }

  Future<void> _runAction(
    Channel channel,
    ChatInboxRowAction action,
    StreamChannelListController controller,
  ) async {
    if (action.destructive) {
      final confirmed = await confirmCommunityAction(
        context,
        title: LoopL10n.current.chat_streamInboxTitle12,
        body: LoopL10n.current.chat_streamInboxBody,
        confirmLabel: LoopL10n.current.common_delete,
        sheetKey: 'chat-inbox-delete-confirm',
      );
      if (!confirmed || !mounted) return;
    }
    try {
      await runChatInboxRowAction(channel, action);
    } catch (_) {
      if (!mounted) return;
      LoopToast.show(
        context,
        message: LoopL10n.current.chat_streamInboxMessage15(action.label),
        kind: LoopToastKind.err,
      );
      return;
    }
    // Stream does not move a row when its pin changes; the list is read
    // again so the pinned part stays on top.
    if (action == ChatInboxRowAction.pin ||
        action == ChatInboxRowAction.unpin) {
      await controller.refresh(resetValue: false);
    }
  }

  static void _openChannel(
    BuildContext context,
    Channel channel,
    LoopDirectChannelDirectory directory,
    Map<String, CommunityFace> faces,
  ) {
    final cid = channel.cid;
    final communityId = cid == null ? null : loopCommunityIdForChannelCid(cid);
    final destination = loopInboxChannelDestination(
      cid: cid,
      directory: directory,
      communityTitle: communityId == null
          ? null
          : inboxCommunityRowTitle(channel, faces[communityId]),
    );
    if (destination == null) return;
    unawaited(
      context.push<void>(
        destination.location,
        extra: destination.target ?? destination.heading,
      ),
    );
  }
}

/// The name a community row carries into its room (decision 0132): the
/// community's own name as this account read it, or nothing — the room then
/// says what kind of room it is until its record answers.
@visibleForTesting
String? inboxCommunityRowTitle(Channel channel, CommunityFace? face) =>
    face?.name;

/// One inbox row (S353a · decision 0278, docs/58 §5.6): the rows sit on the
/// page itself, full width — the ground is the row's own (see
/// [ChatInboxSwipeRow]) — and a 1px white 5 % hairline inside the page
/// gutter closes every row but the last.
Widget _boardRow(List<Channel> ordered, int index, Widget row) {
  if (index == ordered.length - 1) return row;
  return DecoratedBox(
    key: const ValueKey<String>('chat-inbox-board-hairline'),
    position: DecorationPosition.foreground,
    decoration: const _ChatRowHairline(),
    child: row,
  );
}

/// The row's bottom hairline, inset by the page gutter at both ends.
final class _ChatRowHairline extends Decoration {
  const _ChatRowHairline();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _ChatRowHairlinePainter();
}

final class _ChatRowHairlinePainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final bottom = offset.dy + size.height - 0.5;
    canvas.drawLine(
      Offset(offset.dx + LoopSpacing.page, bottom),
      Offset(offset.dx + size.width - LoopSpacing.page, bottom),
      Paint()
        ..color = LoopColors.divider
        ..strokeWidth = 1,
    );
  }
}

/// Stream's channel tile re-cut to the Figma's conversation row (docs/58
/// §5.6): 67 high with a 48 face, 12 between the face and the words, 2
/// between the name and the preview, and the face on the page gutter.
///
/// The official tile spaces itself from the [StreamTheme]'s spacing scale
/// (`xxs` around it, `sm` inside, `md` between the face and the words), so
/// the row is drawn under a copy of that theme with those three steps set.
class ChatInboxRowMetrics extends StatelessWidget {
  const ChatInboxRowMetrics({required this.child, super.key});

  final Widget child;

  /// Around the tile (Stream's `xxs`); also the name-to-preview gap.
  static const double outer = 2;

  /// Inside the tile, top and bottom (Stream's `sm`): what is left of the
  /// 67 row around the 48 face.
  static const double inner =
      (chatInboxRowHeight - chatListAvatarSize) / 2 - outer;

  /// Between the face and the words (Stream's `md`).
  static const double gap = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stream = StreamTheme.of(context);
    final spacing = stream.spacing.copyWith(xxs: outer, sm: inner, md: gap);
    final extensions =
        theme.extensions.values.where((entry) => entry is! StreamTheme).toList()
          ..add(stream.copyWith(spacing: spacing));
    return Theme(
      data: theme.copyWith(extensions: extensions),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LoopSpacing.page - outer - inner,
        ),
        child: child,
      ),
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
///
/// A community row opens its room directly, carrying the name the row was
/// drawn with as [LoopChatRouteHeading] (decision 0132): the room's header
/// then has it from its first frame. The `/chat/channel/` link would redirect
/// there too, but a redirect drops typed navigation state.
@visibleForTesting
({String location, DirectMessageTarget? target, LoopChatRouteHeading? heading})?
loopInboxChannelDestination({
  required String? cid,
  required LoopDirectChannelDirectory directory,
  String? communityTitle,
}) {
  if (cid == null || parseLoopStreamChannelCid(cid) == null) return null;
  final encoded = Uri.encodeComponent(cid);
  if (loopChatSurfaceForCid(cid) == LoopChatSurface.communityChat) {
    final location = loopChatLocationForCid(cid);
    if (location != null) {
      final title = communityTitle?.trim();
      return (
        location: location,
        target: null,
        heading: title == null || title.isEmpty
            ? null
            : LoopChatRouteHeading(title: title),
      );
    }
  }
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
      heading: null,
    );
  }
  return (location: '/chat/channel/$encoded', target: null, heading: null);
}

/// A conversation location that cannot open (decision 0168): the stream
/// shell with the Chinese title the inbox carries, and one centred chat
/// state saying why. It never offers a message action.
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
    final navigator = Navigator.of(context);
    return LoopStreamPage(
      archetype: LoopPageArchetype.state,
      title: context.l10n.common_chat,
      updating: loading,
      onBack: navigator.canPop() ? () => unawaited(navigator.maybePop()) : null,
      collection: const SizedBox.shrink(),
      block: SingleChildScrollView(
        child: LoopEmptyState(
          key: const ValueKey<String>('stream-chat-channel-unavailable'),
          illustration: LoopIllustration.chat,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

/// The inbox's collection while there is no connected chat session: the
/// chat illustration, why, and — when the session can be asked again — one
/// retry.
class _StreamUnavailableCard extends StatelessWidget {
  const _StreamUnavailableCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: LoopEmptyState(
        key: const ValueKey<String>('stream-chat-unavailable'),
        illustration: LoopIllustration.chat,
        title: context.l10n.chat_streamInboxStreamChatUnavailableTitle,
        message: message,
        action: onRetry == null
            ? null
            : LoopButton(
                key: const ValueKey<String>('stream-chat-unavailable-retry'),
                label: context.l10n.common_retry,
                icon: 'refresh',
                onPressed: onRetry,
              ),
      ),
    );
  }
}
