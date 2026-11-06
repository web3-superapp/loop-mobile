// S379 · decision 0303 (需求方 11-06):
// 1. 我的's wallet block — 总资产 through the five keys — stands on one card
//    (12 corner, white 3 %, 1 px cardEdge, 16 inside, the page's 20 either
//    side, 16 above and under), amending 0280's 「no plate」.
// 2. The chart periods are 12 / 400 (idle) and 12 / 500 (chosen), never
//    bold; Candles / MA / VOL keep the 13 chip step.
// 3. The MEME detail head: the whole name (three lines, then one step
//    smaller, never ellipsed), and 「ticker | address + copy」 with the stage
//    capsule flush right on one line.
// 4. The wallet card leans toward the finger (LoopTiltCard).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_parts.dart';
import 'package:loop_mobile/features/market/loop_chart_toolbar.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_tilt_card.dart';

import 'support/launch2_fixtures.dart';
import 'support/me_page_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

final Finder _card = find.byKey(walletTotalCardKey);

final class _Week implements WalletNetWorthHistoryGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopNetWorthHistory> loadNetWorthHistory(
    String walletId,
    LoopNetWorthRange range,
  ) async => LoopNetWorthHistory(
    range: range,
    points: <LoopNetWorthPoint>[
      for (var index = 0; index < 7; index++)
        LoopNetWorthPoint(
          at: DateTime.utc(2026, 10, 8 + index),
          netWorthUsd: Decimal.fromInt(5000 + index * 200),
        ),
    ],
    change24h: LoopNetWorthChangeAvailable(
      usd: Decimal.parse('12.08'),
      pct: Decimal.parse('1.2'),
    ),
  );
}

Matrix4 _tilt(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(LoopTiltCard.transformKey)).transform;

/// The period's (or switch's) drawn word.
TextStyle _word(WidgetTester tester, Finder chip) => tester
    .widget<RichText>(
      find.descendant(of: chip, matching: find.byType(RichText)).first,
    )
    .text
    .style!;

Future<void> _host(WidgetTester tester, Widget child, {double width = 390}) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void main() {
  group('我的 · the wallet card', () {
    testWidgets('one card: 12 corner, white 3 %, 1 px cardEdge, 16 inside', (
      tester,
    ) async {
      await pumpMePage(tester, size: const Size(390, 1400));
      expect(_key('wallet-total-plate'), findsOneWidget);
      expect(_key('wallet-folio'), findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(_card).decoration as BoxDecoration;
      expect(decoration.color, LoopColors.white3);
      expect(decoration.borderRadius, LoopRadius.card);
      expect(LoopRadius.cardValue, 12);
      final border = decoration.border! as Border;
      expect(border.top.color, LoopColors.cardEdge);
      expect(border.top.width, 1);
      expect(
        tester.widget<Padding>(find.byKey(walletTotalCardInsetKey)).padding,
        const EdgeInsets.all(16),
      );
      // The page's 20 either side.
      final card = tester.getRect(_card);
      expect(card.left, LoopSpacing.page);
      expect(card.right, 390 - LoopSpacing.page);
      // 总资产 and the five keys are inside it.
      for (final key in <String>[
        'wallet-total-figure',
        'wallet-eye',
        'wallet-manage-action',
        'wallet-quick-actions',
        'wallet-receive-entry',
        'wallet-pay-entry',
        'wallet-dapp-entry',
      ]) {
        expect(
          find.descendant(of: _card, matching: _key(key)),
          findsOneWidget,
          reason: key,
        );
      }
      // The label starts 16 inside the card's edge.
      expect(tester.getRect(_key('wallet-total-figure')).left, card.left + 16);
      expect(
        tester.getRect(_key('wallet-quick-actions')).bottom,
        card.bottom - 16,
      );
    });

    testWidgets('16 under the follow line and 16 over the section tabs', (
      tester,
    ) async {
      await pumpMePage(tester, size: const Size(390, 1400));
      final card = tester.getRect(_card);
      final person = tester.getRect(_key('profile-identity-card'));
      expect(card.top - person.bottom, closeTo(16, 0.01));
      final sections = tester.getRect(_key('me-sections'));
      // The bar's own room above its strip is the 16.
      expect(sections.top, closeTo(card.bottom, 0.01));
      final strip = find.descendant(
        of: _key('me-sections'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == const EdgeInsets.only(top: 16),
        ),
      );
      expect(strip, findsOneWidget);
    });

    testWidgets('the open net-worth chart stays inside the card', (
      tester,
    ) async {
      await pumpMePage(
        tester,
        size: const Size(390, 1600),
        overrides: [
          walletNetWorthHistoryGatewayProvider.overrideWithValue(_Week()),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(_key('wallet-networth-trend'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _card, matching: _key('wallet-networth-panel')),
        findsOneWidget,
      );
    });
  });

  group('我的 · the card leans toward the finger', () {
    List<Override> motion(bool on) => [
      loopAmbientMotionProvider.overrideWithValue(on),
    ];

    test('the lean sinks the pressed side under the perspective', () {
      final matrix = LoopTiltCard.matrixFor(const Offset(1, 0), 1);
      final right = MatrixUtils.transformPoint(matrix, const Offset(100, 0));
      final left = MatrixUtils.transformPoint(matrix, const Offset(-100, 0));
      expect(right.dx, lessThan(100));
      expect(left.dx.abs(), greaterThan(100));
      final down = LoopTiltCard.matrixFor(const Offset(0, 1), 1);
      final bottom = MatrixUtils.transformPoint(down, const Offset(0, 100));
      final top = MatrixUtils.transformPoint(down, const Offset(0, -100));
      expect(bottom.dy, lessThan(100));
      expect(top.dy.abs(), greaterThan(100));
      expect(LoopTiltCard.maxTilt, closeTo(6 * 3.141592653589793 / 180, 1e-9));
    });

    testWidgets('press leans and lights; release settles flat and dark', (
      tester,
    ) async {
      await pumpMePage(
        tester,
        size: const Size(390, 1400),
        overrides: motion(true),
      );
      expect(_tilt(tester).isIdentity(), isTrue);
      expect(find.byKey(LoopTiltCard.glowKey), findsNothing);
      final card = tester.getRect(_card);
      // Right of and below the centre, clear of any key.
      final at = Offset(card.right - 8, card.center.dy + 4);
      final gesture = await tester.startGesture(at);
      await tester.pump();
      final pressed = _tilt(tester);
      expect(pressed.isIdentity(), isFalse);
      // The pressed (right) edge sinks: a point right of the centre draws
      // nearer to it.
      final centre = card.center;
      final probe = MatrixUtils.transformPoint(
        Matrix4.translationValues(centre.dx, centre.dy, 0)
          ..multiply(pressed)
          ..multiply(Matrix4.translationValues(-centre.dx, -centre.dy, 0)),
        Offset(card.right, centre.dy),
      );
      expect(probe.dx, lessThan(card.right));
      expect(find.byKey(LoopTiltCard.glowKey), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_tilt(tester).isIdentity(), isTrue);
      expect(find.byKey(LoopTiltCard.glowKey), findsNothing);
    });

    testWidgets('the spring never swings past 1 degree the other way', (
      tester,
    ) async {
      await pumpMePage(
        tester,
        size: const Size(390, 1400),
        overrides: motion(true),
      );
      final card = tester.getRect(_card);
      final gesture = await tester.startGesture(
        Offset(card.right - 8, card.center.dy),
      );
      await tester.pump();
      await gesture.up();
      var worst = 0.0;
      for (var frame = 0; frame < 120; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final transform = find.byKey(LoopTiltCard.transformKey);
        final m = tester.widget<Transform>(transform).transform;
        // rotateY's sine sits in entry (0, 2) up to the perspective row.
        final sine = m.entry(0, 2);
        if (sine > worst) worst = sine;
      }
      // Pressed on the right the lean is a negative rotateY; the swing back
      // is a positive sine, held under sin(1°).
      expect(worst, lessThan(0.01746));
      await tester.pumpAndSettle();
    });

    testWidgets('reduced ambient motion: no lean, no light', (tester) async {
      await pumpMePage(
        tester,
        size: const Size(390, 1400),
        overrides: motion(false),
      );
      final card = tester.getRect(_card);
      final gesture = await tester.startGesture(card.center);
      await tester.pump();
      expect(find.byKey(LoopTiltCard.transformKey), findsNothing);
      expect(find.byKey(LoopTiltCard.glowKey), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the keys inside still take their taps', (tester) async {
      final opened = <String>[];
      await pumpMePage(
        tester,
        size: const Size(390, 1400),
        onNavigate: opened.add,
        overrides: motion(true),
      );
      await tester.tap(_key('wallet-manage-action'));
      await tester.pumpAndSettle();
      expect(opened, contains('/wallet/manage'));
    });

    testWidgets('a vertical drag on the card scrolls the page and lets go', (
      tester,
    ) async {
      await pumpMePage(
        tester,
        size: const Size(390, 640),
        overrides: motion(true),
      );
      final scrollable = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      final card = tester.getRect(_card);
      final gesture = await tester.startGesture(card.center);
      await tester.pump();
      for (var step = 0; step < 10; step++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
      }
      final after = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(after, greaterThan(before));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_tilt(tester).isIdentity(), isTrue);
      expect(find.byKey(LoopTiltCard.glowKey), findsNothing);
    });
  });

  group('chart periods · 12, never bold', () {
    Future<void> pumpRow(WidgetTester tester, {required bool fill}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Column(
              children: <Widget>[
                LoopChartIntervalRow(
                  fill: fill,
                  options: const <LoopChartIntervalOption>[
                    (keyName: 'p0', label: '1m'),
                    (keyName: 'p1', label: '5m'),
                    (keyName: 'p2', label: '4h'),
                    (keyName: 'p3', label: '1D'),
                  ],
                  selectedIndex: 2,
                  onSelected: (_) {},
                ),
                LoopChartToggle(
                  key: const ValueKey<String>('toggle'),
                  label: 'VOL',
                  semantic: 'VOL',
                  on: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
    }

    for (final fill in <bool>[true, false]) {
      testWidgets('${fill ? 'filled' : 'scrolling'} row', (tester) async {
        await pumpRow(tester, fill: fill);
        final idle = _word(tester, _key('p0'));
        expect(idle.fontSize, 12);
        expect(idle.fontWeight, FontWeight.w400);
        final chosen = _word(tester, _key('p2'));
        expect(chosen.fontSize, 12);
        expect(chosen.fontWeight, FontWeight.w500);
        // The switches above keep the 13 chip step.
        expect(_word(tester, _key('toggle')).fontSize, 13);
        // The 44 target and the 2 / 4 capsule are unchanged.
        expect(tester.getSize(_key('p0')).height, LoopTouch.minimum);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('token page: periods 12, Candles / MA / VOL 13', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );
      final period = _word(tester, _key('token-interval-1h'));
      expect(period.fontSize, 12);
      expect(period.fontWeight!.value, lessThanOrEqualTo(500));
      expect(
        _word(tester, _key('token-interval-1d')).fontWeight,
        FontWeight.w400,
      );
      for (final toggle in <String>[
        'token-chart-style',
        'token-chart-ma',
        'token-chart-vol',
      ]) {
        expect(_word(tester, _key(toggle)).fontSize, 13, reason: toggle);
      }
    });
  });

  group('MEME detail head', () {
    Widget head({
      required String name,
      String ticker = 'FROG',
      bool countdown = false,
    }) {
      final json = l2DetailJson(stage: 'public', noNextChange: !countdown);
      (json['instance']! as Map<String, Object?>)
        ..['name'] = name
        ..['ticker'] = ticker;
      return Launch2InstanceHead(
        detail: LoopV2Launch2Codec.detail(json, mediaUrl: (_) => null),
        onCopy: () {},
        onElapsed: () {},
      );
    }

    RenderParagraph nameParagraph(WidgetTester tester) =>
        tester.renderObject<RenderParagraph>(
          find.descendant(
            of: _key('launch2-head-name'),
            matching: find.byType(RichText),
          ),
        );

    for (final width in <double>[390, 360]) {
      testWidgets('a long name: up to three lines, whole ($width)', (
        tester,
      ) async {
        const name = '猫猫啦咯啦咯啦咯啦咯啦咯啦咯啦咯';
        await _host(tester, head(name: name), width: width);
        final text = tester.widget<Text>(_key('launch2-head-name'));
        expect(text.data, name);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.style!.fontSize, LoopType.headline.fontSize);
        final paragraph = nameParagraph(tester);
        expect(paragraph.didExceedMaxLines, isFalse);
        final lines =
            paragraph.size.height /
            (text.style!.fontSize! * (text.style!.height ?? 1));
        expect(lines.round(), inInclusiveRange(1, 3));
        expect(tester.takeException(), isNull);
      });

      testWidgets('a name past three lines steps down, still whole ($width)', (
        tester,
      ) async {
        final name = '猫猫啦咯' * 16;
        await _host(tester, head(name: name), width: width);
        final text = tester.widget<Text>(_key('launch2-head-name'));
        expect(text.data, name);
        expect(text.style!.fontSize, LoopType.headlineSm.fontSize);
        expect(text.maxLines, isNull);
        expect(nameParagraph(tester).didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ticker | address + copy and the stage on one line, the '
          'stage flush right ($width)', (tester) async {
        await _host(
          tester,
          head(name: '猫猫啦咯啦咯', ticker: 'AVERYLONGTICKERNAME', countdown: true),
          width: width,
        );
        final ticker = tester.getRect(_key('launch2-head-ticker'));
        final address = tester.getRect(_key('launch2-head-address'));
        final copy = tester.getRect(_key('launch2-copy-address'));
        final stage = tester.getRect(_key('launch2-stage-capsule'));
        final line = tester.getRect(_key('launch2-identity'));
        for (final rect in <Rect>[ticker, address, copy, stage]) {
          expect(rect.top, greaterThanOrEqualTo(line.top - 8));
          expect(rect.bottom, lessThanOrEqualTo(line.bottom + 8));
        }
        expect(ticker.right, lessThanOrEqualTo(address.left));
        expect(address.right, lessThanOrEqualTo(copy.left + 0.01));
        expect(copy.right, lessThanOrEqualTo(stage.left));
        expect(stage.right, closeTo(width - LoopSpacing.page, 0.01));
        // One line each.
        for (final key in <String>[
          'launch2-head-ticker',
          'launch2-head-address',
        ]) {
          expect(tester.widget<Text>(_key(key)).maxLines, 1, reason: key);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
