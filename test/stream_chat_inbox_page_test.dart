import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  test('channel route accepts only a well-formed messaging CID', () {
    final address = parseLoopStreamChannelCid('messaging:loop-room-42');
    expect(address?.type, 'messaging');
    expect(address?.id, 'loop-room-42');
    expect(address?.cid, 'messaging:loop-room-42');
    expect(parseLoopStreamChannelCid('livestream:loop-room-42'), isNull);
    expect(parseLoopStreamChannelCid('messaging:'), isNull);
    expect(parseLoopStreamChannelCid(':loop-room-42'), isNull);
    expect(parseLoopStreamChannelCid('messaging:bad/room'), isNull);
    expect(parseLoopStreamChannelCid('messaging:bad\u0000room'), isNull);
    expect(
      parseLoopStreamChannelCid('messaging:${List.filled(256, 'a').join()}'),
      isNull,
    );
  });

  test(
    'channel controller keeps Stream as the bounded list source of truth',
    () {
      final client = StreamChatClient(
        'public-stream-api-key',
        logLevel: Level.OFF,
      );
      final controller = createLoopStreamChannelListController(
        client: client,
        userId: 'loop-user-42',
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      expect(controller.client, same(client));
      expect(
        controller.filter,
        Filter.and(<Filter>[
          Filter.equal('type', 'messaging'),
          Filter.in_('members', <Object>['loop-user-42']),
        ]),
      );
      expect(controller.channelStateSort, const <SortOption<ChannelState>>[
        SortOption<ChannelState>.desc(ChannelSortKey.lastUpdated),
      ]);
      expect(controller.presence, isTrue);
      expect(controller.limit, 20);
      expect(controller.messageLimit, 25);
      expect(controller.memberLimit, 30);
    },
  );

  testWidgets(
    'production inbox stays fail-closed until backend Stream identity exists',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_config()),
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(),
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'Chat'));
      await tester.pumpAndSettle();

      expect(find.byType(StreamChatInboxPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('stream-chat-unavailable')),
        findsOneWidget,
      );
      expect(find.text('Stream not connected'), findsOneWidget);
      expect(find.byType(StreamChannelListView), findsNothing);
    },
  );

  testWidgets('channel route stays fail-closed without authorization', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
        ],
        child: const MaterialApp(
          home: StreamChatChannelRoutePage(cid: 'messaging:loop-room-42'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('stream-chat-channel-unavailable')),
      findsOneWidget,
    );
    expect(find.byType(StreamChannel), findsNothing);
  });

  testWidgets('encoded CID is decoded by the application route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(NavigationBar));
    GoRouter.of(context)
        .go('/chat/channel/${Uri.encodeComponent('messaging:loop-room-42')}');
    await tester.pumpAndSettle();

    expect(find.byType(StreamChatChannelRoutePage), findsOneWidget);
    final page = tester.widget<StreamChatChannelRoutePage>(
      find.byType(StreamChatChannelRoutePage),
    );
    expect(page.cid, 'messaging:loop-room-42');
  });
}

AppConfig _config() {
  return const AppConfig(
    privyAppId: 'privy-app',
    privyAppClientId: 'privy-client',
    streamApiKey: 'public-stream-api-key',
    backendBaseUrl: '',
    firebaseConfigured: false,
  );
}
