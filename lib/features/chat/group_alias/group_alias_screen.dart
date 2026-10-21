import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_controller.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart'
    show loopFormFieldDecoration;

/// The page title every group-Alias location carries.
const String _groupAliasTitle = '群内昵称';

/// The topbar's back control while there is a page under this one: the old
/// `LoopPage` shell drew it from the same fact, so a deep link that opens the
/// page first still has nothing to go back to.
VoidCallback? _groupAliasBack(BuildContext context) {
  final navigator = Navigator.of(context);
  return navigator.canPop() ? () => unawaited(navigator.maybePop()) : null;
}

/// A whole-page state on the group-Alias shell (decision 0168): the topbar
/// stays so the reader can leave, and one centred state says why there is
/// nothing to do here.
class _GroupAliasBlockedPage extends StatelessWidget {
  const _GroupAliasBlockedPage({required this.state});

  final Widget state;

  @override
  Widget build(BuildContext context) => LoopDashboardPage(
    archetype: LoopPageArchetype.state,
    title: _groupAliasTitle,
    onBack: _groupAliasBack(context),
    sections: const <Widget>[],
    block: state,
  );
}

/// Validates an untrusted route parameter before it can enter the group-Alias
/// feature boundary.
class GroupAliasRoutePage extends StatelessWidget {
  const GroupAliasRoutePage({super.key, required this.routeGroupId});

  final String routeGroupId;

  @override
  Widget build(BuildContext context) {
    if (!loopFeatureSwitchesOf(context).groupAliasVisible) {
      return const GroupAliasPausedPage();
    }
    try {
      return GroupAliasPage(groupId: GroupId.fromWire(routeGroupId));
    } on InvalidGroupAliasContractException {
      return const _GroupAliasBlockedPage(
        state: LoopEmptyState(
          key: ValueKey<String>('group-alias-route-invalid'),
          illustration: LoopIllustration.members,
          title: '群组引用无效',
          message: '这个页面没有收到有效的 LOOP group_id；没有发起网络请求。',
        ),
      );
    }
  }
}

/// What a group-Alias location shows while the feature is hidden
/// (`LoopFeatureSwitches.groupAliasVisible = false`, decision 0112): the
/// page stays mounted, asks nothing, and says members appear under their own
/// names.
class GroupAliasPausedPage extends StatelessWidget {
  const GroupAliasPausedPage({super.key});

  @override
  Widget build(BuildContext context) => const _GroupAliasBlockedPage(
    state: LoopEmptyState(
      key: ValueKey<String>('group-alias-paused'),
      illustration: LoopIllustration.members,
      title: '群内昵称暂未开放',
      message: '群成员以自己的头像和用户名显示。这里没有发起任何请求。',
    ),
  );
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
      return const _GroupAliasBlockedPage(
        state: LoopEmptyState(
          key: ValueKey<String>('group-alias-channel-invalid'),
          illustration: LoopIllustration.members,
          title: '群聊引用无效',
          message: '这个页面没有收到可解析的 Stream 群聊引用；没有发起网络请求。',
        ),
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
      GroupAliasResolverPhase.resolved => '这个群的信息暂时读不到，群昵称暂时不能修改。',
    };
    final isLoading =
        state.phase == GroupAliasResolverPhase.initial ||
        state.phase == GroupAliasResolverPhase.resolving;
    final canRetry =
        !isLoading && state.mode != GroupAliasGatewayMode.unavailable;

    return _GroupAliasBlockedPage(
      state: LoopEmptyState(
        key: const ValueKey<String>('group-alias-resolver-state'),
        illustration: LoopIllustration.members,
        title: title,
        message: message,
        action: canRetry
            ? LoopButton(
                key: const ValueKey<String>('group-alias-resolver-retry'),
                label: '重试确认',
                icon: 'refresh',
                primary: true,
                onPressed: () => unawaited(controller.resolve()),
              )
            : null,
      ),
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

  @override
  void dispose() {
    _aliasController.dispose();
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

    final preview = state.mode == GroupAliasGatewayMode.preview;
    return LoopDashboardPage(
      key: const ValueKey<String>('group-alias-screen'),
      archetype: LoopPageArchetype.record,
      title: _groupAliasTitle,
      kicker: preview ? '开发预览' : null,
      onBack: _groupAliasBack(context),
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('group-alias-folio'),
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: '群昵称',
        heading: _groupAliasTitle,
        caption: '每个群可以使用不同昵称。首次保留后永久不可修改；前端不做跨群身份关联，但这不构成强匿名保证。',
        stamp: switch (state.mode) {
          GroupAliasGatewayMode.preview => '开发预览',
          GroupAliasGatewayMode.production => '仅本群',
          GroupAliasGatewayMode.unavailable => '未连接',
        },
      ),
      sections: <Widget>[
        _GroupAliasBoundaryNotice(mode: state.mode),
        const LoopLabel('我的群昵称'),
        ..._aliasContent(state, controller),
        if (state.mode != GroupAliasGatewayMode.unavailable) ...<Widget>[
          const LoopLabel('查找群成员昵称'),
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
        LoopSkeleton(
          key: ValueKey<String>('group-alias-loading'),
          type: LoopSkeletonType.list,
          rows: 1,
        ),
      ];
    }

    if (state.phase == GroupAliasPhase.unavailable) {
      return const <Widget>[
        LoopEmptyState(
          key: ValueKey<String>('group-alias-unavailable'),
          illustration: LoopIllustration.members,
          title: '群内昵称服务不可用',
          message: '没有展示演示昵称，也没有把账号昵称或钱包地址当作群内身份。',
          compact: true,
        ),
      ];
    }

    final resource = state.resource;
    if (resource != null) {
      final syncing = resource.requiresProjectionRetry;
      return <Widget>[
        KeyedSubtree(
          key: const ValueKey<String>('group-alias-reserved'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopRecordGroup(
                rows: <LoopRecordRow>[
                  LoopRecordRow(
                    leading: LoopInitialsAvatar(label: resource.alias),
                    title: resource.alias,
                    subtitle: syncing ? '已保留 · 群里的显示同步中' : '当前群内昵称',
                    trailingBadge: LoopBadge(
                      syncing ? '同步中' : '已永久保留',
                      kind: syncing ? LoopBadgeKind.mute : LoopBadgeKind.up,
                    ),
                    chevron: false,
                  ),
                ],
              ),
              const SizedBox(height: LoopSpacing.card),
              LoopNotice(
                icon: syncing ? 'refresh' : 'lock',
                tone: syncing ? LoopNoticeTone.warn : LoopNoticeTone.normal,
                body: syncing
                    ? '昵称已经为你保留，群里的显示还在同步。请用完全相同的昵称重试。'
                    : '这个昵称已在当前群永久保留，不能修改。它不会暴露公开 Profile 或 Stream 用户身份。',
              ),
              if (syncing)
                _GroupAliasAction(
                  child: LoopButton(
                    key: const ValueKey<String>('group-alias-retry-projection'),
                    label: '重试同步',
                    icon: 'refresh',
                    block: true,
                    onPressed: state.isBusy
                        ? null
                        : () => unawaited(
                            controller.reserveAlias(resource.alias),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ];
    }

    if (state.phase == GroupAliasPhase.outcomeUnknown) {
      return <Widget>[
        LoopNotice(
          key: const ValueKey<String>('group-alias-outcome-unknown'),
          title: '保留结果待确认',
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: '“${state.pendingAlias}”可能已经永久保留。为避免锁定另一个值，当前只允许重试完全相同的昵称。',
        ),
        _GroupAliasAction(
          child: LoopButton(
            key: const ValueKey<String>('group-alias-retry-pending'),
            label: '用相同昵称重试',
            icon: 'refresh',
            primary: true,
            block: true,
            onPressed: state.isBusy
                ? null
                : () => unawaited(controller.retryPendingAlias()),
          ),
        ),
      ];
    }

    final content = <Widget>[];
    if (state.phase == GroupAliasPhase.failure) {
      content.addAll(<Widget>[
        LoopNotice(
          key: const ValueKey<String>('group-alias-failure'),
          title: '群内昵称未保留',
          icon: 'warn',
          tone: LoopNoticeTone.danger,
          body: _groupAliasFailureMessage(state.failureKind),
        ),
        if (!state.canReserveNewAlias)
          _GroupAliasAction(
            child: LoopButton(
              key: const ValueKey<String>('group-alias-reload'),
              label: '重新读取',
              icon: 'refresh',
              block: true,
              onPressed: state.isBusy
                  ? null
                  : () => unawaited(controller.reload()),
            ),
          ),
      ]);
    }

    if (state.canReserveNewAlias) {
      content.addAll(<Widget>[
        LoopFlatField(
          key: const ValueKey<String>('group-alias-field'),
          label: '当前群昵称',
          footnote: '提交后不可改名；同一群内昵称必须唯一。',
          child: TextField(
            key: const ValueKey<String>('group-alias-input'),
            controller: _aliasController,
            enabled: !state.isBusy,
            maxLength: groupAliasMaximumCodePoints,
            textInputAction: TextInputAction.done,
            style: LoopType.bodyLg,
            decoration: loopFormFieldDecoration(
              hint: '1–40 个字符',
              counterText: '',
            ),
            onSubmitted: (_) => _reserve(controller),
          ),
        ),
        _GroupAliasAction(
          child: LoopButton(
            key: const ValueKey<String>('group-alias-submit'),
            label: state.isBusy ? '保留中…' : '永久保留这个昵称',
            icon: 'lock',
            primary: true,
            block: true,
            onPressed: state.isBusy ? null : () => _reserve(controller),
          ),
        ),
      ]);
    } else if (content.isEmpty) {
      content.add(
        LoopNotice(
          key: const ValueKey<String>('group-alias-blocked'),
          title: '无法设置群内昵称',
          icon: 'lock',
          tone: LoopNoticeTone.warn,
          body: _groupAliasFailureMessage(state.failureKind),
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

/// One full-width button on the page's own 16 gutters.
class _GroupAliasAction extends StatelessWidget {
  const _GroupAliasAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      0,
      LoopSpacing.page,
      LoopSpacing.card,
    ),
    child: child,
  );
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
        LoopFlatField(
          key: const ValueKey<String>('group-alias-search-field'),
          label: '群内昵称',
          footnote: '至少输入 2 个字符',
          trailing: LoopButton(
            key: const ValueKey<String>('group-alias-search-submit'),
            label: state.isBusy ? '查找中' : '查找',
            icon: 'search',
            semanticLabel: '查找群内昵称',
            onPressed: state.isBusy
                ? null
                : () => unawaited(controller.search(_controller.text)),
          ),
          child: TextField(
            key: const ValueKey<String>('group-alias-search-input'),
            controller: _controller,
            enabled: !state.isBusy,
            maxLength: groupAliasMaximumCodePoints,
            textInputAction: TextInputAction.search,
            style: LoopType.bodyLg,
            decoration: loopFormFieldDecoration(
              hint: '输入要查找的昵称',
              counterText: '',
            ),
            onSubmitted: (value) => unawaited(controller.search(value)),
          ),
        ),
        ...switch (state.phase) {
          GroupAliasSearchPhase.idle => const <Widget>[
            LoopNotice(
              key: ValueKey<String>('group-alias-search-scope'),
              icon: 'shield',
              title: '仅在当前群内查找',
              body: '结果只包含群内昵称与不透明的群内引用，不包含公开资料、钱包地址或跨群身份。',
            ),
          ],
          GroupAliasSearchPhase.searching => const <Widget>[
            LoopSkeleton(
              key: ValueKey<String>('group-alias-search-loading'),
              type: LoopSkeletonType.list,
              rows: 2,
            ),
          ],
          GroupAliasSearchPhase.ready when state.page.items.isEmpty =>
            const <Widget>[
              LoopEmptyState(
                key: ValueKey<String>('group-alias-search-empty'),
                illustration: LoopIllustration.search,
                title: '没有找到匹配昵称',
                message: '还没同步完成的成员、已退群的成员和你自己不会出现在结果里。',
                compact: true,
              ),
            ],
          GroupAliasSearchPhase.ready => <Widget>[
            if (state.page.truncated)
              const LoopNotice(
                key: ValueKey<String>('group-alias-search-truncated'),
                icon: 'info',
                tone: LoopNoticeTone.warn,
                title: '结果已截断',
                body: '请继续输入更完整的昵称以缩小范围。',
              ),
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (var index = 0; index < state.page.items.length; index++)
                  LoopRecordRow(
                    key: ValueKey<String>('group-alias-result-$index'),
                    leading: LoopInitialsAvatar(
                      label: state.page.items[index].alias,
                    ),
                    title: state.page.items[index].alias,
                    subtitle: '当前群内昵称',
                    chevron: false,
                  ),
              ],
            ),
          ],
          GroupAliasSearchPhase.unavailable ||
          GroupAliasSearchPhase.failure => <Widget>[
            LoopInlineUnavailable(
              key: const ValueKey<String>('group-alias-search-failure'),
              message:
                  '无法完成群内搜索：${_groupAliasFailureMessage(state.failureKind)}',
              maxLines: 3,
            ),
          ],
        },
      ],
    );
  }
}

/// The one boundary statement at the head of the page: what a group Alias
/// is shown as, and — when the service is absent — that nothing is
/// connected.
class _GroupAliasBoundaryNotice extends StatelessWidget {
  const _GroupAliasBoundaryNotice({required this.mode});

  final GroupAliasGatewayMode mode;

  @override
  Widget build(BuildContext context) {
    final unavailable = mode == GroupAliasGatewayMode.unavailable;
    return LoopNotice(
      key: const ValueKey<String>('group-alias-boundary'),
      icon: unavailable ? 'warn' : 'shield',
      tone: unavailable ? LoopNoticeTone.warn : LoopNoticeTone.normal,
      margin: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        14,
        LoopSpacing.page,
        0,
      ),
      title: switch (mode) {
        GroupAliasGatewayMode.preview => '开发预览 · 仅本次运行',
        GroupAliasGatewayMode.production => 'LOOP 群组身份边界',
        GroupAliasGatewayMode.unavailable => '生产连接不可用',
      },
      body: '群昵称只在这个群里显示，不会关联到你的公开资料或钱包地址。',
    );
  }
}

String _groupAliasFailureMessage(GroupAliasGatewayFailureKind? kind) =>
    switch (kind) {
      GroupAliasGatewayFailureKind.offline => '设备当前离线，没有读到群昵称，也没有提交任何昵称。',
      GroupAliasGatewayFailureKind.unavailable => '群昵称服务当前不可用，没有昵称被显示为已保留。',
      GroupAliasGatewayFailureKind.notFound =>
        '当前没有可见的群昵称；也可能已不再是这个 Stream 群的成员。',
      GroupAliasGatewayFailureKind.immutable => '这个账号已在当前群永久保留了另一个昵称，不能修改。',
      GroupAliasGatewayFailureKind.taken => '这个昵称已经被当前群的其他成员永久保留，请换一个。',
      GroupAliasGatewayFailureKind.invalidData => '这个昵称不可用，请换一个再试。',
      GroupAliasGatewayFailureKind.outcomeUnknown => '请求可能已经提交，只能用完全相同的昵称继续确认。',
      GroupAliasGatewayFailureKind.unexpected => '群昵称操作暂时失败，没有结果被显示为已确认。',
      null => '群昵称当前不可用。',
    };
