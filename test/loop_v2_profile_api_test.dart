import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/loop_v2_profile_api.dart';

void main() {
  const requestId = '11111111-1111-4111-8111-111111111111';
  const loopId = 'LOOP-7HJKMNPQ';
  const command = LoopV2CommandMetadata(
    deviceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    idempotencyKey: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    clientVersion: '0.1.0+1',
    platform: LoopV2Platform.android,
  );

  Map<String, Object?> profileBody({
    String? alias = 'Alice',
    String? avatarRef = 'avatar:preset/people-03',
    String? bio,
    List<String> interests = const <String>['MEME', 'AI'],
    String profileStatus = 'active',
    String? activatedAt = '2026-09-07T01:00:00.000Z',
    int version = 1,
    String? updatedAt = '2026-09-07T01:00:00.000Z',
  }) => <String, Object?>{
    'profile': <String, Object?>{
      'loopId': loopId,
      'alias': alias,
      'avatarRef': avatarRef,
      'bio': bio,
      'interests': interests,
      'profileStatus': profileStatus,
      'activatedAt': activatedAt,
    },
    'version': version,
    'updatedAt': updatedAt,
    'contractVersion': '2.0',
  };

  Map<String, Object?> privacyBody({
    bool discoverable = true,
    bool anonymousMode = false,
    String totalAssets = 'self',
    String miningPower = 'everyone',
    int version = 1,
    String? updatedAt = '2026-09-07T01:00:00.000Z',
  }) => <String, Object?>{
    'privacy': <String, Object?>{
      'discoverable': discoverable,
      'anonymousMode': anonymousMode,
      'visibility': <String, Object?>{
        'totalAssets': totalAssets,
        'miningPower': miningPower,
        'communities': 'everyone',
        'tradeHistory': 'self',
      },
    },
    'version': version,
    'updatedAt': updatedAt,
    'contractVersion': '2.0',
  };

  test('GET /v2/profile sends only its exact V2 business headers', () async {
    RequestOptions? captured;
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        captured = options;
        handler.resolve(_response(options, profileBody()));
      }),
    );

    final resource = await api.getProfile(
      accessToken: 'current-token',
      clientVersion: '0.1.0+1',
    );

    expect(captured?.method, 'GET');
    expect(captured?.uri.path, DioLoopV2ProfileApi.profilePath);
    expect(captured?.queryParameters, isEmpty);
    expect(captured?.data, isNull);
    expect(_header(captured!, 'authorization'), 'Bearer current-token');
    expect(_loopHeaders(captured!), <String, Object?>{
      'x-loop-client-version': '0.1.0+1',
      'x-loop-contract-version': '2.0',
    });
    // CAS reads never carry an idempotency key; the backend rejects one.
    expect(_header(captured!, 'idempotency-key'), isNull);
    expect(resource.loopId, loopId);
    expect(resource.profileStatus, ProfileStatus.active);
    expect(resource.values.interests, <ProfileInterest>[
      ProfileInterest.meme,
      ProfileInterest.ai,
    ]);
    expect(resource.activatedAt, DateTime.utc(2026, 9, 7, 1));
  });

  test(
    'a pending first read keeps version zero and no activation time',
    () async {
      final api = DioLoopV2ProfileApi(
        _dio((options, handler) {
          handler.resolve(
            _response(
              options,
              profileBody(
                alias: null,
                avatarRef: null,
                interests: const <String>[],
                profileStatus: 'pending',
                activatedAt: null,
                version: 0,
                updatedAt: null,
              ),
            ),
          );
        }),
      );

      final resource = await api.getProfile(
        accessToken: 'current-token',
        clientVersion: '0.1.0+1',
      );

      expect(resource.version, 0);
      expect(resource.profileStatus, ProfileStatus.pending);
      expect(resource.activatedAt, isNull);
      expect(resource.values.alias, isNull);
      expect(resource.loopId, loopId);
    },
  );

  test('an unknown response field is rejected as an invalid payload', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        final body = profileBody();
        (body['profile']! as Map<String, Object?>)['nickname'] = 'Alice';
        handler.resolve(_response(options, body));
      }),
    );

    await expectLater(
      api.getProfile(accessToken: 'token', clientVersion: '0.1.0+1'),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('a missing no-store header is rejected', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        handler.resolve(
          _response(options, profileBody(), cacheControl: 'max-age=60'),
        );
      }),
    );

    await expectLater(
      api.getProfile(accessToken: 'token', clientVersion: '0.1.0+1'),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('a wrong contract version is rejected', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        final body = profileBody();
        body['contractVersion'] = '2.1';
        handler.resolve(_response(options, body));
      }),
    );

    await expectLater(
      api.getProfile(accessToken: 'token', clientVersion: '0.1.0+1'),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('a malformed LOOP ID is rejected', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        final body = profileBody();
        // `I`, `L`, `O` and `U` are excluded from Crockford Base32.
        (body['profile']! as Map<String, Object?>)['loopId'] = 'LOOP-IL0OUZ12';
        handler.resolve(_response(options, body));
      }),
    );

    await expectLater(
      api.getProfile(accessToken: 'token', clientVersion: '0.1.0+1'),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('an unknown interest value is rejected instead of dropped', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        handler.resolve(
          _response(
            options,
            profileBody(interests: const <String>['MEME', 'SOCIALFI']),
          ),
        );
      }),
    );

    await expectLater(
      api.getProfile(accessToken: 'token', clientVersion: '0.1.0+1'),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('PUT /v2/profile sends the exact CAS body', () async {
    RequestOptions? captured;
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        captured = options;
        handler.resolve(_response(options, profileBody(version: 2)));
      }),
    );

    await api.replaceProfile(
      accessToken: 'token',
      clientVersion: '0.1.0+1',
      expectedVersion: 1,
      values: ProfileValues(
        alias: 'Alice',
        avatarRef: 'avatar:preset/people-03',
        bio: 'Building on LOOP',
        interests: const <ProfileInterest>[
          ProfileInterest.meme,
          ProfileInterest.ai,
        ],
      ),
    );

    expect(captured?.method, 'PUT');
    expect(captured?.data, <String, Object?>{
      'expectedVersion': 1,
      'profile': <String, Object?>{
        'alias': 'Alice',
        'avatarRef': 'avatar:preset/people-03',
        'bio': 'Building on LOOP',
        'interests': <String>['MEME', 'AI'],
      },
    });
    expect(_header(captured!, 'idempotency-key'), isNull);
  });

  test('POST /v2/profile/loop-id sends the full write header set', () async {
    RequestOptions? captured;
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        captured = options;
        handler.resolve(_response(options, profileBody()));
      }),
    );

    final resource = await api.activateLoopId(
      accessToken: 'token',
      command: command,
      request: const LoopV2ActivationRequest(
        alias: 'Alice',
        avatarRef: 'avatar:preset/people-03',
        interests: <ProfileInterest>[ProfileInterest.meme, ProfileInterest.ai],
      ),
    );

    expect(captured?.method, 'POST');
    expect(captured?.uri.path, DioLoopV2ProfileApi.loopIdPath);
    expect(_loopHeaders(captured!), <String, Object?>{
      'x-loop-client-version': '0.1.0+1',
      'x-loop-contract-version': '2.0',
      'x-loop-device-id': command.deviceId,
      'x-loop-platform': 'android',
    });
    expect(_header(captured!, 'idempotency-key'), command.idempotencyKey);
    expect(captured?.data, <String, Object?>{
      'alias': 'Alice',
      'avatarRef': 'avatar:preset/people-03',
      'interests': <String>['MEME', 'AI'],
    });
    expect(resource.profileStatus, ProfileStatus.active);
  });

  test('an activation that comes back pending is an invalid payload', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        handler.resolve(
          _response(
            options,
            profileBody(profileStatus: 'pending', activatedAt: null),
          ),
        );
      }),
    );

    await expectLater(
      api.activateLoopId(
        accessToken: 'token',
        command: command,
        request: const LoopV2ActivationRequest(
          alias: 'Alice',
          avatarRef: null,
          interests: <ProfileInterest>[],
        ),
      ),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('ALIAS_RESERVED is surfaced with its seven-field envelope', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        handler.reject(
          _errorResponse(options, statusCode: 422, code: 'ALIAS_RESERVED'),
        );
      }),
    );

    await expectLater(
      api.activateLoopId(
        accessToken: 'token',
        command: command,
        request: const LoopV2ActivationRequest(
          alias: 'admin',
          avatarRef: null,
          interests: <ProfileInterest>[],
        ),
      ),
      throwsA(
        isA<LoopBackendFailure>()
            .having((failure) => failure.code, 'code', 'ALIAS_RESERVED')
            .having((failure) => failure.statusCode, 'statusCode', 422)
            .having((failure) => failure.category, 'category', 'validation')
            .having((failure) => failure.retryable, 'retryable', false)
            .having(
              (failure) => failure.userMessageKey,
              'userMessageKey',
              'errors.alias.reserved',
            )
            .having((failure) => failure.requestId, 'requestId', requestId),
      ),
    );
  });

  test('an error body missing a field is an invalid payload', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        final error = _errorResponse(
          options,
          statusCode: 422,
          code: 'ALIAS_BLOCKED',
        );
        (error.response!.data! as Map<String, Object?>).remove('detailsSafe');
        handler.reject(error);
      }),
    );

    await expectLater(
      api.replaceProfile(
        accessToken: 'token',
        clientVersion: '0.1.0+1',
        expectedVersion: 1,
        values: ProfileValues(alias: 'rugpull', avatarRef: null),
      ),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('a correlationId that differs from X-Request-ID is rejected', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        final error = _errorResponse(
          options,
          statusCode: 409,
          code: 'VERSION_CONFLICT',
          category: 'conflict',
          userMessageKey: 'errors.conflict.version',
        );
        (error.response!.data! as Map<String, Object?>)['correlationId'] =
            '22222222-2222-4222-8222-222222222222';
        handler.reject(error);
      }),
    );

    await expectLater(
      api.replaceProfile(
        accessToken: 'token',
        clientVersion: '0.1.0+1',
        expectedVersion: 1,
        values: ProfileValues(alias: 'Alice', avatarRef: null),
      ),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('an error code outside the endpoint catalog is rejected', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        handler.reject(
          _errorResponse(
            options,
            statusCode: 422,
            code: 'IDEMPOTENCY_CONFLICT',
            category: 'conflict',
            userMessageKey: 'errors.conflict.idempotency',
          ),
        );
      }),
    );

    await expectLater(
      api.replaceProfile(
        accessToken: 'token',
        clientVersion: '0.1.0+1',
        expectedVersion: 1,
        values: ProfileValues(alias: 'Alice', avatarRef: null),
      ),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('GET /v2/profile/privacy parses the four visibility facets', () async {
    RequestOptions? captured;
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        captured = options;
        handler.resolve(_response(options, privacyBody()));
      }),
    );

    final resource = await api.getPrivacy(
      accessToken: 'token',
      clientVersion: '0.1.0+1',
    );

    expect(captured?.uri.path, DioLoopV2ProfileApi.privacyPath);
    expect(resource.values.discoverable, isTrue);
    expect(resource.values.anonymousMode, isFalse);
    expect(resource.values.visibility.totalAssets, PrivacyAudience.self);
    expect(resource.values.visibility.miningPower, PrivacyAudience.everyone);
  });

  test('a copyTradeVisibility field is rejected, never ignored', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        final body = privacyBody();
        (body['privacy']! as Map<String, Object?>)['copyTradeVisibility'] =
            'public';
        handler.resolve(_response(options, body));
      }),
    );

    await expectLater(
      api.getPrivacy(accessToken: 'token', clientVersion: '0.1.0+1'),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('PUT /v2/profile/privacy sends the exact CAS body', () async {
    RequestOptions? captured;
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        captured = options;
        handler.resolve(_response(options, privacyBody(version: 2)));
      }),
    );

    await api.replacePrivacy(
      accessToken: 'token',
      clientVersion: '0.1.0+1',
      expectedVersion: 1,
      values: const PrivacyValues(
        discoverable: true,
        anonymousMode: true,
        visibility: PrivacyVisibility.defaults(),
      ),
    );

    expect(captured?.data, <String, Object?>{
      'expectedVersion': 1,
      'privacy': <String, Object?>{
        'discoverable': true,
        'anonymousMode': true,
        'visibility': <String, Object?>{
          'totalAssets': 'self',
          'miningPower': 'self',
          'communities': 'self',
          'tradeHistory': 'self',
        },
      },
    });
  });

  test('GET /v2/profile/avatars is public and rejects duplicates', () async {
    RequestOptions? captured;
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        captured = options;
        handler.resolve(_response(options, _avatarCatalog()));
      }),
    );

    final avatars = await api.getAvatars();

    expect(_header(captured!, 'authorization'), isNull);
    expect(_loopHeaders(captured!), isEmpty);
    // The catalog is the closed submittable set: 12 slots plus the monogram.
    expect(avatars.length, 13);
    // Row-major: slot 5 is row 2, column 1.
    expect(avatars[4].row, 2);
    expect(avatars[4].column, 1);
    expect(avatars.last.isMonogram, isTrue);
    expect(avatars.last.slot, isNull);
  });

  test('a duplicated avatarRef is an invalid catalog', () async {
    final body = _avatarCatalog();
    (body['avatars']! as List<Object?>)[1] = <String, Object?>{
      'avatarRef': 'avatar:preset/people-01',
      'atlas': 'people',
      'slot': 2,
      'label': 'People 01 again',
    };
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) => handler.resolve(_response(options, body))),
    );

    await expectLater(
      api.getAvatars(),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('a short catalog is rejected', () async {
    final body = _avatarCatalog();
    (body['avatars']! as List<Object?>).removeLast();
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) => handler.resolve(_response(options, body))),
    );

    await expectLater(
      api.getAvatars(),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('a non-preset catalog reference is rejected', () async {
    final body = _avatarCatalog();
    (body['avatars']! as List<Object?>)[0] = <String, Object?>{
      'avatarRef': 'avatar:legacy/upload-9f2c',
      'atlas': 'people',
      'slot': 1,
      'label': 'Legacy',
    };
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) => handler.resolve(_response(options, body))),
    );

    await expectLater(
      api.getAvatars(),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });

  test('a module-disabled 404 maps to unavailable, not a crash', () async {
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        handler.reject(
          _errorResponse(
            options,
            statusCode: 404,
            code: 'NOT_FOUND',
            userMessageKey: 'errors.request.notFound',
          ),
        );
      }),
    );

    await expectLater(
      api.getProfile(accessToken: 'token', clientVersion: '0.1.0+1'),
      throwsA(_failure(LoopBackendFailureKind.unavailable)),
    );
  });

  test('an empty access token never reaches the network', () async {
    var requested = false;
    final api = DioLoopV2ProfileApi(
      _dio((options, handler) {
        requested = true;
        handler.resolve(_response(options, profileBody()));
      }),
    );

    await expectLater(
      api.getProfile(accessToken: '', clientVersion: '0.1.0+1'),
      throwsA(_failure(LoopBackendFailureKind.authentication)),
    );
    expect(requested, isFalse);
  });
}

Map<String, Object?> _avatarCatalog() => <String, Object?>{
  'avatars': <Object?>[
    for (var slot = 1; slot <= 12; slot += 1)
      <String, Object?>{
        'avatarRef': 'avatar:preset/people-${slot.toString().padLeft(2, '0')}',
        'atlas': 'people',
        'slot': slot,
        'label': 'People ${slot.toString().padLeft(2, '0')}',
      },
    <String, Object?>{
      'avatarRef': 'avatar:preset/monogram',
      'atlas': 'monogram',
      'slot': null,
      'label': 'Monogram',
    },
  ],
  'contractVersion': '2.0',
};

Dio _dio(void Function(RequestOptions, RequestInterceptorHandler) onRequest) {
  return Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
}

Response<Object?> _response(
  RequestOptions options,
  Object? data, {
  int statusCode = 200,
  String cacheControl = 'no-store',
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': <String>[cacheControl],
      'x-request-id': const <String>['11111111-1111-4111-8111-111111111111'],
    }),
  );
}

DioException _errorResponse(
  RequestOptions options, {
  required int statusCode,
  required String code,
  String category = 'validation',
  String userMessageKey = 'errors.alias.reserved',
}) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: statusCode,
      data: <String, Object?>{
        'code': code,
        'category': category,
        'retryable': false,
        'userMessageKey': userMessageKey,
        'correlationId': '11111111-1111-4111-8111-111111111111',
        'detailsSafe': null,
        'providerReferenceSafe': null,
      },
      headers: Headers.fromMap(<String, List<String>>{
        'cache-control': const <String>['no-store'],
        'x-request-id': const <String>['11111111-1111-4111-8111-111111111111'],
      }),
    ),
  );
}

Object? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name) return entry.value;
  }
  return null;
}

Map<String, Object?> _loopHeaders(RequestOptions options) {
  return <String, Object?>{
    for (final entry in options.headers.entries)
      if (entry.key.toLowerCase().startsWith('x-loop-'))
        entry.key.toLowerCase(): entry.value,
  };
}

TypeMatcher<LoopBackendFailure> _failure(LoopBackendFailureKind kind) {
  return isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    kind,
  );
}
