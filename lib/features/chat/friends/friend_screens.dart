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
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/features/social/secondary_row_metrics.dart';

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
      title: context.l10n.chatFriends_screensFriendGroupCreateScreenTitle,
      kicker: preview ? context.l10n.common_devPreview : null,
      onBack: _friendPageBack(context),
      keyboardAccessory: true,
      folio: LoopFolioPrimary(
        key: ValueKey<String>('friend-group-folio'),
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.action,
        kicker: context.l10n.chatFriends_screensFriendGroupFolioKicker,
        heading: context.l10n.chatFriends_screensFriendGroupCreateScreenTitle,
        caption: context.l10n.chatFriends_screensFriendGroupFolioCaption,
        stamp: context.l10n.chatFriends_screensFriendGroupFolioStamp,
      ),
      block: group.phase == FriendGroupPhase.unavailable
          ? LoopEmptyState(
              key: ValueKey<String>('friend-group-unavailable'),
              illustration: LoopIllustration.friends,
              title:
                  context.l10n.chatFriends_screensFriendGroupUnavailableTitle,
              message:
                  context.l10n.chatFriends_screensFriendGroupUnavailableMessage,
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
            label: context.l10n.chatFriends_screensFriendGroupNameFieldLabel,
            footnote:
                context.l10n.chatFriends_screensFriendGroupNameFieldFootnote,
            child: TextField(
              key: const ValueKey<String>('friend-group-name-input'),
              controller: _nameController,
              enabled: group.canEdit,
              maxLength: 60,
              textInputAction: TextInputAction.next,
              style: LoopType.bodyLg,
              decoration: loopFormFieldDecoration(
                hint: context.l10n.chatFriends_screensFriendGroupNameFieldLabel,
                counterText: '',
              ),
              onChanged: groupController.editName,
            ),
          ),
          LoopLabel(
            context.l10n.chatFriends_screensFriendGroupSelectionLabel(
              groupMaximumSelectedFriends,
              group.selectedFriendRefs.length,
            ),
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
                      ? context
                            .l10n
                            .chatFriends_screensFriendGroupCreateSubmitLabel
                      : context
                            .l10n
                            .chatFriends_screensFriendGroupCreateScreenTitle,
                  primary: true,
                  block: true,
                  onPressed: group.canCreate
                      ? () => unawaited(groupController.create())
                      : null,
                ),
                const SizedBox(height: LoopSpacing.tight),
                Text(
                  context.l10n.chatFriends_screensText(
                    groupMinimumSelectedFriends,
                  ),
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
          title: LoopL10n
              .current
              .chatFriends_screensFriendGroupFriendsFailureTitle,
          message: _friendFailureMessage(directory.failureKind),
          compact: true,
          action: LoopButton(
            key: const ValueKey<String>('friend-group-friends-retry'),
            label: LoopL10n.current.common_retry,
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
          title:
              LoopL10n.current.chatFriends_screensFriendGroupFriendsEmptyTitle,
          message: LoopL10n
              .current
              .chatFriends_screensFriendGroupFriendsEmptyMessage,
          compact: true,
          action: LoopButton(
            key: const ValueKey<String>('friend-group-find-friends'),
            label:
                LoopL10n.current.chatFriends_screensFriendGroupFindFriendsLabel,
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
              label:
                  LoopL10n.current.chatFriends_screensFriendGroupReconcileLabel,
              icon: 'search',
              block: true,
              onPressed: () => unawaited(groupController.reconcile()),
            )
          : group.canResumeEditing
          ? LoopButton(
              key: const ValueKey<String>('friend-group-resume-editing'),
              label: LoopL10n
                  .current
                  .chatFriends_screensFriendGroupResumeEditingLabel,
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
              ? LoopL10n
                    .current
                    .chatFriends_screensFriendGroupCreateFailureTitle
              : group.failureKind == FriendGatewayFailureKind.outcomeUnknown
              ? LoopL10n
                    .current
                    .chatFriends_screensFriendGroupCreateFailureTitle2
              : LoopL10n
                    .current
                    .chatFriends_screensFriendGroupCreateFailureTitle3,
          body: unresolved
              ? LoopL10n.current
                    .chatFriends_screensFriendGroupCreateFailureBody(
                      _friendFailureMessage(group.failureKind),
                    )
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
/// initials at 48 (S370b · decision 0294: the conversation row's face), the alias over the LOOP code, and the shared round
/// [LoopSelectionCheck] in the value column.
LoopRecordRow _selectableFriendRow({
  required String rowKey,
  required FriendIdentity identity,
  required bool selected,
  required VoidCallback? onChanged,
}) => LoopRecordRow(
  key: ValueKey<String>(rowKey),
  // S371 · decision 0297: the conversation row's 67.
  kind: LoopRecordRowKind.person,
  leading: LoopInitialsAvatar(
    label: identity.alias,
    size: SecondaryRowMetrics.personFace,
  ),
  title: identity.alias,
  subtitle: 'LOOP #${identity.profileCode}',
  trailingBadge: LoopSelectionCheck(selected: selected),
  chevron: false,
  onTap: onChanged,
  semanticLabel:
      '${identity.alias}${LoopL10n.current.common_listSeparator}${selected ? LoopL10n.current.chatFriends_screensSelected : LoopL10n.current.chatFriends_screensNotSelected}',
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
  Widget build(BuildContext context) => LoopNotice(
    key: ValueKey<String>('friend-preview-banner'),
    icon: 'info',
    title: context.l10n.chatFriends_screensFriendPreviewBannerTitle,
    body: context.l10n.chatFriends_screensFriendPreviewBannerBody,
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
        LoopLabel(context.l10n.chatFriends_screensLoopLabel),
        LoopNotice(
          icon: 'check',
          title: preview
              ? context.l10n.chatFriends_screensTitle
              : context.l10n.chatFriends_screensTitle2,
          body: preview
              ? context.l10n.chatFriends_screensBody(
                  receipt.name,
                  receipt.friendRefs.length + 1,
                )
              : context.l10n.chatFriends_screensBody2(
                  receipt.name,
                  receipt.friendRefs.length + 1,
                ),
        ),
        if (preview)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
            child: LoopButton(
              key: const ValueKey<String>('friend-group-create-another'),
              label:
                  context.l10n.chatFriends_screensFriendGroupCreateAnotherLabel,
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
                label: context.l10n.chatFriends_screensFriendGroupSetAliasLabel,
                icon: 'id',
                block: true,
                onPressed: onSetAlias,
              ),
              LoopButton(
                key: const ValueKey<String>('friend-group-open-channel'),
                label:
                    context.l10n.chatFriends_screensFriendGroupOpenChannelLabel,
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
  FriendGatewayFailureKind.unavailable =>
    LoopL10n.current.chatFriends_screensUnavailable,
  FriendGatewayFailureKind.invalidData =>
    LoopL10n.current.chatFriends_screensInvalidData,
  FriendGatewayFailureKind.notFound =>
    LoopL10n.current.chatFriends_screensNotFound,
  FriendGatewayFailureKind.permissionDenied =>
    LoopL10n.current.chatFriends_screensPermissionDenied,
  FriendGatewayFailureKind.conflict =>
    LoopL10n.current.chatFriends_screensConflict,
  FriendGatewayFailureKind.rateLimited =>
    LoopL10n.current.chatFriends_screensRateLimited,
  FriendGatewayFailureKind.profileRequired =>
    LoopL10n.current.chatFriends_screensProfileRequired,
  FriendGatewayFailureKind.incomingRequestPending =>
    LoopL10n.current.chatFriends_screensIncomingRequestPending,
  FriendGatewayFailureKind.outgoingRequestPending =>
    LoopL10n.current.chatFriends_screensOutgoingRequestPending,
  FriendGatewayFailureKind.alreadyFriends =>
    LoopL10n.current.chatFriends_screensAlreadyFriends,
  FriendGatewayFailureKind.cooldown =>
    LoopL10n.current.chatFriends_screensCooldown,
  FriendGatewayFailureKind.alreadyDecided =>
    LoopL10n.current.chatFriends_screensAlreadyDecided,
  FriendGatewayFailureKind.cursorInvalid =>
    LoopL10n.current.chatFriends_screensCursorInvalid,
  FriendGatewayFailureKind.operatorRequired =>
    LoopL10n.current.chatFriends_screensOperatorRequired,
  FriendGatewayFailureKind.outcomeUnknown =>
    LoopL10n.current.chatFriends_screensOutcomeUnknown,
  FriendGatewayFailureKind.unexpected =>
    LoopL10n.current.chatFriends_screensUnexpected,
  null => LoopL10n.current.chatFriends_screensSwitch,
};
