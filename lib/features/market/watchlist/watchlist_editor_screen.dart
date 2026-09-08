import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_controller.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `watchlist-edit` · reorder, remove and group the owner's Watchlist.
///
/// The whole resource is replaced under a version compare-and-set, so a
/// concurrent edit on another device is reported rather than overwritten. The
/// Watchlist is not a market fact: no price is rendered here.
class WatchlistEditorScreen extends ConsumerStatefulWidget {
  const WatchlistEditorScreen({super.key, this.onBack, this.onNavigate});

  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<WatchlistEditorScreen> createState() =>
      _WatchlistEditorScreenState();
}

class _WatchlistEditorScreenState extends ConsumerState<WatchlistEditorScreen> {
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
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.watchlist),
    );
    final mode = ref.watch(watchlistGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final state = ref.watch(watchlistEditorControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(watchlistEditorControllerProvider.notifier).load(),
          );
        }
      });
    }
    final controller = ref.read(watchlistEditorControllerProvider.notifier);
    final group = state.selectedGroup;

    return LoopDashboardPage(
      key: const ValueKey<String>('watchlist-editor-screen'),
      archetype: LoopPageArchetype.listing,
      title: '自选管理',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('watchlist-save-action'),
          icon: 'check',
          label: '保存自选',
          onPressed: state.canSave ? () => unawaited(_save(controller)) : null,
        ),
      ],
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('watchlist-folio'),
        archetype: LoopFolioArchetype.listing,
        kicker: 'WATCHLIST CONTROL',
        heading: state.isReady ? '${state.itemCount} 个自选资产' : '自选管理',
        caption: '排序与移除只影响自选列表，不改变钱包持仓，也不是行情事实。',
        stamp: state.isDirty ? 'UNSAVED' : 'EDIT',
      ),
      sections: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('watchlist-capability-block'),
            label: '自选编辑当前不可用',
            reasonCode:
                capability.reasonCode ?? 'WATCHLIST_RUNTIME_UNAVAILABLE',
          )
        else if (!state.isReady)
          LoopChainStateBlock(
            keyPrefix: 'watchlist',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '还没有自选资产',
            emptyReason: '在行情页打开一个资产后加入自选，这里会列出它。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          if (state.requiresReload)
            LoopNotice(
              key: const ValueKey<String>('watchlist-conflict'),
              tone: LoopNoticeTone.warn,
              icon: 'warn',
              title: '版本冲突 —— 没有覆盖任何内容',
              body: '自选已在其他设备上改动。请重新加载后再编辑；重新加载会丢弃当前草稿。',
              trailing: LoopButton(
                key: const ValueKey<String>('watchlist-conflict-reload'),
                label: '重新加载',
                onPressed: () => unawaited(controller.reload()),
              ),
            )
          else if (state.failureKind != null)
            LoopErrorState(
              key: const ValueKey<String>('watchlist-save-error'),
              title: '自选没有保存',
              reason: loopChainFailureReason(state.failureKind),
              onRetry: state.canSave
                  ? () => unawaited(_save(controller))
                  : null,
            ),
          const LoopLabel('分组'),
          if (state.groups.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('watchlist-no-groups'),
              message: '还没有分组',
              reason: '自选分组来自服务端资源，本页只编辑已存在的分组。',
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final (index, item)
                        in state.groups.indexed) ...<Widget>[
                      LoopSeg(
                        key: ValueKey<String>('watchlist-group-${item.key}'),
                        label: '${item.name} ${item.items.length}',
                        selected: index == state.selectedGroupIndex,
                        onSelected: () => controller.selectGroup(index),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          if (group != null) ...<Widget>[
            const LoopLabel('拖动排序 · 左滑删除'),
            if (group.items.isEmpty)
              const LoopEmpty(
                key: ValueKey<String>('watchlist-group-empty'),
                message: '这个分组还没有资产',
                reason: '在行情页打开一个资产后加入自选。',
              )
            else
              _ReorderableWatchlist(
                group: group,
                busy: state.busy,
                onReorder: controller.reorder,
                onRemove: (index) => unawaited(
                  _confirmRemove(controller, group.items[index], index),
                ),
                onOpen: (item) => item.isReadable
                    ? _open(MarketAssetRoute.token(item.assetId))
                    : null,
              ),
          ],
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('watchlist-discard'),
                label: '放弃修改',
                onPressed: state.isDirty && !state.busy
                    ? controller.discard
                    : null,
              ),
              LoopButton(
                key: const ValueKey<String>('watchlist-save'),
                label: state.busy ? '正在保存…' : '保存',
                primary: true,
                onPressed: state.canSave
                    ? () => unawaited(_save(controller))
                    : null,
              ),
            ],
          ),
          const LoopNotice(
            key: ValueKey<String>('watchlist-notice'),
            title: '自选不是行情',
            body: '这里不展示价格与涨跌。加入自选前，资产必须已经登记在 registry 里，否则服务端会整份拒绝。',
          ),
        ],
      ],
    );
  }

  Future<void> _save(WatchlistEditorController controller) async {
    final saved = await controller.save();
    if (!mounted) return;
    if (saved) {
      LoopToast.show(context, message: '自选已保存', kind: LoopToastKind.ok);
    }
  }

  Future<void> _confirmRemove(
    WatchlistEditorController controller,
    WatchlistItem item,
    int index,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LoopSheet(
        title: '从自选中移除',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${item.displayName} 会从这个分组移除。移除只在你保存后才会提交到服务端。',
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            LoopButtonPair(
              children: <Widget>[
                LoopButton(
                  label: '取消',
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
                LoopButton(
                  key: const ValueKey<String>('watchlist-remove-confirm'),
                  label: '移除',
                  primary: true,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed ?? false) controller.removeAt(index);
  }
}

class _ReorderableWatchlist extends StatelessWidget {
  const _ReorderableWatchlist({
    required this.group,
    required this.busy,
    required this.onReorder,
    required this.onRemove,
    required this.onOpen,
  });

  final WatchlistGroup group;
  final bool busy;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onRemove;
  final void Function(WatchlistItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ReorderableListView.builder(
        key: const ValueKey<String>('watchlist-reorderable'),
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: group.items.length,
        onReorderItem: busy ? (_, _) {} : onReorder,
        itemBuilder: (context, index) {
          final item = group.items[index];
          return Padding(
            key: ValueKey<String>('watchlist-item-${item.assetId}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: LoopSurfaceCard(
              onTap: item.isReadable ? () => onOpen(item) : null,
              child: Row(
                children: <Widget>[
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        size: 20,
                        color: LoopColors.text3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.displayDetail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (!item.isReadable) const LoopBadge('不可读'),
                  IconButton(
                    key: ValueKey<String>('watchlist-remove-${item.assetId}'),
                    onPressed: busy ? null : () => onRemove(index),
                    tooltip: '移除 ${item.displayName}',
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
