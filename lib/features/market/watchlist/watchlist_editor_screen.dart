import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_controller.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

/// Providerless Watchlist editor.
///
/// The production gateway remains unavailable until the authenticated adapter
/// is implemented. Preview saves are in-memory and are never market facts.
class WatchlistEditorScreen extends ConsumerStatefulWidget {
  const WatchlistEditorScreen({super.key});

  @override
  ConsumerState<WatchlistEditorScreen> createState() =>
      _WatchlistEditorScreenState();
}

class _WatchlistEditorScreenState extends ConsumerState<WatchlistEditorScreen> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(ref.read(watchlistControllerProvider.notifier).load());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchlistControllerProvider);
    final controller = ref.read(watchlistControllerProvider.notifier);
    final hasSnapshot = state.snapshot != null;

    return LoopPage(
      eyebrow: 'C7 · Personal list',
      title: 'Watchlist',
      subtitle: 'Organize owner-local asset references. A saved asset key is not price, freshness, or proof that a market is tradable.',
      actions: <Widget>[
        IconButton(
          key: const ValueKey<String>('watchlist-add-asset'),
          onPressed: state.canEdit && state.draftGroups.isNotEmpty
              ? () => _addAsset(context, controller, state)
              : null,
          tooltip: state.draftGroups.isEmpty
              ? 'Create a group before adding an asset'
              : 'Add asset reference',
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      bottom: hasSnapshot
          ? LoopActionDock(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey<String>('watchlist-discard'),
                      onPressed: state.isDirty && !state.isBusy
                          ? controller.discard
                          : null,
                      child: Text(
                        state.requiresReload
                            ? 'Discard local draft'
                            : 'Discard',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey<String>('watchlist-save'),
                      onPressed: state.canSave
                          ? () => unawaited(controller.save())
                          : null,
                      icon: state.phase == WatchlistPhase.saving
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        state.phase == WatchlistPhase.saving
                            ? 'Saving…'
                            : 'Save changes',
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
      children: <Widget>[
        _WatchlistModeBanner(mode: state.mode),
        const SizedBox(height: 16),
        ..._stateContent(context, state, controller),
      ],
    );
  }

  List<Widget> _stateContent(
    BuildContext context,
    WatchlistState state,
    WatchlistController controller,
  ) {
    if (state.snapshot == null) {
      return switch (state.phase) {
        WatchlistPhase.initial ||
        WatchlistPhase.loading => <Widget>[const _WatchlistLoadingCard()],
        WatchlistPhase.unavailable => <Widget>[
          LoopStateCard(
            title: state.mode == WatchlistMode.unavailable
                ? 'Watchlist is not connected'
                : 'Watchlist is temporarily unavailable',
            message: state.mode == WatchlistMode.unavailable
                ? 'The production account adapter is intentionally unavailable. No private request was sent and no demo list is being shown.'
                : 'The configured source did not return a snapshot. No supplied data was accepted.',
            icon: Icons.link_off_rounded,
            tone: LoopTone.warning,
          ),
        ],
        _ => <Widget>[
          LoopStateCard(
            title: 'Watchlist could not be loaded',
            message: _failureMessage(state.failureKind),
            icon: Icons.sync_problem_rounded,
            tone: LoopTone.danger,
            action: OutlinedButton.icon(
              key: const ValueKey<String>('watchlist-retry-load'),
              onPressed: state.isBusy
                  ? null
                  : () => unawaited(controller.reload()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ],
      };
    }

    final widgets = <Widget>[_WatchlistSummary(state: state)];
    if (state.phase == WatchlistPhase.conflict) {
      widgets.addAll(<Widget>[
        const SizedBox(height: 14),
        LoopStateCard(
          key: const ValueKey<String>('watchlist-conflict'),
          title: 'Version conflict — nothing was overwritten',
          message: 'This draft is based on an older account version. Reload the latest snapshot before editing or saving again; reload discards this local draft.',
          icon: Icons.call_split_rounded,
          tone: LoopTone.warning,
          action: FilledButton.icon(
            key: const ValueKey<String>('watchlist-conflict-reload'),
            onPressed: state.isBusy
                ? null
                : () => unawaited(controller.reload()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reload latest'),
          ),
        ),
      ]);
    } else if (state.phase == WatchlistPhase.failure ||
        state.phase == WatchlistPhase.unavailable) {
      widgets.addAll(<Widget>[
        const SizedBox(height: 14),
        LoopStateCard(
          title: 'Changes were not saved',
          message: _failureMessage(state.failureKind),
          icon: Icons.cloud_off_rounded,
          tone: LoopTone.danger,
          action: OutlinedButton.icon(
            key: const ValueKey<String>('watchlist-retry-save'),
            onPressed: state.canSave
                ? () => unawaited(controller.save())
                : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry save'),
          ),
        ),
      ]);
    }

    if (state.draftGroups.isEmpty) {
      widgets.addAll(<Widget>[
        const SizedBox(height: 18),
        LoopStateCard(
          title: 'Your Watchlist is empty',
          message: 'Create a group, then add canonical asset references such as BTC or ETH.',
          icon: Icons.bookmark_border_rounded,
          action: FilledButton.icon(
            key: const ValueKey<String>('watchlist-create-first-group'),
            onPressed: state.canEdit
                ? () => _addGroup(context, controller)
                : null,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Create group'),
          ),
        ),
      ]);
    } else {
      for (var index = 0; index < state.draftGroups.length; index++) {
        final group = state.draftGroups[index];
        widgets.addAll(<Widget>[
          LoopSectionLabel(
            group.name,
            trailing: Text(
              group.key,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          _WatchlistGroupCard(
            group: group,
            groupIndex: index,
            groupCount: state.draftGroups.length,
            enabled: state.canEdit,
            onRename: () => _renameGroup(context, controller, group),
            onRemoveGroup: () => _removeGroup(context, controller, group),
            onMoveGroup: (toIndex) => _runEdit(
              context,
              () => controller.reorderGroup(fromIndex: index, toIndex: toIndex),
            ),
            onAddItem: () => _addAsset(
              context,
              controller,
              state,
              initialGroupKey: group.key,
            ),
            onRemoveItem: (assetKey) => _runEdit(
              context,
              () => controller.removeItem(
                groupKey: group.key,
                assetKey: assetKey,
              ),
            ),
            onMoveItem: (fromIndex, toIndex) => _runEdit(
              context,
              () => controller.reorderItem(
                groupKey: group.key,
                fromIndex: fromIndex,
                toIndex: toIndex,
              ),
            ),
          ),
        ]);
      }
    }

    widgets.addAll(<Widget>[
      const LoopSectionLabel('List controls'),
      Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey<String>('watchlist-new-group'),
              onPressed: state.canEdit
                  ? () => _addGroup(context, controller)
                  : null,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('New group'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import later'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const LoopStateCard(
        title: 'Asset references only',
        message: 'This list never supplies price, change, liquidity, risk, alert state, or trading authorization.',
        icon: Icons.shield_outlined,
      ),
    ]);
    return widgets;
  }

  Future<void> _addGroup(
    BuildContext context,
    WatchlistController controller,
  ) async {
    final result = await showDialog<_GroupInput>(
      context: context,
      builder: (context) => const _GroupDialog(),
    );
    if (!context.mounted || result == null) return;
    _runEdit(
      context,
      () => controller.addGroup(
        WatchlistGroup(
          key: result.key,
          name: result.name,
          items: const <WatchlistItem>[],
        ),
      ),
    );
  }

  Future<void> _renameGroup(
    BuildContext context,
    WatchlistController controller,
    WatchlistGroup group,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameGroupDialog(initialName: group.name),
    );
    if (!context.mounted || name == null) return;
    _runEdit(
      context,
      () => controller.editGroup(groupKey: group.key, name: name),
    );
  }

  Future<void> _removeGroup(
    BuildContext context,
    WatchlistController controller,
    WatchlistGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove group?'),
        content: Text(
          'Remove ${group.name} and its ${group.items.length} local asset reference(s)? The change is not saved yet.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    _runEdit(context, () => controller.removeGroup(group.key));
  }

  Future<void> _addAsset(
    BuildContext context,
    WatchlistController controller,
    WatchlistState state, {
    String? initialGroupKey,
  }) async {
    if (state.draftGroups.isEmpty) return;
    final result = await showDialog<_AssetInput>(
      context: context,
      builder: (context) => _AssetDialog(
        groups: state.draftGroups,
        initialGroupKey: initialGroupKey ?? state.draftGroups.first.key,
      ),
    );
    if (!context.mounted || result == null) return;
    _runEdit(
      context,
      () => controller.addItem(
        groupKey: result.groupKey,
        item: WatchlistItem(assetKey: result.assetKey),
      ),
    );
  }

  void _runEdit(BuildContext context, VoidCallback edit) {
    try {
      edit();
    } on InvalidWatchlistContractException {
      _showValidationMessage(context);
    } on StateError {
      _showValidationMessage(context);
    }
  }

  void _showValidationMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'That change is invalid, duplicated, or exceeds the Watchlist limit.',
        ),
      ),
    );
  }
}

class _WatchlistModeBanner extends StatelessWidget {
  const _WatchlistModeBanner({required this.mode});

  final WatchlistMode mode;

  @override
  Widget build(BuildContext context) {
    return LoopStateCard(
      title: switch (mode) {
        WatchlistMode.preview => '开发预览 · in-memory Watchlist',
        WatchlistMode.production => 'Account Watchlist',
        WatchlistMode.unavailable => 'Production connection unavailable',
      },
      message: switch (mode) {
        WatchlistMode.preview => 'Edits persist only for this running Preview and do not update an account, market, or alert.',
        WatchlistMode.production => 'Owner-local references are synchronized through the authenticated LOOP boundary.',
        WatchlistMode.unavailable => 'The app is fail-closed until the authenticated Watchlist adapter is connected.',
      },
      icon: mode == WatchlistMode.preview
          ? Icons.science_outlined
          : Icons.bookmarks_outlined,
      tone: mode == WatchlistMode.preview ? LoopTone.warning : LoopTone.neutral,
    );
  }
}

class _WatchlistLoadingCard extends StatelessWidget {
  const _WatchlistLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const LoopCard(
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('Loading Watchlist snapshot…')),
        ],
      ),
    );
  }
}

class _WatchlistSummary extends StatelessWidget {
  const _WatchlistSummary({required this.state});

  final WatchlistState state;

  @override
  Widget build(BuildContext context) {
    final itemCount = state.draftGroups.fold<int>(
      0,
      (total, group) => total + group.items.length,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        LoopStatusPill(
          label: '${state.draftGroups.length} GROUPS · $itemCount ASSETS',
          tone: LoopTone.market,
        ),
        LoopStatusPill(
          label: 'VERSION ${state.snapshot!.version}',
          icon: Icons.layers_outlined,
        ),
        LoopStatusPill(
          label: state.isDirty ? 'UNSAVED DRAFT' : 'NO LOCAL CHANGES',
          tone: state.isDirty ? LoopTone.warning : LoopTone.positive,
          icon: state.isDirty ? Icons.edit_outlined : Icons.check_rounded,
        ),
      ],
    );
  }
}

class _WatchlistGroupCard extends StatelessWidget {
  const _WatchlistGroupCard({
    required this.group,
    required this.groupIndex,
    required this.groupCount,
    required this.enabled,
    required this.onRename,
    required this.onRemoveGroup,
    required this.onMoveGroup,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onMoveItem,
  });

  final WatchlistGroup group;
  final int groupIndex;
  final int groupCount;
  final bool enabled;
  final VoidCallback onRename;
  final VoidCallback onRemoveGroup;
  final ValueChanged<int> onMoveGroup;
  final VoidCallback onAddItem;
  final ValueChanged<String> onRemoveItem;
  final void Function(int fromIndex, int toIndex) onMoveItem;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${group.items.length} asset reference(s)',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              IconButton(
                onPressed: enabled && groupIndex > 0
                    ? () => onMoveGroup(groupIndex - 1)
                    : null,
                tooltip: 'Move group up',
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                onPressed: enabled && groupIndex < groupCount - 1
                    ? () => onMoveGroup(groupIndex + 1)
                    : null,
                tooltip: 'Move group down',
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                onPressed: enabled ? onRename : null,
                tooltip: 'Rename group',
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                onPressed: enabled ? onRemoveGroup : null,
                tooltip: 'Remove group',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
          if (group.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No asset references in this group.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (
              var index = 0;
              index < group.items.length;
              index++
            ) ...<Widget>[
              if (index == 0) const Divider(height: 18),
              _WatchlistItemRow(
                item: group.items[index],
                index: index,
                count: group.items.length,
                enabled: enabled,
                onMove: (toIndex) => onMoveItem(index, toIndex),
                onRemove: () => onRemoveItem(group.items[index].assetKey),
              ),
              if (index != group.items.length - 1) const Divider(height: 1),
            ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              key: ValueKey<String>('watchlist-add-${group.key}'),
              onPressed: enabled ? onAddItem : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add asset reference'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchlistItemRow extends StatelessWidget {
  const _WatchlistItemRow({
    required this.item,
    required this.index,
    required this.count,
    required this.enabled,
    required this.onMove,
    required this.onRemove,
  });

  final WatchlistItem item;
  final int index;
  final int count;
  final bool enabled;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final mark = item.assetKey.split(':').last;
    return Row(
      key: ValueKey<String>('watchlist-item-${item.assetKey}'),
      children: <Widget>[
        Text(
          (index + 1).toString().padLeft(2, '0'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(width: 9),
        LoopAssetMark(symbol: mark, size: 36),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.assetKey,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'Owner-local reference · no market facts',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: enabled && index > 0 ? () => onMove(index - 1) : null,
          tooltip: 'Move ${item.assetKey} up',
          icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
        ),
        IconButton(
          onPressed: enabled && index < count - 1
              ? () => onMove(index + 1)
              : null,
          tooltip: 'Move ${item.assetKey} down',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ),
        IconButton(
          key: ValueKey<String>('watchlist-remove-${item.assetKey}'),
          onPressed: enabled ? onRemove : null,
          tooltip: 'Remove ${item.assetKey}',
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
        ),
      ],
    );
  }
}

final class _GroupInput {
  const _GroupInput({required this.key, required this.name});

  final String key;
  final String name;
}

class _GroupDialog extends StatefulWidget {
  const _GroupDialog();

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  final _keyController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Watchlist group'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('watchlist-group-key-input'),
            controller: _keyController,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'Group key',
              helperText: 'Lowercase letters, numbers, _ or -',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('watchlist-group-name-input'),
            controller: _nameController,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('watchlist-confirm-group'),
          onPressed: () => Navigator.of(context).pop(
            _GroupInput(key: _keyController.text, name: _nameController.text),
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _RenameGroupDialog extends StatefulWidget {
  const _RenameGroupDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameGroupDialog> createState() => _RenameGroupDialogState();
}

class _RenameGroupDialogState extends State<_RenameGroupDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename group'),
      content: TextField(
        key: const ValueKey<String>('watchlist-group-name-input'),
        controller: _controller,
        maxLength: 40,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Display name'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

final class _AssetInput {
  const _AssetInput({required this.groupKey, required this.assetKey});

  final String groupKey;
  final String assetKey;
}

class _AssetDialog extends StatefulWidget {
  const _AssetDialog({required this.groups, required this.initialGroupKey});

  final List<WatchlistGroup> groups;
  final String initialGroupKey;

  @override
  State<_AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends State<_AssetDialog> {
  final _assetController = TextEditingController();
  late String _groupKey;

  @override
  void initState() {
    super.initState();
    _groupKey = widget.initialGroupKey;
  }

  @override
  void dispose() {
    _assetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add asset reference'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _groupKey,
            decoration: const InputDecoration(labelText: 'Group'),
            items: widget.groups
                .map(
                  (group) => DropdownMenuItem<String>(
                    value: group.key,
                    child: Text(group.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _groupKey = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('watchlist-asset-key-input'),
            controller: _assetController,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Asset key',
              helperText: 'Uppercase key, for example BTC or HL:ETH',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('watchlist-confirm-asset'),
          onPressed: () => Navigator.of(context).pop(
            _AssetInput(groupKey: _groupKey, assetKey: _assetController.text),
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

String _failureMessage(WatchlistGatewayFailureKind? kind) => switch (kind) {
  WatchlistGatewayFailureKind.invalidData => 'The Watchlist response did not match the reviewed contract. No supplied data was accepted.',
  WatchlistGatewayFailureKind.versionConflict =>
    'A newer account version exists. Reload before saving again.',
  WatchlistGatewayFailureKind.unavailable =>
    'The Watchlist service is unavailable. No change was presented as saved.',
  WatchlistGatewayFailureKind.unexpected ||
  null => 'The Watchlist operation failed. Provider details were not exposed.',
};
