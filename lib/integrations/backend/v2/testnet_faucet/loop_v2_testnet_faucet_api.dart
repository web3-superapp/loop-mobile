import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_gateway.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';
import 'package:loop_mobile/integrations/backend/v2/testnet_faucet/loop_v2_testnet_faucet_codec.dart';

/// Strict V2 transport for the testnet faucet (client decision 0154).
///
/// The read carries no `Idempotency-Key`; the claim carries one canonical
/// UUIDv4 supplied by the caller. Every success is checked for
/// `Cache-Control: no-store` and an `X-Request-ID`.
final class DioLoopV2TestnetFaucetApi {
  DioLoopV2TestnetFaucetApi(this._dio);

  static const faucetPath = '/v2/testnet/faucet';

  static const readErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'RESOURCE_CONFLICT'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    502: <String>{'PROVIDER_UNREACHABLE'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  static const writeErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'RESOURCE_CONFLICT',
    },
    422: <String>{'VALIDATION_FAILED'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    502: <String>{'PROVIDER_UNREACHABLE'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  final Dio _dio;

  static String _walletId(String value) {
    if (!LoopV2TestnetFaucetCodec.walletIdPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  Future<TestnetFaucetStatus> getStatus({
    required String accessToken,
    required String clientVersion,
    required String walletId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        faucetPath,
        queryParameters: <String, Object?>{'walletId': _walletId(walletId)},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final status = LoopV2TestnetFaucetCodec.status(response.data);
      if (status.walletId != walletId) LoopV2TestnetFaucetCodec.invalid();
      return status;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  Future<TestnetFaucetClaimResult> postClaim({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    LoopV2WriteOrigin? origin,
  }) async {
    final body = <String, Object?>{'walletId': _walletId(walletId)};
    try {
      final response = await _dio.post<Object?>(
        faucetPath,
        data: body,
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 201);
      final granted = LoopV2TestnetFaucetCodec.granted(response.data);
      if (granted.walletId != walletId) LoopV2TestnetFaucetCodec.invalid();
      return granted;
    } on DioException catch (error) {
      // The error envelope is validated first; only a well-formed refusal
      // may be read as a cooldown or a partial grant.
      final failure = LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: writeErrors,
      );
      final reasonCode = failure.detailsSafe?.reasonCode;
      final data = error.response?.data;
      final detailsSafe = data is Map ? data['detailsSafe'] : null;
      if (failure.code == 'RATE_LIMITED' &&
          reasonCode == TestnetFaucetReason.cooldown) {
        return TestnetFaucetCoolingDown(
          nextAvailableAt: LoopV2TestnetFaucetCodec.cooldownNextAvailableAt(
            detailsSafe,
          ),
        );
      }
      final serverAnswered = failure.code != null;
      if (serverAnswered &&
          (reasonCode == TestnetFaucetReason.partial ||
              reasonCode == TestnetFaucetReason.submissionUnknown) &&
          (failure.statusCode == 502 || failure.statusCode == 503)) {
        return LoopV2TestnetFaucetCodec.partial(
          detailsSafe,
          unconfirmed: reasonCode == TestnetFaucetReason.submissionUnknown,
        );
      }
      // The same claim is still being sent under this key.
      if (failure.code == 'RESOURCE_CONFLICT' &&
          reasonCode == TestnetFaucetReason.inFlight) {
        return const TestnetFaucetPending(TestnetFaucetPendingReason.inFlight);
      }
      // LOOP stopped waiting after 15 s but still finishes and records the
      // grant: the page reads the status again instead of failing.
      if (failure.code == 'REQUEST_TIMEOUT') {
        return const TestnetFaucetPending(TestnetFaucetPendingReason.timedOut);
      }
      throw failure;
    }
  }
}

/// The authenticated adapter behind [TestnetFaucetGateway].
final class DioLoopV2TestnetFaucetGateway implements TestnetFaucetGateway {
  DioLoopV2TestnetFaucetGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    this._originSource,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final DioLoopV2TestnetFaucetApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2WriteOriginSource? _originSource;
  final LoopV2CommandKeyring _keyring;

  String get _clientVersion => _clientMetadata.clientVersion;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  static String _signature(String walletId) => 'testnet:faucet:$walletId';

  /// A status read that shows the wallet cooling down means the server has
  /// recorded a grant for it, so a claim key still held from a pending answer
  /// has an outcome and is let go: the next claim, a day later, must not
  /// replay that stored answer (decision 0158).
  @override
  Future<TestnetFaucetStatus> loadStatus({required String walletId}) async {
    final status = await executeChainRequest(
      _session,
      (accessToken) => _api.getStatus(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        walletId: walletId,
      ),
      write: false,
    );
    if (!status.available) _keyring.release(_signature(walletId));
    return status;
  }

  /// One key per logical claim; it is replayed only while that claim's
  /// outcome is unresolved, so a lost answer never sends a second grant.
  ///
  /// A [TestnetFaucetPending] answer (409 `TESTNET_FAUCET_IN_FLIGHT`, 503
  /// `REQUEST_TIMEOUT`) is such an unresolved outcome: the key is kept and a
  /// retry sends the same one, which the server answers with the stored
  /// outcome of that one grant (decision 0158).
  @override
  Future<TestnetFaucetClaimResult> claim({required String walletId}) async {
    final origin = _originSource == null ? null : await _originSource.resolve();
    final signature = _signature(walletId);
    final key = _keyring.reserve(signature);
    try {
      final result = await executeChainRequest(
        _session,
        (accessToken) => _api.postClaim(
          accessToken: accessToken,
          clientVersion: _clientVersion,
          idempotencyKey: key,
          walletId: walletId,
          origin: origin,
        ),
        write: true,
      );
      if (result is! TestnetFaucetPending) _keyring.release(signature);
      return result;
    } on LoopChainException catch (failure) {
      if (!loopChainOutcomeIsUnresolved(failure.kind)) {
        _keyring.release(signature);
      }
      rethrow;
    } catch (_) {
      _keyring.release(signature);
      rethrow;
    }
  }
}

/// Reading a provider issues no request; a missing Dio client, client
/// metadata or authenticated session keeps the port at its fail-closed
/// default.
final loopV2TestnetFaucetApiProvider = Provider<DioLoopV2TestnetFaucetApi?>((
  ref,
) {
  final dio = ref.watch(loopBackendDioProvider);
  if (dio == null) return null;
  return DioLoopV2TestnetFaucetApi(dio);
});

final loopV2TestnetFaucetGatewayProvider = Provider<TestnetFaucetGateway>((
  ref,
) {
  final api = ref.watch(loopV2TestnetFaucetApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableTestnetFaucetGateway();
  }
  return DioLoopV2TestnetFaucetGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});
