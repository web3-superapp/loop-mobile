// S197-2 (decision 0190): wallet / MEME / intel / token / launchpad rows and
// panels on the final type ladder. Every assertion reads the style the text
// was actually painted with (the RichText under the Text), so a style merged
// in from a parent DefaultTextStyle is checked too.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/meme_fixtures.dart';
import 'support/s5_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  tester.view.physicalSize = const Size(390, 844);
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

TextStyle _painted(WidgetTester tester, Finder text) {
  final rich = tester.widget<RichText>(
    find.descendant(of: text, matching: find.byType(RichText)).first,
  );
  return rich.text.style!;
}

void _expectStep(TextStyle actual, TextStyle step, {FontWeight? weight}) {
  expect(actual.fontSize, step.fontSize);
  expect(actual.fontWeight, weight ?? step.fontWeight);
}

MemeTokenRow _meme({String status = 'trading'}) => memePage(
  items: <Map<String, Object?>>[
    memeRowJson(
      status: status,
      progressBps: status == 'graduated' ? 10000 : 3327,
      pool: status == 'graduated'
          ? '0x7777777777777777777777777777777777777777'
          : null,
      graduatedAt: status == 'graduated' ? '2026-10-08T05:00:00.000Z' : null,
    ),
  ],
).items.single;

Finder _key(String value) => find.byKey(ValueKey<String>(value));

void main() {
  group('H4 / M27 · the MEME list row is the quote row', () {
    testWidgets('ticker 16, line 13, cap 17/600, age 11, progress 12/600', (
      tester,
    ) async {
      await _pump(
        tester,
        MemeTokenCard(row: _meme(), now: DateTime.utc(2026, 10, 8, 3)),
      );
      _expectStep(_painted(tester, _key('meme-row-ticker')), LoopType.titleLg);
      _expectStep(_painted(tester, _key('meme-row-subtitle')), LoopType.bodySm);
      _expectStep(_painted(tester, _key('meme-row-cap')), LoopType.figureMd);
      _expectStep(
        _painted(tester, _key('meme-row-age')),
        LoopType.figureXs,
        weight: FontWeight.w600,
      );
      _expectStep(
        _painted(tester, _key('meme-progress-label')),
        LoopType.figureSm,
        weight: FontWeight.w600,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a graduated row states its move at figureSm 600', (
      tester,
    ) async {
      final row = _meme(status: 'graduated');
      await _pump(tester, MemeTokenCard(row: row));
      if (row.change1hPct != null) {
        _expectStep(
          _painted(tester, _key('meme-change')),
          LoopType.figureSm,
          weight: FontWeight.w600,
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('H5 / H7 / M21 · wallet rows', () {
    testWidgets('a quote-row list: the failed row takes the quote title', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          children: <Widget>[
            WalletAssetLine(row: s5Row(), hidden: false),
            WalletAssetLine(
              row: s5Row(
                assetId: 'eip155:56:erc20:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
                balance: const LoopBalanceUnavailable('BSC_RPC_UNREACHABLE'),
              ),
              hidden: false,
            ),
          ],
        ),
      );
      _expectStep(_painted(tester, find.text('BNB').first), LoopType.titleLg);
      _expectStep(_painted(tester, find.text('WBNB')), LoopType.titleLg);
      // M21: the caller hands no style; the quote row's figureSm applies.
      final value = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'wallet-balance-value-',
            ),
      );
      _expectStep(_painted(tester, value.first), LoopType.figureSm);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 钱包 C list: R4 / R5 / R6 / R7, failed row at R4', (
      tester,
    ) async {
      final healthy = s5Row();
      await _pump(
        tester,
        Column(
          children: <Widget>[
            WalletBalanceRow(
              row: healthy,
              hidden: false,
              actions: const <WalletRowAction>[],
              onBlocked: (_) {},
            ),
            WalletBalanceRow(
              row: s5Row(
                assetId: 'eip155:56:erc20:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
                balance: const LoopBalanceUnavailable('BSC_RPC_UNREACHABLE'),
              ),
              hidden: false,
              actions: const <WalletRowAction>[],
              onBlocked: (_) {},
            ),
          ],
        ),
      );
      _expectStep(_painted(tester, find.text('BNB').first), LoopType.title);
      _expectStep(_painted(tester, find.text('WBNB')), LoopType.title);
      _expectStep(
        _painted(tester, _key('wallet-balance-amount-${healthy.assetId}')),
        LoopType.figure,
      );
      _expectStep(
        _painted(tester, _key('wallet-balance-subtitle-${healthy.assetId}')),
        LoopType.caption,
      );
      _expectStep(
        _painted(tester, _key('wallet-balance-value-${healthy.assetId}')),
        LoopType.figureXs,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('M24 / M25 · market strips', () {
    testWidgets('the tab strip draws the quiet segment word', (tester) async {
      await _pump(
        tester,
        MarketTabBar(
          labels: const <String>['自选', '热门'],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      );
      _expectStep(
        _painted(tester, find.text('自选')),
        LoopType.action,
        weight: FontWeight.w700,
      );
      _expectStep(_painted(tester, find.text('热门')), LoopType.action);
    });

    testWidgets('the quote cells take the stat grid steps', (tester) async {
      await _pump(
        tester,
        const MarketQuoteCells(
          cells: <MarketStatCell>[
            MarketStatCell(label: '24h 高', value: '1.23', available: true),
            MarketStatCell(label: '市值', value: '未报告', available: false),
          ],
        ),
      );
      _expectStep(_painted(tester, find.text('24h 高')), LoopType.kicker);
      _expectStep(_painted(tester, find.text('1.23')), LoopType.figure);
      _expectStep(_painted(tester, find.text('未报告')), LoopType.kicker);
    });
  });

  group('M29 / M31 · tape headers and provenance', () {
    testWidgets('the day header is a LoopLabel', (tester) async {
      await _pump(tester, const WalletActivityDayHeader(label: '今天'));
      expect(find.byType(LoopLabel), findsOneWidget);
      _expectStep(_painted(tester, find.text('今天')), LoopType.sectionTitle);
    });

    testWidgets('a provenance footer is captionSm text3', (tester) async {
      await _pump(tester, const LoopProvenanceFooter(text: '区块 1 · 观察于 刚刚'));
      final style = _painted(tester, find.text('区块 1 · 观察于 刚刚'));
      _expectStep(style, LoopType.captionSm);
      expect(style.color, LoopColors.text3);
    });
  });
}
