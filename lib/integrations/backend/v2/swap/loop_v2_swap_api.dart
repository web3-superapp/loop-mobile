import 'package:dio/dio.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';

/// Strict V2 transport for `POST /v2/swap/quote`.
///
/// The quote stores nothing and therefore forbids `Idempotency-Key`; the
/// intent it feeds (`POST /v2/wallet-intents/swap`) is the idempotent write.
abstract interface class LoopV2SwapApi {
  Future<LoopSwapQuoteView> quote({
    required String accessToken,
    required String clientVersion,
    required String walletId,
    required String sourceAssetId,
    required String destinationAssetId,
    required String amount,
    int? slippageBps,
  });
}

final class DioLoopV2SwapApi implements LoopV2SwapApi {
  DioLoopV2SwapApi(this._dio);

  static const quotePath = '/v2/swap/quote';

  final Dio _dio;

  static Never _badRequest() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);

  @override
  Future<LoopSwapQuoteView> quote({
    required String accessToken,
    required String clientVersion,
    required String walletId,
    required String sourceAssetId,
    required String destinationAssetId,
    required String amount,
    int? slippageBps,
  }) async {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(walletId)) _badRequest();
    if (!LoopV2ChainCodec.assetIdPattern.hasMatch(sourceAssetId) ||
        !LoopV2ChainCodec.assetIdPattern.hasMatch(destinationAssetId)) {
      _badRequest();
    }
    if (amount.length > 160 ||
        !LoopV2ChainCodec.unsignedDecimalPattern.hasMatch(amount)) {
      _badRequest();
    }
    // The user-adjustable ceiling is 300 bps; anything above is a client bug,
    // not a server decision.
    if (slippageBps != null && (slippageBps < 1 || slippageBps > 300)) {
      _badRequest();
    }
    try {
      final response = await _dio.post<Object?>(
        quotePath,
        data: <String, Object?>{
          'walletId': walletId,
          'sourceAssetId': sourceAssetId,
          'destinationAssetId': destinationAssetId,
          'amount': amount,
          'slippageBps': ?slippageBps,
        },
        options: LoopV2ModuleRequest.casOptions(
          accessToken,
          clientVersion,
          hasBody: true,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2IntentCodec.quoteView(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.moneyActionWriteErrors,
      );
    }
  }
}
