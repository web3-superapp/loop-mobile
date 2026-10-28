import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/text/loop_power_text.dart';

// ---------------------------------------------------------------------------
// S138 · 挖矿奖励 (decisions 0140, 0141)
// ---------------------------------------------------------------------------
//
// The view model of `/mining/rewards`: two tracks settled every hour, the
// previous hour displayed minute by minute, five invite levels and one claim.
// Every LOOP amount is an exact integer of the token's smallest unit (18
// decimals); every power is an exact [Decimal]. No `double` is involved, and
// nothing here is ever derived from a local timer.

/// LOOP's on-chain precision.
const int miningLoopDecimals = 18;

/// `10^18`: one whole LOOP in its smallest unit.
final BigInt miningLoopUnit = BigInt.from(10).pow(miningLoopDecimals);

/// How the server says the minute display stands.
enum MiningDisplayState {
  /// No hour has been settled for this account yet.
  awaitingFirstSettlement('awaiting_first_settlement'),

  /// Inside the hour after the last settled one.
  displaying('displaying'),

  /// The display hour is over and the next hour is not settled yet.
  settling('settling'),

  /// The settlement store cannot be read.
  unavailable('unavailable');

  const MiningDisplayState(this.wireName);

  final String wireName;

  static MiningDisplayState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

/// The state of one claim, as the server reports it. The five the requirer
/// names (§7.3), plus `expired` (a voucher whose deadline passed unused) and
/// `none` (no claim yet).
enum MiningClaimStatus {
  none('none'),
  claimable('claimable'),
  submitting('submitting'),
  confirming('confirming'),
  succeeded('succeeded'),
  failed('failed'),
  expired('expired');

  const MiningClaimStatus(this.wireName);

  final String wireName;

  static MiningClaimStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }

  /// Something may be on its way to the chain: no second claim is offered.
  bool get inFlight => this == submitting || this == confirming;

  bool get isTerminal => this == succeeded || this == failed || this == expired;
}

/// One settled hour `[epochStart, epochEnd)`.
@immutable
final class MiningRewardEpoch {
  const MiningRewardEpoch({
    required this.epochStart,
    required this.epochEnd,
    required this.totalReward,
    required this.nftReward,
    required this.assetReward,
  });

  final DateTime epochStart;
  final DateTime epochEnd;
  final BigInt totalReward;
  final BigInt nftReward;
  final BigInt assetReward;
}

/// `hourly.display`: the server's own reading of the display window at
/// `serverTime` (contract §3.2). [completedMinutes] and [displayed] are what
/// the server computed then; the page uses them as they are while the minute
/// is the same, and derives `floor(total × m / 60)` only for later minutes.
@immutable
final class MiningDisplayWindow {
  const MiningDisplayWindow({
    required this.total,
    required this.perMinute,
    required this.completedMinutes,
    required this.displayed,
    this.windowStart,
    this.windowEnd,
    this.nextUpdateAt,
  });

  /// The settled hour's whole reward (`totalRaw`).
  final BigInt total;

  /// `floor(total / 60)`, as published. Informative only: the figure is
  /// `floor(total × m / 60)`, not `perMinute × m`.
  final BigInt perMinute;

  /// 0..60 at `serverTime`.
  final int completedMinutes;

  /// `displayedRaw` at `serverTime`.
  final BigInt displayed;

  /// The first instant of the display hour (the settled hour's end). `null`
  /// lets the page fall back to the epoch's own end.
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final DateTime? nextUpdateAt;
}

/// `hourly.displayState`, its reason and the display window.
@immutable
final class MiningMinuteDisplay {
  const MiningMinuteDisplay({
    required this.state,
    this.reasonCode,
    this.window,
  });

  final MiningDisplayState state;

  /// `MINING_SETTLEMENT_UNAVAILABLE`, `MINING_PARAMETERS_PENDING`.
  final String? reasonCode;
  final MiningDisplayWindow? window;
}

/// NFT track. The real NFT count and the weighted power are two facts and are
/// never merged into one 「持有 NFT」 figure (requirer §8.1).
@immutable
final class MiningNftTrack {
  const MiningNftTrack({
    required this.realCount,
    required this.ownPower,
    required this.invitePower,
    required this.totalPower,
    required this.reward,
    this.networkPower,
  });

  /// `tracks.nft.networkPower`: the whole network's NFT power that hour
  /// (decision 0253). `null` only where a test builds a track without it.
  final Decimal? networkPower;

  final BigInt realCount;
  final Decimal ownPower;
  final Decimal invitePower;
  final Decimal totalPower;
  final BigInt reward;
}

/// `0x1234…abcd` for a CAIP-19 asset id: the contract names no symbol and no
/// precision, so the address is all the page can say.
String miningRewardsAssetLabel(String assetId) {
  final address = assetId.substring(assetId.lastIndexOf(':') + 1);
  if (address.length < 12) return address;
  return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
}

/// One admitted Meme asset the account held at the end of the hour.
@immutable
final class MiningTrackAsset {
  const MiningTrackAsset({
    required this.assetId,
    required this.power,
    required this.balanceAtEnd,
  });

  /// CAIP-19 `eip155:<chain>:0x…`.
  final String assetId;
  final Decimal power;

  /// `balanceAtEndRaw`: the token's smallest unit. Its precision is not
  /// published, so it is never rendered as a whole-token figure.
  final BigInt balanceAtEnd;

  String get label => miningRewardsAssetLabel(assetId);
}

/// An asset that left the asset pool for the hour
/// (`tracks.asset.excludedAssets`), e.g. `MINING_ASSET_GRADUATED_UNREADABLE`.
@immutable
final class MiningRewardsExcludedAsset {
  const MiningRewardsExcludedAsset({
    required this.assetId,
    required this.reasonCode,
  });

  final String assetId;
  final String reasonCode;

  String get label => miningRewardsAssetLabel(assetId);
}

/// Meme coin asset track.
@immutable
final class MiningAssetTrack {
  const MiningAssetTrack({
    required this.assets,
    required this.ownPower,
    required this.invitePower,
    required this.totalPower,
    required this.reward,
    this.excluded = const <MiningRewardsExcludedAsset>[],
    this.networkPower,
  });

  /// `tracks.asset.networkPower` (decision 0253).
  final Decimal? networkPower;

  final List<MiningTrackAsset> assets;

  /// Assets that counted for nothing this hour, with the server's reason.
  final List<MiningRewardsExcludedAsset> excluded;
  final Decimal ownPower;
  final Decimal invitePower;
  final Decimal totalPower;
  final BigInt reward;
}

/// One of the five invite levels.
@immutable
final class MiningInviteLevel {
  const MiningInviteLevel({
    required this.level,
    required this.ratePercent,
    required this.activeMembers,
    required this.nftPower,
    required this.assetPower,
  });

  /// 1..5.
  final int level;

  /// 10 / 5 / 3 / 2 / 1 by default; published by the server.
  final Decimal ratePercent;

  /// Members of this level whose own power is above zero (decision 0140 §5.2).
  final int activeMembers;
  final Decimal nftPower;
  final Decimal assetPower;
}

@immutable
final class MiningInviteTotal {
  const MiningInviteTotal({
    required this.activeMembers,
    required this.nftPower,
    required this.assetPower,
  });

  final int activeMembers;
  final Decimal nftPower;
  final Decimal assetPower;
}

@immutable
final class MiningInvites {
  const MiningInvites({required this.levels, required this.total});

  final List<MiningInviteLevel> levels;
  final MiningInviteTotal total;
}

/// One transaction of a claim that reached the chain.
@immutable
final class MiningClaimTx {
  const MiningClaimTx({
    required this.txHash,
    this.chainId,
    this.amount,
    this.at,
  });

  final String txHash;

  /// `eip155:56` or `eip155:97` when known.
  final String? chainId;
  final BigInt? amount;
  final DateTime? at;

  /// BscScan for the chain the claim ran on; the Launch testnet when the
  /// server did not say (the claim contract is deployed there first).
  String get explorerUrl {
    final host = chainId == 'eip155:56' ? 'bscscan.com' : 'testnet.bscscan.com';
    return 'https://$host/tx/$txHash';
  }
}

/// The claim block of the rewards resource.
@immutable
final class MiningClaimSummary {
  const MiningClaimSummary({
    required this.status,
    required this.executable,
    this.lastTx,
    this.claimId,
    this.reasonCode,
    this.amount,
    this.failureReasonCode,
    this.configurationReported = false,
    this.configurationReasonCode,
  });

  final MiningClaimStatus status;
  final MiningClaimTx? lastTx;

  /// The claim [status] describes, when the server named it.
  final String? claimId;

  /// `hourly.claim.executable`: the server allows a new claim at all
  /// (contract, chain, signer configured, writes open).
  final bool executable;
  final String? reasonCode;
  final BigInt? amount;
  final String? failureReasonCode;

  /// Whether the server sent `hourly.claim.configurationReasonCode` at all
  /// (loop-api decision 0144 §8). An older backend omits the key; its answer
  /// is then read by decision 0184's inference.
  final bool configurationReported;

  /// `hourly.claim.configurationReasonCode`: the claim path's configuration
  /// reason alone, never masked by a ledger reason in [reasonCode]; `null`
  /// when the claim path is configured. Meaningful only when
  /// [configurationReported].
  final String? configurationReasonCode;
}

/// `hourly.claim.reasonCode` while no claim contract is configured.
const String miningClaimContractNotConfiguredCode =
    'MINING_CLAIM_CONTRACT_NOT_CONFIGURED';

/// Decision 0184 (需求方 docs/36 第 4 题): whether the LOOP token is live, read
/// from the one switch the server already has — the claim contract. The day
/// an operator configures it is the day mining starts for real; before it the
/// pages count power, place and invites and print no LOOP amount at all.
enum MiningTokenStage {
  /// No claim contract: the token is not on chain yet.
  preToken,

  /// The server shows the claim path past its contract check.
  live,

  /// The answer does not say whether a contract is configured: the settlement
  /// store is unconfigured (decision 0185), or, on a backend without
  /// `configurationReasonCode`, the claim gate stopped on a ledger fact first
  /// (nothing settled, nothing or too little to claim, parameters pending,
  /// settlement down). Read as
  /// [preToken] by [miningTokenLive]: a LOOP amount is never printed on a
  /// guess.
  unknown,
}

/// The configuration reasons the server checks only after the claim contract
/// is configured (loop-api `miningClaimUnavailableReason`, decision 0125
/// §8.2): any of them proves a contract is there.
const Set<String> _miningClaimPastContractCodes = <String>{
  'MINING_CLAIM_CHAIN_NOT_CONFIGURED',
  'MINING_CLAIM_SIGNER_NOT_CONFIGURED',
  'MINING_CLAIM_WRITES_DISABLED',
  'MINING_CLAIM_CONTRACT_PAUSED',
  'MINING_CLAIM_CHAIN_READ_FAILED',
  'MINING_CLAIM_FUNDING_INSUFFICIENT',
};

/// BSC mainnet, where the LOOP token launches.
const String miningMainnetChainId = 'eip155:56';

/// [MiningTokenStage] from `hourly.claim`.
///
/// Decision 0185: when the server reports `configurationReasonCode` it alone
/// decides — `null` is live, a reason checked before or at the contract is
/// pre-token, a reason checked past it is live, and the settlement store
/// being unconfigured (checked before the contract) does not say. A ledger
/// reason in `reasonCode` no longer hides the answer. An older backend that
/// omits the key falls back to decision 0184's inference.
MiningTokenStage miningTokenStage(MiningClaimSummary claim) {
  if (claim.configurationReported) {
    final configuration = claim.configurationReasonCode;
    if (configuration == null) return MiningTokenStage.live;
    if (_miningClaimPreTokenCodes.contains(configuration)) {
      return MiningTokenStage.preToken;
    }
    if (_miningClaimPastContractCodes.contains(configuration)) {
      return MiningTokenStage.live;
    }
    return MiningTokenStage.unknown;
  }
  return _legacyMiningTokenStage(claim);
}

/// The configuration reasons that mean no LOOP token yet: no claim contract,
/// or the mainnet claim closed (checked before the contract).
const Set<String> _miningClaimPreTokenCodes = <String>{
  miningClaimContractNotConfiguredCode,
  'MINING_CLAIM_MAINNET_CLOSED',
};

/// Decision 0184's reading, kept for a backend without
/// `configurationReasonCode`.
MiningTokenStage _legacyMiningTokenStage(MiningClaimSummary claim) {
  if (claim.executable) return MiningTokenStage.live;
  final reason = claim.reasonCode;
  // `MAINNET_CLOSED` is checked before the contract: on mainnet the claim
  // is closed whatever is configured, so the token is not live there either.
  if (_miningClaimPreTokenCodes.contains(reason)) {
    return MiningTokenStage.preToken;
  }
  if (_miningClaimPastContractCodes.contains(reason)) {
    return MiningTokenStage.live;
  }
  // A claim the server recorded on BSC mainnet was prepared against the
  // token's own contract. A testnet claim proves nothing: a test contract may
  // have been configured once and removed since.
  if (claim.status != MiningClaimStatus.none &&
      claim.lastTx?.chainId == miningMainnetChainId) {
    return MiningTokenStage.live;
  }
  return MiningTokenStage.unknown;
}

/// LOOP amounts may be drawn only when the rewards resource shows the token
/// live. An unread resource, and an answer that does not say, both keep the
/// pages on power only (decision 0184).
bool miningTokenLive(MiningRewardsView? view) =>
    view != null && miningTokenStage(view.claim) == MiningTokenStage.live;

/// The one line that stands where the claim block was while the token is not
/// live (decision 0184; it replaces 0155's Coming soon button and its note).
const String miningPowerOnlyNotice = 'LOOP 代币上线后开始正式开挖，上线前只统计算力';

/// The account's power in the last settled hour: the NFT track plus the Meme
/// track, as the server settled them. `null` when neither track was read.
Decimal? miningLastHourPower(MiningRewardsView? view) {
  final nft = view?.nft?.totalPower;
  final asset = view?.asset?.totalPower;
  if (nft == null && asset == null) return null;
  return (nft ?? Decimal.zero) + (asset ?? Decimal.zero);
}

/// 全网算力 as the 算力榜 adds it up (decision 0253): the last settled hour's
/// `tracks.nft.networkPower + tracks.asset.networkPower`, self plus referral.
/// `null` until both tracks carry it.
Decimal? miningLastHourNetworkPower(MiningRewardsView? view) {
  final nft = view?.nft?.networkPower;
  final asset = view?.asset?.networkPower;
  if (nft == null || asset == null) return null;
  return nft + asset;
}

/// `GET /v2/mining/rewards`, decoded.
@immutable
final class MiningRewardsView {
  const MiningRewardsView({
    required this.settledTotal,
    required this.claimedTotal,
    required this.claimable,
    required this.lastEpoch,
    required this.display,
    required this.nft,
    required this.asset,
    required this.invites,
    required this.claim,
    required this.serverTime,
    this.minimumClaim,
  });

  final BigInt settledTotal;
  final BigInt claimedTotal;

  /// settled − claimed (confirmed on chain). The Claim button uses only this.
  final BigInt claimable;
  final MiningRewardEpoch? lastEpoch;
  final MiningMinuteDisplay display;
  final MiningNftTrack? nft;
  final MiningAssetTrack? asset;
  final MiningInvites? invites;
  final MiningClaimSummary claim;
  final DateTime serverTime;

  /// `parameters.minimumClaimRaw`: below this the server refuses a claim
  /// (`MINING_CLAIM_BELOW_MINIMUM`). `null` while no parameter version is
  /// approved.
  final BigInt? minimumClaim;
}

/// One row of `GET /v2/mining/claims`.
@immutable
final class MiningClaimRecord {
  const MiningClaimRecord({
    required this.claimId,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.txHash,
    this.chainId,
    this.failureReasonCode,
  });

  final String claimId;
  final MiningClaimStatus status;
  final BigInt amount;
  final DateTime createdAt;
  final String? txHash;
  final String? chainId;
  final String? failureReasonCode;

  MiningClaimTx? get tx => txHash == null
      ? null
      : MiningClaimTx(
          txHash: txHash!,
          chainId: chainId,
          amount: amount,
          at: createdAt,
        );
}

@immutable
final class MiningClaimPage {
  const MiningClaimPage({required this.items, this.nextCursor});

  final List<MiningClaimRecord> items;
  final String? nextCursor;
}

/// The pair 「去兑换」 opens the wallet's swap page with.
@immutable
final class MiningSuggestedSwap {
  const MiningSuggestedSwap({
    this.fromAssetId,
    this.toAssetId,
    this.fromSymbol,
    this.toSymbol,
    this.amount,
  });

  final String? fromAssetId;
  final String? toAssetId;
  final String? fromSymbol;
  final String? toSymbol;

  /// `suggestedSwapToAmount`: whole-unit decimal string of the BNB to
  /// receive (shortfall plus 50%), as published.
  final String? amount;
}

/// The unsigned claim transaction the wallet receives verbatim.
@immutable
final class MiningClaimTransaction {
  const MiningClaimTransaction({
    required this.chainReference,
    required this.to,
    required this.data,
    required this.from,
    required this.wire,
  });

  final int chainReference;
  final String to;
  final String data;
  final String from;
  final Map<String, Object?> wire;
}

/// `POST /v2/mining/claim/prepare` → one claim voucher and its transaction.
@immutable
final class MiningClaimIntent {
  const MiningClaimIntent({
    required this.claimId,
    required this.walletId,
    required this.chainId,
    required this.contractAddress,
    required this.amount,
    required this.cumulativeAmount,
    required this.deadline,
    required this.createdAt,
    required this.transaction,
    required this.payloadDigest,
    required this.localPayloadDigest,
    required this.signingAllowed,
    required this.payloadMatchesReview,
    this.signingReasonCode,
  });

  final String claimId;
  final String walletId;
  final String chainId;
  final String contractAddress;

  /// What this claim pays (the expected delta).
  final BigInt amount;
  final BigInt cumulativeAmount;
  final DateTime deadline;
  final DateTime createdAt;
  final MiningClaimTransaction transaction;

  /// The server's `intent.payloadDigest` (`0x` + keccak-256 of the canonical
  /// transaction JSON, loop-api decision 0123).
  final String payloadDigest;

  /// The same digest as this device computed it from [transaction]. The codec
  /// refuses a prepare whose two digests differ; the signer checks again
  /// (decision 0143).
  final String localPayloadDigest;

  /// The server's digest and the device's name the same transaction.
  bool get digestMatches => payloadDigest == localPayloadDigest;
  final bool signingAllowed;
  final String? signingReasonCode;

  /// The transaction calls the reviewed contract with the reviewed calldata
  /// on the reviewed chain.
  final bool payloadMatchesReview;

  bool canSignAt(DateTime now) => signingAllowed && deadline.isAfter(now);
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

/// A LOOP amount at 4 decimals, truncated (never rounded up: a figure on this
/// page is never more than the ledger holds), grouped.
String miningLoopFigure(BigInt amount, {int fractionDigits = 4}) {
  final negative = amount.isNegative;
  final absolute = negative ? -amount : amount;
  final whole = absolute ~/ miningLoopUnit;
  final fraction = absolute.remainder(miningLoopUnit);
  final scaled =
      fraction ~/ BigInt.from(10).pow(miningLoopDecimals - fractionDigits);
  final digits = whole.toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
    grouped.write(digits[index]);
  }
  final tail = fractionDigits == 0
      ? ''
      : '.${scaled.toString().padLeft(fractionDigits, '0')}';
  return '${negative ? '-' : ''}$grouped$tail';
}

/// A power figure: exact, floored to a whole number, grouped (decision 0252).
String miningPowerFigure(Decimal value) =>
    loopPowerFigureOf(value.floor().toBigInt());

/// `10%`, `2.5%`.
String miningRateLabel(Decimal percent) {
  var text = percent.toString();
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return '$text%';
}

/// `0x1234…abcd`.
String miningShortHash(String value) => value.length <= 12
    ? value
    : '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
