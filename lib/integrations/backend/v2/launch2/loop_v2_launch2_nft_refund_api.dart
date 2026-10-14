import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_refund_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';

/// Strict V2 transport for the NFT escrow refund (client decision 0162,
/// loop-api S179): `POST …/instances/:id/nft/refund/prepare` (201, the
/// `launch2Intent` envelope of `nft/prepare`, kind `nft_refund`) and
/// `POST …/nft/refund/report` (200, `nftRefundReport`). The intent is
/// `claimRefund` on the instance's NftEscrow (`contracts.escrow`), no
/// approval.
///
/// The bodies follow `nft/prepare` and the dynamic-claim report: `walletId`
/// + `tokenId`, then `intentId` + `transactionHash` with the two echoes.
final class DioLoopV2Launch2NftRefundApi {
  DioLoopV2Launch2NftRefundApi(this._dio);

  static const instancesPath = DioLoopV2Launch2Api.instancesPath;

  /// The prepares' catalogue plus `409 RESOURCE_CONFLICT` (already
  /// refunded, a report for another transaction).
  static const writeErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    422: <String>{'VALIDATION_FAILED'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'DATA_STALE',
      'IDEMPOTENCY_CONFLICT',
      'INSUFFICIENT_BALANCE',
      'QUOTE_EXPIRED',
      'RESOURCE_CONFLICT',
      'VERSION_CONFLICT',
    },
  };

  static final RegExp _hashPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');

  final Dio _dio;

  static String _id(String value) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static String _token(String tokenId) {
    if (!LoopV2Launch2Codec.integerPattern.hasMatch(tokenId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return tokenId;
  }

  String _base(String instanceId) =>
      '$instancesPath/${_id(instanceId)}/nft/refund';

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

  Future<Launch2Intent> postRefundPrepare({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String instanceId,
    required String walletId,
    required String tokenId,
    LoopV2WriteOrigin? origin,
  }) async {
    final data = await _post(
      '${_base(instanceId)}/prepare',
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: origin,
      statusCode: 201,
      body: <String, Object?>{
        'walletId': _id(walletId),
        'tokenId': _token(tokenId),
      },
    );
    final intent = LoopV2Launch2Codec.intent(
      data,
      venue: Launch2Venue.nftEscrow,
    );
    // A refund spends nothing: an approval would be another operation.
    if (intent.instanceId != instanceId ||
        intent.walletId != walletId ||
        intent.kind != Launch2IntentKind.nftRefund ||
        intent.approval != null) {
      LoopV2Launch2Codec.invalid();
    }
    return intent;
  }

  Future<Launch2NftRefundReport> postRefundReport({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String instanceId,
    required String walletId,
    required String tokenId,
    required String intentId,
    required String transactionHash,
    LoopV2WriteOrigin? origin,
  }) async {
    if (!_hashPattern.hasMatch(transactionHash)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    final data = await _post(
      '${_base(instanceId)}/report',
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: origin,
      statusCode: 200,
      body: <String, Object?>{
        'intentId': _id(intentId),
        'transactionHash': transactionHash.toLowerCase(),
        'walletId': _id(walletId),
        'tokenId': _token(tokenId),
      },
    );
    return LoopV2Launch2Codec.nftRefundReport(data, intentId: intentId);
  }
}

/// The authenticated adapter behind [Launch2NftRefundGateway]. It owns no
/// credential cache and no transport retry; only the idempotency key of each
/// write, replayed only while that write's outcome is unresolved.
final class DioLoopV2Launch2NftRefundGateway
    implements Launch2NftRefundGateway {
  DioLoopV2Launch2NftRefundGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    this._originSource,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final DioLoopV2Launch2NftRefundApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2WriteOriginSource? _originSource;
  final LoopV2CommandKeyring _keyring;

  String get _clientVersion => _clientMetadata.clientVersion;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

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
  Future<Launch2Intent> prepareRefund({
    required String instanceId,
    required String walletId,
    required String tokenId,
  }) async {
    final origin = await _origin();
    return _write(
      'launch2:nft-refund:$instanceId:$walletId:$tokenId',
      (accessToken, key) => _api.postRefundPrepare(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        instanceId: instanceId,
        walletId: walletId,
        tokenId: tokenId,
        origin: origin,
      ),
    );
  }

  @override
  Future<Launch2NftRefundReport> reportRefund({
    required String instanceId,
    required String walletId,
    required String tokenId,
    required String intentId,
    required String transactionHash,
  }) async {
    final origin = await _origin();
    return _write(
      'launch2:nft-refund-report:$intentId:${transactionHash.toLowerCase()}',
      (accessToken, key) => _api.postRefundReport(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        instanceId: instanceId,
        walletId: walletId,
        tokenId: tokenId,
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
final loopV2Launch2NftRefundApiProvider =
    Provider<DioLoopV2Launch2NftRefundApi?>((ref) {
      final dio = ref.watch(loopBackendDioProvider);
      if (dio == null) return null;
      return DioLoopV2Launch2NftRefundApi(dio);
    });

final loopV2Launch2NftRefundGatewayProvider = Provider<Launch2NftRefundGateway>(
  (ref) {
    final api = ref.watch(loopV2Launch2NftRefundApiProvider);
    final metadata = ref.watch(loopV2ClientMetadataProvider);
    final session = ref.watch(loopAuthenticatedSessionProvider);
    if (api == null || metadata == null || session == null) {
      return const UnavailableLaunch2NftRefundGateway();
    }
    return DioLoopV2Launch2NftRefundGateway(
      api: api,
      clientMetadata: metadata,
      session: session,
      originSource: ref.watch(loopV2WriteOriginSourceProvider),
    );
  },
);
