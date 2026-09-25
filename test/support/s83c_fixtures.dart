import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

import 's7_fixtures.dart';

/// 测试专用 · S83c `available` projections, written by hand from
/// `loop-api/openapi/loop-api.v2.json` (decision 0076). No server has ever
/// emitted them; they exist only so the pages can be exercised against the
/// branch the contract will produce. Nothing here reaches `main_preview.dart`
/// or any production path.

const s83cContract = '0x1111111111111111111111111111111111111111';
const s83cUsd1 = '0x2222222222222222222222222222222222222222';
const s83cProjectToken = '0x3333333333333333333333333333333333333333';
const s83cWalletAddress = '0x4444444444444444444444444444444444444444';
const s83cIntentId = '7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
final s83cDigest = '0x${'cd' * 32}';
final s83cBlockHash = '0x${'12' * 32}';
final s83cConfigVersion = '0x${'ab' * 32}';
final s83cRoot = '0x${'ef' * 32}';
final s83cTxHash = '0x${'9a' * 32}';

/// 1 USD1 / 1 token in the 18-decimal smallest unit.
const s83cOne = '1000000000000000000';

LaunchOnChainAvailable s83cOnChain({
  LaunchSaleState sale = LaunchSaleState.live,
  LaunchEntitlementState entitlement = LaunchEntitlementState.none,
  LaunchLiquidityState liquidity = LaunchLiquidityState.notStarted,
  LaunchOperationalState operational = LaunchOperationalState.active,
}) => LaunchOnChainAvailable(
  saleState: sale,
  entitlementState: entitlement,
  liquidityState: liquidity,
  operationalState: operational,
  stateTupleDigest: s83cDigest,
  snapshotBlockNumber: '45000000',
  snapshotBlockHash: s83cBlockHash,
  configVersion: s83cConfigVersion,
);

LaunchSaleConfig s83cSaleConfig() => LaunchSaleConfig(
  projectToken: s83cProjectToken,
  usd1: s83cUsd1,
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
  configVersion: s83cConfigVersion,
);

LaunchChainRound s83cRound({
  int index = 1,
  String? roundId = s7RoundId,
  bool allowlist = true,
}) => LaunchChainRound(
  roundId: roundId,
  roundIndex: index,
  startAt: DateTime.utc(2026, 9, 21, 14, 13, 20),
  endAt: DateTime.utc(2026, 9, 23, 14, 13, 20),
  priceUsd1PerToken: '10000000000000000',
  roundCapUsd1: '40000000000000000000000',
  walletRoundCapUsd1: '500000000000000000000',
  allowlistRoot: allowlist ? s83cRoot : LaunchChainRound.zeroRoot,
  raisedUsd1: '1234000000000000000000',
);

LaunchDetail s83cDetail({
  LaunchOnChainAvailable? onChain,
  List<LaunchChainRound>? rounds,
  String chainId = loopPrimaryChainId,
}) {
  final base = s7Detail(chainId: chainId);
  final summary = base.launch;
  return LaunchDetail(
    launch: LaunchSummary(
      launchId: summary.launchId,
      projectId: summary.projectId,
      name: summary.name,
      ticker: summary.ticker,
      chainId: summary.chainId,
      contractAddress: s83cContract,
      configDigest: null,
      scheduleStatus: LaunchScheduleStatus.scheduled,
      onChainState: onChain ?? s83cOnChain(),
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
    saleConfig: s83cSaleConfig(),
    chainRounds:
        rounds ??
        <LaunchChainRound>[
          s83cRound(),
          s83cRound(
            index: 2,
            roundId: '1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f',
            allowlist: false,
          ),
        ],
  );
}

LaunchPurchaseIntent s83cIntent({
  String chainId = loopPrimaryChainId,
  DateTime? expiresAt,
  String to = s83cContract,
}) => LaunchPurchaseIntent(
  launchIntentId: s83cIntentId,
  state: LaunchIntentState.prepared,
  launchId: s7LaunchId,
  projectId: s7ProjectId,
  walletId: s7WalletId,
  roundId: s7RoundId,
  roundIndex: 1,
  chainId: chainId,
  contractAddress: s83cContract,
  quoteAssetId: 'eip155:97:$s83cUsd1',
  usd1Amount: '500000000000000000000',
  expectedTokenAmount: '50000000000000000000000',
  minTokenAmount: '49500000000000000000000',
  walletCumulativeUsd1: '0',
  deadline: DateTime.utc(2026, 9, 22, 15),
  eligibilityProof: <String>[s83cRoot],
  configVersion: s83cConfigVersion,
  stateTupleDigest: s83cDigest,
  snapshotBlockNumber: '45000000',
  snapshotBlockHash: s83cBlockHash,
  payloadDigest: 'ab' * 32,
  unsignedTransaction: LaunchUnsignedTransaction(
    chainId: loopChainReference(chainId),
    to: to,
    data: '0x${'00' * 36}',
    value: '0x0',
  ),
  expiresAt: expiresAt ?? DateTime.utc(2026, 9, 22, 14, 5),
  createdAt: DateTime.utc(2026, 9, 22, 14),
);

/// The clock every signing test runs at: inside the intent's validity.
DateTime s83cNow() => DateTime.utc(2026, 9, 22, 14, 1);

LoopWalletAccount s83cWallet() => LoopWalletAccount(
  walletId: s7WalletId,
  address: s83cWalletAddress,
  kind: LoopWalletKind.embedded,
  status: LoopWalletStatus.active,
  isActive: true,
  firstSeenAt: DateTime.utc(2026, 9),
  lastSeenAt: DateTime.utc(2026, 9, 22),
);

LaunchEligibility s83cEligibility({String? tier = 'priority'}) =>
    LaunchEligibility(
      launchId: s7LaunchId,
      mode: LaunchEligibilityMode.whitelist,
      result: LaunchEligibilityEvaluated(
        tierWireName: tier,
        reasonCode: null,
        snapshotBlock: '44999000',
        roundIndex: 1,
        allowlistRoot: s83cRoot,
        eligibilityProof: <String>[s83cRoot, s83cDigest],
      ),
      configVersion: 'launchMoonCatV1',
      effectiveAt: DateTime.utc(2026, 9, 8, 1),
      dependsOnStaking: false,
    );

LaunchHolders s83cHolders() => LaunchHolders(
  launchId: s7LaunchId,
  holders: const LaunchReadingAvailable<LaunchHolderCount>(
    LaunchHolderCount(holderCount: 1842, indexedBlockNumber: '45000100'),
  ),
  myPosition: LaunchReadingAvailable<LaunchPosition>(
    LaunchPosition(
      walletId: s7WalletId,
      cumulativeUsd1: '200000000000000000000',
      purchasedTokens: '20000000000000000000000',
      entitledTokens: '0',
      claimableTokens: '0',
      claimedTokens: '0',
      refundableUsd1: '0',
      refundedUsd1: '0',
      snapshotBlockNumber: '45000000',
      snapshotBlockHash: s83cBlockHash,
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
      snapshotBlockHash: s83cBlockHash,
    ),
  ),
);

LaunchHistory s83cHistory({bool empty = false}) => LaunchHistory(
  launchId: s7LaunchId,
  source: LaunchReadingAvailable<LaunchIndexedSource>(
    LaunchIndexedSource(
      indexedBlockNumber: '45000100',
      indexedBlockHash: s83cBlockHash,
    ),
  ),
  purchaseRecords: empty
      ? const <LaunchPurchaseRecord>[]
      : <LaunchPurchaseRecord>[
          LaunchPurchaseRecord(
            purchaseRecordId: '5e6f7a8b-9c0d-4e1f-8a2b-3c4d5e6f7a8b',
            walletId: s7WalletId,
            roundId: s7RoundId,
            roundIndex: 1,
            usd1Amount: '200000000000000000000',
            tokenAmount: '20000000000000000000000',
            transactionHash: s83cTxHash,
            logIndex: 3,
            blockNumber: '45000050',
            blockHash: s83cBlockHash,
            confirmationState: LaunchConfirmationState.confirmed,
            observedAt: DateTime.utc(2026, 9, 22, 14, 2),
          ),
        ],
);

/// A refusal the adapter maps from `detailsSafe.reasonCode`.
const LaunchException s83cRefusal = LaunchException(
  LaunchFailureKind.unavailable,
  reasonCode: 'LAUNCH_SALE_NOT_REGISTERED',
);
