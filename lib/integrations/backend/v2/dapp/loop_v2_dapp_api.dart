import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/dapp/dapp_gateway.dart';
import 'package:loop_mobile/features/dapp/dapp_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/dapp/loop_v2_dapp_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';

/// Strict V2 transport for the DApp browser (S342 · decision 0270,
/// docs/55 §二): the two prepares, the two reports, cancel and the read-only
/// RPC channel.
final class DioLoopV2DappApi {
  DioLoopV2DappApi(this._dio);

  final Dio _dio;

  static const dappTxPath = '/v2/wallet-intents/dapp-tx';
  static const dappSignPath = '/v2/wallet-intents/dapp-sign';
  static const intentsPath = '/v2/wallet-intents';
  static const rpcReadPath = '/v2/chain/rpc-read';

  /// The money-action catalogue plus `422 CHAIN_SIGNING_DISABLED` (a BSC
  /// Mainnet request) and `409 SIMULATION_FAILED`.
  static final Map<int, Set<String>> writeErrors = <int, Set<String>>{
    for (final entry in LoopV2ModuleRequest.moneyActionWriteErrors.entries)
      entry.key: <String>{
        ...entry.value,
        if (entry.key == 422) 'CHAIN_SIGNING_DISABLED',
        // S346: `409 RESOURCE_CONFLICT` with reasonCode INTENT_BUSY — a
        // non-DApp intent is open on the wallet.
        if (entry.key == 409) 'RESOURCE_CONFLICT',
      },
  };

  static final Map<int, Set<String>> readErrors = <int, Set<String>>{
    ...LoopV2ModuleRequest.moneyActionReadErrors,
    422: <String>{
      ...?LoopV2ModuleRequest.moneyActionReadErrors[422],
      'METHOD_NOT_ALLOWED',
    },
  };

  static final RegExp _hash = RegExp(r'^0x[0-9a-fA-F]{64}$');
  static final RegExp _signature = RegExp(r'^0x[0-9a-fA-F]{130}$');

  static Never _badRequest() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);

  static String _uuid(String value) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(value)) _badRequest();
    return value;
  }

  Future<DappIntent> _write(
    String path,
    Map<String, Object?>? body, {
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required LoopV2WriteOrigin? origin,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: body,
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: body != null,
          origin: origin,
        ),
      );
      if (response.statusCode == 201) {
        LoopV2Contract.validateSuccess(response, statusCode: 201);
      } else {
        LoopV2Contract.validateSuccess(response, statusCode: 200);
      }
      return LoopV2DappCodec.intent(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  /// `{ walletId, chainId, origin, tx: { to, data, value } }`.
  Future<DappIntent> prepareTx({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    required String chainId,
    required String origin,
    required DappTxRequest tx,
    LoopV2WriteOrigin? writeOrigin,
  }) {
    if (!LoopV2ChainCodec.chainIdPattern.hasMatch(chainId)) _badRequest();
    return _write(
      dappTxPath,
      dappTxBody(
        walletId: _uuid(walletId),
        chainId: chainId,
        origin: origin,
        tx: tx,
      ),
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: writeOrigin,
    );
  }

  static Map<String, Object?> dappTxBody({
    required String walletId,
    required String chainId,
    required String origin,
    required DappTxRequest tx,
  }) => <String, Object?>{
    'walletId': walletId,
    'chainId': chainId,
    'origin': origin,
    'tx': tx.toWire(),
  };

  /// `{ walletId, chainId, origin, method, payload }`.
  Future<DappIntent> prepareSign({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    required String chainId,
    required String origin,
    required DappSignRequest request,
    LoopV2WriteOrigin? writeOrigin,
  }) {
    if (!LoopV2ChainCodec.chainIdPattern.hasMatch(chainId)) _badRequest();
    return _write(
      dappSignPath,
      dappSignBody(
        walletId: _uuid(walletId),
        chainId: chainId,
        origin: origin,
        request: request,
      ),
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: writeOrigin,
    );
  }

  static Map<String, Object?> dappSignBody({
    required String walletId,
    required String chainId,
    required String origin,
    required DappSignRequest request,
  }) => <String, Object?>{
    'walletId': walletId,
    'chainId': chainId,
    'origin': origin,
    'method': request.method,
    'payload': request.payload,
  };

  Future<DappIntent> reportBroadcast({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String intentId,
    required String txHash,
    LoopV2WriteOrigin? writeOrigin,
  }) {
    if (!_hash.hasMatch(txHash)) _badRequest();
    return _write(
      '$intentsPath/${_uuid(intentId)}/broadcast-report',
      <String, Object?>{'txHash': txHash},
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: writeOrigin,
    );
  }

  Future<DappIntent> reportSignature({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String intentId,
    required String signature,
    LoopV2WriteOrigin? writeOrigin,
  }) {
    if (!_signature.hasMatch(signature)) _badRequest();
    return _write(
      '$intentsPath/${_uuid(intentId)}/signature-report',
      <String, Object?>{'signature': signature},
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: writeOrigin,
    );
  }

  Future<void> cancel({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String intentId,
    LoopV2WriteOrigin? writeOrigin,
  }) async {
    await _write(
      '$intentsPath/${_uuid(intentId)}/cancel',
      null,
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: writeOrigin,
    );
  }

  /// `POST /v2/chain/rpc-read` `{ chainId, method, params }` → `{ result }`.
  /// It stores nothing, so it carries no `Idempotency-Key`.
  Future<Object?> rpcRead({
    required String accessToken,
    required String clientVersion,
    required String chainId,
    required String method,
    required List<Object?> params,
  }) async {
    if (!LoopV2ChainCodec.chainIdPattern.hasMatch(chainId) ||
        !dappReadMethods.contains(method)) {
      _badRequest();
    }
    try {
      final response = await _dio.post<Object?>(
        rpcReadPath,
        data: <String, Object?>{
          'chainId': chainId,
          'method': method,
          'params': params,
        },
        options: LoopV2ModuleRequest.readOptions(
          accessToken,
          clientVersion,
        ).copyWith(contentType: Headers.jsonContentType),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final data = response.data;
      if (data is! Map || !data.containsKey('result')) _badRequest();
      // The node's own JSON-RPC error travels back to the page as is.
      final error = data['error'];
      if (error is Map) {
        final code = error['code'];
        final message = error['message'];
        throw DappRpcError(
          code is int ? code : DappRpcErrorCode.internal,
          message is String ? message : 'Read failed',
        );
      }
      return data['result'];
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }
}

/// The feature port over [DioLoopV2DappApi].
final class DioLoopV2DappGateway implements DappIntentsGateway, DappRpcReader {
  DioLoopV2DappGateway({
    required this.api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
  });

  final DioLoopV2DappApi api;
  final LoopV2ClientMetadata clientMetadata;
  final LoopAuthenticatedSession session;
  final LoopV2WriteOriginSource? originSource;
  final LoopV2CommandKeyring _keyring = LoopV2CommandKeyring();

  String get _clientVersion => clientMetadata.clientVersion;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<LoopV2WriteOrigin?> _origin() async =>
      originSource == null ? null : await originSource!.resolve();

  /// One logical operation reserves one key, replayed only while its outcome
  /// is unresolved (the S6 rule).
  Future<T> _idempotent<T>(
    String signature,
    Future<T> Function(String accessToken, String key) request,
  ) async {
    final key = _keyring.reserve(signature);
    try {
      final result = await executeChainRequest(
        session,
        (accessToken) => request(accessToken, key),
        write: true,
      );
      _keyring.release(signature);
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

  @override
  Future<DappIntent> prepareTx({
    required String walletId,
    required String chainId,
    required String origin,
    required DappTxRequest tx,
  }) async {
    final writeOrigin = await _origin();
    return _idempotent(
      'dapp-tx:$walletId:$chainId:$origin:${tx.to}:${tx.valueHex}:${tx.data}',
      (accessToken, key) => api.prepareTx(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        walletId: walletId,
        chainId: chainId,
        origin: origin,
        tx: tx,
        writeOrigin: writeOrigin,
      ),
    );
  }

  @override
  Future<DappIntent> prepareSign({
    required String walletId,
    required String chainId,
    required String origin,
    required DappSignRequest request,
  }) async {
    final writeOrigin = await _origin();
    return _idempotent(
      'dapp-sign:$walletId:$chainId:$origin:${request.method}:'
      '${request.payload.hashCode}',
      (accessToken, key) => api.prepareSign(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        walletId: walletId,
        chainId: chainId,
        origin: origin,
        request: request,
        writeOrigin: writeOrigin,
      ),
    );
  }

  @override
  Future<DappIntent> reportBroadcast({
    required String intentId,
    required String txHash,
  }) async {
    final writeOrigin = await _origin();
    return _idempotent(
      'dapp-broadcast:$intentId:$txHash',
      (accessToken, key) => api.reportBroadcast(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        intentId: intentId,
        txHash: txHash,
        writeOrigin: writeOrigin,
      ),
    );
  }

  @override
  Future<DappIntent> reportSignature({
    required String intentId,
    required String signature,
  }) async {
    final writeOrigin = await _origin();
    return _idempotent(
      'dapp-signature:$intentId',
      (accessToken, key) => api.reportSignature(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        intentId: intentId,
        signature: signature,
        writeOrigin: writeOrigin,
      ),
    );
  }

  @override
  Future<void> cancel({required String intentId}) async {
    final writeOrigin = await _origin();
    await _idempotent(
      'dapp-cancel:$intentId',
      (accessToken, key) => api.cancel(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        intentId: intentId,
        writeOrigin: writeOrigin,
      ),
    );
  }

  @override
  Future<Object?> read({
    required String chainId,
    required String method,
    required List<Object?> params,
  }) async {
    // A node error is an answer, not a transport failure: it is carried out
    // of the session wrapper and handed to the page as the node gave it.
    final outcome = await executeChainRequest<(Object?, DappRpcError?)>(
      session,
      (accessToken) async {
        try {
          return (
            await api.rpcRead(
              accessToken: accessToken,
              clientVersion: _clientVersion,
              chainId: chainId,
              method: method,
              params: params,
            ),
            null,
          );
        } on DappRpcError catch (error) {
          return (null, error);
        }
      },
      write: false,
    );
    final error = outcome.$2;
    if (error != null) throw error;
    return outcome.$1;
  }
}

final loopV2DappGatewayProvider = Provider<DioLoopV2DappGateway?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || metadata == null || session == null) return null;
  return DioLoopV2DappGateway(
    api: DioLoopV2DappApi(dio),
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});

/// The production DApp intents port, or the fail-closed default.
final loopV2DappIntentsGatewayProvider = Provider<DappIntentsGateway>(
  (ref) =>
      ref.watch(loopV2DappGatewayProvider) ??
      const UnavailableDappIntentsGateway(),
);

/// The production read channel: the server's `rpc-read` allowlist (docs/55
/// §二). Switching to the embedded wallet's provider means replacing this
/// one provider.
final loopV2DappRpcReaderProvider = Provider<DappRpcReader>(
  (ref) =>
      ref.watch(loopV2DappGatewayProvider) ?? const UnavailableDappRpcReader(),
);
