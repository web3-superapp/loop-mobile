import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_voice_room_open.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/secondary_row_metrics.dart';
import 'package:loop_mobile/features/social/qr/loop_qr_card.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The Owner / Admin head count the 成员 row prints, read once per visit
/// from the members directory's own counts (`GET …/members`).
final communityManageCountsProvider = FutureProvider.autoDispose
    .family<CommunityMemberCounts, String>((ref, communityId) async {
      final directory = await ref
          .read(communityGatewayProvider)
          .listMembers(communityId);
      return directory.counts;
    });

/// `community-manage` · action / dashboard (decision 0113, S109b §3.4).
///
/// Everything an owner or an admin does to a community, in one place: its
/// profile (and, for the owner alone, its bound token), its members, its
/// voice room, its announcements, its card and — for the owner — its
/// ownership. The record (`community-profile`) keeps reading; this page is
/// where it is changed. Every write is still the server's to admit: the role
/// only decides what is offered.
///
/// It reads the same record the community page reads (one controller, one
/// answer), so arriving from the record costs no second request.
class CommunityManageScreen extends ConsumerStatefulWidget {
  const CommunityManageScreen({
    required this.communityId,
    super.key,
    this.onBack,
  });

  final String? communityId;
  final VoidCallback? onBack;

  @override
  ConsumerState<CommunityManageScreen> createState() =>
      _CommunityManageScreenState();
}

class _CommunityManageScreenState extends ConsumerState<CommunityManageScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(communityProfileControllerProvider);
    final controller = ref.read(communityProfileControllerProvider.notifier);
    // Held so an opening started here outlives the confirm sheet.
    final opening = ref.watch(voiceRoomOpenControllerProvider);
    final id = widget.communityId;
    final blocked = communityCapabilityBlocks(mode, capability);
    final shown = state.value;
    if (!blocked &&
        id != null &&
        (state.phase == CommunityViewPhase.loading ||
            (shown != null && shown.community.communityId != id))) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(id));
      });
    }
    final detail = shown != null && shown.community.communityId == id
        ? shown
        : null;
    final viewer = detail?.viewer;
    final isOwner = viewer?.isOwner ?? false;
    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('community-manage-screen'),
        archetype: LoopPageArchetype.action,
        title: context.l10n.community_manageCommunityManageScreenTitle,
        kicker: communityPreviewKicker(mode),
        onBack: widget.onBack,
        // Decision 0127: the community's face and name head the page as one
        // row; the hero card and its English eyebrow are gone.
        primary: detail == null
            ? null
            : LoopPersonRow(
                key: const ValueKey<String>('community-manage-header'),
                // S370b · decision 0294: the community row (docs/58 §3.2).
                height: SecondaryRowMetrics.communityRow,
                leading: CommunityLogo(
                  identity: detail.community.communityId,
                  name: detail.community.name,
                  logoRef: detail.community.logoRef,
                  size: SecondaryRowMetrics.communityLogo,
                  radius: SecondaryRowMetrics.communityLogoRadius,
                ),
                title: detail.community.name,
                tag: viewer?.membership == null
                    ? null
                    : LoopTag(viewer!.membership!.role.label, lime: true),
                subtitle: context.l10n.community_homeCommunityMemberCountLabel(
                  communityCountLabel(detail.community.memberCount),
                ),
              ),
        block: id != null && blocked
            ? CommunityCapabilityPageBlock(
                key: const ValueKey<String>(
                  'community-manage-capability-unavailable',
                ),
                capability: capability,
                title: context
                    .l10n
                    .community_discoverCommunityDiscoverCapabilityUnavailableTitle,
              )
            : null,
        onRefresh: id == null ? null : controller.reload,
        updating: state.refreshing || state.busy || opening,
        sections: <Widget>[
          CommunityPreviewNotice(
            mode: mode,
            resource: context.l10n.community_manageCommunityManageScreenTitle,
          ),
          if (id == null)
            LoopInlineUnavailable(
              key: ValueKey<String>('community-manage-missing-id'),
              message:
                  context.l10n.community_manageCommunityManageMissingIdMessage,
              detail:
                  context.l10n.community_manageCommunityManageMissingIdDetail,
              maxLines: 2,
              detailMaxLines: 4,
            )
          else if (detail == null)
            CommunityStateBlock(
              phase: state.phase == CommunityViewPhase.ready
                  ? CommunityViewPhase.loading
                  : state.phase,
              failureKind: state.failureKind,
              skeleton: LoopSkeletonType.list,
              emptyMessage: context.l10n.community_manageEmptyMessage,
              emptyReason: context.l10n.community_manageEmptyReason,
              onRetry: () => unawaited(controller.reload()),
            )
          else if (!detail.viewer.mayManage)
            LoopInlineUnavailable(
              key: ValueKey<String>('community-manage-permission'),
              icon: 'lock',
              message:
                  context.l10n.community_manageCommunityManagePermissionMessage,
              detail:
                  context.l10n.community_manageCommunityManagePermissionDetail,
              maxLines: 2,
              detailMaxLines: 4,
            )
          else
            ..._groups(context, detail, isOwner: isOwner, busy: state.busy),
        ],
      ),
    );
  }

  /// Three sections of entry rows (decision 0127): 资料, 成员, 语音房.
  List<Widget> _groups(
    BuildContext context,
    CommunityDetail detail, {
    required bool isOwner,
    required bool busy,
  }) {
    final community = detail.community;
    final id = community.communityId;
    final counts = ref.watch(communityManageCountsProvider(id));
    return <Widget>[
      // 资料
      LoopLabel(context.l10n.common_profile),
      Column(
        key: const ValueKey<String>('community-manage-profile-group'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopPersonRow(
            key: const ValueKey<String>('community-manage-edit-profile'),
            height: SecondaryRowMetrics.functionRow,
            // S371 · decision 0297: ruled, 6 above and below (docs/58 §9.4).
            divider: true,
            padding: SecondaryRowMetrics.rowPadding,
            leading: LoopEntryIcon(
              'id',
              size: SecondaryRowMetrics.functionGlyph,
              shape: LoopEntryIconShape.square,
            ),
            title: context.l10n.community_manageCommunityManageEditProfileTitle,
            subtitle:
                community.description ??
                context.l10n.community_manageCommunityManageEditProfileSubtitle,
            chevron: true,
            onTap: busy
                ? null
                : () =>
                      unawaited(_editProfile(detail, includeBoundAsset: false)),
          ),
          if (isOwner)
            LoopPersonRow(
              key: const ValueKey<String>('community-manage-bound-asset'),
              height: SecondaryRowMetrics.functionRow,
              // S371 · decision 0297: ruled, 6 above and below (docs/58 §9.4).
              divider: true,
              padding: SecondaryRowMetrics.rowPadding,
              leading: LoopEntryIcon(
                'wallet',
                size: SecondaryRowMetrics.functionGlyph,
                shape: LoopEntryIconShape.square,
              ),
              title:
                  context.l10n.community_manageCommunityManageBoundAssetTitle,
              tag: LoopTag(context.l10n.community_manageLoopTag),
              subtitle: _boundAssetLine(community),
              chevron: true,
              onTap: busy
                  ? null
                  : () => unawaited(
                      _editProfile(detail, includeBoundAsset: true),
                    ),
            ),
          if (isOwner &&
              community.boundAsset != null &&
              !community.boundAsset!.hasRegisteredPool)
            Padding(
              key: const ValueKey<String>('community-manage-no-pool'),
              // S370b: under the row's words — the page margin, the 34 glyph, its 12.
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page + SecondaryRowMetrics.functionGlyph + 12,
                0,
                LoopSpacing.page,
                8,
              ),
              child: Text(
                context.l10n.community_manageGroups,
                style: LoopType.captionSm,
              ),
            ),
          LoopPersonRow(
            key: const ValueKey<String>('community-manage-share'),
            height: SecondaryRowMetrics.functionRow,
            // S371 · decision 0297: ruled, 6 above and below (docs/58 §9.4).
            divider: true,
            padding: SecondaryRowMetrics.rowPadding,
            leading: LoopEntryIcon(
              'share',
              size: SecondaryRowMetrics.functionGlyph,
              shape: LoopEntryIconShape.square,
            ),
            title: context.l10n.community_manageCommunityManageShareTitle,
            subtitle: context.l10n.community_manageCommunityManageShareSubtitle,
            chevron: true,
            onTap: () => unawaited(
              showLoopQrCardSheet(
                context,
                LoopCommunityQrCard(
                  communityId: id,
                  name: community.name,
                  memberCount: community.memberCount,
                  logoRef: community.logoRef,
                  description: community.description,
                ),
              ),
            ),
          ),
          // Publishing waits on the operator console; the row says so in its
          // grey line and takes no tap.
          LoopPersonRow(
            key: ValueKey<String>('community-manage-announcements'),
            height: SecondaryRowMetrics.functionRow,
            // S371 · decision 0297: ruled, 6 above and below (docs/58 §9.4).
            divider: true,
            padding: SecondaryRowMetrics.rowPadding,
            leading: LoopEntryIcon(
              'news',
              size: SecondaryRowMetrics.functionGlyph,
              shape: LoopEntryIconShape.square,
            ),
            title:
                context.l10n.community_manageCommunityManageAnnouncementsTitle,
            subtitle: context
                .l10n
                .community_manageCommunityManageAnnouncementsSubtitle,
          ),
        ],
      ),
      // 成员
      LoopLabel(context.l10n.common_members),
      Column(
        key: const ValueKey<String>('community-manage-members-group'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopPersonRow(
            key: const ValueKey<String>('community-manage-members'),
            height: SecondaryRowMetrics.functionRow,
            // S371 · decision 0297: ruled, 6 above and below (docs/58 §9.4).
            divider: true,
            padding: SecondaryRowMetrics.rowPadding,
            leading: LoopEntryIcon(
              'users',
              size: SecondaryRowMetrics.functionGlyph,
              shape: LoopEntryIconShape.square,
            ),
            title: context.l10n.community_manageCommunityManageMembersTitle,
            subtitle: switch (counts) {
              AsyncData(:final value) => context.l10n.community_manageAsyncData(
                value.admin,
                value.all,
                value.owner,
              ),
              AsyncError() => context.l10n.community_manageAsyncError(
                community.memberCount,
              ),
              _ => context.l10n.community_manageAsyncError(
                community.memberCount,
              ),
            },
            chevron: true,
            onTap: () => unawaited(
              context.push<void>(
                '/community/members?id=${Uri.encodeQueryComponent(id)}',
              ),
            ),
          ),
          if (isOwner)
            LoopPersonRow(
              key: const ValueKey<String>('community-manage-transfer'),
              height: SecondaryRowMetrics.functionRow,
              // S371 · decision 0297: ruled, 6 above and below (docs/58 §9.4).
              divider: true,
              padding: SecondaryRowMetrics.rowPadding,
              leading: LoopEntryIcon(
                'crown',
                size: SecondaryRowMetrics.functionGlyph,
                shape: LoopEntryIconShape.square,
              ),
              title: context.l10n.community_manageCommunityManageTransferTitle,
              subtitle:
                  context.l10n.community_manageCommunityManageTransferSubtitle,
              chevron: true,
              onTap: () => unawaited(
                context.push<void>(
                  '/community/members?id=${Uri.encodeQueryComponent(id)}',
                ),
              ),
            ),
        ],
      ),
      // 语音房
      LoopLabel(context.l10n.common_voiceRooms),
      Column(
        key: const ValueKey<String>('community-manage-voice-group'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (detail.voice.isLive)
            LoopPersonRow(
              key: const ValueKey<String>('community-manage-voice-enter'),
              height: SecondaryRowMetrics.functionRow,
              // S371 · decision 0297: ruled, 6 above and below (docs/58 §9.4).
              divider: true,
              padding: SecondaryRowMetrics.rowPadding,
              leading: LoopEntryIcon(
                'voice',
                size: SecondaryRowMetrics.functionGlyph,
                shape: LoopEntryIconShape.square,
              ),
              title:
                  context.l10n.community_manageCommunityManageVoiceEnterTitle,
              subtitle: context
                  .l10n
                  .community_manageCommunityManageVoiceEnterSubtitle,
              chevron: true,
              onTap: () => unawaited(
                context.push<void>(
                  '/chat/voice?id=${Uri.encodeQueryComponent(id)}',
                ),
              ),
            )
          else
            LoopPersonRow(
              key: const ValueKey<String>('community-manage-voice-open'),
              height: SecondaryRowMetrics.functionRow,
              // S371 · decision 0297: ruled, 6 above and below (docs/58 §9.4).
              divider: true,
              padding: SecondaryRowMetrics.rowPadding,
              leading: LoopEntryIcon(
                'mic',
                size: SecondaryRowMetrics.functionGlyph,
                shape: LoopEntryIconShape.square,
              ),
              title: context.l10n.community_manageCommunityManageVoiceOpenTitle,
              subtitle:
                  context.l10n.community_manageCommunityManageVoiceOpenSubtitle,
              chevron: true,
              onTap: ref.watch(voiceRoomOpenControllerProvider)
                  ? null
                  : () => unawaited(
                      openCommunityVoiceRoom(
                        context,
                        ref,
                        detail,
                        onOpened: (communityId) => unawaited(
                          context.push<void>(
                            '/chat/voice?id='
                            '${Uri.encodeQueryComponent(communityId)}',
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          20,
          LoopSpacing.page,
          0,
        ),
        child: Text(
          isOwner
              ? context.l10n.community_manageCommunityManageLogoNote
              : context.l10n.community_manageCommunityManageLogoNote2,
          key: const ValueKey<String>('community-manage-logo-note'),
          style: LoopType.captionSm,
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  String _boundAssetLine(CommunitySummary community) {
    final key = community.boundAssetKey;
    if (key == null) return LoopL10n.current.community_manageBoundAssetLine;
    final asset = community.boundAsset;
    if (asset == null) {
      // An API that predates the `boundAsset` block: the key is all there is.
      return LoopL10n.current.community_manageIf(
        loopTruncatedAddress(key.split(':').last),
      );
    }
    final name = asset.name;
    final pool = asset.hasRegisteredPool
        ? LoopL10n.current.community_manageIf2
        : LoopL10n.current.community_manageS;
    return name == null || name == asset.symbol
        ? '${asset.symbol} · $pool'
        : '${asset.symbol} · $name · $pool';
  }

  Future<void> _editProfile(
    CommunityDetail detail, {
    required bool includeBoundAsset,
  }) async {
    final controller = ref.read(communityProfileControllerProvider.notifier);
    final edit = await showCommunityProfileEditSheet(
      context,
      community: detail.community,
      // Decision 0113: the bound token is the owner's field alone.
      includeBoundAsset: includeBoundAsset && detail.viewer.isOwner,
    );
    if (edit == null || !mounted) return;
    if (edit.isEmpty) {
      LoopToast.show(
        context,
        message: LoopL10n.current.community_manageMessage,
      );
      return;
    }
    final confirmed = await confirmCommunityAction(
      context,
      title: LoopL10n.current.community_manageTitle,
      body: edit.touchesBoundAsset
          ? LoopL10n.current.community_manageBody(communityBoundAssetUniqueHint)
          : LoopL10n.current.community_manageBody2,
      confirmLabel: LoopL10n.current.common_submit,
      sheetKey: 'community-edit-confirm-sheet',
    );
    if (!confirmed) return;
    final failure = await controller.submitProfileEdit(edit);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(
        context,
        message: LoopL10n.current.community_manageMessage2,
      );
      return;
    }
    LoopToast.show(
      context,
      message: communityProfileEditFailureText(failure),
      kind: LoopToastKind.err,
    );
  }
}

/// The sentence for a refused profile edit (decision 0113). A bound-token
/// refusal is worded by the server's `reasonCode`; everything else keeps the
/// shared copy for its kind.
String communityProfileEditFailureText(CommunityGatewayException failure) =>
    switch (failure.reasonCode) {
      _ when failure.kind == CommunityFailureKind.boundAssetTaken =>
        LoopL10n.current.community_manageBoundAssetTaken,
      'ASSET_NOT_REGISTERED' => LoopL10n.current.community_manageSwitch,
      'OWNER_ONLY_FIELD' => LoopL10n.current.community_manageSwitch2,
      _ => communityFailureReason(failure.kind),
    };
