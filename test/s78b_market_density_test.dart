import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// Mounts [tiles] the way 行情 mounts them, on the Ink page.
Future<void> _pumpTiles(WidgetTester tester, List<Widget> tiles) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(
        backgroundColor: LoopColors.ink,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[MarketAssetTileGroup(tiles: tiles)],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MarketAssetRow _row({
  required String assetId,
  required String symbol,
  String name = 'Wrapped BNB',
  LoopFact? price,
  LoopFact? change,
  String? logoUrl,
}) => MarketAssetRow(
  assetId: assetId,
  asset: LoopAssetSummary(
    symbol: symbol,
    name: name,
    decimals: 18,
    status: LoopAssetStatus.pending,
  ),
  price: price ?? s5FreshFact('747.39'),
  priceChange24h: change ?? s5FreshFact('0.27'),
  logoUrl: logoUrl,
);

void main() {
  loopWatchGround();

  group('行情 row · one height, one value column', () {
    testWidgets('a row with a line and a row without it are the same height', (
      tester,
    ) async {
      await _pumpTiles(tester, <Widget>[
        MarketAssetTile(
          key: const ValueKey<String>('tile-with-line'),
          row: _row(assetId: s5WbnbAssetId, symbol: 'WBNB'),
          sparkline: LoopSparkline(
            closes: <Decimal>[
              Decimal.fromInt(1),
              Decimal.fromInt(3),
              Decimal.fromInt(2),
            ],
            semanticLabel: '3 个收盘价',
          ),
        ),
        MarketAssetTile(
          key: const ValueKey<String>('tile-without-line'),
          row: _row(
            assetId: s5NativeAssetId,
            symbol: 'BNB',
            name: 'BNB',
            change: const LoopFact.unavailable('MARKET_FACT_NOT_REPORTED'),
          ),
        ),
      ]);

      final withLine = tester.getSize(
        find.byKey(const ValueKey<String>('tile-with-line')),
      );
      final withoutLine = tester.getSize(
        find.byKey(const ValueKey<String>('tile-without-line')),
      );
      expect(withLine.height, marketRowHeight);
      expect(withoutLine.height, marketRowHeight);
      // The slot is reserved either way, so the value column does not move
      // sideways from row to row.
      final slots = tester.widgetList<SizedBox>(
        find.byKey(const ValueKey<String>('market-row-spark-slot')),
      );
      expect(slots.length, 2);
      for (final slot in slots) {
        expect(slot.width, marketRowSparklineSize.width);
        expect(slot.height, marketRowSparklineSize.height);
      }
    });

    testWidgets('every price ends on the same right edge', (tester) async {
      await _pumpTiles(tester, <Widget>[
        MarketAssetTile(
          key: const ValueKey<String>('tile-long'),
          row: _row(assetId: s5WbnbAssetId, symbol: 'WBNB'),
        ),
        MarketAssetTile(
          key: const ValueKey<String>('tile-short'),
          row: _row(
            assetId: s5NativeAssetId,
            symbol: 'BNB',
            name: 'BNB',
            price: s5FreshFact('0.1'),
            change: s5FreshFact('-2.5'),
          ),
        ),
      ]);

      final long = tester.getRect(find.text(r'$747.39'));
      final short = tester.getRect(find.text(r'$0.1'));
      expect(long.right, closeTo(short.right, 0.01));
      // The block is a fixed width, so the changes stack into a column too.
      final blocks = tester.widgetList<MarketChangeBlock>(
        find.byType(MarketChangeBlock),
      );
      expect(blocks, hasLength(2));
      for (final block in blocks) {
        expect(block.width, marketRowChangeWidth);
        expect(block.height, marketRowChangeHeight);
      }
      final rects = <Rect>[
        for (final finder in <Finder>[
          find.byType(MarketChangeBlock).at(0),
          find.byType(MarketChangeBlock).at(1),
        ])
          tester.getRect(finder),
      ];
      expect(rects.first.right, closeTo(rects.last.right, 0.01));
      // Price column then change column: the two never overlap.
      expect(long.right, lessThanOrEqualTo(rects.first.left));
    });

    testWidgets('a sub-dollar price keeps its digits instead of reading \$0', (
      tester,
    ) async {
      await _pumpTiles(tester, <Widget>[
        MarketAssetTile(
          row: _row(
            assetId: s5WbnbAssetId,
            symbol: 'DOGE',
            price: s5FreshFact('0.0000082'),
          ),
        ),
      ]);

      expect(find.text(r'$0'), findsNothing);
      expect(find.text(r'$0.0000082'), findsOneWidget);
    });

    testWidgets('a change nothing reported is 读不到, never a flat 0.00%', (
      tester,
    ) async {
      await _pumpTiles(tester, <Widget>[
        MarketAssetTile(
          row: _row(
            assetId: s5WbnbAssetId,
            symbol: 'USDT',
            change: const LoopFact.unavailable('MARKET_FACT_NOT_REPORTED'),
          ),
        ),
      ]);

      expect(find.text('读不到'), findsOneWidget);
      expect(find.text('0.00%'), findsNothing);
      expect(find.text('+0.00%'), findsNothing);
    });

    testWidgets(
      'a price that could not be read spends the line on the reason',
      (tester) async {
        await _pumpTiles(tester, <Widget>[
          MarketAssetTile(
            row: _row(
              assetId: s5WbnbAssetId,
              symbol: 'WBNB',
              price: const LoopFact.unavailable('MARKET_PAIR_NOT_FOUND'),
              change: const LoopFact.unavailable('MARKET_PAIR_NOT_FOUND'),
            ),
          ),
        ]);

        expect(find.textContaining('没有找到这个资产的交易对'), findsOneWidget);
        expect(find.text(r'$0'), findsNothing);
        // The same sentence is never printed twice on one 64pt row.
        expect(find.text('数据不可得'), findsNothing);
      },
    );
  });

  group('行情 row · the mark', () {
    testWidgets('a monogram is two characters, never the whole label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            backgroundColor: LoopColors.ink,
            body: Column(
              children: <Widget>[
                // The provider's own pool name, slash and all (walkthrough
                // 2026-09-23, d06: the tile read 「OH /」).
                LoopTokenLogo(
                  assetSymbol: 'OH / WBNB',
                  fallbackMonogram: 'OH / WBNB',
                ),
                LoopTokenLogo(
                  assetSymbol: 'YAMATA',
                  fallbackMonogram: 'YAMATA',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OH'), findsOneWidget);
      expect(find.text('YA'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);
      expect(find.text('YAMATA'), findsNothing);
    });

    testWidgets('a published logo address is fetched; anything else is not', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            backgroundColor: LoopColors.ink,
            body: Column(
              children: <Widget>[
                LoopTokenLogo(
                  key: ValueKey<String>('logo-remote'),
                  assetSymbol: 'CAKE',
                  logoUrl: 'https://cdn.example.com/cake.png',
                ),
                LoopTokenLogo(
                  key: ValueKey<String>('logo-insecure'),
                  assetSymbol: 'ZZZTEST',
                  logoUrl: 'http://cdn.example.com/zzz.png',
                ),
                LoopTokenLogo(
                  key: ValueKey<String>('logo-garbage'),
                  assetSymbol: 'QQQTEST',
                  logoUrl: '  ',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final remote = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('logo-remote')),
          matching: find.byType(Image),
        ),
      );
      // Decision 0101: decoded at the tile's own pixel size.
      final resized = remote.image as ResizeImage;
      expect(
        (resized.imageProvider as NetworkImage).url,
        'https://cdn.example.com/cake.png',
      );
      // A plaintext address and an empty string are both "no artwork", not a
      // fetch: the tile falls straight through to its monogram.
      for (final key in <String>['logo-insecure', 'logo-garbage']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey<String>(key)),
            matching: find.byType(Image),
          ),
          findsNothing,
        );
      }
      expect(find.text('ZZ'), findsOneWidget);
      expect(find.text('QQ'), findsOneWidget);
    });

    testWidgets('a logo that fails to load falls back to the monogram', (
      tester,
    ) async {
      // `flutter_test` answers every network request with a 400, so this is
      // the failure path end to end.
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            backgroundColor: LoopColors.ink,
            body: LoopTokenLogo(
              assetSymbol: 'ZZZTEST',
              logoUrl: 'https://cdn.example.com/missing.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ZZ'), findsOneWidget);
    });

    test('a validated address is https with a host, and nothing else', () {
      expect(
        loopRemoteLogoUri('https://cdn.example.com/a.png')?.host,
        'cdn.example.com',
      );
      expect(loopRemoteLogoUri('http://cdn.example.com/a.png'), isNull);
      expect(loopRemoteLogoUri('/tokens/a.png'), isNull);
      expect(loopRemoteLogoUri('data:image/png;base64,AA'), isNull);
      expect(loopRemoteLogoUri('https:///a.png'), isNull);
      expect(loopRemoteLogoUri(''), isNull);
      expect(loopRemoteLogoUri(null), isNull);
    });
  });

  group('new-pairs · a venue has a name', () {
    test('a known slug reads as its venue, an unknown one is title-cased', () {
      expect(marketDexLabel('four-meme'), 'four.meme');
      expect(marketDexLabel('pancakeswap_v2'), 'PancakeSwap V2');
      expect(marketDexLabel('uniswap-v4-bsc'), 'Uniswap V4');
      expect(marketDexLabel('PancakeSwap_V3'), 'PancakeSwap V3');
      expect(marketDexLabel('my_new_dex'), 'My New Dex');
      expect(marketDexLabel(''), '');
    });

    testWidgets('a read-only row carries one neutral pill, not two refusals', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NewPairsScreen(),
        market: FakeMarketReadGateway(
          newPairs: S5Answer<MarketNewPairsPage>(
            value: MarketNewPairsPage(
              newPairs: MarketNewPairsAvailable(
                source: LoopFactSource.geckoterminal,
                fetchedAt: DateTime.utc(2026, 9, 8, 7, 31),
                ttlSeconds: 60,
                quality: LoopFactQuality.fresh,
                reasonCode: null,
                omittedCount: 0,
                items: <MarketNewPair>[
                  MarketNewPair(
                    poolRef: const MarketPoolAddressRef(s5PoolAddress),
                    dexId: 'four-meme',
                    name: 'YAMATA / BNB',
                    baseTokenAddress: s5Address,
                    quoteTokenAddress: marketZeroAddress,
                    registryAssetId: null,
                    createdAt: DateTime.utc(2026, 9, 8, 7, 30),
                    reserveUsd: s5Decimal('3696'),
                    volumeH24Usd: s5Decimal('1950'),
                  ),
                ],
              ),
              riskScreening: const LoopUnavailable(
                'MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED',
              ),
            ),
          ),
        ),
      );

      final row = find.byKey(
        ValueKey<String>('new-pair-address:$s5PoolAddress'),
      );
      await scrollToS5Section(tester, row);
      final widget = tester.widget<LoopRecordRow>(row);
      expect(widget.subtitle, startsWith('four.meme'));
      expect(widget.subtitle, isNot(contains('four-meme')));
      expect(widget.subtitle, isNot(contains('暂不支持')));
      expect(widget.subtitleMaxLines, 2);
      expect(find.text(marketBrowseOnlyLabel), findsOneWidget);
      // The mark takes two characters from the pool's name, never the name.
      expect(find.text('YA'), findsOneWidget);
      expect(_folios(tester).first.kicker, marketNewPairsKicker);
      expect(_folios(tester).first.stamp, marketNewPairsStamp);
    });

    testWidgets('a hero that has read nothing yet says so', (tester) async {
      await pumpS5Page(
        tester,
        const NewPairsScreen(),
        market: FakeMarketReadGateway(
          newPairs: S5Answer<MarketNewPairsPage>(pending: true),
        ),
        settle: false,
      );
      await tester.pump();

      // 「新币发现」 under a bar that already says 新币发现 is the page's own
      // name twice (walkthrough 2026-09-23, d05).
      expect(_folios(tester).first.heading, '正在读取新的池');
    });
  });
  group('logo · the contract, and the three hosts it may name', () {
    test('an available block yields its address', () {
      expect(
        LoopV2ChainCodec.logoUrl(<String, Object?>{
          'status': 'available',
          'url': 'https://dd.dexscreener.com/ds-data/tokens/bsc/0xab.png',
          'source': 'dexscreener',
          'observedAt': '2026-09-23T08:00:00.000Z',
        }),
        'https://dd.dexscreener.com/ds-data/tokens/bsc/0xab.png',
      );
      // Trust Wallet's rule URL is never probed, so it has no observation.
      expect(
        LoopV2ChainCodec.logoUrl(<String, Object?>{
          'status': 'available',
          'url':
              'https://raw.githubusercontent.com/trustwallet/assets/master/'
              'blockchains/smartchain/info/logo.png',
          'source': 'trustwallet',
          'observedAt': null,
        }),
        isNotNull,
      );
    });

    test('an unavailable block is a monogram, not a failure', () {
      expect(
        LoopV2ChainCodec.logoUrl(<String, Object?>{
          'status': 'unavailable',
          'reasonCode': 'TOKEN_LOGO_ADDRESS_UNKNOWN',
        }),
        isNull,
      );
    });

    test('a host the client will not fetch is the monogram (S96b)', () {
      for (final url in <String>[
        // Not one of the three hosts.
        'https://evil.example.com/a.png',
        // Plaintext.
        'http://dd.dexscreener.com/a.png',
        // Credentials in the authority.
        'https://u:p@dd.dexscreener.com/a.png',
        // A port.
        'https://dd.dexscreener.com:8443/a.png',
      ]) {
        expect(
          LoopV2ChainCodec.logoUrl(<String, Object?>{
            'status': 'available',
            'url': url,
            'source': 'dexscreener',
            'observedAt': null,
          }),
          isNull,
          reason: url,
        );
      }
    });

    test('a logo block outside the contract is an invalid payload', () {
      for (final body in <Map<String, Object?>>[
        // A source outside the contract's two.
        <String, Object?>{
          'status': 'available',
          'url': 'https://dd.dexscreener.com/a.png',
          'source': 'somewhere-else',
          'observedAt': null,
        },
        // An available block carrying a refusal, or the other way round.
        <String, Object?>{
          'status': 'available',
          'url': 'https://dd.dexscreener.com/a.png',
          'source': 'dexscreener',
          'reasonCode': 'TOKEN_LOGO_ADDRESS_UNKNOWN',
        },
        <String, Object?>{
          'status': 'unavailable',
          'url': 'https://dd.dexscreener.com/a.png',
          'reasonCode': 'TOKEN_LOGO_ADDRESS_UNKNOWN',
        },
        <String, Object?>{'status': 'sometimes'},
      ]) {
        expect(
          () => LoopV2ChainCodec.logoUrl(body),
          throwsA(isA<LoopBackendFailure>()),
          reason: '$body',
        );
      }
    });
  });
}

List<LoopFolioPrimary> _folios(WidgetTester tester) =>
    tester.widgetList<LoopFolioPrimary>(find.byType(LoopFolioPrimary)).toList();
