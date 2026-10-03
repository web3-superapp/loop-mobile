import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/integrations/personalization/memory_profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/social/social_qr.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_inbox_page.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';

import 'support/community_test_harness.dart';

void main() {
  for (final hasId in [true, false]) {
    testWidgets('personal QR requires a profile ID: $hasId', (tester) async {
      await pumpCommunityPage(
        tester,
        const ChatInboxPage(),
        overrides: [
          communicationGatewayProvider.overrideWithValue(
            MemoryCommunicationGateway(),
          ),
          profileGatewayProvider.overrideWithValue(
            MemoryProfileGateway(
              initialResource: ProfileResource(
                version: 1,
                values: ProfileValues(alias: 'QuietComet', avatarRef: null),
                updatedAt: DateTime.utc(2026, 10, 3),
                loopId: hasId ? 'LOOP-7HJKMNPQ' : null,
              ),
            ),
          ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('chat-create-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的二维码'));
      await tester.pumpAndSettle();
      if (hasId) {
        expect(find.byType(SocialQrSymbol), findsOneWidget);
        expect(find.text('LOOP-7HJKMNPQ · 扫码加好友'), findsOneWidget);
      } else {
        expect(find.byType(SocialQrSymbol), findsNothing);
        final host = tester.state<LoopToastHostState>(
          find.byType(LoopToastHost),
        );
        expect(host.current?.kind, LoopToastKind.warn);
      }
    });
  }
  for (final preview in [true, false]) {
    testWidgets(
      '${preview ? 'preview' : 'production'} inbox has one mobile title and existing tools',
      (tester) async {
        await pumpCommunityPage(
          tester,
          preview ? const ChatInboxPage() : const StreamChatInboxPage(),
          size: const Size(320, 700),
          overrides: [
            if (preview)
              communicationGatewayProvider.overrideWithValue(
                MemoryCommunicationGateway(),
              ),
          ],
        );
        expect(find.text('聊天'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('community-chat-segment')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('chat-friends-action')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('chat-create-menu')), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('chat-friends-action')))
              .height,
          greaterThanOrEqualTo(44),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
