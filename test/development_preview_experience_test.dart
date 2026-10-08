import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/preview_conversation_identity.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/loop_ground_probe.dart';

void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

  testWidgets('explicit Preview opens an interactive offline Chat', (
    tester,
  ) async {
    final communicationGateway = MemoryCommunicationGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const UnconfiguredPrivyAuthGateway(),
          ),
          developmentPreviewEnabledProvider.overrideWithValue(true),
          communicationGatewayProvider.overrideWithValue(communicationGateway),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    final previewButton = find.byKey(
      const ValueKey<String>('enter-development-preview-button'),
    );
    await tester.ensureVisible(previewButton);
    await tester.pump();
    await tester.tap(previewButton);
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byKey(const ValueKey<String>('chat-tab-screen'))),
    );

    router.go('/chat');
    await tester.pumpAndSettle();

    // Decision 0110: the 聊天 tab is Stream's own list and closes in Preview,
    // so it lists no fixture. The Preview conversations stay reachable at
    // their own guarded locations.
    expect(
      find.byKey(const ValueKey<String>('stream-chat-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Glyph Hunters'), findsNothing);
    expect(find.text('0xSable'), findsNothing);

    final location = PreviewConversationIdentity.locationForSummary(
      conversationId: ChatContent.groupId,
      kind: ConversationKind.group,
    );
    expect(location, isNotNull);
    unawaited(router.push<void>(location!));
    await tester.pumpAndSettle();

    expect(
      find.text('Offline preview · simulated conversation'),
      findsOneWidget,
    );
    expect(find.text('NightOwl'), findsWidgets);
    // The type ladder (decision 0069) made the transcript taller than one
    // viewport, so the token card sits below the lazily built window.
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(find.text('GLYPH'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Local preview hello');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    final messages = await communicationGateway.loadMessages(
      ChatContent.groupId,
    );
    expect(messages.value?.last.text, 'Local preview hello');
    expect(
      find.text('Simulated message added to the offline preview.'),
      findsOneWidget,
    );
  });
}
