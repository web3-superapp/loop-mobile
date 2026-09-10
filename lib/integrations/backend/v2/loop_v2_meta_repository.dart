import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
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

  /// `evidence.reference` is an operator's audit string of 1–120 characters
  /// (decision 0068).
  static const evidenceReferenceMaxLength = 120;

  /// `configVersion` / `effectiveAt` identify the mutable policy snapshot and
  /// are validated by shape only (decision 0029); they are never pinned.
  static final RegExp configVersionPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$',
  );

  /// `POLICY_NOT_YET_EFFECTIVE` means a complete policy exists but its
  /// `effectiveAt` is still in the future (loop-api decision 0029). Both
  /// values are accepted and the observed one is passed through unchanged.
  static const policyNotYetEffectiveReason = 'POLICY_NOT_YET_EFFECTIVE';
  static const versionGateUnavailableReason =
      'CLIENT_VERSION_POLICY_UNAVAILABLE';
  static const termsGateUnavailableReason = 'TERMS_POLICY_UNAVAILABLE';
  static const versionGateUnavailableReasons = <String>{
    versionGateUnavailableReason,
    policyNotYetEffectiveReason,
  };
  static const termsGateUnavailableReasons = <String>{
    termsGateUnavailableReason,
    policyNotYetEffectiveReason,
  };

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
      configVersion: root['configVersion']! as String,
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
      configVersion: root['configVersion']! as String,
      effectiveAt: _utcDateTime(root['effectiveAt']),
      capabilities: capabilities,
    );
  }

  LoopV2VersionGate _parseVersionGate(Object? value) {
    if (value is! Map) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final status = _enumValue(
      value['status'],
      LoopV2VersionGateStatus.tryParse,
    );
    switch (status) {
      case LoopV2VersionGateStatus.unavailable:
        final gate = LoopV2Contract.strictMap(value, const <String>{
          'status',
          'minimumSupportedVersions',
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
        final reasonCode = gate['reasonCode'];
        if (minimums['ios'] != null ||
            minimums['android'] != null ||
            storeUrls['ios'] != null ||
            storeUrls['android'] != null ||
            reasonCode is! String ||
            !versionGateUnavailableReasons.contains(reasonCode)) {
          throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
        }
        return LoopV2VersionGate.unavailable(reasonCode: reasonCode);
      case LoopV2VersionGateStatus.available:
        final gate = LoopV2Contract.strictMap(value, const <String>{
          'status',
          'minimumSupportedVersions',
          'forceUpdateBelow',
          'storeUrls',
          'reasonCode',
        });
        if (gate['reasonCode'] != null) {
          throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
        }
        return LoopV2VersionGate(
          status: status,
          minimumSupportedVersions: _requiredVersions(
            gate['minimumSupportedVersions'],
          ),
          forceUpdateBelow: _requiredVersions(gate['forceUpdateBelow']),
          storeUrls: _requiredStoreUrls(gate['storeUrls']),
          reasonCode: null,
        );
    }
  }

  LoopV2PlatformVersions _requiredVersions(Object? value) {
    final versions = LoopV2Contract.strictMap(value, const <String>{
      'ios',
      'android',
    });
    return LoopV2PlatformVersions(
      ios: _requiredSemver(versions['ios']),
      android: _requiredSemver(versions['android']),
    );
  }

  LoopV2StoreUrls _requiredStoreUrls(Object? value) {
    final urls = LoopV2Contract.strictMap(value, const <String>{
      'ios',
      'android',
    });
    return LoopV2StoreUrls(
      ios: _requiredHttpsUri(urls['ios']),
      android: _requiredHttpsUri(urls['android']),
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
    final status = _enumValue(gate['status'], LoopV2TermsGateStatus.tryParse);
    final requiredVersion = gate['requiredVersion'];
    switch (status) {
      case LoopV2TermsGateStatus.unavailable:
        final reasonCode = gate['reasonCode'];
        if (requiredVersion != null ||
            reasonCode is! String ||
            !termsGateUnavailableReasons.contains(reasonCode)) {
          throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
        }
        return LoopV2TermsGate(
          status: LoopV2TermsGateStatus.unavailable,
          requiredVersion: null,
          reasonCode: reasonCode,
        );
      case LoopV2TermsGateStatus.available:
        if (requiredVersion is! String ||
            requiredVersion.isEmpty ||
            requiredVersion.length > 128 ||
            gate['reasonCode'] != null) {
          throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
        }
        return LoopV2TermsGate(
          status: status,
          requiredVersion: requiredVersion,
          reasonCode: null,
        );
    }
  }

  LoopV2Capability _parseCapability(Object? value) {
    final capability = LoopV2Contract.strictMap(value, const <String>{
      'capabilityId',
      'availability',
      'reasonCode',
      'evidence',
    });
    final evidence = LoopV2Contract.strictMapWithOptional(
      capability['evidence'],
      const <String>{'status', 'reasonCode'},
      // `launchChainId` belongs to `launch` alone (decision 0038); the key is
      // absent while the Launch slot equals the primary chain, and its
      // presence on any other capability is an invalid payload. `reference`
      // belongs to `voiceRooms` alone (decision 0068) and only while its
      // evidence reads `confirmed`.
      const <String>{'launchChainId', 'reference'},
    );
    final id = _enumValue(
      capability['capabilityId'],
      LoopV2CapabilityId.tryParse,
    );
    final launchChainId = _launchChainId(evidence, id);
    final status = _enumValue(
      evidence['status'],
      LoopV2CapabilityEvidenceStatus.tryParse,
    );
    final reasonCode = _nullableReasonCode(evidence['reasonCode']);
    if (status == LoopV2CapabilityEvidenceStatus.confirmed &&
        reasonCode != null) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return LoopV2Capability(
      id: id,
      availability: _enumValue(
        capability['availability'],
        LoopV2CapabilityAvailability.tryParse,
      ),
      reasonCode: _nullableReasonCode(capability['reasonCode']),
      evidence: LoopV2CapabilityEvidence(
        status: status,
        reasonCode: reasonCode,
        reference: _evidenceReference(evidence, id, status),
        launchChainId: launchChainId,
      ),
    );
  }

  /// The optional `evidence.reference` (decision 0068).
  ///
  /// `confirmed` is a claim that an operator recorded the provider
  /// precondition as met, and the reference is what records it, so the two
  /// are one fact: a `confirmed` without a reference is refused rather than
  /// read as an unreferenced confirmation, and a reference published beside
  /// `pending` or `notApplicable` describes a confirmation the same document
  /// denies. Only `voiceRooms` carries the pair; the key on any other
  /// capability — which also refuses `confirmed` there, since the reference is
  /// mandatory — is an invalid payload.
  String? _evidenceReference(
    Map<String, Object?> evidence,
    LoopV2CapabilityId id,
    LoopV2CapabilityEvidenceStatus status,
  ) {
    final present = evidence.containsKey('reference');
    if (status != LoopV2CapabilityEvidenceStatus.confirmed) {
      if (present) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      return null;
    }
    final value = evidence['reference'];
    if (!present ||
        id != LoopV2CapabilityId.voiceRooms ||
        value is! String ||
        value.isEmpty ||
        value.length > evidenceReferenceMaxLength) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return value;
  }

  /// The optional `evidence.launchChainId` (decision 0038).
  ///
  /// The key is **absent** everywhere in the ordinary case, and absence is the
  /// only shape that means "Launch runs on the primary chain". A published key
  /// is a closed enum on `launch` alone, so an explicit `null` — like a value
  /// on any other capability — is a document that does not describe a chain
  /// slot and is rejected rather than read as absence.
  String? _launchChainId(Map<String, Object?> evidence, LoopV2CapabilityId id) {
    if (!evidence.containsKey('launchChainId')) return null;
    final value = evidence['launchChainId'];
    if (id != LoopV2CapabilityId.launch ||
        value is! String ||
        !loopKnownChainIds.contains(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return value;
  }

  void _validateBaseline(Map<String, Object?> root) {
    final configVersion = root['configVersion'];
    if (root['contractVersion'] != LoopV2ClientMetadata.contractVersion ||
        configVersion is! String ||
        !configVersionPattern.hasMatch(configVersion)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    // effectiveAt is validated where it is parsed (_utcDateTime).
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

  String _requiredSemver(Object? value) {
    if (value is! String ||
        value.length < 5 ||
        value.length > 64 ||
        !_semverPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return value;
  }

  Uri _requiredHttpsUri(Object? value) {
    final parsed = _nullableUri(value);
    if (parsed == null ||
        parsed.scheme != 'https' ||
        parsed.userInfo.isNotEmpty) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return parsed;
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

  /// RFC 3339 date-time with an explicit timezone, normalised to UTC. The
  /// backend emits UTC; an offset is accepted, a local (zone-less) value is
  /// not. RFC 3339 allows the lowercase `t` / `z` spellings, so the value is
  /// upper-cased before parsing (`DateTime.parse` only accepts `T`).
  DateTime _utcDateTime(Object? value) {
    if (value is! String || !_explicitZonePattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final parsed = DateTime.tryParse(value.toUpperCase());
    if (parsed == null || !parsed.isUtc) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return parsed;
  }

  static final RegExp _explicitZonePattern = RegExp(
    r'^\d{4}-\d{2}-\d{2}[Tt]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[Zz]|[+-]\d{2}:\d{2})$',
  );
}
