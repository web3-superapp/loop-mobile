// Decision 0287: the single-project read (`GET /v2/launch/projects/{id}`)
// carries the three project-term keys while loop-api 0199's
// `LAUNCH2_PROJECT_TERMS_EMIT` is on. They are read with the same rules as
// the hooks-config draft (client 0284).
//
// The bodies reuse the handwritten S148 samples and add the term keys.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';

const _token = 'access-token';
const _clientVersion = '1.4.0';
const _projectId = '17f6a9b2-2f22-4c11-9f3a-1a2b3c4d5e6f';
const _directory = 'test/fixtures/s149-s148-api';

Map<String, Object?> _body(String name) {
  final record = jsonDecode(
    File('$_directory/$name.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return jsonDecode(jsonEncode(record['body'])) as Map<String, Object?>;
}

final class _Replay implements HttpClientAdapter {
  _Replay(this.body);

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

DioLoopV2LaunchApi _api(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _Replay(body);
  return DioLoopV2LaunchApi(dio);
}

Matcher get _invalidPayload => throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

const _terms = <String, Object?>{
  'nftPriceUsd1': 150,
  'walletCapPerMille': 8,
  'maxCumulativeBuyRaw': '8000000000000000000000000',
};

Map<String, Object?> _single(Map<String, Object?> extra) {
  final body = _body('launch_project_with_community');
  (body['project']! as Map<String, Object?>).addAll(extra);
  return body;
}

Future<Object?> _get(Map<String, Object?> body) => _api(body).getProject(
  accessToken: _token,
  clientVersion: _clientVersion,
  projectId: _projectId,
);

void main() {
  group('launch · single project · project terms (0287)', () {
    test('the three term keys decode onto the project', () async {
      final project = await _api(_single(_terms)).getProject(
        accessToken: _token,
        clientVersion: _clientVersion,
        projectId: _projectId,
      );
      expect(project.nftPriceUsd1, 150);
      expect(project.walletCapPerMille, 8);
      expect(
        project.maxCumulativeBuyRaw,
        BigInt.parse('8000000000000000000000000'),
      );
    });

    test('absent term keys decode as null', () async {
      final project = await _api(_single(const {})).getProject(
        accessToken: _token,
        clientVersion: _clientVersion,
        projectId: _projectId,
      );
      expect(project.nftPriceUsd1, isNull);
      expect(project.walletCapPerMille, isNull);
      expect(project.maxCumulativeBuyRaw, isNull);
    });

    test('null term keys decode as null', () async {
      final project =
          await _api(
            _single(const <String, Object?>{
              'nftPriceUsd1': null,
              'walletCapPerMille': null,
              'maxCumulativeBuyRaw': null,
            }),
          ).getProject(
            accessToken: _token,
            clientVersion: _clientVersion,
            projectId: _projectId,
          );
      expect(project.nftPriceUsd1, isNull);
      expect(project.walletCapPerMille, isNull);
      expect(project.maxCumulativeBuyRaw, isNull);
    });

    test('an out-of-range or mistyped nftPriceUsd1 is refused', () async {
      for (final value in <Object?>[0, 1001, '150', 1.5]) {
        await expectLater(
          _get(_single(<String, Object?>{..._terms, 'nftPriceUsd1': value})),
          _invalidPayload,
          reason: '$value',
        );
      }
    });

    test('an out-of-range walletCapPerMille is refused', () async {
      for (final value in <Object?>[0, 1001, '8']) {
        await expectLater(
          _get(
            _single(<String, Object?>{..._terms, 'walletCapPerMille': value}),
          ),
          _invalidPayload,
          reason: '$value',
        );
      }
    });

    test('a zero or malformed maxCumulativeBuyRaw is refused', () async {
      for (final value in <Object?>['0', '-1', '01', 8, '1e24']) {
        await expectLater(
          _get(
            _single(<String, Object?>{..._terms, 'maxCumulativeBuyRaw': value}),
          ),
          _invalidPayload,
          reason: '$value',
        );
      }
    });

    test('an unknown key next to the terms is still refused', () async {
      await expectLater(
        _get(_single(<String, Object?>{..._terms, 'nftPriceWei': '1'})),
        _invalidPayload,
      );
    });
  });

  group('launch · project list · project terms (0287)', () {
    test('list items carrying the term keys still decode', () async {
      final body = _body('launch_projects_mixed');
      final items = body['items']! as List<Object?>;
      (items.first! as Map<String, Object?>).addAll(_terms);
      final page = await _api(body)
          .listProjects(accessToken: _token, clientVersion: _clientVersion);
      expect(page.items.first.nftPriceUsd1, 150);
      expect(page.items.first.walletCapPerMille, 8);
      expect(
        page.items.first.maxCumulativeBuyRaw,
        BigInt.parse('8000000000000000000000000'),
      );
      expect(page.items.last.nftPriceUsd1, isNull);
      expect(page.items.last.walletCapPerMille, isNull);
      expect(page.items.last.maxCumulativeBuyRaw, isNull);
    });
  });
}
