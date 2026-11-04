import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_controller.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart'
    show loopFormFieldDecoration;

/// The page title every group-Alias location carries.
String get _groupAliasTitle =>
    LoopL10n.current.chatGroupAlias_screenGroupAliasTitle;

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
      return _GroupAliasBlockedPage(
        state: LoopEmptyState(
          showMessage: true,
          key: ValueKey<String>('group-alias-route-invalid'),
          illustration: LoopIllustration.members,
          title: context.l10n.chatGroupAlias_screenGroupAliasRouteInvalidTitle,
          message:
              context.l10n.chatGroupAlias_screenGroupAliasRouteInvalidMessage,
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
  Widget build(BuildContext context) => _GroupAliasBlockedPage(
    state: LoopEmptyState(
      key: ValueKey<String>('group-alias-paused'),
      illustration: LoopIllustration.members,
      title: context.l10n.chatGroupAlias_screenGroupAliasPausedTitle,
      message: context.l10n.chatGroupAlias_screenGroupAliasPausedMessage,
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
      return _GroupAliasBlockedPage(
        state: LoopEmptyState(
          showMessage: true,
          key: ValueKey<String>('group-alias-channel-invalid'),
          illustration: LoopIllustration.members,
          title:
              context.l10n.chatGroupAlias_screenGroupAliasChannelInvalidTitle,
          message:
              context.l10n.chatGroupAlias_screenGroupAliasChannelInvalidMessage,
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
      GroupAliasResolverPhase.initial || GroupAliasResolverPhase.resolving =>
        context.l10n.chatGroupAlias_screenResolving,
      GroupAliasResolverPhase.notFound =>
        context.l10n.chatGroupAlias_screenNotFound,
      GroupAliasResolverPhase.unavailable =>
        context.l10n.chatGroupAlias_screenUnavailable,
      GroupAliasResolverPhase.failure || GroupAliasResolverPhase.resolved =>
        context.l10n.chatGroupAlias_screenResolved,
    };
    final message = switch (state.phase) {
      GroupAliasResolverPhase.initial || GroupAliasResolverPhase.resolving =>
        context.l10n.chatGroupAlias_screenResolving2,
      GroupAliasResolverPhase.notFound =>
        context.l10n.chatGroupAlias_screenNotFound2,
      GroupAliasResolverPhase.unavailable =>
        context.l10n.chatGroupAlias_screenUnavailable2,
      GroupAliasResolverPhase.failure || GroupAliasResolverPhase.resolved =>
        context.l10n.chatGroupAlias_screenResolved2,
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
                label: context
                    .l10n
                    .chatGroupAlias_screenGroupAliasResolverRetryLabel,
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
      kicker: preview ? context.l10n.common_devPreview : null,
      onBack: _groupAliasBack(context),
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('group-alias-folio'),
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: context.l10n.chatGroupAlias_screenGroupAliasFolioKicker,
        heading: _groupAliasTitle,
        caption: context.l10n.chatGroupAlias_screenGroupAliasFolioCaption,
        stamp: switch (state.mode) {
          GroupAliasGatewayMode.preview => context.l10n.common_devPreview,
          GroupAliasGatewayMode.production =>
            context.l10n.chatGroupAlias_screenProduction,
          GroupAliasGatewayMode.unavailable =>
            context.l10n.chatGroupAlias_screenUnavailable3,
        },
      ),
      sections: <Widget>[
        _GroupAliasBoundaryNotice(mode: state.mode),
        LoopLabel(context.l10n.chatGroupAlias_screenLoopLabel),
        ..._aliasContent(state, controller),
        if (state.mode != GroupAliasGatewayMode.unavailable) ...<Widget>[
          LoopLabel(context.l10n.chatGroupAlias_screenLoopLabel2),
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
      return <Widget>[
        LoopEmptyState(
          key: ValueKey<String>('group-alias-unavailable'),
          illustration: LoopIllustration.members,
          title:
              LoopL10n.current.chatGroupAlias_screenGroupAliasUnavailableTitle,
          message: LoopL10n
              .current
              .chatGroupAlias_screenGroupAliasUnavailableMessage,
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
                    subtitle: syncing
                        ? LoopL10n.current.chatGroupAlias_screenSubtitle
                        : LoopL10n.current.chatGroupAlias_screenSubtitle2,
                    trailingBadge: LoopBadge(
                      syncing
                          ? LoopL10n.current.chatGroupAlias_screenLoopBadge
                          : LoopL10n.current.chatGroupAlias_screenS,
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
                    ? LoopL10n.current.chatGroupAlias_screenBody
                    : LoopL10n.current.chatGroupAlias_screenBody2,
              ),
              if (syncing)
                _GroupAliasAction(
                  child: LoopButton(
                    key: const ValueKey<String>('group-alias-retry-projection'),
                    label: LoopL10n
                        .current
                        .chatGroupAlias_screenGroupAliasRetryProjectionLabel,
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
          title: LoopL10n
              .current
              .chatGroupAlias_screenGroupAliasOutcomeUnknownTitle,
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: LoopL10n.current
              .chatGroupAlias_screenGroupAliasOutcomeUnknownBody(
                state.pendingAlias,
              ),
        ),
        _GroupAliasAction(
          child: LoopButton(
            key: const ValueKey<String>('group-alias-retry-pending'),
            label: LoopL10n
                .current
                .chatGroupAlias_screenGroupAliasRetryPendingLabel,
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
          title: LoopL10n.current.chatGroupAlias_screenGroupAliasFailureTitle,
          icon: 'warn',
          tone: LoopNoticeTone.danger,
          body: _groupAliasFailureMessage(state.failureKind),
        ),
        if (!state.canReserveNewAlias)
          _GroupAliasAction(
            child: LoopButton(
              key: const ValueKey<String>('group-alias-reload'),
              label:
                  LoopL10n.current.chatGroupAlias_screenGroupAliasReloadLabel,
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
          label: LoopL10n.current.chatGroupAlias_screenGroupAliasFieldLabel,
          footnote:
              LoopL10n.current.chatGroupAlias_screenGroupAliasFieldFootnote,
          child: TextField(
            key: const ValueKey<String>('group-alias-input'),
            controller: _aliasController,
            enabled: !state.isBusy,
            maxLength: groupAliasMaximumCodePoints,
            textInputAction: TextInputAction.done,
            style: LoopType.bodyLg,
            decoration: loopFormFieldDecoration(
              hint: LoopL10n.current.chatGroupAlias_screenHint,
              counterText: '',
            ),
            onSubmitted: (_) => _reserve(controller),
          ),
        ),
        _GroupAliasAction(
          child: LoopButton(
            key: const ValueKey<String>('group-alias-submit'),
            label: state.isBusy
                ? LoopL10n.current.chatGroupAlias_screenGroupAliasSubmitLabel
                : LoopL10n.current.chatGroupAlias_screenGroupAliasSubmitLabel2,
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
          title: LoopL10n.current.chatGroupAlias_screenGroupAliasBlockedTitle,
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
          label: context.l10n.chatGroupAlias_screenGroupAliasTitle,
          footnote:
              context.l10n.chatGroupAlias_screenGroupAliasSearchFieldFootnote,
          trailing: LoopButton(
            key: const ValueKey<String>('group-alias-search-submit'),
            label: state.isBusy
                ? context.l10n.chatGroupAlias_screenGroupAliasSearchSubmitLabel
                : context
                      .l10n
                      .chatGroupAlias_screenGroupAliasSearchSubmitLabel2,
            icon: 'search',
            semanticLabel: context
                .l10n
                .chatGroupAlias_screenGroupAliasSearchSubmitSemanticLabel,
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
              hint: context.l10n.chatGroupAlias_screenHint2,
              counterText: '',
            ),
            onSubmitted: (value) => unawaited(controller.search(value)),
          ),
        ),
        ...switch (state.phase) {
          GroupAliasSearchPhase.idle => const <Widget>[],
          GroupAliasSearchPhase.searching => const <Widget>[
            LoopSkeleton(
              key: ValueKey<String>('group-alias-search-loading'),
              type: LoopSkeletonType.list,
              rows: 2,
            ),
          ],
          GroupAliasSearchPhase.ready when state.page.items.isEmpty => <Widget>[
            LoopEmptyState(
              key: ValueKey<String>('group-alias-search-empty'),
              illustration: LoopIllustration.search,
              title:
                  context.l10n.chatGroupAlias_screenGroupAliasSearchEmptyTitle,
              message: context
                  .l10n
                  .chatGroupAlias_screenGroupAliasSearchEmptyMessage,
              compact: true,
            ),
          ],
          GroupAliasSearchPhase.ready => <Widget>[
            if (state.page.truncated)
              LoopNotice(
                key: ValueKey<String>('group-alias-search-truncated'),
                icon: 'info',
                tone: LoopNoticeTone.warn,
                title: context
                    .l10n
                    .chatGroupAlias_screenGroupAliasSearchTruncatedTitle,
                body: context
                    .l10n
                    .chatGroupAlias_screenGroupAliasSearchTruncatedBody,
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
                    subtitle: context.l10n.chatGroupAlias_screenSubtitle2,
                    chevron: false,
                  ),
              ],
            ),
          ],
          GroupAliasSearchPhase.unavailable ||
          GroupAliasSearchPhase.failure => <Widget>[
            LoopInlineUnavailable(
              key: const ValueKey<String>('group-alias-search-failure'),
              message: context.l10n
                  .chatGroupAlias_screenGroupAliasSearchFailureMessage(
                    _groupAliasFailureMessage(state.failureKind),
                  ),
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
        GroupAliasGatewayMode.preview =>
          context.l10n.chatFriends_screensFriendPreviewBannerTitle,
        GroupAliasGatewayMode.production =>
          context.l10n.chatGroupAlias_screenProduction2,
        GroupAliasGatewayMode.unavailable =>
          context.l10n.chatGroupAlias_screenUnavailable4,
      },
      body: context.l10n.chatGroupAlias_screenGroupAliasBoundaryBody,
    );
  }
}

String _groupAliasFailureMessage(GroupAliasGatewayFailureKind? kind) =>
    switch (kind) {
      GroupAliasGatewayFailureKind.offline =>
        LoopL10n.current.chatGroupAlias_screenOffline,
      GroupAliasGatewayFailureKind.unavailable =>
        LoopL10n.current.chatGroupAlias_screenUnavailable5,
      GroupAliasGatewayFailureKind.notFound =>
        LoopL10n.current.chatGroupAlias_screenNotFound3,
      GroupAliasGatewayFailureKind.immutable =>
        LoopL10n.current.chatGroupAlias_screenImmutable,
      GroupAliasGatewayFailureKind.taken =>
        LoopL10n.current.chatGroupAlias_screenTaken,
      GroupAliasGatewayFailureKind.invalidData =>
        LoopL10n.current.chatGroupAlias_screenInvalidData,
      GroupAliasGatewayFailureKind.outcomeUnknown =>
        LoopL10n.current.chatGroupAlias_screenOutcomeUnknown,
      GroupAliasGatewayFailureKind.unexpected =>
        LoopL10n.current.chatGroupAlias_screenUnexpected,
      null => LoopL10n.current.chatGroupAlias_screenSwitch,
    };
