import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_controllers.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// `launch2-projects` · 我的项目 (archetype `index`, layout `stream`).
///
/// Every catalogue project the account owns, each with the state its Hooks
/// draft and review put it in. A row opens the project's status page; the
/// top bar's ＋ starts a new one.
class Launch2ProjectsScreen extends ConsumerWidget {
  const Launch2ProjectsScreen({super.key, this.onBack, this.onNavigate});

  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = launch2CreatorListControllerProvider;
    final state = ref.watch(provider);
    final memory = ref.watch(launch2CreatorMemoryProvider);
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
    } else if (page.rows.isEmpty) {
      collection = ListView(
        children: <Widget>[
          LoopEmptyState(
            key: const ValueKey<String>('launch2-projects-empty'),
            illustration: LoopIllustration.launchpad,
            title: '还没有发起项目',
            message: 'NFT 预售 + 官方外盘，一次发起。',
            action: LoopButton(
              key: const ValueKey<String>('launch2-projects-empty-create'),
              label: '发起 v2 发射',
              primary: true,
              onPressed: () => onNavigate?.call(Launch2CreatorRoute.createPath),
            ),
          ),
        ],
      );
    } else {
      collection = ListView.builder(
        key: const ValueKey<String>('launch2-projects-list'),
        itemCount: page.rows.length + 1,
        itemBuilder: (context, index) {
          if (index == page.rows.length) {
            return LoopLoadMoreFooter(
              key: const ValueKey<String>('launch2-projects-footer'),
              keyPrefix: 'launch2-projects',
              cursor: page.nextCursor,
              canLoadMore: !state.busy && !state.refreshing,
              loading: state.busy,
              onLoadMore: controller.loadMore,
            );
          }
          final row = page.rows[index];
          final status = launch2CreatorStatusOf(
            reviewStatus: row.project.reviewStatus,
            hasDraft: row.draft != null,
            job: memory.jobs[row.project.projectId],
            configAwaitingApproval: memory.awaitingApproval.contains(
              row.project.projectId,
            ),
          );
          return _ProjectRow(
            row: row,
            status: status,
            onTap: () => onNavigate?.call(
              Launch2CreatorRoute.project(row.project.projectId),
            ),
          );
        },
      );
    }
    return LoopStreamPage(
      key: const ValueKey<String>('launch2-projects-screen'),
      archetype: LoopPageArchetype.listing,
      title: '我的项目',
      onBack: onBack,
      updating: state.refreshing,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('launch2-projects-create'),
          icon: 'plus',
          label: '发起 v2 发射',
          onPressed: () => onNavigate?.call(Launch2CreatorRoute.createPath),
        ),
      ],
      onRefresh: controller.reload,
      collection: collection,
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.row,
    required this.status,
    required this.onTap,
  });

  final Launch2CreatorRow row;
  final Launch2CreatorStatus status;
  final VoidCallback onTap;

  String get _subtitle {
    final draft = row.draft;
    return switch (status) {
      Launch2CreatorStatus.rejected => row.project.reviewReasonText ?? '审核未通过',
      Launch2CreatorStatus.draft when draft == null => '还没有发射配置',
      _ when draft != null =>
        '开售 ${loopLocalTimestampLabel(draft.nftSaleStart)}',
      _ => '\$${row.project.ticker}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final project = row.project;
    return LoopPressable(
      key: ValueKey<String>('launch2-project-row-${project.projectId}'),
      onTap: onTap,
      haptic: LoopHaptic.selection,
      scale: false,
      child: Semantics(
        button: true,
        label: '${project.name}，${status.label}',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LoopSpacing.page,
              vertical: 12,
            ),
            child: Row(
              children: <Widget>[
                MemeLogo(
                  symbol: project.ticker,
                  imageUrl: row.draft?.logoAssetUrl,
                  size: 36,
                  radius: 18,
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
                        style: LoopType.titleLg,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.caption.copyWith(
                          color: LoopColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Launch2StatusPill(status: status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
