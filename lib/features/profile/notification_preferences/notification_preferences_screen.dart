import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_diagnostics.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_providers.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/notifications/notification_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `notif-settings` · the ten reviewed notification categories.
///
/// `security.event` is locked on: the switch is not interactive and every
/// write carries `true`, because the server refuses `false` rather than
/// ignoring it. Delivery stays unavailable — there is no push channel.
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({
    super.key,
    this.onBack,
    this.onOpenSecurity,
  });

  final VoidCallback? onBack;

  /// Only the refusal block uses it: step-up is not delivered, so the security
  /// centre is the one honest destination for a `AUTH_STEP_UP_REQUIRED`.
  final VoidCallback? onOpenSecurity;

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  /// The one line the notification resource cannot say for itself.
  ///
  /// Availability and usability are different answers here. The server calls
  /// the capability available as soon as it has a push runtime, and separately
  /// records that no real device has been seen receiving anything yet. The
  /// first decides whether this device registers at all; the second is a claim
  /// the page must not make. Neither closes the switches: they change what the
  /// account is recorded as wanting, and that is true in every state.
  Widget _pushChannelNotice(LoopCapabilityProjection capability) {
    // Only the half the resource card cannot state. A closed capability is
    // already said once, in the server's own words, further down the page;
    // saying it twice on one screen reads as two different problems.
    if (capability.decision != LoopCapabilityDecision.available ||
        !capability.evidencePending) {
      return const SizedBox.shrink();
    }
    // Decision 0126: nothing here asks the reader to act, so it is an ⓘ
    // line, not a banner.
    return LoopNotice(
      key: ValueKey<String>('notification-preferences-push-channel'),
      icon: 'info',
      body: LoopL10n
          .current
          .profileNotificationPreferences_screenNotificationPreferencesPushChannelBody,
    );
  }

  /// What this device can say about its own registration.
  ///
  /// The capability document answers for LOOP; it cannot answer for the
  /// device in front of the reader. The card below used to be the only thing
  /// this page said about the channel, and it said the same thing whether the
  /// owner had refused notifications, the account was still being prepared,
  /// or the registration had never been attempted at all — the case that was
  /// true on every device until 2026-09-22.
  ///
  /// The two steps LOOP itself is the reason for are left to the card below,
  /// which already says them in the server's own words; repeating them here
  /// would read as two different problems on one screen.
  Widget _pushDeviceNotice() {
    return ValueListenableBuilder<LoopPushRegistrationDiagnostics>(
      valueListenable: ref.watch(loopPushRegistrationDiagnosticsProvider),
      builder: (context, diagnostics, _) => _pushDeviceCopy(
        diagnostics.gate,
        onOptIn: () => unawaited(
          ref
              .read(loopPushRegistrationCoordinatorProvider)
              .requestPermissionFromOwner(),
        ),
      ),
    );
  }

  static Widget _pushDeviceCopy(
    LoopPushRegistrationGate gate, {
    required VoidCallback onOptIn,
  }) {
    const key = ValueKey<String>('notification-preferences-push-device');
    switch (gate) {
      // Nothing has been attempted yet in this run, which is a moment rather
      // than a state, and the Preview composition never attempts anything at
      // all. Neither is a fact about the reader's device.
      case LoopPushRegistrationGate.notStarted:
      case LoopPushRegistrationGate.capabilityUnavailable:
      case LoopPushRegistrationGate.runtimeDeferred:
        return const SizedBox.shrink();
      case LoopPushRegistrationGate.registered:
        return LoopNotice(
          key: key,
          title: LoopL10n.current.profileNotificationPreferences_screenTitle,
          body: LoopL10n.current.profileNotificationPreferences_screenBody,
        );
      case LoopPushRegistrationGate.noPrincipal:
        return LoopNotice(
          key: key,
          title: LoopL10n.current.profileNotificationPreferences_screenTitle2,
          body: LoopL10n.current.profileNotificationPreferences_screenBody2,
        );
      // Decision 0076: the prompt waits for Community, which is
      // where this page's reader will be as soon as they leave 通知设置.
      case LoopPushRegistrationGate.awaitingCommunity:
        return LoopNotice(
          key: key,
          title: LoopL10n.current.profileNotificationPreferences_screenTitle2,
          body: LoopL10n.current.profileNotificationPreferences_screenBody3,
        );
      // Decision 0130 (audit 2026-10-09 M15): LOOP explains first and the
      // owner asks; the system dialog only follows the press.
      case LoopPushRegistrationGate.awaitingOptIn:
        return LoopNotice(
          key: const ValueKey<String>('notification-preferences-push-opt-in'),
          title: LoopL10n
              .current
              .profileNotificationPreferences_screenNotificationPreferencesPushOptInTitle,
          body: LoopL10n
              .current
              .profileNotificationPreferences_screenNotificationPreferencesPushOptInBody,
          trailing: LoopButton(
            key: const ValueKey<String>(
              'notification-preferences-push-opt-in-button',
            ),
            label: LoopL10n
                .current
                .profileNotificationPreferences_screenNotificationPreferencesPushOptInButtonLabel,
            primary: true,
            size: LoopButtonSize.compact,
            onPressed: onOptIn,
          ),
        );
      case LoopPushRegistrationGate.noPlatform:
      case LoopPushRegistrationGate.tokenSourceDisabled:
        return LoopNotice(
          key: key,
          title: LoopL10n.current.profileNotificationPreferences_screenTitle3,
          body: LoopL10n.current.profileNotificationPreferences_screenBody4,
        );
      case LoopPushRegistrationGate.permissionDenied:
        return LoopNotice(
          key: key,
          tone: LoopNoticeTone.warn,
          icon: 'warn',
          title: LoopL10n.current.profileNotificationPreferences_screenTitle4,
          body: LoopL10n.current.profileNotificationPreferences_screenBody5,
        );
      case LoopPushRegistrationGate.noTokenYet:
        return LoopNotice(
          key: key,
          title: LoopL10n.current.profileNotificationPreferences_screenTitle5,
          body: LoopL10n.current.profileNotificationPreferences_screenBody6,
        );
      case LoopPushRegistrationGate.gatewayNotProduction:
      case LoopPushRegistrationGate.registerFailed:
        return LoopNotice(
          key: key,
          tone: LoopNoticeTone.warn,
          icon: 'warn',
          title: LoopL10n.current.profileNotificationPreferences_screenTitle6,
          body: LoopL10n.current.profileNotificationPreferences_screenBody7,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.notificationsFeed),
    );
    final mode = ref.watch(notificationsGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final state = ref.watch(notificationPreferencesControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(notificationPreferencesControllerProvider.notifier).load(),
          );
        }
      });
    }
    final controller = ref.read(
      notificationPreferencesControllerProvider.notifier,
    );
    final resource = state.resource;

    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('notification-preferences-screen'),
        archetype: LoopPageArchetype.action,
        title: context.l10n.common_notificationSettings,
        kicker: loopChainPreviewKicker(mode),
        onBack: widget.onBack,
        // The prototype has no `[data-page-primary]` here: it opens on a Chalk
        // summary card and then goes straight to 挖矿. The hero that stood in
        // its place printed 「通知设置」 twice in one screen (§D+ #13).
        block: blocked
            ? LoopCapabilityPageBlock.of(
                key: const ValueKey<String>('notification-capability-block'),
                title: context
                    .l10n
                    .profileNotificationPreferences_screenNotificationCapabilityBlockTitle,
                capability: capability,
                fallbackReasonCode: 'NOTIFICATIONS_RUNTIME_UNAVAILABLE',
              )
            : null,
        sections: <Widget>[
          LoopChainPreviewNotice(
            mode: mode,
            resource: context.l10n.common_notificationSettings,
          ),
          // 0067 §7.6: the push channel is a separate fact from the ten
          // switches. Saving a preference has always worked; whether anything
          // can be delivered is the server's answer, and the page says which of
          // the two it is talking about rather than letting a switch imply both.
          _pushChannelNotice(
            ref.watch(
              loopCapabilityProvider(LoopV2CapabilityId.pushNotifications),
            ),
          ),
          // Decision 0126: the Chalk summary card became one ⓘ line.
          if (resource != null)
            LoopNotice(
              key: const ValueKey<String>('notification-preferences-summary'),
              icon: 'info',
              // 「9 项开启」 counted stored intents and read as nine kinds of
              // notification; only price alerts are emitted.
              body: context.l10n
                  .profileNotificationPreferences_screenNotificationPreferencesSummaryBody(
                    resource.deliveringEnabledCount,
                  ),
              margin: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                4,
                LoopSpacing.page,
                4,
              ),
            ),
          if (!state.isReady || resource == null)
            LoopChainStateBlock(
              keyPrefix: 'notification-preferences',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: context
                  .l10n
                  .profileNotificationPreferences_screenEmptyMessage,
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            if (state.requiresReload)
              LoopNotice(
                key: const ValueKey<String>(
                  'notification-preferences-conflict',
                ),
                tone: LoopNoticeTone.warn,
                icon: 'warn',
                title: context
                    .l10n
                    .profileNotificationPreferences_screenNotificationPreferencesConflictTitle,
                body: context
                    .l10n
                    .profileNotificationPreferences_screenNotificationPreferencesConflictBody,
                trailing: LoopButton(
                  key: const ValueKey<String>(
                    'notification-preferences-conflict-reload',
                  ),
                  label: context.l10n.common_reload,
                  onPressed: () => unawaited(controller.reload()),
                ),
              )
            // A save that never reached the server changed nothing on either
            // side. It is a pause, not a failure: the switches keep the values
            // that are still loaded and the page says which action stopped.
            else if (loopChainIsOffline(state.failureKind))
              LoopOfflineState(
                cause: loopOfflineCauseFor(state.failureKind),
                key: const ValueKey<String>(
                  'notification-preferences-save-offline',
                ),
                pausedActions: <String>[
                  context
                      .l10n
                      .profileNotificationPreferences_screenLoopOfflineState,
                ],
                onRetry: () => unawaited(controller.reload()),
              )
            else if (LoopChainCommandPermission.covers(state.failureKind))
              LoopChainCommandPermission(
                blockKey: 'notification-preferences-permission',
                failureKind: state.failureKind,
                title: context.l10n.profileNotificationPreferences_screenTitle7,
                onOpenSecurity: widget.onOpenSecurity,
              )
            else if (state.failureKind != null)
              LoopErrorState(
                key: const ValueKey<String>('notification-preferences-error'),
                title: context
                    .l10n
                    .profileNotificationPreferences_screenNotificationPreferencesErrorTitle,
                reason: loopChainFailureReason(state.failureKind),
                onRetry: () => unawaited(controller.reload()),
              ),
            // The server's own statement about the channel. Once it has one
            // this disappears and `_pushChannelNotice` takes over, because
            // "there is a channel" and "this device has been seen receiving
            // something" are two different claims and only the first is made
            // here.
            if (resource.push != null)
              LoopUnavailableLine.fact(
                key: const ValueKey<String>('notification-push-unavailable'),
                label: context
                    .l10n
                    .profileNotificationPreferences_screenNotificationPushUnavailableLabel,
                fact: resource.push!,
              ),
            // LOOP's own answer first, then this device's. They are two
            // different claims and the page keeps them apart.
            _pushDeviceNotice(),
            for (final section in _sections)
              ..._sectionWidgets(section, resource, state, controller),
            LoopProvenanceFooter(
              key: const ValueKey<String>('notification-preferences-version'),
              // The CAS version belongs to the write path, not to the page.
              text: resource.updatedAt == null
                  ? context
                        .l10n
                        .profileNotificationPreferences_screenNotificationPreferencesVersionText
                  : context.l10n
                        .profileNotificationPreferences_screenNotificationPreferencesVersionText2(
                          loopRelativeTime(resource.updatedAt!),
                        ),
            ),
          ],
        ],
      ),
    );
  }

  /// 挖矿 / Launch / 交易 / 社区 / 安全, in category order. Derived from the
  /// categories so the grouping holds in every language (decision 0281).
  static List<String> get _sections => LoopNotificationCategory.values
      .map((category) => category.section)
      .toSet()
      .toList(growable: false);

  List<Widget> _sectionWidgets(
    String section,
    LoopNotificationPreferences resource,
    NotificationPreferencesState state,
    NotificationPreferencesController controller,
  ) {
    final categories = LoopNotificationCategory.values
        .where((category) => category.section == section)
        .toList(growable: false);
    if (categories.isEmpty) return const <Widget>[];
    return <Widget>[
      LoopLabel(section),
      // `.label` + one card of `.row`s, not one card per switch: the same ten
      // categories used to run 1.7 screens long (audit 2026-09-21 §J.9).
      LoopRecordGroup(
        key: ValueKey<String>('notification-section-$section'),
        rows: <LoopRecordRow>[
          for (var index = 0; index < categories.length; index += 1)
            _categoryRow(
              categories[index],
              resource: resource,
              busy: state.busy || state.requiresReload,
              controller: controller,
              position: categories.length == 1
                  ? LoopRowPosition.single
                  : index == 0
                  ? LoopRowPosition.first
                  : index == categories.length - 1
                  ? LoopRowPosition.last
                  : LoopRowPosition.middle,
            ),
        ],
      ),
    ];
  }

  /// One category as `.row` + `.badge`.
  ///
  /// The prototype states a notification preference with a Lime 已开启 /
  /// muted 已关闭 pill. A Material `Switch` is not in `style-v2.css` and
  /// appears nowhere else in the app; beside the separate 暂不生效 pill it
  /// also put two status controls on one row (audit 2026-09-21 §D+ #12).
  LoopRecordRow _categoryRow(
    LoopNotificationCategory category, {
    required LoopNotificationPreferences resource,
    required bool busy,
    required NotificationPreferencesController controller,
    required LoopRowPosition position,
  }) {
    final enabled = resource.enabledFor(category);
    final locked = resource.lockedFor(category);
    final detail = <String>[
      // `securityEvent.detail` already says 无法关闭; nothing repeats it.
      ?category.detail,
      if (!category.deliversToday)
        LoopL10n.current.profileNotificationPreferences_screenCategoryRow,
    ].join(' · ');
    final state = enabled
        ? LoopL10n.current.common_on
        : LoopL10n.current.profileNotificationPreferences_screenS;
    return LoopRecordRow(
      key: ValueKey<String>('notification-category-${category.wireName}'),
      title: category.label,
      subtitle: detail.isEmpty ? null : detail,
      subtitleMaxLines: 2,
      // Decision 0126 supersedes the pill (audit §D+ #12): on a flat page a
      // preference is a switch, as on every settings list the reader knows.
      trailingBadge: LoopFlatSwitch(
        value: enabled,
        onChanged: locked || busy
            ? null
            : () => unawaited(_request(controller, category, !enabled)),
      ),
      position: position,
      chevron: false,
      semanticLabel:
          '${category.label}${LoopL10n.current.common_listSeparator}$state${detail.isEmpty ? '' : '${LoopL10n.current.common_listSeparator}$detail'}',
      onTap: locked || busy
          ? null
          : () => unawaited(_request(controller, category, !enabled)),
    );
  }

  /// Decision 0105 · 5: one tap turned a category off, and a stray one while
  /// scrolling did exactly that. Turning a category off asks first; turning
  /// one on does not, because it takes nothing away.
  Future<void> _request(
    NotificationPreferencesController controller,
    LoopNotificationCategory category,
    bool enabled,
  ) async {
    if (!enabled) {
      final confirmed = await confirmCommunityAction(
        context,
        title: notificationDisableTitle(category),
        body: notificationDisableBody(category),
        confirmLabel: LoopL10n.current.common_close,
        sheetKey: 'notification-disable-sheet',
      );
      if (!confirmed || !mounted) return;
    }
    await _toggle(controller, category, enabled);
  }

  Future<void> _toggle(
    NotificationPreferencesController controller,
    LoopNotificationCategory category,
    bool enabled,
  ) async {
    final applied = await controller.toggle(category, enabled);
    if (!mounted) return;
    if (applied) {
      LoopToast.show(
        context,
        message: LoopL10n.current.profileNotificationPreferences_screenMessage,
        kind: LoopToastKind.ok,
      );
    }
  }
}

/// The title of the sheet that confirms turning [category] off.
String notificationDisableTitle(LoopNotificationCategory category) => LoopL10n
    .current
    .profileNotificationPreferences_screenNotificationDisableTitle(
      category.label,
    );

/// The sheet's explanation: the category's own second line, or a plain
/// statement for a category that has none.
String notificationDisableBody(LoopNotificationCategory category) =>
    switch (category) {
      // Decision 0242: this row's detail lists what it covers, which reads as
      // a description rather than a consequence; the dialog says what goes.
      LoopNotificationCategory.launchRound =>
        LoopL10n.current.profileNotificationPreferences_screenLaunchRound,
      _ =>
        category.detail ??
            LoopL10n.current.profileNotificationPreferences_screenSwitch,
    };
