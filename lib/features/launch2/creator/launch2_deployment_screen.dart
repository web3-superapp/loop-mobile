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
import 'package:loop_mobile/l10n/loop_l10n.dart';
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
        title: context
            .l10n
            .launch2Creator_launch2DeploymentLaunch2DeploymentScreenTitle,
        onBack: onBack,
        block: LoopPageBlock(
          key: ValueKey<String>('launch2-deployment-missing'),
          title: context
              .l10n
              .launch2Creator_launch2DeploymentLaunch2DeploymentMissingTitle,
          message: context
              .l10n
              .launch2Creator_launch2DeploymentLaunch2DeploymentMissingMessage,
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
      title: context
          .l10n
          .launch2Creator_launch2DeploymentLaunch2DeploymentScreenTitle,
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
                  emptyMessage: context
                      .l10n
                      .launch2Creator_launch2DeploymentLaunch2DeploymentMissingTitle,
                  onRetry: () =>
                      unawaited(ref.read(provider.notifier).reload()),
                ),
              ]
            : <Widget>[
                if (state.failureKind != null)
                  LoopNotice(
                    key: const ValueKey<String>('launch2-deployment-stale'),
                    icon: 'offline',
                    body: context
                        .l10n
                        .launch2Creator_launch2DeploymentLaunch2DeploymentStaleBody,
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
          style: LoopType.heading,
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
          body: instance == null
              ? context
                    .l10n
                    .launch2Creator_launch2DeploymentLaunch2DeploymentActivatedBody
              : context
                    .l10n
                    .launch2Creator_launch2DeploymentLaunch2DeploymentActivatedBody2,
        ),
        if (instance != null)
          _action(
            'launch2-deployment-open-instance',
            context.l10n.launch2Creator_launch2DeploymentAction,
            () => onOpenInstance?.call(instance.instanceId),
          ),
      ] else if (job.status == Launch2JobStatus.cancelled) ...<Widget>[
        LoopNotice(
          key: ValueKey<String>('launch2-deployment-cancelled'),
          icon: 'info',
          body: context
              .l10n
              .launch2Creator_launch2DeploymentLaunch2DeploymentCancelledBody,
        ),
        _action(
          'launch2-deployment-resign',
          context.l10n.launch2Creator_launch2DeploymentAction2,
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
            launch2JobFailureEditLabel(failure.code),
            () => onEdit?.call(project),
          )
        else if (!failure.retryable)
          _action(
            'launch2-deployment-resign',
            context.l10n.launch2Creator_launch2DeploymentAction2,
            () => onResign?.call(project),
          ),
      ] else if (job.status == Launch2JobStatus.awaitingExecutor)
        LoopNotice(
          key: ValueKey<String>('launch2-deployment-queued'),
          icon: 'clock',
          body: context
              .l10n
              .launch2Creator_launch2DeploymentLaunch2DeploymentQueuedBody,
        ),
      LoopLabel(context.l10n.launch2Creator_launch2DeploymentLoopLabel),
      for (final event in job.events)
        _EventRow(
          key: ValueKey<String>('launch2-event-${event.sequence}'),
          event: event,
        ),
      if (job.txHash != null)
        _TxRow(
          label: context.l10n.launch2Creator_launch2DeploymentLabel,
          hash: job.txHash!,
        ),
      if (job.activationTxHash != null)
        _TxRow(
          label: context.l10n.launch2Creator_launch2DeploymentLabel2,
          hash: job.activationTxHash!,
        ),
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
      if (event.confirmations != null)
        context.l10n.launch2Creator_launch2DeploymentBuild(event.confirmations),
      if (event.blockNumber != null)
        context.l10n.launch2Creator_launch2DeploymentBuild2(event.blockNumber),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LoopSpacing.page,
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Decision 0169: a failed step is a Chalk dot, not the v1 danger
          // pink; what failed is the page's `LoopNotice` and the line below.
          Container(
            key: ValueKey<String>(
              'launch2-event-dot-${failed ? 'failed' : 'done'}',
            ),
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              // S241b: a square mark (decision 0210), Yellow when done.
              color: failed ? LoopColors.chalk : LoopColors.yellow,
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
            label: context.l10n.launch2Creator_launch2DeploymentLabel3,
            onPressed: () => unawaited(
              LoopCopy.text(
                context,
                url,
                message: context.l10n.launch2Creator_launch2DeploymentMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
