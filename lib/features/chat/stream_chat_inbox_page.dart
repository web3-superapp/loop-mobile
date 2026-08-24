import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

@immutable
final class LoopStreamChannelAddress {
  const LoopStreamChannelAddress({required this.type, required this.id});

  final String type;
  final String id;

  @override
  bool operator ==(Object other) {
    return other is LoopStreamChannelAddress &&
        other.type == type &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}

/// Parses the only channel CID shape enabled by LOOP's current Chat product.
LoopStreamChannelAddress? parseLoopStreamChannelCid(String cid) {
  if (cid.isEmpty || cid != cid.trim() || cid.contains('/')) return null;
  final separator = cid.indexOf(':');
  if (separator <= 0 || separator == cid.length - 1) return null;
  final type = cid.substring(0, separator);
  final id = cid.substring(separator + 1);
  if (type != 'messaging' || id.isEmpty || id.contains(':')) return null;
  return LoopStreamChannelAddress(type: type, id: id);
}

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
      appBar: AppBar(automaticallyImplyLeading: false),
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
            final channel = session!.client.channel(
              address.type,
              id: address.id,
            );
            return StreamChannel(
              key: ValueKey<String>(cid),
              channel: channel,
              child: const StreamChannelPage(),
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
