import 'package:loop_mobile/integrations/communication/stream_chat_sdk_session.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';

/// Opens the Stream connection as soon as LOOP has a verified session.
///
/// Decision 0047 counts a community's online members as the official channel
/// members that are connected to Stream *right now* (`queryMembers`'
/// `user.online`). LOOP used to reach [StreamChatSdkSessionAuthorizer.authorize]
/// only from a chat surface, so a signed-in member who had not opened a chat
/// was offline to the provider and every community read 「在线 0 人」 — the
/// count contradicted the member reading it.
///
/// Connecting with the session makes 「App 开着」 mean 「在线」, which is both
/// the member's reading of the number and the one 0047 defines. The SDK owns
/// reconnection from here on.
///
/// This is deliberately not a page read:
///
/// * It costs one chat token per accepted login, inside
///   `STREAM_TOKEN_*_LIMIT_PER_MINUTE`, because [authorize] is single-flight —
///   a chat surface opened afterwards joins this same attempt instead of
///   starting a second one.
/// * It reports nothing. A failed attempt leaves `unavailable` and every page
///   keeps whatever state its own reads produced (S11): no page may turn
///   offline because a background connection did not open.
Future<StreamSessionAuthorization> connectStreamChatForPresence({
  required StreamChatSdkSessionAuthorizer? authorizer,
  required String? principalKey,
}) async {
  // No principal, no client: there is nobody to bring online, and a
  // principal-less authorize would only re-confirm that.
  if (authorizer == null || principalKey == null) {
    return StreamSessionAuthorization.unavailable;
  }
  try {
    // The same two steps `streamChatAuthorizationProvider` performs, in the
    // same order, so the session this opens is the one a chat page later finds
    // already connected.
    await authorizer.synchronizePrincipal(principalKey);
    return await authorizer.authorize();
  } catch (_) {
    // Authorization is fail-closed and silent: presence is a provider fact
    // LOOP asks for, never one it reports a failure about.
    return StreamSessionAuthorization.unavailable;
  }
}
