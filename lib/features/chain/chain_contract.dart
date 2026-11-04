import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// Narrow, feature-facing failure taxonomy shared by the S5 ports
/// (`chain`, `wallet`, `market`, `watchlist`, `alerts`, `notifications`).
///
/// It carries no transport detail: the adapters map the frozen V2 error
/// catalogue onto these kinds, so `lib/features/` never branches on an HTTP
/// status or a `/v2/` literal.
enum LoopChainFailureKind {
  offline,

  /// A **read** that went out and got no answer in time
  /// (`LoopBackendFailureKind.timeout`). It is the same page phase as
  /// [offline]; only the wording differs (S88d). A write never carries it: a
  /// timed-out write stays [offline], whose outcome is unresolved.
  timedOut,

  /// The request was cancelled in flight. A write may or may not have been
  /// applied, so its idempotency key must survive an identical retry.
  cancelled,

  /// A response the client could not parse. The server may already have
  /// applied a write, so this is an unresolved outcome too. It is a **write**
  /// kind: a read that could not be parsed applied nothing and is
  /// [invalidData].
  outcomeUnknown,

  /// A read that did not complete for a reason the client cannot name: no
  /// server answer arrived, and nothing was submitted. It is the read-side
  /// counterpart of [unexpected], whose copy names an operation the reader
  /// never issued.
  readFailed,

  /// The capability, the provider or the runtime is not assembled.
  unavailable,

  /// The indexer has never run. The list is not empty — it is unknown.
  indexingDelayed,
  permissionDenied,

  /// `403 REGION_BLOCKED`: refused by jurisdiction, not by account. Switching
  /// account or asset cannot change it, so the copy must not suggest either.
  regionBlocked,
  notFound,

  /// The server requires a second verification factor for this command. Step
  /// up is not delivered, so the command can never succeed in this build.
  stepUpRequired,

  /// The device's own step-up for a large amount (decision 0152) was
  /// cancelled or did not pass. Nothing was signed and nothing was
  /// submitted; the same operation may be confirmed again.
  stepUpCancelled,

  /// Optimistic-concurrency rejection: reload and merge before retrying.
  versionConflict,
  bootstrapRequired,
  validationFailed,
  chainMismatch,
  rateLimited,
  idempotencyConflict,

  /// The wallet cannot cover the amount, the maximum fee or the gas reserve.
  insufficientBalance,

  /// The exact payload could not be pre-executed, so it may never be signed.
  simulationFailed,

  /// The 30 s quote is gone. A new quote is required; nothing was submitted.
  quoteExpired,

  /// The operation was already submitted once and its outcome is unresolved.
  /// It is locked: poll it, never resubmit.
  submissionUnknown,
  invalidData,
  unexpected,
}

final class LoopChainException implements Exception {
  const LoopChainException(
    this.kind, {
    this.reasonCode,
    this.exposureUsd,
    this.ceilingUsd,
    this.spentUsd,
    this.remainingUsd,
    this.requiredUsd1,
    this.requiredAmountIn,
    this.maxAmountIn,
    this.balanceUsd1,
    this.balanceMeme,
    this.requiredBnb,
    this.balanceBnb,
  });

  final LoopChainFailureKind kind;

  /// The server's own rule name when it named one (`detailsSafe.reasonCode`).
  /// A refusal that carries a rule is explained by that rule, never by a
  /// generic sentence the client invented.
  final String? reasonCode;

  /// The two exact decimal figures a ceiling rule compared. They are present
  /// together or not at all, and only the ceiling rules carry them.
  final String? exposureUsd;
  final String? ceilingUsd;

  /// The rolling-24-hour ceiling's own two figures: what the day has already
  /// committed and what is left. Only `CANARY_DAILY_CEILING_EXCEEDED` sends
  /// them, and a page may render them only when both arrived.
  final String? spentUsd;
  final String? remainingUsd;

  /// A MEME v2 balance refusal's figures (decision 0153): what the action
  /// needs (`requiredUsd1` for the NFT, `requiredAmountIn` for a pool
  /// trade) and the most the wallet can spend (`maxAmountIn`). Exact
  /// decimal strings, each optional.
  final String? requiredUsd1;
  final String? requiredAmountIn;
  final String? maxAmountIn;

  /// The balances a launch2 refusal compared (decision 0156): the wallet's
  /// USD1 or MEME, and on a gas refusal the fee ceiling next to the native
  /// balance. Exact decimal strings, each optional.
  final String? balanceUsd1;
  final String? balanceMeme;
  final String? requiredBnb;
  final String? balanceBnb;

  bool get hasCeilingFigures => exposureUsd != null && ceilingUsd != null;

  bool get hasDailyBudgetFigures => spentUsd != null && remainingUsd != null;

  @override
  String toString() => 'LoopChainException(${kind.name})';
}

/// Thrown by a model when a value would break the frozen contract. It never
/// carries the offending value.
final class InvalidLoopChainContractException implements Exception {
  const InvalidLoopChainContractException();

  @override
  String toString() => 'The S5 payload broke the V2 contract.';
}

/// Delivery mode of one port implementation. `preview` is the only mode that
/// may render the visible `演示数据` label.
enum LoopChainGatewayMode { production, preview, unavailable }

/// The `{ "status": "unavailable", "reasonCode": … }` projection.
///
/// A field carrying this object renders an unavailable explanation. It never
/// renders `0`, `—`, a placeholder figure or a fixture.
@immutable
final class LoopUnavailable {
  const LoopUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopUnavailable && other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

/// Provenance of one market fact. `source` is an enum on the wire, so an
/// unknown value is an invalid payload rather than a guessed provider.
enum LoopFactSource {
  dexscreener('dexscreener'),
  goplus('goplus'),
  geckoterminal('geckoterminal'),
  loopIndexer('loop_indexer'),

  /// A MEME curve token's own snapshot before it graduates (loop-api
  /// decision 0101): price and market cap read from the LOOP curve.
  loopCurve('loop_curve'),

  /// A graduated MEME token priced from its PancakeSwap pool's `slot0` when
  /// no market provider prices it (loop-api decision 0103). Always `derived`.
  poolSlot0('pool_slot0');

  const LoopFactSource(this.wireName);

  final String wireName;

  static LoopFactSource? tryParse(String value) {
    for (final source in values) {
      if (source.wireName == value) return source;
    }
    return null;
  }
}

/// Human label for a provider. It is shown next to every rendered fact.
String loopFactSourceLabel(LoopFactSource source) => switch (source) {
  LoopFactSource.dexscreener => 'DexScreener',
  LoopFactSource.goplus => 'GoPlus',
  LoopFactSource.geckoterminal => 'GeckoTerminal',
  LoopFactSource.loopIndexer =>
    LoopL10n.current.wallet_readScreensLoopProvenanceLine,
  LoopFactSource.loopCurve => LoopL10n.current.chain_contractLoopCurve,
  LoopFactSource.poolSlot0 => LoopL10n.current.chain_contractPoolSlot0,
};

/// How much a rendered number can be trusted right now.
enum LoopFactQuality {
  fresh('fresh'),
  stale('stale'),
  derived('derived'),
  proxied('proxied'),
  unavailable('unavailable');

  const LoopFactQuality(this.wireName);

  final String wireName;

  static LoopFactQuality? tryParse(String value) {
    for (final quality in values) {
      if (quality.wireName == value) return quality;
    }
    return null;
  }
}

/// The single fixed shape of every market number.
///
/// [value] is `null` exactly when [quality] is `unavailable`; the UI then
/// renders the [reasonCode] explanation instead of a figure.
@immutable
final class LoopFact {
  const LoopFact({
    required this.value,
    required this.source,
    required this.fetchedAt,
    required this.ttlSeconds,
    required this.quality,
    required this.reasonCode,
  });

  const LoopFact.unavailable(this.reasonCode)
    : value = null,
      source = null,
      fetchedAt = null,
      ttlSeconds = null,
      quality = LoopFactQuality.unavailable;

  final Decimal? value;
  final LoopFactSource? source;
  final DateTime? fetchedAt;
  final int? ttlSeconds;
  final LoopFactQuality quality;
  final String? reasonCode;

  bool get isAvailable =>
      value != null && quality != LoopFactQuality.unavailable;

  /// True when the figure may be shown but must carry a warning marker.
  bool get needsMarker =>
      quality == LoopFactQuality.stale ||
      quality == LoopFactQuality.derived ||
      quality == LoopFactQuality.proxied;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopFact &&
          other.value == value &&
          other.source == source &&
          other.fetchedAt == fetchedAt &&
          other.ttlSeconds == ttlSeconds &&
          other.quality == quality &&
          other.reasonCode == reasonCode;

  @override
  int get hashCode =>
      Object.hash(value, source, fetchedAt, ttlSeconds, quality, reasonCode);
}

/// zh-CN marker for a fact's quality. `fresh` needs no marker.
String? loopFactQualityMarker(LoopFactQuality quality) => switch (quality) {
  LoopFactQuality.fresh => null,
  LoopFactQuality.stale => LoopL10n.current.wallet_readScreensLoopBadge,
  LoopFactQuality.derived => LoopL10n.current.chain_contractDerived,
  LoopFactQuality.proxied =>
    LoopL10n.current.wallet_readScreensWalletAssetProxied,
  LoopFactQuality.unavailable => null,
};

/// zh-CN copy for a failed S5 operation. It states what did not happen; it
/// never claims a result the server did not confirm.
String loopChainFailureReason(LoopChainFailureKind? kind) => switch (kind) {
  LoopChainFailureKind.offline => LoopL10n.current.chain_contractOffline,
  LoopChainFailureKind.timedOut => LoopL10n.current.chain_contractTimedOut,
  LoopChainFailureKind.cancelled => LoopL10n.current.chain_contractCancelled,
  LoopChainFailureKind.outcomeUnknown =>
    LoopL10n.current.chain_contractOutcomeUnknown,
  LoopChainFailureKind.unavailable =>
    LoopL10n.current.chain_contractUnavailable,
  LoopChainFailureKind.indexingDelayed =>
    LoopL10n.current.chain_contractIndexingDelayed,
  LoopChainFailureKind.permissionDenied =>
    LoopL10n.current.chain_contractPermissionDenied,
  LoopChainFailureKind.regionBlocked =>
    LoopL10n.current.chain_contractRegionBlocked,
  LoopChainFailureKind.stepUpRequired =>
    LoopL10n.current.chain_contractStepUpRequired,
  LoopChainFailureKind.stepUpCancelled =>
    LoopL10n.current.chain_contractStepUpCancelled,
  LoopChainFailureKind.notFound => LoopL10n.current.chain_contractNotFound,
  LoopChainFailureKind.versionConflict =>
    LoopL10n.current.chain_contractVersionConflict,
  LoopChainFailureKind.bootstrapRequired =>
    LoopL10n.current.chain_contractBootstrapRequired,
  LoopChainFailureKind.validationFailed =>
    LoopL10n.current.chain_contractValidationFailed,
  LoopChainFailureKind.chainMismatch =>
    LoopL10n.current.chain_contractChainMismatch,
  LoopChainFailureKind.rateLimited =>
    LoopL10n.current.chain_contractRateLimited,
  LoopChainFailureKind.idempotencyConflict =>
    LoopL10n.current.chain_contractIdempotencyConflict,
  LoopChainFailureKind.insufficientBalance =>
    LoopL10n.current.chain_contractInsufficientBalance,
  LoopChainFailureKind.simulationFailed =>
    LoopL10n.current.chain_contractSimulationFailed,
  LoopChainFailureKind.quoteExpired =>
    LoopL10n.current.chain_contractQuoteExpired,
  LoopChainFailureKind.submissionUnknown =>
    LoopL10n.current.chain_contractSubmissionUnknown,
  LoopChainFailureKind.invalidData =>
    LoopL10n.current.chain_contractInvalidData,
  LoopChainFailureKind.readFailed => LoopL10n.current.chain_contractReadFailed,
  LoopChainFailureKind.unexpected => LoopL10n.current.chain_contractUnexpected,
  null => LoopL10n.current.common_actionIncomplete,
};

/// Whether a failure puts a page on its offline card: no answer from LOOP,
/// whether the connection failed or the read timed out (S88d).
bool loopChainIsOffline(LoopChainFailureKind? kind) =>
    kind == LoopChainFailureKind.offline ||
    kind == LoopChainFailureKind.timedOut;

/// Whether a write's outcome is unknown, so its idempotency key must be
/// replayed rather than replaced.
bool loopChainOutcomeIsUnresolved(LoopChainFailureKind kind) =>
    kind == LoopChainFailureKind.offline ||
    kind == LoopChainFailureKind.timedOut ||
    kind == LoopChainFailureKind.cancelled ||
    kind == LoopChainFailureKind.outcomeUnknown ||
    kind == LoopChainFailureKind.submissionUnknown;

/// zh-CN explanation for one server `reasonCode`.
///
/// An unknown code keeps a neutral sentence rather than inventing a cause.
String loopReasonCodeText(String? reasonCode) => switch (reasonCode) {
  // chain / RPC. A node or a provider LOOP could not reach is LOOP's own
  // read, not this device's connection: swapping WiFi cannot move it, so
  // these sentences say whose side the gap is on instead of sending the
  // owner to debug a network that is already working.
  'BSC_RPC_NOT_CONFIGURED' => LoopL10n.current.chain_contractSwitch,
  'BSC_CHAIN_RUNTIME_UNAVAILABLE' => LoopL10n.current.chain_contractSwitch2,
  'BSC_CHAIN_VERIFICATION_PENDING' => LoopL10n.current.chain_contractSwitch3,
  'BSC_RPC_UNREACHABLE' => LoopL10n.current.chain_contractSwitch4,
  'BSC_CHAIN_ID_MISMATCH' => LoopL10n.current.chain_contractSwitch5,
  // launch chain slot (decision 0038) — only ever about the testnet slot
  // S237 · decision 0204: no 测试网 in the sentence; the slot is named Launch.
  'LAUNCH_CHAIN_RPC_NOT_CONFIGURED' => LoopL10n.current.chain_contractSwitch6,
  'LAUNCH_CHAIN_VERIFICATION_PENDING' => LoopL10n.current.chain_contractSwitch7,
  'LAUNCH_CHAIN_RPC_UNREACHABLE' => LoopL10n.current.chain_contractSwitch8,
  'LAUNCH_CHAIN_ID_MISMATCH' => LoopL10n.current.chain_contractSwitch9,
  'BSC_BALANCE_CALL_FAILED' => LoopL10n.current.chain_contractSwitch10,
  'BSC_INDEXER_NOT_STARTED' => LoopL10n.current.chain_contractSwitch11,
  'BSC_POOL_INDEXER_NOT_STARTED' => LoopL10n.current.chain_contractSwitch12,
  'NATIVE_TRANSFER_SCAN_NOT_SUPPORTED' =>
    LoopL10n.current.chain_contractSwitch13,
  'CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED' =>
    LoopL10n.current.chain_contractSwitch14,
  // Decision 0213 (loop-api 0167): the activity page's Launch-chain leg.
  'LAUNCH2_INDEXER_NOT_STARTED' => LoopL10n.current.chain_contractSwitch15,
  'LAUNCH2_ACTIVITY_READ_FAILED' => LoopL10n.current.chain_contractSwitch16,
  'PRIVY_ASSET_MAPPING_UNAVAILABLE' => LoopL10n.current.chain_contractSwitch17,
  'PRIVY_WALLET_ID_UNAVAILABLE' => LoopL10n.current.chain_contractSwitch18,
  'PRIVY_BALANCE_CROSS_CHECK_FAILED' => LoopL10n.current.chain_contractSwitch19,
  // asset capability
  'SWAP_MODULE_NOT_DELIVERED' => LoopL10n.current.chain_contractSwitch20,
  'ASSET_NOT_READABLE' => LoopL10n.current.chain_contractSwitch21,
  // The address was described by a market provider, not by the registry. It
  // is a statement about where the facts came from, not a warning.
  'ASSET_NOT_REGISTERED' => LoopL10n.current.chain_contractSwitch22,
  'ASSET_BLOCKED' => LoopL10n.current.chain_contractSwitch23,
  // market providers
  'MARKET_RUNTIME_UNAVAILABLE' => LoopL10n.current.chain_contractSwitch24,
  'MARKET_PRICE_PROVIDER_NOT_CONFIGURED' =>
    LoopL10n.current.chain_contractSwitch25,
  'MARKET_PROVIDER_DEXSCREENER_DISABLED' =>
    LoopL10n.current.chain_contractSwitch26,
  'MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED' =>
    LoopL10n.current.chain_contractSwitch27,
  'MARKET_PROVIDER_GECKOTERMINAL_DISABLED' =>
    LoopL10n.current.chain_contractSwitch28,
  'MARKET_PROVIDER_RATE_LIMITED' => LoopL10n.current.chain_contractSwitch29,
  'MARKET_PROVIDER_REQUEST_REJECTED' => LoopL10n.current.chain_contractSwitch30,
  'MARKET_FACT_CACHE_UNAVAILABLE' => LoopL10n.current.chain_contractSwitch31,
  'MARKET_PROVIDER_UNREACHABLE' => LoopL10n.current.chain_contractSwitch32,
  'MARKET_PROVIDER_RESPONSE_MALFORMED' =>
    LoopL10n.current.chain_contractSwitch33,
  'MARKET_PAIR_NOT_FOUND' => LoopL10n.current.chain_contractSwitch34,
  'MARKET_FACT_NOT_REPORTED' => LoopL10n.current.chain_contractSwitch35,
  'MARKET_NATIVE_ASSET_NOT_SUPPORTED' =>
    LoopL10n.current.chain_contractSwitch36,
  'MARKET_POOL_NOT_REGISTERED' => LoopL10n.current.chain_contractSwitch37,
  'MARKET_NO_SWAPS_IN_RANGE' => LoopL10n.current.chain_contractSwitch38,
  'BALANCE_UNAVAILABLE' => LoopL10n.current.chain_contractSwitch39,
  // deferred product areas
  'HOLDER_DISTRIBUTION_NOT_SUPPORTED' => LoopL10n.current.chain_contractText,
  'SMART_MONEY_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText2,
  'PUSH_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText3,
  'COMMUNITY_NOT_BOUND' => LoopL10n.current.chain_contractText4,
  'MINING_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText5,
  'MARKET_CHART_TOOLS_DEFERRED' => LoopL10n.current.chain_contractText6,
  'WALLET_NETWORTH_TREND_DEFERRED' => LoopL10n.current.chain_contractText7,
  'WALLET_CUSTOM_RPC_DEFERRED' => LoopL10n.current.chain_contractText8,
  'WALLET_SECURITY_FACTS_DEFERRED' => LoopL10n.current.chain_contractText9,
  // S6 · money actions (write switch, canary, intent lifecycle)
  'WALLET_INTENT_RUNTIME_UNAVAILABLE' => LoopL10n.current.chain_contractText10,
  'BSC_WRITES_DISABLED' => LoopL10n.current.chain_contractText11,
  'PRIVY_NOT_CONFIGURED' => LoopL10n.current.chain_contractText12,
  'PRIVY_BSC_SWAP_DEVICE_EVIDENCE_PENDING' =>
    LoopL10n.current.chain_contractText13,
  'SWAP_SIMULATION_PROVIDER_PENDING' => LoopL10n.current.chain_contractText14,
  'GOPLUS_ADDRESS_SCREENING_NOT_CONFIGURED' =>
    LoopL10n.current.chain_contractText15,
  'GOPLUS_APPROVAL_FACTS_NOT_CONFIGURED' =>
    LoopL10n.current.chain_contractText16,
  'ALLOWANCE_READ_FAILED' => LoopL10n.current.chain_contractText17,
  'BSC_CALL_REVERTED' => LoopL10n.current.chain_contractText18,
  'SIMULATION_UNAVAILABLE' => LoopL10n.current.chain_contractText19,
  'GAS_ESTIMATE_UNAVAILABLE' => LoopL10n.current.chain_contractText20,
  'INTENT_EXPIRED' => LoopL10n.current.chain_contractText21,
  'INTENT_SUPERSEDED' => LoopL10n.current.chain_contractText22,
  'USER_CANCELLED' => LoopL10n.current.chain_contractText23,
  'TX_PENDING_VERIFICATION' => LoopL10n.current.chain_contractText24,
  'TX_PAYLOAD_MISMATCH' => LoopL10n.current.chain_contractText25,
  'TX_REVERTED' => LoopL10n.current.chain_contractText26,
  'RECEIPT_LOST' => LoopL10n.current.chain_contractText27,
  'PRIVY_SWAP_REJECTED' => LoopL10n.current.chain_contractText28,
  'PROVIDER_RESULT_AMBIGUOUS' => LoopL10n.current.chain_contractText29,
  'PRICE_IMPACT_ABOVE_HARD_LIMIT' => LoopL10n.current.chain_contractText30,
  'PRICE_IMPACT_UNAVAILABLE' => LoopL10n.current.chain_contractText31,
  'SIGNING_PAYLOAD_UNAVAILABLE' => LoopL10n.current.chain_contractText32,
  'INTENT_CHAIN_NOT_PERMITTED' => LoopL10n.current.chain_contractText33,
  // D20 security / settings / support (decision 0037)
  'V2_SECURITY_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText34,
  'SECURITY_RUNTIME_UNAVAILABLE' => LoopL10n.current.chain_contractText35,
  'V2_SETTINGS_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText36,
  'SETTINGS_RUNTIME_UNAVAILABLE' => LoopL10n.current.chain_contractText37,
  'V2_SUPPORT_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText38,
  'SUPPORT_RUNTIME_UNAVAILABLE' => LoopL10n.current.chain_contractText39,
  'ACCOUNT_SESSION_RUNTIME_UNAVAILABLE' =>
    LoopL10n.current.chain_contractText40,
  'NOTIFICATIONS_RUNTIME_UNAVAILABLE' => LoopL10n.current.chain_contractText41,
  'AUTH_STEP_UP_REQUIRED' => LoopL10n.current.chain_contractText42,
  'SUPPORT_ATTACHMENTS_UNAVAILABLE' => LoopL10n.current.chain_contractText43,
  'TERMS_POLICY_UNAVAILABLE' => LoopL10n.current.chain_contractText44,
  'POLICY_NOT_YET_EFFECTIVE' => LoopL10n.current.chain_contractText45,
  'CLIENT_BUILD_IS_DEVICE_LOCAL' => LoopL10n.current.chain_contractText46,
  'WALLET_NOT_SELECTED' => LoopL10n.current.chain_contractText47,
  'WALLET_RUNTIME_UNAVAILABLE' => LoopL10n.current.chain_contractText48,
  'SEND_APPROVALS_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText49,
  'INDEXING_DELAYED' => LoopL10n.current.chain_contractText50,
  'CAPABILITY_UNAVAILABLE' => LoopL10n.current.chain_contractText51,
  // Privy security methods: six permanently pending evidence items (§5.2)
  'PRIVY_MFA_EVIDENCE_PENDING' => LoopL10n.current.chain_contractText52,
  'PRIVY_PASSKEY_EVIDENCE_PENDING' => LoopL10n.current.chain_contractText53,
  'PRIVY_RECOVERY_PASSWORD_EVIDENCE_PENDING' =>
    LoopL10n.current.chain_contractText54,
  'PRIVY_AUTO_RECOVERY_EVIDENCE_PENDING' =>
    LoopL10n.current.chain_contractText55,
  'PRIVY_SOCIAL_RECOVERY_EVIDENCE_PENDING' =>
    LoopL10n.current.chain_contractText56,
  'PRIVY_KEY_EXPORT_EVIDENCE_PENDING' => LoopL10n.current.chain_contractText57,
  // D21 surfaces that exist as entry points only
  'PAY_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText58,
  'BRIDGE_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText59,
  'DAPP_EXECUTION_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText60,
  'COMMUNITY_AI_RUNTIME_DEFERRED' => LoopL10n.current.chain_contractText61,
  null => LoopL10n.current.common_itemUnavailable,
  _ => LoopL10n.current.common_itemUnavailable,
};

/// The phrase a **summary slot** renders in place of a figure it has no value
/// for — today the Token Card metric cells.
///
/// [loopReasonCodeText] writes a whole sentence, which is right where there is
/// a line to write it on. A metric cell is one short line inside a third of a
/// card: the sentence can only ellipsise there, leaving the reader with
/// neither the figure nor the reason. So the cell states the shape of the gap
/// and the full sentence stays in the fact list below the card, which is
/// where the reader goes for the why.
///
/// `等待数据` is reserved for a value that is genuinely on its way: a
/// connection still being verified, an index still catching up. Everything
/// else — including a code this build does not know — says `数据不可得`,
/// which is honest about the gap without promising an arrival that may never
/// come.
///
/// None of the market fact codes reach that first branch today: the codes a
/// market cap, a liquidity or a holder count can carry are all provider,
/// cache or "not reported" answers, none of which is a wait. The branch is
/// kept for the summary slots that will read chain and index facts; it is
/// not covering anything on the Token Card, and no market code should be
/// moved into it without the server actually reporting one.
String loopReasonCodeSummaryText(String? reasonCode) => switch (reasonCode) {
  'BSC_CHAIN_VERIFICATION_PENDING' ||
  'LAUNCH_CHAIN_VERIFICATION_PENDING' ||
  'INDEXING_DELAYED' ||
  'TX_PENDING_VERIFICATION' => LoopL10n.current.common_waitingForData,
  // A figure the provider answered but did not report is not a figure LOOP
  // failed to read. The card cell and the fact list one screen below now name
  // the same event, instead of one saying 数据不可得 and the other 没有数值.
  'MARKET_FACT_NOT_REPORTED' => LoopL10n.current.chain_contractSwitch40,
  _ => LoopL10n.current.common_dataUnavailable,
};

/// The badge every Launch surface and every sign sheet shows while the Launch
/// chain slot is the BSC testnet and the test-hints switch is on (decision
/// 0204). It is a statement of fact, never a blocker. Callers that draw it
/// conditionally use [loopTestnetBadgeFor].
const String loopTestnetBadgeLabel = loopTestnetBadgeText;

/// Title of the one-time explanation that accompanies the badge.
const String loopTestnetNoticeTitle = loopTestnetNoticeTitleText;

/// The one-time explanation. It never says anything is broken: the Launch
/// module points at `eip155:97` on purpose, and everything else stays on the
/// main chain.
final String loopTestnetNoticeBody = loopTestnetNoticeBodyText(
  loopLaunchTestnetChainId,
);

/// The reviewed page states for an S5 surface.
enum LoopChainViewPhase {
  loading,
  ready,
  empty,
  error,
  offline,
  unavailable,
  permission,
}

LoopChainViewPhase loopChainPhaseForFailure(LoopChainFailureKind? kind) =>
    switch (kind) {
      LoopChainFailureKind.offline ||
      LoopChainFailureKind.timedOut => LoopChainViewPhase.offline,
      LoopChainFailureKind.unavailable ||
      LoopChainFailureKind.indexingDelayed => LoopChainViewPhase.unavailable,
      LoopChainFailureKind.permissionDenied ||
      LoopChainFailureKind.regionBlocked ||
      LoopChainFailureKind.stepUpRequired => LoopChainViewPhase.permission,
      null => LoopChainViewPhase.empty,
      _ => LoopChainViewPhase.error,
    };

/// One loaded resource plus the honest phase for the block that renders it.
///
/// Every S5 page composes several of these so a failing block never blanks a
/// block that did load.
@immutable
final class LoopChainResourceState<T> {
  const LoopChainResourceState({
    required this.mode,
    required this.phase,
    this.value,
    this.failureKind,
    this.busy = false,
    this.refreshing = false,
  });

  factory LoopChainResourceState.initial(LoopChainGatewayMode mode) {
    final closed = mode == LoopChainGatewayMode.unavailable;
    return LoopChainResourceState<T>(
      mode: mode,
      phase: closed
          ? LoopChainViewPhase.unavailable
          : LoopChainViewPhase.loading,
      failureKind: closed ? LoopChainFailureKind.unavailable : null,
    );
  }

  final LoopChainGatewayMode mode;
  final LoopChainViewPhase phase;
  final T? value;
  final LoopChainFailureKind? failureKind;

  /// A write is in flight. The page keeps rendering the last server truth and
  /// only disables its actions.
  final bool busy;

  /// A read is in flight over a value this block already holds.
  ///
  /// The page keeps showing what it read last time and marks it 更新中; it does
  /// not fall back to a skeleton, because replacing readable data with a grey
  /// placeholder loses information the user already had. Only a block with no
  /// value at all loads as a skeleton.
  final bool refreshing;

  bool get isPreview => mode == LoopChainGatewayMode.preview;

  bool get isReady => phase == LoopChainViewPhase.ready && value != null;

  LoopChainResourceState<T> loading() => LoopChainResourceState<T>(
    mode: mode,
    phase: value == null
        ? LoopChainViewPhase.loading
        : LoopChainViewPhase.ready,
    value: value,
    busy: busy,
    refreshing: value != null,
  );

  LoopChainResourceState<T> ready(T next) => LoopChainResourceState<T>(
    mode: mode,
    phase: LoopChainViewPhase.ready,
    value: next,
  );

  LoopChainResourceState<T> failed(LoopChainFailureKind kind) =>
      LoopChainResourceState<T>(
        mode: mode,
        phase: value == null
            ? loopChainPhaseForFailure(kind)
            : LoopChainViewPhase.ready,
        value: value,
        failureKind: kind,
      );

  LoopChainResourceState<T> working(bool next) => LoopChainResourceState<T>(
    mode: mode,
    phase: phase,
    value: value,
    failureKind: next ? null : failureKind,
    busy: next,
    refreshing: refreshing,
  );
}
