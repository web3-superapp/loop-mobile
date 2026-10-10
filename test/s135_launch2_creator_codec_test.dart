import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2_creator/loop_v2_launch2_creator_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2_creator/loop_v2_launch2_creator_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/privy/privy_typed_data_signer.dart';

// ---------------------------------------------------------------------------
// S135 · MEME v2 project side: codecs and transport (client decision 0138)
// ---------------------------------------------------------------------------
//
// The samples under `test/fixtures/s135-launch2-creator/` are handwritten from
// the contract (each carries `_handwritten`); there is no Development capture
// of these routes yet.

const String _projectId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const String _walletId = '00000000-0000-4000-8000-000000000099';
const String _jobId = '00000000-0000-4000-8000-000000000011';
const String _requestId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
final String _signature = '0x${'ab' * 65}';

Map<String, Object?> _record(String name) => jsonDecode(
  File('test/fixtures/s135-launch2-creator/$name.json').readAsStringSync(),
) as Map<String, Object?>;

Object? _body(String name) => _record(name)['body'];

Map<String, Object?> _copy(Object? value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

Response<Object?> _response(RequestOptions options, Map<String, Object?> rec) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: rec['status']! as int,
    data: rec['body'],
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': const <String>['no-store'],
      'x-request-id': const <String>[_requestId],
    }),
  );
}

/// Answers every request with the next scripted record and keeps what was
/// sent.
final class _Script {
  _Script(this.records);

  final List<Object> records;
  final List<RequestOptions> sent = <RequestOptions>[];
  int _next = 0;

  Dio dio() {
    return Dio(BaseOptions(baseUrl: 'https://api-dev.example/'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent.add(options);
            final next =
                records[_next < records.length ? _next : records.length - 1];
            _next += 1;
            if (next is DioExceptionType) {
              handler.reject(DioException(requestOptions: options, type: next));
              return;
            }
            final rec = next as Map<String, Object?>;
            final response = _response(options, rec);
            if ((rec['status']! as int) >= 400) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: response,
                  type: DioExceptionType.badResponse,
                ),
              );
              return;
            }
            handler.resolve(response);
          },
        ),
      );
  }
}

Object? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name) return entry.value;
  }
  return null;
}

LoopAuthenticatedSession _session() {
  final bootstrap = LoopBootstrapSession(
    principalKey: 'did:privy:owner-1',
    accessTokens: _Tokens(),
    repository: _Bootstrap(),
  );
  return LoopAuthenticatedSession(
    principalKey: 'did:privy:owner-1',
    bootstrapSession: bootstrap,
    accessTokens: _Tokens(),
  );
}

final class _Tokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => 'access.token.value';
}

final class _Bootstrap implements LoopBootstrapRepository {
  @override
  Future<LoopBootstrapIdentity> bootstrap({
    required String accessToken,
  }) async => const LoopBootstrapIdentity(
    loopUserId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
    streamUserId: 'loop_6d12a86e413447e69312c5ef75a30f55',
  );
}

DioLoopV2Launch2CreatorGateway _gateway(_Script script) =>
    DioLoopV2Launch2CreatorGateway(
      api: DioLoopV2Launch2CreatorApi(script.dio()),
      clientMetadata: const LoopV2ClientMetadata(
        clientVersion: '1.0.0',
        platform: LoopV2Platform.android,
      ),
      session: _session(),
    );

Launch2ConfigInput _input() => Launch2ConfigInput(
  name: 'MoonCat',
  ticker: 'MCAT',
  logoAssetUrl: 'https://api-dev.example/v2/media/x.webp',
  description: 'A launch project',
  links: const <String>['https://mooncat.example/'],
  nftSaleStart: DateTime.utc(2026, 10, 20, 8),
  buybackRecipient: Launch2Template.defaultBuybackRecipient,
);

void main() {
  group('hooks-config codec', () {
    test('a saved draft is read with its server-derived template', () {
      final draft = LoopV2Launch2CreatorCodec.configEnvelope(
        _body('hooks_config_draft'),
        projectId: _projectId,
      )!;
      expect(draft.version, 1);
      expect(draft.ticker, 'MCAT');
      expect(draft.nftSaleStartAt, BigInt.from(1792000000));
      expect(
        draft.buybackRecipient,
        '0x28816c4c4792467390c90e5b426f198570e29307',
      );
      final economics = draft.economics;
      // The template the page shows before a draft exists is the same one
      // the server derives.
      final v1 = Launch2Template.v1;
      expect(economics.memeTotalSupplyRaw, v1.memeTotalSupplyRaw);
      expect(economics.curveSaleSupplyRaw, v1.curveSaleSupplyRaw);
      expect(economics.graduationReserveUsd1Raw, v1.graduationReserveUsd1Raw);
      expect(economics.perAddressCapBps, 50);
      expect(economics.curveBuyTaxBps, 1000);
      expect(economics.officialPoolBuyTaxBps, 200);
      expect(economics.nftPriceUsd1Raw, v1.nftPriceUsd1Raw);
      // The template's chainId is not the deployment chain (decision 0117).
      expect(economics.templateChainId, '56');
    });

    test('no draft is null, never a default', () {
      expect(
        LoopV2Launch2CreatorCodec.configEnvelope(
          _body('hooks_config_empty'),
          projectId: _projectId,
        ),
        isNull,
      );
    });

    test('an unknown key, a foreign project or an override is invalid', () {
      final extra = _copy(_body('hooks_config_draft'));
      ((extra['draft']! as Map)['config']! as Map)['curveBuyTaxBps'] = 0;
      expect(
        () => LoopV2Launch2CreatorCodec.configEnvelope(
          extra,
          projectId: _projectId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2Launch2CreatorCodec.configEnvelope(
          _body('hooks_config_draft'),
          projectId: '9fa85f64-5717-4562-b3fc-2c963f66afa6',
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      final http = _copy(_body('hooks_config_draft'));
      ((http['draft']! as Map)['config']! as Map)['logoAssetUrl'] =
          'http://insecure.example/logo.png';
      expect(
        () => LoopV2Launch2CreatorCodec.configEnvelope(
          http,
          projectId: _projectId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the PUT body carries only the seven owner fields', () {
      final body = LoopV2Launch2CreatorCodec.configBody(
        expectedVersion: 0,
        input: _input(),
      );
      expect(body.keys, <String>['expectedVersion', 'config']);
      expect((body['config']! as Map).keys.toSet(), <String>{
        'name',
        'ticker',
        'logoAssetUrl',
        'description',
        'links',
        'nftSaleStartAt',
        'buybackRecipient',
      });
      expect((body['config']! as Map)['nftSaleStartAt'], '1792483200');
    });
  });

  group('signing-request codec', () {
    test('the request, the typed data and both predictions are read', () {
      final request = LoopV2Launch2CreatorCodec.signingRequest(
        _body('hooks_signing_request'),
      );
      expect(request.memeAddress, endsWith('6666'));
      expect(request.domainChainId, 97);
      expect(request.deadline, BigInt.from(1791000900));
      expect(request.nonce, '9');
      expect(request.typedData['primaryType'], 'LaunchRequest');
      // The request goes back unchanged.
      final body = LoopV2Launch2CreatorCodec.deploymentBody(
        walletId: _walletId,
        request: request,
        signature: _signature,
      );
      expect(body.keys.toSet(), <String>{
        'walletId',
        'request',
        'hookSalt',
        'signature',
      });
      expect(
        body['request'],
        (_body('hooks_signing_request')! as Map)['request'],
      );
    });

    test('a message that differs from the request is refused', () {
      final tampered = _copy(_body('hooks_signing_request'));
      ((tampered['typedData']! as Map)['message']! as Map)['nftSaleStart'] =
          '1700000000';
      expect(
        () => LoopV2Launch2CreatorCodec.signingRequest(tampered),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a MEME address without the 6666 tail is refused', () {
      final plain = _copy(_body('hooks_signing_request'));
      plain['memeAddress'] = '0x${'a' * 40}';
      expect(
        () => LoopV2Launch2CreatorCodec.signingRequest(plain),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the wallet parameter adds only the EIP-712 domain type', () {
      final request = LoopV2Launch2CreatorCodec.signingRequest(
        _body('hooks_signing_request'),
      );
      final json = jsonDecode(
        launch2TypedDataJson(request.typedData),
      ) as Map<String, Object?>;
      final types = json['types']! as Map<String, Object?>;
      expect(types['EIP712Domain'], <Object?>[
        <String, Object?>{'name': 'name', 'type': 'string'},
        <String, Object?>{'name': 'version', 'type': 'string'},
        <String, Object?>{'name': 'chainId', 'type': 'uint256'},
        <String, Object?>{'name': 'verifyingContract', 'type': 'address'},
      ]);
      expect(
        types['LaunchRequest'],
        request.typedData['types'] is Map
            ? (request.typedData['types']! as Map)['LaunchRequest']
            : null,
      );
      expect(json['message'], request.typedData['message']);
      expect(json['domain'], request.typedData['domain']);
    });
  });

  group('deployment job codec', () {
    test('the full successful run reads in sequence order', () {
      final job = LoopV2Launch2CreatorCodec.job(
        _body('hooks_deployment_activated'),
        projectId: _projectId,
        jobId: _jobId,
      );
      expect(job.status, Launch2JobStatus.activated);
      expect(job.settled, isTrue);
      expect(job.events.map((event) => event.kind), <String>[
        'created',
        'claimed',
        'broadcast',
        'confirmed',
        'verified',
        'activation_broadcast',
        'activated',
      ]);
      expect(job.deployedLaunchId, isNotNull);
      expect(job.deployedMeme, endsWith('6666'));
    });

    test(
      'a final failure carries its code; an out-of-order event is invalid',
      () {
        final failed = LoopV2Launch2CreatorCodec.job(
          _body('hooks_deployment_failed'),
          projectId: _projectId,
        );
        expect(failed.failure?.code, 'HOOKS_SIGNATURE_EXPIRED');
        expect(failed.failure?.retryable, isFalse);
        expect(failed.settled, isTrue);

        final shuffled = _copy(_body('hooks_deployment_activated'));
        final events = shuffled['events']! as List<Object?>;
        final first = events.removeAt(0);
        events.add(first);
        expect(
          () => LoopV2Launch2CreatorCodec.job(shuffled, projectId: _projectId),
          throwsA(isA<LoopBackendFailure>()),
        );
      },
    );

    test('an unknown event kind is kept; an unknown status is invalid', () {
      final open = _copy(_body('hooks_deployment_created'));
      ((open['events']! as List<Object?>).first! as Map)['kind'] =
          'lease_taken_over';
      expect(
        LoopV2Launch2CreatorCodec.job(
          open,
          projectId: _projectId,
        ).events.single.kind,
        'lease_taken_over',
      );
      final closed = _copy(_body('hooks_deployment_created'));
      closed['status'] = 'deployed';
      expect(
        () => LoopV2Launch2CreatorCodec.job(closed, projectId: _projectId),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the instance list yields the project it became', () {
      final page = LoopV2Launch2CreatorCodec.instancePage(
        _body('launch2_instances'),
      );
      expect(page.rows.single.projectId, _projectId);
      expect(page.rows.single.stage, 'upcoming');
    });
  });

  group('status projection', () {
    Launch2DeploymentJob job(String name) =>
        LoopV2Launch2CreatorCodec.job(_body(name), projectId: _projectId);

    test('the ten design states come from the three server facts', () {
      Launch2CreatorStatus of(
        LaunchReviewStatus review, {
        bool draft = true,
        Launch2DeploymentJob? job,
        bool notApproved = false,
      }) => launch2CreatorStatusOf(
        reviewStatus: review,
        hasDraft: draft,
        job: job,
        configAwaitingApproval: notApproved,
      );
      expect(of(LaunchReviewStatus.draft), Launch2CreatorStatus.draft);
      expect(
        of(LaunchReviewStatus.inReview),
        Launch2CreatorStatus.awaitingApproval,
      );
      expect(of(LaunchReviewStatus.returned), Launch2CreatorStatus.rejected);
      expect(of(LaunchReviewStatus.rejected), Launch2CreatorStatus.rejected);
      expect(of(LaunchReviewStatus.approved), Launch2CreatorStatus.approved);
      expect(
        of(LaunchReviewStatus.approved, draft: false),
        Launch2CreatorStatus.draft,
      );
      expect(
        of(LaunchReviewStatus.approved, notApproved: true),
        Launch2CreatorStatus.awaitingApproval,
      );
      expect(
        of(LaunchReviewStatus.approved, job: job('hooks_deployment_created')),
        Launch2CreatorStatus.deploying,
      );
      expect(
        of(LaunchReviewStatus.approved, job: job('hooks_deployment_failed')),
        Launch2CreatorStatus.deployFailed,
      );
      expect(
        of(LaunchReviewStatus.approved, job: job('hooks_deployment_activated')),
        Launch2CreatorStatus.active,
      );
    });
  });

  group('transport', () {
    test('PUT hooks-config is a CAS write with no Idempotency-Key', () async {
      final script = _Script(<Object>[_record('hooks_config_put')]);
      final draft = await _gateway(
        script,
      ).saveConfig(projectId: _projectId, expectedVersion: 1, input: _input());
      expect(draft.version, 2);
      final sent = script.sent.single;
      expect(sent.method, 'PUT');
      expect(sent.path, '/v2/launch/projects/$_projectId/hooks-config');
      expect(_header(sent, 'idempotency-key'), isNull);
      expect(_header(sent, 'x-loop-contract-version'), '2.0');
      expect((sent.data as Map)['expectedVersion'], 1);
    });

    test('a sale start the server refuses is invalidData (400)', () async {
      final script = _Script(<Object>[_record('error_sale_too_early')]);
      await expectLater(
        _gateway(script).saveConfig(
          projectId: _projectId,
          expectedVersion: 0,
          input: _input(),
        ),
        throwsA(
          isA<LoopChainException>().having(
            (error) => error.kind,
            'kind',
            LoopChainFailureKind.invalidData,
          ),
        ),
      );
    });

    test('the signing request reads with the opaque walletId', () async {
      final script = _Script(<Object>[_record('hooks_signing_request')]);
      final request = await _gateway(script)
          .loadSigningRequest(projectId: _projectId, walletId: _walletId);
      expect(request.ticker, 'MCAT');
      expect(script.sent.single.queryParameters, <String, Object?>{
        'walletId': _walletId,
      });
      expect(_header(script.sent.single, 'idempotency-key'), isNull);
    });

    test('the submit carries one UUIDv4; an unresolved retry replays it, a '
        'new signature takes a new one', () async {
      final request = LoopV2Launch2CreatorCodec.signingRequest(
        _body('hooks_signing_request'),
      );
      final script = _Script(<Object>[
        DioExceptionType.connectionError,
        _record('hooks_deployment_created'),
        _record('hooks_deployment_created'),
      ]);
      final gateway = _gateway(script);
      await expectLater(
        gateway.submitDeployment(
          projectId: _projectId,
          walletId: _walletId,
          request: request,
          signature: _signature,
        ),
        throwsA(isA<LoopChainException>()),
      );
      final job = await gateway.submitDeployment(
        projectId: _projectId,
        walletId: _walletId,
        request: request,
        signature: _signature,
      );
      expect(job.status, Launch2JobStatus.awaitingExecutor);
      final first = _header(script.sent[0], 'idempotency-key')! as String;
      final second = _header(script.sent[1], 'idempotency-key')! as String;
      expect(LoopV2Contract.uuidV4Pattern.hasMatch(first), isTrue);
      expect(second, first);
      await gateway.submitDeployment(
        projectId: _projectId,
        walletId: _walletId,
        request: request,
        signature: '0x${'cd' * 65}',
      );
      final third = _header(script.sent[2], 'idempotency-key')! as String;
      expect(third, isNot(first));
      expect((script.sent[2].data as Map)['request'], request.request);
    });

    test('409, 403 and 503 keep the server rule', () async {
      final request = LoopV2Launch2CreatorCodec.signingRequest(
        _body('hooks_signing_request'),
      );
      Future<LoopChainException> refusal(String name) async {
        final script = _Script(<Object>[_record(name)]);
        try {
          await _gateway(script).submitDeployment(
            projectId: _projectId,
            walletId: _walletId,
            request: request,
            signature: _signature,
          );
        } on LoopChainException catch (error) {
          return error;
        }
        fail('expected a refusal for $name');
      }

      expect(
        (await refusal('error_version_conflict')).kind,
        LoopChainFailureKind.versionConflict,
      );
      final notApproved = await refusal('error_config_not_approved');
      expect(notApproved.kind, LoopChainFailureKind.permissionDenied);
      expect(notApproved.reasonCode, 'HOOKS_CONFIG_NOT_APPROVED');

      final script = _Script(<Object>[_record('error_hooks_disabled')]);
      await expectLater(
        _gateway(script).loadConfig(_projectId),
        throwsA(
          isA<LoopChainException>()
              .having((e) => e.kind, 'kind', LoopChainFailureKind.unavailable)
              .having((e) => e.reasonCode, 'reason', 'HOOKS_LAUNCH_DISABLED'),
        ),
      );
    });

    test('the job read checks it is the job asked for', () async {
      final script = _Script(<Object>[_record('hooks_deployment_activated')]);
      final job = await _gateway(script)
          .loadDeployment(projectId: _projectId, jobId: _jobId);
      expect(job.status, Launch2JobStatus.activated);
      expect(
        script.sent.single.path,
        '/v2/launch/projects/$_projectId/hooks-deployments/$_jobId',
      );
      final other = _Script(<Object>[_record('hooks_deployment_activated')]);
      await expectLater(
        _gateway(other).loadDeployment(
          projectId: _projectId,
          jobId: '00000000-0000-4000-8000-000000000012',
        ),
        throwsA(isA<LoopChainException>()),
      );
    });

    test('the activated instance is found by its project', () async {
      final script = _Script(<Object>[_record('launch2_instances')]);
      final found = await _gateway(script).findInstance(_projectId);
      expect(found?.instanceId, '8b9f3c1e-2d4a-4f6b-9c8d-1e2f3a4b5c6d');
      expect(script.sent.single.queryParameters, <String, Object?>{
        'limit': 50,
      });
      final none = _Script(<Object>[_record('launch2_instances')]);
      expect(
        await _gateway(none)
            .findInstance('9fa85f64-5717-4562-b3fc-2c963f66afa6'),
        isNull,
      );
    });
  });

  test('every sample says it is handwritten', () {
    final directory = Directory('test/fixtures/s135-launch2-creator');
    final files = directory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.json'),
    );
    expect(files, isNotEmpty);
    for (final file in files) {
      final record =
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      expect(record['_handwritten'], isA<String>(), reason: file.path);
    }
  });
}
