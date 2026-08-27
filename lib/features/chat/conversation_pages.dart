import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/preview_conversation_identity.dart';
import 'package:loop_mobile/features/chat/preview_conversation_unavailable_page.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class GroupChatPage extends StatelessWidget {
  const GroupChatPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final target = PreviewConversationIdentity.resolve(
      conversationId: conversationId,
      kind: ConversationKind.group,
    );
    if (target == null) return const PreviewConversationUnavailablePage();
    return _ConversationPage(target: target);
  }
}

class DirectMessagePage extends StatelessWidget {
  const DirectMessagePage({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final target = PreviewConversationIdentity.resolve(
      conversationId: conversationId,
      kind: ConversationKind.direct,
    );
    if (target == null) return const PreviewConversationUnavailablePage();
    return _ConversationPage(target: target);
  }
}

class _ConversationPage extends ConsumerWidget {
  const _ConversationPage({required this.target});

  final PreviewConversationTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationId = target.id;
    final title = target.title;
    final direct = target.kind == ConversationKind.direct;
    final gateway = ref.watch(communicationGatewayProvider);
    final preview = gateway.mode == CommunicationMode.preview;
    final connectionLabel = preview
        ? 'Offline preview · simulated conversation'
        : gateway.isConfigured
        ? 'Stream presence not verified'
        : 'Stream not connected';
    final messages = ref.watch(conversationMessagesProvider(conversationId));
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: 'Back to chats',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            ChatAvatar(
              label: title,
              size: 36,
              colorSeed: direct ? 4 : 2,
              icon: direct ? null : Icons.groups_rounded,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    connectionLabel,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: LoopColors.vapor),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (!direct)
            IconButton(
              onPressed: () => context.push('/chat/voice'),
              tooltip: 'Open voice room',
              icon: const Icon(Icons.graphic_eq_rounded),
            ),
          IconButton(
            onPressed: () => context.push(target.searchLocation),
            tooltip: 'Search this conversation',
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            onPressed: direct
                ? () => _showDirectActions(context)
                : () => context.push(
                    PreviewConversationIdentity.groupInfoLocation(target.id)!,
                  ),
            tooltip: direct ? 'Conversation settings' : 'Group information',
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: LoopBackdrop()),
            Column(
              children: <Widget>[
                if (!direct) const _PinnedMessageBanner(),
                if (direct) const _DirectProtectionNote(),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: messages.when(
                        data: (items) => CustomScrollView(
                          reverse: false,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          slivers: <Widget>[
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                20,
                              ),
                              sliver: SliverList.list(
                                children: <Widget>[
                                  if (!direct) ...<Widget>[
                                    const InlineVoiceRoomCard(),
                                    const SizedBox(height: 22),
                                  ],
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: LoopColors.basalt,
                                        border: Border.all(
                                          color: LoopColors.line,
                                        ),
                                        borderRadius: LoopRadius.pill,
                                      ),
                                      child: Text(
                                        'Today',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  for (
                                    var index = 0;
                                    index < items.length;
                                    index++
                                  )
                                    ChatMessageTile(
                                      message: items[index],
                                      colorSeed: index + (direct ? 4 : 1),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        loading: () => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (error, stackTrace) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: LoopStateCard(
                              title: 'Messages are unavailable',
                              message: 'Check your connection, then try again.',
                              icon: Icons.cloud_off_outlined,
                              tone: LoopTone.warning,
                              action: OutlinedButton.icon(
                                onPressed: () => ref.invalidate(
                                  conversationMessagesProvider(conversationId),
                                ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try again'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ChatComposer(
                  enabled: preview || gateway.isConfigured,
                  hintText: preview
                      ? 'Simulate a message in this preview'
                      : direct
                      ? 'Message 0xSable'
                      : 'Message Glyph Hunters',
                  onSend: (text) async {
                    final result = await ref
                        .read(communicationGatewayProvider)
                        .sendText(conversationId: conversationId, text: text);
                    if (!context.mounted) return;
                    if (result.isSuccess) {
                      ref.invalidate(
                        conversationMessagesProvider(conversationId),
                      );
                      if (preview) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Simulated message added to the offline preview.',
                              ),
                            ),
                          );
                      }
                    } else {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Message not sent. Check your connection.',
                            ),
                          ),
                        );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedMessageBanner extends StatelessWidget {
  const _PinnedMessageBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LoopColors.basalt,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Pinned: Review the unlock schedule before sharing a call.',
                ),
              ),
            );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: LoopColors.line),
              bottom: BorderSide(color: LoopColors.line),
            ),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.push_pin_outlined,
                size: 17,
                color: LoopColors.chat,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Pinned · Review the unlock schedule before sharing a call.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: LoopColors.chalk),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: LoopColors.vapor),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectProtectionNote extends StatelessWidget {
  const _DirectProtectionNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: LoopColors.chat.withValues(alpha: 0.06),
        border: const Border(
          top: BorderSide(color: LoopColors.line),
          bottom: BorderSide(color: LoopColors.line),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.shield_outlined, size: 15, color: LoopColors.chat),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Message protection follows your current account and service settings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showDirectActions(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Mute notifications'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('Block account'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: LoopColors.danger,
                ),
                title: const Text('Report conversation'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}
