import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';

/// Presentation models for the `mining` module (loop-api decision 0036).
///
/// There is no approved mining formula version in this step, so every power,
/// output, accumulation, claim, rank and boost arrives as `unavailable` with
/// the server's own `reasonCode`. Nothing here can hold a number the server
/// did not send, and no ratio, weight or emission is written into the client.

/// How the newest run under the version in force ended (Decision 0057).
///
/// A run that could not value a held asset is never published, so `complete`
/// is the only status a *published* snapshot has; the other two describe a
/// run that happened after the numbers on the page were computed.
enum MiningSnapshotAttemptStatus {
  complete('complete'),
  incomplete('incomplete'),
  invalidated('invalidated');

  const MiningSnapshotAttemptStatus(this.wireName);

  final String wireName;

  static MiningSnapshotAttemptStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// One holding the latest run could not value, with the server's own reason.
///
/// It is why that run was not published: a weighted asset with a positive
/// balance and no readable reference price would otherwise have been summed
/// as nothing (Decision 0057). The client never renames the reason.
@immutable
final class MiningUnreadInput {
  const MiningUnreadInput({required this.assetId, required this.reasonCode});

  final String assetId;
  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiningUnreadInput &&
          other.assetId == assetId &&
          other.reasonCode == reasonCode;

  @override
  int get hashCode => Object.hash(assetId, reasonCode);
}

/// The newest run under the version in force, whatever became of it.
///
/// When the page is not stale this is the very snapshot it is reading. When
/// it is stale, this is the run that happened afterwards and did not become
/// the numbers on the page, and [unreadInputs] is what stopped it.
@immutable
final class MiningSnapshotAttempt {
  const MiningSnapshotAttempt({
    required this.snapshotId,
    required this.status,
    required this.computedAt,
    required this.reasonCode,
    required this.unreadInputs,
  });

  final String snapshotId;
  final MiningSnapshotAttemptStatus status;
  final DateTime computedAt;

  /// The server's own reason. `null` on a run that completed.
  final String? reasonCode;

  /// Empty except on a run that could not value a holding.
  final List<MiningUnreadInput> unreadInputs;

  bool get isComplete => status == MiningSnapshotAttemptStatus.complete;

  bool get isInvalidated => status == MiningSnapshotAttemptStatus.invalidated;
}

/// A settled power snapshot, or the server's reason there is none.
@immutable
sealed class MiningSnapshotRef {
  const MiningSnapshotRef();
}

@immutable
final class MiningSnapshotUnavailable extends MiningSnapshotRef {
  const MiningSnapshotUnavailable(this.reasonCode, {this.latestAttempt});

  final String reasonCode;

  /// Present when the version in force has run at least once and no run of it
  /// ever completed: it says why there is nothing to show.
  final MiningSnapshotAttempt? latestAttempt;
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
    this.stale = false,
    this.latestAttempt,
    this.holdingsSource,
  });

  final String snapshotId;
  final String blockNumber;
  final String blockHash;
  final String formulaVersion;
  final String priceVersion;
  final DateTime computedAt;

  /// True when a later run under the same version did not complete, so the
  /// numbers on the page are this snapshot's and are older than that run
  /// (Decision 0057). It is never a reason to hide them: they were computed
  /// from a full set of holdings, which is exactly why the later run was not
  /// published.
  final bool stale;

  /// The newest run under the version in force. It is this snapshot itself
  /// while [stale] is false.
  final MiningSnapshotAttempt? latestAttempt;

  /// Which kinds of balance produced the numbers (decision 0061). A
  /// deployment that predates the field says nothing, and the page then
  /// claims nothing about it.
  final MiningHoldingsSource? holdingsSource;

  /// True when at least one figure counted a holding that was written for
  /// development rather than observed on chain. The page has to say so.
  bool get includesDemonstrationHoldings =>
      holdingsSource != null && holdingsSource != MiningHoldingsSource.chain;
}

/// What the balances behind a settled run were.
///
/// `chain` is the only value a production deployment can publish. The other
/// two mean the numbers are real arithmetic over holdings nobody holds, which
/// is a thing the page must state rather than hide.
enum MiningHoldingsSource {
  chain('chain'),
  mockSeed('mock_seed'),
  mixed('mixed');

  const MiningHoldingsSource(this.wireName);

  final String wireName;

  static MiningHoldingsSource? tryParse(String value) {
    for (final source in values) {
      if (source.wireName == value) return source;
    }
    return null;
  }
}

/// True when the snapshot a page is printing counted demonstration holdings.
bool miningSnapshotIncludesDemonstrationHoldings(MiningSnapshotRef? snapshot) =>
    snapshot is MiningSnapshotComputed &&
    snapshot.includesDemonstrationHoldings;

/// Whether the numbers a page is printing came from a snapshot that a later
/// run has already overtaken without completing.
bool miningSnapshotIsStale(MiningSnapshotRef? snapshot) =>
    snapshot is MiningSnapshotComputed && snapshot.stale;

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

/// Whether the version in force declares itself the development baseline.
///
/// It is the only thing that may put the baseline label on a figure: the
/// version string is an identifier and is never read for meaning.
bool miningGateIsBaseline(MiningFormulaGate gate) => switch (gate) {
  MiningFormulaEffective(:final scope) => scope.isBaseline,
  MiningFormulaPending() => false,
};

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
  proxied('proxied'),
  derived('derived');

  const MiningReferencePriceQuality(this.wireName);

  final String wireName;

  static MiningReferencePriceQuality? tryParse(String value) {
    for (final quality in values) {
      if (quality.wireName == value) return quality;
    }
    return null;
  }

  bool get isProxied => this == MiningReferencePriceQuality.proxied;

  /// The asset was the quote token of the pair its price was read from, so
  /// the price is that pair divided out and checked against the band the
  /// version declared (Decision 0059). It is an observation, not an estimate,
  /// and the row says which pool it came from.
  bool get isDerived => this == MiningReferencePriceQuality.derived;
}

/// One asset the settlement weighted. Every figure is the server's own decimal
/// string; the client multiplies nothing, because the row that reached it was
/// already settled at one block.
@immutable
final class MiningAssetRow {
  const MiningAssetRow({
    required this.assetId,
    required this.symbol,
    required this.holding,
    required this.referencePriceUsd,
    required this.referencePriceQuality,
    required this.referencePriceProxyAssetId,
    required this.weight,
    required this.power,
    required this.blockNumber,
    this.referencePricePairAddress,
    this.logoUrl,
  });

  final String assetId;

  /// The registry's published artwork, or `null` when none was published
  /// (decision 0072). Never an identity — `assetId` alone keys the row.
  final String? logoUrl;

  /// The Asset Registry's own `symbol()` for [assetId], `BNB` for the chain's
  /// coin. It is `null` only when the registry has no row for the asset; the
  /// client never derives a name from an address or a chain slot.
  final String? symbol;

  final String holding;
  final String referencePriceUsd;
  final MiningReferencePriceQuality referencePriceQuality;

  /// The asset whose price was used. Non-null exactly when the quality is
  /// `proxied`: a proxied price with no proxy, or a fresh price carrying one,
  /// would leave the row unable to say where its price came from.
  final String? referencePriceProxyAssetId;

  /// The pool the price was read from. Non-null on a derived price, which is
  /// that pool divided out; it may also be present on a direct reading the
  /// version pinned to one pair, and is absent everywhere else.
  final String? referencePricePairAddress;

  /// The effective weight already in the power: the formula's asset weight
  /// times the approved community weight, when one community binds the asset.
  final String weight;
  final String power;
  final String blockNumber;

  bool get isProxiedPrice => referencePriceQuality.isProxied;

  bool get isDerivedPrice => referencePriceQuality.isDerived;
}

/// One asset the account holds that the settlement did not weight. The reason
/// is the server's own; the client never guesses which rule skipped it.
@immutable
final class MiningExcludedAsset {
  const MiningExcludedAsset({
    required this.assetId,
    required this.symbol,
    required this.reasonCode,
    this.logoUrl,
  });

  final String assetId;

  /// The registry's own symbol, on the same terms as an included row.
  final String? symbol;

  /// The registry's published artwork, or `null` (decision 0072).
  final String? logoUrl;

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
    required this.formula,
  });

  final MiningFigure totalPower;
  final List<MiningAssetRow> included;
  final List<MiningExcludedAsset> excluded;
  final MiningSnapshotRef source;
  final MiningReferencePrice referencePrice;

  /// The version in force, in the same block the summary reads. The page
  /// stamps its own figures from this and never reads the version string for
  /// meaning.
  final MiningFormulaGate formula;

  /// True while no settlement produced these lists. An empty list under a
  /// settlement is a different sentence from an empty list without one.
  bool get isUnsettled => source is MiningSnapshotUnavailable;
}

/// A display name for one asset id when no symbol reached the client: the row
/// says what the id itself states — a contract address in short form, or the
/// chain's own coin. It is a fallback, never a guessed name.
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

/// The pool one derived price was read from, in short form. The full address
/// is the identity and stays in the model; the row only has to let a reader
/// recognise it.
String miningPricePoolLabel(String pairAddress) =>
    loopTruncatedAddress(pairAddress);

/// The heading for one asset row. A registry symbol is the row's name; without
/// one the id itself is all the row may say, and it says that instead of
/// inventing a token name from the address.
String miningAssetTitle({required String? symbol, required String assetId}) =>
    symbol ?? miningAssetLabel(assetId);

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

  /// The same block the summary reads: a figure under an effective version,
  /// the server's own reason without one.
  final MiningDailyOutput estimatedToday;
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

/// The two independent rules a ranking row is displayed under (decision 0049):
/// [ruleKey] states that anonymous mode alone decides whether other readers see
/// an alias or the anonymous member label, and [powerRuleKey] that the owner's
/// mining power visibility alone decides whether the power number is published.
/// Being discoverable decides nothing here. All three are server-owned keys.
@immutable
final class MiningRankDisplayRule {
  const MiningRankDisplayRule({
    required this.anonymousMemberKey,
    required this.ruleKey,
    required this.powerRuleKey,
  });

  final String anonymousMemberKey;
  final String ruleKey;
  final String powerRuleKey;
}

/// Who a fact on a ranking row is published to. It is the row owner's own
/// setting, reported verbatim, never a decision this client makes.
enum MiningRankAudience {
  everyone('everyone'),
  self('self');

  const MiningRankAudience(this.wireName);

  final String wireName;

  static MiningRankAudience? tryParse(String value) {
    for (final audience in values) {
      if (audience.wireName == value) return audience;
    }
    return null;
  }
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

/// How one ranked account may be named. Another reader's row carries the alias
/// only while that account has anonymous mode off; otherwise it carries the
/// server's anonymous label and no identifier at all. The reader's own row is
/// always the alias — nobody is anonymous to themselves — and its [audience]
/// says whether everyone else sees that alias too.
@immutable
sealed class MiningRankIdentity {
  const MiningRankIdentity();
}

@immutable
final class MiningRankAlias extends MiningRankIdentity {
  const MiningRankAlias({
    required this.alias,
    required this.publicProfileId,
    required this.audience,
  });

  final String alias;
  final String publicProfileId;

  /// [MiningRankAudience.self] only on the reader's own row while anonymous
  /// mode is on: the reader sees the alias, every other reader sees the
  /// anonymous label.
  final MiningRankAudience audience;
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
    required this.powerVisibility,
    required this.display,
    required this.isSelf,
  });

  /// `null` while the power is zero: the account is in the settlement and has
  /// no place on the board. It is never rendered as a position 0. The position
  /// is public whatever the owner's visibility setting says.
  final int? position;

  /// `null` when the row belongs to somebody who publishes their power to
  /// themselves only. It is a withheld number, not a number this client failed
  /// to read, and the row says so.
  final String? power;

  /// The row owner's mining power visibility, published verbatim.
  final MiningRankAudience powerVisibility;
  final MiningRankIdentity display;
  final bool isSelf;

  bool get isRanked => position != null;

  /// The owner keeps the number to themselves and this reader is not them.
  bool get isPowerWithheld => power == null;
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
    required this.formula,
  });

  final MiningRankScope scope;
  final MiningRanking ranking;
  final MiningRankPosition myPosition;
  final MiningSnapshotRef snapshot;
  final MiningRankDisplayRule display;

  /// The version in force, in the same block the summary reads. The board's
  /// places were produced under it, so the page says which version it is.
  final MiningFormulaGate formula;
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

/// Why a community has no approved weight.
///
/// The two values are not the same sentence: a bound community is waiting for
/// a review, and an unbound one has nothing to review at all (Decision 0046).
/// A page that says 「权重审核中」 to a community that never bound an asset is
/// promising a review nobody is performing.
enum MiningWeightReviewStatus {
  pendingReview('pending_review'),
  notApplicable('not_applicable');

  const MiningWeightReviewStatus(this.wireName);

  final String wireName;

  static MiningWeightReviewStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }

  bool get isPendingReview => this == MiningWeightReviewStatus.pendingReview;
}

@immutable
final class MiningCommunityWeightPending extends MiningCommunityWeight {
  const MiningCommunityWeightPending({
    required this.reasonCode,
    required this.reviewStatus,
  });

  final String reasonCode;
  final MiningWeightReviewStatus reviewStatus;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiningCommunityWeightPending &&
          other.reasonCode == reasonCode &&
          other.reviewStatus == reviewStatus;

  @override
  int get hashCode => Object.hash(reasonCode, reviewStatus);
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

/// The inclusive bounds a reviewed weight must satisfy under one version.
/// Both ends are the server's own decimal strings, printed verbatim.
@immutable
final class MiningWeightBounds {
  const MiningWeightBounds({required this.min, required this.max});

  final String min;
  final String max;
}

/// A weight band: its key, its approval state, and — only once the version
/// pinned it — the numeric range itself. `range` stays null while the band is
/// still a rule with no numbers, and the page keeps the em dash for it.
@immutable
final class MiningWeightBand {
  const MiningWeightBand({
    required this.status,
    required this.descriptionKey,
    this.range,
  });

  final MiningFormulaStatus status;
  final String descriptionKey;
  final MiningWeightBounds? range;
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

/// The daily output one formula version declares. While the reward token is
/// undecided the budget is a `development_placeholder`, and the page must say
/// so beside it rather than print the number on its own.
@immutable
final class MiningFormulaDailyOutput {
  const MiningFormulaDailyOutput({
    required this.status,
    required this.budget,
    required this.unitKey,
  });

  final String status;
  final String budget;
  final String unitKey;

  bool get isPlaceholder => status == 'development_placeholder';
}

@immutable
final class MiningFormulaVersion {
  const MiningFormulaVersion({
    required this.configVersion,
    required this.status,
    required this.scope,
    required this.effectiveAt,
    required this.approvedAt,
    required this.expressionKey,
    required this.dailyOutputKey,
    required this.assetWeights,
    required this.dailyOutput,
    required this.weightRange,
    required this.priceGuardRules,
    required this.referralBoostStatus,
  });

  final String configVersion;
  final MiningFormulaStatus status;

  /// What the version says it is. `developmentBaseline` publishes numbers
  /// that are not a product measure, and every figure it produced carries
  /// the baseline label.
  final MiningFormulaScope scope;
  final DateTime? effectiveAt;
  final DateTime? approvedAt;
  final String expressionKey;
  final String dailyOutputKey;

  /// Canonical asset id → the version's own decimal weight. Empty on a
  /// product draft, which publishes rule keys and no numbers.
  final Map<String, String> assetWeights;

  /// Null while the version declares no budget at all.
  final MiningFormulaDailyOutput? dailyOutput;
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

  /// Null while no version has been approved.
  final MiningFormulaVersion? approved;
  final List<MiningFormulaVersion> pendingApproval;

  /// The version in force, as the same block the summary, the composition
  /// page and the ranking read. Approved on the development baseline;
  /// pending while nothing is in effect.
  final MiningFormulaGate baseline;
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
  'mining.rules.reviewFactor.communityScale' ||
  'mining.rules.reviewFactor.communitySize' => '社区规模',
  'mining.rules.reviewFactor.tokenLiquidity' => 'Token 流动性',
  'mining.rules.reviewFactor.projectQuality' => '项目质量',
  'mining.rules.reviewFactor.marketStability' => '市场稳定性',
  'mining.rules.reviewFactor.userQuality' => '用户质量',
  'mining.rules.reviewFactor.partnershipDepth' ||
  'mining.rules.reviewFactor.loopPartnership' => '与 LOOP 的合作深度',
  'mining.rules.priceGuard.twap' => 'TWAP 时间加权均价：避免单笔成交扭曲参考价。',
  'mining.rules.priceGuard.multiPeriodMultiSource' => '多周期、多渠道比对，交叉验证异常波动。',
  'mining.rules.priceGuard.liquidityCap' => 'Liquidity Cap：低流动性资产限制可计入价值。',
  'mining.rank.anonymousMember' => '匿名成员',
  'mining.rank.display.anonymousModeOnly' =>
    '别人看到的是别名还是「匿名成员」，只由该账号的匿名模式决定；「显示 LOOP ID」不参与，自己永远看得到自己的别名。',
  'mining.rank.power.ownerVisibility' =>
    '算力数值按该账号自己的「挖矿算力」可见范围显示；设为仅自己时别人看不到数值，名次与参与条目数仍然公开。',
  _ => 'LOOP 定义的规则项。',
};
