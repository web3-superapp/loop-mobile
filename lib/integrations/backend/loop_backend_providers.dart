import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/core/network/loop_dio_factory.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_repository.dart';
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

final loopBackendAccessTokenSourceProvider =
    Provider<LoopBackendAccessTokenSource>((ref) {
      return _PrivyLoopBackendAccessTokenSource(
        ref.watch(privyAuthGatewayProvider),
      );
    });

final class _PrivyLoopBackendAccessTokenSource
    implements LoopBackendAccessTokenSource {
  const _PrivyLoopBackendAccessTokenSource(this._gateway);

  final PrivyAuthGateway _gateway;

  @override
  Future<String> loadAccessToken() => _gateway.getCurrentAccessToken();
}
