import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
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

/// The one sentence for `closed_no_holders` (decision 0142).
const String launch2ClosedNoHoldersText = '无人认购，已关闭';

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
    '${launch2MemeFigure(value)} \$$ticker';

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

/// What bounds the MAX, said as the reason a larger amount is refused.
String launch2LimitedByText(Launch2LimitedBy limitedBy) => switch (limitedBy) {
  Launch2LimitedBy.quota => '单地址累计上限 5,000,000 枚',
  Launch2LimitedBy.inventory => '内盘剩余库存',
  Launch2LimitedBy.balance => '钱包余额',
  Launch2LimitedBy.soldSupply => '内盘可卖数量',
  Launch2LimitedBy.closed => '当前阶段不可交易',
};

/// The buyback's `nextOrderBlockedReason` in zh-CN; `null` reads as ready.
String launch2BuybackBlockedText(String? reasonCode) => switch (reasonCode) {
  null => '下一笔可以执行',
  'BUYBACK_PAUSED' => '回购已暂停',
  'BUYBACK_NOT_GRADUATED' => '毕业后才开始回购',
  'BUYBACK_NO_BUDGET' => '托管余额不足一笔',
  'BUYBACK_PROTECTION_BLOCKED' => '价格保护生效，暂不执行',
  'BUYBACK_PRICE_SOURCE_UNAVAILABLE' => '参考价暂时读不到，暂不执行',
  _ => '暂不执行',
};

/// zh-CN for the server's own `launch2` refusal rules (contract §4). Every
/// line says what did not happen.
String launch2ReasonText(String? reasonCode) => switch (reasonCode) {
  'LAUNCH2_INSTANCE_NOT_FOUND' => '项目不存在',
  launch2StageMismatchCode => '当前阶段不能交易，已重新读取项目状态',
  'LAUNCH2_SELL_NOT_OPEN' => '提前购阶段只能买入，公开内盘开始后可卖出',
  'LAUNCH2_SOLD_OUT' => '内盘已卖满',
  'LAUNCH2_QUOTA_EXHAUSTED' => '已用完单地址累计 5,000,000 枚额度',
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
