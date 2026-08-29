import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token_session.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';

final streamVideoSessionSourceProvider = Provider<StreamVideoSessionSource>(
  (ref) => _LoopBackendStreamVideoSessionSource(
    ref.watch(loopBootstrapSessionProvider),
    ref.watch(loopStreamTokenSessionProvider),
  ),
);

final streamVideoClientFactoryProvider = Provider<StreamVideoClientFactory>(
  (ref) => const StreamVideoSdkClientFactory(),
);

/// Opaque account-rotation key; never a Stream user ID.
final streamVideoPrincipalKeyProvider = Provider<String?>((ref) {
  return ref.watch(
    loopSessionProvider.select((session) {
      if (!session.canUseProviderBackedFeatures) return null;
      return session.account?.privyUserId;
    }),
  );
});

/// A foreground, principal-bound Video owner created only when watched.
///
/// The owner itself performs no backend or SDK work. The official client is
/// created later by [streamVideoAuthorizationProvider], after backend identity
/// validation. Closing the last foreground consumer retires the owner.
final streamVideoSdkSessionProvider =
    Provider.autoDispose<StreamVideoSdkSession?>((ref) {
      final apiKey = ref.watch(
        appConfigProvider.select(
          (config) => config.streamApiKeyForCurrentBuild,
        ),
      );
      final principalKey = ref.watch(streamVideoPrincipalKeyProvider);
      if (apiKey.isEmpty || principalKey == null) return null;

      final session = StreamVideoSdkSession(
        apiKey: apiKey,
        source: ref.watch(streamVideoSessionSourceProvider),
        clientFactory: ref.watch(streamVideoClientFactoryProvider),
        initialPrincipalKey: principalKey,
      );
      ref.onDispose(() => unawaited(_disposeSessionSafely(session)));
      return session;
    });

/// Connects Video only for a fully verified Privy principal.
///
/// No token value is exposed by this provider. Logout and account changes
/// rebuild the principal-bound owner and invalidate the old authorization.
final streamVideoAuthorizationProvider =
    FutureProvider.autoDispose<StreamVideoSessionAuthorization>((ref) async {
      final principalKey = ref.watch(streamVideoPrincipalKeyProvider);
      final session = ref.watch(streamVideoSdkSessionProvider);
      if (principalKey == null || session == null) {
        return StreamVideoSessionAuthorization.unavailable;
      }
      await session.synchronizePrincipal(principalKey);
      return session.authorize();
    });

Future<void> _disposeSessionSafely(StreamVideoSdkSession session) async {
  try {
    await session.dispose();
  } catch (_) {
    // The retired instance is unreachable and cannot authorize a new user.
  }
}

final class _LoopBackendStreamVideoSessionSource
    implements StreamVideoSessionSource {
  const _LoopBackendStreamVideoSessionSource(
    this._bootstrapSession,
    this._tokenSession,
  );

  final LoopBootstrapSession? _bootstrapSession;
  final LoopStreamTokenSession? _tokenSession;

  @override
  Future<StreamVideoIdentity?> loadIdentity() async {
    final session = _bootstrapSession;
    if (session == null ||
        await session.authorize() != LoopBootstrapAuthorization.authorized) {
      return null;
    }
    final identity = session.identity;
    if (identity == null) return null;
    return StreamVideoIdentity(userId: identity.streamUserId);
  }

  @override
  Future<String> loadToken(String userId) {
    final session = _tokenSession;
    if (session == null) {
      return Future<String>.error(
        const LoopBackendFailure(
          LoopBackendFailureKind.unavailable,
          code: 'stream_token_configuration_unavailable',
        ),
      );
    }
    return session.loadToken(
      product: LoopStreamTokenProduct.video,
      expectedStreamUserId: userId,
    );
  }
}
