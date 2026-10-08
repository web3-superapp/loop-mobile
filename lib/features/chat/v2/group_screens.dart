import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/group_rename.dart';
import 'package:loop_mobile/features/chat/v2/loop_channel_message_policy.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The unavailable facts `group-info` renders instead of prototype samples.
const _memberDirectoryDeferred = LoopUnavailableFact(
  'GROUP_MEMBER_DIRECTORY_DEFERRED',
);
const _groupSettingsDeferred = LoopUnavailableFact('GROUP_SETTINGS_DEFERRED');

/// `group` · one small-group conversation.
///
/// The channel address always comes from the server (group creation, the
/// channel list, or a notification deep link). The page adds only the chrome:
/// Stream still owns history, delivery, read state and the composer.
class GroupChatScreen extends ConsumerWidget {
  const GroupChatScreen({
    required this.channelCid,
    super.key,
    this.onBack,
    this.onOpenInfo,
    this.onOpenSearch,
    this.onOpenForward,
  });

  final String? channelCid;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenInfo;

  /// Both take the channel CID, so search and forwarding start from the exact
  /// conversation the user is reading.
  final ValueChanged<String>? onOpenSearch;
  final ValueChanged<String>? onOpenForward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityChat),
    );
    final mode = ref.watch(chatV2GatewayProvider).mode;
    final cid = channelCid;
    final blocked = communityCapabilityBlocks(mode, capability);
    return Scaffold(
      key: const ValueKey<String>('group-screen'),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopTopbar(
              title: '群聊',
              kicker: communityPreviewKicker(mode),
              onBack: onBack,
              minHeight: 72,
              actions: <Widget>[
                if (cid != null) ...<Widget>[
                  LoopIconButton(
                    key: const ValueKey<String>('group-open-search'),
                    icon: 'search',
                    label: '搜索这个会话',
                    onPressed: () => onOpenSearch?.call(cid),
                  ),
                  LoopIconButton(
                    key: const ValueKey<String>('group-open-forward'),
                    icon: 'shuffle',
                    label: '转发消息',
                    onPressed: () => onOpenForward?.call(cid),
                  ),
                  LoopIconButton(
                    key: const ValueKey<String>('group-open-info'),
                    icon: 'info',
                    label: '群信息',
                    onPressed: () => onOpenInfo?.call(cid),
                  ),
                ],
              ],
            ),
            Expanded(
              child: switch ((blocked, cid)) {
                (true, _) => _Block(
                  blockKey: 'group-capability-unavailable',
                  message: '群聊当前不可用',
                  reason: capability.reasonCode == null
                      ? '尚未读取到能力清单，本页不请求任何频道。'
                      : communicationUnavailableReason(capability.reasonCode),
                ),
                (false, null) => const _Block(
                  blockKey: 'group-missing-cid',
                  message: '缺少群聊标识',
                  reason: '请从会话列表或群信息进入，本页不会猜测要打开哪个群。',
                ),
                (false, final String value) => LoopStreamChannelSurface(
                  key: ValueKey<String>('group-$value'),
                  cid: value,
                  keyPrefix: 'group-channel',
                  composerHint: loopChatComposerHint,
                  // S99c: only the group's creator pins (loop-api 0091).
                  mayPinMessagesFor: loopFriendGroupCreatorMayPin,
                  header: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      CommunityPreviewNotice(mode: mode, resource: '群聊'),
                      LoopChatHeaderFold(
                        collapsed: loopChatKeyboardIsUp(context),
                        child: const LoopNotice(
                          key: ValueKey<String>('group-scope-note'),
                          icon: 'info',
                          title: '普通群与社区的区别',
                          body:
                              '普通群没有社区币、没有 Mining Weight，也没有 Community AI。'
                              '带币社区在「社区」栏。',
                          margin: EdgeInsets.fromLTRB(16, 10, 16, 4),
                        ),
                      ),
                    ],
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// `group-info` · the group record and its one available action.
///
/// Member management (kick) has no reviewed source in this step and is
/// rendered unavailable; the creator may rename the group (decision 0113). Leaving goes through the LOOP backend, never Stream's
/// own `leave`, so the removal stays server-owned and idempotent.
class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({
    required this.channelCid,
    super.key,
    this.onBack,
    this.onLeft,
  });

  final String? channelCid;
  final VoidCallback? onBack;
  final VoidCallback? onLeft;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  GroupId? _groupId;
  bool _resolving = false;

  /// The group's name and the reader's standing, read from Stream. Null
  /// until read, and null for good when Stream could not say.
  GroupStreamFacts? _facts;
  bool _factsRead = false;

  /// The name the server confirmed in this visit. It is shown at once; the
  /// channel list catches up from Stream's own update event.
  String? _renamedTo;
  bool _renaming = false;

  /// Why the exit is closed. `null` means the resolve has not failed.
  ///
  /// The kind is kept rather than a boolean so an offline device, a group the
  /// server will not confirm, and a broken response each get their own block
  /// instead of one indistinguishable failure.
  GroupAliasGatewayFailureKind? _resolveFailure;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_resolveGroup);
    scheduleMicrotask(_readFacts);
  }

  Future<void> _readFacts() async {
    final cid = widget.channelCid;
    if (cid == null) return;
    final facts = await ref.read(groupStreamFactsReaderProvider)(cid);
    if (!mounted) return;
    setState(() {
      _facts = facts;
      _factsRead = true;
    });
  }

  Future<void> _rename() async {
    final groupId = _groupId;
    if (groupId == null || _renaming) return;
    final current = _renamedTo ?? _facts?.name ?? '';
    final name = await showGroupRenameSheet(context, current: current);
    if (name == null || !mounted || name == current) return;
    setState(() => _renaming = true);
    CommunityFailureKind? failure;
    GroupRenamed? renamed;
    try {
      renamed = await ref
          .read(groupProfileGatewayProvider)
          .rename(groupId.wireValue, name);
    } on CommunityGatewayException catch (error) {
      failure = error.kind;
    } catch (_) {
      failure = CommunityFailureKind.unexpected;
    }
    if (!mounted) return;
    setState(() {
      _renaming = false;
      if (renamed != null) _renamedTo = renamed.name;
    });
    if (renamed != null) {
      LoopToast.show(context, message: '群名称已改为「${renamed.name}」');
      return;
    }
    LoopToast.show(
      context,
      message: switch (failure!) {
        CommunityFailureKind.permissionDenied => '只有群主可以修改群名称；这次没有改动。',
        CommunityFailureKind.unavailable => '改名暂时不可用，群名称没有改动。',
        CommunityFailureKind.notFound => '群不存在或你已不在群里。',
        CommunityFailureKind.validationFailed => '群名称需要 1–40 个字符，且不能含控制字符。',
        final kind => communityFailureReason(kind),
      },
      kind: LoopToastKind.warn,
    );
  }

  Future<void> _resolveGroup() async {
    final cid = widget.channelCid;
    if (cid == null || _resolving) return;
    GroupAliasStreamChannelId channelId;
    try {
      channelId = GroupAliasStreamChannelId.fromCid(cid);
    } on InvalidGroupAliasContractException {
      if (mounted) {
        setState(
          () => _resolveFailure = GroupAliasGatewayFailureKind.invalidData,
        );
      }
      return;
    }
    setState(() {
      _resolving = true;
      _resolveFailure = null;
    });
    try {
      final groupId = await ref
          .read(groupAliasResolverGatewayProvider)
          .resolveGroup(channelId);
      if (!mounted) return;
      setState(() {
        _groupId = groupId;
        _resolving = false;
      });
    } on GroupAliasGatewayException catch (error) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _resolveFailure = error.kind;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _resolveFailure = GroupAliasGatewayFailureKind.unexpected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(chatV2GatewayProvider).mode;
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityChat),
    );
    final busy = ref.watch(groupMembershipControllerProvider);
    final blocked = communityCapabilityBlocks(mode, capability);
    final canLeave = !blocked && _groupId != null && !busy;

    return LoopDashboardPage(
      key: const ValueKey<String>('group-info-screen'),
      archetype: LoopPageArchetype.record,
      title: '群信息',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'GROUP RECORD',
        heading: '群信息',
        caption: '成员、通知与退出按风险从低到高排列。这里只显示已确认的信息。',
        stamp: 'PRIVATE',
      ),
      sections: <Widget>[
        CommunityPreviewNotice(mode: mode, resource: '群信息'),
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('group-info-capability-unavailable'),
            icon: 'warn',
            message: '群聊当前不可用',
            reason: capability.reasonCode == null
                ? '尚未读取到能力清单，本页不请求任何群资源。'
                : communicationUnavailableReason(capability.reasonCode),
          )
        else if (widget.channelCid == null)
          const LoopEmpty(
            key: ValueKey<String>('group-info-missing-cid'),
            icon: 'warn',
            message: '缺少群聊标识',
            reason: '请从群聊页进入，本页不会猜测要打开哪个群的信息。',
          )
        else ...<Widget>[
          const LoopLabel('成员'),
          const CommunityUnavailableCard(
            key: ValueKey<String>('group-info-members-unavailable'),
            label: '成员与成员管理',
            fact: _memberDirectoryDeferred,
          ),
          const LoopLabel('群资料'),
          _GroupNameRow(
            name: _renamedTo ?? _facts?.name,
            read: _factsRead,
            mayRename: _facts?.viewerIsCreator ?? false,
            busy: _renaming || _resolving || _groupId == null,
            onRename: () => unawaited(_rename()),
          ),
          const LoopLabel('设置'),
          const CommunityUnavailableCard(
            key: ValueKey<String>('group-info-settings-unavailable'),
            label: '消息通知与置顶会话',
            fact: _groupSettingsDeferred,
          ),
          const LoopLabel('退出'),
          if (_resolving)
            const LoopSkeleton(
              key: ValueKey<String>('group-info-state-loading'),
              type: LoopSkeletonType.list,
              rows: 1,
            )
          else if (_resolveFailure == GroupAliasGatewayFailureKind.offline)
            LoopOfflineState(
              key: const ValueKey<String>('group-info-state-offline'),
              onRetry: () => unawaited(_resolveGroup()),
              pausedActions: const <String>['退出群聊'],
            )
          else if (_resolveFailure == GroupAliasGatewayFailureKind.notFound)
            const LoopEmpty(
              key: ValueKey<String>('group-info-state-empty'),
              icon: 'info',
              message: '没有可退出的群成员关系',
              reason: '找不到这个群，或者你已经不是成员了。这不代表退出失败。',
            )
          else if (_resolveFailure == GroupAliasGatewayFailureKind.unavailable)
            const LoopEmpty(
              key: ValueKey<String>('group-info-state-unavailable'),
              icon: 'warn',
              message: '退出操作当前不可用',
              reason: '群成员关系服务暂时不可用，本页没有提交任何变更。',
            )
          else if (_resolveFailure != null)
            LoopErrorState(
              key: const ValueKey<String>('group-info-resolve-failed'),
              reason: '这个群的信息还没确认，暂时不能退出，也没有提交任何改动。',
              onRetry: () => unawaited(_resolveGroup()),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: LoopButton(
                key: const ValueKey<String>('group-info-leave'),
                label: '退出群聊',
                block: true,
                icon: 'warn',
                onPressed: canLeave ? () => unawaited(_leave()) : null,
              ),
            ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _leave() async {
    final groupId = _groupId;
    if (groupId == null) return;
    final confirmed = await confirmCommunityAction(
      context,
      title: '退出这个群聊？',
      body: '退出后你不会再收到这个群的消息。群创建者不能退出。',
      confirmLabel: '退出',
      sheetKey: 'group-leave-confirm-sheet',
    );
    if (!confirmed || !mounted) return;
    final failure = await ref
        .read(groupMembershipControllerProvider.notifier)
        .leave(groupId.wireValue);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: '已退出群聊');
      widget.onLeft?.call();
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.warn,
    );
  }
}

/// 群名称: the name, and — for the creator — the way to change it.
class _GroupNameRow extends StatelessWidget {
  const _GroupNameRow({
    required this.name,
    required this.read,
    required this.mayRename,
    required this.busy,
    required this.onRename,
  });

  final String? name;
  final bool read;
  final bool mayRename;
  final bool busy;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final shown = name == null || name!.trim().isEmpty ? null : name;
    return LoopRecordGroup(
      key: const ValueKey<String>('group-info-name-group'),
      rows: <LoopRecordRow>[
        LoopRecordRow(
          key: const ValueKey<String>('group-info-name'),
          title: '群名称',
          subtitle: !read ? '正在读取群名称' : shown ?? '群名称暂时读不到',
          trailingCaption: mayRename ? '修改' : '仅群主可改',
          onTap: mayRename && !busy ? onRename : null,
        ),
      ],
    );
  }
}

/// Asks for the group's new name. Returns the normalised name, or null when
/// the reader backed out. The field refuses what the server would refuse.
Future<String?> showGroupRenameSheet(
  BuildContext context, {
  required String current,
}) => showLoopSheet<String>(
  context,
  barrierLabel: '关闭群名称修改',
  builder: (sheetContext) => _GroupRenameForm(current: current),
);

class _GroupRenameForm extends StatefulWidget {
  const _GroupRenameForm({required this.current});

  final String current;

  @override
  State<_GroupRenameForm> createState() => _GroupRenameFormState();
}

class _GroupRenameFormState extends State<_GroupRenameForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.current,
  );
  bool _invalid = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = normalizedGroupName(_name.text);
    if (name == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey<String>('group-rename-sheet'),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '修改群名称',
          style: LoopTypography.heading(18, weight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('group-rename-field'),
          controller: _name,
          autofocus: true,
          onChanged: (_) {
            if (_invalid) setState(() => _invalid = false);
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: '群名称（1–$groupNameMaximumRunes 个字符）',
            errorText: _invalid ? '群名称需要 1–40 个字符，且不能含控制字符' : null,
          ),
        ),
        const SizedBox(height: 16),
        LoopButtonPair(
          padded: false,
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('group-rename-submit'),
              label: '保存',
              primary: true,
              onPressed: _submit,
            ),
            LoopButton(
              key: const ValueKey<String>('group-rename-cancel'),
              label: '取消',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block({
    required this.blockKey,
    required this.message,
    required this.reason,
  });

  final String blockKey;
  final String message;
  final String reason;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: LoopEmpty(
      key: ValueKey<String>(blockKey),
      icon: 'warn',
      message: message,
      reason: reason,
    ),
  );
}
