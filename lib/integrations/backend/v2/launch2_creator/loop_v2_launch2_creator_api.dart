import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_gateway.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2_creator/loop_v2_launch2_creator_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';

/// Strict V2 transport for the MEME v2 project side (S135, decision 0138):
/// the S125 Hooks routes (`launch` module) and the `launch2` instance list.
///
/// `PUT hooks-config` is a compare-and-set write and carries no
/// `Idempotency-Key` (the server answers `400` when one is present);
/// `POST hooks-deployments` carries exactly one canonical UUIDv4.
final class DioLoopV2Launch2CreatorApi {
  DioLoopV2Launch2CreatorApi(this._dio);

  static const projectsPath = '/v2/launch/projects';
  static const instancesPath = '/v2/launch2/instances';

  static const readErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED', 'REGION_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'DATA_STALE',
      'VERSION_CONFLICT',
    },
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// `PUT hooks-config` (§3, §7).
  static const saveErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'VERSION_CONFLICT'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// `POST hooks-deployments` (§5, §7).
  static const submitErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'VERSION_CONFLICT',
    },
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  final Dio _dio;

  static String _id(String value) {
    if (!LoopV2Contract.uuidPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static String _config(String projectId) =>
      '$projectsPath/${_id(projectId)}/hooks-config';

  static String _deployments(String projectId) =>
      '$projectsPath/${_id(projectId)}/hooks-deployments';

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

  Future<Launch2HooksConfig> getConfig({
    required String accessToken,
    required String clientVersion,
    required String projectId,
  }) async {
    final data = await _get(
      _config(projectId),
      accessToken: accessToken,
      clientVersion: clientVersion,
    );
    return LoopV2Launch2CreatorCodec.configEnvelope(data, projectId: projectId);
  }

  Future<Launch2HooksDraft> putConfig({
    required String accessToken,
    required String clientVersion,
    required String projectId,
    required int expectedVersion,
    required Launch2ConfigInput input,
    LoopV2WriteOrigin? origin,
  }) async {
    try {
      final response = await _dio.put<Object?>(
        _config(projectId),
        data: LoopV2Launch2CreatorCodec.configBody(
          expectedVersion: expectedVersion,
          input: input,
        ),
        options: LoopV2ModuleRequest.casOptions(
          accessToken,
          clientVersion,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2Launch2CreatorCodec.draft(
        response.data,
        projectId: projectId,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: saveErrors);
    }
  }

  Future<Launch2SigningRequest> getSigningRequest({
    required String accessToken,
    required String clientVersion,
    required String projectId,
    required String walletId,
  }) async {
    final data = await _get(
      '${_config(projectId)}/signing-request',
      accessToken: accessToken,
      clientVersion: clientVersion,
      query: <String, Object?>{'walletId': _id(walletId)},
    );
    return LoopV2Launch2CreatorCodec.signingRequest(data);
  }

  Future<Launch2DeploymentJob> postDeployment({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String projectId,
    required String walletId,
    required Launch2SigningRequest request,
    required String signature,
    LoopV2WriteOrigin? origin,
  }) async {
    if (!RegExp(r'^0x[0-9a-fA-F]{130}$').hasMatch(signature)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        _deployments(projectId),
        data: LoopV2Launch2CreatorCodec.deploymentBody(
          walletId: _id(walletId),
          request: request,
          signature: signature,
        ),
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2Launch2CreatorCodec.job(response.data, projectId: projectId);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: submitErrors);
    }
  }

  Future<Launch2DeploymentJob> getDeployment({
    required String accessToken,
    required String clientVersion,
    required String projectId,
    required String jobId,
  }) async {
    final data = await _get(
      '${_deployments(projectId)}/${_id(jobId)}',
      accessToken: accessToken,
      clientVersion: clientVersion,
    );
    return LoopV2Launch2CreatorCodec.job(
      data,
      projectId: projectId,
      jobId: jobId,
    );
  }

  /// Walks at most [maxPages] pages of the instance list for the one row
  /// this project became.
  Future<Launch2InstanceRef?> findInstance({
    required String accessToken,
    required String clientVersion,
    required String projectId,
    int maxPages = 3,
  }) async {
    String? cursor;
    for (var page = 0; page < maxPages; page += 1) {
      final data = await _get(
        instancesPath,
        accessToken: accessToken,
        clientVersion: clientVersion,
        query: <String, Object?>{
          if (cursor != null) 'cursor': cursor else 'limit': 50,
        },
      );
      final decoded = LoopV2Launch2CreatorCodec.instancePage(data);
      for (final row in decoded.rows) {
        if (row.projectId == projectId) return row;
      }
      cursor = decoded.nextCursor;
      if (cursor == null) return null;
    }
    return null;
  }
}

/// The authenticated adapter behind [Launch2CreatorGateway].
final class DioLoopV2Launch2CreatorGateway implements Launch2CreatorGateway {
  DioLoopV2Launch2CreatorGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    this._originSource,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final DioLoopV2Launch2CreatorApi _api;
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

  @override
  Future<Launch2HooksConfig> loadConfig(String projectId) => _read(
    (accessToken) => _api.getConfig(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      projectId: projectId,
    ),
  );

  @override
  Future<Launch2HooksDraft> saveConfig({
    required String projectId,
    required int expectedVersion,
    required Launch2ConfigInput input,
  }) async {
    final origin = await _origin();
    // CAS: the version is what makes a retry safe, so there is no key.
    return executeChainRequest(
      _session,
      (accessToken) => _api.putConfig(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        projectId: projectId,
        expectedVersion: expectedVersion,
        input: input,
        origin: origin,
      ),
      write: true,
    );
  }

  @override
  Future<Launch2SigningRequest> loadSigningRequest({
    required String projectId,
    required String walletId,
  }) => _read(
    (accessToken) => _api.getSigningRequest(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      projectId: projectId,
      walletId: walletId,
    ),
  );

  @override
  Future<Launch2DeploymentJob> submitDeployment({
    required String projectId,
    required String walletId,
    required Launch2SigningRequest request,
    required String signature,
  }) async {
    final origin = await _origin();
    // One signature is one action: a new signature always gets a new key,
    // and only an unresolved submission of the same one replays its key.
    final operation = 'launch2:deploy:$projectId:$walletId:$signature';
    final key = _keyring.reserve(operation);
    try {
      final job = await executeChainRequest(
        _session,
        (accessToken) => _api.postDeployment(
          accessToken: accessToken,
          clientVersion: _clientVersion,
          idempotencyKey: key,
          projectId: projectId,
          walletId: walletId,
          request: request,
          signature: signature,
          origin: origin,
        ),
        write: true,
      );
      _keyring.release(operation);
      return job;
    } on LoopChainException catch (failure) {
      if (!_unresolved(failure.kind)) _keyring.release(operation);
      rethrow;
    } catch (_) {
      _keyring.release(operation);
      rethrow;
    }
  }

  @override
  Future<Launch2DeploymentJob> loadDeployment({
    required String projectId,
    required String jobId,
  }) => _read(
    (accessToken) => _api.getDeployment(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      projectId: projectId,
      jobId: jobId,
    ),
  );

  @override
  Future<Launch2InstanceRef?> findInstance(String projectId) => _read(
    (accessToken) => _api.findInstance(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      projectId: projectId,
    ),
  );
}

final loopV2Launch2CreatorApiProvider = Provider<DioLoopV2Launch2CreatorApi?>((
  ref,
) {
  final dio = ref.watch(loopBackendDioProvider);
  if (dio == null) return null;
  return DioLoopV2Launch2CreatorApi(dio);
});

/// Reading the provider issues no request; a missing Dio client, client
/// metadata or authenticated session keeps the port at its fail-closed
/// default.
final loopV2Launch2CreatorGatewayProvider = Provider<Launch2CreatorGateway>((
  ref,
) {
  final api = ref.watch(loopV2Launch2CreatorApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableLaunch2CreatorGateway();
  }
  return DioLoopV2Launch2CreatorGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});
