import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// Decision 0119 · the wallet tab's OKX-style first screen.
void main() {
  // The eye test mounts the wallet page through its own pumpWidget.
  loopWatchGround();

  Matcher invalid() => throwsA(
    isA<LoopBackendFailure>().having(
      (failure) => failure.kind,
      'kind',
      LoopBackendFailureKind.invalidPayload,
    ),
  );

  LoopWalletBalances decode(Map<String, Object?> body) =>
      DioLoopV2WalletApi.decodeBalances(body, walletId: s5WalletId);

  Finder key(String value) => find.byKey(ValueKey<String>(value));

  LoopNetWorthValued valued({
    LoopNetWorthChange change = const LoopNetWorthChangeUnavailable(
      'PRICE_CHANGE_PARTIAL',
    ),
  }) => LoopNetWorthValued(
    partial: false,
    valuationCurrency: 'USD',
    valueUsd: Decimal.parse('6352.815'),
    unavailableCount: 0,
    quality: LoopFactQuality.fresh,
    priceSource: LoopFactSource.dexscreener,
    asOf: DateTime.utc(2026, 9, 8, 7, 52),
    isSpendable: false,
    change24h: change,
  );

  LoopAssetBalanceRow zeroRow() => s5Row(
    assetId: s5WbnbAssetId,
    balance: LoopBalanceAvailable(
      rawValue: '0',
      displayBalance: Decimal.zero,
      availableBalance: Decimal.zero,
      spendableBalance: Decimal.zero,
      gasReserve: Decimal.zero,
    ),
    valuation: LoopValuationAvailable(
      priceSource: LoopFactSource.dexscreener,
      fetchedAt: DateTime.utc(2026, 9, 8, 7, 52),
      quality: LoopFactQuality.fresh,
      reasonCode: null,
      proxyAsset: null,
      priceUsd: Decimal.parse('747.39'),
      valueUsd: Decimal.zero,
      change24hPct: Decimal.parse('-2.5'),
    ),
  );

  group('codec · netWorth.change24h (loop-api decision 0100)', () {
    test('(a) a figure decodes, signed, both halves exact', () {
      final balances = decode(
        s5BalancesBody(
          netWorth: s5NetWorth(
            change24h: const <String, Object?>{
              'usd': '-12.345678',
              'pct': '-0.1942',
            },
          ),
        ),
      );
      final netWorth = balances.netWorth as LoopNetWorthValued;
      final change = netWorth.change24h as LoopNetWorthChangeAvailable;
      expect(change.usd, Decimal.parse('-12.345678'));
      expect(change.pct, Decimal.parse('-0.1942'));
    });

    test('(b) null with change24hUnavailable is the server\'s reason', () {
      final balances = decode(
        s5BalancesBody(
          netWorth: s5NetWorth(
            change24h: null,
            change24hUnavailable: const <String, Object?>{
              'reasonCode': 'PRICE_CHANGE_PARTIAL',
            },
          ),
        ),
      );
      final netWorth = balances.netWorth as LoopNetWorthValued;
      expect(
        (netWorth.change24h as LoopNetWorthChangeUnavailable).reasonCode,
        'PRICE_CHANGE_PARTIAL',
      );
    });

    test('(b) null without a reason, or a figure with one, is refused', () {
      expect(
        () => decode(s5BalancesBody(netWorth: s5NetWorth(change24h: null))),
        invalid(),
      );
      expect(
        () => decode(
          s5BalancesBody(
            netWorth: s5NetWorth(
              change24hUnavailable: const <String, Object?>{
                'reasonCode': 'PRICE_CHANGE_PARTIAL',
              },
            ),
          ),
        ),
        invalid(),
      );
    });

    test('a valued net worth without the key, or a malformed figure, is '
        'refused', () {
      final missing = s5NetWorth()..remove('change24h');
      expect(() => decode(s5BalancesBody(netWorth: missing)), invalid());
      for (final change in <Map<String, Object?>>[
        <String, Object?>{'usd': '1'},
        <String, Object?>{'usd': 1, 'pct': '1'},
        <String, Object?>{'usd': '1', 'pct': '1', 'extra': '1'},
        <String, Object?>{'usd': '1e3', 'pct': '1'},
      ]) {
        expect(
          () => decode(s5BalancesBody(netWorth: s5NetWorth(change24h: change))),
          invalid(),
          reason: '$change',
        );
      }
    });

    test('(c) an unavailable net worth carries neither field', () {
      final balances = decode(
        s5BalancesBody(
          netWorth: const <String, Object?>{
            'status': 'unavailable',
            'reasonCode': 'MARKET_PRICE_PROVIDER_NOT_CONFIGURED',
          },
        ),
      );
      expect(balances.netWorth, isA<LoopNetWorthUnavailable>());
      for (final extra in <String, Object?>{
        'change24h': null,
        'change24hUnavailable': <String, Object?>{
          'reasonCode': 'PRICE_CHANGE_PARTIAL',
        },
      }.entries) {
        expect(
          () => decode(
            s5BalancesBody(
              netWorth: <String, Object?>{
                'status': 'unavailable',
                'reasonCode': 'MARKET_PRICE_PROVIDER_NOT_CONFIGURED',
                extra.key: extra.value,
              },
            ),
          ),
          invalid(),
          reason: extra.key,
        );
      }
    });

    test('a row carries change24hPct, signed or null, and never omits it', () {
      final rows = decode(
        s5BalancesBody(
          balances: <Object?>[
            s5BalanceRow(
              valuation: s5ValuationAvailable(
                quality: 'proxied',
                proxyAsset: s5WbnbAssetId,
                change24hPct: '-2.5',
              ),
            ),
            s5BalanceRow(
              assetId: s5WbnbAssetId,
              valuation: s5ValuationAvailable(change24hPct: null),
            ),
          ],
        ),
      ).balances;
      expect(
        (rows.first.valuation as LoopValuationAvailable).change24hPct,
        Decimal.parse('-2.5'),
      );
      expect(
        (rows.last.valuation as LoopValuationAvailable).change24hPct,
        isNull,
      );
      final missing = s5ValuationAvailable()..remove('change24hPct');
      expect(
        () => decode(
          s5BalancesBody(balances: <Object?>[s5BalanceRow(valuation: missing)]),
        ),
        invalid(),
      );
    });
  });

  group('总资产 · the 24h line in its three states', () {
    testWidgets('a rise is ▲ with the figure and the percent, in rise', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );

      expect(find.text('\$6,352.82'), findsOneWidget);
      final line = tester.widget<Text>(key('wallet-change24h'));
      expect(line.data, '▲ \$302.52 (+5%) · 24h');
      expect(line.style!.color, LoopColors.rise);
    });

    testWidgets('a fall is ▼ in fall', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              netWorth: valued(
                change: LoopNetWorthChangeAvailable(
                  usd: Decimal.parse('-12.3'),
                  pct: Decimal.parse('-0.1942'),
                ),
              ),
            ),
          ),
        ),
      );

      final line = tester.widget<Text>(key('wallet-change24h'));
      expect(line.data, '▼ \$12.3 (-0.19%) · 24h');
      expect(line.style!.color, LoopColors.fall);
    });

    testWidgets('null says 「24h 变动暂不可用」 once, weakly, never 0', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(netWorth: valued()),
          ),
        ),
      );

      expect(key('wallet-change24h-unavailable'), findsOneWidget);
      expect(find.text('24h 变动暂不可用'), findsOneWidget);
      expect(key('wallet-change24h'), findsNothing);
      expect(find.textContaining('(+0%)'), findsNothing);
    });

    testWidgets('an unavailable net worth draws no 24h line at all', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              netWorth: const LoopNetWorthUnavailable(
                'MARKET_PRICE_PROVIDER_NOT_CONFIGURED',
              ),
            ),
          ),
        ),
      );

      expect(key('wallet-change24h'), findsNothing);
      expect(key('wallet-change24h-unavailable'), findsNothing);
      expect(find.text('暂不可用'), findsOneWidget);
      expect(find.textContaining('暂时读不到价格'), findsOneWidget);
    });
  });

  group('the eye', () {
    testWidgets('masks the total, the 24h figure and every row amount, and '
        'is remembered for this run only', (tester) async {
      final visible = ValueNotifier<bool>(true);
      addTearDown(visible.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletReadGatewayProvider.overrideWithValue(
              FakeWalletReadGateway(),
            ),
            loopV2MetaSnapshotProvider.overrideWith(
              (ref) async => s5MetaSnapshot(),
            ),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            builder: (context, child) => LoopToastHost(child: child!),
            home: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, show, _) =>
                  show ? const WalletScreen() : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('\$6,352.82'), findsOneWidget);

      await tester.tap(key('wallet-eye'));
      await tester.pumpAndSettle();
      expect(find.text('\$6,352.82'), findsNothing);
      expect(find.text('7'), findsNothing);
      expect(find.textContaining('5,231.73'), findsNothing);
      expect(
        tester.widget<Text>(key('wallet-total-figure')).data,
        walletMaskedFigure,
      );
      expect(
        tester.widget<Text>(key('wallet-change24h')).data,
        '$walletMaskedFigure · 24h',
      );
      expect(
        tester.widget<Text>(key('wallet-balance-amount-$s5NativeAssetId')).data,
        walletMaskedFigure,
      );

      // Leaving the tab and coming back keeps the choice for this run.
      visible.value = false;
      await tester.pumpAndSettle();
      visible.value = true;
      await tester.pumpAndSettle();
      expect(find.text('\$6,352.82'), findsNothing);

      await tester.tap(key('wallet-eye'));
      await tester.pumpAndSettle();
      expect(find.text('\$6,352.82'), findsOneWidget);
    });

    testWidgets('the (i) says the total is not a spendable balance', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );

      expect(find.textContaining('不是可用余额'), findsNothing);
      await tester.tap(key('wallet-info'));
      await tester.pumpAndSettle();
      expect(key('wallet-info-sheet'), findsOneWidget);
      expect(find.textContaining('不是可用余额'), findsOneWidget);
      expect(find.textContaining('DexScreener'), findsWidgets);
    });
  });

  group('four keys', () {
    testWidgets('接收 / 发送 / 兑换 / 扫码 open their own routes', (tester) async {
      final opened = <String>[];
      await pumpS5Page(
        tester,
        WalletScreen(onNavigate: opened.add),
        wallet: FakeWalletReadGateway(),
        meta: s5MetaSnapshot(
          sendApprovals: LoopV2CapabilityAvailability.available,
          privySwap: LoopV2CapabilityAvailability.available,
          swapEvidencePending: false,
        ),
      );

      for (final entry in const <String>[
        'wallet-receive-entry',
        'wallet-send-entry',
        'wallet-swap-entry',
        'wallet-pay-entry',
      ]) {
        await tester.tap(key(entry));
        await tester.pumpAndSettle();
      }

      expect(opened, <String>[
        WalletRoute.receive(s5WalletId),
        '/wallet/send',
        '/wallet/swap',
        '/scan',
      ]);
      expect(find.text('扫码'), findsOneWidget);
      // 跨链 left the keys for the entry group.
      expect(
        tester.getTopLeft(key('wallet-bridge-entry')).dy,
        greaterThan(tester.getTopLeft(key('wallet-pay-entry')).dy),
      );
    });

    testWidgets('a closed write gate says its reason and opens nothing', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpS5Page(
        tester,
        WalletScreen(onNavigate: opened.add),
        wallet: FakeWalletReadGateway(),
      );

      await tester.tap(key('wallet-send-entry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(opened, isEmpty);
      expect(find.textContaining('链上操作'), findsWidgets);
    });
  });

  group('zero balances', () {
    testWidgets('fold by default; the switch shows them and is remembered', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(rows: <LoopAssetBalanceRow>[s5Row(), zeroRow()]),
          ),
        ),
      );

      expect(key('wallet-balance-$s5NativeAssetId'), findsOneWidget);
      expect(key('wallet-balance-$s5WbnbAssetId'), findsNothing);
      expect(key('wallet-zero-toggle'), findsOneWidget);
      expect(find.text('显示 1 项零余额资产'), findsOneWidget);

      await tester.tap(key('wallet-zero-toggle'));
      await tester.pumpAndSettle();
      expect(key('wallet-balance-$s5WbnbAssetId'), findsOneWidget);
      final value = tester.widget<Text>(
        key('wallet-balance-value-$s5WbnbAssetId'),
      );
      expect(value.data, '≈\$0');
      final move = find.descendant(
        of: key('wallet-balance-change-$s5WbnbAssetId'),
        matching: find.text('-2.50%'),
      );
      expect(tester.widget<Text>(move).style!.color, LoopColors.fall);
      // Open, the switch offers to fold them again.
      expect(find.text('隐藏零余额资产'), findsOneWidget);
    });

    testWidgets('an unread row is never folded as zero', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[
                s5Row(
                  balance: const LoopBalanceUnavailable('BSC_RPC_UNREACHABLE'),
                  valuation: const LoopValuationUnavailable(
                    'BALANCE_UNAVAILABLE',
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        key('wallet-balance-unavailable-$s5NativeAssetId'),
        findsOneWidget,
      );
      expect(key('wallet-zero-toggle'), findsNothing);
    });
  });

  group('entries', () {
    testWidgets('设置 opens the profile settings page', (tester) async {
      final opened = <String>[];
      await pumpS5Page(
        tester,
        WalletScreen(onNavigate: opened.add),
        wallet: FakeWalletReadGateway(),
      );

      await scrollToS5Section(tester, key('wallet-settings-entry'));
      await tester.tap(key('wallet-settings-entry'));
      await tester.pumpAndSettle();
      expect(opened, <String>['/profile/settings']);
    });

    testWidgets('设置 stays reachable when the wallet list was not read', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            failure: LoopChainFailureKind.unexpected,
          ),
        ),
      );

      await scrollToS5Section(tester, key('wallet-settings-entry'));
      expect(key('wallet-settings-entry'), findsOneWidget);
      expect(key('wallet-quick-actions'), findsNothing);
    });
  });

  group('tx-history scrolls on', () {
    testWidgets('the next cursor is asked only once the end is in view', (
      tester,
    ) async {
      final entries = <LoopWalletActivityEntry>[
        for (var index = 0; index < 14; index += 1)
          LoopWalletActivityEntry(
            assetId: s5WbnbAssetId,
            symbol: 'WBNB',
            decimals: 18,
            direction: LoopTransferDirection.incoming,
            counterpartyAddress: s5Address,
            rawValue: '1500000000000000000',
            displayValue: Decimal.parse('1.5'),
            transactionHash: s5TxHash,
            logIndex: index,
            blockNumber: BigInt.from(120628064),
            blockHash: s5BlockHash,
            confirmations: 101,
            status: LoopConfirmationStatus.confirmed,
            observedAt: DateTime.utc(2026, 9, 8),
          ),
      ];
      final wallet = FakeWalletReadGateway(
        activity: S5Answer<LoopWalletActivityPage>(
          value: s5Activity(items: entries, nextCursor: s5Cursor),
        ),
      );
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: wallet,
        size: const Size(390, 760),
      );

      expect(wallet.activityCursors, <String?>[null]);
      expect(find.text('加载更多'), findsNothing);

      await scrollToS5Section(tester, key('tx-history-load-more'));
      await tester.pumpAndSettle();
      expect(wallet.activityCursors, <String?>[null, s5Cursor]);
      // The same cursor answered again is not asked a second time.
      await tester.pumpAndSettle();
      expect(wallet.activityCursors, <String?>[null, s5Cursor]);
    });
  });

  test('a zero row is one the read answered with exactly zero', () {
    expect(walletRowIsZero(zeroRow()), isTrue);
    expect(walletRowIsZero(s5Row()), isFalse);
    expect(
      walletRowIsZero(
        s5Row(balance: const LoopBalanceUnavailable('BSC_RPC_UNREACHABLE')),
      ),
      isFalse,
    );
    expect(
      walletRowIsZero(
        s5Row(
          assetId: s5WbnbAssetId,
          balance: (zeroRow().balance),
          pending: LoopPendingAvailable(rawValue: '1', value: Decimal.one),
        ),
      ),
      isFalse,
    );
    expect(walletRowChangeText(Decimal.parse('0')), '0%');
  });
}
