import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/chat/friends/friend_controllers.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/v2/loop_message_selection.dart'
    show LoopSelectionCheck;
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';

class CreateFriendGroupPage extends ConsumerStatefulWidget {
  const CreateFriendGroupPage({super.key});

  @override
  ConsumerState<CreateFriendGroupPage> createState() =>
      _CreateFriendGroupPageState();
}

class _CreateFriendGroupPageState extends ConsumerState<CreateFriendGroupPage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    ref.listenManual<FriendGateway>(friendGatewayProvider, (previous, next) {
      if (previous != null && !identical(previous, next)) {
        _replaceNameText('');
      }
    });
    ref.listenManual<FriendGroupState>(friendGroupControllerProvider, (
      previous,
      next,
    ) {
      if (previous == null || previous.name != next.name) {
        _replaceNameText(next.name);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _replaceNameText(String value) {
    if (_nameController.text == value) return;
    _nameController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(friendDirectoryControllerProvider);
    final directoryController = ref.read(
      friendDirectoryControllerProvider.notifier,
    );
    final group = ref.watch(friendGroupControllerProvider);
    final groupController = ref.read(friendGroupControllerProvider.notifier);
    if (directory.phase == FriendDirectoryPhase.initial) {
      scheduleMicrotask(() {
        if (mounted) unawaited(directoryController.load());
      });
    }

    final preview = group.mode == FriendGatewayMode.preview;
    final receipt = group.receipt;
    final editing =
        group.phase != FriendGroupPhase.unavailable && receipt == null;
    // Decision 0168: the create flow is a focus page — a quiet folio, the
    // name field, one labelled group of pickable rows and one block button
    // at the foot. No English eyebrow; a preview build keeps its 开发预览
    // mark, which is the one label that must stay visible.
    return LoopFocusPage(
      key: const ValueKey<String>('friend-group-create-screen'),
      archetype: LoopPageArchetype.action,
      title: '创建群组',
      kicker: preview ? '开发预览' : null,
      onBack: _friendPageBack(context),
      keyboardAccessory: true,
      folio: const LoopFolioPrimary(
        key: ValueKey<String>('friend-group-folio'),
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.action,
        kicker: '好友建群',
        heading: '创建群组',
        caption: '从已接受的好友里选人。群由 LOOP 后端创建，成功后才会出现在聊天里。',
        stamp: '仅好友',
      ),
      block: group.phase == FriendGroupPhase.unavailable
          ? const LoopEmptyState(
              key: ValueKey<String>('friend-group-unavailable'),
              illustration: LoopIllustration.friends,
              title: '创建群聊还没有开放',
              message: '这里不会创建任何群或添加成员。',
            )
          : null,
      body: <Widget>[
        if (preview) const _FriendPreviewNotice(),
        if (receipt != null)
          _CreatedFriendGroupResult(
            mode: group.mode,
            receipt: receipt,
            onOpen: receipt.streamCid == null
                ? null
                : () => context.push(
                    '/chat/channel/${Uri.encodeComponent(receipt.streamCid!)}',
                  ),
            onSetAlias:
                receipt.groupId == null ||
                    !ref.watch(loopFeatureSwitchesProvider).groupAliasVisible
                ? null
                : () => context.push('/chat/groups/${receipt.groupId}/alias'),
            onReset: () {
              groupController.reset();
              _nameController.clear();
              setState(() {});
            },
          )
        else ...<Widget>[
          const SizedBox(height: LoopSpacing.group),
          LoopFlatField(
            key: const ValueKey<String>('friend-group-name-field'),
            label: '群组名称',
            footnote: '最多 60 个字符',
            child: TextField(
              key: const ValueKey<String>('friend-group-name-input'),
              controller: _nameController,
              enabled: group.canEdit,
              maxLength: 60,
              textInputAction: TextInputAction.next,
              style: LoopType.bodyLg,
              decoration: loopFormFieldDecoration(
                hint: '群组名称',
                counterText: '',
              ),
              onChanged: groupController.editName,
            ),
          ),
          LoopLabel(
            '选择好友 · ${group.selectedFriendRefs.length}/$groupMaximumSelectedFriends',
            key: const ValueKey<String>('friend-group-selection-label'),
          ),
          ..._friendSelection(
            directory,
            directoryController,
            group,
            groupController,
          ),
        ],
      ],
      primaryAction: editing
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('friend-group-create-submit'),
                  label: group.phase == FriendGroupPhase.creating
                      ? '创建中…'
                      : '创建群组',
                  primary: true,
                  block: true,
                  onPressed: group.canCreate
                      ? () => unawaited(groupController.create())
                      : null,
                ),
                const SizedBox(height: LoopSpacing.tight),
                Text(
                  '至少选择 $groupMinimumSelectedFriends 位好友',
                  textAlign: TextAlign.center,
                  style: LoopType.captionSm,
                ),
              ],
            )
          : null,
    );
  }

  List<Widget> _friendSelection(
    FriendDirectoryState directory,
    FriendDirectoryController directoryController,
    FriendGroupState group,
    FriendGroupController groupController,
  ) {
    if (directory.phase == FriendDirectoryPhase.loading &&
        directory.friends.isEmpty) {
      return const <Widget>[
        LoopSkeleton(
          key: ValueKey<String>('friend-group-friends-loading'),
          type: LoopSkeletonType.list,
          rows: 3,
        ),
      ];
    }
    if (directory.phase == FriendDirectoryPhase.failure &&
        directory.friends.isEmpty) {
      return <Widget>[
        LoopEmptyState(
          key: const ValueKey<String>('friend-group-friends-failure'),
          illustration: LoopIllustration.friends,
          title: '好友列表暂时无法加载',
          message: _friendFailureMessage(directory.failureKind),
          compact: true,
          action: LoopButton(
            key: const ValueKey<String>('friend-group-friends-retry'),
            label: '重试',
            icon: 'refresh',
            onPressed: directory.isBusy
                ? null
                : () => unawaited(directoryController.reload()),
          ),
        ),
      ];
    }
    if (directory.friends.isEmpty) {
      return <Widget>[
        LoopEmptyState(
          key: const ValueKey<String>('friend-group-friends-empty'),
          illustration: LoopIllustration.friends,
          title: '没有可选择的好友',
          message: '好友请求被对方接受后，才能邀请对方创建群组。',
          compact: true,
          action: LoopButton(
            key: const ValueKey<String>('friend-group-find-friends'),
            label: '添加好友',
            icon: 'users',
            onPressed: () => context.push('/search'),
          ),
        ),
      ];
    }

    final content = <Widget>[
      LoopRecordGroup(
        key: const ValueKey<String>('friend-group-selection'),
        rows: <LoopRecordRow>[
          for (var index = 0; index < directory.friends.length; index++)
            _selectableFriendRow(
              rowKey: 'friend-select-result-$index',
              identity: directory.friends[index],
              selected: group.selectedFriendRefs.contains(
                directory.friends[index].profileRef,
              ),
              onChanged: group.canEdit
                  ? () => groupController.toggleFriend(
                      directory.friends[index].profileRef,
                    )
                  : null,
            ),
        ],
      ),
    ];
    if (group.phase == FriendGroupPhase.failure) {
      final unresolved =
          group.failureKind == FriendGatewayFailureKind.outcomeUnknown ||
          group.failureKind == FriendGatewayFailureKind.operatorRequired;
      final recovery = group.canReconcile
          ? LoopButton(
              key: const ValueKey<String>('friend-group-reconcile'),
              label: '查询结果',
              icon: 'search',
              block: true,
              onPressed: () => unawaited(groupController.reconcile()),
            )
          : group.canResumeEditing
          ? LoopButton(
              key: const ValueKey<String>('friend-group-resume-editing'),
              label: '修改草稿',
              block: true,
              onPressed: groupController.resumeEditing,
            )
          : null;
      content.insertAll(0, <Widget>[
        LoopNotice(
          key: const ValueKey<String>('friend-group-create-failure'),
          icon: 'warn',
          tone: LoopNoticeTone.danger,
          title: group.failureKind == FriendGatewayFailureKind.operatorRequired
              ? '群组创建需人工核对'
              : group.failureKind == FriendGatewayFailureKind.outcomeUnknown
              ? '群组创建结果待确认'
              : '群组未创建',
          body: unresolved
              ? '${_friendFailureMessage(group.failureKind)} 当前草稿已冻结，不会自动重复提交。'
              : _friendFailureMessage(group.failureKind),
        ),
        if (recovery != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              0,
              LoopSpacing.page,
              LoopSpacing.card,
            ),
            child: recovery,
          ),
      ]);
    }
    return content;
  }
}

/// One friend to pick (decision 0168): a `.row` in the labelled group — the
/// initials at 36, the alias over the LOOP code, and the shared round
/// [LoopSelectionCheck] in the value column.
LoopRecordRow _selectableFriendRow({
  required String rowKey,
  required FriendIdentity identity,
  required bool selected,
  required VoidCallback? onChanged,
}) => LoopRecordRow(
  key: ValueKey<String>(rowKey),
  leading: LoopInitialsAvatar(label: identity.alias, size: 36),
  title: identity.alias,
  subtitle: 'LOOP #${identity.profileCode}',
  trailingBadge: LoopSelectionCheck(selected: selected),
  chevron: false,
  onTap: onChanged,
  semanticLabel: '${identity.alias}，${selected ? '已选择' : '未选择'}',
);

/// The topbar's back control while there is a page under this one, as the
/// retired `LoopPage` shell drew it.
VoidCallback? _friendPageBack(BuildContext context) {
  final navigator = Navigator.of(context);
  return navigator.canPop() ? () => unawaited(navigator.maybePop()) : null;
}

/// The 开发预览 statement on the create flow: a notice, not a card.
class _FriendPreviewNotice extends StatelessWidget {
  const _FriendPreviewNotice();

  @override
  Widget build(BuildContext context) => const LoopNotice(
    key: ValueKey<String>('friend-preview-banner'),
    icon: 'info',
    title: '开发预览 · 仅本次运行',
    body: '好友、请求与新群组只保存在内存中，不会写入 LOOP 后端或 Stream。',
    margin: EdgeInsets.fromLTRB(LoopSpacing.page, 14, LoopSpacing.page, 0),
  );
}

/// The create flow's result (decision 0168): one notice that states what was
/// created and where it lives, and the next steps under it.
class _CreatedFriendGroupResult extends StatelessWidget {
  const _CreatedFriendGroupResult({
    required this.mode,
    required this.receipt,
    required this.onReset,
    required this.onOpen,
    required this.onSetAlias,
  });

  final FriendGatewayMode mode;
  final CreatedFriendGroup receipt;
  final VoidCallback onReset;
  final VoidCallback? onOpen;
  final VoidCallback? onSetAlias;

  @override
  Widget build(BuildContext context) {
    final preview = mode == FriendGatewayMode.preview;
    return Column(
      key: ValueKey<String>(
        preview ? 'friend-group-created-preview' : 'friend-group-created',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('结果'),
        LoopNotice(
          icon: 'check',
          title: preview ? '开发预览群组已创建' : '群组已创建',
          body: preview
              ? '${receipt.name} · ${receipt.friendRefs.length + 1} 位成员。这个结果仅存在于本次运行，未创建 Stream 频道。'
              : '${receipt.name} · ${receipt.friendRefs.length + 1} 位成员。频道已由 LOOP 后端创建并授权。',
        ),
        if (preview)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
            child: LoopButton(
              key: const ValueKey<String>('friend-group-create-another'),
              label: '再建一个',
              icon: 'plus',
              block: true,
              onPressed: onReset,
            ),
          )
        else
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('friend-group-set-alias'),
                label: '设置群昵称',
                icon: 'id',
                block: true,
                onPressed: onSetAlias,
              ),
              LoopButton(
                key: const ValueKey<String>('friend-group-open-channel'),
                label: '进入群聊',
                icon: 'chat',
                primary: true,
                block: true,
                onPressed: onOpen,
              ),
            ],
          ),
      ],
    );
  }
}

String _friendFailureMessage(FriendGatewayFailureKind? kind) => switch (kind) {
  FriendGatewayFailureKind.unavailable => '好友服务当前不可用，没有关系或群组被修改。',
  FriendGatewayFailureKind.invalidData => '输入或服务返回的数据不符合当前安全约束。',
  FriendGatewayFailureKind.notFound => '目标当前不可用。不可发现和不存在的账号不会被区分。',
  FriendGatewayFailureKind.permissionDenied => '当前账号无权完成该操作，没有关系或群组被修改。',
  FriendGatewayFailureKind.conflict => '好友关系已经变化，请刷新后再试。',
  FriendGatewayFailureKind.rateLimited => '操作过于频繁，请稍后再试。',
  FriendGatewayFailureKind.profileRequired => '请先在 Profile 中设置 LOOP 主昵称。',
  FriendGatewayFailureKind.incomingRequestPending => '对方已经向你发送申请，请在好友申请中处理。',
  FriendGatewayFailureKind.outgoingRequestPending => '好友申请已经发送，正在等待对方处理。',
  FriendGatewayFailureKind.alreadyFriends => '你们已经是好友。',
  FriendGatewayFailureKind.cooldown => '该好友申请处于冷却期，请稍后再试。',
  FriendGatewayFailureKind.alreadyDecided => '这条好友申请已经处理，请刷新列表。',
  FriendGatewayFailureKind.cursorInvalid => '列表分页已过期，需要从第一页重新加载。',
  FriendGatewayFailureKind.operatorRequired => '频道需要后台人工核对；不会自动创建第二个频道。',
  FriendGatewayFailureKind.outcomeUnknown => '请求可能已被接收，当前无法安全确认最终结果。',
  FriendGatewayFailureKind.unexpected => '服务暂时无法完成请求；没有好友关系或群组被修改。',
  null => '操作暂时无法完成。',
};
