import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_snapshot.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_snapshot_tap.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';
import 'package:loop_mobile/integrations/backend/v2/mining_rewards/loop_v2_mining_rewards_codec.dart';

/// Strict V2 transport for the S138 hourly rewards and the claim
/// (decision 0140).
///
/// Reads carry no `Idempotency-Key`; the two writes carry one canonical
/// UUIDv4 supplied by the caller. Every success is checked for
/// `Cache-Control: no-store` and an `X-Request-ID`.
final class DioLoopV2MiningRewardsApi {
  DioLoopV2MiningRewardsApi(this._dio, {this._snapshotTap});

  static const rewardsPath = '/v2/mining/rewards';
  static const claimsPath = '/v2/mining/claims';
  static const preparePath = '/v2/mining/claim/prepare';
  static const reportPath = '/v2/mining/claim/report';

  static const readErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'VERSION_CONFLICT'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

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
      'RESOURCE_CONFLICT',
      'SIMULATION_FAILED',
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

  final Dio _dio;
  final LoopV2SnapshotTap? _snapshotTap;

  /// The live decoder, shared with the cold-start snapshot.
  static MiningRewardsView decodeRewards(Object? body) =>
      LoopV2MiningRewardsCodec.rewards(body);

  static String _id(String value) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

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
  }

  Future<MiningRewardsView> getRewards({
    required String accessToken,
    required String clientVersion,
  }) async {
    final data = await _get(
      rewardsPath,
      accessToken: accessToken,
      clientVersion: clientVersion,
    );
    final view = decodeRewards(data);
    _snapshotTap?.call(LoopSnapshotResource.miningRewards, data);
    return view;
  }

  Future<MiningClaimPage> getClaims({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  }) async {
    final data = await _get(
      claimsPath,
      accessToken: accessToken,
      clientVersion: clientVersion,
      query: cursor == null ? null : <String, Object?>{'cursor': cursor},
    );
    return LoopV2MiningRewardsCodec.claims(data);
  }

  Future<MiningClaimPrepareResult> postPrepare({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    LoopV2WriteOrigin? origin,
  }) async {
    try {
      final data = await _post(
        preparePath,
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: idempotencyKey,
        statusCode: 201,
        origin: origin,
        body: <String, Object?>{'walletId': _id(walletId)},
      );
      final intent = LoopV2MiningRewardsCodec.prepared(data);
      if (intent.walletId != walletId) LoopV2MiningRewardsCodec.invalid();
      return MiningClaimPrepared(intent);
    } on DioException catch (error) {
      final response = error.response;
      if (error.type == DioExceptionType.badResponse &&
          response?.statusCode == 409) {
        final gas = LoopV2MiningRewardsCodec.gasRefusal(response?.data);
        if (gas != null) {
          return gas.reason == LoopV2MiningRewardsCodec.gasInsufficientCode
              ? MiningClaimGasInsufficient(
                  swap: gas.swap,
                  requiredNative: gas.requiredNative,
                )
              : MiningClaimNoGasSource(requiredNative: gas.requiredNative);
        }
      }
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  Future<MiningClaimRecord> postReport({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String claimId,
    required String txHash,
    LoopV2WriteOrigin? origin,
  }) async {
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(txHash)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final data = await _post(
        reportPath,
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: idempotencyKey,
        statusCode: 200,
        origin: origin,
        body: <String, Object?>{
          'claimId': _id(claimId),
          'transactionHash': txHash.toLowerCase(),
        },
      );
      final record = LoopV2MiningRewardsCodec.reported(data);
      if (record.claimId != claimId) LoopV2MiningRewardsCodec.invalid();
      return record;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }
}

/// The authenticated adapter behind [MiningRewardsGateway].
final class DioLoopV2MiningRewardsGateway implements MiningRewardsGateway {
  DioLoopV2MiningRewardsGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    this._originSource,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final DioLoopV2MiningRewardsApi _api;
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

  /// One key per logical write; it is replayed only while that write's
  /// outcome is unresolved, so a lost answer never prepares a second claim.
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
  Future<MiningRewardsView> loadRewards() => _read(
    (accessToken) => _api.getRewards(
      accessToken: accessToken,
      clientVersion: _clientVersion,
    ),
  );

  @override
  Future<MiningClaimPage> loadClaims({String? cursor}) => _read(
    (accessToken) => _api.getClaims(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      cursor: cursor,
    ),
  );

  @override
  Future<MiningClaimPrepareResult> prepareClaim({
    required String walletId,
  }) async {
    final origin = await _origin();
    return _write(
      'mining:claim:prepare:$walletId',
      (accessToken, key) => _api.postPrepare(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        walletId: walletId,
        origin: origin,
      ),
    );
  }

  @override
  Future<MiningClaimRecord> reportClaim({
    required String claimId,
    required String txHash,
  }) async {
    final origin = await _origin();
    return _write(
      'mining:claim:report:$claimId:${txHash.toLowerCase()}',
      (accessToken, key) => _api.postReport(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        claimId: claimId,
        txHash: txHash,
        origin: origin,
      ),
    );
  }
}

/// Reading a provider issues no request; a missing Dio client, client
/// metadata or authenticated session keeps the port at its fail-closed
/// default.
final loopV2MiningRewardsApiProvider = Provider<DioLoopV2MiningRewardsApi?>((
  ref,
) {
  final dio = ref.watch(loopBackendDioProvider);
  if (dio == null) return null;
  return DioLoopV2MiningRewardsApi(
    dio,
    snapshotTap: ref.watch(loopV2SnapshotSessionProvider)?.record,
  );
});

final loopV2MiningRewardsGatewayProvider = Provider<MiningRewardsGateway>((
  ref,
) {
  final api = ref.watch(loopV2MiningRewardsApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableMiningRewardsGateway();
  }
  return DioLoopV2MiningRewardsGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});
