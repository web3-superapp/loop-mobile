import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_capability_refresh.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/money_asset_picker.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/transfer_amount.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// How long the pay amount rests before it is quoted by itself (decision
/// 0131, the MEME panel's pattern).
const Duration swapQuoteDebounce = Duration(milliseconds: 400);

/// `swap` · quote, review and confirm one Privy swap.
///
/// The confirm button has two independent gates: the `privySwap` capability
/// (backend configuration) and its `evidence` (device proof). While evidence
/// is pending the page still quotes and still shows every figure — it simply
/// cannot execute, and says so.
class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({
    super.key,
    this.onBack,
    this.onNavigate,
    this.clock,
    this.initialSourceAssetId,
    this.initialDestinationAssetId,
  });

  final VoidCallback? onBack;

  /// A pair another page asked for (decision 0120: a graduated MEME token's
  /// 「去兑换」). Only a selection: an asset the wallet does not list simply
  /// stays unnamed, and nothing is quoted until the owner asks.
  final String? initialSourceAssetId;
  final String? initialDestinationAssetId;
  final void Function(String location, {Object? extra})? onNavigate;
  final DateTime Function()? clock;

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen> {
  final TextEditingController _amount = TextEditingController();

  String? _sourceAssetId;
  String? _destinationAssetId;
  int _slippageBps = 50;
  bool _confirmPriceImpact = false;

  LoopSwapQuoteView? _quote;
  LoopChainException? _failure;
  bool _busy = false;

  /// The capability document is being re-read before the sheet opens.
  bool _checkingCapability = false;

  /// Typing, choosing an asset or a slippage asks for a quote by itself
  /// after [swapQuoteDebounce]; only the newest request's answer is kept.
  Timer? _debounce;
  int _quoteRequest = 0;

  static const List<int> _slippageChoices = <int>[50, 100, 300];

  @override
  void initState() {
    super.initState();
    _sourceAssetId = widget.initialSourceAssetId;
    _destinationAssetId = widget.initialDestinationAssetId;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amount.dispose();
    super.dispose();
  }

  void _open(String location, {Object? extra}) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location, extra: extra);
      return;
    }
    context.push(location, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.privySwap),
    );
    final blocked = moneyActionBlocks(
      ref.watch(swapQuoteGatewayProvider).mode,
      capability,
    );
    final walletId = watchActiveMoneyWalletId(ref, blocked: blocked);
    final balancesState = walletId == null
        ? null
        : ref.watch(walletBalancesControllerProvider(walletId));
    if (!blocked &&
        walletId != null &&
        balancesState != null &&
        balancesState.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .load(),
          );
        }
      });
    }
    final balances = balancesState?.value;
    final quote = _quote;
    // With the keyboard up the quote folio folds away so both amount boxes
    // stay in view, and the amount pad can always be put away (decision 0091).
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    return LoopFocusPage(
      key: const ValueKey<String>('swap-screen'),
      archetype: LoopPageArchetype.action,
      title: '兑换',
      onBack: widget.onBack,
      folioCollapsed: typing,
      keyboardAccessory: true,
      // 报价与费用明细 is a page about one quote. Without a quote it has
      // nothing to open, and the chevron that used to sit there took the tap,
      // changed nothing, and pushed no route at all.
      actions: <Widget>[
        // Decision 0133: 「路由由供应商选择」 and 「算力影响不可用」 ask nothing
        // of the reader. They were two cards under the form; they are this
        // (i) now, and the page is the form.
        LoopIconButton(
          key: const ValueKey<String>('swap-info-action'),
          icon: 'info',
          label: '关于兑换',
          onPressed: () => unawaited(showSwapInfoSheet(context)),
        ),
        if (quote != null)
          LoopIconButton(
            key: const ValueKey<String>('swap-route-action'),
            icon: 'chevron',
            label: '报价与费用明细',
            onPressed: () => _open('/wallet/swap/route', extra: quote),
          ),
      ],
      primaryAction: blocked ? null : _primaryAction(capability, quote),
      body: <Widget>[
        // A closed gate used to take the whole page. The prototype's swap is
        // two figure boxes and a button; the page keeps them, every figure a
        // dash, and the gate's own sentence stands where the quote would be
        // (audit item 4).
        if (blocked) ...<Widget>[
          const LoopFigureBox(
            key: ValueKey<String>('swap-source-blocked'),
            caption: '支付',
            figure: loopFigureDash,
          ),
          const LoopFigureBox(
            key: ValueKey<String>('swap-destination-blocked'),
            caption: '获得',
            figure: loopFigureDash,
          ),
          LoopCapabilityBlockCard(
            key: const ValueKey<String>('swap-capability-block'),
            label: '兑换当前不可用',
            capability: capability,
            fallbackReasonCode: 'PRIVY_NOT_CONFIGURED',
          ),
        ] else if (walletId == null || balancesState == null)
          LoopChainStateBlock(
            keyPrefix: 'swap-directory',
            phase: ref.watch(walletDirectoryControllerProvider).phase,
            failureKind: ref
                .watch(walletDirectoryControllerProvider)
                .failureKind,
            emptyMessage: '这个账号还没有可兑换的钱包',
            onRetry: () => unawaited(
              ref.read(walletDirectoryControllerProvider.notifier).reload(),
            ),
          )
        else if (!balancesState.isReady)
          LoopChainStateBlock(
            keyPrefix: 'swap-balances',
            phase: balancesState.phase,
            failureKind: balancesState.failureKind,
            emptyMessage: '这个钱包还没有可读资产',
            onRetry: () => unawaited(
              ref
                  .read(walletBalancesControllerProvider(walletId).notifier)
                  .reload(),
            ),
          )
        else ...<Widget>[
          // One sentence, not two: the title used to restate the reason code
          // printed directly under it (「兑换还在验证中，暂时不能执行」 over
          // 「兑换还在验证中，可以查看报价，但不能执行。」).
          //
          // Decision 0133: a real limit, so it stays on the page — as one
          // small line, not a banner over the form.
          if (capability.evidencePending)
            LoopInlineUnavailable(
              key: const ValueKey<String>('swap-evidence-pending'),
              message: loopReasonCodeText(capability.evidenceReasonCode),
            ),
          _AssetField(
            keyPrefix: 'swap-source',
            label: '支付',
            symbol: _symbolFor(balances, _sourceAssetId),
            balanceLine: _balanceLineFor(balances, _sourceAssetId),
            controller: _amount,
            onPick: () => unawaited(
              _pickAsset(balances!, source: true, walletId: walletId),
            ),
            onAmountChanged: () => _inputsChanged(walletId),
          ),
          Center(
            child: LoopIconButton(
              key: const ValueKey<String>('swap-flip'),
              icon: 'swap-vert',
              label: '互换支付与获得',
              framed: true,
              onPressed: _sourceAssetId == null && _destinationAssetId == null
                  ? null
                  : () => _flip(walletId),
            ),
          ),
          _ReceiveField(
            symbol: _symbolFor(balances, _destinationAssetId),
            quote: quote,
            quoting: _busy && quote == null,
            onPick: () => unawaited(
              _pickAsset(balances!, source: false, walletId: walletId),
            ),
          ),
          const LoopLabel('滑点上限'),
          // `.segs`: one row of chips, each as wide as the step it names.
          // The 「50 bps」 label was trade-desk vocabulary — the percentage is
          // the same number in the unit the chooser already owns.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final bps in _slippageChoices)
                  LoopSeg(
                    key: ValueKey<String>('swap-slippage-$bps'),
                    label: moneySlippageLabel(bps),
                    selected: bps == _slippageBps,
                    onSelected: () {
                      _slippageBps = bps;
                      _inputsChanged(walletId);
                    },
                  ),
              ],
            ),
          ),
          if (MoneyPolicyNotice.covers(_failure))
            MoneyPolicyNotice(
              blockKey: 'swap-permission',
              failure: _failure!,
              onOpenSecurity: () => _open('/profile/security'),
            )
          // A quote that never reached the provider has not prepared, signed
          // or executed anything. The step pauses instead of erroring.
          else if (MoneyOfflinePause.covers(_failure))
            MoneyOfflinePause(
              blockKey: 'swap-quote-offline',
              failureKind: _failure?.kind,
              pausedActions: const <String>['报价', '兑换', '签名'],
              onRetry: () => unawaited(_requestQuote(walletId)),
            )
          else if (_failure != null)
            LoopErrorState(
              key: const ValueKey<String>('swap-quote-error'),
              title: '没有取到报价',
              reason: loopChainFailureReason(_failure!.kind),
              onRetry: () => unawaited(_requestQuote(walletId)),
            ),
          if (quote != null) ...<Widget>[
            _QuoteFacts(quote: quote, clock: widget.clock),
            _PriceImpactNotice(quote: quote),
            if (quote.quote.priceImpact.requiresConfirmation)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: CheckboxListTile(
                  key: const ValueKey<String>('swap-confirm-price-impact'),
                  value: _confirmPriceImpact,
                  onChanged: (value) =>
                      setState(() => _confirmPriceImpact = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('我已知晓价格影响在 1%–5% 之间，仍要继续'),
                ),
              ),
            LoopButton(
              key: const ValueKey<String>('swap-route-entry'),
              label: '报价明细与费用',
              block: true,
              onPressed: () => _open('/wallet/swap/route', extra: quote),
            ),
          ],
        ],
      ],
    );
  }

  Widget? _primaryAction(
    LoopCapabilityProjection capability,
    LoopSwapQuoteView? quote,
  ) {
    if (quote == null) {
      // There is nothing to press before a quote: it is asked for by
      // itself, and the button only says where that stands.
      final amountReady = TransferAmount.tryParse(_amount.text.trim()) != null;
      final walletId = ref
          .watch(walletDirectoryControllerProvider)
          .value
          ?.activeWalletId;
      return LoopButton(
        key: const ValueKey<String>('swap-quote-action'),
        label: _busy
            ? '报价中…'
            : _sourceAssetId == null || _destinationAssetId == null
            ? '选择支付与获得的资产'
            : !amountReady
            ? '输入数量后自动报价'
            : _failure != null
            ? '重新报价'
            : '报价中…',
        primary: true,
        block: true,
        onPressed: !_busy && amountReady && _failure != null && walletId != null
            ? () => unawaited(_requestQuote(walletId))
            : null,
      );
    }
    final impact = quote.quote.priceImpact;
    return MoneyCountdown(
      expiresAt: quote.quote.expiresAt,
      clock: widget.clock,
      builder: (context, remaining) {
        final expired = remaining == Duration.zero;
        final allowed =
            !expired &&
            !_busy &&
            capability.isUsable &&
            !impact.isBlocked &&
            (!impact.requiresConfirmation || _confirmPriceImpact);
        return LoopButton(
          key: const ValueKey<String>('swap-confirm-action'),
          label: _checkingCapability
              ? moneyCapabilityCheckingLabel
              : expired
              ? '报价已过期 · 重新报价'
              : capability.evidencePending
              ? '兑换还在验证中'
              : '兑换（${moneyCountdownLabel(remaining)}）',
          primary: true,
          block: true,
          onPressed: expired && !_busy
              ? () => unawaited(_requestQuote(quote.walletId))
              : allowed
              ? () => unawaited(_confirm(quote))
              : null,
        );
      },
    );
  }

  String? _symbolFor(LoopWalletBalances? balances, String? assetId) {
    if (balances == null || assetId == null) return null;
    return balances.rowFor(assetId)?.symbol;
  }

  /// The sentence under the pay field.
  ///
  /// 「读不到可用余额」 is a read failure and must only be said when a read
  /// failed. Before an asset is chosen there is nothing to read — the wallet
  /// page one tap away was showing 2.99 USDT while this line claimed the
  /// balance could not be read — and when the chain read for the chosen asset
  /// did fail, the server's own reason is what belongs here.
  String _balanceLineFor(LoopWalletBalances? balances, String? assetId) {
    if (assetId == null) return '先选择要支付的资产，这里会显示它的可动用余额。';
    if (balances == null) return '余额还没有读到。';
    final row = balances.rowFor(assetId);
    if (row == null) return '这个钱包没有这一行，读不到它的余额。';
    return switch (row.balance) {
      LoopBalanceAvailable(spendableBalance: final spendable) =>
        '可动用 ${loopFormatDecimal(spendable)} ${row.symbol}',
      LoopBalanceUnavailable(reasonCode: final reasonCode) =>
        loopReasonCodeText(reasonCode),
    };
  }

  Future<void> _pickAsset(
    LoopWalletBalances balances, {
    required bool source,
    required String walletId,
  }) async {
    final picked = await showMoneyAssetPicker(
      context,
      balances: balances,
      rowKeyPrefix: 'swap-pick',
      selectedAssetId: source ? _sourceAssetId : _destinationAssetId,
      // The side that pays needs something to pay with; the side that
      // receives can be an asset this wallet does not hold yet.
      requireBalance: source,
      title: source ? '选择支付资产' : '选择获得资产',
    );
    if (picked == null || !mounted) return;
    final other = source ? _destinationAssetId : _sourceAssetId;
    if (picked == other) {
      // Choosing the other side's asset turns the pair around.
      _flip(walletId);
      return;
    }
    if (source) {
      _sourceAssetId = picked;
    } else {
      _destinationAssetId = picked;
    }
    _inputsChanged(walletId);
  }

  /// 互换: the pay and receive assets trade places; the typed amount stays
  /// the amount paid and is quoted again.
  void _flip(String walletId) {
    final source = _sourceAssetId;
    _sourceAssetId = _destinationAssetId;
    _destinationAssetId = source;
    _inputsChanged(walletId);
  }

  /// Drops the quote every changed input makes stale and asks for a new one
  /// once the inputs rest.
  void _inputsChanged(String walletId) {
    _debounce?.cancel();
    _quoteRequest += 1;
    final ready =
        _sourceAssetId != null &&
        _destinationAssetId != null &&
        _sourceAssetId != _destinationAssetId &&
        TransferAmount.tryParse(_amount.text.trim()) != null;
    setState(() {
      _quote = null;
      _failure = null;
      _confirmPriceImpact = false;
      _busy = ready;
    });
    if (!ready) return;
    _debounce = Timer(
      swapQuoteDebounce,
      () => unawaited(_requestQuote(walletId, auto: true)),
    );
  }

  Future<void> _requestQuote(String walletId, {bool auto = false}) async {
    final source = _sourceAssetId;
    final destination = _destinationAssetId;
    final amount = TransferAmount.tryParse(_amount.text.trim());
    if ((_busy && !auto) ||
        source == null ||
        destination == null ||
        source == destination ||
        amount == null) {
      return;
    }
    _debounce?.cancel();
    final request = auto ? _quoteRequest : ++_quoteRequest;
    setState(() {
      _busy = true;
      _failure = null;
      _confirmPriceImpact = false;
    });
    try {
      final quote = await ref
          .read(swapQuoteGatewayProvider)
          .loadQuote(
            walletId: walletId,
            sourceAssetId: source,
            destinationAssetId: destination,
            amount: amount.wire,
            slippageBps: _slippageBps,
          );
      if (!mounted || request != _quoteRequest) return;
      setState(() {
        _quote = quote;
        _busy = false;
      });
    } on LoopChainException catch (failure) {
      if (!mounted || request != _quoteRequest) return;
      setState(() {
        _failure = failure;
        _busy = false;
      });
    } catch (_) {
      if (!mounted || request != _quoteRequest) return;
      setState(() {
        _failure = const LoopChainException(LoopChainFailureKind.unexpected);
        _busy = false;
      });
    }
  }

  Future<void> _confirm(LoopSwapQuoteView quote) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _checkingCapability = true;
    });
    // S88d: the server's current answer decides whether an intent is prepared
    // and the sheet opened. A closed gate falls back to the page's own block.
    await loopRefreshCapabilitiesBeforeSigning(ref);
    if (!mounted) return;
    final capability = ref.read(
      loopCapabilityProvider(LoopV2CapabilityId.privySwap),
    );
    final closed =
        moneyActionBlocks(
          ref.read(swapQuoteGatewayProvider).mode,
          capability,
        ) ||
        !capability.isUsable;
    setState(() {
      _checkingCapability = false;
      if (closed) _busy = false;
    });
    if (closed) return;
    try {
      final intent = await ref
          .read(walletIntentsGatewayProvider)
          .prepareSwap(
            walletId: quote.walletId,
            quoteId: quote.quote.quoteId,
            confirmPriceImpact: _confirmPriceImpact,
          );
      if (!mounted) return;
      setState(() => _busy = false);
      final outcome = await showMoneySignSheet(
        context,
        intent: intent,
        signer: ref.read(moneyActionSignerProvider),
        clock: widget.clock,
      );
      if (!mounted || outcome == null) return;
      if (outcome.opensResult) {
        _open('/wallet/tx/result?intentId=${intent.intentId}');
      }
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        _busy = false;
        // A consumed or expired quote can never be reused: the page drops it
        // so the owner re-quotes instead of confirming stale numbers.
        if (failure.kind == LoopChainFailureKind.quoteExpired) _quote = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failure = const LoopChainException(LoopChainFailureKind.unexpected);
        _busy = false;
      });
    }
  }
}

class _AssetField extends StatelessWidget {
  const _AssetField({
    required this.keyPrefix,
    required this.label,
    required this.symbol,
    required this.balanceLine,
    required this.controller,
    required this.onPick,
    required this.onAmountChanged,
  });

  final String keyPrefix;
  final String label;
  final String? symbol;

  /// What this field says about the balance behind it. Built by the page, so
  /// "not chosen yet" is never rendered as "could not be read".
  final String balanceLine;
  final TextEditingController controller;
  final VoidCallback onPick;
  final VoidCallback onAmountChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: LoopSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(label, style: LoopMono.label),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: ValueKey<String>('$keyPrefix-amount'),
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    maxLength: TransferAmount.maxWireLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    onChanged: (_) => onAmountChanged(),
                    decoration: const InputDecoration(
                      labelText: '数量',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                LoopButton(
                  key: ValueKey<String>('$keyPrefix-pick'),
                  label: symbol ?? '选择资产',
                  onPressed: onPick,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              balanceLine,
              key: ValueKey<String>('$keyPrefix-balance'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiveField extends StatelessWidget {
  const _ReceiveField({
    required this.symbol,
    required this.quote,
    required this.onPick,
    this.quoting = false,
  });

  final String? symbol;
  final LoopSwapQuoteView? quote;
  final bool quoting;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LoopSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('获得', style: LoopMono.label),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    key: const ValueKey<String>('swap-receive-amount'),
                    quote == null
                        ? (quoting ? '报价中…' : '报价后显示')
                        : quote!.quote.estimatedOutputAmount.display,
                    style: LoopMono.headline,
                  ),
                ),
                const SizedBox(width: 8),
                LoopButton(
                  key: const ValueKey<String>('swap-destination-pick'),
                  label: symbol ?? '选择资产',
                  onPressed: onPick,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteFacts extends StatelessWidget {
  const _QuoteFacts({required this.quote, this.clock});

  final LoopSwapQuoteView quote;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final value = quote.quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: LoopSurfaceCard(
            key: const ValueKey<String>('swap-quote-facts'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopKeyValue(
                  label: '最少获得',
                  value:
                      '${value.minimumOutputAmount.display} '
                      '${quote.destinationAsset.symbol}',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: '滑点上限',
                  value: moneySlippageLabel(value.slippageBps),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: '价格影响',
                  value: swapPriceImpactLabel(value.priceImpact),
                  valueUp:
                      value.priceImpact.decision ==
                      LoopPriceImpactDecision.allowed,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: '平台费',
                  value: value.platformFeeBps == null
                      ? '未设置'
                      : '${value.platformFeeBps} bps',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: '单笔上限',
                  value:
                      '${loopFormatUsd(quote.canary.inputValueUsd)} / '
                      '${loopFormatUsd(quote.canary.canaryMaxUsd)}',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ],
            ),
          ),
        ),
        LoopProvenanceFooter(
          key: const ValueKey<String>('swap-quote-provenance'),
          text:
              '报价方 ${value.provider} · 报价于 '
              '${loopRelativeTime(value.quotedAt, now: clock?.call())}'
              '${quote.policy.isPendingProductConfirmation ? ' · 待产品确认' : ''}',
        ),
      ],
    );
  }
}

class _PriceImpactNotice extends StatelessWidget {
  const _PriceImpactNotice({required this.quote});

  final LoopSwapQuoteView quote;

  @override
  Widget build(BuildContext context) {
    final impact = quote.quote.priceImpact;
    return switch (impact.decision) {
      LoopPriceImpactDecision.allowed => const SizedBox.shrink(),
      LoopPriceImpactDecision.confirm => const LoopNotice(
        key: ValueKey<String>('swap-impact-confirm'),
        icon: 'warn',
        tone: LoopNoticeTone.warn,
        title: '价格影响在 1%–5% 之间',
        body:
            '这笔兑换会明显推动价格。滑点与价格影响是两件事：滑点是你设定的上限，'
            '价格影响是这笔成交本身造成的偏移。',
      ),
      LoopPriceImpactDecision.blocked => LoopNotice(
        key: const ValueKey<String>('swap-impact-blocked'),
        icon: 'warn',
        tone: LoopNoticeTone.danger,
        title: '价格影响超过硬阻断线',
        body: loopReasonCodeText(impact.reasonCode),
      ),
    };
  }
}

/// zh-CN label for a price impact. An unavailable impact never renders as 0 %.
String swapPriceImpactLabel(LoopSwapPriceImpact impact) {
  final value = impact.value;
  if (!impact.available || value == null) {
    return '无法定价';
  }
  return loopFormatPercent(value * Decimal.fromInt(100));
}

// ---------------------------------------------------------------------------
// swap-route · read-only quote detail
// ---------------------------------------------------------------------------

/// `swap-route` · the quote's own numbers, opened from `swap`.
///
/// It is read-only by design: confirming happens on `swap`, against the same
/// quote object, so this page can never carry a stale figure into a signature.
class SwapRouteScreen extends StatelessWidget {
  const SwapRouteScreen({required this.quote, super.key, this.onBack});

  final LoopSwapQuoteView quote;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final value = quote.quote;
    return LoopFocusPage(
      key: const ValueKey<String>('swap-route-screen'),
      archetype: LoopPageArchetype.record,
      title: '报价与费用',
      onBack: onBack,
      primaryAction: LoopButton(
        key: const ValueKey<String>('swap-route-back'),
        label: '返回兑换并确认',
        primary: true,
        block: true,
        onPressed: onBack ?? () => Navigator.of(context).pop(),
      ),
      body: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: LoopSurfaceCard(
            key: const ValueKey<String>('swap-route-amounts'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopKeyValue(
                  label: '支付',
                  value:
                      '${value.inputAmount.display} ${quote.sourceAsset.symbol}',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: '预计获得',
                  value:
                      '${value.estimatedOutputAmount.display} '
                      '${quote.destinationAsset.symbol}',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: '最少获得',
                  value:
                      '${value.minimumOutputAmount.display} '
                      '${quote.destinationAsset.symbol}'
                      '（滑点 ${moneySlippageLabel(value.slippageBps)}）',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ],
            ),
          ),
        ),
        const LoopLabel('费用构成'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: LoopSurfaceCard(
            key: const ValueKey<String>('swap-route-fees'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopKeyValue(
                  label: '网络费估算',
                  value: '${loopGroupedFigure(value.gasEstimateRaw)} gas',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: 'LOOP 服务费',
                  value: value.platformFeeBps == null
                      ? '未设置'
                      : '${value.platformFeeBps} bps',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: '价格影响',
                  value: swapPriceImpactLabel(value.priceImpact),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: '市场估值',
                  value: value.priceImpact.marketValueUsd == null
                      ? '无法定价'
                      : loopFormatUsd(value.priceImpact.marketValueUsd!),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ],
            ),
          ),
        ),
        LoopProvenanceFooter(
          key: const ValueKey<String>('swap-route-provenance'),
          text:
              '报价方 ${value.provider} · 定价出处 '
              '${value.priceImpact.priceSource ?? '未标注'} · '
              '有效期 ${quote.policy.quoteTtlSeconds} 秒',
        ),
        const LoopNotice(
          key: ValueKey<String>('swap-route-notice'),
          title: '只展示最终报价',
          body: '只有报价方提供路径时才会显示逐跳明细，这次没有提供。',
        ),
      ],
    );
  }
}

/// What the 兑换 page's (i) says (decision 0133): the two explanations that
/// used to stand under the form as cards, word for word.
Future<void> showSwapInfoSheet(BuildContext context) => showLoopInfoSheet(
  context,
  title: '关于兑换',
  sheetKey: 'swap-info-sheet',
  notes: const <LoopInfoNote>[
    LoopInfoNote(
      key: ValueKey<String>('swap-routing-notice'),
      title: '路由由供应商选择',
      body:
          'LOOP 不自建路由，也不做逐跳拆解。这里只展示 Privy 返回的最终报价；'
          '兑换所得资产直接进入本钱包。',
    ),
    LoopInfoNote(
      key: ValueKey<String>('swap-power-notice'),
      title: '算力影响不可用',
      body: '买入后的算力变化暂时读不到，这里不做估算。',
    ),
  ],
);
