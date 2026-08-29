import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/network/loop_dio_factory.dart';

void main() {
  group('LoopDioFactory', () {
    test('common clients use bounded defaults without credential headers', () {
      final clients = <Dio>[
        LoopDioFactory.createCredentialFreePublic(
          origin: Uri.parse('https://public.example.com/'),
        ),
        LoopDioFactory.createLoopBackend(
          origin: Uri.parse('https://api.example.com/'),
        ),
      ];
      addTearDown(() {
        for (final client in clients) {
          client.close(force: true);
        }
      });

      for (final client in clients) {
        expect(client.options.connectTimeout, const Duration(seconds: 10));
        expect(client.options.sendTimeout, const Duration(seconds: 10));
        expect(client.options.receiveTimeout, const Duration(seconds: 15));
        expect(client.options.followRedirects, isFalse);
        expect(client.options.maxRedirects, 0);
        expect(client.options.responseType, ResponseType.json);
        expect(
          client.options.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(
          client.options.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('cookie')),
        );
        expect(
          client.options.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('idempotency-key')),
        );
      }
    });

    test(
      'credential-free public client accepts only its exact HTTPS origin',
      () async {
        final client = LoopDioFactory.createCredentialFreePublic(
          origin: Uri.parse('https://public.example.com/'),
        );
        addTearDown(() => client.close(force: true));
        final dispatched = <RequestOptions>[];
        _resolveRequests(client, dispatched);

        await client.post<Object?>(
          '/info',
          data: const <String, String>{'type': 'publicFacts'},
        );

        expect(dispatched, hasLength(1));
        expect(
          dispatched.single.uri,
          Uri.parse('https://public.example.com/info'),
        );

        for (final location in <String>[
          'http://public.example.com:443/info',
          'https://public.example.com:444/info',
          'https://other.example.com/info',
        ]) {
          await expectLater(
            client.get<Object?>(location),
            throwsA(_boundaryViolation()),
          );
        }
        expect(dispatched, hasLength(1));
      },
    );

    test('credential-free public client rejects credential headers before dispatch', () async {
      final client = LoopDioFactory.createCredentialFreePublic(
        origin: Uri.parse('https://public.example.com/'),
      );
      addTearDown(() => client.close(force: true));
      final dispatched = <RequestOptions>[];
      _resolveRequests(client, dispatched);

      for (final headers in <Map<String, String>>[
        const <String, String>{'Authorization': 'Bearer private-token'},
        const <String, String>{'Cookie': 'session=private-cookie'},
        const <String, String>{'X-Api-Key': 'private-api-key'},
      ]) {
        await expectLater(
          client.get<Object?>('/info', options: Options(headers: headers)),
          throwsA(_boundaryViolation()),
        );
      }

      expect(dispatched, isEmpty);
    });

    test(
      'backend client accepts request-local bearer only on its exact origin',
      () async {
        final client = LoopDioFactory.createLoopBackend(
          origin: Uri.parse('https://api.example.com/'),
        );
        addTearDown(() => client.close(force: true));
        final dispatched = <RequestOptions>[];
        _resolveRequests(client, dispatched);

        await client.post<Object?>(
          '/v1/bootstrap',
          options: Options(
            headers: const <String, String>{
              'authorization': 'Bearer current-access-token',
            },
          ),
        );

        expect(dispatched, hasLength(1));
        expect(
          dispatched.single.headers['authorization'],
          'Bearer current-access-token',
        );

        for (final headers in <Map<String, String>>[
          const <String, String>{'Cookie': 'session=must-not-dispatch'},
          const <String, String>{
            'Proxy-Authorization': 'Bearer must-not-dispatch',
          },
          const <String, String>{'X-Api-Key': 'must-not-dispatch'},
        ]) {
          await expectLater(
            client.post<Object?>(
              '/v1/bootstrap',
              options: Options(headers: headers),
            ),
            throwsA(_boundaryViolation()),
          );
        }
        expect(dispatched, hasLength(1));

        for (final location in <String>[
          'http://api.example.com:443/v1/bootstrap',
          'https://api.example.com:444/v1/bootstrap',
          'https://other.example.com/v1/bootstrap',
        ]) {
          await expectLater(
            client.post<Object?>(
              location,
              options: Options(
                headers: const <String, String>{
                  'authorization': 'Bearer must-not-leave-origin',
                },
              ),
            ),
            throwsA(_boundaryViolation()),
          );
        }
        expect(dispatched, hasLength(1));
      },
    );

    test('backend client rejects persistent authorization defaults', () async {
      final client = LoopDioFactory.createLoopBackend(
        origin: Uri.parse('https://api.example.com/'),
      );
      addTearDown(() => client.close(force: true));
      final dispatched = <RequestOptions>[];
      _resolveRequests(client, dispatched);
      client.options.headers['authorization'] = 'Bearer persisted-token';

      await expectLater(
        client.post<Object?>('/v1/bootstrap'),
        throwsA(_boundaryViolation()),
      );

      expect(dispatched, isEmpty);
    });

    test('every client rejects per-request redirect enablement', () async {
      final clients = <Dio>[
        LoopDioFactory.createCredentialFreePublic(
          origin: Uri.parse('https://public.example.com/'),
        ),
        LoopDioFactory.createLoopBackend(
          origin: Uri.parse('https://api.example.com/'),
        ),
      ];
      addTearDown(() {
        for (final client in clients) {
          client.close(force: true);
        }
      });

      for (final client in clients) {
        final dispatched = <RequestOptions>[];
        _resolveRequests(client, dispatched);
        await expectLater(
          client.get<Object?>(
            '/redirect',
            options: Options(followRedirects: true),
          ),
          throwsA(_boundaryViolation()),
        );
        expect(dispatched, isEmpty);
      }
    });

    test('factory rejects unsafe or non-origin configuration', () {
      final invalidPublicOrigins = <Uri>[
        Uri.parse('http://public.example.com/'),
        Uri.parse('https://user@public.example.com/'),
        Uri.parse('https://public.example.com/info'),
        Uri.parse('https://public.example.com/?token=secret'),
      ];
      for (final origin in invalidPublicOrigins) {
        expect(
          () => LoopDioFactory.createCredentialFreePublic(origin: origin),
          throwsArgumentError,
        );
      }

      expect(
        () => LoopDioFactory.createLoopBackend(
          origin: Uri.parse('http://api.example.com/'),
        ),
        throwsArgumentError,
      );
      final loopback = LoopDioFactory.createLoopBackend(
        origin: Uri.parse('http://127.0.0.1:3000/'),
      );
      expect(loopback.options.baseUrl, 'http://127.0.0.1:3000/');
      loopback.close(force: true);
    });
  });
}

void _resolveRequests(Dio client, List<RequestOptions> dispatched) {
  client.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        dispatched.add(options);
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: const <String, Object?>{},
          ),
        );
      },
    ),
  );
}

Matcher _boundaryViolation() {
  return isA<DioException>()
      .having((error) => error.type, 'type', DioExceptionType.unknown)
      .having(
        (error) => error.error,
        'sanitized boundary error',
        isA<LoopHttpBoundaryViolation>(),
      );
}
