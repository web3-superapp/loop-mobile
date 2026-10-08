import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';

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
  'MEME_DEX_CHAIN_NOT_PRICED' => '暂无外盘报价',
  'MEME_DEX_QUOTE_UNAVAILABLE' => '外盘行情暂时取不到',
  'MEME_TOKEN_NOT_ON_CHAIN' => '还没有上链',
  _ => '价格暂时读不到',
};

/// zh-CN for the server's own refusal rules (contract §11) and the state
/// reasons it may attach. Every line says what did not happen.
String memeReasonText(String? reasonCode) => switch (reasonCode) {
  'MEME_TOKEN_NOT_FOUND' => '代币不存在',
  'MEME_CURVE_NOT_TRADING' => '当前不可交易',
  'MEME_CURVE_FULL' => '已打满，等待毕业',
  'MEME_TOKEN_NOT_DRAFT' || 'MEME_TOKEN_NOT_ON_CHAIN' => '状态已变化，请刷新',
  'MEME_SALT_TAKEN' => '地址已被占用，请重试',
  'MEME_INTENT_EXPIRED' => '这笔交易已过期（约 30 秒内未签名），请重新发起',
  'MEME_INTENT_NOT_SIGNABLE' ||
  'MEME_INTENT_ALREADY_REPORTED' => '这笔交易已失效，请重新发起',
  'MEME_USD1_BALANCE_INSUFFICIENT' => 'USD1 余额不足',
  'MEME_SELL_EXCEEDS_BALANCE' => '卖出数量超过持有',
  'MEME_GAS_INSUFFICIENT' => 'tBNB 手续费不足',
  'MEME_WALLET_CAP_EXCEEDED' => '超过单钱包 4,000 万枚上限',
  'MEME_BELOW_MIN_BUY' => '最少买入 1 USD1',
  'MEME_METADATA_INVALID' => '资料不符合要求，请检查名称、符号、简介和链接',
  'MEME_IMAGE_NOT_OWNED' => '这张图片不是当前账号上传的，请重新上传',
  'MEME_MIN_OUT_ABOVE_QUOTE' || 'MEME_QUOTE_ZERO' => '报价已变化，请重新报价',
  'MEME_TX_PAYLOAD_MISMATCH' => '链上交易与确认内容不符',
  'MEME_TX_REVERTED' => '交易在链上没有成功',
  'MEME_TX_NOT_OBSERVED' => '迟迟没有看到这笔交易上链',
  'MEME_CREATE_RATE_LIMITED' => '今天的创建次数用完了，明天再来',
  'MEME_SIMULATION_REVERTED' => '试算没有通过，请重新报价',
  'MEME_SIMULATION_UNAVAILABLE' => '暂时无法试算，请稍后再试',
  'MEME_APPROVAL_REQUIRED' => '需要先授权，授权前无法试算',
  'MEME_VIEWER_WALLET_MISSING' => '还没有激活钱包',
  'MEME_CONTRACT_READ_FAILED' || 'MEME_CHAIN_RPC_UNREACHABLE' => '链上读数暂时取不到',
  'MEME_WRITES_DISABLED' => '交易暂时关闭',
  'MEME_MAINNET_SIGNING_CLOSED' => '主网签名暂未开放',
  'MEME_MODULE_NOT_ENABLED' => '发射台暂未开放',
  'MEME_RUNTIME_UNAVAILABLE' || 'MEME_REPOSITORY_UNAVAILABLE' => '发射台服务暂时不可用',
  'MEME_CONTRACT_NOT_CONFIGURED' || 'MEME_USD1_NOT_CONFIGURED' => '发射台合约还没有配置',
  'CANARY_CEILING_EXCEEDED' => '超过单笔金额上限',
  'CANARY_DAILY_CEILING_EXCEEDED' => '超过今日金额上限',
  'ASSET_NOT_IN_CANARY_ALLOWLIST' ||
  'COUNTERPARTY_NOT_IN_CANARY_ALLOWLIST' => '这笔交易暂不在允许范围内',
  _ => loopReasonCodeSummaryText(reasonCode),
};

/// The sentence for one failed request: the server's own rule when it named
/// one, otherwise what kind of failure it was.
String memeFailureText(LoopChainException failure) {
  final reason = failure.reasonCode;
  if (reason != null) return memeReasonText(reason);
  return loopChainFailureReason(failure.kind);
}
