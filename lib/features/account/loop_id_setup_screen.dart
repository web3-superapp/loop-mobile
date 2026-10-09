import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/loop_id_setup_controller.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_editor.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/loop_id_copy.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `loop-id-setup`: the one-time public-profile activation (decision 0112).
///
/// Since S107 the page is the profile itself: the default avatar (the
/// monogram) or an uploaded picture, the user name (the alias), an optional
/// bio, and the LOOP ID to copy. The preset grid and the interest tracks are
/// gone from the page; the server keeps both fields and receives an empty
/// interest list. The LOOP ID is server-generated, unique and immutable.
/// The alias suggestion is local and never checked for availability, because
/// aliases may repeat. After activation the account goes on to
/// `onboarding-communities`.
class LoopIdSetupScreen extends ConsumerStatefulWidget {
  const LoopIdSetupScreen({super.key, this.onBack, this.onActivated});

  final VoidCallback? onBack;
  final VoidCallback? onActivated;

  @override
  ConsumerState<LoopIdSetupScreen> createState() => _LoopIdSetupScreenState();
}

class _LoopIdSetupScreenState extends ConsumerState<LoopIdSetupScreen> {
  final _aliasController = TextEditingController();
  final _bioController = TextEditingController();
  String? _syncedAlias;
  String? _syncedBio;

  @override
  void dispose() {
    _aliasController.dispose();
    _bioController.dispose();
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
    _syncBio(state);
    final editable = !state.isBusy && state.phase != LoopIdSetupPhase.activated;

    return LoopFlat(
      step: true,
      child: LoopFocusPage(
        archetype: LoopPageArchetype.intro,
        title: '完善资料',
        onBack: widget.onBack,
        actionsFollowBody: true,
        primaryAction: LoopButton(
          key: const ValueKey<String>('loop-id-submit'),
          label: switch (state.phase) {
            LoopIdSetupPhase.submitting => '提交中…',
            _ => '下一步',
          },
          primary: true,
          block: true,
          onPressed: state.phase == LoopIdSetupPhase.activated
              ? widget.onActivated
              : state.canSubmit
              ? () => unawaited(_submit(controller))
              : null,
        ),
        body: <Widget>[
          const IdentityProgress(step: 5, total: 5, label: '完善资料'),
          const IdentityStepCopy('头像和用户名是别人在聊天里看到的你，钱包地址不会公开。'),
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
              title: '资料服务暂不可用',
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
                pausedActions: const <String>['保存资料'],
                onRetry: () => unawaited(_submit(controller)),
              )
            else if (state.phase == LoopIdSetupPhase.failure)
              LoopNotice(
                key: const ValueKey<String>('loop-id-failure'),
                icon: 'close',
                tone: LoopNoticeTone.danger,
                title: '没有保存成功',
                body: profileFailureReason(state.failureKind),
              ),
            if (state.phase == LoopIdSetupPhase.activated)
              LoopNotice(
                key: const ValueKey<String>('loop-id-activated'),
                icon: 'check',
                title: '资料已保存',
                body: state.bioSaveFailed
                    ? '简介没有保存成功，可以之后在「编辑资料」里补上。'
                    : '之后可以在「编辑资料」里修改。',
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: LoopAvatarEditor(
                key: const ValueKey<String>('loop-id-avatar-editor'),
                avatarRef: state.avatarRef,
                alias: state.alias,
                enabled: editable,
                onChanged: controller.editAvatarRef,
              ),
            ),
            const LoopLabel('用户名'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LoopSurfaceCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>('loop-id-alias-field'),
                        controller: _aliasController,
                        enabled: editable,
                        maxLength: 40,
                        buildCounter: (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) => null,
                        style: LoopTypography.body(16, color: LoopColors.chalk),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '1–40 个字符，可以和别人重复',
                        ),
                        onChanged: controller.editAlias,
                      ),
                    ),
                    LoopSeg(
                      key: const ValueKey<String>('loop-id-alias-suggest'),
                      label: '换一个',
                      selected: false,
                      onSelected: editable ? () => _suggest(controller) : null,
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
                  key: const ValueKey<String>('loop-id-bio-field'),
                  controller: _bioController,
                  enabled: editable,
                  maxLength: profileMaximumBioCodePoints,
                  maxLines: 3,
                  minLines: 1,
                  style: LoopTypography.body(15, color: LoopColors.chalk),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '一句话介绍自己（可以不填）',
                  ),
                  onChanged: controller.editBio,
                ),
              ),
            ),
            const LoopLabel('LOOP ID'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LoopSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (state.loopId case final String loopId)
                      LoopIdCopyLine(
                        loopId: loopId,
                        textKey: const ValueKey<String>('loop-id-value'),
                        copyKey: const ValueKey<String>('loop-id-copy'),
                        style: LoopTypography.figure(
                          18,
                          height: 1.2,
                          color: LoopColors.chalk,
                        ),
                      )
                    else
                      Text(
                        key: const ValueKey<String>('loop-id-value'),
                        '尚未分配',
                        style: LoopTypography.caption(
                          13,
                          color: LoopColors.text3,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '系统生成、唯一、不可更改。好友可以用它搜到你。',
                      style: LoopTypography.caption(
                        12,
                        color: LoopColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  void _syncAlias(LoopIdSetupState state) {
    final alias = state.alias ?? '';
    if (_syncedAlias != alias && _aliasController.text != alias) {
      _aliasController.text = alias;
    }
    _syncedAlias = alias;
  }

  void _syncBio(LoopIdSetupState state) {
    final bio = state.bio ?? '';
    if (_syncedBio != bio && _bioController.text != bio) {
      _bioController.text = bio;
    }
    _syncedBio = bio;
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
