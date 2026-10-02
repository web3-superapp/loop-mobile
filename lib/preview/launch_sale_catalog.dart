// Deterministic memory-only display specimens. No provider observations.
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/preview/launch_mining_catalog.dart';

const previewSaleContract = '0x1111111111111111111111111111111111111111';
const previewSaleUsd1 = '0x2222222222222222222222222222222222222222';
const previewSaleProjectToken = '0x3333333333333333333333333333333333333333';
final previewSaleDigest = '0x${'cd' * 32}';
final previewSaleBlockHash = '0x${'12' * 32}';
final previewSaleConfigVersion = '0x${'ab' * 32}';
final previewSaleRoot = '0x${'ef' * 32}';
LaunchOnChainAvailable previewSaleOnChain({
  LaunchSaleState sale = LaunchSaleState.live,
  LaunchEntitlementState entitlement = LaunchEntitlementState.none,
  LaunchLiquidityState liquidity = LaunchLiquidityState.notStarted,
  LaunchOperationalState operational = LaunchOperationalState.active,
}) => LaunchOnChainAvailable(
  saleState: sale,
  entitlementState: entitlement,
  liquidityState: liquidity,
  operationalState: operational,
  stateTupleDigest: previewSaleDigest,
  snapshotBlockNumber: '45000000',
  snapshotBlockHash: previewSaleBlockHash,
  configVersion: previewSaleConfigVersion,
);

LaunchSaleConfig previewSaleSaleConfig() => LaunchSaleConfig(
  projectToken: previewSaleProjectToken,
  usd1: previewSaleUsd1,
  softCapUsd1: '20000000000000000000000',
  hardCapUsd1: '100000000000000000000000',
  walletProjectCapUsd1: '1000000000000000000000',
  minPurchaseUsd1: '10000000000000000000',
  protocolFeeBps: 300,
  liquidityBps: 5000,
  tgeBps: 2500,
  cliffSeconds: 0,
  vestingSeconds: 7776000,
  poolFeeTier: 2500,
  lpLockSeconds: 31536000,
  configVersion: previewSaleConfigVersion,
);

LaunchChainRound previewSaleRound({
  int index = 1,
  String? roundId = previewLaunchRoundId,
  bool allowlist = true,
}) => LaunchChainRound(
  roundId: roundId,
  roundIndex: index,
  startAt: DateTime.utc(2026, 9, 21, 14, 13, 20),
  endAt: DateTime.utc(2026, 9, 23, 14, 13, 20),
  priceUsd1PerToken: '10000000000000000',
  roundCapUsd1: '40000000000000000000000',
  walletRoundCapUsd1: '500000000000000000000',
  allowlistRoot: allowlist ? previewSaleRoot : LaunchChainRound.zeroRoot,
  raisedUsd1: '1234000000000000000000',
);

LaunchDetail previewSaleDetail({
  LaunchOnChainAvailable? onChain,
  List<LaunchChainRound>? rounds,
  String chainId = loopPrimaryChainId,
}) {
  final base = previewLaunchDetail(chainId: chainId);
  final summary = base.launch;
  return LaunchDetail(
    launch: LaunchSummary(
      launchId: summary.launchId,
      projectId: summary.projectId,
      name: summary.name,
      ticker: summary.ticker,
      chainId: summary.chainId,
      contractAddress: previewSaleContract,
      configDigest: null,
      scheduleStatus: LaunchScheduleStatus.scheduled,
      onChainState: onChain ?? previewSaleOnChain(),
      configVersion: null,
      createdAt: summary.createdAt,
    ),
    project: base.project,
    config: null,
    configPending: null,
    rounds: const <LaunchRound>[],
    graduation: base.graduation,
    market: base.market,
    holders: base.holders,
    saleConfig: previewSaleSaleConfig(),
    chainRounds:
        rounds ??
        <LaunchChainRound>[
          previewSaleRound(),
          previewSaleRound(
            index: 2,
            roundId: '1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f',
            allowlist: false,
          ),
        ],
  );
}

final previewSaleTxHash = '0x${'9a' * 32}';
LaunchHolders previewSaleHolders() => LaunchHolders(
  launchId: previewLaunchLaunchId,
  holders: const LaunchReadingAvailable<LaunchHolderCount>(
    LaunchHolderCount(holderCount: 1842, indexedBlockNumber: '45000100'),
  ),
  myPosition: LaunchReadingAvailable<LaunchPosition>(
    LaunchPosition(
      walletId: '0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
      cumulativeUsd1: '200000000000000000000',
      purchasedTokens: '20000000000000000000000',
      entitledTokens: '0',
      claimableTokens: '0',
      claimedTokens: '0',
      refundableUsd1: '0',
      refundedUsd1: '0',
      snapshotBlockNumber: '45000000',
      snapshotBlockHash: previewSaleBlockHash,
    ),
  ),
  walletCap: LaunchReadingAvailable<LaunchWalletCap>(
    LaunchWalletCap(
      walletProjectCapUsd1: '1000000000000000000000',
      rounds: const <LaunchWalletRoundCap>[
        LaunchWalletRoundCap(
          roundIndex: 1,
          walletRoundCapUsd1: '500000000000000000000',
          cumulativeUsd1: '200000000000000000000',
        ),
      ],
      snapshotBlockNumber: '45000000',
      snapshotBlockHash: previewSaleBlockHash,
    ),
  ),
);

LaunchHistory previewSaleHistory({bool empty = false}) => LaunchHistory(
  launchId: previewLaunchLaunchId,
  source: LaunchReadingAvailable<LaunchIndexedSource>(
    LaunchIndexedSource(
      indexedBlockNumber: '45000100',
      indexedBlockHash: previewSaleBlockHash,
    ),
  ),
  purchaseRecords: empty
      ? const <LaunchPurchaseRecord>[]
      : <LaunchPurchaseRecord>[
          LaunchPurchaseRecord(
            purchaseRecordId: '5e6f7a8b-9c0d-4e1f-8a2b-3c4d5e6f7a8b',
            walletId: '0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
            roundId: previewLaunchRoundId,
            roundIndex: 1,
            usd1Amount: '200000000000000000000',
            tokenAmount: '20000000000000000000000',
            transactionHash: previewSaleTxHash,
            logIndex: 3,
            blockNumber: '45000050',
            blockHash: previewSaleBlockHash,
            confirmationState: LaunchConfirmationState.confirmed,
            observedAt: DateTime.utc(2026, 9, 22, 14, 2),
          ),
        ],
);
