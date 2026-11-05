// S370a · decision 0293: the MEME second-level pages at docs/58 §9's
// measures — the detail page's head, tabs, price and trade rows, the trade
// panels' chips, the rewards / NFT / pool lines on the 20 edge, the sign
// sheet, the creator pages and the curve MEME pages.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_parts.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_recent_trades.dart';
import 'package:loop_mobile/features/launch2/launch2_secondary_metrics.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/meme/meme_design.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_tab_strip.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

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

Launch2PublicPoolTrade _trade({String? wallet = '0x12…ab'}) =>
    Launch2PublicPoolTrade(
      txHash: '0xabc',
      blockNumber: BigInt.one,
      at: DateTime.utc(2026, 11, 5, 8),
      side: Launch2Side.buy,
      memeAmount: Decimal.parse('12000'),
      usd1Amount: Decimal.parse('12.5'),
      priceUsd1: Decimal.parse('0.001'),
      wallet: wallet,
    );

void main() {
  loopWatchGround();

  group('the analogies (类推)', () {
    test('a record row is 51: 6 + a 36 face + 6 plus a line of slack', () {
      expect(Launch2SecondaryMetrics.recordRow, 51);
      expect(Launch2SecondaryMetrics.recordInset, 6);
      expect(Launch2SecondaryMetrics.recordFace, 36);
      expect(Launch2SecondaryMetrics.faceGap, 12);
      expect(
        Launch2SecondaryMetrics.recordInset * 2 +
            Launch2SecondaryMetrics.recordFace,
        lessThanOrEqualTo(Launch2SecondaryMetrics.recordRow),
      );
    });

    test('a token face is 44; chips sit 8 apart and 12 above content', () {
      expect(Launch2SecondaryMetrics.tokenFace, 44);
      expect(Launch2SecondaryMetrics.chipSpacing, LoopSpacing.chipSpacing);
      expect(Launch2SecondaryMetrics.chipToContent, LoopSpacing.chipGap);
    });
  });

  group('MEME 详情页', () {
    testWidgets('the tabs are the first-level text strip, 16 to the list', (
      tester,
    ) async {
      var chosen = Launch2InstanceTab.trades;
      await _host(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Launch2InstanceTabs(
            tabs: Launch2InstanceTab.values,
            selected: chosen,
            onSelected: (tab) => setState(() => chosen = tab),
          ),
        ),
      );
      expect(find.byType(LoopTabStrip), findsOneWidget);
      expect(Launch2InstanceTabs.listGap, 16);
      // No Purple pill any more.
      final purple = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == LoopColors.purple,
      );
      expect(purple, findsNothing);
      // The chosen tab's words are the tab step.
      final words = tester.widget<Text>(
        find.descendant(
          of: _key('launch2-tab-trades'),
          matching: find.byType(Text),
        ),
      );
      expect(words.style?.fontSize, LoopType.tab.fontSize);
      expect(words.style?.fontWeight, FontWeight.w600);
      // The per-tab keys still answer a tap.
      await tester.tap(_key('launch2-tab-info'));
      await tester.pump();
      expect(chosen, Launch2InstanceTab.info);
      // The strip spans the screen; its cells start on the 20 edge.
      final strip = tester.getRect(find.byType(LoopTabStrip));
      expect(strip.width, 390);
      expect(tester.getRect(_key('launch2-tab-trades')).left, LoopSpacing.page);
    });

    testWidgets('the head: a 44 round face and a r4 stage capsule', (
      tester,
    ) async {
      await _host(
        tester,
        Launch2InstanceHead(
          detail: l2Detail(stage: 'public', noNextChange: true),
          onCopy: () {},
          onElapsed: () {},
        ),
      );
      final logo = tester.widget<MemeLogo>(find.byType(MemeLogo));
      expect(logo.size, 44);
      expect(logo.radius, 22);
      final capsule = tester.widget<DecoratedBox>(
        _key('launch2-stage-capsule'),
      );
      final decoration = capsule.decoration as BoxDecoration;
      expect(decoration.borderRadius, LoopRadius.stage);
      expect(decoration.color, LoopColors.yellowSoft);
      final word = tester.widget<Text>(
        find
            .descendant(
              of: _key('launch2-stage-capsule'),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(word.style?.fontSize, 11);
      expect(word.style?.fontWeight, FontWeight.w400);
      expect(word.style?.color, LoopColors.yellow);
    });

    testWidgets('the price is the 30 / 700 key figure', (tester) async {
      await _host(
        tester,
        Launch2PriceHeader(price: Decimal.parse('0.0012'), priceKey: 'price'),
      );
      final price = tester.widget<Text>(_key('price'));
      expect(price.style?.fontSize, 30);
      expect(price.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('a public trade is a 51 record row: body1, 14 / 600', (
      tester,
    ) async {
      await _host(
        tester,
        Column(
          children: <Widget>[
            Launch2PublicTradeRow(trade: _trade(), ticker: 'DOG'),
            Launch2PublicTradeRow(trade: _trade(wallet: null), ticker: 'DOG'),
          ],
        ),
      );
      final rows = find.byType(Launch2PublicTradeRow);
      expect(tester.getSize(rows.first).height, greaterThanOrEqualTo(51));
      expect(tester.getSize(rows.first).height, lessThan(56));
      final amount = tester.widget<Text>(find.text('12.5 USD1').first);
      expect(amount.style?.fontSize, 14);
      expect(amount.style?.fontWeight, FontWeight.w600);
      final side = tester.widget<RichText>(
        find.descendant(of: rows.first, matching: find.byType(RichText)).first,
      );
      final sized = <double>[];
      side.text.visitChildren((span) {
        final size = span.style?.fontSize;
        if (span is TextSpan && span.text != null && size != null) {
          sized.add(size);
        }
        return true;
      });
      // The side word and the trader, both body1 14.
      expect(sized, isNotEmpty);
      expect(sized.first, 14);
      // On the 20 edge.
      final first = tester.getRect(rows.first);
      final words = tester.getRect(
        find.descendant(of: rows.first, matching: find.byType(RichText)).first,
      );
      expect(words.left - first.left, LoopSpacing.page);
    });
  });

  group('交易面板 / 回购 / 奖励', () {
    testWidgets('the LoopDynamic retry stands on both 20 edges', (
      tester,
    ) async {
      await _host(
        tester,
        Launch2DynamicUnavailableBlock(reason: 'Hook down', onRetry: () {}),
      );
      final retry = tester.getRect(_key('launch2-dyn-unavailable-retry'));
      expect(retry.left, LoopSpacing.page);
      expect(390 - retry.right, LoopSpacing.page);
    });
  });

  group('签名', () {
    testWidgets('the NFT confirm sheet sits on the heading\'s 20 edge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showLaunch2NftConfirmSheet(
                    context,
                    ticker: 'DOG',
                    priceLabel: '100 USD1',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final button = tester.getRect(_key('launch2-nft-confirm-button'));
      final sheet = tester.getRect(_key('launch2-nft-confirm'));
      expect(button.left - sheet.left, LoopSpacing.page);
      expect(sheet.right - button.right, LoopSpacing.page);
    });
  });

  group('发射申请', () {
    testWidgets('the fixed recipient is a r12 field', (tester) async {
      await _host(tester, const Launch2FixedRecipient(address: '0x1234'));
      final box = tester.widget<Container>(
        find
            .descendant(
              of: _key('launch2-fixed-recipient'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container && widget.decoration is BoxDecoration,
              ),
            )
            .first,
      );
      expect(
        (box.decoration! as BoxDecoration).borderRadius,
        LoopRadius.control,
      );
    });
  });

  group('曲线 MEME', () {
    test('a stage tag is the r4 stage capsule', () {
      for (final tone in MemeTagTone.values) {
        expect(memeTagDecoration(tone).borderRadius, LoopRadius.stage);
      }
    });
  });
}
