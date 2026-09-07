import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';

void main() {
  const requestId = '11111111-1111-4111-8111-111111111111';

  test('client policy GET is credential-free and parses every gate', () async {
    RequestOptions? captured;
    final repository = DioLoopV2MetaRepository.withClient(
      _dio((options, handler) {
        captured = options;
        handler.resolve(_response(options, _clientPolicy()));
      }),
    );

    final policy = await repository.getClientPolicy();

    expect(captured?.method, 'GET');
    expect(captured?.uri.path, DioLoopV2MetaRepository.clientPolicyPath);
    expect(captured?.queryParameters, isEmpty);
    expect(captured?.data, isNull);
    expect(_header(captured!, 'authorization'), isNull);
    expect(_header(captured!, 'idempotency-key'), isNull);
    expect(
      captured!.headers.keys.map((key) => key.toLowerCase()),
      isNot(contains(startsWith('x-loop-'))),
    );
    expect(policy.contractVersion, '2.0');
    expect(policy.configVersion, 'productPolicyV2.2026-09-01');
    expect(policy.effectiveAt, DateTime.utc(2026, DateTime.september));
    expect(policy.defaultRoute, LoopV2PrimaryTab.community);
    expect(policy.navigation.primaryTabs, <LoopV2PrimaryTab>[
      LoopV2PrimaryTab.community,
      LoopV2PrimaryTab.mining,
      LoopV2PrimaryTab.launch,
      LoopV2PrimaryTab.market,
      LoopV2PrimaryTab.wallet,
    ]);
    expect(policy.versionGate.status, LoopV2VersionGateStatus.unavailable);
    expect(policy.versionGate.isAvailable, isFalse);
    expect(policy.versionGate.minimumSupportedVersions.ios, isNull);
    expect(policy.versionGate.minimumSupportedVersions.android, isNull);
    expect(policy.versionGate.forceUpdateBelow, isNull);
    expect(policy.versionGate.storeUrls.ios, isNull);
    expect(policy.versionGate.storeUrls.android, isNull);
    expect(policy.versionGate.reasonCode, 'CLIENT_VERSION_POLICY_UNAVAILABLE');
    expect(policy.regionGate.status, LoopV2RegionGateStatus.unavailable);
    expect(policy.regionGate.supportUrl, isNull);
    expect(policy.regionGate.readOnlyAssetAccess, isNull);
    expect(policy.regionGate.reasonCode, 'REGION_POLICY_UNAVAILABLE');
    expect(policy.termsGate.status, LoopV2TermsGateStatus.unavailable);
    expect(policy.termsGate.requiredVersion, isNull);
    expect(policy.termsGate.reasonCode, 'TERMS_POLICY_UNAVAILABLE');
  });

  test(
    'capabilities GET preserves availability and evidence separately',
    () async {
      RequestOptions? captured;
      final repository = DioLoopV2MetaRepository.withClient(
        _dio((options, handler) {
          captured = options;
          handler.resolve(_response(options, _capabilities()));
        }),
      );

      final projection = await repository.getCapabilities();

      expect(captured?.method, 'GET');
      expect(captured?.uri.path, DioLoopV2MetaRepository.capabilitiesPath);
      expect(captured?.queryParameters, isEmpty);
      expect(captured?.data, isNull);
      expect(_header(captured!, 'authorization'), isNull);
      expect(_header(captured!, 'idempotency-key'), isNull);
      expect(
        captured!.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains(startsWith('x-loop-'))),
      );
      expect(projection.capabilities, hasLength(16));
      expect(
        projection.capabilities.map((item) => item.id).toSet(),
        LoopV2CapabilityId.values.toSet(),
      );

      final accountSession = projection[LoopV2CapabilityId.accountSession];
      expect(
        accountSession.availability,
        LoopV2CapabilityAvailability.available,
      );
      expect(
        accountSession.evidence.status,
        LoopV2CapabilityEvidenceStatus.pending,
      );
      expect(
        accountSession.evidence.reasonCode,
        'PHYSICAL_DEVICE_EVIDENCE_PENDING',
      );

      final community = projection[LoopV2CapabilityId.community];
      expect(community.availability, LoopV2CapabilityAvailability.deferred);
      expect(
        community.evidence.status,
        LoopV2CapabilityEvidenceStatus.notApplicable,
      );
      expect(community.reasonCode, 'RUNTIME_DEFERRED');
    },
  );

  test(
    'policy parses the available version and terms variants exactly',
    () async {
      final value = _clientPolicy();
      value['configVersion'] = 'productPolicyV2.2026-09-07_rc-2';
      value['effectiveAt'] = '2026-09-07T10:30:00+08:00';
      value['versionGate'] = _availableVersionGate();
      value['regionGate'] = <String, Object?>{
        'status': 'allowed',
        'reasonCode': null,
        'supportUrl': 'https://quant-dinger.cc/support',
        'readOnlyAssetAccess': true,
      };
      value['termsGate'] = <String, Object?>{
        'status': 'available',
        'requiredVersion': 'terms-2026-09',
        'reasonCode': null,
      };
      final repository = _resolvingRepository(value);

      final policy = await repository.getClientPolicy();

      expect(policy.configVersion, 'productPolicyV2.2026-09-07_rc-2');
      expect(policy.effectiveAt, DateTime.utc(2026, 9, 7, 2, 30));
      expect(policy.versionGate.status, LoopV2VersionGateStatus.available);
      expect(policy.versionGate.isAvailable, isTrue);
      expect(policy.versionGate.reasonCode, isNull);
      expect(policy.versionGate.minimumSupportedVersions.ios, '1.4.0');
      expect(
        policy.versionGate.minimumSupportedVersions.android,
        '1.2.4-beta.1+7',
      );
      expect(policy.versionGate.forceUpdateBelow?.ios, '1.2.0');
      expect(policy.versionGate.forceUpdateBelow?.android, '1.2.4-beta.1+7');
      expect(
        policy.versionGate.storeUrls.ios,
        Uri.parse('https://apps.apple.com/app/loop'),
      );
      expect(policy.regionGate.status, LoopV2RegionGateStatus.allowed);
      expect(policy.regionGate.readOnlyAssetAccess, isTrue);
      expect(policy.termsGate.status, LoopV2TermsGateStatus.available);
      expect(policy.termsGate.requiredVersion, 'terms-2026-09');
      expect(policy.termsGate.reasonCode, isNull);
    },
  );

  test(
    'strict policy rejects drift, reordered tabs, and invalid proof',
    () async {
      final extraField = _clientPolicy()..['futureField'] = true;
      final reorderedTabs = _clientPolicy();
      (reorderedTabs['navigation']! as Map<String, Object?>)['primaryTabs'] =
          <String>['mining', 'community', 'launch', 'market', 'wallet'];
      final invalidSemver = _clientPolicy();
      invalidSemver['versionGate'] = _availableVersionGate()
        ..['minimumSupportedVersions'] = <String, Object?>{
          'ios': '01.0.0',
          'android': '1.0.0',
        };
      final unavailableWithFloor = _clientPolicy();
      (unavailableWithFloor['versionGate']!
          as Map<String, Object?>)['forceUpdateBelow'] = <String, Object?>{
        'ios': null,
        'android': null,
      };
      final legacyForceUpdate = _clientPolicy();
      (legacyForceUpdate['versionGate']!
              as Map<String, Object?>)['forceUpdate'] =
          null;
      final availableMissingFloor = _clientPolicy();
      availableMissingFloor['versionGate'] = _availableVersionGate()
        ..remove('forceUpdateBelow');
      final availableWithReason = _clientPolicy();
      availableWithReason['versionGate'] = _availableVersionGate()
        ..['reasonCode'] = 'CLIENT_VERSION_POLICY_UNAVAILABLE';
      final availableHttpStore = _clientPolicy();
      availableHttpStore['versionGate'] = _availableVersionGate()
        ..['storeUrls'] = <String, Object?>{
          'ios': 'http://apps.apple.com/app/loop',
          'android': 'https://play.google.com/store/apps/details?id=x',
        };
      final legacyActiveStatus = _clientPolicy();
      legacyActiveStatus['versionGate'] = _availableVersionGate()
        ..['status'] = 'active';
      final termsWithoutVersion = _clientPolicy();
      termsWithoutVersion['termsGate'] = <String, Object?>{
        'status': 'available',
        'requiredVersion': null,
        'reasonCode': null,
      };
      final legacyTermsRequired = _clientPolicy();
      legacyTermsRequired['termsGate'] = <String, Object?>{
        'status': 'required',
        'requiredVersion': 'terms-2026-09',
        'reasonCode': 'TERMS_ACCEPTANCE_REQUIRED',
      };
      final badConfigVersion = _clientPolicy()..['configVersion'] = '.v1';
      final localEffectiveAt = _clientPolicy()
        ..['effectiveAt'] = '2026-09-01T00:00:00';

      for (final repository in <DioLoopV2MetaRepository>[
        _resolvingRepository(extraField),
        _resolvingRepository(reorderedTabs),
        _resolvingRepository(invalidSemver),
        _resolvingRepository(unavailableWithFloor),
        _resolvingRepository(legacyForceUpdate),
        _resolvingRepository(availableMissingFloor),
        _resolvingRepository(availableWithReason),
        _resolvingRepository(availableHttpStore),
        _resolvingRepository(legacyActiveStatus),
        _resolvingRepository(termsWithoutVersion),
        _resolvingRepository(legacyTermsRequired),
        _resolvingRepository(badConfigVersion),
        _resolvingRepository(localEffectiveAt),
        _resolvingRepository(_clientPolicy(), includeRequestId: false),
        _resolvingRepository(
          _clientPolicy(),
          cacheControl: 'private, no-store',
        ),
      ]) {
        await expectLater(
          repository.getClientPolicy(),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      }
    },
  );

  test(
    'capabilities reject missing, duplicate, and unknown capability IDs',
    () async {
      final missing = _capabilities();
      (missing['capabilities']! as List<Object?>).removeLast();

      final duplicate = _capabilities();
      final duplicateItems = duplicate['capabilities']! as List<Object?>;
      duplicateItems[15] = Map<String, Object?>.from(
        duplicateItems.first! as Map<String, Object?>,
      );

      final unknown = _capabilities();
      final unknownItems = unknown['capabilities']! as List<Object?>;
      unknownItems[0] = <String, Object?>{
        ...(unknownItems.first! as Map<String, Object?>),
        'capabilityId': 'futureCapability',
      };

      for (final value in <Map<String, Object?>>[missing, duplicate, unknown]) {
        await expectLater(
          _resolvingRepository(value).getCapabilities(),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      }
    },
  );

  test(
    'V2 metadata error requires exact code and request correlation',
    () async {
      final validRepository = DioLoopV2MetaRepository.withClient(
        _dio((options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: _response(options, <String, Object?>{
                'code': 'REQUEST_TIMEOUT',
                'category': 'availability',
                'retryable': true,
                'userMessageKey': 'errors.request.timeout',
                'correlationId': requestId,
                'detailsSafe': null,
                'providerReferenceSafe': null,
              }, statusCode: 503),
            ),
          );
        }),
      );
      await expectLater(
        validRepository.getCapabilities(),
        throwsA(
          _failure(LoopBackendFailureKind.timeout)
              .having((failure) => failure.code, 'code', 'REQUEST_TIMEOUT')
              .having((failure) => failure.requestId, 'request ID', requestId),
        ),
      );

      final invalidRepository = DioLoopV2MetaRepository.withClient(
        _dio((options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: _response(options, const <String, Object?>{
                'code': 'REQUEST_TIMEOUT',
                'category': 'availability',
                'retryable': true,
                'userMessageKey': 'errors.request.timeout',
                'correlationId': '22222222-2222-4222-8222-222222222222',
                'detailsSafe': null,
                'providerReferenceSafe': null,
              }, statusCode: 503),
            ),
          );
        }),
      );
      await expectLater(
        invalidRepository.getClientPolicy(),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    },
  );

  test('production constructor enforces a credential-free HTTPS origin', () {
    expect(
      () => DioLoopV2MetaRepository(
        origin: Uri.parse('http://api-dev.quant-dinger.cc/'),
      ),
      throwsArgumentError,
    );

    final repository = DioLoopV2MetaRepository(
      origin: Uri.parse('https://api-dev.quant-dinger.cc/'),
    );
    addTearDown(repository.close);
  });
}

DioLoopV2MetaRepository _resolvingRepository(
  Object? value, {
  bool includeRequestId = true,
  String cacheControl = 'no-store',
}) {
  return DioLoopV2MetaRepository.withClient(
    _dio((options, handler) {
      handler.resolve(
        _response(
          options,
          value,
          includeRequestId: includeRequestId,
          cacheControl: cacheControl,
        ),
      );
    }),
  );
}

Dio _dio(void Function(RequestOptions, RequestInterceptorHandler) onRequest) {
  return Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
}

Response<Object?> _response(
  RequestOptions options,
  Object? data, {
  int statusCode = 200,
  String cacheControl = 'no-store',
  bool includeRequestId = true,
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': <String>[cacheControl],
      if (includeRequestId)
        'x-request-id': const <String>['11111111-1111-4111-8111-111111111111'],
    }),
  );
}

Map<String, Object?> _clientPolicy() {
  return <String, Object?>{
    'contractVersion': '2.0',
    'configVersion': 'productPolicyV2.2026-09-01',
    'effectiveAt': '2026-09-01T00:00:00.000Z',
    'defaultRoute': 'community',
    'navigation': <String, Object?>{
      'primaryTabs': <String>[
        'community',
        'mining',
        'launch',
        'market',
        'wallet',
      ],
    },
    'versionGate': <String, Object?>{
      'status': 'unavailable',
      'minimumSupportedVersions': <String, Object?>{
        'ios': null,
        'android': null,
      },
      'storeUrls': <String, Object?>{'ios': null, 'android': null},
      'reasonCode': 'CLIENT_VERSION_POLICY_UNAVAILABLE',
    },
    'regionGate': <String, Object?>{
      'status': 'unavailable',
      'reasonCode': 'REGION_POLICY_UNAVAILABLE',
      'supportUrl': null,
      'readOnlyAssetAccess': null,
    },
    'termsGate': <String, Object?>{
      'status': 'unavailable',
      'requiredVersion': null,
      'reasonCode': 'TERMS_POLICY_UNAVAILABLE',
    },
  };
}

Map<String, Object?> _availableVersionGate() {
  return <String, Object?>{
    'status': 'available',
    'minimumSupportedVersions': <String, Object?>{
      'ios': '1.4.0',
      'android': '1.2.4-beta.1+7',
    },
    'forceUpdateBelow': <String, Object?>{
      'ios': '1.2.0',
      'android': '1.2.4-beta.1+7',
    },
    'storeUrls': <String, Object?>{
      'ios': 'https://apps.apple.com/app/loop',
      'android': 'https://play.google.com/store/apps/details?id=com.cywd.loop',
    },
    'reasonCode': null,
  };
}

Map<String, Object?> _capabilities() {
  return <String, Object?>{
    'contractVersion': '2.0',
    'configVersion': 'productPolicyV2.2026-09-01',
    'effectiveAt': '2026-09-01T00:00:00.000Z',
    'capabilities': <Object?>[
      for (var index = 0; index < LoopV2CapabilityId.values.length; index++)
        <String, Object?>{
          'capabilityId': LoopV2CapabilityId.values[index].wireName,
          'availability': index < 4 ? 'available' : 'deferred',
          'reasonCode': index < 4 ? null : 'RUNTIME_DEFERRED',
          'evidence': <String, Object?>{
            'status': index < 4 ? 'pending' : 'notApplicable',
            'reasonCode': index < 4 ? 'PHYSICAL_DEVICE_EVIDENCE_PENDING' : null,
          },
        },
    ],
  };
}

Object? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name) return entry.value;
  }
  return null;
}

TypeMatcher<LoopBackendFailure> _failure(LoopBackendFailureKind kind) {
  return isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    kind,
  );
}
