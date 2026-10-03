import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_recommendations_controller.dart';
import 'package:loop_mobile/features/community/community_recommendations_screen.dart';
import 'package:loop_mobile/features/community/community_state.dart';

import 'support/community_test_harness.dart';

CommunityHome _home({int count = 7, List<JoinedCommunity> joined = const []}) =>
    CommunityHome(
      joined: joined,
      joinedTruncated: false,
      discover: <CommunitySummary>[
        for (var index = 0; index < count; index += 1)
          // Counts deliberately run opposite to server order.
          testCommunity(
            communityId: 'community-$index',
            name: '社区 $index',
            memberCount: index * 100,
          ),
      ],
      unread: const LoopUnavailableFact('UNREAD_UNAVAILABLE'),
      liveVoice: const LoopUnavailableFact('VOICE_UNAVAILABLE'),
      observedAt: DateTime.utc(2026, 10, 3),
      source: 'home',
      recommendation: const CommunityRecommendation(
        recommendationId: 'onboarding',
        ruleVersion: 'rule-1',
      ),
    );

class _Gateway implements CommunityGateway {
  _Gateway({CommunityHome? home}) : home = home ?? _home();

  CommunityHome home;
  final List<String> joins = <String>[];
  final Map<String, CommunityFailureKind> failures = {};
  final Map<String, CommunityDetail> answers = {};
  Completer<CommunityDetail>? pendingJoin;
  int homeReads = 0;
  int directoryReads = 0;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.preview;

  @override
  Future<CommunityHome> loadHome() async {
    homeReads += 1;
    return home;
  }

  @override
  Future<CommunityDetail> join(String communityId) async {
    joins.add(communityId);
    if (pendingJoin != null) return pendingJoin!.future;
    final failure = failures[communityId];
    if (failure != null) throw CommunityGatewayException(failure);
    return answers[communityId] ??
        testDetail(
          community: testCommunity(communityId: communityId),
          viewer: testViewer(role: CommunityRole.member),
        );
  }

  @override
  Future<CommunityDirectoryPage> listCommunities({
    CommunityDirectorySort sort = CommunityDirectorySort.members,
    CommunityVerificationFilter verification =
        CommunityVerificationFilter.verified,
    CommunityMembershipFilter membership = CommunityMembershipFilter.all,
    String? cursor,
  }) {
    directoryReads += 1;
    throw StateError('Recommendations must read home, never the directory.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_Gateway gateway) {
  final container = ProviderContainer(
    overrides: [communityGatewayProvider.overrideWithValue(gateway)],
  );
  container.listen(communityRecommendationsControllerProvider, (_, _) {});
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'defaults at most five in home order and never requests popularity',
    () async {
      final gateway = _Gateway();
      final container = _container(gateway);
      final controller = container.read(
        communityRecommendationsControllerProvider.notifier,
      );
      await controller.load();
      final state = container.read(communityRecommendationsControllerProvider);
      expect(state.pendingIds, [for (var i = 0; i < 5; i++) 'community-$i']);
      expect(state.items.map((item) => item.communityId), [
        for (var i = 0; i < 7; i++) 'community-$i',
      ]);
      expect(state.recommendation?.ruleVersion, 'rule-1');
      expect(gateway.homeReads, 1);
      expect(gateway.directoryReads, 0);
      await controller.load();
      expect(gateway.homeReads, 1);
    },
  );

  test(
    'excludes current memberships and defaults all when fewer than five',
    () async {
      final community = testCommunity(communityId: 'community-0');
      final gateway = _Gateway(
        home: _home(
          count: 3,
          joined: [
            JoinedCommunity(
              community: community,
              membership: testViewer(role: CommunityRole.member).membership!,
            ),
          ],
        ),
      );
      final container = _container(gateway);
      await container
          .read(communityRecommendationsControllerProvider.notifier)
          .load();
      expect(
        container.read(communityRecommendationsControllerProvider).pendingIds,
        ['community-1', 'community-2'],
      );
    },
  );

  test(
    'deselection and additional selection determine exact join requests',
    () async {
      final gateway = _Gateway();
      final container = _container(gateway);
      final controller = container.read(
        communityRecommendationsControllerProvider.notifier,
      );
      await controller.load();
      controller.toggle('community-1');
      controller.toggle('community-6');
      controller.toggle('not-listed');
      expect(await controller.joinSelected(), isTrue);
      expect(gateway.joins, [
        'community-0',
        'community-2',
        'community-3',
        'community-4',
        'community-6',
      ]);
      expect(await controller.joinSelected(), isTrue);
      expect(gateway.joins.length, 5);
    },
  );

  test(
    'partial failure preserves selection and retries only failed joins',
    () async {
      final gateway = _Gateway(home: _home(count: 3));
      gateway.failures['community-1'] = CommunityFailureKind.offline;
      final container = _container(gateway);
      final controller = container.read(
        communityRecommendationsControllerProvider.notifier,
      );
      await controller.load();
      expect(await controller.joinSelected(), isFalse);
      final state = container.read(communityRecommendationsControllerProvider);
      expect(state.joined, {'community-0', 'community-2'});
      expect(state.pendingIds, ['community-1']);
      expect(state.selected, {'community-0', 'community-1', 'community-2'});
      expect(state.failures['community-1'], CommunityFailureKind.offline);
      gateway.failures.clear();
      expect(await controller.joinSelected(), isTrue);
      expect(gateway.joins, [
        'community-0',
        'community-1',
        'community-2',
        'community-1',
      ]);
      expect(
        container.read(communityRecommendationsControllerProvider).failures,
        isEmpty,
      );
    },
  );

  test(
    'a matching non-banned membership is required to announce a join',
    () async {
      final gateway = _Gateway(home: _home(count: 3));
      gateway.answers['community-0'] = testDetail(
        community: testCommunity(communityId: 'wrong-community'),
      );
      gateway.answers['community-1'] = testDetail(
        community: testCommunity(communityId: 'community-1'),
        viewer: testViewer(role: null),
      );
      gateway.answers['community-2'] = testDetail(
        community: testCommunity(communityId: 'community-2'),
        viewer: testViewer(
          role: CommunityRole.member,
          status: CommunityMemberStatus.banned,
        ),
      );
      final container = _container(gateway);
      final controller = container.read(
        communityRecommendationsControllerProvider.notifier,
      );
      await controller.load();
      expect(await controller.joinSelected(), isFalse);
      final state = container.read(communityRecommendationsControllerProvider);
      expect(state.joined, isEmpty);
      expect(state.failures, {
        'community-0': CommunityFailureKind.outcomeUnknown,
        'community-1': CommunityFailureKind.outcomeUnknown,
        'community-2': CommunityFailureKind.permissionDenied,
      });
    },
  );

  test('single flight freezes selection during an in-flight batch', () async {
    final gateway = _Gateway(home: _home(count: 1));
    gateway.pendingJoin = Completer<CommunityDetail>();
    final container = _container(gateway);
    final controller = container.read(
      communityRecommendationsControllerProvider.notifier,
    );
    await controller.load();
    final first = controller.joinSelected();
    controller.toggle('community-0');
    expect(await controller.joinSelected(), isFalse);
    expect(
      container.read(communityRecommendationsControllerProvider).selected,
      {'community-0'},
    );
    gateway.pendingJoin!.complete(
      testDetail(community: testCommunity(communityId: 'community-0')),
    );
    expect(await first, isTrue);
    expect(gateway.joins, ['community-0']);
  });

  testWidgets('skip is optional and invitation delegates without join calls', (
    tester,
  ) async {
    final gateway = _Gateway(home: _home(count: 2));
    var done = 0;
    var invitations = 0;
    await pumpCommunityPage(
      tester,
      CommunityRecommendationsScreen(
        onDone: () => done += 1,
        onBindInvitation: () => invitations += 1,
      ),
      community: gateway,
    );
    await tester.tap(find.byKey(const ValueKey('recommendations-invitation')));
    expect(invitations, 1);
    await tester.tap(find.byKey(const ValueKey('recommendations-skip')));
    expect(done, 1);
    expect(gateway.joins, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'partial failure stays open until remaining membership confirms',
    (tester) async {
      final gateway = _Gateway(home: _home(count: 2));
      gateway.failures['community-1'] = CommunityFailureKind.permissionDenied;
      var done = 0;
      await pumpCommunityPage(
        tester,
        CommunityRecommendationsScreen(onDone: () => done += 1),
        community: gateway,
      );
      await tester.tap(find.byKey(const ValueKey('recommendations-join')));
      await tester.pumpAndSettle();
      expect(done, 0);
      expect(find.text('已加入'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('recommendations-partial-failure')),
        findsOneWidget,
      );
      gateway.failures.clear();
      await tester.tap(find.byKey(const ValueKey('recommendations-join')));
      await tester.pumpAndSettle();
      expect(done, 1);
      expect(gateway.joins, ['community-0', 'community-1', 'community-1']);
      expect(tester.takeException(), isNull);
    },
  );

  test('unavailable default never fabricates a recommendation', () async {
    final container = ProviderContainer.test();
    container.listen(communityRecommendationsControllerProvider, (_, _) {});
    final controller = container.read(
      communityRecommendationsControllerProvider.notifier,
    );
    await controller.load();
    expect(
      container.read(communityRecommendationsControllerProvider).phase,
      CommunityViewPhase.unavailable,
    );
    expect(await controller.joinSelected(), isFalse);
  });

  testWidgets('closed capability still permits skipping the optional step', (
    tester,
  ) async {
    var done = 0;
    await pumpCommunityPage(
      tester,
      CommunityRecommendationsScreen(onDone: () => done += 1),
    );
    await tester.tap(find.byKey(const ValueKey('recommendations-skip')));
    expect(done, 1);
    expect(tester.takeException(), isNull);
  });

  test(
    'retiring controller drops a late write instead of announcing done',
    () async {
      final gateway = _Gateway(home: _home(count: 1));
      gateway.pendingJoin = Completer<CommunityDetail>();
      final container = ProviderContainer(
        overrides: [communityGatewayProvider.overrideWithValue(gateway)],
      );
      container.listen(communityRecommendationsControllerProvider, (_, _) {});
      final controller = container.read(
        communityRecommendationsControllerProvider.notifier,
      );
      await controller.load();
      final write = controller.joinSelected();
      container.dispose();
      gateway.pendingJoin!.complete(
        testDetail(community: testCommunity(communityId: 'community-0')),
      );
      expect(await write, isFalse);
      expect(gateway.joins, ['community-0']);
    },
  );
}
