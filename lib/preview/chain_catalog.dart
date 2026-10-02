// Deterministic memory-only display specimens. No provider observations.
import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

const previewChainWalletId = '0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const previewChainOtherWalletId = '1c3d2e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f';
const previewChainRecommendationId = '4f6a5b7c-8d9e-4fa0-b1c2-d3e4f5a6b7c8';
const previewChainNativeAssetId = 'eip155:56:native';
const previewChainWbnbAssetId =
    'eip155:56:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c';
const previewChainUsdtAssetId =
    'eip155:56:0x55d398326f99059ff775485246999027b3197955';
const previewChainAddress = '0x00000000000000000000000000000000000000a1';
const previewChainPoolAddress = '0x3669000000000000000000000000000000000001';

const previewChainTxHash =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const previewChainBlockHash =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
Decimal previewChainDecimal(String value) => Decimal.parse(value);

LoopWalletDirectory previewChainDirectory({
  String? activeWalletId = previewChainWalletId,
}) => LoopWalletDirectory(
  wallets: <LoopWalletAccount>[
    LoopWalletAccount(
      walletId: previewChainWalletId,
      address: previewChainAddress,
      kind: LoopWalletKind.embedded,
      status: LoopWalletStatus.active,
      isActive: activeWalletId == previewChainWalletId,
      firstSeenAt: DateTime.utc(2026, 9, 8),
      lastSeenAt: DateTime.utc(2026, 9, 8),
    ),
    LoopWalletAccount(
      walletId: previewChainOtherWalletId,
      address: '0x00000000000000000000000000000000000000b2',
      kind: LoopWalletKind.external,
      status: LoopWalletStatus.active,
      isActive: activeWalletId == previewChainOtherWalletId,
      firstSeenAt: DateTime.utc(2026, 9, 8),
      lastSeenAt: DateTime.utc(2026, 9, 8),
    ),
  ],
  activeWalletId: activeWalletId,
  observedAt: DateTime.utc(2026, 9, 8, 5, 12),
);

LoopAssetBalanceRow previewChainRow({
  String assetId = previewChainNativeAssetId,
  LoopBalanceAmount? balance,
  LoopValuation? valuation,
  LoopPendingAmount? pending,
  LoopBalanceCrossCheck? crossCheck,
  String? logoUrl,
}) => LoopAssetBalanceRow(
  assetId: assetId,
  logoUrl: logoUrl,
  symbol: assetId == previewChainNativeAssetId ? 'BNB' : 'WBNB',
  name: assetId == previewChainNativeAssetId ? 'BNB' : 'Wrapped BNB',
  decimals: 18,
  address: assetId == previewChainNativeAssetId ? null : previewChainAddress,
  balance:
      balance ??
      LoopBalanceAvailable(
        rawValue: '7000000000000000000',
        displayBalance: previewChainDecimal('7'),
        availableBalance: previewChainDecimal('7'),
        spendableBalance: previewChainDecimal('6.995'),
        gasReserve: previewChainDecimal('0.005'),
      ),
  pending:
      pending ??
      LoopPendingAvailable(rawValue: '0', value: previewChainDecimal('0')),
  valuation:
      valuation ??
      LoopValuationAvailable(
        priceSource: LoopFactSource.dexscreener,
        fetchedAt: DateTime.utc(2026, 9, 8, 7, 52),
        quality: LoopFactQuality.proxied,
        reasonCode: null,
        proxyAsset: previewChainWbnbAssetId,
        priceUsd: previewChainDecimal('747.39'),
        valueUsd: previewChainDecimal('5231.73'),
      ),
  crossCheck:
      crossCheck ??
      const LoopBalanceCrossCheck(
        status: LoopCrossCheckStatus.matched,
        reasonCode: null,
        blockDelta: null,
      ),
);

LoopWalletBalances previewChainBalances({
  String walletId = previewChainWalletId,
  List<LoopAssetBalanceRow>? rows,
  LoopNetWorth? netWorth,
  LoopLaunchChainBalance? launchChain,
}) => LoopWalletBalances(
  walletId: walletId,
  snapshot: LoopBalanceSnapshot(
    blockNumber: BigInt.from(120628164),
    blockHash: previewChainBlockHash,
    observedAt: DateTime.utc(2026, 9, 8, 5, 12),
    confirmations: 15,
  ),
  gasReservePolicy: LoopGasReservePolicy(
    configVersion: 'walletGasReserveV1',
    nativeReserveRaw: '5000000000000000',
    nativeReserve: previewChainDecimal('0.005'),
  ),
  balances: rows ?? <LoopAssetBalanceRow>[previewChainRow()],
  launchChain: launchChain,
  netWorth:
      netWorth ??
      LoopNetWorthValued(
        partial: false,
        valuationCurrency: 'USD',
        valueUsd: previewChainDecimal('5231.73'),
        unavailableCount: 0,
        quality: LoopFactQuality.fresh,
        priceSource: LoopFactSource.dexscreener,
        asOf: DateTime.utc(2026, 9, 8, 7, 52),
        isSpendable: false,
      ),
);

LoopWalletActivityPage previewChainActivity({
  String walletId = previewChainWalletId,
  List<LoopWalletActivityEntry>? items,
  String? nextCursor,
}) => LoopWalletActivityPage(
  walletId: walletId,
  items:
      items ??
      <LoopWalletActivityEntry>[
        LoopWalletActivityEntry(
          assetId: previewChainWbnbAssetId,
          symbol: 'WBNB',
          decimals: 18,
          direction: LoopTransferDirection.incoming,
          counterpartyAddress: previewChainAddress,
          rawValue: '1500000000000000000',
          displayValue: previewChainDecimal('1.5'),
          transactionHash: previewChainTxHash,
          logIndex: 3,
          blockNumber: BigInt.from(120628064),
          blockHash: previewChainBlockHash,
          confirmations: 101,
          status: LoopConfirmationStatus.confirmed,
          observedAt: DateTime.utc(2026, 9, 8),
        ),
      ],
  nextCursor: nextCursor,
  freshness: LoopIndexerFreshness(
    indexerBlockNumber: BigInt.from(120628771),
    headBlockNumber: BigInt.from(120628804),
    lagBlocks: 33,
    observedAt: DateTime.utc(2026, 9, 8, 5, 16),
  ),
  nativeTransfers: const LoopUnavailable('NATIVE_TRANSFER_SCAN_NOT_SUPPORTED'),
  crossChain: const LoopUnavailable('CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED'),
);
