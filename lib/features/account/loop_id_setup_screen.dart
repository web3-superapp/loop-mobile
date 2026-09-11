import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/loop_id_setup_controller.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `loop-id-setup`: the one-time public-profile activation.
///
/// The LOOP ID is server-generated, unique and immutable; it is shown read
/// only. The alias suggestion is local and clearly labelled as a suggestion —
/// it is never checked for availability, because aliases may repeat.
class LoopIdSetupScreen extends ConsumerStatefulWidget {
  const LoopIdSetupScreen({super.key, this.onBack, this.onActivated});

  final VoidCallback? onBack;
  final VoidCallback? onActivated;

  @override
  ConsumerState<LoopIdSetupScreen> createState() => _LoopIdSetupScreenState();
}

class _LoopIdSetupScreenState extends ConsumerState<LoopIdSetupScreen> {
  final _aliasController = TextEditingController();
  String? _syncedAlias;

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loopIdSetupControllerProvider);
    if (state.phase == LoopIdSetupPhase.initial) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(loopIdSetupControllerProvider.notifier).load());
        }
      });
    }
    final controller = ref.read(loopIdSetupControllerProvider.notifier);
    _syncAlias(state);
    final avatarUpload = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.avatarUpload),
    );

    return LoopFocusPage(
      archetype: LoopPageArchetype.intro,
      title: '创建 LOOP ID',
      onBack: widget.onBack,
      primaryActionBeforeDisclosure: true,
      primaryAction: LoopButton(
        key: const ValueKey<String>('loop-id-submit'),
        label: switch (state.phase) {
          LoopIdSetupPhase.submitting => '提交中…',
          LoopIdSetupPhase.activated => '进入 LOOP',
          _ => '进入 LOOP',
        },
        primary: true,
        block: true,
        onPressed: state.phase == LoopIdSetupPhase.activated
            ? widget.onActivated
            : state.canSubmit
            ? () => unawaited(_submit(controller))
            : null,
      ),
      disclosure: LoopDisclosure(
        summary: '身份说明、关注赛道与通知',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const LoopNotice(
                icon: 'id',
                title: 'LOOP ID 才是你的社交身份',
                body: '钱包地址只是可绑定、可更换的凭证。换钱包不会丢掉你的社区关系、Launch 记录与挖矿历史。',
                margin: EdgeInsets.only(bottom: 12),
              ),
              const LoopLabel('关注赛道', tight: true),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    for (final interest in ProfileInterest.values)
                      LoopSeg(
                        key: ValueKey<String>(
                          'loop-id-interest-${interest.wireValue}',
                        ),
                        label: interest.label,
                        selected: state.interests.contains(interest),
                        onSelected: state.isBusy
                            ? null
                            : () => controller.toggleInterest(interest),
                      ),
                  ],
                ),
              ),
              const LoopLabel('通知', tight: true),
              LoopTogglePreferenceRow(
                key: const ValueKey<String>('loop-id-push-toggle'),
                title: '开启推送',
                subtitle: '挖矿结算、Launch 开始、社区动态 · 仅本地偏好，投递仍不可用',
                value: state.pushNotificationsRequested,
                onLabel: '想接收',
                offLabel: '不接收',
                onChanged: () => controller.setPushNotificationsRequested(
                  !state.pushNotificationsRequested,
                ),
              ),
            ],
          ),
        ),
      ),
      body: <Widget>[
        const IdentityProgress(step: 5, total: 5, label: '创建 LOOP ID'),
        const IdentityStepCopy('设置公开身份，不暴露你的钱包地址。'),
        if (state.phase == LoopIdSetupPhase.loading && state.resource == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LoopSkeleton(
              key: ValueKey<String>('loop-id-loading'),
              type: LoopSkeletonType.detail,
            ),
          )
        else if (state.phase == LoopIdSetupPhase.unavailable)
          LoopNotice(
            key: const ValueKey<String>('loop-id-unavailable'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: 'LOOP ID 激活暂不可用',
            body: profileFailureReason(state.failureKind),
          )
        else if (state.resource == null && state.failureKind == null)
          // Nothing has been read yet and nothing failed: an initial state is
          // not an error.
          LoopEmpty(
            key: const ValueKey<String>('loop-id-empty'),
            message: '还没有读取到你的 LOOP ID',
            reason: '账号资料尚未载入。',
            action: LoopButton(label: '载入', onPressed: controller.reload),
          )
        else if (state.resource == null)
          LoopErrorState(
            key: const ValueKey<String>('loop-id-error'),
            reason: profileFailureReason(state.failureKind),
            source: '资料服务',
            onRetry: controller.reload,
          )
        else ...<Widget>[
          if (state.failureKind == ProfileGatewayFailureKind.offline)
            LoopOfflineState(
              key: const ValueKey<String>('loop-id-offline'),
              pausedActions: const <String>['激活 LOOP ID'],
              onRetry: () => unawaited(_submit(controller)),
            )
          else if (state.phase == LoopIdSetupPhase.failure)
            LoopNotice(
              key: const ValueKey<String>('loop-id-failure'),
              icon: 'close',
              tone: LoopNoticeTone.danger,
              title: '激活未完成',
              body: profileFailureReason(state.failureKind),
            ),
          if (state.phase == LoopIdSetupPhase.activated)
            const LoopNotice(
              key: ValueKey<String>('loop-id-activated'),
              icon: 'check',
              title: 'LOOP ID 已激活',
              body: '别名与关注赛道已保存。之后可以在「编辑资料」里修改。',
            ),
          _LoopIdAvatarCard(
            selected: state.avatarRef,
            alias: state.alias,
            enabled: !state.isBusy && state.phase != LoopIdSetupPhase.activated,
            uploadUsable: avatarUpload.isUsable,
            onSelected: controller.editAvatarRef,
          ),
          const LoopLabel('你的 LOOP ID'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LoopSurfaceCard(
              child: Column(
                children: <Widget>[
                  Text(
                    key: const ValueKey<String>('loop-id-value'),
                    state.loopId ?? '—',
                    style: LoopTypography.figure(
                      20,
                      height: 1.15,
                      color: LoopColors.chalk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '系统生成，不可更改',
                    style: LoopTypography.caption(11, color: LoopColors.text3),
                  ),
                ],
              ),
            ),
          ),
          const LoopLabel('别名'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LoopSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: const ValueKey<String>('loop-id-alias-field'),
                          controller: _aliasController,
                          enabled:
                              !state.isBusy &&
                              state.phase != LoopIdSetupPhase.activated,
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
                          onChanged: controller.editAlias,
                        ),
                      ),
                      LoopSeg(
                        key: const ValueKey<String>('loop-id-alias-suggest'),
                        label: '换一个',
                        selected: false,
                        onSelected:
                            state.isBusy ||
                                state.phase == LoopIdSetupPhase.activated
                            ? null
                            : () => _suggest(controller),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '随时可改 · 别人看到的是这个名字。「换一个」只是本地建议，不代表已被占用或可用。',
                    style: LoopTypography.caption(11, color: LoopColors.text3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _syncAlias(LoopIdSetupState state) {
    final alias = state.alias ?? '';
    if (_syncedAlias != alias && _aliasController.text != alias) {
      _aliasController.text = alias;
    }
    _syncedAlias = alias;
  }

  void _suggest(LoopIdSetupController controller) {
    final suggestion = loopLocalAliasSuggestion();
    _aliasController.text = suggestion;
    controller.editAlias(suggestion);
  }

  Future<void> _submit(LoopIdSetupController controller) async {
    await controller.submit();
    if (!mounted) return;
    final state = ref.read(loopIdSetupControllerProvider);
    if (state.phase == LoopIdSetupPhase.activated) {
      widget.onActivated?.call();
    }
  }
}

class _LoopIdAvatarCard extends ConsumerWidget {
  const _LoopIdAvatarCard({
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: <Widget>[
          LoopProfileAvatar(avatarRef: selected, alias: alias),
          const SizedBox(height: 12),
          catalog.when(
            loading: () => const LoopSkeleton(
              key: ValueKey<String>('loop-id-avatar-loading'),
              type: LoopSkeletonType.list,
              rows: 1,
            ),
            error: (error, stackTrace) => Text(
              key: const ValueKey<String>('loop-id-avatar-unavailable'),
              '预设头像清单暂不可读，先用首字母头像继续。',
              textAlign: TextAlign.center,
              style: LoopTypography.caption(11, color: LoopColors.text3),
            ),
            data: (presets) => Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final preset in presets)
                  _LoopIdAvatarChoice(
                    preset: preset,
                    alias: alias,
                    selected: preset.isMonogram
                        ? selected == null
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
            const SizedBox(height: 8),
            Text(
              '自定义头像上传暂不可用，只能选择预设头像。',
              textAlign: TextAlign.center,
              style: LoopTypography.caption(11, color: LoopColors.text3),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoopIdAvatarChoice extends StatelessWidget {
  const _LoopIdAvatarChoice({
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
        key: ValueKey<String>('loop-id-avatar-${preset.avatarRef}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: LoopTouch.minimum,
          height: LoopTouch.minimum,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? LoopColors.lime : Colors.transparent,
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
