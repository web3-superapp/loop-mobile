import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/post_auth_profile_redirect_coordinator.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_client_policy.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_controller.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

// ---------------------------------------------------------------------------
// Shared identity presentation
// ---------------------------------------------------------------------------

/// Renders the preset avatar for [avatarRef], falling back to the alias
/// monogram. A non-preset V1 value also renders as the monogram; it is never
/// resubmitted.
class LoopProfileAvatar extends StatelessWidget {
  const LoopProfileAvatar({
    required this.avatarRef,
    required this.alias,
    super.key,
    this.size = 72,
  });

  static const presetPrefix = 'avatar:preset/people-';

  final String? avatarRef;
  final String? alias;
  final double size;

  /// Maps the one-based catalog slot onto the 4x3 people atlas cell key.
  static String? peopleSlotKey(int slot) {
    if (slot < 1 || slot > 12) return null;
    final column = (slot - 1) % 4;
    final row = (slot - 1) ~/ 4;
    for (final entry in LoopIdentitySlots.people.entries) {
      if (entry.value.column == column && entry.value.row == row) {
        return entry.key;
      }
    }
    return null;
  }

  static String monogramFor(String? alias) {
    final trimmed = alias?.trim() ?? '';
    if (trimmed.isEmpty) return 'LO';
    final runes = trimmed.runes.take(2).toList(growable: false);
    return String.fromCharCodes(runes).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final monogram = monogramFor(alias);
    final reference = avatarRef;
    if (reference != null && reference.startsWith(presetPrefix)) {
      final slot = int.tryParse(reference.substring(presetPrefix.length));
      final key = slot == null ? null : peopleSlotKey(slot);
      if (key != null) {
        return LoopIdentityAvatar(
          key: ValueKey<String>('loop-profile-avatar-$reference'),
          atlas: LoopIdentityAtlas.people,
          slot: key,
          size: size,
          semanticLabel: '头像',
          fallbackMonogram: monogram,
        );
      }
    }
    return Container(
      key: const ValueKey<String>('loop-profile-avatar-monogram'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: LoopColors.card2,
        shape: BoxShape.circle,
      ),
      child: Text(
        monogram,
        style: LoopTypography.figure(size / 4.5, color: LoopColors.chalk),
      ),
    );
  }
}

/// `开发预览` eyebrow for a Preview-backed page. Production and unavailable
/// modes carry no kicker, so the label can never appear outside Preview.
String? loopPreviewKicker(bool isPreview) => isPreview ? '开发预览' : null;

/// Visible Preview truth label (constraint 10). Edits made here persist only
/// for the running Preview and never reach an account or a provider.
class LoopPreviewModeNotice extends StatelessWidget {
  const LoopPreviewModeNotice({
    required this.isPreview,
    required this.resource,
    super.key,
  });

  final bool isPreview;

  /// The resource name shown in the copy, e.g. `资料` or `隐私设置`.
  final String resource;

  @override
  Widget build(BuildContext context) {
    if (!isPreview) return const SizedBox.shrink();
    return LoopNotice(
      key: const ValueKey<String>('loop-preview-mode-notice'),
      icon: 'info',
      tone: LoopNoticeTone.warn,
      title: '开发预览',
      body: '$resource只保存在本次运行的内存里，不会写入账号，也不会调用任何 Provider。',
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    );
  }
}

/// The five reviewed states for a Profile-backed page.
///
/// [permission] is the server's own refusal — `403 PERMISSION_DENIED`,
/// `POLICY_BLOCKED`, `REGION_BLOCKED` or `AUTH_STEP_UP_REQUIRED`. It is not a
/// device permission and never a retryable error: the request arrived, was
/// understood, and was refused.
enum LoopResourcePhase {
  loading,
  empty,
  error,
  offline,
  permission,
  unavailable,
  ready,
}

LoopResourcePhase profileResourcePhase(ProfileState state) {
  if (state.phase == ProfilePhase.initial ||
      state.phase == ProfilePhase.loading) {
    return state.resource == null
        ? LoopResourcePhase.loading
        : LoopResourcePhase.ready;
  }
  if (state.resource != null) return LoopResourcePhase.ready;
  return switch (state.failureKind) {
    ProfileGatewayFailureKind.unavailable => LoopResourcePhase.unavailable,
    ProfileGatewayFailureKind.offline => LoopResourcePhase.offline,
    ProfileGatewayFailureKind.permissionDenied ||
    ProfileGatewayFailureKind.regionBlocked ||
    ProfileGatewayFailureKind.stepUpRequired => LoopResourcePhase.permission,
    null => LoopResourcePhase.empty,
    _ => LoopResourcePhase.error,
  };
}

LoopResourcePhase privacyResourcePhase(PrivacyState state) {
  if (state.phase == PrivacyPhase.initial ||
      state.phase == PrivacyPhase.loading) {
    return state.resource == null
        ? LoopResourcePhase.loading
        : LoopResourcePhase.ready;
  }
  if (state.resource != null) return LoopResourcePhase.ready;
  return switch (state.failureKind) {
    PrivacyGatewayFailureKind.unavailable => LoopResourcePhase.unavailable,
    PrivacyGatewayFailureKind.offline => LoopResourcePhase.offline,
    PrivacyGatewayFailureKind.permissionDenied ||
    PrivacyGatewayFailureKind.regionBlocked ||
    PrivacyGatewayFailureKind.stepUpRequired => LoopResourcePhase.permission,
    null => LoopResourcePhase.empty,
    _ => LoopResourcePhase.error,
  };
}

String profileFailureReason(ProfileGatewayFailureKind? kind) => switch (kind) {
  ProfileGatewayFailureKind.unavailable => '资料服务当前不可用，没有任何修改被保存。',
  ProfileGatewayFailureKind.offline => '设备当前离线，资料未能读取，也没有提交任何修改。',
  ProfileGatewayFailureKind.permissionDenied =>
    '当前策略不允许读取或修改账号资料，没有发生任何变化。'
        '这项权限不能在应用里自行调整。',
  ProfileGatewayFailureKind.regionBlocked =>
    '你所在的地区暂时不能读取或修改账号资料，没有发生任何变化。'
        '这与账号无关，换一个账号也不会改变结果。',
  ProfileGatewayFailureKind.stepUpRequired =>
    '这一步需要二次验证，二次验证还没有开放，没有发生任何变化。'
        '请到安全中心查看当前可用的验证方式。',
  ProfileGatewayFailureKind.versionConflict => '资料在别处已被修改。请重新载入后再保存。',
  ProfileGatewayFailureKind.idempotencyConflict => '提交冲突，已重置，请再试一次。',
  ProfileGatewayFailureKind.bootstrapRequired => '账号尚未完成初始化，请稍后重试。',
  ProfileGatewayFailureKind.validationFailed => '别名或简介超出长度限制，请修改后重试。',
  ProfileGatewayFailureKind.aliasReserved => '该名称属于 LOOP 保留词，请换一个再试。',
  ProfileGatewayFailureKind.aliasBlocked => '该名称包含不允许的词，请换一个再试。',
  ProfileGatewayFailureKind.invalidData => '服务返回的资料不符合约定，没有采纳任何内容。',
  ProfileGatewayFailureKind.unexpected => '资料操作没有完成，请稍后再试。',
  null => '资料操作没有完成。',
};

String privacyFailureReason(PrivacyGatewayFailureKind? kind) => switch (kind) {
  PrivacyGatewayFailureKind.unavailable => '隐私服务当前不可用，没有任何修改被保存。',
  PrivacyGatewayFailureKind.offline => '设备当前离线，隐私设置未能读取，也没有提交任何修改。',
  PrivacyGatewayFailureKind.permissionDenied =>
    '当前策略不允许读取或修改隐私设置，没有发生任何变化。'
        '这项权限不能在应用里自行调整；开关的当前状态以 LOOP 记录为准。',
  PrivacyGatewayFailureKind.regionBlocked =>
    '你所在的地区暂时不能读取或修改隐私设置，没有发生任何变化。'
        '这与账号无关，换一个账号也不会改变结果。',
  PrivacyGatewayFailureKind.stepUpRequired =>
    '修改隐私设置需要二次验证，二次验证还没有开放，没有发生任何变化。'
        '请到安全中心查看当前可用的验证方式。',
  PrivacyGatewayFailureKind.versionConflict => '隐私设置在别处已被修改。请重新载入后再保存。',
  PrivacyGatewayFailureKind.bootstrapRequired => '账号尚未完成初始化，请稍后重试。',
  PrivacyGatewayFailureKind.validationFailed => '提交的隐私设置不被接受，请检查后重试。',
  PrivacyGatewayFailureKind.invalidData => '服务返回的隐私设置不符合约定，没有采纳任何内容。',
  PrivacyGatewayFailureKind.unexpected => '隐私操作没有完成，请稍后再试。',
  null => '隐私操作没有完成。',
};

/// `.row` with a state badge on the right. It is a control, not a claim: the
/// badge repeats the stored preference only.
class LoopTogglePreferenceRow extends StatelessWidget {
  const LoopTogglePreferenceRow({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.subtitle,
    this.onLabel = '已开启',
    this.offLabel = '已关闭',
    this.position = LoopRowPosition.single,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final VoidCallback? onChanged;
  final String onLabel;
  final String offLabel;
  final LoopRowPosition position;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: LoopRecordRow(
        title: title,
        subtitle: subtitle,
        trailing: value ? onLabel : offLabel,
        onTap: onChanged,
        position: position,
        semanticLabel: '$title，${value ? onLabel : offLabel}',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// profile · dashboard / record
// ---------------------------------------------------------------------------

class ProfileHomeScreen extends ConsumerStatefulWidget {
  const ProfileHomeScreen({
    required this.onNavigate,
    super.key,
    this.onBack,
    this.onSignOut,
    this.walletAddress,
  });

  final ValueChanged<String> onNavigate;
  final VoidCallback? onBack;
  final Future<void> Function()? onSignOut;
  final String? walletAddress;

  @override
  ConsumerState<ProfileHomeScreen> createState() => _ProfileHomeScreenState();
}

class _ProfileHomeScreenState extends ConsumerState<ProfileHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    if (state.phase == ProfilePhase.initial) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(profileControllerProvider.notifier).load());
        }
      });
    }
    final resource = state.resource;
    final alias = resource?.values.alias;
    final phase = profileResourcePhase(state);
    final isPreview = state.mode == ProfileMode.preview;

    return LoopDashboardPage(
      archetype: LoopPageArchetype.record,
      title: '我的',
      kicker: loopPreviewKicker(isPreview),
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('profile-open-settings'),
          icon: 'settings',
          label: '设置',
          onPressed: () => widget.onNavigate('settings'),
        ),
      ],
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.lime,
        archetype: LoopFolioArchetype.record,
        kicker: 'PUBLIC PROFILE',
        heading: alias ?? '尚未设置别名',
        caption: 'LOOP ID 是你的社交身份；钱包地址只是可更换的凭证。',
        stamp: 'PUBLIC',
      ),
      sections: <Widget>[
        LoopPreviewModeNotice(isPreview: isPreview, resource: '资料'),
        if (phase != LoopResourcePhase.ready)
          _ProfileStateBlock(
            phase: phase,
            state: state,
            onRetry: () =>
                ref.read(profileControllerProvider.notifier).reload(),
            onOpenSecurity: () => widget.onNavigate('security'),
          )
        else
          _ProfileIdentityCard(
            resource: resource!,
            onEdit: () => widget.onNavigate('profile-edit'),
          ),
        const LoopLabel('LOOP'),
        const LoopEmpty(
          key: ValueKey<String>('profile-metrics-unavailable'),
          message: 'LOOP 余额、质押与算力暂不可读',
          reason: '资产与挖矿数据还没有开放，这里不显示任何数字。',
        ),
        const LoopLabel('我的社区'),
        ProfileCommunitiesRow(onNavigate: widget.onNavigate),
        const LoopLabel('Launch'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('profile-open-launch-history'),
              title: '参与记录',
              subtitle: 'Launch 参与数据还没有开放',
              trailing: '未开放',
              position: LoopRowPosition.first,
              onTap: () => widget.onNavigate('launch-history'),
            ),
            LoopRecordRow(
              key: const ValueKey<String>('profile-open-launch-tier'),
              title: '我的资格',
              subtitle: '质押与 Tier 数据还没有开放',
              trailing: '未开放',
              position: LoopRowPosition.last,
              onTap: () => widget.onNavigate('launch-tier'),
            ),
          ],
        ),
        const LoopLabel('账户'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('profile-open-wallets'),
              title: '我的钱包',
              subtitle: '绑定的钱包与地址',
              onTap: () => widget.onNavigate('wallets'),
            ),
            LoopRecordRow(
              key: const ValueKey<String>('profile-open-privacy'),
              title: '隐私中心',
              subtitle: '匿名模式、可见性与被搜索',
              onTap: () => widget.onNavigate('privacy'),
            ),
            LoopRecordRow(
              key: const ValueKey<String>('profile-open-security'),
              title: '安全中心',
              subtitle: '应用锁、MFA 与设备',
              onTap: () => widget.onNavigate('security'),
            ),
            LoopRecordRow(
              key: const ValueKey<String>('profile-open-friend-requests'),
              title: '好友请求',
              subtitle: '收到的好友申请（好友列表已折叠进搜索与关注）',
              onTap: () => widget.onNavigate('friend-requests'),
            ),
            LoopRecordRow(
              key: const ValueKey<String>('profile-open-connections'),
              title: '关注与粉丝',
              subtitle: '关注数据还没有开放',
              onTap: () => widget.onNavigate('connections'),
            ),
            LoopRecordRow(
              key: const ValueKey<String>('profile-open-notifications'),
              title: '通知设置',
              subtitle: '推送投递仍不可用',
              onTap: () => widget.onNavigate('notif-settings'),
            ),
          ],
        ),
        if (widget.onSignOut != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('profile-sign-out'),
              label: '退出登录',
              block: true,
              onPressed: () => unawaited(widget.onSignOut!()),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// The 我的社区 entry on `profile`.
///
/// Membership is not a profile fact. It is only ever the `joined` block of
/// `community`'s own home aggregate, so this row reads that aggregate through
/// the existing [CommunityHomeController] instead of adding a second source,
/// and states the aggregate's phase rather than claiming the relationship is
/// unconnected.
///
/// The row stays a navigation entry in every phase: a failure is reported
/// here in one line and carries the owner to the community directory, which
/// is the page that owns the full five-state block and its retry.
class ProfileCommunitiesRow extends ConsumerStatefulWidget {
  const ProfileCommunitiesRow({required this.onNavigate, super.key});

  /// Profile-screen destination id, resolved by the composition root.
  final ValueChanged<String> onNavigate;

  /// The paginated directory narrowed to the owner's own communities.
  static const joinedDestination = 'community-joined';

  /// The public directory, used whenever there is nothing joined to open.
  static const discoverDestination = 'community-discover';

  /// How many joined communities the subtitle names before the trailing count
  /// takes over.
  static const namedLimit = 2;

  @override
  ConsumerState<ProfileCommunitiesRow> createState() =>
      _ProfileCommunitiesRowState();
}

class _ProfileCommunitiesRowState extends ConsumerState<ProfileCommunitiesRow> {
  /// `名称（Owner）· 名称（成员）`, capped at [ProfileCommunitiesRow.namedLimit].
  /// A muted or banned membership reads as that state, not as its role.
  static String _namedCommunities(List<JoinedCommunity> joined) => joined
      .take(ProfileCommunitiesRow.namedLimit)
      .map(
        (entry) =>
            '${entry.community.name}（${communityMembershipLabel(entry.membership)}）',
      )
      .join(' · ');

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(communityHomeControllerProvider);
    final blocked = communityCapabilityBlocks(mode, capability);
    if (!blocked && state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(communityHomeControllerProvider.notifier).load());
        }
      });
    }

    final home = state.value;
    final isReady = state.phase == CommunityViewPhase.ready && home != null;
    final joined = home?.joined ?? const <JoinedCommunity>[];
    final truncated = home?.joinedTruncated ?? false;

    final String trailing;
    final String subtitle;
    if (blocked) {
      trailing = communityMissingFigure;
      subtitle = '社区模块当前不可用，未读取成员关系';
    } else if (isReady) {
      // `truncated` means the aggregate could not carry every membership, so
      // the count is a floor and is marked as one.
      trailing = truncated ? '${joined.length}+ 个已加入' : '${joined.length} 个已加入';
      subtitle = joined.isEmpty ? '还没有加入社区，从发现社区开始' : _namedCommunities(joined);
    } else {
      trailing = communityMissingFigure;
      subtitle = switch (state.phase) {
        CommunityViewPhase.loading => '正在读取社区成员关系',
        CommunityViewPhase.offline => '设备已离线，没有读到社区成员关系',
        CommunityViewPhase.unavailable => '社区服务当前不可用，未读取成员关系',
        CommunityViewPhase.permission => '需要先完成 LOOP ID 激活才能读取成员关系',
        // `empty` cannot reach here: a ready aggregate with no membership is
        // handled above, and this state carries no other empty answer.
        CommunityViewPhase.empty ||
        CommunityViewPhase.error ||
        CommunityViewPhase.ready => '社区成员关系读取失败，打开社区目录可重试',
      };
    }

    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        LoopRecordRow(
          key: const ValueKey<String>('profile-open-communities'),
          title: '我的社区',
          subtitle: subtitle,
          trailing: trailing,
          semanticLabel: '我的社区，$trailing，$subtitle',
          onTap: () => widget.onNavigate(
            isReady && joined.isNotEmpty
                ? ProfileCommunitiesRow.joinedDestination
                : ProfileCommunitiesRow.discoverDestination,
          ),
        ),
      ],
    );
  }
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({required this.resource, required this.onEdit});

  final ProfileResource resource;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final alias = resource.values.alias;
    final loopId = resource.loopId;
    return LoopChalkCard(
      key: const ValueKey<String>('profile-identity-card'),
      child: Column(
        children: <Widget>[
          LoopProfileAvatar(avatarRef: resource.values.avatarRef, alias: alias),
          const SizedBox(height: 10),
          Text(
            alias ?? '尚未设置别名',
            style: LoopTypography.heading(
              18,
              weight: FontWeight.w700,
              color: LoopColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            loopId ?? 'LOOP ID 不可读',
            style: LoopTypography.figure(
              11,
              weight: FontWeight.w500,
              color: LoopColors.ink.withValues(alpha: 0.64),
            ),
          ),
          if (resource.values.bio != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              resource.values.bio!,
              textAlign: TextAlign.center,
              style: LoopTypography.caption(
                12,
                color: LoopColors.ink.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // `.chalk-card .seg`: Ink ground with Chalk text, not the Lime fill.
          Semantics(
            button: true,
            label: '编辑资料',
            child: Material(
              color: LoopColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: LoopColors.ink),
              ),
              child: InkWell(
                key: const ValueKey<String>('profile-open-edit'),
                onTap: onEdit,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: LoopTouch.minimum,
                    minHeight: LoopTouch.minimum,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  child: ExcludeSemantics(
                    child: Text(
                      '编辑资料',
                      style: LoopTypography.label(
                        12,
                        weight: FontWeight.w700,
                        color: LoopColors.chalk,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStateBlock extends StatelessWidget {
  const _ProfileStateBlock({
    required this.phase,
    required this.state,
    required this.onRetry,
    this.onOpenSecurity,
  });

  final LoopResourcePhase phase;
  final ProfileState state;
  final VoidCallback onRetry;

  /// Only the permission block uses it: step-up is not delivered, so the one
  /// honest destination is the security centre.
  final VoidCallback? onOpenSecurity;

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      LoopResourcePhase.loading => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: LoopSkeleton(
          key: ValueKey<String>('profile-loading'),
          type: LoopSkeletonType.detail,
        ),
      ),
      LoopResourcePhase.offline => LoopOfflineState(
        key: const ValueKey<String>('profile-offline'),
        pausedActions: const <String>['保存资料', '激活 LOOP ID'],
        onRetry: onRetry,
      ),
      LoopResourcePhase.unavailable => LoopNotice(
        key: const ValueKey<String>('profile-unavailable'),
        icon: 'warn',
        tone: LoopNoticeTone.warn,
        title: '资料暂不可用',
        body: profileFailureReason(state.failureKind),
      ),
      LoopResourcePhase.empty => const LoopEmpty(
        key: ValueKey<String>('profile-empty'),
        message: '还没有可展示的资料',
        reason: '账号资料尚未读取。',
      ),
      // A refusal is not an error: the request arrived and the server answered
      // "no". Retrying it would claim otherwise, so the block offers the only
      // real next step instead.
      LoopResourcePhase.permission => LoopPermissionState(
        key: const ValueKey<String>('profile-permission'),
        icon: 'shield',
        denied: true,
        title: state.failureKind == ProfileGatewayFailureKind.stepUpRequired
            ? '这一步需要二次验证'
            : state.failureKind == ProfileGatewayFailureKind.regionBlocked
            ? '当前地区不能读取或修改资料'
            : '当前账号无权读取或修改资料',
        purpose: profileFailureReason(state.failureKind),
        settingsLabel: '前往安全中心',
        onOpenSettings: onOpenSecurity,
      ),
      LoopResourcePhase.error => LoopErrorState(
        key: const ValueKey<String>('profile-error'),
        reason: profileFailureReason(state.failureKind),
        source: '资料服务',
        onRetry: onRetry,
      ),
      // The owner renders the resource itself; a ready state must never reach
      // a state block.
      LoopResourcePhase.ready => throw StateError(
        'a ready Profile must not render a state block',
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// profile-edit · focus / action
// ---------------------------------------------------------------------------

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({required this.onNavigate, super.key, this.onBack});

  final ValueChanged<String> onNavigate;
  final VoidCallback? onBack;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _aliasController = TextEditingController();
  final _bioController = TextEditingController();
  String? _syncedAlias;
  String? _syncedBio;
  String? _validationMessage;

  @override
  void dispose() {
    _aliasController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    if (state.phase == ProfilePhase.initial) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(profileControllerProvider.notifier).load());
        }
      });
    }
    final controller = ref.read(profileControllerProvider.notifier);
    _syncEditors(state);
    _convergeAvatarRef(controller, state);
    final phase = profileResourcePhase(state);
    final avatarUpload = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.avatarUpload),
    );

    return LoopFocusPage(
      archetype: LoopPageArchetype.action,
      title: '编辑资料',
      kicker: loopPreviewKicker(state.mode == ProfileMode.preview),
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.action,
        kicker: 'PROFILE EDIT',
        heading: state.draft.alias ?? '尚未设置别名',
        caption: '别名、头像、简介与关注赛道可修改；LOOP ID 与钱包地址保持不同边界。',
        stamp: 'PUBLIC',
        compact: true,
      ),
      primaryAction: LoopButton(
        key: const ValueKey<String>('profile-edit-save'),
        label: state.phase == ProfilePhase.saving ? '保存中…' : '保存',
        primary: true,
        block: true,
        onPressed: state.canSave && state.phase != ProfilePhase.saving
            ? () => unawaited(_save(controller))
            : null,
      ),
      body: <Widget>[
        LoopPreviewModeNotice(
          isPreview: state.mode == ProfileMode.preview,
          resource: '资料',
        ),
        if (phase != LoopResourcePhase.ready)
          _ProfileStateBlock(
            phase: phase,
            state: state,
            onRetry: controller.reload,
            onOpenSecurity: () => widget.onNavigate('security'),
          )
        else ...<Widget>[
          if (state.requiresReload)
            LoopNotice(
              key: const ValueKey<String>('profile-edit-conflict'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '资料已在别处修改',
              body: profileFailureReason(state.failureKind),
              trailing: LoopButton(label: '重新载入', onPressed: controller.reload),
            ),
          if (_validationMessage != null)
            LoopNotice(
              key: const ValueKey<String>('profile-edit-validation'),
              icon: 'warn',
              tone: LoopNoticeTone.danger,
              title: '无法保存',
              body: _validationMessage!,
            ),
          // A failed save must never look like a success. The draft is kept
          // and the sanitized reason is shown next to the save action.
          if (state.phase == ProfilePhase.failure)
            switch (state.failureKind) {
              ProfileGatewayFailureKind.offline => LoopOfflineState(
                key: const ValueKey<String>('profile-edit-offline'),
                pausedActions: const <String>['保存资料'],
                onRetry: () => unawaited(_save(controller)),
              ),
              ProfileGatewayFailureKind.permissionDenied ||
              ProfileGatewayFailureKind.regionBlocked ||
              ProfileGatewayFailureKind.stepUpRequired => LoopPermissionState(
                key: const ValueKey<String>('profile-edit-permission'),
                icon: 'shield',
                denied: true,
                title:
                    state.failureKind ==
                        ProfileGatewayFailureKind.stepUpRequired
                    ? '这一步需要二次验证'
                    : state.failureKind ==
                          ProfileGatewayFailureKind.regionBlocked
                    ? '当前地区不能修改资料'
                    : '当前账号无权修改资料',
                purpose: profileFailureReason(state.failureKind),
                settingsLabel: '前往安全中心',
                onOpenSettings: () => widget.onNavigate('security'),
              ),
              _ => LoopNotice(
                key: const ValueKey<String>('profile-edit-failure'),
                icon: 'close',
                tone: LoopNoticeTone.danger,
                title: '保存未完成',
                body: profileFailureReason(state.failureKind),
              ),
            },
          _AvatarPickerCard(
            selected: state.draft.avatarRef,
            alias: state.draft.alias,
            enabled: state.canEdit,
            uploadUsable: avatarUpload.isUsable,
            onSelected: controller.editAvatarRef,
          ),
          const LoopLabel('别名'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LoopSurfaceCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const ValueKey<String>('profile-edit-alias-field'),
                      controller: _aliasController,
                      enabled: state.canEdit,
                      maxLength: 40,
                      buildCounter: (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) => null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '例如 Voyager_7',
                      ),
                      onChanged: (value) => _applyAlias(controller, value),
                    ),
                  ),
                  LoopSeg(
                    key: const ValueKey<String>('profile-edit-alias-suggest'),
                    label: '换一个',
                    selected: false,
                    onSelected: state.canEdit
                        ? () => _suggestAlias(controller)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const LoopLabel('简介'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LoopSurfaceCard(
              child: TextField(
                key: const ValueKey<String>('profile-edit-bio-field'),
                controller: _bioController,
                enabled: state.canEdit,
                maxLength: 160,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '一句话介绍自己（可留空）',
                ),
                onChanged: (value) => _applyBio(controller, value),
              ),
            ),
          ),
          const LoopLabel('关注赛道'),
          _InterestChips(
            selected: state.draft.interests,
            enabled: state.canEdit,
            onToggle: (interest) => _toggleInterest(controller, interest),
          ),
          const LoopLabel('公开范围'),
          LoopRecordRow(
            key: const ValueKey<String>('profile-edit-open-privacy'),
            title: '隐私中心',
            subtitle: '总资产、算力、社区与交易记录的可见性在这里设置',
            onTap: () => widget.onNavigate('privacy'),
          ),
          const LoopNotice(
            icon: 'info',
            title: '别名可以重复',
            body: 'LOOP ID 唯一且不可更改；别名只是别人看到的名字，随时可改。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
          ),
        ],
      ],
    );
  }

  /// A V1 row may hold a non-preset avatar reference. It renders as the
  /// monogram, but the draft drops it so a save can never resubmit it.
  void _convergeAvatarRef(ProfileController controller, ProfileState state) {
    if (!state.canEdit || state.draft.avatarRef == null) return;
    if (isProfilePresetAvatarRef(state.draft.avatarRef)) return;
    scheduleMicrotask(() {
      if (!mounted) return;
      final current = ref.read(profileControllerProvider);
      if (!current.canEdit ||
          isProfilePresetAvatarRef(current.draft.avatarRef)) {
        return;
      }
      ref.read(profileControllerProvider.notifier).editAvatarRef(null);
    });
  }

  void _syncEditors(ProfileState state) {
    final alias = state.draft.alias ?? '';
    if (_syncedAlias != alias && _aliasController.text != alias) {
      _aliasController.text = alias;
    }
    _syncedAlias = alias;
    final bio = state.draft.bio ?? '';
    if (_syncedBio != bio && _bioController.text != bio) {
      _bioController.text = bio;
    }
    _syncedBio = bio;
  }

  void _applyAlias(ProfileController controller, String value) {
    try {
      controller.editAlias(value.trim().isEmpty ? null : value);
      setState(() => _validationMessage = null);
    } on InvalidProfileContractException {
      setState(() => _validationMessage = '别名需要 1–40 个字符，且不能包含不可见字符。');
    } on StateError {
      // The draft is locked by a pending reload; the notice already says so.
    }
  }

  void _applyBio(ProfileController controller, String value) {
    try {
      controller.editBio(value);
      setState(() => _validationMessage = null);
    } on InvalidProfileContractException {
      setState(() => _validationMessage = '简介最多 160 个字符。');
    } on StateError {
      // The draft is locked by a pending reload.
    }
  }

  void _toggleInterest(ProfileController controller, ProfileInterest value) {
    try {
      controller.toggleInterest(value);
      setState(() => _validationMessage = null);
    } on InvalidProfileContractException {
      setState(() => _validationMessage = '最多可以选择 6 个赛道。');
    } on StateError {
      // The draft is locked by a pending reload.
    }
  }

  void _suggestAlias(ProfileController controller) {
    final suggestion = loopLocalAliasSuggestion();
    _aliasController.text = suggestion;
    _applyAlias(controller, suggestion);
  }

  Future<void> _save(ProfileController controller) async {
    final expectedVersion = ref.read(profileControllerProvider).expectedVersion;
    await controller.save();
    if (!mounted) return;
    final state = ref.read(profileControllerProvider);
    final version = state.resource?.version;
    // The only evidence of a save is an advanced committed resource. The
    // toast repeats that exact version instead of claiming success.
    if (state.phase == ProfilePhase.ready &&
        !state.isDirty &&
        version != null &&
        expectedVersion != null &&
        version > expectedVersion) {
      LoopToast.show(context, message: '已提交到版本 $version');
    }
  }
}

class _AvatarPickerCard extends ConsumerWidget {
  const _AvatarPickerCard({
    required this.selected,
    required this.alias,
    required this.enabled,
    required this.uploadUsable,
    required this.onSelected,
  });

  final String? selected;
  final String? alias;
  final bool enabled;

  /// Whether the backend has opened custom avatar upload. While it is closed
  /// the card says so once; the capability's own code stays off the screen.
  final bool uploadUsable;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(avatarCatalogProvider);
    return LoopChalkCard(
      key: const ValueKey<String>('profile-avatar-picker'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: LoopProfileAvatar(avatarRef: selected, alias: alias),
          ),
          const SizedBox(height: 12),
          catalog.when(
            loading: () => const LoopSkeleton(
              key: ValueKey<String>('profile-avatar-loading'),
              type: LoopSkeletonType.list,
              rows: 1,
            ),
            error: (error, stackTrace) => Text(
              key: const ValueKey<String>('profile-avatar-unavailable'),
              '预设头像清单暂不可读，保留当前头像。',
              textAlign: TextAlign.center,
              style: LoopTypography.caption(
                12,
                color: LoopColors.ink.withValues(alpha: 0.72),
              ),
            ),
            data: (presets) => Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final preset in presets)
                  _AvatarChoice(
                    preset: preset,
                    alias: alias,
                    selected: preset.isMonogram
                        ? selected == null || selected == preset.avatarRef
                        : selected == preset.avatarRef,
                    onTap: enabled
                        ? () => onSelected(
                            preset.isMonogram ? null : preset.avatarRef,
                          )
                        : null,
                  ),
              ],
            ),
          ),
          if (!uploadUsable) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '自定义头像上传暂不可用，只能选择预设头像。',
              textAlign: TextAlign.center,
              style: LoopTypography.caption(
                11,
                color: LoopColors.ink.withValues(alpha: 0.64),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.preset,
    required this.alias,
    required this.selected,
    required this.onTap,
  });

  final AvatarPreset preset;
  final String? alias;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: preset.label,
      enabled: onTap != null,
      child: InkWell(
        key: ValueKey<String>('profile-avatar-${preset.avatarRef}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: LoopTouch.minimum,
          height: LoopTouch.minimum,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? LoopColors.ink : Colors.transparent,
              width: 2,
            ),
          ),
          child: ExcludeSemantics(
            child: LoopProfileAvatar(
              avatarRef: preset.isMonogram ? null : preset.avatarRef,
              alias: alias,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestChips extends StatelessWidget {
  const _InterestChips({
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final List<ProfileInterest> selected;
  final bool enabled;
  final ValueChanged<ProfileInterest> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: <Widget>[
          for (final interest in ProfileInterest.values)
            LoopSeg(
              key: ValueKey<String>('interest-${interest.wireValue}'),
              label: interest.label,
              selected: selected.contains(interest),
              onSelected: enabled ? () => onToggle(interest) : null,
            ),
        ],
      ),
    );
  }
}

/// Local, clearly-labelled alias suggestion. It is never checked for
/// uniqueness: aliases may repeat and the backend owns every rejection.
String loopLocalAliasSuggestion([int? seed]) {
  const stems = <String>[
    'Voyager',
    'Signal',
    'Ledger',
    'Orbit',
    'Cipher',
    'Harbor',
    'Nimbus',
    'Quartz',
  ];
  final value = seed ?? DateTime.now().microsecondsSinceEpoch;
  final stem = stems[value.abs() % stems.length];
  final suffix = (value.abs() ~/ stems.length) % 90 + 10;
  return '${stem}_$suffix';
}

// ---------------------------------------------------------------------------
// privacy · focus / action
// ---------------------------------------------------------------------------

class PrivacyCenterScreen extends ConsumerStatefulWidget {
  const PrivacyCenterScreen({required this.onNavigate, super.key, this.onBack});

  final ValueChanged<String> onNavigate;
  final VoidCallback? onBack;

  @override
  ConsumerState<PrivacyCenterScreen> createState() =>
      _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends ConsumerState<PrivacyCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(privacyControllerProvider);
    if (state.phase == PrivacyPhase.initial) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(privacyControllerProvider.notifier).load());
        }
      });
    }
    final controller = ref.read(privacyControllerProvider.notifier);
    final phase = privacyResourcePhase(state);
    final draft = state.draft;

    return LoopFocusPage(
      archetype: LoopPageArchetype.action,
      title: '隐私中心',
      kicker: loopPreviewKicker(state.mode == PrivacyMode.preview),
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.action,
        kicker: 'PRIVACY STATUS',
        heading: draft.anonymousMode ? '匿名模式已开启' : '匿名模式已关闭',
        caption: '公开身份、可见性与地址显示分别控制。这些只是展示偏好，不构成任何授权。',
        stamp: draft.anonymousMode ? 'ON' : 'OFF',
        compact: true,
      ),
      primaryAction: LoopButton(
        key: const ValueKey<String>('privacy-save'),
        label: state.phase == PrivacyPhase.saving ? '保存中…' : '保存',
        primary: true,
        block: true,
        onPressed: state.canSave && state.phase != PrivacyPhase.saving
            ? () => unawaited(_save(controller))
            : null,
      ),
      body: <Widget>[
        LoopPreviewModeNotice(
          isPreview: state.mode == PrivacyMode.preview,
          resource: '隐私设置',
        ),
        if (phase != LoopResourcePhase.ready)
          _PrivacyStateBlock(
            phase: phase,
            state: state,
            onRetry: controller.reload,
            onOpenSecurity: () => widget.onNavigate('security'),
          )
        else ...<Widget>[
          if (state.requiresReload)
            LoopNotice(
              key: const ValueKey<String>('privacy-conflict'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '隐私设置已在别处修改',
              body: privacyFailureReason(state.failureKind),
              trailing: LoopButton(label: '重新载入', onPressed: controller.reload),
            ),
          // A save that did not commit must say so next to the switches it
          // failed to change; a silent no-op reads as "saved". Offline keeps
          // its own block: nothing was submitted, so it pauses, not fails.
          if (!state.requiresReload && state.phase == PrivacyPhase.failure)
            switch (state.failureKind) {
              PrivacyGatewayFailureKind.offline => LoopOfflineState(
                key: const ValueKey<String>('privacy-save-offline'),
                pausedActions: const <String>['保存隐私设置'],
                onRetry: () => unawaited(_save(controller)),
              ),
              // The server answered: it refused. Offering a retry would claim
              // the refusal might not hold, so the block offers the only real
              // next step instead.
              PrivacyGatewayFailureKind.permissionDenied ||
              PrivacyGatewayFailureKind.regionBlocked ||
              PrivacyGatewayFailureKind.stepUpRequired => LoopPermissionState(
                key: const ValueKey<String>('privacy-save-permission'),
                icon: 'shield',
                denied: true,
                title:
                    state.failureKind ==
                        PrivacyGatewayFailureKind.stepUpRequired
                    ? '这一步需要二次验证'
                    : state.failureKind ==
                          PrivacyGatewayFailureKind.regionBlocked
                    ? '当前地区不能修改隐私设置'
                    : '当前账号无权修改隐私设置',
                purpose: privacyFailureReason(state.failureKind),
                settingsLabel: '前往安全中心',
                onOpenSettings: () => widget.onNavigate('security'),
              ),
              _ => LoopNotice(
                key: const ValueKey<String>('privacy-save-failure'),
                icon: 'close',
                tone: LoopNoticeTone.danger,
                title: '保存未完成',
                body: privacyFailureReason(state.failureKind),
              ),
            },
          const LoopLabel('身份'),
          LoopTogglePreferenceRow(
            key: const ValueKey<String>('privacy-anonymous-mode'),
            title: '匿名模式',
            subtitle: '只显示别名，不显示钱包地址',
            value: draft.anonymousMode,
            position: LoopRowPosition.first,
            onChanged: state.canEdit
                ? () => controller.editAnonymousMode(!draft.anonymousMode)
                : null,
          ),
          LoopTogglePreferenceRow(
            key: const ValueKey<String>('privacy-discoverable'),
            title: '显示 LOOP ID',
            subtitle: '别人可以通过 ID 找到你',
            value: draft.discoverable,
            position: LoopRowPosition.last,
            onChanged: state.canEdit
                ? () => controller.editDiscoverable(!draft.discoverable)
                : null,
          ),
          const LoopLabel('可见性'),
          for (final facet in PrivacyVisibilityFacet.values)
            LoopTogglePreferenceRow(
              key: ValueKey<String>('privacy-visibility-${facet.wireValue}'),
              title: facet.label,
              value: draft.visibility[facet] == PrivacyAudience.everyone,
              onLabel: '所有人',
              offLabel: '仅自己',
              position: facet == PrivacyVisibilityFacet.values.first
                  ? LoopRowPosition.first
                  : facet == PrivacyVisibilityFacet.values.last
                  ? LoopRowPosition.last
                  : LoopRowPosition.middle,
              onChanged: state.canEdit
                  ? () => controller.editVisibility(
                      facet,
                      draft.visibility[facet] == PrivacyAudience.everyone
                          ? PrivacyAudience.self
                          : PrivacyAudience.everyone,
                    )
                  : null,
            ),
          LoopRecordRow(
            key: const ValueKey<String>('privacy-open-blocklist'),
            title: '屏蔽名单',
            onTap: () => widget.onNavigate('blocklist'),
          ),
          const LoopNotice(
            icon: 'info',
            title: '可见性不是授权',
            body: '这些开关只影响展示。它们不会建立社交关系，也不会让别人复制你的交易或访问你的钱包。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
          ),
        ],
      ],
      disclosure: LoopDisclosure(
        summary: '隐私状态说明',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Text(
            draft.anonymousMode
                ? '公开别名，不公开钱包地址与资产明细。'
                : '别名与钱包地址都可能出现在公开位置；关闭前请先确认。',
            style: LoopTypography.caption(11, color: LoopColors.text2),
          ),
        ),
      ),
    );
  }

  Future<void> _save(PrivacyController controller) async {
    final expectedVersion = ref.read(privacyControllerProvider).expectedVersion;
    await controller.save();
    if (!mounted) return;
    final state = ref.read(privacyControllerProvider);
    final version = state.resource?.version;
    // Only an advanced committed resource is evidence. The toast repeats that
    // exact version; it never announces that preferences took effect.
    if (state.phase == PrivacyPhase.ready &&
        !state.isDirty &&
        version != null &&
        expectedVersion != null &&
        version > expectedVersion) {
      LoopToast.show(context, message: '已提交到版本 $version');
    }
  }
}

class _PrivacyStateBlock extends StatelessWidget {
  const _PrivacyStateBlock({
    required this.phase,
    required this.state,
    required this.onRetry,
    this.onOpenSecurity,
  });

  final LoopResourcePhase phase;
  final PrivacyState state;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSecurity;

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      LoopResourcePhase.loading => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: LoopSkeleton(
          key: ValueKey<String>('privacy-loading'),
          type: LoopSkeletonType.list,
        ),
      ),
      LoopResourcePhase.offline => LoopOfflineState(
        key: const ValueKey<String>('privacy-offline'),
        pausedActions: const <String>['保存隐私设置'],
        onRetry: onRetry,
      ),
      LoopResourcePhase.unavailable => LoopNotice(
        key: const ValueKey<String>('privacy-unavailable'),
        icon: 'warn',
        tone: LoopNoticeTone.warn,
        title: '隐私设置暂不可用',
        body: privacyFailureReason(state.failureKind),
      ),
      LoopResourcePhase.empty => const LoopEmpty(
        key: ValueKey<String>('privacy-empty'),
        message: '还没有可展示的隐私设置',
        reason: '隐私偏好尚未读取。',
      ),
      LoopResourcePhase.permission => LoopPermissionState(
        key: const ValueKey<String>('privacy-permission'),
        icon: 'shield',
        denied: true,
        title: state.failureKind == PrivacyGatewayFailureKind.stepUpRequired
            ? '这一步需要二次验证'
            : state.failureKind == PrivacyGatewayFailureKind.regionBlocked
            ? '当前地区不能读取或修改隐私设置'
            : '当前账号无权读取或修改隐私设置',
        purpose: privacyFailureReason(state.failureKind),
        settingsLabel: '前往安全中心',
        onOpenSettings: onOpenSecurity,
      ),
      LoopResourcePhase.error => LoopErrorState(
        key: const ValueKey<String>('privacy-error'),
        reason: privacyFailureReason(state.failureKind),
        source: '隐私服务',
        onRetry: onRetry,
      ),
      LoopResourcePhase.ready => throw StateError(
        'a ready Privacy resource must not render a state block',
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Post-login profile availability notice
// ---------------------------------------------------------------------------

/// Shown inside the shell when the post-login `GET /v2/profile` check failed.
///
/// Login is never blocked by that failure, so the banner is the only place
/// that says so. It claims nothing about the stored profile, and the check
/// runs again on the next start.
class ProfileAvailabilityBanner extends ConsumerWidget {
  const ProfileAvailabilityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(loopProfileLandingProvider);
    if (!landing.isUnavailable) return const SizedBox.shrink();
    return LoopNotice(
      key: const ValueKey<String>('profile-availability-banner'),
      icon: 'warn',
      tone: LoopNoticeTone.warn,
      title: '资料状态暂不可读',
      body: '${profileFailureReason(landing.failureKind)} 你可以继续浏览；下次启动会重新检查。',
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    );
  }
}

// ---------------------------------------------------------------------------
// Soft update prompt (S1 batch B ruling, delivered in step 2)
// ---------------------------------------------------------------------------

/// Dismissible prompt for `updateRecommended`.
///
/// `updateRequired` is not shown here: it keeps its own blocking system page.
/// An unavailable, not-yet-effective or unparsable version gate shows nothing,
/// because "unknown" is never "out of date".
class LoopSoftUpdatePrompt extends ConsumerStatefulWidget {
  const LoopSoftUpdatePrompt({super.key});

  @override
  ConsumerState<LoopSoftUpdatePrompt> createState() =>
      _LoopSoftUpdatePromptState();
}

class _LoopSoftUpdatePromptState extends ConsumerState<LoopSoftUpdatePrompt> {
  /// Run-local only. Dismissing is a convenience, never a stored decision.
  String? _dismissedConfigVersion;

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(loopVersionPolicyProvider);
    if (version.decision != LoopVersionPolicyDecision.updateRecommended ||
        _dismissedConfigVersion == version.configVersion) {
      return const SizedBox.shrink();
    }
    final minimum = version.minimumVersion;
    return LoopNotice(
      key: const ValueKey<String>('loop-soft-update-prompt'),
      icon: 'info',
      title: '有新版本可用',
      body: minimum == null
          ? '建议更新到最新版本；当前版本仍然可以继续使用。'
          : '建议更新到 $minimum 或更高版本；当前版本仍然可以继续使用。',
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      trailing: LoopIconButton(
        key: const ValueKey<String>('loop-soft-update-dismiss'),
        icon: 'close',
        label: '忽略更新提示',
        onPressed: () =>
            setState(() => _dismissedConfigVersion = version.configVersion),
      ),
    );
  }
}
