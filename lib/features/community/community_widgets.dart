import 'package:flutter/material.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// `开发预览` eyebrow for a Preview-backed S3 page. Production and unavailable
/// modes carry no kicker, so the label can never appear outside Preview.
String? communityPreviewKicker(CommunityGatewayMode mode) =>
    mode == CommunityGatewayMode.preview ? '开发预览' : null;

/// Whether the page must stop at the capability gate instead of reading.
///
/// The explicit Development Preview adapter makes no server claim and is
/// visibly labelled `演示数据`, so it is not gated by the public capability
/// document — which a Preview session never observes.
bool communityCapabilityBlocks(
  CommunityGatewayMode mode,
  LoopCapabilityProjection capability,
) => mode != CommunityGatewayMode.preview && !capability.isAvailable;

/// Visible Preview truth label. Reads and writes made here stay in the
/// running Preview and never reach an account or a provider.
class CommunityPreviewNotice extends StatelessWidget {
  const CommunityPreviewNotice({
    required this.mode,
    required this.resource,
    super.key,
  });

  final CommunityGatewayMode mode;
  final String resource;

  @override
  Widget build(BuildContext context) {
    if (mode != CommunityGatewayMode.preview) return const SizedBox.shrink();
    return LoopNotice(
      key: const ValueKey<String>('community-preview-notice'),
      icon: 'info',
      tone: LoopNoticeTone.warn,
      title: '演示数据',
      body: '$resource只存在于本次开发预览运行中，不会写入账号，也不会调用任何服务端。',
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    );
  }
}

/// The one place the five reviewed states are rendered for an S3 page.
class CommunityStateBlock extends StatelessWidget {
  const CommunityStateBlock({
    required this.phase,
    required this.failureKind,
    super.key,
    this.onRetry,
    this.emptyMessage = '这里还没有内容',
    this.emptyReason,
    this.permissionTitle = '当前账号没有权限',
    this.skeleton = LoopSkeletonType.list,
    this.rows = 3,
  });

  final CommunityViewPhase phase;
  final CommunityFailureKind? failureKind;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final String? emptyReason;
  final String permissionTitle;
  final LoopSkeletonType skeleton;
  final int rows;

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case CommunityViewPhase.loading:
        return LoopSkeleton(
          key: const ValueKey<String>('community-state-loading'),
          type: skeleton,
          rows: rows,
        );
      case CommunityViewPhase.empty:
        return LoopEmpty(
          key: const ValueKey<String>('community-state-empty'),
          message: emptyMessage,
          reason: emptyReason,
        );
      case CommunityViewPhase.offline:
        return LoopOfflineState(
          key: const ValueKey<String>('community-state-offline'),
          onRetry: onRetry,
          pausedActions: const <String>['加入', '关注', '屏蔽', '治理'],
        );
      case CommunityViewPhase.unavailable:
        return LoopEmpty(
          key: const ValueKey<String>('community-state-unavailable'),
          icon: 'warn',
          message: '该功能当前不可用',
          reason: communityFailureReason(failureKind),
        );
      case CommunityViewPhase.permission:
        return LoopPermissionState(
          key: const ValueKey<String>('community-state-permission'),
          icon: 'shield',
          title: permissionTitle,
          purpose: communityFailureReason(failureKind),
        );
      case CommunityViewPhase.error:
        return LoopErrorState(
          key: const ValueKey<String>('community-state-error'),
          reason: communityFailureReason(failureKind),
          onRetry: onRetry,
        );
      case CommunityViewPhase.ready:
        return const SizedBox.shrink();
    }
  }
}

/// Renders one `{status: unavailable, reasonCode}` field. It never renders a
/// figure, a zero, or a fixture in place of the missing fact.
class CommunityUnavailableCard extends StatelessWidget {
  const CommunityUnavailableCard({
    required this.label,
    required this.fact,
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String label;
  final LoopUnavailableFact fact;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return LoopEmpty(
      key: ValueKey<String>('community-unavailable-${fact.reasonCode}'),
      message: label,
      reason: communityUnavailableReason(fact.reasonCode),
      margin: margin,
    );
  }
}

/// The em dash used wherever a real figure has no source. Never `0`.
const String communityMissingFigure = '—';

String communityMemberCountLabel(int? memberCount) =>
    memberCount == null ? communityMissingFigure : '$memberCount 名成员';

/// Square monogram tile for a community.
///
/// `logoRef` is a `avatar:preset/community-01..12` reference the frozen local
/// atlas does not carry, so the tile shows the community's own initials rather
/// than an unrelated preset image.
class CommunityLogoTile extends StatelessWidget {
  const CommunityLogoTile({required this.name, super.key, this.size = 44});

  final String name;
  final double size;

  static String monogramFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'LO';
    final runes = trimmed.runes.take(2).toList(growable: false);
    return String.fromCharCodes(runes).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopColors.card2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        monogramFor(name),
        style: LoopTypography.mono(
          size: size / 3.4,
          weight: FontWeight.w600,
          color: LoopColors.chalk,
        ),
      ),
    );
  }
}

/// One community row. The subtitle only ever carries server-maintained facts.
///
/// It is a function, not a widget, because [LoopRecordGroup] needs the row
/// instances themselves to draw its dividers.
LoopRecordRow communityDirectoryRow({
  required CommunitySummary community,
  required VoidCallback? onTap,
  LoopRowPosition position = LoopRowPosition.single,
}) {
  final verification = switch (community.verificationStatus) {
    CommunityVerification.verified => '已验证',
    CommunityVerification.pending => '审核中',
    CommunityVerification.rejected => '未通过',
  };
  return LoopRecordRow(
    key: ValueKey<String>('community-row-${community.communityId}'),
    leading: CommunityLogoTile(name: community.name),
    title: community.name,
    subtitle: '${community.slug} · $verification',
    trailing: '${community.memberCount}',
    trailingCaption: '成员',
    onTap: onTap,
    position: position,
    semanticLabel:
        '${community.name}，$verification，${community.memberCount} 名成员',
  );
}

/// Row position inside a group of [length] rows.
LoopRowPosition communityRowPosition(int index, int length) {
  if (length <= 1) return LoopRowPosition.single;
  if (index == 0) return LoopRowPosition.first;
  if (index == length - 1) return LoopRowPosition.last;
  return LoopRowPosition.middle;
}

/// Server observation time in UTC. The client never restates it as a local
/// wall clock or as a relative "just now".
String communityObservedAtLabel(DateTime observedAt) {
  final value = observedAt.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)} UTC';
}

/// Second confirmation for a governance or relationship action.
///
/// The sheet states exactly what the server will be asked to do. It never
/// promises the outcome: the caller shows a success Toast only after a 2xx.
Future<bool> confirmCommunityAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String cancelLabel = '取消',
  String sheetKey = 'community-confirm-sheet',
}) async {
  final confirmed = await showLoopSheet<bool>(
    context,
    barrierLabel: '关闭确认弹层',
    builder: (sheetContext) => Padding(
      key: ValueKey<String>(sheetKey),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: LoopTypography.sora(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: LoopTypography.sora(
              size: 13,
              weight: FontWeight.w500,
              color: LoopColors.muted,
            ),
          ),
          const SizedBox(height: 18),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('community-confirm-accept'),
                label: confirmLabel,
                primary: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              LoopButton(
                key: const ValueKey<String>('community-confirm-cancel'),
                label: cancelLabel,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

/// Owner-only community profile edit sheet.
///
/// `slug` and `verificationStatus` are not editable and are shown read-only,
/// so the sheet can never submit a field the server would reject.
Future<CommunityProfileEdit?> showCommunityProfileEditSheet(
  BuildContext context, {
  required CommunitySummary community,
}) {
  final nameController = TextEditingController(text: community.name);
  final descriptionController = TextEditingController(
    text: community.description ?? '',
  );
  return showLoopSheet<CommunityProfileEdit>(
    context,
    barrierLabel: '关闭社区资料编辑',
    builder: (sheetContext) => Padding(
      key: const ValueKey<String>('community-edit-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '编辑社区资料',
            style: LoopTypography.sora(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('community-edit-name'),
            controller: nameController,
            decoration: const InputDecoration(labelText: '社区名称'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('community-edit-description'),
            controller: descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '简介（可留空）'),
          ),
          const SizedBox(height: 12),
          LoopKeyValue(
            label: '短链接（不可修改）',
            value: community.slug,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('community-edit-submit'),
                label: '下一步',
                primary: true,
                onPressed: () {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();
                  Navigator.of(sheetContext).pop(
                    CommunityProfileEdit(
                      name: name == community.name || name.isEmpty
                          ? null
                          : name,
                      description:
                          description.isEmpty ||
                              description == community.description
                          ? null
                          : description,
                      clearDescription:
                          description.isEmpty && community.description != null,
                    ),
                  );
                },
              ),
              LoopButton(
                key: const ValueKey<String>('community-edit-cancel'),
                label: '取消',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    nameController.dispose();
    descriptionController.dispose();
  });
}
