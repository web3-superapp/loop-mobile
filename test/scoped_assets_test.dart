import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/scoped_assets_controller.dart';
import 'package:loop_mobile/features/market/scoped_assets_screen.dart';

import 'support/community_test_harness.dart';
import 'support/s5_fixtures.dart';
import 'support/s7_fixtures.dart';
import 'support/s83c_fixtures.dart';
import 'support/s5_page_harness.dart';

class _Launch implements LaunchGateway {
  LaunchOverview overview = s7Overview();
  final details = <String, LaunchDetail>{};
  final requested = <String>[];
  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.preview;
  @override
  Future<LaunchOverview> loadOverview() async => overview;
  @override
  Future<LaunchDetail> loadLaunch(String id) async {
    requested.add(id);
    return details[id] ?? s7Detail();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Market implements MarketReadGateway {
  final requested = <String>[];
  Completer<MarketAssetDetail>? pending;
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.preview;
  @override
  Future<MarketAssetDetail> loadAsset(String id) async {
    requested.add(id);
    return pending == null ? s5Detail() : pending!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Community implements CommunityGateway {
  final pages = <CommunityDirectoryPage>[];
  int reads = 0;
  bool failNext = false;
  @override
  get mode => CommunityGatewayMode.preview;
  @override
  Future<CommunityDirectoryPage> listCommunities({
    CommunityDirectorySort sort = CommunityDirectorySort.members,
    CommunityVerificationFilter verification = CommunityVerificationFilter.all,
    CommunityMembershipFilter membership = CommunityMembershipFilter.all,
    String? cursor,
  }) async {
    if (failNext) {
      failNext = false;
      throw const CommunityGatewayException(CommunityFailureKind.unavailable);
    }
    return pages[reads++];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CommunityDirectoryPage _page(List<CommunitySummary> items, {String? cursor}) =>
    CommunityDirectoryPage(
      items: items,
      nextCursor: cursor,
      recommendation: const CommunityRecommendation(
        recommendationId: 'directory',
        ruleVersion: 'v1',
      ),
      ordering: const CommunityOrderingApplied(
        sort: CommunityDirectorySort.members,
        basis: CommunityStoredBasis(),
      ),
    );

void main() {
  test(
    'refresh retry starts at the first batch despite retained rows',
    () async {
      final community = _Community()
        ..pages.addAll([
          _page([
            for (var i = 0; i < 6; i++) testCommunity(communityId: 'old-$i'),
          ], cursor: 'more'),
          _page([testCommunity(communityId: 'old-6')]),
          _page([
            for (var i = 0; i < 8; i++) testCommunity(communityId: 'new-$i'),
          ]),
        ]);
      final container = ProviderContainer(
        overrides: [
          communityGatewayProvider.overrideWithValue(community),
          marketReadGatewayProvider.overrideWithValue(_Market()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(communityScopedAssetsControllerProvider, (_, _) {});
      final controller = container.read(
        communityScopedAssetsControllerProvider.notifier,
      );
      await controller.load();
      await controller.next();
      community.failNext = true;
      await controller.reload();
      expect(
        container.read(communityScopedAssetsControllerProvider).items.length,
        7,
      );
      expect(
        container.read(communityScopedAssetsControllerProvider).failure,
        isNotNull,
      );
      await controller.retry();
      expect(
        container
            .read(communityScopedAssetsControllerProvider)
            .items
            .map((item) => item.sourceId),
        [for (var i = 0; i < 6; i++) 'new-$i'],
      );
      expect(
        container.read(communityScopedAssetsControllerProvider).failure,
        isNull,
      );
      await controller.next();
      expect(
        container
            .read(communityScopedAssetsControllerProvider)
            .items
            .map((item) => item.sourceId),
        [for (var i = 0; i < 8; i++) 'new-$i'],
      );
    },
  );

  testWidgets('asset lists append on swipe and refresh without page controls', (
    tester,
  ) async {
    final community = _Community()
      ..pages.addAll([
        _page([
          for (var i = 0; i < 6; i++)
            testCommunity(communityId: 'community-$i'),
        ], cursor: 'more'),
        _page([
          for (var i = 6; i < 8; i++)
            testCommunity(communityId: 'community-$i'),
        ]),
        _page([testCommunity(communityId: 'fresh')]),
      ]);
    await pumpS5Page(
      tester,
      const ScopedAssetsScreen(scope: ScopedAssetsScope.community),
      size: const Size(390, 844),
      market: _Market(),
      overrides: [communityGatewayProvider.overrideWithValue(community)],
    );
    expect(find.text('上一页'), findsNothing);
    expect(find.text('下一页'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(community.reads, 2);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScopedAssetsScreen)),
    );
    expect(
      container.read(communityScopedAssetsControllerProvider).items.length,
      8,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('scoped-asset-community-7')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('scoped-asset-community-7')),
      findsOneWidget,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 450));
    await tester.pumpAndSettle();
    expect(community.reads, 3);
    expect(find.byKey(const ValueKey('scoped-asset-fresh')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('scoped-asset-community-0')),
      findsNothing,
    );
  });

  test(
    'continuing a partially filled page never skips the sixth source',
    () async {
      final community = _Community()
        ..pages.addAll([
          for (var i = 0; i < 4; i++)
            _page([
              testCommunity(communityId: 'community-$i'),
            ], cursor: 'cursor-$i'),
          _page([
            for (var i = 4; i < 8; i++)
              testCommunity(communityId: 'community-$i'),
          ]),
        ]);
      final container = ProviderContainer(
        overrides: [
          communityGatewayProvider.overrideWithValue(community),
          marketReadGatewayProvider.overrideWithValue(_Market()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(communityScopedAssetsControllerProvider, (_, _) {});
      final controller = container.read(
        communityScopedAssetsControllerProvider.notifier,
      );
      await controller.load();
      expect(
        container.read(communityScopedAssetsControllerProvider).items.length,
        4,
      );
      community.failNext = true;
      await controller.next();
      expect(
        container.read(communityScopedAssetsControllerProvider).failure,
        isNotNull,
      );
      expect(
        container
            .read(communityScopedAssetsControllerProvider)
            .continuationPending,
        isTrue,
      );
      await controller.next();
      expect(
        container
            .read(communityScopedAssetsControllerProvider)
            .items
            .map((e) => e.sourceId),
        [
          'community-0',
          'community-1',
          'community-2',
          'community-3',
          'community-4',
          'community-5',
        ],
      );
      await controller.next();
      expect(
        container
            .read(communityScopedAssetsControllerProvider)
            .items
            .map((e) => e.sourceId),
        [for (var i = 0; i < 8; i++) 'community-$i'],
      );
    },
  );
  testWidgets('community facts render and open only their exact asset', (
    tester,
  ) async {
    final community = _Community()
      ..pages.add(_page([testCommunity(boundAssetKey: s5WbnbAssetId)]));
    final destinations = <String>[];
    await pumpS5Page(
      tester,
      ScopedAssetsScreen(
        scope: ScopedAssetsScope.community,
        onNavigate: destinations.add,
      ),
      market: _Market(),
      overrides: [communityGatewayProvider.overrideWithValue(community)],
    );
    expect(find.text('WBNB'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('scoped-asset-$testCommunityId')),
    );
    expect(destinations, [
      '/market/token?assetId=eip155%3A56%3A0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
    ]);
  });

  test(
    'testnet platform identity stays on its chain without market fallback',
    () async {
      final launch = _Launch()
        ..overview = s7Overview(
          awaitingSchedule: [s7LaunchSummary(chainId: 'eip155:97')],
        )
        ..details[s7LaunchId] = s83cDetail(chainId: 'eip155:97');
      final market = _Market();
      final container = ProviderContainer(
        overrides: [
          launchGatewayProvider.overrideWithValue(launch),
          marketReadGatewayProvider.overrideWithValue(market),
        ],
      );
      addTearDown(container.dispose);
      container.listen(platformScopedAssetsControllerProvider, (_, _) {});
      await container
          .read(platformScopedAssetsControllerProvider.notifier)
          .load();
      expect(
        container
            .read(platformScopedAssetsControllerProvider)
            .items
            .single
            .assetId,
        'eip155:97:0x3333333333333333333333333333333333333333',
      );
      expect(market.requested, isEmpty);
    },
  );

  test(
    'bounded empty directory scan remains unknown until continuation ends',
    () async {
      final community = _Community()
        ..pages.addAll([
          for (var i = 0; i < 4; i++) _page([], cursor: 'cursor-$i'),
          _page([testCommunity(boundAssetKey: s5WbnbAssetId)]),
        ]);
      final container = ProviderContainer(
        overrides: [
          communityGatewayProvider.overrideWithValue(community),
          marketReadGatewayProvider.overrideWithValue(_Market()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(communityScopedAssetsControllerProvider, (_, _) {});
      final controller = container.read(
        communityScopedAssetsControllerProvider.notifier,
      );
      await controller.load();
      final partial = container.read(communityScopedAssetsControllerProvider);
      expect(partial.items, isEmpty);
      expect(partial.continuationPending, isTrue);
      expect(partial.hasNext, isTrue);
      await controller.next();
      expect(
        container
            .read(communityScopedAssetsControllerProvider)
            .items
            .single
            .detail
            ?.assetId,
        s5WbnbAssetId,
      );
      expect(container.read(communityScopedAssetsControllerProvider).page, 0);
    },
  );
  test(
    'platform identity comes from projectToken rather than sale contract',
    () async {
      final launch = _Launch()..details[s7LaunchId] = s83cDetail();
      final market = _Market();
      final container = ProviderContainer(
        overrides: [
          launchGatewayProvider.overrideWithValue(launch),
          marketReadGatewayProvider.overrideWithValue(market),
        ],
      );
      addTearDown(container.dispose);
      container.listen(platformScopedAssetsControllerProvider, (_, _) {});
      await container
          .read(platformScopedAssetsControllerProvider.notifier)
          .load();
      final row = container
          .read(platformScopedAssetsControllerProvider)
          .items
          .single;
      expect(
        row.assetId,
        'eip155:56:0x3333333333333333333333333333333333333333',
      );
      expect(market.requested, [
        'eip155:56:0x3333333333333333333333333333333333333333',
      ]);
      // A market answer for another identity must not render its price.
      expect(row.detail, isNull);
    },
  );

  test(
    'unconfirmed configuration never becomes a ticker inferred asset',
    () async {
      final market = _Market();
      final container = ProviderContainer(
        overrides: [
          launchGatewayProvider.overrideWithValue(_Launch()),
          marketReadGatewayProvider.overrideWithValue(market),
        ],
      );
      addTearDown(container.dispose);
      container.listen(platformScopedAssetsControllerProvider, (_, _) {});
      await container
          .read(platformScopedAssetsControllerProvider.notifier)
          .load();
      expect(market.requested, isEmpty);
      expect(
        container
            .read(platformScopedAssetsControllerProvider)
            .items
            .single
            .assetId,
        isNull,
      );
    },
  );

  test('six source records per page and exact community binding', () async {
    final community = _Community()
      ..pages.add(
        _page([
          for (var i = 0; i < 8; i++)
            testCommunity(
              communityId: 'community-$i',
              boundAssetKey: i == 0 ? s5WbnbAssetId : null,
            ),
        ]),
      );
    final market = _Market();
    final container = ProviderContainer(
      overrides: [
        communityGatewayProvider.overrideWithValue(community),
        marketReadGatewayProvider.overrideWithValue(market),
      ],
    );
    addTearDown(container.dispose);
    container.listen(communityScopedAssetsControllerProvider, (_, _) {});
    final controller = container.read(
      communityScopedAssetsControllerProvider.notifier,
    );
    await controller.load();
    expect(
      container.read(communityScopedAssetsControllerProvider).items.length,
      6,
    );
    expect(
      container
          .read(communityScopedAssetsControllerProvider)
          .items
          .first
          .detail
          ?.assetId,
      s5WbnbAssetId,
    );
    await controller.next();
    expect(
      container.read(communityScopedAssetsControllerProvider).items.length,
      8,
    );
    expect(market.requested, [s5WbnbAssetId]);
  });

  test('owner rotation discards pending market facts', () async {
    final owner = StateProvider<String?>((ref) => 'owner-a');
    final community = _Community()
      ..pages.add(_page([testCommunity(boundAssetKey: s5WbnbAssetId)]));
    final market = _Market()..pending = Completer<MarketAssetDetail>();
    final container = ProviderContainer(
      overrides: [
        communityGatewayProvider.overrideWithValue(community),
        marketReadGatewayProvider.overrideWithValue(market),
        loopAccountScopeProvider.overrideWith((ref) => ref.watch(owner)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(communityScopedAssetsControllerProvider, (_, _) {});
    final operation = container
        .read(communityScopedAssetsControllerProvider.notifier)
        .load();
    await Future<void>.delayed(Duration.zero);
    container.read(owner.notifier).state = 'owner-b';
    expect(
      container.read(communityScopedAssetsControllerProvider).items,
      isEmpty,
    );
    market.pending!.complete(s5Detail());
    await operation;
    expect(
      container.read(communityScopedAssetsControllerProvider).items,
      isEmpty,
    );
  });
}
