import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';
import 'package:loop_mobile/integrations/backend/v2/mining/loop_v2_mining_api.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// transport doubles
// ---------------------------------------------------------------------------

final class _Recorder implements HttpClientAdapter {
  _Recorder(this.body);

  final Object? body;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>['5b0f8a2e-6d1c-4e7a-9b3f-2c8d4e6f1a09'],
      },
    );
  }
}

Dio _dio(_Recorder adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;

Map<String, Object?> _categoryBody({
  String category = 'major',
  List<Object?>? items,
  String? nextCursor,
}) => <String, Object?>{
  'category': category,
  'sort': 'marketCap',
  'items':
      items ??
      <Object?>[
        <String, Object?>{
          'assetId': s5WbnbAssetId,
          'symbol': 'WBNB',
          'name': 'Wrapped BNB',
          'logoUrl': null,
          'quote': <String, Object?>{
            'priceUsd': '747.39',
            'change24hPct': '-1.01',
            'marketCapUsd': '1640000000',
            'volume24hUsd': '512345678.9',
            'observedAt': '2026-10-08T09:30:00.000Z',
            'source': 'dexscreener',
            'quality': 'fresh',
          },
          'sparkline': <String, Object?>{
            'status': 'unavailable',
            'reasonCode': 'MARKET_SPARKLINE_NOT_CACHED',
          },
        },
        <String, Object?>{
          'assetId': 'eip155:97:0x358d40a1a2b02d550c64e7a9b8dc599f8219d976',
          'symbol': 'LTPT',
          'name': 'Loop Test Project Token',
          'logoUrl': null,
          'quote': null,
          'quoteUnavailable': <String, Object?>{
            'reasonCode': 'MARKET_CHAIN_NOT_PRICED',
          },
          'sparkline': <String, Object?>{
            'status': 'unavailable',
            'reasonCode': 'MARKET_CHAIN_NOT_PRICED',
          },
        },
      ],
  'nextCursor': nextCursor,
  'rules': <String, Object?>{
    'configVersion': 'marketCategoriesV1',
    'effectiveAt': '2026-10-08T00:00:00.000Z',
    'ordering': 'dexscreener_market_cap_desc',
  },
  'observedAt': '2026-10-08T09:30:01.123Z',
  'contractVersion': '2.0',
};

Map<String, Object?> _promotion({
  String id = '5b0f8a2e-6d1c-4e7a-9b3f-2c8d4e6f1a01',
  String deeplink = '/intel',
  int order = 1,
}) => <String, Object?>{
  'id': id,
  'title': 'LOOP 挖矿算力周榜',
  'subtitle': '看看本周谁的算力最高',
  'imageUrl': null,
  'deeplink': deeplink,
  'startsAt': '2026-10-08T00:00:00.000Z',
  'endsAt': '2027-01-01T00:00:00.000Z',
  'order': order,
};

// ---------------------------------------------------------------------------
// page doubles
// ---------------------------------------------------------------------------

/// A mining port whose board is read a page at a time.
final class _PagedMining implements MiningGateway {
  _PagedMining({required this.first, this.pages = const {}});

  final MiningRank Function(MiningRankScope scope) first;
  final Map<String, MiningRank> pages;
  final List<(MiningRankScope, String?)> reads = <(MiningRankScope, String?)>[];
  final FakeMiningGateway _inner = FakeMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) {
    reads.add((scope, cursor));
    if (cursor != null) {
      final page = pages[cursor];
      if (page != null) return Future<MiningRank>.value(page);
    }
    return Future<MiningRank>.value(first(scope));
  }

  @override
  Future<MiningSummary> loadSummary() => _inner.loadSummary();

  @override
  Future<MiningAssets> loadAssets() => _inner.loadAssets();

  @override
  Future<MiningRewards> loadRewards() => _inner.loadRewards();

  @override
  Future<MiningCommunity> loadCommunity(String communityId) =>
      _inner.loadCommunity(communityId);

  @override
  Future<MiningRules> loadRules() => _inner.loadRules();
}

MiningRankingUsers _users(int from, int count) => MiningRankingUsers(
  items: <MiningRankUserRow>[
    for (var index = 0; index < count; index += 1)
      MiningRankUserRow(
        position: from + index,
        power: '${1000 - from - index}',
        powerVisibility: MiningRankAudience.everyone,
        display: MiningRankAlias(
          alias: 'member${from + index}',
          publicProfileId:
              '8c2b7a15-4d3e-4f60-9a11-${(from + index).toString().padLeft(12, '0')}',
          audience: MiningRankAudience.everyone,
          avatarRef: 'avatar:preset/people-01',
        ),
        isSelf: false,
      ),
  ],
  participants: 60,
);

const _referrals = MiningRankingReferrals(
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
      invitedCount: 5,
      display: MiningRankAnonymous('mining.rank.anonymousMember'),
      isSelf: false,
    ),
  ],
  participants: 2,
  ruleKey: 'mining.rank.referrals.directActiveEdges',
);

List<LoopCandle> _candles(int count) => <LoopCandle>[
  for (var index = 0; index < count; index += 1)
    LoopCandle(
      openTime: DateTime.utc(2026, 10, 1).add(Duration(hours: index)),
      closeTime: DateTime.utc(2026, 10, 1).add(Duration(hours: index + 1)),
      open: Decimal.parse('${100 + index % 7}'),
      high: Decimal.parse('${110 + index % 7}'),
      low: Decimal.parse('${95 + index % 7}'),
      close: Decimal.parse('${101 + (index * 3) % 11}'),
      volume: Decimal.parse('${10 + index % 5}'),
      swapCount: 3,
      isOpen: index == count - 1,
    ),
];

Future<void> _pumpChart(
  WidgetTester tester,
  List<LoopCandle> candles, {
  LoopChartStyle style = LoopChartStyle.line,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(
        backgroundColor: LoopColors.ink,
        body: Column(
          children: <Widget>[
            LoopMarketChart(
              candles: candles,
              interval: LoopCandleInterval.oneHour,
              semanticLabel: 'chart',
              style: style,
              height: 300,
            ),
          ],
        ),
      ),
    ),
  );
}

LoopMarketChartState _chart(WidgetTester tester) =>
    tester.state<LoopMarketChartState>(find.byType(LoopMarketChart));

Finder _key(String key) => find.byKey(ValueKey<String>(key));

void main() {
  loopWatchGround();

  // -------------------------------------------------------------------------
  group('codec · 情报 categories and promotions (decision 0100)', () {
    test(
      'a first page names category and sort, a continuation never limit',
      () async {
        final adapter = _Recorder(_categoryBody(nextCursor: 'abc.def'));
        final api = DioLoopV2MarketApi(_dio(adapter));
        final page = await api.getCategory(
          accessToken: 't',
          clientVersion: '1.0.0',
          category: MarketCategory.major,
          sort: MarketCategorySort.marketCap,
        );
        expect(adapter.requests.single.path, '/v2/market/assets');
        expect(adapter.requests.single.queryParameters, <String, Object?>{
          'category': 'major',
          'sort': 'marketCap',
        });
        expect(page.nextCursor, 'abc.def');
        expect(page.items.first.quote!.priceUsd, Decimal.parse('747.39'));
        // A testnet token arrives with its reason, never as a zero.
        expect(page.items.last.quote, isNull);
        expect(
          page.items.last.quoteUnavailableReason,
          'MARKET_CHAIN_NOT_PRICED',
        );

        await api.getCategory(
          accessToken: 't',
          clientVersion: '1.0.0',
          category: MarketCategory.major,
          sort: MarketCategorySort.marketCap,
          cursor: 'abc.def',
        );
        expect(adapter.requests.last.queryParameters, <String, Object?>{
          'category': 'major',
          'sort': 'marketCap',
          'cursor': 'abc.def',
        });
        expect(
          () => api.getCategory(
            accessToken: 't',
            clientVersion: '1.0.0',
            category: MarketCategory.major,
            sort: MarketCategorySort.marketCap,
            cursor: 'abc.def',
            limit: 30,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      },
    );

    test('a community row must name its community, others must not', () {
      expect(
        () => DioLoopV2MarketApi.decodeCategory(
          _categoryBody(category: 'community'),
          category: MarketCategory.community,
          sort: MarketCategorySort.marketCap,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => DioLoopV2MarketApi.decodeCategory(
          _categoryBody(category: 'meme'),
          category: MarketCategory.major,
          sort: MarketCategorySort.marketCap,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('promotions keep in-app links only and come back in order', () {
      final decoded = DioLoopV2MarketApi.decodePromotions(<String, Object?>{
        'items': <Object?>[
          _promotion(
            id: '5b0f8a2e-6d1c-4e7a-9b3f-2c8d4e6f1a02',
            deeplink: '/square',
            order: 2,
          ),
          _promotion(),
        ],
        'configVersion': 'intelPromotionsV1',
        'effectiveAt': '2026-10-08T00:00:00.000Z',
        'contractVersion': '2.0',
      });
      expect(decoded.items.map((item) => item.deeplink), <String>[
        '/intel',
        '/square',
      ]);
      expect(
        () => DioLoopV2MarketApi.decodePromotions(<String, Object?>{
          'items': <Object?>[_promotion(deeplink: 'https://evil.example')],
          'configVersion': 'intelPromotionsV1',
          'effectiveAt': '2026-10-08T00:00:00.000Z',
          'contractVersion': '2.0',
        }),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      'the 推广 board decodes with the reader\'s place and a cursor',
      () async {
        final adapter = _Recorder(<String, Object?>{
          'scope': 'referrals',
          'ranking': <String, Object?>{
            'status': 'available',
            'scope': 'referrals',
            'items': <Object?>[
              <String, Object?>{
                'position': 1,
                'invitedCount': 12,
                'display': <String, Object?>{
                  'kind': 'alias',
                  'alias': 'inviter',
                  'publicProfileId': s7PublicProfileId,
                  'audience': 'everyone',
                  'avatarRef': 'avatar:preset/people-03',
                },
                'isSelf': false,
              },
            ],
            'participants': 1,
            'ruleKey': 'mining.rank.referrals.directActiveEdges',
          },
          'myPosition': <String, Object?>{
            'status': 'unavailable',
            'reasonCode': 'MINING_RANK_NOT_APPLICABLE',
          },
          'me': <String, Object?>{'rank': 3, 'value': '5'},
          'nextCursor': 'next.page',
          'snapshot': <String, Object?>{
            'status': 'unavailable',
            'reasonCode': 'MINING_SNAPSHOT_NOT_AVAILABLE',
          },
          'display': <String, Object?>{
            'anonymousMemberKey': 'mining.rank.anonymousMember',
            'ruleKey': 'mining.rank.display.anonymousModeOnly',
            'powerRuleKey': 'mining.rank.power.ownerVisibility',
          },
          'formula': <String, Object?>{
            'status': 'unavailable',
            'reasonCode': 'MINING_FORMULA_BASELINE_PENDING',
            'pendingVersion': null,
          },
          'contractVersion': '2.0',
        });
        final api = DioLoopV2MiningApi(_dio(adapter));
        final rank = await api.getRank(
          accessToken: 't',
          clientVersion: '1.0.0',
          scope: MiningRankScope.referrals,
          cursor: 'prev.page',
        );
        expect(adapter.requests.single.queryParameters, <String, Object?>{
          'scope': 'referrals',
          'cursor': 'prev.page',
        });
        expect(rank.me!.rank, 3);
        expect(rank.me!.value, '5');
        expect(rank.nextCursor, 'next.page');
        final board = rank.ranking as MiningRankingReferrals;
        expect(board.items.single.invitedCount, 12);
        expect(
          (board.items.single.display as MiningRankAlias).avatarRef,
          'avatar:preset/people-03',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  group('情报 · 行情 list', () {
    testWidgets('the chips are 自选 / 主流 / MEME / 社区代币 and 主流 reads major', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        categories: <MarketCategory, S5Answer<MarketCategoryPage>>{
          MarketCategory.major: S5Answer<MarketCategoryPage>(
            value: s5CategoryPage(
              items: <MarketCategoryRow>[
                s5CategoryRow(),
                s5CategoryRow(
                  assetId: s5UsdtAssetId,
                  symbol: 'LTPT',
                  price: null,
                ),
              ],
            ),
          ),
        },
      );
      await pumpS5Page(
        tester,
        const MarketScreen(embedded: true),
        market: market,
      );
      for (final label in <String>['自选', '主流', 'MEME', '社区代币']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // 新币 and 聪明钱 are hidden by the switch (decision 0118).
      expect(find.text('新币'), findsNothing);
      expect(_key('market-smart-money-entry'), findsNothing);

      await tester.tap(find.text('主流'));
      await tester.pumpAndSettle();
      expect(market.categoryRequests.first, (
        MarketCategory.major,
        MarketCategorySort.marketCap,
        null,
      ));
      final row = _key('market-asset-$s5WbnbAssetId');
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, marketFomoRowHeight);
      expect(find.text('WBNB'), findsWidgets);
      expect(find.text('市值 \$1.6B'), findsOneWidget);
      expect(find.text('\$747.39'), findsOneWidget);
      expect(find.text('▲ 2.50%'), findsOneWidget);
      // The unpriced row says why, inline, and prints no price.
      final unpriced = _key('market-asset-$s5UsdtAssetId');
      expect(
        find.descendant(of: unpriced, matching: find.text('测试网代币不报价')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: unpriced,
          matching: find.byType(LoopInlineUnavailable),
        ),
        findsOneWidget,
      );
      // The old chrome is gone.
      expect(_key('market-truth-notice'), findsNothing);
      expect(_key('market-stats'), findsNothing);
      expect(_key('market-trending-rules'), findsNothing);
      expect(_key('market-list-provenance'), findsOneWidget);
    });

    testWidgets('a list reads its next page as it scrolls and then ends', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        categories: <MarketCategory, S5Answer<MarketCategoryPage>>{
          MarketCategory.meme: S5Answer<MarketCategoryPage>(
            value: s5CategoryPage(
              category: MarketCategory.meme,
              nextCursor: 'page.two',
            ),
          ),
        },
        categoryPages: <String, S5Answer<MarketCategoryPage>>{
          'page.two': S5Answer<MarketCategoryPage>(
            value: s5CategoryPage(
              category: MarketCategory.meme,
              items: <MarketCategoryRow>[
                s5CategoryRow(assetId: s5UsdtAssetId, symbol: 'MEME2'),
              ],
            ),
          ),
        },
      );
      await pumpS5Page(
        tester,
        const MarketScreen(embedded: true),
        market: market,
      );
      await tester.tap(find.text('MEME'));
      await tester.pumpAndSettle();
      expect(market.categoryRequests.map((request) => request.$3), <String?>[
        null,
        'page.two',
      ]);
      expect(find.text('MEME2'), findsOneWidget);
      expect(_key('market-list-end'), findsOneWidget);
      expect(find.text('没有更多'), findsOneWidget);
    });

    testWidgets('an empty 自选 sends the reader to 主流', (tester) async {
      final market = FakeMarketReadGateway(
        overview: S5Answer<MarketOverview>(
          value: s5Overview(
            watchlist: MarketWatchlistAvailable(
              version: 1,
              items: const <MarketAssetRow>[],
            ),
          ),
        ),
      );
      await pumpS5Page(
        tester,
        const MarketScreen(embedded: true),
        market: market,
      );
      expect(find.text('还没有自选'), findsOneWidget);
      await tester.tap(_key('market-watchlist-browse-major'));
      await tester.pumpAndSettle();
      expect(market.categoryRequests.single.$1, MarketCategory.major);
    });

    testWidgets('管理自选 opens the Watchlist editor, not the alerts page', (
      tester,
    ) async {
      final routes = <String>[];
      await pumpS5Page(
        tester,
        MarketScreen(embedded: true, onNavigate: routes.add),
        market: FakeMarketReadGateway(),
      );
      await tester.tap(_key('market-watchlist-manage'));
      await tester.pumpAndSettle();
      expect(routes, <String>['/market/watchlist']);
    });

    testWidgets('the promotion strip shows its cards and opens their link', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpS5Page(
        tester,
        MarketScreen(embedded: true, onOpenPromotion: opened.add),
        market: FakeMarketReadGateway(
          promotions: S5Answer<IntelPromotions>(
            value: IntelPromotions(
              items: <IntelPromotion>[
                IntelPromotion(
                  id: '5b0f8a2e-6d1c-4e7a-9b3f-2c8d4e6f1a02',
                  title: '推荐社区',
                  subtitle: '发现正在活跃的社区',
                  imageUrl: null,
                  deeplink: '/square',
                  startsAt: DateTime.utc(2026, 10, 8),
                  endsAt: DateTime.utc(2027),
                  order: 2,
                ),
              ],
              configVersion: 'intelPromotionsV1',
              effectiveAt: DateTime.utc(2026, 10, 8),
            ),
          ),
        ),
      );
      expect(_key('intel-promotions'), findsOneWidget);
      await tester.tap(find.text('推荐社区'));
      await tester.pumpAndSettle();
      expect(opened, <String>['/square']);
    });

    testWidgets('no running promotion draws no strip at all', (tester) async {
      await pumpS5Page(
        tester,
        const MarketScreen(embedded: true),
        market: FakeMarketReadGateway(),
      );
      expect(_key('intel-promotions'), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('intel-promotions-hidden'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('the switch brings 新币 and 聪明钱 back when it is on', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
        overrides: [
          loopFeatureSwitchesProvider.overrideWithValue(
            const LoopFeatureSwitchValues(outboundMarketListsVisible: true),
          ),
        ],
      );
      expect(find.text('新币'), findsOneWidget);
      expect(_key('market-smart-money-entry'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('情报 · 算力榜', () {
    testWidgets('推广 is a real board, and 我的名次 is its own card', (tester) async {
      final mining = _PagedMining(
        first: (scope) => scope == MiningRankScope.referrals
            ? s7MiningRank(
                scope: scope,
                ranking: _referrals,
                me: const MiningRankMe(rank: 3, value: '5'),
              )
            : s7MiningRank(scope: scope),
      );
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: mining,
      );
      // No me: 还没有名次.
      expect(find.text('还没有名次'), findsOneWidget);
      await tester.tap(find.text('推广'));
      await tester.pumpAndSettle();
      expect(mining.reads.last, (MiningRankScope.referrals, null));
      expect(find.text('第 3 名'), findsOneWidget);
      expect(find.text('5 人'), findsOneWidget);
      expect(find.text('inviter'), findsOneWidget);
      // B7: an anonymous inviter stays anonymous.
      expect(find.text('匿名成员'), findsOneWidget);
      // The two explanation cards are now the one source line.
      expect(_key('mining-rank-anonymity'), findsNothing);
      expect(_key('mining-rank-notice'), findsNothing);
      expect(_key('intel-rank-provenance'), findsOneWidget);
      expect(find.text('没有更多'), findsOneWidget);
    });

    testWidgets('the user board reads on to its next page', (tester) async {
      final mining = _PagedMining(
        first: (scope) => scope == MiningRankScope.users
            ? s7MiningRank(
                scope: scope,
                ranking: _users(1, 30),
                nextCursor: 'users.two',
                me: const MiningRankMe(rank: 7, value: '993'),
              )
            : s7MiningRank(scope: scope),
        pages: <String, MiningRank>{
          'users.two': s7MiningRank(
            scope: MiningRankScope.users,
            ranking: _users(31, 5),
          ),
        },
      );
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: mining,
      );
      await tester.tap(find.text('用户'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('没有更多'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(mining.reads, contains((MiningRankScope.users, 'users.two')));
      expect(find.text('member35'), findsOneWidget);
      expect(find.text('第 7 名'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('token chart', () {
    testWidgets('it opens on the newest 60 buckets', (tester) async {
      await _pumpChart(tester, _candles(300));
      final viewport = _chart(tester).viewport;
      expect(viewport.visible, LoopChartViewport.defaultVisible);
      expect(viewport.endOffset, 0);
    });

    testWidgets('a horizontal drag moves the window into the past', (
      tester,
    ) async {
      await _pumpChart(tester, _candles(300));
      await tester.dragFrom(const Offset(200, 150), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(_chart(tester).viewport.endOffset, greaterThan(0));
      final moved = _chart(tester).viewport.endOffset;
      await tester.dragFrom(const Offset(200, 150), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(_chart(tester).viewport.endOffset, lessThan(moved));
    });

    testWidgets('the left 24pt answer no drag (edge-swipe back)', (
      tester,
    ) async {
      await _pumpChart(tester, _candles(300));
      await tester.dragFrom(const Offset(10, 150), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(_chart(tester).viewport.endOffset, 0);
    });

    testWidgets('a pinch zooms between 20 and 300 buckets', (tester) async {
      await _pumpChart(tester, _candles(300));
      Future<void> pinch(double from, double to) async {
        final left = await tester.startGesture(Offset(200 - from, 150));
        final right = await tester.startGesture(Offset(200 + from, 150));
        await tester.pump();
        for (var step = 1; step <= 6; step += 1) {
          final spread = from + (to - from) * step / 6;
          await left.moveTo(Offset(200 - spread, 150));
          await right.moveTo(Offset(200 + spread, 150));
          await tester.pump();
        }
        await left.up();
        await right.up();
        await tester.pumpAndSettle();
      }

      // Fingers apart: fewer, wider buckets, never below 20.
      await pinch(20, 160);
      expect(_chart(tester).viewport.visible, LoopChartViewport.minVisible);
      // Fingers together: more buckets, never above 300.
      await pinch(160, 4);
      await pinch(160, 4);
      expect(_chart(tester).viewport.visible, LoopChartViewport.maxVisible);
    });

    testWidgets('a long press draws the crosshair with price and time', (
      tester,
    ) async {
      await _pumpChart(tester, _candles(300));
      final gesture = await tester.startGesture(const Offset(200, 150));
      await tester.pump(const Duration(milliseconds: 700));
      expect(_chart(tester).crosshairIndex, isNotNull);
      expect(_key('loop-market-chart-crosshair-price'), findsOneWidget);
      expect(_key('loop-market-chart-crosshair-time'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_chart(tester).crosshairIndex, isNull);
    });

    testWidgets('the time axis carries four to six ticks', (tester) async {
      await _pumpChart(tester, _candles(300));
      final ticks = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'loop-market-chart-tick-',
            ),
      );
      expect(ticks.evaluate().length, inInclusiveRange(4, 6));
      for (final width in <double>[200, 320, 480, 900]) {
        final count = loopChartTimeTickIndices(
          LoopChartViewport.initial(300),
          width,
        ).length;
        expect(count, inInclusiveRange(4, 6), reason: '$width');
      }
    });

    test('the window never leaves the series', () {
      var viewport = LoopChartViewport.initial(300);
      viewport = viewport.panBy(10000);
      expect(viewport.endOffset, 240);
      viewport = viewport.panBy(-10000);
      expect(viewport.endOffset, 0);
      expect(viewport.zoomTo(5).visible, 20);
      expect(viewport.zoomTo(999).visible, 300);
      // A short series is shown whole.
      expect(LoopChartViewport.initial(12).visible, 12);
    });
  });

  // -------------------------------------------------------------------------
  group('token page', () {
    testWidgets('a line by default, K 线 on request, MA off and VOL on', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        candles: S5Answer<MarketCandleSeries>(
          value: s5Series(items: _candles(120)),
        ),
      );
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: market,
      );
      // One read of 300 buckets feeds the pan and the zoom.
      expect(market.candleLimits, everyElement(300));
      var chart = tester.widget<LoopMarketChart>(find.byType(LoopMarketChart));
      expect(chart.style, LoopChartStyle.line);
      expect(chart.showMovingAverages, isFalse);
      expect(chart.showVolume, isTrue);

      await tester.tap(_key('token-chart-style'));
      await tester.pumpAndSettle();
      chart = tester.widget<LoopMarketChart>(find.byType(LoopMarketChart));
      expect(chart.style, LoopChartStyle.candles);

      await tester.tap(_key('token-chart-ma'));
      await tester.tap(_key('token-chart-vol'));
      await tester.pumpAndSettle();
      chart = tester.widget<LoopMarketChart>(find.byType(LoopMarketChart));
      expect(chart.showMovingAverages, isTrue);
      expect(chart.showVolume, isFalse);

      // 15分 / 1时 / 4时 / 1日 / 1周.
      for (final label in <String>['15分', '1时', '4时', '1日', '1周']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.tap(find.text('4时'));
      await tester.pumpAndSettle();
      expect(market.intervals.last, LoopCandleInterval.fourHours);
    });

    testWidgets('持有者 / 动态 / 关于, and 动态 scrolls on to the end', (tester) async {
      MarketTradesPage page(String? next, int from) => MarketTradesPage(
        assetId: s5WbnbAssetId,
        trades: MarketTradesAvailable(
          source: LoopFactSource.loopIndexer,
          items: <MarketTrade>[
            for (var index = from; index < from + 3; index += 1)
              MarketTrade(
                transactionHash:
                    '0x${index.toRadixString(16).padLeft(64, '0')}',
                logIndex: 0,
                blockNumber: BigInt.from(100 + index),
                blockHash: '0x${'a' * 64}',
                blockTimestamp: DateTime.utc(2026, 10, 8, 9),
                confirmations: 12,
                status: LoopConfirmationStatus.confirmed,
                direction: index.isEven
                    ? MarketTradeDirection.buy
                    : MarketTradeDirection.sell,
                amountAsset: Decimal.parse('1.5'),
                amountQuote: Decimal.parse('${1000 + index}'),
                quoteAssetId: s5UsdtAssetId,
                quoteSymbol: 'USDT',
                priceAfter: null,
                poolAddress: s5PoolAddress,
                isOwn: false,
              ),
          ],
          nextCursor: next,
          freshness: LoopIndexerFreshness(
            indexerBlockNumber: BigInt.from(120640710),
            headBlockNumber: BigInt.from(120640743),
            lagBlocks: 33,
            observedAt: DateTime.utc(2026, 10, 8, 9, 31),
          ),
        ),
      );
      final market = FakeMarketReadGateway(
        trades: S5Answer<MarketTradesPage>(value: page('trades.two', 0)),
        tradePages: <String, S5Answer<MarketTradesPage>>{
          'trades.two': S5Answer<MarketTradesPage>(value: page(null, 3)),
        },
      );
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: market,
      );
      for (final label in <String>['持有者', '动态', '关于']) {
        expect(_key('token-tab-$label'), findsOneWidget, reason: label);
      }
      expect(_key('token-holders-distribution-unavailable'), findsOneWidget);

      await tester.tap(_key('token-tab-动态'));
      await tester.pumpAndSettle();
      expect(market.tradeCursors, <String?>[null, 'trades.two']);
      expect(find.text('买入'), findsWidgets);
      expect(find.text('卖出'), findsWidgets);
      expect(_key('token-trades-end'), findsOneWidget);

      await tester.tap(_key('token-tab-关于'));
      await tester.pumpAndSettle();
      expect(_key('token-pool-contract-facts'), findsOneWidget);
      expect(_key('token-swap-unavailable'), findsOneWidget);
      // The page's own explanation card is gone; the source line stays.
      expect(_key('token-facts-notice'), findsNothing);
      expect(_key('token-facts-provenance'), findsOneWidget);
    });
  });
}
