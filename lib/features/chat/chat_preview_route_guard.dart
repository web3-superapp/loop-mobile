import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

/// Prevents legacy fixture-backed Chat surfaces from entering production.
///
/// The production inbox and channel routes are owned by Stream's official UI.
/// Secondary pages that still read LOOP preview DTOs may be mounted only by
/// the explicit offline preview composition root.
class ChatPreviewRouteGuard extends ConsumerWidget {
  const ChatPreviewRouteGuard({
    required this.surfaceLabel,
    required this.child,
    super.key,
  });

  final String surfaceLabel;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateway = ref.watch(communicationGatewayProvider);
    if (gateway.mode == CommunicationMode.preview) {
      return Semantics(
        container: true,
        label: '开发预览',
        child: Banner(
          key: const ValueKey<String>('chat-preview-route-label'),
          message: '开发预览',
          location: BannerLocation.topEnd,
          child: child,
        ),
      );
    }

    return LoopPage(
      eyebrow: 'Discuss',
      title: surfaceLabel,
      children: <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('chat-preview-route-blocked'),
          title: 'Offline preview only',
          message: 'This surface still uses development fixtures and is disabled in the production app. Open a server-authorized Stream conversation from Chats instead.',
          icon: Icons.visibility_off_outlined,
          tone: LoopTone.neutral,
          action: FilledButton.icon(
            key: const ValueKey<String>('chat-preview-open-chats'),
            onPressed: () => context.go('/chat'),
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Open Chats'),
          ),
        ),
      ],
    );
  }
}
