import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_capability_refresh.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_approval.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_settlement.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `launch-trade` · the internal-market purchase form (archetype `action`,
/// layout `focus`).
///
/// The main action opens only while the capability is settled **and** the
/// four axes read `LIVE` + `ACTIVE` (decision 0088). It prepares one server
/// intent; the review card and the signing sheet both render that intent
/// through `launchPurchaseFields`, and the wallet receives its transaction
/// verbatim. There is no sell side — an ungraduated launch is buy-only.
class LaunchTradeScreen extends ConsumerStatefulWidget {
  const LaunchTradeScreen({
    super.key,
    this.launchId,
    this.onBack,
    this.onOpenHolders,
    this.clock,
  });

  final String? launchId;
  final VoidCallback? onBack;
  final VoidCallback? onOpenHolders;

  /// Injected by tests; the device clock otherwise. Only expiry and the
  /// round window are ever evaluated on the device.
  final DateTime Function()? clock;

  @override
  ConsumerState<LaunchTradeScreen> createState() => _LaunchTradeScreenState();
}

class _LaunchTradeScreenState extends ConsumerState<LaunchTradeScreen> {
  final TextEditingController _amount = TextEditingController();

  /// The one round the page stands on (decision 0109): the row that reads
  /// 已选择 and the round 买入 submits are both this value, or the prepared
  /// intent's round while one stands.
  String? _roundId;

  /// The detail reading the selection was last reconciled against. A new
  /// reading — a reload, a pull, a re-read after an intent — reconciles it
  /// again, even when the rounds it carries are unchanged.
  LaunchResourceState<LaunchDetail>? _reconciledRead;

  /// Set when the selection must be reconciled at the next build: a new
  /// detail, a round boundary passed, or the round lock released.
  bool _reconcileDue = true;
  bool _wasRoundLocked = false;

  /// One-shot wake-up at the next round boundary (a `startAt` or `endAt`).
  /// It only rebuilds the page; it never reads the network.
  Timer? _boundary;

  DateTime _now() => (widget.clock ?? DateTime.now)().toUtc();

  /// The capability document is being re-read before a signing sheet opens.
  bool _checkingCapability = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _boundary?.cancel();
    _amount
      ..removeListener(_onAmountChanged)
      ..dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  /// Decision 0109: keeps the selection on a round the contract accepts now.
  /// An empty, unknown or ended selection moves to the round in its window,
  /// or to the next one to open; a round that has not started yet — chosen
  /// by hand, or the next one before the sale — is kept.
  void _reconcileRound(List<LaunchChainRound> rounds, DateTime now) {
    LaunchChainRound? current;
    for (final round in rounds) {
      if (round.roundId != null && round.roundId == _roundId) current = round;
    }
    if (current == null || !now.isBefore(current.endAt)) {
      // With nothing left to open, an ended selection stays so the page can
      // say which round ended.
      _roundId =
          launchTradeDefaultRound(rounds, now)?.roundId ?? current?.roundId;
    }
  }

  /// Arms the one-shot wake-up for the next boundary after [now].
  void _armBoundary(List<LaunchChainRound> rounds, DateTime now) {
    _boundary?.cancel();
    _boundary = null;
    DateTime? next;
    for (final round in rounds) {
      for (final at in <DateTime>[round.startAt, round.endAt]) {
        if (at.isAfter(now) && (next == null || at.isBefore(next))) next = at;
      }
    }
    if (next == null) return;
    _boundary = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _reconcileDue = true);
    });
  }

  /// The exact string the server accepts: a positive USD1 amount with at
  /// most 18 decimals. A malformed amount keeps the action disabled here
  /// rather than spending a request.
  String? get _payAmount {
    final raw = _amount.text.trim();
    return launchUsd1Units(raw) == null ? null : raw;
  }

  /// 「先授权 USD1」: the exact-amount approval towards the Launch contract,
  /// through the wallet approval intent and the one signing exit.
  /// S88d: re-reads the capability document before a signing sheet opens and
  /// answers whether the page's own gate is still open. It applies the gate
  /// the page already applies — the `launch` capability and its evidence — and
  /// no other; a closed gate is then drawn by the page itself.
  Future<bool> _capabilityStillOpen() async {
    if (_checkingCapability) return false;
    setState(() => _checkingCapability = true);
    await loopRefreshCapabilitiesBeforeSigning(ref);
    if (!mounted) return false;
    setState(() => _checkingCapability = false);
    final capability = ref.read(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    return !launchCapabilityBlocks(capability) && !capability.evidencePending;
  }

  Future<void> _approve({
    required String walletId,
    required String assetId,
    required String spenderAddress,
    required String amount,
  }) async {
    if (!await _capabilityStillOpen() || !mounted) return;
    final approval = ref.read(launchApprovalControllerProvider.notifier);
    final intent = await approval.prepare(
      walletId: walletId,
      assetId: assetId,
      spenderAddress: spenderAddress,
      amount: amount,
    );
    if (intent == null || !mounted) return;
    final outcome = await showMoneySignSheet(
      context,
      intent: intent,
      signer: ref.read(moneyActionSignerProvider),
      clock: widget.clock,
    );
    if (!mounted) return;
    approval.recordOutcome(outcome);
  }

  Future<void> _sign(LaunchPurchasePrepared prepared, String ticker) async {
    if (!await _capabilityStillOpen() || !mounted) return;
    final directory = ref.read(walletDirectoryControllerProvider).value;
    String? fromAddress;
    for (final wallet in directory?.wallets ?? const <LoopWalletAccount>[]) {
      if (wallet.walletId == prepared.intent.walletId) {
        fromAddress = wallet.address;
      }
    }
    final outcome = await showLaunchSignSheet(
      context,
      prepared: prepared,
      signer: ref.read(launchPurchaseSignerProvider),
      fromAddress: fromAddress,
      ticker: ticker,
      clock: widget.clock,
    );
    if (outcome == null || !mounted) return;
    ref.read(launchTradeControllerProvider.notifier).recordSignOutcome(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchDetailControllerProvider);
    final controller = ref.read(launchDetailControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final detail = state.value;
    final trade = ref.watch(launchTradeControllerProvider);
    final tradeController = ref.read(launchTradeControllerProvider.notifier);
    // The paying wallet is a real input the page must resolve. It is read
    // through the wallet port, never guessed from an address.
    final walletState = ref.watch(walletDirectoryControllerProvider);
    if (!blocked && walletState.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(walletDirectoryControllerProvider.notifier).load(),
          );
        }
      });
    }
    final walletId = ref.watch(activeWalletIdProvider);
    // Decision 0089: the USD1 allowance is read from the wallet balances
    // (`launchChain.usd1`), never guessed and never taken from the intent.
    final balancesState = walletId == null
        ? null
        : ref.watch(walletBalancesControllerProvider(walletId));
    if (!blocked &&
        walletId != null &&
        balancesState?.phase == LoopChainViewPhase.loading &&
        balancesState?.value == null) {
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
    final approval = ref.watch(launchApprovalControllerProvider);
    final approvalController = ref.read(
      launchApprovalControllerProvider.notifier,
    );
    // Each funding refusal leads back to its own guidance: the balances are
    // re-read so the page shows what the server compared against.
    ref.listen<String?>(
      launchTradeControllerProvider.select((trade) => trade.refusalReasonCode),
      (previous, next) {
        if (walletId != null && launchFundingReasonCodes.contains(next)) {
          unawaited(
            ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .reload(),
          );
        }
      },
    );
    // A finished approval clears the refusal that asked for it.
    ref.listen<LaunchApprovalPhase>(
      launchApprovalControllerProvider.select((approval) => approval.phase),
      (previous, next) {
        if (previous == LaunchApprovalPhase.polling &&
            next == LaunchApprovalPhase.idle) {
          ref.read(launchTradeControllerProvider.notifier).discard();
        }
      },
    );
    // S92b2: once the server settles the broadcast, the position, the
    // records, the detail and the paying wallet's balances are re-read.
    ref.listen<LaunchIntentState?>(
      launchTradeControllerProvider.select((trade) => trade.reported?.state),
      (previous, next) {
        if (previous == next || !launchIntentRereads(next)) return;
        final id =
            widget.launchId ??
            ref.read(launchTradeControllerProvider).reported?.launchId;
        if (id != null) {
          launchRereadAfterIntent(ref, id, openIfIdle: false);
        }
        if (walletId != null) {
          unawaited(
            ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .reload(),
          );
        }
      },
    );
    // Decision 0094: a prepared intent names its round. The page's own
    // selection follows it, so the highlight can never drift from what the
    // review and the chain will say.
    ref.listen<String?>(
      launchTradeControllerProvider.select(
        (trade) => trade.prepared?.intent.roundId,
      ),
      (previous, next) {
        if (next != null && next != _roundId) setState(() => _roundId = next);
      },
    );
    final launchId = widget.launchId;
    final payAmount = _payAmount;
    final ticker = detail?.launch.ticker ?? launchMissingFigure;
    final prepared = trade.prepared;
    // While an intent is being prepared, reviewed, signed or broadcast — or
    // an approval is on its way — the round is fixed. Only 「重新报价」
    // (discard) releases it (decision 0094).
    final roundLocked =
        trade.busy || prepared != null || trade.locked || approval.busy;
    final now = _now();
    final chainRounds = detail?.chainRounds ?? const <LaunchChainRound>[];
    if (!identical(state, _reconciledRead)) {
      _reconciledRead = state;
      _reconcileDue = true;
    }
    if (_wasRoundLocked && !roundLocked) _reconcileDue = true;
    _wasRoundLocked = roundLocked;
    if (_reconcileDue && !roundLocked && state.phase == LaunchViewPhase.ready) {
      _reconcileDue = false;
      _reconcileRound(chainRounds, now);
      _armBoundary(chainRounds, now);
    }
    final effectiveRoundId = prepared?.intent.roundId ?? _roundId;
    LaunchChainRound? selected;
    for (final round in chainRounds) {
      if (round.roundId != null && round.roundId == effectiveRoundId) {
        selected = round;
      }
    }
    final roundId = selected?.roundId;
    // Only a round inside its window can be bought; any other is shown and
    // explained, never submitted (decision 0109).
    final roundOpen = selected != null && selected.isOpenAt(now);
    final lockedRoundIndex =
        prepared?.intent.roundIndex ?? selected?.roundIndex;
    // The action is closed by the server's capability evidence and by the
    // four axes, never by a rule of our own. Everything else is a real
    // missing input.
    final refusedByEvidence = capability.evidencePending;
    final purchasable =
        !refusedByEvidence &&
        (detail?.launch.onChainState.isPurchasable ?? false);
    final launchChainId = detail?.launch.chainId;
    var allowance = launchAllowanceView(
      balances: balancesState,
      launchChainId: launchChainId ?? '',
      required: launchUsd1Units(payAmount),
    );
    // The server compared the allowance and said it is short. A reading that
    // says otherwise is older than that answer, so approval comes first.
    if (trade.refusalReasonCode == launchAllowanceInsufficientCode &&
        allowance.status == LaunchAllowanceStatus.sufficient) {
      allowance = LaunchAllowanceView(
        status: LaunchAllowanceStatus.insufficient,
        usd1: allowance.usd1,
        native: allowance.native,
      );
    }
    final usd1Address = detail?.saleConfig?.usd1;
    final spender = detail?.launch.contractAddress;
    final approveAssetId = launchChainId == null || usd1Address == null
        ? null
        : '$launchChainId:$usd1Address';
    final needsApproval =
        purchasable &&
        payAmount != null &&
        allowance.status == LaunchAllowanceStatus.insufficient;
    final canApprove =
        needsApproval &&
        !_checkingCapability &&
        !approval.busy &&
        !trade.busy &&
        !trade.locked &&
        prepared == null &&
        walletId != null &&
        approveAssetId != null &&
        spender != null &&
        approval.phase != LaunchApprovalPhase.pollTimedOut;
    final canSubmit =
        purchasable &&
        !trade.busy &&
        !trade.locked &&
        !approval.busy &&
        prepared == null &&
        launchId != null &&
        walletId != null &&
        roundId != null &&
        roundOpen &&
        payAmount != null &&
        allowance.status == LaunchAllowanceStatus.sufficient;
    final fee = detail?.saleConfig == null
        ? launchFeeLabel(detail?.config)
        : launchBpsLabel(detail!.saleConfig!.protocolFeeBps);

    // The one next step is pinned above the bottom inset, so the keyboard
    // lifts it instead of covering it (decision 0091). A prepared intent has
    // its own review pair in the body, and a page that did not load has no
    // step at all.
    final Widget? primaryAction =
        blocked || state.phase != LaunchViewPhase.ready || prepared != null
        ? null
        : needsApproval
        ? LoopButton(
            key: const ValueKey<String>('launch-trade-approve'),
            label: _checkingCapability
                ? moneyCapabilityCheckingLabel
                : '先授权 USD1',
            primary: true,
            block: true,
            onPressed: canApprove
                ? () => unawaited(
                    _approve(
                      walletId: walletId,
                      assetId: approveAssetId,
                      spenderAddress: spender,
                      amount: payAmount,
                    ),
                  )
                : null,
            semanticLabel: _checkingCapability
                ? '先授权 USD1，$moneyCapabilityCheckingLabel'
                : canApprove
                ? '先授权 USD1'
                : '先授权 USD1，当前不可执行',
          )
        : LoopButton(
            key: const ValueKey<String>('launch-trade-submit'),
            label: '买入',
            primary: true,
            block: true,
            onPressed: canSubmit
                ? () => unawaited(
                    tradeController.prepare(
                      launchId: launchId,
                      walletId: walletId,
                      roundId: roundId,
                      payAmount: payAmount,
                    ),
                  )
                : null,
            semanticLabel: canSubmit ? '买入' : '买入，当前不可执行',
          );
    // With the keyboard up the page keeps about a third of its height; the
    // folio folds away so the amount, the balance line and the allowance
    // card stay in view (the `send-to` precedent).
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    return LoopFocusPage(
      key: const ValueKey<String>('launch-trade-screen'),
      archetype: LoopPageArchetype.action,
      title: detail?.launch.ticker ?? 'Launch 认购',
      subtitle: '内盘 · 只买不卖 · 手续费 ${fee ?? launchMissingFigure}',
      onBack: widget.onBack,
      keyboardAccessory: true,
      folioCollapsed: typing,
      primaryAction: primaryAction,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('launch-trade-holders-action'),
          icon: 'users',
          label: '查看持有人',
          framed: true,
          onPressed: widget.onOpenHolders,
        ),
      ],
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.lime,
        archetype: LoopFolioArchetype.action,
        kicker: 'FINAL BUY QUOTE',
        // The quote is the server's, after prepare; nothing before it.
        heading: prepared == null
            ? launchMissingHeading
            : '${launchUnitsFigure(prepared.intent.expectedTokenAmount)} '
                  '$ticker',
        caption: prepared == null
            ? '支付、获得、费用与剩余额度在签名前完成最终复核。提交后才有服务端报价。'
            : '报价来自区块 ${prepared.intent.snapshotBlockNumber} 的合约读数，'
                  '签名前以下方复核为准。',
        stamp: purchasable ? 'LIVE' : 'DISABLED',
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-trade-capability-unavailable',
              ),
              title: '内盘认购当前不可用',
              capability: capability,
            )
          : null,
      body: <Widget>[
        // A detail read that has not landed must not be shown as "no round to
        // join": loading, offline and a failed read each get their own block.
        if (state.phase != LaunchViewPhase.ready)
          LaunchStateBlock(
            prefix: 'launch-trade',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '这个 Launch 没有可读的认购信息',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          if (trade.locked)
            _TradeInFlightBanner(trade: trade, roundIndex: lockedRoundIndex),
          LaunchChainBlock(
            testnet: launchSurfaceIsTestnet(
              capability: capability,
              launch: detail?.launch,
            ),
          ),
          _TradeQuoteCard(
            amount: _amount,
            enabled: prepared == null && !trade.locked && !approval.busy,
            ticker: ticker,
            feeLabel: fee,
            prepared: prepared,
            usd1: allowance.usd1,
          ),
          // The allowance reading sits directly under the amount, so it stays
          // in view with the keyboard up (decision 0091).
          if (prepared == null &&
              purchasable &&
              walletId != null &&
              payAmount != null)
            _AllowanceNotice(
              allowance: allowance,
              approval: approval,
              amount: payAmount,
              onReread: () {
                if (approval.phase == LaunchApprovalPhase.pollTimedOut) {
                  approvalController.resumePolling();
                } else {
                  unawaited(
                    ref
                        .read(
                          walletBalancesControllerProvider(walletId).notifier,
                        )
                        .reload(),
                  );
                }
              },
            ),
          const LoopLabel('本轮参数'),
          if (roundLocked && lockedRoundIndex != null)
            Padding(
              key: const ValueKey<String>('launch-trade-round-locked'),
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                0,
                LoopSpacing.page,
                LoopSpacing.tight,
              ),
              child: Text(
                '本次认购：Round $lockedRoundIndex',
                style: LoopTypography.caption(12, color: LoopColors.text2),
              ),
            ),
          _TradeParameters(
            detail: detail,
            selectable: purchasable && !roundLocked,
            selectedRoundId: roundId,
            onSelect: (value) => setState(() => _roundId = value),
          ),
          if (prepared != null)
            _TradeReview(
              prepared: prepared,
              ticker: ticker,
              trade: trade,
              checkingCapability: _checkingCapability,
              onSign: trade.locked || _checkingCapability
                  ? null
                  : () => unawaited(_sign(prepared, ticker)),
              onDiscard: (trade.locked && !trade.settled) || _checkingCapability
                  ? null
                  : tradeController.discard,
              onRetryReport: trade.reportRetryable && !trade.reporting
                  ? () => unawaited(tradeController.retryReport())
                  : null,
              onResumePolling: tradeController.resumePolling,
            ),
          if (prepared == null)
            LoopNotice(
              key: const ValueKey<String>('launch-trade-refusal'),
              icon: 'shield',
              tone: LoopNoticeTone.warn,
              title: trade.attempted ? '这次认购没有通过' : '认购入口当前不可执行',
              body: trade.refusalKind != null
                  ? launchPurchaseRefusalText(
                      trade.refusalKind,
                      trade.refusalReasonCode,
                    )
                  : refusedByEvidence
                  ? '${launchReasonCodeText(capability.evidenceReasonCode)}'
                        '本页因此不构造任何交易，也不打开签名。'
                  : _closedReason(
                      onChainState: detail?.launch.onChainState,
                      walletId: walletId,
                      round: selected,
                      now: now,
                      payAmount: payAmount,
                      allowance: allowance.status,
                    ),
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          if (prepared == null &&
              walletId != null &&
              launchFundingReasonCodes.contains(trade.refusalReasonCode))
            _FundingGuidance(
              reasonCode: trade.refusalReasonCode!,
              allowance: allowance,
              refreshing: balancesState?.refreshing ?? false,
              onReread: () => unawaited(
                ref
                    .read(walletBalancesControllerProvider(walletId).notifier)
                    .reload(),
              ),
            ),
          if (prepared == null &&
              launchUnexplainedReasonCode(trade.refusalReasonCode) != null)
            LoopDisclosure(
              key: const ValueKey<String>('launch-trade-refusal-code'),
              summary: '错误代码',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SelectableText(
                  trade.refusalReasonCode!,
                  style: LoopTypography.figure(12, color: LoopColors.text2),
                ),
              ),
            ),
          const LoopNotice(
            key: ValueKey<String>('launch-trade-buy-only'),
            icon: 'info',
            title: '未毕业只买不卖',
            body: '内盘阶段没有卖出接口。毕业并建立外部流动性之后，交易才会转到行情模块。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          LoopDisclosure(
            key: const ValueKey<String>('launch-trade-facts'),
            summary: '固定价格与合约限制',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: _TradeLimitsCard(detail: detail, selected: selected),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// The page-top line once the wallet has broadcast (or its outcome is
/// unknown): the attempt is in flight and stays so until the server's intent
/// state moves. It states the server's state, never a result of its own.
class _TradeInFlightBanner extends StatelessWidget {
  const _TradeInFlightBanner({required this.trade, required this.roundIndex});

  final LaunchTradeState trade;
  final int? roundIndex;

  @override
  Widget build(BuildContext context) {
    final hash = trade.txHash;
    final state = trade.reported?.state;
    final String title;
    if (hash == null) {
      title = '已提交给钱包，结果未确认';
    } else if (state == null || state == LaunchIntentState.submitted) {
      title = '已广播，等待链上索引';
    } else {
      title = '已广播 · ${state.label}';
    }
    final round = roundIndex == null ? '' : 'Round $roundIndex · ';
    final body = hash == null
        ? '$round这笔认购已锁定，不要重复签名。结果会出现在「我的参与记录」。'
        : '$round交易 ${launchShortHex(hash)}。广播不代表已成交，'
              '结果以链上索引为准，会出现在「我的参与记录」。';
    return LoopNotice(
      key: const ValueKey<String>('launch-trade-in-flight'),
      icon: 'clock',
      tone: LoopNoticeTone.warn,
      title: title,
      body: body,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    );
  }
}

/// Why the action is closed while the capability evidence is settled. Each
/// reason is a real missing input or an axis, never a rule of our own.
String _closedReason({
  required LaunchOnChainState? onChainState,
  required String? walletId,
  required LaunchChainRound? round,
  required DateTime now,
  required String? payAmount,
  required LaunchAllowanceStatus allowance,
}) {
  switch (onChainState) {
    case LaunchOnChainUnavailable(:final reasonCode):
      return '${launchReasonCodeText(reasonCode)}本页因此不构造任何交易，也不打开签名。';
    case final LaunchOnChainAvailable chain when !chain.isPurchasable:
      return '当前链上状态：${launchStateProjection(chain)}。'
          '只有销售进行中且未暂停时才能认购。';
    case null:
      return '还没有读到链上状态，本页不构造任何交易。';
    default:
      break;
  }
  if (walletId == null) return '还没有可用的支付钱包，请先在钱包中选择一个。';
  if (round == null || round.roundId == null) return '请先选择要参与的轮次。';
  if (now.isBefore(round.startAt)) {
    return 'Round ${round.roundIndex} 尚未开始，'
        '${launchTimestampLabel(round.startAt)} 开放后才能认购。';
  }
  if (!round.isOpenAt(now)) {
    return 'Round ${round.roundIndex} 已于 '
        '${launchTimestampLabel(round.endAt)} 结束，请选择进行中的轮次。';
  }
  if (payAmount == null) return '请输入一个有效的支付数量（最多 18 位小数）。';
  switch (allowance) {
    case LaunchAllowanceStatus.reading:
      return '正在读取 USD1 授权额度，读到之前不能购买。';
    case LaunchAllowanceStatus.unread:
      return '授权状态未读取，本页不猜测授权额度，因此暂不能购买。';
    case LaunchAllowanceStatus.insufficient:
      return 'USD1 授权额度不足，需要先授权本次金额，授权到账后才能购买。';
    case LaunchAllowanceStatus.sufficient:
      return '可以提交，结果以提交后的状态为准。';
  }
}

/// The prototype's Chalk buy box: `支付 USD1` over the amount, a hairline,
/// then `预计获得` over the token it would buy. The lower half is the
/// server's quote once an intent is prepared, and the em dash before.
class _TradeQuoteCard extends StatelessWidget {
  const _TradeQuoteCard({
    required this.amount,
    required this.enabled,
    required this.ticker,
    required this.feeLabel,
    required this.prepared,
    required this.usd1,
  });

  final TextEditingController amount;
  final bool enabled;
  final String ticker;
  final String? feeLabel;
  final LaunchPurchasePrepared? prepared;

  /// `launchChain.usd1` from the wallet balances, or `null` (未读取).
  final LoopLaunchUsd1Reading? usd1;

  /// The settlement asset of the frozen Launchpad baseline (06 §1).
  static const String payAsset = 'USD1';

  @override
  Widget build(BuildContext context) {
    final intent = prepared?.intent;
    final reading = usd1;
    final balance = reading == null ? '未读取' : launchUsd1Label(reading.balance);
    final allowance = reading == null
        ? '未读取'
        : launchUsd1Label(reading.allowance);
    return LoopChalkCard(
      key: const ValueKey<String>('launch-trade-quote'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Builder(
        builder: (context) {
          final ink = LoopGround.inkOf(context);
          final auxiliary = LoopGround.auxiliaryOf(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '支付 $payAsset',
                style: LoopTypography.eyebrow(11, color: auxiliary),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const ValueKey<String>('launch-trade-amount'),
                      controller: amount,
                      enabled: enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      // Android's number pad closes on its done key; iOS
                      // gets the page's 「完成」 bar (decision 0091).
                      textInputAction: TextInputAction.done,
                      cursorColor: ink,
                      style: LoopTypography.figure(
                        24,
                        weight: FontWeight.w700,
                        color: ink,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: '0',
                        hintStyle: LoopTypography.figure(
                          24,
                          weight: FontWeight.w700,
                          color: auxiliary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(payAsset, style: LoopTypography.figure(13, color: ink)),
                ],
              ),
              const LoopHairline(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '预计获得',
                          style: LoopTypography.caption(11, color: auxiliary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          intent == null
                              ? launchMissingFigure
                              : launchUnitsFigure(intent.expectedTokenAmount),
                          style: LoopTypography.figure(
                            18,
                            weight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(ticker, style: LoopTypography.figure(13, color: ink)),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                '包含本轮手续费 ${feeLabel ?? launchMissingFigure} · '
                'USD1 余额 $balance · 授权额度 $allowance',
                key: const ValueKey<String>('launch-trade-balance'),
                style: LoopTypography.caption(11, color: auxiliary),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The prepared intent's review, line for line what the sheet will show.
class _TradeReview extends StatelessWidget {
  const _TradeReview({
    required this.prepared,
    required this.ticker,
    required this.trade,
    required this.onSign,
    required this.onDiscard,
    required this.onRetryReport,
    required this.onResumePolling,
    this.checkingCapability = false,
  });

  final LaunchPurchasePrepared prepared;
  final String ticker;
  final LaunchTradeState trade;

  /// The capability document is being re-read before the sheet opens.
  final bool checkingCapability;
  final VoidCallback? onSign;
  final VoidCallback? onDiscard;
  final VoidCallback? onRetryReport;
  final VoidCallback? onResumePolling;

  @override
  Widget build(BuildContext context) {
    final fields = launchPurchaseFields(prepared.intent, ticker: ticker);
    final reason = trade.signReasonCode;
    final reported = trade.reported;
    return Column(
      key: const ValueKey<String>('launch-trade-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('签名前复核'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (var index = 1; index < fields.length; index += 1)
              LoopRecordRow(
                key: ValueKey<String>('launch-review-${fields[index].label}'),
                title: fields[index].label,
                trailing: fields[index].value,
                position: launchRowPosition(index - 1, fields.length - 1),
                chevron: false,
              ),
          ],
        ),
        if (trade.locked && reported != null && trade.settled) ...<Widget>[
          // S92b2: the read-back settled. Only `confirmed` names a result.
          Builder(
            builder: (context) {
              final text = launchSettlementProgressText(
                LaunchIntentKind.buy,
                reported,
              );
              final confirmed = reported.state == LaunchIntentState.confirmed;
              return LoopNotice(
                key: ValueKey<String>(
                  'launch-trade-state-${reported.state.wireName}',
                ),
                icon: confirmed ? 'check' : 'clock',
                title: text.title,
                body: text.body,
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('launch-trade-settled-done'),
              label: '重新认购',
              block: true,
              onPressed: onDiscard,
            ),
          ),
        ] else if (trade.locked) ...<Widget>[
          LoopNotice(
            key: const ValueKey<String>('launch-trade-locked'),
            icon: 'clock',
            tone: LoopNoticeTone.warn,
            title: reported == null
                ? '已提交给钱包，结果未确认'
                : '已广播 · ${reported.state.label}',
            body:
                launchBroadcastText(
                  LaunchSignOutcome(
                    status: MoneySignStatus.values.byName(
                      trade.signOutcomeStatus ?? 'locked',
                    ),
                    reasonCode: reason ?? '',
                    txHash: trade.txHash,
                    reported: reported,
                  ),
                ) +
                (trade.pollTimedOut ? '还没有读到链上结果，可以稍后重新查询。' : ''),
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          if (trade.pollTimedOut)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: LoopButton(
                key: const ValueKey<String>('launch-trade-poll-resume'),
                label: '重新查询',
                block: true,
                onPressed: onResumePolling,
              ),
            ),
          if (trade.reportRetryable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: LoopButton(
                key: const ValueKey<String>('launch-trade-report-retry'),
                label: trade.reporting ? '正在重新上报' : '重新上报',
                block: true,
                onPressed: onRetryReport,
              ),
            ),
        ] else ...<Widget>[
          if (reason != null)
            LoopNotice(
              key: const ValueKey<String>('launch-trade-sign-refused'),
              icon: 'shield',
              tone: LoopNoticeTone.warn,
              title: '没有签名',
              body: launchSignReasonText(reason),
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('launch-trade-discard'),
                label: '重新报价',
                onPressed: onDiscard,
              ),
              LoopButton(
                key: const ValueKey<String>('launch-trade-sign'),
                label: checkingCapability
                    ? moneyCapabilityCheckingLabel
                    : '签名认购',
                primary: true,
                onPressed: onSign,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Where the USD1 approval stands for the typed amount (decision 0089).
///
/// It states what was read and nothing else: a missing reading is
/// 「授权状态未读取」, never a zero and never a guess.
class _AllowanceNotice extends StatelessWidget {
  const _AllowanceNotice({
    required this.allowance,
    required this.approval,
    required this.amount,
    required this.onReread,
  });

  final LaunchAllowanceView allowance;
  final LaunchApprovalState approval;
  final String amount;
  final VoidCallback onReread;

  @override
  Widget build(BuildContext context) {
    final approvalText = launchApprovalText(approval);
    final failure = approval.failure;
    final String title;
    final String body;
    var reread = false;
    if (approval.phase == LaunchApprovalPhase.prepareFailed &&
        failure != null) {
      title = '授权没有准备成功';
      body =
          MoneyPolicyNotice.covers(failure) ||
              failure.kind == LoopChainFailureKind.permissionDenied
          ? moneyPolicyRefusalText(failure)
          : loopChainFailureReason(failure.kind);
    } else if (approvalText != null) {
      title = switch (approval.phase) {
        LaunchApprovalPhase.polling => '等待授权到账',
        LaunchApprovalPhase.pollTimedOut => '授权额度还没有更新',
        LaunchApprovalPhase.failedOnChain => '授权没有生效',
        LaunchApprovalPhase.signRefused => '授权没有签名',
        _ => '正在准备授权',
      };
      body = approvalText;
      reread = approval.phase == LaunchApprovalPhase.pollTimedOut;
    } else {
      switch (allowance.status) {
        case LaunchAllowanceStatus.reading:
          title = '正在读取授权状态';
          body = '正在读取这个钱包在 Launch 链上的 USD1 授权额度，读到之前不能购买。';
        case LaunchAllowanceStatus.unread:
          title = '授权状态未读取';
          body = allowance.failureKind == null
              ? '没有读到这个钱包在 Launch 链上的 USD1 授权额度。本页不猜测授权额度，'
                    '因此暂不能购买。'
              : '${loopChainFailureReason(allowance.failureKind)}'
                    '授权额度读到之前不能购买。';
          reread = true;
        case LaunchAllowanceStatus.insufficient:
          final usd1 = allowance.usd1;
          title = '需要先授权 USD1';
          body =
              '${usd1 == null ? '' : '当前授权 ${launchUsd1Label(usd1.allowance)}，'}'
              '本次需要 $amount USD1。授权额度只按本次金额，不是无限额度；'
              '授权到账后才能购买。';
        case LaunchAllowanceStatus.sufficient:
          return const SizedBox.shrink();
      }
    }
    return Column(
      key: const ValueKey<String>('launch-trade-allowance'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LoopNotice(
          key: const ValueKey<String>('launch-trade-allowance-notice'),
          icon: approval.phase == LaunchApprovalPhase.polling
              ? 'clock'
              : 'shield',
          tone: LoopNoticeTone.warn,
          title: title,
          body: body,
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        ),
        if (reread)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('launch-trade-allowance-reread'),
              label: '重新读取',
              block: true,
              onPressed: onReread,
            ),
          ),
      ],
    );
  }
}

/// The guidance after a funding refusal: what was read for the half the
/// server named, and a re-read. The allowance refusal needs none of this —
/// its guidance is the 「先授权 USD1」 action itself.
class _FundingGuidance extends StatelessWidget {
  const _FundingGuidance({
    required this.reasonCode,
    required this.allowance,
    required this.refreshing,
    required this.onReread,
  });

  final String reasonCode;
  final LaunchAllowanceView allowance;
  final bool refreshing;
  final VoidCallback onReread;

  @override
  Widget build(BuildContext context) {
    if (reasonCode == launchAllowanceInsufficientCode) {
      return const SizedBox.shrink();
    }
    final usd1 = allowance.usd1;
    final native = allowance.native;
    final gas = reasonCode == launchGasInsufficientCode;
    final fact = gas
        ? (native == null
              ? '网络费余额未读取'
              : '网络费余额 ${loopFormatDecimal(native.displayBalance)} '
                    '${native.symbol}')
        : (usd1 == null
              ? 'USD1 余额未读取'
              : 'USD1 余额 ${launchUsd1Label(usd1.balance)}');
    return Column(
      key: ValueKey<String>('launch-trade-funding-$reasonCode'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LoopNotice(
          icon: 'wallet',
          title: gas ? '先补充网络费' : '先补充 USD1',
          body: '$fact。转入后重新读取余额，再重新买入。',
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: LoopButton(
            key: const ValueKey<String>('launch-trade-funding-reread'),
            label: refreshing ? '正在读取余额' : '重新读取余额',
            block: true,
            onPressed: refreshing ? null : onReread,
          ),
        ),
      ],
    );
  }
}

/// `details.focus-disclosure > .record-card`: the fixed price, the round
/// window and what has been raised. Every figure is a contract reading at the
/// snapshot block, or the em dash while the axes are unreadable.
class _TradeLimitsCard extends StatelessWidget {
  const _TradeLimitsCard({required this.detail, required this.selected});

  final LaunchDetail? detail;
  final LaunchChainRound? selected;

  @override
  Widget build(BuildContext context) {
    final rounds = detail?.chainRounds ?? const <LaunchChainRound>[];
    final round = selected ?? (rounds.isEmpty ? null : rounds.first);
    final config = detail?.saleConfig;
    final price = round == null
        ? launchMissingFigure
        : '${launchUnitsFigure(round.priceUsd1PerToken)} USD1';
    final window = round == null
        ? launchMissingFigure
        : launchTimestampLabel(round.endAt);
    BigInt? raised;
    for (final item in rounds) {
      raised = (raised ?? BigInt.zero) + BigInt.parse(item.raisedUsd1);
    }
    final raisedLabel = raised == null
        ? launchMissingFigure
        : launchUsd1Label(raised.toString());
    final hardCap = config == null
        ? launchMissingFigure
        : launchUsd1Label(config.hardCapUsd1);
    double? progress;
    if (raised != null && config != null) {
      final cap = BigInt.parse(config.hardCapUsd1);
      if (cap > BigInt.zero) {
        // Normalised into pixel space only; the figures stay exact strings.
        progress = (raised * BigInt.from(10000) ~/ cap).toInt() / 10000;
        if (progress > 1) progress = 1;
      }
    }
    return LoopRecordCard(
      key: const ValueKey<String>('launch-trade-limits'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '固定价格',
                      style: LoopTypography.eyebrow(
                        11,
                        color: LoopColors.text3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(price, style: LoopTypography.figure(20, height: 1.05)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(window, style: LoopTypography.figure(13)),
                  Text(
                    '本轮截止',
                    style: LoopTypography.caption(11, color: LoopColors.text3),
                  ),
                ],
              ),
            ],
          ),
          const LoopHairline(),
          Text(
            '已募集 $raisedLabel / 硬顶 $hardCap',
            style: LoopTypography.caption(11, color: LoopColors.text2),
          ),
          const SizedBox(height: 10),
          LoopProgressBar(
            value: progress,
            semanticLabel: progress == null ? '募集进度暂时读不到' : '募集进度',
          ),
        ],
      ),
    );
  }
}

class _TradeParameters extends StatelessWidget {
  const _TradeParameters({
    required this.detail,
    required this.selectable,
    required this.selectedRoundId,
    required this.onSelect,
  });

  final LaunchDetail? detail;
  final bool selectable;
  final String? selectedRoundId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final chain = detail?.chainRounds ?? const <LaunchChainRound>[];
    if (chain.isNotEmpty) {
      return LoopRecordGroup(
        key: const ValueKey<String>('launch-trade-rounds'),
        rows: <LoopRecordRow>[
          for (var index = 0; index < chain.length; index += 1)
            launchChainRoundRow(
              round: chain[index],
              position: launchRowPosition(index, chain.length),
              onTap: selectable && chain[index].roundId != null
                  ? () => onSelect(chain[index].roundId!)
                  : null,
              selected:
                  chain[index].roundId != null &&
                  chain[index].roundId == selectedRoundId,
            ),
        ],
      );
    }
    final rounds = detail?.rounds ?? const <LaunchRound>[];
    if (rounds.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('launch-trade-no-round'),
        icon: 'warn',
        message: '没有可参与的轮次',
        reason: '轮次配置尚未确认，因此没有价格、资格或额度可以展示。',
      );
    }
    // LOOP's own round slots: shown as configured, never selectable, because
    // only a contract round can be bought.
    return LoopRecordGroup(
      key: const ValueKey<String>('launch-trade-rounds'),
      rows: <LoopRecordRow>[
        for (var index = 0; index < rounds.length; index += 1)
          launchRoundRow(
            round: rounds[index],
            position: launchRowPosition(index, rounds.length),
          ),
      ],
    );
  }
}

/// The round `launch-trade` stands on when nothing valid is selected
/// (decision 0109): the round inside its window at [now]; otherwise the next
/// one to open, shown but not submittable; otherwise none. Only a round LOOP
/// has a record of (`roundId`) can be chosen, since the intent names it.
LaunchChainRound? launchTradeDefaultRound(
  List<LaunchChainRound> rounds,
  DateTime now,
) {
  LaunchChainRound? next;
  for (final round in rounds) {
    if (round.roundId == null) continue;
    if (round.isOpenAt(now)) return round;
    if (now.isBefore(round.startAt) &&
        (next == null || round.startAt.isBefore(next.startAt))) {
      next = round;
    }
  }
  return next;
}
