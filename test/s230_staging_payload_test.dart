// S230 · client decision 0201: the staging capability document, decoded the
// way the App decodes it, against the decision 0200 evidence rule.
//
// The fixture is an unedited capture of staging (loop-api aefffe0); build 28
// still drew 「测试网合约还在核对」 on it because that APK was not built from
// the decision 0200 commit (see 0201), not because staging answers another
// reason code.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';

void main() {
  test('staging capabilities: launch2 is available, evidence pending with the '
      'module marker, and the project page draws no evidence line', () async {
    final record = jsonDecode(
      File('test/fixtures/s230/capabilities_staging.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final repository = DioLoopV2MetaRepository.withClient(
      Dio(BaseOptions(baseUrl: 'https://api-staging.quant-dinger.cc/'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: record['body'],
                headers: Headers.fromMap(<String, List<String>>{
                  'cache-control': <String>['no-store'],
                  'x-request-id': <String>[
                    '11111111-1111-4111-8111-111111111111',
                  ],
                }),
              ),
            ),
          ),
        ),
    );
    final capabilities = await repository.getCapabilities();
    final projection = LoopCapabilityProjector.of(
      capabilities,
      LoopV2CapabilityId.launch2,
    );
    expect(projection.isAvailable, isTrue);
    expect(projection.evidencePending, isTrue);
    expect(projection.evidenceReasonCode, launch2TestnetEvidencePendingCode);
    expect(launch2EvidenceNoticeShown(projection), isFalse);
  });
}
