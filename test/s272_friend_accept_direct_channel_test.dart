// S272 · decision 0231: accepting a friend request opens the direct channel.
//
// Bug (TestFlight build 40): after a friend request was accepted the 聊天
// tab's 好友 filter still read 「还没有好友会话」. The inbox lists Stream
// channels (`ChatInboxFilter.friends` keeps `loop_direct_` / `loop_group_`
// CIDs), and `POST /v2/message-requests/:id/decision` with `accept` writes
// only the friendship row — no direct channel exists until somebody opens
// the conversation from a profile card. The accepting side now runs the
// backend's idempotent get-or-create right after the accept.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/social/accepted_friend_direct_channel.dart';
import 'package:loop_mobile/features/social/social_controllers.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/community/memory_community_gateways.dart';

const String _cid = 'messaging:loop_direct_0123456789abcdef0123456789abcdef';

void main() {
  group('accepting a message request', () {
    test('opens the direct channel with the requester', () async {
      final chat = _RecordingChatGateway();
      final container = _container(chat: chat);
      addTearDown(container.dispose);
      final controller = container.read(
        messageRequestsControllerProvider.notifier,
      );
      await controller.load();
      final entry = container
          .read(messageRequestsControllerProvider)
          .items
          .single;
      final peer = entry.profile.publicProfileId!;

      final outcome = await controller.decide(
        messageRequestId: entry.messageRequestId,
        decision: MessageRequestDecision.accept,
      );
      expect(outcome, isNotNull);
      await chat.settled;

      expect(chat.opened, <String>[peer]);
      expect(chat.polled, isNotEmpty, reason: 'pending is polled to terminal');
      // The new row is the 好友 filter's kind of row.
      expect(ChatInboxFilter.friends.includes(_cid), isTrue);
    });

    test('ignore and report never open a channel', () async {
      for (final decision in <MessageRequestDecision>[
        MessageRequestDecision.ignore,
        MessageRequestDecision.report,
      ]) {
        final chat = _RecordingChatGateway();
        final container = _container(chat: chat);
        final controller = container.read(
          messageRequestsControllerProvider.notifier,
        );
        await controller.load();
        final entry = container
            .read(messageRequestsControllerProvider)
            .items
            .single;
        await controller.decide(
          messageRequestId: entry.messageRequestId,
          decision: decision,
        );
        await Future<void>.delayed(Duration.zero);
        expect(chat.opened, isEmpty, reason: decision.name);
        container.dispose();
      }
    });

    test('a refused accept opens nothing', () async {
      final chat = _RecordingChatGateway();
      final container = _container(chat: chat, social: _RefusingSocial());
      addTearDown(container.dispose);
      final controller = container.read(
        messageRequestsControllerProvider.notifier,
      );
      await controller.load();
      final entry = container
          .read(messageRequestsControllerProvider)
          .items
          .single;
      final outcome = await controller.decide(
        messageRequestId: entry.messageRequestId,
        decision: MessageRequestDecision.accept,
      );
      await Future<void>.delayed(Duration.zero);
      expect(outcome, isNull);
      expect(chat.opened, isEmpty);
    });

    test('leaving the page mid-flight does not cancel the channel', () async {
      final chat = _RecordingChatGateway();
      final container = _container(chat: chat);
      addTearDown(container.dispose);
      final keep = container.listen(
        messageRequestsControllerProvider,
        (_, _) {},
      );
      final controller = container.read(
        messageRequestsControllerProvider.notifier,
      );
      await controller.load();
      final entry = container
          .read(messageRequestsControllerProvider)
          .items
          .single;
      await controller.decide(
        messageRequestId: entry.messageRequestId,
        decision: MessageRequestDecision.accept,
      );
      keep.close();
      await Future<void>.delayed(Duration.zero);
      expect(await chat.settled, isTrue);
      expect(chat.polled, isNotEmpty);
    });
  });

  group('AcceptedFriendDirectChannel', () {
    test('refreshes the direct-channel index once created', () async {
      final chat = _RecordingChatGateway();
      final container = _container(chat: chat);
      addTearDown(container.dispose);
      final keep = container.listen(directChannelDirectoryProvider, (_, _) {});
      addTearDown(keep.close);
      await container.read(directChannelDirectoryProvider.future);
      expect(chat.listed, 1);

      final ok = await container
          .read(acceptedFriendDirectChannelProvider)
          .ensure('peer-1');
      expect(ok, isTrue);
      await container.read(directChannelDirectoryProvider.future);
      expect(chat.listed, 2);
    });

    test('concurrent calls for one friend share one operation', () async {
      final chat = _RecordingChatGateway();
      final container = _container(chat: chat);
      addTearDown(container.dispose);
      final ensurer = container.read(acceptedFriendDirectChannelProvider);
      final results = await Future.wait(<Future<bool>>[
        ensurer.ensure('peer-1'),
        ensurer.ensure('peer-1'),
      ]);
      expect(results, <bool>[true, true]);
      expect(chat.opened, <String>['peer-1']);
    });

    test('a failure is swallowed and reported as false', () async {
      final chat = _RecordingChatGateway(fail: true);
      final container = _container(chat: chat);
      addTearDown(container.dispose);
      final ok = await container
          .read(acceptedFriendDirectChannelProvider)
          .ensure('peer-1');
      expect(ok, isFalse);
    });

    test('an unavailable chat gateway is not called', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          socialGatewayProvider.overrideWithValue(MemorySocialGateway()),
        ],
      );
      addTearDown(container.dispose);
      final ok = await container
          .read(acceptedFriendDirectChannelProvider)
          .ensure('peer-1');
      expect(ok, isFalse);
    });
  });
}

ProviderContainer _container({
  required _RecordingChatGateway chat,
  SocialGateway? social,
}) => ProviderContainer(
  overrides: <Override>[
    socialGatewayProvider.overrideWithValue(social ?? MemorySocialGateway()),
    chatV2GatewayProvider.overrideWithValue(chat),
  ],
);

final class _RefusingSocial implements SocialGateway {
  final MemorySocialGateway _inner = MemorySocialGateway();

  @override
  CommunityGatewayMode get mode => _inner.mode;

  @override
  Future<MessageRequestPage> listMessageRequests({String? cursor}) =>
      _inner.listMessageRequests(cursor: cursor);

  @override
  Future<MessageRequestOutcome> decideMessageRequest({
    required String messageRequestId,
    required MessageRequestDecision decision,
  }) => Future<MessageRequestOutcome>.error(
    const CommunityGatewayException(CommunityFailureKind.stale),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingChatGateway implements ChatV2Gateway {
  _RecordingChatGateway({this.fail = false});

  final bool fail;
  final List<String> opened = <String>[];
  final List<String> polled = <String>[];
  int listed = 0;
  final Completer<bool> _settled = Completer<bool>();

  Future<bool> get settled => _settled.future;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<ChatOperation> openDirectChannel(String targetPublicProfileId) async {
    opened.add(targetPublicProfileId);
    if (fail) {
      throw const CommunityGatewayException(CommunityFailureKind.unavailable);
    }
    return _operation(terminal: false, target: targetPublicProfileId);
  }

  @override
  Future<ChatOperation> pollOperation(String operationId) async {
    polled.add(operationId);
    final done = _operation(terminal: true, target: opened.last);
    if (!_settled.isCompleted) _settled.complete(true);
    return done;
  }

  @override
  Future<DirectChannelPage> listDirectChannels({String? cursor}) async {
    listed += 1;
    return DirectChannelPage(
      items: const <DirectChannelEntry>[],
      nextCursor: null,
    );
  }

  @override
  Future<void> leaveGroup(String groupId) async {}

  ChatOperation _operation({required bool terminal, required String target}) =>
      ChatOperation(
        operationId: '5d9c1f1e-0d1c-4b8e-9a51-1c7c2f7f9e01',
        kind: ChatOperationKind.directGetOrCreate,
        status: terminal
            ? ChatOperationStatus.succeeded
            : ChatOperationStatus.pending,
        terminal: terminal,
        retryAfterMs: terminal ? null : 1,
        directResult: terminal
            ? ChatDirectChannelResult(
                targetPublicProfileId: target,
                streamCid: _cid,
              )
            : null,
        groupResult: null,
        errorCode: null,
      );
}
