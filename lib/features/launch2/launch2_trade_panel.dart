import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_trade_panel.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// The one line a moved or expired price leaves in the panel (S134–S137 §4:
/// 「面板内一行，不弹 toast」).
const String launch2PriceMovedText = '价格已变化，已刷新';

/// 提前购 / 公开内盘 · the curve's buy / sell panel (decision 0139).
///
/// The S117 panel's shape — side, one amount field, the server's quote, one
/// confirm key that sits above the keypad — drawn inline on the project page
/// (no sheet over a sheet), plus what the v2 curve adds: the server's MAX
/// key, the cumulative quota bar (已用 / the instance's cap, decision 0197),
/// the 10% tax line and the
/// holder-list badge. In the priority hour a wallet outside the list sees
/// the panel greyed with the reason; a quote that expired or was overtaken
/// re-quotes in place with one line, never a toast or an error page.
///
/// The panel prepares the intent itself so a refusal stays in the panel;
/// [onPrepared] hands the intent to the page's signing exit.
class Launch2TradePanel extends ConsumerStatefulWidget {
  const Launch2TradePanel({
    required this.detail,
    required this.walletId,
    required this.onPrepared,
    super.key,
    this.locked = false,
    this.onStageMoved,
    this.onTopUp,
    this.onFaucet,
  });

  /// 「去充值」 under a balance refusal (decision 0153): the wallet's receive
  /// page. `null` shows no link.
  final VoidCallback? onTopUp;

  /// Opens the testnet faucet sheet (decision 0154); `null` while the
  /// server does not publish `testnetFaucet` as available.
  final VoidCallback? onFaucet;

  final Launch2InstanceDetail detail;

  /// A quote or prepare answered `409 LAUNCH2_STAGE_MISMATCH`: the stage on
  /// screen is stale (contract §3.3 — "treat it as not open yet and keep
  /// polling the detail"). The page re-reads; the panel keeps one quiet line.
  final VoidCallback? onStageMoved;

  /// The active wallet the quote and the intent are for; `null` disables the
  /// panel with the reason.
  final String? walletId;
  final Future<void> Function(Launch2Intent intent) onPrepared;

  /// A broadcast of ours is still settling: no second signature.
  final bool locked;

  @override
  ConsumerState<Launch2TradePanel> createState() => _Launch2TradePanelState();
}

class _Launch2TradePanelState extends ConsumerState<Launch2TradePanel> {
  final TextEditingController _amount = TextEditingController();
  final GlobalKey _confirmKey = GlobalKey();

  Launch2Side _side = Launch2Side.buy;
  Timer? _debounce;
  Timer? _expiry;
  int _request = 0;
  Launch2Quote? _quote;
  LoopChainException? _quoteFailure;
  bool _quoting = false;
  bool _preparing = false;
  String? _notice;
  LoopChainException? _prepareFailure;

  /// What the refused prepare asked to spend, for the shortfall line.
  Decimal? _preparedAmount;

  /// Set while the field holds the server's MAX, so a re-quote does not
  /// clear the line that explains it.
  bool _filledMax = false;

  Launch2InstanceDetail get _detail => widget.detail;
  String get _ticker => _detail.row.ticker;
  bool get _priority => _detail.stage == Launch2Stage.priority;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_amountChanged);
  }

  @override
  void didUpdateWidget(Launch2TradePanel old) {
    super.didUpdateWidget(old);
    // The priority hour ended into the public round: selling opens, the
    // holder list stops mattering. A sell picked in public that is now not
    // offered falls back to buy.
    if (_side == Launch2Side.sell && _detail.stage != Launch2Stage.public) {
      _side = Launch2Side.buy;
      _amount.clear();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _expiry?.cancel();
    _amount
      ..removeListener(_amountChanged)
      ..dispose();
    super.dispose();
  }

  Decimal? get _entered => launch2AmountFromInput(_amount.text);

  /// The holder-list rule in the priority hour, as the detail states it.
  bool get _listBlocked {
    if (!_priority) return false;
    final viewer = _detail.viewer;
    if (viewer == null) return false;
    final quote = _quote;
    if (quote != null && quote.eligibilityRequired && quote.eligible == false) {
      return true;
    }
    return !viewer.eligibleNow;
  }

  bool get _snapshotUnverified =>
      _quote?.eligibilityReasonCode == 'LAUNCH2_SNAPSHOT_UNVERIFIED' ||
      _prepareFailure?.reasonCode == 'LAUNCH2_SNAPSHOT_UNVERIFIED' ||
      (_priority &&
          _detail.snapshot.verification ==
              Launch2SnapshotVerification.mismatch);

  bool get _disabled =>
      widget.walletId == null ||
      _listBlocked ||
      _snapshotUnverified ||
      widget.locked;

  void _amountChanged() {
    _debounce?.cancel();
    _request += 1;
    final amount = _entered;
    setState(() {
      _quote = null;
      _quoteFailure = null;
      _prepareFailure = null;
      _quoting = amount != null;
      if (!_filledMax) _notice = null;
    });
    _filledMax = false;
    if (amount == null || _disabled) return;
    _debounce = Timer(memeQuoteDebounce, () => unawaited(_fetchQuote()));
  }

  Future<Launch2Quote?> _ask(Decimal amount) async {
    final walletId = widget.walletId;
    if (walletId == null) return null;
    return ref
        .read(launch2GatewayProvider)
        .quote(
          instanceId: _detail.instanceId,
          side: _side,
          amount: amount,
          walletId: walletId,
        );
  }

  Future<void> _fetchQuote({String? notice}) async {
    final amount = _entered;
    if (amount == null) return;
    final request = _request;
    setState(() => _quoting = true);
    try {
      final quote = await _ask(amount);
      if (!mounted || request != _request || quote == null) return;
      setState(() {
        _quote = quote;
        _quoting = false;
        if (notice != null) _notice = notice;
      });
      _armExpiry(quote);
      _revealConfirm();
    } on LoopChainException catch (failure) {
      if (!mounted || request != _request) return;
      setState(() {
        _quoteFailure = failure;
        _quoting = false;
      });
      if (failure.reasonCode == launch2StageMismatchCode) {
        widget.onStageMoved?.call();
      }
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

  /// A quote is good until its `deadline`; past it the panel asks again
  /// without a word (contract §3.3).
  void _armExpiry(Launch2Quote quote) {
    _expiry?.cancel();
    final now = ref.read(launch2ClockProvider)();
    final left = quote.deadline.difference(now);
    if (left.isNegative) return;
    _expiry = Timer(left, () {
      if (!mounted || !identical(_quote, quote)) return;
      _request += 1;
      unawaited(_fetchQuote());
    });
  }

  /// MAX is the server's (contract §3.3 `max.amountIn`): from the quote on
  /// screen, or from one asked for this key alone.
  Future<void> _fillMax() async {
    var quote = _quote;
    if (quote == null) {
      setState(() => _quoting = true);
      try {
        quote = await _ask(Decimal.one);
      } on LoopChainException catch (failure) {
        if (!mounted) return;
        setState(() {
          _quoteFailure = failure;
          _quoting = false;
        });
        if (failure.reasonCode == launch2StageMismatchCode) {
          widget.onStageMoved?.call();
        }
        return;
      }
      if (!mounted || quote == null) return;
    }
    final max = quote.maxAmountIn;
    if (max <= Decimal.zero) {
      setState(() {
        _quoting = false;
        _quote = quote;
      });
      return;
    }
    _filledMax = true;
    _amount.text = launch2InputText(max);
  }

  void _revealConfirm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _confirmKey.currentContext;
      if (!mounted || target == null || !target.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  Future<void> _confirm() async {
    final quote = _quote;
    final walletId = widget.walletId;
    if (quote == null ||
        walletId == null ||
        _preparing ||
        _detail.tradingHold != null) {
      return;
    }
    final now = ref.read(launch2ClockProvider)();
    if (!quote.deadline.isAfter(now)) {
      _request += 1;
      await _fetchQuote();
      return;
    }
    setState(() {
      _preparing = true;
      _prepareFailure = null;
      _preparedAmount = quote.amountIn;
      _notice = null;
    });
    try {
      final intent = await ref
          .read(launch2GatewayProvider)
          .prepareTrade(
            instanceId: _detail.instanceId,
            walletId: walletId,
            side: quote.side,
            amount: quote.amountIn,
            minOut: quote.minOut,
            deadline: quote.deadline,
          );
      if (!mounted) return;
      setState(() => _preparing = false);
      await widget.onPrepared(intent);
      if (!mounted) return;
      _amount.clear();
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() => _preparing = false);
      final reason = failure.reasonCode;
      if (failure.kind == LoopChainFailureKind.quoteExpired ||
          reason == 'LAUNCH2_QUOTE_EXPIRED') {
        // Expired: re-quote silently.
        _request += 1;
        await _fetchQuote();
        return;
      }
      if (reason == 'LAUNCH2_PRICE_MOVED') {
        // Overtaken by another order: one line and a fresh quote.
        _request += 1;
        await _fetchQuote(notice: launch2PriceMovedText);
        return;
      }
      if (reason == 'LAUNCH2_AMOUNT_ABOVE_MAX') {
        // The fresh quote carries `exceedsMax` and offers MAX.
        _request += 1;
        await _fetchQuote();
        return;
      }
      setState(() => _prepareFailure = failure);
      if (reason == launch2StageMismatchCode) widget.onStageMoved?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _prepareFailure = const LoopChainException(
          LoopChainFailureKind.unexpected,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewer = _detail.viewer;
    final template = _detail.template;
    final quote = _quote;
    final amount = _entered;
    // Decision 0197: the instance's own cap (S209 Factory parameter); a
    // missing figure reads as the old 5,000,000.
    final cap = launch2CurveCapOf(quote?.quotaCap ?? template.perAddressCap);
    final used = quote?.quotaUsed ?? viewer?.curve.cumulativeBought;
    final taxBps = _side == Launch2Side.buy
        ? template.curveBuyTaxBps
        : template.curveSellTaxBps;
    final listBlocked = _listBlocked;
    final notInList =
        listBlocked || _prepareFailure?.reasonCode == 'LAUNCH2_NOT_IN_SNAPSHOT';
    // Decision 0161: the field stays live (the quote may say why), the
    // confirm key does not.
    final hold = _detail.tradingHold;
    final canConfirm =
        hold == null &&
        !_disabled &&
        !notInList &&
        amount != null &&
        quote != null &&
        !quote.exceedsMax &&
        !_quoting &&
        !_preparing &&
        quote.expectedOut > Decimal.zero;
    final String? blockedLine = widget.walletId == null
        ? '还没有可用的钱包，激活钱包后可交易'
        : _snapshotUnverified
        ? launch2ReasonText('LAUNCH2_SNAPSHOT_UNVERIFIED')
        : notInList
        ? '提前购仅限名单内持有人，公开内盘开始后可买入'
        : null;
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_detail.stage == Launch2Stage.public) ...<Widget>[
          LoopSegBar(
            key: const ValueKey<String>('launch2-trade-side'),
            labels: const <String>['买入', '卖出'],
            padding: const EdgeInsets.only(bottom: 14),
            selectedIndex: _side == Launch2Side.buy ? 0 : 1,
            onSelected: (index) {
              final next = index == 0 ? Launch2Side.buy : Launch2Side.sell;
              if (next == _side) return;
              setState(() {
                _side = next;
                _quote = null;
                _notice = null;
              });
              _amount.clear();
            },
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          key: const ValueKey<String>('launch2-trade-amount'),
          controller: _amount,
          enabled: !_disabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          textInputAction: TextInputAction.done,
          maxLines: 1,
          style: LoopType.figureLg,
          decoration: InputDecoration(
            labelText: _side == Launch2Side.buy ? '支付（含税）' : '卖出',
            hintText: '0',
            suffixText: _side == Launch2Side.buy
                ? 'USD1'
                : loopTickerLabel(_ticker),
            suffixIcon: _MaxKey(onTap: _disabled ? null : _fillMax),
          ),
        ),
        const SizedBox(height: 10),
        _QuoteLines(
          quote: quote,
          quoting: _quoting,
          failure: _quoteFailure,
          side: _side,
          ticker: _ticker,
          cap: cap,
          onFillMax: _fillMax,
        ),
        if (_notice case final String line)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Launch2WarnLine(
              line,
              key: const ValueKey<String>('launch2-trade-notice'),
            ),
          ),
        if (_prepareFailure case final LoopChainException failure
            when failure.reasonCode != 'LAUNCH2_NOT_IN_SNAPSHOT' &&
                failure.reasonCode != 'LAUNCH2_SNAPSHOT_UNVERIFIED')
          _PrepareFailureLine(
            failure: launch2ActionFailure(
              failure,
              fallback: (failure) => _failureText(failure, cap),
              requested: _preparedAmount,
              ticker: _ticker,
            ),
            onTopUp: widget.onTopUp,
            onFaucet: widget.onFaucet,
          ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: _confirmKey,
          child: LoopButton(
            key: const ValueKey<String>('launch2-trade-confirm'),
            label: _preparing
                ? '正在准备…'
                : _side == Launch2Side.buy
                ? '确认买入'
                : '确认卖出',
            primary: true,
            block: true,
            onPressed: canConfirm ? () => unawaited(_confirm()) : null,
          ),
        ),
        if (hold != null)
          Launch2TradingHoldLine(
            key: const ValueKey<String>('launch2-trade-hold'),
            hold: hold,
          ),
      ],
    );
    // Decision 0166: the panel opens with the page's `.label`, its badge
    // and tax at the label's end (was decision 0149's 20 / 700 heading).
    return Column(
      key: const ValueKey<String>('launch2-trade-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Launch2SectionLabel(
          _priority ? '提前购' : '公开内盘',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_priority) ...<Widget>[
                LoopBadge(
                  viewer?.snapshotMember == true ? '名单内' : '不在名单',
                  key: const ValueKey<String>('launch2-eligibility-badge'),
                  kind: viewer?.snapshotMember == true
                      ? LoopBadgeKind.launch
                      : LoopBadgeKind.mute,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '税率 ${launch2BpsLabel(taxBps)}',
                key: const ValueKey<String>('launch2-trade-tax'),
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _QuotaBar(used: used, cap: cap, ticker: _ticker),
              const SizedBox(height: 12),
              if (blockedLine != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    blockedLine,
                    key: const ValueKey<String>('launch2-trade-blocked'),
                    style: LoopType.caption.copyWith(color: LoopColors.text2),
                  ),
                ),
              // Greyed, not hidden: the reader sees what opens later.
              Launch2Greyed(
                key: const ValueKey<String>('launch2-trade-controls'),
                greyed: blockedLine != null,
                child: controls,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A curve refusal, with the instance's cap in `LAUNCH2_QUOTA_EXHAUSTED`.
String _failureText(LoopChainException failure, Decimal cap) =>
    failure.reasonCode == 'LAUNCH2_QUOTA_EXHAUSTED'
    ? launch2QuotaExhaustedText(cap)
    : launch2FailureText(failure);

/// 累计额度：已用 / the instance's cap (decision 0197; both rounds share it;
/// selling does not restore it).
class _QuotaBar extends StatelessWidget {
  const _QuotaBar({
    required this.used,
    required this.cap,
    required this.ticker,
  });

  final Decimal? used;
  final Decimal cap;
  final String ticker;

  @override
  Widget build(BuildContext context) {
    final value = used;
    return Column(
      key: const ValueKey<String>('launch2-quota'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '累计额度',
              style: LoopType.caption.copyWith(color: LoopColors.text2),
            ),
            const Spacer(),
            Text(
              value == null
                  ? '— / ${launch2MemeFigure(cap)}'
                  : '${launch2MemeFigure(value)} / ${launch2MemeFigure(cap)}',
              key: const ValueKey<String>('launch2-quota-figure'),
              style: LoopType.figure,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LoopProgressBar(
          value: value == null ? null : launch2Share(value, cap),
          semanticLabel: value == null
              ? '累计额度暂时读不到'
              : '累计额度已用 ${launch2MemeFigure(value)} ${loopTickerLabel(ticker)}，'
                    '${launch2CurveCapSentence(cap)}',
        ),
      ],
    );
  }
}

/// MAX inside the amount field, in a 44pt touch target.
class _MaxKey extends StatelessWidget {
  const _MaxKey({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: '填入最大可买',
    excludeSemantics: true,
    child: LoopPressable(
      key: const ValueKey<String>('launch2-trade-max'),
      onTap: onTap,
      child: SizedBox(
        width: LoopTouch.minimum + 8,
        height: LoopTouch.minimum,
        child: Center(
          child: Text(
            'MAX',
            // R17 inline text action (decision 0190 L21).
            style: LoopTypography.withWeight(LoopType.label, FontWeight.w600)
                .copyWith(
                  color: onTap == null ? LoopColors.text3 : LoopColors.yellow,
                ),
          ),
        ),
      ),
    ),
  );
}

class _QuoteLines extends StatelessWidget {
  const _QuoteLines({
    required this.quote,
    required this.quoting,
    required this.failure,
    required this.side,
    required this.ticker,
    required this.cap,
    required this.onFillMax,
  });

  final Launch2Quote? quote;
  final bool quoting;
  final LoopChainException? failure;
  final Launch2Side side;
  final String ticker;

  /// The instance's per-address cap (decision 0197).
  final Decimal cap;
  final VoidCallback onFillMax;

  @override
  Widget build(BuildContext context) {
    final value = quote;
    if (failure != null) {
      return LoopInlineUnavailable(
        key: const ValueKey<String>('launch2-trade-quote-failed'),
        message: '没有取到报价 · ${_failureText(failure!, cap)}',
        padding: EdgeInsets.zero,
      );
    }
    if (value == null) {
      return Text(
        quoting ? '正在报价…' : '输入金额后显示报价',
        key: const ValueKey<String>('launch2-trade-quote-empty'),
        style: LoopType.caption.copyWith(color: LoopColors.text3),
      );
    }
    const pad = EdgeInsets.symmetric(vertical: 4);
    return Column(
      key: const ValueKey<String>('launch2-trade-quote'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (value.exceedsMax)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Launch2WarnLine(
                    '超出可${side == Launch2Side.buy ? '买' : '卖'}上限'
                    '（${launch2LimitedByText(value.limitedBy, cap: value.quotaCap)}）',
                    key: const ValueKey<String>('launch2-trade-exceeds'),
                  ),
                ),
                TextButton(
                  key: const ValueKey<String>('launch2-trade-fill-max'),
                  onPressed: onFillMax,
                  style: TextButton.styleFrom(
                    foregroundColor: LoopColors.yellow,
                    minimumSize: const Size(
                      LoopTouch.minimum,
                      LoopTouch.minimum,
                    ),
                  ),
                  child: Text(
                    side == Launch2Side.buy
                        ? '填入 ${launch2Usd1Label(value.maxAmountIn, maxFractionDigits: 4)}'
                        : '填入 ${launch2MemeLabel(value.maxAmountIn, ticker)}',
                  ),
                ),
              ],
            ),
          ),
        LoopKeyValue(
          label: side == Launch2Side.buy ? '预计获得' : '预计到手',
          value: side == Launch2Side.buy
              ? launch2MemeLabel(value.expectedOut, ticker)
              : launch2Usd1Label(value.expectedOut, maxFractionDigits: 4),
          padding: pad,
        ),
        LoopKeyValue(
          label: side == Launch2Side.buy ? '最少获得' : '最少到手',
          value: side == Launch2Side.buy
              ? launch2MemeLabel(value.minOut, ticker)
              : launch2Usd1Label(value.minOut, maxFractionDigits: 4),
          padding: pad,
        ),
        // Decision 0200: the curve has no slippage choice (0139: the
        // server's own tolerance is already inside `minOut`); say so next
        // to the figure instead of leaving the panel looking incomplete
        // beside the official pool's 0.5 / 1 / 3% selector.
        Text(
          launch2CurveMinOutNote(value.slippageBps),
          key: const ValueKey<String>('launch2-trade-min-out-note'),
          style: LoopType.captionSm.copyWith(color: LoopColors.text3),
        ),
        LoopKeyValue(
          label: '税 ${launch2BpsLabel(value.taxBps)}',
          value: launch2Usd1Label(value.taxUsd1, maxFractionDigits: 4),
          padding: pad,
        ),
        if (value.refundUsd1 > Decimal.zero)
          LoopKeyValue(
            label: '退回',
            value: launch2Usd1Label(value.refundUsd1, maxFractionDigits: 4),
            padding: pad,
          ),
        LoopKeyValue(
          label: '价格',
          value:
              '${launch2PriceLabel(value.priceBeforeUsd1)} → '
              '${launch2PriceLabel(value.priceAfterUsd1)}',
          padding: pad,
        ),
        LoopProvenanceLine(
          key: const ValueKey<String>('launch2-trade-quote-provenance'),
          sources: const <String>['链上曲线'],
          observedAt: value.quotedAt,
          padding: EdgeInsets.zero,
          detail:
              '报价按区块 ${value.basisBlockNumber} 的曲线计算，含 10% 税；'
              '滑点 ${launch2BpsLabel(value.slippageBps)}，到期自动重新报价。',
        ),
      ],
    );
  }
}

/// The refused prepare, right above 「确认买入 / 卖出」 (decision 0153).
class _PrepareFailureLine extends StatelessWidget {
  const _PrepareFailureLine({
    required this.failure,
    this.onTopUp,
    this.onFaucet,
  });

  final Launch2ActionFailure failure;
  final VoidCallback? onTopUp;
  final VoidCallback? onFaucet;

  @override
  Widget build(BuildContext context) => Launch2ActionFailureLine(
    key: const ValueKey<String>('launch2-trade-prepare-failed'),
    padding: const EdgeInsets.only(top: 6),
    message: failure.text,
    topUpKey: const ValueKey<String>('launch2-trade-topup'),
    onTopUp: failure.topUp ? onTopUp : null,
    faucetKey: const ValueKey<String>('launch2-trade-faucet'),
    onFaucet: failure.topUp ? onFaucet : null,
  );
}

/// The line under the curve's 「最少获得 / 最少到手」 (decision 0200).
String launch2CurveMinOutNote(int slippageBps) =>
    '按当前曲线价计算，已含 ${launch2BpsLabel(slippageBps)} 滑点保护，成交以链上为准';
