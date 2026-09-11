import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `tx-result` · the one result page for every money action.
///
/// It reads `GET /v2/wallet-intents/{intentId}` and renders exactly what the
/// server reports. A success toast fires only on `confirmed`; `unknown` is a
/// locked state that is polled and never resubmitted.
class TransactionResultScreen extends ConsumerStatefulWidget {
  const TransactionResultScreen({
    super.key,
    this.intentId,
    this.onBack,
    this.onNavigate,
    this.pollInterval = const Duration(seconds: 4),
    this.maximumPollFailures = 5,
  });

  final String? intentId;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  /// The base interval. Each consecutive failure doubles the wait, so a server
  /// that is down is not hammered by a page left open.
  final Duration pollInterval;

  /// After this many consecutive failed reads the page stops on its own and
  /// offers a manual retry instead of polling forever.
  final int maximumPollFailures;

  @override
  ConsumerState<TransactionResultScreen> createState() =>
      _TransactionResultScreenState();
}

class _TransactionResultScreenState
    extends ConsumerState<TransactionResultScreen> {
  Timer? _poll;
  int _consecutiveFailures = 0;
  bool _pollingStopped = false;

  /// The `intentId:state` this page has already announced. A toast fires on a
  /// transition into `confirmed`, never on every rebuild or re-read of the
  /// same state.
  String? _announced;

  @override
  void initState() {
    super.initState();
    if (widget.intentId == null) return;
    scheduleMicrotask(() {
      if (mounted) unawaited(_read(initial: true));
    });
    _schedule(widget.pollInterval);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _schedule(Duration delay) {
    _poll?.cancel();
    _poll = Timer(delay, _tick);
  }

  Future<void> _tick() async {
    if (!mounted || _pollingStopped) return;
    final intentId = widget.intentId;
    if (intentId == null) return;
    final controller = ref.read(
      walletIntentControllerProvider(intentId).notifier,
    );
    if (!controller.keepsPolling) return;
    await _read();
    if (!mounted || _pollingStopped) return;
    if (!controller.keepsPolling) return;
    // Exponential back-off, capped, so a page left open on a failing server
    // settles instead of retrying every few seconds forever.
    final multiplier = 1 << _consecutiveFailures.clamp(0, 4);
    _schedule(widget.pollInterval * multiplier);
  }

  /// Reads once and records whether the read succeeded, so the page can stop
  /// on its own rather than claim it is still watching.
  Future<void> _read({bool initial = false}) async {
    final intentId = widget.intentId;
    if (intentId == null) return;
    final controller = ref.read(
      walletIntentControllerProvider(intentId).notifier,
    );
    await (initial ? controller.load() : controller.reload());
    if (!mounted) return;
    final failed =
        ref.read(walletIntentControllerProvider(intentId)).failureKind != null;
    setState(() {
      _consecutiveFailures = failed ? _consecutiveFailures + 1 : 0;
      if (_consecutiveFailures >= widget.maximumPollFailures) {
        _pollingStopped = true;
        _poll?.cancel();
      }
    });
  }

  /// Restarts polling after the owner asks for it.
  Future<void> _retry() async {
    setState(() {
      _pollingStopped = false;
      _consecutiveFailures = 0;
    });
    await _read();
    if (mounted && !_pollingStopped) _schedule(widget.pollInterval);
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final intentId = widget.intentId;
    if (intentId == null) {
      return LoopFocusPage(
        key: const ValueKey<String>('tx-result-screen'),
        archetype: LoopPageArchetype.state,
        title: '交易结果',
        onBack: widget.onBack,
        folio: const LoopFolioPrimary(
          key: ValueKey<String>('tx-result-folio'),
          kicker: 'TRANSACTION RESULT',
          heading: '没有可展示的结果',
          caption: '结果页只展示一笔具体操作，需要指定是哪一笔。',
        ),
        body: const <Widget>[
          LoopEmpty(
            key: ValueKey<String>('tx-result-empty'),
            message: '这里还没有要展示的操作',
            reason: '从发送、授权或兑换的签名页进来时，这一页会显示那一笔的状态。',
          ),
        ],
      );
    }

    // The result page is a read. It must stay readable for every kind — a
    // swap result is not a `sendApprovals` fact — and while the write switch
    // is closed, because a submitted intent still has a state to report.
    final blocked = moneyReadBlocks(
      ref.watch(walletIntentsGatewayProvider).mode,
    );
    final state = ref.watch(walletIntentControllerProvider(intentId));
    final intent = state.value;
    if (intent != null && intent.state == LoopIntentState.confirmed) {
      // The one place a success toast may fire, and only on the transition
      // into `confirmed`: a rebuild or a re-read of the same state is not a
      // new event, and nothing earlier proves on-chain completion.
      final announcement = '${intent.intentId}:${intent.state.wireName}';
      if (_announced != announcement) {
        _announced = announcement;
        scheduleMicrotask(() {
          if (mounted) LoopToast.show(context, message: '交易已确认');
        });
      }
    }

    return LoopFocusPage(
      key: const ValueKey<String>('tx-result-screen'),
      archetype: LoopPageArchetype.state,
      title: '交易结果',
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        key: const ValueKey<String>('tx-result-folio'),
        kicker: 'TRANSACTION RESULT',
        heading: intent == null ? '正在读取结果' : _headline(intent),
        caption: intent == null ? '结果以链上核对为准，这一页不会自己判断成败。' : _caption(intent),
        stamp: intent == null
            ? null
            : moneyIntentStateLabel(intent.state).toUpperCase(),
      ),
      block: blocked
          ? const LoopCapabilityPageBlock(
              key: ValueKey<String>('tx-result-capability-block'),
              title: '交易状态当前不可读',
              reasonCode: 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
            )
          : null,
      body: <Widget>[
        if (intent == null)
          LoopChainStateBlock(
            keyPrefix: 'tx-result',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '这笔操作没有可读状态',
            onRetry: () => unawaited(_retry()),
          )
        else ...<Widget>[
          _ResultBanner(intent: intent),
          if (intent.state == LoopIntentState.unknown)
            LoopNotice(
              key: const ValueKey<String>('tx-result-unknown-lock'),
              icon: 'warn',
              tone: LoopNoticeTone.danger,
              title: '结果未知，已锁定',
              body:
                  '${loopReasonCodeText(intent.result.reasonCode)}'
                  ' 本页只会继续查询，不会重复提交；请勿再次签名。',
            ),
          if (intent.state == LoopIntentState.awaitingSignature ||
              intent.state == LoopIntentState.prepared)
            const LoopNotice(
              key: ValueKey<String>('tx-result-unreported'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '这次提交还没有记录到',
              body:
                  '如果钱包已经广播过这笔交易，它可能已经上链，只是上报没有成功。'
                  '请稍后回到这里重试，在提交被接受之前不要重新签名。',
            ),
          if (intent.state == LoopIntentState.submitted)
            const LoopNotice(
              key: ValueKey<String>('tx-result-pending'),
              icon: 'clock',
              tone: LoopNoticeTone.warn,
              title: '已提交，等待回执',
              body: '提交成功不代表链上已完成，还需要 15 个区块确认。',
            ),
          if (_pollingStopped)
            LoopNotice(
              key: const ValueKey<String>('tx-result-polling-stopped'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '已停止自动查询',
              body:
                  '连续 ${widget.maximumPollFailures} 次读取失败，本页不再自动重试，'
                  '已停止自动重试。这笔操作的状态没有改变，请手动重试。',
              trailing: LoopButton(
                key: const ValueKey<String>('tx-result-poll-retry'),
                label: '重试',
                onPressed: () => unawaited(_retry()),
              ),
            ),
          _ResultFacts(intent: intent),
          const LoopLabel('分享'),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('tx-result-forward'),
                label: '转发消息',
                onPressed: intent.state == LoopIntentState.confirmed
                    ? () => _open('/chat/forward')
                    : null,
              ),
              LoopButton(
                key: const ValueKey<String>('tx-result-merge'),
                label: '合并长图',
                onPressed: intent.state == LoopIntentState.confirmed
                    ? () => _open('/chat/merge-preview')
                    : null,
              ),
              LoopButton(
                key: const ValueKey<String>('tx-result-community'),
                label: '社区',
                onPressed: () => _open('/community/chat'),
              ),
            ],
          ),
          const LoopNotice(
            key: ValueKey<String>('tx-result-power'),
            icon: 'mine',
            title: '算力影响不可用',
            body: '挖矿算力与日产出暂时读不到，这里不显示数字。',
          ),
          MoneyFactsFooter(intent: intent),
        ],
      ],
    );
  }

  String _headline(LoopWalletIntent intent) => switch (intent.state) {
    LoopIntentState.confirmed => '${_action(intent)}已确认',
    LoopIntentState.reverted => '${_action(intent)}已回滚',
    LoopIntentState.failed => '${_action(intent)}失败',
    LoopIntentState.unknown => '${_action(intent)}结果未知',
    LoopIntentState.cancelled => '${_action(intent)}已取消',
    LoopIntentState.expired => '${_action(intent)}已过期',
    _ => '${_action(intent)}进行中',
  };

  String _action(LoopWalletIntent intent) =>
      moneyActionTitle(intent.kind).replaceFirst('确认', '');

  String _caption(LoopWalletIntent intent) {
    final receipt = intent.result.receipt;
    if (receipt == null) {
      return '结果、交易哈希和下一步动作集中在这里，不会混入新的报价。';
    }
    return '区块 ${receipt.blockNumber} · '
        '${receipt.confirmations == null ? '确认数读不到' : '${receipt.confirmations} 确认'}';
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.intent});

  final LoopWalletIntent intent;

  @override
  Widget build(BuildContext context) {
    final (String label, LoopBadgeKind kind) = switch (intent.state) {
      LoopIntentState.confirmed => ('已确认', LoopBadgeKind.up),
      LoopIntentState.submitted => ('等待中', LoopBadgeKind.mining),
      LoopIntentState.reverted ||
      LoopIntentState.failed => ('失败', LoopBadgeKind.down),
      LoopIntentState.unknown => ('未知', LoopBadgeKind.down),
      _ => (moneyIntentStateLabel(intent.state), LoopBadgeKind.mute),
    };
    return LoopRecordCard(
      key: ValueKey<String>('tx-result-banner-${intent.state.wireName}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  moneyIntentStateLabel(intent.state),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              LoopBadge(label, kind: kind),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            intent.result.reasonCode == null
                ? '最新状态。'
                : loopReasonCodeText(intent.result.reasonCode),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ResultFacts extends StatelessWidget {
  const _ResultFacts({required this.intent});

  final LoopWalletIntent intent;

  @override
  Widget build(BuildContext context) {
    final receipt = intent.result.receipt;
    final fee = intent.review.fee;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: LoopSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopKeyValue(
              key: const ValueKey<String>('tx-result-hash'),
              label: '交易哈希',
              value: intent.result.transactionHash ?? '尚未上报',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            if (intent.result.providerActionId != null)
              LoopKeyValue(
                key: const ValueKey<String>('tx-result-action-id'),
                label: '供应商动作',
                value: intent.result.providerActionId!,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            LoopKeyValue(
              key: const ValueKey<String>('tx-result-confirmations'),
              label: '确认数',
              value: receipt == null
                  ? '还没有回执'
                  : receipt.confirmations == null
                  ? '链头读不到'
                  : '${receipt.confirmations}',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              key: const ValueKey<String>('tx-result-gas'),
              label: receipt == null ? '最高网络费' : '实际用量',
              value: receipt == null
                  ? (fee == null
                        ? '不可用'
                        : '${loopFormatDecimal(fee.maximumFee, maxFractionDigits: 10)} BNB')
                  : '${receipt.gasUsed} gas',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              key: const ValueKey<String>('tx-result-updated'),
              label: '更新于',
              value: loopRelativeTime(intent.updatedAt),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ],
        ),
      ),
    );
  }
}
