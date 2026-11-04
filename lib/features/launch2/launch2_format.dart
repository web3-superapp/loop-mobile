import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';

// ---------------------------------------------------------------------------
// Display helpers for MEME v2 (client decision 0139)
// ---------------------------------------------------------------------------
//
// Rounding and grouping happen here and nowhere else. USD1 is read at par
// with the dollar, the way the contract (`priceSource: usd1_par`) reads it.

/// Whether the App reads Chinese: the formatters below keep the zh-CN
/// shapes (「10 亿」, 「10-18 17:32」); every other locale gets the English
/// ones (glossary §1.7–8).
bool get launch2ChineseCopy => LoopL10n.currentLocale.languageCode == 'zh';

const List<String> _launch2MonthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// 「Oct 18」: an English month and day of [local], without the year.
String launch2MonthDay(DateTime local) =>
    '${_launch2MonthNames[local.month - 1]} ${local.day}';

/// The stage's short name, as the list pill and the page's stage bar say it.
String launch2StageLabel(Launch2Stage stage) => switch (stage) {
  Launch2Stage.upcoming => LoopL10n.current.launch2_launch2FormatUpcoming,
  Launch2Stage.nftSale => LoopL10n.current.launch2_launch2FormatNftSale,
  Launch2Stage.snapshotPending =>
    LoopL10n.current.launch2_launch2AtmosphereSwitch2,
  Launch2Stage.closedNoHolders =>
    LoopL10n.current.launch2_launch2FormatClosedNoHolders,
  Launch2Stage.priority => LoopL10n.current.launch2_launch2FormatPriority,
  Launch2Stage.public => LoopL10n.current.launch2_launch2FormatPublic,
  Launch2Stage.graduated => LoopL10n.current.common_graduated,
  Launch2Stage.paused => LoopL10n.current.common_paused,
};

/// `409 DATA_STALE` for a stage that takes no order (contract §3.3).
const String launch2StageMismatchCode = 'LAUNCH2_STAGE_MISMATCH';

/// The one sentence for `closed_no_holders` (decision 0142). Only instances
/// of a v2-generation Factory can still reach it (loop-api decision 0122).
String get launch2ClosedNoHoldersText =>
    LoopL10n.current.launch2_launch2FormatLaunch2ClosedNoHoldersText;

/// A v3 sale that ended with no NFT minted opened the public round directly
/// (`snapshot.status = opened_without_holders`, decision 0144).
String get launch2OpenedWithoutHoldersText =>
    LoopL10n.current.launch2_launch2FormatLaunch2OpenedWithoutHoldersText;

/// The second half of the stage bar (contract §2 「App」 column).
String launch2StageCaption(Launch2Stage stage) => switch (stage) {
  Launch2Stage.upcoming => LoopL10n.current.launch2_launch2FormatUpcoming2,
  Launch2Stage.nftSale => LoopL10n.current.launch2_launch2FormatNftSale2,
  Launch2Stage.snapshotPending =>
    LoopL10n.current.launch2_launch2FormatSnapshotPending,
  Launch2Stage.closedNoHolders => launch2ClosedNoHoldersText,
  Launch2Stage.priority => LoopL10n.current.launch2_launch2FormatPriority2,
  Launch2Stage.public => LoopL10n.current.launch2_launch2FormatPublic2,
  Launch2Stage.graduated => LoopL10n.current.launch2_launch2FormatGraduated,
  Launch2Stage.paused => LoopL10n.current.launch2_launch2FormatPaused,
};

/// A remaining time on the countdown face: `2天 03:12:05`, `03:12:05`,
/// `12:05`. A time already passed reads `00:00`, never a negative figure.
String launch2CountdownText(Duration remaining) {
  final total = remaining.isNegative ? 0 : remaining.inSeconds;
  final days = total ~/ 86400;
  final hours = (total % 86400) ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  if (days > 0) {
    return LoopL10n.current.launch2_launch2FormatLaunch2CountdownText(
      days,
      two(hours),
      two(minutes),
      two(seconds),
    );
  }
  if (hours > 0) return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  return '${two(minutes)}:${two(seconds)}';
}

/// 「12.34 USD1」.
String launch2Usd1Label(Decimal value, {int maxFractionDigits = 2}) =>
    '${loopFormatDecimal(value, maxFractionDigits: maxFractionDigits)} USD1';

/// A MEME amount, exact to two decimals and grouped.
String launch2MemeFigure(Decimal value) =>
    loopFormatDecimal(value, maxFractionDigits: 2);

String launch2MemeLabel(Decimal value, String ticker) =>
    '${launch2MemeFigure(value)} ${loopTickerLabel(ticker)}';

/// A MEME amount in a summary slot: exact below 100,000, `K`/`M`/`B` above.
String launch2MemeCompact(Decimal value) {
  if (value < Decimal.fromInt(100000)) {
    return loopFormatDecimal(value, maxFractionDigits: 2);
  }
  return loopFormatCompactFigure(value, usd: false);
}

/// A curve price at the 行情 column's precision with its leading zeros
/// folded: `$0.0₄4166`.
String launch2PriceLabel(Decimal price) =>
    loopFoldedZerosPrice(marketRowPrice(price));

/// Basis points as a percentage with up to two decimals (`33.27%`, `10%`).
String launch2BpsLabel(int bps) {
  final value = Decimal.fromInt(bps).shift(-2);
  return '${loopFormatDecimal(value, maxFractionDigits: 2)}%';
}

/// The fraction a bar fills, in drawing space only.
double launch2Fraction(int bps) => bps.clamp(0, 10000) / 10000;

/// A [part] of [whole] as a drawing fraction; `0` when [whole] is not
/// positive.
double launch2Share(Decimal part, Decimal whole) {
  if (whole <= Decimal.zero) return 0;
  final ratio = (part / whole).toDecimal(scaleOnInfinitePrecision: 6);
  return double.parse(ratio.toString()).clamp(0.0, 1.0);
}

String launch2ShortAddress(String address) => loopTruncatedAddress(address);

/// The decimal string a field receives for an exact amount: plain digits,
/// no grouping, at most 18 decimals.
String launch2InputText(Decimal value) {
  final text = value.toString();
  if (!text.contains('.')) return text;
  final parts = text.split('.');
  final fraction = parts[1].length > 18 ? parts[1].substring(0, 18) : parts[1];
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.isEmpty ? parts[0] : '${parts[0]}.$trimmed';
}

/// What a typed amount means, or `null` when it is not a positive amount the
/// contract accepts (`^(0|[1-9][0-9]{0,40})(\.[0-9]{1,18})?$`).
Decimal? launch2AmountFromInput(String text) {
  final value = text.trim();
  if (!RegExp(r'^(0|[1-9][0-9]{0,40})(\.[0-9]{1,18})?$').hasMatch(value)) {
    return null;
  }
  final parsed = Decimal.tryParse(value);
  if (parsed == null || parsed <= Decimal.zero) return null;
  return parsed;
}

/// Why an instance is held.
String launch2HoldReasonText(Launch2HoldReason? reason) => switch (reason) {
  Launch2HoldReason.deployedEventMismatch =>
    LoopL10n.current.launch2_launch2FormatDeployedEventMismatch,
  Launch2HoldReason.activationMissing =>
    LoopL10n.current.launch2_launch2FormatActivationMissing,
  null => LoopL10n.current.launch2_launch2FormatSwitch,
};

/// The pre-S209 constant per-address curve cap, 5,000,000 MEME (decision
/// 0197): the fallback when an instance's own cap is not readable.
final Decimal launch2DefaultCurveCap = Decimal.fromInt(5000000);

/// Decision 0197 (loop-api 0152): an instance's per-address curve cap is a
/// Factory parameter from S209 on. The server reads it from the verified
/// curve into `template.perAddressCap` / `quote.quota.capMeme`; a missing or
/// non-positive figure reads as the old 5,000,000.
Decimal launch2CurveCapOf(Decimal? cap) =>
    cap == null || cap <= Decimal.zero ? launch2DefaultCurveCap : cap;

/// A whole-token count with thousands separators: 「5,000,000」.
String launch2CurveCapFigure(Decimal? cap) =>
    loopFormatDecimal(launch2CurveCapOf(cap).floor(), maxFractionDigits: 0);

/// Where a LoopDynamic buy's base fee is taken from (decision 0197): the
/// one wording the pool quote and the creator's template card share
/// (decision 0198).
String launch2BuyFeeSideText({required bool fromUsd1}) => fromUsd1
    ? LoopL10n.current.launch2_launch2FormatSwitch2
    : LoopL10n.current.launch2_launch2FormatS;

/// 「每个地址最多买 N 枚」 for an instance's cap (decision 0197).
String launch2CurveCapSentence(Decimal? cap) => LoopL10n.current
    .launch2_launch2FormatLaunch2CurveCapSentence(launch2CurveCapFigure(cap));

/// `LAUNCH2_QUOTA_EXHAUSTED` for an instance's cap (decision 0197).
String launch2QuotaExhaustedText(Decimal? cap) => LoopL10n.current
    .launch2_launch2FormatLaunch2QuotaExhaustedText(launch2CurveCapFigure(cap));

/// What bounds the MAX, said as the reason a larger amount is refused.
/// [cap] is the instance's per-address curve cap (decision 0197).
String launch2LimitedByText(Launch2LimitedBy limitedBy, {Decimal? cap}) =>
    switch (limitedBy) {
      Launch2LimitedBy.quota => LoopL10n.current.launch2_launch2FormatQuota(
        launch2CurveCapFigure(cap),
      ),
      Launch2LimitedBy.inventory =>
        LoopL10n.current.launch2_launch2FormatInventory,
      Launch2LimitedBy.balance => LoopL10n.current.launch2_launch2FormatBalance,
      Launch2LimitedBy.soldSupply =>
        LoopL10n.current.launch2_launch2FormatSoldSupply,
      Launch2LimitedBy.closed => LoopL10n.current.launch2_launch2FormatClosed,
    };

/// The buyback's `nextOrderBlockedReason` in zh-CN; `null` reads as ready
/// (loop-api decision 0122 redefined the set: the v3 executor has no price
/// protection, `BUYBACK_LEGACY_PRICE_PROTECTION` is v2 instances only).
String launch2BuybackBlockedText(String? reasonCode) => switch (reasonCode) {
  null => LoopL10n.current.launch2_launch2FormatSwitch3,
  'BUYBACK_PAUSED' => LoopL10n.current.launch2_launch2FormatSwitch4,
  'BUYBACK_NOT_GRADUATED' => LoopL10n.current.launch2_launch2FormatSwitch5,
  'BUYBACK_NO_BUDGET' => LoopL10n.current.launch2_launch2FormatSwitch6,
  'BUYBACK_TOO_SOON' => LoopL10n.current.launch2_launch2FormatSwitch7,
  'BUYBACK_PRINCIPAL_INSUFFICIENT' =>
    LoopL10n.current.launch2_launch2FormatSwitch8,
  'BUYBACK_QUOTE_UNAVAILABLE' => LoopL10n.current.launch2_launch2FormatSwitch9,
  'BUYBACK_LEGACY_PRICE_PROTECTION' =>
    LoopL10n.current.launch2_launch2FormatSwitch10,
  _ => LoopL10n.current.launch2_launch2FormatSwitch11,
};

/// The keeper line of the buyback panel (decision 0146): whether the
/// server-side buyback keeper (`buyback.keeper`, loop-api decision 0121) is
/// running or held, in one sentence.
@immutable
final class Launch2KeeperLine {
  const Launch2KeeperLine({
    required this.text,
    required this.held,
    this.reason,
    this.reasonCode,
    this.nextEligibleAt,
  });

  final String text;

  /// 「回购暂缓」: the keeper has a blocking reason. Otherwise it is running.
  final bool held;

  /// A held keeper's reason alone (no 「回购暂缓：」, no time).
  final String? reason;
  final String? reasonCode;
  final DateTime? nextEligibleAt;
}

/// Decision 0146 (coordinator ruling): `null` — the keeper never looked at
/// this instance (contract §5: show the ledger only) or the buyback is
/// paused (the panel already says 回购已暂停). A `rejected` / `failed`
/// attempt is 「回购暂缓：<原因>」; `pending` / `broadcast` / `confirmed`, and a
/// `rejected` that is only the 10 s spacing, are 「自动回购运行中 · 上次 <时间>」
/// where the time is the ledger's last execution.
Launch2KeeperLine? launch2KeeperLine(Launch2BuybackSummary summary) {
  final keeper = summary.keeper;
  if (keeper == null || summary.paused) return null;
  final code = keeper.reasonCode;
  final running = switch (keeper.lastResult) {
    Launch2KeeperResult.pending ||
    Launch2KeeperResult.broadcast ||
    Launch2KeeperResult.confirmed => true,
    Launch2KeeperResult.rejected => code == 'LAUNCH2_BUYBACK_TOO_SOON',
    Launch2KeeperResult.failed => false,
  };
  if (running) {
    final last = summary.lastExecutedAt;
    final inFlight =
        keeper.lastResult == Launch2KeeperResult.pending ||
        keeper.lastResult == Launch2KeeperResult.broadcast;
    return Launch2KeeperLine(
      held: false,
      text: <String>[
        LoopL10n.current.launch2_launch2FormatLaunch2KeeperLine,
        if (inFlight) LoopL10n.current.launch2_launch2FormatLaunch2KeeperLine2,
        if (last != null)
          LoopL10n.current.launch2_launch2FormatLaunch2KeeperLine3(
            loopDateTimeLabel(last),
          ),
      ].join(' · '),
    );
  }
  final reason = keeper.lastResult == Launch2KeeperResult.failed
      ? launch2KeeperFailureText(code)
      : launch2KeeperRefusalText(code);
  final next = keeper.nextEligibleAt;
  return Launch2KeeperLine(
    held: true,
    reason: reason,
    reasonCode: code,
    nextEligibleAt: next,
    text: <String>[
      LoopL10n.current.launch2_launch2FormatLaunch2KeeperLine4(reason),
      if (next != null)
        LoopL10n.current.launch2_launch2FormatLaunch2KeeperLine5(
          loopClockLabel(next),
        ),
    ].join(' · '),
  );
}

/// One kind of hold, whichever source names it: the live read's
/// `BUYBACK_*` and the keeper's `LAUNCH2_BUYBACK_*`, the three legacy price
/// codes as one.
String? _buybackHoldKind(String? code) {
  if (code == null) return null;
  final bare = code.startsWith('LAUNCH2_') ? code.substring(8) : code;
  return switch (bare) {
    'BUYBACK_REFERENCE_UNAVAILABLE' ||
    'BUYBACK_SPOT_OUTSIDE_PROTECTION' ||
    'BUYBACK_OUTPUT_BELOW_PROTECTION' => 'BUYBACK_LEGACY_PRICE_PROTECTION',
    _ => bare,
  };
}

/// The merged hold of the buyback card (decisions 0148 / 0150): the reason
/// on the first line, where it came from and the keeper's retry time on the
/// second, so a 360-wide screen never cuts the time off.
@immutable
final class Launch2BuybackHeldLine {
  const Launch2BuybackHeldLine({required this.reason, this.detail});

  /// 「下一笔暂缓：<原因>」 — may wrap, never truncated.
  final String reason;

  /// 「来源：链上读数 · 自动回购 · HH:mm 后再试」, or the retry time alone
  /// when the two sources name different reasons (each is tagged inline).
  final String? detail;

  String get text => <String>[reason, ?detail].join('\n');
}

/// Decision 0148: when the live read says the next order is held
/// ([liveBlockedReason]) and the keeper's last attempt was held too, the
/// buyback card says it once instead of two rows from two sources.
/// Decision 0150: two lines — the reason, then 「来源：链上读数 · 自动回购」
/// with the keeper's retry time. `null` when either is not held (each keeps
/// its own row).
Launch2BuybackHeldLine? launch2BuybackHeldLine({
  required String? liveBlockedReason,
  required Launch2KeeperLine? keeper,
}) {
  if (liveBlockedReason == null || keeper == null || !keeper.held) {
    return null;
  }
  final live = launch2BuybackBlockedText(liveBlockedReason)
      .replaceAll(LoopL10n.current.launch2_launch2FormatReplaceAll, '')
      .replaceAll(LoopL10n.current.launch2_launch2FormatReplaceAll2, '');
  final next = keeper.nextEligibleAt;
  final retry = next == null
      ? null
      : LoopL10n.current.launch2_launch2FormatLaunch2KeeperLine5(
          loopClockLabel(next),
        );
  final same =
      _buybackHoldKind(liveBlockedReason) ==
      _buybackHoldKind(keeper.reasonCode);
  if (same) {
    return Launch2BuybackHeldLine(
      reason: LoopL10n.current.launch2_launch2FormatReason(live),
      detail: <String>[
        LoopL10n.current.launch2_launch2FormatLaunch2BuybackHeldLine,
        ?retry,
      ].join(' · '),
    );
  }
  return Launch2BuybackHeldLine(
    reason: LoopL10n.current.launch2_launch2FormatReason2(live, keeper.reason),
    detail: retry,
  );
}

/// Why the keeper's simulation was refused (`lastResult: rejected`), per
/// the frontend contract §3.2 (loop-api decisions 0121 / 0122).
String launch2KeeperRefusalText(String? reasonCode) => switch (reasonCode) {
  'LAUNCH2_BUYBACK_PRINCIPAL_INSUFFICIENT' =>
    LoopL10n.current.launch2_launch2FormatSwitch12,
  'LAUNCH2_BUYBACK_NO_BUDGET' => LoopL10n.current.launch2_launch2FormatSwitch6,
  'LAUNCH2_BUYBACK_PAUSED' => LoopL10n.current.launch2_launch2FormatSwitch13,
  'LAUNCH2_BUYBACK_NOT_GRADUATED' =>
    LoopL10n.current.launch2_launch2FormatSwitch14,
  'LAUNCH2_BUYBACK_NOT_KEEPER' ||
  'LAUNCH2_BUYBACK_KEEPER_NOT_AUTHORIZED' ||
  'LAUNCH2_BUYBACK_KEEPER_CHAIN_MISMATCH' =>
    LoopL10n.current.launch2_launch2FormatSwitch15,
  'LAUNCH2_BUYBACK_ESCROW_MISMATCH' =>
    LoopL10n.current.launch2_launch2FormatSwitch16,
  'LAUNCH2_BUYBACK_NO_OUTPUT' => LoopL10n.current.launch2_launch2FormatSwitch17,
  'LAUNCH2_BUYBACK_REFERENCE_UNAVAILABLE' ||
  'LAUNCH2_BUYBACK_SPOT_OUTSIDE_PROTECTION' ||
  'LAUNCH2_BUYBACK_OUTPUT_BELOW_PROTECTION' =>
    LoopL10n.current.launch2_launch2FormatSwitch18,
  'LAUNCH2_BUYBACK_GAS_PRICE_ABOVE_CAP' =>
    LoopL10n.current.launch2_launch2FormatSwitch19,
  'LAUNCH2_BUYBACK_CONTRACT_REVERTED' =>
    LoopL10n.current.launch2_launch2FormatSwitch20,
  _ => LoopL10n.current.launch2_launch2FormatSwitch11,
};

/// Why a prepared or sent buyback did not execute (`lastResult: failed`).
String launch2KeeperFailureText(String? reasonCode) => switch (reasonCode) {
  'LAUNCH2_BUYBACK_PAUSED' => LoopL10n.current.launch2_launch2FormatSwitch13,
  'LAUNCH2_BUYBACK_KEEPER_INSUFFICIENT_FUNDS' =>
    LoopL10n.current.launch2_launch2FormatSwitch21,
  'LAUNCH2_BUYBACK_GAS_ABOVE_CAP' =>
    LoopL10n.current.launch2_launch2FormatSwitch22,
  _ => LoopL10n.current.launch2_launch2FormatSwitch23,
};

/// zh-CN for the server's own `launch2` refusal rules (contract §4). Every
/// line says what did not happen.
/// The chain guard's hold, in one sentence (decision 0161) — the banner,
/// the panels' line and the refusal codes all say the same thing.
String get launch2Usd1PausedText =>
    LoopL10n.current.launch2_launch2FormatLaunch2Usd1PausedText;
String get launch2AddressFrozenText =>
    LoopL10n.current.launch2_launch2FormatLaunch2AddressFrozenText;

String launch2TradingHoldText(Launch2TradingHoldKind kind) => switch (kind) {
  Launch2TradingHoldKind.usd1Paused => launch2Usd1PausedText,
  Launch2TradingHoldKind.addressFrozen => launch2AddressFrozenText,
};

/// 「自 14:05 起」 today, 「自 2026-10-13 14:05 起」 on an earlier day.
String launch2TradingHoldSinceText(DateTime since, {DateTime? now}) {
  final local = since.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  return sameDay
      ? LoopL10n.current.launch2_launch2FormatLaunch2TradingHoldSinceText(
          loopLocalClockLabel(since),
        )
      : LoopL10n.current.launch2_launch2FormatLaunch2TradingHoldSinceText(
          loopLocalTimestampLabel(since),
        );
}

/// `LAUNCH2_QUOTE_ZERO` (decision 0225): the amount buys less than one
/// unit. Was 「报价已变化，请重新报价」, shared with the deadline refusal.
String get launch2QuoteZeroText =>
    LoopL10n.current.launch2_launch2FormatLaunch2QuoteZeroText;

/// The two balance refusals a quote or a prepare may answer with (`409
/// INSUFFICIENT_BALANCE`, loop-api S266). Decision 0225: a quote refused
/// this way says the shortfall and offers the funding links.
const String launch2Usd1BalanceInsufficientCode =
    'LAUNCH2_USD1_BALANCE_INSUFFICIENT';
const String launch2MemeBalanceInsufficientCode =
    'LAUNCH2_MEME_BALANCE_INSUFFICIENT';

/// Whether [failure] is the wallet being short, not the quote failing.
bool launch2IsBalanceRefusal(LoopChainException failure) =>
    failure.reasonCode == launch2Usd1BalanceInsufficientCode ||
    failure.reasonCode == launch2MemeBalanceInsufficientCode;

/// Decision 0225: the buy side with a USD1 balance read as zero, said under
/// the amount field before any quote is asked.
String get launch2NoUsd1Text =>
    LoopL10n.current.launch2_launch2FormatLaunch2NoUsd1Text;

/// Decision 0225: the sell side with this token's balance read as zero.
String get launch2NoMemeText =>
    LoopL10n.current.launch2_launch2FormatLaunch2NoMemeText;

String launch2ReasonText(String? reasonCode) => switch (reasonCode) {
  'LAUNCH2_USD1_PAUSED' => launch2Usd1PausedText,
  'LAUNCH2_ADDRESS_FROZEN' => launch2AddressFrozenText,
  'LAUNCH2_INSTANCE_NOT_FOUND' =>
    LoopL10n.current.launch2_launch2FormatSwitch24,
  launch2StageMismatchCode => LoopL10n.current.launch2_launch2FormatSwitch25,
  'LAUNCH2_SELL_NOT_OPEN' => LoopL10n.current.launch2_launch2FormatSwitch26,
  'LAUNCH2_SOLD_OUT' => LoopL10n.current.launch2_launch2FormatSwitch27,
  // Decision 0197: the cap is per instance; the trade panel names it
  // ([launch2QuotaExhaustedText]).
  'LAUNCH2_QUOTA_EXHAUSTED' => LoopL10n.current.launch2_launch2FormatSwitch28,
  'LAUNCH2_INSTANCE_PAUSED' => LoopL10n.current.launch2_launch2FormatSwitch29,
  'LAUNCH2_NFT_ALREADY_MINTED' =>
    LoopL10n.current.launch2_launch2FormatSwitch30,
  'LAUNCH2_PRICE_MOVED' => LoopL10n.current.launch2_launch2FormatSwitch31,
  'LAUNCH2_QUOTE_EXPIRED' => LoopL10n.current.launch2_launch2FormatSwitch32,
  'LAUNCH2_USD1_BALANCE_INSUFFICIENT' =>
    LoopL10n.current.launch2_launch2FormatSwitch33,
  'LAUNCH2_MEME_BALANCE_INSUFFICIENT' =>
    LoopL10n.current.launch2_launch2FormatSwitch34,
  'LAUNCH2_GAS_INSUFFICIENT' => LoopL10n.current.launch2_launch2FormatSwitch35(
    loopLaunchNativeSymbolText,
  ),
  'LAUNCH2_AMOUNT_INVALID' => LoopL10n.current.launch2_launch2FormatSwitch36,
  'LAUNCH2_AMOUNT_ABOVE_MAX' => LoopL10n.current.launch2_launch2FormatSwitch37,
  'LAUNCH2_DEADLINE_TOO_FAR' => LoopL10n.current.launch2_launch2FormatSwitch38,
  // Decision 0225: the curve really priced this amount at zero units.
  'LAUNCH2_QUOTE_ZERO' => launch2QuoteZeroText,
  'LAUNCH2_WALLET_NOT_EMBEDDED' =>
    LoopL10n.current.launch2_launch2FormatSwitch39,
  'LAUNCH2_NOT_IN_SNAPSHOT' => LoopL10n.current.launch2_launch2FormatSwitch40,
  'LAUNCH2_COUNTERPARTY_NOT_INSTANCE' =>
    LoopL10n.current.launch2_launch2FormatSwitch41,
  'LAUNCH2_INTENT_EXPIRED' => LoopL10n.current.launch2_launch2FormatSwitch42,
  'LAUNCH2_SIMULATION_REVERTED' =>
    LoopL10n.current.launch2_launch2FormatSwitch43,
  'LAUNCH2_APPROVAL_REQUIRED' => LoopL10n.current.launch2_launch2FormatSwitch44,
  'LAUNCH2_SNAPSHOT_UNVERIFIED' =>
    LoopL10n.current.launch2_launch2FormatSwitch45,
  'LAUNCH2_FACTORY_NOT_CONFIGURED' || 'LAUNCH2_CHAIN_NOT_CONFIGURED' =>
    LoopL10n.current.launch2_launch2FormatSwitch46,
  'LAUNCH2_REPOSITORY_UNAVAILABLE' || 'LAUNCH2_RUNTIME_UNAVAILABLE' =>
    LoopL10n.current.launch2_launch2FormatSwitch47,
  'LAUNCH2_CHAIN_READ_FAILED' => LoopL10n.current.launch2_launch2FormatSwitch48,
  'LAUNCH2_WALLETS_UNAVAILABLE' =>
    LoopL10n.current.launch2_launch2FormatSwitch49,
  'LAUNCH2_WRITES_DISABLED' => LoopL10n.current.launch2_launch2FormatSwitch50,
  'LAUNCH2_MAINNET_SIGNING_CLOSED' =>
    LoopL10n.current.launch2_launch2FormatSwitch51,
  'LAUNCH2_MODULE_NOT_ENABLED' ||
  'LAUNCH2_CAPABILITY_ABSENT' => LoopL10n.current.launch2_launch2FormatSwitch52,
  'CANARY_CEILING_EXCEEDED' => LoopL10n.current.launch2_launch2FormatSwitch53,
  'CANARY_DAILY_CEILING_EXCEEDED' =>
    LoopL10n.current.launch2_launch2FormatSwitch54,
  'ASSET_NOT_IN_CANARY_ALLOWLIST' =>
    LoopL10n.current.launch2_launch2FormatSwitch55,
  _ => loopReasonCodeSummaryText(reasonCode),
};

/// The sentence for one failed request: the server's own rule when it named
/// one, otherwise what kind of failure it was.
String launch2FailureText(LoopChainException failure) {
  final reason = failure.reasonCode;
  if (reason != null) return launch2ReasonText(reason);
  return loopChainFailureReason(failure.kind);
}

/// One failed action, said next to the button that started it (client
/// decision 0153).
@immutable
final class Launch2ActionFailure {
  const Launch2ActionFailure(this.text, {this.topUp = false});

  final String text;

  /// A balance refusal (USD1 or tBNB): the line offers 「去充值」.
  final bool topUp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Launch2ActionFailure &&
          other.text == text &&
          other.topUp == topUp;

  @override
  int get hashCode => Object.hash(text, topUp);
}

/// zh-CN for the native-gas refusal at the button when the refusal carries
/// no figure: names the token and the fee. The symbol goes through
/// [loopDisplaySymbol] (decision 0204).
String get launch2GasShortText =>
    LoopL10n.current.launch2_launch2FormatLaunch2GasShortText(
      loopLaunchNativeSymbolText,
      loopLaunchNativeSymbolText,
    );

/// The gas refusal's line with the server's figures (decision 0156): the
/// fee ceiling the check compared and the wallet's tBNB. A missing figure
/// leaves its clause out; with neither the figure-free sentence stays.
String launch2GasFailureText(LoopChainException failure) {
  final required = _detailFigure(failure.requiredBnb);
  final balance = _detailFigure(failure.balanceBnb);
  String bnb(Decimal value) =>
      '${loopFormatDecimal(value, maxFractionDigits: 8)} $loopLaunchNativeSymbolText';
  if (required == null && balance == null) return launch2GasShortText;
  final parts = <String>[
    if (required != null)
      LoopL10n.current.launch2_launch2FormatLaunch2GasFailureText(
        bnb(required),
      ),
    if (balance != null)
      LoopL10n.current.launch2_launch2FormatLaunch2GasFailureText2(
        bnb(balance),
      ),
  ];
  return LoopL10n.current.launch2_launch2FormatLaunch2GasFailureText3(
    loopLaunchNativeSymbolText,
    parts.join(LoopL10n.current.common_listSeparator),
  );
}

Decimal? _detailFigure(String? raw) =>
    raw == null ? null : Decimal.tryParse(raw);

/// The line for one failed prepare, with the figures the refusal carried.
///
/// `LAUNCH2_USD1_BALANCE_INSUFFICIENT` says what the action needs — the
/// server's `requiredUsd1` (NFT) or `requiredAmountIn` (official pool),
/// else [requested], what this request asked to spend — and what the
/// wallet has: the server's `balanceUsd1` first (decision 0156), else
/// `maxAmountIn` when [maxIsBalance] (the official pool sends its balance
/// there), else a balance the page has read ([usd1Balance]). On the curve
/// `maxAmountIn` is the balance-limited maximum and is said as 「最多可付」.
/// A MEME shortfall says the holding from `balanceMeme` the same way, and
/// `LAUNCH2_GAS_INSUFFICIENT` names the fee ceiling (`requiredBnb`) and the
/// wallet's tBNB (`balanceBnb`). A refusal without figures still gets its
/// sentence; nothing is invented.
///
/// [fallback] words every other refusal (the curve's or the pool's own
/// catalogue).
Launch2ActionFailure launch2ActionFailure(
  LoopChainException failure, {
  String Function(LoopChainException failure) fallback = launch2FailureText,
  Decimal? requested,
  Decimal? usd1Balance,
  bool maxIsBalance = false,
  String ticker = '',
}) {
  final reason = failure.reasonCode;
  final required =
      _detailFigure(failure.requiredUsd1) ??
      _detailFigure(failure.requiredAmountIn) ??
      requested;
  final max = _detailFigure(failure.maxAmountIn);
  switch (reason) {
    case 'LAUNCH2_USD1_BALANCE_INSUFFICIENT':
      String usd1(Decimal value) =>
          launch2Usd1Label(value, maxFractionDigits: 4);
      final current =
          _detailFigure(failure.balanceUsd1) ??
          (maxIsBalance ? max : usd1Balance);
      final parts = <String>[
        if (required != null)
          LoopL10n.current.launch2_launch2FormatSwitch56(usd1(required)),
        if (current != null)
          LoopL10n.current.launch2_launch2FormatSwitch57(usd1(current))
        else if (max != null)
          LoopL10n.current.launch2_launch2FormatSwitch58(usd1(max)),
      ];
      return Launch2ActionFailure(
        parts.isEmpty
            ? fallback(failure)
            : LoopL10n.current.launch2_launch2FormatLaunch2ActionFailure(
                parts.join(LoopL10n.current.common_listSeparator),
              ),
        topUp: true,
      );
    case 'LAUNCH2_MEME_BALANCE_INSUFFICIENT':
      String meme(Decimal value) => launch2MemeLabel(value, ticker);
      final holding =
          _detailFigure(failure.balanceMeme) ?? (maxIsBalance ? max : null);
      final parts = <String>[
        if (required != null)
          LoopL10n.current.launch2_launch2FormatSwitch56(meme(required)),
        if (holding != null)
          LoopL10n.current.launch2_launch2FormatSwitch60(meme(holding))
        else if (max != null)
          LoopL10n.current.launch2_launch2FormatSwitch61(meme(max)),
      ];
      return Launch2ActionFailure(
        parts.isEmpty
            ? fallback(failure)
            : LoopL10n.current.launch2_launch2FormatLaunch2ActionFailure2(
                parts.join(LoopL10n.current.common_listSeparator),
              ),
      );
    case 'LAUNCH2_GAS_INSUFFICIENT':
      return Launch2ActionFailure(launch2GasFailureText(failure), topUp: true);
  }
  return Launch2ActionFailure(
    fallback(failure),
    topUp:
        reason == null &&
        failure.kind == LoopChainFailureKind.insufficientBalance,
  );
}

/// 名单生成中's title, by the publication attempt (loop-api decision 0118
/// display rule). The priority hour opens only with the stage itself.
String launch2SnapshotPendingTitle(Launch2Snapshot snapshot) =>
    switch (snapshot.publication?.status) {
      null => LoopL10n.current.launch2_launch2AtmosphereSwitch2,
      Launch2PublicationStatus.pending || Launch2PublicationStatus.broadcast =>
        LoopL10n.current.launch2_launch2FormatBroadcast,
      Launch2PublicationStatus.confirmed =>
        snapshot.published
            ? LoopL10n.current.launch2_launch2FormatSwitch62
            : LoopL10n.current.launch2_launch2FormatS3,
      Launch2PublicationStatus.failed || Launch2PublicationStatus.mismatch =>
        LoopL10n.current.launch2_launch2FormatMismatch,
    };

/// The project page's stage label (the folio kicker). Decision 0203
/// (S234-3): while the snapshot is pending it is the same publication state
/// as the body ([launch2SnapshotPendingTitle]), so the card never says
/// 「名单生成中」 over a body that already reads 「名单发布中」.
String launch2InstanceStageLabel(Launch2InstanceDetail detail) =>
    detail.row.stage == Launch2Stage.snapshotPending
    ? launch2SnapshotPendingTitle(detail.snapshot)
    : launch2StageLabel(detail.row.stage);

/// The line under it: the cutoff block and what opens next.
String launch2SnapshotPendingMessage(Launch2Snapshot snapshot) {
  final block = snapshot.cutoffBlockNumber ?? snapshot.publication?.cutoffBlock;
  if (block == null) {
    return LoopL10n.current.launch2_launch2FormatLaunch2SnapshotPendingMessage;
  }
  return LoopL10n.current.launch2_launch2FormatLaunch2SnapshotPendingMessage2(
    loopGroupedFigure(block.toString()),
  );
}

/// Whether the page draws the NFT名单公布 block (decision 0202): the list was
/// published and the instance has moved past it (提前购, 公开内盘, 已毕业).
/// A public round opened without holders has no list.
bool launch2SnapshotPublishedShown(Launch2InstanceDetail detail) =>
    detail.snapshot.published &&
    detail.snapshot.openedWithoutHolders == null &&
    (detail.stage == Launch2Stage.priority ||
        detail.stage == Launch2Stage.public ||
        detail.stage == Launch2Stage.graduated);

/// 核验 in the NFT名单公布 block (`snapshot.verification`); `null` when the
/// server said nothing.
String? launch2SnapshotVerificationText(
  Launch2SnapshotVerification? verification,
) => switch (verification) {
  null => null,
  Launch2SnapshotVerification.verified =>
    LoopL10n.current.launch2_launch2FormatVerified,
  Launch2SnapshotVerification.pending =>
    LoopL10n.current.launch2Creator_launch2Confirmed,
  Launch2SnapshotVerification.mismatch =>
    LoopL10n.current.launch2_launch2FormatMismatch2,
};

/// The BscScan page of [hash] on [chainId] (decision 0202): the main
/// network's for the primary slot, the testnet's for the Launch testnet,
/// nothing for a chain LOOP does not publish or a missing hash.
Uri? launch2ExplorerTxUri(String chainId, String? hash) {
  if (hash == null) return null;
  final host = switch (chainId) {
    loopPrimaryChainId => 'bscscan.com',
    loopLaunchTestnetChainId => 'testnet.bscscan.com',
    _ => null,
  };
  return host == null ? null : Uri.https(host, '/tx/$hash');
}

/// How long an NFT sale runs: 「7 天」, 「1 小时」 or 「90 分钟」.
String launch2SaleDurationLabel(Launch2NftSale sale) {
  final minutes = sale.endAt.difference(sale.startAt).inMinutes;
  final hours = minutes / 60;
  if (hours >= 24 && hours % 24 == 0) {
    return LoopL10n.current.launch2Creator_launch2Launch2DurationLabel(
      hours ~/ 24,
    );
  }
  if (hours == hours.roundToDouble()) {
    return LoopL10n.current.launch2Creator_launch2CreateLeadLabel(
      hours.toInt(),
    );
  }
  return LoopL10n.current.launch2Creator_launch2CreateLeadLabel2(minutes);
}

/// A countdown said aloud (decision 0163): 「2 天 3 小时」, 「2 小时 14 分」,
/// 「14 分」, 「不到 1 分」.
String launch2SpokenDuration(Duration remaining) {
  final total = remaining.isNegative ? 0 : remaining.inMinutes;
  final days = total ~/ 1440;
  final hours = (total % 1440) ~/ 60;
  final minutes = total % 60;
  if (days > 0) {
    return hours > 0
        ? LoopL10n.current.launch2_launch2FormatLaunch2SpokenDuration(
            days,
            hours,
          )
        : LoopL10n.current.launch2Creator_launch2Launch2DurationLabel(days);
  }
  if (hours > 0) {
    return LoopL10n.current.launch2_launch2FormatLaunch2SpokenDuration2(
      hours,
      minutes,
    );
  }
  if (minutes > 0) {
    return LoopL10n.current.launch2_launch2FormatLaunch2SpokenDuration3(
      minutes,
    );
  }
  return LoopL10n.current.launch2_launch2FormatLaunch2SpokenDuration4;
}
