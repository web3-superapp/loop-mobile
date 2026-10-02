import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_screen.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

void main() {
  for (final width in <double>[360, 390]) {
    testWidgets('price and change stack at right at $width', (tester) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
        size: Size(width, 900),
      );
      final tile = find.byType(MarketAssetTile).first;
      final price = find.descendant(
        of: tile,
        matching: find.byKey(const ValueKey<String>('market-row-price-slot')),
      );
      final change = find.descendant(
        of: tile,
        matching: find.byType(MarketChangeBlock),
      );
      expect(
        tester.getRect(change).top,
        greaterThanOrEqualTo(tester.getRect(price).bottom),
      );
      expect(
        tester.getRect(change).right,
        closeTo(tester.getRect(price).right, 1),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('canonical category filter changes rows without detail reads', (
    tester,
  ) async {
    final gateway = FakeMarketReadGateway(
      overview: S5Answer<MarketOverview>(
        value: s5Overview(
          watchlist: MarketWatchlistAvailable(
            version: 1,
            items: [
              s5MarketRow(),
              s5MarketRow(assetId: s5NativeAssetId),
            ],
          ),
        ),
      ),
    );
    await pumpS5Page(tester, const MarketScreen(), market: gateway);
    await tester.tap(
      find.byKey(const ValueKey<String>('market-filter-native')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('market-asset-$s5NativeAssetId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('market-asset-$s5WbnbAssetId')),
      findsNothing,
    );
    expect(gateway.assetReads, isEmpty);
  });
  testWidgets('detail offers dynamic holders and about tabs at phone width', (
    tester,
  ) async {
    await pumpS5Page(
      tester,
      const TokenDetailScreen(assetId: s5WbnbAssetId),
      market: FakeMarketReadGateway(),
      size: const Size(360, 2400),
    );
    expect(find.text('动态'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('token-tab-持有者')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('token-holders-entry')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('token-tab-关于')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('token-security-facts')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('community discussion uses the bound community route', (
    tester,
  ) async {
    String? destination;
    await pumpS5Page(
      tester,
      TokenDetailScreen(
        assetId: s5WbnbAssetId,
        onNavigate: (value) => destination = value,
      ),
      market: FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(
          value: s5Detail(
            community: const MarketCommunityBound(
              communityId: s5CommunityId,
              name: 'BNB 社区',
              slug: 'bnb',
              memberCount: 42,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('进入社区讨论'));
    expect(destination, '/community/profile?id=$s5CommunityId');
  });
}
