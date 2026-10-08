import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/account/onboarding_communities.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_live_voice_rooms.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_recommended_communities.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

String _cid(int index) =>
    '${index.toString().padLeft(8, '0')}-5717-4562-b3fc-2c963f66a${index.toString().padLeft(3, '0')}';

Map<String, Object?> _communityWire(int index) => <String, Object?>{
  'communityId': _cid(index),
  'name': '社区 $index',
  'slug': 'community-$index',
  'description': null,
  'logoRef': 'avatar:preset/community-01',
  'verificationStatus': 'verified',
  'boundAssetKey': null,
  'memberCount': 100 + index,
  'createdAt': '2026-06-01T00:00:00.000Z',
  'configVersion': 'communityV1',
};

Map<String, Object?> _wire({int count = 7, int defaults = 5}) =>
    <String, Object?>{
      'items': <Object?>[for (var i = 1; i <= count; i += 1) _communityWire(i)],
      'defaultSelectedIds': <Object?>[
        for (var i = 1; i <= defaults; i += 1) _cid(i),
      ],
      'contractVersion': '2.0',
    };

final class _Recommended implements RecommendedCommunitiesGateway {
  _Recommended({this.answer, this.failure, this.pending = false});

  final RecommendedCommunities? answer;
  final CommunityFailureKind? failure;
  final bool pending;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<RecommendedCommunities> load() {
    if (pending) return Completer<RecommendedCommunities>().future;
    final kind = failure;
    if (kind != null) {
      return Future<RecommendedCommunities>.error(
        CommunityGatewayException(kind),
      );
    }
    return Future<RecommendedCommunities>.value(answer);
  }
}

final class _Muter implements CommunityChannelMuter {
  _Muter({this.fails = false});

  final bool fails;
  final List<String> muted = <String>[];

  @override
  Future<void> mute(String channelCid) async {
    if (fails) throw StateError('stream_unavailable');
    muted.add(channelCid);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required RecommendedCommunitiesGateway recommended,
  FakeCommunityGateway? community,
  CommunityChannelMuter? muter,
  VoidCallback? onDone,
  bool settle = true,
}) => pumpCommunityPage(
  tester,
  OnboardingCommunitiesScreen(onDone: onDone ?? () {}),
  community:
      community ??
      FakeCommunityGateway(
        directoryPage: const CommunityDirectoryPage(
          items: <CommunitySummary>[],
          nextCursor: null,
          recommendation: CommunityRecommendation(
            recommendationId: 'rec-1',
            ruleVersion: 'v1',
          ),
          ordering: CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),
        ),
        detail: testDetail(chat: testChatAvailable),
      ),
  size: const Size(390, 2400),
  settle: settle,
  overrides: <Override>[
    recommendedCommunitiesGatewayProvider.overrideWithValue(recommended),
    communityChannelMuterProvider.overrideWithValue(muter ?? _Muter()),
  ],
);

void main() {
  loopWatchGround();

  group('GET /v2/communities/recommended codec (S107 §4)', () {
    test('reads the contract shape', () {
      final answer = LoopV2RecommendedCommunitiesCodec.decode(_wire());
      expect(answer.items, hasLength(7));
      expect(answer.items.first.memberCount, 101);
      expect(answer.defaultSelectedIds, hasLength(5));
    });

    test('refuses an extra key, a missing version, a stray default', () {
      expect(
        () => LoopV2RecommendedCommunitiesCodec.decode(_wire()..['total'] = 7),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2RecommendedCommunitiesCodec.decode(
          _wire()..remove('contractVersion'),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2RecommendedCommunitiesCodec.decode(
          _wire()..['defaultSelectedIds'] = <Object?>[_cid(99)],
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2RecommendedCommunitiesCodec.decode(
          _wire(count: 7, defaults: 6),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('404 and 503 close the page', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = _StatusAdapter(404);
      await expectLater(
        DioLoopV2RecommendedCommunitiesApi(dio)
            .load(accessToken: 'token', clientVersion: '1.0.0'),
        throwsA(
          isA<LoopBackendFailure>().having(
            liveVoiceRoomFailureKind,
            'kind',
            CommunityFailureKind.unavailable,
          ),
        ),
      );
      expect(
        liveVoiceRoomFailureKind(
          const LoopBackendFailure(
            LoopBackendFailureKind.unavailable,
            statusCode: 503,
            code: 'CAPABILITY_UNAVAILABLE',
          ),
        ),
        CommunityFailureKind.unavailable,
      );
    });

    test('a community channel CID round-trips', () {
      final cid = loopCommunityChannelCid(_cid(3))!;
      expect(loopCommunityIdForChannelCid(cid), _cid(3));
      expect(loopCommunityChannelCid('frog'), isNull);
    });
  });

  group('onboarding-communities · five states', () {
    testWidgets('loading', (tester) async {
      await _pump(
        tester,
        recommended: _Recommended(pending: true),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
    });

    testWidgets('empty still offers the way in', (tester) async {
      await _pump(
        tester,
        recommended: _Recommended(
          answer: const RecommendedCommunities(
            items: <CommunitySummary>[],
            defaultSelectedIds: <String>[],
          ),
        ),
      );
      expect(find.text('还没有可加入的社区'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('onboarding-communities-enter')),
        findsOneWidget,
      );
    });

    for (final (kind, key) in <(CommunityFailureKind, String)>[
      (CommunityFailureKind.unavailable, 'community-state-unavailable'),
      (CommunityFailureKind.offline, 'community-state-offline'),
      (CommunityFailureKind.permissionDenied, 'community-state-permission'),
      (CommunityFailureKind.unexpected, 'community-state-error'),
    ]) {
      testWidgets('${kind.name}: no invented list, 跳过 still works', (
        tester,
      ) async {
        var done = 0;
        await _pump(
          tester,
          recommended: _Recommended(failure: kind),
          onDone: () => done += 1,
        );
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey<String>('onboarding-communities-skip')),
        );
        await tester.pumpAndSettle();
        expect(done, 1);
      });
    }
  });

  group('onboarding-communities · join', () {
    RecommendedCommunities answer() =>
        LoopV2RecommendedCommunitiesCodec.decode(_wire());

    testWidgets('five are ticked by default', (tester) async {
      await _pump(tester, recommended: _Recommended(answer: answer()));
      expect(find.text('已选'), findsNWidgets(5));
      expect(find.text('未选'), findsNWidgets(2));
      expect(find.text('加入 5 个社区并进入'), findsOneWidget);
    });

    testWidgets('进入 LOOP joins each ticked one and mutes its chat', (
      tester,
    ) async {
      final community = FakeCommunityGateway(
        directoryPage: const CommunityDirectoryPage(
          items: <CommunitySummary>[],
          nextCursor: null,
          recommendation: CommunityRecommendation(
            recommendationId: 'rec-1',
            ruleVersion: 'v1',
          ),
          ordering: CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),
        ),
        detail: testDetail(chat: testChatAvailable),
      );
      final muter = _Muter();
      var done = 0;
      await _pump(
        tester,
        recommended: _Recommended(answer: answer()),
        community: community,
        muter: muter,
        onDone: () => done += 1,
      );
      // Untick one: four remain.
      await tester.tap(find.text('社区 2'));
      await tester.pumpAndSettle();
      expect(find.text('加入 4 个社区并进入'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('onboarding-communities-enter')),
      );
      await tester.pumpAndSettle();

      expect(
        community.commands.where((command) => command.startsWith('join:')),
        <String>[
          'join:${_cid(1)}',
          'join:${_cid(3)}',
          'join:${_cid(4)}',
          'join:${_cid(5)}',
        ],
      );
      expect(muter.muted, hasLength(4));
      expect(done, 1);
    });

    testWidgets('a failed join is said on its row and does not block', (
      tester,
    ) async {
      final community = FakeCommunityGateway(
        directoryPage: const CommunityDirectoryPage(
          items: <CommunitySummary>[],
          nextCursor: null,
          recommendation: CommunityRecommendation(
            recommendationId: 'rec-1',
            ruleVersion: 'v1',
          ),
          ordering: CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),
        ),
        detail: testDetail(chat: testChatAvailable),
        writeFailure: CommunityFailureKind.permissionDenied,
      );
      var done = 0;
      await _pump(
        tester,
        recommended: _Recommended(answer: answer()),
        community: community,
        onDone: () => done += 1,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('onboarding-communities-enter')),
      );
      await tester.pumpAndSettle();

      // All five were tried; none joined; the page stayed and said so.
      expect(
        community.commands.where((command) => command.startsWith('join:')),
        hasLength(5),
      );
      expect(done, 0);
      expect(find.text('当前账号没有执行这个操作的权限。'), findsNWidgets(5));
      expect(find.text('继续进入 LOOP'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('onboarding-communities-enter')),
      );
      await tester.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('a join whose mute failed says it is joined but not muted', (
      tester,
    ) async {
      var done = 0;
      await _pump(
        tester,
        recommended: _Recommended(answer: answer()),
        muter: _Muter(fails: true),
        onDone: () => done += 1,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('onboarding-communities-enter')),
      );
      await tester.pumpAndSettle();
      expect(done, 0);
      expect(find.textContaining('免打扰没有设置成功'), findsNWidgets(5));
    });

    testWidgets('跳过 joins nothing', (tester) async {
      final community = FakeCommunityGateway(
        detail: testDetail(chat: testChatAvailable),
      );
      var done = 0;
      await _pump(
        tester,
        recommended: _Recommended(answer: answer()),
        community: community,
        onDone: () => done += 1,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('onboarding-communities-skip-text')),
      );
      await tester.pumpAndSettle();
      expect(done, 1);
      expect(
        community.commands.where((command) => command.startsWith('join:')),
        isEmpty,
      );
    });

    testWidgets('the list continues into the directory', (tester) async {
      final community = FakeCommunityGateway(
        directoryPage: CommunityDirectoryPage(
          items: <CommunitySummary>[
            testCommunity(communityId: _cid(1), name: '社区 1'),
            testCommunity(communityId: _cid(42), name: '目录社区'),
          ],
          nextCursor: null,
          recommendation: const CommunityRecommendation(
            recommendationId: 'rec-1',
            ruleVersion: 'v1',
          ),
          ordering: const CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),
        ),
        detail: testDetail(chat: testChatAvailable),
      );
      await _pump(
        tester,
        recommended: _Recommended(answer: answer()),
        community: community,
      );
      // The directory row arrives after the seven recommended ones, and the
      // one it shares with them is not listed twice.
      expect(find.text('目录社区'), findsOneWidget);
      expect(find.text('社区 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('onboarding-communities-end')),
        findsOneWidget,
      );
    });
  });
}

final class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"message":"Route not found"}',
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
