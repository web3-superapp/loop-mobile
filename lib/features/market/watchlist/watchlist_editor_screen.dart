import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_controller.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
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
      kicker: loopChainPreviewKicker(mode),
      onBack: widget.onBack,
      actions: <Widget>[
        // `.topbar .seg`: the prototype's 完成 text pill. A bare ✓ glyph did
        // not read as a save (audit 2026-09-21 §G.6).
        LoopSeg(
          key: const ValueKey<String>('watchlist-save-action'),
          label: '完成',
          selected: false,
          onSelected: state.canSave ? () => unawaited(_save(controller)) : null,
        ),
      ],
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('watchlist-folio'),
        variant: LoopFolioVariant.chalk,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: marketWatchlistKicker,
        heading: state.isReady ? '${state.itemCount} 个自选资产' : '自选管理',
        caption: '排序与移除只影响自选列表，不改变钱包持仓，也不是行情事实。',
        stamp: state.isDirty ? '未保存' : '编辑',
      ),
      // An edit surface takes no pull-to-refresh: a background re-read would
      // drop an ordering the user has not saved yet.
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('watchlist-capability-block'),
              title: '自选编辑当前不可用',
              capability: capability,
              fallbackReasonCode: 'WATCHLIST_RUNTIME_UNAVAILABLE',
            )
          : null,
      sections: <Widget>[
        LoopChainPreviewNotice(mode: mode, resource: '自选列表'),
        if (!state.isReady)
          LoopChainStateBlock(
            keyPrefix: 'watchlist',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '还没有自选资产',
            emptyReason: '打开代币页，点右上角星标即可加入自选。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          if (state.requiresReload) ...<Widget>[
            LoopNotice(
              key: const ValueKey<String>('watchlist-conflict'),
              tone: LoopNoticeTone.warn,
              icon: 'warn',
              title: '版本冲突 —— 没有覆盖任何内容',
              body: '自选已在其他设备上改动。重新加载会丢弃下面这些改动，先复制草稿再决定。',
            ),
            // A reload is destructive, so it is offered only next to a list of
            // exactly what it would discard and a way to keep that list.
            _ConflictDiff(
              changes: state.draftChanges,
              onCopyDraft: () => unawaited(_copyDraft(state.draftAsText)),
              onReload: () => unawaited(controller.reload()),
            ),
          ]
          // A save that never reached the server changed nothing on either
          // side; the draft below is still exactly what was typed.
          else if (state.failureKind == LoopChainFailureKind.offline)
            LoopOfflineState(
              key: const ValueKey<String>('watchlist-save-offline'),
              pausedActions: const <String>['保存自选'],
              onRetry: state.canSave
                  ? () => unawaited(_save(controller))
                  : null,
            )
          // The server answered and refused. A retry would claim the answer
          // might change; the draft below is untouched either way.
          else if (LoopChainCommandPermission.covers(state.failureKind))
            LoopChainCommandPermission(
              blockKey: 'watchlist-save-permission',
              failureKind: state.failureKind,
              title: '当前账号无权保存自选',
              onOpenSecurity: () => _open('/profile/security'),
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
          // The prototype's order: the list the page exists to edit comes
          // first, and 分组 sits under it. LOOP put the chips, two buttons
          // and two ⓘ cards between the hero and the list, which pushed the
          // list onto the second screen (audit 2026-09-21 §G.6).
          if (group != null) ...<Widget>[
            const LoopLabel('拖动排序 · 左滑删除'),
            if (group.items.isEmpty)
              LoopEmpty(
                key: const ValueKey<String>('watchlist-group-empty'),
                message: '这个分组还没有资产',
                reason: '打开代币页，点右上角星标即可加入自选。',
                action: LoopButton(
                  key: const ValueKey<String>('watchlist-group-empty-add'),
                  label: '添加资产',
                  onPressed: () => _open('/market/new'),
                ),
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
          const LoopLabel('分组'),
          if (state.groups.isEmpty)
            LoopEmpty(
              key: const ValueKey<String>('watchlist-no-groups'),
              message: '还没有分组',
              reason:
                  '有两条路：在代币页点右上角星标，资产会进入默认分组「$watchlistDefaultGroupName」；'
                  '或者在这里先建一个分组。',
              action: LoopButton(
                key: const ValueKey<String>('watchlist-new-group-empty'),
                label: '新建分组',
                onPressed: state.busy
                    ? null
                    : () => unawaited(_createGroup(controller, state)),
              ),
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
          if (state.groups.isNotEmpty) ...<Widget>[
            LoopButtonPair(
              children: <Widget>[
                // C-30 (8): the page could only reorder and remove, so an
                // owner looking for 「在哪儿增加自选」 found nothing here. It
                // still cannot add — the write lives on the token page — so
                // the button is a route to a page with token pages on it, and
                // the notice below says where the asset lands.
                LoopButton(
                  key: const ValueKey<String>('watchlist-add-asset'),
                  label: '添加资产',
                  onPressed: () => _open('/market/new'),
                ),
                LoopButton(
                  key: const ValueKey<String>('watchlist-new-group'),
                  label: '新建分组',
                  onPressed:
                      state.busy || state.groups.length >= watchlistMaxGroups
                      ? null
                      : () => unawaited(_createGroup(controller, state)),
                ),
              ],
            ),
            LoopNotice(
              key: const ValueKey<String>('watchlist-add-asset-note'),
              icon: 'info',
              title: '怎么添加资产',
              body:
                  '加入自选只有一条路：打开代币页，点右上角星标。'
                  '这样加入的资产进入默认分组「$watchlistDefaultGroupName」，'
                  '本页不能把它移到别的分组。'
                  '行情的「趋势」和「新币发现」都能打开代币页。',
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            ),
            // A control that greys out without a word looks broken. At the
            // ceiling it says which ceiling and what clears it.
            if (state.groups.length >= watchlistMaxGroups)
              LoopNotice(
                key: const ValueKey<String>('watchlist-group-limit'),
                icon: 'info',
                body:
                    '分组已达上限 $watchlistMaxGroups 个。'
                    '要新建一个，先删掉一个现有分组。',
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
            body:
                '这里不展示价格与涨跌。本页只排序、移除与建分组；加入资产在代币页点星标。'
                '资产必须已经在 LOOP 登记，否则整份自选表都不会保存。',
          ),
        ],
      ],
    );
  }

  /// Asks for a name, then adds the group to the draft.
  ///
  /// The field validates against the same bounds the server does, so the
  /// refusal is named before a save can be spent on it.
  Future<void> _createGroup(
    WatchlistEditorController controller,
    WatchlistEditorState state,
  ) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NewGroupSheet(groups: state.groups),
    );
    if (name == null || !mounted) return;
    final issue = controller.createGroup(name);
    if (issue == null || !mounted) return;
    LoopToast.show(
      context,
      message: watchlistGroupNameIssueText(issue),
      kind: LoopToastKind.err,
    );
  }

  Future<void> _copyDraft(String draft) async {
    await Clipboard.setData(ClipboardData(text: draft));
    if (!mounted) return;
    LoopToast.show(context, message: '草稿已复制', kind: LoopToastKind.ok);
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
              '${item.displayName} 会从这个分组移除。保存后才会生效。',
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

/// One name, validated live against the write contract.
class _NewGroupSheet extends StatefulWidget {
  const _NewGroupSheet({required this.groups});

  final List<WatchlistGroup> groups;

  @override
  State<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends State<_NewGroupSheet> {
  final TextEditingController _name = TextEditingController();
  WatchlistGroupNameIssue? _issue;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final issue = watchlistGroupNameIssue(_name.text, existing: widget.groups);
    if (issue != null) {
      setState(() => _issue = issue);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return LoopSheet(
      title: '新建分组',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('watchlist-group-name-field'),
            controller: _name,
            autofocus: true,
            maxLength: watchlistMaxNameCodePoints,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '分组名称',
              hintText: '1–$watchlistMaxNameCodePoints 个字符',
            ),
            onChanged: (_) {
              if (_issue != null) setState(() => _issue = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          if (_issue case final issue?) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              watchlistGroupNameIssueText(issue),
              key: const ValueKey<String>('watchlist-group-name-error'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
          const SizedBox(height: 16),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                label: '取消',
                onPressed: () => Navigator.of(context).pop(),
              ),
              LoopButton(
                key: const ValueKey<String>('watchlist-group-name-confirm'),
                label: '添加分组',
                primary: true,
                onPressed: _submit,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '分组保存后才会生效，最多 $watchlistMaxGroups 个。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
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
      // `.row` inside one container: the prototype's rows share a card and a
      // hairline. LOOP gave every row its own card with air between them, and
      // the list lost its rhythm (audit 2026-09-21 §G.6).
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: LoopColors.chalk.withValues(alpha: 0.045),
          borderRadius: LoopRadius.card,
        ),
        child: ReorderableListView.builder(
          key: const ValueKey<String>('watchlist-reorderable'),
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: group.items.length,
          onReorderItem: busy ? (_, _) {} : onReorder,
          itemBuilder: (context, index) {
            final item = group.items[index];
            final last = index == group.items.length - 1;
            return Material(
              key: ValueKey<String>('watchlist-item-${item.assetId}'),
              type: MaterialType.transparency,
              child: InkWell(
                onTap: item.isReadable ? () => onOpen(item) : null,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: LoopTouch.minimum,
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  decoration: BoxDecoration(
                    border: last
                        ? null
                        : Border(
                            bottom: BorderSide(
                              color: LoopColors.chalk.withValues(alpha: 0.1),
                            ),
                          ),
                  ),
                  child: Row(
                    children: <Widget>[
                      // `.row-ico` with `#i-drag`: the handle has a container
                      // in the prototype, so it reads as something to grab.
                      ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: LoopGround.fillOf(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const LoopIcon(
                            'drag',
                            size: 18,
                            color: LoopColors.text2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
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
                      if (!item.isReadable) ...<Widget>[
                        const LoopBadge('不可读'),
                        const SizedBox(width: 8),
                      ],
                      // `.badge.badge-down`: a word, not a bin glyph. This
                      // stages a removal in the draft; nothing leaves the
                      // server until 保存.
                      Semantics(
                        button: true,
                        enabled: !busy,
                        label: '移除 ${item.displayName}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            key: ValueKey<String>(
                              'watchlist-remove-${item.assetId}',
                            ),
                            onTap: busy ? null : () => onRemove(index),
                            borderRadius: BorderRadius.circular(9),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: ExcludeSemantics(
                                child: LoopBadge(
                                  '删除',
                                  kind: LoopBadgeKind.down,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Names every change a reload would discard, and offers to keep them.
class _ConflictDiff extends StatelessWidget {
  const _ConflictDiff({
    required this.changes,
    required this.onCopyDraft,
    required this.onReload,
  });

  final List<String> changes;
  final VoidCallback onCopyDraft;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return LoopSurfaceCard(
      key: const ValueKey<String>('watchlist-conflict-diff'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('重新加载会丢弃', style: LoopMono.label),
          const SizedBox(height: 6),
          if (changes.isEmpty)
            Text(
              '这份草稿与已提交的版本没有差异。',
              key: const ValueKey<String>('watchlist-conflict-no-diff'),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (final change in changes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '· $change',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          const SizedBox(height: 12),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('watchlist-conflict-copy-draft'),
                label: '复制当前草稿',
                onPressed: onCopyDraft,
              ),
              LoopButton(
                key: const ValueKey<String>('watchlist-conflict-reload'),
                label: '重新加载',
                primary: true,
                onPressed: onReload,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
