import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

void main() {
  test('every registered asset file exists on disk', () {
    for (final name in LoopIconNames.all) {
      expect(
        File(LoopAssetPaths.icon(name)).existsSync(),
        isTrue,
        reason: name,
      );
    }
    expect(LoopIconNames.all, hasLength(61));
    expect(
      Directory(LoopAssetPaths.icons)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.svg'))
          .length,
      61,
    );
    for (final file in LoopTokenAssets.bySymbol.values) {
      expect(
        File(LoopAssetPaths.token(file)).existsSync(),
        isTrue,
        reason: file,
      );
    }
    expect(
      File(LoopAssetPaths.token(LoopTokenAssets.fallback)).existsSync(),
      isTrue,
    );
    for (final file in LoopNetworkAssets.byId.values.toSet()) {
      expect(
        File(LoopAssetPaths.network(file)).existsSync(),
        isTrue,
        reason: file,
      );
    }
    for (final path in <String>[
      LoopAssetPaths.people,
      LoopAssetPaths.communities,
      LoopBrandAssets.appIconWebp,
      LoopBrandAssets.appIconSvg,
      LoopBrandAssets.wordmarkWebp,
      LoopBrandAssets.wordmarkSvg,
      'assets/fonts/Sora-Variable.ttf',
      'assets/fonts/IBMPlexMono-Regular.ttf',
      'assets/fonts/IBMPlexMono-Medium.ttf',
      'assets/fonts/IBMPlexMono-SemiBold.ttf',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    expect(File('assets/fonts/NotoSansSC[wght].ttf').existsSync(), isFalse);
  });

  test('identity atlas slots mirror the prototype FX.media grid', () {
    expect(LoopIdentityAtlas.people.columns, 4);
    expect(LoopIdentityAtlas.people.rows, 3);
    expect(LoopIdentityAtlas.communities.columns, 2);
    expect(LoopIdentityAtlas.communities.rows, 2);
    expect(LoopIdentitySlots.people, hasLength(12));
    expect(LoopIdentitySlots.communities, hasLength(4));

    final whale = LoopIdentityAtlas.people.slot('whale')!;
    expect((whale.column, whale.row, whale.fallback), (3, 1, 'WH'));
    final observer = LoopIdentityAtlas.people.slot('observer')!;
    expect((observer.column, observer.row), (3, 2));
    final mcat = LoopIdentityAtlas.communities.slot('mcat')!;
    expect((mcat.column, mcat.row, mcat.label), (1, 1, 'MOONCAT 社区图标'));
    expect(LoopIdentitySlots.communityAliases['bonkcommunity'], 'bonk');

    final cells = LoopIdentitySlots.people.values
        .map((slot) => (slot.column, slot.row))
        .toSet();
    expect(cells, hasLength(12));
  });

  test('monogram keeps two characters and never returns empty', () {
    expect(loopMonogram('pepe'), 'PE');
    expect(loopMonogram('ETH'), 'ET');
    expect(loopMonogram('x'), 'X');
    expect(loopMonogram('0xSable'), '0X');
    expect(loopMonogram('   '), '·');
  });

  testWidgets(
    'LoopIcon renders the sprite with a colour filter and semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Row(
            children: <Widget>[
              LoopIcon(
                'wallet',
                color: LoopColors.lime,
                semanticLabel: 'Wallet',
              ),
              LoopIcon('search'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pictures = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
      expect(pictures, hasLength(2));
      expect(
        pictures.first.colorFilter,
        const ColorFilter.mode(LoopColors.lime, BlendMode.srcIn),
      );
      expect(pictures.first.width, 21);
      expect(find.bySemanticsLabel('Wallet'), findsOneWidget);
      expect(pictures.last.excludeFromSemantics, isTrue);
      semantics.dispose();
    },
  );

  testWidgets('token and network logos fall back to a labelled monogram', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const Row(
          children: <Widget>[
            LoopTokenLogo(assetSymbol: 'USDC'),
            LoopTokenLogo(assetSymbol: 'GLYPH'),
            LoopTokenLogo(assetSymbol: 'ZZ', fallbackMonogram: 'Z'),
            LoopNetworkLogo(network: 'bsc'),
            LoopNetworkLogo(network: 'aptos'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey<String>('loop-asset-monogram')),
      findsNWidgets(3),
    );
    expect(find.text('GL'), findsOneWidget);
    expect(find.text('Z'), findsOneWidget);
    expect(find.text('AP'), findsOneWidget);
    expect(find.bySemanticsLabel('GLYPH logo'), findsOneWidget);
    expect(find.bySemanticsLabel('aptos network'), findsOneWidget);
    expect(find.bySemanticsLabel('USDC logo'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('identity avatar crops the atlas cell and labels the image', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const Row(
          children: <Widget>[
            LoopIdentityAvatar(atlas: LoopIdentityAtlas.people, slot: 'whale'),
            LoopIdentityAvatar(
              atlas: LoopIdentityAtlas.communities,
              slot: 'BonkCommunity',
              size: 48,
            ),
            LoopIdentityAvatar(atlas: LoopIdentityAtlas.people, slot: 'nobody'),
          ],
        ),
      ),
    );
    await tester.pump();

    final aligns = tester.widgetList<Align>(
      find.byWidgetPredicate(
        (widget) => widget is Align && widget.widthFactor != null,
      ),
    );
    expect(aligns, hasLength(2));
    expect(aligns.first.widthFactor, closeTo(0.25, 0.0001));
    expect(aligns.first.heightFactor, closeTo(1 / 3, 0.0001));
    expect(aligns.first.alignment, const Alignment(1, 0));
    expect(aligns.last.widthFactor, 0.5);
    expect(aligns.last.alignment, const Alignment(-1, 1));

    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.map((image) => (image.image as AssetImage).assetName),
      <String>[LoopAssetPaths.people, LoopAssetPaths.communities],
    );
    expect(find.bySemanticsLabel('whale_0x9f 头像'), findsOneWidget);
    expect(find.bySemanticsLabel('BONK Community 社区图标'), findsOneWidget);
    expect(find.text('NO'), findsOneWidget);
    expect(find.bySemanticsLabel('nobody 头像'), findsOneWidget);
    semantics.dispose();
  });
}
