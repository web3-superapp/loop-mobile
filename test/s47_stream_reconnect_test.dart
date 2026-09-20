import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/integrations/communication/stream_connection.dart';
import 'package:loop_mobile/integrations/communication/stream_failure.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Real-device report 2026-09-19 · F1, second half.
///
/// S44 gave each way of failing its own sentence. It did not change what the
/// retry button retries: with the websocket closed behind a backgrounded app,
/// every press re-ran the same query on the same dead socket and produced the
/// same error, and restoring the network changed nothing. A retry reconnects
/// first now, and so does the page when the app comes back to the foreground.
const String _cid = 'messaging:loop_community_99565a0c000000000000000000000000';
const String _userId = 'loop_3bb585972e3145e7b5f0957803a824ed';

/// A websocket LOOP can open, refuse to open, or find already up.
class _FakeConnection implements LoopStreamConnection {
  _FakeConnection({this.connected = false, this.opens = true});

  bool connected;

  /// Whether [open] brings the socket up. `false` is a reconnect that failed.
  bool opens;

  /// What [open] throws instead of failing quietly, when anything.
  Object? failure;

  int openCalls = 0;

  @override
  bool get isConnected => connected;

  @override
  Future<void> open() async {
    openCalls += 1;
    if (failure case final error?) throw error;
    if (opens) connected = true;
  }
}

Future<void> _pumpBody(
  WidgetTester tester, {
  required StreamChatClient client,
  required _FakeConnection connection,
  required LoopStreamMemberChannelQuery query,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: StreamChat(
        client: client,
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 72),
              Expanded(
                child: LoopStreamMemberChannelBody(
                  client: client,
                  cid: _cid,
                  userId: _userId,
                  composerHint: '发送消息',
                  unresolvedMessage: null,
                  header: null,
                  banner: null,
                  footer: null,
                  keyPrefix: 'community-chat-channel',
                  connection: connection,
                  query: query,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('a read that needs the socket opens one first', () {
    test('a live socket is read over directly', () async {
      final connection = _FakeConnection(connected: true);
      var reads = 0;
      final answer = await loopStreamConnectedRead(connection, () async {
        reads += 1;
        return 'ok';
      });
      expect(answer, 'ok');
      expect(connection.openCalls, 0);
      expect(reads, 1);
    });

    test('a closed socket is opened, then the read runs', () async {
      final connection = _FakeConnection();
      var reads = 0;
      final answer = await loopStreamConnectedRead(connection, () async {
        reads += 1;
        expect(connection.isConnected, isTrue);
        return 'ok';
      });
      expect(answer, 'ok');
      expect(connection.openCalls, 1);
      expect(reads, 1);
    });

    test('a socket that would not open stops the read', () async {
      final connection = _FakeConnection(opens: false);
      var reads = 0;
      await expectLater(
        loopStreamConnectedRead(connection, () async => reads += 1),
        throwsA(isA<LoopStreamNotConnected>()),
      );
      expect(connection.openCalls, 1);
      expect(reads, 0, reason: 'nothing was asked');
    });

    test('a socket that came up under a concurrent reconnect is honoured', () {
      // The SDK's own lifecycle observer may be opening the same socket; its
      // `openConnection` then throws "already in progress" at ours. What
      // matters is whether the socket is up when we look again.
      final connection = _FakeConnection()
        ..failure = const StreamChatError('Connection already available');
      connection.connected = true;
      return expectLater(
        loopStreamConnectedRead(connection, () async => 'ok'),
        completion('ok'),
      );
    });

    test('a failed reconnect that never left the device stays offline', () {
      final block = loopStreamChannelBlockOf(
        LoopStreamNotConnected(
          StreamChatNetworkError.raw(
            code: -1,
            message: 'connection error',
            type: StreamChatNetworkErrorType.connectionError,
          ),
        ),
      );
      expect(block, LoopStreamChannelBlock.offline);
    });

    test('any other failed reconnect names the socket, not membership', () {
      const block = LoopStreamChannelBlock.notConnected;
      expect(
        loopStreamChannelBlockOf(
          const LoopStreamNotConnected(StreamChatError('boom')),
        ),
        block,
      );
      expect(loopStreamChannelBlockOf(const LoopStreamNotConnected()), block);
      expect(loopStreamChannelBlockMessage(block), '没有连上聊天服务，请检查网络后重试。');
      expect(
        loopStreamChannelBlockMessage(block),
        isNot(contains('你还不是这个群的成员')),
      );
      expect(loopStreamChannelBlockKey(block), 'disconnected');
    });

    test('the SDK sentence itself is classified the same way', () {
      expect(
        loopStreamChannelBlockOf(
          const StreamChatError(
            'You cannot use queryChannels without an active connection. '
            'Please call `connectUser` to connect the client.',
          ),
        ),
        LoopStreamChannelBlock.notConnected,
      );
    });
  });

  group('the channel body retries the connection, not just the query', () {
    testWidgets('retry opens the socket and only then asks Stream', (
      tester,
    ) async {
      final client = StreamChatClient('public-key', logLevel: Level.OFF);
      final connection = _FakeConnection(opens: false);
      var queries = 0;

      await _pumpBody(
        tester,
        client: client,
        connection: connection,
        query: () async {
          queries += 1;
          return const <Channel>[];
        },
      );

      // The first read could not open a socket, so it never asked Stream
      // anything — and says exactly that.
      expect(
        find.byKey(
          const ValueKey<String>('community-chat-channel-disconnected'),
        ),
        findsOneWidget,
      );
      expect(find.text('没有连上聊天服务，请检查网络后重试。'), findsOneWidget);
      expect(find.textContaining('你还不是这个群的成员'), findsNothing);
      expect(connection.openCalls, 1);
      expect(queries, 0);

      // The member restores the network and presses retry. The socket opens,
      // the query goes out, and what is on screen afterwards is the query's
      // own answer — not the connection sentence again.
      connection.opens = true;
      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump();

      expect(connection.openCalls, 2);
      expect(connection.isConnected, isTrue);
      expect(queries, 1);
      expect(
        find.byKey(
          const ValueKey<String>('community-chat-channel-disconnected'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-chat-channel-unresolved')),
        findsOneWidget,
      );
      expect(find.text('没有连上聊天服务，请检查网络后重试。'), findsNothing);
    });

    testWidgets('a retry that still cannot connect never blames membership', (
      tester,
    ) async {
      final client = StreamChatClient('public-key', logLevel: Level.OFF);
      final connection = _FakeConnection(opens: false)
        ..failure = const StreamChatError('ws handshake refused');
      var queries = 0;

      await _pumpBody(
        tester,
        client: client,
        connection: connection,
        query: () async {
          queries += 1;
          return const <Channel>[];
        },
      );

      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump();

      expect(connection.openCalls, 2);
      expect(queries, 0, reason: 'a read with no socket was never sent');
      expect(find.text('没有连上聊天服务，请检查网络后重试。'), findsOneWidget);
      expect(find.textContaining('你还不是这个群的成员'), findsNothing);
      expect(find.textContaining('没能打开这个频道的会话'), findsNothing);
    });

    testWidgets('coming back to the app reconnects and re-reads once', (
      tester,
    ) async {
      final client = StreamChatClient('public-key', logLevel: Level.OFF);
      final connection = _FakeConnection(opens: false);
      var queries = 0;

      await _pumpBody(
        tester,
        client: client,
        connection: connection,
        query: () async {
          queries += 1;
          return const <Channel>[];
        },
      );
      expect(connection.openCalls, 1);
      expect(queries, 0);

      connection.opens = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(connection.openCalls, 2);
      expect(queries, 1);
      expect(
        find.byKey(const ValueKey<String>('community-chat-channel-unresolved')),
        findsOneWidget,
      );

      // A second resume over a live socket asks for nothing: the rule is
      // "reconnect when there is no connection", not "re-read on every
      // resume".
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(connection.openCalls, 2);
      expect(queries, 1);
    });
  });
}
