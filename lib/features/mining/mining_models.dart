import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
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

/// One mining figure. The server either settled it under an effective formula
/// version, or it did not, and then only its own `reasonCode` exists. The
/// client never fills the gap with a zero.
@immutable
sealed class MiningFigure {
  const MiningFigure();
}

@immutable
final class MiningFigureUnavailable extends MiningFigure {
  const MiningFigureUnavailable(this.reasonCode);

  final String reasonCode;
}

@immutable
final class MiningFigureValue extends MiningFigure {
  const MiningFigureValue(this.value);

  /// The server's own unsigned decimal string, displayed verbatim in the
  /// monospace face. It is never parsed into a double.
  final String value;
}

/// The scope a formula version declares about itself. `developmentBaseline`
/// is the Decision 0043 placeholder: it produces numbers, and those numbers
/// are not a product measure.
enum MiningFormulaScope {
  developmentBaseline('development_baseline'),
  product(null);

  const MiningFormulaScope(this.wireName);

  final String? wireName;

  static MiningFormulaScope? tryParse(String? value) {
    for (final scope in values) {
      if (scope.wireName == value) return scope;
    }
    return null;
  }

  bool get isBaseline => this == MiningFormulaScope.developmentBaseline;
}

/// The label a development-baseline figure always carries, wherever it is
/// printed. The version string itself is a backend identifier and stays
/// inside 详情.
const String miningBaselineLabel = '开发基线';

/// The estimated daily output. The available branch carries the budget it was
/// divided out of, the budget's own status and the version that declared it,
/// because a placeholder budget must never reach the screen as a plain number.
@immutable
sealed class MiningDailyOutput {
  const MiningDailyOutput();
}

@immutable
final class MiningDailyOutputUnavailable extends MiningDailyOutput {
  const MiningDailyOutputUnavailable(this.reasonCode);

  final String reasonCode;
}

@immutable
final class MiningDailyOutputEstimate extends MiningDailyOutput {
  const MiningDailyOutputEstimate({
    required this.value,
    required this.budget,
    required this.unitKey,
    required this.budgetStatus,
    required this.formulaVersion,
    required this.scope,
  });

  final String value;
  final String budget;
  final String unitKey;

  /// `development_placeholder` while no product budget exists. The page says
  /// so in words; it never prints the budget on its own.
  final String budgetStatus;
  final String formulaVersion;
  final MiningFormulaScope scope;

  bool get isPlaceholderBudget => budgetStatus == 'development_placeholder';
}

/// The formula gate on the summary. Either a version is approved and in
/// effect — and then every number on the page belongs to it — or a draft is
/// waiting for approval and nothing can be computed.
@immutable
sealed class MiningFormulaGate {
  const MiningFormulaGate();
}

@immutable
final class MiningFormulaPending extends MiningFormulaGate {
  const MiningFormulaPending({
    required this.reasonCode,
    required this.pendingVersion,
  });

  final String reasonCode;
  final String? pendingVersion;
}

@immutable
final class MiningFormulaEffective extends MiningFormulaGate {
  const MiningFormulaEffective({
    required this.configVersion,
    required this.effectiveAt,
    required this.scope,
  });

  final String configVersion;
  final DateTime effectiveAt;
  final MiningFormulaScope scope;
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

  final MiningFigure power;
  final MiningFigure networkPower;
  final MiningDailyOutput estimatedToday;

  /// Pinned unavailable: there is no reward ledger to accumulate against.
  final LaunchUnavailable accumulated;
  final LaunchUnavailable claimable;
  final LaunchUnavailable referralBoost;
  final MiningFormulaGate formula;
  final MiningSnapshotRef snapshot;
}

/// Where one row's reference price came from. `proxied` means the formula
/// version priced this asset through a declared proxy asset — the chain's own
/// coin has no pair of its own — so the page must say the price is not the
/// asset's own.
enum MiningReferencePriceQuality {
  fresh('fresh'),
  proxied('proxied');

  const MiningReferencePriceQuality(this.wireName);

  final String wireName;

  static MiningReferencePriceQuality? tryParse(String value) {
    for (final quality in values) {
      if (quality.wireName == value) return quality;
    }
    return null;
  }

  bool get isProxied => this == MiningReferencePriceQuality.proxied;
}

/// One asset the settlement weighted. Every figure is the server's own decimal
/// string; the client multiplies nothing, because the row that reached it was
/// already settled at one block.
@immutable
final class MiningAssetRow {
  const MiningAssetRow({
    required this.assetId,
    required this.holding,
    required this.referencePriceUsd,
    required this.referencePriceQuality,
    required this.referencePriceProxyAssetId,
    required this.weight,
    required this.power,
    required this.blockNumber,
  });

  final String assetId;
  final String holding;
  final String referencePriceUsd;
  final MiningReferencePriceQuality referencePriceQuality;

  /// The asset whose price was used. Non-null exactly when the quality is
  /// `proxied`: a proxied price with no proxy, or a fresh price carrying one,
  /// would leave the row unable to say where its price came from.
  final String? referencePriceProxyAssetId;

  /// The effective weight already in the power: the formula's asset weight
  /// times the approved community weight, when one community binds the asset.
  final String weight;
  final String power;
  final String blockNumber;

  bool get isProxiedPrice => referencePriceQuality.isProxied;
}

/// One asset the account holds that the settlement did not weight. The reason
/// is the server's own; the client never guesses which rule skipped it.
@immutable
final class MiningExcludedAsset {
  const MiningExcludedAsset({required this.assetId, required this.reasonCode});

  final String assetId;
  final String reasonCode;
}

/// The price version the settlement priced every row against.
@immutable
sealed class MiningReferencePrice {
  const MiningReferencePrice();
}

@immutable
final class MiningReferencePriceUnavailable extends MiningReferencePrice {
  const MiningReferencePriceUnavailable(this.reasonCode);

  final String reasonCode;
}

@immutable
final class MiningReferencePriceSettled extends MiningReferencePrice {
  const MiningReferencePriceSettled(this.priceVersion);

  /// A backend identifier. It stays inside 详情.
  final String priceVersion;
}

/// The per-asset composition. Both lists are empty while no settlement exists
/// under the version in force — that is a contract fact, not "this wallet
/// holds nothing" — and [source] is what says which of the two it is.
@immutable
final class MiningAssets {
  const MiningAssets({
    required this.totalPower,
    required this.included,
    required this.excluded,
    required this.source,
    required this.referencePrice,
  });

  final MiningFigure totalPower;
  final List<MiningAssetRow> included;
  final List<MiningExcludedAsset> excluded;
  final MiningSnapshotRef source;
  final MiningReferencePrice referencePrice;

  /// True while no settlement produced these lists. An empty list under a
  /// settlement is a different sentence from an empty list without one.
  bool get isUnsettled => source is MiningSnapshotUnavailable;
}

/// A display name for one asset id. The payload carries no symbol, so the row
/// says what the id itself states: a contract address in short form, or the
/// chain's own coin.
String miningAssetLabel(String assetId) {
  final separator = assetId.lastIndexOf(':');
  if (separator < 0 || separator + 1 >= assetId.length) return assetId;
  final tail = assetId.substring(separator + 1);
  if (tail != 'native') return loopTruncatedAddress(tail);
  final chainId = assetId.substring(0, separator);
  return loopKnownChainIds.contains(chainId)
      ? '${loopChainName(chainId)} 原生代币'
      : '原生代币';
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

/// True when a settled power is zero. A zero power is a reading — the account
/// was in the settlement and held nothing that counted — and it is why a row
/// carries no position at all rather than the position 0.
bool miningPowerIsZero(String value) {
  if (value.isEmpty) return false;
  for (final unit in value.codeUnits) {
    // '0' and '.'
    if (unit != 0x30 && unit != 0x2E) return false;
  }
  return true;
}

/// How one ranked account may be named. An alias reaches the board only while
/// the account is discoverable and not in anonymous mode; otherwise the row
/// carries the server's anonymous label and no identifier at all.
@immutable
sealed class MiningRankIdentity {
  const MiningRankIdentity();
}

@immutable
final class MiningRankAlias extends MiningRankIdentity {
  const MiningRankAlias({required this.alias, required this.publicProfileId});

  final String alias;
  final String publicProfileId;
}

@immutable
final class MiningRankAnonymous extends MiningRankIdentity {
  const MiningRankAnonymous(this.labelKey);

  final String labelKey;
}

/// One account on the user board.
@immutable
final class MiningRankUserRow {
  const MiningRankUserRow({
    required this.position,
    required this.power,
    required this.display,
    required this.isSelf,
  });

  /// `null` while the power is zero: the account is in the settlement and has
  /// no place on the board. It is never rendered as a position 0.
  final int? position;
  final String power;
  final MiningRankIdentity display;
  final bool isSelf;

  bool get isRanked => position != null;
}

/// One community on the community board. The reference is the same record the
/// community mining panel reads, and here the bound asset always exists: an
/// unbound community cannot be ranked.
@immutable
final class MiningRankCommunityRow {
  const MiningRankCommunityRow({
    required this.position,
    required this.power,
    required this.community,
    required this.weight,
    required this.participants,
  });

  final int? position;
  final String power;
  final MiningCommunityRef community;
  final String weight;
  final int participants;

  bool get isRanked => position != null;
}

/// The board itself. The two scopes are different rows, not one row with two
/// optional halves, so a page cannot read a community's weight off an account.
@immutable
sealed class MiningRanking {
  const MiningRanking();
}

@immutable
final class MiningRankingUnavailable extends MiningRanking {
  const MiningRankingUnavailable(this.reasonCode);

  final String reasonCode;
}

@immutable
final class MiningRankingUsers extends MiningRanking {
  const MiningRankingUsers({required this.items, required this.participants});

  final List<MiningRankUserRow> items;

  /// Accounts with a power above zero. The board may hold more rows than this
  /// — the zero-power ones — and fewer than the whole network: it stops at
  /// one hundred.
  final int participants;
}

@immutable
final class MiningRankingCommunities extends MiningRanking {
  const MiningRankingCommunities({
    required this.items,
    required this.participants,
  });

  final List<MiningRankCommunityRow> items;
  final int participants;
}

/// The reader's own place on the board.
@immutable
sealed class MiningRankPosition {
  const MiningRankPosition();
}

@immutable
final class MiningRankPositionUnavailable extends MiningRankPosition {
  const MiningRankPositionUnavailable(this.reasonCode);

  final String reasonCode;
}

@immutable
final class MiningRankPositionSettled extends MiningRankPosition {
  const MiningRankPositionSettled({
    required this.position,
    required this.power,
  });

  final int position;
  final String power;
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
  final MiningRanking ranking;
  final MiningRankPosition myPosition;
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

/// How many members the settlement counted. A count of zero is a reading —
/// every member held nothing that counted — and it is not the same fact as
/// having no count at all.
@immutable
sealed class MiningParticipants {
  const MiningParticipants();
}

@immutable
final class MiningParticipantsUnavailable extends MiningParticipants {
  const MiningParticipantsUnavailable(this.reasonCode);

  final String reasonCode;
}

@immutable
final class MiningParticipantsCount extends MiningParticipants {
  const MiningParticipantsCount(this.count);

  final int count;
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
    required this.snapshot,
  });

  final MiningCommunityRef community;
  final MiningCommunityWeight weight;
  final MiningFigure communityPower;
  final MiningFigure myContribution;

  /// The community's own place on the community board, in the same shape the
  /// board gives the reader.
  final MiningRankPosition rank;
  final MiningParticipants participants;
  final MiningSnapshotRef snapshot;
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
