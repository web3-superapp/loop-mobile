// S367 · 去掉全局涂鸦氛围背景 (client decision 0291, 需求方 2026-11-05 第 5
// 条): the wall, its fogs, the crown behind a title, the chip splat and the
// MEME glow are gone with their files; every tab stands on plain Ink. The
// chosen tab's Purple doodle and the banner's chrome hand stay.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_atmosphere.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_title_doodle.dart';

import 'support/authenticated_test_privy_gateway.dart';

/// The files decision 0291 deleted.
const _gone = <String>[
  'assets/brand/atmo-wall.webp',
  'assets/brand/atmo-spray-purple.png',
  'assets/brand/atmo-spray-yellow.png',
  'assets/brand/atmo-crown-wall.png',
  'assets/brand/atmo-splat-yellow.png',
  'assets/figma/ambient-glow.svg',
];

String _base(String path) => path.split('/').last.split('.').first;

final class _EmptySpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  const _EmptySpotMarketRepository();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async =>
      HyperliquidSpotSnapshot(
        receivedAt: DateTime.utc(2026, 9, 2),
        markets: const <HyperliquidSpotMarket>[],
      );
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
          const _EmptySpotMarketRepository(),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every asset name an image, a decoration or an SVG on screen asks for.
Set<String> _assetsOnScreen(WidgetTester tester) {
  final names = <String>{};
  void add(ImageProvider<Object>? image) {
    if (image is AssetImage) names.add(image.assetName);
    if (image is ResizeImage) add(image.imageProvider);
  }

  for (final widget in tester.allWidgets) {
    if (widget is Image) add(widget.image);
    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) add(decoration.image?.image);
    }
    if (widget is Container) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) add(decoration.image?.image);
    }
    if (widget is SvgPicture) {
      final loader = widget.bytesLoader;
      if (loader is SvgAssetLoader) names.add(loader.assetName);
    }
  }
  return names;
}

void main() {
  test('the background pieces are gone from the asset list and the disk', () {
    for (final path in _gone) {
      expect(File(path).existsSync(), isFalse, reason: path);
      expect(LoopAtmoAssets.all, isNot(contains(path)));
    }
    expect(loopAtmosphereTabAssets, isEmpty);
    // What is content stays.
    expect(LoopAtmoAssets.all, contains(LoopAtmoAssets.handChrome));
    expect(File(LoopAtmoAssets.handChrome).existsSync(), isTrue);
    expect(File(LoopFigmaAssets.titleDoodle).existsSync(), isTrue);
    expect(File(LoopBrandAssets.wordmarkPng).existsSync(), isTrue);
  });

  test('no file under lib names a deleted piece', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final path in _gone) {
        if (source.contains(_base(path))) offenders.add(entity.path);
      }
      for (final name in <String>[
        'LoopAtmoAssets.wall',
        'LoopAtmoAssets.spray',
        'LoopAtmoAssets.crownWall',
        'LoopAtmoAssets.splatYellow',
      ]) {
        if (source.contains(name)) offenders.add('${entity.path} · $name');
      }
    }
    expect(offenders, isEmpty);
  });

  testWidgets('the wall paints Ink alone; the crown and the splat draw '
      'nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const SizedBox(
                height: 200,
                child: LoopWallBackdrop(
                  fog: LoopWallFog.chat,
                  keyPrefix: 'probe',
                ),
              ),
              const LoopTitleCrown(
                crownKey: ValueKey<String>('probe-crown'),
                child: Text('Title'),
              ),
              loopSplatted(
                const Text('Chosen'),
                key: const ValueKey<String>('probe-splat'),
              ),
              const SizedBox(height: 120, child: Launch2AtmosphereBackdrop()),
            ],
          ),
        ),
      ),
    );
    final ground = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('probe-wall')),
    );
    expect(ground.color, LoopColors.ink);
    expect(find.byKey(const ValueKey<String>('probe-crown')), findsNothing);
    expect(find.byKey(const ValueKey<String>('probe-splat')), findsNothing);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Chosen'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('launch2-atmo-glow')),
      findsNothing,
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byType(SvgPicture), findsNothing);
    expect(_assetsOnScreen(tester), isEmpty);
  });

  testWidgets('the five tabs stand on Ink: no wall, fog, title crown, splat '
      'or glow; the chosen tab keeps its Purple doodle', (tester) async {
    await _pumpApp(tester);
    final tabs = tester
        .widgetList<LoopTabItem>(find.byType(LoopTabItem))
        .map((tab) => tab.label)
        .toList();
    expect(tabs, hasLength(5));
    for (final label in tabs) {
      await tester.tap(find.widgetWithText(LoopTabItem, label));
      await tester.pumpAndSettle();
      final assets = _assetsOnScreen(tester);
      for (final asset in assets) {
        expect(_gone, isNot(contains(asset)), reason: '$label · $asset');
      }
      for (final key in <String>[
        'chat-atmo-title-crown',
        'square-atmo-title-crown',
        'intel-atmo-title-crown',
        'wallet-atmo-title-crown',
        'launch2-atmo-title-crown',
        'launch2-atmo-glow',
        'loop-seg-splat',
        'loop-spray-heading-splat',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing, reason: label);
      }
      // Whatever backdrop the page hangs is plain Ink.
      for (final wall in tester.widgetList<LoopWallBackdrop>(
        find.byType(LoopWallBackdrop),
      )) {
        final ground = tester.widget<ColoredBox>(
          find.byKey(ValueKey<String>('${wall.keyPrefix}-wall')).first,
        );
        expect(ground.color, LoopColors.ink, reason: label);
      }
    }
    expect(find.byType(LoopTitleDoodle), findsWidgets);
  });
}
