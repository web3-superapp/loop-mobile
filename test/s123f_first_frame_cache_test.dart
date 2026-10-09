// S123f · decision 0132: first frames drawn from what the device holds.
//
// Audit 2026-10-09 M11 (a conversation opened on a skeleton and a 「暂无名称」
// title; a cold start drew the inbox as a skeleton), M12 (接收 drew its own
// address as a skeleton; the history skeleton was not the shape of its rows)
// and m19 (the owner's face was a monogram on one head and a picture on
// another).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_owner_face.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_faces.dart';
import 'package:loop_mobile/features/profile/presentation/owner_face.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_snapshot.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_connection.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_media_image.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

// ---------------------------------------------------------------------------
// Doubles
// ---------------------------------------------------------------------------

final class _Clock {
  _Clock(this.now);

  DateTime now;

  DateTime call() => now;
}

/// Hands out the same stored values every time, like a stable resource.
final class _StableRestorer implements LoopSnapshotRestorer {
  _StableRestorer(this._values);

  final Map<String, LoopRestoredSnapshot> _values;

  @override
  LoopRestoredSnapshot? restore(String resource) => _values[resource];
}

class _Connected implements LoopStreamConnection {
  @override
  bool get isConnected => true;

  @override
  Future<void> open() async {}
}

class _LocalClient extends StreamChatClient {
  _LocalClient() : super('key', logLevel: Level.OFF);

  @override
  Future<EmptyResponse> markChannelRead(
    String channelId,
    String channelType, {
    String? messageId,
  }) async => EmptyResponse();
}

const String _groupCid =
    'messaging:loop_group_9c1f0f2e5a7b4c3d8e9f0a1b2c3d4e5f';
const String _me = 'me';

Channel _group(StreamChatClient client, {bool member = true}) =>
    Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: _groupCid.split(':').last,
          type: 'messaging',
          ownCapabilities: const <String>[
            'send-message',
            'send-reply',
            'read-events',
          ],
        ),
        membership: Member(userId: member ? _me : 'someone-else'),
        members: <Member>[
          Member(
            userId: _me,
            user: User(id: _me),
          ),
        ],
        messages: <Message>[
          for (var i = 3; i >= 1; i--)
            Message(
              id: 'm$i',
              text: '消息 $i',
              user: User(id: 'other', name: '成员'),
              createdAt: DateTime.utc(
                2026,
                10,
                9,
                12,
              ).subtract(Duration(minutes: i)),
              state: MessageState.sent,
            ),
        ],
      ),
    );

Future<void> _pumpConversation(
  WidgetTester tester, {
  required StreamChatClient client,
  required LoopStreamMemberChannelQuery query,
}) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.record/messages'),
    (call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      null,
    ),
  );
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark.copyWith(
        extensions: [...LoopTheme.dark.extensions.values, loopStreamTheme()],
      ),
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        LoopStreamChatLocalizationsDelegate(),
      ],
      builder: (context, child) => StreamChat(
        client: client,
        themeData: loopStreamChatThemeData(),
        child: child!,
      ),
      home: Scaffold(
        body: LoopStreamMemberChannelBody(
          client: client,
          cid: _groupCid,
          userId: _me,
          composerHint: loopChatComposerHint,
          unresolvedMessage: null,
          header: null,
          banner: null,
          footer: null,
          keyPrefix: 'group-channel',
          connection: _Connected(),
          query: query,
        ),
      ),
    ),
  );
}

Future<void> _disposeConversation(WidgetTester tester, Channel channel) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
  channel.dispose();
}

void main() {
  loopWatchGround();

  // -------------------------------------------------------------------------
  // M11 · a conversation the client holds opens on its messages
  // -------------------------------------------------------------------------
  group('a held conversation', () {
    test('only a loaded channel naming this account counts', () {
      final client = _LocalClient();
      // ignore: invalid_use_of_internal_member
      client.state.currentUser = OwnUser(id: _me);
      expect(
        loopStreamCachedMemberChannel(
          client: client,
          cid: _groupCid,
          userId: _me,
        ),
        isNull,
        reason: 'nothing held, nothing drawn',
      );
      final mine = _group(client);
      // ignore: invalid_use_of_internal_member
      client.state.addChannels(<String, Channel>{_groupCid: mine});
      expect(
        loopStreamCachedMemberChannel(
          client: client,
          cid: _groupCid,
          userId: _me,
        ),
        same(mine),
      );
      expect(
        loopStreamCachedMemberChannel(
          client: client,
          cid: _groupCid,
          userId: 'another-account',
        ),
        isNull,
        reason: 'a channel object is never proof of membership by itself',
      );
      mine.dispose();
    });

    testWidgets('the first frame is the conversation, not a skeleton', (
      tester,
    ) async {
      final client = _LocalClient();
      // ignore: invalid_use_of_internal_member
      client.state.currentUser = OwnUser(id: _me, name: '我');
      final channel = _group(client);
      // ignore: invalid_use_of_internal_member
      client.state.addChannels(<String, Channel>{_groupCid: channel});
      final answer = Completer<List<Channel>>();

      await _pumpConversation(
        tester,
        client: client,
        query: () => answer.future,
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('group-channel-confirming')),
        findsNothing,
      );
      expect(find.text('消息 1'), findsOneWidget);

      // What the reader typed while the query ran survives its answer: the
      // answer is the same channel object, so nothing is remounted.
      await tester.enterText(find.byType(TextField).last, '还在');
      answer.complete(<Channel>[channel]);
      await tester.pumpAndSettle();
      expect(find.text('消息 1'), findsOneWidget);
      expect(find.text('还在'), findsOneWidget);

      await _disposeConversation(tester, channel);
    });

    testWidgets('a failed read keeps the messages already on screen', (
      tester,
    ) async {
      final client = _LocalClient();
      // ignore: invalid_use_of_internal_member
      client.state.currentUser = OwnUser(id: _me, name: '我');
      final channel = _group(client);
      // ignore: invalid_use_of_internal_member
      client.state.addChannels(<String, Channel>{_groupCid: channel});

      await _pumpConversation(
        tester,
        client: client,
        query: () async => throw const SocketException('offline'),
      );
      await tester.pumpAndSettle();

      expect(find.text('消息 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('group-channel-offline')),
        findsNothing,
      );
      await _disposeConversation(tester, channel);
    });

    testWidgets('an answer naming no membership still closes the room', (
      tester,
    ) async {
      final client = _LocalClient();
      // ignore: invalid_use_of_internal_member
      client.state.currentUser = OwnUser(id: _me, name: '我');
      final channel = _group(client);
      // ignore: invalid_use_of_internal_member
      client.state.addChannels(<String, Channel>{_groupCid: channel});

      await _pumpConversation(
        tester,
        client: client,
        query: () async => const <Channel>[],
      );
      await tester.pumpAndSettle();

      expect(find.text('消息 1'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('group-channel-unresolved')),
        findsOneWidget,
      );
      await _disposeConversation(tester, channel);
    });

    testWidgets('with nothing held the room still confirms first', (
      tester,
    ) async {
      final client = _LocalClient();
      // ignore: invalid_use_of_internal_member
      client.state.currentUser = OwnUser(id: _me, name: '我');
      final answer = Completer<List<Channel>>();

      await _pumpConversation(
        tester,
        client: client,
        query: () => answer.future,
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('group-channel-confirming')),
        findsOneWidget,
      );
      answer.complete(const <Channel>[]);
      await tester.pumpAndSettle();
    });
  });

  // -------------------------------------------------------------------------
  // M11 · the room's header has a name from its first frame
  // -------------------------------------------------------------------------
  group('the community room title', () {
    test('never the placeholder', () {
      expect(
        communityChatTitle(detail: null, heading: null, face: null),
        communityChatNeutralTitle,
      );
      expect(
        communityChatTitle(
          detail: null,
          heading: const LoopChatRouteHeading(title: '链上数据观察站 24 号'),
          face: const CommunityFace(name: '别的名字'),
        ),
        '链上数据观察站 24 号',
      );
      expect(
        communityChatTitle(
          detail: null,
          heading: null,
          face: const CommunityFace(name: 'Frog Holders'),
        ),
        'Frog Holders',
      );
      expect(
        communityChatTitle(
          detail: testDetail(),
          heading: const LoopChatRouteHeading(title: '旧名字'),
          face: null,
        ),
        'Frog Holders',
        reason: 'the record wins once it answered',
      );
      expect(LoopChatRouteHeading.of(const Object()), isNull);
      expect(
        LoopChatRouteHeading.of(const LoopChatRouteHeading(title: '  ')),
        isNull,
      );
    });

    testWidgets('the row name is the title while the record loads', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(detail: testDetail())
        ..pending = true;
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(
          communityId: testCommunityId,
          heading: LoopChatRouteHeading(title: '链上数据观察站 24 号'),
        ),
        community: gateway,
        settle: false,
      );

      expect(find.text('链上数据观察站 24 号'), findsOneWidget);
      expect(find.text('暂无名称'), findsNothing);
    });

    testWidgets('with no name known the title says what the room is', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(detail: testDetail())
        ..pending = true;
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: gateway,
        settle: false,
      );

      expect(find.text(communityChatNeutralTitle), findsOneWidget);
      expect(find.text('暂无名称'), findsNothing);
    });

    test('a community row carries its name and opens the room directly', () {
      final cid = loopCommunityChannelCid(testCommunityId)!;
      final destination = loopInboxChannelDestination(
        cid: cid,
        directory: LoopDirectChannelDirectory.empty(),
        communityTitle: 'Frog Holders',
      );
      expect(destination?.location, '/community/chat?id=$testCommunityId');
      expect(destination?.heading?.title, 'Frog Holders');
      expect(destination?.target, isNull);
      // The name travels as navigation state, never in the URL.
      expect(destination?.location.contains('Frog'), isFalse);

      final unnamed = loopInboxChannelDestination(
        cid: cid,
        directory: LoopDirectChannelDirectory.empty(),
      );
      expect(unnamed?.heading, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // M11 · a cold start draws the inbox from this device's own copy
  // -------------------------------------------------------------------------
  group('the inbox while the session connects', () {
    test('an empty or failed local copy keeps the loading shape', () async {
      final client = _LocalClient();
      final empty = LoopLocalChannelListController(
        client: client,
        userId: _me,
        read: () async => const <Channel>[],
      );
      await empty.doInitialLoad();
      expect(empty.value.isSuccess, isFalse);
      expect(loopInboxLocalSeed(client, _me), isNull);
      empty.dispose();

      final failed = LoopLocalChannelListController(
        client: client,
        userId: _me,
        read: () async => throw StateError('no store'),
      );
      await failed.doInitialLoad();
      expect(failed.value.isSuccess, isFalse);
      failed.dispose();
    });

    test('the local rows become the live list\'s first value', () async {
      final client = _LocalClient();
      final channel = _group(client);
      final local = LoopLocalChannelListController(
        client: client,
        userId: _me,
        read: () async => <Channel>[channel],
      );
      await local.doInitialLoad();
      expect(local.value.asSuccess.items, <Channel>[channel]);
      expect(loopInboxLocalSeed(client, _me), <Channel>[channel]);
      expect(loopInboxLocalSeed(client, 'another-account'), isNull);

      final live = createLoopStreamChannelListController(
        client: client,
        userId: _me,
        initialChannels: loopInboxLocalSeed(client, _me),
      );
      expect(live.value.isSuccess, isTrue);
      expect(live.value.asSuccess.items, <Channel>[channel]);
      expect(
        createLoopStreamChannelListController(
          client: client,
          userId: _me,
        ).value.isSuccess,
        isFalse,
        reason: 'without a local copy the live list starts loading',
      );
      local.dispose();
      live.dispose();
      channel.dispose();
    });

    testWidgets('nothing known yet: rows in their own shape', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(body: ChatInboxRowsSkeleton()),
        ),
      );
      final rows = find.descendant(
        of: find.byType(ChatInboxRowsSkeleton),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is LoopSkeletonBlock &&
              widget.width == 40 &&
              widget.height == 40,
        ),
      );
      expect(rows, findsNWidgets(7));
      // One conversation row is about as tall as the tile it stands for.
      final first = tester.getRect(rows.at(0));
      final second = tester.getRect(rows.at(1));
      expect(second.top - first.top, inInclusiveRange(70, 84));
    });
  });

  // -------------------------------------------------------------------------
  // M12 · 接收 and the history tape
  // -------------------------------------------------------------------------
  group('receive', () {
    test('a stored receive answer stays drawable, every time', () {
      final clock = _Clock(DateTime.utc(2026, 10, 9, 8));
      final store = MemoryLoopSnapshotStore();
      final session = LoopV2SnapshotSession(
        store: store,
        principal: 'did:privy:abc',
        clock: clock.call,
      );
      Object? persisted(Object? body) => jsonDecode(jsonEncode(body));
      session.record(
        LoopSnapshotResource.walletReceive(s5WalletId),
        persisted(s5ReceiveBody()),
      );
      session.record(
        LoopSnapshotResource.walletBalances(s5WalletId),
        persisted(s5BalancesBody()),
      );

      clock.now = clock.now.add(const Duration(days: 3));
      final reopened = LoopV2SnapshotSession(
        store: store,
        principal: 'did:privy:abc',
        clock: clock.call,
      );
      final receive = LoopSnapshotResource.walletReceive(s5WalletId);
      expect(reopened.restore(receive)?.value, isA<LoopWalletReceive>());
      expect(
        reopened.restore(receive)?.value,
        isA<LoopWalletReceive>(),
        reason: 'an address does not change: it is drawn on every open',
      );
      expect(
        reopened.restore(LoopSnapshotResource.walletBalances(s5WalletId)),
        isNull,
        reason: 'balances keep the ten-minute window',
      );

      clock.now = clock.now.add(LoopSnapshotPolicy.stableMaxAge);
      expect(reopened.restore(receive), isNull);
    });

    test('the receive resource is known and names its wallet', () {
      final resource = LoopSnapshotResource.walletReceive(s5WalletId);
      expect(LoopSnapshotResource.isKnown(resource), isTrue);
      expect(LoopSnapshotResource.isStable(resource), isTrue);
      expect(LoopSnapshotResource.receiveWalletIdOf(resource), s5WalletId);
      expect(LoopSnapshotResource.walletIdOf(resource), isNull);
      expect(
        LoopSnapshotResource.isStable(LoopSnapshotResource.walletDirectory),
        isFalse,
      );
    });

    testWidgets('the stored addresses are the first frame', (tester) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          receive: S5Answer<LoopWalletReceive>(pending: true),
        ),
        settle: false,
        overrides: [
          loopSnapshotRestorerProvider.overrideWithValue(
            _StableRestorer(<String, LoopRestoredSnapshot>{
              LoopSnapshotResource.walletReceive(
                s5WalletId,
              ): LoopRestoredSnapshot(
                value: s5Receive(),
                observedAt: DateTime.utc(2026, 9, 1),
              ),
            }),
          ),
        ],
      );

      expect(find.byKey(const ValueKey<String>('receive-qr')), findsOneWidget);
      expect(find.text(s5Address), findsOneWidget);
      expect(find.byType(WalletReceiveSkeleton), findsNothing);
      expect(find.byType(LoopSkeleton), findsNothing);
    });

    testWidgets('a first-ever visit loads in the page\'s own shape', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          receive: S5Answer<LoopWalletReceive>(pending: true),
        ),
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('receive-state-loading')),
        findsOneWidget,
      );
      expect(find.byType(WalletReceiveSkeleton), findsOneWidget);
      // The code plate stands where the code will.
      final plate = find.descendant(
        of: find.byType(WalletReceiveSkeleton),
        matching: find.byWidgetPredicate(
          (widget) => widget is LoopSkeletonBlock && widget.width == 232,
        ),
      );
      expect(tester.getSize(plate), const Size(232, 232));
    });
  });

  group('the history tape', () {
    testWidgets('its first page loads under the real chips as its rows', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(pending: true),
        ),
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('tx-history-seg-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tx-history-state-loading')),
        findsOneWidget,
      );
      expect(find.byType(WalletActivitySkeleton), findsOneWidget);
    });

    testWidgets('a placeholder row is as tall as the row it stands for', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final entry = s5Activity().items.first;
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: LoopFlat(
              child: Column(
                children: <Widget>[
                  const WalletActivitySkeleton(
                    key: ValueKey<String>('skeleton'),
                    rows: 1,
                  ),
                  KeyedSubtree(
                    key: const ValueKey<String>('row'),
                    child: walletActivityRow(entry, onTap: () {}),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final skeleton = tester.getSize(
        find.byKey(const ValueKey<String>('skeleton')),
      );
      final row = tester.getSize(find.byKey(const ValueKey<String>('row')));
      expect((skeleton.height - row.height).abs(), lessThanOrEqualTo(4));
      // The mark is the record's 36 circle, not a 44 rounded square.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is LoopSkeletonBlock &&
              widget.width == 36 &&
              widget.radius == 18,
        ),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // m19 · one face for the owner, from the first frame
  // -------------------------------------------------------------------------
  group('the owner face', () {
    test('a stored face is drawn before the profile answers', () {
      const face = LoopOwnerFace(
        alias: 'cy',
        avatarRef: 'avatar:media/3fa85f64-5717-4562-b3fc-2c963f66afa6',
      );
      final container = ProviderContainer(
        overrides: [
          loopSnapshotRestorerProvider.overrideWithValue(
            _StableRestorer(<String, LoopRestoredSnapshot>{
              LoopSnapshotResource.ownerFace: LoopRestoredSnapshot(
                value: face,
                observedAt: DateTime.utc(2026, 10, 1),
              ),
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(ownerFaceProvider), face);
    });

    test('the stored face decodes strictly', () {
      expect(
        LoopOwnerFace.decode(<String, Object?>{
          'alias': 'cy',
          'avatarRef': 'avatar:preset/people-3',
        }),
        const LoopOwnerFace(alias: 'cy', avatarRef: 'avatar:preset/people-3'),
      );
      expect(
        LoopOwnerFace.decode(
          const LoopOwnerFace(alias: 'cy', avatarRef: null).toJson(),
        ),
        const LoopOwnerFace(alias: 'cy', avatarRef: null),
      );
      expect(
        LoopOwnerFace.decode(<String, Object?>{'alias': 'cy', 'x': 1}),
        isNull,
      );
      expect(
        LoopOwnerFace.decode(<String, Object?>{'avatarRef': 'https://x/y'}),
        isNull,
      );
      expect(LoopOwnerFace.decode(<String, Object?>{}), isNull);
      expect(LoopOwnerFace.decode('cy'), isNull);
      expect(
        LoopSnapshotResource.isStable(LoopSnapshotResource.ownerFace),
        isTrue,
      );
    });

    testWidgets('every slot shares one decode of a picture', (tester) async {
      const url = 'https://api.example.com/v2/media/abc.webp';
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: <Widget>[
              LoopRemoteAvatar(url: url, size: 40, fallback: SizedBox()),
              LoopRemoteAvatar(url: url, size: 56, fallback: SizedBox()),
            ],
          ),
        ),
      );
      final images = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image)
          .toList();
      expect(images, hasLength(2));
      expect(images.first, images.last);
      expect(images.first, loopRemoteAvatarImage(const LoopMediaImage(url)));
    });

    testWidgets('a picture kept on this device is read without a download', (
      tester,
    ) async {
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('loop-media-'),
      );
      addTearDown(() => directory!.deleteSync(recursive: true));
      LoopMediaDiskCache.debugDirectory = () async => directory;
      addTearDown(() => LoopMediaDiskCache.debugDirectory = null);

      // A 1×1 PNG, written as the cache would have written it.
      final png = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 1, 1),
          Paint()..color = const Color(0xFFB8FF20),
        );
        final image = await recorder.endRecording().toImage(1, 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      const url = 'https://unreachable.invalid/v2/media/kept.webp';
      await tester.runAsync(() => LoopMediaDiskCache.instance.write(url, png!));
      final kept = await tester.runAsync(
        () => LoopMediaDiskCache.instance.read(url),
      );
      expect(kept, isA<Uint8List>());
      expect(kept, png);

      final info = await tester.runAsync(() {
        final done = Completer<ImageInfo>();
        const LoopMediaImage(url)
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (info, _) {
                  if (!done.isCompleted) done.complete(info);
                },
                onError: (error, stack) {
                  if (!done.isCompleted) done.completeError(error, stack);
                },
              ),
            );
        return done.future;
      });
      expect(info!.image.width, 1);
      expect(
        LoopMediaDiskCache.fileNameFor(url),
        isNot(contains('unreachable')),
      );
    });
  });
}
