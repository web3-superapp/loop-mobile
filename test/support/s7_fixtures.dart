import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';

/// Deterministic S7 projections for the widget tests.
///
/// They mirror exactly what the step-7 server answers: every on-chain and
/// formula-derived field is `unavailable` with its own reason code, and no
/// fixture ever invents a rate, a cap, a supply or a tax.

const s7LaunchId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const s7ProjectId = '17f6a9b2-2f22-4c11-9f3a-1a2b3c4d5e6f';
const s7RoundId = '9c1d6e2a-7c3b-4a55-8d21-0f1e2d3c4b5a';
const s7CommunityId = '5b0c9d18-6a44-4f39-b0d2-9e8f7a6b5c4d';
const s7MilestoneId = '2e4f6a80-1b2c-4d3e-9f01-a2b3c4d5e6f7';
const s7WalletId = '4d5e6f70-8a9b-4c1d-8e2f-3a4b5c6d7e8f';

const s7LaunchBaselinePending = 'LAUNCH_CONTRACT_BASELINE_PENDING';
const s7ConfigPending = 'LAUNCH_CONFIG_PENDING_CONFIRMATION';
const s7TierPending = 'TIER_MODE_PENDING';
const s7StakingPending = 'STAKING_CONTRACT_PENDING';
const s7FormulaPending = 'MINING_FORMULA_BASELINE_PENDING';
const s7RewardPending = 'REWARD_AUTHORITY_PENDING';

/// The boost's own code. The server answers it whether or not a formula
/// version is in effect, so a fixture that reused the baseline code made the
/// page state a blanket outage beside settled figures.
const s7ReferralBoostPending = 'MINING_REFERRAL_BOOST_PENDING';

LaunchOnChainState s7OnChainState() => const LaunchOnChainState(
  saleState: 'unavailable',
  entitlementState: 'unavailable',
  liquidityState: 'unavailable',
  operationalState: 'unavailable',
  stateTupleDigest: null,
  snapshotBlockNumber: null,
  snapshotBlockHash: null,
  source: 'unavailable',
  reasonCode: s7LaunchBaselinePending,
);

LaunchSummary s7LaunchSummary({
  String launchId = s7LaunchId,
  String name = 'MoonCat',
  String ticker = 'MCAT',
  LaunchScheduleStatus scheduleStatus = LaunchScheduleStatus.unscheduled,
  String? configVersion,
  String chainId = loopPrimaryChainId,
}) => LaunchSummary(
  launchId: launchId,
  projectId: s7ProjectId,
  name: name,
  ticker: ticker,
  chainId: chainId,
  contractAddress: null,
  configDigest: null,
  scheduleStatus: scheduleStatus,
  onChainState: s7OnChainState(),
  configVersion: configVersion,
  createdAt: DateTime.utc(2026, 9, 8, 1),
);

LaunchOverview s7Overview({
  List<LaunchSummary>? live,
  List<LaunchSummary>? upcoming,
  List<LaunchSummary>? awaitingSchedule,
  List<LaunchSummary>? ended,
}) => LaunchOverview(
  segments: LaunchSegments(
    live: live ?? const <LaunchSummary>[],
    upcoming: upcoming ?? const <LaunchSummary>[],
    awaitingSchedule: awaitingSchedule ?? <LaunchSummary>[s7LaunchSummary()],
    ended: ended ?? const <LaunchSummary>[],
  ),
  graduated: const LaunchUnavailable(s7LaunchBaselinePending),
  myEligibility: const LaunchUnavailable(s7TierPending),
  staking: const LaunchUnavailable(s7StakingPending),
  catalog: LaunchCatalogStamp(
    configVersion: 'launchCatalogV1',
    source: 'loop_db',
    observedAt: DateTime.utc(2026, 9, 9, 6, 30),
  ),
);

LaunchConfigSlots s7PendingSlots() => const LaunchConfigSlots(
  walletRoundCap: LaunchConfigSlotPending(s7ConfigPending),
  walletProjectCap: LaunchConfigSlotPending(s7ConfigPending),
  feeBps: LaunchConfigSlotPending(s7ConfigPending),
  softCap: LaunchConfigSlotPending(s7ConfigPending),
  hardCap: LaunchConfigSlotPending(s7ConfigPending),
  tge: LaunchConfigSlotPending(s7ConfigPending),
  vesting: LaunchConfigSlotPending(s7ConfigPending),
  tierModeV1: LaunchConfigSlotPending(s7ConfigPending),
);

LaunchRound s7Round({
  int index = 1,
  String configVersion = 'launchMoonCatV1',
  String roundId = s7RoundId,
}) => LaunchRound(
  roundId: roundId,
  roundIndex: index,
  configVersion: configVersion,
  status: LaunchConfigStatus.pendingConfirmation,
  startsAt: null,
  endsAt: null,
  priceUsd1: null,
  eligibilityTier: null,
  walletRoundCapRaw: null,
);

LaunchDetail s7Detail({
  LaunchConfig? config,
  List<LaunchRound>? rounds,
  LaunchUnavailable? configPending,
  String chainId = loopPrimaryChainId,
}) => LaunchDetail(
  launch: s7LaunchSummary(chainId: chainId),
  project: const LaunchProjectBrief(
    projectId: s7ProjectId,
    name: 'MoonCat',
    ticker: 'MCAT',
    narrative: '有故事、有传播、可持续运营的 MEME。',
    officialLinks: LaunchOfficialLinks(website: 'https://mooncat.example'),
    materialVersion: 2,
  ),
  config:
      config ??
      LaunchConfig(
        configVersion: 'launchMoonCatV1',
        status: LaunchConfigStatus.pendingConfirmation,
        effectiveAt: null,
        slots: s7PendingSlots(),
      ),
  configPending: configPending ?? const LaunchUnavailable(s7ConfigPending),
  rounds: rounds ?? <LaunchRound>[s7Round(), s7Round(index: 2)],
  graduation: const LaunchGraduation(
    steps: <LaunchGraduationStep>[
      LaunchGraduationStep(
        step: LaunchGraduationStepKind.stopInternalTrading,
        status: 'pending',
      ),
      LaunchGraduationStep(
        step: LaunchGraduationStepKind.preparePool,
        status: 'pending',
      ),
      LaunchGraduationStep(
        step: LaunchGraduationStepKind.addAndLockLiquidity,
        status: 'pending',
      ),
      LaunchGraduationStep(
        step: LaunchGraduationStepKind.openExternalTrading,
        status: 'pending',
      ),
    ],
    poolEvidence: LaunchUnavailable('LAUNCH_POOL_EVIDENCE_UNAVAILABLE'),
  ),
  market: const LaunchUnavailable(s7LaunchBaselinePending),
  holders: const LaunchUnavailable(s7LaunchBaselinePending),
);

LaunchEligibility s7Eligibility({
  LaunchEligibilityMode mode = LaunchEligibilityMode.unavailable,
  String reasonCode = s7TierPending,
  String? configVersion,
}) => LaunchEligibility(
  launchId: s7LaunchId,
  mode: mode,
  tier: null,
  reasonCode: reasonCode,
  snapshotBlock: null,
  configVersion: configVersion,
  effectiveAt: null,
  dependsOnStaking: false,
);

LaunchStake s7Stake() => const LaunchStake(
  stake: LaunchUnavailable(s7StakingPending),
  executable: false,
);

LaunchHolders s7Holders() => const LaunchHolders(
  launchId: s7LaunchId,
  holders: LaunchUnavailable(s7LaunchBaselinePending),
  myPosition: LaunchUnavailable(s7LaunchBaselinePending),
  walletCap: LaunchUnavailable(s7LaunchBaselinePending),
);

LaunchHistory s7History() => const LaunchHistory(
  launchId: s7LaunchId,
  source: LaunchUnavailable(s7LaunchBaselinePending),
);

LaunchEconomy s7Economy() => LaunchEconomy(
  projects: const LaunchProjectCounts(
    draft: 1,
    submitted: 0,
    inReview: 0,
    returned: 0,
    approved: 1,
    rejected: 0,
  ),
  launches: const LaunchScheduleCounts(
    unscheduled: 1,
    scheduled: 0,
    live: 0,
    ended: 0,
  ),
  confirmedRoundCount: 0,
  totalSupply: const LaunchUnavailable('LAUNCH_ECONOMY_CONTRACT_PENDING'),
  distributed: const LaunchUnavailable('LAUNCH_ECONOMY_CONTRACT_PENDING'),
  ecosystemTax: const LaunchUnavailable('LAUNCH_ECONOMY_CONTRACT_PENDING'),
  source: 'loop_db',
  observedAt: DateTime.utc(2026, 9, 9, 6, 30),
);

LaunchProject s7Project({
  String projectId = s7ProjectId,
  LaunchReviewStatus reviewStatus = LaunchReviewStatus.draft,
  int version = 1,
  int? nullableVersion,
  String? reviewReasonCode,
  String? reviewReasonText,
  String? launchId,
  DateTime? submittedAt,
}) => LaunchProject(
  projectId: projectId,
  name: 'MoonCat',
  ticker: 'MCAT',
  narrative: '有故事、有传播、可持续运营的 MEME。',
  officialLinks: const LaunchOfficialLinks(website: 'https://mooncat.example'),
  materialVersion: version,
  reviewStatus: reviewStatus,
  reviewReasonCode: reviewReasonCode,
  // The contract pairs the two: a code always arrives with the server's own
  // sentence, and neither exists without the other.
  reviewReasonText: reviewReasonCode == null
      ? null
      : reviewReasonText ?? '材料还不完整，补齐后可以重新提交审核。',
  kyb: const LaunchKyb(
    status: 'unavailable',
    state: 'unavailable',
    reasonCode: 'KYB_PROVIDER_NOT_SELECTED',
  ),
  attachments: const LaunchUnavailable('ATTACHMENT_STORAGE_NOT_SELECTED'),
  submittedAt: submittedAt,
  reviewedAt: null,
  launchId: launchId,
  version: nullableVersion ?? version,
  createdAt: DateTime.utc(2026, 9, 8, 1),
  updatedAt: DateTime.utc(2026, 9, 8, 2),
  configVersion: 'launchCatalogV1',
);

/// A non-owner projection: the review trail and the CAS version are `null`.
LaunchProject s7ForeignProject() => LaunchProject(
  projectId: s7ProjectId,
  name: 'MoonCat',
  ticker: 'MCAT',
  narrative: null,
  officialLinks: const LaunchOfficialLinks(),
  materialVersion: 3,
  reviewStatus: LaunchReviewStatus.approved,
  reviewReasonCode: null,
  reviewReasonText: null,
  kyb: const LaunchKyb(
    status: 'unavailable',
    state: 'unavailable',
    reasonCode: 'KYB_PROVIDER_NOT_SELECTED',
  ),
  attachments: const LaunchUnavailable('ATTACHMENT_STORAGE_NOT_SELECTED'),
  submittedAt: null,
  reviewedAt: null,
  launchId: s7LaunchId,
  version: null,
  createdAt: DateTime.utc(2026, 9, 8, 1),
  updatedAt: DateTime.utc(2026, 9, 8, 2),
  configVersion: 'launchCatalogV1',
);

/// The five tracks 03 §8.4 fixes. `lbank/spot` carries reviewed evidence; the
/// other four arrive as implicit `PREPARING` rows with no stored record.
LaunchMilestones s7Milestones({List<LaunchMilestone>? items}) =>
    LaunchMilestones(
      projectId: s7ProjectId,
      items:
          items ??
          <LaunchMilestone>[
            s7ListedMilestone(),
            for (final track in launchMilestoneTracks.skip(1))
              s7ImplicitMilestone(venue: track.$1, marketType: track.$2),
          ],
    );

LaunchMilestone s7ListedMilestone({
  LaunchMilestoneState state = LaunchMilestoneState.listed,
  LaunchVenue venue = LaunchVenue.lbank,
  LaunchMarketType marketType = LaunchMarketType.spot,
  DateTime? observedAt,
}) => LaunchMilestone(
  venueMilestoneId: s7MilestoneId,
  venue: venue,
  marketType: marketType,
  state: state,
  evidence: LaunchMilestoneEvidence(
    digest: 'a' * 64,
    recordedAt: DateTime.utc(2026, 9, 5, 3),
    observedAt: observedAt ?? DateTime.utc(2026, 9),
    reviewer: 'ops.alice',
  ),
  version: 2,
  updatedAt: DateTime.utc(2026, 9, 5, 3),
);

/// A track the operator has never recorded against: no id, version 0, no
/// update time and no evidence.
LaunchMilestone s7ImplicitMilestone({
  required LaunchVenue venue,
  required LaunchMarketType marketType,
}) => LaunchMilestone(
  venueMilestoneId: null,
  venue: venue,
  marketType: marketType,
  state: LaunchMilestoneState.preparing,
  evidence: const LaunchMilestoneEvidence(
    digest: null,
    recordedAt: null,
    observedAt: null,
    reviewer: null,
  ),
  version: 0,
  updatedAt: null,
);

// ---------------------------------------------------------------------------
// mining
// ---------------------------------------------------------------------------

const s7BaselineVersion = 'miningFormula-devBaseline-2026-09-15-r2';

/// The version in force on the Development lane, in the block the summary,
/// the composition page and the ranking all publish.
MiningFormulaEffective s7EffectiveFormula() => MiningFormulaEffective(
  configVersion: s7BaselineVersion,
  effectiveAt: DateTime.utc(2026, 9, 15, 14, 57, 37),
  scope: MiningFormulaScope.developmentBaseline,
);

/// No version in force: the same block, naming the draft that is waiting.
MiningFormulaPending s7PendingFormula() => const MiningFormulaPending(
  reasonCode: s7FormulaPending,
  pendingVersion: 'miningFormulaV1-draft',
);

MiningSummary s7MiningSummary({
  String? pendingVersion,
  MiningFigure? power,
  MiningFigure? networkPower,
  MiningDailyOutput? estimatedToday,
  LaunchUnavailable? accumulated,
  MiningFormulaGate? formula,
  MiningSnapshotRef? snapshot,
}) => MiningSummary(
  power: power ?? const MiningFigureUnavailable(s7FormulaPending),
  networkPower: networkPower ?? const MiningFigureUnavailable(s7FormulaPending),
  estimatedToday:
      estimatedToday ?? const MiningDailyOutputUnavailable(s7FormulaPending),
  accumulated: accumulated ?? const LaunchUnavailable(s7FormulaPending),
  claimable: const LaunchUnavailable(s7RewardPending),
  referralBoost: const LaunchUnavailable(s7ReferralBoostPending),
  formula:
      formula ??
      MiningFormulaPending(
        reasonCode: s7FormulaPending,
        pendingVersion: pendingVersion ?? 'miningFormulaV1-draft',
      ),
  snapshot:
      snapshot ??
      const MiningSnapshotUnavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
);

/// The Development baseline as it actually answers: a version in effect, and
/// every number under it still zero.
MiningSummary s7MiningBaselineSummary() => s7MiningSummary(
  power: const MiningFigureValue('1000'),
  networkPower: const MiningFigureValue('4000'),
  estimatedToday: const MiningDailyOutputEstimate(
    value: '250000',
    budget: '1000000',
    unitKey: 'mining.rules.dailyOutput.unit.loopTokenPending',
    budgetStatus: 'development_placeholder',
    formulaVersion: s7BaselineVersion,
    scope: MiningFormulaScope.developmentBaseline,
  ),
  // Under an effective version the page never carries the baseline code: the
  // ledger is missing for its own reason, and the server guarantees the two
  // never appear together.
  accumulated: const LaunchUnavailable(s7RewardPending),
  formula: s7EffectiveFormula(),
);

/// The four asset ids the Development baseline weighs, and the price version
/// it weighed them under.
const s7CakeAssetId = 'eip155:56:0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82';
const s7UsdtAssetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';
const s7WbnbAssetId = 'eip155:56:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c';
const s7NativeAssetId = 'eip155:56:native';
const s7PriceVersion = 'dexscreener:2026-09-15T14:58:51.862Z';

MiningSnapshotComputed s7MiningSnapshot() => MiningSnapshotComputed(
  snapshotId: '0e358b31-e49f-48b9-89b2-c5c908c3ad5e',
  blockNumber: '122037728',
  blockHash:
      '0x3decab82b150493d90cb8fe47b3873c6e3b8c72aecf08ce91b4aceb266bda28a',
  formulaVersion: s7BaselineVersion,
  priceVersion: s7PriceVersion,
  computedAt: DateTime.utc(2026, 9, 15, 14, 58, 54, 366),
);

MiningAssets s7MiningAssets({
  MiningFigure? totalPower,
  List<MiningAssetRow>? included,
  List<MiningExcludedAsset>? excluded,
  MiningSnapshotRef? source,
  MiningReferencePrice? referencePrice,
  MiningFormulaGate? formula,
}) => MiningAssets(
  totalPower: totalPower ?? const MiningFigureUnavailable(s7FormulaPending),
  included: included ?? const <MiningAssetRow>[],
  excluded: excluded ?? const <MiningExcludedAsset>[],
  source:
      source ??
      const MiningSnapshotUnavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
  referencePrice:
      referencePrice ?? const MiningReferencePriceUnavailable(s7FormulaPending),
  formula: formula ?? s7PendingFormula(),
);

/// One weighted row, defaulting to the Development shape: a real holding, a
/// fresh price, the registry's own symbol and the effective weight the row
/// was settled with.
MiningAssetRow s7MiningAssetRow({
  String assetId = s7CakeAssetId,
  String? symbol = 'Cake',
  String holding = '0',
  String referencePriceUsd = '2.26',
  String weight = '0.8',
  String power = '0',
  String? proxyAssetId,
}) => MiningAssetRow(
  assetId: assetId,
  symbol: symbol,
  holding: holding,
  referencePriceUsd: referencePriceUsd,
  referencePriceQuality: proxyAssetId == null
      ? MiningReferencePriceQuality.fresh
      : MiningReferencePriceQuality.proxied,
  referencePriceProxyAssetId: proxyAssetId,
  weight: weight,
  power: power,
  blockNumber: '122037728',
);

/// The Development settlement of 2026-09-15: four weighted rows, every figure
/// a real zero reading, and the chain's own coin priced through its declared
/// proxy.
MiningAssets s7MiningSettledAssets({
  List<MiningAssetRow>? included,
  List<MiningExcludedAsset>? excluded,
  MiningFormulaGate? formula,
}) => s7MiningAssets(
  formula: formula ?? s7EffectiveFormula(),
  totalPower: const MiningFigureValue('0'),
  included:
      included ??
      <MiningAssetRow>[
        s7MiningAssetRow(),
        s7MiningAssetRow(
          assetId: s7UsdtAssetId,
          symbol: 'USDT',
          referencePriceUsd: '0.9994',
          weight: '1.5',
        ),
        s7MiningAssetRow(
          assetId: s7WbnbAssetId,
          symbol: 'WBNB',
          referencePriceUsd: '713.42',
          weight: '1',
        ),
        s7MiningAssetRow(
          assetId: s7NativeAssetId,
          symbol: 'BNB',
          referencePriceUsd: '713.42',
          weight: '1',
          proxyAssetId: s7WbnbAssetId,
        ),
      ],
  excluded: excluded ?? const <MiningExcludedAsset>[],
  source: s7MiningSnapshot(),
  referencePrice: const MiningReferencePriceSettled(s7PriceVersion),
);

MiningRewards s7MiningRewards() => const MiningRewards(
  claimable: LaunchUnavailable(s7RewardPending),
  claimExecutable: false,
  estimatedToday: LaunchUnavailable(s7FormulaPending),
  accumulated: LaunchUnavailable(s7FormulaPending),
  source: LaunchUnavailable(s7FormulaPending),
);

MiningRank s7MiningRank({
  MiningRankScope scope = MiningRankScope.communities,
  MiningRanking? ranking,
  MiningRankPosition? myPosition,
  MiningSnapshotRef? snapshot,
  MiningFormulaGate? formula,
}) => MiningRank(
  scope: scope,
  ranking: ranking ?? const MiningRankingUnavailable(s7FormulaPending),
  myPosition:
      myPosition ?? const MiningRankPositionUnavailable(s7FormulaPending),
  snapshot:
      snapshot ??
      const MiningSnapshotUnavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
  display: const MiningRankDisplayRule(
    anonymousMemberKey: 'mining.rank.anonymousMember',
    ruleKey: 'mining.rank.display.aliasOrAnonymous',
  ),
  formula: formula ?? s7PendingFormula(),
);

const s7PublicProfileId = '8c2b7a15-4d3e-4f60-9a11-2b3c4d5e6f70';
const s7OtherCommunityId = '439cabe6-4c98-4f99-860f-192ad52403a1';

/// The Development user board of 2026-09-15: two accounts in the settlement,
/// both with a zero power, so neither has a position at all.
MiningRankingUsers s7MiningUserBoard({
  List<MiningRankUserRow>? items,
  int participants = 0,
}) => MiningRankingUsers(
  items:
      items ??
      const <MiningRankUserRow>[
        MiningRankUserRow(
          position: null,
          power: '0',
          display: MiningRankAlias(
            alias: 'whale',
            publicProfileId: s7PublicProfileId,
          ),
          isSelf: false,
        ),
        MiningRankUserRow(
          position: null,
          power: '0',
          display: MiningRankAnonymous('mining.rank.anonymousMember'),
          isSelf: true,
        ),
      ],
  participants: participants,
);

/// The Development community board: two bound communities, each with the
/// weight its review granted and no power yet.
MiningRankingCommunities s7MiningCommunityBoard({
  List<MiningRankCommunityRow>? items,
  int participants = 0,
}) => MiningRankingCommunities(
  items:
      items ??
      const <MiningRankCommunityRow>[
        MiningRankCommunityRow(
          position: null,
          power: '0',
          community: MiningCommunityRef(
            communityId: s7OtherCommunityId,
            name: 'Builders Guild',
            boundAssetId: s7UsdtAssetId,
          ),
          weight: '1.5',
          participants: 0,
        ),
        MiningRankCommunityRow(
          position: null,
          power: '0',
          community: MiningCommunityRef(
            communityId: s7CommunityId,
            name: 'DeFi 早读会',
            boundAssetId: s7CakeAssetId,
          ),
          weight: '0.8',
          participants: 0,
        ),
      ],
  participants: participants,
);

MiningCommunity s7MiningCommunity({
  MiningCommunityWeight? weight,
  MiningCommunityRef? community,
  MiningFigure? communityPower,
  MiningFigure? myContribution,
  MiningRankPosition? rank,
  MiningParticipants? participants,
  MiningSnapshotRef? snapshot,
}) => MiningCommunity(
  community:
      community ??
      const MiningCommunityRef(
        communityId: s7CommunityId,
        name: 'Frog Holders',
        // Bound, and waiting for a review: the two go together, because a
        // community with nothing bound has no weight to review (0046).
        boundAssetId: s7CakeAssetId,
      ),
  weight:
      weight ??
      const MiningCommunityWeightPending(
        reasonCode: 'COMMUNITY_WEIGHT_PENDING_REVIEW',
        reviewStatus: MiningWeightReviewStatus.pendingReview,
      ),
  communityPower:
      communityPower ?? const MiningFigureUnavailable(s7FormulaPending),
  myContribution:
      myContribution ?? const MiningFigureUnavailable(s7FormulaPending),
  rank: rank ?? const MiningRankPositionUnavailable(s7FormulaPending),
  participants:
      participants ?? const MiningParticipantsUnavailable(s7FormulaPending),
  snapshot:
      snapshot ??
      const MiningSnapshotUnavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
);

/// A community that never bound an asset. Its weight is not under review: no
/// weight exists to review, and the panel says that instead (0046).
MiningCommunity s7MiningUnboundCommunity() => s7MiningCommunity(
  community: const MiningCommunityRef(
    communityId: s7CommunityId,
    name: 'Frog Holders',
    boundAssetId: null,
  ),
  weight: const MiningCommunityWeightPending(
    reasonCode: 'COMMUNITY_ASSET_NOT_BOUND',
    reviewStatus: MiningWeightReviewStatus.notApplicable,
  ),
  communityPower: const MiningFigureUnavailable('COMMUNITY_ASSET_NOT_BOUND'),
  myContribution: const MiningFigureUnavailable('COMMUNITY_ASSET_NOT_BOUND'),
  rank: const MiningRankPositionUnavailable('COMMUNITY_ASSET_NOT_BOUND'),
  participants: const MiningParticipantsUnavailable(
    'COMMUNITY_ASSET_NOT_BOUND',
  ),
);

/// The Development panel of 2026-09-15 for `mock-defi-morning`: a reviewed
/// weight, a settlement, and every figure a real zero reading.
MiningCommunity s7MiningSettledCommunity({
  MiningRankPosition? rank,
  MiningParticipants? participants,
}) => s7MiningCommunity(
  community: const MiningCommunityRef(
    communityId: s7CommunityId,
    name: 'DeFi 早读会',
    boundAssetId: s7CakeAssetId,
  ),
  weight: MiningCommunityWeightApproved(
    value: '0.8',
    configVersion: s7BaselineVersion,
    reviewedAt: DateTime.utc(2026, 9, 15, 14, 58, 52, 89),
  ),
  communityPower: const MiningFigureValue('0'),
  myContribution: const MiningFigureValue('0'),
  rank: rank ?? const MiningRankPositionUnavailable('MINING_RANK_NOT_RANKED'),
  participants: participants ?? const MiningParticipantsCount(0),
  snapshot: s7MiningSnapshot(),
);

MiningFormulaVersion s7DraftFormula({
  String configVersion = 'miningFormulaV1-draft',
}) => MiningFormulaVersion(
  configVersion: configVersion,
  status: MiningFormulaStatus.pendingApproval,
  effectiveAt: null,
  approvedAt: null,
  expressionKey: 'mining.rules.formula.holdingTimesReferencePriceTimesWeight',
  dailyOutputKey: 'mining.rules.dailyOutput.shareOfNetworkPower',
  weightRange: const MiningWeightRange(
    loop: MiningWeightBand(
      status: MiningFormulaStatus.pendingApproval,
      descriptionKey: 'mining.rules.weight.loopFixedMaximum',
    ),
    community: MiningWeightBand(
      status: MiningFormulaStatus.pendingApproval,
      descriptionKey: 'mining.rules.weight.communityReviewed',
    ),
    reviewFactorKeys: <String>[
      'mining.rules.reviewFactor.communityQuality',
      'mining.rules.reviewFactor.tokenLiquidity',
    ],
  ),
  priceGuardRules: const <MiningPriceGuardRule>[
    MiningPriceGuardRule(
      ruleKey: 'mining.rules.priceGuard.twap',
      status: MiningFormulaStatus.pendingApproval,
    ),
    MiningPriceGuardRule(
      ruleKey: 'mining.rules.priceGuard.multiPeriodMultiSource',
      status: MiningFormulaStatus.pendingApproval,
    ),
    MiningPriceGuardRule(
      ruleKey: 'mining.rules.priceGuard.liquidityCap',
      status: MiningFormulaStatus.pendingApproval,
    ),
  ],
  referralBoostStatus: MiningFormulaStatus.pendingApproval,
);

MiningRules s7MiningRules({
  MiningFormulaVersion? approved,
  List<MiningFormulaVersion>? pendingApproval,
}) => MiningRules(
  approved: approved,
  pendingApproval: pendingApproval ?? <MiningFormulaVersion>[s7DraftFormula()],
  baseline: const LaunchUnavailable(s7FormulaPending),
  referral: MiningReferralRules(
    configVersion: 'referralRulesV1',
    effectiveAt: DateTime.utc(2026, 9),
    levels: <MiningReferralLevelRule>[
      for (var level = 1; level <= 5; level += 1)
        MiningReferralLevelRule(
          level: level,
          boostPercent: <String>['10', '5', '3', '2', '1'][level - 1],
          descriptionKey: 'mining.referral.level$level',
        ),
    ],
  ),
);

// ---------------------------------------------------------------------------
// referral
// ---------------------------------------------------------------------------

ReferralValidationCounts s7Counts({
  int pendingActivation = 0,
  int pendingWallet = 2,
  int pendingMining = 1,
  int valid = 0,
  int invalidated = 0,
}) => ReferralValidationCounts(
  pendingActivation: pendingActivation,
  pendingWallet: pendingWallet,
  pendingMining: pendingMining,
  valid: valid,
  invalidated: invalidated,
);

ReferralOverview s7Referral({
  ReferralBinding? binding,
  List<ReferralLevel>? levels,
}) => ReferralOverview(
  inviteCode: ReferralInviteCode(
    code: 'LOOP-7HJKM',
    issuedAt: DateTime.utc(2026, 9, 8),
  ),
  binding:
      binding ??
      ReferralBinding(
        isBound: false,
        inviter: null,
        claimWindow: ReferralClaimWindowTimed(
          isOpen: true,
          activatedAt: DateTime.utc(2026, 9, 6),
          closesAt: DateTime.utc(2026, 9, 13),
        ),
      ),
  levels:
      levels ??
      <ReferralLevel>[
        for (var level = 1; level <= 5; level += 1)
          ReferralLevel(
            level: level,
            boostPercent: <String>['10', '5', '3', '2', '1'][level - 1],
            counts: level == 1
                ? s7Counts()
                : s7Counts(pendingWallet: 0, pendingMining: 0),
            total: level == 1 ? 3 : 0,
          ),
      ],
  boost: const LaunchUnavailable(s7ReferralBoostPending),
  rules: ReferralRulesInfo(
    configVersion: 'referralRulesV1',
    effectiveAt: DateTime.utc(2026, 9),
    appliesTo: 'miningPower',
    maximumDepth: 5,
    claimWindowDays: 7,
  ),
);

ReferralBinding s7BoundBinding() => ReferralBinding(
  isBound: true,
  inviter: ReferralInviter(
    depth: 1,
    validationStatus: ReferralValidationStatus.pendingMining,
    lockedAt: DateTime.utc(2026, 9, 9, 4),
    effectiveFrom: DateTime.utc(2026, 9, 9, 4),
    configVersion: 'referralRulesV1',
  ),
  claimWindow: ReferralClaimWindowTimed(
    isOpen: true,
    activatedAt: DateTime.utc(2026, 9, 6),
    closesAt: DateTime.utc(2026, 9, 13),
  ),
);
