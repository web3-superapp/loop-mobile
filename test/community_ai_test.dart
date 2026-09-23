import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_ai_controller.dart';
import 'package:loop_mobile/features/community/community_ai_gateway.dart';
import 'package:loop_mobile/features/community/community_ai_models.dart';
import 'package:loop_mobile/features/community/community_ai_screen.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/community/dio_loop_v2_community_ai_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_ai_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

const _requestId = '11111111-1111-4111-8111-111111111111';
const _communityId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const _answerId = '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f';
const _reportId = '1a2b3c4d-5e6f-4a8b-9c0d-1e2f3a4b5c6d';
const _idempotencyKey = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _clientVersion = '1.0.0';
const _token = 'preflight.access.token';
const _disclaimer = '本回答由 AI 根据下列来源生成，不构成投资建议。';

Map<String, Object?> _source({
  String sourceId = 's1',
  String kind = 'communityProfile',
  String label = '社区档案：PEPE',
  String observedAt = '2026-09-22T03:00:00.000Z',
}) => <String, Object?>{
  'sourceId': sourceId,
  'kind': kind,
  'label': label,
  'observedAt': observedAt,
};

Map<String, Object?> _capability({
  String capabilityId = 'communitySupport',
  String title = '社区客服',
  String summary = 'CA 是什么、怎么买、怎么参与挖矿',
  String availability = 'available',
  Object? reasonCode,
  bool adminOnly = false,
}) => <String, Object?>{
  'capabilityId': capabilityId,
  'title': title,
  'summary': summary,
  'availability': availability,
  'reasonCode': reasonCode,
  'adminOnly': adminOnly,
};

Map<String, Object?> _overviewBody({
  Object? brief,
  Object? capabilities,
  Object? knowledge,
}) => <String, Object?>{
  'capabilities':
      capabilities ??
      <Object?>[
        _capability(),
        _capability(
          capabilityId: 'projectKnowledge',
          title: '项目知识',
          summary: '白皮书、Tokenomics、Roadmap、FAQ',
          availability: 'unavailable',
          reasonCode: 'KNOWLEDGE_DOCUMENTS_NOT_INGESTED',
        ),
      ],
  'knowledge':
      knowledge ??
      <String, Object?>{
        'sourceCount': 2,
        'updatedAt': '2026-09-22T03:00:00.000Z',
        'sources': <Object?>[
          _source(),
          _source(
            sourceId: 's2',
            kind: 'assetFacts',
            label: '绑定资产行情：PEPE',
            observedAt: '2026-09-22T02:58:00.000Z',
          ),
        ],
        'omittedSources': <Object?>[
          <String, Object?>{
            'kind': 'announcements',
            'reasonCode': 'ANNOUNCEMENT_SOURCE_UNAVAILABLE',
          },
        ],
        'documents': <String, Object?>{
          'status': 'unavailable',
          'reasonCode': 'KNOWLEDGE_DOCUMENTS_NOT_INGESTED',
        },
      },
  'exampleQuestions': <Object?>['这个社区的代币现在多少钱', '怎么参与挖矿', '这周社区在讨论什么'],
  'brief':
      brief ??
      <String, Object?>{
        'status': 'available',
        'messageCount': 42,
        'bounded': false,
        'windowHours': 24,
        'summary': '今天社区主要在讨论挖矿权重与新绑定资产的流动性。',
        'model': 'claude-sonnet-5',
        'generatedAt': '2026-09-22T03:00:00.000Z',
      },
  'disclaimer': _disclaimer,
  'contractVersion': '2.0',
};

Map<String, Object?> _answerBody({
  String answer = '这个社区绑定的资产当前价格是 0.0000123 USD [s2]。',
  Object? refusal,
  Object? citations,
}) => <String, Object?>{
  'answerId': _answerId,
  'answer': answer,
  'refusal': refusal,
  'citations':
      citations ??
      <Object?>[
        _source(
          sourceId: 's2',
          kind: 'assetFacts',
          label: '绑定资产行情：PEPE',
          observedAt: '2026-09-22T02:58:00.000Z',
        ),
      ],
  'sources': <Object?>[
    _source(),
    _source(
      sourceId: 's2',
      kind: 'assetFacts',
      label: '绑定资产行情：PEPE',
      observedAt: '2026-09-22T02:58:00.000Z',
    ),
  ],
  'omittedSources': <Object?>[
    <String, Object?>{
      'kind': 'communityChat',
      'reasonCode': 'COMMUNITY_CHAT_NOT_CONNECTED',
    },
  ],
  'model': 'claude-sonnet-5',
  'generatedAt': '2026-09-22T03:00:01.000Z',
  'disclaimer': _disclaimer,
  'contractVersion': '2.0',
};

void main() {
  // One test unmounts the page through its own `pumpWidget`, so this file
  // arms the ground probe itself; the page harness arms it for the rest.
  loopWatchGround();

  group('community-ai transport', () {
    test(
      'the overview read carries no idempotency key and decodes whole',
      () async {
        RequestOptions? captured;
        final api = DioLoopV2CommunityAiApi(
          _dio((options, handler) {
            captured = options;
            handler.resolve(_response(options, _overviewBody()));
          }),
        );

        final overview = await api.getOverview(
          accessToken: _token,
          clientVersion: _clientVersion,
          communityId: _communityId,
        );

        expect(captured!.method, 'GET');
        expect(captured!.path, '/v2/communities/$_communityId/ai/overview');
        expect(_header(captured!, 'idempotency-key'), isNull);
        expect(_header(captured!, 'x-loop-contract-version'), '2.0');
        expect(
          overview.capabilities.first.ability,
          CommunityAiAbility.communitySupport,
        );
        expect(overview.capabilities.first.available, isTrue);
        expect(overview.capabilities.last.available, isFalse);
        expect(
          overview.capabilities.last.reasonCode,
          'KNOWLEDGE_DOCUMENTS_NOT_INGESTED',
        );
        expect(overview.knowledge.sourceCount, 2);
        expect(
          overview.knowledge.sources.first.kind,
          CommunityAiSourceKind.communityProfile,
        );
        expect(
          overview.knowledge.omittedSources.single.kind,
          CommunityAiSourceKind.announcements,
        );
        expect(overview.exampleQuestions.length, 3);
        expect(overview.disclaimer, _disclaimer);
        final brief = overview.brief as CommunityAiBriefAvailable;
        expect(brief.messageCount, 42);
        expect(brief.bounded, isFalse);
        expect(brief.model, 'claude-sonnet-5');
      },
    );

    test('an unavailable brief keeps its reason instead of a zero', () async {
      final api = DioLoopV2CommunityAiApi(
        _dio((options, handler) {
          handler.resolve(
            _response(
              options,
              _overviewBody(
                brief: <String, Object?>{
                  'status': 'unavailable',
                  'reasonCode': 'COMMUNITY_AI_MEMBERSHIP_REQUIRED',
                },
              ),
            ),
          );
        }),
      );

      final overview = await api.getOverview(
        accessToken: _token,
        clientVersion: _clientVersion,
        communityId: _communityId,
      );

      expect(
        overview.brief,
        const CommunityAiBriefUnavailable('COMMUNITY_AI_MEMBERSHIP_REQUIRED'),
      );
    });

    test('a summary still being written decodes as the state it is', () async {
      final api = DioLoopV2CommunityAiApi(
        _dio((options, handler) {
          handler.resolve(
            _response(
              options,
              _overviewBody(
                brief: <String, Object?>{
                  'status': 'unavailable',
                  'reasonCode': communityAiBriefPendingReasonCode,
                },
              ),
            ),
          );
        }),
      );

      final overview = await api.getOverview(
        accessToken: _token,
        clientVersion: _clientVersion,
        communityId: _communityId,
      );

      final brief = overview.brief as CommunityAiBriefUnavailable;
      expect(brief.reasonCode, 'COMMUNITY_AI_BRIEF_PENDING');
      expect(brief.isGenerating, isTrue);
      expect(brief.isNeutral, isTrue);
      expect(communityAiReason(brief.reasonCode), '今日摘要生成中，稍后下拉刷新。');

      // The other seven of the closed set: one more state, five failures.
      const quota = CommunityAiBriefUnavailable(
        communityAiBriefQuotaExhaustedReasonCode,
      );
      expect(quota.isGenerating, isFalse);
      expect(quota.isNeutral, isTrue);
      expect(communityAiReason(quota.reasonCode), '今日摘要配额已用完，明天再来。');
      const chat = CommunityAiBriefUnavailable('COMMUNITY_CHAT_NOT_CONNECTED');
      expect(chat.isGenerating, isFalse);
      expect(chat.isNeutral, isFalse);
      for (final reasonCode in const <String>[
        'COMMUNITY_AI_MEMBERSHIP_REQUIRED',
        'COMMUNITY_CHAT_NOT_CONNECTED',
        'COMMUNITY_CHAT_NOT_OBSERVED',
        'COMMUNITY_AI_BRIEF_PENDING',
        'COMMUNITY_AI_PROVIDER_UNAVAILABLE',
        'COMMUNITY_AI_PROVIDER_REJECTED',
        'COMMUNITY_AI_PROVIDER_MALFORMED',
        'COMMUNITY_AI_QUOTA_EXHAUSTED',
      ]) {
        // Every code in the closed set has its own sentence: none falls
        // through to the neutral one, and none of them is a code.
        expect(communityAiReason(reasonCode), isNot('这一项暂时读不到。'));
        expect(communityAiReason(reasonCode), isNot(contains('COMMUNITY_')));
      }
    });

    // R3-2 for the S3 family: the overview read is a GET, and a GET that
    // could not be parsed submitted nothing. The page used to greet a slow
    // summary with a sentence about an unresolved submission.
    test('an unparsable overview read is a page that did not load', () async {
      final api = DioLoopV2CommunityAiApi(
        _dio((options, handler) {
          handler.resolve(
            _response(options, _overviewBody()..['surprise'] = true),
          );
        }),
      );

      try {
        await api.getOverview(
          accessToken: _token,
          clientVersion: _clientVersion,
          communityId: _communityId,
        );
        fail('the overview read must be refused');
      } on LoopBackendFailure catch (failure) {
        expect(failure.kind, LoopBackendFailureKind.invalidPayload);

        final read = communityFailureKindForV2(failure, write: false);
        expect(read, CommunityFailureKind.invalidData);
        expect(communityFailureReason(read), isNot(contains('结果未确认')));
        expect(communityFailureReason(read), isNot(contains('不要重复提交')));
        expect(communityOutcomeIsUnresolved(read), isFalse);
        expect(communityPhaseForFailure(read), CommunityViewPhase.error);

        // The same failure after a command is still unresolved.
        expect(
          communityFailureKindForV2(failure, write: true),
          CommunityFailureKind.outcomeUnknown,
        );
      }
    });

    test('a knowledge count the rows do not support is refused', () async {
      final api = DioLoopV2CommunityAiApi(
        _dio((options, handler) {
          handler.resolve(
            _response(
              options,
              _overviewBody(
                knowledge: <String, Object?>{
                  // 14 documents is the prototype's figure and has no source:
                  // a count the list does not carry is an invalid payload.
                  'sourceCount': 14,
                  'updatedAt': '2026-09-22T03:00:00.000Z',
                  'sources': <Object?>[_source()],
                  'omittedSources': <Object?>[],
                  'documents': <String, Object?>{
                    'status': 'unavailable',
                    'reasonCode': 'KNOWLEDGE_DOCUMENTS_NOT_INGESTED',
                  },
                },
              ),
            ),
          );
        }),
      );

      await expectLater(
        api.getOverview(
          accessToken: _token,
          clientVersion: _clientVersion,
          communityId: _communityId,
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidPayload,
          ),
        ),
      );
    });

    test('a document corpus the contract forbids is refused', () async {
      final api = DioLoopV2CommunityAiApi(
        _dio((options, handler) {
          handler.resolve(
            _response(
              options,
              _overviewBody(
                knowledge: <String, Object?>{
                  'sourceCount': 1,
                  'updatedAt': '2026-09-22T03:00:00.000Z',
                  'sources': <Object?>[_source()],
                  'omittedSources': <Object?>[],
                  'documents': <String, Object?>{
                    'status': 'available',
                    'reasonCode': 'KNOWLEDGE_DOCUMENTS_NOT_INGESTED',
                  },
                },
              ),
            ),
          );
        }),
      );

      await expectLater(
        api.getOverview(
          accessToken: _token,
          clientVersion: _clientVersion,
          communityId: _communityId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('ask sends the question under one canonical key', () async {
      RequestOptions? captured;
      final api = DioLoopV2CommunityAiApi(
        _dio((options, handler) {
          captured = options;
          handler.resolve(_response(options, _answerBody()));
        }),
      );

      final answer = await api.ask(
        accessToken: _token,
        clientVersion: _clientVersion,
        idempotencyKey: _idempotencyKey,
        communityId: _communityId,
        question: '  这个币现在多少钱  ',
      );

      expect(captured!.method, 'POST');
      expect(captured!.path, '/v2/communities/$_communityId/ai/ask');
      expect(_header(captured!, 'idempotency-key'), _idempotencyKey);
      expect(captured!.data, <String, Object?>{'question': '这个币现在多少钱'});
      expect(answer.answerId, _answerId);
      expect(answer.refusal, isNull);
      expect(answer.citations.single.sourceId, 's2');
      expect(answer.sources.length, 2);
      expect(
        answer.omittedSources.single.kind,
        CommunityAiSourceKind.communityChat,
      );
      expect(answer.model, 'claude-sonnet-5');
    });

    test(
      'a refusal is the reply, and an empty answer without one is not',
      () async {
        final refusing = DioLoopV2CommunityAiApi(
          _dio((options, handler) {
            handler.resolve(
              _response(
                options,
                _answerBody(
                  answer: '',
                  refusal: '这属于投资建议，我只提供事实。',
                  citations: <Object?>[],
                ),
              ),
            );
          }),
        );
        final answer = await refusing.ask(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _idempotencyKey,
          communityId: _communityId,
          question: '这个币会涨吗',
        );
        expect(answer.spoken, '这属于投资建议，我只提供事实。');

        final silent = DioLoopV2CommunityAiApi(
          _dio((options, handler) {
            handler.resolve(
              _response(
                options,
                _answerBody(answer: '', citations: <Object?>[]),
              ),
            );
          }),
        );
        await expectLater(
          silent.ask(
            accessToken: _token,
            clientVersion: _clientVersion,
            idempotencyKey: _idempotencyKey,
            communityId: _communityId,
            question: '这个币会涨吗',
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      },
    );

    test('a question outside the contract is never sent', () async {
      var sent = false;
      final api = DioLoopV2CommunityAiApi(
        _dio((options, handler) {
          sent = true;
          handler.resolve(_response(options, _answerBody()));
        }),
      );

      await expectLater(
        api.ask(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _idempotencyKey,
          communityId: _communityId,
          question: ' 短 ',
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidRequest,
          ),
        ),
      );
      expect(sent, isFalse);
    });

    test('a report is a 201 receipt about the answer it named', () async {
      RequestOptions? captured;
      final api = DioLoopV2CommunityAiApi(
        _dio((options, handler) {
          captured = options;
          handler.resolve(
            _response(options, <String, Object?>{
              'answerId': _answerId,
              'reportId': _reportId,
              'reason': 'inaccurate',
              'createdAt': '2026-09-22T03:05:00.000Z',
              'contractVersion': '2.0',
            }, statusCode: 201),
          );
        }),
      );

      final receipt = await api.report(
        accessToken: _token,
        clientVersion: _clientVersion,
        idempotencyKey: _idempotencyKey,
        communityId: _communityId,
        answerId: _answerId,
        reason: CommunityAiReportReason.inaccurate,
        note: '  价格和行情页不一致  ',
      );

      expect(
        captured!.path,
        '/v2/communities/$_communityId/ai/answers/$_answerId/report',
      );
      expect(_header(captured!, 'idempotency-key'), _idempotencyKey);
      expect(captured!.data, <String, Object?>{
        'reason': 'inaccurate',
        'note': '价格和行情页不一致',
      });
      expect(receipt.reportId, _reportId);
      expect(receipt.reason, CommunityAiReportReason.inaccurate);
    });

    test('a receipt about another answer is refused', () async {
      final api = DioLoopV2CommunityAiApi(
        _dio((options, handler) {
          handler.resolve(
            _response(options, <String, Object?>{
              'answerId': _reportId,
              'reportId': _reportId,
              'reason': 'inaccurate',
              'createdAt': '2026-09-22T03:05:00.000Z',
              'contractVersion': '2.0',
            }, statusCode: 201),
          );
        }),
      );

      await expectLater(
        api.report(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _idempotencyKey,
          communityId: _communityId,
          answerId: _answerId,
          reason: CommunityAiReportReason.inaccurate,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a quota refusal names the budget it was measured against', () async {
      final api = DioLoopV2CommunityAiApi(
        _dio((options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Object?>(
                requestOptions: options,
                statusCode: 429,
                data: <String, Object?>{
                  'code': 'RATE_LIMITED',
                  'category': 'rateLimit',
                  'retryable': true,
                  'userMessageKey': 'errors.rateLimited',
                  'correlationId': _requestId,
                  'detailsSafe': <String, Object?>{'scope': 'community'},
                  'providerReferenceSafe': null,
                },
                headers: Headers.fromMap(<String, List<String>>{
                  'cache-control': const <String>['no-store'],
                  'x-request-id': const <String>[_requestId],
                }),
              ),
            ),
          );
        }),
      );

      try {
        await api.ask(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _idempotencyKey,
          communityId: _communityId,
          question: '这周社区在讨论什么',
        );
        fail('an exhausted budget must not answer');
      } on LoopBackendFailure catch (failure) {
        expect(failure.code, 'RATE_LIMITED');
        expect(failure.detailsSafe?.scope, 'community');
        expect(
          communityAiRateLimitReason(failure.detailsSafe?.scope),
          '这个社区今天的提问额度用完了，明天再来。',
        );
      }
    });
  });

  group('community-ai idempotency', () {
    test(
      'the same question replays one key; a new question takes a new one',
      () async {
        final api = _RecordingAiApi();
        final gateway = DioLoopV2CommunityAiGateway(
          api: api,
          clientMetadata: const LoopV2ClientMetadata(
            clientVersion: _clientVersion,
            platform: LoopV2Platform.android,
          ),
          session: _immediateSession(),
        );

        // A lost connection leaves the outcome unknown, so the key is kept.
        api.failWith = const LoopBackendFailure(
          LoopBackendFailureKind.connection,
        );
        await expectLater(
          gateway.ask(communityId: _communityId, question: '怎么参与挖矿'),
          throwsA(isA<CommunityGatewayException>()),
        );
        final firstKey = api.keys.single;
        expect(
          gateway.peekAskKey(communityId: _communityId, question: '怎么参与挖矿'),
          firstKey,
        );

        // The identical retry replays it.
        api.failWith = null;
        await gateway.ask(communityId: _communityId, question: '怎么参与挖矿');
        expect(api.keys, <String>[firstKey, firstKey]);
        // A resolved outcome releases the key.
        expect(
          gateway.peekAskKey(communityId: _communityId, question: '怎么参与挖矿'),
          isNull,
        );

        // A different question is a different logical operation.
        await gateway.ask(communityId: _communityId, question: '这周社区在讨论什么');
        expect(api.keys.last, isNot(firstKey));
      },
    );
  });

  group('community-ai page', () {
    testWidgets('a closed capability keeps the page with nothing behind it', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityAiScreen(communityId: _communityId),
      );

      expect(find.text(communityAiHeadline), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-ai-composer-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('知识库'), findsNothing);
      expect(find.textContaining('COMMUNITY_AI'), findsNothing);
    });

    testWidgets('the five states each render their own block', (tester) async {
      for (final (kind, key) in const <(CommunityFailureKind, String)>[
        (CommunityFailureKind.offline, 'community-ai-state-offline'),
        (CommunityFailureKind.unavailable, 'community-ai-state-unavailable'),
        (
          CommunityFailureKind.permissionDenied,
          'community-ai-state-permission',
        ),
        (CommunityFailureKind.unexpected, 'community-ai-state-error'),
      ]) {
        await _pumpOpenPage(
          tester,
          _FakeAiGateway(
            overviewFailure: CommunityGatewayException(
              kind,
              reasonCode: 'COMMUNITY_AI_MEMBERSHIP_REQUIRED',
            ),
          ),
        );
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
        expect(find.textContaining('COMMUNITY_AI'), findsNothing);
      }

      // Loading is the state before any of them.
      final pending = _FakeAiGateway(overviewDelay: Completer<void>());
      await _pumpOpenPage(tester, pending, settle: false);
      expect(
        find.byKey(const ValueKey<String>('community-ai-state-loading')),
        findsOneWidget,
      );
      pending.overviewDelay!.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('community-ai-state-loading')),
        findsNothing,
      );
    });

    testWidgets('the open page states its sources, brief and abilities', (
      tester,
    ) async {
      await _pumpOpenPage(tester, _FakeAiGateway());

      // The bar counts live sources; the prototype's document figure has no
      // source and never appears.
      expect(find.textContaining('知识源 2 项 · 更新于'), findsOneWidget);
      expect(find.textContaining('知识库'), findsNothing);
      expect(find.text('今日 42 条讨论'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-ai-brief-mark')),
        findsOneWidget,
      );
      expect(find.textContaining('AI 生成 · claude-sonnet-5'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-ai-disclaimer')),
        findsOneWidget,
      );
      await scrollToCommunitySection(
        tester,
        find.byKey(
          const ValueKey<String>('community-ai-capability-projectKnowledge'),
        ),
      );
      // A closed ability is visible, greyed and explained in words.
      expect(find.textContaining('还没有收录项目文档'), findsOneWidget);
      expect(find.textContaining('KNOWLEDGE_DOCUMENTS'), findsNothing);
    });

    testWidgets('a bounded count says so, and an unavailable brief says why', (
      tester,
    ) async {
      await _pumpOpenPage(
        tester,
        _FakeAiGateway(
          brief: CommunityAiBriefAvailable(
            messageCount: 100,
            bounded: true,
            windowHours: 24,
            summary: '讨论集中在权重。',
            model: 'claude-sonnet-5',
            generatedAt: _TestTime.generatedAt,
          ),
        ),
      );
      expect(find.text('今日至少 100 条讨论'), findsOneWidget);

      await _pumpOpenPage(
        tester,
        _FakeAiGateway(
          brief: const CommunityAiBriefUnavailable(
            'COMMUNITY_CHAT_NOT_CONNECTED',
          ),
        ),
      );
      expect(find.text('今日讨论读不到'), findsOneWidget);
      expect(find.textContaining('还没有开通官方群'), findsOneWidget);
      expect(find.textContaining('0 条'), findsNothing);
    });

    testWidgets('a summary still being written is a state, and the page '
        'reads again once by itself', (tester) async {
      final gateway = _FakeAiGateway(
        brief: const CommunityAiBriefUnavailable(
          communityAiBriefPendingReasonCode,
        ),
      );
      await _pumpOpenPage(tester, gateway);

      expect(gateway.loads, 1);
      // Neutral: the hero neither says the discussion could not be read nor
      // offers the failure block's 重试.
      expect(find.text(communityAiBriefPendingHeading), findsOneWidget);
      expect(find.textContaining('稍后下拉刷新'), findsOneWidget);
      expect(find.text('今日讨论读不到'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('community-ai-state-error')),
        findsNothing,
      );
      expect(find.textContaining('不要重复提交'), findsNothing);
      // The rest of the page is on screen: the brief is the only thing
      // waiting.
      expect(find.textContaining('知识源 2 项 · 更新于'), findsOneWidget);

      // The server finishes writing it behind the first read.
      gateway.brief = CommunityAiBriefAvailable(
        messageCount: 42,
        bounded: false,
        windowHours: 24,
        summary: '今天社区主要在讨论挖矿权重。',
        model: 'claude-sonnet-5',
        generatedAt: _TestTime.generatedAt,
      );
      await tester.pump(CommunityAiController.briefRecheckDelay);
      await tester.pumpAndSettle();

      expect(gateway.loads, 2);
      expect(find.text('今日 42 条讨论'), findsOneWidget);
      expect(find.text(communityAiBriefPendingHeading), findsNothing);
    });

    testWidgets('a spent summary budget is a state too, and earns no re-read', (
      tester,
    ) async {
      final gateway = _FakeAiGateway(
        brief: const CommunityAiBriefUnavailable(
          communityAiBriefQuotaExhaustedReasonCode,
        ),
      );
      await _pumpOpenPage(tester, gateway);

      expect(find.text(communityAiBriefQuotaHeading), findsOneWidget);
      expect(find.textContaining('明天再来'), findsOneWidget);
      expect(find.text('今日讨论读不到'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('community-ai-state-error')),
        findsNothing,
      );

      // Nothing the page can do brings it back before tomorrow.
      await tester.pump(CommunityAiController.briefRecheckDelay * 4);
      await tester.pumpAndSettle();
      expect(gateway.loads, 1);
    });

    testWidgets('the summary is re-read once and only once', (tester) async {
      final gateway = _FakeAiGateway(
        brief: const CommunityAiBriefUnavailable(
          communityAiBriefPendingReasonCode,
        ),
      );
      await _pumpOpenPage(tester, gateway);

      await tester.pump(CommunityAiController.briefRecheckDelay);
      await tester.pumpAndSettle();
      expect(gateway.loads, 2);

      // Still pending: the page keeps the neutral line and stops reading. A
      // page that polled would spend the account's quota to print the same
      // sentence.
      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();
      expect(gateway.loads, 2);
      expect(find.text(communityAiBriefPendingHeading), findsOneWidget);
    });

    testWidgets('leaving the page takes the pending re-read with it', (
      tester,
    ) async {
      final gateway = _FakeAiGateway(
        brief: const CommunityAiBriefUnavailable(
          communityAiBriefPendingReasonCode,
        ),
      );
      await _pumpOpenPage(tester, gateway);
      expect(gateway.loads, 1);

      // The page goes away before the wait is over; the timer goes with it,
      // and the test's own teardown would fail on one left pending.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(CommunityAiController.briefRecheckDelay * 4);
      await tester.pumpAndSettle();
      expect(gateway.loads, 1);
    });

    testWidgets('an unreadable overview says the page did not load, not that '
        'a submission is unresolved', (tester) async {
      await _pumpOpenPage(
        tester,
        _FakeAiGateway(
          overviewFailure: const CommunityGatewayException(
            CommunityFailureKind.invalidData,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-ai-state-error')),
        findsOneWidget,
      );
      expect(find.text('返回的数据不完整，这一页没有采用任何内容。'), findsOneWidget);
      expect(find.textContaining('不要重复提交'), findsNothing);
      expect(find.textContaining('结果未确认'), findsNothing);
    });

    testWidgets('a sample question fills the composer instead of sending', (
      tester,
    ) async {
      final gateway = _FakeAiGateway();
      await _pumpOpenPage(tester, gateway);

      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('community-ai-sample-怎么参与挖矿')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('community-ai-sample-怎么参与挖矿')),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('loop-composer-input')),
      );
      expect(field.controller!.text, '怎么参与挖矿');
      expect(gateway.asked, isEmpty);
    });

    testWidgets('a question is on screen while it is in flight, and the '
        'composer is closed until it lands', (tester) async {
      final gateway = _FakeAiGateway(askDelay: Completer<void>());
      await _pumpOpenPage(tester, gateway);

      await tester.enterText(
        find.byKey(const ValueKey<String>('loop-composer-input')),
        '这个币现在多少钱',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-composer-send')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('community-ai-turn-0-question')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-ai-turn-0-pending')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey<String>('loop-composer-send')),
            )
            .onTap,
        isNull,
      );

      gateway.askDelay!.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('community-ai-turn-0-answer')),
        findsOneWidget,
      );
      expect(gateway.asked, <String>['这个币现在多少钱']);
    });

    testWidgets('a cited handle opens the source it names', (tester) async {
      await _pumpOpenPage(tester, _FakeAiGateway());
      await _ask(tester, '这个币现在多少钱');

      expect(
        find.byKey(const ValueKey<String>('community-ai-citation-s2')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('community-ai-citation-s2')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('community-ai-source-sheet')),
        findsOneWidget,
      );
      expect(find.text('绑定资产行情：PEPE'), findsOneWidget);
      expect(find.textContaining('观察于 2026-09-22'), findsOneWidget);
    });

    testWidgets('a refused question keeps the reason, never an answer', (
      tester,
    ) async {
      await _pumpOpenPage(
        tester,
        _FakeAiGateway(
          askFailure: const CommunityGatewayException(
            CommunityFailureKind.rateLimited,
            scope: 'user',
          ),
        ),
      );
      await _ask(tester, '这个币现在多少钱');

      expect(
        find.byKey(const ValueKey<String>('community-ai-turn-0-failure')),
        findsOneWidget,
      );
      expect(find.text('提问太频繁了，等一分钟再问。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-ai-turn-0-answer')),
        findsNothing,
      );
    });

    testWidgets('every answer can be reported once, by reason', (tester) async {
      final gateway = _FakeAiGateway();
      await _pumpOpenPage(tester, gateway);
      await _ask(tester, '这个币现在多少钱');

      await tester.tap(
        find.byKey(const ValueKey<String>('community-ai-report-$_answerId')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('community-ai-report-sheet')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('community-ai-report-reason-inaccurate'),
        ),
      );
      await tester.pumpAndSettle();

      expect(gateway.reported, <String>['$_answerId:inaccurate']);
      expect(find.text('已提交举报'), findsOneWidget);
      // The server keeps one report per (answer, account), so the control
      // stops offering a second one.
      expect(find.text('已举报'), findsWidgets);
      expect(
        tester
            .widget<InkWell>(
              find.byKey(
                const ValueKey<String>('community-ai-report-$_answerId'),
              ),
            )
            .onTap,
        isNull,
      );
    });
  });
}

/// The one clock the page's copy is read against.
abstract final class _TestTime {
  static final DateTime generatedAt = DateTime.utc(2026, 9, 22, 3);
}

Future<void> _pumpOpenPage(
  WidgetTester tester,
  _FakeAiGateway gateway, {
  bool settle = true,
}) async {
  await pumpCommunityPage(
    tester,
    const CommunityAiScreen(communityId: _communityId),
    communityAi: gateway,
    meta: testMetaSnapshot(communityAi: LoopV2CapabilityAvailability.available),
    settle: settle,
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester, String question) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('loop-composer-input')),
    question,
  );
  await tester.tap(find.byKey(const ValueKey<String>('loop-composer-send')));
  await tester.pumpAndSettle();
}

final class _FakeAiGateway implements CommunityAiGateway {
  _FakeAiGateway({
    this.overviewFailure,
    this.askFailure,
    this.overviewDelay,
    this.askDelay,
    CommunityAiBrief? brief,
  }) : brief =
           brief ??
           CommunityAiBriefAvailable(
             messageCount: 42,
             bounded: false,
             windowHours: 24,
             summary: '今天社区主要在讨论挖矿权重。',
             model: 'claude-sonnet-5',
             generatedAt: _TestTime.generatedAt,
           );

  final CommunityGatewayException? overviewFailure;
  final CommunityGatewayException? askFailure;
  final Completer<void>? overviewDelay;
  final Completer<void>? askDelay;

  /// The brief the *next* read answers with, so a test can let the server
  /// finish writing today's summary between two reads.
  CommunityAiBrief brief;

  /// How many times the overview was read. It is what says whether the page
  /// read again by itself, and how often.
  var loads = 0;
  final List<String> asked = <String>[];
  final List<String> reported = <String>[];

  static final _profile = CommunityAiSource(
    sourceId: 's1',
    kind: CommunityAiSourceKind.communityProfile,
    label: '社区档案：PEPE',
    observedAt: _TestTime.generatedAt,
  );
  static final _asset = CommunityAiSource(
    sourceId: 's2',
    kind: CommunityAiSourceKind.assetFacts,
    label: '绑定资产行情：PEPE',
    observedAt: _TestTime.generatedAt,
  );

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<CommunityAiOverview> loadOverview(String communityId) async {
    loads += 1;
    await overviewDelay?.future;
    final failure = overviewFailure;
    if (failure != null) throw failure;
    return CommunityAiOverview(
      capabilities: <CommunityAiCapability>[
        const CommunityAiCapability(
          ability: CommunityAiAbility.communitySupport,
          title: '社区客服',
          summary: 'CA 是什么、怎么买、怎么参与挖矿',
          available: true,
          reasonCode: null,
          adminOnly: false,
        ),
        const CommunityAiCapability(
          ability: CommunityAiAbility.projectKnowledge,
          title: '项目知识',
          summary: '白皮书、Tokenomics、Roadmap、FAQ',
          available: false,
          reasonCode: 'KNOWLEDGE_DOCUMENTS_NOT_INGESTED',
          adminOnly: false,
        ),
      ],
      knowledge: CommunityAiKnowledge(
        sourceCount: 2,
        updatedAt: _TestTime.generatedAt,
        sources: <CommunityAiSource>[_profile, _asset],
        omittedSources: const <CommunityAiOmittedSource>[
          CommunityAiOmittedSource(
            kind: CommunityAiSourceKind.announcements,
            reasonCode: 'ANNOUNCEMENT_SOURCE_UNAVAILABLE',
          ),
        ],
        documentsReasonCode: 'KNOWLEDGE_DOCUMENTS_NOT_INGESTED',
      ),
      exampleQuestions: const <String>['这个社区的代币现在多少钱', '怎么参与挖矿', '这周社区在讨论什么'],
      brief: brief,
      disclaimer: _disclaimer,
    );
  }

  @override
  Future<CommunityAiAnswer> ask({
    required String communityId,
    required String question,
  }) async {
    asked.add(question);
    await askDelay?.future;
    final failure = askFailure;
    if (failure != null) throw failure;
    return CommunityAiAnswer(
      answerId: _answerId,
      answer: '这个社区绑定的资产当前价格是 0.0000123 USD [s2]。',
      refusal: null,
      citations: <CommunityAiSource>[_asset],
      sources: <CommunityAiSource>[_profile, _asset],
      omittedSources: const <CommunityAiOmittedSource>[],
      model: 'claude-sonnet-5',
      generatedAt: _TestTime.generatedAt,
      disclaimer: _disclaimer,
    );
  }

  @override
  Future<CommunityAiReportReceipt> report({
    required String communityId,
    required String answerId,
    required CommunityAiReportReason reason,
    String? note,
  }) async {
    reported.add('$answerId:${reason.wireName}');
    return CommunityAiReportReceipt(
      answerId: answerId,
      reportId: _reportId,
      reason: reason,
      createdAt: _TestTime.generatedAt,
    );
  }
}

/// Records the idempotency key each write went out with.
final class _RecordingAiApi implements LoopV2CommunityAiApi {
  final List<String> keys = <String>[];
  LoopBackendFailure? failWith;

  @override
  Future<CommunityAiOverview> getOverview({
    required String accessToken,
    required String clientVersion,
    required String communityId,
  }) => throw UnimplementedError();

  @override
  Future<CommunityAiAnswer> ask({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String question,
  }) async {
    keys.add(idempotencyKey);
    final failure = failWith;
    if (failure != null) throw failure;
    return CommunityAiAnswer(
      answerId: _answerId,
      answer: '答案。',
      refusal: null,
      citations: const <CommunityAiSource>[],
      sources: const <CommunityAiSource>[],
      omittedSources: const <CommunityAiOmittedSource>[],
      model: 'claude-sonnet-5',
      generatedAt: _TestTime.generatedAt,
      disclaimer: _disclaimer,
    );
  }

  @override
  Future<CommunityAiReportReceipt> report({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String answerId,
    required CommunityAiReportReason reason,
    String? note,
  }) async {
    keys.add(idempotencyKey);
    return CommunityAiReportReceipt(
      answerId: answerId,
      reportId: _reportId,
      reason: reason,
      createdAt: _TestTime.generatedAt,
    );
  }
}

LoopAuthenticatedSession _immediateSession() {
  final bootstrapSession = LoopBootstrapSession(
    principalKey: 'did:privy:owner-1',
    accessTokens: _StaticAccessTokens(),
    repository: _BootstrapRepository(),
  );
  return LoopAuthenticatedSession(
    principalKey: 'did:privy:owner-1',
    bootstrapSession: bootstrapSession,
    accessTokens: _StaticAccessTokens(),
  );
}

final class _StaticAccessTokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => _token;
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

Dio _dio(void Function(RequestOptions, RequestInterceptorHandler) onRequest) {
  return Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
}

Response<Object?> _response(
  RequestOptions options,
  Object? data, {
  int statusCode = 200,
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': const <String>['no-store'],
      'x-request-id': const <String>[_requestId],
    }),
  );
}

Object? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name) return entry.value;
  }
  return null;
}
