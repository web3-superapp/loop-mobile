import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
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
/// decision 0157, loop-api S166 draft).
///
/// `dynamic-pool` is a separate route an older App never calls. Its `404`
/// (an OfficialTax instance, or a server without the route) and a `503
/// CAPABILITY_UNAVAILABLE` both answer [Launch2OfficialTaxPool]; nothing
/// else does.
final class DioLoopV2Launch2DynamicPoolApi {
  DioLoopV2Launch2DynamicPoolApi(this._dio);

  static const instancesPath = DioLoopV2Launch2Api.instancesPath;

  static const readErrors = DioLoopV2Launch2Api.readErrors;

  /// The claim prepare and report: the pool prepare's catalogue (the round
  /// refusals arrive as `409` / `422` with their `reasonCode`).
  static const writeErrors = DioLoopV2Launch2Api.poolWriteErrors;

  static final RegExp _hashPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');

  final Dio _dio;

  static String _id(String value) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static String _round(BigInt roundId) {
    if (roundId.isNegative) {
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
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
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
      return Launch2LoopDynamicPool(
        LoopV2Launch2DynamicPoolCodec.state(response.data),
      );
    } on DioException catch (error) {
      // An OfficialTax instance and a server before S166 both answer 404,
      // whatever the body.
      if (error.type == DioExceptionType.badResponse &&
          error.response?.statusCode == 404) {
        return const Launch2OfficialTaxPool();
      }
      final failure = LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: readErrors,
      );
      if (failure.statusCode == 503 &&
          failure.code == 'CAPABILITY_UNAVAILABLE') {
        return const Launch2OfficialTaxPool();
      }
      throw failure;
    }
  }

  Future<Launch2DynamicRewards> getRewards({
    required String accessToken,
    required String clientVersion,
    required String instanceId,
  }) async {
    final data = await _get(
      '${_base(instanceId)}/rewards',
      accessToken: accessToken,
      clientVersion: clientVersion,
    );
    return LoopV2Launch2DynamicPoolCodec.rewards(data);
  }

  Future<Launch2Intent> postClaimPrepare({
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
    return LoopV2Launch2DynamicPoolCodec.claimIntent(
      data,
      instanceId: instanceId,
      walletId: walletId,
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
      body: <String, Object?>{
        'walletId': _id(walletId),
        'roundId': _round(roundId),
        'intentId': _id(intentId),
        'transactionHash': transactionHash.toLowerCase(),
      },
    );
    return LoopV2Launch2DynamicPoolCodec.report(data, roundId: roundId);
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
  Future<Launch2DynamicRewards> loadRewards(String instanceId) => _read(
    (accessToken) => _api.getRewards(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      instanceId: instanceId,
    ),
  );

  @override
  Future<Launch2Intent> prepareClaim({
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
