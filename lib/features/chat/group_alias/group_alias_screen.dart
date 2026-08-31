import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_controller.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

/// Validates an untrusted route parameter before it can enter the group-Alias
/// feature boundary.
class GroupAliasRoutePage extends StatelessWidget {
  const GroupAliasRoutePage({super.key, required this.routeGroupId});

  final String routeGroupId;

  @override
  Widget build(BuildContext context) {
    try {
      return GroupAliasPage(groupId: GroupId.fromWire(routeGroupId));
    } on InvalidGroupAliasContractException {
      return const LoopPage(
        eyebrow: 'GROUP IDENTITY',
        title: '群组引用无效',
        children: <Widget>[
          LoopStateCard(
            title: '无法打开群内昵称',
            message: '这个页面没有收到有效的 LOOP group_id；没有发起网络请求。',
            icon: Icons.link_off_rounded,
            tone: LoopTone.warning,
          ),
        ],
      );
    }
  }
}

/// Resolves a Stream group to its LOOP `group_id` after the Chat-owned route
/// has proved the exact CID and current membership. Known direct channels and
/// malformed CIDs still fail closed before touching the backend.
///
/// Application routing must mount this page only through
/// `StreamGroupAliasChannelRoutePage`; keeping the provider query here lets the
/// group-Alias feature remain independent of Stream SDK types.
class GroupAliasChannelRoutePage extends StatelessWidget {
  const GroupAliasChannelRoutePage({super.key, required this.routeCid});

  final String routeCid;

  @override
  Widget build(BuildContext context) {
    try {
      return _GroupAliasResolverPage(
        channelId: GroupAliasStreamChannelId.fromCid(routeCid),
      );
    } on InvalidGroupAliasContractException {
      return const LoopPage(
        eyebrow: 'GROUP IDENTITY',
        title: '群聊引用无效',
        children: <Widget>[
          LoopStateCard(
            key: ValueKey<String>('group-alias-channel-invalid'),
            title: '无法打开群内昵称',
            message: '这个页面没有收到可解析的 Stream 群聊引用；没有发起网络请求。',
            icon: Icons.link_off_rounded,
            tone: LoopTone.warning,
          ),
        ],
      );
    }
  }
}

class _GroupAliasResolverPage extends ConsumerStatefulWidget {
  const _GroupAliasResolverPage({required this.channelId});

  final GroupAliasStreamChannelId channelId;

  @override
  ConsumerState<_GroupAliasResolverPage> createState() =>
      _GroupAliasResolverPageState();
}

class _GroupAliasResolverPageState
    extends ConsumerState<_GroupAliasResolverPage> {
  @override
  Widget build(BuildContext context) {
    final provider = groupAliasResolverControllerProvider(widget.channelId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (state.phase == GroupAliasResolverPhase.initial) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.resolve());
      });
    }

    final groupId = state.groupId;
    if (state.phase == GroupAliasResolverPhase.resolved && groupId != null) {
      return GroupAliasPage(groupId: groupId);
    }

    final title = switch (state.phase) {
      GroupAliasResolverPhase.initial ||
      GroupAliasResolverPhase.resolving => '正在确认群组',
      GroupAliasResolverPhase.notFound => '群组不可用',
      GroupAliasResolverPhase.unavailable => '群组服务暂不可用',
      GroupAliasResolverPhase.failure ||
      GroupAliasResolverPhase.resolved => '无法解析群组',
    };
    final message = switch (state.phase) {
      GroupAliasResolverPhase.initial ||
      GroupAliasResolverPhase.resolving => 'LOOP 正在确认当前账号仍是这个 Stream 群聊的成员。',
      GroupAliasResolverPhase.notFound => '这个频道不是可见群组，或当前账号已不是成员；没有开放群昵称操作。',
      GroupAliasResolverPhase.unavailable => '暂时无法确认群组成员关系；没有开放群昵称操作。',
      GroupAliasResolverPhase.failure ||
      GroupAliasResolverPhase.resolved => '服务响应不符合群组解析契约；没有开放群昵称操作。',
    };
    final isLoading =
        state.phase == GroupAliasResolverPhase.initial ||
        state.phase == GroupAliasResolverPhase.resolving;
    final canRetry =
        !isLoading && state.mode != GroupAliasGatewayMode.unavailable;

    return LoopPage(
      eyebrow: 'GROUP IDENTITY',
      title: '群内昵称',
      children: <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('group-alias-resolver-state'),
          title: title,
          message: message,
          icon: isLoading
              ? Icons.sync_rounded
              : Icons.admin_panel_settings_outlined,
          tone: state.phase == GroupAliasResolverPhase.notFound
              ? LoopTone.warning
              : LoopTone.neutral,
          action: canRetry
              ? OutlinedButton.icon(
                  key: const ValueKey<String>('group-alias-resolver-retry'),
                  onPressed: () => unawaited(controller.resolve()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试确认'),
                )
              : null,
        ),
      ],
    );
  }
}

class GroupAliasPage extends ConsumerStatefulWidget {
  const GroupAliasPage({super.key, required this.groupId});

  final GroupId groupId;

  @override
  ConsumerState<GroupAliasPage> createState() => _GroupAliasPageState();
}

class _GroupAliasPageState extends ConsumerState<GroupAliasPage> {
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _aliasController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = groupAliasControllerProvider(widget.groupId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (state.phase == GroupAliasPhase.initial) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }

    return LoopPage(
      eyebrow: state.mode == GroupAliasGatewayMode.preview
          ? '开发预览 · GROUP IDENTITY'
          : 'GROUP IDENTITY',
      title: '群内昵称',
      subtitle: '每个群可以使用不同昵称。首次保留后永久不可修改；前端不做跨群身份关联，但这不构成强匿名保证。',
      children: <Widget>[
        _GroupAliasBoundaryBanner(mode: state.mode),
        const SizedBox(height: 16),
        ..._aliasContent(state, controller),
        if (state.mode != GroupAliasGatewayMode.unavailable) ...<Widget>[
          const SizedBox(height: 24),
          _GroupAliasSearch(groupId: widget.groupId),
        ],
      ],
    );
  }

  List<Widget> _aliasContent(
    GroupAliasState state,
    GroupAliasController controller,
  ) {
    if (state.phase == GroupAliasPhase.initial ||
        state.phase == GroupAliasPhase.loading) {
      return const <Widget>[
        LoopCard(
          child: Row(
            children: <Widget>[
              SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 14),
              Expanded(child: Text('正在读取本人群内昵称…')),
            ],
          ),
        ),
      ];
    }

    if (state.phase == GroupAliasPhase.unavailable) {
      return const <Widget>[
        LoopStateCard(
          key: ValueKey<String>('group-alias-unavailable'),
          title: '群内昵称服务不可用',
          message: '没有展示演示昵称，也没有把账号昵称或钱包地址当作群内身份。',
          icon: Icons.link_off_rounded,
          tone: LoopTone.warning,
        ),
      ];
    }

    final resource = state.resource;
    if (resource != null) {
      return <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('group-alias-reserved'),
          title: resource.alias,
          message: resource.requiresProjectionRetry
              ? '昵称已由 LOOP 永久保留，Stream 成员投影仍待确认。只能用完全相同的值重试。'
              : '这个昵称已在当前群永久保留，不能修改。它不会暴露公开 Profile 或 Stream 用户身份。',
          icon: resource.requiresProjectionRetry
              ? Icons.sync_problem_rounded
              : Icons.lock_outline_rounded,
          tone: resource.requiresProjectionRetry
              ? LoopTone.warning
              : LoopTone.positive,
          action: resource.requiresProjectionRetry
              ? OutlinedButton.icon(
                  key: const ValueKey<String>('group-alias-retry-projection'),
                  onPressed: state.isBusy
                      ? null
                      : () =>
                            unawaited(controller.reserveAlias(resource.alias)),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('重试投影'),
                )
              : null,
        ),
      ];
    }

    if (state.phase == GroupAliasPhase.outcomeUnknown) {
      return <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('group-alias-outcome-unknown'),
          title: '保留结果待确认',
          message: '“${state.pendingAlias}”可能已经永久保留。为避免锁定另一个值，当前只允许重试完全相同的昵称。',
          icon: Icons.manage_search_rounded,
          tone: LoopTone.warning,
          action: FilledButton.icon(
            key: const ValueKey<String>('group-alias-retry-pending'),
            onPressed: state.isBusy
                ? null
                : () => unawaited(controller.retryPendingAlias()),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('用相同昵称重试'),
          ),
        ),
      ];
    }

    final content = <Widget>[];
    if (state.phase == GroupAliasPhase.failure) {
      content.addAll(<Widget>[
        LoopStateCard(
          key: const ValueKey<String>('group-alias-failure'),
          title: '群内昵称未保留',
          message: _groupAliasFailureMessage(state.failureKind),
          icon: Icons.sync_problem_rounded,
          tone: LoopTone.danger,
          action: state.canReserveNewAlias
              ? null
              : OutlinedButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => unawaited(controller.reload()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新读取'),
                ),
        ),
        const SizedBox(height: 14),
      ]);
    }

    if (state.canReserveNewAlias) {
      content.add(
        LoopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('group-alias-input'),
                controller: _aliasController,
                enabled: !state.isBusy,
                maxLength: groupAliasMaximumCodePoints,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '当前群昵称',
                  hintText: '1–40 个字符',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                onSubmitted: (_) => _reserve(controller),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey<String>('group-alias-submit'),
                onPressed: state.isBusy ? null : () => _reserve(controller),
                icon: state.phase == GroupAliasPhase.setting
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline_rounded),
                label: Text(state.isBusy ? '保留中…' : '永久保留这个昵称'),
              ),
              const SizedBox(height: 10),
              Text(
                '提交后不可改名；同一群内昵称必须唯一。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    } else if (content.isEmpty) {
      content.add(
        LoopStateCard(
          title: '无法设置群内昵称',
          message: _groupAliasFailureMessage(state.failureKind),
          icon: Icons.lock_outline_rounded,
          tone: LoopTone.warning,
        ),
      );
    }
    return content;
  }

  void _reserve(GroupAliasController controller) {
    FocusScope.of(context).unfocus();
    unawaited(controller.reserveAlias(_aliasController.text));
  }
}

class _GroupAliasSearch extends ConsumerStatefulWidget {
  const _GroupAliasSearch({required this.groupId});

  final GroupId groupId;

  @override
  ConsumerState<_GroupAliasSearch> createState() => _GroupAliasSearchState();
}

class _GroupAliasSearchState extends ConsumerState<_GroupAliasSearch> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = groupAliasSearchControllerProvider(widget.groupId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopSectionLabel('查找群成员昵称'),
        TextField(
          key: const ValueKey<String>('group-alias-search-input'),
          controller: _controller,
          enabled: !state.isBusy,
          maxLength: groupAliasMaximumCodePoints,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '至少输入 2 个字符',
            prefixIcon: const Icon(Icons.manage_search_rounded),
            suffixIcon: state.isBusy
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    key: const ValueKey<String>('group-alias-search-submit'),
                    tooltip: '查找群内昵称',
                    onPressed: () =>
                        unawaited(controller.search(_controller.text)),
                    icon: const Icon(Icons.search_rounded),
                  ),
          ),
          onSubmitted: (value) => unawaited(controller.search(value)),
        ),
        const SizedBox(height: 12),
        ...switch (state.phase) {
          GroupAliasSearchPhase.idle => const <Widget>[
            LoopStateCard(
              title: '仅在当前群内查找',
              message: '结果只包含群内昵称与不透明的群内引用，不包含公开资料、钱包地址或跨群身份。',
              icon: Icons.shield_outlined,
            ),
          ],
          GroupAliasSearchPhase.searching => const <Widget>[],
          GroupAliasSearchPhase.ready when state.page.items.isEmpty =>
            const <Widget>[
              LoopStateCard(
                title: '没有找到匹配昵称',
                message: '未确认投影、已离群和当前用户本人不会出现在结果中。',
                icon: Icons.person_search_outlined,
              ),
            ],
          GroupAliasSearchPhase.ready => <Widget>[
            if (state.page.truncated) ...<Widget>[
              const LoopStateCard(
                title: '结果已截断',
                message: '请继续输入更完整的昵称以缩小范围。',
                icon: Icons.filter_alt_outlined,
                tone: LoopTone.warning,
              ),
              const SizedBox(height: 12),
            ],
            LoopCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (var index = 0; index < state.page.items.length; index++)
                    ListTile(
                      key: ValueKey<String>('group-alias-result-$index'),
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(state.page.items[index].alias),
                      subtitle: const Text('当前群内昵称'),
                    ),
                ],
              ),
            ),
          ],
          GroupAliasSearchPhase.unavailable ||
          GroupAliasSearchPhase.failure => <Widget>[
            LoopStateCard(
              key: const ValueKey<String>('group-alias-search-failure'),
              title: '无法完成群内搜索',
              message: _groupAliasFailureMessage(state.failureKind),
              icon: Icons.sync_problem_rounded,
              tone: LoopTone.danger,
            ),
          ],
        },
      ],
    );
  }
}

class _GroupAliasBoundaryBanner extends StatelessWidget {
  const _GroupAliasBoundaryBanner({required this.mode});

  final GroupAliasGatewayMode mode;

  @override
  Widget build(BuildContext context) {
    return LoopStateCard(
      title: switch (mode) {
        GroupAliasGatewayMode.preview => '开发预览 · 仅本次运行',
        GroupAliasGatewayMode.production => 'LOOP 群组身份边界',
        GroupAliasGatewayMode.unavailable => '生产连接不可用',
      },
      message: '群昵称由 LOOP 后端保留；Stream 只接收服务端投影。客户端不会把它映射为公开 Profile、钱包或 Stream user ID。',
      icon: Icons.privacy_tip_outlined,
      tone: mode == GroupAliasGatewayMode.unavailable
          ? LoopTone.warning
          : LoopTone.conversation,
    );
  }
}

String _groupAliasFailureMessage(GroupAliasGatewayFailureKind? kind) =>
    switch (kind) {
      GroupAliasGatewayFailureKind.unavailable => '群昵称服务当前不可用，没有昵称被显示为已保留。',
      GroupAliasGatewayFailureKind.notFound =>
        '当前没有可见的群昵称；也可能已不再是这个 Stream 群的成员。',
      GroupAliasGatewayFailureKind.immutable => '这个账号已在当前群永久保留了另一个昵称，不能修改。',
      GroupAliasGatewayFailureKind.taken => '这个昵称已经被当前群的其他成员永久保留，请换一个。',
      GroupAliasGatewayFailureKind.invalidData => '昵称或服务响应不符合当前群昵称契约。',
      GroupAliasGatewayFailureKind.outcomeUnknown => '请求可能已经提交，只能用完全相同的昵称继续确认。',
      GroupAliasGatewayFailureKind.unexpected => '群昵称操作暂时失败，没有结果被显示为已确认。',
      null => '群昵称当前不可用。',
    };
