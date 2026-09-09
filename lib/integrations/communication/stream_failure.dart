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
