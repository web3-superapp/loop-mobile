// S265 · 氛围层铺到四个 Tab + MEME 为第一个页面 (client decision 0221): each
// of 聊天 / 广场 / 情报 / 钱包 stands on its own still wall with the crown
// behind its title; 我的名次 and 总资产 are chrome plates; the first three
// faces wear crowns; a community with no logo wears the chrome medal; the
// App lands on MEME and every other tab's back returns there.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/features/square/square_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show Channel, Level, PagedValue, StreamChatClient;

import 'support/authenticated_test_privy_gateway.dart';
import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

// ---- the App ----------------------------------------------------------------

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
          const _EmptySpotMarketRepository(),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(LoopTabBar)));
}

final class _EmptySpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  const _EmptySpotMarketRepository();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async =>
      HyperliquidSpotSnapshot(
        receivedAt: DateTime.utc(2026, 9, 2),
        markets: const <HyperliquidSpotMarket>[],
      );
}

String _location(GoRouter router) =>
    router.routeInformationProvider.value.uri.path;

PopScope<dynamic> _shellScope(WidgetTester tester) =>
    tester.widget<PopScope<dynamic>>(
      find
          .ancestor(
            of: find.byType(LoopTabBar),
            matching: find.byWidgetPredicate((widget) => widget is PopScope),
          )
          .first,
    );

// ---- 情报 -------------------------------------------------------------------

const _powers = <String>['12960', '8420', '6115', '4870', '3210', '2045'];

MiningRank _boards(MiningRankScope scope) => s7MiningRank(
  scope: scope,
  ranking: switch (scope) {
    MiningRankScope.referrals => const MiningRankingReferrals(
      items: <MiningRankReferralRow>[
        MiningRankReferralRow(
          position: 1,
          invitedCount: 12,
          display: MiningRankAlias(
            alias: 'inviter',
            publicProfileId: s7PublicProfileId,
            audience: MiningRankAudience.everyone,
          ),
          isSelf: false,
        ),
        MiningRankReferralRow(
          position: 2,
          invitedCount: 8,
          display: MiningRankAnonymous('mining.rank.anonymousMember'),
          isSelf: false,
        ),
      ],
      participants: 40,
      ruleKey: 'mining.rank.referrals.directActiveEdges',
    ),
    _ => MiningRankingCommunities(
      items: <MiningRankCommunityRow>[
        for (var index = 0; index < 30; index += 1)
          MiningRankCommunityRow(
            position: index + 1,
            power: _powers[index % _powers.length],
            community: MiningCommunityRef(
              communityId: 'community-${index + 1}',
              name: '社区${index + 1}',
              boundAssetId: s7CakeAssetId,
            ),
            weight: '1.0',
            participants: 30 - index,
          ),
      ],
      participants: 150,
    ),
  },
  me: const MiningRankMe(rank: 12, value: '1240', communityId: 'mine'),
  snapshot: s7MiningSnapshot(),
);

final class _BoardMining implements MiningGateway {
  _BoardMining();

  final FakeMiningGateway _inner = FakeMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) =>
      Future<MiningRank>.value(_boards(scope));

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

  group('C · MEME is the first page', () {
    testWidgets('the App lands on /meme and the tab order is unchanged', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      expect(LoopRouteManifest.defaultPath, '/meme');
      expect(_location(router), '/meme');
      expect(find.byType(MemeScreen), findsOneWidget);
      expect(LoopShell.destinationLabels, <String>[
        '聊天',
        '广场',
        'MEME',
        '情报',
        '钱包',
      ]);
      expect(LoopShell.homeIndex, 2);
      // `/`, `/home` and an illegal location all land on MEME.
      for (final location in <String>['/', '/home', '/no-such-page']) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(_location(router), '/meme', reason: location);
      }
    });

    testWidgets('back on 聊天 / 广场 / 情报 / 钱包 returns to MEME; only MEME '
        'lets the App go', (tester) async {
      final router = await _pumpApp(tester);
      expect(_shellScope(tester).canPop, isTrue);
      for (final (label, path) in <(String, String)>[
        ('聊天', '/chat'),
        ('广场', '/square'),
        ('情报', '/intel'),
        ('钱包', '/wallet'),
      ]) {
        await tester.tap(find.widgetWithText(LoopTabItem, label));
        await tester.pumpAndSettle();
        expect(_location(router), path);
        expect(_shellScope(tester).canPop, isFalse, reason: label);
        final handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(handled, isTrue, reason: label);
        expect(_location(router), '/meme', reason: label);
        expect(find.byType(LoopTabBar), findsOneWidget);
      }
    });
  });

  group('B · each tab stands on its own wall', () {
    testWidgets('聊天 / 广场 / 情报 / 钱包: the wall, the crown, no loop', (
      tester,
    ) async {
      await _pumpApp(tester);
      for (final (label, prefix) in <(String, String)>[
        ('聊天', 'chat'),
        ('广场', 'square'),
        ('情报', 'intel'),
        ('钱包', 'wallet'),
      ]) {
        await tester.tap(find.widgetWithText(LoopTabItem, label));
        await tester.pumpAndSettle();
        expect(_key('$prefix-atmo-backdrop'), findsWidgets, reason: label);
        expect(_key('$prefix-atmo-wall'), findsWidgets, reason: label);
        expect(_key('$prefix-atmo-title-crown'), findsOneWidget, reason: label);
        final backdrop = tester.widget<LoopWallBackdrop>(
          _key('$prefix-atmo-backdrop').first,
        );
        expect(backdrop.fog.name, prefix, reason: label);
        // Nothing on these pages loops: a settled pump has nothing left.
        expect(tester.binding.hasScheduledFrame, isFalse, reason: label);
      }
      // 聊天's chosen filter chip wears MEME's splat.
      await tester.tap(find.widgetWithText(LoopTabItem, '聊天'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('chat-inbox-filters'),
          matching: _key('loop-seg-splat'),
        ),
        findsOneWidget,
      );
      // The five walls are not one copy.
      expect(
        LoopWallFog.values.map((fog) => fog.spots.first.left).toSet().length +
            LoopWallFog.values
                .map((fog) => fog.spots.first.right)
                .toSet()
                .length,
        greaterThan(2),
      );
    });

    testWidgets('情报: the wall stays while the board scrolls; 我的名次 is a '
        'chrome plate with a Yellow place; the first three wear crowns', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelScreen(onNavigate: (_) {}),
        mining: _BoardMining(),
        size: const Size(390, 844),
      );
      expect(_key('intel-atmo-backdrop'), findsOneWidget);
      final wall = tester.getRect(_key('intel-atmo-backdrop'));

      // 我的名次: the chrome edge around the dark card face.
      final plate = find.descendant(
        of: _key('intel-rank-me'),
        matching: find.byType(LoopChromePlate),
      );
      expect(plate, findsOneWidget);
      final edge = tester.widget<DecoratedBox>(
        find.descendant(of: plate, matching: _key('loop-chrome-plate-edge')),
      );
      final gradient =
          (edge.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, contains(LoopColors.chrome1));
      expect(gradient.colors, contains(LoopColors.chrome3));
      final face = tester.widget<DecoratedBox>(
        find.descendant(of: plate, matching: _key('loop-chrome-plate-face')),
      );
      expect((face.decoration as BoxDecoration).color, LoopColors.card);
      final place = tester.widget<Text>(
        find.descendant(of: plate, matching: find.byType(Text)).at(1),
      );
      final spans = <TextSpan>[];
      place.textSpan!.visitChildren((span) {
        if (span is TextSpan && span.text == '第 12 名') spans.add(span);
        return true;
      });
      expect(spans.single.style?.color, LoopColors.yellow);
      expect(spans.single.style?.fontSize, 32);
      expect(spans.single.style?.fontWeight, FontWeight.w700);

      // The podium: a Yellow crown on the first, chrome-grey on 2 and 3.
      for (final place in <int>[1, 2, 3]) {
        final crown = tester.widget<LoopRankCrown>(
          _key('intel-rank-crown-$place'),
        );
        expect(crown.place, place);
        final face = tester.getRect(_key('intel-rank-face-$place'));
        final at = tester.getRect(_key('intel-rank-crown-$place'));
        // Pressed onto the face's top-right corner.
        expect(at.overlaps(face), isTrue, reason: '$place');
        expect(at.center.dx, greaterThan(face.center.dx), reason: '$place');
      }
      expect(
        find.descendant(
          of: _key('intel-rank-crown-1'),
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _key('intel-rank-crown-2'),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );

      // The wall does not scroll with the board.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.getRect(_key('intel-atmo-backdrop')), wall);
    });

    testWidgets('广场: rows on one card board, no-logo communities wear the '
        'chrome medal, the pinned chips paint the wall', (tester) async {
      await pumpCommunityPage(
        tester,
        SquareScreen(onOpenCommunity: (_) {}, onOpenVoiceRoom: (_) {}),
        community: FakeCommunityGateway(
          directoryPage: CommunityDirectoryPage(
            items: <CommunitySummary>[
              for (var index = 0; index < 12; index += 1)
                testCommunity(
                  communityId:
                      '4b96a75e-6828-4a6b-8c1d-${index.toString().padLeft(12, '0')}',
                  name: '社区 $index',
                ),
            ],
            nextCursor: null,
            recommendation: const CommunityRecommendation(
              recommendationId: '22222222-2222-4222-8222-222222222222',
              ruleVersion: 'rule:verified-members-v1',
            ),
            ordering: const CommunityOrderingApplied(
              sort: CommunityDirectorySort.members,
              basis: CommunityStoredBasis(),
            ),
          ),
        ),
      );
      // The page's wall, and the same wall cut to the pinned chips' box.
      expect(_key('square-atmo-backdrop'), findsNWidgets(2));
      expect(_key('square-atmo-title-crown'), findsOneWidget);
      final board = _key('square-community-board');
      expect(board, findsOneWidget);
      final first = '4b96a75e-6828-4a6b-8c1d-${0.toString().padLeft(12, '0')}';
      expect(
        find.descendant(of: board, matching: _key('square-community-$first')),
        findsOneWidget,
      );
      // No logo: the chrome medal, not a letter tile.
      expect(_key('community-logo-chrome-$first'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('square-community-$first'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'community-logo-monogram-',
                ),
          ),
        ),
        findsNothing,
      );
      // 「已验证」 is unchanged.
      expect(_key('square-community-verification-$first'), findsOneWidget);
      // The pinned chips stand on the same wall, cut to their box.
      expect(_key('loop-backdrop-slice'), findsOneWidget);
      final wall = tester.getRect(_key('square-atmo-backdrop').first);
      await tester.drag(_key('square-community-scroll'), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.getRect(_key('square-atmo-backdrop').first), wall);
      expect(_key('loop-backdrop-slice'), findsOneWidget);
    });

    testWidgets('钱包: 总资产 is a chrome plate with a Yellow figure; the '
        'chosen asset tab wears the splat', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );
      expect(_key('wallet-atmo-backdrop'), findsWidgets);
      expect(_key('wallet-atmo-title-crown'), findsOneWidget);
      final plate = _key('wallet-total-plate');
      expect(plate, findsOneWidget);
      expect(
        find.descendant(of: plate, matching: _key('wallet-total-figure')),
        findsOneWidget,
      );
      final figure = tester.widget<Text>(_key('wallet-total-figure'));
      expect(figure.style?.color, LoopColors.yellow);
      expect(figure.style?.fontSize, 32);
      final face = tester.widget<DecoratedBox>(
        find.descendant(of: plate, matching: _key('loop-chrome-plate-face')),
      );
      expect((face.decoration as BoxDecoration).color, LoopColors.card);
      expect(
        find.descendant(
          of: _key('wallet-asset-tab-tokens'),
          matching: _key('loop-seg-splat'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('wallet-asset-tab-nft'),
          matching: _key('loop-seg-splat'),
        ),
        findsNothing,
      );
      // The wall does not scroll with the page.
      final wall = tester.getRect(_key('wallet-atmo-backdrop').first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getRect(_key('wallet-atmo-backdrop').first), wall);
    });
  });

  group('B · 聊天 empty states', () {
    late StreamChatClient client;
    setUp(() {
      client = StreamChatClient('public-stream-api-key', logLevel: Level.OFF);
    });
    tearDown(() => client.dispose());

    const hex = '0123456789abcdef0123456789abcdef';

    testWidgets('a filter with nothing left: the grey crown, one sentence and '
        'a Yellow action', (tester) async {
      final value = ValueNotifier<PagedValue<int, Channel>>(
        PagedValue<int, Channel>(
          items: <Channel>[Channel(client, 'messaging', 'loop_direct_$hex')],
        ),
      );
      addTearDown(value.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: ChatInboxFilterEmptyGate(
              controller: value,
              filter: ChatInboxFilter.communities,
              child: const Text('channel-list'),
            ),
          ),
        ),
      );
      final empty = _key('chat-inbox-filter-empty-communities');
      expect(empty, findsOneWidget);
      expect(tester.widget(empty), isA<LoopAtmoEmpty>());
      expect(
        find.descendant(of: empty, matching: find.byType(ColorFiltered)),
        findsOneWidget,
      );
      expect(find.text('还没有社区会话'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('chat-inbox-filter-empty-action-communities'),
          matching: find.text('去广场看看'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget(_key('chat-inbox-filter-empty-action-communities')),
        isA<LoopYellowButton>(),
      );
    });
  });
}
