// Decision 0147: the client side of loop-api S148 (Decision 0125).
//
// Every sample under test/fixtures/s149-s148-api/ is handwritten from the
// loop-api S148 contract docs and OpenAPI (see each file's `_handwritten`).
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';
import 'package:loop_mobile/integrations/backend/v2/mining/loop_v2_mining_api.dart';

import 'support/s7_page_harness.dart';

const _token = 'access-token';
const _clientVersion = '1.4.0';
const _idempotencyKey = '66666666-7777-4888-8999-aaaaaaaaaaaa';
const _projectId = '17f6a9b2-2f22-4c11-9f3a-1a2b3c4d5e6f';
const _communityId = '5b0c9d18-6a44-4f39-b0d2-9e8f7a6b5c4d';
const _cake = 'eip155:56:0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82';

const _directory = 'test/fixtures/s149-s148-api';

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('$_directory/$name.json').readAsStringSync())
        as Map<String, Object?>;

/// A deep copy of one sample's body, so a test may bend it.
Map<String, Object?> _body(String name) =>
    jsonDecode(jsonEncode(_fixture(name)['body'])) as Map<String, Object?>;

/// Replays one canned response and records the request.
final class _Replay implements HttpClientAdapter {
  _Replay(this.status, this.body);

  final int status;
  final Object? body;
  RequestOptions? seen;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>['11111111-2222-4333-8444-555555555555'],
      },
    );
  }
}

Dio _dio(_Replay adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = adapter;
  return dio;
}

(DioLoopV2MiningApi, _Replay) _mining(Object? body, {int status = 200}) {
  final adapter = _Replay(status, body);
  return (DioLoopV2MiningApi(_dio(adapter)), adapter);
}

(DioLoopV2LaunchApi, _Replay) _launch(Object? body, {int status = 200}) {
  final adapter = _Replay(status, body);
  return (DioLoopV2LaunchApi(_dio(adapter)), adapter);
}

Matcher get _invalidPayload => throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

const _draft = LaunchProjectDraft(
  name: 'Frog',
  ticker: 'FROG',
  narrative: null,
  officialLinks: LaunchOfficialLinks(
    website: null,
    x: null,
    telegram: null,
    discord: null,
  ),
);

void main() {
  test('every sample says where it came from', () {
    final names = Directory(_directory)
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last.replaceAll('.json', ''))
        .toList();
    expect(names, hasLength(10));
    for (final name in names) {
      final record = _fixture(name);
      expect(record['_handwritten'], contains('ba6aa45'), reason: name);
    }
  });

  group('mining · assetPowerBasis', () {
    test('the summary keeps quantity, available and unavailable', () async {
      for (final name in <String>[
        'mining_summary_quantity',
        'mining_summary_unavailable_quantity',
      ]) {
        final (api, _) = _mining(_body(name));
        final summary = await api.getSummary(
          accessToken: _token,
          clientVersion: _clientVersion,
        );
        expect(
          summary.assetPowerBasis,
          MiningAssetPowerBasis.quantity,
          reason: name,
        );
      }
    });

    test('the assets read keeps quantity and the server power', () async {
      final (api, _) = _mining(_body('mining_assets_quantity'));
      final assets = await api.getAssets(
        accessToken: _token,
        clientVersion: _clientVersion,
      );
      expect(assets.assetPowerBasis, MiningAssetPowerBasis.quantity);
      final row = assets.included.single;
      expect(row.assetId, _cake);
      expect(row.holding, '10');
      expect(row.weight, '0.8');
      expect(row.power, '8');
    });

    test('a server before 0125 sends no key and still parses', () async {
      final summaryBody = _body('mining_summary_quantity')
        ..remove('assetPowerBasis');
      final (summaryApi, _) = _mining(summaryBody);
      final summary = await summaryApi.getSummary(
        accessToken: _token,
        clientVersion: _clientVersion,
      );
      expect(summary.assetPowerBasis, isNull);

      final assetsBody = _body('mining_assets_quantity')
        ..remove('assetPowerBasis');
      final (assetsApi, _) = _mining(assetsBody);
      final assets = await assetsApi.getAssets(
        accessToken: _token,
        clientVersion: _clientVersion,
      );
      expect(assets.assetPowerBasis, isNull);
    });

    test('any other basis, or null, is refused', () async {
      for (final value in <Object?>['price', null, 1]) {
        final (summaryApi, _) = _mining(
          _body('mining_summary_quantity')..['assetPowerBasis'] = value,
        );
        expect(
          () => summaryApi.getSummary(
            accessToken: _token,
            clientVersion: _clientVersion,
          ),
          _invalidPayload,
          reason: '$value',
        );
        final (assetsApi, _) = _mining(
          _body('mining_assets_quantity')..['assetPowerBasis'] = value,
        );
        expect(
          () => assetsApi.getAssets(
            accessToken: _token,
            clientVersion: _clientVersion,
          ),
          _invalidPayload,
          reason: '$value',
        );
      }
    });

    test('an unknown key next to it is still refused', () async {
      final (api, _) = _mining(
        _body('mining_summary_quantity')..['somethingNew'] = true,
      );
      expect(
        () =>
            api.getSummary(accessToken: _token, clientVersion: _clientVersion),
        _invalidPayload,
      );
    });
  });

  group('mining · rules', () {
    test('holdingTimesWeight parses and reads 持有量 × 权重', () async {
      final (api, _) = _mining(_body('mining_rules_holding_times_weight'));
      final rules = await api.getRules(
        accessToken: _token,
        clientVersion: _clientVersion,
      );
      final approved = rules.approved!;
      expect(approved.expressionKey, 'mining.rules.formula.holdingTimesWeight');
      expect(miningRuleKeyText(approved.expressionKey), '算力 = 持有量 × 权重');
      // Deprecated, still published, still parsed.
      expect(
        approved.priceGuardRules.single.ruleKey,
        'mining.rules.priceGuard.twap',
      );
    });

    testWidgets('the rules page states the quantity formula, no guards', (
      tester,
    ) async {
      final (api, _) = _mining(_body('mining_rules_holding_times_weight'));
      // Dio reads its body on real timers, outside the widget test's clock.
      final rules = (await tester.runAsync(
        () => api.getRules(accessToken: _token, clientVersion: _clientVersion),
      ))!;
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(rules: S7Answer<MiningRules>(value: rules)),
      );
      expect(find.text('算力 = 持有量 × 权重'), findsWidgets);
      expect(find.textContaining('参考价'), findsNothing);
      expect(find.text('Reference Price Guard'), findsNothing);
      expect(
        find.text(miningRuleKeyText('mining.rules.priceGuard.twap')),
        findsNothing,
      );
    });

    testWidgets('the assets page reads a 0125 answer', (tester) async {
      final (api, _) = _mining(_body('mining_assets_quantity'));
      final assets = (await tester.runAsync(
        () => api.getAssets(accessToken: _token, clientVersion: _clientVersion),
      ))!;
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: FakeMiningGateway(
          assets: S7Answer<MiningAssets>(value: assets),
        ),
      );
      final row = find.byKey(
        const ValueKey<String>('mining-assets-row-$_cake'),
      );
      await scrollToS7Section(tester, row);
      expect(row, findsOneWidget);
      expect(find.textContaining('10 × 0.8×'), findsOneWidget);
      expect(find.textContaining(r'$2.26'), findsNothing);
    });
  });

  group('launch · communityId', () {
    test('a project naming a community keeps its id', () async {
      final (api, _) = _launch(_body('launch_project_with_community'));
      final project = await api.getProject(
        accessToken: _token,
        clientVersion: _clientVersion,
        projectId: _projectId,
      );
      expect(project.communityId, _communityId);
      expect(project.kind, LaunchProjectKind.launch2);
    });

    test('a list mixes named and unnamed projects', () async {
      final (api, _) = _launch(_body('launch_projects_mixed'));
      final page = await api.listProjects(
        accessToken: _token,
        clientVersion: _clientVersion,
      );
      expect(page.items.map((project) => project.communityId), <String?>[
        _communityId,
        null,
      ]);
    });

    test('a null or malformed communityId is refused', () async {
      for (final value in <Object?>[null, 'not-a-uuid', 7]) {
        final body = _body('launch_project_with_community');
        (body['project']! as Map<String, Object?>)['communityId'] = value;
        final (api, _) = _launch(body);
        expect(
          () => api.getProject(
            accessToken: _token,
            clientVersion: _clientVersion,
            projectId: _projectId,
          ),
          _invalidPayload,
          reason: '$value',
        );
      }
    });

    test('the default draft sends no communityId on create or edit', () async {
      expect(_draft.toCreateRequestJson().containsKey('communityId'), isFalse);
      expect(_draft.toRequestJson().containsKey('communityId'), isFalse);
      expect(_draft.community.isKeep, isTrue);

      final (api, adapter) = _launch(
        _body('launch_project_with_community'),
        status: 201,
      );
      await api.createProject(
        accessToken: _token,
        clientVersion: _clientVersion,
        idempotencyKey: _idempotencyKey,
        draft: _draft,
      );
      final sent = adapter.seen!.data as Map<String, Object?>;
      expect(sent.containsKey('communityId'), isFalse);
    });

    test('a named community rides the create and the edit body', () async {
      const bound = LaunchProjectDraft(
        name: 'Frog',
        ticker: 'FROG',
        narrative: null,
        officialLinks: LaunchOfficialLinks(
          website: null,
          x: null,
          telegram: null,
          discord: null,
        ),
        kind: LaunchProjectKind.launch2,
        community: LaunchDraftCommunity.bind(_communityId),
      );
      expect(bound.invalidField, isNull);

      final (create, created) = _launch(
        _body('launch_project_with_community'),
        status: 201,
      );
      final project = await create.createProject(
        accessToken: _token,
        clientVersion: _clientVersion,
        idempotencyKey: _idempotencyKey,
        draft: bound,
      );
      expect(project.communityId, _communityId);
      final createBody = created.seen!.data as Map<String, Object?>;
      expect(createBody['communityId'], _communityId);
      expect(createBody['kind'], 'launch2');

      final (edit, edited) = _launch(_body('launch_project_with_community'));
      await edit.putProject(
        accessToken: _token,
        clientVersion: _clientVersion,
        projectId: _projectId,
        expectedVersion: 1,
        draft: bound,
      );
      final editBody = edited.seen!.data as Map<String, Object?>;
      expect(
        (editBody['project']! as Map<String, Object?>)['communityId'],
        _communityId,
      );
    });

    test('clearing sends an explicit null on edit', () async {
      const cleared = LaunchProjectDraft(
        name: 'Frog',
        ticker: 'FROG',
        narrative: null,
        officialLinks: LaunchOfficialLinks(
          website: null,
          x: null,
          telegram: null,
          discord: null,
        ),
        community: LaunchDraftCommunity.clear(),
      );
      final json = cleared.toRequestJson();
      expect(json.containsKey('communityId'), isTrue);
      expect(json['communityId'], isNull);
      expect(cleared.community.isClear, isTrue);
    });

    test('a malformed community id is caught before the request', () async {
      const wrong = LaunchProjectDraft(
        name: 'Frog',
        ticker: 'FROG',
        narrative: null,
        officialLinks: LaunchOfficialLinks(
          website: null,
          x: null,
          telegram: null,
          discord: null,
        ),
        community: LaunchDraftCommunity.bind('5B0C9D18-6A44-4F39-B0D2'),
      );
      expect(wrong.invalidField, LaunchDraftField.community);
      expect(
        launchDraftFieldReason(LaunchDraftField.community),
        '关联社区的标识无效，请重新选择。',
      );
      final (api, adapter) = _launch(_body('launch_project_with_community'));
      expect(
        () => api.createProject(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _idempotencyKey,
          draft: wrong,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(adapter.seen, isNull);
    });

    test('422 LAUNCH_COMMUNITY_NOT_OWNED keeps its reason code', () async {
      final (api, _) = _launch(
        _body('launch_project_create_422_community_not_owned'),
        status: 422,
      );
      Object? caught;
      try {
        await api.createProject(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _idempotencyKey,
          draft: const LaunchProjectDraft(
            name: 'Frog',
            ticker: 'FROG',
            narrative: null,
            officialLinks: LaunchOfficialLinks(
              website: null,
              x: null,
              telegram: null,
              discord: null,
            ),
            community: LaunchDraftCommunity.bind(_communityId),
          ),
        );
      } catch (error) {
        caught = error;
      }
      final failure = caught! as LoopBackendFailure;
      expect(failure.statusCode, 422);
      expect(failure.code, 'VALIDATION_FAILED');
      expect(failure.detailsSafe?.reasonCode, 'LAUNCH_COMMUNITY_NOT_OWNED');
      expect(
        launchReasonCodeText('LAUNCH_COMMUNITY_NOT_OWNED'),
        '只能关联你担任群主的社区；这个社区不存在、已被驳回，或你已不是群主。资料没有保存。',
      );
    });
  });
}
