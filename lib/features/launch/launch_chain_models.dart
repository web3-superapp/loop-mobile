import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// The `available` branches loop-api decision 0076 (S83a) added beside every
/// on-chain Launch slot. Decision 0088 records how the client reads them.
///
/// Every amount stays the server's decimal integer string in the smallest
/// unit (06 §3: USD1 and project tokens both have 18 decimals). Only the
/// display helpers at the bottom of this file shift it into a readable
/// figure, and they never round-trip it back into a request.

// ---------------------------------------------------------------------------
// the four axes (06 §2)
// ---------------------------------------------------------------------------

enum LaunchSaleState {
  scheduled('SCHEDULED'),
  live('LIVE'),
  ended('ENDED'),
  succeeded('SUCCEEDED'),
  failed('FAILED'),
  cancelled('CANCELLED');

  const LaunchSaleState(this.wireName);

  final String wireName;
  String get meaning => switch (this) {
    LaunchSaleState.scheduled => LoopL10n.current.launch_chainModelsScheduled,
    LaunchSaleState.live => LoopL10n.current.launch_chainModelsLive,
    LaunchSaleState.ended => LoopL10n.current.launch_chainModelsEnded,
    LaunchSaleState.succeeded => LoopL10n.current.launch_chainModelsSucceeded,
    LaunchSaleState.failed => LoopL10n.current.launch_chainModelsFailed,
    LaunchSaleState.cancelled => LoopL10n.current.launch_chainModelsCancelled,
  };

  static LaunchSaleState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

enum LaunchEntitlementState {
  none('NONE'),
  frozen('FROZEN'),
  vesting('VESTING'),
  completed('COMPLETED'),
  refunding('REFUNDING'),
  refunded('REFUNDED');

  const LaunchEntitlementState(this.wireName);

  final String wireName;
  String get meaning => switch (this) {
    LaunchEntitlementState.none => LoopL10n.current.launch_chainModelsNone,
    LaunchEntitlementState.frozen => LoopL10n.current.launch_chainModelsFrozen,
    LaunchEntitlementState.vesting =>
      LoopL10n.current.launch_chainModelsVesting,
    LaunchEntitlementState.completed =>
      LoopL10n.current.launch_chainModelsCompleted,
    LaunchEntitlementState.refunding =>
      LoopL10n.current.launch_chainModelsRefunding,
    LaunchEntitlementState.refunded =>
      LoopL10n.current.launch_chainModelsRefunded,
  };

  bool get isRefundBranch =>
      this == LaunchEntitlementState.refunding ||
      this == LaunchEntitlementState.refunded;

  static LaunchEntitlementState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

enum LaunchLiquidityState {
  notStarted('NOT_STARTED'),
  preparing('PREPARING'),
  v3Live('V3_LIVE'),
  lpLocked('LP_LOCKED'),
  completed('COMPLETED'),
  retryScheduled('RETRY_SCHEDULED');

  const LaunchLiquidityState(this.wireName);

  final String wireName;
  String get meaning => switch (this) {
    LaunchLiquidityState.notStarted =>
      LoopL10n.current.launch_chainModelsNotStarted,
    LaunchLiquidityState.preparing =>
      LoopL10n.current.launch_chainModelsPreparing,
    LaunchLiquidityState.v3Live => LoopL10n.current.launch_chainModelsV3Live,
    LaunchLiquidityState.lpLocked =>
      LoopL10n.current.launch_chainModelsLpLocked,
    LaunchLiquidityState.completed =>
      LoopL10n.current.launch_chainModelsCompleted2,
    LaunchLiquidityState.retryScheduled =>
      LoopL10n.current.launch_chainModelsRetryScheduled,
  };

  /// Only these two carry the locked-liquidity evidence 03 §8.3 requires
  /// before anything may say "已毕业".
  bool get isLocked =>
      this == LaunchLiquidityState.lpLocked ||
      this == LaunchLiquidityState.completed;

  static LaunchLiquidityState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

enum LaunchOperationalState {
  active('ACTIVE'),
  paused('PAUSED');

  const LaunchOperationalState(this.wireName);

  final String wireName;
  String get meaning => switch (this) {
    LaunchOperationalState.active => LoopL10n.current.launch_chainModelsActive,
    LaunchOperationalState.paused => LoopL10n.current.launch_chainModelsPaused,
  };

  static LaunchOperationalState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

/// `launch.onChainState`, discriminated by `source`.
@immutable
sealed class LaunchOnChainState {
  const LaunchOnChainState();

  /// The server's reason while the axes cannot be read; `null` on chain.
  String? get reasonCode;

  bool get isProvable;

  /// A purchase is admissible only while a round is live and the sale is not
  /// paused. Any other combination — including an unreadable one — is not.
  bool get isPurchasable;
}

/// `source: unavailable`: the pre-S83a object, byte for byte.
final class LaunchOnChainUnavailable extends LaunchOnChainState {
  const LaunchOnChainUnavailable(this.reasonCode);

  @override
  final String reasonCode;

  @override
  bool get isProvable => false;

  @override
  bool get isPurchasable => false;
}

/// `source: chain`: the four axes read at one block.
final class LaunchOnChainAvailable extends LaunchOnChainState {
  const LaunchOnChainAvailable({
    required this.saleState,
    required this.entitlementState,
    required this.liquidityState,
    required this.operationalState,
    required this.stateTupleDigest,
    required this.snapshotBlockNumber,
    required this.snapshotBlockHash,
    required this.configVersion,
  });

  final LaunchSaleState saleState;
  final LaunchEntitlementState entitlementState;
  final LaunchLiquidityState liquidityState;
  final LaunchOperationalState operationalState;

  /// The contract's own digest, never recomputed on the device.
  final String stateTupleDigest;
  final String snapshotBlockNumber;
  final String snapshotBlockHash;
  final String configVersion;

  @override
  String? get reasonCode => null;

  @override
  bool get isProvable => true;

  @override
  bool get isPurchasable =>
      saleState == LaunchSaleState.live &&
      operationalState == LaunchOperationalState.active;

  /// The four axes in the fixed order every page renders them.
  List<LaunchAxisReading> get axes => <LaunchAxisReading>[
    LaunchAxisReading(
      LoopL10n.current.launch_chainModelsLaunchAxisReading,
      saleState.wireName,
      saleState.meaning,
    ),
    LaunchAxisReading(
      LoopL10n.current.launch_chainModelsLaunchAxisReading2,
      entitlementState.wireName,
      entitlementState.meaning,
    ),
    LaunchAxisReading(
      LoopL10n.current.launch_chainModelsLaunchAxisReading3,
      liquidityState.wireName,
      liquidityState.meaning,
    ),
    LaunchAxisReading(
      LoopL10n.current.launch_chainModelsLaunchAxisReading4,
      operationalState.wireName,
      operationalState.meaning,
    ),
  ];
}

@immutable
final class LaunchAxisReading {
  const LaunchAxisReading(this.label, this.wireName, this.meaning);

  final String label;
  final String wireName;
  final String meaning;
}

/// The axis labels the unavailable block keeps, in the same order.
List<String> get launchAxisLabels => <String>[
  LoopL10n.current.launch_chainModelsLaunchAxisReading,
  LoopL10n.current.launch_chainModelsLaunchAxisReading2,
  LoopL10n.current.launch_chainModelsLaunchAxisReading3,
  LoopL10n.current.launch_chainModelsLaunchAxisReading4,
];

/// Stable ids for the four axes, in the same order (keys, not copy).
const List<String> launchAxisIds = <String>[
  'sale',
  'entitlement',
  'liquidity',
  'operational',
];

/// Stable ids for [LaunchSaleConfig.entries], in the same order.
const List<String> launchSaleConfigIds = <String>[
  'soft-cap',
  'hard-cap',
  'wallet-project-cap',
  'min-purchase',
  'protocol-fee',
  'liquidity',
  'tge',
  'cliff',
  'vesting',
  'pool-fee-tier',
  'lp-lock',
  'project-token',
  'usd1',
];

/// The read-only combined projection 03 §8.3 allows: one sentence composed
/// from the four axes and nothing else. It never introduces a fifth state,
/// and a pause is always stated on its own.
String launchStateProjection(LaunchOnChainAvailable state) {
  final String body;
  switch (state.saleState) {
    case LaunchSaleState.scheduled:
      body = LoopL10n.current.launch_chainModelsScheduled;
    case LaunchSaleState.live:
      body = LoopL10n.current.launch_chainModelsBody;
    case LaunchSaleState.ended:
      body = LoopL10n.current.launch_chainModelsBody2;
    case LaunchSaleState.succeeded:
      final liquidity = switch (state.liquidityState) {
        LaunchLiquidityState.notStarted =>
          LoopL10n.current.launch_chainModelsNotStarted2,
        LaunchLiquidityState.preparing =>
          LoopL10n.current.launch_chainModelsPreparing2,
        LaunchLiquidityState.retryScheduled =>
          LoopL10n.current.launch_chainModelsRetryScheduled2,
        // V3_LIVE is not a lock: 03 §8.3 forbids calling it graduated.
        LaunchLiquidityState.v3Live =>
          LoopL10n.current.launch_chainModelsV3Live2,
        LaunchLiquidityState.lpLocked =>
          LoopL10n.current.launch_chainModelsLpLocked2,
        LaunchLiquidityState.completed =>
          LoopL10n.current.launch_chainModelsCompleted3,
      };
      final entitlement = switch (state.entitlementState) {
        LaunchEntitlementState.vesting =>
          LoopL10n.current.launch_chainModelsVesting2,
        LaunchEntitlementState.completed =>
          LoopL10n.current.launch_chainModelsCompleted4,
        _ => '',
      };
      body = '$liquidity$entitlement';
    case LaunchSaleState.failed:
      body = switch (state.entitlementState) {
        LaunchEntitlementState.refunding =>
          LoopL10n.current.launch_chainModelsRefunding2,
        LaunchEntitlementState.refunded =>
          LoopL10n.current.launch_chainModelsRefunded2,
        _ => LoopL10n.current.launch_chainModelsSwitch,
      };
    case LaunchSaleState.cancelled:
      body = switch (state.entitlementState) {
        LaunchEntitlementState.refunding =>
          LoopL10n.current.launch_chainModelsRefunding3,
        LaunchEntitlementState.refunded =>
          LoopL10n.current.launch_chainModelsRefunded3,
        _ => LoopL10n.current.common_cancelled,
      };
  }
  return state.operationalState == LaunchOperationalState.paused
      ? LoopL10n.current.launch_chainModelsSwitch2(body)
      : body;
}

/// "毕业中 / 已毕业" as the read-only projection 03 §8.3 describes, or `null`
/// when neither applies.
String? launchGraduationProjection(LaunchOnChainAvailable state) {
  if (state.liquidityState.isLocked) return LoopL10n.current.common_graduated;
  if (state.saleState == LaunchSaleState.succeeded &&
      state.liquidityState != LaunchLiquidityState.notStarted) {
    return LoopL10n.current.launch_chainModelsIf;
  }
  return null;
}

// ---------------------------------------------------------------------------
// graduation rail
// ---------------------------------------------------------------------------

enum LaunchGraduationProgress {
  pending(),
  active(),
  retrying(),
  done(),
  notApplicable();

  const LaunchGraduationProgress();

  String get label => switch (this) {
    LaunchGraduationProgress.pending =>
      LoopL10n.current.launch_chainModelsPending,

    LaunchGraduationProgress.active => LoopL10n.current.common_inProgress,

    LaunchGraduationProgress.retrying =>
      LoopL10n.current.launch_chainModelsRetrying,

    LaunchGraduationProgress.done => LoopL10n.current.launch_chainModelsDone,

    LaunchGraduationProgress.notApplicable =>
      LoopL10n.current.launch_chainModelsNotApplicable,
  };
}

// ---------------------------------------------------------------------------
// sale configuration and rounds (`getSaleConfig`, `getRounds`)
// ---------------------------------------------------------------------------

@immutable
final class LaunchSaleConfig {
  const LaunchSaleConfig({
    required this.projectToken,
    required this.usd1,
    required this.softCapUsd1,
    required this.hardCapUsd1,
    required this.walletProjectCapUsd1,
    required this.minPurchaseUsd1,
    required this.protocolFeeBps,
    required this.liquidityBps,
    required this.tgeBps,
    required this.cliffSeconds,
    required this.vestingSeconds,
    required this.poolFeeTier,
    required this.lpLockSeconds,
    required this.configVersion,
  });

  final String projectToken;
  final String usd1;
  final String softCapUsd1;
  final String hardCapUsd1;
  final String walletProjectCapUsd1;
  final String minPurchaseUsd1;
  final int protocolFeeBps;
  final int liquidityBps;
  final int tgeBps;
  final int cliffSeconds;
  final int vestingSeconds;
  final int poolFeeTier;
  final int lpLockSeconds;
  final String configVersion;

  /// `(label, value)` in the order the rules page renders them; the ids
  /// for their keys are [launchSaleConfigIds].
  List<(String, String)> get entries => <(String, String)>[
    (LoopL10n.current.launch_chainModelsEntries, launchUsd1Label(softCapUsd1)),
    (LoopL10n.current.launch_chainModelsEntries2, launchUsd1Label(hardCapUsd1)),
    (
      LoopL10n.current.launch_chainModelsEntries3,
      launchUsd1Label(walletProjectCapUsd1),
    ),
    (
      LoopL10n.current.launch_chainModelsEntries4,
      launchUsd1Label(minPurchaseUsd1),
    ),
    (
      LoopL10n.current.launch_chainModelsEntries5,
      launchBpsLabel(protocolFeeBps),
    ),
    (LoopL10n.current.launch_chainModelsEntries6, launchBpsLabel(liquidityBps)),
    (LoopL10n.current.launch_chainModelsEntries7, launchBpsLabel(tgeBps)),
    ('Cliff', launchDurationLabel(cliffSeconds)),
    ('Vesting', launchDurationLabel(vestingSeconds)),
    (
      LoopL10n.current.launch_chainModelsEntries8,
      launchPoolFeeTierLabel(poolFeeTier),
    ),
    (
      LoopL10n.current.launch_chainModelsEntries9,
      launchDurationLabel(lpLockSeconds),
    ),
    (
      LoopL10n.current.launch_chainModelsEntries10,
      launchShortHex(projectToken),
    ),
    (LoopL10n.current.launch_chainModelsEntries11, launchShortHex(usd1)),
  ];
}

@immutable
final class LaunchChainRound {
  const LaunchChainRound({
    required this.roundId,
    required this.roundIndex,
    required this.startAt,
    required this.endAt,
    required this.priceUsd1PerToken,
    required this.roundCapUsd1,
    required this.walletRoundCapUsd1,
    required this.allowlistRoot,
    required this.raisedUsd1,
  });

  static final String zeroRoot = '0x${'0' * 64}';

  /// LOOP's opaque round ID; `null` when LOOP has no row for this index. Such
  /// a round is shown but cannot be bought, because the intent names it.
  final String? roundId;

  /// The contract's `roundId` (uint16).
  final int roundIndex;
  final DateTime startAt;
  final DateTime endAt;
  final String priceUsd1PerToken;
  final String roundCapUsd1;
  final String walletRoundCapUsd1;
  final String allowlistRoot;
  final String raisedUsd1;

  bool get hasAllowlist => allowlistRoot != zeroRoot;

  bool isOpenAt(DateTime now) => !now.isBefore(startAt) && now.isBefore(endAt);
}

// ---------------------------------------------------------------------------
// eligibility
// ---------------------------------------------------------------------------

/// Eligibility `result`, discriminated by the presence of `status`.
@immutable
sealed class LaunchEligibilityResult {
  const LaunchEligibilityResult();
}

/// The unchanged decision-0036 object: no evaluator exists.
final class LaunchEligibilityPending extends LaunchEligibilityResult {
  const LaunchEligibilityPending(this.reasonCode);

  final String reasonCode;
}

/// `status: available` (S83b evaluators).
final class LaunchEligibilityEvaluated extends LaunchEligibilityResult {
  const LaunchEligibilityEvaluated({
    required this.tierWireName,
    required this.reasonCode,
    required this.snapshotBlock,
    required this.roundIndex,
    required this.allowlistRoot,
    required this.eligibilityProof,
  });

  /// `priority` / `community` / `public`, or `null` when the wallet is not in
  /// the allowlist.
  final String? tierWireName;
  final String? reasonCode;
  final String snapshotBlock;
  final int roundIndex;
  final String allowlistRoot;
  final List<String> eligibilityProof;

  bool get rootIsZero => allowlistRoot == LaunchChainRound.zeroRoot;
}

// ---------------------------------------------------------------------------
// holders
// ---------------------------------------------------------------------------

/// A fact that is either the server's `{status: unavailable, reasonCode}` or
/// its `available` value.
@immutable
sealed class LaunchReading<T> {
  const LaunchReading();

  String? get reasonCode;
}

final class LaunchReadingUnavailable<T> extends LaunchReading<T> {
  const LaunchReadingUnavailable(this.fact);

  final LaunchUnavailable fact;

  @override
  String get reasonCode => fact.reasonCode;
}

final class LaunchReadingAvailable<T> extends LaunchReading<T> {
  const LaunchReadingAvailable(this.value);

  final T value;

  @override
  String? get reasonCode => null;
}

@immutable
final class LaunchHolderCount {
  const LaunchHolderCount({
    required this.holderCount,
    required this.indexedBlockNumber,
  });

  final int holderCount;
  final String indexedBlockNumber;
}

/// 06 `Position` at one block.
@immutable
final class LaunchPosition {
  const LaunchPosition({
    required this.walletId,
    required this.cumulativeUsd1,
    required this.purchasedTokens,
    required this.entitledTokens,
    required this.claimableTokens,
    required this.claimedTokens,
    required this.refundableUsd1,
    required this.refundedUsd1,
    required this.snapshotBlockNumber,
    required this.snapshotBlockHash,
  });

  final String walletId;
  final String cumulativeUsd1;
  final String purchasedTokens;
  final String entitledTokens;
  final String claimableTokens;
  final String claimedTokens;
  final String refundableUsd1;
  final String refundedUsd1;
  final String snapshotBlockNumber;
  final String snapshotBlockHash;
}

@immutable
final class LaunchWalletRoundCap {
  const LaunchWalletRoundCap({
    required this.roundIndex,
    required this.walletRoundCapUsd1,
    required this.cumulativeUsd1,
  });

  final int roundIndex;
  final String walletRoundCapUsd1;
  final String cumulativeUsd1;
}

@immutable
final class LaunchWalletCap {
  const LaunchWalletCap({
    required this.walletProjectCapUsd1,
    required this.rounds,
    required this.snapshotBlockNumber,
    required this.snapshotBlockHash,
  });

  final String walletProjectCapUsd1;
  final List<LaunchWalletRoundCap> rounds;
  final String snapshotBlockNumber;
  final String snapshotBlockHash;
}

// ---------------------------------------------------------------------------
// history
// ---------------------------------------------------------------------------

@immutable
final class LaunchIndexedSource {
  const LaunchIndexedSource({
    required this.indexedBlockNumber,
    required this.indexedBlockHash,
  });

  final String indexedBlockNumber;
  final String indexedBlockHash;
}

enum LaunchConfirmationState {
  pending('pending'),
  confirmed('confirmed'),
  reorged('reorged');

  const LaunchConfirmationState(this.wireName);

  final String wireName;
  String get label => switch (this) {
    LaunchConfirmationState.pending =>
      LoopL10n.current.common_pendingConfirmation,
    LaunchConfirmationState.confirmed => LoopL10n.current.common_confirmed,
    LaunchConfirmationState.reorged =>
      LoopL10n.current.launch_chainModelsReorged,
  };

  static LaunchConfirmationState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

@immutable
final class LaunchPurchaseRecord {
  const LaunchPurchaseRecord({
    required this.purchaseRecordId,
    required this.walletId,
    required this.roundId,
    required this.roundIndex,
    required this.usd1Amount,
    required this.tokenAmount,
    required this.transactionHash,
    required this.logIndex,
    required this.blockNumber,
    required this.blockHash,
    required this.confirmationState,
    required this.observedAt,
  });

  final String purchaseRecordId;
  final String walletId;
  final String? roundId;
  final int roundIndex;
  final String usd1Amount;
  final String tokenAmount;
  final String transactionHash;
  final int logIndex;
  final String blockNumber;
  final String blockHash;
  final LaunchConfirmationState confirmationState;
  final DateTime observedAt;
}

enum LaunchEntitlementRecordState {
  frozen('frozen'),
  partiallyClaimed('partially_claimed'),
  claimed('claimed');

  const LaunchEntitlementRecordState(this.wireName);

  final String wireName;
  String get label => switch (this) {
    LaunchEntitlementRecordState.frozen =>
      LoopL10n.current.launch_chainModelsFrozen2,
    LaunchEntitlementRecordState.partiallyClaimed =>
      LoopL10n.current.launch_chainModelsPartiallyClaimed,
    LaunchEntitlementRecordState.claimed =>
      LoopL10n.current.launch_chainModelsClaimed,
  };

  static LaunchEntitlementRecordState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

@immutable
final class LaunchEntitlementRecord {
  const LaunchEntitlementRecord({
    required this.entitlementId,
    required this.walletId,
    required this.entitledTokens,
    required this.claimedTokens,
    required this.state,
    required this.frozenAtBlock,
  });

  final String entitlementId;
  final String walletId;
  final String entitledTokens;
  final String claimedTokens;
  final LaunchEntitlementRecordState state;
  final String? frozenAtBlock;
}

enum LaunchRefundRecordState {
  frozen('frozen'),
  partiallyRefunded('partially_refunded'),
  refunded('refunded');

  const LaunchRefundRecordState(this.wireName);

  final String wireName;
  String get label => switch (this) {
    LaunchRefundRecordState.frozen =>
      LoopL10n.current.launch_chainModelsFrozen2,
    LaunchRefundRecordState.partiallyRefunded =>
      LoopL10n.current.launch_chainModelsPartiallyRefunded,
    LaunchRefundRecordState.refunded =>
      LoopL10n.current.launch_chainModelsRefunded4,
  };

  static LaunchRefundRecordState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

@immutable
final class LaunchRefundRecord {
  const LaunchRefundRecord({
    required this.refundLiabilityId,
    required this.walletId,
    required this.refundableUsd1,
    required this.refundedUsd1,
    required this.state,
    required this.frozenAtBlock,
  });

  final String refundLiabilityId;
  final String walletId;
  final String refundableUsd1;
  final String refundedUsd1;
  final LaunchRefundRecordState state;
  final String? frozenAtBlock;
}

/// `settlements[].kind` (loop-api decision 0087): one `Claimed` or one
/// `Refunded` log of the caller's wallet.
enum LaunchSettlementKind {
  claimed('claimed'),
  refunded('refunded');

  const LaunchSettlementKind(this.wireName);

  final String wireName;
  String get label => switch (this) {
    LaunchSettlementKind.claimed => LoopL10n.current.launch_chainModelsClaimed2,
    LaunchSettlementKind.refunded =>
      LoopL10n.current.launch_chainModelsRefunded5,
  };

  static LaunchSettlementKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// One `Claimed` / `Refunded` log (history `settlements[]`, decision 0087).
///
/// [amount] is in the base unit of [assetId]: the project token for a claim,
/// USD1 for a refund. [cumulativeAmount] is the wallet's running total after
/// this log.
@immutable
final class LaunchSettlementRecord {
  const LaunchSettlementRecord({
    required this.settlementRecordId,
    required this.kind,
    required this.walletId,
    required this.assetId,
    required this.amount,
    required this.cumulativeAmount,
    required this.transactionHash,
    required this.logIndex,
    required this.blockNumber,
    required this.blockHash,
    required this.confirmationState,
    required this.observedAt,
  });

  final String settlementRecordId;
  final LaunchSettlementKind kind;
  final String walletId;
  final String assetId;
  final String amount;
  final String cumulativeAmount;
  final String transactionHash;
  final int logIndex;
  final String blockNumber;
  final String blockHash;
  final LaunchConfirmationState confirmationState;
  final DateTime observedAt;
}

// ---------------------------------------------------------------------------
// launch intent (`POST …/intents` → 201): buy, claim, claimRefund
// ---------------------------------------------------------------------------

/// `launchIntent.kind` (loop-api decision 0087). The key is absent on a
/// purchase, so a missing `kind` is [buy]; the two others call
/// `claim(saleId)` / `claimRefund(saleId)` on the same contract.
enum LaunchIntentKind {
  buy('buy', '0x'),
  claim('claim', '0x379607f5'),
  claimRefund('claimRefund', '0x5b7baf64');

  const LaunchIntentKind(this.wireName, this.selector);

  final String wireName;

  /// The 4-byte function selector the calldata must start with. A purchase
  /// is not pinned here (its calldata carries six arguments).
  final String selector;

  bool get isSettlement => this != LaunchIntentKind.buy;

  static LaunchIntentKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

enum LaunchIntentState {
  prepared('prepared'),
  awaitingSignature('awaiting_signature'),
  // The server moved it here on the device's broadcast report: pending
  // evidence, never a purchase.
  submitted('submitted'),
  // The launch-event index saw the `Purchased` log of that transaction.
  confirmed('confirmed'),
  reverted('reverted'),
  failed('failed'),
  unknown('unknown'),
  cancelled('cancelled'),
  expired('expired');

  const LaunchIntentState(this.wireName);

  final String wireName;

  /// zh-CN, as the server states it. Only [confirmed] names a result.
  String get label => switch (this) {
    LaunchIntentState.prepared => LoopL10n.current.common_pendingConfirmation,
    LaunchIntentState.awaitingSignature =>
      LoopL10n.current.common_awaitingSignature,
    LaunchIntentState.submitted => LoopL10n.current.launch_chainModelsSubmitted,
    LaunchIntentState.confirmed => LoopL10n.current.common_confirmed,
    LaunchIntentState.reverted => LoopL10n.current.launch_chainModelsReverted,
    LaunchIntentState.failed => LoopL10n.current.common_failed,
    LaunchIntentState.unknown => LoopL10n.current.launch_chainModelsUnknown,
    LaunchIntentState.cancelled => LoopL10n.current.common_cancelled,
    LaunchIntentState.expired => LoopL10n.current.common_expired,
  };

  bool get isSignable =>
      this == LaunchIntentState.prepared ||
      this == LaunchIntentState.awaitingSignature;

  /// A state the server will not move on its own (S92a.6): the read-back of
  /// a broadcast stops here.
  bool get isSettled =>
      this == LaunchIntentState.confirmed ||
      this == LaunchIntentState.reverted ||
      this == LaunchIntentState.failed ||
      this == LaunchIntentState.expired;

  static LaunchIntentState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

/// The `eth_sendTransaction` parameter exactly as the server built it.
///
/// The four required keys are typed; the optional S83b keys (`from`, `gas`,
/// `nonce`, `type`, `maxFeePerGas`, `maxPriorityFeePerGas`, `gasPrice`) are
/// kept in [optional] exactly as they arrived — present or absent, `null` or
/// a value — so the wallet receives the server's object verbatim.
@immutable
final class LaunchUnsignedTransaction {
  LaunchUnsignedTransaction({
    required this.chainId,
    required this.to,
    required this.data,
    required this.value,
    Map<String, Object?> optional = const <String, Object?>{},
  }) : optional = Map<String, Object?>.unmodifiable(optional);

  /// The optional keys in contract order (decision 0089).
  static const optionalKeys = <String>[
    'from',
    'gas',
    'nonce',
    'type',
    'maxFeePerGas',
    'maxPriorityFeePerGas',
    'gasPrice',
  ];

  final int chainId;
  final String to;
  final String data;
  final String value;
  final Map<String, Object?> optional;

  /// The signing wallet the server built the call for, when it said so.
  String? get from => optional['from'] as String?;

  /// The contract keys in contract order; nothing added or dropped.
  Map<String, Object?> toWire() => <String, Object?>{
    'chainId': chainId,
    'to': to,
    'data': data,
    'value': value,
    for (final key in optionalKeys)
      if (optional.containsKey(key)) key: optional[key],
  };
}

/// `launchIntent.simulation` (optional, loop-api 0077): `eth_call` plus
/// `estimateGas` of the exact `buy()` payload at prepare.
enum LaunchSimulationStatus {
  passed('passed'),
  reverted('reverted'),
  unavailable('unavailable');

  const LaunchSimulationStatus(this.wireName);

  final String wireName;
  String get label => switch (this) {
    LaunchSimulationStatus.passed => LoopL10n.current.common_simulationPassed,
    LaunchSimulationStatus.reverted =>
      LoopL10n.current.common_simulationRejected,
    LaunchSimulationStatus.unavailable =>
      LoopL10n.current.common_simulationUnavailable,
  };

  static LaunchSimulationStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

@immutable
final class LaunchIntentSimulation {
  const LaunchIntentSimulation({
    required this.status,
    required this.reasonCode,
  });

  final LaunchSimulationStatus status;
  final String? reasonCode;
}

/// `launchIntent.policy` (optional): the canary facts the intent was admitted
/// under. `*Usd` are dollar decimal strings (USD1 at par).
@immutable
final class LaunchIntentPolicy {
  const LaunchIntentPolicy({
    required this.configVersion,
    required this.canaryMaxUsd,
    required this.valueUsd,
    required this.priceSource,
  });

  final String configVersion;
  final String canaryMaxUsd;
  final String valueUsd;
  final String priceSource;
}

/// `launchIntent.signing` (optional): the server's own permission. `allowed`
/// is true only in `awaiting_signature` before `expiresAt`.
@immutable
final class LaunchIntentSigning {
  const LaunchIntentSigning({
    required this.mode,
    required this.allowed,
    required this.reasonCode,
  });

  final String mode;
  final bool allowed;
  final String? reasonCode;
}

@immutable
final class LaunchPurchaseIntent {
  const LaunchPurchaseIntent({
    required this.launchIntentId,
    required this.state,
    required this.launchId,
    required this.projectId,
    required this.walletId,
    required this.roundId,
    required this.roundIndex,
    required this.chainId,
    required this.contractAddress,
    required this.quoteAssetId,
    required this.usd1Amount,
    required this.expectedTokenAmount,
    required this.minTokenAmount,
    required this.walletCumulativeUsd1,
    required this.deadline,
    required this.eligibilityProof,
    required this.configVersion,
    required this.stateTupleDigest,
    required this.snapshotBlockNumber,
    required this.snapshotBlockHash,
    required this.payloadDigest,
    required this.unsignedTransaction,
    required this.expiresAt,
    required this.createdAt,
    this.kind = LaunchIntentKind.buy,
    this.claimableTokens,
    this.refundableUsd1,
    this.projectAssetId,
    this.saleId,
    this.walletRoundCapUsd1,
    this.walletProjectCapUsd1,
    this.transactionHash,
    this.simulation,
    this.policy,
    this.signing,
    this.revertReason,
  });

  final String launchIntentId;
  final LaunchIntentState state;
  final String launchId;
  final String projectId;
  final String walletId;

  /// LOOP's round ID and the contract round of a purchase; `null` on a claim
  /// or a refund (decision 0087), which name no round.
  final String? roundId;
  final int? roundIndex;
  final String chainId;
  final String contractAddress;
  final String quoteAssetId;
  final String usd1Amount;
  final String expectedTokenAmount;
  final String minTokenAmount;
  final String walletCumulativeUsd1;
  final DateTime deadline;
  final List<String> eligibilityProof;
  final String configVersion;
  final String stateTupleDigest;
  final String snapshotBlockNumber;
  final String snapshotBlockHash;

  /// 64 hex characters. It binds the reviewed facts to the signed payload.
  final String payloadDigest;
  final LaunchUnsignedTransaction unsignedTransaction;
  final DateTime expiresAt;
  final DateTime createdAt;

  /// Decision 0087: which contract call this intent seals.
  final LaunchIntentKind kind;

  /// `getPosition().claimableTokens` at [snapshotBlockNumber]; claim only.
  final String? claimableTokens;

  /// `getPosition().refundableUsd1` at [snapshotBlockNumber]; refund only.
  final String? refundableUsd1;

  // The optional S83b keys (loop-api decision 0077). Absent means the server
  // did not send them, never zero.
  final String? projectAssetId;
  final String? saleId;

  /// `getRounds().walletRoundCapUsd1` at [snapshotBlockNumber].
  final String? walletRoundCapUsd1;

  /// `getSaleConfig().walletProjectCapUsd1` at [snapshotBlockNumber].
  final String? walletProjectCapUsd1;

  /// The device-reported broadcast hash: pending evidence only.
  final String? transactionHash;
  final LaunchIntentSimulation? simulation;
  final LaunchIntentPolicy? policy;
  final LaunchIntentSigning? signing;

  /// Decision 0080: the decoded revert reason of a `reverted` intent when a
  /// read surface yields one. `null` both when absent and when sent as null.
  final String? revertReason;

  /// The only on-device evaluation: the server's state, its own signing
  /// permission when it sent one, and the clock.
  bool canSignAt(DateTime now) =>
      state.isSignable &&
      (signing?.allowed ?? true) &&
      expiresAt.isAfter(now) &&
      deadline.isAfter(now);

  /// The transaction and the reviewed facts describe the same call.
  bool get payloadMatchesReview =>
      loopKnownChainIds.contains(chainId) &&
      unsignedTransaction.chainId == loopChainReference(chainId) &&
      unsignedTransaction.to == contractAddress &&
      unsignedTransaction.value == '0x0' &&
      unsignedTransaction.data.length > 10 &&
      _settlementCallMatches;

  /// A claim or a refund is `selector ‖ uint256 saleId` and nothing else
  /// (06 §4.1). When the server named the sale, the argument must be it.
  bool get _settlementCallMatches {
    if (!kind.isSettlement) return true;
    final data = unsignedTransaction.data;
    if (data.length != 74 || !data.startsWith(kind.selector)) return false;
    final sale = saleId;
    if (sale == null) return true;
    return BigInt.parse(data.substring(10), radix: 16) == BigInt.parse(sale);
  }
}

/// A prepared purchase: the server's intent and nothing else.
///
/// Decision 0089: USD1 balance and allowance are not part of the intent
/// response. They are read from `GET /v2/wallets/{id}/balances`
/// (`launchChain.usd1`), strictly.
@immutable
final class LaunchPurchasePrepared {
  const LaunchPurchasePrepared({required this.intent});

  final LaunchPurchaseIntent intent;
}

// ---------------------------------------------------------------------------
// display helpers
// ---------------------------------------------------------------------------

/// The 18-decimal smallest unit as an exact [Decimal].
Decimal launchUnits(String raw) => Decimal.parse(raw).shift(-18);

/// A grouped figure from an 18-decimal string. Grouping and rounding happen
/// here; the model keeps the exact string.
String launchUnitsFigure(String raw, {int maxFractionDigits = 4}) {
  final value = launchUnits(raw);
  final negative = value < Decimal.zero;
  final rounded = (negative ? -value : value).round(scale: maxFractionDigits);
  var text = rounded.toString();
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  final parts = text.split('.');
  final integer = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < integer.length; index += 1) {
    if (index > 0 && (integer.length - index) % 3 == 0) buffer.write(',');
    buffer.write(integer[index]);
  }
  final body = parts.length == 1
      ? buffer.toString()
      : '${buffer.toString()}.${parts[1]}';
  return negative ? '-$body' : body;
}

String launchUsd1Label(String raw) => '${launchUnitsFigure(raw)} USD1';

/// Basis points as a percentage; an integer is never parsed from a string.
String launchBpsLabel(int bps) {
  final whole = bps ~/ 100;
  final rest = bps % 100;
  if (rest == 0) return '$whole%';
  final fraction = rest
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0$'), '');
  return '$whole.$fraction%';
}

/// `poolFeeTier` is in hundredths of a basis point (2500 = 0.25%).
String launchPoolFeeTierLabel(int tier) {
  return '${Decimal.fromInt(tier).shift(-4)}%';
}

String launchDurationLabel(int seconds) {
  if (seconds == 0) return '0';
  if (seconds % 86400 == 0) {
    return LoopL10n.current.launch_chainModelsLaunchDurationLabel(
      seconds ~/ 86400,
    );
  }
  if (seconds % 3600 == 0) {
    return LoopL10n.current.launch_chainModelsLaunchDurationLabel2(
      seconds ~/ 3600,
    );
  }
  if (seconds % 60 == 0) {
    return LoopL10n.current.launch_chainModelsLaunchDurationLabel3(
      seconds ~/ 60,
    );
  }
  return LoopL10n.current.launch_chainModelsLaunchDurationLabel4(seconds);
}

/// `0x1234…abcd` for a digest or an address. The full value stays the truth.
String launchShortHex(String value) {
  if (value.length <= 13) return value;
  return '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
}
