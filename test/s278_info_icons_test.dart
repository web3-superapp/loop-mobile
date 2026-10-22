// S278 · decision 0236 (需求方 2026-10-22 第 11–14 条): explanatory text and
// provenance stand behind one (i) instead of on the page.
//
// The checks run in every `flutter test`. The three shots at the end write
// 390-wide renders to docs/integration/S278/shots/ and run only with
// `--dart-define=LOOP_SHOTS=true`.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/features/wallet/deferred_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s5_page_harness.dart';
import 'support/s8_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _shotDir = 'docs/integration/S278/shots';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _host(WidgetTester tester, Widget child) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[child],
          ),
        ),
      ),
    ),
  );
}

void main() {
  loopWatchGround();

  group('LoopProvenanceFooter', () {
    const statement = '区块 120,628,164 · 15 确认 · 来源 DexScreener · 观察于 2 分钟前';

    testWidgets('prints no long text by default, only (i) 来源', (tester) async {
      await _host(tester, const LoopProvenanceFooter(text: statement));

      expect(find.text(statement), findsNothing);
      expect(find.textContaining('观察于'), findsNothing);
      final trigger = _key('provenance-footer');
      expect(trigger, findsOneWidget);
      expect(
        find.descendant(of: trigger, matching: find.text('来源')),
        findsOneWidget,
      );
      expect(tester.getSize(trigger).height, greaterThanOrEqualTo(44));
      // A screen reader still hears the whole statement.
      expect(tester.getSemantics(trigger).label, contains(statement));
    });

    testWidgets('a tap on (i) opens the sheet with the full statement', (
      tester,
    ) async {
      await _host(
        tester,
        const LoopProvenanceFooter(
          text: statement,
          notes: <String>['回收会发送一笔 approve(spender, 0) 交易。'],
        ),
      );

      await tester.tap(_key('provenance-footer'));
      await tester.pumpAndSettle();

      expect(_key('provenance-footer-sheet'), findsOneWidget);
      expect(find.text('数据来源'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _key('provenance-footer-text'),
                matching: find.byType(Text),
              ),
            )
            .data,
        statement,
      );
      expect(find.text('回收会发送一笔 approve(spender, 0) 交易。'), findsOneWidget);
    });

    testWidgets('an explanation names itself 说明', (tester) async {
      await _host(
        tester,
        const LoopProvenanceFooter(
          text: '结果只留在这台设备上，不会上传。',
          label: '说明',
          title: '结果去向',
        ),
      );
      expect(find.text('说明'), findsOneWidget);
      expect(find.text('结果只留在这台设备上，不会上传。'), findsNothing);
      await tester.tap(_key('provenance-footer'));
      await tester.pumpAndSettle();
      expect(find.text('结果去向'), findsOneWidget);
      expect(find.text('结果只留在这台设备上，不会上传。'), findsOneWidget);
    });

    testWidgets('a list-state footnote stays printed', (tester) async {
      await _host(tester, const LoopFootnote(text: '没有更多提醒'));
      expect(find.text('没有更多提醒'), findsOneWidget);
    });
  });

  group('LoopFactLine', () {
    testWidgets('the figure stays; its source is behind (i)', (tester) async {
      final fact = LoopFact(
        value: Decimal.parse('747.39'),
        source: LoopFactSource.dexscreener,
        fetchedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ttlSeconds: 60,
        quality: LoopFactQuality.fresh,
        reasonCode: null,
      );
      await _host(tester, LoopFactLine(label: '价格', fact: fact));
      expect(find.text('747.39'), findsOneWidget);
      expect(find.textContaining('观察于'), findsNothing);
      await tester.tap(_key('fact-价格-provenance'));
      await tester.pumpAndSettle();
      expect(_key('fact-provenance-sheet'), findsOneWidget);
      expect(find.textContaining('观察于'), findsOneWidget);
    });
  });

  group('第 11 条 · 跨链', () {
    testWidgets('the heading and the disabled form stay; nothing explains '
        'itself on the page', (tester) async {
      await pumpS8Page(tester, BridgeScreen(onOpenStatus: () {}));
      expect(find.text('跨链尚未开放'), findsOneWidget);
      expect(_key('bridge-start'), findsOneWidget);
      expect(_key('bridge-open-status'), findsOneWidget);
      expect(find.textContaining('先选来源链'), findsNothing);
      expect(find.textContaining('这里不会出现预估数字'), findsNothing);
      expect(find.textContaining('这里不会发起任何跨链操作'), findsNothing);

      await tester.tap(_key('bridge-info'));
      await tester.pumpAndSettle();
      expect(_key('bridge-info-sheet'), findsOneWidget);
      expect(find.textContaining('先选来源链'), findsOneWidget);
      expect(find.text('这里不会出现预估数字'), findsOneWidget);
    });
  });

  group('第 12 条 · 安全中心', () {
    testWidgets('row descriptions are behind each row\'s (i)', (tester) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(),
      );
      for (final sentence in <String>[
        '当前钱包上仍然生效的 ERC-20 授权',
        '额度没有上限的授权，风险最高',
        '时再验一次身份',
        '授权记录自区块',
        '这些保护由 Privy 提供',
      ]) {
        expect(find.textContaining(sentence), findsNothing, reason: sentence);
      }
      // Titles, figures and the 还没有开放 pills stay.
      expect(find.text('有效授权'), findsOneWidget);
      expect(find.text('无限额度授权'), findsOneWidget);
      expect(find.text('还没有开放'), findsWidgets);

      final info = _key('security-approvals-unlimited-info');
      await tester.ensureVisible(info);
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(_key('security-approvals-unlimited-info-sheet'), findsOneWidget);
      expect(find.textContaining('额度没有上限的授权，风险最高'), findsOneWidget);
    });
  });

  group('第 13 条 · 钱包资产卡', () {
    testWidgets('no provenance line under the list; (i) holds it', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );
      expect(find.textContaining('观察于'), findsNothing);
      expect(find.textContaining('区块 120,628,164'), findsNothing);
      final line = _key('wallet-snapshot-footer');
      expect(line, findsOneWidget);
      await tester.ensureVisible(line);
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(_key('loop-provenance-sheet'), findsOneWidget);
      expect(find.textContaining('区块 120,628,164'), findsOneWidget);
    });
  });

  group('shots', () {
    testWidgets('wallet home asset card', skip: !_shots, (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        size: const Size(390, 1300),
      );
      await loopShot(tester, 'wallet-home', dir: _shotDir, slice: 1300);
    });

    testWidgets('bridge', skip: !_shots, (tester) async {
      await pumpS8Page(
        tester,
        BridgeScreen(onOpenStatus: () {}),
        size: const Size(390, 844),
      );
      await loopShot(tester, 'bridge', dir: _shotDir, slice: 844);
      await tester.tap(_key('bridge-info'));
      await tester.pumpAndSettle();
      await loopShot(tester, 'bridge-info-sheet', dir: _shotDir, slice: 844);
    });

    testWidgets('security center', skip: !_shots, (tester) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(),
        size: const Size(390, 1700),
      );
      await loopShot(tester, 'security-center', dir: _shotDir, slice: 1700);
    });
  });
}
