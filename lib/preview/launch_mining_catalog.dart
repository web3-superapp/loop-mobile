// Deterministic memory-only display specimens. No provider observations.
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';

const previewLaunchLaunchId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const previewLaunchProjectId = '17f6a9b2-2f22-4c11-9f3a-1a2b3c4d5e6f';
const previewLaunchRoundId = '9c1d6e2a-7c3b-4a55-8d21-0f1e2d3c4b5a';
const previewLaunchCommunityId = '5b0c9d18-6a44-4f39-b0d2-9e8f7a6b5c4d';
const previewLaunchMilestoneId = '2e4f6a80-1b2c-4d3e-9f01-a2b3c4d5e6f7';
const previewLaunchLaunchBaselinePending = 'LAUNCH_CONTRACT_BASELINE_PENDING';
const previewLaunchConfigPending = 'LAUNCH_CONFIG_PENDING_CONFIRMATION';
const previewLaunchTierPending = 'TIER_MODE_PENDING';
const previewLaunchStakingPending = 'STAKING_CONTRACT_PENDING';
const previewLaunchFormulaPending = 'MINING_FORMULA_BASELINE_PENDING';
const previewLaunchRewardPending = 'REWARD_AUTHORITY_PENDING';

const previewLaunchReferralBoostPending = 'MINING_REFERRAL_BOOST_PENDING';

LaunchOnChainState previewLaunchOnChainState() =>
    const LaunchOnChainUnavailable(previewLaunchLaunchBaselinePending);

LaunchSummary previewLaunchLaunchSummary({
  String launchId = previewLaunchLaunchId,
  String name = 'MoonCat',
  String ticker = 'MCAT',
  LaunchScheduleStatus scheduleStatus = LaunchScheduleStatus.unscheduled,
  String? configVersion,
  String chainId = loopPrimaryChainId,
  LaunchOnChainState? onChainState,
}) => LaunchSummary(
  launchId: launchId,
  projectId: previewLaunchProjectId,
  name: name,
  ticker: ticker,
  chainId: chainId,
  contractAddress: null,
  configDigest: null,
  scheduleStatus: scheduleStatus,
  onChainState: onChainState ?? previewLaunchOnChainState(),
  configVersion: configVersion,
  createdAt: DateTime.utc(2026, 9, 8, 1),
);

LaunchOverview previewLaunchOverview({
  List<LaunchSummary>? live,
  List<LaunchSummary>? upcoming,
  List<LaunchSummary>? awaitingSchedule,
  List<LaunchSummary>? ended,
  LaunchGraduated graduated = const LaunchGraduatedUnavailable(
    LaunchUnavailable(previewLaunchLaunchBaselinePending),
  ),
}) => LaunchOverview(
  segments: LaunchSegments(
    live: live ?? const <LaunchSummary>[],
    upcoming: upcoming ?? const <LaunchSummary>[],
    awaitingSchedule:
        awaitingSchedule ?? <LaunchSummary>[previewLaunchLaunchSummary()],
    ended: ended ?? const <LaunchSummary>[],
  ),
  graduated: graduated,
  myEligibility: const LaunchUnavailable(previewLaunchTierPending),
  staking: const LaunchUnavailable(previewLaunchStakingPending),
  catalog: LaunchCatalogStamp(
    configVersion: 'launchCatalogV1',
    source: 'loop',
    observedAt: DateTime.utc(2026, 9, 9, 6, 30),
  ),
);

LaunchConfigSlots previewLaunchPendingSlots() => const LaunchConfigSlots(
  walletRoundCap: LaunchConfigSlotPending(previewLaunchConfigPending),
  walletProjectCap: LaunchConfigSlotPending(previewLaunchConfigPending),
  feeBps: LaunchConfigSlotPending(previewLaunchConfigPending),
  softCap: LaunchConfigSlotPending(previewLaunchConfigPending),
  hardCap: LaunchConfigSlotPending(previewLaunchConfigPending),
  tge: LaunchConfigSlotPending(previewLaunchConfigPending),
  vesting: LaunchConfigSlotPending(previewLaunchConfigPending),
  tierModeV1: LaunchConfigSlotPending(previewLaunchConfigPending),
);

LaunchRound previewLaunchRound({
  int index = 1,
  String configVersion = 'launchMoonCatV1',
  String roundId = previewLaunchRoundId,
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

LaunchDetail previewLaunchDetail({
  LaunchConfig? config,
  List<LaunchRound>? rounds,
  LaunchUnavailable? configPending,
  String chainId = loopPrimaryChainId,
}) => LaunchDetail(
  launch: previewLaunchLaunchSummary(chainId: chainId),
  project: const LaunchProjectBrief(
    projectId: previewLaunchProjectId,
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
        slots: previewLaunchPendingSlots(),
      ),
  configPending:
      configPending ?? const LaunchUnavailable(previewLaunchConfigPending),
  rounds:
      rounds ??
      <LaunchRound>[previewLaunchRound(), previewLaunchRound(index: 2)],
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
  market: const LaunchUnavailable(previewLaunchLaunchBaselinePending),
  holders: const LaunchUnavailable(previewLaunchLaunchBaselinePending),
);

LaunchEligibility previewLaunchEligibility({
  LaunchEligibilityMode mode = LaunchEligibilityMode.unavailable,
  String reasonCode = previewLaunchTierPending,
  String? configVersion,
  bool dependsOnStaking = false,
}) => LaunchEligibility(
  launchId: previewLaunchLaunchId,
  mode: mode,
  result: LaunchEligibilityPending(reasonCode),
  configVersion: configVersion,
  effectiveAt: null,
  dependsOnStaking: dependsOnStaking,
);

LaunchStake previewLaunchStake() => const LaunchStake(
  stake: LaunchUnavailable(previewLaunchStakingPending),
  executable: false,
);

LaunchHolders previewLaunchHolders() => const LaunchHolders(
  launchId: previewLaunchLaunchId,
  holders: LaunchReadingUnavailable<LaunchHolderCount>(
    LaunchUnavailable(previewLaunchLaunchBaselinePending),
  ),
  myPosition: LaunchReadingUnavailable<LaunchPosition>(
    LaunchUnavailable(previewLaunchLaunchBaselinePending),
  ),
  walletCap: LaunchReadingUnavailable<LaunchWalletCap>(
    LaunchUnavailable(previewLaunchLaunchBaselinePending),
  ),
);

LaunchHistory previewLaunchHistory() => const LaunchHistory(
  launchId: previewLaunchLaunchId,
  source: LaunchReadingUnavailable<LaunchIndexedSource>(
    LaunchUnavailable(previewLaunchLaunchBaselinePending),
  ),
);

LaunchEconomy previewLaunchEconomy() => LaunchEconomy(
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
  source: 'loop',
  observedAt: DateTime.utc(2026, 9, 9, 6, 30),
);

LaunchProject previewLaunchProject({
  String projectId = previewLaunchProjectId,
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

LaunchMilestones previewLaunchMilestones({List<LaunchMilestone>? items}) =>
    LaunchMilestones(
      projectId: previewLaunchProjectId,
      items:
          items ??
          <LaunchMilestone>[
            previewLaunchListedMilestone(),
            for (final track in launchMilestoneTracks.skip(1))
              previewLaunchImplicitMilestone(
                venue: track.$1,
                marketType: track.$2,
              ),
          ],
    );

LaunchMilestone previewLaunchListedMilestone({
  LaunchMilestoneState state = LaunchMilestoneState.listed,
  LaunchVenue venue = LaunchVenue.lbank,
  LaunchMarketType marketType = LaunchMarketType.spot,
  DateTime? observedAt,
}) => LaunchMilestone(
  venueMilestoneId: previewLaunchMilestoneId,
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

LaunchMilestone previewLaunchImplicitMilestone({
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

const previewLaunchBaselineVersion = 'miningFormula-devBaseline-2026-09-15-r2';

MiningFormulaEffective previewLaunchEffectiveFormula() =>
    MiningFormulaEffective(
      configVersion: previewLaunchBaselineVersion,
      effectiveAt: DateTime.utc(2026, 9, 15, 14, 57, 37),
      scope: MiningFormulaScope.developmentBaseline,
    );

MiningFormulaPending previewLaunchPendingFormula() =>
    const MiningFormulaPending(
      reasonCode: previewLaunchFormulaPending,
      pendingVersion: 'miningFormulaV1-draft',
    );

MiningFormulaPending previewLaunchPendingBaseline() =>
    const MiningFormulaPending(
      reasonCode: previewLaunchFormulaPending,
      pendingVersion: null,
    );

MiningSummary previewLaunchMiningSummary({
  String? pendingVersion,
  MiningFigure? power,
  MiningFigure? networkPower,
  MiningDailyOutput? estimatedToday,
  LaunchUnavailable? accumulated,
  MiningFormulaGate? formula,
  MiningSnapshotRef? snapshot,
}) => MiningSummary(
  power: power ?? const MiningFigureUnavailable(previewLaunchFormulaPending),
  networkPower:
      networkPower ??
      const MiningFigureUnavailable(previewLaunchFormulaPending),
  estimatedToday:
      estimatedToday ??
      const MiningDailyOutputUnavailable(previewLaunchFormulaPending),
  accumulated:
      accumulated ?? const LaunchUnavailable(previewLaunchFormulaPending),
  claimable: const LaunchUnavailable(previewLaunchRewardPending),
  referralBoost: const LaunchUnavailable(previewLaunchReferralBoostPending),
  formula:
      formula ??
      MiningFormulaPending(
        reasonCode: previewLaunchFormulaPending,
        pendingVersion: pendingVersion ?? 'miningFormulaV1-draft',
      ),
  snapshot:
      snapshot ??
      const MiningSnapshotUnavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
);

const previewLaunchCakeAssetId =
    'eip155:56:0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82';
const previewLaunchUsdtAssetId =
    'eip155:56:0x55d398326f99059ff775485246999027b3197955';
const previewLaunchWbnbAssetId =
    'eip155:56:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c';
const previewLaunchNativeAssetId = 'eip155:56:native';
const previewLaunchPriceVersion = 'dexscreener:2026-09-15T14:58:51.862Z';

MiningSnapshotComputed previewLaunchMiningSnapshot({
  MiningHoldingsSource? holdingsSource,
}) => MiningSnapshotComputed(
  snapshotId: '0e358b31-e49f-48b9-89b2-c5c908c3ad5e',
  blockNumber: '122037728',
  blockHash:
      '0x3decab82b150493d90cb8fe47b3873c6e3b8c72aecf08ce91b4aceb266bda28a',
  formulaVersion: previewLaunchBaselineVersion,
  priceVersion: previewLaunchPriceVersion,
  computedAt: DateTime.utc(2026, 9, 15, 14, 58, 54, 366),
  holdingsSource: holdingsSource,
);

MiningAssets previewLaunchMiningAssets({
  MiningFigure? totalPower,
  List<MiningAssetRow>? included,
  List<MiningExcludedAsset>? excluded,
  MiningSnapshotRef? source,
  MiningReferencePrice? referencePrice,
  MiningFormulaGate? formula,
}) => MiningAssets(
  totalPower:
      totalPower ?? const MiningFigureUnavailable(previewLaunchFormulaPending),
  included: included ?? const <MiningAssetRow>[],
  excluded: excluded ?? const <MiningExcludedAsset>[],
  source:
      source ??
      const MiningSnapshotUnavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
  referencePrice:
      referencePrice ??
      const MiningReferencePriceUnavailable(previewLaunchFormulaPending),
  formula: formula ?? previewLaunchPendingFormula(),
);

MiningAssetRow previewLaunchMiningAssetRow({
  String assetId = previewLaunchCakeAssetId,
  String? symbol = 'Cake',
  String holding = '0',
  String referencePriceUsd = '2.26',
  String weight = '0.8',
  String power = '0',
  String? proxyAssetId,
  String? logoUrl,
}) => MiningAssetRow(
  assetId: assetId,
  symbol: symbol,
  logoUrl: logoUrl,
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

MiningRewards previewLaunchMiningRewards({
  LaunchUnavailable? claimable,
  MiningDailyOutput? estimatedToday,
  LaunchUnavailable? accumulated,
  LaunchUnavailable? source,
}) => MiningRewards(
  claimable: claimable ?? const LaunchUnavailable(previewLaunchRewardPending),
  claimExecutable: false,
  estimatedToday:
      estimatedToday ??
      const MiningDailyOutputUnavailable(previewLaunchFormulaPending),
  accumulated:
      accumulated ?? const LaunchUnavailable(previewLaunchFormulaPending),
  source: source ?? const LaunchUnavailable(previewLaunchFormulaPending),
);

MiningRank previewLaunchMiningRank({
  MiningRankScope scope = MiningRankScope.communities,
  MiningRanking? ranking,
  MiningRankPosition? myPosition,
  MiningSnapshotRef? snapshot,
  MiningFormulaGate? formula,
}) => MiningRank(
  scope: scope,
  ranking:
      ranking ?? const MiningRankingUnavailable(previewLaunchFormulaPending),
  myPosition:
      myPosition ??
      const MiningRankPositionUnavailable(previewLaunchFormulaPending),
  snapshot:
      snapshot ??
      const MiningSnapshotUnavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
  display: const MiningRankDisplayRule(
    anonymousMemberKey: 'mining.rank.anonymousMember',
    ruleKey: 'mining.rank.display.anonymousModeOnly',
    powerRuleKey: 'mining.rank.power.ownerVisibility',
  ),
  formula: formula ?? previewLaunchPendingFormula(),
);

const previewLaunchPublicProfileId = '8c2b7a15-4d3e-4f60-9a11-2b3c4d5e6f70';
const previewLaunchOtherPublicProfileId =
    '5f1c2d3e-9a8b-4c7d-8e6f-0a1b2c3d4e5f';
const previewLaunchOtherCommunityId = '439cabe6-4c98-4f99-860f-192ad52403a1';

MiningRankingUsers previewLaunchMiningUserBoard({
  List<MiningRankUserRow>? items,
  int participants = 0,
}) => MiningRankingUsers(
  items:
      items ??
      const <MiningRankUserRow>[
        MiningRankUserRow(
          position: null,
          power: '0',
          powerVisibility: MiningRankAudience.everyone,
          display: MiningRankAlias(
            alias: 'whale',
            publicProfileId: previewLaunchPublicProfileId,
            audience: MiningRankAudience.everyone,
          ),
          isSelf: false,
        ),
        MiningRankUserRow(
          position: null,
          power: '0',
          powerVisibility: MiningRankAudience.everyone,
          display: MiningRankAnonymous('mining.rank.anonymousMember'),
          isSelf: false,
        ),
      ],
  participants: participants,
);

MiningRankingCommunities previewLaunchMiningCommunityBoard({
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
            communityId: previewLaunchOtherCommunityId,
            name: 'Builders Guild',
            boundAssetId: previewLaunchUsdtAssetId,
          ),
          weight: '1.5',
          participants: 0,
        ),
        MiningRankCommunityRow(
          position: null,
          power: '0',
          community: MiningCommunityRef(
            communityId: previewLaunchCommunityId,
            name: 'DeFi 早读会',
            boundAssetId: previewLaunchCakeAssetId,
          ),
          weight: '0.8',
          participants: 0,
        ),
      ],
  participants: participants,
);

MiningCommunity previewLaunchMiningCommunity({
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
        communityId: previewLaunchCommunityId,
        name: 'Frog Holders',
        // Bound, and waiting for a review: the two go together, because a
        // community with nothing bound has no weight to review (0046).
        boundAssetId: previewLaunchCakeAssetId,
      ),
  weight:
      weight ??
      const MiningCommunityWeightPending(
        reasonCode: 'COMMUNITY_WEIGHT_PENDING_REVIEW',
        reviewStatus: MiningWeightReviewStatus.pendingReview,
      ),
  communityPower:
      communityPower ??
      const MiningFigureUnavailable(previewLaunchFormulaPending),
  myContribution:
      myContribution ??
      const MiningFigureUnavailable(previewLaunchFormulaPending),
  rank:
      rank ?? const MiningRankPositionUnavailable(previewLaunchFormulaPending),
  participants:
      participants ??
      const MiningParticipantsUnavailable(previewLaunchFormulaPending),
  snapshot:
      snapshot ??
      const MiningSnapshotUnavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
);

MiningFormulaVersion previewLaunchDraftFormula({
  String configVersion = 'miningFormulaV1-draft',
}) => MiningFormulaVersion(
  configVersion: configVersion,
  status: MiningFormulaStatus.pendingApproval,
  // A product draft publishes rule keys and no numbers.
  scope: MiningFormulaScope.product,
  effectiveAt: null,
  approvedAt: null,
  expressionKey: 'mining.rules.formula.holdingTimesReferencePriceTimesWeight',
  dailyOutputKey: 'mining.rules.dailyOutput.shareOfNetworkPower',
  assetWeights: const <String, String>{},
  dailyOutput: null,
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

MiningFormulaVersion previewLaunchBaselineFormulaVersion() =>
    MiningFormulaVersion(
      configVersion: previewLaunchBaselineVersion,
      status: MiningFormulaStatus.approved,
      scope: MiningFormulaScope.developmentBaseline,
      effectiveAt: DateTime.utc(2026, 9, 15, 14, 57, 37),
      approvedAt: DateTime.utc(2026, 9, 15, 14, 57, 37),
      expressionKey:
          'mining.rules.formula.holdingTimesReferencePriceTimesWeight',
      dailyOutputKey: 'mining.rules.dailyOutput.shareOfNetworkPower',
      assetWeights: const <String, String>{
        previewLaunchNativeAssetId: '1',
        previewLaunchCakeAssetId: '1',
        previewLaunchUsdtAssetId: '1',
        previewLaunchWbnbAssetId: '1',
      },
      dailyOutput: const MiningFormulaDailyOutput(
        status: 'development_placeholder',
        budget: '1000000',
        unitKey: 'mining.rules.dailyOutput.unit.loopTokenPending',
      ),
      weightRange: const MiningWeightRange(
        loop: MiningWeightBand(
          status: MiningFormulaStatus.pendingApproval,
          descriptionKey: 'mining.rules.weight.loopFixedMaximum',
        ),
        community: MiningWeightBand(
          status: MiningFormulaStatus.approved,
          descriptionKey: 'mining.rules.weight.communityReviewed',
          range: MiningWeightBounds(min: '0.5', max: '2'),
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
      ],
      referralBoostStatus: MiningFormulaStatus.pendingApproval,
    );

MiningRules previewLaunchBaselineMiningRules() => previewLaunchMiningRules(
  approved: previewLaunchBaselineFormulaVersion(),
  baseline: previewLaunchEffectiveFormula(),
);

MiningRules previewLaunchMiningRules({
  MiningFormulaVersion? approved,
  List<MiningFormulaVersion>? pendingApproval,
  MiningFormulaGate? baseline,
}) => MiningRules(
  approved: approved,
  pendingApproval:
      pendingApproval ?? <MiningFormulaVersion>[previewLaunchDraftFormula()],
  baseline: baseline ?? previewLaunchPendingBaseline(),
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

ReferralValidationCounts previewLaunchCounts({
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

ReferralOverview previewLaunchReferral({
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
                ? previewLaunchCounts()
                : previewLaunchCounts(pendingWallet: 0, pendingMining: 0),
            total: level == 1 ? 3 : 0,
          ),
      ],
  boost: const LaunchUnavailable(previewLaunchReferralBoostPending),
  rules: ReferralRulesInfo(
    configVersion: 'referralRulesV1',
    effectiveAt: DateTime.utc(2026, 9),
    appliesTo: 'miningPower',
    maximumDepth: 5,
    claimWindowDays: 7,
  ),
);

ReferralBinding previewLaunchBoundBinding() => ReferralBinding(
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
