import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_sdk_session.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';

final streamChatSessionSourceProvider = Provider<StreamChatSessionSource>(
  (ref) => _LoopBackendStreamChatSessionSource(
    ref.watch(loopBootstrapSessionProvider),
  ),
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

final class _LoopBackendStreamChatSessionSource
    implements StreamChatSessionSource {
  const _LoopBackendStreamChatSessionSource(this._bootstrapSession);

  final LoopBootstrapSession? _bootstrapSession;

  @override
  Future<StreamChatIdentity?> loadIdentity() async {
    final session = _bootstrapSession;
    if (session == null ||
        await session.authorize() != LoopBootstrapAuthorization.authorized) {
      return null;
    }
    final identity = session.identity;
    if (identity == null) return null;
    return StreamChatIdentity(userId: identity.streamUserId);
  }

  @override
  Future<String> loadToken(String userId) {
    return Future<String>.error(
      const LoopBackendFailure(
        LoopBackendFailureKind.unavailable,
        code: 'stream_token_contract_unavailable',
      ),
    );
  }
}
