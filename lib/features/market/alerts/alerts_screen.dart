import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_controller.dart';
import 'package:loop_mobile/features/market/alerts/alerts_gateway.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `alerts` · price alerts plus the context notification feed.
///
/// The threshold is a decimal STRING end to end: it is validated against the
/// contract pattern here and sent verbatim, because a JSON number is rejected
/// by the server before type coercion. Distance to target is computed on the
/// client from the current market price and is never a server fact.
class PriceAlertsScreen extends ConsumerStatefulWidget {
  const PriceAlertsScreen({
    super.key,
    this.assetId,
    this.onBack,
    this.onNavigate,
  });

  /// Optional: pre-selects the asset when the page is opened from `token`.
  final String? assetId;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends ConsumerState<PriceAlertsScreen> {
  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.priceAlerts),
    );
    final mode = ref.watch(alertsGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final state = ref.watch(alertsControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(alertsControllerProvider.notifier).load());
        }
      });
    }
    final controller = ref.read(alertsControllerProvider.notifier);
    final armed = state.page?.armed ?? const <LoopPriceAlert>[];

    return LoopDashboardPage(
      key: const ValueKey<String>('alerts-screen'),
      archetype: LoopPageArchetype.listing,
      title: '价格提醒',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('alerts-create-action'),
          icon: 'bell',
          label: '新建价格提醒',
          onPressed: blocked || state.busy
              ? null
              : () => unawaited(_openEditor(controller)),
        ),
      ],
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('alerts-folio'),
        archetype: LoopFolioArchetype.listing,
        kicker: 'PRICE ALERTS',
        heading: state.isReady ? '${armed.length} 个提醒正在监听' : '价格提醒',
        caption: '触发一次后提醒会停下来，重新编辑才会再次生效。',
        stamp: state.isReady ? '${armed.length} ACTIVE' : null,
      ),
      sections: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('alerts-capability-block'),
            label: '价格提醒当前不可用',
            reasonCode: capability.reasonCode ?? 'ALERTS_RUNTIME_UNAVAILABLE',
          )
        else if (!state.isReady)
          LoopChainStateBlock(
            keyPrefix: 'alerts',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '还没有价格提醒',
            emptyReason: '新建一个提醒后，评估器会在价格新鲜时检查它。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          if (state.failureKind != null)
            LoopErrorState(
              key: const ValueKey<String>('alerts-command-error'),
              title: '提醒没有更新',
              reason: loopChainFailureReason(state.failureKind),
              onRetry: () => unawaited(controller.reload()),
            ),
          const LoopLabel('已设提醒'),
          if (state.items.isEmpty)
            LoopEmpty(
              key: const ValueKey<String>('alerts-empty'),
              message: '还没有价格提醒',
              reason: '新建一个提醒后，评估器会在价格新鲜时检查它。',
              action: LoopButton(
                key: const ValueKey<String>('alerts-empty-create'),
                label: '新建提醒',
                onPressed: () => unawaited(_openEditor(controller)),
              ),
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final alert in state.items) _alertRow(alert, controller),
              ],
            ),
          const LoopLabel('触发历史'),
          const _AlertNotificationFeed(),
          const LoopNotice(
            key: ValueKey<String>('alerts-push-notice'),
            title: '推送尚不可用',
            body: '没有接入 FCM / APNs，提醒只会出现在应用内的通知列表里。评估器只用新鲜价格，过期价格不会触发。',
            tone: LoopNoticeTone.warn,
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('alerts-notification-settings'),
                title: '通知设置',
                subtitle: '关闭价格提醒类别后仍会记录事件，但不会生成通知',
                onTap: () => _open('/profile/notifications'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  LoopRecordRow _alertRow(LoopPriceAlert alert, AlertsController controller) {
    final currentPrice = _currentPriceFor(alert.assetId);
    final distance = alert.distancePercent(currentPrice);
    return LoopRecordRow(
      key: ValueKey<String>('alert-${alert.alertId}'),
      title: alert.headline,
      subtitle: <String>[
        alert.state.label,
        if (distance != null) '距目标 ${loopFormatPercent(distance)}',
        if (alert.lastEvaluatedAt == null)
          '评估器还没有看过这条'
        else
          '评估于 ${loopRelativeTime(alert.lastEvaluatedAt!)}',
      ].join(' · '),
      trailingBadge: LoopBadge(
        alert.state.label,
        kind: switch (alert.state) {
          LoopAlertState.active => LoopBadgeKind.up,
          LoopAlertState.triggered => LoopBadgeKind.mining,
          LoopAlertState.expired => LoopBadgeKind.mute,
        },
      ),
      onTap: () => unawaited(_openEditor(controller, existing: alert)),
    );
  }

  Decimal? _currentPriceFor(String assetId) {
    final detail = ref.watch(marketAssetControllerProvider(assetId)).value;
    return detail?.price.value;
  }

  Future<void> _openEditor(
    AlertsController controller, {
    LoopPriceAlert? existing,
  }) async {
    final result = await showModalBottomSheet<_AlertEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AlertEditorSheet(
        existing: existing,
        initialAssetId: existing?.assetId ?? widget.assetId,
      ),
    );
    if (result == null || !mounted) return;
    final bool applied;
    if (result.delete && existing != null) {
      applied = await controller.delete(existing);
    } else if (existing != null) {
      applied = await controller.update(alert: existing, draft: result.draft!);
    } else {
      applied = await controller.create(result.draft!);
    }
    if (!mounted) return;
    if (applied) {
      LoopToast.show(
        context,
        message: result.delete ? '提醒已删除' : '提醒已保存',
        kind: LoopToastKind.ok,
      );
    }
  }
}

class _AlertEditorResult {
  const _AlertEditorResult({this.draft, this.delete = false});

  final LoopAlertDraft? draft;
  final bool delete;
}

class _AlertEditorSheet extends StatefulWidget {
  const _AlertEditorSheet({
    required this.existing,
    required this.initialAssetId,
  });

  final LoopPriceAlert? existing;
  final String? initialAssetId;

  @override
  State<_AlertEditorSheet> createState() => _AlertEditorSheetState();
}

class _AlertEditorSheetState extends State<_AlertEditorSheet> {
  late final TextEditingController _assetController;
  late final TextEditingController _thresholdController;
  late LoopAlertCondition _condition;
  String? _error;

  @override
  void initState() {
    super.initState();
    _assetController = TextEditingController(
      text: widget.existing?.assetId ?? widget.initialAssetId ?? '',
    );
    _thresholdController = TextEditingController(
      text: widget.existing?.thresholdText ?? '',
    );
    _condition = widget.existing?.condition ?? LoopAlertCondition.atOrAbove;
  }

  @override
  void dispose() {
    _assetController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _submit() {
    final draft = LoopAlertDraft(
      assetId: _assetController.text.trim(),
      condition: _condition,
      threshold: _thresholdController.text.trim(),
      expiresAt: widget.existing?.expiresAt,
    );
    final invalid = draft.invalidField;
    if (invalid != null) {
      setState(() {
        _error = switch (invalid) {
          'assetId' => '资产标识必须是规范的 CAIP id，例如 eip155:56:0x…',
          'threshold' => '阈值必须是正的十进制数字，最多 18 位小数。',
          _ => '过期时间必须在未来。',
        };
      });
      return;
    }
    Navigator.of(context).pop(_AlertEditorResult(draft: draft));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return LoopSheet(
      title: existing == null ? '新建价格提醒' : '编辑价格提醒',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('alert-asset-field'),
            controller: _assetController,
            enabled: existing == null,
            decoration: const InputDecoration(
              labelText: '资产标识（CAIP assetId）',
              hintText: 'eip155:56:0x…',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final condition in LoopAlertCondition.values)
                LoopSeg(
                  key: ValueKey<String>(
                    'alert-condition-${condition.wireName}',
                  ),
                  label: condition.label,
                  selected: condition == _condition,
                  onSelected: () => setState(() => _condition = condition),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('alert-threshold-field'),
            controller: _thresholdController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // The threshold never becomes a `double`: it stays the exact text
            // the user typed all the way to the wire.
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: '阈值（USD）',
              hintText: '例如 800.5',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const ValueKey<String>('alert-editor-error'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
          const SizedBox(height: 16),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                label: '取消',
                onPressed: () => Navigator.of(context).pop(),
              ),
              LoopButton(
                key: const ValueKey<String>('alert-editor-submit'),
                label: '保存',
                primary: true,
                onPressed: _submit,
              ),
            ],
          ),
          if (existing != null) ...<Widget>[
            const SizedBox(height: 10),
            LoopButton(
              key: const ValueKey<String>('alert-editor-delete'),
              label: '删除这个提醒',
              block: true,
              onPressed: () =>
                  Navigator.of(context)
                      .pop(const _AlertEditorResult(delete: true)),
            ),
          ],
        ],
      ),
    );
  }
}

/// The trigger history: the feed entries whose type is `trade.priceAlert`.
class _AlertNotificationFeed extends ConsumerStatefulWidget {
  const _AlertNotificationFeed();

  @override
  ConsumerState<_AlertNotificationFeed> createState() =>
      _AlertNotificationFeedState();
}

class _AlertNotificationFeedState
    extends ConsumerState<_AlertNotificationFeed> {
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
    if (feed == null) {
      return LoopChainStateBlock(
        keyPrefix: 'alerts-feed',
        phase: state.phase,
        failureKind: state.failureKind,
        rows: 2,
        emptyMessage: '还没有触发记录',
        onRetry: () => unawaited(
          ref.read(notificationFeedControllerProvider.notifier).reload(),
        ),
      );
    }
    final entries = feed.priceAlerts;
    if (entries.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('alerts-feed-empty'),
        message: '还没有触发记录',
        reason: '提醒触发后会在这里留下一条带来源与观察时间的记录。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (final entry in entries)
              LoopRecordRow(
                key: ValueKey<String>('alerts-feed-${entry.notificationId}'),
                title: _feedTitle(entry),
                subtitle: _feedDetail(entry),
                trailingBadge: entry.isUnread ? const LoopBadge('未读') : null,
                onTap: entry.isUnread
                    ? () => unawaited(
                        ref
                            .read(notificationFeedControllerProvider.notifier)
                            .markRead(entry.notificationId),
                      )
                    : null,
              ),
          ],
        ),
        LoopProvenanceFooter(
          key: const ValueKey<String>('alerts-feed-unread'),
          text:
              '未读 ${feed.unreadCount} 条 · '
              '${loopReasonCodeText(feed.push.reasonCode)}',
        ),
      ],
    );
  }
}

String _feedTitle(LoopNotificationEntry entry) {
  final symbol = entry.payload['symbol'];
  final threshold = entry.payload['threshold'];
  final observed = entry.payload['observedValue'];
  if (symbol == null || threshold == null || observed == null) {
    return '价格提醒已触发';
  }
  return '$symbol 触发 $threshold（观察值 $observed）';
}

String _feedDetail(LoopNotificationEntry entry) {
  final source = entry.source;
  final observedAt = entry.observedAt;
  return <String>[
    if (source != null) '来源 $source',
    if (observedAt != null) '观察于 ${loopRelativeTime(observedAt)}',
    if (entry.priceAlertId != null) '提醒 ${entry.priceAlertId}',
  ].join(' · ');
}

/// Kept so a caller can build the alerts route without importing the model.
String alertsRouteFor(String assetId) => MarketAssetRoute.alerts(assetId);
