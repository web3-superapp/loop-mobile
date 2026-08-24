import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';

/// Future backend integration overrides only this narrow source.
///
/// The default returns no identity and never returns a token, so the public API
/// key alone cannot construct or connect an authenticated Video client.
final streamVideoSessionSourceProvider = Provider<StreamVideoSessionSource>(
  (ref) => const _UnavailableStreamVideoSessionSource(),
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
        appConfigProvider.select((config) => config.streamApiKey.trim()),
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

final class _UnavailableStreamVideoSessionSource
    implements StreamVideoSessionSource {
  const _UnavailableStreamVideoSessionSource();

  @override
  Future<StreamVideoIdentity?> loadIdentity() async => null;

  @override
  Future<String> loadToken(String userId) {
    throw StateError('LOOP Stream Video bootstrap is not configured.');
  }
}
