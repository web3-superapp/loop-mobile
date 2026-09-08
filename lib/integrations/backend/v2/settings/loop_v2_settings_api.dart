import 'package:dio/dio.dart';
import 'package:loop_mobile/features/profile/settings/settings_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';

/// Strict V2 transport for the account settings resource (decision 0037).
///
/// `PUT` is a compare-and-set write and must not carry an `Idempotency-Key`:
/// the server answers `400 INVALID_REQUEST` when one is present.
abstract interface class LoopV2SettingsApi {
  Future<LoopAccountSettings> getSettings({
    required String accessToken,
    required String clientVersion,
  });

  Future<LoopAccountSettings> putSettings({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required LoopAccountSettingsValues values,
    LoopV2WriteOrigin? origin,
  });
}

final class DioLoopV2SettingsApi implements LoopV2SettingsApi {
  DioLoopV2SettingsApi(this._dio);

  static const settingsPath = '/v2/settings';
  static const maximumVersion = 2147483647;

  final Dio _dio;

  @override
  Future<LoopAccountSettings> getSettings({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        settingsPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _settings(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  @override
  Future<LoopAccountSettings> putSettings({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required LoopAccountSettingsValues values,
    LoopV2WriteOrigin? origin,
  }) async {
    if (expectedVersion < 0 || expectedVersion > maximumVersion) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    // Both values are fixed in this step; anything else is refused locally
    // rather than sent for a `422`.
    if (values.displayCurrency !=
            LoopAccountSettingsValues.fixedDisplayCurrency ||
        values.language != LoopAccountSettingsValues.fixedLanguage) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.put<Object?>(
        settingsPath,
        data: <String, Object?>{
          'expectedVersion': expectedVersion,
          'settings': <String, Object?>{
            'displayCurrency': values.displayCurrency,
            'language': values.language,
          },
        },
        options: LoopV2ModuleRequest.casOptions(
          accessToken,
          clientVersion,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _settings(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.casWriteErrors,
      );
    }
  }

  static LoopAccountSettings _settings(Object? data) {
    final root = LoopV2Contract.strictMap(data, const <String>{
      'settings',
      'version',
      'updatedAt',
      'policy',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final values = _values(root['settings']);
    final policy = LoopV2Contract.strictMap(root['policy'], const <String>{
      'configVersion',
      'fixed',
      'localOnly',
    });
    final localOnly = <String>[];
    for (final raw in LoopV2ChainCodec.requireList(
      policy['localOnly'],
      maximum: 8,
    )) {
      if (raw is! String || raw.isEmpty || raw.length > 64) {
        LoopV2ChainCodec.invalid();
      }
      localOnly.add(raw);
    }
    final version = LoopV2ChainCodec.requireInt(
      root,
      'version',
      maximum: maximumVersion,
    );
    final updatedAt = LoopV2ChainCodec.optionalTimestamp(root, 'updatedAt');
    // Version 0 means no row was ever written, so it can carry no update time.
    if ((version == 0) != (updatedAt == null)) LoopV2ChainCodec.invalid();
    return LoopAccountSettings(
      values: values,
      version: version,
      updatedAt: updatedAt,
      policy: LoopAccountSettingsPolicy(
        configVersion: LoopV2ChainCodec.requireString(
          policy,
          'configVersion',
          pattern: RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'),
          maxLength: 64,
        ),
        fixed: _values(policy['fixed']),
        localOnly: localOnly,
      ),
    );
  }

  static LoopAccountSettingsValues _values(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'displayCurrency',
      'language',
    });
    final displayCurrency = map['displayCurrency'];
    final language = map['language'];
    if (displayCurrency != LoopAccountSettingsValues.fixedDisplayCurrency ||
        language != LoopAccountSettingsValues.fixedLanguage) {
      LoopV2ChainCodec.invalid();
    }
    return const LoopAccountSettingsValues(
      displayCurrency: LoopAccountSettingsValues.fixedDisplayCurrency,
      language: LoopAccountSettingsValues.fixedLanguage,
    );
  }
}
