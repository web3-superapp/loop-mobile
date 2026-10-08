import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// What the panel hands back to the token page: one side, one whole-unit
/// amount and the slippage the owner chose. The page prepares the intent.
@immutable
final class MemeTradeRequest {
  const MemeTradeRequest({
    required this.side,
    required this.amount,
    required this.slippageBps,
  });

  final MemeTradeSide side;
  final String amount;
  final int slippageBps;
}

/// The three slippage choices; the third is typed.
const List<int> memeSlippagePresets = <int>[100, 300];

/// The panel's debounce before it asks for a quote.
const Duration memeQuoteDebounce = Duration(milliseconds: 350);

/// Opens the buy / sell panel for one token. `null` when it was closed.
Future<MemeTradeRequest?> showMemeTradePanel(
  BuildContext context, {
  required MemeTokenDetail detail,
  required MemeTradeSide side,
}) => showLoopSheet<MemeTradeRequest>(
  context,
  builder: (context) => MemeTradePanel(detail: detail, initialSide: side),
);

/// 买入 / 卖出 (S115–S118 §3): an amount in USD1 or in the token, the
/// 25 / 50 / 75 / 100% shortcuts, the server's quote — what arrives, the fee,
/// the price impact and any cap the trade would hit — and the slippage. A cap
/// is said here, before anything is signed.
class MemeTradePanel extends ConsumerStatefulWidget {
  const MemeTradePanel({
    required this.detail,
    required this.initialSide,
    super.key,
  });

  final MemeTokenDetail detail;
  final MemeTradeSide initialSide;

  @override
  ConsumerState<MemeTradePanel> createState() => _MemeTradePanelState();
}

class _MemeTradePanelState extends ConsumerState<MemeTradePanel> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _customSlippage = TextEditingController();

  late MemeTradeSide _side = widget.initialSide;
  int? _slippageBps = memeSlippagePresets.first;
  bool _customSelected = false;

  Timer? _debounce;
  int _request = 0;
  MemeQuote? _quote;
  LoopChainException? _quoteFailure;
  bool _quoting = false;

  MemeTokenDetail get _detail => widget.detail;
  String get _ticker => '\$${_detail.row.symbol}';

  @override
  void initState() {
    super.initState();
    _amount.addListener(_amountChanged);
    _customSlippage.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amount
      ..removeListener(_amountChanged)
      ..dispose();
    _customSlippage.dispose();
    super.dispose();
  }

  void _amountChanged() {
    _debounce?.cancel();
    _request += 1;
    setState(() {
      _quote = null;
      _quoteFailure = null;
      _quoting = memeRawFromInput(_amount.text) != null;
    });
    if (memeRawFromInput(_amount.text) == null) return;
    _debounce = Timer(memeQuoteDebounce, () => unawaited(_fetchQuote()));
  }

  Future<void> _fetchQuote() async {
    final amount = _amount.text.trim();
    final request = _request;
    try {
      final quote = await ref
          .read(memeGatewayProvider)
          .quote(
            memeTokenId: _detail.memeTokenId,
            side: _side,
            amount: amount,
            walletId: _detail.viewer?.walletId,
          );
      if (!mounted || request != _request) return;
      setState(() {
        _quote = quote;
        _quoting = false;
      });
    } on LoopChainException catch (failure) {
      if (!mounted || request != _request) return;
      setState(() {
        _quoteFailure = failure;
        _quoting = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _quoteFailure = const LoopChainException(
          LoopChainFailureKind.readFailed,
        );
        _quoting = false;
      });
    }
  }

  void _selectSide(MemeTradeSide side) {
    if (side == _side) return;
    _side = side;
    _amount.clear();
  }

  BigInt? get _balance => switch (_side) {
    MemeTradeSide.buy => _detail.viewer?.usd1Balance,
    MemeTradeSide.sell => _detail.viewer?.balance,
  };

  void _fill(int percent) {
    final balance = _balance;
    if (balance == null || balance <= BigInt.zero) return;
    final raw = balance * BigInt.from(percent) ~/ BigInt.from(100);
    if (raw <= BigInt.zero) return;
    _amount.text = memeDecimalString(raw);
  }

  /// The chosen slippage in basis points, or `null` while a typed one is not
  /// a valid percentage (0.01–50).
  int? get _effectiveSlippage {
    if (!_customSelected) return _slippageBps;
    final raw = memeRawFromInput(_customSlippage.text);
    if (raw == null) return null;
    // Percent with at most two decimals → basis points.
    final bps = raw * BigInt.from(100) ~/ BigInt.from(10).pow(memeDecimals);
    final exact =
        bps * BigInt.from(10).pow(memeDecimals) == raw * BigInt.from(100);
    if (!exact || bps <= BigInt.zero || bps > BigInt.from(5000)) return null;
    return bps.toInt();
  }

  /// What keeps 「确认」 closed, said in one line, or `null`.
  String? get _blockingReason {
    final raw = memeRawFromInput(_amount.text);
    if (raw == null) return null;
    final balance = _balance;
    if (balance != null && raw > balance) {
      return _side == MemeTradeSide.buy ? 'USD1 余额不足' : '卖出数量超过持有';
    }
    final quote = _quote;
    if (quote == null) return null;
    if (quote.belowMinBuy) {
      return '最少买入 ${memeUsd1Label(_detail.curve.minBuyUsd1)}';
    }
    if (quote.walletCapHit) {
      final left = quote.walletCapRemaining;
      return left == null
          ? '超过单钱包 ${memeTokenFigure(_detail.curve.walletCapTokens)} 枚上限'
          : '超过单钱包上限，最多还能买 ${memeTokenLabel(left, _ticker)}';
    }
    if (quote.out <= BigInt.zero) return '这个金额得不到代币，请调整';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final raw = memeRawFromInput(_amount.text);
    final quote = _quote;
    final blocking = _blockingReason;
    final slippage = _effectiveSlippage;
    final canConfirm =
        raw != null &&
        quote != null &&
        !_quoting &&
        blocking == null &&
        slippage != null;
    final balance = _balance;
    final viewerReason = _detail.viewerUnavailableReason;
    return LoopSheet(
      title: _side == MemeTradeSide.buy ? '买入 $_ticker' : '卖出 $_ticker',
      child: Padding(
        key: const ValueKey<String>('meme-trade-panel'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopSegBar(
              key: const ValueKey<String>('meme-trade-side'),
              labels: const <String>['买入', '卖出'],
              selectedIndex: _side == MemeTradeSide.buy ? 0 : 1,
              onSelected: (index) {
                _selectSide(
                  index == 0 ? MemeTradeSide.buy : MemeTradeSide.sell,
                );
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('meme-trade-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              style: LoopType.figureLg,
              decoration: InputDecoration(
                labelText: _side == MemeTradeSide.buy ? '支付' : '卖出',
                suffixText: _side == MemeTradeSide.buy ? 'USD1' : _ticker,
                hintText: '0',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              key: const ValueKey<String>('meme-trade-balance'),
              balance == null
                  ? '钱包读数暂时取不到 · ${memeReasonText(viewerReason ?? 'MEME_VIEWER_WALLET_MISSING')}'
                  : _side == MemeTradeSide.buy
                  ? '可用 ${memeUsd1Label(balance)}'
                  : '持有 ${memeTokenLabel(balance, _ticker)}',
              style: LoopType.captionSm.copyWith(color: LoopColors.text3),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                for (final percent in const <int>[25, 50, 75, 100]) ...<Widget>[
                  Expanded(
                    child: LoopSeg(
                      key: ValueKey<String>('meme-trade-fill-$percent'),
                      label: '$percent%',
                      selected: false,
                      block: true,
                      onSelected: balance == null || balance <= BigInt.zero
                          ? null
                          : () => _fill(percent),
                    ),
                  ),
                  if (percent != 100) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _QuoteBlock(
              quote: quote,
              quoting: _quoting,
              failure: _quoteFailure,
              side: _side,
              ticker: _ticker,
            ),
            if (blocking != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  blocking,
                  key: const ValueKey<String>('meme-trade-blocking'),
                  style: LoopType.caption.copyWith(color: LoopColors.warning),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              '滑点上限',
              style: LoopType.captionSm.copyWith(color: LoopColors.text3),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (final bps in memeSlippagePresets) ...<Widget>[
                  LoopSeg(
                    key: ValueKey<String>('meme-trade-slippage-$bps'),
                    label: memeBpsLabel(bps),
                    selected: !_customSelected && _slippageBps == bps,
                    onSelected: () => setState(() {
                      _customSelected = false;
                      _slippageBps = bps;
                    }),
                  ),
                  const SizedBox(width: 6),
                ],
                LoopSeg(
                  key: const ValueKey<String>('meme-trade-slippage-custom'),
                  label: '自定义',
                  selected: _customSelected,
                  onSelected: () => setState(() => _customSelected = true),
                ),
                if (_customSelected) ...<Widget>[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const ValueKey<String>(
                        'meme-trade-slippage-custom-input',
                      ),
                      controller: _customSlippage,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: '%',
                        hintText: '0.01–50',
                        errorText:
                            _customSlippage.text.isNotEmpty && slippage == null
                            ? '0.01–50'
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            LoopButton(
              key: const ValueKey<String>('meme-trade-confirm'),
              label: _side == MemeTradeSide.buy ? '确认买入' : '确认卖出',
              primary: true,
              block: true,
              onPressed: canConfirm
                  ? () => Navigator.of(context).pop(
                      MemeTradeRequest(
                        side: _side,
                        amount: memeDecimalString(raw),
                        slippageBps: slippage,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({
    required this.quote,
    required this.quoting,
    required this.failure,
    required this.side,
    required this.ticker,
  });

  final MemeQuote? quote;
  final bool quoting;
  final LoopChainException? failure;
  final MemeTradeSide side;
  final String ticker;

  @override
  Widget build(BuildContext context) {
    final value = quote;
    if (failure != null) {
      return LoopInlineUnavailable(
        key: const ValueKey<String>('meme-trade-quote-failed'),
        message: '没有取到报价 · ${memeFailureText(failure!)}',
        padding: EdgeInsets.zero,
      );
    }
    if (value == null) {
      return Text(
        quoting ? '正在报价…' : '输入金额后显示报价',
        key: const ValueKey<String>('meme-trade-quote-empty'),
        style: LoopType.caption.copyWith(color: LoopColors.text3),
      );
    }
    final refund = value.refund;
    return Column(
      key: const ValueKey<String>('meme-trade-quote'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopKeyValue(
          label: '得',
          value: side == MemeTradeSide.buy
              ? memeTokenLabel(value.out, ticker)
              : memeUsd1Label(value.out),
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        LoopKeyValue(
          label: '费',
          value: memeUsd1Label(value.fee, maxFractionDigits: 4),
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        LoopKeyValue(
          label: '影响',
          value: memeBpsLabel(value.priceImpactBps),
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        if (refund != null && refund > BigInt.zero)
          LoopKeyValue(
            label: '打满退回',
            value: memeUsd1Label(refund),
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),
        LoopProvenanceLine(
          key: const ValueKey<String>('meme-trade-quote-provenance'),
          sources: <String>[value.basisFromChain ? '链上曲线' : 'LOOP 链上索引'],
          observedAt: value.observedAt,
          padding: EdgeInsets.zero,
          detail: value.basisFromChain
              ? '报价按链上当前曲线计算。'
              : '链上暂时读不到，报价按索引快照计算，可能落后几个区块。',
        ),
      ],
    );
  }
}
