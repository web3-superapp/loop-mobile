import 'package:decimal/decimal.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

// ---------------------------------------------------------------------------
// Display helpers for the MEME launchpad (client decision 0120)
// ---------------------------------------------------------------------------
//
// Rounding and grouping happen here and nowhere else. USD1 is read at par
// with the dollar, the way the contract and Launch both read it.

/// 「12.34 USD1」 from a raw 18-decimal amount.
String memeUsd1Label(BigInt raw, {int maxFractionDigits = 2}) =>
    '${loopFormatDecimal(memeUnits(raw), maxFractionDigits: maxFractionDigits)} USD1';

/// A token amount, exact to two decimals and grouped. Every amount a reader
/// commits to — a quote, a signing fact, a holding — uses this one.
String memeTokenFigure(BigInt raw) =>
    loopFormatDecimal(memeUnits(raw), maxFractionDigits: 2);

/// A token amount in a summary slot (a holder row, a trade row): exact below
/// 100,000, `K` / `M` / `B` above. Never used for an amount being signed.
String memeTokenCompact(BigInt raw) {
  final value = memeUnits(raw);
  if (value < Decimal.fromInt(100000)) {
    return loopFormatDecimal(value, maxFractionDigits: 2);
  }
  return loopFormatCompactFigure(value, usd: false);
}

String memeTokenLabel(BigInt raw, String symbol) =>
    '${memeTokenFigure(raw)} $symbol';

/// A curve price at the 行情 column's precision (`$0.000009891`).
String memePriceLabel(Decimal price) => marketRowPrice(price);

/// A market cap or a volume in a summary slot (`$9,891`, `$1.2M`).
String memeCapLabel(Decimal value) => loopFormatCompactFigure(value);

/// How long a token has been live, in the list row's words (decision 0173,
/// design 35 列表 A): 「11 分钟」, 「12 小时」, 「1 天」. Under a minute — or a
/// launch time ahead of [now], a clock that disagrees — is 「刚刚」.
String memeAgeLabel(DateTime createdAt, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final age = reference.difference(createdAt.toUtc());
  if (age.inMinutes < 1) return LoopL10n.current.common_justNow;
  if (age.inHours < 1) {
    return LoopL10n.current.meme_formatMemeAgeLabel(age.inMinutes);
  }
  if (age.inDays < 1) {
    return LoopL10n.current.meme_formatMemeAgeLabel2(age.inHours);
  }
  return LoopL10n.current.meme_formatMemeAgeLabel3(age.inDays);
}

/// Basis points as a percentage with up to two decimals (`33.27%`, `1%`).
String memeBpsLabel(int bps) {
  final value = Decimal.fromInt(bps).shift(-2);
  return '${loopFormatDecimal(value, maxFractionDigits: 2)}%';
}

/// 0x1234…abcd.
String memeShortAddress(String address) => loopTruncatedAddress(address);

/// The fraction a progress bar fills, in drawing space only. The figure
/// printed beside it stays [memeBpsLabel].
double memeProgressFraction(int bps) => (bps.clamp(0, 10000)) / 10000;

/// The one sentence a row or a page prints where its price would be when the
/// server did not price it (contract §3). Never a zero, never a dash.
String memeQuoteUnavailableText(String? reasonCode) => switch (reasonCode) {
  'MEME_DEX_CHAIN_NOT_PRICED' => LoopL10n.current.meme_formatSwitch,
  'MEME_DEX_QUOTE_UNAVAILABLE' => LoopL10n.current.meme_formatSwitch2,
  'MEME_TOKEN_NOT_ON_CHAIN' => LoopL10n.current.meme_formatSwitch3,
  _ => LoopL10n.current.meme_formatSwitch4,
};

/// zh-CN for the server's own refusal rules (contract §11) and the state
/// reasons it may attach. Every line says what did not happen.
String memeReasonText(String? reasonCode) => switch (reasonCode) {
  'MEME_TOKEN_NOT_FOUND' => LoopL10n.current.meme_formatSwitch5,
  'MEME_CURVE_NOT_TRADING' => LoopL10n.current.meme_formatSwitch6,
  'MEME_CURVE_FULL' => LoopL10n.current.meme_formatSwitch7,
  'MEME_TOKEN_NOT_DRAFT' ||
  'MEME_TOKEN_NOT_ON_CHAIN' => LoopL10n.current.meme_formatSwitch8,
  'MEME_SALT_TAKEN' => LoopL10n.current.meme_formatSwitch9,
  'MEME_INTENT_EXPIRED' => LoopL10n.current.meme_formatSwitch10,
  'MEME_INTENT_NOT_SIGNABLE' ||
  'MEME_INTENT_ALREADY_REPORTED' => LoopL10n.current.meme_formatSwitch11,
  'MEME_USD1_BALANCE_INSUFFICIENT' => LoopL10n.current.meme_formatSwitch12,
  'MEME_SELL_EXCEEDS_BALANCE' => LoopL10n.current.meme_formatSwitch13,
  'MEME_GAS_INSUFFICIENT' => LoopL10n.current.meme_formatSwitch14(
    loopLaunchNativeSymbolText,
  ),
  'MEME_WALLET_CAP_EXCEEDED' => LoopL10n.current.meme_formatSwitch15,
  'MEME_BELOW_MIN_BUY' => LoopL10n.current.meme_formatSwitch16,
  'MEME_METADATA_INVALID' => LoopL10n.current.meme_formatSwitch17,
  'MEME_IMAGE_NOT_OWNED' => LoopL10n.current.meme_formatSwitch18,
  'MEME_MIN_OUT_ABOVE_QUOTE' ||
  'MEME_QUOTE_ZERO' => LoopL10n.current.meme_formatSwitch19,
  'MEME_TX_PAYLOAD_MISMATCH' => LoopL10n.current.meme_formatSwitch20,
  'MEME_TX_REVERTED' => LoopL10n.current.meme_formatSwitch21,
  'MEME_TX_NOT_OBSERVED' => LoopL10n.current.meme_formatSwitch22,
  'MEME_CREATE_RATE_LIMITED' => LoopL10n.current.meme_createIf2,
  'MEME_SIMULATION_REVERTED' => LoopL10n.current.meme_formatSwitch23,
  'MEME_SIMULATION_UNAVAILABLE' => LoopL10n.current.meme_formatSwitch24,
  'MEME_APPROVAL_REQUIRED' => LoopL10n.current.meme_formatSwitch25,
  'MEME_VIEWER_WALLET_MISSING' => LoopL10n.current.meme_formatSwitch26,
  'MEME_CONTRACT_READ_FAILED' ||
  'MEME_CHAIN_RPC_UNREACHABLE' => LoopL10n.current.meme_formatSwitch27,
  'MEME_WRITES_DISABLED' => LoopL10n.current.meme_formatSwitch28,
  'MEME_MAINNET_SIGNING_CLOSED' => LoopL10n.current.meme_formatSwitch29,
  'MEME_MODULE_NOT_ENABLED' => LoopL10n.current.meme_formatSwitch30,
  'MEME_RUNTIME_UNAVAILABLE' ||
  'MEME_REPOSITORY_UNAVAILABLE' => LoopL10n.current.meme_formatSwitch31,
  'MEME_CONTRACT_NOT_CONFIGURED' ||
  'MEME_USD1_NOT_CONFIGURED' => LoopL10n.current.meme_formatSwitch32,
  'CANARY_CEILING_EXCEEDED' => LoopL10n.current.meme_formatSwitch33,
  'CANARY_DAILY_CEILING_EXCEEDED' => LoopL10n.current.meme_formatSwitch34,
  'ASSET_NOT_IN_CANARY_ALLOWLIST' || 'COUNTERPARTY_NOT_IN_CANARY_ALLOWLIST' =>
    LoopL10n.current.meme_formatSwitch35,
  _ => loopReasonCodeSummaryText(reasonCode),
};

/// The sentence for one failed request: the server's own rule when it named
/// one, otherwise what kind of failure it was.
String memeFailureText(LoopChainException failure) {
  final reason = failure.reasonCode;
  if (reason != null) return memeReasonText(reason);
  return loopChainFailureReason(failure.kind);
}
