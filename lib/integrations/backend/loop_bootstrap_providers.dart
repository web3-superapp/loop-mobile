import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/network/loop_dio_factory.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_repository.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

final loopBackendEndpointProvider = Provider<LoopBackendEndpoint?>((ref) {
  final rawValue = ref.watch(
    appConfigProvider.select((config) => config.backendBaseUrlForCurrentBuild),
  );
  return LoopBackendEndpoint.tryParse(rawValue);
});

final loopBackendDioProvider = Provider<Dio?>((ref) {
  final endpoint = ref.watch(loopBackendEndpointProvider);
  if (endpoint == null) return null;
  final dio = LoopDioFactory.createLoopBackend(origin: endpoint.uri);
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final loopBootstrapRepositoryProvider = Provider<LoopBootstrapRepository?>((
  ref,
) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopBootstrapRepository(dio);
});

final loopBackendAccessTokenSourceProvider =
    Provider<LoopBackendAccessTokenSource>((ref) {
      return _PrivyLoopBackendAccessTokenSource(
        ref.watch(privyAuthGatewayProvider),
      );
    });

/// Opaque account-rotation key; never a LOOP or Stream user ID.
final loopBootstrapPrincipalKeyProvider = Provider<String?>((ref) {
  return ref.watch(
    loopSessionProvider.select((session) {
      if (!session.canUseProviderBackedFeatures) return null;
      return session.account?.privyUserId;
    }),
  );
});

/// Lazily creates one bootstrap owner for the current verified principal.
///
/// Merely reading this provider performs no token or network request.
final loopBootstrapSessionProvider = Provider<LoopBootstrapSession?>((ref) {
  final principalKey = ref.watch(loopBootstrapPrincipalKeyProvider);
  final repository = ref.watch(loopBootstrapRepositoryProvider);
  if (principalKey == null || repository == null) return null;

  final session = LoopBootstrapSession(
    principalKey: principalKey,
    accessTokens: ref.watch(loopBackendAccessTokenSourceProvider),
    repository: repository,
  );
  ref.onDispose(session.dispose);
  return session;
});

final loopBootstrapAuthorizationProvider =
    FutureProvider.autoDispose<LoopBootstrapAuthorization>((ref) async {
      final session = ref.watch(loopBootstrapSessionProvider);
      if (session == null) return LoopBootstrapAuthorization.unavailable;
      return session.authorize();
    }, retry: (retryCount, error) => null);

final class _PrivyLoopBackendAccessTokenSource
    implements LoopBackendAccessTokenSource {
  const _PrivyLoopBackendAccessTokenSource(this._gateway);

  final PrivyAuthGateway _gateway;

  @override
  Future<String> loadAccessToken() => _gateway.getCurrentAccessToken();
}
