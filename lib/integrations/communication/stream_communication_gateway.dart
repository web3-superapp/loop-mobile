import 'package:loop_mobile/integrations/communication/communication_gateway.dart';

enum StreamSessionAuthorization { authorized, unavailable }

/// Establishes or refreshes the Stream user session before every SDK operation.
///
/// A production implementation obtains a short-lived user token from the BFF
/// and connects that token through the SDK bridge. Token material is never
/// returned to application UI code.
abstract interface class StreamSessionAuthorizer {
  Future<StreamSessionAuthorization> authorize();
}

/// A narrow bridge for the selected Stream Chat + Stream Video/Audio Rooms SDKs.
///
/// No Stream API secret or user token belongs in the mobile repository. A
/// production bridge may receive the public Stream API key from configuration,
/// but user tokens must be short-lived and issued by the BFF. The selected
/// provider is not live until that bridge is supplied and verified.
abstract interface class StreamCommunicationBridge {
  Future<List<ConversationSummary>> loadConversations();

  Future<List<ConversationMessage>> loadMessages(String conversationId);

  Future<ConversationMessage> sendText({
    required String conversationId,
    required String text,
  });

  Future<List<MessageSearchResult>> searchMessages({
    required String query,
    String? conversationId,
  });

  Future<List<MessageRequestSummary>> loadMessageRequests();

  Future<void> acceptMessageRequest(String requestId);

  Future<void> ignoreMessageRequest(String requestId);

  Future<void> reportMessageRequest({
    required String requestId,
    required String reason,
  });

  Future<VoiceRoomSummary> joinVoiceRoom({
    required String roomId,
    required bool microphoneMuted,
  });

  Future<void> leaveVoiceRoom(String roomId);

  Future<void> setMicrophoneMuted({
    required String roomId,
    required bool muted,
  });
}

class StreamCommunicationGateway implements CommunicationGateway {
  const StreamCommunicationGateway({
    required this.bridge,
    required this.authorizer,
  });

  /// The selected production seam. It intentionally performs no network work
  /// until both an SDK bridge and a session authorizer are configured.
  const StreamCommunicationGateway.unconfigured()
    : bridge = null,
      authorizer = null;

  final StreamCommunicationBridge? bridge;
  final StreamSessionAuthorizer? authorizer;

  @override
  CommunicationMode get mode => CommunicationMode.production;

  @override
  bool get isConfigured => bridge != null && authorizer != null;

  @override
  Future<CommunicationResult<void>> acceptMessageRequest(String requestId) {
    return _run<void>(() => bridge!.acceptMessageRequest(requestId));
  }

  @override
  Future<CommunicationResult<void>> ignoreMessageRequest(String requestId) {
    return _run<void>(() => bridge!.ignoreMessageRequest(requestId));
  }

  @override
  Future<CommunicationResult<VoiceRoomSummary>> joinVoiceRoom({
    required String roomId,
    required bool microphoneMuted,
  }) {
    return _run<VoiceRoomSummary>(
      () => bridge!.joinVoiceRoom(
        roomId: roomId,
        microphoneMuted: microphoneMuted,
      ),
    );
  }

  @override
  Future<CommunicationResult<void>> leaveVoiceRoom(String roomId) {
    return _run<void>(() => bridge!.leaveVoiceRoom(roomId));
  }

  @override
  Future<CommunicationResult<void>> reportMessageRequest({
    required String requestId,
    required String reason,
  }) {
    return _run<void>(
      () => bridge!.reportMessageRequest(requestId: requestId, reason: reason),
    );
  }

  @override
  Future<CommunicationResult<List<ConversationSummary>>> loadConversations() {
    return _run<List<ConversationSummary>>(() => bridge!.loadConversations());
  }

  @override
  Future<CommunicationResult<List<MessageRequestSummary>>>
  loadMessageRequests() {
    return _run<List<MessageRequestSummary>>(
      () => bridge!.loadMessageRequests(),
    );
  }

  @override
  Future<CommunicationResult<List<ConversationMessage>>> loadMessages(
    String conversationId,
  ) {
    return _run<List<ConversationMessage>>(
      () => bridge!.loadMessages(conversationId),
    );
  }

  @override
  Future<CommunicationResult<List<MessageSearchResult>>> searchMessages({
    required String query,
    String? conversationId,
  }) {
    return _run<List<MessageSearchResult>>(
      () =>
          bridge!.searchMessages(query: query, conversationId: conversationId),
    );
  }

  @override
  Future<CommunicationResult<ConversationMessage>> sendText({
    required String conversationId,
    required String text,
  }) {
    return _run<ConversationMessage>(
      () => bridge!.sendText(conversationId: conversationId, text: text),
    );
  }

  @override
  Future<CommunicationResult<void>> setMicrophoneMuted({
    required String roomId,
    required bool muted,
  }) {
    return _run<void>(
      () => bridge!.setMicrophoneMuted(roomId: roomId, muted: muted),
    );
  }

  Future<CommunicationResult<T>> _run<T>(Future<T> Function() operation) async {
    if (!isConfigured) {
      return CommunicationResult<T>.failure(CommunicationFailure.notConfigured);
    }
    StreamSessionAuthorization authorization;
    try {
      authorization = await authorizer!.authorize();
    } catch (_) {
      return CommunicationResult<T>.failure(
        CommunicationFailure.authorizationUnavailable,
      );
    }
    if (authorization != StreamSessionAuthorization.authorized) {
      return CommunicationResult<T>.failure(
        CommunicationFailure.authorizationUnavailable,
      );
    }
    try {
      return CommunicationResult<T>.success(await operation());
    } catch (_) {
      return CommunicationResult<T>.failure(
        const CommunicationFailure(
          code: 'communication_unavailable',
          message: 'Communication is temporarily unavailable.',
        ),
      );
    }
  }
}
