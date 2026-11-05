// S368 · decision 0292: the trade band's rail stops before its chevron, the
// tape's day header is a 13 grey caption, and a promotion may open the board
// page /mining/rank.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_atmosphere.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _pumpPlain(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

Launch2Activity _trade(int i) => Launch2Activity(
  kind: Launch2ActivityKind.curveBuy,
  instanceId: 'i$i',
  ticker: 'GEM',
  name: '宝石',
  at: DateTime.utc(2026, 11, 5, 12, i),
  actor: '0x${'$i'.padLeft(40, '0')}',
  amountUsd1: Decimal.fromInt(237),
  transactionHash: '0x$i',
);

LoopWalletActivityEntry _entry(String id, DateTime at) {
  final index = id.codeUnitAt(0) - 'a'.codeUnitAt(0) + 1;
  return LoopWalletActivityEntry(
    assetId: s5WbnbAssetId,
    symbol: 'WBNB',
    decimals: 18,
    direction: LoopTransferDirection.incoming,
    counterpartyAddress: s5Address,
    rawValue: '1000000000000000000',
    displayValue: s5Decimal('1'),
    transactionHash: s5TxHash,
    logIndex: index,
    blockNumber: BigInt.from(120628064 + index),
    blockHash: s5BlockHash,
    confirmations: 101,
    status: LoopConfirmationStatus.confirmed,
    observedAt: at.toUtc(),
  );
}

Map<String, Object?> _promotions(String deeplink) => <String, Object?>{
  'items': <Object?>[
    <String, Object?>{
      'id': '5b0f8a2e-6d1c-4e7a-9b3f-2c8d4e6f1a01',
      'title': 'LOOP 挖矿算力周榜',
      'subtitle': '看看本周谁的算力最高',
      'imageUrl': null,
      'deeplink': deeplink,
      'startsAt': '2026-10-08T00:00:00.000Z',
      'endsAt': '2027-01-01T00:00:00.000Z',
      'order': 1,
    },
  ],
  'configVersion': 'intelPromotionsV1',
  'effectiveAt': '2026-10-08T00:00:00.000Z',
  'contractVersion': '2.0',
};

void main() {
  group('第 1 条 · the trade band', () {
    testWidgets('the rail is cut 8 before the chevron and fades out', (
      tester,
    ) async {
      var opened = 0;
      await _pumpPlain(
        tester,
        Launch2TradeTicker(
          items: <Launch2Activity>[for (var i = 1; i <= 6; i++) _trade(i)],
          onOpenAll: () => opened++,
        ),
      );
      await tester.pump();
      final mask = _key('launch2-ticker-rail-mask');
      expect(mask, findsOneWidget);
      final ground = _key('launch2-ticker-all-ground');
      final railRight = tester.getTopRight(mask).dx;
      final chevronLeft = tester.getTopLeft(ground).dx;
      expect(railRight, lessThanOrEqualTo(chevronLeft));
      expect(
        chevronLeft - railRight,
        moreOrLessEquals(Launch2TradeTicker.allGap, epsilon: 1),
      );
      // The rail clips: nothing it paints reaches past its own right edge.
      expect(
        find.descendant(of: mask, matching: find.byType(ClipRect)),
        findsWidgets,
      );
      // The chevron stands on an opaque ground of its own.
      final box = tester.widget<Container>(ground).decoration! as BoxDecoration;
      expect(box.gradient, isNull);
      expect(box.color, Launch2TradeTicker.fade);
      expect(box.color!.a, 1.0);
      // The right end fades over its last 16.
      final width = tester.getSize(mask).width;
      final stops = launch2TickerRailStops(width);
      expect(stops, hasLength(4));
      expect(
        (stops[3] - stops[2]) * width,
        moreOrLessEquals(Launch2TradeTicker.railFade, epsilon: 0.01),
      );
      expect(stops[1] * width, moreOrLessEquals(18, epsilon: 0.01));
      // 「● 实时」 still holds the left end.
      expect(_key('launch2-ticker-live'), findsOneWidget);
      expect(
        tester.getTopLeft(_key('launch2-ticker-live')).dx,
        lessThan(tester.getTopLeft(mask).dx),
      );
      await tester.tap(_key('launch2-ticker-all'));
      expect(opened, 1);
    });

    testWidgets('an empty band keeps its full width and no chevron', (
      tester,
    ) async {
      await _pumpPlain(
        tester,
        Launch2TradeTicker(items: const <Launch2Activity>[], onOpenAll: () {}),
      );
      expect(_key('launch2-ticker-empty'), findsOneWidget);
      expect(_key('launch2-ticker-all'), findsNothing);
      expect(_key('launch2-ticker-rail-mask'), findsNothing);
    });

    test('the stops stay ordered on a very narrow rail', () {
      expect(launch2TickerRailStops(0), <double>[0, 0, 1, 1]);
      final narrow = launch2TickerRailStops(20);
      for (var i = 1; i < narrow.length; i++) {
        expect(narrow[i], greaterThanOrEqualTo(narrow[i - 1]));
      }
    });
  });

  group('第 6 条 · the tape day header', () {
    testWidgets('the header is a 13 Text3 caption, not a section title', (
      tester,
    ) async {
      await _pumpPlain(
        tester,
        const Column(
          children: <Widget>[
            WalletActivityDayHeader(label: 'Today'),
            WalletActivityDayHeader(label: 'Yesterday'),
            WalletActivityDayHeader(label: 'Oct 21'),
          ],
        ),
      );
      expect(find.byType(LoopLabel), findsNothing);
      for (final label in <String>['Today', 'Yesterday', 'Oct 21']) {
        final style = tester.widget<Text>(find.text(label)).style!;
        expect(style.fontSize, 13);
        expect(style.color, LoopColors.text3);
        expect(style.fontSize, lessThan(LoopType.sectionTitle.fontSize!));
      }
      final header = find.byType(WalletActivityDayHeader).first;
      final text = find.text('Today');
      expect(
        tester.getTopLeft(text).dy - tester.getTopLeft(header).dy,
        moreOrLessEquals(16, epsilon: 0.5),
      );
      expect(
        tester.getBottomLeft(header).dy - tester.getBottomLeft(text).dy,
        moreOrLessEquals(8, epsilon: 0.5),
      );
    });

    testWidgets('on the tape the header starts where its rows start', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            value: s5Activity(
              items: <LoopWalletActivityEntry>[
                _entry('a', DateTime(2026, 9, 8, 12)),
                _entry('b', DateTime(2026, 9, 1, 9)),
              ],
            ),
          ),
        ),
      );
      final header = find.byKey(
        const ValueKey<String>('tx-history-day-2026-09-08'),
      );
      expect(header, findsOneWidget);
      final text = find.descendant(of: header, matching: find.byType(Text));
      final style = tester.widget<Text>(text).style!;
      expect(style.fontSize, 13);
      expect(style.color, LoopColors.text3);
      final row = find.byType(LoopRecordRow).first;
      final icon = find.descendant(of: row, matching: find.byType(LoopRowIcon));
      expect(icon, findsOneWidget);
      expect(
        tester.getTopLeft(text).dx,
        moreOrLessEquals(tester.getTopLeft(icon).dx, epsilon: 1),
      );
    });
  });

  group('第 9 条 · the promotion link to the boards', () {
    test('/mining/rank decodes; the old links still do; others do not', () {
      for (final link in <String>[
        '/mining/rank',
        '/intel',
        '/square',
        '/meme',
        '/community/profile?id=5b0f8a2e-6d1c-4e7a-9b3f-2c8d4e6f1a09',
      ]) {
        expect(
          DioLoopV2MarketApi.decodePromotions(_promotions(link))
              .items
              .single
              .deeplink,
          link,
        );
      }
      for (final link in <String>[
        '/mining',
        '/mining/rank/x',
        '/mining/rank?scope=users',
        '/mining/ranks',
        '/wallet',
        'https://evil.example',
      ]) {
        expect(
          () => DioLoopV2MarketApi.decodePromotions(_promotions(link)),
          throwsA(isA<LoopBackendFailure>()),
          reason: link,
        );
      }
    });

    testWidgets('/mining/rank is pushed; /intel still only picks the tab', (
      tester,
    ) async {
      late BuildContext context;
      late WidgetRef ref;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (c, r, _) {
                context = c;
                ref = r;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final pushed = <String>[];
      IntelScreen.openPromotion(context, ref, '/mining/rank', pushed.add);
      expect(pushed, <String>['/mining/rank']);
      IntelScreen.openPromotion(context, ref, '/intel', pushed.add);
      expect(pushed, <String>['/mining/rank']);
      expect(container.read(loopTabSegmentMemoryProvider)['intel'], 0);
    });
  });
}
