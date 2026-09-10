import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';

/// Presentation models for the `mining` module (loop-api decision 0036).
///
/// There is no approved mining formula version in this step, so every power,
/// output, accumulation, claim, rank and boost arrives as `unavailable` with
/// the server's own `reasonCode`. Nothing here can hold a number the server
/// did not send, and no ratio, weight or emission is written into the client.

/// A settled power snapshot. It cannot exist before a formula version is
/// approved, so the unavailable branch is the only one this step renders.
@immutable
sealed class MiningSnapshotRef {
  const MiningSnapshotRef();
}

@immutable
final class MiningSnapshotUnavailable extends MiningSnapshotRef {
  const MiningSnapshotUnavailable(this.reasonCode);

  final String reasonCode;
}

@immutable
final class MiningSnapshotComputed extends MiningSnapshotRef {
  const MiningSnapshotComputed({
    required this.snapshotId,
    required this.blockNumber,
    required this.blockHash,
    required this.formulaVersion,
    required this.priceVersion,
    required this.computedAt,
  });

  final String snapshotId;
  final String blockNumber;
  final String blockHash;
  final String formulaVersion;
  final String priceVersion;
  final DateTime computedAt;
}

/// The formula gate on the summary. `pendingVersion` names the draft that is
/// waiting for approval so the page can label it "待批准（…）".
@immutable
final class MiningFormulaGate {
  const MiningFormulaGate({
    required this.reasonCode,
    required this.pendingVersion,
  });

  final String reasonCode;
  final String? pendingVersion;
}

@immutable
final class MiningSummary {
  const MiningSummary({
    required this.power,
    required this.networkPower,
    required this.estimatedToday,
    required this.accumulated,
    required this.claimable,
    required this.referralBoost,
    required this.formula,
    required this.snapshot,
  });

  final LaunchUnavailable power;
  final LaunchUnavailable networkPower;
  final LaunchUnavailable estimatedToday;
  final LaunchUnavailable accumulated;
  final LaunchUnavailable claimable;
  final LaunchUnavailable referralBoost;
  final MiningFormulaGate formula;
  final MiningSnapshotRef snapshot;
}

/// `included` and `excluded` are empty **by contract**, not because the wallet
/// holds nothing: without a formula there is no way to classify an asset.
@immutable
final class MiningAssets {
  const MiningAssets({
    required this.totalPower,
    required this.source,
    required this.referencePrice,
  });

  final LaunchUnavailable totalPower;
  final LaunchUnavailable source;
  final LaunchUnavailable referencePrice;
}

@immutable
final class MiningRewards {
  const MiningRewards({
    required this.claimable,
    required this.claimExecutable,
    required this.estimatedToday,
    required this.accumulated,
    required this.source,
  });

  final LaunchUnavailable claimable;

  /// Always `false`. The claim control renders disabled with the server's own
  /// reason; the page never opens a signing sheet.
  final bool claimExecutable;
  final LaunchUnavailable estimatedToday;
  final LaunchUnavailable accumulated;
  final LaunchUnavailable source;
}

enum MiningRankScope {
  users('users'),
  communities('communities');

  const MiningRankScope(this.wireName);

  final String wireName;

  static MiningRankScope? tryParse(String value) {
    for (final scope in values) {
      if (scope.wireName == value) return scope;
    }
    return null;
  }
}

String miningRankScopeLabel(MiningRankScope scope) => switch (scope) {
  MiningRankScope.users => '用户榜',
  MiningRankScope.communities => '社区榜',
};

/// The anonymity contract for a future ranking row: an entry shows its alias
/// only when the account is discoverable and not in anonymous mode; otherwise
/// it shows the anonymous member label. Both are server-owned keys.
@immutable
final class MiningRankDisplayRule {
  const MiningRankDisplayRule({
    required this.anonymousMemberKey,
    required this.ruleKey,
  });

  final String anonymousMemberKey;
  final String ruleKey;
}

@immutable
final class MiningRank {
  const MiningRank({
    required this.scope,
    required this.ranking,
    required this.myPosition,
    required this.snapshot,
    required this.display,
  });

  final MiningRankScope scope;
  final LaunchUnavailable ranking;
  final LaunchUnavailable myPosition;
  final MiningSnapshotRef snapshot;
  final MiningRankDisplayRule display;
}

@immutable
final class MiningCommunityRef {
  const MiningCommunityRef({
    required this.communityId,
    required this.name,
    required this.boundAssetId,
  });

  final String communityId;
  final String name;
  final String? boundAssetId;
}

@immutable
sealed class MiningCommunityWeight {
  const MiningCommunityWeight();
}

@immutable
final class MiningCommunityWeightApproved extends MiningCommunityWeight {
  const MiningCommunityWeightApproved({
    required this.value,
    required this.configVersion,
    required this.reviewedAt,
  });

  /// The reviewed weight, kept as the server's decimal string.
  final String value;
  final String configVersion;
  final DateTime reviewedAt;
}

@immutable
final class MiningCommunityWeightPending extends MiningCommunityWeight {
  const MiningCommunityWeightPending({
    required this.reasonCode,
    required this.reviewStatus,
  });

  final String reasonCode;
  final String reviewStatus;
}

@immutable
final class MiningCommunity {
  const MiningCommunity({
    required this.community,
    required this.weight,
    required this.communityPower,
    required this.myContribution,
    required this.rank,
    required this.participants,
  });

  final MiningCommunityRef community;
  final MiningCommunityWeight weight;
  final LaunchUnavailable communityPower;
  final LaunchUnavailable myContribution;
  final LaunchUnavailable rank;
  final LaunchUnavailable participants;
}

// ---------------------------------------------------------------------------
// rules
// ---------------------------------------------------------------------------

enum MiningFormulaStatus {
  pendingApproval('pending_approval'),
  approved('approved'),
  retired('retired');

  const MiningFormulaStatus(this.wireName);

  final String wireName;

  static MiningFormulaStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

String miningFormulaStatusLabel(MiningFormulaStatus status) => switch (status) {
  MiningFormulaStatus.pendingApproval => '待批准',
  MiningFormulaStatus.approved => '已批准',
  MiningFormulaStatus.retired => '已退役',
};

/// A weight band. Only its key and approval state exist; the numeric range is
/// deliberately absent until the formula is approved.
@immutable
final class MiningWeightBand {
  const MiningWeightBand({required this.status, required this.descriptionKey});

  final MiningFormulaStatus status;
  final String descriptionKey;
}

@immutable
final class MiningWeightRange {
  const MiningWeightRange({
    required this.loop,
    required this.community,
    required this.reviewFactorKeys,
  });

  final MiningWeightBand loop;
  final MiningWeightBand community;
  final List<String> reviewFactorKeys;
}

@immutable
final class MiningPriceGuardRule {
  const MiningPriceGuardRule({required this.ruleKey, required this.status});

  final String ruleKey;
  final MiningFormulaStatus status;
}

@immutable
final class MiningFormulaVersion {
  const MiningFormulaVersion({
    required this.configVersion,
    required this.status,
    required this.effectiveAt,
    required this.approvedAt,
    required this.expressionKey,
    required this.dailyOutputKey,
    required this.weightRange,
    required this.priceGuardRules,
    required this.referralBoostStatus,
  });

  final String configVersion;
  final MiningFormulaStatus status;
  final DateTime? effectiveAt;
  final DateTime? approvedAt;
  final String expressionKey;
  final String dailyOutputKey;
  final MiningWeightRange weightRange;
  final List<MiningPriceGuardRule> priceGuardRules;
  final MiningFormulaStatus referralBoostStatus;
}

@immutable
final class MiningReferralLevelRule {
  const MiningReferralLevelRule({
    required this.level,
    required this.boostPercent,
    required this.descriptionKey,
  });

  final int level;

  /// The server's own decimal string. It is displayed verbatim and never
  /// parsed into a double or restated as a fixed ladder in the client.
  final String boostPercent;
  final String descriptionKey;
}

@immutable
final class MiningReferralRules {
  const MiningReferralRules({
    required this.configVersion,
    required this.effectiveAt,
    required this.levels,
  });

  final String configVersion;
  final DateTime effectiveAt;
  final List<MiningReferralLevelRule> levels;
}

@immutable
final class MiningRules {
  const MiningRules({
    required this.approved,
    required this.pendingApproval,
    required this.baseline,
    required this.referral,
  });

  /// `null` for the whole of step 7.
  final MiningFormulaVersion? approved;
  final List<MiningFormulaVersion> pendingApproval;
  final LaunchUnavailable baseline;
  final MiningReferralRules referral;

  bool get hasApprovedFormula => approved != null;
}

/// zh-CN copy for one server-owned rule key. An unknown key keeps a neutral
/// sentence: the client never invents a formula, a ratio or a guard.
String miningRuleKeyText(String key) => switch (key) {
  'mining.rules.formula.holdingTimesReferencePriceTimesWeight' =>
    '算力 = 持有量 × 参考价 × 权重',
  'mining.rules.dailyOutput.shareOfNetworkPower' => '每日产出 = 我的算力 ÷ 全网算力 × 当日产量',
  'mining.rules.weight.loopFixedMaximum' => 'LOOP 采用固定的最高权重档位（数值待批准）。',
  'mining.rules.weight.communityReviewed' => '社区币权重按审核结果授予，区间待批准。',
  'mining.rules.reviewFactor.communityQuality' => '社区质量',
  'mining.rules.reviewFactor.communityScale' => '社区规模',
  'mining.rules.reviewFactor.tokenLiquidity' => 'Token 流动性',
  'mining.rules.reviewFactor.projectQuality' => '项目质量',
  'mining.rules.reviewFactor.marketStability' => '市场稳定性',
  'mining.rules.reviewFactor.userQuality' => '用户质量',
  'mining.rules.reviewFactor.partnershipDepth' => '与 LOOP 的合作深度',
  'mining.rules.priceGuard.twap' => 'TWAP 时间加权均价：避免单笔成交扭曲参考价。',
  'mining.rules.priceGuard.multiPeriodMultiSource' => '多周期、多渠道比对，交叉验证异常波动。',
  'mining.rules.priceGuard.liquidityCap' => 'Liquidity Cap：低流动性资产限制可计入价值。',
  'mining.rank.anonymousMember' => '匿名成员',
  'mining.rank.display.aliasOrAnonymous' =>
    '排行条目只在该账号可被发现且未开启匿名模式时显示别名，否则显示「匿名成员」。',
  _ => 'LOOP 定义的规则项。',
};
