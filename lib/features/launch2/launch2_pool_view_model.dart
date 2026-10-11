import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';

// ---------------------------------------------------------------------------
// 外盘交易 · the panel's view model (client decision 0145)
// ---------------------------------------------------------------------------
//
// Everything the graduated page's buy / sell panel says is decided here, from
// the instance, the reader's choices and the server's last answer, so the
// widget only lays it out and the rules are unit-tested without a frame.

/// The slippage presets; a third is typed (0.01–50%).
const List<int> launch2PoolSlippagePresets = <int>[50, 100, 300];

/// The default slippage (1%), the curve's default as well.
const int launch2PoolDefaultSlippageBps = 100;

/// The official pool's tax when the server has not said otherwise.
const int launch2PoolFallbackTaxBps = 200;

/// The line a moved or expired price leaves in the panel.
const String launch2PoolPriceMovedText = '价格已变化，已刷新';

/// One label / value line under the amount field.
@immutable
final class Launch2PoolLine {
  const Launch2PoolLine(this.key, this.label, this.value);

  /// The widget key suffix (`launch2-pool-line-<key>`).
  final String key;
  final String label;
  final String value;
}

/// What the reader holds of the graduated token, when it is known.
@immutable
final class Launch2PoolHolding {
  const Launch2PoolHolding({required this.balance, this.sellable});

  /// The wallet's MEME balance.
  final Decimal balance;

  /// What a sell can move now; the balance when the server does not say.
  final Decimal? sellable;

  Decimal get sellableOrBalance => sellable ?? balance;
}

/// The panel's whole face for one frame.
@immutable
final class Launch2PoolTradeView {
  const Launch2PoolTradeView({
    required this.fieldLabel,
    required this.fieldSuffix,
    required this.taxLabel,
    required this.lines,
    required this.quotePlaceholder,
    required this.confirmLabel,
    required this.canConfirm,
    required this.showMax,
    this.overHolding = false,
    this.balanceLine,
    this.blockedLine,
    this.quoteFailureLine,
    this.holdingLine,
    this.provenance,
  });

  final String fieldLabel;
  final String fieldSuffix;

  /// 「外盘税 2%」 in the header.
  final String taxLabel;

  /// The quote, line by line; empty while there is none.
  final List<Launch2PoolLine> lines;

  /// What stands in for the quote while there is none (「输入金额后显示报价」…).
  final String? quotePlaceholder;
  final String confirmLabel;
  final bool canConfirm;

  /// MAX fills what can be sold (a sell typed in MEME).
  final bool showMax;

  /// The typed sell is above what can be sold; nothing is asked.
  final bool overHolding;

  /// The quote needs more than the wallet holds (`exceedsBalance`).
  final String? balanceLine;

  /// Why the panel is greyed, or `null`.
  final String? blockedLine;

  /// The quote request failed: one line with the server's reason.
  final String? quoteFailureLine;

  /// 「持有 … · 可卖 …」.
  final String? holdingLine;

  /// The quote's source line (router block).
  final String? provenance;
}

/// zh-CN for the pool routes' own refusals (loop-api S146), then the
/// curve's catalogue. Every line says nothing was traded.
String launch2PoolReasonText(String? reasonCode) => switch (reasonCode) {
  'POOL_QUOTE_UNAVAILABLE' => '官方池试算没有通过，换个金额再试',
  'POOL_NOT_GRADUATED' => '项目还没有毕业，官方池尚未开放',
  'POOL_INSUFFICIENT_LIQUIDITY' => '官方池流动性不足，换个小一点的金额试试',
  'POOL_QUOTE_ZERO' => '这个金额太小，换算后为 0',
  'POOL_ROUTER_NOT_CONFIGURED' ||
  'POOL_ROUTER_CODE_MISMATCH' ||
  'POOL_ROUTER_MANAGER_MISMATCH' ||
  'POOL_KEY_MISMATCH' => '外盘交易暂时关闭，平台正在核对官方池',
  'LAUNCH2_AMOUNT_INVALID' => '金额不正确',
  'LAUNCH2_USD1_BALANCE_INSUFFICIENT' => 'USD1 余额不足，没有发起任何交易',
  'LAUNCH2_MEME_BALANCE_INSUFFICIENT' => '卖出数量超过持有，没有发起任何交易',
  _ => launch2ReasonText(reasonCode),
};

String launch2PoolFailureText(LoopChainException failure) {
  final reason = failure.reasonCode;
  if (reason != null) return launch2PoolReasonText(reason);
  return loopChainFailureReason(failure.kind);
}

/// The amount field's label and unit for one side and mode.
(String label, String suffix) launch2PoolField(
  Launch2Side side,
  Launch2PoolMode mode,
  String ticker,
) => switch ((side, mode)) {
  (Launch2Side.buy, Launch2PoolMode.exactIn) => ('支付（含税）', 'USD1'),
  (Launch2Side.buy, Launch2PoolMode.exactOut) => ('想买入', '\$$ticker'),
  (Launch2Side.sell, Launch2PoolMode.exactIn) => ('卖出', '\$$ticker'),
  (Launch2Side.sell, Launch2PoolMode.exactOut) => ('想到手', 'USD1'),
};

/// The two labels the mode toggle offers for a side.
(String exactIn, String exactOut) launch2PoolModeLabels(Launch2Side side) =>
    side == Launch2Side.buy ? ('按支付', '按买入数量') : ('按卖出数量', '按到手');

String _usd1(Decimal value) => launch2Usd1Label(value, maxFractionDigits: 4);

/// The quote's lines, said the way the signing sheet says them.
List<Launch2PoolLine> launch2PoolQuoteLines(
  Launch2PoolQuote quote,
  String ticker,
) {
  final buy = quote.side == Launch2Side.buy;
  String out(Decimal value) =>
      buy ? launch2MemeLabel(value, ticker) : _usd1(value);
  String into(Decimal value) =>
      buy ? _usd1(value) : launch2MemeLabel(value, ticker);
  return <Launch2PoolLine>[
    if (quote.mode == Launch2PoolMode.exactIn) ...<Launch2PoolLine>[
      Launch2PoolLine(
        'expected',
        buy ? '预计获得' : '预计到手',
        out(quote.expectedOut),
      ),
      Launch2PoolLine('min', buy ? '最少获得' : '最少到手', out(quote.minOut)),
    ] else ...<Launch2PoolLine>[
      Launch2PoolLine('expected', buy ? '预计支付' : '预计卖出', into(quote.amountIn)),
      Launch2PoolLine('max', buy ? '最多支付' : '最多卖出', into(quote.maxIn)),
    ],
    Launch2PoolLine(
      'tax',
      '外盘税 ${launch2BpsLabel(quote.taxBps)}',
      quote.taxToken == Launch2PoolTaxToken.meme
          ? launch2MemeLabel(quote.taxAmount, ticker)
          : _usd1(quote.taxAmount),
    ),
    Launch2PoolLine('price', '成交均价', launch2PriceLabel(quote.averagePriceUsd1)),
    Launch2PoolLine('slippage', '滑点上限', launch2BpsLabel(quote.slippageBps)),
  ];
}

/// What the reader holds, from the freshest source: the quote's balances at
/// its block, else the position the account read.
Launch2PoolHolding? launch2PoolHoldingOf({
  Launch2PoolQuote? quote,
  Launch2PoolHolding? position,
}) {
  if (quote != null) return Launch2PoolHolding(balance: quote.balanceMeme);
  return position;
}

/// The panel for one frame.
///
/// [walletId] `null` greys the panel; [locked] holds the next signature back
/// while our own broadcast settles; a sell above [holding] is refused before
/// the server is asked, and a quote above the balance is refused before the
/// prepare.
Launch2PoolTradeView launch2PoolTradeView({
  required Launch2InstanceDetail detail,
  required String? walletId,
  required Launch2Side side,
  required Launch2PoolMode mode,
  required Decimal? amount,
  required int? slippageBps,
  required Launch2PoolQuote? quote,
  required bool quoting,
  required bool preparing,
  required bool locked,
  LoopChainException? quoteFailure,
  Launch2PoolHolding? holding,
}) {
  final ticker = detail.row.ticker;
  final (label, suffix) = launch2PoolField(side, mode, ticker);
  final taxBps =
      quote?.taxBps ??
      detail.graduation?.officialPoolTaxBps ??
      detail.template.officialPoolTaxBps;
  final graduated = detail.stage == Launch2Stage.graduated;
  final pool = detail.pool;
  final String? blocked = !graduated
      ? '项目还没有毕业，官方池尚未开放'
      : detail.graduation == null
      ? '官方池信息还在同步，暂时不能交易'
      : pool != null && pool.router == null
      ? '外盘交易暂未开放（路由未配置）'
      : walletId == null
      ? '还没有可用的钱包，激活钱包后可交易'
      : null;
  final sellAll = holding?.sellableOrBalance;
  final String? overHolding =
      side == Launch2Side.sell &&
          mode == Launch2PoolMode.exactIn &&
          amount != null &&
          sellAll != null &&
          amount > sellAll
      ? '卖出数量超过可卖 ${launch2MemeLabel(sellAll, ticker)}'
      : null;
  final String? overBalance = quote != null && quote.exceedsBalance
      ? side == Launch2Side.buy
            ? 'USD1 余额不足：最多需要 ${_usd1(quote.maxIn)}，'
                  '钱包有 ${_usd1(quote.balanceUsd1)}'
            : '\$$ticker 余额不足：最多需要 ${launch2MemeLabel(quote.maxIn, ticker)}，'
                  '钱包有 ${launch2MemeLabel(quote.balanceMeme, ticker)}'
      : null;
  final failureLine = quoteFailure == null
      ? null
      : '没有取到报价 · ${launch2PoolFailureText(quoteFailure)}';
  final lines = quote == null
      ? const <Launch2PoolLine>[]
      : launch2PoolQuoteLines(quote, ticker);
  final String? placeholder = quote != null || failureLine != null
      ? null
      : overHolding ?? (quoting ? '正在向官方池报价…' : '输入金额后显示报价');
  final canConfirm =
      blocked == null &&
      !locked &&
      overHolding == null &&
      overBalance == null &&
      amount != null &&
      slippageBps != null &&
      quote != null &&
      quote.side == side &&
      quote.mode == mode &&
      !quoting &&
      !preparing &&
      quote.expectedOut > Decimal.zero &&
      quote.amountIn > Decimal.zero;
  // Neither the detail nor `me/positions` carries a wallet balance (loop-api
  // S146): before the first quote the curve figure is said as what it is.
  final curveNet = detail.viewer?.curve.net;
  final String? holdingLine = holding != null
      ? '持有 ${launch2MemeLabel(holding.balance, ticker)} · '
            '可卖 ${launch2MemeLabel(holding.sellableOrBalance, ticker)}'
      : curveNet != null && curveNet > Decimal.zero
      ? '内盘净买入 ${launch2MemeLabel(curveNet, ticker)} · 钱包余额报价后显示'
      : null;
  return Launch2PoolTradeView(
    fieldLabel: label,
    fieldSuffix: suffix,
    taxLabel: '外盘税 ${launch2BpsLabel(taxBps)}',
    lines: lines,
    quotePlaceholder: placeholder,
    overHolding: overHolding != null,
    balanceLine: overBalance,
    confirmLabel: preparing
        ? '正在准备…'
        : locked
        ? '上一笔确认中…'
        : side == Launch2Side.buy
        ? '确认买入'
        : '确认卖出',
    canConfirm: canConfirm,
    showMax:
        side == Launch2Side.sell &&
        mode == Launch2PoolMode.exactIn &&
        sellAll != null &&
        sellAll > Decimal.zero,
    blockedLine: blocked,
    quoteFailureLine: failureLine,
    holdingLine: holdingLine,
    provenance: quote == null
        ? null
        : '按区块 ${quote.quotedAtBlock} 的官方池计算，已扣 '
              '${launch2BpsLabel(quote.taxBps)} 外盘税；到期自动重新报价。',
  );
}

/// A typed slippage in percent (two decimals at most, 0.01–50) as basis
/// points, or `null` when it is not one.
int? launch2PoolSlippageFromInput(String text) {
  final value = text.trim();
  if (!RegExp(r'^(0|[1-9][0-9]?)(\.[0-9]{1,2})?$').hasMatch(value)) {
    return null;
  }
  final bps = (Decimal.parse(value) * Decimal.fromInt(100)).toBigInt().toInt();
  if (bps <= 0 || bps > 5000) return null;
  return bps;
}
