import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/network/loop_dio_factory.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';

abstract interface class LoopV2MetaRepository {
  Future<LoopV2ClientPolicy> getClientPolicy();

  Future<LoopV2Capabilities> getCapabilities();
}

final class DioLoopV2MetaRepository implements LoopV2MetaRepository {
  factory DioLoopV2MetaRepository({required Uri origin}) {
    return DioLoopV2MetaRepository._(
      LoopDioFactory.createCredentialFreePublic(origin: origin),
      ownsClient: true,
    );
  }

  @visibleForTesting
  factory DioLoopV2MetaRepository.withClient(Dio dio) {
    return DioLoopV2MetaRepository._(dio, ownsClient: false);
  }

  DioLoopV2MetaRepository._(this._dio, {required this._ownsClient});

  static const clientPolicyPath = '/v2/meta/client-policy';
  static const capabilitiesPath = '/v2/meta/capabilities';
  static const productConfigVersion = 'productPolicyV2.2026-09-01';
  static const productEffectiveAt = '2026-09-01T00:00:00.000Z';

  static const _metaErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{'REQUEST_TIMEOUT'},
  };
  static const _primaryTabs = <LoopV2PrimaryTab>[
    LoopV2PrimaryTab.community,
    LoopV2PrimaryTab.mining,
    LoopV2PrimaryTab.launch,
    LoopV2PrimaryTab.market,
    LoopV2PrimaryTab.wallet,
  ];
  static final RegExp _semverPattern = RegExp(
    r'^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  final Dio _dio;
  final bool _ownsClient;

  @override
  Future<LoopV2ClientPolicy> getClientPolicy() async {
    try {
      final response = await _dio.get<Object?>(
        clientPolicyPath,
        options: Options(
          headers: const <String, String>{'accept': Headers.jsonContentType},
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _parseClientPolicy(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: _metaErrors);
    }
  }

  @override
  Future<LoopV2Capabilities> getCapabilities() async {
    try {
      final response = await _dio.get<Object?>(
        capabilitiesPath,
        options: Options(
          headers: const <String, String>{'accept': Headers.jsonContentType},
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _parseCapabilities(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: _metaErrors);
    }
  }

  void close() {
    if (_ownsClient) _dio.close(force: true);
  }

  LoopV2ClientPolicy _parseClientPolicy(Object? value) {
    final root = LoopV2Contract.strictMap(value, const <String>{
      'contractVersion',
      'configVersion',
      'effectiveAt',
      'defaultRoute',
      'navigation',
      'versionGate',
      'regionGate',
      'termsGate',
    });
    _validateBaseline(root);
    final defaultRoute = _enumValue(
      root['defaultRoute'],
      LoopV2PrimaryTab.tryParse,
    );
    if (defaultRoute != LoopV2PrimaryTab.community) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    final navigation = LoopV2Contract.strictMap(
      root['navigation'],
      const <String>{'primaryTabs'},
    );
    final primaryTabsValue = navigation['primaryTabs'];
    if (primaryTabsValue is! List || primaryTabsValue.length != 5) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final primaryTabs = <LoopV2PrimaryTab>[
      for (final value in primaryTabsValue)
        _enumValue(value, LoopV2PrimaryTab.tryParse),
    ];
    if (!listEquals(primaryTabs, _primaryTabs)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    return LoopV2ClientPolicy(
      contractVersion: LoopV2ClientMetadata.contractVersion,
      configVersion: productConfigVersion,
      effectiveAt: _utcDateTime(root['effectiveAt']),
      defaultRoute: defaultRoute,
      navigation: LoopV2Navigation(primaryTabs: primaryTabs),
      versionGate: _parseVersionGate(root['versionGate']),
      regionGate: _parseRegionGate(root['regionGate']),
      termsGate: _parseTermsGate(root['termsGate']),
    );
  }

  LoopV2Capabilities _parseCapabilities(Object? value) {
    final root = LoopV2Contract.strictMap(value, const <String>{
      'contractVersion',
      'configVersion',
      'effectiveAt',
      'capabilities',
    });
    _validateBaseline(root);
    final rawCapabilities = root['capabilities'];
    if (rawCapabilities is! List ||
        rawCapabilities.length != LoopV2CapabilityId.values.length) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    final capabilities = <LoopV2Capability>[];
    final seen = <LoopV2CapabilityId>{};
    for (final rawCapability in rawCapabilities) {
      final capability = _parseCapability(rawCapability);
      if (!seen.add(capability.id)) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      capabilities.add(capability);
    }
    if (seen.length != LoopV2CapabilityId.values.length ||
        !seen.containsAll(LoopV2CapabilityId.values)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    return LoopV2Capabilities(
      contractVersion: LoopV2ClientMetadata.contractVersion,
      configVersion: productConfigVersion,
      effectiveAt: _utcDateTime(root['effectiveAt']),
      capabilities: capabilities,
    );
  }

  LoopV2VersionGate _parseVersionGate(Object? value) {
    final gate = LoopV2Contract.strictMap(value, const <String>{
      'status',
      'minimumSupportedVersions',
      'forceUpdate',
      'storeUrls',
      'reasonCode',
    });
    final minimums = LoopV2Contract.strictMap(
      gate['minimumSupportedVersions'],
      const <String>{'ios', 'android'},
    );
    final storeUrls = LoopV2Contract.strictMap(
      gate['storeUrls'],
      const <String>{'ios', 'android'},
    );
    return LoopV2VersionGate(
      status: _enumValue(gate['status'], LoopV2VersionGateStatus.tryParse),
      minimumSupportedVersions: LoopV2MinimumSupportedVersions(
        ios: _nullableSemver(minimums['ios']),
        android: _nullableSemver(minimums['android']),
      ),
      forceUpdate: _nullableBool(gate['forceUpdate']),
      storeUrls: LoopV2StoreUrls(
        ios: _nullableUri(storeUrls['ios']),
        android: _nullableUri(storeUrls['android']),
      ),
      reasonCode: _nullableReasonCode(gate['reasonCode']),
    );
  }

  LoopV2RegionGate _parseRegionGate(Object? value) {
    final gate = LoopV2Contract.strictMap(value, const <String>{
      'status',
      'reasonCode',
      'supportUrl',
      'readOnlyAssetAccess',
    });
    return LoopV2RegionGate(
      status: _enumValue(gate['status'], LoopV2RegionGateStatus.tryParse),
      reasonCode: _nullableReasonCode(gate['reasonCode']),
      supportUrl: _nullableUri(gate['supportUrl']),
      readOnlyAssetAccess: _nullableBool(gate['readOnlyAssetAccess']),
    );
  }

  LoopV2TermsGate _parseTermsGate(Object? value) {
    final gate = LoopV2Contract.strictMap(value, const <String>{
      'status',
      'requiredVersion',
      'reasonCode',
    });
    final requiredVersion = gate['requiredVersion'];
    if (requiredVersion != null &&
        (requiredVersion is! String ||
            requiredVersion.isEmpty ||
            requiredVersion.length > 128)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return LoopV2TermsGate(
      status: _enumValue(gate['status'], LoopV2TermsGateStatus.tryParse),
      requiredVersion: requiredVersion as String?,
      reasonCode: _nullableReasonCode(gate['reasonCode']),
    );
  }

  LoopV2Capability _parseCapability(Object? value) {
    final capability = LoopV2Contract.strictMap(value, const <String>{
      'capabilityId',
      'availability',
      'reasonCode',
      'evidence',
    });
    final evidence = LoopV2Contract.strictMap(
      capability['evidence'],
      const <String>{'status', 'reasonCode'},
    );
    return LoopV2Capability(
      id: _enumValue(capability['capabilityId'], LoopV2CapabilityId.tryParse),
      availability: _enumValue(
        capability['availability'],
        LoopV2CapabilityAvailability.tryParse,
      ),
      reasonCode: _nullableReasonCode(capability['reasonCode']),
      evidence: LoopV2CapabilityEvidence(
        status: _enumValue(
          evidence['status'],
          LoopV2CapabilityEvidenceStatus.tryParse,
        ),
        reasonCode: _nullableReasonCode(evidence['reasonCode']),
      ),
    );
  }

  void _validateBaseline(Map<String, Object?> root) {
    if (root['contractVersion'] != LoopV2ClientMetadata.contractVersion ||
        root['configVersion'] != productConfigVersion ||
        root['effectiveAt'] != productEffectiveAt) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
  }

  T _enumValue<T>(Object? value, T? Function(String) parser) {
    if (value is! String) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final result = parser(value);
    if (result == null) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return result;
  }

  String? _nullableReasonCode(Object? value) {
    if (value == null) return null;
    if (value is! String ||
        value.isEmpty ||
        value.length > 128 ||
        !LoopV2Contract.reasonCodePattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return value;
  }

  String? _nullableSemver(Object? value) {
    if (value == null) return null;
    if (value is! String ||
        value.length < 5 ||
        value.length > 64 ||
        !_semverPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return value;
  }

  Uri? _nullableUri(Object? value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty || value.length > 2048) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final parsed = Uri.tryParse(value);
    if (parsed == null || !parsed.isAbsolute) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return parsed;
  }

  bool? _nullableBool(Object? value) {
    if (value != null && value is! bool) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return value as bool?;
  }

  DateTime _utcDateTime(Object? value) {
    if (value is! String) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return parsed;
  }
}
