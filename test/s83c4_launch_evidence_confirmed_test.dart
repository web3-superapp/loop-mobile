import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';

import 'support/loop_ground_probe.dart';

/// loop-api decision 0083: the `launch` capability's evidence reads
/// `confirmed` with `reasonCode: LAUNCH_CONTRACT_CONFIRMED` and an optional
/// `launchContractVersion` once the contract adapter verified the contract.
/// A device round on 2026-09-27 showed the old decoder refusing that
/// document as a whole, which the app rendered as 「连不上 LOOP」.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  loopWatchGround();

  Map<String, Object?> body({
    required Map<String, Object?> launchEvidence,
    LoopV2CapabilityId onCapability = LoopV2CapabilityId.launch,
  }) => <String, Object?>{
    'contractVersion': '2.0',
    'configVersion': 'productPolicyV2.2026-09-01',
    'effectiveAt': '2026-09-01T00:00:00.000Z',
    'capabilities': <Object?>[
      for (final id in LoopV2CapabilityId.values)
        <String, Object?>{
          'capabilityId': id.wireName,
          'availability': 'available',
          'reasonCode': null,
          'evidence': id == onCapability
              ? launchEvidence
              : <String, Object?>{
                  'status': 'pending',
                  'reasonCode': 'AUDIO_ROOM_USER_ROLE_EVIDENCE_PENDING',
                },
        },
    ],
  };

  Future<LoopV2Capabilities> read(Map<String, Object?> document) =>
      DioLoopV2MetaRepository.withClient(_metaDio(document)).getCapabilities();

  const confirmed = <String, Object?>{
    'status': 'confirmed',
    'reasonCode': 'LAUNCH_CONTRACT_CONFIRMED',
    'launchChainId': 'eip155:97',
    'launchContractVersion': '1.0.0',
  };

  test(
    'the live 2026-09-27 launch evidence decodes and opens the gate',
    () async {
      final capabilities = await read(body(launchEvidence: confirmed));
      final evidence = capabilities[LoopV2CapabilityId.launch].evidence;
      expect(evidence.status, LoopV2CapabilityEvidenceStatus.confirmed);
      expect(evidence.reasonCode, 'LAUNCH_CONTRACT_CONFIRMED');
      expect(evidence.launchChainId, 'eip155:97');
      expect(evidence.launchContractVersion, '1.0.0');
      expect(evidence.reference, isNull);
      final projection = LoopCapabilityProjector.of(
        capabilities,
        LoopV2CapabilityId.launch,
      );
      expect(projection.evidencePending, isFalse);
    },
  );

  test('confirmed on launch without the version still decodes', () async {
    final capabilities = await read(
      body(
        launchEvidence: const <String, Object?>{
          'status': 'confirmed',
          'reasonCode': 'LAUNCH_CONTRACT_CONFIRMED',
        },
      ),
    );
    expect(
      capabilities[LoopV2CapabilityId.launch].evidence.launchContractVersion,
      isNull,
    );
  });

  test(
    'a pending launch evidence with the adapter reason stays pending',
    () async {
      final capabilities = await read(
        body(
          launchEvidence: const <String, Object?>{
            'status': 'pending',
            'reasonCode': 'LAUNCH_CONTRACT_CODE_MISSING',
            'launchChainId': 'eip155:97',
          },
        ),
      );
      final projection = LoopCapabilityProjector.of(
        capabilities,
        LoopV2CapabilityId.launch,
      );
      expect(projection.evidencePending, isTrue);
      expect(projection.evidenceReasonCode, 'LAUNCH_CONTRACT_CODE_MISSING');
    },
  );

  for (final (label, evidence, on)
      in <(String, Map<String, Object?>, LoopV2CapabilityId)>[
        (
          'confirmed on launch without a reason code',
          <String, Object?>{'status': 'confirmed', 'reasonCode': null},
          LoopV2CapabilityId.launch,
        ),
        (
          'confirmed on launch with a reference',
          <String, Object?>{
            'status': 'confirmed',
            'reasonCode': 'LAUNCH_CONTRACT_CONFIRMED',
            'reference': 'ops-2026-09-27',
          },
          LoopV2CapabilityId.launch,
        ),
        (
          'a malformed launchContractVersion',
          <String, Object?>{
            'status': 'confirmed',
            'reasonCode': 'LAUNCH_CONTRACT_CONFIRMED',
            'launchContractVersion': 'v1',
          },
          LoopV2CapabilityId.launch,
        ),
        (
          'launchContractVersion beside a pending status',
          <String, Object?>{
            'status': 'pending',
            'reasonCode': 'LAUNCH_CONTRACT_BASELINE_PENDING',
            'launchContractVersion': '1.0.0',
          },
          LoopV2CapabilityId.launch,
        ),
        (
          'launchContractVersion on another capability',
          <String, Object?>{
            'status': 'pending',
            'reasonCode': 'MINING_FORMULA_BASELINE_PENDING',
            'launchContractVersion': '1.0.0',
          },
          LoopV2CapabilityId.mining,
        ),
      ]) {
    test('$label is an invalid payload', () async {
      await expectLater(
        read(body(launchEvidence: evidence, onCapability: on)),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidPayload,
          ),
        ),
      );
    });
  }
}

Dio _metaDio(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _StubAdapter(body);
  return dio;
}

final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final Object? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>['11111111-2222-4333-8444-555555555555'],
      },
    );
  }
}
