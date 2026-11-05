import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
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
import 'package:loop_mobile/features/wallet/wallet_segmented_control.dart';
import 'package:loop_mobile/features/wallet/transfer_amount.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// How long the pay amount rests before it is quoted by itself (decision
/// 0131, the MEME panel's pattern).
const Duration swapQuoteDebounce = Duration(milliseconds: 400);

/// Decision 0282 (loop-api 0198): Privy swaps on BSC mainnet only. An asset
/// on any other chain slot — the Launch testnet — never reaches the swap
/// picker and is never quoted.
bool swapIsMainnetAssetId(String assetId) =>
    assetId.startsWith('$loopPrimaryChainId:');

/// [balances] with only the rows a swap may pay from or receive into.
LoopWalletBalances swapMainnetBalances(LoopWalletBalances balances) {
  if (balances.balances.every((row) => swapIsMainnetAssetId(row.assetId))) {
    return balances;
  }
  return LoopWalletBalances(
    walletId: balances.walletId,
    snapshot: balances.snapshot,
    gasReservePolicy: balances.gasReservePolicy,
    balances: <LoopAssetBalanceRow>[
      for (final row in balances.balances)
        if (swapIsMainnetAssetId(row.assetId)) row,
    ],
    netWorth: balances.netWorth,
    launchChain: balances.launchChain,
    launchUsd1: balances.launchUsd1,
  );
}

/// True only when every mainnet row was read and every one is zero
/// (decision 0282). A failed read is not zero: the page then keeps its form
/// and the picker says which row could not be read.
bool swapHasNoMainnetBalance(LoopWalletBalances balances) =>
    balances.balances.every(
      (row) => switch (row.balance) {
        LoopBalanceAvailable(displayBalance: final display) =>
          display <= Decimal.zero,
        LoopBalanceUnavailable() => false,
      },
    );

/// `swap` · quote, review and confirm one Privy swap.
///
/// The confirm button has two independent gates: the `privySwap` capability
/// (backend configuration) and its `evidence` (device proof). While evidence
/// is pending the page still quotes and still shows every figure — it simply
/// cannot execute, and says so. Once the server records it `confirmed`
/// (loop-api decision 0198, `PRIVY_SWAP_EXECUTION_ENABLED=on`) the button is
/// gated by the capability and, on the sheet, by the intent's own
/// `signing.allowed` — the quote's unavailable simulation never closes it.
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

  /// Another page asked for an asset that is not on BSC mainnet (decision
  /// 0282). It was dropped, and the page says why once.
  bool _pairOffMainnet = false;

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
    _sourceAssetId = _mainnetOnly(widget.initialSourceAssetId);
    _destinationAssetId = _mainnetOnly(widget.initialDestinationAssetId);
  }

  String? _mainnetOnly(String? assetId) {
    if (assetId == null || swapIsMainnetAssetId(assetId)) return assetId;
    _pairOffMainnet = true;
    return null;
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
    final read = balancesState?.value;
    final balances = read == null ? null : swapMainnetBalances(read);
    final empty =
        !blocked &&
        walletId != null &&
        (balancesState?.isReady ?? false) &&
        balances != null &&
        swapHasNoMainnetBalance(balances);
    final quote = _quote;
    // With the keyboard up the quote folio folds away so both amount boxes
    // stay in view, and the amount pad can always be put away (decision 0091).
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    return LoopFocusPage(
      key: const ValueKey<String>('swap-screen'),
      archetype: LoopPageArchetype.action,
      title: context.l10n.common_swap,
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
          label: context.l10n.wallet_swapScreensSwapInfoActionLabel,
          onPressed: () => unawaited(showSwapInfoSheet(context)),
        ),
        if (quote != null)
          LoopIconButton(
            key: const ValueKey<String>('swap-route-action'),
            icon: 'chevron',
            label: context.l10n.wallet_swapScreensSwapRouteActionLabel,
            onPressed: () => _open('/wallet/swap/route', extra: quote),
          ),
      ],
      primaryAction: blocked || empty
          ? null
          : _primaryAction(capability, quote),
      body: <Widget>[
        // A closed gate used to take the whole page. The prototype's swap is
        // two figure boxes and a button; the page keeps them, every figure a
        // dash, and the gate's own sentence stands where the quote would be
        // (audit item 4).
        if (blocked) ...<Widget>[
          LoopFigureBox(
            key: ValueKey<String>('swap-source-blocked'),
            caption: context.l10n.common_pay,
            figure: loopFigureDash,
          ),
          LoopFigureBox(
            key: ValueKey<String>('swap-destination-blocked'),
            caption:
                context.l10n.wallet_swapScreensSwapDestinationBlockedCaption,
            figure: loopFigureDash,
          ),
          LoopCapabilityBlockCard(
            key: const ValueKey<String>('swap-capability-block'),
            label: context.l10n.wallet_swapScreensSwapCapabilityBlockLabel,
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
            emptyMessage: context.l10n.wallet_swapScreensEmptyMessage,
            onRetry: () => unawaited(
              ref.read(walletDirectoryControllerProvider.notifier).reload(),
            ),
          )
        else if (empty)
          // Decision 0282: nothing on BSC mainnet to pay with. The form would
          // only offer a picker whose every row is folded away; the page says
          // so and hands over the one next step, 接收.
          LoopEmptyState(
            key: const ValueKey<String>('swap-no-mainnet-balance'),
            title: context.l10n.wallet_swapNoMainnetBalanceTitle,
            message: context.l10n.wallet_swapMainnetOnly,
            showMessage: true,
            action: LoopButton(
              key: const ValueKey<String>('swap-receive-entry'),
              label: context.l10n.common_receive,
              primary: true,
              onPressed: () => _open(WalletRoute.receive(walletId)),
            ),
          )
        else if (!balancesState.isReady)
          LoopChainStateBlock(
            keyPrefix: 'swap-balances',
            phase: balancesState.phase,
            failureKind: balancesState.failureKind,
            emptyMessage: context.l10n.wallet_moneyAssetPickerTitle2,
            onRetry: () => unawaited(
              ref
                  .read(walletBalancesControllerProvider(walletId).notifier)
                  .reload(),
            ),
          )
        else ...<Widget>[
          if (_pairOffMainnet)
            LoopNotice(
              key: const ValueKey<String>('swap-mainnet-only'),
              tone: LoopNoticeTone.warn,
              icon: 'warn',
              body: context.l10n.wallet_swapMainnetOnly,
              margin: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                0,
                LoopSpacing.page,
                12,
              ),
            ),
          // One sentence, not two: the title used to restate the reason code
          // printed directly under it (「兑换还在验证中，暂时不能执行」 over
          // 「兑换还在验证中，可以查看报价，但不能执行。」).
          //
          // Decision 0133: a real limit, so it stays on the page. UX-016
          // (decision 0257): it is the shared warning card, not a bare line
          // in a style of its own.
          if (capability.evidencePending)
            LoopNotice(
              key: const ValueKey<String>('swap-evidence-pending'),
              tone: LoopNoticeTone.warn,
              icon: 'warn',
              body: loopReasonCodeText(capability.evidenceReasonCode),
              margin: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                0,
                LoopSpacing.page,
                12,
              ),
            ),
          // UX-016 (decision 0257, 图 46): 支付 and 获得 on one card, a
          // hairline between them and ⇅ centred on that hairline.
          Padding(
            key: const ValueKey<String>('swap-panel'),
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              0,
              LoopSpacing.page,
              12,
            ),
            child: LoopSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _AssetField(
                    keyPrefix: 'swap-source',
                    label: context.l10n.common_pay,
                    symbol: _symbolFor(balances, _sourceAssetId),
                    balanceLine: _balanceLineFor(balances, _sourceAssetId),
                    controller: _amount,
                    onPick: () => unawaited(
                      _pickAsset(balances!, source: true, walletId: walletId),
                    ),
                    onAmountChanged: () => _inputsChanged(walletId),
                  ),
                  SizedBox(
                    key: const ValueKey<String>('swap-divider'),
                    height: LoopTouch.minimum + 8,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: LoopColors.line2,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: LoopColors.card,
                            borderRadius: LoopRadius.tool,
                            border: Border.all(color: LoopColors.line2),
                          ),
                          child: LoopIconButton(
                            key: const ValueKey<String>('swap-flip'),
                            icon: 'swap-vert',
                            label: context.l10n.wallet_swapScreensSwapFlipLabel,
                            onPressed:
                                _sourceAssetId == null &&
                                    _destinationAssetId == null
                                ? null
                                : () => _flip(walletId),
                          ),
                        ),
                      ],
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
                ],
              ),
            ),
          ),
          // UX-016 (decision 0257): 滑点上限 on the left, its three steps a
          // small segmented control on the right — not Purple capsules. The
          // 「50 bps」 label was trade-desk vocabulary — the percentage is
          // the same number in the unit the chooser already owns.
          Padding(
            key: const ValueKey<String>('swap-slippage-row'),
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              0,
              LoopSpacing.page,
              12,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.common_slippageLimit,
                    style: LoopTypography.withWeight(
                      LoopType.body,
                      FontWeight.w600,
                    ).copyWith(color: LoopColors.chalk),
                  ),
                ),
                WalletSegmentedControl<int>(
                  key: const ValueKey<String>('swap-slippage'),
                  semanticLabel: context.l10n.common_slippageLimit,
                  expand: false,
                  options: _slippageChoices,
                  labelOf: moneySlippageLabel,
                  keyOf: (bps) => ValueKey<String>('swap-slippage-$bps'),
                  selected: _slippageBps,
                  onSelected: (bps) {
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
              pausedActions: <String>[
                context.l10n.wallet_swapScreensMoneyOfflinePause,
                context.l10n.common_swap,
                context.l10n.common_sign,
              ],
              onRetry: () => unawaited(_requestQuote(walletId)),
            )
          else if (_failure != null)
            LoopErrorState(
              key: const ValueKey<String>('swap-quote-error'),
              title: context.l10n.wallet_swapScreensSwapQuoteErrorTitle,
              reason: loopChainFailureReason(_failure!.kind),
              onRetry: () => unawaited(_requestQuote(walletId)),
            ),
          if (quote != null) ...<Widget>[
            _QuoteFacts(quote: quote, clock: widget.clock),
            _PriceImpactNotice(quote: quote),
            if (quote.quote.priceImpact.requiresConfirmation)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  0,
                  LoopSpacing.page,
                  12,
                ),
                child: CheckboxListTile(
                  key: const ValueKey<String>('swap-confirm-price-impact'),
                  value: _confirmPriceImpact,
                  onChanged: (value) =>
                      setState(() => _confirmPriceImpact = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(context.l10n.wallet_swapScreensText),
                ),
              ),
            LoopButton(
              key: const ValueKey<String>('swap-route-entry'),
              label: context.l10n.wallet_swapScreensSwapRouteEntryLabel,
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
            ? LoopL10n.current.wallet_swapScreensSwapQuoteActionLabel
            : _sourceAssetId == null || _destinationAssetId == null
            ? LoopL10n.current.wallet_swapScreensSwapQuoteActionLabel2
            : !amountReady
            ? LoopL10n.current.wallet_swapScreensSwapQuoteActionLabel3
            : _failure != null
            ? LoopL10n.current.wallet_swapScreensSwapQuoteActionLabel4
            : LoopL10n.current.wallet_swapScreensSwapQuoteActionLabel,
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
              ? context.l10n.wallet_swapScreensSwapConfirmActionLabel
              : capability.evidencePending
              ? context.l10n.wallet_swapScreensSwapConfirmActionLabel2
              : context.l10n.wallet_swapScreensSwapConfirmActionLabel3(
                  moneyCountdownLabel(remaining),
                ),
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
    if (assetId == null) {
      return LoopL10n.current.wallet_swapScreensBalanceLineFor;
    }
    if (balances == null) {
      return LoopL10n.current.wallet_swapScreensBalanceLineFor2;
    }
    final row = balances.rowFor(assetId);
    if (row == null) return LoopL10n.current.wallet_swapScreensBalanceLineFor3;
    return switch (row.balance) {
      LoopBalanceAvailable(spendableBalance: final spendable) =>
        LoopL10n.current.wallet_swapScreensLoopBalanceAvailable(
          loopFormatDecimal(spendable),
          row.symbol,
        ),
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
      title: source
          ? LoopL10n.current.wallet_swapScreensTitle
          : LoopL10n.current.wallet_swapScreensTitle2,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: LoopType.eyebrow),
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
                decoration: InputDecoration(
                  hintText: context.l10n.common_amount,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            SwapAssetPickButton(
              key: ValueKey<String>('$keyPrefix-pick'),
              label: symbol ?? context.l10n.wallet_moneyAssetPickerTitle,
              onPressed: onPick,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          balanceLine,
          key: ValueKey<String>('$keyPrefix-balance'),
          style: LoopType.caption,
        ),
      ],
    );
  }
}

/// 「选择资产 ›」 / 「BNB ›」 (UX-016, decision 0257): the asset a side of the
/// swap is in, with the chevron that says it opens the picker.
class SwapAssetPickButton extends StatelessWidget {
  const SwapAssetPickButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    enabled: onPressed != null,
    excludeSemantics: true,
    child: Material(
      color: LoopColors.card2,
      borderRadius: LoopRadius.button,
      child: InkWell(
        onTap: onPressed,
        borderRadius: LoopRadius.button,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  style: LoopTypography.withWeight(
                    LoopType.body,
                    FontWeight.w700,
                  ).copyWith(color: LoopColors.chalk),
                ),
                const SizedBox(width: 6),
                const LoopIcon('chevron', size: 14, color: LoopColors.text2),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.wallet_swapScreensSwapDestinationBlockedCaption,
          style: LoopType.eyebrow,
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                key: const ValueKey<String>('swap-receive-amount'),
                quote == null
                    ? (quoting
                          ? context.l10n.wallet_swapScreensSwapQuoteActionLabel
                          : context.l10n.wallet_swapScreensS)
                    : quote!.quote.estimatedOutputAmount.display,
                // A quoted amount is the figure (R24); 「报价中…」 and
                // 「报价后显示」 are words, the note step (R20, decision
                // 0190 L10).
                style: quote == null
                    ? LoopType.caption.copyWith(color: LoopColors.text3)
                    : LoopType.figureLg,
              ),
            ),
            const SizedBox(width: 8),
            SwapAssetPickButton(
              key: const ValueKey<String>('swap-destination-pick'),
              label: symbol ?? context.l10n.wallet_moneyAssetPickerTitle,
              onPressed: onPick,
            ),
          ],
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
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            12,
          ),
          child: LoopSurfaceCard(
            key: const ValueKey<String>('swap-quote-facts'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopKeyValue(
                  label: context.l10n.common_minimumReceive,
                  value:
                      '${value.minimumOutputAmount.display} '
                      '${quote.destinationAsset.symbol}',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: context.l10n.common_slippageLimit,
                  value: moneySlippageLabel(value.slippageBps),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: context.l10n.wallet_swapScreensLabel,
                  value: swapPriceImpactLabel(value.priceImpact),
                  valueUp:
                      value.priceImpact.decision ==
                      LoopPriceImpactDecision.allowed,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                // S353c: no platform fee, no row; a fee is shown as it is.
                if (value.platformFeeBps case final int bps)
                  LoopKeyValue(
                    key: const ValueKey<String>('swap-quote-platform-fee'),
                    label: context.l10n.wallet_swapScreensLabel2,
                    value: '$bps bps',
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                LoopKeyValue(
                  label: context.l10n.wallet_swapScreensLabel3,
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
          text: context.l10n.wallet_swapScreensSwapQuoteProvenanceText(
            value.provider,
            quote.policy.isPendingProductConfirmation
                ? context
                      .l10n
                      .wallet_swapScreensWalletSwapScreensSwapQuoteProvenanceText
                : '',
            loopRelativeTime(value.quotedAt, now: clock?.call()),
          ),
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
      LoopPriceImpactDecision.confirm => LoopNotice(
        key: ValueKey<String>('swap-impact-confirm'),
        icon: 'warn',
        tone: LoopNoticeTone.warn,
        title: context.l10n.wallet_swapScreensSwapImpactConfirmTitle,
        body: context.l10n.wallet_swapScreensSwapImpactConfirmBody,
      ),
      LoopPriceImpactDecision.blocked => LoopNotice(
        key: const ValueKey<String>('swap-impact-blocked'),
        icon: 'warn',
        tone: LoopNoticeTone.danger,
        title: context.l10n.wallet_swapScreensSwapImpactBlockedTitle,
        body: loopReasonCodeText(impact.reasonCode),
      ),
    };
  }
}

/// zh-CN label for a price impact. An unavailable impact never renders as 0 %.
String swapPriceImpactLabel(LoopSwapPriceImpact impact) {
  final value = impact.value;
  if (!impact.available || value == null) {
    return LoopL10n.current.wallet_swapScreensIf;
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
      title: context.l10n.wallet_swapScreensSwapRouteScreenTitle,
      onBack: onBack,
      primaryAction: LoopButton(
        key: const ValueKey<String>('swap-route-back'),
        label: context.l10n.wallet_swapScreensSwapRouteBackLabel,
        primary: true,
        block: true,
        onPressed: onBack ?? () => Navigator.of(context).pop(),
      ),
      body: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            12,
          ),
          child: LoopSurfaceCard(
            key: const ValueKey<String>('swap-route-amounts'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopKeyValue(
                  label: context.l10n.common_pay,
                  value:
                      '${value.inputAmount.display} ${quote.sourceAsset.symbol}',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: context.l10n.common_estimatedReceive,
                  value:
                      '${value.estimatedOutputAmount.display} '
                      '${quote.destinationAsset.symbol}',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: context.l10n.common_minimumReceive,
                  value: context.l10n.wallet_swapScreensValue2(
                    value.minimumOutputAmount.display,
                    moneySlippageLabel(value.slippageBps),
                    quote.destinationAsset.symbol,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ],
            ),
          ),
        ),
        LoopLabel(context.l10n.wallet_swapScreensLoopLabel),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            12,
          ),
          child: LoopSurfaceCard(
            key: const ValueKey<String>('swap-route-fees'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopKeyValue(
                  label: context.l10n.wallet_swapScreensLabel4,
                  value: '${loopGroupedFigure(value.gasEstimateRaw)} gas',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: context.l10n.wallet_swapScreensLabel5,
                  value: value.platformFeeBps == null
                      ? context.l10n.wallet_swapScreensValue
                      : '${value.platformFeeBps} bps',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: context.l10n.wallet_swapScreensLabel,
                  value: swapPriceImpactLabel(value.priceImpact),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                LoopKeyValue(
                  label: context.l10n.wallet_swapScreensLabel6,
                  value: value.priceImpact.marketValueUsd == null
                      ? context.l10n.wallet_swapScreensIf
                      : loopFormatUsd(value.priceImpact.marketValueUsd!),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ],
            ),
          ),
        ),
        LoopProvenanceFooter(
          key: const ValueKey<String>('swap-route-provenance'),
          text: context.l10n.wallet_swapScreensSwapRouteProvenanceText(
            value.priceImpact.priceSource ??
                context.l10n.wallet_moneyActionsWalletMoneyActionsS2,
            value.provider,
            quote.policy.quoteTtlSeconds,
          ),
          // S278 · decision 0236: the 「只展示最终报价」 card.
          notes: <String>[context.l10n.wallet_swapScreensLoopProvenanceFooter],
        ),
      ],
    );
  }
}

/// What the 兑换 page's (i) says (decision 0133): the two explanations that
/// used to stand under the form as cards, word for word.
Future<void> showSwapInfoSheet(BuildContext context) => showLoopInfoSheet(
  context,
  title: context.l10n.wallet_swapScreensSwapInfoActionLabel,
  sheetKey: 'swap-info-sheet',
  notes: <LoopInfoNote>[
    LoopInfoNote(
      key: ValueKey<String>('swap-routing-notice'),
      title: context.l10n.wallet_swapScreensSwapRoutingNoticeTitle,
      body: context.l10n.wallet_swapScreensSwapRoutingNoticeBody,
    ),
    LoopInfoNote(
      key: ValueKey<String>('swap-power-notice'),
      title: context.l10n.wallet_swapScreensSwapPowerNoticeTitle,
      body: context.l10n.wallet_swapScreensSwapPowerNoticeBody,
    ),
  ],
);
