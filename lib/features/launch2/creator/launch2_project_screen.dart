import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
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
import 'package:loop_mobile/features/launch2/launch2_widgets.dart'
    show Launch2CountdownBuilder;
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_step_track.dart';
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
    final clock = this.clock ?? DateTime.now;
    // Decision 0200: the page stays mounted under 修改 / 签名 / 部署进度;
    // coming back re-reads it.
    return Launch2RefreshOnReturn(
      onReturn: () {
        final current = ref.read(provider);
        if (current.value == null || current.busy || current.refreshing) {
          return;
        }
        unawaited(ref.read(provider.notifier).reload());
      },
      child: LoopStreamPage(
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
              : _body(value, clock),
        ),
      ),
    );
  }

  List<Widget> _body(Launch2CreatorProject value, DateTime Function() clock) {
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
                    loopTickerLabel(project.ticker),
                    style: LoopType.caption.copyWith(color: LoopColors.text2),
                  ),
                ],
              ),
            ),
            Launch2StatusPill(status: status),
          ],
        ),
      ),
      // Decision 0233: the NFT image submitted with the draft, beside its
      // label; a draft saved before it existed has none and shows nothing.
      if (draft?.nftImageAssetUrl case final String nftImage)
        Padding(
          key: const ValueKey<String>('launch2-project-nft-image'),
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            16,
          ),
          child: Row(
            children: <Widget>[
              Launch2NftImageFrame(imageUrl: nftImage, size: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'NFT 图',
                      style: LoopType.label.copyWith(color: LoopColors.chalk),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      launch2NftImageHelp,
                      style: LoopType.captionSm.copyWith(
                        color: LoopColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      // Decision 0169: the shared step track (was Launch2MilestoneTrack).
      LoopStepTrack.milestones(
        key: ValueKey<String>('launch2-milestones-${status.wireName}'),
        labels: launch2CreatorMilestones,
        current: status.milestone,
        reachedCurrent: status == Launch2CreatorStatus.active,
        failed: status.isFailure,
        semanticLabel:
            '进度：${launch2CreatorMilestones[status.milestone]}，${status.label}',
      ),
      ..._next(value, status),
      if (draft != null) ...<Widget>[
        const LoopLabel('发射配置'),
        // Decision 0200: 「（N 小时后）」 follows the clock, not the build.
        Launch2CountdownBuilder(
          target: draft.nftSaleStart,
          builder: (context, _) => LoopKeyValue(
            key: const ValueKey<String>('launch2-project-sale-start'),
            label: '铸造开始',
            value: launch2SaleStartLabel(draft.nftSaleStart, clock()),
          ),
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
        // 等审核页 (decision 0142). A rejection shows under `rejected`
        // (decision 0144); a resubmitted version is awaiting again.
        final submitted = launch2LatestSubmission(value);
        return <Widget>[
          LoopNotice(
            key: const ValueKey<String>('launch2-project-next-review'),
            icon: 'clock',
            title: '审核中',
            body: submitted == null
                ? '平台审核发射配置，结果会显示在这里，下拉可刷新。'
                : '${loopLocalTimestampLabel(submitted)} 提交，'
                      '结果会显示在这里，下拉可刷新。',
          ),
        ];
      case Launch2CreatorStatus.rejected:
        // Returned, rejected material and a rejected launch configuration
        // are all edited and resubmitted (loop-api decision 0122).
        final rejection = value.rejection;
        final catalogue =
            project.reviewStatus == LaunchReviewStatus.rejected ||
            project.reviewStatus == LaunchReviewStatus.returned;
        return <Widget>[
          if (rejection != null)
            KeyedSubtree(
              key: const ValueKey<String>('launch2-project-next-rejected'),
              child: Launch2RejectionNotice(
                rejection: rejection,
                configuration: !catalogue,
              ),
            )
          else
            LoopNotice(
              key: const ValueKey<String>('launch2-project-next-rejected'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '审核意见',
              // The server's own sentence, rendered verbatim (decision 0041).
              body: project.reviewReasonText ?? '这次审核没有通过，修改后可以重新提交。',
            ),
          _action(
            'launch2-project-resubmit',
            '修改后重新提交',
            () => _go(Launch2CreatorRoute.edit(id)),
          ),
        ];
      case Launch2CreatorStatus.approved:
      case Launch2CreatorStatus.signing:
        final approvedAt = value.approval?.approvedAt;
        if (value.config.recipientOutdated) {
          // An approved version with another recipient can never be signed
          // (loop-api decision 0122, ruling 2): save a new version.
          return <Widget>[
            const LoopNotice(
              key: ValueKey<String>('launch2-project-next-recipient-outdated'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '回购收币地址需要更新',
              body:
                  '这一版配置的回购收币地址不是平台固定地址，不能签名部署。'
                  '修改资料重新保存一版后需要重新审核。',
            ),
            _action(
              'launch2-project-update-recipient',
              '修改资料',
              () => _go(Launch2CreatorRoute.edit(id)),
            ),
          ];
        }
        return <Widget>[
          LoopNotice(
            key: const ValueKey<String>('launch2-project-next-sign'),
            icon: 'check',
            title: '已批准',
            body: approvedAt == null
                ? '用钱包签名后，平台会部署并激活。'
                : '${loopLocalTimestampLabel(approvedAt)} 批准。'
                      '用钱包签名后，平台会部署并激活。',
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
              launch2JobFailureEditLabel(code),
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

/// When the owner last submitted (decision 0200): the catalogue's
/// `submittedAt` is the project's first submission, and a resubmission after
/// a rejected launch configuration only saves a new configuration version,
/// so the later of the two is the submission under review now.
DateTime? launch2LatestSubmission(Launch2CreatorProject value) {
  final submitted = value.project.submittedAt;
  final saved = value.draft?.updatedAt;
  if (submitted == null) return null;
  if (saved == null || !saved.isAfter(submitted)) return submitted;
  return saved;
}
