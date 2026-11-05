import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/loop_id_setup_controller.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_editor.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/loop_id_copy.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inputs.dart';
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
        title: context.l10n.account_idSetupLoopIdSubmitTitle,
        onBack: widget.onBack,
        actionsFollowBody: true,
        primaryAction: LoopButton(
          key: const ValueKey<String>('loop-id-submit'),
          label: switch (state.phase) {
            LoopIdSetupPhase.submitting =>
              context.l10n.account_idSetupSubmitting,
            _ => context.l10n.common_next,
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
          IdentityProgress(
            step: 5,
            total: 5,
            label: context.l10n.account_idSetupLoopIdSubmitTitle,
          ),
          IdentityStepCopy(context.l10n.account_idSetupIdentityStepCopy),
          if (state.phase == LoopIdSetupPhase.loading && state.resource == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: LoopSpacing.page),
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
              title: context.l10n.account_idSetupLoopIdUnavailableTitle,
              body: profileFailureReason(state.failureKind),
            )
          else if (state.resource == null && state.failureKind == null)
            // Nothing has been read yet and nothing failed: an initial state is
            // not an error.
            LoopEmptyState(
              key: const ValueKey<String>('loop-id-empty'),
              illustration: LoopIllustration.profile,
              title: context.l10n.account_idSetupLoopIdEmptyTitle,
              message: context.l10n.account_idSetupLoopIdEmptyMessage,
              action: LoopButton(
                label: context.l10n.account_idSetupLabel,
                onPressed: controller.reload,
              ),
              compact: true,
            )
          else if (state.resource == null)
            LoopErrorState(
              key: const ValueKey<String>('loop-id-error'),
              reason: profileFailureReason(state.failureKind),
              source: context.l10n.account_idSetupLoopIdErrorSource,
              onRetry: controller.reload,
            )
          else ...<Widget>[
            if (state.failureKind == ProfileGatewayFailureKind.offline)
              LoopOfflineState(
                key: const ValueKey<String>('loop-id-offline'),
                pausedActions: <String>[
                  context.l10n.account_idSetupLoopOfflineState,
                ],
                onRetry: () => unawaited(_submit(controller)),
              )
            else if (state.phase == LoopIdSetupPhase.failure)
              LoopNotice(
                key: const ValueKey<String>('loop-id-failure'),
                icon: 'close',
                tone: LoopNoticeTone.danger,
                title: context.l10n.account_idSetupLoopIdFailureTitle,
                body: profileFailureReason(state.failureKind),
              ),
            if (state.phase == LoopIdSetupPhase.activated)
              LoopNotice(
                key: const ValueKey<String>('loop-id-activated'),
                icon: 'check',
                title: context.l10n.account_idSetupLoopIdActivatedTitle,
                body: state.bioSaveFailed
                    ? context.l10n.account_idSetupLoopIdActivatedBody
                    : context.l10n.account_idSetupLoopIdActivatedBody2,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                16,
                LoopSpacing.page,
                4,
              ),
              child: LoopAvatarEditor(
                key: const ValueKey<String>('loop-id-avatar-editor'),
                avatarRef: state.avatarRef,
                alias: state.alias,
                enabled: editable,
                onChanged: controller.editAvatarRef,
              ),
            ),
            LoopLabel(context.l10n.account_idSetupLoopLabel),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
              // UX-008 (decision 0254): the card is the field's box, so the
              // focus edge sits on the card.
              child: LoopFocusRing(
                borderRadius: LoopRadius.card,
                enabled: editable,
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
                          style: LoopType.bodyLg,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            hintText: context.l10n.account_idSetupHintText,
                          ),
                          onChanged: controller.editAlias,
                        ),
                      ),
                      LoopSeg(
                        key: const ValueKey<String>('loop-id-alias-suggest'),
                        label:
                            context.l10n.account_idSetupLoopIdAliasSuggestLabel,
                        selected: false,
                        onSelected: editable
                            ? () => _suggest(controller)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            LoopLabel(context.l10n.account_idSetupLoopLabel2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
              child: LoopFocusRing(
                borderRadius: LoopRadius.card,
                enabled: editable,
                child: LoopSurfaceCard(
                  child: TextField(
                    key: const ValueKey<String>('loop-id-bio-field'),
                    controller: _bioController,
                    enabled: editable,
                    maxLength: profileMaximumBioCodePoints,
                    maxLines: 3,
                    minLines: 1,
                    style: LoopType.bodyLg,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      hintText: context.l10n.account_idSetupHintText2,
                    ),
                    onChanged: controller.editBio,
                  ),
                ),
              ),
            ),
            const LoopLabel('LOOP ID'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
              child: LoopSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (state.loopId case final String loopId)
                      LoopIdCopyLine(
                        loopId: loopId,
                        textKey: const ValueKey<String>('loop-id-value'),
                        copyKey: const ValueKey<String>('loop-id-copy'),
                        // M19 the setup page's main value: figureLg 20
                        // (decision 0191).
                        style: LoopType.figureLg,
                      )
                    else
                      Text(
                        key: const ValueKey<String>('loop-id-value'),
                        context.l10n.account_idSetupLoopIdValue,
                        style: LoopType.bodySm.copyWith(
                          color: LoopColors.text3,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.account_idSetupText,
                      style: LoopType.caption,
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
