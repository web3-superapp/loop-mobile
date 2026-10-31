import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_controllers.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `launch2-projects` · 我的项目 (archetype `index`, layout `stream`).
///
/// Every MEME v2 catalogue project the account owns (`kind=launch2`), each
/// with the state its review, Hooks draft, approval and newest task put it
/// in. A row resumes the flow on the page that state belongs to (decision
/// 0142). S326 · decision 0256 (UX-005): the page is inside the launch flow
/// and carries no 「发起」 of its own — the MEME home's 「发射」 is the one
/// way in, so create → 我的项目 → create no longer nests without end.
class Launch2ProjectsScreen extends ConsumerWidget {
  const Launch2ProjectsScreen({super.key, this.onBack, this.onNavigate});

  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = launch2CreatorListControllerProvider;
    final state = ref.watch(provider);
    if (state.phase == LoopChainViewPhase.loading && state.value == null) {
      scheduleMicrotask(() => unawaited(ref.read(provider.notifier).load()));
    }
    final controller = ref.read(provider.notifier);
    final page = state.value;
    final Widget collection;
    if (page == null) {
      collection = ListView(
        children: <Widget>[
          LoopChainStateBlock(
            keyPrefix: 'launch2-projects',
            phase: state.phase,
            failureKind: state.failureKind,
            onRetry: () => unawaited(controller.reload()),
          ),
        ],
      );
    } else if (page.entries.isEmpty) {
      collection = ListView(
        children: <Widget>[
          LoopEmptyState(
            key: const ValueKey<String>('launch2-projects-empty'),
            illustration: LoopIllustration.launchpad,
            title: '还没有发起项目',
            message: 'NFT 预售 + 官方外盘，一次发起。',
          ),
        ],
      );
    } else {
      // Decision 0169: the owner's projects are one `.row` group.
      collection = ListView(
        key: const ValueKey<String>('launch2-projects-list'),
        padding: const EdgeInsets.only(top: 4),
        children: <Widget>[
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (final entry in page.entries)
                switch (entry) {
                  Launch2CreatorReadableListEntry(:final row) => _projectRow(
                    row,
                    // Straight to where the owner left off (decision 0142).
                    () => onNavigate?.call(
                      Launch2CreatorRoute.resume(row.projectId, row.resume),
                    ),
                  ),
                  // Decision 0198: the project page reads it again and
                  // says what it can.
                  Launch2CreatorUnreadableListEntry(:final project) =>
                    _unreadableRow(
                      project,
                      () => onNavigate?.call(
                        Launch2CreatorRoute.project(project.projectId),
                      ),
                    ),
                },
            ],
          ),
          LoopLoadMoreFooter(
            key: const ValueKey<String>('launch2-projects-footer'),
            keyPrefix: 'launch2-projects',
            cursor: page.nextCursor,
            canLoadMore: !state.busy && !state.refreshing,
            loading: state.busy,
            onLoadMore: controller.loadMore,
          ),
        ],
      );
    }
    // Decision 0200: the list stays mounted under the pages a row opens.
    // Coming back re-reads, so an edit, a resubmission or a review made in
    // the meantime shows instead of the answer read before.
    return Launch2RefreshOnReturn(
      onReturn: () {
        final current = ref.read(provider);
        if (current.value == null || current.busy || current.refreshing) {
          return;
        }
        unawaited(ref.read(provider.notifier).reload());
      },
      child: LoopStreamPage(
        key: const ValueKey<String>('launch2-projects-screen'),
        archetype: LoopPageArchetype.listing,
        title: '我的项目',
        onBack: onBack,
        updating: state.refreshing,
        onRefresh: controller.reload,
        collection: collection,
      ),
    );
  }
}

/// What a row says under the project's name.
String _projectSubtitle(Launch2CreatorRow row) {
  final draft = row.draft;
  return switch (row.status) {
    // Decision 0200: 「已拒绝 · 原因类别」; the reviewer's own words are on
    // the project page and the edit form.
    Launch2CreatorStatus.rejected => switch (row.rejection) {
      final LaunchRejection rejection => launch2RejectedRowText(rejection),
      null => row.project.reviewReasonText ?? '已拒绝',
    },
    Launch2CreatorStatus.approved when row.config.recipientOutdated =>
      '回购收币地址需要更新',
    Launch2CreatorStatus.draft when draft == null => '还没有发射配置',
    _ when draft != null =>
      '${loopLocalTimestampLabel(draft.nftSaleStart)} 开始铸造',
    _ => loopTickerLabel(row.project.ticker),
  };
}

/// One project: logo, name, where it stands and its state badge.
LoopRecordRow _projectRow(Launch2CreatorRow row, VoidCallback onTap) {
  final project = row.project;
  final status = row.status;
  return LoopRecordRow(
    key: ValueKey<String>('launch2-project-row-${project.projectId}'),
    leading: MemeLogo(
      symbol: project.ticker,
      imageUrl: row.draft?.logoAssetUrl,
      size: 36,
      radius: 18,
    ),
    title: project.name,
    subtitle: _projectSubtitle(row),
    trailingBadge: Launch2StatusPill(status: status),
    semanticLabel: '${project.name}，${status.label}',
    onTap: () {
      LoopHaptics.selection();
      onTap();
    },
  );
}

/// Decision 0198: a project whose launch configuration this build could not
/// read. It names the project and claims no state.
LoopRecordRow _unreadableRow(LaunchProject project, VoidCallback onTap) {
  return LoopRecordRow(
    key: ValueKey<String>('launch2-project-unreadable-${project.projectId}'),
    leading: MemeLogo(symbol: project.ticker, size: 36, radius: 18),
    title: project.name,
    subtitle: '发射配置暂时读不到，下拉刷新或点开重试',
    semanticLabel: '${project.name}，发射配置暂时读不到',
    onTap: () {
      LoopHaptics.selection();
      onTap();
    },
  );
}
