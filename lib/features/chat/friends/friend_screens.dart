import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/chat/friends/friend_controllers.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

class FriendListPage extends ConsumerStatefulWidget {
  const FriendListPage({super.key});

  @override
  ConsumerState<FriendListPage> createState() => _FriendListPageState();
}

class _FriendListPageState extends ConsumerState<FriendListPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendDirectoryControllerProvider);
    final controller = ref.read(friendDirectoryControllerProvider.notifier);
    final direct = ref.watch(friendDirectControllerProvider);
    final directController = ref.read(friendDirectControllerProvider.notifier);
    ref.listen<FriendDirectState>(friendDirectControllerProvider, (
      previous,
      next,
    ) {
      final receipt = next.receipt;
      if (receipt == null || previous?.receipt == receipt) return;
      directController.consumeReceipt();
      context.push('/chat/channel/${Uri.encodeComponent(receipt.streamCid)}');
    });
    if (state.phase == FriendDirectoryPhase.initial) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    return LoopPage(
      eyebrow: state.mode == FriendGatewayMode.preview
          ? '开发预览 · PEOPLE'
          : 'PEOPLE',
      title: '我的好友',
      subtitle: '好友关系属于 LOOP 账号，与钱包地址和每个群组内的独立化名分离。',
      actions: <Widget>[
        if (state.mode == FriendGatewayMode.production)
          IconButton(
            key: const ValueKey<String>('friends-open-requests'),
            tooltip: '好友申请',
            onPressed: () => context.push('/chat/friends/requests'),
            icon: const Icon(Icons.mark_email_unread_outlined),
          ),
        if (state.mode != FriendGatewayMode.unavailable)
          IconButton(
            key: const ValueKey<String>('friends-refresh'),
            tooltip: '刷新好友',
            onPressed: state.isBusy
                ? null
                : () => unawaited(controller.reload()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        IconButton(
          key: const ValueKey<String>('friends-open-add'),
          tooltip: '添加好友',
          onPressed: () => context.push('/chat/friends/add'),
          icon: const Icon(Icons.person_add_alt_1_outlined),
        ),
      ],
      children: <Widget>[
        if (state.mode == FriendGatewayMode.preview) ...<Widget>[
          const _FriendPreviewBanner(),
          const SizedBox(height: 14),
        ],
        ..._directoryContent(state, controller, direct, directController),
      ],
    );
  }

  List<Widget> _directoryContent(
    FriendDirectoryState state,
    FriendDirectoryController controller,
    FriendDirectState direct,
    FriendDirectController directController,
  ) {
    if (state.phase == FriendDirectoryPhase.unavailable) {
      return const <Widget>[
        LoopStateCard(
          key: ValueKey<String>('friends-service-unavailable'),
          title: '好友服务尚未接入',
          message: '后端好友目录与关系接口完成前，这里不会展示演示好友，也不会发起网络请求。',
          icon: Icons.people_outline_rounded,
          tone: LoopTone.warning,
        ),
      ];
    }
    if (state.phase == FriendDirectoryPhase.loading && state.friends.isEmpty) {
      return const <Widget>[_FriendLoadingCard()];
    }

    final content = <Widget>[];
    if (direct.phase == FriendDirectPhase.failure) {
      content.addAll(<Widget>[
        LoopStateCard(
          key: const ValueKey<String>('friend-direct-failure'),
          title: direct.failureKind == FriendGatewayFailureKind.outcomeUnknown
              ? '私聊频道结果待确认'
              : '暂时无法打开私聊',
          message: _friendFailureMessage(direct.failureKind),
          icon: Icons.forum_outlined,
          tone: LoopTone.danger,
          action: direct.canReconcile
              ? OutlinedButton.icon(
                  key: const ValueKey<String>('friend-direct-reconcile'),
                  onPressed: () => unawaited(directController.reconcile()),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('查询结果'),
                )
              : null,
        ),
        const SizedBox(height: 14),
      ]);
    }
    if (state.phase == FriendDirectoryPhase.failure) {
      content.addAll(<Widget>[
        LoopStateCard(
          key: const ValueKey<String>('friends-load-failure'),
          title: '好友列表暂时无法加载',
          message: _friendFailureMessage(state.failureKind),
          icon: Icons.sync_problem_rounded,
          tone: LoopTone.danger,
          action: OutlinedButton.icon(
            key: const ValueKey<String>('friends-retry-load'),
            onPressed: state.isBusy
                ? null
                : () => unawaited(controller.reload()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ),
        const SizedBox(height: 14),
      ]);
    }
    if (state.friends.isEmpty) {
      content.add(
        LoopStateCard(
          key: const ValueKey<String>('friends-empty'),
          title: '还没有好友',
          message: '通过 LOOP 主昵称找到对方并发送好友请求。对方接受后才会出现在这里。',
          icon: Icons.person_search_outlined,
          action: FilledButton.icon(
            onPressed: () => context.push('/chat/friends/add'),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('添加好友'),
          ),
        ),
      );
      return content;
    }

    content.addAll(<Widget>[
      LoopSectionLabel(
        'FRIENDS',
        trailing: LoopStatusPill(
          label: '${state.friends.length}',
          tone: LoopTone.conversation,
        ),
      ),
      LoopCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            for (
              var index = 0;
              index < state.friends.length;
              index++
            ) ...<Widget>[
              _FriendIdentityRow(
                identity: state.friends[index],
                chatEnabled: state.mode == FriendGatewayMode.production,
                chatBusy:
                    direct.isBusy &&
                    direct.targetProfileRef == state.friends[index].profileRef,
                onChat: () => unawaited(
                  directController.open(state.friends[index].profileRef),
                ),
              ),
              if (index != state.friends.length - 1)
                const Divider(height: 1, indent: 72),
            ],
          ],
        ),
      ),
      if (state.nextCursor != null) ...<Widget>[
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton.icon(
            key: const ValueKey<String>('friends-load-more'),
            onPressed: state.isBusy
                ? null
                : () => unawaited(controller.loadMore()),
            icon: state.isBusy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: const Text('加载更多'),
          ),
        ),
      ],
    ]);
    return content;
  }
}

class AddFriendPage extends ConsumerStatefulWidget {
  const AddFriendPage({super.key});

  @override
  ConsumerState<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends ConsumerState<AddFriendPage> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    ref.listenManual<FriendGateway>(friendGatewayProvider, (previous, next) {
      if (previous != null && !identical(previous, next)) {
        _replaceQueryText('');
      }
    });
    ref.listenManual<FriendSearchState>(friendSearchControllerProvider, (
      previous,
      next,
    ) {
      if (previous == null || previous.query != next.query) {
        _replaceQueryText(next.query);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendSearchControllerProvider);
    final controller = ref.read(friendSearchControllerProvider.notifier);
    return LoopPage(
      eyebrow: state.mode == FriendGatewayMode.preview
          ? '开发预览 · DISCOVERY'
          : 'DISCOVERY',
      title: '添加好友',
      subtitle: '仅搜索允许被发现的 LOOP 主昵称；群内昵称和钱包地址不会参与搜索。',
      actions: <Widget>[
        if (state.mode == FriendGatewayMode.production)
          IconButton(
            key: const ValueKey<String>('friend-search-open-requests'),
            tooltip: '好友申请',
            onPressed: state.isBusy
                ? null
                : () => context.push('/chat/friends/requests'),
            icon: const Icon(Icons.mark_email_unread_outlined),
          ),
      ],
      children: <Widget>[
        if (state.mode == FriendGatewayMode.preview) ...<Widget>[
          const _FriendPreviewBanner(),
          const SizedBox(height: 14),
        ],
        if (state.phase == FriendSearchPhase.unavailable)
          const LoopStateCard(
            key: ValueKey<String>('friend-search-unavailable'),
            title: '用户搜索尚未接入',
            message: '后端发现与好友请求接口完成前，生产环境不会搜索用户或创建本地假关系。',
            icon: Icons.person_search_outlined,
            tone: LoopTone.warning,
          )
        else ...<Widget>[
          TextField(
            key: const ValueKey<String>('friend-alias-search-input'),
            controller: _queryController,
            enabled: !state.isBusy,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: 'LOOP 主昵称',
              hintText: '例如 onchain.mia',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              suffixIcon: _queryController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空',
                      onPressed: state.isBusy ? null : _clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: state.isBusy ? null : (_) => _search(controller),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey<String>('friend-alias-search-submit'),
              onPressed:
                  state.isBusy || _queryController.text.trim().runes.length < 2
                  ? null
                  : () => _search(controller),
              icon: state.phase == FriendSearchPhase.searching
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                state.phase == FriendSearchPhase.searching ? '搜索中…' : '搜索',
              ),
            ),
          ),
          const SizedBox(height: 18),
          ..._searchContent(state, controller),
        ],
      ],
    );
  }

  void _search(FriendSearchController controller) {
    FocusScope.of(context).unfocus();
    unawaited(controller.search(_queryController.text));
  }

  void _clear() {
    _queryController.clear();
    ref.read(friendSearchControllerProvider.notifier).clear();
    setState(() {});
  }

  void _replaceQueryText(String value) {
    if (_queryController.text == value) return;
    _queryController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  List<Widget> _searchContent(
    FriendSearchState state,
    FriendSearchController controller,
  ) {
    if (state.phase == FriendSearchPhase.idle) {
      return const <Widget>[
        LoopStateCard(
          key: ValueKey<String>('friend-search-idle'),
          title: '按昵称查找',
          message: '昵称可能重名。这里只显示后端允许当前账号发现的资料，不展示钱包或 Stream 身份。',
          icon: Icons.manage_search_rounded,
        ),
      ];
    }
    if (state.phase == FriendSearchPhase.searching) {
      return const <Widget>[_FriendLoadingCard(label: '正在查找可发现的用户…')];
    }
    if (state.phase == FriendSearchPhase.failure) {
      final requestOutcomeUnknown =
          state.requestingProfileRef != null &&
          state.failureKind == FriendGatewayFailureKind.outcomeUnknown;
      return <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('friend-search-failure'),
          title: state.requestingProfileRef == null
              ? '无法完成搜索'
              : requestOutcomeUnknown
              ? '好友请求结果待确认'
              : '好友请求未发送',
          message: _friendFailureMessage(state.failureKind),
          icon: Icons.sync_problem_rounded,
          tone: LoopTone.danger,
          action: state.requestingProfileRef == null && state.query.isNotEmpty
              ? OutlinedButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => unawaited(controller.search(state.query)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试搜索'),
                )
              : requestOutcomeUnknown
              ? OutlinedButton.icon(
                  key: const ValueKey<String>('friend-request-reconcile'),
                  onPressed: state.isBusy
                      ? null
                      : () => unawaited(
                          controller.reconcileRequest(
                            state.requestingProfileRef!,
                          ),
                        ),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('查询结果'),
                )
              : null,
        ),
        if (state.results.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          ..._resultList(state, controller),
        ],
      ];
    }
    if (state.results.isEmpty) {
      return const <Widget>[
        LoopStateCard(
          key: ValueKey<String>('friend-search-empty'),
          title: '没有找到可添加的用户',
          message: '请检查昵称。不可发现和不存在的账号不会在客户端被区分。',
          icon: Icons.person_off_outlined,
        ),
      ];
    }
    return _resultList(state, controller);
  }

  List<Widget> _resultList(
    FriendSearchState state,
    FriendSearchController controller,
  ) {
    return <Widget>[
      if (state.truncated) ...<Widget>[
        const LoopStateCard(
          key: ValueKey<String>('friend-search-truncated'),
          title: '结果较多',
          message: '当前只显示前 20 条结果，请输入更完整的昵称缩小范围。',
          icon: Icons.filter_alt_outlined,
          tone: LoopTone.warning,
        ),
        const SizedBox(height: 14),
      ],
      LoopSectionLabel(
        'RESULTS',
        trailing: LoopStatusPill(
          label: '${state.results.length}',
          tone: LoopTone.conversation,
        ),
      ),
      LoopCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            for (
              var index = 0;
              index < state.results.length;
              index++
            ) ...<Widget>[
              _FriendSearchResultRow(
                rowKey: 'friend-add-result-$index',
                result: state.results[index],
                requesting:
                    state.phase == FriendSearchPhase.requesting &&
                    state.requestingProfileRef ==
                        state.results[index].identity.profileRef,
                outcomeUnknown: state.outcomeUnknownProfileRefs.contains(
                  state.results[index].identity.profileRef,
                ),
                enabled: !state.isBusy,
                onAdd: () => unawaited(
                  controller.sendRequest(
                    state.results[index].identity.profileRef,
                  ),
                ),
                onReconcile: () => unawaited(
                  controller.reconcileRequest(
                    state.results[index].identity.profileRef,
                  ),
                ),
                onReviewIncoming: () => context.push('/chat/friends/requests'),
              ),
              if (index != state.results.length - 1)
                const Divider(height: 1, indent: 72),
            ],
          ],
        ),
      ),
    ];
  }
}

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

    return LoopPage(
      eyebrow: group.mode == FriendGatewayMode.preview
          ? '开发预览 · NEW GROUP'
          : 'NEW GROUP',
      title: '创建群组',
      subtitle: '从已接受的好友中选择成员。LOOP 不会把钱包地址或群内昵称当作成员身份。',
      children: <Widget>[
        if (group.mode == FriendGatewayMode.preview) ...<Widget>[
          const _FriendPreviewBanner(),
          const SizedBox(height: 14),
        ],
        if (group.phase == FriendGroupPhase.unavailable)
          const LoopStateCard(
            key: ValueKey<String>('friend-group-unavailable'),
            title: '建群服务尚未接入',
            message: '后端完成好友校验与 Stream 建群契约前，生产环境不会创建频道或写入成员。',
            icon: Icons.group_add_outlined,
            tone: LoopTone.warning,
          )
        else if (group.receipt != null)
          _CreatedFriendGroupCard(
            mode: group.mode,
            receipt: group.receipt!,
            onOpen: group.receipt!.streamCid == null
                ? null
                : () => context.push(
                    '/chat/channel/${Uri.encodeComponent(group.receipt!.streamCid!)}',
                  ),
            onSetAlias: group.receipt!.groupId == null
                ? null
                : () => context.push(
                    '/chat/groups/${group.receipt!.groupId}/alias',
                  ),
            onReset: () {
              groupController.reset();
              _nameController.clear();
              setState(() {});
            },
          )
        else ...<Widget>[
          TextField(
            key: const ValueKey<String>('friend-group-name-input'),
            controller: _nameController,
            enabled: group.canEdit,
            maxLength: 60,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '群组名称',
              hintText: '例如 Spot Research',
              prefixIcon: Icon(Icons.forum_outlined),
            ),
            onChanged: groupController.editName,
          ),
          LoopSectionLabel(
            '选择好友',
            trailing: LoopStatusPill(
              label:
                  '${group.selectedFriendRefs.length}/$groupMaximumSelectedFriends',
              tone: LoopTone.conversation,
            ),
          ),
          ..._friendSelection(
            directory,
            directoryController,
            group,
            groupController,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey<String>('friend-group-create-submit'),
              onPressed: group.canCreate
                  ? () => unawaited(groupController.create())
                  : null,
              icon: group.phase == FriendGroupPhase.creating
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.group_add_outlined),
              label: Text(
                group.phase == FriendGroupPhase.creating ? '创建中…' : '创建群组',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '至少选择 $groupMinimumSelectedFriends 位好友；当前用户会由后端加入群组。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
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
      return const <Widget>[_FriendLoadingCard(label: '正在加载好友…')];
    }
    if (directory.phase == FriendDirectoryPhase.failure &&
        directory.friends.isEmpty) {
      return <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('friend-group-friends-failure'),
          title: '好友列表暂时无法加载',
          message: _friendFailureMessage(directory.failureKind),
          icon: Icons.sync_problem_rounded,
          tone: LoopTone.danger,
          action: OutlinedButton.icon(
            onPressed: directory.isBusy
                ? null
                : () => unawaited(directoryController.reload()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ),
      ];
    }
    if (directory.friends.isEmpty) {
      return <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('friend-group-friends-empty'),
          title: '没有可选择的好友',
          message: '好友请求被对方接受后，才能邀请对方创建群组。',
          icon: Icons.group_off_outlined,
          action: OutlinedButton.icon(
            onPressed: () => context.push('/chat/friends/add'),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('添加好友'),
          ),
        ),
      ];
    }

    final content = <Widget>[
      LoopCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            for (
              var index = 0;
              index < directory.friends.length;
              index++
            ) ...<Widget>[
              _SelectableFriendRow(
                rowKey: 'friend-select-result-$index',
                identity: directory.friends[index],
                selected: group.selectedFriendRefs.contains(
                  directory.friends[index].profileRef,
                ),
                enabled: group.canEdit,
                onChanged: () => groupController.toggleFriend(
                  directory.friends[index].profileRef,
                ),
              ),
              if (index != directory.friends.length - 1)
                const Divider(height: 1, indent: 72),
            ],
          ],
        ),
      ),
    ];
    if (group.phase == FriendGroupPhase.failure) {
      final unresolved =
          group.failureKind == FriendGatewayFailureKind.outcomeUnknown ||
          group.failureKind == FriendGatewayFailureKind.operatorRequired;
      content.insertAll(0, <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('friend-group-create-failure'),
          title: group.failureKind == FriendGatewayFailureKind.operatorRequired
              ? '群组创建需人工核对'
              : group.failureKind == FriendGatewayFailureKind.outcomeUnknown
              ? '群组创建结果待确认'
              : '群组未创建',
          message: unresolved
              ? '${_friendFailureMessage(group.failureKind)} 当前草稿已冻结，不会自动重复提交。'
              : _friendFailureMessage(group.failureKind),
          icon: Icons.sync_problem_rounded,
          tone: LoopTone.danger,
          action: group.canReconcile
              ? OutlinedButton.icon(
                  key: const ValueKey<String>('friend-group-reconcile'),
                  onPressed: () => unawaited(groupController.reconcile()),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('查询结果'),
                )
              : group.canResumeEditing
              ? OutlinedButton.icon(
                  key: const ValueKey<String>('friend-group-resume-editing'),
                  onPressed: groupController.resumeEditing,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('修改草稿'),
                )
              : null,
        ),
        const SizedBox(height: 14),
      ]);
    }
    return content;
  }
}

class _FriendPreviewBanner extends StatelessWidget {
  const _FriendPreviewBanner();

  @override
  Widget build(BuildContext context) {
    return const LoopStateCard(
      key: ValueKey<String>('friend-preview-banner'),
      title: '开发预览 · 仅本次运行',
      message: '好友、请求与新群组只保存在内存中，不会写入 LOOP 后端或 Stream。',
      icon: Icons.science_outlined,
      tone: LoopTone.conversation,
    );
  }
}

class _FriendIdentityRow extends StatelessWidget {
  const _FriendIdentityRow({
    required this.identity,
    required this.chatEnabled,
    required this.chatBusy,
    required this.onChat,
  });

  final FriendIdentity identity;
  final bool chatEnabled;
  final bool chatBusy;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${identity.alias}，LOOP 好友',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            ChatAvatar(
              label: identity.alias,
              colorSeed: identity.colorSeed,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    identity.alias,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    identity.accountAlias == null
                        ? '未设置主昵称 · ${identity.profileCode}'
                        : 'LOOP #${identity.profileCode}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (chatEnabled)
              IconButton(
                tooltip: '发起私聊',
                onPressed: chatBusy ? null : onChat,
                icon: chatBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.forum_outlined),
              )
            else
              const LoopStatusPill(label: '好友', tone: LoopTone.conversation),
          ],
        ),
      ),
    );
  }
}

class _FriendSearchResultRow extends StatelessWidget {
  const _FriendSearchResultRow({
    required this.rowKey,
    required this.result,
    required this.requesting,
    required this.outcomeUnknown,
    required this.enabled,
    required this.onAdd,
    required this.onReconcile,
    required this.onReviewIncoming,
  });

  final String rowKey;
  final FriendSearchResult result;
  final bool requesting;
  final bool outcomeUnknown;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onReconcile;
  final VoidCallback onReviewIncoming;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          ChatAvatar(
            label: result.identity.alias,
            colorSeed: result.identity.colorSeed,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  result.identity.alias,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  'LOOP #${result.identity.profileCode}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (outcomeUnknown)
            OutlinedButton(
              key: ValueKey<String>('$rowKey-reconcile'),
              onPressed: enabled ? onReconcile : null,
              child: const Text('查询结果'),
            )
          else
            switch (result.relationship) {
              FriendRelationship.none => OutlinedButton(
                key: ValueKey<String>(rowKey),
                onPressed: requesting || !enabled ? null : onAdd,
                child: requesting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('添加'),
              ),
              FriendRelationship.requestPending => const LoopStatusPill(
                label: '已发送',
                tone: LoopTone.warning,
              ),
              FriendRelationship.outgoingPending => const LoopStatusPill(
                label: '已发送',
                tone: LoopTone.warning,
              ),
              FriendRelationship.incomingPending => OutlinedButton(
                key: ValueKey<String>('$rowKey-review-incoming'),
                onPressed: enabled ? onReviewIncoming : null,
                child: const Text('处理申请'),
              ),
              FriendRelationship.friend => const LoopStatusPill(
                label: '已是好友',
                tone: LoopTone.conversation,
              ),
            },
        ],
      ),
    );
  }
}

class _SelectableFriendRow extends StatelessWidget {
  const _SelectableFriendRow({
    required this.rowKey,
    required this.identity,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String rowKey;
  final FriendIdentity identity;
  final bool selected;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: selected,
      enabled: enabled,
      label: '${identity.alias}，${selected ? '已选择' : '未选择'}',
      child: InkWell(
        key: ValueKey<String>(rowKey),
        onTap: enabled ? onChanged : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => onChanged() : null,
              ),
              const SizedBox(width: 4),
              ChatAvatar(
                label: identity.alias,
                colorSeed: identity.colorSeed,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      identity.alias,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'LOOP #${identity.profileCode}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatedFriendGroupCard extends StatelessWidget {
  const _CreatedFriendGroupCard({
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
    return LoopStateCard(
      key: ValueKey<String>(
        preview ? 'friend-group-created-preview' : 'friend-group-created',
      ),
      title: preview ? '开发预览群组已创建' : '群组已创建',
      message: preview
          ? '${receipt.name} · ${receipt.friendRefs.length + 1} 位成员。这个结果仅存在于本次运行，未创建 Stream 频道。'
          : '${receipt.name} · ${receipt.friendRefs.length + 1} 位成员。频道已由 LOOP 后端创建并授权。',
      icon: Icons.groups_rounded,
      tone: LoopTone.conversation,
      action: preview
          ? OutlinedButton.icon(
              key: const ValueKey<String>('friend-group-create-another'),
              onPressed: onReset,
              icon: const Icon(Icons.add_rounded),
              label: const Text('再建一个'),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('friend-group-set-alias'),
                  onPressed: onSetAlias,
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('设置群昵称'),
                ),
                FilledButton.icon(
                  key: const ValueKey<String>('friend-group-open-channel'),
                  onPressed: onOpen,
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('进入群聊'),
                ),
              ],
            ),
    );
  }
}

class _FriendLoadingCard extends StatelessWidget {
  const _FriendLoadingCard({this.label = '正在加载好友…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      child: Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
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
