import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_server_clock.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_policy.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_outgoing_message_order.dart';
import 'package:loop_mobile/integrations/communication/stream_server_clock_source.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_connection.dart';
import 'package:loop_mobile/integrations/communication/stream_failure.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The Lime Ledger surface for one official Stream channel.
///
/// LOOP owns only the locator, the chrome and the copy. Message history,
/// pagination, delivery state, read state, threads, reactions and the composer
/// stay with the official Stream widgets, so no LOOP DTO ever mirrors a
/// provider fact. The composer sends text and pictures; voice recording is
/// disabled application wide. This surface only restates the placeholder.
class LoopStreamChannelSurface extends ConsumerWidget {
  const LoopStreamChannelSurface({
    required this.cid,
    required this.composerHint,
    super.key,
    this.header,
    this.banner,
    this.notConnectedMessage = '这个会话暂时打不开，稍后再试。',
    this.unresolvedMessage,
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

  /// What to say when Stream answers the membership query with no channel for
  /// this account. The caller passes the sentence its own server reason code
  /// maps to; without one the surface states only what it observed.
  final String? unresolvedMessage;

  /// The key prefix for this surface's state blocks. A page passes its own
  /// slug so an acceptance assertion names that page rather than the shared
  /// surface that happened to render.
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (parseLoopStreamChannelCid(cid) == null) {
      return LoopStreamChannelStateBlock(
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
          loading: () => LoopStreamChannelStateBlock(
            key: ValueKey<String>('$keyPrefix-connecting'),
            message: '正在恢复聊天会话…',
            loading: true,
          ),
          // A token call that never reached the server has not refused
          // anything: the conversation is paused, not broken. Only a server
          // answer may render as an error.
          error: (error, stackTrace) => loopStreamFailureIsOffline(error)
              ? LoopStreamChannelStateBlock(
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
              : LoopStreamChannelStateBlock(
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
              return LoopStreamChannelStateBlock(
                key: ValueKey<String>('$keyPrefix-not-connected'),
                message: notConnectedMessage,
                icon: 'warn',
                onRetry: () => ref.invalidate(streamChatAuthorizationProvider),
              );
            }
            return LoopStreamMemberChannelBody(
              key: ValueKey<String>('$keyPrefix-$cid-${currentUser.id}'),
              client: session.client,
              cid: cid,
              userId: currentUser.id,
              composerHint: composerHint,
              unresolvedMessage: unresolvedMessage,
              header: header,
              banner: banner,
              keyPrefix: keyPrefix,
            );
          },
        );
  }
}

/// Resolves the one channel a surface shows, or nothing.
///
/// The surface supplies Stream's membership query; a test supplies its own
/// answer. It is called only with a live websocket — see
/// [loopStreamConnectedRead].
typedef LoopStreamMemberChannelQuery = Future<List<Channel>> Function();

/// Server-side membership proof before any official channel UI mounts.
///
/// A channel-list query cannot create a missing channel, unlike
/// `client.channel(...).watch()`. A CID the account is not a member of simply
/// resolves to nothing.
///
/// Every LOOP conversation — direct message, community official group, friend
/// group — mounts through this one body, so the connect-before-read rule
/// (device report 2026-09-19 · F1) is stated once and holds for all three.
class LoopStreamMemberChannelBody extends StatefulWidget {
  const LoopStreamMemberChannelBody({
    required this.client,
    required this.cid,
    required this.userId,
    required this.composerHint,
    required this.unresolvedMessage,
    required this.header,
    required this.banner,
    required this.keyPrefix,
    super.key,
    this.connection,
    this.query,
  });

  final StreamChatClient client;
  final String cid;
  final String userId;
  final String composerHint;
  final String? unresolvedMessage;
  final Widget? header;
  final Widget? banner;
  final String keyPrefix;

  /// The websocket this body reads over. Defaults to [client]'s own.
  final LoopStreamConnection? connection;

  /// The membership query. Defaults to Stream's channel-list query for
  /// [cid] and [userId].
  final LoopStreamMemberChannelQuery? query;

  @override
  State<LoopStreamMemberChannelBody> createState() =>
      _LoopStreamMemberChannelBodyState();
}

class _LoopStreamMemberChannelBodyState
    extends State<LoopStreamMemberChannelBody>
    with WidgetsBindingObserver {
  late Future<Channel?> _channel;
  late LoopStreamConnection _connection;
  LoopOutgoingMessageOrder? _outgoingOrder;
  StreamSubscription<Event>? _clockSource;

  /// Whether a resume has already asked this body to reconnect and is still
  /// waiting for the answer. One resume buys one attempt; a failed attempt
  /// leaves the retry button and does not schedule another by itself.
  bool _resumeReadInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connection =
        widget.connection ?? LoopStreamClientConnection(widget.client);
    _clockSource = loopWatchStreamServerClock(widget.client);
    _channel = _start();
  }

  @override
  void didUpdateWidget(covariant LoopStreamMemberChannelBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client) ||
        !identical(oldWidget.connection, widget.connection) ||
        oldWidget.cid != widget.cid ||
        oldWidget.userId != widget.userId) {
      unawaited(_clockSource?.cancel());
      _connection =
          widget.connection ?? LoopStreamClientConnection(widget.client);
      _clockSource = loopWatchStreamServerClock(widget.client);
      _reload();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _outgoingOrder?.dispose();
    _outgoingOrder = null;
    unawaited(_clockSource?.cancel());
    _clockSource = null;
    super.dispose();
  }

  /// The OS closes the websocket behind a backgrounded app, and nothing on
  /// screen says so: the page the member comes back to is the page they left,
  /// and until S47 the only way out of it was a retry that re-ran the same
  /// query on the same dead socket. Coming back to the app now re-opens the
  /// socket and re-reads, once.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;
    if (_resumeReadInFlight || _connection.isConnected) return;
    _resumeReadInFlight = true;
    setState(_reload);
  }

  void _reload() {
    _outgoingOrder?.dispose();
    _outgoingOrder = null;
    _channel = _start();
  }

  /// Starts one read and keeps its failure off the zone's uncaught handler.
  ///
  /// `setState` only schedules the rebuild that re-subscribes the
  /// `FutureBuilder`, so a read that fails before that frame has no listener
  /// yet and is reported as an unhandled exception — one per retry press, as
  /// the 2026-09-19 device log shows. `ignore()` claims the failure without
  /// consuming it: the builder still receives it and still renders the block.
  Future<Channel?> _start() {
    final pending = _load();
    pending.ignore();
    return pending;
  }

  /// One read, over a socket this method opens first when there is none.
  Future<Channel?> _load() async {
    try {
      return await loopStreamConnectedRead(_connection, _resolve);
    } finally {
      _resumeReadInFlight = false;
    }
  }

  Future<Channel?> _resolve() async {
    final channels = await (widget.query ?? _queryMemberChannel)();
    if (channels.length != 1) return null;
    final channel = channels.single;
    if (channel.cid != widget.cid ||
        channel.state == null ||
        channel.membership?.userId != widget.userId) {
      return null;
    }
    // Attached here, before the Stream widgets below subscribe to the same
    // channel state, so an out-of-order stamp is corrected in the same
    // microtask drain and no frame is painted with the message misplaced.
    _outgoingOrder = LoopOutgoingMessageOrder(channel: channel)..attach();
    return channel;
  }

  Future<List<Channel>> _queryMemberChannel() =>
      widget.client.queryChannelsOnline(
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Channel?>(
      future: _channel,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return LoopStreamChannelStateBlock(
            key: ValueKey<String>('${widget.keyPrefix}-confirming'),
            message: '正在确认这个频道以及你的成员身份…',
            loading: true,
          );
        }
        // The membership query is the same read: a query that never reached
        // Stream did not disprove membership, so it pauses rather than
        // claiming the account is not a member. Every other cause gets its
        // own sentence too — see [loopStreamChannelBlockOf].
        if (snapshot.hasError || snapshot.data == null) {
          final block = loopStreamChannelBlockOf(snapshot.error);
          if (kDebugMode && snapshot.error != null) {
            // The real class and the provider's own words stay here. They are
            // the only account of what failed, and neither is a sentence for
            // a reader.
            debugPrint(
              'LOOP channel blocked: ${block.name} · ${widget.cid} · '
              '${snapshot.error.runtimeType} · ${snapshot.error}',
            );
          }
          if (block == LoopStreamChannelBlock.offline) {
            return LoopStreamChannelStateBlock(
              key: ValueKey<String>('${widget.keyPrefix}-offline'),
              offlinePausedActions: const <String>['打开会话', '发消息', '搜索', '转发'],
              message: '设备当前离线，没有确认这个频道的成员身份，也没有发送任何消息。',
              onRetry: () => setState(_reload),
            );
          }
          return LoopStreamChannelStateBlock(
            key: ValueKey<String>(
              '${widget.keyPrefix}-${loopStreamChannelBlockKey(block)}',
            ),
            message: loopStreamChannelBlockMessage(
              block,
              unresolvedMessage: widget.unresolvedMessage,
            ),
            icon: 'warn',
            onRetry: () => setState(_reload),
          );
        }
        return loopStreamChannelScope(
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

/// Exposes an already-loaded channel to the official Stream widgets without
/// letting them reposition its loaded window.
///
/// `StreamChannel` (the default constructor) repositions on mount: when the
/// channel has unread messages it re-queries around the last-read message,
/// and that query calls `state.truncate()` and holds `isUpToDate = false`
/// until the server answers
/// (`stream_chat-10.3.0/lib/src/client/channel.dart:2175` and
/// `stream_chat_flutter_core-10.3.0/lib/src/stream_channel.dart:518`). For the
/// first seconds inside a room that means the message list is emptied and
/// every `message.new` event is dropped — including the echo of what the
/// member just typed (`channel.dart:3335`). If the last-read anchor lands in
/// the middle of the returned window, `_bottomPaginationEnded` stays false and
/// `isUpToDate` never comes back, so live messages stop arriving for the whole
/// visit.
///
/// LOOP's rooms always open at the newest messages, and the membership query
/// that mounts this surface has already loaded them, so there is nothing to
/// reposition. `StreamChannel.value` keeps that window and leaves
/// `isUpToDate` true.
///
/// The cost: no automatic jump to the first unread message. Unread messages
/// older than the loaded window are reached by scrolling up, the same gesture
/// as reading any older message; the list's own unread separator and
/// scroll-to-bottom button are unaffected.
Widget loopStreamChannelScope({
  required Channel channel,
  required Widget child,
  Key? key,
}) => StreamChannel.value(key: key, channel: channel, child: child);

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

  /// The device instant the send left at, so the server's own
  /// `created_at` on the answer can be paired with the right local window.
  DateTime? _sendStartedAt;

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

  /// Stream's answer to a send names the instant the servers filed it at.
  /// That is a free, accurate reading of the server clock on exactly the
  /// action whose timestamp the member is about to look at, so it refines the
  /// offset the next message will be stamped with.
  ///
  /// Only a first send counts. An edit answers with the message's *original*
  /// `created_at`, which would read as a device clock hours or days ahead.
  /// `remoteCreatedAt == null` is the same test the composer itself routes on
  /// (`stream_message_composer.dart:1556`).
  FutureOr<Message> _beforeSend(Message message) {
    _sendStartedAt = message.remoteCreatedAt == null
        ? LoopServerClock.instance.deviceNow()
        : null;
    // The other half of the same step: an `@` in a group or community channel
    // spells the channel Alias, which Stream's own mention filter does not
    // recognize, so the member it names is named with it here and the link
    // leaves with the message (device report 2026-09-20 · R14-2).
    return loopPrepareChannelMessageForSend(
      message: message,
      channel: StreamChannel.of(context).channel,
    );
  }

  void _afterSend(Message message) {
    final serverTime = message.remoteCreatedAt;

    final sentAt = _sendStartedAt;
    _sendStartedAt = null;
    if (serverTime == null || sentAt == null) return;
    LoopServerClock.instance.observe(serverTime: serverTime, sentAt: sentAt);
  }

  void _edit(Message message) {
    _composerController.editMessage(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Decision 0055. In a group or community channel a member is named by the
    // Alias this channel projected, so the `@` overlay is LOOP's: Stream's own
    // one searches and types the account identity. A direct channel keeps
    // Stream's overlay, where the row names the peer from their profile.
    final aliasMentions = loopChannelAutocompleteTriggers(
      StreamChannel.of(context).channel.cid,
    );
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
          preMessageSending: _beforeSend,
          onMessageSent: _afterSend,
          // Pictures go through the one gate in `loop_chat_image_composer.dart`
          // — images only, 10 MB, nine per message — which the component
          // builder applies to every composer, including this one. Voice
          // recording stays off: LOOP has proven no recording capability.
          enableVoiceRecording: false,
          enableMentionsOverlay: aliasMentions.isEmpty,
          customAutocompleteTriggers: aliasMentions,
          allowedAttachmentPickerTypes: loopChatImagePickerTypes,
          attachmentLimit: loopChatImageMaxCount,
          useSystemAttachmentPicker: true,
          placeholderBuilder: (context, placeholder) => widget.composerHint,
        ),
      ],
    );
  }
}

/// zh-CN copy for a channel that did not open.
///
/// One sentence per cause, and none of them claims a fact the client did not
/// observe. [LoopStreamChannelBlock.offline] is not handled here: the offline
/// state names the actions it paused instead of stating a failure.
String loopStreamChannelBlockMessage(
  LoopStreamChannelBlock block, {
  String? unresolvedMessage,
}) => switch (block) {
  // Stream itself refused this account the channel. This is the only case
  // that may name membership.
  LoopStreamChannelBlock.refused => '你还不是这个群的成员，LOOP 没有打开任何会话。',
  // Nothing was asked, so nothing about membership may be said. The socket is
  // the thing that is missing, and the network is where the member looks.
  LoopStreamChannelBlock.notConnected => '没有连上聊天服务，请检查网络后重试。',
  LoopStreamChannelBlock.notOpened => '没能打开这个频道的会话，请稍后重试。',
  LoopStreamChannelBlock.unresolved =>
    unresolvedMessage ?? '这个频道还没有同步到你的账号，LOOP 没有打开任何会话。',
  LoopStreamChannelBlock.offline => '设备当前离线，没有确认这个频道的成员身份，也没有发送任何消息。',
};

/// The key suffix a blocked channel renders under, so an acceptance assertion
/// names the cause and not just "unavailable".
String loopStreamChannelBlockKey(LoopStreamChannelBlock block) =>
    switch (block) {
      LoopStreamChannelBlock.refused => 'not-member',
      LoopStreamChannelBlock.notConnected => 'disconnected',
      LoopStreamChannelBlock.notOpened => 'not-opened',
      LoopStreamChannelBlock.unresolved => 'unresolved',
      LoopStreamChannelBlock.offline => 'offline',
    };

/// One state of a channel surface, sized to its own content.
///
/// It used to be a bare `Padding`, which inside the page's `Expanded` handed
/// its card the whole remaining height: the error read as a tall panel with an
/// empty field under the retry button. It is laid out the way every other
/// closed page is — content-sized, centred in the space it was given, and
/// scrollable, so a long sentence with the keyboard up stays reachable.
class LoopStreamChannelStateBlock extends StatelessWidget {
  const LoopStreamChannelStateBlock({
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

  /// The room a blocked state may take above and below its content. It is a
  /// margin, not a share of the page.
  static const double verticalMargin = 24;

  @override
  Widget build(BuildContext context) {
    // A skeleton is the shape of the list it stands in for, so it keeps the
    // top of the page rather than floating in the middle of it.
    if (loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: LoopSkeleton(type: LoopSkeletonType.list, rows: 4),
        ),
      );
    }
    final paused = offlinePausedActions;
    return _centred(
      paused != null
          ? LoopOfflineState(
              pausedActions: paused,
              onRetry: onRetry,
              margin: EdgeInsets.zero,
            )
          : onRetry == null
          ? LoopEmpty(icon: icon, message: '会话不可用', reason: message)
          : LoopErrorState(
              reason: message,
              onRetry: onRetry,
              margin: EdgeInsets.zero,
            ),
    );
  }

  /// Content height plus [verticalMargin] top and bottom, centred while it
  /// fits and scrollable once it does not.
  ///
  /// `Center` hands the scroll view loose constraints, so the view takes the
  /// height of the card rather than the height of the page; the card's own
  /// `mainAxisSize.min` column then stops it growing. Nothing under the retry
  /// button belongs to the card.
  Widget _centred(Widget child) => Center(
    child: SingleChildScrollView(
      key: const ValueKey<String>('loop-stream-channel-state-block'),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: verticalMargin,
      ),
      child: child,
    ),
  );
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

/// One line of channel context above the message list.
///
/// Presence and the pinned announcement used to be two full-width cards. On a
/// phone that is most of the first screen, and with the keyboard raised it was
/// the part of the conversation the user could no longer read. They are one
/// strip now (decision 0071):
///
/// * every segment the server actually stated, joined by `·`, one line;
/// * nothing at all when the server stated none — an absent fact is not a
///   card explaining its own absence;
/// * nothing while the keyboard is up, because a person who is typing is
///   reading the messages, not the header.
///
/// The strip sits above the list in the same column, so it can never cover a
/// message.
class LoopChatHeaderStrip extends StatelessWidget {
  const LoopChatHeaderStrip({
    super.key,
    this.segments = const <String>[],
    this.collapsed,
  });

  /// Already-formatted, server-stated segments (`在线 128`, `公告 …`). A caller
  /// passes nothing for a fact it does not have; this widget never invents a
  /// zero, a dash or a placeholder sentence.
  final List<String> segments;

  /// Whether the keyboard is up. Pass [loopChatKeyboardIsUp] read from the
  /// screen's own context: a `Scaffold` body's `MediaQuery` has already had
  /// `viewInsets.bottom` removed, so a widget under one cannot see the
  /// keyboard for itself. `null` falls back to the ambient inset.
  final bool? collapsed;

  @override
  Widget build(BuildContext context) {
    final stated = segments
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (stated.isEmpty) return const SizedBox.shrink();
    if (collapsed ?? loopChatKeyboardIsUp(context)) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const ValueKey<String>('loop-chat-header-strip'),
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        children: <Widget>[
          const LoopIcon('info', size: 15, color: LoopColors.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stated.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.caption(11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header context that folds away while the keyboard is up.
///
/// A chat header explains the room; once the user is typing, the messages are
/// what they need to see. This wrapper takes the header out of the column for
/// exactly as long as the keyboard covers the screen, and puts it back when
/// the keyboard goes down. It never overlays the list.
class LoopChatHeaderFold extends StatelessWidget {
  const LoopChatHeaderFold({required this.child, super.key, this.collapsed});

  final Widget child;

  /// See [LoopChatHeaderStrip.collapsed].
  final bool? collapsed;

  @override
  Widget build(BuildContext context) =>
      (collapsed ?? loopChatKeyboardIsUp(context))
      ? const SizedBox.shrink()
      : child;
}

/// Whether the software keyboard currently covers part of the screen.
///
/// Read it from the screen's own `build` context, above its `Scaffold`: with
/// `resizeToAvoidBottomInset` the Scaffold hands its body a `MediaQuery` whose
/// `viewInsets.bottom` is already zero, so a widget inside the body would
/// always answer "no".
bool loopChatKeyboardIsUp(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom > 0;
