import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_trade_panel.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// 外盘交易 · the graduated page's buy / sell panel (decision 0145).
///
/// The curve panel's shape (decision 0139) — side, one amount field, the
/// server's quote, one confirm key above the keypad — drawn inline on the
/// project page, for the official pool: what the field fixes (pay / receive),
/// the 2% pool tax, a slippage choice and the least that comes out. The
/// panel prepares the intent itself so a refusal stays in the panel;
/// [onPrepared] hands it to the page's signing exit, which signs the
/// router approval first when the intent carries one.
class Launch2PoolTradePanel extends ConsumerStatefulWidget {
  const Launch2PoolTradePanel({
    required this.detail,
    required this.walletId,
    required this.onPrepared,
    super.key,
    this.holding,
    this.locked = false,
  });

  final Launch2InstanceDetail detail;
  final String? walletId;

  /// What the reader holds of the token, when known; MAX on a sell fills it.
  final Launch2PoolHolding? holding;
  final Future<void> Function(Launch2Intent intent) onPrepared;

  /// A broadcast of ours is still settling: no second signature.
  final bool locked;

  @override
  ConsumerState<Launch2PoolTradePanel> createState() =>
      _Launch2PoolTradePanelState();
}

class _Launch2PoolTradePanelState extends ConsumerState<Launch2PoolTradePanel> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _customSlippage = TextEditingController();
  final GlobalKey _confirmKey = GlobalKey();

  Launch2Side _side = Launch2Side.buy;
  Launch2PoolMode _mode = Launch2PoolMode.exactIn;
  int _presetSlippage = launch2PoolDefaultSlippageBps;
  bool _customSelected = false;
  Timer? _debounce;
  Timer? _expiry;
  int _request = 0;
  Launch2PoolQuote? _quote;

  /// The latest quote answered, kept for its balances while a new one runs.
  Launch2PoolQuote? _lastQuote;
  LoopChainException? _quoteFailure;
  bool _quoting = false;
  bool _preparing = false;
  String? _notice;
  LoopChainException? _prepareFailure;

  Launch2InstanceDetail get _detail => widget.detail;

  int? get _slippage => _customSelected
      ? launch2PoolSlippageFromInput(_customSlippage.text)
      : _presetSlippage;

  Decimal? get _entered => launch2AmountFromInput(_amount.text);

  @override
  void initState() {
    super.initState();
    _amount.addListener(_inputsChanged);
    _customSlippage.addListener(_inputsChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _expiry?.cancel();
    _amount
      ..removeListener(_inputsChanged)
      ..dispose();
    _customSlippage
      ..removeListener(_inputsChanged)
      ..dispose();
    super.dispose();
  }

  Launch2PoolTradeView _view() => launch2PoolTradeView(
    detail: _detail,
    walletId: widget.walletId,
    side: _side,
    mode: _mode,
    amount: _entered,
    slippageBps: _slippage,
    quote: _quote,
    quoting: _quoting,
    preparing: _preparing,
    locked: widget.locked,
    quoteFailure: _quoteFailure,
    holding: _holding,
  );

  /// The quote's balance once there is one, else the account's position.
  Launch2PoolHolding? get _holding => launch2PoolHoldingOf(
    quote: _quote ?? _lastQuote,
    position: widget.holding,
  );

  /// Any change to side, mode, amount or slippage drops the quote on screen
  /// and asks again after the debounce.
  void _inputsChanged() {
    _debounce?.cancel();
    _expiry?.cancel();
    _request += 1;
    final amount = _entered;
    final slippage = _slippage;
    final view = _view();
    final ask =
        amount != null &&
        slippage != null &&
        view.blockedLine == null &&
        !view.overHolding;
    setState(() {
      _quote = null;
      _quoteFailure = null;
      _prepareFailure = null;
      _quoting = ask;
      _notice = null;
    });
    if (!ask) return;
    _debounce = Timer(memeQuoteDebounce, () => unawaited(_fetchQuote()));
  }

  Future<void> _fetchQuote({String? notice}) async {
    final amount = _entered;
    final slippage = _slippage;
    final walletId = widget.walletId;
    if (amount == null || slippage == null || walletId == null) return;
    final request = _request;
    setState(() => _quoting = true);
    try {
      final quote = await ref
          .read(launch2GatewayProvider)
          .poolQuote(
            instanceId: _detail.instanceId,
            side: _side,
            mode: _mode,
            amount: amount,
            slippageBps: slippage,
            walletId: walletId,
          );
      if (!mounted || request != _request) return;
      setState(() {
        _quote = quote;
        _lastQuote = quote;
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

  /// A pool price moves with every swap: past `expiresAt` the panel asks
  /// again without a word.
  void _armExpiry(Launch2PoolQuote quote) {
    _expiry?.cancel();
    final now = ref.read(launch2ClockProvider)();
    final left = quote.expiresAt.difference(now);
    if (left.isNegative) return;
    _expiry = Timer(left, () {
      if (!mounted || !identical(_quote, quote)) return;
      _request += 1;
      unawaited(_fetchQuote());
    });
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

  void _fillMax() {
    final all = _holding?.sellableOrBalance;
    if (all == null || all <= Decimal.zero) return;
    _amount.text = launch2InputText(all);
  }

  void _setSide(Launch2Side side) {
    if (side == _side) return;
    _side = side;
    _mode = Launch2PoolMode.exactIn;
    _amount.text = '';
    _inputsChanged();
  }

  void _setMode(Launch2PoolMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _amount.text = '';
    _inputsChanged();
  }

  Future<void> _confirm() async {
    final quote = _quote;
    final walletId = widget.walletId;
    if (quote == null || walletId == null || _preparing) return;
    final now = ref.read(launch2ClockProvider)();
    if (!quote.expiresAt.isAfter(now)) {
      _request += 1;
      await _fetchQuote();
      return;
    }
    setState(() {
      _preparing = true;
      _prepareFailure = null;
      _notice = null;
    });
    try {
      final prepared = await ref
          .read(launch2GatewayProvider)
          .preparePoolTrade(
            instanceId: _detail.instanceId,
            walletId: walletId,
            side: quote.side,
            mode: quote.mode,
            amount: quote.requestedAmount,
            slippageBps: quote.slippageBps,
          );
      if (!mounted) return;
      setState(() => _preparing = false);
      await widget.onPrepared(prepared.intent);
      if (!mounted) return;
      _amount.text = '';
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() => _preparing = false);
      final reason = failure.reasonCode ?? '';
      if (failure.kind == LoopChainFailureKind.quoteExpired ||
          reason.endsWith('QUOTE_EXPIRED')) {
        _request += 1;
        await _fetchQuote();
        return;
      }
      if (reason.endsWith('PRICE_MOVED')) {
        _request += 1;
        await _fetchQuote(notice: launch2PoolPriceMovedText);
        return;
      }
      setState(() => _prepareFailure = failure);
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
    final view = _view();
    final greyed = view.blockedLine != null;
    final (inLabel, outLabel) = launch2PoolModeLabels(_side);
    final slippage = _slippage;
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSegBar(
          key: const ValueKey<String>('launch2-pool-side'),
          labels: const <String>['买入', '卖出'],
          selectedIndex: _side == Launch2Side.buy ? 0 : 1,
          padding: EdgeInsets.zero,
          onSelected: (index) =>
              _setSide(index == 0 ? Launch2Side.buy : Launch2Side.sell),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            LoopSeg(
              key: const ValueKey<String>('launch2-pool-mode-exactIn'),
              label: inLabel,
              selected: _mode == Launch2PoolMode.exactIn,
              quiet: true,
              onSelected: () => _setMode(Launch2PoolMode.exactIn),
            ),
            const SizedBox(width: 6),
            LoopSeg(
              key: const ValueKey<String>('launch2-pool-mode-exactOut'),
              label: outLabel,
              selected: _mode == Launch2PoolMode.exactOut,
              quiet: true,
              onSelected: () => _setMode(Launch2PoolMode.exactOut),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey<String>('launch2-pool-amount'),
          controller: _amount,
          enabled: !greyed,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          textInputAction: TextInputAction.done,
          maxLines: 1,
          style: LoopType.figureLg,
          decoration: InputDecoration(
            labelText: view.fieldLabel,
            hintText: '0',
            suffixText: view.fieldSuffix,
            suffixIcon: view.showMax
                ? _PoolMaxKey(onTap: greyed ? null : _fillMax)
                : null,
          ),
        ),
        if (view.holdingLine case final String line)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              line,
              key: const ValueKey<String>('launch2-pool-holding'),
              style: LoopType.caption.copyWith(color: LoopColors.text2),
            ),
          ),
        const SizedBox(height: 10),
        if (view.quoteFailureLine case final String line)
          LoopInlineUnavailable(
            key: const ValueKey<String>('launch2-pool-quote-failed'),
            message: line,
            padding: EdgeInsets.zero,
          )
        else if (view.lines.isEmpty)
          Text(
            view.quotePlaceholder ?? '',
            key: const ValueKey<String>('launch2-pool-quote-empty'),
            style: LoopType.caption.copyWith(
              color: view.overHolding ? LoopColors.warning : LoopColors.text3,
            ),
          )
        else
          Column(
            key: const ValueKey<String>('launch2-pool-quote'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final line in view.lines)
                LoopKeyValue(
                  key: ValueKey<String>('launch2-pool-line-${line.key}'),
                  label: line.label,
                  value: line.value,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
              if (_quote case final Launch2PoolQuote quote)
                LoopProvenanceLine(
                  key: const ValueKey<String>('launch2-pool-provenance'),
                  sources: const <String>['官方池路由'],
                  observedAt: quote.quotedAt,
                  padding: EdgeInsets.zero,
                  detail: view.provenance,
                ),
            ],
          ),
        if (view.balanceLine case final String line)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              line,
              key: const ValueKey<String>('launch2-pool-balance-short'),
              style: LoopType.caption.copyWith(color: LoopColors.warning),
            ),
          ),
        if (_notice case final String line)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              line,
              key: const ValueKey<String>('launch2-pool-notice'),
              style: LoopType.caption.copyWith(color: LoopColors.warning),
            ),
          ),
        if (_prepareFailure case final LoopChainException failure)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              launch2PoolFailureText(failure),
              key: const ValueKey<String>('launch2-pool-prepare-failed'),
              style: LoopType.caption.copyWith(color: LoopColors.warning),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          '滑点上限',
          style: LoopType.captionSm.copyWith(color: LoopColors.text3),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            for (final bps in launch2PoolSlippagePresets) ...<Widget>[
              LoopSeg(
                key: ValueKey<String>('launch2-pool-slippage-$bps'),
                label: launch2BpsLabel(bps),
                selected: !_customSelected && _presetSlippage == bps,
                onSelected: () {
                  _customSelected = false;
                  _presetSlippage = bps;
                  _inputsChanged();
                },
              ),
              const SizedBox(width: 6),
            ],
            LoopSeg(
              key: const ValueKey<String>('launch2-pool-slippage-custom'),
              label: '自定义',
              selected: _customSelected,
              onSelected: () {
                _customSelected = true;
                _inputsChanged();
              },
            ),
            if (_customSelected) ...<Widget>[
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey<String>(
                    'launch2-pool-slippage-custom-input',
                  ),
                  controller: _customSlippage,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
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
        KeyedSubtree(
          key: _confirmKey,
          child: LoopButton(
            key: const ValueKey<String>('launch2-pool-confirm'),
            label: view.confirmLabel,
            primary: true,
            block: true,
            onPressed: view.canConfirm ? () => unawaited(_confirm()) : null,
          ),
        ),
      ],
    );
    return Padding(
      key: const ValueKey<String>('launch2-pool-panel'),
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        4,
        LoopSpacing.page,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('外盘交易', style: LoopTypography.title(18)),
              const SizedBox(width: 8),
              const LoopBadge('官方池', kind: LoopBadgeKind.launch),
              const Spacer(),
              Text(
                view.taxLabel,
                key: const ValueKey<String>('launch2-pool-tax-label'),
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (view.blockedLine case final String line)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                key: const ValueKey<String>('launch2-pool-blocked'),
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
            ),
          Launch2Greyed(
            key: const ValueKey<String>('launch2-pool-controls'),
            greyed: greyed,
            child: controls,
          ),
        ],
      ),
    );
  }
}

/// MAX inside the amount field: everything that can be sold.
class _PoolMaxKey extends StatelessWidget {
  const _PoolMaxKey({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: '填入全部可卖',
    excludeSemantics: true,
    child: LoopPressable(
      key: const ValueKey<String>('launch2-pool-max'),
      onTap: onTap,
      child: SizedBox(
        width: LoopTouch.minimum + 8,
        height: LoopTouch.minimum,
        child: Center(
          child: Text(
            'MAX',
            style: LoopTypography.label(
              13,
              weight: FontWeight.w700,
              color: onTap == null ? LoopColors.text3 : LoopColors.lime,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 官方池 · 最新价 and 成交笔数 from the detail's `pool` object.
class Launch2PoolStats extends StatelessWidget {
  const Launch2PoolStats({required this.detail, super.key});

  final Launch2InstanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final pool = detail.pool;
    if (pool == null) {
      return const LoopInlineUnavailable(
        key: ValueKey<String>('launch2-pool-stats-unavailable'),
        icon: 'info',
        message: '官方池成交还在同步',
      );
    }
    final price = pool.lastPriceUsd1;
    return Column(
      key: const ValueKey<String>('launch2-pool-stats'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopKeyValue(
          key: const ValueKey<String>('launch2-pool-last-price'),
          label: '外盘最新价',
          value: price == null ? '还没有成交' : launch2PriceLabel(price),
        ),
        LoopKeyValue(
          key: const ValueKey<String>('launch2-pool-trade-count'),
          label: '外盘成交',
          value:
              '${loopGroupedFigure(pool.tradeCount.toString())} 笔 · '
              '买 ${loopGroupedFigure(pool.buyCount.toString())} / '
              '卖 ${loopGroupedFigure(pool.sellCount.toString())}',
        ),
        LoopKeyValue(
          key: const ValueKey<String>('launch2-pool-volume'),
          label: '24 小时成交额',
          value: launch2Usd1Label(pool.volume24hUsd1),
        ),
        if (pool.lastTradeAt case final DateTime at)
          LoopKeyValue(
            key: const ValueKey<String>('launch2-pool-last-trade'),
            label: '最近成交',
            value: loopDateTimeLabel(at),
          ),
      ],
    );
  }
}

/// The wallet Swap, one quiet link under the panel (decision 0145: no
/// longer the page's primary action).
class Launch2PoolSwapLink extends StatelessWidget {
  const Launch2PoolSwapLink({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page - 8),
      child: TextButton(
        key: const ValueKey<String>('launch2-go-swap'),
        onPressed: onOpen,
        style: TextButton.styleFrom(
          foregroundColor: LoopColors.text2,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.minimum),
        ),
        child: const Text('也可以在钱包兑换里交易'),
      ),
    ),
  );
}
