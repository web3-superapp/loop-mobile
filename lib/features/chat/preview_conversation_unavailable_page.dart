import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class PreviewConversationUnavailablePage extends StatelessWidget {
  const PreviewConversationUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: '开发预览',
      title: 'Preview conversation unavailable',
      subtitle: 'No local fixture matches this exact conversation identity.',
      children: <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('preview-conversation-unavailable'),
          title: 'Conversation not found',
          message: 'The Preview did not substitute another group, direct message, room, or meeting. Return to Chats and choose a listed item.',
          icon: Icons.forum_outlined,
          tone: LoopTone.warning,
          action: FilledButton.icon(
            onPressed: () => context.go('/chat'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to Chats'),
          ),
        ),
      ],
    );
  }
}
