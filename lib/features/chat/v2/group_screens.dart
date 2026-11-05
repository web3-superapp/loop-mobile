import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/group_rename.dart';
import 'package:loop_mobile/features/chat/v2/loop_channel_heading.dart';
import 'package:loop_mobile/features/chat/v2/loop_channel_message_policy.dart';
import 'package:loop_mobile/features/chat/v2/loop_message_selection.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_search_entry.dart';

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

  /// Takes the channel CID, so search starts from the exact conversation the
  /// user is reading.
  final ValueChanged<String>? onOpenSearch;

  /// No longer drawn (S108, decision 0114): forwarding starts from a
  /// message's long-press. Kept so the router's wiring stays as it is.
  final ValueChanged<String>? onOpenForward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityChat),
    );
    final mode = ref.watch(chatV2GatewayProvider).mode;
    final cid = channelCid;
    final blocked = communityCapabilityBlocks(mode, capability);
    return LoopMessageSelectionHost(
      child: Scaffold(
        key: const ValueKey<String>('group-screen'),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopSelectionAwareTopbar(
                // S253: the header names the group and states its size, from
                // the channel this client holds; 「群聊」 only while it has
                // neither (device report S240).
                child: LoopStreamChannelHeadingBuilder(
                  cid: blocked ? null : cid,
                  builder: (context, heading) => LoopTopbar(
                    title: groupChatTitle(heading),
                    subtitle: loopChannelMemberLine(heading.memberCount),
                    titleMaxLines: 1,
                    dense: true,
                    kicker: communityPreviewKicker(mode),
                    onBack: onBack,
                    minHeight: 72,
                    actions: <Widget>[
                      if (cid != null) ...<Widget>[
                        LoopIconButton(
                          key: const ValueKey<String>('group-open-search'),
                          icon: 'search',
                          label: context
                              .l10n
                              .chatV2_communityCommunityChatOpenSearchLabel,
                          onPressed: () => onOpenSearch?.call(cid),
                        ),
                        LoopIconButton(
                          key: const ValueKey<String>('group-open-info'),
                          icon: 'info',
                          label: context
                              .l10n
                              .chatV2_groupScreensGroupOpenInfoLabel,
                          onPressed: () => onOpenInfo?.call(cid),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: switch ((blocked, cid)) {
                  (true, _) => _Block(
                    blockKey: 'group-capability-unavailable',
                    message: context.l10n.chatV2_groupScreensMessage,
                    reason: capability.reasonCode == null
                        ? context.l10n.chatV2_communityReason2
                        : communicationUnavailableReason(capability.reasonCode),
                  ),
                  (false, null) => _Block(
                    blockKey: 'group-missing-cid',
                    message: context.l10n.chatV2_groupScreensMessage2,
                    reason: context.l10n.chatV2_groupScreensReason,
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
                        CommunityPreviewNotice(
                          mode: mode,
                          resource: context.l10n.common_groupChat,
                        ),
                        LoopChatHeaderFold(
                          collapsed: loopChatKeyboardIsUp(context),
                          // S278 · decision 0236: an explanation, behind (i).
                          child: LoopProvenanceFooter(
                            key: ValueKey<String>('group-scope-note'),
                            label: context.l10n.common_about,
                            title: context
                                .l10n
                                .chatV2_groupScreensGroupScopeNoteTitle,
                            margin: EdgeInsets.fromLTRB(
                              LoopSpacing.page,
                              0,
                              12,
                              0,
                            ),
                            text: context
                                .l10n
                                .chatV2_groupScreensGroupScopeNoteText,
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
      ),
    );
  }
}

/// The `group` header title: the group's own name, or 「群聊」 while this
/// client holds no name for it.
String groupChatTitle(LoopChannelHeading heading) =>
    heading.name ?? groupChatNeutralTitle;

/// What the `group` header says when no name is known.
String get groupChatNeutralTitle => LoopL10n.current.common_groupChat;

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
      LoopToast.show(
        context,
        message: LoopL10n.current.chatV2_groupScreensMessage3(renamed.name),
      );
      return;
    }
    LoopToast.show(
      context,
      message: switch (failure!) {
        CommunityFailureKind.permissionDenied =>
          LoopL10n.current.chatV2_groupScreensPermissionDenied,
        CommunityFailureKind.unavailable =>
          LoopL10n.current.chatV2_groupScreensUnavailable,
        CommunityFailureKind.notFound =>
          LoopL10n.current.chatV2_groupScreensNotFound,
        CommunityFailureKind.validationFailed =>
          LoopL10n.current.chatV2_groupScreensValidationFailed,
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
      title: context.l10n.chatV2_groupScreensGroupOpenInfoLabel,
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: context.l10n.chatV2_groupScreensKicker,
        heading: context.l10n.chatV2_groupScreensGroupOpenInfoLabel,
        caption: context.l10n.chatV2_groupScreensCaption,
        stamp: context.l10n.chatV2_directMessageStamp,
      ),
      sections: <Widget>[
        CommunityPreviewNotice(
          mode: mode,
          resource: context.l10n.chatV2_groupScreensGroupOpenInfoLabel,
        ),
        if (blocked)
          LoopInlineUnavailable(
            key: const ValueKey<String>('group-info-capability-unavailable'),
            message: context.l10n.chatV2_groupScreensMessage,
            detail: capability.reasonCode == null
                ? context
                      .l10n
                      .chatV2_groupScreensGroupInfoCapabilityUnavailableDetail
                : communicationUnavailableReason(capability.reasonCode),
            maxLines: 2,
            detailMaxLines: 4,
          )
        else if (widget.channelCid == null)
          LoopInlineUnavailable(
            key: ValueKey<String>('group-info-missing-cid'),
            message: context.l10n.chatV2_groupScreensMessage2,
            detail: context.l10n.chatV2_groupScreensGroupInfoMissingCidDetail,
            maxLines: 2,
            detailMaxLines: 4,
          )
        else ...<Widget>[
          LoopLabel(context.l10n.common_members),
          CommunityUnavailableCard(
            key: ValueKey<String>('group-info-members-unavailable'),
            label: context
                .l10n
                .chatV2_groupScreensGroupInfoMembersUnavailableLabel,
            fact: _memberDirectoryDeferred,
          ),
          LoopLabel(context.l10n.chatV2_groupScreensKicker),
          _GroupNameRow(
            name: _renamedTo ?? _facts?.name,
            read: _factsRead,
            mayRename: _facts?.viewerIsCreator ?? false,
            busy: _renaming || _resolving || _groupId == null,
            onRename: () => unawaited(_rename()),
          ),
          LoopLabel(context.l10n.common_settings),
          CommunityUnavailableCard(
            key: ValueKey<String>('group-info-settings-unavailable'),
            label: context
                .l10n
                .chatV2_groupScreensGroupInfoSettingsUnavailableLabel,
            fact: _groupSettingsDeferred,
          ),
          LoopLabel(context.l10n.common_exit),
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
              pausedActions: <String>[
                context.l10n.chatV2_groupScreensLoopOfflineState,
              ],
            )
          else if (_resolveFailure == GroupAliasGatewayFailureKind.notFound)
            LoopEmptyState(
              showMessage: true,
              key: ValueKey<String>('group-info-state-empty'),
              illustration: LoopIllustration.members,
              title: context.l10n.chatV2_groupScreensGroupInfoStateEmptyTitle,
              message:
                  context.l10n.chatV2_groupScreensGroupInfoStateEmptyMessage,
              compact: true,
            )
          else if (_resolveFailure == GroupAliasGatewayFailureKind.unavailable)
            LoopInlineUnavailable(
              key: ValueKey<String>('group-info-state-unavailable'),
              message: context
                  .l10n
                  .chatV2_groupScreensGroupInfoStateUnavailableMessage,
              detail: context
                  .l10n
                  .chatV2_groupScreensGroupInfoStateUnavailableDetail,
              maxLines: 2,
              detailMaxLines: 4,
            )
          else if (_resolveFailure != null)
            LoopErrorState(
              key: const ValueKey<String>('group-info-resolve-failed'),
              reason:
                  context.l10n.chatV2_groupScreensGroupInfoResolveFailedReason,
              onRetry: () => unawaited(_resolveGroup()),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                4,
                LoopSpacing.page,
                0,
              ),
              child: LoopButton(
                key: const ValueKey<String>('group-info-leave'),
                label: context.l10n.chatV2_groupScreensLoopOfflineState,
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
      title: LoopL10n.current.chatV2_groupScreensTitle,
      body: LoopL10n.current.chatV2_groupScreensBody,
      confirmLabel: LoopL10n.current.common_exit,
      sheetKey: 'group-leave-confirm-sheet',
    );
    if (!confirmed || !mounted) return;
    final failure = await ref
        .read(groupMembershipControllerProvider.notifier)
        .leave(groupId.wireValue);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(
        context,
        message: LoopL10n.current.chatV2_groupScreensMessage4,
      );
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
          title: context.l10n.chatV2_groupScreensGroupInfoNameTitle,
          subtitle: !read
              ? context.l10n.chatV2_groupScreensGroupInfoNameSubtitle
              : shown ?? context.l10n.chatV2_groupScreensGroupInfoNameSubtitle2,
          trailingCaption: mayRename
              ? context.l10n.chatV2_groupScreensGroupInfoNameTrailingCaption
              : context.l10n.chatV2_groupScreensGroupInfoNameTrailingCaption2,
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
  barrierLabel: context.l10n.chatV2_groupScreensBarrierLabel,
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
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('group-rename-sheet'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      LoopSheetHeading(context.l10n.chatV2_groupScreensLoopSheetHeading),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('group-rename-field'),
              controller: _name,
              autofocus: true,
              onChanged: (_) {
                if (_invalid) setState(() => _invalid = false);
              },
              onSubmitted: (_) => _submit(),
              // S371 · decision 0297: the Figma search-field face.
              decoration: loopSearchFieldDecoration(
                hint: context.l10n.chatV2_groupScreensLabelText(
                  groupNameMaximumRunes,
                ),
                searchGlyph: false,
                errorText: _invalid
                    ? context.l10n.chatV2_groupScreensErrorText
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            LoopButtonPair(
              padded: false,
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('group-rename-submit'),
                  label: context.l10n.common_save,
                  primary: true,
                  onPressed: _submit,
                ),
                LoopButton(
                  key: const ValueKey<String>('group-rename-cancel'),
                  label: context.l10n.common_cancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
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
    child: LoopInlineUnavailable(
      key: ValueKey<String>(blockKey),
      message: message,
      detail: reason,
      maxLines: 2,
      detailMaxLines: 4,
    ),
  );
}
