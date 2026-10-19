import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show CachingAssetBundle;
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
    // 61 sprites imported from the prototype plus ten drawn for LOOP:
    // `refresh`, `plus` / `share` for the top-bar words decision 0087
    // turned into glyphs, `copy` for the LOOP ID (decision 0104, S97b) and
    // the five message reactions (decision 0121, S121a) and `bolt` for the
    // MEME token page's 快买 key (decision 0174, S187-2).
    expect(LoopIconNames.all, hasLength(71));
    for (final name in <String>[
      'react-like',
      'react-laugh',
      'react-heart',
      'react-wow',
      'react-sad',
    ]) {
      expect(LoopIconNames.contains(name), isTrue, reason: name);
    }
    expect(LoopIconNames.contains('refresh'), isTrue);
    expect(LoopIconNames.contains('plus'), isTrue);
    expect(LoopIconNames.contains('share'), isTrue);
    expect(LoopIconNames.contains('copy'), isTrue);
    expect(
      Directory(LoopAssetPaths.icons)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.svg'))
          .length,
      71,
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
      LoopBrandAssets.officialIconWebp,
      LoopBrandAssets.appIconWebp,
      LoopBrandAssets.appIconSvg,
      LoopBrandAssets.wordmarkPng,
      LoopBrandAssets.wordmarkSvg,
      'assets/brand/2.0x/loop-wordmark-crown.png',
      'assets/brand/3.0x/loop-wordmark-crown.png',
      'assets/fonts/IBMPlexMono-Regular.ttf',
      'assets/fonts/IBMPlexMono-Medium.ttf',
      'assets/fonts/IBMPlexMono-SemiBold.ttf',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    expect(File('assets/fonts/NotoSansSC[wght].ttf').existsSync(), isFalse);
    // The proportional voice is the platform's own sans (decision 0080): no
    // display face ships with the app any more.
    expect(File('assets/fonts/Sora-Variable.ttf').existsSync(), isFalse);
    expect(File('assets/fonts/OFL-Sora.txt').existsSync(), isFalse);
  });

  group('S244 crown logo (decision 0205)', () {
    // PNG IHDR: width @16, height @20, bit depth @24, colour type @25.
    (int, int, int) header(String path) {
      final bytes = File(path).readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      return (data.getUint32(16), data.getUint32(20), bytes[25]);
    }

    test('brand marks are the crown tracing, not the retired marks', () {
      for (final retired in <String>[
        'assets/brand/loop-app-icon-u3d.webp',
        'assets/brand/loop-app-icon.svg',
        'assets/brand/loop-wordmark.svg',
      ]) {
        expect(File(retired).existsSync(), isFalse, reason: retired);
      }
      final logo = File(LoopBrandAssets.wordmarkSvg).readAsStringSync();
      expect(logo, contains('viewBox="0 0 480 310"'));
      expect(logo, contains('fill="#FDEB00"'));
      expect(logo, contains('fill="#FFFFFF"'));
      final square = File(LoopBrandAssets.appIconSvg).readAsStringSync();
      expect(square, contains('viewBox="0 0 1024 1024"'));
      expect(square, isNot(contains('<rect')));
      final webp = File(LoopBrandAssets.appIconWebp).readAsBytesSync();
      expect(String.fromCharCodes(webp.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(webp.sublist(8, 16)), 'WEBPVP8L');
      // Wordmark variants keep the 480:310 aspect at 1x / 2x / 3x.
      for (final (path, width) in <(String, int)>[
        (LoopBrandAssets.wordmarkPng, 240),
        ('assets/brand/2.0x/loop-wordmark-crown.png', 480),
        ('assets/brand/3.0x/loop-wordmark-crown.png', 720),
      ]) {
        final (w, h, type) = header(path);
        expect(
          (w, h, type),
          (width, (width * 310 / 480).round(), 6),
          reason: path,
        );
      }
    });

    testWidgets('flutter_svg parses both traced SVGs', (tester) async {
      for (final path in <String>[
        LoopBrandAssets.wordmarkSvg,
        LoopBrandAssets.appIconSvg,
      ]) {
        final info = await tester.runAsync(
          () => vg.loadPicture(
            SvgStringLoader(File(path).readAsStringSync()),
            null,
          ),
        );
        expect(info, isNotNull, reason: path);
        expect(info!.size.width, greaterThan(0), reason: path);
        info.picture.dispose();
      }
    });

    test('every iOS AppIcon slot is opaque and sized as declared', () {
      const set = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final manifest = jsonDecode(
        File('$set/Contents.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final images = (manifest['images'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(images, hasLength(19));
      for (final image in images) {
        final path = '$set/${image['filename']}';
        final points = double.parse((image['size'] as String).split('x')[0]);
        final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
        final pixels = (points * scale).round();
        // Colour type 2 = RGB, no alpha (App Store rejects alpha).
        expect(header(path), (pixels, pixels, 2), reason: path);
      }
    });

    test('launch frames carry the crown logo on Ink', () {
      for (final (scale, width) in <(String, int)>[
        ('', 160),
        ('@2x', 320),
        ('@3x', 480),
      ]) {
        final path =
            'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$scale.png';
        expect(header(path).$1, width, reason: path);
      }
      const res = 'android/app/src/main/res';
      for (final variant in <String>['drawable', 'drawable-v21']) {
        final xml = File('$res/$variant/launch_background.xml')
            .readAsStringSync();
        expect(xml, contains('@color/loop_ink'));
        expect(xml, contains('@drawable/launch_wordmark'));
      }
      for (final (bucket, width) in <(String, int)>[
        ('mdpi', 160),
        ('hdpi', 240),
        ('xhdpi', 320),
        ('xxhdpi', 480),
        ('xxxhdpi', 640),
      ]) {
        expect(
          header('$res/drawable-$bucket/launch_wordmark.png').$1,
          width,
          reason: bucket,
        );
        expect(header('$res/mipmap-$bucket/ic_launcher_round.png').$3, 6);
      }
      expect(
        File('$res/values-v31/styles.xml').readAsStringSync(),
        contains('@mipmap/ic_launcher_foreground'),
      );
      expect(
        File('$res/mipmap-anydpi-v26/ic_launcher_round.xml').existsSync(),
        isTrue,
      );
    });

    test('notification icon is a white crown silhouette on 24dp', () {
      final xml = File(
        'android/app/src/main/res/drawable/ic_loop_notification.xml',
      ).readAsStringSync();
      expect(xml, contains('android:viewportWidth="24"'));
      expect(xml, contains('android:fillColor="#FFFFFFFF"'));
      expect(xml, isNot(contains('strokeColor')));
    });

    test('web manifest grounds on Ink', () {
      final manifest = File('web/manifest.json').readAsStringSync();
      expect(manifest, contains('"background_color": "#050604"'));
      expect(manifest, contains('"theme_color": "#050604"'));
    });
  });

  group('S244b official square icon (decision 0207)', () {
    const res = 'android/app/src/main/res';
    const densities = <String, double>{
      'mdpi': 1,
      'hdpi': 1.5,
      'xhdpi': 2,
      'xxhdpi': 3,
      'xxxhdpi': 4,
    };

    (int, int, int) header(String path) {
      final bytes = File(path).readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      return (data.getUint32(16), data.getUint32(20), bytes[25]);
    }

    Future<(int, Uint8List)> rgba(WidgetTester tester, String path) async {
      final result = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          File(path).readAsBytesSync(),
        );
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData();
        final width = frame.image.width;
        frame.image.dispose();
        codec.dispose();
        return (width, data!.buffer.asUint8List());
      });
      return result!;
    }

    bool stroke(Uint8List p, int i) =>
        p[i + 3] > 128 && p[i] > 120 && p[i + 1] > 96 && p[i + 2] < p[i] * 0.6;

    double farthestStroke(int width, Uint8List p) {
      var r2 = 0.0;
      final c = width / 2;
      for (var i = 0; i < p.length; i += 4) {
        if (!stroke(p, i)) continue;
        final x = (i ~/ 4) % width + 0.5 - c;
        final y = (i ~/ 4) ~/ width + 0.5 - c;
        r2 = r2 > x * x + y * y ? r2 : x * x + y * y;
      }
      return r2 == 0 ? 0 : math.sqrt(r2);
    }

    test('login mark asset is a lossy WebP without alpha', () {
      final webp = File(LoopBrandAssets.officialIconWebp).readAsBytesSync();
      expect(String.fromCharCodes(webp.sublist(0, 4)), 'RIFF');
      // Simple-format VP8 carries no alpha chunk (VP8X would).
      expect(String.fromCharCodes(webp.sublist(8, 16)), 'WEBPVP8 ');
    });

    testWidgets('iOS AppIcon is the full-bleed artwork', (tester) async {
      const path =
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png';
      expect(header(path), (180, 180, 2));
      final (width, pixels) = await rgba(tester, path);
      // The vector mark kept its strokes inside r 36 %; the artwork runs
      // corner to corner, past r 50 %.
      expect(farthestStroke(width, pixels) / width, greaterThan(0.5));
    });

    testWidgets('adaptive foreground: transparent corners, strokes in the '
        '66dp safe circle', (tester) async {
      for (final MapEntry(key: bucket, value: density) in densities.entries) {
        final path = '$res/mipmap-$bucket/ic_launcher_foreground.png';
        final size = (108 * density).round();
        expect(header(path), (size, size, 6), reason: path);
        final (width, pixels) = await rgba(tester, path);
        for (final (x, y) in <(int, int)>[
          (0, 0),
          (width - 1, 0),
          (0, width - 1),
          (width - 1, width - 1),
        ]) {
          expect(pixels[(y * width + x) * 4 + 3], 0, reason: '$path $x,$y');
        }
        expect(
          farthestStroke(width, pixels) / density,
          lessThanOrEqualTo(33),
          reason: path,
        );
        expect(
          farthestStroke(width, pixels) / density,
          greaterThan(28),
          reason: '$path: the artwork should fill the safe circle',
        );
      }
    });

    testWidgets('adaptive background is opaque, text-free texture', (
      tester,
    ) async {
      for (final MapEntry(key: bucket, value: density) in densities.entries) {
        final path = '$res/mipmap-$bucket/ic_launcher_background.png';
        final size = (108 * density).round();
        expect(header(path), (size, size, 2), reason: path);
      }
      final (width, pixels) = await rgba(
        tester,
        '$res/mipmap-xxxhdpi/ic_launcher_background.png',
      );
      expect(farthestStroke(width, pixels), 0);
      for (final name in <String>['ic_launcher', 'ic_launcher_round']) {
        final xml = File('$res/mipmap-anydpi-v26/$name.xml').readAsStringSync();
        expect(xml, contains('@mipmap/ic_launcher_background'), reason: name);
        expect(xml, contains('@mipmap/ic_launcher_foreground'), reason: name);
      }
      for (final MapEntry(key: bucket, value: density) in densities.entries) {
        final legacy = (48 * density).round();
        expect(header('$res/mipmap-$bucket/ic_launcher.png'), (
          legacy,
          legacy,
          2,
        ));
      }
    });

    testWidgets('only the login mark takes the official artwork', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: <Widget>[
              LoopBrandMark(kind: LoopBrandMarkKind.officialIcon, height: 104),
              LoopBrandMark(kind: LoopBrandMarkKind.appIcon, height: 54),
            ],
          ),
        ),
      );
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(
        images.map((image) => (image.image as AssetImage).assetName),
        <String>[LoopBrandAssets.officialIconWebp, LoopBrandAssets.appIconWebp],
      );
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.borderRadius, BorderRadius.circular(104 * 0.225));
      final login = File('lib/features/account/privy_login_screen.dart')
          .readAsStringSync();
      expect(
        RegExp(r'LoopBrandMarkKind\.officialIcon').allMatches(login),
        hasLength(1),
      );
      for (final small in <String>[
        'lib/features/account/account_screens.dart',
        'lib/features/shell/loop_shell.dart',
        'lib/features/square/square_feed_view.dart',
      ]) {
        expect(
          File(small).readAsStringSync(),
          isNot(contains('LoopBrandMarkKind.officialIcon')),
          reason: small,
        );
      }
    });
  });

  test('every sprite is drawn to the one sheet specification', () {
    // The sheet is a single pen: one 24 box, no fill, and a stroke the caller
    // colours and sizes. A glyph that misses any of it would not inherit the
    // tone of the control it sits in, so a hand-drawn addition has to match
    // the imported ones exactly rather than approximately.
    for (final name in LoopIconNames.all) {
      final source = File(LoopAssetPaths.icon(name)).readAsStringSync();
      for (final attribute in <String>[
        'viewBox="0 0 24 24"',
        'fill="none"',
        'stroke="currentColor"',
        'stroke-width="1.7"',
        'stroke-linecap="round"',
        'stroke-linejoin="round"',
      ]) {
        expect(source, contains(attribute), reason: '$name · $attribute');
      }
    }
  });

  test('identity atlas slots mirror the prototype FX.media grid', () {
    expect(LoopIdentityAtlas.people.columns, 4);
    expect(LoopIdentityAtlas.people.rows, 3);
    // The community sheet is the one extension of the prototype's grid: the
    // server publishes twelve presets, so the atlas carries twelve cells.
    expect(LoopIdentityAtlas.communities.columns, 4);
    expect(LoopIdentityAtlas.communities.rows, 3);
    expect(LoopIdentitySlots.people, hasLength(12));
    expect(LoopIdentitySlots.communities, hasLength(12));

    final whale = LoopIdentityAtlas.people.slot('whale')!;
    expect((whale.column, whale.row, whale.fallback), (3, 1, 'WH'));
    final observer = LoopIdentityAtlas.people.slot('observer')!;
    expect((observer.column, observer.row), (3, 2));
    // The four prototype illustrations keep row 0, in catalog order.
    final mcat = LoopIdentityAtlas.communities.slot('mcat')!;
    expect((mcat.column, mcat.row, mcat.label), (3, 0, 'MOONCAT 社区图标'));
    final signal = LoopIdentityAtlas.communities.slot('community-12')!;
    expect((signal.column, signal.row), (3, 2));
    expect(LoopIdentitySlots.communityAliases['bonkcommunity'], 'bonk');

    final communityCells = LoopIdentitySlots.communities.values
        .map((slot) => (slot.column, slot.row))
        .toSet();
    expect(communityCells, hasLength(12));

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
      LoopIconRasters.debugReset();
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

      // The first sight of a glyph at a size is the vector sprite.
      final pictures = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
      expect(pictures, hasLength(2));
      expect(
        pictures.first.colorFilter,
        const ColorFilter.mode(LoopColors.lime, BlendMode.srcIn),
      );
      expect(pictures.first.width, 21);
      expect(find.bySemanticsLabel('Wallet'), findsOneWidget);
      expect(pictures.last.excludeFromSemantics, isTrue);

      // Decision 0101: once its raster exists the same glyph is drawn from
      // it, tinted by the same srcIn filter on the image draw — no layer.
      await tester.runAsync(
        () => Future.wait(<Future<Object?>>[
          LoopIconRasters.rasterize('wallet', 63),
          LoopIconRasters.rasterize('search', 63),
        ]),
      );
      await tester.pumpAndSettle();
      final rasters = tester.widgetList<RawImage>(find.byType(RawImage));
      expect(rasters, hasLength(2));
      expect(find.byType(SvgPicture), findsNothing);
      expect(rasters.first.color, LoopColors.lime);
      expect(rasters.first.colorBlendMode, BlendMode.srcIn);
      expect(rasters.first.width, 21);
      expect(rasters.first.image!.width, 63);
      expect(find.bySemanticsLabel('Wallet'), findsOneWidget);
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

  testWidgets(
    'identity avatar swaps the whole crop tree for a monogram on failure',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: DefaultAssetBundle(
            bundle: _ThrowingAssetBundle(),
            child: const Center(
              child: LoopIdentityAvatar(
                atlas: LoopIdentityAtlas.people,
                slot: 'whale',
                size: 56,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final monogram = find.byKey(
        const ValueKey<String>('loop-asset-monogram'),
      );
      expect(monogram, findsOneWidget);
      expect(find.text('WH'), findsOneWidget);
      expect(find.byType(FittedBox), findsNothing);
      final avatarRect = tester.getRect(find.byType(LoopIdentityAvatar));
      expect(tester.getRect(monogram), avatarRect);
      expect(avatarRect.size, const Size(56, 56));
      expect(find.bySemanticsLabel('whale_0x9f 头像'), findsOneWidget);
      semantics.dispose();
    },
  );

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
    // BONK is cell (2, 0) of the 4x3 community sheet.
    expect(aligns.last.widthFactor, closeTo(0.25, 0.0001));
    expect(aligns.last.heightFactor, closeTo(1 / 3, 0.0001));
    final bonk = aligns.last.alignment as Alignment;
    expect(bonk.x, closeTo(1 / 3, 0.0001));
    expect(bonk.y, -1);

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

final class _ThrowingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('asset unavailable in test: $key');
  }
}
