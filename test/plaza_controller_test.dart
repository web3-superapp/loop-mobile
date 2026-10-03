import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/plaza_controller.dart';
import 'package:loop_mobile/features/community/plaza_screen.dart';

import 'support/community_test_harness.dart';

CommunityDirectoryPage directory(List<String> ids, {String? cursor}) =>
    CommunityDirectoryPage(
      items: ids.map((id) => testCommunity(communityId: id)).toList(),
      nextCursor: cursor,
      recommendation: const CommunityRecommendation(
        ruleVersion: 'rule',
        recommendationId: 'rec',
      ),
      ordering: const CommunityOrderingApplied(
        sort: CommunityDirectorySort.members,
        basis: CommunityStoredBasis(),
      ),
    );

class _Gateway implements CommunityGateway {
  final List<CommunityDirectoryPage> pages;
  _Gateway(this.pages);
  int reads = 0;
  int attempts = 0;
  int active = 0;
  int maxActive = 0;
  bool wrongIdentity = false;
  bool brokenVoice = false;
  Completer<CommunityDirectoryPage>? pending;
  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.preview;
  @override
  Future<CommunityDirectoryPage> listCommunities({
    CommunityDirectorySort sort = CommunityDirectorySort.members,
    CommunityVerificationFilter verification =
        CommunityVerificationFilter.verified,
    CommunityMembershipFilter membership = CommunityMembershipFilter.all,
    String? cursor,
  }) async {
    expect(verification, CommunityVerificationFilter.all);
    attempts++;
    if (pending != null) return pending!.future;
    return pages[reads++];
  }

  @override
  Future<CommunityDetail> loadCommunity(String id) async {
    active++;
    if (active > maxActive) maxActive = active;
    await Future<void>.delayed(Duration.zero);
    active--;
    if (brokenVoice) throw StateError('No voice projection');
    return testDetail(
      community: testCommunity(communityId: wrongIdentity ? 'other' : id),
      voice: testVoiceLive,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'refresh retains communities during reading and retries a failed refresh',
    () async {
      final gateway = _Gateway([
        directory(['old']),
        directory(['fresh']),
      ]);
      final controller = PlazaController(gateway);
      addTearDown(controller.dispose);
      await controller.reload();
      final pending = Completer<CommunityDirectoryPage>();
      gateway.pending = pending;
      final refresh = controller.reload();
      expect(controller.loading, isTrue);
      expect(controller.items.map((row) => row.communityId), ['old']);
      pending.completeError(StateError('unavailable'));
      await refresh;
      expect(controller.failed, isTrue);
      expect(controller.items.map((row) => row.communityId), ['old']);
      gateway.pending = null;
      await controller.retry();
      expect(controller.failed, isFalse);
      expect(controller.items.map((row) => row.communityId), ['fresh']);
    },
  );

  testWidgets(
    'swiping appends communities and pull-down refresh replaces them',
    (tester) async {
      final gateway = _Gateway([
        directory([for (var i = 0; i < 6; i++) '$i'], cursor: 'more'),
        directory(['6', '7']),
        directory(['fresh']),
      ]);
      await pumpCommunityPage(
        tester,
        const PlazaScreen(),
        community: gateway,
        size: const Size(390, 844),
      );
      expect(find.text('上一页'), findsNothing);
      expect(find.text('下一页'), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(gateway.reads, 2);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlazaScreen)),
      );
      expect(container.read(plazaControllerProvider).items.length, 8);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plaza-7')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('plaza-7')), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 450));
      await tester.pumpAndSettle();
      expect(gateway.reads, 3);
      expect(find.byKey(const ValueKey('plaza-fresh')), findsOneWidget);
      expect(find.byKey(const ValueKey('plaza-0')), findsNothing);
    },
  );

  testWidgets(
    'repeated swipes do not duplicate an in-flight or finished read',
    (tester) async {
      final gateway = _Gateway([
        directory([for (var i = 0; i < 6; i++) '$i'], cursor: 'more'),
      ]);
      await pumpCommunityPage(
        tester,
        const PlazaScreen(),
        community: gateway,
        size: const Size(390, 844),
      );
      gateway.pending = Completer<CommunityDirectoryPage>();
      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump();
      }
      expect(gateway.attempts, 2);
      gateway.pending!.complete(directory(['6', '7']));
      gateway.pending = null;
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(gateway.attempts, 2);
    },
  );

  test(
    'loading more appends without duplicates, with bounded room reads',
    () async {
      final gateway = _Gateway([
        directory([for (var i = 0; i < 8; i++) '$i']),
      ]);
      final controller = PlazaController(gateway);
      addTearDown(controller.dispose);
      await controller.reload();
      expect(controller.items.map((row) => row.communityId), [
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
      ]);
      expect(gateway.maxActive, 3);
      await controller.next();
      expect(controller.items.map((row) => row.communityId), [
        for (var i = 0; i < 8; i++) '$i',
      ]);
      expect(controller.canNext, false);
    },
  );
  test('four empty pages retain continuation, fifth page is reached', () async {
    final gateway = _Gateway([
      for (var i = 0; i < 4; i++) directory([], cursor: '$i'),
      directory(['last']),
    ]);
    final controller = PlazaController(gateway);
    addTearDown(controller.dispose);
    await controller.reload();
    expect(gateway.reads, 4);
    expect(controller.hasUnreadDirectory, true);
    await controller.next();
    expect(controller.items.single.communityId, 'last');
    expect(controller.page, 0);
    expect(controller.hasUnreadDirectory, false);
  });
  test('partial six-row viewport is filled before advancing', () async {
    final gateway = _Gateway([
      directory(['0'], cursor: 'a'),
      directory(['1'], cursor: 'b'),
      directory(['2'], cursor: 'c'),
      directory([], cursor: 'd'),
      directory(['3', '4', '5', '6']),
    ]);
    final controller = PlazaController(gateway);
    addTearDown(controller.dispose);
    await controller.reload();
    expect(controller.items.length, 3);
    await controller.next();
    expect(controller.page, 0);
    expect(controller.items.map((row) => row.communityId), [
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
    ]);
    await controller.next();
    expect(controller.items.map((row) => row.communityId), [
      for (var i = 0; i < 7; i++) '$i',
    ]);
  });
  test('wrong room identity and failed room read stay unknown', () async {
    final gateway = _Gateway([
      directory(['a']),
      directory(['b']),
    ])..wrongIdentity = true;
    final controller = PlazaController(gateway);
    addTearDown(controller.dispose);
    await controller.reload();
    expect(controller.voices['a'], null);
    gateway.wrongIdentity = false;
    gateway.brokenVoice = true;
    await controller.reload();
    expect(controller.voices['b'], null);
  });
  test('repeated cursor fails bounded rather than declaring empty', () async {
    final gateway = _Gateway([
      directory([], cursor: 'a'),
      directory([], cursor: 'a'),
    ]);
    final controller = PlazaController(gateway);
    addTearDown(controller.dispose);
    await controller.reload();
    expect(controller.failed, true);
    expect(gateway.reads, 2);
  });
  test('gateway and owner changes retire directory and late results', () async {
    final gateway = _Gateway([])..pending = Completer<CommunityDirectoryPage>();
    final container = ProviderContainer(
      overrides: [
        communityGatewayProvider.overrideWithValue(gateway),
        loopAccountScopeProvider.overrideWithValue('a'),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(plazaControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    final old = container.read(plazaControllerProvider);
    final load = old.reload();
    final replacement = _Gateway([
      directory(['new']),
    ]);
    container.updateOverrides([
      communityGatewayProvider.overrideWithValue(replacement),
      loopAccountScopeProvider.overrideWithValue('b'),
    ]);
    final fresh = container.read(plazaControllerProvider);
    expect(identical(old, fresh), false);
    await container.pump();
    gateway.pending!.complete(directory(['old']));
    await load;
    await fresh.reload();
    expect(fresh.items.single.communityId, 'new');
    expect(old.items, isEmpty);
  });
}
