import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/integrations/communication/stream_failure.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Real-device report 2026-09-19 · F1.
///
/// A member of a community opened its official group and was told they were
/// not a member of it. Only one of the four ways a channel can fail to open is
/// an answer about membership; the other three had never asked. Each cause
/// keeps its own sentence here, and the block that carries it is the size of
/// its own content.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // The page shape the surface actually lives in: the block is handed
          // every pixel the header did not take.
          children: <Widget>[
            const SizedBox(height: 72),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('a channel that did not open says which thing failed', () {
    test('only a refusal from Stream may speak about membership', () {
      expect(
        loopStreamChannelBlockOf(
          StreamChatNetworkError(ChatErrorCode.notAllowed, statusCode: 403),
        ),
        LoopStreamChannelBlock.refused,
      );
      expect(
        loopStreamChannelBlockOf(
          StreamChatNetworkError(ChatErrorCode.noAccessToChannels),
        ),
        LoopStreamChannelBlock.refused,
      );
      expect(
        loopStreamChannelBlockMessage(LoopStreamChannelBlock.refused),
        '你还不是这个群的成员，LOOP 没有打开任何会话。',
      );
    });

    test('a client with no connection, or a failed query, did not ask', () {
      // The SDK's own refusal to query without a live websocket
      // (`client.dart:891`). This is the one that reached the reader as
      // "you are not a member of this group". S47 gave it its own cause —
      // the socket, which a retry can now re-open — see
      // `s47_stream_reconnect_test.dart`.
      expect(
        loopStreamChannelBlockOf(
          const StreamChatError(
            'You cannot use queryChannels without an active connection. '
            'Please call `connectUser` to connect the client.',
          ),
        ),
        LoopStreamChannelBlock.notConnected,
      );
      expect(
        loopStreamChannelBlockOf(TimeoutException('Channel query timed out')),
        LoopStreamChannelBlock.notOpened,
      );
      expect(
        loopStreamChannelBlockOf(
          StreamChatNetworkError(
            ChatErrorCode.internalSystemError,
            statusCode: 500,
          ),
        ),
        LoopStreamChannelBlock.notOpened,
      );
      expect(
        loopStreamChannelBlockMessage(LoopStreamChannelBlock.notOpened),
        '没能打开这个频道的会话，请稍后重试。',
      );
    });

    test('an empty answer takes the server reason code when there is one', () {
      expect(loopStreamChannelBlockOf(null), LoopStreamChannelBlock.unresolved);
      expect(
        loopStreamChannelBlockMessage(
          LoopStreamChannelBlock.unresolved,
          unresolvedMessage: communicationUnavailableReason(
            'COMMUNITY_CHANNEL_MEMBER_SYNCING',
          ),
        ),
        '你的频道成员身份正在同步，稍后即可进入。',
      );
      // Without one it states what it observed and nothing more. It never
      // borrows the refusal's sentence.
      expect(
        loopStreamChannelBlockMessage(LoopStreamChannelBlock.unresolved),
        isNot(contains('你还不是这个群的成员')),
      );
    });

    test('a read that never reached Stream stays offline', () {
      expect(
        loopStreamChannelBlockOf(
          StreamChatNetworkError.raw(
            code: -1,
            message: 'connection error',
            type: StreamChatNetworkErrorType.connectionError,
          ),
        ),
        LoopStreamChannelBlock.offline,
      );
    });

    testWidgets('each cause renders its own sentence and its own key', (
      tester,
    ) async {
      for (final block in <LoopStreamChannelBlock>[
        LoopStreamChannelBlock.refused,
        LoopStreamChannelBlock.notOpened,
        LoopStreamChannelBlock.unresolved,
      ]) {
        await _pump(
          tester,
          LoopStreamChannelStateBlock(
            key: ValueKey<String>(
              'community-chat-channel-${loopStreamChannelBlockKey(block)}',
            ),
            message: loopStreamChannelBlockMessage(block),
            icon: 'warn',
            onRetry: () {},
          ),
        );
        expect(
          find.byKey(
            ValueKey<String>(
              'community-chat-channel-${loopStreamChannelBlockKey(block)}',
            ),
          ),
          findsOneWidget,
          reason: block.name,
        );
        expect(
          find.text(loopStreamChannelBlockMessage(block)),
          findsOneWidget,
          reason: block.name,
        );
      }
    });
  });

  group('the block is the size of its content', () {
    testWidgets('an error never takes the height the page handed it', (
      tester,
    ) async {
      await _pump(
        tester,
        LoopStreamChannelStateBlock(
          message: loopStreamChannelBlockMessage(
            LoopStreamChannelBlock.notOpened,
          ),
          icon: 'warn',
          onRetry: () {},
        ),
      );

      // The height the page handed the block: everything under the header.
      const available = 844.0 - 72.0;
      final block = tester.getSize(
        find.byKey(const ValueKey<String>('loop-stream-channel-state-block')),
      );
      final card = tester.getSize(
        find.byKey(const ValueKey<String>('loop-error-state')),
      );

      // The card carries its own content only, and the block is that card
      // plus a fixed margin — not a share of the page.
      expect(card.height, lessThan(available));
      expect(
        block.height,
        lessThanOrEqualTo(
          card.height + LoopStreamChannelStateBlock.verticalMargin * 2,
        ),
      );

      // Nothing empty sits under the retry button: the card ends at the
      // button plus its own padding.
      final buttonBottom = tester.getRect(find.text('重试')).bottom;
      final cardBottom = tester
          .getRect(find.byKey(const ValueKey<String>('loop-error-state')))
          .bottom;
      expect(cardBottom - buttonBottom, lessThan(40));
    });

    testWidgets('the offline block is sized the same way', (tester) async {
      await _pump(
        tester,
        LoopStreamChannelStateBlock(
          message: loopStreamChannelBlockMessage(
            LoopStreamChannelBlock.offline,
          ),
          offlinePausedActions: const <String>['打开会话', '发消息'],
          onRetry: () {},
        ),
      );

      const available = 844.0 - 72.0;
      final card = tester.getSize(
        find.byKey(const ValueKey<String>('loop-offline-state')),
      );
      expect(card.height, lessThan(available));
    });
  });
}
