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

const s7LaunchBaselinePending = 'LAUNCH_CONTRACT_BASELINE_PENDING';
const s7ConfigPending = 'LAUNCH_CONFIG_PENDING_CONFIRMATION';
const s7TierPending = 'TIER_MODE_PENDING';
const s7StakingPending = 'STAKING_CONTRACT_PENDING';
const s7FormulaPending = 'MINING_FORMULA_BASELINE_PENDING';
const s7RewardPending = 'REWARD_AUTHORITY_PENDING';

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
}) => LaunchSummary(
  launchId: launchId,
  projectId: s7ProjectId,
  name: name,
  ticker: ticker,
  chainId: 'eip155:56',
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
}) => LaunchDetail(
  launch: s7LaunchSummary(),
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

LaunchMilestones s7Milestones({List<LaunchMilestone>? items}) =>
    LaunchMilestones(
      projectId: s7ProjectId,
      items:
          items ??
          <LaunchMilestone>[
            LaunchMilestone(
              venueMilestoneId: s7MilestoneId,
              venue: LaunchVenue.lbank,
              marketType: LaunchMarketType.spot,
              state: LaunchMilestoneState.listed,
              evidence: LaunchMilestoneEvidence(
                digest: 'a' * 64,
                recordedAt: DateTime.utc(2026, 9, 5, 3),
                observedAt: DateTime.utc(2026, 9, 1),
                reviewer: 'ops.alice',
              ),
              version: 2,
              updatedAt: DateTime.utc(2026, 9, 5, 3),
            ),
          ],
    );

// ---------------------------------------------------------------------------
// mining
// ---------------------------------------------------------------------------

MiningSummary s7MiningSummary({String? pendingVersion}) => MiningSummary(
  power: const LaunchUnavailable(s7FormulaPending),
  networkPower: const LaunchUnavailable(s7FormulaPending),
  estimatedToday: const LaunchUnavailable(s7FormulaPending),
  accumulated: const LaunchUnavailable(s7FormulaPending),
  claimable: const LaunchUnavailable(s7RewardPending),
  referralBoost: const LaunchUnavailable(s7FormulaPending),
  formula: MiningFormulaGate(
    reasonCode: s7FormulaPending,
    pendingVersion: pendingVersion ?? 'miningFormulaV1-draft',
  ),
  snapshot: const MiningSnapshotUnavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
);

MiningAssets s7MiningAssets() => const MiningAssets(
  totalPower: LaunchUnavailable(s7FormulaPending),
  source: LaunchUnavailable(s7FormulaPending),
  referencePrice: LaunchUnavailable(s7FormulaPending),
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
}) => MiningRank(
  scope: scope,
  ranking: const LaunchUnavailable(s7FormulaPending),
  myPosition: const LaunchUnavailable(s7FormulaPending),
  snapshot: const MiningSnapshotUnavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
  display: const MiningRankDisplayRule(
    anonymousMemberKey: 'mining.rank.anonymousMember',
    ruleKey: 'mining.rank.display.aliasOrAnonymous',
  ),
);

MiningCommunity s7MiningCommunity({MiningCommunityWeight? weight}) =>
    MiningCommunity(
      community: const MiningCommunityRef(
        communityId: s7CommunityId,
        name: 'Frog Holders',
        boundAssetId: null,
      ),
      weight:
          weight ??
          const MiningCommunityWeightPending(
            reasonCode: 'COMMUNITY_WEIGHT_PENDING_REVIEW',
            reviewStatus: 'pending_review',
          ),
      communityPower: const LaunchUnavailable(s7FormulaPending),
      myContribution: const LaunchUnavailable(s7FormulaPending),
      rank: const LaunchUnavailable(s7FormulaPending),
      participants: const LaunchUnavailable(s7FormulaPending),
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
  boost: const LaunchUnavailable(s7FormulaPending),
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
