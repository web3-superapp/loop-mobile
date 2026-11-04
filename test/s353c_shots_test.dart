// S353c · decision 0280: 我的 and another account's page against the Figma
// wallet frames (docs/58 §5.10–§5.13, §5.19), in English at 390 and 360,
// before and after. Also the English overflow pages handed to this batch.
// Runs only with `--dart-define=LOOP_SHOTS=true`; the PNGs go to
// `LOOP_SHOTS_DIR` with `LOOP_SHOTS_TAG` (before / after) in the name.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/profile/support/support_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/me_page_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s8_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment('LOOP_SHOTS_DIR');
const String _tag = String.fromEnvironment(
  'LOOP_SHOTS_TAG',
  defaultValue: 'after',
);

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(loopLoadShotFonts);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name-$_tag.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// A week of stored net worth with a ¥ line and a 24 h move.
final class _History implements WalletNetWorthHistoryGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopNetWorthHistory> loadNetWorthHistory(
    String walletId,
    LoopNetWorthRange range,
  ) async => LoopNetWorthHistory(
    range: range,
    points: <LoopNetWorthPoint>[
      for (final (index, value) in const <String>[
        '5120.10',
        '5480.00',
        '5302.40',
        '5810.90',
        '5650.00',
        '6120.30',
        '6352.82',
      ].indexed)
        LoopNetWorthPoint(
          at: DateTime.utc(2026, 10, 8 + index),
          netWorthUsd: Decimal.parse(value),
        ),
    ],
    change24h: LoopNetWorthChangeAvailable(
      usd: Decimal.parse('232.52'),
      pct: Decimal.parse('3.8'),
    ),
    fiat: LoopNetWorthFiat(
      currency: 'CNY',
      rate: Decimal.parse('7.1125'),
      amount: Decimal.parse('45184.43'),
    ),
    source: 'loop_networth_snapshots',
    observedAt: DateTime.utc(2026, 10, 15, 0, 5),
  );
}

Future<void> _section(WidgetTester tester, String bar, String id) async {
  final cell = find.descendant(
    of: find.byKey(ValueKey<String>(bar)),
    matching: find.byKey(ValueKey<String>('loop-profile-section-$id')),
  );
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

void main() {
  loopWatchGround();

  for (final width in <double>[390, 360]) {
    final w = width.toInt();
    final screen = Size(width, width == 390 ? 844 : 800);
    final tall = Size(width, 1400);

    testWidgets('me · holdings $w', skip: !_shots, (tester) async {
      await pumpMePage(tester, size: screen);
      await _shot(tester, 'me-holdings-$w');
    });

    testWidgets('me · history $w', skip: !_shots, (tester) async {
      await pumpMePage(
        tester,
        size: screen,
        overrides: [
          walletNetWorthHistoryGatewayProvider.overrideWithValue(_History()),
        ],
      );
      await _shot(tester, 'me-history-$w');
    });

    testWidgets('me · holdings full $w', skip: !_shots, (tester) async {
      await pumpMePage(tester, size: tall);
      await _shot(tester, 'me-holdings-full-$w');
    });

    testWidgets('me · holdings empty $w', skip: !_shots, (tester) async {
      await pumpMePage(
        tester,
        balances: s5Balances(rows: const <LoopAssetBalanceRow>[]),
        size: tall,
      );
      await _shot(tester, 'me-holdings-empty-$w');
    });

    testWidgets('me · trades $w', skip: !_shots, (tester) async {
      await pumpMePage(
        tester,
        activity: meLongTape(nextCursor: null),
        size: tall,
      );
      await _section(tester, 'me-sections', 'trades');
      await _shot(tester, 'me-trades-$w');
    });

    testWidgets('me · communities $w', skip: !_shots, (tester) async {
      await pumpMePage(tester, size: tall);
      await _section(tester, 'me-sections', 'communities');
      await _shot(tester, 'me-communities-$w');
    });

    testWidgets('me · communities empty $w', skip: !_shots, (tester) async {
      await pumpMePage(
        tester,
        home: meHome(
          joined: const <JoinedCommunity>[],
          owned: const <OwnedCommunity>[],
        ),
        size: tall,
      );
      await _section(tester, 'me-sections', 'communities');
      await _shot(tester, 'me-communities-empty-$w');
    });

    testWidgets('user · holdings $w', skip: !_shots, (tester) async {
      await pumpOtherProfile(tester, size: screen);
      await _shot(tester, 'user-holdings-$w');
    });

    testWidgets('user · trades $w', skip: !_shots, (tester) async {
      await pumpOtherProfile(tester, size: tall);
      await _section(tester, 'user-profile-sections', 'trades');
      await _shot(tester, 'user-trades-$w');
    });

    testWidgets('user · communities $w', skip: !_shots, (tester) async {
      await pumpOtherProfile(tester, size: tall);
      await _section(tester, 'user-profile-sections', 'communities');
      await _shot(tester, 'user-communities-$w');
    });

    testWidgets('user · empty $w', skip: !_shots, (tester) async {
      await pumpOtherProfile(tester, empty: true, size: screen);
      await _shot(tester, 'user-holdings-empty-$w');
    });

    testWidgets('wallet asset $w', skip: !_shots, (tester) async {
      await pumpS5Page(
        tester,
        const WalletAssetScreen(assetId: s5WbnbAssetId),
        wallet: FakeWalletReadGateway(),
        chain: FakeChainGateway(),
        size: screen,
      );
      await _shot(tester, 'wallet-asset-$w');
    });

    testWidgets('watchlist editor $w', skip: !_shots, (tester) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(),
        size: screen,
      );
      await _shot(tester, 'watchlist-editor-$w');
    });

    testWidgets('support $w', skip: !_shots, (tester) async {
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: FakeSupportGateway(),
        size: screen,
      );
      await _shot(tester, 'support-$w');
    });
  }
}
