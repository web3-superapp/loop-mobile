import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_diagnostics.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_providers.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/notifications/notification_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
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
    return const LoopNotice(
      key: ValueKey<String>('notification-preferences-push-channel'),
      tone: LoopNoticeTone.warn,
      icon: 'warn',
      title: '推送还没有在真机上确认过',
      body: '推送通道已经配好，但还没有一台设备确认收到过。开关照常保存，也照常影响站内的通知列表。',
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
      builder: (context, diagnostics, _) => _pushDeviceCopy(diagnostics.gate),
    );
  }

  static Widget _pushDeviceCopy(LoopPushRegistrationGate gate) {
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
        return const LoopNotice(
          key: key,
          title: '这台设备已登记接收推送',
          body: '这不代表已经能送达。',
        );
      case LoopPushRegistrationGate.noPrincipal:
        return const LoopNotice(
          key: key,
          title: '还没有向这台设备请求通知权限',
          body: '账号准备好之后会请求一次。',
        );
      // Decision 0076: the prompt waits for Community, which is
      // where this page's reader will be as soon as they leave 通知设置.
      case LoopPushRegistrationGate.awaitingCommunity:
        return const LoopNotice(
          key: key,
          title: '还没有向这台设备请求通知权限',
          body: '进入社区后会请求一次。',
        );
      case LoopPushRegistrationGate.noPlatform:
      case LoopPushRegistrationGate.tokenSourceDisabled:
        return const LoopNotice(
          key: key,
          title: '这台设备上没有推送通道',
          body: '通知只会留在应用内的通知列表里。',
        );
      case LoopPushRegistrationGate.permissionDenied:
        return const LoopNotice(
          key: key,
          tone: LoopNoticeTone.warn,
          icon: 'warn',
          title: '通知权限已拒绝，这台设备收不到推送',
          body: '可以在系统设置里为 LOOP 重新打开通知。',
        );
      case LoopPushRegistrationGate.noTokenYet:
        return const LoopNotice(
          key: key,
          title: '正在等待系统分配推送通道',
          body: '拿到之后这台设备会自动登记。',
        );
      case LoopPushRegistrationGate.gatewayNotProduction:
      case LoopPushRegistrationGate.registerFailed:
        return const LoopNotice(
          key: key,
          tone: LoopNoticeTone.warn,
          icon: 'warn',
          title: '这台设备还没有登记成功',
          body: '下次回到 LOOP 时会再试一次。',
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

    return LoopDashboardPage(
      key: const ValueKey<String>('notification-preferences-screen'),
      archetype: LoopPageArchetype.action,
      title: '通知设置',
      kicker: loopChainPreviewKicker(mode),
      onBack: widget.onBack,
      // The prototype has no `[data-page-primary]` here: it opens on a Chalk
      // summary card and then goes straight to 挖矿. The hero that stood in
      // its place printed 「通知设置」 twice in one screen (§D+ #13).
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('notification-capability-block'),
              title: '通知设置当前不可用',
              capability: capability,
              fallbackReasonCode: 'NOTIFICATIONS_RUNTIME_UNAVAILABLE',
            )
          : null,
      sections: <Widget>[
        LoopChainPreviewNotice(mode: mode, resource: '通知设置'),
        // 0067 §7.6: the push channel is a separate fact from the ten
        // switches. Saving a preference has always worked; whether anything
        // can be delivered is the server's answer, and the page says which of
        // the two it is talking about rather than letting a switch imply both.
        _pushChannelNotice(
          ref.watch(
            loopCapabilityProvider(LoopV2CapabilityId.pushNotifications),
          ),
        ),
        if (resource != null)
          LoopChalkCard(
            key: const ValueKey<String>('notification-preferences-summary'),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'NOTIFICATION SUMMARY',
                  style: LoopTypography.eyebrow(
                    10,
                    color: LoopColors.ink.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 10),
                // 「9 项开启」 counted stored intents and read as nine kinds of
                // notification; only price alerts are emitted.
                Text(
                  '${resource.deliveringEnabledCount} 项开启并生效',
                  style: LoopTypography.heading(
                    26,
                    weight: FontWeight.w800,
                    color: LoopColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '安全事件始终开启且无法关闭；这里保存的是意图，不代表已经能送达。',
                  style: LoopTypography.caption(
                    11,
                    color: LoopColors.ink.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        if (!state.isReady || resource == null)
          LoopChainStateBlock(
            keyPrefix: 'notification-preferences',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '还没有通知设置',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          if (state.requiresReload)
            LoopNotice(
              key: const ValueKey<String>('notification-preferences-conflict'),
              tone: LoopNoticeTone.warn,
              icon: 'warn',
              title: '版本冲突 —— 没有覆盖任何内容',
              body: '通知设置已在其他设备上改动。请重新加载后再修改。',
              trailing: LoopButton(
                key: const ValueKey<String>(
                  'notification-preferences-conflict-reload',
                ),
                label: '重新加载',
                onPressed: () => unawaited(controller.reload()),
              ),
            )
          // A save that never reached the server changed nothing on either
          // side. It is a pause, not a failure: the switches keep the values
          // that are still loaded and the page says which action stopped.
          else if (state.failureKind == LoopChainFailureKind.offline)
            LoopOfflineState(
              key: const ValueKey<String>(
                'notification-preferences-save-offline',
              ),
              pausedActions: const <String>['保存通知设置'],
              onRetry: () => unawaited(controller.reload()),
            )
          else if (LoopChainCommandPermission.covers(state.failureKind))
            LoopChainCommandPermission(
              blockKey: 'notification-preferences-permission',
              failureKind: state.failureKind,
              title: '当前账号无权修改通知设置',
              onOpenSecurity: widget.onOpenSecurity,
            )
          else if (state.failureKind != null)
            LoopErrorState(
              key: const ValueKey<String>('notification-preferences-error'),
              title: '设置没有保存',
              reason: loopChainFailureReason(state.failureKind),
              onRetry: () => unawaited(controller.reload()),
            ),
          // The server's own statement about the channel. Once it has one
          // this disappears and `_pushChannelNotice` takes over, because
          // "there is a channel" and "this device has been seen receiving
          // something" are two different claims and only the first is made
          // here.
          if (resource.push != null)
            LoopUnavailableCard.fact(
              key: const ValueKey<String>('notification-push-unavailable'),
              label: '推送尚不可用',
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
                ? '当前使用默认设置'
                : '更新于 ${loopRelativeTime(resource.updatedAt!)}',
          ),
          const LoopNotice(
            key: ValueKey<String>('notification-preferences-notice'),
            title: '开关只是意图',
            body: '目前只有"价格提醒"会生成应用内通知，其他类别还没有开放。',
          ),
        ],
      ],
    );
  }

  static const List<String> _sections = <String>[
    '挖矿',
    'Launch',
    '交易',
    '社区',
    '安全',
  ];

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
      if (!category.deliversToday) '暂不生效',
    ].join(' · ');
    final state = enabled ? '已开启' : '已关闭';
    return LoopRecordRow(
      key: ValueKey<String>('notification-category-${category.wireName}'),
      title: category.label,
      subtitle: detail.isEmpty ? null : detail,
      subtitleMaxLines: 2,
      trailingBadge: LoopBadge(
        state,
        kind: enabled ? LoopBadgeKind.up : LoopBadgeKind.mute,
      ),
      position: position,
      chevron: false,
      semanticLabel:
          '${category.label}，$state${detail.isEmpty ? '' : '，$detail'}',
      onTap: locked || busy
          ? null
          : () => unawaited(_toggle(controller, category, !enabled)),
    );
  }

  Future<void> _toggle(
    NotificationPreferencesController controller,
    LoopNotificationCategory category,
    bool enabled,
  ) async {
    final applied = await controller.toggle(category, enabled);
    if (!mounted) return;
    if (applied) {
      LoopToast.show(context, message: '通知设置已保存', kind: LoopToastKind.ok);
    }
  }
}
