import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
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
  });

  final String? intentId;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;
  final Duration pollInterval;

  @override
  ConsumerState<TransactionResultScreen> createState() =>
      _TransactionResultScreenState();
}

class _TransactionResultScreenState
    extends ConsumerState<TransactionResultScreen> {
  Timer? _poll;
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    final intentId = widget.intentId;
    if (intentId == null) return;
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(
          ref.read(walletIntentControllerProvider(intentId).notifier).load(),
        );
      }
    });
    _poll = Timer.periodic(widget.pollInterval, (_) {
      if (!mounted) return;
      final controller = ref.read(
        walletIntentControllerProvider(intentId).notifier,
      );
      if (!controller.keepsPolling) {
        _poll?.cancel();
        return;
      }
      unawaited(controller.reload());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
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
          caption: '结果页只展示一笔具体操作，需要它的 intentId。',
        ),
        body: const <Widget>[
          LoopEmpty(
            key: ValueKey<String>('tx-result-empty'),
            message: '这里还没有要展示的操作',
            reason: '从发送、授权或兑换的签名弹层进入时，这一页会展示那一笔的服务端状态。',
          ),
        ],
      );
    }

    final blocked = sendCapabilityBlocks(ref);
    final state = ref.watch(walletIntentControllerProvider(intentId));
    final intent = state.value;
    if (intent != null &&
        intent.state == LoopIntentState.confirmed &&
        !_announced) {
      _announced = true;
      // The one place a success toast may fire: the server reported a receipt
      // with enough confirmations. Nothing earlier proves on-chain completion.
      scheduleMicrotask(() {
        if (mounted) LoopToast.show(context, message: '交易已确认');
      });
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
        caption: intent == null ? '结果只来自服务端对账，本页不会自己判断成败。' : _caption(intent),
        stamp: intent == null
            ? null
            : moneyIntentStateLabel(intent.state).toUpperCase(),
      ),
      body: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('tx-result-capability-block'),
            label: '交易状态当前不可读',
            reasonCode: sendCapabilityReason(ref),
          )
        else if (intent == null)
          LoopChainStateBlock(
            keyPrefix: 'tx-result',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '这笔操作没有可读状态',
            onRetry: () => unawaited(
              ref
                  .read(walletIntentControllerProvider(intentId).notifier)
                  .reload(),
            ),
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
          if (intent.state == LoopIntentState.submitted)
            const LoopNotice(
              key: ValueKey<String>('tx-result-pending'),
              icon: 'clock',
              tone: LoopNoticeTone.warn,
              title: '已提交，等待回执',
              body: '提交成功不代表链上已完成。确认需要 15 个区块确认后由服务端对账给出。',
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
            body: '挖矿算力与日产出没有服务端来源，本页不展示任何数字。',
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
                ? '服务端记录的最新状态。'
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
