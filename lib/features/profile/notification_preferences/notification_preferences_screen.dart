import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
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
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('notification-preferences-folio'),
        archetype: LoopFolioArchetype.action,
        kicker: 'NOTIFICATION SUMMARY',
        heading: resource == null ? '通知设置' : '${resource.enabledCount} 项开启',
        caption: '安全事件始终开启且无法关闭；这里保存的是意图，不代表已经能送达。',
      ),
      sections: <Widget>[
        LoopChainPreviewNotice(mode: mode, resource: '通知设置'),
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('notification-capability-block'),
            label: '通知设置当前不可用',
            reasonCode:
                capability.reasonCode ?? 'NOTIFICATIONS_RUNTIME_UNAVAILABLE',
          )
        else if (!state.isReady || resource == null)
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
          LoopUnavailableCard.fact(
            key: const ValueKey<String>('notification-push-unavailable'),
            label: '推送尚不可用',
            fact: resource.push,
          ),
          for (final section in _sections)
            ..._sectionWidgets(section, resource, state, controller),
          LoopProvenanceFooter(
            key: const ValueKey<String>('notification-preferences-version'),
            text: resource.updatedAt == null
                ? '尚未写入过设置（版本 ${resource.version}）'
                : '版本 ${resource.version} · '
                      '更新于 ${loopRelativeTime(resource.updatedAt!)}',
          ),
          const LoopNotice(
            key: ValueKey<String>('notification-preferences-notice'),
            title: '开关只是意图',
            body: '目前只有"价格提醒"会生成应用内通知，其他类别还没有开放。推送暂时不可用。',
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
      for (final category in categories)
        _CategorySwitch(
          key: ValueKey<String>('notification-category-${category.wireName}'),
          category: category,
          enabled: resource.enabledFor(category),
          locked: resource.lockedFor(category),
          busy: state.busy || state.requiresReload,
          onChanged: (value) => unawaited(_toggle(controller, category, value)),
        ),
    ];
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

class _CategorySwitch extends StatelessWidget {
  const _CategorySwitch({
    required this.category,
    required this.enabled,
    required this.locked,
    required this.busy,
    required this.onChanged,
    super.key,
  });

  final LoopNotificationCategory category;
  final bool enabled;
  final bool locked;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return LoopSurfaceCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  category.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (category.detail != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    category.detail!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (locked)
            const LoopBadge('无法关闭', kind: LoopBadgeKind.up)
          else
            Switch(
              key: ValueKey<String>('notification-switch-${category.wireName}'),
              value: enabled,
              onChanged: busy ? null : onChanged,
            ),
        ],
      ),
    );
  }
}
