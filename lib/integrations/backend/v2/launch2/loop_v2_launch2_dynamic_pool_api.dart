import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_dynamic_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';

/// Strict V2 transport for the LoopDynamic routes of `launch2` (client
/// decisions 0157 / 0159, loop-api `frontend-v2-launch2-api.md` §3.12).
///
/// `dynamic-pool` is a separate route an older App never calls. It answers
/// every instance with its `hookKind` (decision 0159). A `404` is a server
/// without the route (an older API) and stays OfficialTax; a `503` whose
/// `reasonCode` is a LoopDynamic one only reaches a LoopDynamic instance and
/// becomes [Launch2LoopDynamicUnavailable]; every other failure is thrown.
final class DioLoopV2Launch2DynamicPoolApi {
  DioLoopV2Launch2DynamicPoolApi(this._dio);

  static const instancesPath = DioLoopV2Launch2Api.instancesPath;

  static const readErrors = DioLoopV2Launch2Api.readErrors;

  /// The claim prepare and report (§3.12.4–3.12.5): the pool prepare's
  /// catalogue plus `409 RESOURCE_CONFLICT` (`LAUNCH2_DYNAMIC_ALREADY_CLAIMED`,
  /// `LAUNCH2_DYNAMIC_CLAIM_TRANSACTION_CONFLICT`).
  static const writeErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'DATA_STALE',
      'IDEMPOTENCY_CONFLICT',
      'INSUFFICIENT_BALANCE',
      'QUOTE_EXPIRED',
      'RESOURCE_CONFLICT',
      'VERSION_CONFLICT',
    },
    422: <String>{'VALIDATION_FAILED'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// The `reasonCode`s only a LoopDynamic instance's `dynamic-pool` read can
  /// answer with a `503` (§3.12.1 route description).
  static const dynamicUnavailableReasons = <String>{
    'LAUNCH2_DYNAMIC_ROUTER_NOT_CONFIGURED',
    'LAUNCH2_DYNAMIC_ROUTER_CODE_MISMATCH',
    'LAUNCH2_DYNAMIC_ROUTER_MANAGER_MISMATCH',
    'LAUNCH2_DYNAMIC_HOOK_NOT_INDEXED',
    'LAUNCH2_DYNAMIC_HOOK_MISMATCH',
    'LAUNCH2_DYNAMIC_HOOK_NOT_INITIALIZED',
  };

  static final RegExp _hashPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');

  final Dio _dio;

  static String _id(String value) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  /// Round ids start at 1 (`^[1-9][0-9]{0,30}$` on both bodies).
  static String _round(BigInt roundId) {
    if (roundId <= BigInt.zero) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return roundId.toString();
  }

  String _base(String instanceId) =>
      '$instancesPath/${_id(instanceId)}/dynamic-pool';

  Future<Object?> _get(
    String path, {
    required String accessToken,
    required String clientVersion,
    Map<String, Object?>? query,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: query,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return response.data;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  Future<Object?> _post(
    String path, {
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required Map<String, Object?> body,
    required int statusCode,
    LoopV2WriteOrigin? origin,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: body,
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: statusCode);
      return response.data;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  Future<Launch2PoolKind> getPoolKind({
    required String accessToken,
    required String clientVersion,
    required String instanceId,
  }) async {
    final path = _base(instanceId);
    try {
      final response = await _dio.get<Object?>(
        path,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2Launch2DynamicPoolCodec.pool(
        response.data,
        instanceId: instanceId,
      );
    } on DioException catch (error) {
      // A server before S166 has no such route: whatever the body, the
      // instance can only be OfficialTax there.
      if (error.type == DioExceptionType.badResponse &&
          error.response?.statusCode == 404) {
        return const Launch2OfficialTaxPool();
      }
      final failure = LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: readErrors,
      );
      final reason = failure.detailsSafe?.reasonCode;
      if (failure.statusCode == 503 &&
          reason != null &&
          dynamicUnavailableReasons.contains(reason)) {
        return Launch2LoopDynamicUnavailable(reason);
      }
      throw failure;
    }
  }

  Future<Launch2DynamicRewards> getRewards({
    required String accessToken,
    required String clientVersion,
    required String instanceId,
    required String walletId,
  }) async {
    final data = await _get(
      '${_base(instanceId)}/rewards',
      accessToken: accessToken,
      clientVersion: clientVersion,
      query: <String, Object?>{'walletId': _id(walletId)},
    );
    return LoopV2Launch2DynamicPoolCodec.rewards(
      data,
      instanceId: instanceId,
      walletId: walletId,
    );
  }

  Future<Launch2DynamicClaimPrepared> postClaimPrepare({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String instanceId,
    required String walletId,
    required BigInt roundId,
    LoopV2WriteOrigin? origin,
  }) async {
    final data = await _post(
      '${_base(instanceId)}/claim/prepare',
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: origin,
      statusCode: 201,
      body: <String, Object?>{
        'walletId': _id(walletId),
        'roundId': _round(roundId),
      },
    );
    return LoopV2Launch2DynamicPoolCodec.claimPrepared(
      data,
      instanceId: instanceId,
      walletId: walletId,
      roundId: roundId,
    );
  }

  Future<Launch2DynamicClaimReport> postClaimReport({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String instanceId,
    required String walletId,
    required BigInt roundId,
    required String intentId,
    required String transactionHash,
    LoopV2WriteOrigin? origin,
  }) async {
    if (!_hashPattern.hasMatch(transactionHash)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    final data = await _post(
      '${_base(instanceId)}/claim/report',
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: origin,
      statusCode: 200,
      // `walletId` / `roundId` are the optional echoes (§3.12.5): a mismatch
      // is 404, so a report can never land on another wallet's round.
      body: <String, Object?>{
        'intentId': _id(intentId),
        'transactionHash': transactionHash.toLowerCase(),
        'walletId': _id(walletId),
        'roundId': _round(roundId),
      },
    );
    return LoopV2Launch2DynamicPoolCodec.report(
      data,
      instanceId: instanceId,
      walletId: walletId,
      roundId: roundId,
      intentId: intentId,
      transactionHash: transactionHash,
    );
  }
}

/// The authenticated adapter behind [Launch2DynamicPoolGateway]. It owns no
/// credential cache and no transport retry; only the idempotency key of each
/// write, replayed only while that write's outcome is unresolved.
final class DioLoopV2Launch2DynamicPoolGateway
    implements Launch2DynamicPoolGateway {
  DioLoopV2Launch2DynamicPoolGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    this._originSource,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final DioLoopV2Launch2DynamicPoolApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2WriteOriginSource? _originSource;
  final LoopV2CommandKeyring _keyring;

  String get _clientVersion => _clientMetadata.clientVersion;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<T> _read<T>(Future<T> Function(String accessToken) request) =>
      executeChainRequest(_session, request, write: false);

  Future<LoopV2WriteOrigin?> _origin() async =>
      _originSource == null ? null : await _originSource.resolve();

  static bool _unresolved(LoopChainFailureKind kind) =>
      kind == LoopChainFailureKind.offline ||
      kind == LoopChainFailureKind.cancelled ||
      kind == LoopChainFailureKind.outcomeUnknown ||
      kind == LoopChainFailureKind.unexpected;

  Future<T> _write<T>(
    String signature,
    Future<T> Function(String accessToken, String key) request,
  ) async {
    final key = _keyring.reserve(signature);
    try {
      final result = await executeChainRequest(
        _session,
        (accessToken) => request(accessToken, key),
        write: true,
      );
      _keyring.release(signature);
      return result;
    } on LoopChainException catch (failure) {
      if (!_unresolved(failure.kind)) _keyring.release(signature);
      rethrow;
    } catch (_) {
      _keyring.release(signature);
      rethrow;
    }
  }

  @override
  Future<Launch2PoolKind> loadPoolKind(String instanceId) => _read(
    (accessToken) => _api.getPoolKind(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      instanceId: instanceId,
    ),
  );

  @override
  Future<Launch2DynamicRewards> loadRewards({
    required String instanceId,
    required String walletId,
  }) => _read(
    (accessToken) => _api.getRewards(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      instanceId: instanceId,
      walletId: walletId,
    ),
  );

  @override
  Future<Launch2DynamicClaimPrepared> prepareClaim({
    required String instanceId,
    required String walletId,
    required BigInt roundId,
  }) async {
    final origin = await _origin();
    return _write(
      'launch2:dynamic-claim:$instanceId:$walletId:$roundId',
      (accessToken, key) => _api.postClaimPrepare(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        instanceId: instanceId,
        walletId: walletId,
        roundId: roundId,
        origin: origin,
      ),
    );
  }

  @override
  Future<Launch2DynamicClaimReport> reportClaim({
    required String instanceId,
    required String walletId,
    required BigInt roundId,
    required String intentId,
    required String transactionHash,
  }) async {
    final origin = await _origin();
    return _write(
      'launch2:dynamic-claim-report:$intentId:${transactionHash.toLowerCase()}',
      (accessToken, key) => _api.postClaimReport(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        instanceId: instanceId,
        walletId: walletId,
        roundId: roundId,
        intentId: intentId,
        transactionHash: transactionHash,
        origin: origin,
      ),
    );
  }
}

/// Reading a provider issues no request; a missing Dio client, client
/// metadata or authenticated session keeps the port at its fail-closed
/// default.
final loopV2Launch2DynamicPoolApiProvider =
    Provider<DioLoopV2Launch2DynamicPoolApi?>((ref) {
      final dio = ref.watch(loopBackendDioProvider);
      if (dio == null) return null;
      return DioLoopV2Launch2DynamicPoolApi(dio);
    });

final loopV2Launch2DynamicPoolGatewayProvider =
    Provider<Launch2DynamicPoolGateway>((ref) {
      final api = ref.watch(loopV2Launch2DynamicPoolApiProvider);
      final metadata = ref.watch(loopV2ClientMetadataProvider);
      final session = ref.watch(loopAuthenticatedSessionProvider);
      if (api == null || metadata == null || session == null) {
        return const UnavailableLaunch2DynamicPoolGateway();
      }
      return DioLoopV2Launch2DynamicPoolGateway(
        api: api,
        clientMetadata: metadata,
        session: session,
        originSource: ref.watch(loopV2WriteOriginSourceProvider),
      );
    });
