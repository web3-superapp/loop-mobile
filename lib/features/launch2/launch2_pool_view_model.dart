import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

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
String get launch2PoolPriceMovedText =>
    LoopL10n.current.launch2_launch2FormatSwitch31;

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

/// Decision 0159 · zh-CN for every LoopDynamic `reasonCode`, exactly the
/// server's `launch2DynamicReasonMessagesZh` (`frontend-v2-launch2-api.md`
/// §3.12.6). `null` for any other code.
Map<String, String> launch2DynamicReasonMessagesZh = <String, String>{
  'LAUNCH2_DYNAMIC_ROUTER_NOT_CONFIGURED':
      LoopL10n.current.launch2_launch2PoolViewModelS,
  'LAUNCH2_DYNAMIC_ROUTER_CODE_MISMATCH':
      LoopL10n.current.launch2_launch2PoolViewModelS2,
  'LAUNCH2_DYNAMIC_ROUTER_MANAGER_MISMATCH':
      LoopL10n.current.launch2_launch2PoolViewModelS3,
  'LAUNCH2_DYNAMIC_HOOK_NOT_INDEXED':
      LoopL10n.current.launch2_launch2DynamicRewardsReason,
  'LAUNCH2_DYNAMIC_HOOK_MISMATCH':
      LoopL10n.current.launch2_launch2PoolViewModelS4,
  'LAUNCH2_DYNAMIC_HOOK_NOT_INITIALIZED':
      LoopL10n.current.launch2_launch2PoolViewModelS5,
  'LAUNCH2_EXACT_OUT_UNSUPPORTED':
      LoopL10n.current.launch2_launch2PoolViewModelS6,
  'LAUNCH2_DYNAMIC_POOL_NOT_APPLICABLE':
      LoopL10n.current.launch2_launch2PoolViewModelS7,
  'LAUNCH2_DYNAMIC_ROUND_INVALID':
      LoopL10n.current.launch2_launch2PoolViewModelS8,
  'LAUNCH2_DYNAMIC_ROUTER_UNAUTHORIZED':
      LoopL10n.current.launch2_launch2PoolViewModelS9,
  'LAUNCH2_DYNAMIC_SWAP_UNSUPPORTED':
      LoopL10n.current.launch2_launch2PoolViewModelS10,
  'LAUNCH2_DYNAMIC_HOOK_BUSY': LoopL10n.current.launch2_launch2PoolViewModelS11,
  'LAUNCH2_DYNAMIC_ROUND_NOT_CLOSED':
      LoopL10n.current.launch2_launch2PoolViewModelS12,
  'LAUNCH2_DYNAMIC_ALREADY_CLAIMED':
      LoopL10n.current.launch2_launch2PoolViewModelS13,
  'LAUNCH2_DYNAMIC_CLAIM_TRANSACTION_CONFLICT':
      LoopL10n.current.launch2_launch2PoolViewModelS14,
  'LAUNCH2_DYNAMIC_NOTHING_TO_CLAIM':
      LoopL10n.current.launch2_launch2DynamicRewardsLaunch2DynamicNoRewardText,
  'LAUNCH2_DYNAMIC_CLAIM_INTENT_NOT_FOUND':
      LoopL10n.current.launch2_launch2PoolViewModelS15,
};

String? launch2DynamicReasonText(String? reasonCode) =>
    reasonCode == null ? null : launch2DynamicReasonMessagesZh[reasonCode];

/// zh-CN for the pool routes' own refusals (loop-api S146), then the
/// curve's catalogue. Every line says nothing was traded.
String launch2PoolReasonText(String? reasonCode) =>
    launch2DynamicReasonText(reasonCode) ?? _poolReasonText(reasonCode);

String _poolReasonText(String? reasonCode) => switch (reasonCode) {
  'POOL_QUOTE_UNAVAILABLE' =>
    LoopL10n.current.launch2_launch2PoolViewModelSwitch,
  'POOL_NOT_GRADUATED' => LoopL10n.current.launch2_launch2PoolViewModelSwitch2,
  'POOL_INSUFFICIENT_LIQUIDITY' =>
    LoopL10n.current.launch2_launch2PoolViewModelSwitch3,
  'POOL_QUOTE_ZERO' => LoopL10n.current.launch2_launch2PoolViewModelSwitch4,
  'POOL_ROUTER_NOT_CONFIGURED' ||
  'POOL_ROUTER_CODE_MISMATCH' ||
  'POOL_ROUTER_MANAGER_MISMATCH' ||
  'POOL_KEY_MISMATCH' => LoopL10n.current.launch2_launch2PoolViewModelSwitch5,
  'LAUNCH2_AMOUNT_INVALID' => LoopL10n.current.launch2_launch2FormatSwitch36,
  'LAUNCH2_USD1_BALANCE_INSUFFICIENT' =>
    LoopL10n.current.launch2_launch2PoolViewModelSwitch6,
  'LAUNCH2_MEME_BALANCE_INSUFFICIENT' =>
    LoopL10n.current.launch2_launch2PoolViewModelSwitch7,
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
  (Launch2Side.buy, Launch2PoolMode.exactIn) => (
    LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolFailureText,
    'USD1',
  ),
  (Launch2Side.buy, Launch2PoolMode.exactOut) => (
    LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolFailureText2,
    loopTickerLabel(ticker),
  ),
  (Launch2Side.sell, Launch2PoolMode.exactIn) => (
    LoopL10n.current.common_sell,
    loopTickerLabel(ticker),
  ),
  (Launch2Side.sell, Launch2PoolMode.exactOut) => (
    LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolFailureText3,
    'USD1',
  ),
};

/// The two labels the mode toggle offers for a side.
(String exactIn, String exactOut) launch2PoolModeLabels(Launch2Side side) =>
    side == Launch2Side.buy
    ? (
        LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolFailureText4,
        LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolFailureText5,
      )
    : (
        LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolFailureText6,
        LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolFailureText7,
      );

String _usd1(Decimal value) => launch2Usd1Label(value, maxFractionDigits: 4);

/// The quote's lines, said the way the signing sheet says them. A quote
/// with `dynamic` (decision 0159) reads as a LoopDynamic one.
List<Launch2PoolLine> launch2PoolQuoteLines(
  Launch2PoolQuote quote,
  String ticker,
) {
  final loopDynamic = quote.loopDynamic;
  if (loopDynamic != null) {
    return launch2DynamicQuoteLines(quote, ticker, loopDynamic);
  }
  final buy = quote.side == Launch2Side.buy;
  String out(Decimal value) =>
      buy ? launch2MemeLabel(value, ticker) : _usd1(value);
  String into(Decimal value) =>
      buy ? _usd1(value) : launch2MemeLabel(value, ticker);
  return <Launch2PoolLine>[
    if (quote.mode == Launch2PoolMode.exactIn) ...<Launch2PoolLine>[
      Launch2PoolLine(
        'expected',
        buy
            ? LoopL10n.current.common_estimatedReceive
            : LoopL10n.current.launch2_launch2PoolViewModelS16,
        out(quote.expectedOut),
      ),
      Launch2PoolLine(
        'min',
        buy
            ? LoopL10n.current.common_minimumReceive
            : LoopL10n.current.launch2_launch2PoolViewModelS17,
        out(quote.minOut),
      ),
    ] else ...<Launch2PoolLine>[
      Launch2PoolLine(
        'expected',
        buy
            ? LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine
            : LoopL10n.current.launch2_launch2PoolViewModelS18,
        into(quote.amountIn),
      ),
      Launch2PoolLine(
        'max',
        buy
            ? LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine2
            : LoopL10n.current.launch2_launch2PoolViewModelS19,
        into(quote.maxIn),
      ),
    ],
    Launch2PoolLine(
      'tax',
      LoopL10n.current.launch2_launch2InstanceLaunch2PoolTaxTitle(
        launch2BpsLabel(quote.taxBps),
      ),
      quote.taxToken == Launch2PoolTaxToken.meme
          ? launch2MemeLabel(quote.taxAmount, ticker)
          : _usd1(quote.taxAmount),
    ),
    Launch2PoolLine(
      'price',
      LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine3,
      launch2PriceLabel(quote.averagePriceUsd1),
    ),
    Launch2PoolLine(
      'slippage',
      LoopL10n.current.common_slippageLimit,
      launch2BpsLabel(quote.slippageBps),
    ),
  ];
}

/// Decision 0197 · a LoopDynamic buy's base-tax line, by
/// `dynamic.baseTaxToken`: 「基础税 2%（从付出的 USD1 扣）」 = `taxUsd1`, or
/// before S209 「基础税 2%（从到手的 MEME 扣）」 = `taxAmount` MEME.
Launch2PoolLine launch2DynamicBuyTaxLine(
  Launch2PoolQuote quote,
  String ticker,
  Launch2PoolDynamicQuote loopDynamic,
) {
  final rate = launch2BpsLabel(loopDynamic.baseTaxBps);
  return loopDynamic.buyFeeFromUsd1
      ? Launch2PoolLine(
          'tax',
          LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine4(
            launch2BuyFeeSideText(fromUsd1: true),
            rate,
          ),
          _usd1(quote.taxUsd1),
        )
      : Launch2PoolLine(
          'tax',
          LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine4(
            launch2BuyFeeSideText(fromUsd1: false),
            rate,
          ),
          launch2MemeLabel(quote.taxAmount, ticker),
        );
}

/// Decision 0159 · a LoopDynamic quote (exactIn only, §3.12.2). The amounts
/// are already net of every tax: a buy's line is the 2% MEME tax and the
/// weight it adds to the round; a sell's is the base and the dynamic tax
/// together ([Launch2PoolQuote.taxAmount]), with the split under it.
List<Launch2PoolLine> launch2DynamicQuoteLines(
  Launch2PoolQuote quote,
  String ticker,
  Launch2PoolDynamicQuote loopDynamic,
) {
  final buy = quote.side == Launch2Side.buy;
  String out(Decimal value) =>
      buy ? launch2MemeLabel(value, ticker) : _usd1(value);
  final base = LoopL10n.current.launch2_launch2PoolViewModelBase(
    launch2BpsLabel(loopDynamic.baseTaxBps),
  );
  return <Launch2PoolLine>[
    Launch2PoolLine(
      'expected',
      buy
          ? LoopL10n.current.common_estimatedReceive
          : LoopL10n.current.launch2_launch2PoolViewModelS16,
      out(quote.expectedOut),
    ),
    Launch2PoolLine(
      'min',
      buy
          ? LoopL10n.current.common_minimumReceive
          : LoopL10n.current.launch2_launch2PoolViewModelS17,
      out(quote.minOut),
    ),
    if (buy) ...<Launch2PoolLine>[
      // Decision 0197: an S209 Hook keeps the 2% out of the USD1 paid in
      // (the MEME out is untaxed); an older one takes it from the MEME
      // received. The expected MEME is the server's, never re-derived.
      launch2DynamicBuyTaxLine(quote, ticker, loopDynamic),
      loopDynamic.armed
          ? Launch2PoolLine(
              'reward-weight',
              LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine5,
              _usd1(loopDynamic.rewardWeight),
            )
          : Launch2PoolLine(
              'reward-weight',
              LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine6,
              LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine7,
            ),
    ] else ...<Launch2PoolLine>[
      Launch2PoolLine(
        'tax',
        LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine8(
          base,
          launch2BpsLabel(loopDynamic.dynamicTaxBps),
        ),
        _usd1(quote.taxAmount),
      ),
      Launch2PoolLine(
        'tax-split',
        LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine9,
        _usd1(loopDynamic.dynamicTaxAmount),
      ),
    ],
    Launch2PoolLine(
      'price',
      LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolLine3,
      launch2PriceLabel(quote.averagePriceUsd1),
    ),
    Launch2PoolLine(
      'slippage',
      LoopL10n.current.common_slippageLimit,
      launch2BpsLabel(quote.slippageBps),
    ),
  ];
}

/// What the reader holds (decision 0148): the server's own read of the
/// wallet's MEME balance ([server], the detail's `viewer`) first, so the
/// line is there before any quote; the last quote's balance at its block
/// when the server has none; else the position the caller passed.
Launch2PoolHolding? launch2PoolHoldingOf({
  Launch2WalletHolding? server,
  Launch2PoolQuote? quote,
  Launch2PoolHolding? position,
}) {
  final balance = server?.memeBalance;
  if (balance != null) return Launch2PoolHolding(balance: balance);
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
  Launch2DynamicPoolState? dynamicPool,
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
      ? LoopL10n.current.launch2_launch2PoolViewModelSwitch2
      : detail.graduation == null
      ? LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolTradeView
      : pool != null && pool.router == null
      ? LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolTradeView2
      : walletId == null
      ? LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolTradeView3
      : null;
  final sellAll = holding?.sellableOrBalance;
  final String? overHolding =
      side == Launch2Side.sell &&
          mode == Launch2PoolMode.exactIn &&
          amount != null &&
          sellAll != null &&
          amount > sellAll
      ? LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolTradeView4(
          launch2MemeLabel(sellAll, ticker),
        )
      : null;
  final String? overBalance = quote != null && quote.exceedsBalance
      ? side == Launch2Side.buy
            ? LoopL10n.current
                  .launch2_launch2PoolViewModelLaunch2PoolTradeView5(
                    _usd1(quote.maxIn),
                    _usd1(quote.balanceUsd1),
                  )
            : LoopL10n.current.launch2_launch2PoolViewModelS20(
                launch2MemeLabel(quote.maxIn, ticker),
                launch2MemeLabel(quote.balanceMeme, ticker),
                loopTickerLabel(ticker),
              )
      : null;
  final failureLine = quoteFailure == null
      ? null
      : LoopL10n.current.launch2_launch2PoolViewModelNull(
          launch2PoolFailureText(quoteFailure),
        );
  final lines = quote == null
      ? const <Launch2PoolLine>[]
      : launch2PoolQuoteLines(quote, ticker);
  final String? placeholder = quote != null || failureLine != null
      ? null
      : overHolding ??
            (quoting
                ? LoopL10n
                      .current
                      .launch2_launch2PoolViewModelLaunch2PoolTradeView6
                : LoopL10n.current.launch2_launch2PoolViewModelS21);
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
  // Decision 0148: the viewer carries the wallet balance (loop-api S150).
  // A server that read none says so; an older server (no holding group)
  // leaves the curve figure said as what it is until the first quote.
  final curveNet = detail.viewer?.curve.net;
  final server = detail.viewer?.holding;
  // Decision 0149: 「可卖」 is a sell-side figure; the buy side says what is
  // held, once, without repeating the long ticker twice.
  final String? holdingLine = holding != null
      ? side == Launch2Side.buy
            ? LoopL10n.current
                  .launch2_launch2PoolViewModelLaunch2PoolTradeView7(
                    launch2MemeLabel(holding.balance, ticker),
                  )
            : LoopL10n.current.launch2_launch2PoolViewModelS22(
                launch2MemeLabel(holding.balance, ticker),
                launch2MemeLabel(holding.sellableOrBalance, ticker),
              )
      : server != null && server.status == Launch2BalanceStatus.unavailable
      ? LoopL10n.current.launch2_launch2PoolViewModelText
      : curveNet != null && curveNet > Decimal.zero
      ? LoopL10n.current.launch2_launch2PoolViewModelText2(
          launch2MemeLabel(curveNet, ticker),
        )
      : null;
  return Launch2PoolTradeView(
    fieldLabel: label,
    fieldSuffix: suffix,
    taxLabel: dynamicPool == null
        ? LoopL10n.current.launch2_launch2InstanceLaunch2PoolTaxTitle(
            launch2BpsLabel(taxBps),
          )
        : LoopL10n.current.launch2_launch2PoolViewModelTaxLabel(
            launch2BpsLabel(taxBps),
          ),
    lines: lines,
    quotePlaceholder: placeholder,
    overHolding: overHolding != null,
    balanceLine: overBalance,
    confirmLabel: preparing
        ? LoopL10n.current.launch2_launch2DynamicRewardsLabel
        : locked
        ? LoopL10n.current.launch2_launch2PoolViewModelConfirmLabel
        : side == Launch2Side.buy
        ? LoopL10n.current.launch2_launch2PoolViewModelConfirmLabel2
        : LoopL10n.current.launch2_launch2PoolViewModelConfirmLabel3,
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
        : quote.loopDynamic != null
        ? LoopL10n.current.launch2_launch2PoolViewModelProvenance(
            quote.side == Launch2Side.buy
                ? (quote.loopDynamic!.buyFeeFromUsd1
                      ? LoopL10n.current.launch2_provenanceBuyFeeFromUsd1(
                          launch2BpsLabel(quote.taxBps),
                        )
                      : LoopL10n.current.launch2_provenancePoolTax(
                          launch2BpsLabel(quote.taxBps),
                        ))
                : (quote.loopDynamic!.priceTiming == Launch2PriceTiming.postSwap
                      ? LoopL10n.current.launch2_provenanceSellPostSwap
                      : LoopL10n.current.launch2_provenanceSellPreSwap),
            quote.quotedAtBlock,
          )
        : LoopL10n.current.launch2_launch2PoolViewModelProvenance2(
            launch2BpsLabel(quote.taxBps),
            quote.quotedAtBlock,
          ),
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

/// One of the wallet's own pool trades in a line (decision 0148): what came
/// out for what went in, both net of the 2% pool tax.
String launch2PoolTradeFigure(Launch2PoolTrade trade, String ticker) =>
    trade.side == Launch2Side.buy
    ? LoopL10n.current.launch2_launch2PoolViewModelLaunch2PoolSlippageFromInput(
        launch2MemeLabel(trade.amountOut, ticker),
        _usd1(trade.amountIn),
      )
    : LoopL10n.current.launch2_launch2PoolViewModelS23(
        launch2MemeLabel(trade.amountIn, ticker),
        _usd1(trade.amountOut),
      );
