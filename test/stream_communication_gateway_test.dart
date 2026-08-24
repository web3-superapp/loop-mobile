import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';

void main() {
  test('default provider is the fail-closed production Stream seam', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final gateway = container.read(communicationGatewayProvider);

    expect(gateway, isA<StreamCommunicationGateway>());
    expect(gateway.mode, CommunicationMode.production);
    expect(gateway.isConfigured, isFalse);
  });

  test('memory gateway is explicitly marked as offline preview', () {
    final gateway = MemoryCommunicationGateway();

    expect(gateway.mode, CommunicationMode.preview);
    expect(gateway.isConfigured, isTrue);
  });

  test(
    'selected Stream integration remains fail-closed when unconfigured',
    () async {
      const gateway = StreamCommunicationGateway.unconfigured();

      expect(gateway.mode, CommunicationMode.production);
      expect(gateway.isConfigured, isFalse);

      final conversations = await gateway.loadConversations();
      expect(conversations.isSuccess, isFalse);
      expect(
        conversations.failure?.code,
        CommunicationFailure.notConfigured.code,
      );

      final voiceRoom = await gateway.joinVoiceRoom(
        roomId: 'room-preview',
        microphoneMuted: true,
      );
      expect(voiceRoom.isSuccess, isFalse);
      expect(voiceRoom.failure?.code, CommunicationFailure.notConfigured.code);

      final message = await gateway.sendText(
        conversationId: 'group-preview',
        text: 'This must not send',
      );
      expect(message.isSuccess, isFalse);
      expect(message.failure?.code, CommunicationFailure.notConfigured.code);
    },
  );

  test('a bridge without session authorization remains fail-closed', () async {
    final bridge = _RecordingStreamBridge();
    final gateway = StreamCommunicationGateway(
      bridge: bridge,
      authorizer: null,
    );

    final result = await gateway.loadConversations();

    expect(gateway.isConfigured, isFalse);
    expect(result.failure?.code, CommunicationFailure.notConfigured.code);
    expect(bridge.loadConversationCalls, 0);
  });

  test('denied session authorization never invokes the SDK bridge', () async {
    final bridge = _RecordingStreamBridge();
    final authorizer = _TestStreamAuthorizer(
      result: StreamSessionAuthorization.unavailable,
    );
    final gateway = StreamCommunicationGateway(
      bridge: bridge,
      authorizer: authorizer,
    );

    final result = await gateway.loadConversations();

    expect(gateway.isConfigured, isTrue);
    expect(authorizer.calls, 1);
    expect(bridge.loadConversationCalls, 0);
    expect(
      result.failure?.code,
      CommunicationFailure.authorizationUnavailable.code,
    );
  });

  test('authorization errors fail closed before the SDK bridge', () async {
    final bridge = _RecordingStreamBridge();
    final authorizer = _TestStreamAuthorizer(throws: true);
    final gateway = StreamCommunicationGateway(
      bridge: bridge,
      authorizer: authorizer,
    );

    final result = await gateway.loadConversations();

    expect(authorizer.calls, 1);
    expect(bridge.loadConversationCalls, 0);
    expect(
      result.failure?.code,
      CommunicationFailure.authorizationUnavailable.code,
    );
  });

  test('an authorized operation reaches the narrow SDK bridge', () async {
    final bridge = _RecordingStreamBridge();
    final authorizer = _TestStreamAuthorizer(
      result: StreamSessionAuthorization.authorized,
    );
    final gateway = StreamCommunicationGateway(
      bridge: bridge,
      authorizer: authorizer,
    );

    final result = await gateway.loadConversations();

    expect(result.isSuccess, isTrue);
    expect(result.value, isEmpty);
    expect(authorizer.calls, 1);
    expect(bridge.loadConversationCalls, 1);
  });

  test(
    'configured production voice still waits for official Stream CallState',
    () async {
      final bridge = _RecordingStreamBridge();
      final gateway = StreamCommunicationGateway(
        bridge: bridge,
        authorizer: _TestStreamAuthorizer(),
      );
      final container = ProviderContainer(
        overrides: [communicationGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      await container.read(voiceSessionControllerProvider.notifier).join();

      expect(
        container.read(voiceSessionControllerProvider).phase,
        VoiceConnectionPhase.idle,
      );
      expect(bridge.joinVoiceCalls, 0);
    },
  );
}

class _TestStreamAuthorizer implements StreamSessionAuthorizer {
  _TestStreamAuthorizer({
    this.result = StreamSessionAuthorization.authorized,
    this.throws = false,
  });

  final StreamSessionAuthorization result;
  final bool throws;
  int calls = 0;

  @override
  Future<StreamSessionAuthorization> authorize() async {
    calls += 1;
    if (throws) throw StateError('BFF authorization unavailable');
    return result;
  }
}

class _RecordingStreamBridge implements StreamCommunicationBridge {
  int loadConversationCalls = 0;
  int joinVoiceCalls = 0;

  @override
  Future<void> acceptMessageRequest(String requestId) async {}

  @override
  Future<void> ignoreMessageRequest(String requestId) async {}

  @override
  Future<VoiceRoomSummary> joinVoiceRoom({
    required String roomId,
    required bool microphoneMuted,
  }) async {
    joinVoiceCalls += 1;
    return VoiceRoomSummary(
      id: roomId,
      groupId: 'group-preview',
      title: 'Preview room',
      topic: 'Preview only',
      listenerCount: 0,
      speakerCount: 0,
      participants: const <VoiceParticipant>[],
    );
  }

  @override
  Future<void> leaveVoiceRoom(String roomId) async {}

  @override
  Future<List<ConversationSummary>> loadConversations() async {
    loadConversationCalls += 1;
    return const <ConversationSummary>[];
  }

  @override
  Future<List<MessageRequestSummary>> loadMessageRequests() async {
    return const <MessageRequestSummary>[];
  }

  @override
  Future<List<ConversationMessage>> loadMessages(String conversationId) async {
    return const <ConversationMessage>[];
  }

  @override
  Future<void> reportMessageRequest({
    required String requestId,
    required String reason,
  }) async {}

  @override
  Future<List<MessageSearchResult>> searchMessages({
    required String query,
    String? conversationId,
  }) async {
    return const <MessageSearchResult>[];
  }

  @override
  Future<ConversationMessage> sendText({
    required String conversationId,
    required String text,
  }) async {
    return ConversationMessage(
      id: 'message-preview',
      conversationId: conversationId,
      senderId: 'user-preview',
      senderAlias: 'Preview user',
      timeLabel: 'Preview',
      kind: MessageKind.text,
      text: text,
      isMine: true,
    );
  }

  @override
  Future<void> setMicrophoneMuted({
    required String roomId,
    required bool muted,
  }) async {}
}
