import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Whether a chat failure is a connectivity observation rather than an answer.
///
/// House convention (`loop_v2_chain_failure.dart:34-36`,
/// `loop_v2_community_api.dart:611-613`, `dio_loop_group_alias_gateway.dart`):
/// a request that never reached the server — or that timed out on an
/// idempotent read — is *offline*. It is not a service outage and not a
/// refusal, and a page that renders it as an error claims the server answered
/// when it did not (01 §9).
///
/// Two error shapes reach a chat surface, and both carry the distinction
/// explicitly, so nothing here has to guess from a message string:
///
/// * [StreamChatNetworkError.type] — the Stream SDK's own transport cause.
/// * [LoopBackendFailure.kind] — the LOOP token call that authorizes the SDK.
bool loopStreamFailureIsOffline(Object? error) {
  if (error is StreamChatNetworkError) {
    return switch (error.type) {
      StreamChatNetworkErrorType.connectionError ||
      StreamChatNetworkErrorType.connectionTimeout ||
      StreamChatNetworkErrorType.sendTimeout ||
      StreamChatNetworkErrorType.receiveTimeout => true,
      StreamChatNetworkErrorType.transformTimeout ||
      StreamChatNetworkErrorType.badResponse ||
      StreamChatNetworkErrorType.cancel ||
      StreamChatNetworkErrorType.badCertificate ||
      StreamChatNetworkErrorType.unknown => false,
    };
  }
  if (error is LoopBackendFailure) {
    return error.kind == LoopBackendFailureKind.connection ||
        error.kind == LoopBackendFailureKind.timeout;
  }
  return false;
}

/// Why a channel did not open, as far as the client can prove.
///
/// The surface used to render every failed read as "you are not a member".
/// That is an answer only the server can give, and three of the four causes
/// below never asked it: a client with no live websocket, a call that failed
/// on the way, and a query that answered with nothing all left membership
/// untested. Each keeps its own sentence.
enum LoopStreamChannelBlock {
  /// The device never reached Stream, so nothing was asked.
  offline,

  /// Stream answered, and the answer refused this account the channel.
  refused,

  /// Stream answered the membership query and returned no channel for this
  /// account. The channel may not exist yet, or the membership may not have
  /// landed on the provider; the client cannot tell those apart, so the copy
  /// comes from the server's own reason code when the caller has one.
  unresolved,

  /// No answer was produced at all: the SDK had no active connection, the
  /// query timed out, or it failed for a cause the client cannot attribute.
  notOpened,
}

/// Classifies one channel-load outcome. `null` means the query succeeded and
/// resolved to no channel.
LoopStreamChannelBlock loopStreamChannelBlockOf(Object? error) {
  if (error == null) return LoopStreamChannelBlock.unresolved;
  if (loopStreamFailureIsOffline(error)) return LoopStreamChannelBlock.offline;
  if (error is StreamChatNetworkError) {
    return _isAccessRefusal(error.errorCode, error.statusCode)
        ? LoopStreamChannelBlock.refused
        : LoopStreamChannelBlock.notOpened;
  }
  if (error is StreamWebSocketError) {
    return _isAccessRefusal(error.errorCode, error.data?.statusCode)
        ? LoopStreamChannelBlock.refused
        : LoopStreamChannelBlock.notOpened;
  }
  // Everything else — including the SDK's own
  // `StreamChatError('You cannot use queryChannels without an active
  // connection…')` and a `TimeoutException` from its 30s query guard — is a
  // read that produced no answer.
  return LoopStreamChannelBlock.notOpened;
}

/// The two Stream codes that mean "this account may not have this channel",
/// plus the HTTP status that carries them.
bool _isAccessRefusal(ChatErrorCode? code, int? statusCode) =>
    code == ChatErrorCode.notAllowed ||
    code == ChatErrorCode.noAccessToChannels ||
    statusCode == 403;
