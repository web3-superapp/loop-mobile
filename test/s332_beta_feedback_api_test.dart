import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/feedback/loop_v2_feedback_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';

import 'support/s332_beta_feedback.dart';
import 'support/s8_fixtures.dart';

final RegExp _lowerUuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

BetaFeedbackImage _image(int localId) => BetaFeedbackImage(
  localId: localId,
  bytes: s332Png,
  contentType: 'image/png',
);

BetaFeedbackSubmission _submission({List<String>? mediaIds}) =>
    BetaFeedbackSubmission(
      category: BetaFeedbackCategory.bug,
      body: '点开钱包闪退',
      mediaIds: mediaIds ?? <String>[s332Uuid(1)],
      context: BetaFeedbackContext.of(s332Environment, s332Origin),
    );

Map<String, Object?> _receiptBody() => <String, Object?>{
  'feedback': <String, Object?>{
    'id': s332Uuid(9),
    'status': 'open',
    'createdAt': '2026-11-02T06:00:00.000Z',
  },
};

void main() {
  group('POST /v2/media/feedback-images', () {
    test('one multipart file under the write headers', () async {
      RequestOptions? captured;
      final api = DioLoopV2FeedbackApi(
        s8Dio((options, handler) {
          captured = options;
          handler.resolve(
            s8Response(options, <String, Object?>{
              'mediaId': s332Uuid(1),
              'url': '/v2/media/${s332Uuid(1)}.webp',
              // A key the contract does not name is ignored, not refused.
              'contractVersion': '2.0',
              'width': 1,
            }, statusCode: 201),
          );
        }),
      );

      final uploaded = await api.uploadImage(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
        idempotencyKey: s8IdempotencyKey,
        image: _image(0),
      );

      final options = captured!;
      expect(options.method, 'POST');
      expect(options.path, '/v2/media/feedback-images');
      expect(options.headers['idempotency-key'], s8IdempotencyKey);
      expect(options.headers['x-loop-contract-version'], '2.0');
      final form = options.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'feedback.png');
      expect(uploaded.mediaId, s332Uuid(1));
      expect(
        uploaded.url,
        'https://api-dev.quant-dinger.cc/v2/media/${s332Uuid(1)}.webp',
      );
    });

    test('an absolute url is kept; a missing mediaId is refused', () async {
      final api = DioLoopV2FeedbackApi(
        s8Dio(
          (options, handler) => handler.resolve(
            s8Response(options, <String, Object?>{
              'mediaId': s332Uuid(2),
              'url': 'https://cdn.example/v2/media/${s332Uuid(2)}.webp',
            }, statusCode: 201),
          ),
        ),
      );
      final uploaded = await api.uploadImage(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
        idempotencyKey: s8IdempotencyKey,
        image: _image(0),
      );
      expect(uploaded.url, 'https://cdn.example/v2/media/${s332Uuid(2)}.webp');

      final broken = DioLoopV2FeedbackApi(
        s8Dio(
          (options, handler) => handler.resolve(
            s8Response(options, <String, Object?>{
              'url': 'https://cdn.example/x.webp',
            }, statusCode: 201),
          ),
        ),
      );
      await expectLater(
        broken.uploadImage(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          idempotencyKey: s8IdempotencyKey,
          image: _image(0),
        ),
        throwsA(s8InvalidPayload),
      );
    });

    test('a picture that is not an accepted type never leaves', () async {
      var asked = false;
      final api = DioLoopV2FeedbackApi(
        s8Dio((options, handler) {
          asked = true;
          handler.reject(DioException(requestOptions: options));
        }),
      );
      await expectLater(
        api.uploadImage(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          idempotencyKey: s8IdempotencyKey,
          image: BetaFeedbackImage(
            localId: 0,
            bytes: s332Png,
            contentType: 'image/gif',
          ),
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (f) => f.kind,
            'kind',
            LoopBackendFailureKind.invalidRequest,
          ),
        ),
      );
      expect(asked, isFalse);
    });
  });

  group('POST /v2/feedback', () {
    test('sends category, body, mediaIds and context', () async {
      RequestOptions? captured;
      final api = DioLoopV2FeedbackApi(
        s8Dio((options, handler) {
          captured = options;
          handler.resolve(s8Response(options, _receiptBody(), statusCode: 201));
        }),
      );

      final receipt = await api.submit(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
        idempotencyKey: s8IdempotencyKey,
        submission: _submission(mediaIds: <String>[s332Uuid(1), s332Uuid(2)]),
      );

      final options = captured!;
      expect(options.path, '/v2/feedback');
      expect(options.headers['idempotency-key'], s8IdempotencyKey);
      final body = options.data as Map<String, Object?>;
      expect(body.keys, <String>['category', 'body', 'mediaIds', 'context']);
      expect(body['category'], 'bug');
      expect(body['body'], '点开钱包闪退');
      expect(body['mediaIds'], <String>[s332Uuid(1), s332Uuid(2)]);
      expect(body['context'], <String, Object?>{
        'appVersion': '1.0.0',
        'build': '57',
        'platform': 'ios',
        'osVersion': 'iOS 26.1.0',
        'deviceModel': 'iPhone17,1',
        'route': '/meme',
        'locale': 'zh-CN',
      });
      expect(receipt.id, s332Uuid(9));
      expect(receipt.status, BetaFeedbackStatus.open);
      expect(receipt.createdAt, DateTime.utc(2026, 11, 2, 6));
    });

    test('the idempotent replay (200) decodes too', () async {
      final api = DioLoopV2FeedbackApi(
        s8Dio(
          (options, handler) =>
              handler.resolve(s8Response(options, _receiptBody())),
        ),
      );
      final receipt = await api.submit(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
        idempotencyKey: s8IdempotencyKey,
        submission: _submission(),
      );
      expect(receipt.id, s332Uuid(9));
    });

    test('an unknown status is refused', () async {
      final body = _receiptBody();
      (body['feedback']! as Map<String, Object?>)['status'] = 'closed';
      final api = DioLoopV2FeedbackApi(
        s8Dio(
          (options, handler) =>
              handler.resolve(s8Response(options, body, statusCode: 201)),
        ),
      );
      await expectLater(
        api.submit(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          idempotencyKey: s8IdempotencyKey,
          submission: _submission(),
        ),
        throwsA(s8InvalidPayload),
      );
    });

    test('a submission with no text or five pictures cannot be built', () {
      expect(
        () => BetaFeedbackSubmission(
          category: BetaFeedbackCategory.bug,
          body: '   ',
          mediaIds: const <String>[],
          context: BetaFeedbackContext.of(s332Environment, s332Origin),
        ),
        throwsArgumentError,
      );
      expect(
        () => _submission(
          mediaIds: <String>[for (var i = 0; i < 5; i++) s332Uuid(i)],
        ),
        throwsArgumentError,
      );
    });
  });

  group('GET /v2/feedback/mine', () {
    Map<String, Object?> page() => <String, Object?>{
      'items': <Object?>[
        <String, Object?>{
          'id': s332Uuid(1),
          'category': 'suggestion',
          'body': '第一行\n第二行',
          'status': 'wont_fix',
          'createdAt': '2026-11-02T06:00:00Z',
          'images': <Object?>['/v2/media/${s332Uuid(5)}.webp'],
        },
      ],
      'nextCursor': 'eyJ0IjoiMjAyNiJ9.abc',
    };

    test('reads the page with its cursor', () async {
      RequestOptions? captured;
      final api = DioLoopV2FeedbackApi(
        s8Dio((options, handler) {
          captured = options;
          handler.resolve(s8Response(options, page()));
        }),
      );
      final result = await api.listMine(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
        cursor: 'abc.def',
      );
      expect(captured!.path, '/v2/feedback/mine');
      expect(captured!.queryParameters, <String, Object?>{'cursor': 'abc.def'});
      expect(captured!.headers.containsKey('idempotency-key'), isFalse);
      final item = result.items.single;
      expect(item.category, BetaFeedbackCategory.suggestion);
      expect(item.status, BetaFeedbackStatus.wontFix);
      expect(item.body, '第一行\n第二行');
      expect(
        item.images.single,
        startsWith('https://api-dev.quant-dinger.cc/'),
      );
      expect(result.nextCursor, 'eyJ0IjoiMjAyNiJ9.abc');
    });

    test('a duplicated id is refused', () async {
      final body = page();
      final items = body['items']! as List<Object?>;
      items.add(items.first);
      final api = DioLoopV2FeedbackApi(
        s8Dio((options, handler) => handler.resolve(s8Response(options, body))),
      );
      await expectLater(
        api.listMine(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
        ),
        throwsA(s8InvalidPayload),
      );
    });
  });

  group('gateway', () {
    test('uploads then submits, one lowercase key each', () async {
      final requests = <RequestOptions>[];
      final gateway = DioLoopV2BetaFeedbackGateway(
        api: DioLoopV2FeedbackApi(
          s8Dio((options, handler) {
            requests.add(options);
            if (options.path == '/v2/media/feedback-images') {
              handler.resolve(
                s8Response(options, <String, Object?>{
                  'mediaId': s332Uuid(requests.length),
                  'url': '/v2/media/${s332Uuid(requests.length)}.webp',
                }, statusCode: 201),
              );
            } else {
              handler.resolve(
                s8Response(options, _receiptBody(), statusCode: 201),
              );
            }
          }),
        ),
        clientMetadata: s8ClientMetadata,
        session: _session(),
      );

      final first = await gateway.uploadImage(_image(0));
      final second = await gateway.uploadImage(_image(1));
      await gateway.submit(
        _submission(mediaIds: <String>[first.mediaId, second.mediaId]),
      );

      expect(requests.map((r) => r.path), <String>[
        '/v2/media/feedback-images',
        '/v2/media/feedback-images',
        '/v2/feedback',
      ]);
      final keys = requests
          .map((r) => r.headers['idempotency-key'] as String)
          .toList();
      for (final key in keys) {
        expect(key, matches(_lowerUuidV4));
      }
      expect(keys.toSet(), hasLength(3));
      expect((requests.last.data as Map<String, Object?>)['mediaIds'], <String>[
        first.mediaId,
        second.mediaId,
      ]);
    });

    test(
      'an unresolved send replays its key; a resolved one does not',
      () async {
        final keys = <String>[];
        var attempt = 0;
        final keyring = LoopV2CommandKeyring();
        final gateway = DioLoopV2BetaFeedbackGateway(
          api: DioLoopV2FeedbackApi(
            s8Dio((options, handler) {
              keys.add(options.headers['idempotency-key'] as String);
              if (attempt++ == 0) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.receiveTimeout,
                  ),
                );
                return;
              }
              handler.resolve(
                s8Response(options, _receiptBody(), statusCode: 201),
              );
            }),
          ),
          clientMetadata: s8ClientMetadata,
          session: _session(),
          keyring: keyring,
        );
        final submission = _submission();

        await expectLater(
          gateway.submit(submission),
          throwsA(
            isA<LoopChainException>().having(
              (e) => loopChainOutcomeIsUnresolved(e.kind),
              'unresolved',
              isTrue,
            ),
          ),
        );
        await gateway.submit(submission);
        await gateway.submit(submission);

        expect(keys, hasLength(3));
        expect(keys[1], keys[0], reason: 'the retry of an unresolved send');
        expect(keys[2], isNot(keys[0]), reason: 'a new send after success');
        expect(keyring.peek(submission.signature), isNull);
      },
    );

    test('a 422 carries the server\'s reasonCode', () async {
      final gateway = DioLoopV2BetaFeedbackGateway(
        api: DioLoopV2FeedbackApi(
          s8Dio((options, handler) {
            final error = s8ErrorResponse(
              options,
              statusCode: 422,
              code: 'VALIDATION_FAILED',
              category: 'validation',
              retryable: false,
              userMessageKey: 'errors.validation.failed',
            );
            (error.response!.data! as Map<String, Object?>)['detailsSafe'] =
                <String, Object?>{'reasonCode': 'MEDIA_NOT_OWNED'};
            handler.reject(error);
          }),
        ),
        clientMetadata: s8ClientMetadata,
        session: _session(),
      );
      await expectLater(
        gateway.submit(_submission()),
        throwsA(
          isA<LoopChainException>()
              .having(
                (e) => e.kind,
                'kind',
                LoopChainFailureKind.validationFailed,
              )
              .having((e) => e.reasonCode, 'reasonCode', 'MEDIA_NOT_OWNED'),
        ),
      );
    });

    test('404 and 503 read as unavailable, 429 as rate limited', () async {
      for (final (status, code, kind) in <(int, String, LoopChainFailureKind)>[
        (404, 'NOT_FOUND', LoopChainFailureKind.unavailable),
        (503, 'CAPABILITY_UNAVAILABLE', LoopChainFailureKind.unavailable),
        (429, 'RATE_LIMITED', LoopChainFailureKind.rateLimited),
      ]) {
        final gateway = DioLoopV2BetaFeedbackGateway(
          api: DioLoopV2FeedbackApi(
            s8Dio(
              (options, handler) => handler.reject(
                s8ErrorResponse(options, statusCode: status, code: code),
              ),
            ),
          ),
          clientMetadata: s8ClientMetadata,
          session: _session(),
        );
        await expectLater(
          gateway.listMine(),
          throwsA(
            isA<LoopChainException>().having((e) => e.kind, 'kind', kind),
          ),
          reason: '$status',
        );
        await expectLater(
          gateway.submit(_submission()),
          throwsA(
            isA<LoopChainException>().having((e) => e.kind, 'kind', kind),
          ),
          reason: '$status',
        );
      }
    });
  });
}

LoopAuthenticatedSession _session() => LoopAuthenticatedSession(
  principalKey: s8PrincipalKey,
  bootstrapSession: LoopBootstrapSession(
    principalKey: s8PrincipalKey,
    accessTokens: _StaticAccessTokens(),
    repository: _BootstrapRepository(),
  ),
  accessTokens: _StaticAccessTokens(),
);

final class _StaticAccessTokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => s8AccessToken;
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    return const LoopBootstrapIdentity(
      loopUserId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
      streamUserId: 'loop_6d12a86e413447e69312c5ef75a30f55',
    );
  }
}
