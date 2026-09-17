// Where an owner adds an asset to the Watchlist.
//
// C-30 (8) on the device: 「在哪儿增加自选呢？」. The empty state named the
// star — 「打开代币页，点右上角星标即可加入自选」 — and nothing on either
// Watchlist surface led to a page that has one. Adding is a write on the
// token page and only there (S13), so these surfaces cannot add; what they
// owed the reader was a way to reach a token page, and the star owed them
// its presence in every state of that page.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

void main() {
  loopWatchGround();

  final Finder star = find.byKey(
    const ValueKey<String>('token-watchlist-action'),
  );
  final Finder addRow = find.byKey(
    const ValueKey<String>('market-watchlist-add'),
  );

  group('market · 自选 names the way in', () {
    testWidgets('an empty Watchlist offers the route to a token page', (
      tester,
    ) async {
      final routes = <String>[];
      await pumpS5Page(
        tester,
        MarketScreen(onNavigate: routes.add),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(
            value: s5Overview(
              watchlist: MarketWatchlistAvailable(
                version: 3,
                items: <MarketAssetRow>[],
              ),
            ),
          ),
        ),
      );

      await scrollToS5Section(tester, addRow);
      expect(
        find.byKey(const ValueKey<String>('market-watchlist-empty')),
        findsOneWidget,
      );
      expect(find.text('添加自选资产'), findsOneWidget);

      await tester.tap(addRow);
      await tester.pumpAndSettle();
      expect(routes, <String>['/market/new']);
    });

    testWidgets('a Watchlist that already has rows keeps the same way in', (
      tester,
    ) async {
      final routes = <String>[];
      await pumpS5Page(
        tester,
        MarketScreen(onNavigate: routes.add),
        market: FakeMarketReadGateway(),
      );

      await scrollToS5Section(tester, addRow);
      expect(addRow, findsOneWidget);

      await tester.tap(addRow);
      await tester.pumpAndSettle();
      expect(routes, <String>['/market/new']);
    });

    testWidgets('a Watchlist that could not be read offers no way in', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(
            value: s5Overview(
              watchlist: const MarketWatchlistUnavailable(
                'WATCHLIST_RUNTIME_UNAVAILABLE',
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('market-watchlist-unavailable')),
        findsOneWidget,
      );
      // There is no list for the write to land in, so the row would promise
      // one that does not exist.
      expect(addRow, findsNothing);
    });
  });

  group('watchlist-edit · every group says how an asset gets in', () {
    WatchlistSnapshot snapshot({required bool populated}) => WatchlistSnapshot(
      version: 4,
      updatedAt: null,
      groups: <WatchlistGroup>[
        WatchlistGroup(
          key: watchlistDefaultGroupKey,
          name: watchlistDefaultGroupName,
          items: populated
              ? <WatchlistItem>[
                  WatchlistItem(assetId: s5WbnbAssetId, asset: s5Summary()),
                ]
              : const <WatchlistItem>[],
        ),
      ],
    );

    testWidgets('a group with rows carries the 添加资产 control', (tester) async {
      final routes = <String>[];
      await pumpS5Page(
        tester,
        WatchlistEditorScreen(onNavigate: routes.add),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(
            value: snapshot(populated: true),
          ),
        ),
      );

      final add = find.byKey(const ValueKey<String>('watchlist-add-asset'));
      await scrollToS5Section(tester, add);
      expect(add, findsOneWidget);
      // The control cannot add, and the page says where the asset lands
      // instead of implying it lands in the group on screen.
      expect(find.textContaining('打开代币页，点右上角星标'), findsOneWidget);
      expect(find.textContaining('本页不能把它移到别的分组'), findsOneWidget);

      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(routes, <String>['/market/new']);
    });

    testWidgets('an empty group offers the same control, not only a sentence', (
      tester,
    ) async {
      final routes = <String>[];
      await pumpS5Page(
        tester,
        WatchlistEditorScreen(onNavigate: routes.add),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(
            value: snapshot(populated: false),
          ),
        ),
      );

      final add = find.byKey(
        const ValueKey<String>('watchlist-group-empty-add'),
      );
      await scrollToS5Section(tester, add);
      expect(
        find.byKey(const ValueKey<String>('watchlist-group-empty')),
        findsOneWidget,
      );

      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(routes, <String>['/market/new']);
    });
  });

  group('token · the star is the write, in every state', () {
    testWidgets('a price that could not be read does not close the star', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            failure: LoopChainFailureKind.notFound,
          ),
        ),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(
            value: WatchlistSnapshot(
              version: 4,
              updatedAt: null,
              groups: const <WatchlistGroup>[],
            ),
          ),
        ),
      );

      expect(star, findsOneWidget);
      // The Watchlist read succeeded, so the star still states membership and
      // still toggles it: a Market outage is not an answer about this list.
      expect(tester.widget<LoopIconButton>(star).label, '加入自选');
      expect(tester.widget<LoopIconButton>(star).onPressed, isNotNull);
    });

    testWidgets('a Watchlist that could not be read keeps the star visible', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(
            failure: LoopChainFailureKind.unavailable,
          ),
        ),
      );

      // Never hidden: a control that disappears is a control the reader goes
      // looking for. It says why it cannot be used instead.
      expect(star, findsOneWidget);
      expect(tester.widget<LoopIconButton>(star).toggled, isNull);
    });
  });
}
