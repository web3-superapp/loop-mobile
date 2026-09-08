import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';

/// Strict V2 transport for the `alerts` half of the notifications module.
///
/// `POST` carries one canonical `Idempotency-Key`; `PUT` and `DELETE` carry
/// none and use `expectedVersion` instead. The threshold is always sent as a
/// JSON string: a JSON number is refused by the server before type coercion.
abstract interface class LoopV2AlertsApi {
  Future<LoopAlertPage> listAlerts({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  });

  Future<LoopPriceAlert> createAlert({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required LoopAlertDraft draft,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopPriceAlert> updateAlert({
    required String accessToken,
    required String clientVersion,
    required String alertId,
    required int expectedVersion,
    required LoopAlertDraft draft,
    LoopV2WriteOrigin? origin,
  });

  Future<void> deleteAlert({
    required String accessToken,
    required String clientVersion,
    required String alertId,
    required int expectedVersion,
    LoopV2WriteOrigin? origin,
  });
}

final class DioLoopV2AlertsApi implements LoopV2AlertsApi {
  DioLoopV2AlertsApi(this._dio);

  static const alertsPath = '/v2/alerts';
  static const maximumVersion = 2147483647;

  final Dio _dio;

  static String _requireAlertId(String value) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static int _requireVersion(int value) {
    if (value < 1 || value > maximumVersion) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static Map<String, Object?> _body(LoopAlertDraft draft) {
    if (draft.invalidField != null) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return <String, Object?>{
      'assetId': draft.assetId,
      'condition': draft.condition.wireName,
      // A JSON string, deliberately. `threshold` is never a JSON number.
      'threshold': draft.threshold,
      'expiresAt': draft.expiresAt?.toUtc().toIso8601String(),
    };
  }

  @override
  Future<LoopAlertPage> listAlerts({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  }) async {
    if (cursor != null &&
        (cursor.length < 3 ||
            cursor.length > LoopV2ChainCodec.maximumCursorLength ||
            !LoopV2ChainCodec.cursorPattern.hasMatch(cursor))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        alertsPath,
        queryParameters: cursor == null
            ? null
            : <String, Object?>{'cursor': cursor},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'items',
        'nextCursor',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      final items = <LoopPriceAlert>[];
      final seen = <String>{};
      for (final raw in LoopV2ChainCodec.requireList(
        root['items'],
        maximum: 50,
      )) {
        final alert = alertFromMap(raw);
        if (!seen.add(alert.alertId)) LoopV2ChainCodec.invalid();
        items.add(alert);
      }
      return LoopAlertPage(
        items: items,
        nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<LoopPriceAlert> createAlert({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required LoopAlertDraft draft,
    LoopV2WriteOrigin? origin,
  }) async {
    final body = _body(draft);
    try {
      final response = await _dio.post<Object?>(
        alertsPath,
        data: body,
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      // `201` is a new alert, `200` an identical replay of the same key.
      final statusCode = response.statusCode;
      if (statusCode != 200 && statusCode != 201) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      LoopV2Contract.validateSuccess(response, statusCode: statusCode!);
      return _envelope(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainIdempotentWriteErrors,
      );
    }
  }

  @override
  Future<LoopPriceAlert> updateAlert({
    required String accessToken,
    required String clientVersion,
    required String alertId,
    required int expectedVersion,
    required LoopAlertDraft draft,
    LoopV2WriteOrigin? origin,
  }) async {
    final target = _requireAlertId(alertId);
    final version = _requireVersion(expectedVersion);
    final body = <String, Object?>{'expectedVersion': version, ..._body(draft)};
    try {
      final response = await _dio.put<Object?>(
        '$alertsPath/$target',
        data: body,
        options: LoopV2ModuleRequest.casOptions(
          accessToken,
          clientVersion,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _envelope(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.casWriteErrors,
      );
    }
  }

  @override
  Future<void> deleteAlert({
    required String accessToken,
    required String clientVersion,
    required String alertId,
    required int expectedVersion,
    LoopV2WriteOrigin? origin,
  }) async {
    final target = _requireAlertId(alertId);
    final version = _requireVersion(expectedVersion);
    try {
      final response = await _dio.delete<Object?>(
        '$alertsPath/$target',
        queryParameters: <String, Object?>{'expectedVersion': version},
        options: LoopV2ModuleRequest.casOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 204);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.casWriteErrors,
      );
    }
  }

  static LoopPriceAlert _envelope(Object? data) {
    final root = LoopV2Contract.strictMap(data, const <String>{
      'alert',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    return alertFromMap(root['alert']);
  }

  /// Visible to the notifications transport, which shares this projection.
  static LoopPriceAlert alertFromMap(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'alertId',
      'assetId',
      'asset',
      'condition',
      'threshold',
      'expiresAt',
      'state',
      'triggeredAt',
      'lastEvaluatedAt',
      'delivery',
      'version',
      'createdAt',
      'updatedAt',
    });
    final rawCondition = map['condition'];
    final rawState = map['state'];
    if (rawCondition is! String || rawState is! String) {
      LoopV2ChainCodec.invalid();
    }
    final condition = LoopAlertCondition.tryParse(rawCondition);
    final state = LoopAlertState.tryParse(rawState);
    if (condition == null || state == null) LoopV2ChainCodec.invalid();
    final thresholdText = LoopV2ChainCodec.requireString(
      map,
      'threshold',
      pattern: loopAlertThresholdPattern,
      maxLength: 96,
    );
    final threshold = Decimal.tryParse(thresholdText);
    if (threshold == null) LoopV2ChainCodec.invalid();
    final triggeredAt = LoopV2ChainCodec.optionalTimestamp(map, 'triggeredAt');
    // A triggered alert always says when it fired.
    if ((state == LoopAlertState.triggered) != (triggeredAt != null)) {
      LoopV2ChainCodec.invalid();
    }
    return LoopPriceAlert(
      alertId: LoopV2ChainCodec.requireString(
        map,
        'alertId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      assetId: LoopV2ChainCodec.requireAssetId(map, 'assetId'),
      asset: LoopV2ChainCodec.assetSummary(map['asset']),
      condition: condition,
      threshold: threshold,
      thresholdText: thresholdText,
      expiresAt: LoopV2ChainCodec.optionalTimestamp(map, 'expiresAt'),
      state: state,
      triggeredAt: triggeredAt,
      lastEvaluatedAt: LoopV2ChainCodec.optionalTimestamp(
        map,
        'lastEvaluatedAt',
      ),
      delivery: LoopV2ChainCodec.unavailable(map['delivery']),
      version: LoopV2ChainCodec.requireInt(map, 'version', minimum: 1),
      createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
      updatedAt: LoopV2ChainCodec.requireTimestamp(map, 'updatedAt'),
    );
  }
}
