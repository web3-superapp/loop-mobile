import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// Decision 0171 · S186-6: the market and wallet detail pages speak the
/// shared family (docs/33 M11, M15, L3–L7, L13–L15, L17, L18).
void main() {
  Finder key(String value) => find.byKey(ValueKey<String>(value));

  group('M11 · watchlist-edit', () {
    testWidgets('the list is one record card with row-icon handles', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(),
      );
      expect(
        find.ancestor(
          of: key('watchlist-reorderable'),
          matching: find.byType(LoopRecordCard),
        ),
        findsOneWidget,
      );
      final handle = tester.widget<LoopRowIcon>(
        key('watchlist-drag-$s5WbnbAssetId'),
      );
      expect(handle.icon, 'drag');
      expect(handle.tone, LoopRowIconTone.neutral);
    });

    testWidgets('a swipe shows Chalk on Card2, never the fall colour', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(),
      );
      final row = key('watchlist-item-$s5WbnbAssetId');
      await tester.ensureVisible(row);
      final gesture = await tester.startGesture(tester.getCenter(row));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      final ground = tester.widget<ColoredBox>(
        key('watchlist-swipe-background'),
      );
      expect(ground.color, LoopColors.card2);
      expect(ground.color, isNot(LoopColors.fall));
      final word = tester.widget<Text>(
        find.descendant(
          of: key('watchlist-swipe-background'),
          matching: find.text('删除'),
        ),
      );
      expect(word.style?.color, LoopColors.chalk);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the undo offer is the shared toast with one action', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(),
      );
      await tester.tap(key('watchlist-remove-$s5WbnbAssetId'));
      await tester.pumpAndSettle();
      final view = tester.widget<LoopToastView>(
        find.ancestor(
          of: key('watchlist-undo-toast'),
          matching: find.byType(LoopToastView),
        ),
      );
      expect(view.entry.kind, LoopToastKind.ok);
      expect(view.entry.action?.label, '撤销');
      expect(find.textContaining('2 个自选资产'), findsOneWidget);

      await tester.tap(key('watchlist-undo'));
      await tester.pumpAndSettle();
      expect(key('watchlist-undo-toast'), findsNothing);
      expect(find.textContaining('3 个自选资产'), findsOneWidget);
    });
  });

  group('L3 / L4 · token page', () {
    testWidgets('the chosen lower tab is underlined in Chalk', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );
      await scrollToS5Section(tester, key('token-section-tabs'));
      final underline = tester.widget<Container>(
        find
            .descendant(
              of: key('token-tab-${TokenSectionTab.holders.label}'),
              matching: find.byType(Container),
            )
            .first,
      );
      final border = (underline.decoration! as BoxDecoration).border! as Border;
      expect(border.bottom.color, LoopColors.chalk);
    });

    testWidgets('periods and chart switches are quiet segs', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );
      final period = tester.widget<LoopSeg>(key('token-interval-1h'));
      expect(period.quiet, isTrue);
      expect(period.selected, isTrue);
      expect(
        tester.widget<LoopSeg>(key('token-interval-1d')).selected,
        isFalse,
      );
      for (final toggle in const <String>[
        'token-chart-style',
        'token-chart-ma',
        'token-chart-vol',
      ]) {
        final seg = tester.widget<LoopSeg>(
          find.descendant(of: key(toggle), matching: find.byType(LoopSeg)),
        );
        expect(seg.quiet, isTrue, reason: toggle);
      }
    });
  });

  group('L6 · token-holders', () {
    testWidgets('the stats are the shared grid; the gap is one inline line', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const HolderDistributionScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );
      expect(tester.widget(key('token-holders-stats')), isA<LoopStatGrid>());
      await scrollToS5Section(tester, key('token-holders-distribution'));
      expect(
        find.descendant(
          of: key('token-holders-distribution'),
          matching: find.byType(LoopInlineUnavailable),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('持有人分布暂时读不到'), findsOneWidget);
    });
  });

  group('L13 · alerts', () {
    testWidgets('a triggered record leads with the accent row icon', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(),
      );
      await scrollToS5Section(tester, key('alerts-feed-$s5NotificationId'));
      final icon = tester.widget<LoopRowIcon>(
        find.descendant(
          of: key('alerts-feed-$s5NotificationId'),
          matching: find.byType(LoopRowIcon),
        ),
      );
      expect(icon.tone, LoopRowIconTone.accent);
      expect(icon.icon, 'check');
    });
  });

  // The completion line of the batch: no v1 colour, no Material text slot
  // and no bare surface radius left in the two modules. The chart's named
  // plot-pixel corners and the rise / fall of a money direction (L16, kept
  // by the user's ruling) are the stated exceptions.
  test('market/ and wallet/ carry no v1 colour, theme slot or bare radius', () {
    final offenders = <String>[];
    final banned = <RegExp>[
      RegExp(r'LoopColors\.(warning|danger|chat|market|elevated)\b'),
      RegExp(r'Theme\.of\([A-Za-z]+\)\.textTheme'),
      RegExp(r'Radius\.circular\(\s*\d'),
    ];
    // Plot-pixel corners, named once (decision 0171).
    final allowed = RegExp(
      r'static const (Radius|BorderRadius) (candle|axisTag|bubble) =|'
      r'const Radius _candleCorner =',
    );
    for (final root in const <String>[
      'lib/features/market',
      'lib/features/wallet',
    ]) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (final (index, line) in lines.indexed) {
          if (allowed.hasMatch(line)) continue;
          if (banned.any((pattern) => pattern.hasMatch(line))) {
            offenders.add('${entity.path}:${index + 1}: ${line.trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
