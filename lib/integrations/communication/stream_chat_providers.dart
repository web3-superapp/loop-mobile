import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_sdk_session.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';

/// Future backend integration overrides only this narrow source.
///
/// The default never returns a user or token, so merely supplying the public
/// Stream API key cannot create an authenticated connection.
final streamChatSessionSourceProvider = Provider<StreamChatSessionSource>(
  (ref) => const _UnavailableStreamChatSessionSource(),
);

/// Opaque account-rotation key; never a Stream user ID.
final streamChatPrincipalKeyProvider = Provider<String?>((ref) {
  return ref.watch(
    loopSessionProvider.select((session) {
      if (!session.canUseProviderBackedFeatures) return null;
      return session.account?.privyUserId;
    }),
  );
});

/// One active, principal-bound Stream Chat client per application ProviderScope.
///
/// Client construction attaches persistence but performs no provider request.
/// A principal change rebuilds this provider so abandoned SDK initialization
/// can mutate only its retired client/persistence pair, never the next user's.
/// The client is absent when the public API key is absent (for example in the
/// explicit offline preview composition root).
final streamChatSdkSessionProvider = Provider<StreamChatSdkSession?>((ref) {
  final apiKey = ref.watch(
    appConfigProvider.select((config) => config.streamApiKey.trim()),
  );
  if (apiKey.isEmpty) return null;
  final principalKey = ref.watch(streamChatPrincipalKeyProvider);

  final session = StreamChatSdkSession.create(
    apiKey: apiKey,
    source: ref.watch(streamChatSessionSourceProvider),
    principalKey: principalKey,
  );
  ref.onDispose(() => unawaited(_disposeSessionSafely(session)));
  return session;
});

/// Authorizes the SDK only for a fully verified Privy session.
///
/// Authenticated-unverified and preview sessions explicitly clear any Stream
/// user while retaining that user's local offline history.
final streamChatAuthorizationProvider =
    FutureProvider.autoDispose<StreamSessionAuthorization>((ref) async {
      final principalKey = ref.watch(streamChatPrincipalKeyProvider);
      final streamSession = ref.watch(streamChatSdkSessionProvider);
      if (streamSession == null) {
        return StreamSessionAuthorization.unavailable;
      }
      await streamSession.authorizer.synchronizePrincipal(principalKey);
      if (principalKey == null) {
        return StreamSessionAuthorization.unavailable;
      }
      return streamSession.authorizer.authorize();
    });

Future<void> _disposeSessionSafely(StreamChatSdkSession session) async {
  try {
    await session.dispose();
  } catch (_) {
    // The retired instance remains unreachable; disposal cannot authorize it.
  }
}

final class _UnavailableStreamChatSessionSource
    implements StreamChatSessionSource {
  const _UnavailableStreamChatSessionSource();

  @override
  Future<StreamChatIdentity?> loadIdentity() async => null;

  @override
  Future<String> loadToken(String userId) {
    throw StateError('LOOP Stream bootstrap is not configured.');
  }
}
