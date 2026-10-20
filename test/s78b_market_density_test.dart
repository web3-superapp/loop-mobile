import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_media_image.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

void main() {
  loopWatchGround();

  // Decision 0171 (docs/33 L7): the unmounted 行情 tile and its change
  // block were deleted with their density tests; the mark tests below cover
  // the logo the live rows share.

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
        (resized.imageProvider as LoopMediaImage).url,
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
