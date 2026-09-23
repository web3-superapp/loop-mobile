import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// The one published address the contract's allow-list accepts for a BSC
/// token. Every projection test below asserts this exact string reaches the
/// widget, because a logo that is decoded and dropped is indistinguishable on
/// screen from one that was never published (decision 0086).
const String _trustWalletLogo =
    'https://raw.githubusercontent.com/trustwallet/assets/master/'
    'blockchains/smartchain/assets/'
    '0x55d398326f99059fF775485246999027B3197955/logo.png';

/// The address the [LoopTokenLogo] under [parent] was handed, or `null`.
String? _logoUrlUnder(WidgetTester tester, Finder parent) {
  final logo = find.descendant(
    of: parent,
    matching: find.byType(LoopTokenLogo),
  );
  if (logo.evaluate().isEmpty) return null;
  return tester.widget<LoopTokenLogo>(logo.first).logoUrl;
}

void main() {
  loopWatchGround();

  // -------------------------------------------------------------------------
  // 1 · the published logo reaches every row that used to draw a monogram
  // -------------------------------------------------------------------------
  group('token 图 · 每个投影点都把 logo 交到组件手上', () {
    test('钱包余额行 · balances[].logo 投影到模型', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5BalancesBody())),
        ),
      );

      final balances = await api.getBalances(
        accessToken: 'privy-access-token',
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
      );

      // S78b validated the block and threw it away; the row now carries it.
      expect(balances.balances.first.logoUrl, isNotNull);
      expect(balances.balances.first.logoUrl, startsWith('https://'));
    });

    testWidgets('钱包资产行把它交给 LoopTokenLogo', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[s5Row(logoUrl: _trustWalletLogo)],
            ),
          ),
        ),
      );

      final row = find.byKey(
        const ValueKey<String>('wallet-balance-$s5NativeAssetId'),
      );
      await scrollToS5Section(tester, row);
      expect(_logoUrlUnder(tester, row), _trustWalletLogo);
    });

    testWidgets('发送选资产列表把它交给 LoopTokenLogo', (tester) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[s5Row(logoUrl: _trustWalletLogo)],
            ),
          ),
        ),
        intents: FakeWalletIntentsGateway(),
      );

      final row = find.byKey(
        const ValueKey<String>('send-asset-$s5NativeAssetId'),
      );
      expect(_logoUrlUnder(tester, row), _trustWalletLogo);
    });

    testWidgets('挖矿算力明细行把它交给 LoopTokenLogo', (tester) async {
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: FakeMiningGateway(
          assets: S7Answer<MiningAssets>(
            value: s7MiningSettledAssets(
              included: <MiningAssetRow>[
                s7MiningAssetRow(logoUrl: _trustWalletLogo),
              ],
            ),
          ),
        ),
      );

      final row = find.byKey(
        ValueKey<String>('mining-assets-row-$s7CakeAssetId'),
      );
      await scrollToS7Section(tester, row);
      expect(_logoUrlUnder(tester, row), _trustWalletLogo);
    });

    testWidgets('搜索资产行把它交给 LoopTokenLogo', (tester) async {
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(initialQuery: 'usdt'),
        search: FakeSearchGateway(
          pages: <SearchDomain, SearchPage>{
            SearchDomain.assets: SearchPage(
              domain: SearchDomain.assets,
              available: true,
              reasonCode: null,
              results: <SearchResult>[
                SearchResult(
                  resultType: SearchResultType.asset,
                  stableId: s5UsdtAssetId,
                  title: 'USDT',
                  subtitle: 'Tether USD',
                  avatarRef: null,
                  logoUrl: _trustWalletLogo,
                  memberCount: null,
                  verificationStatus: 'pending',
                  destination: const SearchAssetDestination(s5UsdtAssetId),
                ),
              ],
              nextCursor: null,
            ),
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('search-seg-assets')));
      await tester.pumpAndSettle();

      final row = find.byKey(
        const ValueKey<String>('search-result-$s5UsdtAssetId'),
      );
      expect(_logoUrlUnder(tester, row), _trustWalletLogo);
    });

    testWidgets('自选管理行有了资产自己的图，不再只是一个拖拽把手', (tester) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(
            value: WatchlistSnapshot(
              version: 3,
              updatedAt: DateTime.utc(2026, 9, 8),
              groups: <WatchlistGroup>[
                WatchlistGroup(
                  key: 'default',
                  name: '默认',
                  items: <WatchlistItem>[
                    WatchlistItem(
                      assetId: s5UsdtAssetId,
                      asset: s5Summary(symbol: 'USDT'),
                      logoUrl: _trustWalletLogo,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      final logo = find.byKey(
        const ValueKey<String>('watchlist-logo-$s5UsdtAssetId'),
      );
      await scrollToS5Section(tester, logo);
      expect(tester.widget<LoopTokenLogo>(logo).logoUrl, _trustWalletLogo);
    });

    testWidgets('社区币卡 · 社区详情的 Token Card 画的是真图', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: LoopTokenCard(
                key: ValueKey<String>('community-bound-asset'),
                state: LoopTokenCardState.normal,
                model: LoopTokenCardModel(
                  symbol: 'USDT',
                  identifier: 'eip155:56:0x55d3…7955',
                  logoUrl: _trustWalletLogo,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Before this step the card drew its own green ₮ for every USDT on the
      // screen, including the 社区币 card the requester screenshotted.
      expect(
        tester.widget<LoopTokenLogo>(find.byType(LoopTokenLogo)).logoUrl,
        _trustWalletLogo,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2 · 发现社区 rows follow the prototype's own row
  // -------------------------------------------------------------------------
  group('发现社区 · 行按原型排', () {
    testWidgets('行高、内边距与分隔线与 community-discover.html 相同', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            backgroundColor: LoopColors.ink,
            body: SingleChildScrollView(
              child: LoopRecordGroup(
                rows: <LoopRecordRow>[
                  communityDirectoryRow(
                    community: testCommunity(name: 'DeFi 早读会'),
                    onTap: () {},
                  ),
                  communityDirectoryRow(
                    community: testCommunity(
                      communityId: '33333333-3333-4333-8333-333333333333',
                      name: '链上数据观察站 24 号',
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // `.refined-page .folio-body>.row{padding:13px 12px}` over a 44pt
      // `.row-ico`, plus the 1px hairline: 13 + 44 + 13 + 1 = 71.
      final rows = find.byType(LoopRecordRow);
      expect(tester.getSize(rows.at(1)).height, 70);
      expect(
        tester.getTopLeft(rows.at(1)).dy - tester.getTopLeft(rows.at(0)).dy,
        72,
      );
      // `.row{gap:12px}` after a 44pt mark inside a 16pt page margin.
      expect(tester.getTopLeft(find.text('DeFi 早读会')).dx, 84);
    });

    testWidgets('第二行说成员数，右边只留 chevron', (tester) async {
      final row = communityDirectoryRow(
        community: testCommunity(memberCount: 312),
        onTap: () {},
      );

      // `renderRow('community')`: `<div class="row-s">${d.members} 成员 · …`.
      // 「已验证」 alone on the second line while 「312 / 成员」 stood in a
      // two-line value column spent a 70pt row on four words.
      expect(row.subtitle, '312 名成员 · 已验证');
      expect(row.trailing, isNull);
      expect(row.trailingCaption, isNull);
    });

    testWidgets('chip 行与首行之间是原型的 16', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: FakeCommunityGateway(
          directoryPage: CommunityDirectoryPage(
            ordering: const CommunityOrderingApplied(
              sort: CommunityDirectorySort.members,
              basis: CommunityStoredBasis(),
            ),
            items: <CommunitySummary>[testCommunity()],
            nextCursor: null,
            recommendation: const CommunityRecommendation(
              recommendationId: '22222222-2222-4222-8222-222222222222',
              ruleVersion: 'rule:verified-members-v1',
            ),
          ),
        ),
      );

      final chip = find.byKey(const ValueKey<String>('discover-seg-members'));
      final padding = tester.widget<Padding>(
        find.ancestor(of: chip, matching: find.byType(Padding)).at(1),
      );
      expect(padding.padding, const EdgeInsets.fromLTRB(16, 0, 16, 16));
    });
  });

  // -------------------------------------------------------------------------
  // 3a · 跌为红
  // -------------------------------------------------------------------------
  group('涨跌 · 跌一律 danger，零与读不到一律 muted', () {
    test('方向只有四种，颜色只有三种', () {
      expect(LoopPriceMove.of(Decimal.parse('1.2')), LoopPriceMove.up);
      expect(LoopPriceMove.of(Decimal.parse('-1.2')), LoopPriceMove.down);
      expect(LoopPriceMove.of(Decimal.zero), LoopPriceMove.flat);
      expect(LoopPriceMove.of(null), LoopPriceMove.unread);
      expect(LoopPriceMove.up.color, LoopColors.lime);
      expect(LoopPriceMove.down.color, LoopColors.danger);
      expect(LoopPriceMove.flat.color, LoopColors.muted);
      expect(LoopPriceMove.unread.color, LoopColors.muted);
    });

    testWidgets('社区币卡的跌是 danger，不是 Chalk', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            backgroundColor: LoopColors.ink,
            body: SingleChildScrollView(
              child: LoopTokenCard(
                state: LoopTokenCardState.normal,
                model: LoopTokenCardModel(
                  symbol: 'USDT',
                  identifier: '0x55d3…7955',
                  price: r'$0.9994',
                  change: '-3.20%',
                  move: LoopPriceMove.down,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.text('-3.20%')).style?.color,
        LoopColors.danger,
      );
    });

    testWidgets('行情行的色块：涨 lime、跌 danger、持平与读不到 muted', (tester) async {
      Color groundOf(LoopFact fact) {
        return MarketMove.of(fact).shared.ground;
      }

      expect(groundOf(s5FreshFact('1.2')), LoopColors.lime);
      expect(groundOf(s5FreshFact('-1.2')), LoopColors.danger);
      expect(groundOf(s5FreshFact('0')), LoopColors.muted);
      expect(
        groundOf(const LoopFact.unavailable('MARKET_FACT_NOT_REPORTED')),
        LoopColors.muted,
      );
    });

    testWidgets('K 线读数行的 C 值随方向变色', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          candles: S5Answer<MarketCandleSeries>(
            value: s5Series(
              items: <LoopCandle>[
                LoopCandle(
                  openTime: DateTime.utc(2026, 9, 8, 6),
                  closeTime: DateTime.utc(2026, 9, 8, 7),
                  open: s5Decimal('750'),
                  high: s5Decimal('752'),
                  low: s5Decimal('740'),
                  close: s5Decimal('742'),
                  volume: s5Decimal('100'),
                  swapCount: 12,
                  isOpen: false,
                ),
              ],
            ),
          ),
        ),
      );

      final close = find.textContaining('C ');
      expect(tester.widget<Text>(close.first).style?.color, LoopColors.danger);
    });

    testWidgets('明细行的向下副标题也是 danger', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: LoopRecordRow(
              title: '卖出 120 USDT',
              trailing: '0.16',
              trailingCaption: '流入池',
              trailingCaptionUp: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.text('流入池')).style?.color,
        LoopColors.danger,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3b–3e · 代币页
  // -------------------------------------------------------------------------
  group('代币页 · 交易所的形状', () {
    testWidgets('买入 / 卖出 固定在页脚，滚动不带走', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      final bar = find.byKey(const ValueKey<String>('token-trade-bar'));
      expect(bar, findsOneWidget);
      final before = tester.getTopLeft(bar).dy;
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      // The bar does not move with the page it floats over.
      expect(tester.getTopLeft(bar).dy, before);
      // And nothing below it is cut off: the scroll reserves its height.
      expect(find.byKey(const ValueKey<String>('token-buy-action')), findsOne);
    });

    testWidgets('周期 Tab 与 MA7 / MA25 在 K 线上方一行', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      for (final interval in LoopCandleInterval.values) {
        expect(
          find.byKey(ValueKey<String>('token-interval-${interval.wireName}')),
          findsOneWidget,
          reason: '五个周期都在 K 线上方那一行',
        );
      }
      final averages = find.byKey(
        const ValueKey<String>('token-moving-averages'),
      );
      expect(averages, findsOneWidget);
      expect(tester.widget<Text>(averages).data, contains('MA7'));
      // 紧贴上方：读数行在图之上，图在读数行之下的同一张卡里。
      final chart = find.byKey(const ValueKey<String>('token-candle-chart'));
      expect(
        tester.getTopLeft(averages).dy,
        lessThan(tester.getTopLeft(chart).dy),
      );
      // 成交量与 K 线同屏。
      expect(tester.widget<LoopCandleChart>(chart).showVolume, isTrue);
    });

    testWidgets('下半页是社区 / 持有人 / 成交 / 简介 四个 Tab', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            value: s5Detail(
              community: const MarketCommunityBound(
                communityId: '11111111-1111-4111-8111-111111111111',
                name: 'Frog Holders',
                slug: 'frog-holders',
                memberCount: 128,
              ),
            ),
          ),
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-section-tabs')),
      );
      for (final tab in TokenSectionTab.values) {
        expect(
          find.byKey(ValueKey<String>('token-tab-${tab.label}')),
          findsOneWidget,
        );
      }
      // 社区 is the tab the page opens on, and it lists the bound community
      // as a row rather than as a link to a link.
      expect(
        find.byKey(const ValueKey<String>('token-community-entry')),
        findsOneWidget,
      );
      // 「更多」 is gone: the two rows it held are the other two tabs.
      expect(
        find.byKey(const ValueKey<String>('token-holders-entry')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey<String>('token-tab-成交')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('token-trades-entry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('token-community-entry')),
        findsNothing,
      );
    });

    testWidgets('24h 高 / 24h 低两格读服务端的窗口', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      final cells = find.byKey(const ValueKey<String>('token-quote-cells'));
      expect(
        find.descendant(of: cells, matching: find.text('24h 高')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cells, matching: find.text(r'$748.90')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cells, matching: find.text(r'$746.50')),
        findsOneWidget,
      );
    });

    testWidgets('窗口读不到时两格印「—」，绝不是 0，也不自己从 K 线算', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            value: s5Detail(
              range24h: const MarketRange24hUnavailable(
                'MARKET_SPARKLINE_NOT_CACHED',
              ),
            ),
          ),
        ),
      );

      final cells = find.byKey(const ValueKey<String>('token-quote-cells'));
      expect(
        find.descendant(of: cells, matching: find.text(marketMissingFigure)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: cells, matching: find.text('0')),
        findsNothing,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 契约：决策 0074 §3a / §4.1 / §4 的三处收紧
  // -------------------------------------------------------------------------
  group('契约 · 决策 0074 的三处', () {
    test('range24h 必填，缺键即无效载荷', () async {
      final body = s5AssetDetailBody()..remove('range24h');
      final api = DioLoopV2MarketApi(
        s5Dio((options, handler) => handler.resolve(s5Response(options, body))),
      );

      await expectLater(
        api.getAsset(
          accessToken: 'privy-access-token',
          clientVersion: s5ClientVersion,
          assetId: s5WbnbAssetId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('range24h 解出 high / low / bars / quality', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5AssetDetailBody(
                range24h: s5Range24h(bars: 6, quality: 'stale'),
              ),
            ),
          ),
        ),
      );

      final detail = await api.getAsset(
        accessToken: 'privy-access-token',
        clientVersion: s5ClientVersion,
        assetId: s5WbnbAssetId,
      );

      final range = detail.range24h! as MarketRange24hAvailable;
      expect(range.high, s5Decimal('748.9'));
      expect(range.low, s5Decimal('746.5'));
      expect(range.bars, 6);
      // 不足 24 根仍然是 available —— 只是历史短，不是读不到。
      expect(range.isPartialWindow, isTrue);
      expect(range.quality, LoopFactQuality.stale);
    });

    test('high 低于 low 不是一个窗口', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5AssetDetailBody(
                range24h: s5Range24h(high: '746.5', low: '748.9'),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        api.getAsset(
          accessToken: 'privy-access-token',
          clientVersion: s5ClientVersion,
          assetId: s5WbnbAssetId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('24h 涨跌的 stale + MARKET_FACT_NOT_REPORTED 是可用值，不是错误', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, <String, Object?>{
              ...s5AssetDetailBody(),
              'priceChange24h': s5Fact(
                value: '-0.31',
                quality: 'stale',
                reasonCode: 'MARKET_FACT_NOT_REPORTED',
              ),
            }),
          ),
        ),
      );

      final detail = await api.getAsset(
        accessToken: 'privy-access-token',
        clientVersion: s5ClientVersion,
        assetId: s5WbnbAssetId,
      );

      // Provider 本次没给、后端用同池上次值：按值显示，并带 stale 标记。
      expect(detail.priceChange24h.isAvailable, isTrue);
      expect(detail.priceChange24h.value, s5Decimal('-0.31'));
      expect(detail.priceChange24h.needsMarker, isTrue);
      expect(MarketMove.of(detail.priceChange24h).shared, LoopPriceMove.down);
    });
  });
}
