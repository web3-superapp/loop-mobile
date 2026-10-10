import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_controllers.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `launch2-project` · 项目状态 (archetype `record`, layout `stream`).
///
/// One project on the five milestones 资料 → 审核 → 签名 → 部署 → 激活, the
/// one thing the owner can do next, and what was saved. Pull to re-read.
class Launch2ProjectScreen extends ConsumerWidget {
  const Launch2ProjectScreen({
    required this.projectId,
    super.key,
    this.onBack,
    this.onNavigate,
    this.onOpenInstance,
    this.clock,
  });

  /// `null` when the route carried no valid id: the page fails closed.
  final String? projectId;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;
  final void Function(String instanceId)? onOpenInstance;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = projectId;
    if (id == null) {
      return LoopFocusPage(
        key: const ValueKey<String>('launch2-project-screen'),
        archetype: LoopPageArchetype.record,
        title: '项目',
        onBack: onBack,
        block: const LoopPageBlock(
          key: ValueKey<String>('launch2-project-missing'),
          title: '找不到这个项目',
          message: '链接里没有有效的项目编号。',
        ),
        body: const <Widget>[],
      );
    }
    final provider = launch2ProjectControllerProvider(id);
    final state = ref.watch(provider);
    if (state.phase == LoopChainViewPhase.loading && state.value == null) {
      scheduleMicrotask(() => unawaited(ref.read(provider.notifier).load()));
    }
    final value = state.value;
    final now = (clock ?? DateTime.now)();
    return LoopStreamPage(
      key: const ValueKey<String>('launch2-project-screen'),
      archetype: LoopPageArchetype.record,
      title: value?.project.name ?? '项目',
      onBack: onBack,
      updating: state.refreshing,
      onRefresh: ref.read(provider.notifier).reload,
      collection: ListView(
        key: const ValueKey<String>('launch2-project-body'),
        children: value == null
            ? <Widget>[
                LoopChainStateBlock(
                  keyPrefix: 'launch2-project',
                  phase: state.phase,
                  failureKind: state.failureKind,
                  emptyMessage: '找不到这个项目',
                  onRetry: () =>
                      unawaited(ref.read(provider.notifier).reload()),
                ),
              ]
            : _body(value, now),
      ),
    );
  }

  List<Widget> _body(Launch2CreatorProject value, DateTime now) {
    final project = value.project;
    final draft = value.draft;
    final status = value.status;
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          8,
          LoopSpacing.page,
          16,
        ),
        child: Row(
          children: <Widget>[
            MemeLogo(
              symbol: project.ticker,
              imageUrl: draft?.logoAssetUrl,
              size: 56,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.headingSm,
                  ),
                  Text(
                    '\$${project.ticker}',
                    style: LoopType.caption.copyWith(color: LoopColors.text2),
                  ),
                ],
              ),
            ),
            Launch2StatusPill(status: status),
          ],
        ),
      ),
      Launch2MilestoneTrack(status: status),
      ..._next(value, status),
      if (draft != null) ...<Widget>[
        const LoopLabel('发射配置'),
        LoopKeyValue(
          label: 'NFT 开售',
          value: launch2SaleStartLabel(draft.nftSaleStart, now),
        ),
        LoopKeyValue(
          label: '回购收币地址',
          value: loopTruncatedAddress(draft.buybackRecipient),
        ),
        LoopKeyValue(label: '配置版本', value: 'v${draft.version}'),
        const SizedBox(height: 8),
        Launch2TemplateCard(economics: draft.economics, fromServer: true),
      ],
    ];
  }

  Widget _action(String key, String label, VoidCallback? onPressed) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      0,
      LoopSpacing.page,
      20,
    ),
    child: LoopButton(
      key: ValueKey<String>(key),
      label: label,
      primary: true,
      block: true,
      onPressed: onPressed,
    ),
  );

  void _go(String location) => onNavigate?.call(location);

  /// The state in one sentence and the one next step.
  List<Widget> _next(Launch2CreatorProject value, Launch2CreatorStatus status) {
    final project = value.project;
    final id = project.projectId;
    final job = value.job;
    switch (status) {
      case Launch2CreatorStatus.draft:
        return <Widget>[
          LoopNotice(
            key: const ValueKey<String>('launch2-project-next-draft'),
            icon: 'info',
            body: value.draft == null ? '资料已保存，还差发射配置。' : '还没有提交审核。',
          ),
          _action(
            'launch2-project-continue',
            '继续填写',
            () => _go(Launch2CreatorRoute.edit(id)),
          ),
        ];
      case Launch2CreatorStatus.awaitingApproval:
        final submitted = project.submittedAt;
        return <Widget>[
          LoopNotice(
            key: const ValueKey<String>('launch2-project-next-review'),
            icon: 'clock',
            title: value.configAwaitingApproval ? '配置等待平台审批' : '平台审核中',
            body: value.configAwaitingApproval
                ? '资料已通过，发射配置还在等审批。审批通过后回来签名。'
                : submitted == null
                ? '审核结果会显示在这里，下拉可刷新。'
                : '${loopLocalTimestampLabel(submitted)} 提交，审核结果会显示在这里。',
          ),
        ];
      case Launch2CreatorStatus.rejected:
        final returned = project.reviewStatus == LaunchReviewStatus.returned;
        return <Widget>[
          LoopNotice(
            key: const ValueKey<String>('launch2-project-next-rejected'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '审核意见',
            // The server's own sentence, rendered verbatim (decision 0041).
            body: project.reviewReasonText ?? '这次审核没有通过。',
          ),
          if (returned)
            _action(
              'launch2-project-resubmit',
              '修改后重新提交',
              () => _go(Launch2CreatorRoute.edit(id)),
            )
          else
            _action(
              'launch2-project-restart',
              '重新发起',
              () => _go(Launch2CreatorRoute.createPath),
            ),
        ];
      case Launch2CreatorStatus.approved:
      case Launch2CreatorStatus.signing:
        return <Widget>[
          const LoopNotice(
            key: ValueKey<String>('launch2-project-next-sign'),
            icon: 'check',
            body: '已通过审核。用钱包签名后，平台会部署并激活。',
          ),
          _action(
            'launch2-project-sign',
            '去签名部署',
            () => _go(Launch2CreatorRoute.sign(id)),
          ),
        ];
      case Launch2CreatorStatus.deploying:
      case Launch2CreatorStatus.deployed:
      case Launch2CreatorStatus.verified:
        return <Widget>[
          LoopNotice(
            key: const ValueKey<String>('launch2-project-next-deploying'),
            icon: 'clock',
            body: job == null ? '部署进行中。' : launch2JobStatusText(job),
          ),
          if (job != null)
            _action(
              'launch2-project-progress',
              '查看部署进度',
              () => _go(Launch2CreatorRoute.deployment(id, job.jobId)),
            ),
        ];
      case Launch2CreatorStatus.deployFailed:
        final code = job?.failure?.code;
        final edit = code != null && launch2JobFailureNeedsEdit(code);
        return <Widget>[
          LoopNotice(
            key: const ValueKey<String>('launch2-project-next-failed'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            body: code == null ? '部署没有完成。' : launch2JobFailureText(code),
          ),
          if (edit)
            _action(
              'launch2-project-edit',
              '修改开售时间',
              () => _go(Launch2CreatorRoute.edit(id)),
            )
          else
            _action(
              'launch2-project-resign',
              '重新签名',
              () => _go(Launch2CreatorRoute.sign(id)),
            ),
        ];
      case Launch2CreatorStatus.active:
        final instance = value.instance;
        return <Widget>[
          LoopNotice(
            key: const ValueKey<String>('launch2-project-next-active'),
            icon: 'check',
            body: instance == null ? '已激活，项目页生成中，下拉可刷新。' : '已激活，你是这个项目的项目方。',
          ),
          if (instance != null)
            _action(
              'launch2-project-open-instance',
              '查看项目页',
              () => onOpenInstance?.call(instance.instanceId),
            ),
        ];
    }
  }
}
