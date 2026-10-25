// S306 · decision 0246 / loop-api decision 0185: POST /v2/wallets/sync.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_gateways.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';

import 'support/s5_fixtures.dart';

const _accessToken = 'privy-access-token';

Map<String, Object?> _syncBody() => <String, Object?>{
  ...s5WalletDirectoryBody(),
  'externalWalletLimit': 3,
};

void main() {
  group('the transport', () {
    test('POST with the active-switch headers, no body, no query and no '
        'Idempotency-Key; the answer is the list', () async {
      RequestOptions? captured;
      final api = DioLoopV2WalletApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, _syncBody()));
        }),
      );

      final directory = await api.postWalletsSync(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        origin: LoopV2WriteOrigin.tryCreate(
          platform: 'ios',
          deviceId: s5OtherWalletId,
        ),
      );

      expect(captured!.method, 'POST');
      expect(captured!.uri.path, DioLoopV2WalletApi.walletsSyncPath);
      expect(captured!.queryParameters, isEmpty);
      expect(captured!.data, isNull);
      expect(captured!.headers.containsKey('idempotency-key'), isFalse);
      expect(captured!.headers['authorization'], 'Bearer $_accessToken');
      expect(captured!.headers['x-loop-platform'], 'ios');
      expect(directory!.externalWalletLimit, 3);
      expect(directory.wallets.single.walletId, s5WalletId);
    });

    test('a server without the route answers null', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Object?>(
                requestOptions: options,
                statusCode: 404,
              ),
            ),
          ),
        ),
      );

      expect(
        await api.postWalletsSync(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        isNull,
      );
    });

    test('503 PROVIDER_DISCONNECTED keeps its code', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) => handler.reject(
            s5ErrorResponse(
              options,
              statusCode: 503,
              code: 'PROVIDER_DISCONNECTED',
            ),
          ),
        ),
      );

      await expectLater(
        api.postWalletsSync(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.code,
            'code',
            'PROVIDER_DISCONNECTED',
          ),
        ),
      );
    });
  });

  group('the gateway', () {
    DioLoopV2WalletReadGateway gateway(
      void Function(RequestOptions, RequestInterceptorHandler) onRequest,
    ) => DioLoopV2WalletReadGateway(
      api: DioLoopV2WalletApi(s5Dio(onRequest)),
      clientMetadata: const LoopV2ClientMetadata(
        clientVersion: s5ClientVersion,
        platform: LoopV2Platform.ios,
      ),
      session: _immediateSession(),
    );

    test('a 200 is synced with the list', () async {
      final result = await gateway(
        (options, handler) => handler.resolve(s5Response(options, _syncBody())),
      ).requestSync();

      expect(result.status, WalletInventorySyncStatus.synced);
      expect(result.directory?.externalWalletLimit, 3);
    });

    test('503 PROVIDER_DISCONNECTED is providerDisconnected', () async {
      final result = await gateway(
        (options, handler) => handler.reject(
          s5ErrorResponse(
            options,
            statusCode: 503,
            code: 'PROVIDER_DISCONNECTED',
          ),
        ),
      ).requestSync();

      expect(result.status, WalletInventorySyncStatus.providerDisconnected);
      expect(result.directory, isNull);
    });

    test('any other failure is failed, never thrown', () async {
      final result = await gateway(
        (options, handler) => handler.reject(
          s5ErrorResponse(
            options,
            statusCode: 500,
            code: 'INTERNAL_ERROR',
            category: 'internal',
            retryable: false,
            userMessageKey: 'errors.internal',
          ),
        ),
      ).requestSync();

      expect(result.status, WalletInventorySyncStatus.failed);
    });
  });
}

LoopAuthenticatedSession _immediateSession() {
  const principalKey = 'did:privy:owner-1';
  return LoopAuthenticatedSession(
    principalKey: principalKey,
    bootstrapSession: LoopBootstrapSession(
      principalKey: principalKey,
      accessTokens: _StaticAccessTokens(),
      repository: _BootstrapRepository(),
    ),
    accessTokens: _StaticAccessTokens(),
  );
}

final class _StaticAccessTokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => 'current-token';
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    return const LoopBootstrapIdentity(
      loopUserId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
      streamUserId: 'loop_6d12a86e413447e69312c5ef75a30f55',
    );
  }
}
