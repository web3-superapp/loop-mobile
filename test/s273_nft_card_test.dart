// S273 · decision 0232: 需求方 「NFT 应该展示图片吧」. The project NFT is a
// picture card everywhere it is shown — the wallet's 「NFT」 grid, the centre
// of the 共识勋章 medal and the mint confirm sheet — with the logo as its face
// or, without one, the MEME banner's default art. Never a two-letter
// monogram.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_card.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _logo = 'https://cdn.example.com/frog.png';
const String _nftImage = 'https://cdn.example.com/frog-nft.png';
const String _accepted = 'https://raw.githubusercontent.com/loop/nft/frog.png';

String? _noMedia(String mediaId) => null;

/// A picture still downloading: it never arrives within the test.
final class _Pending extends ImageProvider<_Pending> {
  const _Pending(this.url);

  final String url;

  @override
  Future<_Pending> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_Pending>(this);

  @override
  ImageStreamCompleter loadImage(_Pending key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);

  @override
  bool operator ==(Object other) => other is _Pending && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Answers `me/positions` only.
final class _Positions implements Launch2Gateway {
  _Positions(this.positions);

  final Launch2Positions positions;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Positions> loadPositions() async => positions;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

LoopV2MetaSnapshot _metaWithLaunch2() {
  final base = s5MetaSnapshot();
  final launch2 = LoopV2Capability(
    id: LoopV2CapabilityId.launch2,
    availability: LoopV2CapabilityAvailability.available,
    reasonCode: null,
    evidence: const LoopV2CapabilityEvidence(
      status: LoopV2CapabilityEvidenceStatus.notApplicable,
      reasonCode: null,
    ),
  );
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: base.capabilities.contractVersion,
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id != LoopV2CapabilityId.launch2) capability,
        launch2,
      ],
    ),
  );
}

/// The fixture's FROG position, again under [id] / [ticker] / [logoUrl].
Launch2Position _position({
  required String id,
  required String ticker,
  String? logoUrl,
  String? nftImageUrl,
  int held = 1,
  int? tokenId = 1,
  Launch2Stage stage = Launch2Stage.public,
}) {
  final base = l2Positions().items.single;
  return Launch2Position(
    instanceId: id,
    name: base.name,
    ticker: ticker,
    logoUrl: logoUrl,
    nftImageUrl: nftImageUrl,
    memeAddress: base.memeAddress,
    stage: stage,
    walletId: base.walletId,
    nftHeld: held,
    snapshotMember: true,
    curve: base.curve,
    mintedTokenId: tokenId == null ? null : BigInt.from(tokenId),
  );
}

Future<void> _pumpBare(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

/// No monogram anywhere: neither a [MemeLogo] nor its two letters.
void _noInitials(WidgetTester tester, String ticker) {
  expect(find.byType(MemeLogo), findsNothing);
  expect(find.text(ticker.substring(0, 2)), findsNothing);
}

void main() {
  loopWatchGround();

  group('Launch2NftCard faces', () {
    testWidgets('with a logo: the logo fills the card, shade, ticker, #id', (
      tester,
    ) async {
      await _pumpBare(
        tester,
        Launch2NftCard(
          ticker: 'FROG',
          logoUrl: _logo,
          tokenId: BigInt.from(7),
          size: 180,
        ),
      );
      final logo = tester.widget<Image>(_key('launch2-nft-card-logo'));
      expect(logo.fit, BoxFit.cover);
      expect(_key('launch2-nft-card-logo-face'), findsOneWidget);
      expect(_key('launch2-nft-card-shade'), findsOneWidget);
      expect(
        tester.getSize(_key('launch2-nft-card-shade')).height,
        closeTo(180 * 0.45, 0.01),
      );
      expect(_key('launch2-nft-card-ring'), findsOneWidget);
      final ticker = tester.widget<Text>(
        find.descendant(
          of: _key('launch2-nft-card-logo-face'),
          matching: _key('launch2-nft-card-ticker'),
        ),
      );
      expect(ticker.data, 'FROG');
      expect(ticker.style?.fontSize, LoopType.headline.fontSize);
      final id = tester.widget<Text>(
        find.descendant(
          of: _key('launch2-nft-card-logo-face'),
          matching: _key('launch2-nft-card-id'),
        ),
      );
      expect(id.data, '#7');
      expect(id.style?.color, LoopColors.yellow);
      expect(tester.getSize(_key('launch2-nft-card')), const Size(180, 180));
      _noInitials(tester, 'FROG');
    });

    testWidgets('without a logo: the banner art, the ticker big, #id under', (
      tester,
    ) async {
      await _pumpBare(
        tester,
        Launch2NftCard(ticker: 'PEPE', tokenId: BigInt.from(12), size: 180),
      );
      expect(_key('launch2-nft-card-default-art'), findsOneWidget);
      expect(_key('launch2-nft-card-logo'), findsNothing);
      expect(_key('launch2-nft-card-shade'), findsNothing);
      final ticker = tester.widget<Text>(_key('launch2-nft-card-ticker'));
      expect(ticker.data, 'PEPE');
      expect(ticker.style?.fontSize, LoopType.title1.fontSize);
      final id = tester.widget<Text>(_key('launch2-nft-card-id'));
      expect(id.data, '#12');
      expect(
        tester.getTopLeft(_key('launch2-nft-card-id')).dy,
        greaterThan(tester.getTopLeft(_key('launch2-nft-card-ticker')).dy),
      );
      // The art is the banner's pieces, still: no sheen anywhere.
      final assets = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image)
          .whereType<AssetImage>()
          .map((image) => image.assetName)
          .toSet();
      expect(assets, containsAll(launch2NftCardAssets.skip(1)));
      expect(_key('launch2-atmo-hand-sheen'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      _noInitials(tester, 'PEPE');
    });

    testWidgets('a thumbnail drops the #id and keeps no monogram', (
      tester,
    ) async {
      await _pumpBare(
        tester,
        Launch2NftCard(ticker: 'PEPE', tokenId: BigInt.from(12), size: 64),
      );
      expect(_key('launch2-nft-card-default-art'), findsOneWidget);
      expect(_key('launch2-nft-card-id'), findsNothing);
      expect(find.text('PEPE'), findsOneWidget);
      _noInitials(tester, 'PEPE');
    });
  });

  group('wallet NFT tab', () {
    testWidgets('a two-column grid of cards; a card opens 共识勋章', (
      tester,
    ) async {
      final opened = <String>[];
      final positions = Launch2Positions(
        items: <Launch2Position>[
          _position(id: 'inst-a', ticker: 'FROG', logoUrl: _logo),
          _position(id: 'inst-b', ticker: 'PEPE', held: 2, tokenId: 9),
          _position(
            id: 'inst-d',
            ticker: 'MOON',
            nftImageUrl: _nftImage,
            logoUrl: _logo,
          ),
          _position(
            id: 'inst-c',
            ticker: 'DOGE',
            stage: Launch2Stage.priority,
            tokenId: null,
          ),
        ],
      );
      await pumpS5Page(
        tester,
        WalletScreen(onNavigate: opened.add),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(value: s5Balances()),
        ),
        meta: _metaWithLaunch2(),
        overrides: <Override>[
          launch2GatewayProvider.overrideWithValue(_Positions(positions)),
        ],
      );
      await tester.ensureVisible(_key('wallet-asset-tab-nft'));
      await tester.tap(_key('wallet-asset-tab-nft'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_key('launch2-nft-grid'), findsOneWidget);
      expect(find.byType(Launch2NftCard), findsNWidgets(4));
      expect(
        tester
            .widget<Launch2NftCard>(
              find.descendant(
                of: _key('launch2-wallet-nft-inst-d'),
                matching: find.byType(Launch2NftCard),
              ),
            )
            .pictureUrls,
        <String>[_nftImage, _logo],
      );
      final a = tester.getRect(_key('launch2-wallet-nft-inst-a'));
      final b = tester.getRect(_key('launch2-wallet-nft-inst-b'));
      final c = tester.getRect(_key('launch2-wallet-nft-inst-d'));
      // Two to a row, a 12 gutter across and down, equal columns.
      expect(b.top, a.top);
      expect(b.left - a.right, closeTo(LoopSpacing.rowGap, 0.01));
      expect(a.width, closeTo(b.width, 0.01));
      expect(c.left, a.left);
      expect(c.top - a.bottom, closeTo(LoopSpacing.rowGap, 0.01));
      // Square cards, the logo face only where there is a logo.
      final cards = tester.getRect(
        find.descendant(
          of: _key('launch2-wallet-nft-inst-a'),
          matching: _key('launch2-nft-card'),
        ),
      );
      expect(cards.width, closeTo(cards.height, 0.01));
      expect(
        find.descendant(
          of: _key('launch2-wallet-nft-inst-a'),
          matching: _key('launch2-nft-card-logo'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('launch2-wallet-nft-inst-b'),
          matching: _key('launch2-nft-card-default-art'),
        ),
        findsOneWidget,
      );
      // The two lines under each card.
      expect(find.text('FROG NFT'), findsOneWidget);
      expect(find.text('×1 · 公开内盘'), findsNWidgets(2));
      expect(find.text('×2 · 公开内盘'), findsOneWidget);
      expect(find.text('×1 · 提前购'), findsOneWidget);
      expect(find.text('#9'), findsOneWidget);
      final name = tester.widget<Text>(find.text('PEPE NFT'));
      expect(name.style?.fontSize, LoopType.body1.fontSize);
      expect(_key('wallet-nft-provenance'), findsOneWidget);
      expect(find.byType(MemeLogo), findsNothing);

      await tester.ensureVisible(_key('launch2-wallet-nft-inst-b'));
      await tester.tap(_key('launch2-wallet-nft-inst-b'));
      expect(opened.last, Launch2Route.nft('inst-b'));
    });
  });

  group('共识勋章', () {
    testWidgets('the medal centre is the picture, ring and arcs kept', (
      tester,
    ) async {
      await _pumpBare(
        tester,
        const Launch2NftMedal(
          key: ValueKey<String>('medal'),
          ticker: 'FROG',
          logoUrl: _logo,
          bottomLabel: '#3',
          lit: true,
        ),
      );
      expect(tester.getSize(_key('medal')), const Size(200, 200));
      final picture = tester.widget<Launch2NftCard>(
        _key('launch2-nft-medal-picture'),
      );
      expect(picture.shape, Launch2NftCardShape.medal);
      expect(picture.logoUrl, _logo);
      expect(
        tester.getSize(_key('launch2-nft-medal-picture')),
        const Size(134, 134),
      );
      expect(
        tester.getCenter(_key('launch2-nft-medal-picture')),
        tester.getCenter(_key('medal')),
      );
      expect(
        find.descendant(
          of: _key('launch2-nft-medal-picture'),
          matching: find.byType(ClipOval),
        ),
        findsOneWidget,
      );
      // The medal's own ring and words stay on the arcs: no overlay words.
      expect(_key('launch2-nft-card-shade'), findsNothing);
      expect(_key('launch2-nft-card-id'), findsNothing);
      _noInitials(tester, 'FROG');
    });

    testWidgets('no logo: the default art with the ticker in the centre', (
      tester,
    ) async {
      await _pumpBare(
        tester,
        const Launch2NftMedal(ticker: 'PEPE', bottomLabel: '共识勋章', lit: false),
      );
      expect(_key('launch2-nft-card-default-art'), findsOneWidget);
      expect(
        tester.getCenter(_key('launch2-nft-card-ticker')).dx,
        closeTo(tester.getCenter(_key('launch2-nft-medal-picture')).dx, 0.5),
      );
      _noInitials(tester, 'PEPE');
    });
  });

  group('mint confirm sheet', () {
    testWidgets('a 64 card at the top shows what is minted', (tester) async {
      await _pumpBare(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showLaunch2NftConfirmSheet(
              context,
              ticker: 'FROG',
              priceLabel: '100 USD1',
              logoUrl: _logo,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(_key('launch2-nft-confirm'), findsOneWidget);
      expect(
        tester.getSize(_key('launch2-nft-confirm-card')),
        const Size(64, 64),
      );
      final card = tester.widget<Launch2NftCard>(
        _key('launch2-nft-confirm-card'),
      );
      expect(card.logoUrl, _logo);
      expect(card.ticker, 'FROG');
      // Above the price.
      expect(
        tester.getTopLeft(_key('launch2-nft-confirm-card')).dy,
        lessThan(tester.getTopLeft(find.text('价格')).dy),
      );
      _noInitials(tester, 'FROG');
    });

    testWidgets('no logo: the thumbnail is the default art', (tester) async {
      await _pumpBare(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showLaunch2NftConfirmSheet(
              context,
              ticker: 'PEPE',
              priceLabel: '100 USD1',
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('launch2-nft-confirm-card'),
          matching: _key('launch2-nft-card-default-art'),
        ),
        findsOneWidget,
      );
      _noInitials(tester, 'PEPE');
    });
  });

  group('nftImageUrl (S274 key, client first)', () {
    Map<String, Object?> withKey(
      Map<String, Object?> map,
      Object? value, {
      bool present = true,
    }) => <String, Object?>{...map, if (present) 'nftImageUrl': value};

    Launch2InstanceRow row(Object? value, {bool present = true}) =>
        LoopV2Launch2Codec.page(
          l2PageJson(<Map<String, Object?>>[
            withKey(l2RowJson(), value, present: present),
          ]),
          mediaUrl: _noMedia,
        ).items.single;

    Launch2InstanceRow detailRow(Object? value, {bool present = true}) {
      final json = l2DetailJson();
      final instance = json['instance']! as Map<String, Object?>;
      return LoopV2Launch2Codec.detail(<String, Object?>{
        ...json,
        'instance': withKey(instance, value, present: present),
      }, mediaUrl: _noMedia).row;
    }

    Launch2Position position(Object? value, {bool present = true}) {
      final json = l2PositionsJson();
      final rows = json['positions']! as List<Object?>;
      return LoopV2Launch2Codec.positions(<String, Object?>{
        ...json,
        'positions': <Object?>[
          withKey(
            rows.single! as Map<String, Object?>,
            value,
            present: present,
          ),
        ],
      }, mediaUrl: _noMedia).items.single;
    }

    test('a list row reads it; absent, null or junk is none', () {
      expect(row(_accepted).nftImageUrl, _accepted);
      expect(row(null, present: false).nftImageUrl, isNull);
      expect(row(null).nftImageUrl, isNull);
      expect(row(42).nftImageUrl, isNull);
      expect(row('').nftImageUrl, isNull);
      expect(row('http://evil.example/x.png').nftImageUrl, isNull);
    });

    test('the detail reads it; absent or null is none', () {
      expect(detailRow(_accepted).nftImageUrl, _accepted);
      expect(detailRow(null, present: false).nftImageUrl, isNull);
      expect(detailRow(null).nftImageUrl, isNull);
    });

    test('a position reads it; absent, null or junk is none', () {
      expect(position(_accepted).nftImageUrl, _accepted);
      expect(position(null, present: false).nftImageUrl, isNull);
      expect(position(null).nftImageUrl, isNull);
      expect(position(<String, Object?>{}).nftImageUrl, isNull);
    });
  });

  group('picture priority: nftImageUrl → logoUrl → default art', () {
    test('the order the card tries', () {
      expect(
        const Launch2NftCard(
          ticker: 'FROG',
          nftImageUrl: _nftImage,
          logoUrl: _logo,
        ).pictureUrls,
        <String>[_nftImage, _logo],
      );
      expect(
        const Launch2NftCard(ticker: 'FROG', logoUrl: _logo).pictureUrls,
        <String>[_logo],
      );
      expect(const Launch2NftCard(ticker: 'FROG').pictureUrls, isEmpty);
    });

    testWidgets('the NFT picture is asked for first, the logo not at all', (
      tester,
    ) async {
      final asked = <String>[];
      debugLoopRemoteAvatarImageProvider = (url) {
        asked.add(url);
        return _Pending(url);
      };
      addTearDown(() => debugLoopRemoteAvatarImageProvider = null);
      await _pumpBare(
        tester,
        const Launch2NftCard(
          ticker: 'FROG',
          nftImageUrl: _nftImage,
          logoUrl: _logo,
          size: 180,
        ),
      );
      expect(asked, <String>[_nftImage]);
      // Loading: the default art without its own words, the face's words on
      // the bottom — never a monogram.
      expect(_key('launch2-nft-card-default-art'), findsOneWidget);
      expect(find.text('FROG'), findsOneWidget);
      _noInitials(tester, 'FROG');
    });

    testWidgets('an NFT picture that fails falls back to the logo', (
      tester,
    ) async {
      final asked = <String>[];
      debugLoopRemoteAvatarImageProvider = (url) {
        asked.add(url);
        return MemoryImage(Uint8List.fromList(<int>[0, 1, 2, 3]));
      };
      addTearDown(() => debugLoopRemoteAvatarImageProvider = null);
      await _pumpBare(
        tester,
        const Launch2NftCard(
          ticker: 'FROG',
          nftImageUrl: _nftImage,
          logoUrl: _logo,
          size: 180,
        ),
      );
      for (var i = 0; i < 2; i += 1) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(asked, <String>[_nftImage, _logo]);
      expect(_key('launch2-nft-card-default-art'), findsOneWidget);
      _noInitials(tester, 'FROG');
    });

    testWidgets('the medal and the sheet pass the NFT picture through', (
      tester,
    ) async {
      await _pumpBare(
        tester,
        const Launch2NftMedal(
          ticker: 'FROG',
          nftImageUrl: _nftImage,
          logoUrl: _logo,
          bottomLabel: '#3',
          lit: true,
        ),
      );
      expect(
        tester
            .widget<Launch2NftCard>(_key('launch2-nft-medal-picture'))
            .pictureUrls,
        <String>[_nftImage, _logo],
      );
      await _pumpBare(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showLaunch2NftConfirmSheet(
              context,
              ticker: 'FROG',
              priceLabel: '100 USD1',
              nftImageUrl: _nftImage,
              logoUrl: _logo,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Launch2NftCard>(_key('launch2-nft-confirm-card'))
            .pictureUrls,
        <String>[_nftImage, _logo],
      );
    });
  });
}
