import 'package:dio/dio.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';

/// Strict V2 transport for the approval inventory.
///
/// The list depends on the indexer's `Approval` checkpoint; without one the
/// server answers `503 INDEXING_DELAYED` and the page must say "unknown",
/// never "no approvals". The single read does not depend on the indexer.
abstract interface class LoopV2ApprovalsApi {
  Future<LoopApprovalInventory> getApprovals({
    required String accessToken,
    required String clientVersion,
    required String walletId,
  });

  Future<LoopApprovalRow> getApproval({
    required String accessToken,
    required String clientVersion,
    required String walletId,
    required String assetId,
    required String spender,
  });
}

final class DioLoopV2ApprovalsApi implements LoopV2ApprovalsApi {
  DioLoopV2ApprovalsApi(this._dio);

  static const approvalsPath = '/v2/approvals';

  final Dio _dio;

  static Never _badRequest() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);

  static String _walletId(String value) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(value)) _badRequest();
    return value;
  }

  @override
  Future<LoopApprovalInventory> getApprovals({
    required String accessToken,
    required String clientVersion,
    required String walletId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        approvalsPath,
        queryParameters: <String, Object?>{'walletId': _walletId(walletId)},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2IntentCodec.approvals(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.moneyActionReadErrors,
      );
    }
  }

  @override
  Future<LoopApprovalRow> getApproval({
    required String accessToken,
    required String clientVersion,
    required String walletId,
    required String assetId,
    required String spender,
  }) async {
    if (!LoopV2ChainCodec.assetIdPattern.hasMatch(assetId) ||
        !LoopV2ChainCodec.addressPattern.hasMatch(spender)) {
      _badRequest();
    }
    try {
      final response = await _dio.get<Object?>(
        '$approvalsPath/$assetId/$spender',
        queryParameters: <String, Object?>{'walletId': _walletId(walletId)},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2IntentCodec.approvalDetail(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.moneyActionReadErrors,
      );
    }
  }
}
