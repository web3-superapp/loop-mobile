import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_controllers.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_sign_screen.dart'
    show Launch2AddressTail;
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `launch2-project-deployment` · 部署进度 (archetype `state`, layout
/// `stream`).
///
/// The executor's job read every few seconds until it settles (§6): its
/// status in the owner's words, the `events[]` timeline with the BscScan
/// testnet link of each transaction, a failure in one sentence with the one
/// next step, and — once activated — the way to the project page.
class Launch2DeploymentScreen extends ConsumerWidget {
  const Launch2DeploymentScreen({
    required this.projectId,
    required this.jobId,
    super.key,
    this.onBack,
    this.onResign,
    this.onEdit,
    this.onOpenInstance,
  });

  final String? projectId;
  final String? jobId;
  final VoidCallback? onBack;
  final void Function(String projectId)? onResign;
  final void Function(String projectId)? onEdit;
  final void Function(String instanceId)? onOpenInstance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = projectId;
    final job = jobId;
    if (project == null || job == null) {
      return LoopFocusPage(
        key: const ValueKey<String>('launch2-deployment-screen'),
        archetype: LoopPageArchetype.state,
        title: '部署进度',
        onBack: onBack,
        block: const LoopPageBlock(
          key: ValueKey<String>('launch2-deployment-missing'),
          title: '找不到这次部署',
          message: '链接里没有有效的项目或任务编号。',
        ),
        body: const <Widget>[],
      );
    }
    final key = (projectId: project, jobId: job);
    final provider = launch2DeploymentControllerProvider(key);
    final state = ref.watch(provider);
    if (state.phase == LoopChainViewPhase.loading && state.value == null) {
      scheduleMicrotask(() => unawaited(ref.read(provider.notifier).load()));
    }
    final value = state.value;
    Launch2InstanceRef? instance;
    if (value?.status == Launch2JobStatus.activated) {
      final lookup = launch2InstanceLookupProvider(project);
      instance = ref.watch(lookup);
      if (instance == null) {
        scheduleMicrotask(() => unawaited(ref.read(lookup.notifier).start()));
      }
    }
    return LoopStreamPage(
      key: const ValueKey<String>('launch2-deployment-screen'),
      archetype: LoopPageArchetype.state,
      title: '部署进度',
      onBack: onBack,
      updating: state.refreshing,
      onRefresh: ref.read(provider.notifier).reload,
      collection: ListView(
        key: const ValueKey<String>('launch2-deployment-body'),
        children: value == null
            ? <Widget>[
                LoopChainStateBlock(
                  keyPrefix: 'launch2-deployment',
                  phase: state.phase,
                  failureKind: state.failureKind,
                  emptyMessage: '找不到这次部署',
                  onRetry: () =>
                      unawaited(ref.read(provider.notifier).reload()),
                ),
              ]
            : <Widget>[
                if (state.failureKind != null)
                  LoopNotice(
                    key: const ValueKey<String>('launch2-deployment-stale'),
                    icon: 'offline',
                    body: '最新进度没有读到，下面是上一次读到的状态，会自动重试。',
                  ),
                ..._body(context, value, instance),
              ],
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    Launch2DeploymentJob job,
    Launch2InstanceRef? instance,
  ) {
    final failure = job.failure;
    final project = job.projectId;
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          8,
          LoopSpacing.page,
          4,
        ),
        child: Text(
          launch2JobStatusText(job),
          key: ValueKey<String>(
            'launch2-deployment-status-${job.status.wireName}',
          ),
          style: LoopType.figureLg,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          16,
        ),
        child: Launch2AddressTail(address: job.deployedMeme ?? job.memeAddress),
      ),
      if (job.status == Launch2JobStatus.activated) ...<Widget>[
        LoopNotice(
          key: const ValueKey<String>('launch2-deployment-activated'),
          icon: 'check',
          body: instance == null ? '已激活，项目页生成中…' : '已激活，你是这个项目的项目方。',
        ),
        if (instance != null)
          _action(
            'launch2-deployment-open-instance',
            '查看项目页',
            () => onOpenInstance?.call(instance.instanceId),
          ),
      ] else if (job.status == Launch2JobStatus.cancelled) ...<Widget>[
        const LoopNotice(
          key: ValueKey<String>('launch2-deployment-cancelled'),
          icon: 'info',
          body: '这次部署已取消。',
        ),
        _action(
          'launch2-deployment-resign',
          '重新签名',
          () => onResign?.call(project),
        ),
      ] else if (failure != null) ...<Widget>[
        LoopNotice(
          key: ValueKey<String>('launch2-deployment-failure-${failure.code}'),
          icon: failure.retryable ? 'clock' : 'warn',
          tone: failure.retryable ? LoopNoticeTone.normal : LoopNoticeTone.warn,
          body: failure.retryable
              ? launch2JobFailureText('HOOKS_TX_DROPPED')
              : launch2JobFailureText(failure.code),
        ),
        if (!failure.retryable && launch2JobFailureNeedsEdit(failure.code))
          _action(
            'launch2-deployment-edit',
            '修改开售时间',
            () => onEdit?.call(project),
          )
        else if (!failure.retryable)
          _action(
            'launch2-deployment-resign',
            '重新签名',
            () => onResign?.call(project),
          ),
      ] else if (job.status == Launch2JobStatus.awaitingExecutor)
        const LoopNotice(
          key: ValueKey<String>('launch2-deployment-queued'),
          icon: 'clock',
          body: '已验签登记，等待平台执行器部署。这一步还没有上链。',
        ),
      const LoopLabel('进度'),
      for (final event in job.events)
        _EventRow(
          key: ValueKey<String>('launch2-event-${event.sequence}'),
          event: event,
        ),
      if (job.txHash != null) _TxRow(label: '部署交易', hash: job.txHash!),
      if (job.activationTxHash != null)
        _TxRow(label: '激活交易', hash: job.activationTxHash!),
      const SizedBox(height: 24),
    ];
  }

  Widget _action(String key, String label, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      0,
      LoopSpacing.page,
      16,
    ),
    child: LoopButton(
      key: ValueKey<String>(key),
      label: label,
      primary: true,
      block: true,
      onPressed: onPressed,
    ),
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, super.key});

  final Launch2JobEvent event;

  @override
  Widget build(BuildContext context) {
    final failed = event.kind == 'failed' || event.errorCode != null;
    final detail = <String>[
      loopLocalTimestampLabel(event.createdAt),
      if (event.confirmations != null) '${event.confirmations} 确认',
      if (event.blockNumber != null) '区块 ${event.blockNumber}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LoopSpacing.page,
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: failed ? LoopColors.danger : LoopColors.lime,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(launch2EventTitle(event), style: LoopType.title),
                Text(
                  detail,
                  style: LoopType.caption.copyWith(color: LoopColors.text3),
                ),
                if (event.errorCode != null)
                  Text(
                    launch2JobFailureText(event.errorCode!),
                    style: LoopType.caption.copyWith(color: LoopColors.text2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One transaction: its short hash, and a control that copies its BscScan
/// testnet address (the App opens no browser).
class _TxRow extends StatelessWidget {
  const _TxRow({required this.label, required this.hash});

  final String label;
  final String hash;

  @override
  Widget build(BuildContext context) {
    final url = launch2ExplorerTx(hash)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 4, 8, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: LoopKeyValue(
              label: label,
              value: loopTruncatedAddress(hash),
              padding: EdgeInsets.zero,
            ),
          ),
          LoopIconButton(
            key: ValueKey<String>('launch2-tx-copy-$hash'),
            icon: 'link',
            label: '复制 BscScan 链接',
            onPressed: () => unawaited(
              LoopCopy.text(context, url, message: 'BscScan 链接已复制'),
            ),
          ),
        ],
      ),
    );
  }
}
