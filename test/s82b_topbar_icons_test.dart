import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/wallet/approval_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_activity_export.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';

/// S82b · every top-bar action is a glyph, and every glyph keeps its word.
///
/// Six pages copied the prototype's `.topbar .seg` and spelled their one
/// action — 新建, 完成, 批量回收, 行情, 添加, 导出 — while thirty others drew
/// theirs. Decision 0087 makes the whole bar glyphs. The word is not deleted:
/// it becomes the control's accessible name and its tooltip, so the semantics
/// tree reads exactly as it did and an automated walkthrough that looks for
/// 「导出」 still finds it.
///
/// Each case below is written the way that walkthrough reads the screen: find
/// the control **by its spoken name**, then press it and check that the page
/// does what the word promised.
void main() {
  /// Presses the one control whose accessible name is [name].
  ///
  /// Going through the semantics tree rather than through a key is the point
  /// of the test: a glyph that lost its name would still be found by key and
  /// would still take the tap, and nobody who cannot see it could reach it.
  Future<LoopIconButton> tapByName(WidgetTester tester, String name) async {
    final handle = tester.ensureSemantics();
    final finder = find.bySemanticsLabel(name);
    expect(finder, findsOneWidget, reason: 'no control is named $name');
    final button = tester.widget<LoopIconButton>(
      find.ancestor(of: finder, matching: find.byType(LoopIconButton)).first,
    );
    await tester.tap(finder);
    await tester.pumpAndSettle();
    handle.dispose();
    return button;
  }

  /// Asserts the named control is a glyph on the 44 grid, not a word.
  void expectGlyph(
    WidgetTester tester,
    Key key, {
    required String icon,
    required String name,
  }) {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget);
    final button = tester.widget<LoopIconButton>(finder);
    expect(button.icon, icon);
    expect(button.label, name);
    // The word is gone from the paint and nowhere else.
    expect(
      find.descendant(of: finder, matching: find.text(name)),
      findsNothing,
    );
    final size = tester.getSize(finder);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    // A glyph with no name is unreachable; the tooltip carries the word for
    // a long press and the semantics carry it for a screen reader.
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(of: finder, matching: find.byType(Tooltip)).first,
          )
          .message,
      name,
    );
  }

  group('价格提醒 · 新建', () {
    testWidgets('the ＋ glyph is named 新建 and opens the editor', (tester) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(assetId: s5WbnbAssetId),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(),
      );

      expectGlyph(
        tester,
        const ValueKey<String>('alerts-create-action'),
        icon: 'plus',
        name: '新建',
      );
      await tapByName(tester, '新建');

      expect(
        find.byKey(const ValueKey<String>('alert-threshold-field')),
        findsOneWidget,
      );
    });
  });

  group('自选管理 · 完成', () {
    testWidgets('the ✓ glyph is named 完成 and commits the draft', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway();
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: watchlist,
      );

      expectGlyph(
        tester,
        const ValueKey<String>('watchlist-save-action'),
        icon: 'check',
        name: '完成',
      );
      // Nothing to save yet: the control is off, exactly as the word was.
      expect(
        tester
            .widget<LoopIconButton>(
              find.byKey(const ValueKey<String>('watchlist-save-action')),
            )
            .onPressed,
        isNull,
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('watchlist-remove-$s5UsdtAssetId')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-remove-$s5UsdtAssetId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-remove-confirm')),
      );
      await tester.pumpAndSettle();

      await tapByName(tester, '完成');

      expect(find.text('自选已保存'), findsOneWidget);
    });
  });

  group('授权盘点 · 批量回收', () {
    testWidgets('the blocked glyph keeps its name and still answers the tap', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const ApprovalsScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(),
      );

      expectGlyph(
        tester,
        const ValueKey<String>('approvals-batch-action'),
        icon: 'blocked',
        name: '批量回收',
      );
      final button = await tapByName(tester, '批量回收');
      // Disabled paint, disabled semantics — and an answer all the same.
      expect(button.onPressed, isNull);
      expect(button.onBlocked, isNotNull);

      expect(find.textContaining('批量回收还没有开放'), findsOneWidget);
    });
  });

  group('Wallet 资产 · 行情', () {
    testWidgets('the chart glyph is named 行情 and opens the token page', (
      tester,
    ) async {
      final routes = <String>[];
      await pumpS5Page(
        tester,
        WalletAssetScreen(
          assetId: s5NativeAssetId,
          onNavigate: (location, {Object? extra}) => routes.add(location),
        ),
        wallet: FakeWalletReadGateway(),
      );

      expectGlyph(
        tester,
        const ValueKey<String>('wallet-asset-market-action'),
        icon: 'chart',
        name: '行情',
      );
      await tapByName(tester, '行情');

      expect(routes, hasLength(1));
      expect(routes.single, startsWith('/market/token'));
    });
  });

  group('我的钱包 · 添加', () {
    testWidgets('the ＋ glyph is named 添加 and opens the explanation', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(),
      );

      expectGlyph(
        tester,
        const ValueKey<String>('wallets-add-action'),
        icon: 'plus',
        name: '添加',
      );
      await tapByName(tester, '添加');

      expect(
        find.byKey(const ValueKey<String>('wallets-add-sheet')),
        findsOneWidget,
      );
      expect(find.text('暂不支持绑定第二个钱包'), findsOneWidget);
    });
  });

  group('交易历史 · 导出', () {
    testWidgets('the share glyph is named 导出 and hands the rows over', (
      tester,
    ) async {
      final sink = _NamedExportSink();
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(),
        wallet: FakeWalletReadGateway(),
        exportSink: sink,
      );

      expectGlyph(
        tester,
        const ValueKey<String>('tx-history-export-action'),
        icon: 'share',
        name: '导出',
      );
      await tapByName(tester, '导出');

      expect(sink.fileNames, hasLength(1));
      expect(sink.fileNames.single, endsWith('.csv'));
      expect(find.text('记录已导出，请在分享面板中选择去处'), findsOneWidget);
    });
  });
}

final class _NamedExportSink implements WalletActivityExportSink {
  final List<String> fileNames = <String>[];

  @override
  Future<WalletExportOutcome> shareCsv({
    required String csv,
    required String fileName,
  }) async {
    fileNames.add(fileName);
    return WalletExportOutcome.shared;
  }
}
