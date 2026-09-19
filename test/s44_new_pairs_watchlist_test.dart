import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// Real-device report 2026-09-19 · F4.
///
/// 新币发现 could only be read: a member who found a pool there had to go and
/// look the token up somewhere else to keep it. The row now writes through the
/// same watchlist path the Token page's star does — but only where LOOP
/// already knows which registry asset the row's base token is.
const String _newAssetId =
    'eip155:56:0x00000000000000000000000000000000000000a2';

MarketNewPairsPage _page({
  required String? registryAssetId,
  MarketPoolRef poolRef = const MarketPoolAddressRef(s5PoolAddress),
}) => MarketNewPairsPage(
  newPairs: MarketNewPairsAvailable(
    source: LoopFactSource.geckoterminal,
    fetchedAt: DateTime.utc(2026, 9, 8, 7, 31),
    ttlSeconds: 60,
    quality: LoopFactQuality.fresh,
    reasonCode: null,
    omittedCount: 0,
    items: <MarketNewPair>[
      MarketNewPair(
        poolRef: poolRef,
        dexId: 'pancakeswap_v3',
        name: 'X / WBNB',
        baseTokenAddress: s5Address,
        quoteTokenAddress: s5Address,
        registryAssetId: registryAssetId,
        createdAt: DateTime.utc(2026, 9, 8, 5),
        reserveUsd: Decimal.parse('12345.6'),
        volumeH24Usd: Decimal.parse('2345.6'),
      ),
    ],
  ),
  riskScreening: const LoopUnavailable('MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED'),
);

void main() {
  testWidgets('a registered pool is added from the row it was found on', (
    tester,
  ) async {
    final watchlist = FakeWatchlistGateway();
    await pumpS5Page(
      tester,
      const NewPairsScreen(),
      market: FakeMarketReadGateway(
        newPairs: S5Answer<MarketNewPairsPage>(
          value: _page(registryAssetId: _newAssetId),
        ),
      ),
      watchlist: watchlist,
    );

    final star = find.byKey(
      const ValueKey<String>('new-pair-watchlist-$_newAssetId'),
    );
    await scrollToS5Section(tester, star);
    // One document holds every membership on this page. Reading it once per
    // row would be the same read a hundred times, so nothing is read until a
    // row is pressed.
    expect(watchlist.loads, 0);

    await tester.tap(star);
    await tester.pumpAndSettle();

    expect(watchlist.loads, 1);
    final written = watchlist.written.single;
    expect(
      written.expand((group) => group.items).map((item) => item.assetId),
      contains(_newAssetId),
    );
    // The same sentence the Token page's star says, from the same helper.
    expect(find.text('已加入自选'), findsOneWidget);
  });

  testWidgets('a pool the registry does not carry offers nothing to press', (
    tester,
  ) async {
    final watchlist = FakeWatchlistGateway();
    await pumpS5Page(
      tester,
      const NewPairsScreen(),
      market: FakeMarketReadGateway(
        newPairs: S5Answer<MarketNewPairsPage>(
          value: _page(registryAssetId: null),
        ),
      ),
      watchlist: watchlist,
    );

    final row = find.byKey(ValueKey<String>('new-pair-address:$s5PoolAddress'));
    await scrollToS5Section(tester, row);
    expect(row, findsOneWidget);
    // An address is not an asset id, so the row says what it cannot do rather
    // than offering a star the server would refuse.
    expect(find.textContaining('暂不支持加自选'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'new-pair-watchlist-',
            ),
      ),
      findsNothing,
    );
    expect(watchlist.loads, 0);
  });

  testWidgets('a pool with no address keeps its own explanation', (
    tester,
  ) async {
    await pumpS5Page(
      tester,
      const NewPairsScreen(),
      market: FakeMarketReadGateway(
        newPairs: S5Answer<MarketNewPairsPage>(
          value: _page(
            registryAssetId: null,
            poolRef: const MarketPoolIdRef(s5PoolId),
          ),
        ),
      ),
      watchlist: FakeWatchlistGateway(),
    );

    final row = find.byKey(const ValueKey<String>('new-pair-poolId:$s5PoolId'));
    await scrollToS5Section(tester, row);
    expect(find.textContaining('Uniswap V4 池 · 暂不支持详情'), findsOneWidget);
    // One row never carries two sentences about the same absence.
    expect(find.textContaining('暂不支持加自选'), findsNothing);
  });

  testWidgets('a watchlist that is full refuses before it writes', (
    tester,
  ) async {
    final watchlist = FakeWatchlistGateway(
      snapshot: S5Answer<WatchlistSnapshot>(
        value: WatchlistSnapshot(
          version: 4,
          updatedAt: DateTime.utc(2026, 9, 8, 6),
          groups: <WatchlistGroup>[
            WatchlistGroup(
              key: watchlistDefaultGroupKey,
              name: watchlistDefaultGroupName,
              items: <WatchlistItem>[
                for (var index = 0; index < watchlistMaxItems; index += 1)
                  WatchlistItem(
                    assetId:
                        'eip155:56:0x'
                        '${index.toRadixString(16).padLeft(40, '0')}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    await pumpS5Page(
      tester,
      const NewPairsScreen(),
      market: FakeMarketReadGateway(
        newPairs: S5Answer<MarketNewPairsPage>(
          value: _page(registryAssetId: _newAssetId),
        ),
      ),
      watchlist: watchlist,
    );

    final star = find.byKey(
      const ValueKey<String>('new-pair-watchlist-$_newAssetId'),
    );
    await scrollToS5Section(tester, star);
    await tester.tap(star);
    await tester.pumpAndSettle();

    expect(watchlist.written, isEmpty);
    expect(find.textContaining('自选已达'), findsOneWidget);
  });
}
