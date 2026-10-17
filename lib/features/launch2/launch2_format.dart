import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';

// ---------------------------------------------------------------------------
// Display helpers for MEME v2 (client decision 0139)
// ---------------------------------------------------------------------------
//
// Rounding and grouping happen here and nowhere else. USD1 is read at par
// with the dollar, the way the contract (`priceSource: usd1_par`) reads it.

/// The stage's short name, as the list pill and the page's stage bar say it.
String launch2StageLabel(Launch2Stage stage) => switch (stage) {
  Launch2Stage.upcoming => '即将开售',
  Launch2Stage.nftSale => 'NFT 发售中',
  Launch2Stage.snapshotPending => '名单生成中',
  Launch2Stage.closedNoHolders => '已关闭',
  Launch2Stage.priority => '提前购',
  Launch2Stage.public => '公开内盘',
  Launch2Stage.graduated => '已毕业',
  Launch2Stage.paused => '已暂停',
};

/// `409 DATA_STALE` for a stage that takes no order (contract §3.3).
const String launch2StageMismatchCode = 'LAUNCH2_STAGE_MISMATCH';

/// The one sentence for `closed_no_holders` (decision 0142). Only instances
/// of a v2-generation Factory can still reach it (loop-api decision 0122).
const String launch2ClosedNoHoldersText = '无人认购，已关闭';

/// A v3 sale that ended with no NFT minted opened the public round directly
/// (`snapshot.status = opened_without_holders`, decision 0144).
const String launch2OpenedWithoutHoldersText = '无 NFT 持有人，直接开放公开内盘';

/// The second half of the stage bar (contract §2 「App」 column).
String launch2StageCaption(Launch2Stage stage) => switch (stage) {
  Launch2Stage.upcoming => '开售倒计时',
  Launch2Stage.nftSale => '剩余',
  Launch2Stage.snapshotPending => '名单发布后开始 1 小时提前购',
  Launch2Stage.closedNoHolders => launch2ClosedNoHoldersText,
  Launch2Stage.priority => '持有人优先 · 剩余',
  Launch2Stage.public => '人人可买，卖满即毕业',
  Launch2Stage.graduated => '官方池交易中',
  Launch2Stage.paused => '暂停中',
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
  if (days > 0) return '$days天 ${two(hours)}:${two(minutes)}:${two(seconds)}';
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
  Launch2HoldReason.deployedEventMismatch => '链上部署记录与登记不一致，平台正在核对',
  Launch2HoldReason.activationMissing => '链上还没有看到激活记录，平台正在核对',
  null => '平台正在核对这个项目',
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
String launch2BuyFeeSideText({required bool fromUsd1}) =>
    fromUsd1 ? '从付出的 USD1 扣' : '从到手的 MEME 扣';

/// 「每个地址最多买 N 枚」 for an instance's cap (decision 0197).
String launch2CurveCapSentence(Decimal? cap) =>
    '每个地址最多买 ${launch2CurveCapFigure(cap)} 枚';

/// `LAUNCH2_QUOTA_EXHAUSTED` for an instance's cap (decision 0197).
String launch2QuotaExhaustedText(Decimal? cap) =>
    '已用完单地址累计 ${launch2CurveCapFigure(cap)} 枚额度';

/// What bounds the MAX, said as the reason a larger amount is refused.
/// [cap] is the instance's per-address curve cap (decision 0197).
String launch2LimitedByText(Launch2LimitedBy limitedBy, {Decimal? cap}) =>
    switch (limitedBy) {
      Launch2LimitedBy.quota => '单地址累计上限 ${launch2CurveCapFigure(cap)} 枚',
      Launch2LimitedBy.inventory => '内盘剩余库存',
      Launch2LimitedBy.balance => '钱包余额',
      Launch2LimitedBy.soldSupply => '内盘可卖数量',
      Launch2LimitedBy.closed => '当前阶段不可交易',
    };

/// The buyback's `nextOrderBlockedReason` in zh-CN; `null` reads as ready
/// (loop-api decision 0122 redefined the set: the v3 executor has no price
/// protection, `BUYBACK_LEGACY_PRICE_PROTECTION` is v2 instances only).
String launch2BuybackBlockedText(String? reasonCode) => switch (reasonCode) {
  null => '下一笔可以执行',
  'BUYBACK_PAUSED' => '回购已暂停',
  'BUYBACK_NOT_GRADUATED' => '毕业后才开始回购',
  'BUYBACK_NO_BUDGET' => '托管余额不足一笔',
  'BUYBACK_TOO_SOON' => '距上一笔不到 10 秒，稍后执行',
  'BUYBACK_PRINCIPAL_INSUFFICIENT' => '官方池本金保护：本金不足 10,000 USD1 或单笔超过 1%',
  'BUYBACK_QUOTE_UNAVAILABLE' => '合约报价暂时读不到，暂不执行',
  'BUYBACK_LEGACY_PRICE_PROTECTION' => '旧版合约价格保护生效，暂不执行',
  _ => '暂不执行',
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
        '自动回购运行中',
        if (inFlight) '一笔正在上链',
        if (last != null) '上次 ${loopDateTimeLabel(last)}',
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
      '回购暂缓：$reason',
      if (next != null) '${loopClockLabel(next)} 后再试',
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
      .replaceAll('，暂不执行', '')
      .replaceAll('，稍后执行', '');
  final next = keeper.nextEligibleAt;
  final retry = next == null ? null : '${loopClockLabel(next)} 后再试';
  final same =
      _buybackHoldKind(liveBlockedReason) ==
      _buybackHoldKind(keeper.reasonCode);
  if (same) {
    return Launch2BuybackHeldLine(
      reason: '下一笔暂缓：$live',
      detail: <String>['来源：链上读数 · 自动回购', ?retry].join(' · '),
    );
  }
  return Launch2BuybackHeldLine(
    reason: '下一笔暂缓：$live（链上读数）；${keeper.reason}（自动回购）',
    detail: retry,
  );
}

/// Why the keeper's simulation was refused (`lastResult: rejected`), per
/// the frontend contract §3.2 (loop-api decisions 0121 / 0122).
String launch2KeeperRefusalText(String? reasonCode) => switch (reasonCode) {
  'LAUNCH2_BUYBACK_PRINCIPAL_INSUFFICIENT' =>
    '官方池本金保护，本金不足 10,000 USD1 或单笔超过 1%',
  'LAUNCH2_BUYBACK_NO_BUDGET' => '托管余额不足一笔',
  'LAUNCH2_BUYBACK_PAUSED' => '合约回购已暂停',
  'LAUNCH2_BUYBACK_NOT_GRADUATED' => '项目还没有毕业',
  'LAUNCH2_BUYBACK_NOT_KEEPER' ||
  'LAUNCH2_BUYBACK_KEEPER_NOT_AUTHORIZED' ||
  'LAUNCH2_BUYBACK_KEEPER_CHAIN_MISMATCH' => '回购执行账户未就绪，平台处理中',
  'LAUNCH2_BUYBACK_ESCROW_MISMATCH' => '托管记录与链上不一致，平台核对中',
  'LAUNCH2_BUYBACK_NO_OUTPUT' => '成交到账为 0，平台处理中',
  'LAUNCH2_BUYBACK_REFERENCE_UNAVAILABLE' ||
  'LAUNCH2_BUYBACK_SPOT_OUTSIDE_PROTECTION' ||
  'LAUNCH2_BUYBACK_OUTPUT_BELOW_PROTECTION' => '旧版合约价格保护生效',
  'LAUNCH2_BUYBACK_GAS_PRICE_ABOVE_CAP' => '链上手续费过高',
  'LAUNCH2_BUYBACK_CONTRACT_REVERTED' => '合约拒绝执行，平台处理中',
  _ => '暂不执行',
};

/// Why a prepared or sent buyback did not execute (`lastResult: failed`).
String launch2KeeperFailureText(String? reasonCode) => switch (reasonCode) {
  'LAUNCH2_BUYBACK_PAUSED' => '合约回购已暂停',
  'LAUNCH2_BUYBACK_KEEPER_INSUFFICIENT_FUNDS' => '执行账户手续费不足，平台处理中',
  'LAUNCH2_BUYBACK_GAS_ABOVE_CAP' => '链上手续费过高，稍后重试',
  _ => '上一笔没有执行，稍后重试',
};

/// zh-CN for the server's own `launch2` refusal rules (contract §4). Every
/// line says what did not happen.
/// The chain guard's hold, in one sentence (decision 0161) — the banner,
/// the panels' line and the refusal codes all say the same thing.
const String launch2Usd1PausedText = 'USD1 已被发行方暂停，买卖和领取暂不可用';
const String launch2AddressFrozenText = '本项目合约地址被 USD1 发行方限制，买卖和领取暂不可用';

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
      ? '自 ${loopLocalClockLabel(since)} 起'
      : '自 ${loopLocalTimestampLabel(since)} 起';
}

String launch2ReasonText(String? reasonCode) => switch (reasonCode) {
  'LAUNCH2_USD1_PAUSED' => launch2Usd1PausedText,
  'LAUNCH2_ADDRESS_FROZEN' => launch2AddressFrozenText,
  'LAUNCH2_INSTANCE_NOT_FOUND' => '项目不存在',
  launch2StageMismatchCode => '当前阶段不能交易，已重新读取项目状态',
  'LAUNCH2_SELL_NOT_OPEN' => '提前购阶段只能买入，公开内盘开始后可卖出',
  'LAUNCH2_SOLD_OUT' => '内盘已卖满',
  // Decision 0197: the cap is per instance; the trade panel names it
  // ([launch2QuotaExhaustedText]).
  'LAUNCH2_QUOTA_EXHAUSTED' => '已用完单地址累计买入额度',
  'LAUNCH2_INSTANCE_PAUSED' => '项目已暂停',
  'LAUNCH2_NFT_ALREADY_MINTED' => '这个钱包已经买过 NFT（每个地址终身 1 枚）',
  'LAUNCH2_PRICE_MOVED' => '价格已变化，已刷新',
  'LAUNCH2_QUOTE_EXPIRED' => '报价已过期，已重新报价',
  'LAUNCH2_USD1_BALANCE_INSUFFICIENT' => 'USD1 余额不足',
  'LAUNCH2_MEME_BALANCE_INSUFFICIENT' => '卖出数量超过持有',
  'LAUNCH2_GAS_INSUFFICIENT' => 'tBNB 手续费不足，充值后再试',
  'LAUNCH2_AMOUNT_INVALID' => '金额不正确',
  'LAUNCH2_AMOUNT_ABOVE_MAX' => '超出可买上限',
  'LAUNCH2_DEADLINE_TOO_FAR' || 'LAUNCH2_QUOTE_ZERO' => '报价已变化，请重新报价',
  'LAUNCH2_WALLET_NOT_EMBEDDED' => '只能用 LOOP 内置钱包购买',
  'LAUNCH2_NOT_IN_SNAPSHOT' => '提前购仅限名单内持有人',
  'LAUNCH2_COUNTERPARTY_NOT_INSTANCE' => '暂不可用',
  'LAUNCH2_INTENT_EXPIRED' => '这笔交易已过期，没有提交任何交易，请重新发起',
  'LAUNCH2_SIMULATION_REVERTED' => '试算没有通过，这笔交易在链上会被拒绝',
  'LAUNCH2_APPROVAL_REQUIRED' => '需要先授权，授权前无法试算',
  'LAUNCH2_SNAPSHOT_UNVERIFIED' => '名单还在核对，提前购暂不可用',
  'LAUNCH2_FACTORY_NOT_CONFIGURED' ||
  'LAUNCH2_CHAIN_NOT_CONFIGURED' => 'MEME v2 合约还没有配置',
  'LAUNCH2_REPOSITORY_UNAVAILABLE' ||
  'LAUNCH2_RUNTIME_UNAVAILABLE' => 'MEME v2 服务暂时不可用',
  'LAUNCH2_CHAIN_READ_FAILED' => '链上读数暂时取不到',
  'LAUNCH2_WALLETS_UNAVAILABLE' => '钱包目录暂时读不到',
  'LAUNCH2_WRITES_DISABLED' => '交易暂时关闭',
  'LAUNCH2_MAINNET_SIGNING_CLOSED' => '主网签名暂未开放',
  'LAUNCH2_MODULE_NOT_ENABLED' || 'LAUNCH2_CAPABILITY_ABSENT' => 'MEME v2 暂未开放',
  'CANARY_CEILING_EXCEEDED' => '超过单笔金额上限',
  'CANARY_DAILY_CEILING_EXCEEDED' => '超过今日金额上限',
  'ASSET_NOT_IN_CANARY_ALLOWLIST' => '这笔交易暂不在允许范围内',
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

/// zh-CN for the tBNB gas refusal at the button when the refusal carries no
/// figure: names the token and the fee.
const String launch2GasShortText = 'tBNB 手续费不足：钱包里的 tBNB 不够付这笔的网络手续费，充值后再试';

/// The gas refusal's line with the server's figures (decision 0156): the
/// fee ceiling the check compared and the wallet's tBNB. A missing figure
/// leaves its clause out; with neither the figure-free sentence stays.
String launch2GasFailureText(LoopChainException failure) {
  final required = _detailFigure(failure.requiredBnb);
  final balance = _detailFigure(failure.balanceBnb);
  String bnb(Decimal value) =>
      '${loopFormatDecimal(value, maxFractionDigits: 8)} tBNB';
  if (required == null && balance == null) return launch2GasShortText;
  final parts = <String>[
    if (required != null) '这笔约需 ${bnb(required)}',
    if (balance != null) '钱包有 ${bnb(balance)}',
  ];
  return 'tBNB 手续费不足：${parts.join('，')}，充值后再试';
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
        if (required != null) '需要 ${usd1(required)}',
        if (current != null)
          '当前 ${usd1(current)}'
        else if (max != null)
          '最多可付 ${usd1(max)}',
      ];
      return Launch2ActionFailure(
        parts.isEmpty ? fallback(failure) : 'USD1 余额不足：${parts.join('，')}',
        topUp: true,
      );
    case 'LAUNCH2_MEME_BALANCE_INSUFFICIENT':
      String meme(Decimal value) => launch2MemeLabel(value, ticker);
      final holding =
          _detailFigure(failure.balanceMeme) ?? (maxIsBalance ? max : null);
      final parts = <String>[
        if (required != null) '需要 ${meme(required)}',
        if (holding != null)
          '当前持有 ${meme(holding)}'
        else if (max != null)
          '最多可卖 ${meme(max)}',
      ];
      return Launch2ActionFailure(
        parts.isEmpty ? fallback(failure) : '卖出数量超过持有：${parts.join('，')}',
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
      null => '名单生成中',
      Launch2PublicationStatus.pending ||
      Launch2PublicationStatus.broadcast => '名单发布中',
      Launch2PublicationStatus.confirmed =>
        snapshot.published ? '名单已发布' : '名单已上链，同步中',
      Launch2PublicationStatus.failed ||
      Launch2PublicationStatus.mismatch => '名单发布异常，平台处理中',
    };

/// The line under it: the cutoff block and what opens next.
String launch2SnapshotPendingMessage(Launch2Snapshot snapshot) {
  final block = snapshot.cutoffBlockNumber ?? snapshot.publication?.cutoffBlock;
  if (block == null) return '等待截止块确认，名单发布后开始 1 小时提前购';
  return '截止块 #${loopGroupedFigure(block.toString())}，名单发布后开始 1 小时提前购';
}

/// How long an NFT sale runs: 「7 天」, 「1 小时」 or 「90 分钟」.
String launch2SaleDurationLabel(Launch2NftSale sale) {
  final minutes = sale.endAt.difference(sale.startAt).inMinutes;
  final hours = minutes / 60;
  if (hours >= 24 && hours % 24 == 0) return '${hours ~/ 24} 天';
  if (hours == hours.roundToDouble()) return '${hours.toInt()} 小时';
  return '$minutes 分钟';
}

/// A countdown said aloud (decision 0163): 「2 天 3 小时」, 「2 小时 14 分」,
/// 「14 分」, 「不到 1 分」.
String launch2SpokenDuration(Duration remaining) {
  final total = remaining.isNegative ? 0 : remaining.inMinutes;
  final days = total ~/ 1440;
  final hours = (total % 1440) ~/ 60;
  final minutes = total % 60;
  if (days > 0) return hours > 0 ? '$days 天 $hours 小时' : '$days 天';
  if (hours > 0) return '$hours 小时 $minutes 分';
  if (minutes > 0) return '$minutes 分';
  return '不到 1 分';
}
