import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
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
  String? _roundId;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amount
      ..removeListener(_onAmountChanged)
      ..dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  /// The exact string the server accepts. A malformed amount keeps the action
  /// disabled here rather than spending a request.
  String? get _payAmount {
    final raw = _amount.text.trim();
    if (raw.isEmpty ||
        !RegExp(r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,60})?$').hasMatch(raw)) {
      return null;
    }
    return raw;
  }

  Future<void> _sign(LaunchPurchasePrepared prepared, String ticker) async {
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
    ref
        .read(launchTradeControllerProvider.notifier)
        .recordSignOutcome(
          status: outcome.isLocked ? 'locked' : outcome.status.name,
          reasonCode: outcome.reasonCode,
          txHash: outcome.txHash,
        );
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
    final launchId = widget.launchId;
    final payAmount = _payAmount;
    final ticker = detail?.launch.ticker ?? launchMissingFigure;
    LaunchChainRound? selected;
    for (final round in detail?.chainRounds ?? const <LaunchChainRound>[]) {
      if (round.roundId != null && round.roundId == _roundId) selected = round;
    }
    final roundId = selected?.roundId;
    // The action is closed by the server's capability evidence and by the
    // four axes, never by a rule of our own. Everything else is a real
    // missing input.
    final refusedByEvidence = capability.evidencePending;
    final purchasable =
        !refusedByEvidence &&
        (detail?.launch.onChainState.isPurchasable ?? false);
    final prepared = trade.prepared;
    final canSubmit =
        purchasable &&
        !trade.busy &&
        !trade.locked &&
        prepared == null &&
        launchId != null &&
        walletId != null &&
        roundId != null &&
        payAmount != null;
    final fee = detail?.saleConfig == null
        ? launchFeeLabel(detail?.config)
        : launchBpsLabel(detail!.saleConfig!.protocolFeeBps);

    return LoopFocusPage(
      key: const ValueKey<String>('launch-trade-screen'),
      archetype: LoopPageArchetype.action,
      title: detail?.launch.ticker ?? 'Launch 认购',
      subtitle: '内盘 · 只买不卖 · 手续费 ${fee ?? launchMissingFigure}',
      onBack: widget.onBack,
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
          LaunchChainBlock(
            testnet: launchSurfaceIsTestnet(
              capability: capability,
              launch: detail?.launch,
            ),
          ),
          _TradeQuoteCard(
            amount: _amount,
            enabled: prepared == null && !trade.locked,
            ticker: ticker,
            feeLabel: fee,
            prepared: prepared,
          ),
          const LoopLabel('本轮参数'),
          _TradeParameters(
            detail: detail,
            selectable: purchasable && prepared == null && !trade.locked,
            selectedRoundId: roundId,
            onSelect: (value) => setState(() => _roundId = value),
          ),
          if (prepared != null)
            _TradeReview(
              prepared: prepared,
              ticker: ticker,
              locked: trade.locked,
              txHash: trade.txHash,
              signReasonCode: trade.signReasonCode,
              onSign: trade.locked
                  ? null
                  : () => unawaited(_sign(prepared, ticker)),
              onDiscard: trade.locked ? null : tradeController.discard,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: LoopButton(
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
              ),
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
                      roundId: roundId,
                      payAmount: payAmount,
                    ),
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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

/// Why the action is closed while the capability evidence is settled. Each
/// reason is a real missing input or an axis, never a rule of our own.
String _closedReason({
  required LaunchOnChainState? onChainState,
  required String? walletId,
  required String? roundId,
  required String? payAmount,
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
  if (roundId == null) return '请先选择要参与的轮次。';
  if (payAmount == null) return '请输入一个有效的支付数量。';
  return '可以提交，结果以提交后的状态为准。';
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
  });

  final TextEditingController amount;
  final bool enabled;
  final String ticker;
  final String? feeLabel;
  final LaunchPurchasePrepared? prepared;

  /// The settlement asset of the frozen Launchpad baseline (06 §1).
  static const String payAsset = 'USD1';

  @override
  Widget build(BuildContext context) {
    final intent = prepared?.intent;
    final usd1 = prepared?.usd1;
    final balance = usd1?.balance == null
        ? '未读取'
        : launchUsd1Label(usd1!.balance!);
    final allowance = usd1?.allowance == null
        ? '未读取'
        : launchUsd1Label(usd1!.allowance!);
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
    required this.locked,
    required this.txHash,
    required this.signReasonCode,
    required this.onSign,
    required this.onDiscard,
  });

  final LaunchPurchasePrepared prepared;
  final String ticker;
  final bool locked;
  final String? txHash;
  final String? signReasonCode;
  final VoidCallback? onSign;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final fields = launchPurchaseFields(prepared.intent, ticker: ticker);
    final hash = txHash;
    final reason = signReasonCode;
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
        if (locked)
          LoopNotice(
            key: const ValueKey<String>('launch-trade-locked'),
            icon: 'clock',
            tone: LoopNoticeTone.warn,
            title: '已提交给钱包，结果未确认',
            body: hash == null
                ? '钱包的结果未知，这笔认购已锁定。请在「我的参与记录」查看，不要重复签名。'
                : '钱包已广播 ${launchShortHex(hash)}。广播不代表已成交，'
                      '结果以链上索引为准，会出现在「我的参与记录」。',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          )
        else ...<Widget>[
          if (reason != null && reason != LaunchPurchaseSigner.broadcastReason)
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
                label: '签名认购',
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
