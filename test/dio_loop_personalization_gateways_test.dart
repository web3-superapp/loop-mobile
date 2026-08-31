import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/personalization/dio_loop_personalization_gateways.dart';

void main() {
  const requestId = '7a7448be-64e2-4f9f-a9f1-891f1beec7fd';
  final updatedAt = DateTime.utc(2026, 8, 31, 12, 30);

  group('Dio LOOP personalization gateways', () {
    test('send exact authenticated GET and full-CAS PUT requests', () async {
      final requests = <RequestOptions>[];
      final fixture = await _fixture((options, handler) {
        requests.add(options);
        final isWrite = options.method == 'PUT';
        handler.resolve(
          _successResponse(
            options,
            data: switch (options.uri.path) {
              '/v1/profile' => _profileBody(
                version: isWrite ? 2 : 1,
                updatedAt: updatedAt,
              ),
              '/v1/profile/privacy' => _privacyBody(
                version: isWrite ? 2 : 1,
                updatedAt: updatedAt,
              ),
              '/v1/profile/social-privacy' => _socialPrivacyBody(
                version: isWrite ? 2 : 1,
                updatedAt: updatedAt,
              ),
              _ => throw StateError('unexpected path'),
            },
          ),
        );
      });
      addTearDown(fixture.dispose);
      final profile = DioLoopProfileGateway(
        dio: fixture.dio,
        session: fixture.session,
      );
      final privacy = DioLoopPrivacyGateway(
        dio: fixture.dio,
        session: fixture.session,
      );
      final socialPrivacy = DioLoopSocialPrivacyGateway(
        dio: fixture.dio,
        session: fixture.session,
      );

      final loadedProfile = await profile.load();
      final savedProfile = await profile.replace(
        expectedVersion: 1,
        values: ProfileValues(alias: 'Alice', avatarRef: 'avatar:alice'),
      );
      final loadedPrivacy = await privacy.load();
      final savedPrivacy = await privacy.replace(
        expectedVersion: 1,
        values: const PrivacyValues(
          discoverable: true,
          copyTradeVisibility: CopyTradeVisibility.followers,
        ),
      );
      final loadedSocialPrivacy = await socialPrivacy.load();
      final savedSocialPrivacy = await socialPrivacy.replace(
        expectedVersion: 1,
        values: const SocialPrivacyValues(
          friendRequests: FriendRequestsPreference.enabled,
          groupInvites: GroupInvitesPreference.friends,
          directMessages: DirectMessagesPreference.friends,
        ),
      );

      expect(profile.mode, ProfileMode.production);
      expect(privacy.mode, PrivacyMode.production);
      expect(socialPrivacy.mode, SocialPrivacyMode.production);
      expect(loadedProfile.version, 1);
      expect(savedProfile.version, 2);
      expect(loadedPrivacy.version, 1);
      expect(savedPrivacy.version, 2);
      expect(loadedSocialPrivacy.version, 1);
      expect(savedSocialPrivacy.version, 2);
      expect(
        requests.map((request) => '${request.method} ${request.uri.path}'),
        <String>[
          'GET /v1/profile',
          'PUT /v1/profile',
          'GET /v1/profile/privacy',
          'PUT /v1/profile/privacy',
          'GET /v1/profile/social-privacy',
          'PUT /v1/profile/social-privacy',
        ],
      );
      expect(
        requests.every((request) => request.queryParameters.isEmpty),
        true,
      );
      expect(requests.every((request) => !request.followRedirects), true);
      expect(requests.map(_authorization), <String>[
        'Bearer current-access-token-1',
        'Bearer current-access-token-2',
        'Bearer current-access-token-3',
        'Bearer current-access-token-4',
        'Bearer current-access-token-5',
        'Bearer current-access-token-6',
      ]);
      expect(requests.every((request) => !_hasIdempotencyKey(request)), true);
      expect(requests[0].data, isNull);
      expect(requests[1].data, <String, Object?>{
        'expected_version': 1,
        'profile': <String, Object?>{
          'alias': 'Alice',
          'avatar_ref': 'avatar:alice',
        },
      });
      expect(requests[2].data, isNull);
      expect(requests[3].data, <String, Object?>{
        'expected_version': 1,
        'privacy': <String, Object?>{
          'discoverable': true,
          'copy_trade_visibility': 'followers',
        },
      });
      expect(requests[4].data, isNull);
      expect(requests[5].data, <String, Object?>{
        'expected_version': 1,
        'social_privacy': <String, Object?>{
          'friend_requests': 'enabled',
          'group_invites': 'friends',
          'direct_messages': 'friends',
        },
      });
    });

    test('requires a strict no-store success envelope', () async {
      final headers = <Headers>[
        Headers.fromMap(<String, List<String>>{
          'x-request-id': <String>[requestId],
        }),
        Headers.fromMap(<String, List<String>>{
          'cache-control': <String>['no-store'],
        }),
        Headers.fromMap(<String, List<String>>{
          'cache-control': <String>['no-store'],
          'x-request-id': <String>[requestId, requestId],
        }),
        Headers.fromMap(<String, List<String>>{
          'cache-control': <String>['no-store'],
          'x-request-id': <String>['not-a-request-id'],
        }),
      ];
      var index = 0;
      final fixture = await _fixture((options, handler) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: _profileBody(version: 1, updatedAt: updatedAt),
            headers: headers[index++],
          ),
        );
      });
      addTearDown(fixture.dispose);
      final gateway = DioLoopProfileGateway(
        dio: fixture.dio,
        session: fixture.session,
      );

      for (var attempt = 0; attempt < headers.length; attempt++) {
        await expectLater(
          gateway.load(),
          throwsA(_profileFailure(ProfileGatewayFailureKind.invalidData)),
        );
      }
      expect(fixture.requestTokens.calls, headers.length);
    });

    test(
      'rejects response key, canonical alias, and timestamp drift',
      () async {
        final bodies = <Object?>[
          <String, Object?>{
            ..._profileBody(version: 1, updatedAt: updatedAt),
            'bio': 'not contracted',
          },
          <String, Object?>{
            'version': 1,
            'profile': <String, Object?>{
              'alias': ' Alice ',
              'avatar_ref': 'avatar:alice',
            },
            'updated_at': updatedAt.toIso8601String(),
          },
          <String, Object?>{
            'version': 1,
            'profile': <String, Object?>{
              'alias': 'Alice',
              'avatar_ref': 'avatar:alice',
            },
            'updated_at': '2026-02-31T12:30:00.000Z',
          },
          <String, Object?>{
            'version': 0,
            'profile': <String, Object?>{'alias': null, 'avatar_ref': null},
            'updated_at': updatedAt.toIso8601String(),
          },
        ];
        var index = 0;
        final fixture = await _fixture((options, handler) {
          handler.resolve(_successResponse(options, data: bodies[index++]));
        });
        addTearDown(fixture.dispose);
        final gateway = DioLoopProfileGateway(
          dio: fixture.dio,
          session: fixture.session,
        );

        for (var attempt = 0; attempt < bodies.length; attempt++) {
          await expectLater(
            gateway.load(),
            throwsA(_profileFailure(ProfileGatewayFailureKind.invalidData)),
          );
        }
      },
    );

    test('rejects Privacy and Social Privacy type or enum drift', () async {
      final bodies = <Object?>[
        <String, Object?>{
          'version': 1,
          'privacy': <String, Object?>{
            'discoverable': 1,
            'copy_trade_visibility': 'private',
          },
          'updated_at': updatedAt.toIso8601String(),
        },
        <String, Object?>{
          'version': 1,
          'privacy': <String, Object?>{
            'discoverable': false,
            'copy_trade_visibility': 'friends',
          },
          'updated_at': updatedAt.toIso8601String(),
        },
        <String, Object?>{
          'version': 1,
          'social_privacy': <String, Object?>{
            'friend_requests': 'followers',
            'group_invites': 'friends',
            'direct_messages': 'friends',
          },
          'updated_at': updatedAt.toIso8601String(),
        },
      ];
      var index = 0;
      final fixture = await _fixture((options, handler) {
        handler.resolve(_successResponse(options, data: bodies[index++]));
      });
      addTearDown(fixture.dispose);
      final privacy = DioLoopPrivacyGateway(
        dio: fixture.dio,
        session: fixture.session,
      );
      final socialPrivacy = DioLoopSocialPrivacyGateway(
        dio: fixture.dio,
        session: fixture.session,
      );

      await expectLater(
        privacy.load(),
        throwsA(_privacyFailure(PrivacyGatewayFailureKind.invalidData)),
      );
      await expectLater(
        privacy.load(),
        throwsA(_privacyFailure(PrivacyGatewayFailureKind.invalidData)),
      );
      await expectLater(
        socialPrivacy.load(),
        throwsA(
          _socialPrivacyFailure(SocialPrivacyGatewayFailureKind.invalidData),
        ),
      );
    });

    test('maps exact CAS conflicts for all three resources', () async {
      final fixture = await _fixture((options, handler) {
        handler.reject(
          _error(options, statusCode: 409, code: 'version_conflict'),
        );
      });
      addTearDown(fixture.dispose);

      await expectLater(
        DioLoopProfileGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).replace(
          expectedVersion: 1,
          values: ProfileValues(alias: 'Alice', avatarRef: null),
        ),
        throwsA(_profileFailure(ProfileGatewayFailureKind.versionConflict)),
      );
      await expectLater(
        DioLoopPrivacyGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).replace(expectedVersion: 1, values: const PrivacyValues.defaults()),
        throwsA(_privacyFailure(PrivacyGatewayFailureKind.versionConflict)),
      );
      await expectLater(
        DioLoopSocialPrivacyGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).replace(
          expectedVersion: 1,
          values: const SocialPrivacyValues.defaults(),
        ),
        throwsA(
          _socialPrivacyFailure(
            SocialPrivacyGatewayFailureKind.versionConflict,
          ),
        ),
      );
    });

    test('maps resource-specific 503 responses to unavailable', () async {
      final fixture = await _fixture((options, handler) {
        handler.reject(
          _error(
            options,
            statusCode: 503,
            code: options.uri.path == '/v1/profile/social-privacy'
                ? 'social_unavailable'
                : 'authentication_unavailable',
          ),
        );
      });
      addTearDown(fixture.dispose);

      await expectLater(
        DioLoopProfileGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).load(),
        throwsA(_profileFailure(ProfileGatewayFailureKind.unavailable)),
      );
      await expectLater(
        DioLoopPrivacyGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).load(),
        throwsA(_privacyFailure(PrivacyGatewayFailureKind.unavailable)),
      );
      await expectLater(
        DioLoopSocialPrivacyGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).load(),
        throwsA(
          _socialPrivacyFailure(SocialPrivacyGatewayFailureKind.unavailable),
        ),
      );
    });

    test('one strict 401 obtains a current token and then succeeds', () async {
      var requests = 0;
      final fixture = await _fixture((options, handler) {
        requests += 1;
        if (requests == 1) {
          handler.reject(
            _error(options, statusCode: 401, code: 'invalid_access_token'),
          );
          return;
        }
        handler.resolve(
          _successResponse(
            options,
            data: _profileBody(version: 1, updatedAt: updatedAt),
          ),
        );
      });
      addTearDown(fixture.dispose);

      final resource = await DioLoopProfileGateway(
        dio: fixture.dio,
        session: fixture.session,
      ).load();

      expect(resource.version, 1);
      expect(requests, 2);
      expect(fixture.requestTokens.calls, 2);
    });

    test(
      'one bootstrap_required response reauthorizes then succeeds',
      () async {
        var requests = 0;
        final fixture = await _fixture((options, handler) {
          requests += 1;
          if (requests == 1) {
            handler.reject(
              _error(options, statusCode: 409, code: 'bootstrap_required'),
            );
            return;
          }
          handler.resolve(
            _successResponse(
              options,
              data: _privacyBody(version: 1, updatedAt: updatedAt),
            ),
          );
        });
        addTearDown(fixture.dispose);

        final resource = await DioLoopPrivacyGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).load();

        expect(resource.version, 1);
        expect(requests, 2);
        expect(fixture.bootstrapRepository.calls, 2);
      },
    );

    test('malformed 401 cannot trigger credential recovery', () async {
      var requests = 0;
      final fixture = await _fixture((options, handler) {
        requests += 1;
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: 401,
              data: const <String, Object?>{
                'code': 'invalid_access_token',
                'message': 'Sanitized.',
                'request_id': requestId,
              },
              headers: Headers.fromMap(<String, List<String>>{
                'cache-control': <String>['no-store'],
                'x-request-id': <String>[
                  '11111111-1111-4111-8111-111111111111',
                ],
              }),
            ),
          ),
        );
      });
      addTearDown(fixture.dispose);

      await expectLater(
        DioLoopProfileGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).load(),
        throwsA(_profileFailure(ProfileGatewayFailureKind.invalidData)),
      );
      expect(requests, 1);
      expect(fixture.requestTokens.calls, 1);
    });

    test('transport failures remain sanitized feature failures', () async {
      for (final (type, expected)
          in <(DioExceptionType, ProfileGatewayFailureKind)>[
            (
              DioExceptionType.receiveTimeout,
              ProfileGatewayFailureKind.unavailable,
            ),
            (
              DioExceptionType.connectionError,
              ProfileGatewayFailureKind.unavailable,
            ),
            (DioExceptionType.unknown, ProfileGatewayFailureKind.unexpected),
          ]) {
        final fixture = await _fixture((options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: type,
              message: 'private-access-token leaked by transport',
            ),
          );
        });
        final gateway = DioLoopProfileGateway(
          dio: fixture.dio,
          session: fixture.session,
        );

        Object? captured;
        try {
          await gateway.load();
        } catch (error) {
          captured = error;
        } finally {
          fixture.dispose();
        }
        expect(captured, _profileFailure(expected));
        expect(captured.toString(), isNot(contains('private-access-token')));
      }
    });

    test('invalid expected versions dispatch no request', () async {
      var requests = 0;
      final fixture = await _fixture((options, handler) {
        requests += 1;
        handler.resolve(
          _successResponse(
            options,
            data: _profileBody(version: 1, updatedAt: updatedAt),
          ),
        );
      });
      addTearDown(fixture.dispose);

      await expectLater(
        DioLoopProfileGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).replace(expectedVersion: -1, values: ProfileValues.empty()),
        throwsA(_profileFailure(ProfileGatewayFailureKind.invalidData)),
      );
      await expectLater(
        DioLoopPrivacyGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).replace(
          expectedVersion: privacyMaximumVersion + 1,
          values: const PrivacyValues.defaults(),
        ),
        throwsA(_privacyFailure(PrivacyGatewayFailureKind.invalidData)),
      );
      await expectLater(
        DioLoopSocialPrivacyGateway(
          dio: fixture.dio,
          session: fixture.session,
        ).replace(
          expectedVersion: socialPrivacyMaximumVersion + 1,
          values: const SocialPrivacyValues.defaults(),
        ),
        throwsA(
          _socialPrivacyFailure(SocialPrivacyGatewayFailureKind.invalidData),
        ),
      );
      expect(requests, 0);
      expect(fixture.requestTokens.calls, 0);
    });
  });
}

Future<_Fixture> _fixture(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) async {
  final bootstrapRepository = _BootstrapRepository();
  final bootstrapSession = LoopBootstrapSession(
    principalKey: 'did:privy:owner-a',
    accessTokens: _AccessTokens(prefix: 'bootstrap-access-token'),
    repository: bootstrapRepository,
  );
  expect(
    await bootstrapSession.authorize(),
    LoopBootstrapAuthorization.authorized,
  );
  final requestTokens = _AccessTokens(prefix: 'current-access-token');
  final session = LoopAuthenticatedSession(
    principalKey: 'did:privy:owner-a',
    bootstrapSession: bootstrapSession,
    accessTokens: requestTokens,
  );
  final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return _Fixture(
    dio: dio,
    session: session,
    bootstrapSession: bootstrapSession,
    bootstrapRepository: bootstrapRepository,
    requestTokens: requestTokens,
  );
}

final class _Fixture {
  const _Fixture({
    required this.dio,
    required this.session,
    required this.bootstrapSession,
    required this.bootstrapRepository,
    required this.requestTokens,
  });

  final Dio dio;
  final LoopAuthenticatedSession session;
  final LoopBootstrapSession bootstrapSession;
  final _BootstrapRepository bootstrapRepository;
  final _AccessTokens requestTokens;

  void dispose() {
    session.dispose();
    bootstrapSession.dispose();
    dio.close(force: true);
  }
}

final class _AccessTokens implements LoopBackendAccessTokenSource {
  _AccessTokens({required this.prefix});

  final String prefix;
  var calls = 0;

  @override
  Future<String> loadAccessToken() async {
    calls += 1;
    return '$prefix-$calls';
  }
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  var calls = 0;

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    calls += 1;
    return const LoopBootstrapIdentity(
      loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
      streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
    );
  }
}

Map<String, Object?> _profileBody({
  required int version,
  required DateTime updatedAt,
}) => <String, Object?>{
  'version': version,
  'profile': <String, Object?>{'alias': 'Alice', 'avatar_ref': 'avatar:alice'},
  'updated_at': updatedAt.toIso8601String(),
};

Map<String, Object?> _privacyBody({
  required int version,
  required DateTime updatedAt,
}) => <String, Object?>{
  'version': version,
  'privacy': <String, Object?>{
    'discoverable': true,
    'copy_trade_visibility': 'followers',
  },
  'updated_at': updatedAt.toIso8601String(),
};

Map<String, Object?> _socialPrivacyBody({
  required int version,
  required DateTime updatedAt,
}) => <String, Object?>{
  'version': version,
  'social_privacy': <String, Object?>{
    'friend_requests': 'enabled',
    'group_invites': 'friends',
    'direct_messages': 'friends',
  },
  'updated_at': updatedAt.toIso8601String(),
};

Response<Object?> _successResponse(
  RequestOptions options, {
  required Object? data,
}) => Response<Object?>(
  requestOptions: options,
  statusCode: 200,
  data: data,
  headers: _strictHeaders(),
);

DioException _error(
  RequestOptions options, {
  required int statusCode,
  required String code,
}) => DioException(
  requestOptions: options,
  type: DioExceptionType.badResponse,
  response: Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: <String, Object?>{
      'code': code,
      'message': 'Sanitized public message.',
      'request_id': '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
    },
    headers: _strictHeaders(),
  ),
);

Headers _strictHeaders() => Headers.fromMap(<String, List<String>>{
  'cache-control': <String>['private', 'no-store'],
  'x-request-id': <String>['7a7448be-64e2-4f9f-a9f1-891f1beec7fd'],
});

String _authorization(RequestOptions options) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == 'authorization') {
      return entry.value as String;
    }
  }
  throw StateError('missing authorization');
}

bool _hasIdempotencyKey(RequestOptions options) =>
    options.headers.keys.any((key) => key.toLowerCase() == 'idempotency-key');

TypeMatcher<ProfileGatewayException> _profileFailure(
  ProfileGatewayFailureKind kind,
) => isA<ProfileGatewayException>().having(
  (failure) => failure.kind,
  'kind',
  kind,
);

TypeMatcher<PrivacyGatewayException> _privacyFailure(
  PrivacyGatewayFailureKind kind,
) => isA<PrivacyGatewayException>().having(
  (failure) => failure.kind,
  'kind',
  kind,
);

TypeMatcher<SocialPrivacyGatewayException> _socialPrivacyFailure(
  SocialPrivacyGatewayFailureKind kind,
) => isA<SocialPrivacyGatewayException>().having(
  (failure) => failure.kind,
  'kind',
  kind,
);
