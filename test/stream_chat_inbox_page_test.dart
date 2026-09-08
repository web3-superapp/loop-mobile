import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_screen.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
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

  test('channel route lookup requires an exact CID and current membership', () {
    expect(
      createLoopStreamChannelMembershipFilter(
        cid: 'messaging:loop-room-42',
        userId: 'loop-user-42',
      ),
      Filter.and(<Filter>[
        Filter.equal('cid', 'messaging:loop-room-42'),
        Filter.equal('type', 'messaging'),
        Filter.in_('members', <Object>['loop-user-42']),
      ]),
    );
  });

  testWidgets(
    'production inbox stays fail-closed until backend Stream identity exists',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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

      final router = GoRouter.of(
        tester.element(find.byKey(const ValueKey<String>('community-screen'))),
      );
      router.go('/chat');
      await tester.pumpAndSettle();

      expect(find.byType(StreamChatInboxPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('stream-chat-unavailable')),
        findsOneWidget,
      );
      expect(find.text('Stream not connected'), findsOneWidget);
      expect(find.byType(StreamChannelListView), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('stream-audio-room-entry')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-create-menu')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('chat-create-menu')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('chat-create-group-menu-item')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-add-friend-menu-item')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-add-friend-menu-item')),
      );
      await tester.pumpAndSettle();
      // The V1 alias search was folded into the V2 global search in step 3.
      expect(
        find.byKey(const ValueKey<String>('global-search-screen')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the generic Chat inbox no longer offers an Audio Room without a community',
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

      final router = GoRouter.of(
        tester.element(find.byKey(const ValueKey<String>('community-screen'))),
      );
      router.go('/chat');
      await tester.pumpAndSettle();

      // Step 4 made every room a community resource, so the inbox has no
      // locator of its own and must not offer one.
      expect(
        find.byKey(const ValueKey<String>('stream-audio-room-entry')),
        findsNothing,
      );

      // Reached without a capability document the lobby stays closed and
      // requests nothing; no fixture room is ever substituted.
      router.go('/chat/voice');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-capability-unavailable')),
        findsOneWidget,
      );
      expect(find.text('ETH Macro Room'), findsNothing);
      expect(find.textContaining('preview participant'), findsNothing);
      expect(find.text('Connected'), findsNothing);
    },
  );

  testWidgets('the create menu remains visible while Chat loads', (
    tester,
  ) async {
    final authorization = Completer<StreamSessionAuthorization>();
    addTearDown(() {
      if (!authorization.isCompleted) {
        authorization.complete(StreamSessionAuthorization.unavailable);
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streamChatAuthorizationProvider.overrideWith(
            (ref) => authorization.future,
          ),
        ],
        child: const MaterialApp(home: StreamChatInboxPage()),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('stream-chat-connecting')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('stream-audio-room-entry')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-create-menu')),
      findsOneWidget,
    );
  });

  testWidgets('the create menu remains visible after a Chat error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streamChatAuthorizationProvider.overrideWith(
            (ref) => Future<StreamSessionAuthorization>.error(
              StateError('test authorization failure'),
            ),
          ),
        ],
        child: const MaterialApp(home: StreamChatInboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('stream-chat-unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('stream-audio-room-entry')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-create-menu')),
      findsOneWidget,
    );
  });

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

  testWidgets('a channel deep link redirects to the surface its prefix names', (
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

    final router = GoRouter.of(
      tester.element(find.byKey(const ValueKey<String>('community-screen'))),
    );
    const hex = '0123456789abcdef0123456789abcdef';
    for (final (cid, path) in <(String, String)>[
      ('messaging:loop_direct_$hex', '/chat/dm'),
      ('messaging:loop_group_$hex', '/chat/group'),
      ('messaging:loop_community_$hex', '/community/chat'),
    ]) {
      router.go('/chat/channel/${Uri.encodeComponent(cid)}');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path, reason: cid);
    }

    // An unknown channel shape fails closed rather than opening a generic
    // channel page.
    router.go('/chat/channel/${Uri.encodeComponent('messaging:loop-room-42')}');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/community');
  });

  testWidgets(
    'the retired CID-addressed Alias route never reaches a resolver',
    (tester) async {
      final resolver = _RecordingGroupAliasResolverGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_config()),
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(),
            ),
            groupAliasResolverGatewayProvider.overrideWithValue(resolver),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();

      final router = GoRouter.of(
        tester.element(find.byKey(const ValueKey<String>('community-screen'))),
      );
      router.go(
        '/chat/channel/${Uri.encodeComponent('messaging:loop_group_12345678')}'
        '/alias',
      );
      await tester.pumpAndSettle();

      // Step 4 folded the CID-addressed entry into `group-info`, which resolves
      // the LOOP group itself.
      expect(find.byType(StreamGroupAliasChannelRoutePage), findsNothing);
      expect(find.byType(GroupAliasChannelRoutePage), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/community');
      expect(resolver.calls, isEmpty);
    },
  );
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

final class _RecordingGroupAliasResolverGateway
    implements GroupAliasResolverGateway {
  final List<GroupAliasStreamChannelId> calls = <GroupAliasStreamChannelId>[];

  @override
  GroupAliasGatewayMode get mode => GroupAliasGatewayMode.production;

  @override
  Future<GroupId> resolveGroup(GroupAliasStreamChannelId channelId) {
    calls.add(channelId);
    return Future<GroupId>.error(
      const GroupAliasGatewayException(GroupAliasGatewayFailureKind.unexpected),
    );
  }
}
