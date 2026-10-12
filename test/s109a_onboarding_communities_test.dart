import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/account/onboarding_communities.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
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

/// Records every client-side mute; since decision 0136 a join makes none.
final class _Muter implements CommunityChannelMuter {
  final List<String> muted = <String>[];

  @override
  Future<void> mute(String channelCid) async {
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
  bool reduceMotion = false,
}) => pumpCommunityPage(
  tester,
  reduceMotion
      ? Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: OnboardingCommunitiesScreen(onDone: onDone ?? () {}),
          ),
        )
      : OnboardingCommunitiesScreen(onDone: onDone ?? () {}),
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

FakeCommunityGateway _gateway({CommunityFailureKind? writeFailure}) =>
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
      writeFailure: writeFailure,
    );

const _entering = ValueKey<String>('onboarding-communities-entering');

OnboardingCommunitiesState _state(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(OnboardingCommunitiesScreen)),
    ).read(onboardingCommunitiesControllerProvider);

/// Pumps one frame at a time through the mute wait. The entering page's
/// loader sweeps until the route goes away, so `pumpAndSettle` would never
/// return while it is on screen.
Future<void> _pumpThroughWait(WidgetTester tester) async {
  for (var round = 0; round < onboardingMuteSyncRounds; round += 1) {
    await tester.pump(onboardingMuteSyncInterval);
    await tester.pump();
  }
  await tester.pump();
}

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
      // Decision 0126: the state is a Lime tick circle named 已选 / 未选.
      Finder tick(String state) => find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == state,
      );
      expect(tick('已选'), findsNWidgets(5));
      expect(tick('未选'), findsNWidgets(2));
      expect(find.text('加入 5 个社区并进入'), findsOneWidget);
    });

    testWidgets('进入 LOOP joins each ticked one with notifications: muted '
        'and never mutes on the client (decision 0136)', (tester) async {
      final community = _gateway()..membershipReadsBeforeSynced = 1;
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
      await tester.pump();
      await tester.pump();

      expect(
        community.commands.where((command) => command.startsWith('join:')),
        <String>[
          'join:${_cid(1)}',
          'join:${_cid(3)}',
          'join:${_cid(4)}',
          'join:${_cid(5)}',
        ],
      );
      expect(
        community.joinNotifications,
        List<CommunityNotificationPreference>.filled(
          4,
          CommunityNotificationPreference.muted,
        ),
      );
      // The app no longer races the server's channel sync.
      expect(muter.muted, isEmpty);
      // Joined; the server has not confirmed the mute yet. Decision 0151:
      // the list has given way to 正在进入 LOOP for the wait.
      Iterable<OnboardingJoinResult> joined() =>
          _state(tester).results.values.where((result) => result.isJoined);
      expect(joined(), hasLength(4));
      expect(joined(), everyElement(OnboardingJoinResult.joinedMutePending));
      expect(find.byKey(_entering), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('onboarding-communities-list')),
        findsNothing,
      );
      expect(done, 0);

      // First poll: not yet synced.
      await tester.pump(onboardingMuteSyncInterval);
      await tester.pump();
      expect(joined(), everyElement(OnboardingJoinResult.joinedMutePending));
      expect(find.byKey(_entering), findsOneWidget);
      expect(done, 0);

      // Second poll: synced and muted; the page goes on by itself.
      await tester.pump(onboardingMuteSyncInterval);
      await tester.pump();
      await tester.pump();
      expect(joined(), everyElement(OnboardingJoinResult.joined));
      expect(community.membershipReads, hasLength(8));
      expect(done, 1);
    });

    testWidgets('a mute the server has not confirmed in ~10 s keeps 生效中 '
        'and the page goes on anyway', (tester) async {
      final community = _gateway()..membershipReadsBeforeSynced = 1000;
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
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_entering), findsOneWidget);
      await _pumpThroughWait(tester);
      expect(
        _state(tester).results.values,
        everyElement(OnboardingJoinResult.joinedMutePending),
      );
      expect(
        community.membershipReads,
        hasLength(5 * onboardingMuteSyncRounds),
      );
      expect(done, 1);
    });

    testWidgets('the entering page offers no way out and leaves once '
        '(decision 0151)', (tester) async {
      final community = _gateway()..membershipReadsBeforeSynced = 1000;
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
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_entering), findsOneWidget);
      expect(find.text('正在进入 LOOP'), findsOneWidget);
      expect(find.text('正在为你把刚加入的社区设为免打扰…'), findsOneWidget);
      // The five communities just joined circle the centre; LOOP is not
      // there yet.
      for (var index = 1; index <= 5; index += 1) {
        expect(
          find.byKey(
            ValueKey<String>('onboarding-entering-logo-${_cid(index)}'),
          ),
          findsOneWidget,
        );
      }
      double opacityOf(Finder finder) => tester
          .widget<FadeTransition>(
            find
                .ancestor(of: finder, matching: find.byType(FadeTransition))
                .first,
          )
          .opacity
          .value;
      const wordmark = ValueKey<String>('onboarding-entering-wordmark');
      expect(opacityOf(find.byKey(wordmark)), 0);
      // Past the gathering and the ring, the wordmark has taken their place.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(opacityOf(find.byKey(wordmark)), 1);
      // The logos have gathered into the centre and are no longer drawn.
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey<String>('onboarding-entering-logo-${_cid(1)}'),
          ),
          matching: find.byType(CommunityLogo),
        ),
        findsNothing,
      );
      for (final key in <String>[
        'onboarding-communities-enter',
        'onboarding-communities-skip',
        'onboarding-communities-skip-text',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing);
      }
      expect(find.byType(TextButton), findsNothing);
      // No way back either: the system back gesture is refused.
      final pop = tester.widget(
        find.ancestor(
          of: find.byKey(_entering),
          matching: find.byWidgetPredicate((widget) => widget is PopScope),
        ),
      );
      expect((pop as PopScope).canPop, isFalse);
      expect(done, 0);
      // The wait ends on its own at the ceiling, exactly once.
      await _pumpThroughWait(tester);
      expect(done, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(done, 1);
    });

    testWidgets('reduced motion draws the last frame and holds still', (
      tester,
    ) async {
      final community = _gateway()
        ..membershipReadFailure = CommunityFailureKind.notFound;
      var done = 0;
      await _pump(
        tester,
        recommended: _Recommended(answer: answer()),
        community: community,
        onDone: () => done += 1,
        reduceMotion: true,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('onboarding-communities-enter')),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_entering), findsOneWidget);
      const wordmark = ValueKey<String>('onboarding-entering-wordmark');
      expect(
        tester
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.byKey(wordmark),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        1,
      );
      expect(find.text('正在进入 LOOP'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey<String>('onboarding-entering-logo-${_cid(1)}'),
          ),
          matching: find.byType(CommunityLogo),
        ),
        findsNothing,
      );
      // Nothing is ticking: no frame is asked for while the page waits.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(done, 0);
      await tester.pump(onboardingEnteringMinimumStay);
      await tester.pump();
      expect(done, 1);
      expect(find.byKey(_entering), findsOneWidget);
    });

    testWidgets('a clean result never draws on the list (decision 0151)', (
      tester,
    ) async {
      final community = _gateway()..membershipReadsBeforeSynced = 1000;
      await _pump(
        tester,
        recommended: _Recommended(answer: answer()),
        community: community,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('onboarding-communities-enter')),
      );
      // Every frame until the entering page shows is a submitting frame.
      var frames = 0;
      while (find.byKey(_entering).evaluate().isEmpty) {
        await tester.pump();
        frames += 1;
        expect(frames, lessThan(20));
        if (find.byKey(_entering).evaluate().isNotEmpty) break;
        expect(find.text('正在加入…'), findsOneWidget);
        expect(find.text('进入 LOOP'), findsNothing);
      }
      expect(find.byKey(_entering), findsOneWidget);
      await _pumpThroughWait(tester);
    });

    testWidgets('nothing ticked leaves at once, without the entering page', (
      tester,
    ) async {
      final community = _gateway();
      var done = 0;
      await _pump(
        tester,
        recommended: _Recommended(answer: answer()),
        community: community,
        onDone: () => done += 1,
      );
      for (var index = 1; index <= 5; index += 1) {
        await tester.tap(find.text('社区 $index'));
        await tester.pumpAndSettle();
      }
      expect(find.text('进入 LOOP'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('onboarding-communities-enter')),
      );
      await tester.pumpAndSettle();
      expect(done, 1);
      expect(find.byKey(_entering), findsNothing);
      expect(
        community.commands.where((command) => command.startsWith('join:')),
        isEmpty,
      );
    });

    testWidgets('a server without the membership read ends the wait at once', (
      tester,
    ) async {
      final community = _gateway()
        ..membershipReadFailure = CommunityFailureKind.notFound;
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
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_entering), findsOneWidget);
      await tester.pump(onboardingMuteSyncInterval);
      await tester.pump();
      await tester.pump();
      expect(community.membershipReads, hasLength(5));
      expect(
        _state(tester).results.values,
        everyElement(OnboardingJoinResult.joinedMutePending),
      );
      // Decision 0151: the wait is over, but the gathering plays out first.
      expect(done, 0);
      await tester.pump(
        onboardingEnteringMinimumStay - onboardingMuteSyncInterval,
      );
      await tester.pump();
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
      expect(find.byKey(_entering), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('onboarding-communities-list')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('onboarding-communities-enter')),
      );
      await tester.pumpAndSettle();
      expect(done, 1);
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
