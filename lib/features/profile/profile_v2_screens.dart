import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/post_auth_profile_redirect_coordinator.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_client_policy.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/notifications/community_application_notifications.dart';
import 'package:loop_mobile/features/notifications/notification_controllers.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_editor.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_controller.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/sign_out_button.dart';
import 'package:loop_mobile/features/social/loop_id_copy.dart';
import 'package:loop_mobile/features/social/qr/loop_qr_card.dart';
import 'package:loop_mobile/features/social/social_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';
import 'package:loop_mobile/widgets/loop_round_key.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';

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

  /// Whether [reference] draws a picture rather than the monogram: a preset
  /// illustration or an uploaded image.
  static bool drawsPicture(String? reference) =>
      reference != null &&
      (loopMediaIdOf(reference) != null ||
          (reference.startsWith(presetPrefix) &&
              peopleSlotKey(
                    int.tryParse(reference.substring(presetPrefix.length)) ?? 0,
                  ) !=
                  null));

  @override
  Widget build(BuildContext context) {
    final reference = avatarRef;
    // S107 §1: an uploaded picture, over the monogram it replaces until its
    // first frame arrives (and for good if it never does).
    final mediaUrl = loopMediaUrlFor(context, reference);
    if (mediaUrl != null) {
      return LoopRemoteAvatar(
        key: ValueKey<String>('loop-profile-avatar-$reference'),
        url: mediaUrl,
        size: size,
        semanticLabel: '头像',
        fallback: _monogram(context),
      );
    }
    final monogram = monogramFor(alias);
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
    return _monogram(context);
  }

  Widget _monogram(BuildContext context) {
    final monogram = monogramFor(alias);
    // The identity card is a Chalk card and the setup page is the Ink page,
    // so this fallback has to hold on both. Naming `card2` and `chalk` here
    // painted Chalk on Chalk on the card: a 200px disc that was simply not
    // there, with the monogram invisible inside it.
    //
    // On a light ground the disc is the ground's own ink and the monogram is
    // the ground — `#scr-profile` draws exactly that, `background:var(--ink);
    // color:var(--chalk)`. A `card2` tint of a light ground is the pale grey
    // disc the device showed on 我的 while every other surface drew a solid
    // face (walkthrough 2026-09-23 · h01/h04).
    final ink = LoopGround.inkOf(context);
    final lightGround = ink.computeLuminance() < 0.5;
    return Container(
      key: const ValueKey<String>('loop-profile-avatar-monogram'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: lightGround ? ink : LoopGround.fillOf(context),
        shape: BoxShape.circle,
      ),
      child: Text(
        monogram,
        style: LoopTypography.figure(
          size / 4.5,
          color: lightGround ? LoopColors.chalk : ink,
        ),
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
        // Decision 0105: 可被发现 states two rules in one line, and the half
        // that says a LOOP ID is always searchable must not be the half cut.
        subtitleMaxLines: 2,
        // `.row .badge`: the prototype states a preference as a pill, not as
        // a mono value in the figure column. A row that read 「已关闭 ›」 in
        // the same grey as a number could not be scanned for its state at all
        // (audit 2026-09-21 §J.4).
        // Decision 0126: a flat page states the preference as a switch.
        trailingBadge: LoopFlat.of(context)
            ? LoopFlatSwitch(value: value, onChanged: onChanged)
            : LoopBadge(
                value ? onLabel : offLabel,
                kind: value ? LoopBadgeKind.up : LoopBadgeKind.mute,
              ),
        onTap: onChanged,
        position: position,
        chevron: false,
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
  var _startedSideReads = false;

  /// Starts the reads the prototype's own rows are printed from, once.
  ///
  /// `#scr-profile` states a figure on the mining row and a state on each of
  /// the four 账户 rows. LOOP has no projection that carries them together,
  /// so the page asks the four modules that own them — each is the same read
  /// the row's destination makes, so opening that destination costs nothing
  /// extra. A read that fails leaves its row without a second line; the page
  /// never writes 「读不到」 where a state belongs.
  void _startSideReads() {
    if (_startedSideReads) return;
    _startedSideReads = true;
    scheduleMicrotask(() {
      if (!mounted) return;
      unawaited(ref.read(miningSummaryControllerProvider.notifier).load());
      unawaited(ref.read(miningUserRankControllerProvider.notifier).load());
      unawaited(ref.read(walletDirectoryControllerProvider.notifier).load());
      unawaited(ref.read(privacyControllerProvider.notifier).load());
      unawaited(ref.read(connectionsControllerProvider.notifier).load());
      unawaited(ref.read(referralControllerProvider.notifier).load());
    });
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
    _startSideReads();
    final resource = state.resource;
    final alias = resource?.values.alias;
    final phase = profileResourcePhase(state);
    final isPreview = state.mode == ProfileMode.preview;
    final switches = ref.watch(loopFeatureSwitchesProvider);

    // 我 (decision 0126, OKX 资产页 4908): the person, four round keys, then
    // three flat sections — 账号, 资产与挖矿, 设置 — and the version last.
    final loopId = resource?.loopId;
    final version = ref
        .watch(appConfigProvider)
        .loopClientVersionForCurrentBuild;
    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('profile-home-screen'),
        archetype: LoopPageArchetype.record,
        title: '我',
        kicker: loopPreviewKicker(isPreview),
        onBack: widget.onBack,
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
          // Decision 0126 on decision 0127's round keys: 56 Lime discs. The
          // fourth, 好友, opened 关注与粉丝 — the row below — under another
          // name (decision 0133, audit m9).
          LoopRoundKeyRow(
            key: const ValueKey<String>('profile-round-keys'),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            keys: <Widget>[
              LoopRoundKey(
                key: const ValueKey<String>('profile-share-loop-id'),
                icon: 'share',
                label: '分享名片',
                onPressed: loopId == null
                    ? null
                    : () => unawaited(
                        showLoopQrCardSheet(
                          context,
                          LoopUserQrCard(
                            loopId: loopId,
                            displayName: alias ?? loopId,
                            avatarRef: resource?.values.avatarRef,
                          ),
                        ),
                      ),
                onBlocked: () =>
                    LoopToast.show(context, message: '资料还没读到，暂时不能分享'),
              ),
              LoopRoundKey(
                key: const ValueKey<String>('profile-open-scan'),
                icon: 'camera',
                label: '扫一扫',
                onPressed: () => widget.onNavigate('scan'),
              ),
              LoopRoundKey(
                key: const ValueKey<String>('profile-open-mining-key'),
                icon: 'mine',
                label: '挖矿',
                onPressed: () => widget.onNavigate('mining'),
              ),
            ],
          ),
          // The prototype's 账户 rows carry a state value on their second
          // line — 「2 个已绑定」, 「关注 24 · 粉丝 108」 — read from the module
          // that owns it; a row whose state this device has not read carries
          // no second line at all.
          const LoopLabel('账号'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('profile-open-wallets'),
                leading: const LoopRowIcon(icon: 'wallet'),
                title: '我的钱包',
                trailing: _walletSubtitle(),
                onTap: () => widget.onNavigate('wallets'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('profile-open-connections'),
                leading: const LoopRowIcon(icon: 'users'),
                title: '关注与粉丝',
                trailing: _connectionsSubtitle(),
                onTap: () => widget.onNavigate('connections'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('profile-open-friend-requests'),
                leading: const LoopRowIcon(icon: 'hand'),
                // The page it opens, and the row on 聊天, both say 陌生人请求
                // (audit m9).
                title: '陌生人请求',
                onTap: () => widget.onNavigate('friend-requests'),
              ),
              _inviteRow(),
            ],
          ),
          ProfileCommunitiesRow(onNavigate: widget.onNavigate),
          const LoopLabel('资产与挖矿'),
          // `#scr-profile` prints `12,840 H` here with 「总算力 · 排名 #8,421」
          // under it, read from the same two projections the mining page
          // does. Since decision 0110 the mining record pages hang under it.
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              _miningRow(),
              LoopRecordRow(
                key: const ValueKey<String>('profile-open-mining-assets'),
                leading: const LoopRowIcon(icon: 'droplet'),
                title: '挖矿资产',
                onTap: () => widget.onNavigate('mining-assets'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('profile-open-mining-rewards'),
                leading: const LoopRowIcon(icon: 'parachute'),
                title: '挖矿奖励',
                onTap: () => widget.onNavigate('mining-rewards'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('profile-open-mining-rules'),
                leading: const LoopRowIcon(icon: 'book'),
                title: '挖矿规则',
                onTap: () => widget.onNavigate('mining-rules'),
              ),
              // 需求方 2026-10-08: IDO Launch keeps its code and its pages,
              // and its entries on 我 follow the one switch that brings it
              // back.
              if (switches.idoLaunchVisible) ...<LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('profile-open-launch-history'),
                  leading: const LoopRowIcon(icon: 'launch'),
                  title: '参与记录',
                  trailing: '未开放',
                  onTap: () => widget.onNavigate('launch-history'),
                ),
                LoopRecordRow(
                  key: const ValueKey<String>('profile-open-launch-tier'),
                  leading: const LoopRowIcon(icon: 'ticket'),
                  title: '我的资格',
                  trailing: '未开放',
                  onTap: () => widget.onNavigate('launch-tier'),
                ),
              ],
            ],
          ),
          const LoopLabel('设置'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('profile-open-privacy'),
                leading: const LoopRowIcon(icon: 'lock'),
                title: '隐私中心',
                trailing: _privacySubtitle(),
                onTap: () => widget.onNavigate('privacy'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('profile-open-security'),
                leading: const LoopRowIcon(icon: 'shield'),
                title: '安全中心',
                // The security projection reports every method as
                // unavailable while the device holds Privy MFA of its own
                // (walkthrough · h17). Until the two agree this row states no
                // posture.
                onTap: () => widget.onNavigate('security'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('profile-open-notifications'),
                leading: const LoopRowIcon(icon: 'bell'),
                title: '通知设置',
                onTap: () => widget.onNavigate('notif-settings'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('profile-open-settings'),
                leading: const LoopRowIcon(icon: 'settings'),
                title: '通用设置',
                onTap: () => widget.onNavigate('settings'),
              ),
            ],
          ),
          // Decision 0133 (audit M14, m15): the same confirmed control 设置
          // carries, at the foot of the list.
          if (widget.onSignOut != null)
            LoopSignOutButton(
              key: const ValueKey<String>('profile-sign-out'),
              onSignOut: widget.onSignOut!,
            ),
          LoopFlatFootnote(
            version.isEmpty ? 'LOOP' : 'LOOP $version',
            key: const ValueKey<String>('profile-version'),
          ),
        ],
      ),
    );
  }

  /// `总算力` with the place it earned, both read from the mining module.
  LoopRecordRow _miningRow() {
    final summary = ref.watch(miningSummaryControllerProvider);
    final rank = ref.watch(miningUserRankControllerProvider);
    final (String figure, String? line) = switch (summary.value?.power) {
      MiningFigureValue(:final value) => (
        loopGroupedFigure(value),
        _rankLine(rank.value),
      ),
      MiningFigureUnavailable(:final reasonCode) => (
        communityMissingFigure,
        launchReasonCodeText(reasonCode),
      ),
      null => (
        communityMissingFigure,
        summary.phase == LaunchViewPhase.loading
            ? '正在读取算力与名次。'
            : '这次没有读到算力，挖矿页是它的出处。',
      ),
    };
    return LoopRecordRow(
      key: const ValueKey<String>('profile-open-mining'),
      leading: const LoopRowIcon(icon: 'mine'),
      title: '总算力',
      subtitle: line,
      subtitleMaxLines: 2,
      trailing: figure,
      semanticLabel: '总算力 $figure${line == null ? '' : '，$line'}',
      onTap: () => widget.onNavigate('mining'),
    );
  }

  /// 邀请码 with a one-tap copy; the row itself opens the referral page.
  ///
  /// The code is the one `GET /v2/referral` issued to this account. Until
  /// it is read the row says nothing about it and offers no copy, because
  /// there is nothing yet to copy.
  LoopRecordRow _inviteRow() {
    final referral = ref.watch(referralControllerProvider);
    final code = referral.value?.inviteCode.code;
    return LoopRecordRow(
      key: const ValueKey<String>('profile-open-referral'),
      leading: const LoopRowIcon(icon: 'ticket'),
      title: '邀请好友',
      trailingBadge: code == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  code,
                  style: LoopTypography.figure(
                    14,
                    weight: FontWeight.w500,
                    color: LoopColors.text2,
                  ),
                ),
                _CopyInviteCodeButton(code: code),
              ],
            ),
      semanticLabel: code == null ? '邀请好友' : '我的邀请码 $code',
      onTap: () => widget.onNavigate('referral'),
    );
  }

  /// `我的名次 第 47 名`, or the server's reason for having none.
  static String? _rankLine(MiningRank? rank) => switch (rank?.myPosition) {
    MiningRankPositionSettled(:final position) => '我的名次 第 $position 名',
    MiningRankPositionUnavailable(:final reasonCode) => launchReasonCodeText(
      reasonCode,
    ),
    null => null,
  };

  /// `1 个已绑定`. A directory this device has not read states nothing.
  String? _walletSubtitle() {
    final directory = ref.watch(walletDirectoryControllerProvider).value;
    if (directory == null) return null;
    return '${directory.wallets.length} 个已绑定';
  }

  /// `持仓与交易已公开` / `持仓与交易仅自己可见`, as the privacy centre stored
  /// it (S107 §4: the 匿名模式 line went with its switch).
  String? _privacySubtitle() {
    final resource = ref.watch(privacyControllerProvider).resource;
    if (resource == null) return null;
    return privacyHoldingsPublic(resource.values.visibility)
        ? '持仓与交易已公开'
        : '持仓与交易仅自己可见';
  }

  /// `关注 24 · 粉丝 108`, from the counts the connections page reads.
  String? _connectionsSubtitle() {
    final counts = ref.watch(connectionsControllerProvider).counts;
    if (counts == null) return null;
    return '关注 ${counts.following} · 粉丝 ${counts.followers}';
  }
}

/// Copies the account's invite code; the row around it stays a link.
class _CopyInviteCodeButton extends StatelessWidget {
  const _CopyInviteCodeButton({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return LoopIconButton(
      key: const ValueKey<String>('profile-copy-invite-code'),
      icon: 'copy',
      label: '复制邀请码',
      onPressed: () async {
        await LoopCopy.text(context, code, message: '邀请码已复制');
      },
    );
  }
}

/// The 我的社区 block on `profile`.
///
/// Membership is not a profile fact. It is only ever the community module's
/// own home aggregate, so this block reads that aggregate through the existing
/// [CommunityHomeController] instead of adding a second source, and states the
/// aggregate's phase rather than claiming the relationship is unconnected.
///
/// Since the 2026-09-23 ruling the block is two groups, because the aggregate
/// answers in two (backend decision 0073): 我加入的 stays the one navigation
/// row it has always been, and 我创建的 lists the reader's own communities with
/// the state of each application on the row. **A reader who has never applied
/// sees no second group at all** — an empty 我创建的 would teach every account
/// about a review queue none of them is in.
///
/// The joined row stays a navigation entry in every phase: a failure is
/// reported there in one line and carries the owner to the community
/// directory, which is the page that owns the full five-state block and its
/// retry.
class ProfileCommunitiesRow extends ConsumerStatefulWidget {
  const ProfileCommunitiesRow({required this.onNavigate, super.key});

  /// Profile-screen destination id, resolved by the composition root.
  final ValueChanged<String> onNavigate;

  /// The paginated directory narrowed to the owner's own communities.
  static const joinedDestination = 'community-joined';

  /// The public directory, used whenever there is nothing joined to open.
  static const discoverDestination = 'community-discover';

  /// One community's own record. The id travels in the destination because
  /// `community-profile` addresses exactly one community and the composition
  /// root owns the query it is addressed with.
  static String recordDestination(String communityId) =>
      'community-profile:$communityId';

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
    final owned = isReady ? home.owned : const <OwnedCommunity>[];

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('profile-open-communities'),
              leading: const LoopRowIcon(icon: 'community'),
              title: '我加入的',
              subtitle: subtitle,
              trailing: trailing,
              semanticLabel: '我加入的，$trailing，$subtitle',
              onTap: () => widget.onNavigate(
                isReady && joined.isNotEmpty
                    ? ProfileCommunitiesRow.joinedDestination
                    : ProfileCommunitiesRow.discoverDestination,
              ),
            ),
          ],
        ),
        if (owned.isNotEmpty) ...<Widget>[
          // Decision 0126: a sub-group of 账号 on 我, so the small label.
          const LoopLabel('我创建的', followsLabel: true, tight: true),
          LoopRecordGroup(
            key: const ValueKey<String>('profile-owned-communities'),
            rows: <LoopRecordRow>[for (final entry in owned) _ownedRow(entry)],
          ),
          if (home!.ownedTruncated)
            const LoopProvenanceFooter(
              key: ValueKey<String>('profile-owned-truncated'),
              text: '这一页放不下全部，上面是最近提交的几个。',
            ),
          ProfileApplicationNotifications(onOpenCommunity: widget.onNavigate),
        ],
      ],
    );
  }

  /// One community this account created, with the state of its review.
  ///
  /// The value column carries the state as a pill rather than a figure: it is
  /// a decision somebody made, not a number. The second line is the fact the
  /// owner can act on — when the version under review was submitted, or the
  /// head of the operator's own reason for refusing it.
  LoopRecordRow _ownedRow(OwnedCommunity entry) {
    final community = entry.community;
    final line = communityApplicationRowLine(entry);
    final status = communityApplicationStatusLabel(entry.status);
    return LoopRecordRow(
      key: ValueKey<String>('profile-owned-${community.communityId}'),
      leading: CommunityLogo(
        identity: community.communityId,
        name: community.name,
        logoRef: community.logoRef,
        size: 40,
        radius: 12,
      ),
      title: community.name,
      subtitle: line,
      subtitleMaxLines: 2,
      trailingBadge: CommunityApplicationBadge(entry.status),
      chevron: false,
      semanticLabel: '${community.name}，$status，$line',
      onTap: () => widget.onNavigate(
        ProfileCommunitiesRow.recordDestination(community.communityId),
      ),
    );
  }
}

/// The review results the feed holds for the reader's own communities.
///
/// LOOP has no notification centre and will not grow one (红线 1), so a
/// notification lives on the page that owns what it is about. These two live
/// directly under 我创建的, because that is where the 2026-09-23 ruling sends
/// the applicant to watch for the answer and because the rows they belong to
/// are the ones above them.
///
/// The feed is only read when this account owns something to be reviewed: an
/// account that never applied pays nothing for a surface it will never see.
/// A failed or unavailable read draws nothing at all — the group above it
/// already carries the authoritative state of every application, and a second
/// block saying the notification list could not be read would report a
/// failure about a fact the reader can already see.
class ProfileApplicationNotifications extends ConsumerStatefulWidget {
  const ProfileApplicationNotifications({
    required this.onOpenCommunity,
    super.key,
  });

  /// Takes `community-profile:<communityId>`, the destination the composition
  /// root resolves into the record's own route.
  final ValueChanged<String> onOpenCommunity;

  @override
  ConsumerState<ProfileApplicationNotifications> createState() =>
      _ProfileApplicationNotificationsState();
}

class _ProfileApplicationNotificationsState
    extends ConsumerState<ProfileApplicationNotifications> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationFeedControllerProvider);
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(notificationFeedControllerProvider.notifier).load(),
          );
        }
      });
    }
    final feed = state.value;
    if (feed == null) return const SizedBox.shrink();
    final results = communityApplicationNotifications(feed);
    if (results.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('审核通知', followsLabel: true),
        LoopRecordGroup(
          key: const ValueKey<String>('profile-application-notifications'),
          rows: <LoopRecordRow>[
            for (final result in results)
              LoopRecordRow(
                key: ValueKey<String>(
                  'profile-application-notification-'
                  '${result.entry.notificationId}',
                ),
                title: result.title,
                subtitle: result.body,
                subtitleMaxLines: 3,
                trailingBadge: result.entry.isUnread
                    ? const LoopBadge('未读')
                    : null,
                chevron: false,
                semanticLabel: '${result.title}，${result.body}',
                onTap: () {
                  // Reading it is the tap that opens it; the read is the
                  // server's to confirm and is never waited on here.
                  if (result.entry.isUnread) {
                    unawaited(
                      ref
                          .read(notificationFeedControllerProvider.notifier)
                          .markRead(result.entry.notificationId),
                    );
                  }
                  widget.onOpenCommunity(
                    ProfileCommunitiesRow.recordDestination(result.communityId),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// The person at the top of 我 (decision 0126, OKX 资产页): avatar 56, the
/// name at 18 bold, the LOOP ID at 13 grey with its copy glyph, and one edit
/// glyph on the right. Sharing moved to the first round key under it.
class _ProfileIdentityCard extends ConsumerWidget {
  const _ProfileIdentityCard({required this.resource, required this.onEdit});

  final ProfileResource resource;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alias = resource.values.alias;
    final loopId = resource.loopId;
    final idStyle = LoopTypography.figure(
      13,
      weight: FontWeight.w400,
      color: LoopColors.text3,
    );
    return Padding(
      key: const ValueKey<String>('profile-identity-card'),
      padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 8, 6, 16),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: onEdit,
            child: LoopProfileAvatar(
              avatarRef: resource.values.avatarRef,
              alias: alias,
              size: 56,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  alias ?? '尚未设置别名',
                  key: const ValueKey<String>('profile-alias'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopTypography.heading(18, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                // Decision 0104 (S97b layout): the copy glyph follows the ID
                // it copies; an ID this device could not read offers nothing
                // to copy.
                if (loopId != null)
                  LoopIdCopyLine(
                    loopId: loopId,
                    style: idStyle,
                    textKey: const ValueKey<String>('profile-loop-id'),
                    copyKey: const ValueKey<String>('profile-copy-loop-id'),
                  )
                else
                  Text(
                    'LOOP ID 不可读',
                    key: const ValueKey<String>('profile-loop-id'),
                    style: idStyle,
                  ),
              ],
            ),
          ),
          Semantics(
            key: const ValueKey<String>('profile-open-edit'),
            button: true,
            label: '编辑资料',
            excludeSemantics: true,
            child: InkWell(
              onTap: onEdit,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: LoopTouch.minimum,
                height: LoopTouch.minimum,
                child: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: LoopColors.chalk,
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
    final loopId = state.resource?.loopId;

    // S107 §4 / docs/09 §6.2 #7: a title, three groups — the face, the
    // public basics, where they are seen — and one pinned save. The Chalk
    // hero that repeated the alias above the field holding it is gone, and
    // with it a screen of scrolling before the first field.
    return LoopFlat(
      child: LoopFocusPage(
        archetype: LoopPageArchetype.action,
        title: '编辑资料',
        kicker: loopPreviewKicker(state.mode == ProfileMode.preview),
        onBack: widget.onBack,
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
                trailing: LoopButton(
                  label: '重新载入',
                  onPressed: controller.reload,
                ),
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
            Padding(
              key: const ValueKey<String>('profile-avatar-picker'),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: LoopAvatarEditor(
                avatarRef: state.draft.avatarRef,
                alias: state.draft.alias,
                enabled: state.canEdit,
                onChanged: controller.editAvatarRef,
              ),
            ),
            // Decision 0126: labelled 52-high form fields (decision 0127's
            // field), no section label over each one.
            LoopFlatField(
              key: const ValueKey<String>('profile-edit-alias'),
              label: '用户名',
              trailing: LoopSeg(
                key: const ValueKey<String>('profile-edit-alias-suggest'),
                label: '换一个',
                selected: false,
                onSelected: state.canEdit
                    ? () => _suggestAlias(controller)
                    : null,
              ),
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
                style: LoopTypography.body(16, color: LoopColors.chalk),
                decoration: loopFormFieldDecoration(hint: '1–40 个字符，可以和别人重复'),
                onChanged: (value) => _applyAlias(controller, value),
              ),
            ),
            LoopFlatField(
              key: const ValueKey<String>('profile-edit-bio'),
              label: '简介',
              child: TextField(
                key: const ValueKey<String>('profile-edit-bio-field'),
                controller: _bioController,
                enabled: state.canEdit,
                maxLength: 160,
                maxLines: 4,
                minLines: 1,
                buildCounter: (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) => null,
                style: LoopTypography.body(15, color: LoopColors.chalk),
                decoration: loopFormFieldDecoration(hint: '一句话介绍自己（可以不填）'),
                onChanged: (value) => _applyBio(controller, value),
              ),
            ),
            if (loopId != null)
              LoopFlatField(
                key: const ValueKey<String>('profile-edit-loop-id-field'),
                label: 'LOOP ID',
                boxed: true,
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: LoopIdCopyLine(
                    loopId: loopId,
                    textKey: const ValueKey<String>('profile-edit-loop-id'),
                    copyKey: const ValueKey<String>(
                      'profile-edit-copy-loop-id',
                    ),
                    style: LoopTypography.figure(
                      15,
                      height: 1.3,
                      color: LoopColors.chalk,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            LoopRecordRow(
              key: const ValueKey<String>('profile-edit-open-privacy'),
              leading: const LoopRowIcon(icon: 'lock'),
              title: '隐私中心',
              subtitle: '持仓与交易是否公开、谁能加你',
              onTap: () => widget.onNavigate('privacy'),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
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

    // Decision 0126: a flat settings page — three sections of switches, the
    // state is the switch itself, so the folio that restated it is gone.
    return LoopFlat(
      child: LoopFocusPage(
        archetype: LoopPageArchetype.action,
        title: '隐私中心',
        kicker: loopPreviewKicker(state.mode == PrivacyMode.preview),
        onBack: widget.onBack,
        // `.folio-body` order, and a save that flows under the last row instead
        // of sitting in a pinned bar above it. Pinned, the bar took the bottom
        // of the viewport and 「屏蔽名单」 came to rest two pixels above it on
        // first entry — reachable only after a second drag inside the list
        // (audit 2026-09-21 §J.4).
        actionsFollowBody: true,
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
                trailing: LoopButton(
                  label: '重新载入',
                  onPressed: controller.reload,
                ),
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
            // S107 §2: a person is drawn with their own avatar and name
            // everywhere, so the 匿名模式 switch is hidden (not removed); the
            // field stays in the resource and is resubmitted unchanged.
            if (ref.watch(loopFeatureSwitchesProvider).anonymousModeVisible)
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
              // Decision 0105 (backend decision 0090): the switch governs being
              // found by nickname and being followed. A LOOP ID is always found
              // by an exact search, whichever way this switch is set.
              title: '可被发现',
              // The subtitle described the switch turned on while the row read
              // 已关闭 beside it, so the state and the sentence disagreed.
              // Decision 0096 (S107b): the switch governs search listings only;
              // follows and friend requests from a reached profile are not
              // gated by it.
              subtitle: draft.discoverable
                  ? '允许别人按昵称搜到你；LOOP ID 始终可被精确搜索'
                  : '别人无法按昵称搜到你；LOOP ID 始终可被精确搜索',
              value: draft.discoverable,
              position:
                  ref.watch(loopFeatureSwitchesProvider).anonymousModeVisible
                  ? LoopRowPosition.last
                  : LoopRowPosition.single,
              onChanged: state.canEdit
                  ? () => controller.editDiscoverable(!draft.discoverable)
                  : null,
            ),
            // 社交 · the three admission gates (decision 0070). They sit apart
            // from 可见性 because they are not display preferences: the server
            // reads them before it lets a request, a direct channel or a group
            // invite reach this account. The prototype's 持仓广播 card is not
            // implemented, so this group takes the middle slot of the page.
            const LoopLabel('社交'),
            for (final gate in PrivacySocialGate.values)
              LoopTogglePreferenceRow(
                key: ValueKey<String>('privacy-social-${gate.wireValue}'),
                title: gate.label,
                subtitle: _socialGateSubtitle(gate, open: draft.social[gate]),
                value: draft.social[gate],
                position: gate == PrivacySocialGate.values.first
                    ? LoopRowPosition.first
                    : gate == PrivacySocialGate.values.last
                    ? LoopRowPosition.last
                    : LoopRowPosition.middle,
                onChanged: state.canEdit
                    ? () => controller.editSocialGate(
                        gate,
                        open: !draft.social[gate],
                      )
                    : null,
              ),
            const LoopLabel('可见性'),
            // S107 §4: one switch for what the profile page shows others —
            // holdings and trades together. It writes `totalAssets` and
            // `tradeHistory` to the same audience.
            LoopTogglePreferenceRow(
              key: const ValueKey<String>('privacy-public-holdings'),
              title: '公开持仓与交易',
              subtitle: privacyHoldingsPublic(draft.visibility)
                  ? '别人在你的主页能看到持仓和交易记录，不显示钱包地址'
                  : '只有你自己能看到持仓和交易记录',
              value: privacyHoldingsPublic(draft.visibility),
              onLabel: '所有人',
              offLabel: '仅自己',
              position: LoopRowPosition.first,
              onChanged: state.canEdit
                  ? () {
                      final audience = privacyHoldingsPublic(draft.visibility)
                          ? PrivacyAudience.self
                          : PrivacyAudience.everyone;
                      controller
                        ..editVisibility(
                          PrivacyVisibilityFacet.totalAssets,
                          audience,
                        )
                        ..editVisibility(
                          PrivacyVisibilityFacet.tradeHistory,
                          audience,
                        );
                    }
                  : null,
            ),
            for (final facet in const <PrivacyVisibilityFacet>[
              PrivacyVisibilityFacet.miningPower,
              PrivacyVisibilityFacet.communities,
            ])
              LoopTogglePreferenceRow(
                key: ValueKey<String>('privacy-visibility-${facet.wireValue}'),
                title: facet.label,
                value: draft.visibility[facet] == PrivacyAudience.everyone,
                onLabel: '所有人',
                offLabel: '仅自己',
                position: LoopRowPosition.middle,
                onChanged: state.canEdit
                    ? () => controller.editVisibility(
                        facet,
                        draft.visibility[facet] == PrivacyAudience.everyone
                            ? PrivacyAudience.self
                            : PrivacyAudience.everyone,
                      )
                    : null,
              ),
            // The prototype closes the 可见性 card with this row rather than
            // floating it alone under the card.
            LoopRecordRow(
              key: const ValueKey<String>('privacy-open-blocklist'),
              title: '屏蔽名单',
              position: LoopRowPosition.last,
              onTap: () => widget.onNavigate('blocklist'),
            ),
            const LoopNotice(
              key: ValueKey<String>('privacy-visibility-note'),
              icon: 'info',
              body:
                  '可见性只影响展示，不会让别人复制你的交易或访问你的钱包；'
                  '头像和用户名在聊天与主页上始终显示，钱包地址从不出现在主页上。',
              margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
            ),
          ],
        ],
      ),
    );
  }

  /// The second line states what the gate does *in its current position*.
  /// Since backend decision 0090 a friend request no longer requires the
  /// target to be discoverable: whoever knows the LOOP ID finds the account
  /// by exact search and may ask (decision 0105).
  String _socialGateSubtitle(PrivacySocialGate gate, {required bool open}) =>
      switch (gate) {
        PrivacySocialGate.friendRequests =>
          open ? '知道你 LOOP ID 的人可以加你' : '陌生人无法向你发好友申请',
        PrivacySocialGate.directMessages =>
          open ? '已成为好友的人可以直接打开与你的私聊' : '关闭后，好友也无法打开与你的私聊',
        PrivacySocialGate.groupInvites =>
          open ? '好友可以把你拉进小群' : '关闭后，好友无法把你拉进小群',
      };

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
/// that says so. It claims nothing about the stored profile.
///
/// The check runs once per accepted principal, which used to mean that a
/// single moment of bad network pinned this warning to every page for the rest
/// of the session — the copy said "下次启动会重新检查" and that was literally
/// the only way out. So the banner carries the two things it was missing:
///
/// * 重试 reads the profile again. It shows that a read is running and cannot
///   start a second one, and it announces nothing itself: the answer is
///   published by the coordinator, so a retry that fails leaves the warning
///   exactly where it was.
/// * 关闭 puts the warning away for this run. It is not an answer either —
///   nothing about the profile changes, and the next published answer brings
///   the warning back if it is still unread.
///
/// Both are icon controls on the same 44 grid as every other bar action. As a
/// labelled button 重试 was a word wide enough to push the notice into another
/// line of height on a banner that already sits above the page; the sprite
/// says the same thing in the space the 关闭 control already occupies, and the
/// spoken label still carries the whole sentence.
class ProfileAvailabilityBanner extends ConsumerWidget {
  const ProfileAvailabilityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landing = ref.watch(loopProfileLandingProvider);
    if (!landing.shouldWarn) return const SizedBox.shrink();
    final controller = ref.read(loopProfileLandingProvider.notifier);
    final rechecking = landing.rechecking;
    // A policy refusal is an answer, so it keeps the close action and nothing
    // else; only a read that could answer differently is worth repeating.
    final retryable = loopProfileRecheckCanHelp(landing.failureKind);
    return LoopNotice(
      key: const ValueKey<String>('profile-availability-banner'),
      icon: 'warn',
      tone: LoopNoticeTone.warn,
      title: '资料状态暂不可读',
      body: rechecking
          ? '正在重新读取资料状态。'
          : '${profileFailureReason(landing.failureKind)}'
                '${retryable ? ' 你可以继续浏览，也可以现在重试。' : ' 你可以继续浏览。'}',
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (retryable)
            LoopIconButton(
              key: const ValueKey<String>('profile-availability-retry'),
              icon: 'refresh',
              label: rechecking ? '正在重试…' : '重新读取资料状态',
              onPressed: rechecking
                  ? null
                  : () => unawaited(controller.recheck()),
            ),
          LoopIconButton(
            key: const ValueKey<String>('profile-availability-dismiss'),
            icon: 'close',
            label: '收起资料状态提示',
            onPressed: controller.dismiss,
          ),
        ],
      ),
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

/// Whether the profile page shows this account's holdings and trades to
/// others: both facets the single switch writes are `everyone`.
bool privacyHoldingsPublic(PrivacyVisibility visibility) =>
    visibility[PrivacyVisibilityFacet.totalAssets] ==
        PrivacyAudience.everyone &&
    visibility[PrivacyVisibilityFacet.tradeHistory] == PrivacyAudience.everyone;
