import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/widgets/loop_tray_disclosure.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// Decision 0096 · the token page's fact tray: a compact two-column grid,
/// risk-class facts first, at most eight cells, one provenance line.
void main() {
  final observed = DateTime.utc(2026, 9, 8, 7, 20);

  MarketSecurityFact fact(String key, String value, {DateTime? at}) =>
      MarketSecurityFact(
        fact: key,
        value: value,
        source: LoopFactSource.goplus,
        observedAt: at ?? observed,
      );

  // Source order puts the neutral ones first; three are risk-class.
  final facts = <MarketSecurityFact>[
    fact('openSource', 'true'),
    fact('proxy', 'false'),
    fact('mintable', 'true'),
    fact('ownershipTakeBack', 'false'),
    fact('hiddenOwner', 'false'),
    fact('selfDestruct', 'false'),
    fact('transferPausable', 'true'),
    fact('honeypot', 'false'),
    fact('blacklist', 'true', at: DateTime.utc(2026, 9, 8, 7, 10)),
    fact('whitelist', 'false'),
    fact('buyTax', '0'),
    fact('sellTax', '0'),
  ];

  MarketSecurityAvailable block(List<MarketSecurityFact> facts) =>
      MarketSecurityAvailable(
        source: LoopFactSource.goplus,
        fetchedAt: observed,
        ttlSeconds: 600,
        quality: LoopFactQuality.fresh,
        reasonCode: null,
        facts: facts,
      );

  Finder key(String value) => find.byKey(ValueKey<String>(value));

  Future<void> openTray(
    WidgetTester tester,
    List<MarketSecurityFact> facts,
  ) async {
    await pumpS5Page(
      tester,
      const TokenDetailScreen(assetId: s5WbnbAssetId),
      market: FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(
          value: s5Detail(security: block(facts)),
        ),
      ),
    );
    await tester.tap(
      find.descendant(
        of: key('token-facts-tray'),
        matching: key('loop-tray-toggle'),
      ),
    );
    // Frame by frame through the open, then assert the end state.
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  }

  test('risk class: present capabilities and an unverified contract', () {
    expect(tokenSecurityFactIsRisk(fact('mintable', 'true')), isTrue);
    expect(tokenSecurityFactIsRisk(fact('mintable', 'false')), isFalse);
    expect(tokenSecurityFactIsRisk(fact('transferPausable', 'true')), isTrue);
    expect(tokenSecurityFactIsRisk(fact('blacklist', 'true')), isTrue);
    expect(tokenSecurityFactIsRisk(fact('openSource', 'false')), isTrue);
    expect(tokenSecurityFactIsRisk(fact('openSource', 'true')), isFalse);
    // "可以全部卖出" starts with 可 and is not a risk: the class is semantic.
    expect(tokenSecurityFactIsRisk(fact('cannotSellAll', 'false')), isFalse);
    expect(tokenSecurityFactIsRisk(fact('buyTax', '0.1')), isFalse);
    expect(tokenSecurityFactIsRisk(fact('mintable', 'unknown')), isFalse);
    // Short labels keep the claim: 未检测到 stays 未检测到.
    expect(tokenSecurityFactShortText(fact('mintable', 'false')), '未检测到 mint');
    expect(tokenSecurityFactShortText(fact('mystery', 'x')), 'mystery = x');
  });

  testWidgets('two columns, risk first, eight at most, then 更多 and one '
      'provenance line', (tester) async {
    await openTray(tester, facts);
    final detail = key('token-facts-tray-detail');
    expect(detail, findsOneWidget);
    expect(
      find.descendant(
        of: detail,
        matching: find.textContaining('主交易对：pancakeswap · 报价币 USDT'),
      ),
      findsOneWidget,
    );

    final cells = tester
        .widgetList<TokenFactCell>(find.byType(TokenFactCell))
        .toList();
    expect(cells, hasLength(TokenFactsTrayDetail.maxCells));
    // The three risk-class facts lead, in source order.
    expect(cells.take(3).map((cell) => cell.fact.fact), <String>[
      'mintable',
      'transferPausable',
      'blacklist',
    ]);
    expect(cells.take(3).every((cell) => cell.risk), isTrue);
    expect(cells.skip(3).every((cell) => !cell.risk), isTrue);
    // Warning dot for risk, neutral for the rest.
    Color dot(String fact) =>
        (tester.widget<DecoratedBox>(key('token-fact-dot-$fact')).decoration
                as BoxDecoration)
            .color!;
    expect(dot('mintable'), LoopColors.warning);
    expect(dot('openSource'), LoopColors.text3);

    // Two columns: cell 0 and 1 share a row, cell 2 starts the next.
    final first = tester.getTopLeft(key('token-fact-mintable'));
    final second = tester.getTopLeft(key('token-fact-transferPausable'));
    final third = tester.getTopLeft(key('token-fact-blacklist'));
    expect(second.dy, moreOrLessEquals(first.dy));
    expect(second.dx, greaterThan(first.dx));
    expect(third.dy, greaterThan(first.dy));
    expect(third.dx, moreOrLessEquals(first.dx));

    // Twelve facts, eight cells: four fold into 简介.
    expect(
      find.descendant(
        of: key('token-facts-tray-more'),
        matching: find.text('更多 4 项'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(key('token-facts-tray-more')).height,
      greaterThanOrEqualTo(LoopTouch.minimum),
    );
    // Source and time once, at the foot, with the oldest observation.
    expect(
      find.descendant(of: detail, matching: find.textContaining('来源')),
      findsOneWidget,
    );
    final source = tester.widget<Text>(key('token-facts-tray-source'));
    expect(source.data, startsWith('来源 GoPlus · 观察于 '));
    expect(
      tester.getTopLeft(key('token-facts-tray-source')).dy,
      greaterThan(tester.getTopLeft(key('token-facts-tray-more')).dy),
    );
  });

  testWidgets('更多 opens 简介 and keeps the tray where it is', (tester) async {
    await openTray(tester, facts);
    final before = tester.getTopLeft(key('token-quote-cells'));
    await tester.tap(key('token-facts-tray-more'));
    await tester.pumpAndSettle();
    // The tab switched; the tray did not toggle closed.
    expect(key('token-security-facts'), findsOneWidget);
    expect(key('token-facts-tray-detail'), findsOneWidget);
    expect(tester.getTopLeft(key('token-quote-cells')), before);
  });

  testWidgets('eight or fewer: no 更多, still one provenance line', (
    tester,
  ) async {
    await openTray(tester, facts.take(5).toList());
    expect(find.byType(TokenFactCell), findsNWidgets(5));
    expect(key('token-facts-tray-more'), findsNothing);
    expect(key('token-facts-tray-source'), findsOneWidget);
  });

  testWidgets('the cells sit on a panel as wide as the tray', (tester) async {
    await openTray(tester, facts);
    final panel = tester.getRect(key('token-quote-panel'));
    final tray = tester.getRect(
      find.descendant(of: key('token-facts-tray'), matching: key('loop-tray')),
    );
    expect(panel.width, moreOrLessEquals(tray.width));
    expect(panel.left, moreOrLessEquals(tray.left));
    // The tray runs up under the panel and shows below it.
    expect(tray.top, lessThan(panel.bottom));
    expect(tray.bottom, greaterThan(panel.bottom));
    expect(
      find.descendant(
        of: key('token-quote-panel'),
        matching: key('token-quote-cells'),
      ),
      findsOneWidget,
    );
    // The panel is opaque, so the tray under its edge never shows through.
    final decoration =
        tester.widget<DecoratedBox>(key('token-quote-panel')).decoration
            as BoxDecoration;
    expect(decoration.color!.a, 1);
    expect(
      tester.widget<LoopTrayDisclosure>(key('token-facts-tray')).trayInset,
      LoopSpacing.page,
    );
  });
}
