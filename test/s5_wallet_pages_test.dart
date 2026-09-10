import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

void main() {
  group('wallet', () {
    testWidgets('loading shows a skeleton and no balance', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(pending: true),
        ),
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('every figure states the block it was read at', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );

      expect(find.textContaining('区块 120628164'), findsOneWidget);
      expect(find.textContaining('15 确认'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.textContaining('可动用 6.995'), findsOneWidget);
    });

    testWidgets('the gas reserve comes from the server, never a constant', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[
                s5Row(
                  balance: LoopBalanceAvailable(
                    rawValue: '7000000000000000000',
                    displayBalance: Decimal.parse('7'),
                    availableBalance: Decimal.parse('7'),
                    spendableBalance: Decimal.parse('6.99'),
                    gasReserve: Decimal.parse('0.01'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('手续费保留 0.005 BNB'), findsOneWidget);
      expect(find.textContaining('walletGasReserveV1'), findsOneWidget);
    });

    testWidgets('an unreadable row says so and never renders zero', (
      tester,
    ) async {
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
              netWorth: LoopNetWorthValued(
                partial: true,
                valuationCurrency: 'USD',
                valueUsd: Decimal.zero,
                unavailableCount: 1,
                quality: LoopFactQuality.fresh,
                priceSource: LoopFactSource.dexscreener,
                asOf: DateTime.utc(2026, 9, 8, 7),
                isSpendable: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('读不到'), findsOneWidget);
      expect(find.textContaining('RPC 端点当前不可达'), findsWidgets);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a proxied native price is labelled', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );

      expect(find.text('以 WBNB 计价'), findsWidgets);
    });

    testWidgets('the deferred security rows never state a count', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-security-unavailable')),
      );
      expect(find.textContaining('安全中心 / DApp'), findsOneWidget);
      expect(find.textContaining('8 个有效授权'), findsNothing);
      expect(find.textContaining('4 条链已启用'), findsNothing);
    });

    testWidgets('the funds actions open their own manifest slugs', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpS5Page(
        tester,
        WalletScreen(onNavigate: opened.add),
        wallet: FakeWalletReadGateway(),
      );

      for (final entry in const <(String, String)>[
        ('wallet-pay-entry', '/pay'),
        ('wallet-swap-entry', '/wallet/swap'),
        ('wallet-send-entry', '/wallet/send'),
        ('wallet-bridge-entry', '/wallet/bridge'),
      ]) {
        await scrollToS5Section(tester, find.byKey(ValueKey<String>(entry.$1)));
        await tester.tap(find.byKey(ValueKey<String>(entry.$1)));
        await tester.pumpAndSettle();
      }

      // Each entry opens its own page, which owns its unavailable state; this
      // page never speaks for the four destinations.
      expect(opened, <String>[
        '/pay',
        '/wallet/swap',
        '/wallet/send',
        '/wallet/bridge',
      ]);
    });

    testWidgets('an unavailable chain capability stops the page', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        meta: s5MetaSnapshot(bscRead: LoopV2CapabilityAvailability.unavailable),
      );

      expect(
        find.byKey(const ValueKey<String>('wallet-capability-block')),
        findsOneWidget,
      );
      expect(find.textContaining('没有配置任何 BSC RPC 端点'), findsOneWidget);
    });

    testWidgets('a disconnected provider is an error, not an empty wallet', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            failure: LoopChainFailureKind.unavailable,
          ),
        ),
      );

      expect(find.textContaining('没有回退到演示数据'), findsOneWidget);
      expect(find.text('这个账号还没有钱包'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('wallet-directory-create-wallet')),
        findsNothing,
      );
    });

    testWidgets('an empty directory is "no wallet yet", never "not read"', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(directory: emptyDirectoryAnswer()),
        privy: WalletCreatingTestPrivyGateway(),
      );

      expect(find.text('这个账号还没有钱包'), findsOneWidget);
      expect(find.textContaining('尚未读取成功'), findsNothing);
      expect(find.textContaining('创建后余额会出现在这里'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('wallet-directory-create-wallet')),
        findsOneWidget,
      );
    });

    testWidgets(
      'creating a wallet re-reads the directory it was missing from',
      (tester) async {
        final privy = WalletCreatingTestPrivyGateway();
        final wallet = FakeWalletReadGateway(directory: emptyDirectoryAnswer());
        await pumpS5Page(
          tester,
          const WalletScreen(),
          wallet: wallet,
          privy: privy,
        );
        expect(wallet.directoryReads, 1);

        await tester.tap(
          find.byKey(const ValueKey<String>('wallet-directory-create-wallet')),
        );
        await tester.pumpAndSettle();

        expect(privy.creationPrincipals, <String>['did:privy:test-widget']);
        // The server projects `/v2/wallets` from Privy, so the list this page
        // rendered predates the wallet and is read again.
        expect(wallet.directoryReads, 2);
        expect(find.text('钱包已创建'), findsOneWidget);
      },
    );

    testWidgets('a failed creation states the provider reason and stays', (
      tester,
    ) async {
      final privy = WalletCreatingTestPrivyGateway(
        failure: const PrivyGatewayException('Privy 暂时不能创建钱包。'),
      );
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(directory: emptyDirectoryAnswer()),
        privy: privy,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('wallet-directory-create-wallet')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Privy 暂时不能创建钱包。'), findsOneWidget);
      expect(find.text('这个账号还没有钱包'), findsOneWidget);
      expect(find.text('钱包已创建'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('wallet-directory-create-wallet')),
        findsOneWidget,
      );
    });

    testWidgets('the button is disabled while a creation is in flight', (
      tester,
    ) async {
      final gate = Completer<PrivyWalletCreationResult>();
      final privy = WalletCreatingTestPrivyGateway(pending: gate.future);
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(directory: emptyDirectoryAnswer()),
        privy: privy,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('wallet-directory-create-wallet')),
      );
      await tester.pump();

      expect(find.text('创建中…'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('wallet-directory-create-wallet')),
      );
      await tester.pump();
      expect(privy.creationPrincipals, hasLength(1));

      gate.complete(
        const PrivyWalletCreationResult(
          privyUserId: 'did:privy:test-widget',
          wallet: PrivyWalletSummary(address: walletCreationAddress),
        ),
      );
      await tester.pumpAndSettle();
      expect(privy.creationPrincipals, hasLength(1));
    });

    testWidgets('a session that may not create a wallet offers no button', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(directory: emptyDirectoryAnswer()),
      );

      expect(find.text('这个账号还没有钱包'), findsOneWidget);
      expect(find.textContaining('当前会话未完成验证'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('wallet-directory-create-wallet')),
        findsNothing,
      );
    });

    testWidgets('a read wallet list with no active wallet is not "no wallet"', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            value: s5Directory(activeWalletId: null),
          ),
        ),
        privy: WalletCreatingTestPrivyGateway(),
      );

      expect(find.text('还没有选定当前钱包'), findsOneWidget);
      expect(find.text('这个账号还没有钱包'), findsNothing);
      expect(find.textContaining('尚未读取成功'), findsNothing);
    });
  });

  group('networth', () {
    testWidgets('the total is never presented as a spendable balance', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetWorthScreen(),
        wallet: FakeWalletReadGateway(),
      );

      expect(find.text('\$6,352.82'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('wallet-networth-not-spendable')),
        findsOneWidget,
      );
      expect(find.text('不是可用余额'), findsOneWidget);
    });

    testWidgets('a partial total says how many rows have no price', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetWorthScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              netWorth: LoopNetWorthValued(
                partial: true,
                valuationCurrency: 'USD',
                valueUsd: Decimal.parse('100'),
                unavailableCount: 2,
                quality: LoopFactQuality.stale,
                priceSource: LoopFactSource.dexscreener,
                asOf: DateTime.utc(2026, 9, 8, 7),
                isSpendable: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('部分估值 · 2 项无价格'), findsOneWidget);
      expect(find.textContaining('只是已估值资产的合计，不是总资产'), findsOneWidget);
      expect(find.text('数据可能过期'), findsWidgets);
    });

    testWidgets('the trend chart is unavailable, not an invented series', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetWorthScreen(),
        wallet: FakeWalletReadGateway(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('networth-trend-unavailable')),
      );
      expect(find.textContaining('净值走势与 24h 涨跌'), findsOneWidget);
    });

    testWidgets('an unavailable net worth states its reason', (tester) async {
      await pumpS5Page(
        tester,
        const NetWorthScreen(),
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

      expect(find.text('净值不可用'), findsWidgets);
      expect(find.textContaining('价格来源尚未配置'), findsWidgets);
    });
  });

  group('asset', () {
    testWidgets('the five balance meanings are shown separately', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletAssetScreen(assetId: s5NativeAssetId),
        wallet: FakeWalletReadGateway(),
        chain: FakeChainGateway(),
      );

      expect(find.text('链上余额'), findsOneWidget);
      expect(find.text('可用'), findsOneWidget);
      expect(find.text('可动用（扣除手续费保留）'), findsOneWidget);
      expect(find.text('手续费保留'), findsOneWidget);
      expect(find.text('最小单位'), findsOneWidget);
      expect(find.text('7000000000000000000'), findsOneWidget);
    });

    testWidgets('a proxied valuation names the asset it borrowed', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletAssetScreen(assetId: s5NativeAssetId),
        wallet: FakeWalletReadGateway(),
        chain: FakeChainGateway(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-asset-proxied')),
      );
      expect(find.textContaining('代理资产'), findsOneWidget);
    });

    testWidgets('a misaligned cross-check never changes the chain figure', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletAssetScreen(assetId: s5NativeAssetId),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[
                s5Row(
                  crossCheck: const LoopBalanceCrossCheck(
                    status: LoopCrossCheckStatus.unaligned,
                    reasonCode: null,
                    blockDelta: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
        chain: FakeChainGateway(),
      );

      expect(find.text('7'), findsWidgets);
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-asset-crosscheck')),
      );
      expect(find.textContaining('交叉核对不会改变它'), findsOneWidget);
    });

    testWidgets('a malformed asset identity fails closed', (tester) async {
      await pumpS5Page(
        tester,
        const WalletAssetScreen(assetId: 'BNB'),
        wallet: FakeWalletReadGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('wallet-asset-invalid-identity')),
        findsOneWidget,
      );
    });
  });

  group('receive', () {
    testWidgets('renders the QR, the address and the EIP-681 uri', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
      );

      expect(find.byKey(const ValueKey<String>('receive-qr')), findsOneWidget);
      expect(find.text(s5Address), findsOneWidget);
      expect(find.text('ethereum:$s5Address@56'), findsOneWidget);
      expect(find.textContaining('只接收 BNB Smart Chain'), findsOneWidget);
    });

    testWidgets('no other network is listed, not even as a placeholder', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
      );

      expect(find.text('Ethereum'), findsNothing);
      expect(find.text('Solana'), findsNothing);
      expect(find.text('Base'), findsNothing);
    });

    testWidgets('copying puts the full address on the clipboard', (
      tester,
    ) async {
      final writes = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') writes.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('receive-copy-address')),
      );
      await tester.pumpAndSettle();

      // The clipboard carries the exact full address, never the truncated
      // display form the wallet list uses.
      expect(writes, hasLength(1));
      expect(
        (writes.single.arguments as Map<Object?, Object?>)['text'],
        s5Address,
      );
      expect(find.text('地址已复制'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('receive-copy-uri')));
      await tester.pumpAndSettle();

      expect(
        (writes.last.arguments as Map<Object?, Object?>)['text'],
        'ethereum:$s5Address@56',
      );
      expect(find.text('付款链接已复制'), findsOneWidget);
    });

    testWidgets('an unavailable receive read states its reason', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          receive: S5Answer<LoopWalletReceive>(
            failure: LoopChainFailureKind.unavailable,
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>('receive-qr')), findsNothing);
      expect(find.textContaining('没有回退到演示数据'), findsOneWidget);
    });
  });

  group('wallets', () {
    testWidgets('addresses are truncated and grouped by kind', (tester) async {
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(),
      );

      expect(find.text('PRIVY 嵌入式钱包'), findsOneWidget);
      expect(find.text('已连接的外部钱包'.toUpperCase()), findsOneWidget);
      expect(find.textContaining('0x0000…00a1'), findsOneWidget);
      // The full address is never rendered on this page.
      expect(find.text(s5Address), findsNothing);
      expect(find.text('使用中'), findsOneWidget);
    });

    testWidgets('switching confirms first and sends the expected active id', (
      tester,
    ) async {
      final wallet = FakeWalletReadGateway();
      await pumpS5Page(tester, const WalletManagerScreen(), wallet: wallet);

      await tester.tap(
        find.byKey(const ValueKey<String>('wallet-row-$s5OtherWalletId')),
      );
      await tester.pumpAndSettle();
      expect(wallet.switched, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-activate-confirm')),
      );
      await tester.pumpAndSettle();

      expect(wallet.switched, <String>[s5OtherWalletId]);
      expect(wallet.expectedActive, <String?>[s5WalletId]);
      expect(find.text('已切换活跃钱包'), findsOneWidget);
    });

    testWidgets('a concurrent switch reports the conflict', (tester) async {
      final wallet = FakeWalletReadGateway(
        switchFailure: LoopChainFailureKind.versionConflict,
      );
      await pumpS5Page(tester, const WalletManagerScreen(), wallet: wallet);

      await tester.tap(
        find.byKey(const ValueKey<String>('wallet-row-$s5OtherWalletId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-activate-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text('活跃钱包没有切换'), findsOneWidget);
      expect(find.textContaining('本次没有覆盖任何内容'), findsOneWidget);
      expect(find.text('已切换活跃钱包'), findsNothing);
    });

    testWidgets('an archived wallet cannot be activated', (tester) async {
      final wallet = FakeWalletReadGateway(
        directory: S5Answer<LoopWalletDirectory>(
          value: LoopWalletDirectory(
            wallets: <LoopWalletAccount>[
              LoopWalletAccount(
                walletId: s5OtherWalletId,
                address: s5Address,
                kind: LoopWalletKind.external,
                status: LoopWalletStatus.archived,
                isActive: false,
                firstSeenAt: DateTime.utc(2026, 9, 8),
                lastSeenAt: DateTime.utc(2026, 9, 8),
              ),
            ],
            activeWalletId: null,
            observedAt: DateTime.utc(2026, 9, 8),
          ),
        ),
      );
      await pumpS5Page(tester, const WalletManagerScreen(), wallet: wallet);

      expect(find.text('已归档'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('wallet-row-$s5OtherWalletId')),
      );
      await tester.pumpAndSettle();
      expect(wallet.switched, isEmpty);
    });

    testWidgets('an empty list offers the one creation path, not a retry', (
      tester,
    ) async {
      final privy = WalletCreatingTestPrivyGateway();
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(directory: emptyDirectoryAnswer()),
        privy: privy,
      );

      expect(find.text('这个账号还没有钱包'), findsOneWidget);
      expect(find.textContaining('还没有读到'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-create-wallet')),
      );
      await tester.pumpAndSettle();
      expect(privy.creationPrincipals, <String>['did:privy:test-widget']);
    });

    testWidgets('a failed read still says the list was not read', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            failure: LoopChainFailureKind.unexpected,
          ),
        ),
        privy: WalletCreatingTestPrivyGateway(),
      );

      expect(find.text('这个账号还没有钱包'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('wallets-create-wallet')),
        findsNothing,
      );
    });
  });

  group('tx-history', () {
    testWidgets('a row carries its transaction, block and confirmations', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
      );

      expect(find.text('收到 WBNB'), findsOneWidget);
      expect(
        find.textContaining('已确认 · 101 确认 · 区块 120628064'),
        findsOneWidget,
      );
      expect(find.text('1.5'), findsOneWidget);
      expect(find.textContaining('数据落后 33 块'), findsOneWidget);
    });

    testWidgets('a reorged row is marked as rolled back', (tester) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            value: s5Activity(
              items: <LoopWalletActivityEntry>[
                LoopWalletActivityEntry(
                  assetId: s5WbnbAssetId,
                  symbol: 'WBNB',
                  decimals: 18,
                  direction: LoopTransferDirection.outgoing,
                  counterpartyAddress: s5Address,
                  rawValue: '1',
                  displayValue: Decimal.parse('0.000000000000000001'),
                  transactionHash: s5TxHash,
                  logIndex: 4,
                  blockNumber: BigInt.from(1),
                  blockHash: s5BlockHash,
                  confirmations: 0,
                  status: LoopConfirmationStatus.reorged,
                  observedAt: DateTime.utc(2026, 9, 8),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('已回滚'), findsWidgets);
    });

    testWidgets('the native and cross-chain segments are unavailable', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(),
      );

      await tester.tap(find.byKey(const ValueKey<String>('tx-history-seg-3')));
      await tester.pumpAndSettle();
      expect(find.textContaining('原生 BNB 转账历史本步没有来源'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('tx-history-seg-4')));
      await tester.pumpAndSettle();
      expect(find.textContaining('跨链与挖矿领取记录本步没有来源'), findsOneWidget);
    });

    testWidgets('an indexer that never ran is unavailable, not empty', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            failure: LoopChainFailureKind.indexingDelayed,
          ),
        ),
      );

      expect(find.textContaining('不是"没有记录"'), findsOneWidget);
      expect(find.text('还没有链上活动'), findsNothing);
    });

    testWidgets('a next page is requested with the opaque cursor', (
      tester,
    ) async {
      final wallet = FakeWalletReadGateway(
        activity: S5Answer<LoopWalletActivityPage>(
          value: s5Activity(nextCursor: s5Cursor),
        ),
      );
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: wallet,
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('tx-history-load-more')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('tx-history-load-more')),
      );
      await tester.pumpAndSettle();

      expect(wallet.activityCursors, <String?>[null, s5Cursor]);
      // The repeated row is not appended twice.
      expect(find.text('收到 WBNB'), findsOneWidget);
    });
  });

  group('networks', () {
    testWidgets(
      'endpoints are shown by opaque reference with latency and lag',
      (tester) async {
        await pumpS5Page(
          tester,
          const NetworksScreen(),
          chain: FakeChainGateway(),
        );

        expect(find.text('rpc-2bd52ca6d267'), findsOneWidget);
        expect(find.textContaining('延迟 515ms'), findsOneWidget);
        expect(find.textContaining('落后 0 块'), findsOneWidget);
        expect(find.text('1 / 1 正常'), findsOneWidget);
        // A URL is never rendered or guessed.
        expect(find.textContaining('https://'), findsNothing);
      },
    );

    testWidgets('a degraded endpoint carries the 异常 badge', (tester) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(
          status: S5Answer<LoopChainStatus>(
            value: s5Status(endpointStatus: LoopEndpointStatus.degraded),
          ),
        ),
      );

      expect(find.text('异常'), findsWidgets);
    });

    testWidgets('a chain-id mismatch makes the whole page unusable', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(
          status: S5Answer<LoopChainStatus>(value: s5Status(mismatched: true)),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('networks-chain-mismatch')),
        findsOneWidget,
      );
      expect(find.text('rpc-2bd52ca6d267'), findsNothing);
    });

    testWidgets('an indexer lane that never ran states its reason', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('lane-erc20_transfer')),
      );
      expect(find.text('ERC-20 转账索引'), findsOneWidget);
      expect(find.text('未运行'), findsOneWidget);
    });

    testWidgets('custom RPC and testnets are unavailable, not toggles', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('networks-custom-rpc')),
      );
      expect(find.textContaining('自定义 RPC 与自行添加网络本步不开放'), findsOneWidget);
    });
  });
}

const walletCreationAddress = '0x00000000000000000000000000000000000000c3';

/// `GET /v2/wallets` answered, and answered "this account owns no wallet".
S5Answer<LoopWalletDirectory> emptyDirectoryAnswer() =>
    S5Answer<LoopWalletDirectory>(
      value: LoopWalletDirectory(
        wallets: const <LoopWalletAccount>[],
        activeWalletId: null,
        observedAt: DateTime.utc(2026, 9, 9, 5),
      ),
    );

/// A verified session whose Privy wallet creation can be driven by a test.
class WalletCreatingTestPrivyGateway implements PrivyAuthGateway {
  WalletCreatingTestPrivyGateway({this.failure, this.pending});

  final PrivyGatewayException? failure;
  final Future<PrivyWalletCreationResult>? pending;
  final List<String> creationPrincipals = <String>[];

  @override
  Future<PrivySessionSnapshot> restoreSession() async {
    return const PrivySessionSnapshot(
      PrivySessionKind.authenticated,
      account: PrivyAccountSummary(privyUserId: 'did:privy:test-widget'),
    );
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) {
    creationPrincipals.add(expectedPrivyUserId);
    final held = pending;
    if (held != null) return held;
    final reason = failure;
    if (reason != null) {
      return Future<PrivyWalletCreationResult>.error(reason);
    }
    return Future<PrivyWalletCreationResult>.value(
      PrivyWalletCreationResult(
        privyUserId: expectedPrivyUserId,
        wallet: const PrivyWalletSummary(address: walletCreationAddress),
      ),
    );
  }

  @override
  Future<String> getCurrentAccessToken() async => 'test-access-token';

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendEmailCode(String email) {
    throw UnsupportedError('This gateway does not send OTPs.');
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) {
    throw UnsupportedError('This gateway does not verify OTPs.');
  }
}
