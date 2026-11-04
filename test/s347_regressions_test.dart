import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/profile/profile_destinations.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/loop_ground_probe.dart';

// S347 · docs/57 §三: the regressions the page slimming left behind.

// ---------------------------------------------------------------------------
// N1 / N2 · a tab is switched to, never pushed over the shell
// ---------------------------------------------------------------------------

final class _EmptySpot implements HyperliquidSpotMarketRepository {
  const _EmptySpot();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async =>
      HyperliquidSpotSnapshot(
        receivedAt: DateTime.utc(2026, 11, 3),
        markets: const <HyperliquidSpotMarket>[],
      );
}

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
          const _EmptySpot(),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(MemeScreen)));
}

String _location(GoRouter router) =>
    router.routeInformationProvider.value.uri.toString();

/// One user board whose fifth place is the reader.
final class _SelfBoard implements MiningGateway {
  final FakeMiningGateway _inner = FakeMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) =>
      Future<MiningRank>.value(
        s7MiningRank(
          scope: scope,
          snapshot: s7MiningSnapshot(),
          me: const MiningRankMe(rank: 5, value: '3020'),
          ranking: MiningRankingUsers(
            items: <MiningRankUserRow>[
              for (var index = 0; index < 8; index += 1)
                MiningRankUserRow(
                  position: index + 1,
                  power: '${3420 - index * 100}',
                  powerVisibility: MiningRankAudience.everyone,
                  display: MiningRankAlias(
                    alias: 'member${index + 1}',
                    publicProfileId:
                        '8c2b7a15-4d3e-4f60-9a11-'
                        '${(index + 1).toString().padLeft(12, '0')}',
                    audience: MiningRankAudience.everyone,
                  ),
                  isSelf: index == 4,
                ),
            ],
            participants: 40,
          ),
        ),
      );

  @override
  Future<MiningSummary> loadSummary() => _inner.loadSummary();

  @override
  Future<MiningAssets> loadAssets() => _inner.loadAssets();

  @override
  Future<MiningCommunity> loadCommunity(String communityId) =>
      _inner.loadCommunity(communityId);

  @override
  Future<MiningRules> loadRules() => _inner.loadRules();
}

void main() {
  loopWatchGround();

  group('N1 · 算力榜: the reader\'s own row opens 我的', () {
    testWidgets('the self row switches to the tab instead of pushing it', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/mining/rank',
        routes: <RouteBase>[
          GoRoute(path: '/mining/rank', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/wallet', builder: (_, _) => const SizedBox()),
        ],
      );
      addTearDown(router.dispose);
      final pushed = <String>[];
      await pumpS7Page(
        tester,
        InheritedGoRouter(
          goRouter: router,
          child: IntelRankBoard(onNavigate: pushed.add),
        ),
        mining: _SelfBoard(),
      );
      await tester.ensureVisible(find.text('User'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('User'));
      await tester.pumpAndSettle();
      final self = find.byKey(const ValueKey<String>('intel-rank-user-4'));
      await tester.ensureVisible(self);
      await tester.tap(self);
      await tester.pumpAndSettle();
      expect(pushed, isEmpty);
      expect(_location(router), loopOwnProfileLocation);
      // Somebody else's row still opens their page through the host.
      final other = find.byKey(const ValueKey<String>('intel-rank-user-3'));
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(pushed.single, startsWith('/profile/user'));
    });

    testWidgets('from /mining/rank, 我的 is reached without a crash', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      unawaited(router.push('/mining/rank'));
      await tester.pumpAndSettle();
      tester
          .widget<IntelRankBoard>(find.byType(IntelRankBoard))
          .onNavigate(loopOwnProfileLocation);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_location(router), '/wallet');
      expect(router.canPop(), isFalse);
    });

    testWidgets('from the board a community page opened, the same', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      unawaited(
        router.push(
          '/mining/community?id=8c2b7a15-4d3e-4f60-9a11-000000000001',
        ),
      );
      await tester.pumpAndSettle();
      unawaited(router.push('/mining/rank'));
      await tester.pumpAndSettle();
      final board = tester.widget<IntelRankBoard>(find.byType(IntelRankBoard));
      board.onNavigate(loopOwnProfileLocation);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_location(router), '/wallet');
      expect(router.canPop(), isFalse);
    });
  });

  group('N2 · a tab with a query is still a tab', () {
    testWidgets('我的 · 邀请好友 lands on 情报 · 算力 · 邀请', (tester) async {
      final router = await _pumpApp(tester);
      unawaited(router.push('/profile/settings'));
      await tester.pumpAndSettle();
      tester
          .widget<ProfileSurfaceScreen>(find.byType(ProfileSurfaceScreen))
          .onNavigate!('invite');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(profileDestinationPath('invite'), loopIntelInviteLocation);
      // 情报 takes the tab it was handed and keeps its own address.
      expect(router.routeInformationProvider.value.uri.path, '/intel');
      expect(router.canPop(), isFalse);
      expect(find.byType(IntelScreen), findsOneWidget);
    });
  });
}
