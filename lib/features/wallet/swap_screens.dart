import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/transfer_amount.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// `swap` · quote, review and confirm one Privy swap.
///
/// The confirm button has two independent gates: the `privySwap` capability
/// (backend configuration) and its `evidence` (device proof). While evidence
/// is pending the page still quotes and still shows every figure — it simply
/// cannot execute, and says so.
class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({super.key, this.onBack, this.onNavigate, this.clock});

  final VoidCallback? onBack;
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

  static const List<int> _slippageChoices = <int>[50, 100, 300];

  @override
  void dispose() {
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

    return LoopFocusPage(
      key: const ValueKey<String>('swap-screen'),
      archetype: LoopPageArchetype.action,
      title: '兑换',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('swap-route-action'),
          icon: 'chevron',
          label: '报价与费用明细',
          onPressed: quote == null
              ? null
              : () => _open('/wallet/swap/route', extra: quote),
        ),
      ],
      folio: LoopFolioPrimary(
        key: const ValueKey<String>('swap-folio'),
        kicker: 'SWAP QUOTE',
        heading: quote == null
            ? '钱包内兑换'
            : '${quote.quote.inputAmount.display} ${quote.sourceAsset.symbol}'
                  ' → ${quote.quote.estimatedOutputAmount.display} '
                  '${quote.destinationAsset.symbol}',
        caption: '报价、滑点、价格影响与费用都在同一页可核对。',
        stamp: quote == null ? null : 'REVIEW QUOTE',
      ),
      primaryAction: _primaryAction(capability, quote),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('swap-capability-block'),
              title: '兑换当前不可用',
              capability: capability,
              fallbackReasonCode: 'PRIVY_NOT_CONFIGURED',
            )
          : null,
      body: <Widget>[
        if (walletId == null || balancesState == null)
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
          if (capability.evidencePending)
            LoopNotice(
              key: const ValueKey<String>('swap-evidence-pending'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '兑换还在验证中，暂时不能执行',
              body: loopReasonCodeText(capability.evidenceReasonCode),
            ),
          _AssetField(
            keyPrefix: 'swap-source',
            label: '支付',
            symbol: _symbolFor(balances, _sourceAssetId),
            balance: _spendableFor(balances, _sourceAssetId),
            controller: _amount,
            onPick: () => unawaited(
              _pickAsset(balances!, (assetId) {
                setState(() {
                  _sourceAssetId = assetId;
                  _quote = null;
                });
              }),
            ),
            onAmountChanged: () => setState(() => _quote = null),
          ),
          _ReceiveField(
            symbol: _symbolFor(balances, _destinationAssetId),
            quote: quote,
            onPick: () => unawaited(
              _pickAsset(balances!, (assetId) {
                setState(() {
                  _destinationAssetId = assetId;
                  _quote = null;
                });
              }),
            ),
          ),
          const LoopLabel('滑点上限'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final bps in _slippageChoices)
                  LoopSeg(
                    key: ValueKey<String>('swap-slippage-$bps'),
                    label: '$bps bps',
                    selected: bps == _slippageBps,
                    onSelected: () => setState(() {
                      _slippageBps = bps;
                      _quote = null;
                    }),
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
              pausedActions: const <String>['获取报价', '兑换', '签名'],
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
          const LoopNotice(
            key: ValueKey<String>('swap-routing-notice'),
            title: '路由由供应商选择',
            body:
                'LOOP 不自建路由，也不做逐跳拆解。这里只展示 Privy 返回的最终报价；'
                '兑换所得资产直接进入本钱包。',
          ),
          const LoopNotice(
            key: ValueKey<String>('swap-power-notice'),
            icon: 'mine',
            title: '算力影响不可用',
            body: '买入后的算力变化暂时读不到，这里不做估算。',
          ),
        ],
      ],
    );
  }

  Widget? _primaryAction(
    LoopCapabilityProjection capability,
    LoopSwapQuoteView? quote,
  ) {
    if (quote == null) {
      final walletId = ref
          .watch(walletDirectoryControllerProvider)
          .value
          ?.activeWalletId;
      final ready =
          walletId != null &&
          _sourceAssetId != null &&
          _destinationAssetId != null &&
          _sourceAssetId != _destinationAssetId &&
          TransferAmount.tryParse(_amount.text.trim()) != null;
      return LoopButton(
        key: const ValueKey<String>('swap-quote-action'),
        label: _busy ? '报价中' : '获取报价',
        primary: true,
        block: true,
        onPressed: ready && !_busy
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
          label: expired
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

  Decimal? _spendableFor(LoopWalletBalances? balances, String? assetId) {
    if (balances == null || assetId == null) return null;
    final balance = balances.rowFor(assetId)?.balance;
    return balance is LoopBalanceAvailable ? balance.spendableBalance : null;
  }

  Future<void> _pickAsset(
    LoopWalletBalances balances,
    void Function(String assetId) onPicked,
  ) async {
    final picked = await showLoopSheet<String>(
      context,
      builder: (context) => _AssetPickerSheet(balances: balances),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _requestQuote(String walletId) async {
    final source = _sourceAssetId;
    final destination = _destinationAssetId;
    final amount = TransferAmount.tryParse(_amount.text.trim());
    if (_busy || source == null || destination == null || amount == null) {
      return;
    }
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
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _busy = false;
      });
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failure = const LoopChainException(LoopChainFailureKind.unexpected);
        _busy = false;
      });
    }
  }

  Future<void> _confirm(LoopSwapQuoteView quote) async {
    if (_busy) return;
    setState(() => _busy = true);
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
    required this.balance,
    required this.controller,
    required this.onPick,
    required this.onAmountChanged,
  });

  final String keyPrefix;
  final String label;
  final String? symbol;
  final Decimal? balance;
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
              balance == null
                  ? '读不到可用余额，这里不做估算。'
                  : '可动用 ${loopFormatDecimal(balance!)}',
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
  });

  final String? symbol;
  final LoopSwapQuoteView? quote;
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
                        ? '报价后显示'
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

class _AssetPickerSheet extends StatelessWidget {
  const _AssetPickerSheet({required this.balances});

  final LoopWalletBalances balances;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('选择资产'),
        for (final row in balances.balances)
          LoopRecordRow(
            key: ValueKey<String>('swap-pick-${row.assetId}'),
            leading: LoopTokenLogo(
              assetSymbol: row.symbol,
              fallbackMonogram: row.symbol,
            ),
            title: row.symbol,
            subtitle: row.name,
            onTap: () => Navigator.of(context).pop(row.assetId),
          ),
      ],
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
                  value: '${value.slippageBps} bps',
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
      folio: LoopFolioPrimary(
        key: const ValueKey<String>('swap-route-folio'),
        kicker: 'ROUTE & FEES',
        heading:
            '${value.estimatedOutputAmount.display} '
            '${quote.destinationAsset.symbol}',
        caption: '报价方、最少获得、滑点与价格影响逐项公开。',
        stamp: 'FINAL',
      ),
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
                      '（滑点 ${value.slippageBps} bps）',
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
                  value: '${value.gasEstimateRaw} gas',
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
