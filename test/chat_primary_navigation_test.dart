import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

import 'support/loop_ground_probe.dart';

void main() {
  loopWatchGround();
  for (final width in <double>[360, 390]) {
    testWidgets(
      'chat is the first primary destination with usable targets at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              privyAuthGatewayProvider.overrideWithValue(
                const AuthenticatedTestPrivyGateway(),
              ),
              communicationGatewayProvider.overrideWithValue(
                MemoryCommunicationGateway(),
              ),
            ],
            child: const LoopApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(LoopShell.destinationLabels, ['聊天', '广场', 'MEME', '情报', '钱包']);
        expect(
          find.byKey(const ValueKey('community-chat-segment')),
          findsNothing,
        );
        final chatTab = find.widgetWithText(LoopTabItem, '聊天');
        expect(chatTab, findsOneWidget);
        expect(tester.getSize(chatTab).height, greaterThanOrEqualTo(48));
        await tester.tap(chatTab);
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));
        expect(router.state.matchedLocation, '/chat');
        expect(
          tester
              .widget<VoiceRoomMinimizedBanner>(
                find.byType(VoiceRoomMinimizedBanner),
              )
              .onTabRoute!(),
          isTrue,
        );
        expect(find.byType(LoopTabBar), findsOneWidget);
        expect(
          tester
              .widget<LoopTabItem>(find.widgetWithText(LoopTabItem, '聊天'))
              .selected,
          isTrue,
        );
        expect(find.byTooltip('返回社区'), findsNothing);
        expect(find.byTooltip('Change display alias'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('chat-friends-action')));
        await tester.pumpAndSettle();
        expect(router.state.matchedLocation, '/profile/connections');
        expect(find.byType(LoopTabBar), findsNothing);
        router.pop();
        await tester.pumpAndSettle();
        expect(router.state.matchedLocation, '/chat');
        expect(find.byType(LoopTabBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
