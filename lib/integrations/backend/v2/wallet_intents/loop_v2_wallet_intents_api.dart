import 'package:dio/dio.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';

/// Strict V2 transport for the S6 wallet-intent lifecycle (loop-api decision
/// 0035): prepare, report, execute, cancel and read.
///
/// `preflight` deliberately carries no `Idempotency-Key` — it stores nothing
/// and the server answers `400 INVALID_REQUEST` when one is present. Every
/// other write carries exactly one.
abstract interface class LoopV2WalletIntentsApi {
  Future<LoopSendPreflight> preflightSend({
    required String accessToken,
    required String clientVersion,
    required String walletId,
    required String address,
  });

  Future<LoopWalletIntent> prepareSend({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    required String assetId,
    required String amount,
    required String recipientAddress,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopWalletIntent> prepareApprove({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    required String assetId,
    required String spenderAddress,
    required LoopAllowanceRequest allowance,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopWalletIntent> prepareRevoke({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    required String assetId,
    required String spenderAddress,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopWalletIntent> prepareSwap({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    required String quoteId,
    required bool confirmPriceImpact,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopWalletIntent> reportBroadcast({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String intentId,
    required String txHash,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopWalletIntent> execute({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String intentId,
    required String authorizationSignature,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopWalletIntent> cancel({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String intentId,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopWalletIntent> getIntent({
    required String accessToken,
    required String clientVersion,
    required String intentId,
  });

  Future<LoopWalletIntentPage> listIntents({
    required String accessToken,
    required String clientVersion,
    String? cursor,
    int? limit,
  });
}

final class DioLoopV2WalletIntentsApi implements LoopV2WalletIntentsApi {
  DioLoopV2WalletIntentsApi(this._dio);

  static const intentsPath = '/v2/wallet-intents';
  static const preflightPath = '/v2/wallet-intents/send/preflight';
  static const sendPath = '/v2/wallet-intents/send';
  static const approvePath = '/v2/wallet-intents/approve';
  static const revokePath = '/v2/wallet-intents/revoke';
  static const swapPath = '/v2/wallet-intents/swap';

  static final RegExp _mixedCaseAddress = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final RegExp _mixedCaseHash = RegExp(r'^0x[0-9a-fA-F]{64}$');

  final Dio _dio;

  static Never _badRequest() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);

  static String _uuid(String value) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(value)) _badRequest();
    return value;
  }

  static String _assetId(String value) {
    if (!LoopV2ChainCodec.assetIdPattern.hasMatch(value)) _badRequest();
    return value;
  }

  /// The wire accepts a mixed-case address, but a mixed-case value must be a
  /// valid EIP-55 checksum: the server rejects one wrong character.
  static String _address(String value) {
    if (!_mixedCaseAddress.hasMatch(value)) _badRequest();
    return value;
  }

  static String _hash(String value) {
    if (!_mixedCaseHash.hasMatch(value)) _badRequest();
    return value;
  }

  /// A positive decimal amount in the asset's display unit, kept as the exact
  /// text the owner typed.
  static String _amount(String value) {
    if (value.length > 160 ||
        !LoopV2ChainCodec.unsignedDecimalPattern.hasMatch(value)) {
      _badRequest();
    }
    return value;
  }

  Future<LoopWalletIntent> _prepare(
    String path,
    Map<String, Object?> body, {
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
          hasBody: true,
          origin: origin,
        ),
      );
      // A replayed key answers 200 with the original intent; a fresh key 201.
      if (response.statusCode == 200) {
        LoopV2Contract.validateSuccess(response, statusCode: 200);
      } else {
        LoopV2Contract.validateSuccess(response, statusCode: 201);
      }
      return LoopV2IntentCodec.intent(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.moneyActionWriteErrors,
      );
    }
  }

  Future<LoopWalletIntent> _transition(
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
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2IntentCodec.intent(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.moneyActionWriteErrors,
      );
    }
  }

  @override
  Future<LoopSendPreflight> preflightSend({
    required String accessToken,
    required String clientVersion,
    required String walletId,
    required String address,
  }) async {
    final body = <String, Object?>{
      'walletId': _uuid(walletId),
      'address': _address(address),
    };
    try {
      final response = await _dio.post<Object?>(
        preflightPath,
        data: body,
        options: LoopV2ModuleRequest.casOptions(
          accessToken,
          clientVersion,
          hasBody: true,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2IntentCodec.preflight(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.moneyActionReadErrors,
      );
    }
  }

  @override
  Future<LoopWalletIntent> prepareSend({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    required String assetId,
    required String amount,
    required String recipientAddress,
    LoopV2WriteOrigin? origin,
  }) => _prepare(
    sendPath,
    <String, Object?>{
      'walletId': _uuid(walletId),
      'assetId': _assetId(assetId),
      'amount': _amount(amount),
      'recipientAddress': _address(recipientAddress),
    },
    accessToken: accessToken,
    clientVersion: clientVersion,
    idempotencyKey: idempotencyKey,
    origin: origin,
  );

  @override
  Future<LoopWalletIntent> prepareApprove({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    required String assetId,
    required String spenderAddress,
    required LoopAllowanceRequest allowance,
    LoopV2WriteOrigin? origin,
  }) {
    // `unlimited` never travels alone: the guard's second confirmation is a
    // separate top-level field the server validates.
    final body = <String, Object?>{
      'walletId': _uuid(walletId),
      'assetId': _assetId(assetId),
      'spenderAddress': _address(spenderAddress),
      'allowance': switch (allowance) {
        LoopExactAllowanceRequest(amount: final amount) => <String, Object?>{
          'mode': 'exact',
          'amount': _amount(amount),
        },
        LoopUnlimitedAllowanceRequest() => <String, Object?>{
          'mode': 'unlimited',
        },
      },
      if (allowance is LoopUnlimitedAllowanceRequest)
        'acknowledgeUnlimited': true,
    };
    return _prepare(
      approvePath,
      body,
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: origin,
    );
  }

  @override
  Future<LoopWalletIntent> prepareRevoke({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    required String assetId,
    required String spenderAddress,
    LoopV2WriteOrigin? origin,
  }) => _prepare(
    revokePath,
    <String, Object?>{
      'walletId': _uuid(walletId),
      'assetId': _assetId(assetId),
      'spenderAddress': _address(spenderAddress),
    },
    accessToken: accessToken,
    clientVersion: clientVersion,
    idempotencyKey: idempotencyKey,
    origin: origin,
  );

  @override
  Future<LoopWalletIntent> prepareSwap({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String walletId,
    required String quoteId,
    required bool confirmPriceImpact,
    LoopV2WriteOrigin? origin,
  }) => _prepare(
    swapPath,
    <String, Object?>{
      'walletId': _uuid(walletId),
      'quoteId': _uuid(quoteId),
      if (confirmPriceImpact) 'confirmPriceImpact': true,
    },
    accessToken: accessToken,
    clientVersion: clientVersion,
    idempotencyKey: idempotencyKey,
    origin: origin,
  );

  @override
  Future<LoopWalletIntent> reportBroadcast({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String intentId,
    required String txHash,
    LoopV2WriteOrigin? origin,
  }) => _transition(
    '$intentsPath/${_uuid(intentId)}/broadcast-report',
    <String, Object?>{'txHash': _hash(txHash)},
    accessToken: accessToken,
    clientVersion: clientVersion,
    idempotencyKey: idempotencyKey,
    origin: origin,
  );

  @override
  Future<LoopWalletIntent> execute({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String intentId,
    required String authorizationSignature,
    LoopV2WriteOrigin? origin,
  }) {
    if (authorizationSignature.isEmpty ||
        authorizationSignature.length > 4096) {
      _badRequest();
    }
    return _transition(
      '$intentsPath/${_uuid(intentId)}/execute',
      <String, Object?>{'authorizationSignature': authorizationSignature},
      accessToken: accessToken,
      clientVersion: clientVersion,
      idempotencyKey: idempotencyKey,
      origin: origin,
    );
  }

  @override
  Future<LoopWalletIntent> cancel({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String intentId,
    LoopV2WriteOrigin? origin,
  }) => _transition(
    '$intentsPath/${_uuid(intentId)}/cancel',
    null,
    accessToken: accessToken,
    clientVersion: clientVersion,
    idempotencyKey: idempotencyKey,
    origin: origin,
  );

  @override
  Future<LoopWalletIntent> getIntent({
    required String accessToken,
    required String clientVersion,
    required String intentId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$intentsPath/${_uuid(intentId)}',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2IntentCodec.intent(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.moneyActionReadErrors,
      );
    }
  }

  @override
  Future<LoopWalletIntentPage> listIntents({
    required String accessToken,
    required String clientVersion,
    String? cursor,
    int? limit,
  }) async {
    // `cursor` and `limit` are mutually exclusive: the page size is already
    // encoded in the cursor.
    if (cursor != null && limit != null) _badRequest();
    if (limit != null && (limit < 1 || limit > 50)) _badRequest();
    if (cursor != null &&
        (cursor.length < 3 ||
            cursor.length > LoopV2ChainCodec.maximumCursorLength ||
            !LoopV2ChainCodec.cursorPattern.hasMatch(cursor))) {
      _badRequest();
    }
    try {
      final response = await _dio.get<Object?>(
        intentsPath,
        queryParameters: cursor != null
            ? <String, Object?>{'cursor': cursor}
            : limit != null
            ? <String, Object?>{'limit': limit}
            : null,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2IntentCodec.intentPage(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.moneyActionReadErrors,
      );
    }
  }
}
