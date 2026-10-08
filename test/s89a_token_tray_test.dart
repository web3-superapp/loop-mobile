import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_screen.dart';

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

  // Decision 0118: the tray under the quote is gone; 关于 lists every fact,
  // risk-class first, and states the source once.
  testWidgets('关于 lists every fact, risk first, with one source line', (
    tester,
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
    await scrollToS5Section(tester, key('token-section-tabs'));
    await tester.tap(key('token-tab-关于'));
    await tester.pumpAndSettle();
    await scrollToS5Section(tester, key('token-security-provenance'));
    final cells = find.byType(TokenFactCell);
    expect(cells, findsNWidgets(facts.length));
    final first = tester.widget<TokenFactCell>(cells.first);
    expect(first.risk, isTrue);
    expect(find.textContaining('合约事实 ${facts.length} 项'), findsOneWidget);
    expect(find.textContaining('来源 GoPlus'), findsOneWidget);
  });
}
