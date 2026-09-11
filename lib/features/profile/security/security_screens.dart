import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/security/security_controllers.dart';
import 'package:loop_mobile/features/profile/security/security_gateway.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The four D20 security surfaces (decision 0037).
///
/// Nothing on these pages claims a protection is enabled, a device was signed
/// out, or a guardian exists. The prototype's score badge, "3 项保护已开启"
/// heading, device names, geography, exported-key variant and guardian samples
/// have no backend source and are deliberately absent.

/// Copy shared by every unavailable security method.
const _securityMethodUnavailableLabel = '未开启';

bool _securityBlocked(
  LoopChainGatewayMode mode,
  LoopCapabilityProjection capability,
) => loopChainCapabilityBlocks(mode, capability);

/// One `unavailable` security method row plus its "how to enable" note.
class _SecurityMethodRow extends LoopRecordRow {
  _SecurityMethodRow({
    required LoopSecurityCapability capability,
    required super.position,
    super.onTap,
  }) : super(
         key: ValueKey<String>('security-method-${capability.id.wireName}'),
         title: capability.id.label,
         subtitle: loopReasonCodeText(capability.reasonCode),
         trailingBadge: const LoopBadge(_securityMethodUnavailableLabel),
         semanticLabel:
             '${capability.id.label}，$_securityMethodUnavailableLabel，'
             '${loopReasonCodeText(capability.reasonCode)}',
       );
}

/// `security` · summary + the six unavailable methods + recent events.
class SecurityCenterScreen extends ConsumerStatefulWidget {
  const SecurityCenterScreen({
    required this.onNavigate,
    super.key,
    this.onBack,
  });

  final ValueChanged<String> onNavigate;
  final VoidCallback? onBack;

  @override
  ConsumerState<SecurityCenterScreen> createState() =>
      _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends ConsumerState<SecurityCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.security),
    );
    final mode = ref.watch(securityGatewayProvider).mode;
    final blocked = _securityBlocked(mode, capability);
    final summary = ref.watch(securitySummaryControllerProvider);
    final methods = ref.watch(securityCapabilitiesControllerProvider);
    if (!blocked) {
      if (summary.phase == LoopChainViewPhase.loading) {
        scheduleMicrotask(() {
          if (mounted) {
            unawaited(
              ref.read(securitySummaryControllerProvider.notifier).load(),
            );
          }
        });
      }
      if (methods.phase == LoopChainViewPhase.loading) {
        scheduleMicrotask(() {
          if (mounted) {
            unawaited(
              ref.read(securityCapabilitiesControllerProvider.notifier).load(),
            );
          }
        });
      }
    }
    final resource = summary.value;
    final devices = resource?.devices;

    return LoopDashboardPage(
      key: const ValueKey<String>('security-screen'),
      archetype: LoopPageArchetype.action,
      title: '安全中心',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('security-folio'),
        archetype: LoopFolioArchetype.action,
        kicker: 'SECURITY POSTURE',
        heading: switch (devices) {
          LoopSecurityDevicesAvailable(
            deviceCount: final count,
            activeSessionCount: final sessions,
          ) =>
            '$count 台设备 · $sessions 个会话',
          _ => '安全中心',
        },
        caption: '这里不打安全评分。每一项只显示它自己的状态与原因；未开启就是未开启。',
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('security-capability-block'),
              title: '安全中心当前不可用',
              capability: capability,
              fallbackReasonCode: 'SECURITY_RUNTIME_UNAVAILABLE',
            )
          : null,
      sections: <Widget>[
        const LoopLabel('账户保护'),
        if (!methods.isReady)
          LoopChainStateBlock(
            keyPrefix: 'security-methods',
            phase: methods.phase,
            failureKind: methods.failureKind,
            emptyMessage: '没有可展示的安全能力',
            onRetry: () => unawaited(
              ref
                  .read(securityCapabilitiesControllerProvider.notifier)
                  .reload(),
            ),
          )
        else
          _SecurityMethodGroup(
            capabilities: methods.value!,
            onNavigate: widget.onNavigate,
          ),
        const LoopLabel('设备'),
        if (!summary.isReady)
          LoopChainStateBlock(
            keyPrefix: 'security-summary',
            phase: summary.phase,
            failureKind: summary.failureKind,
            emptyMessage: '还没有安全汇总',
            onRetry: () => unawaited(
              ref.read(securitySummaryControllerProvider.notifier).reload(),
            ),
          )
        else ...<Widget>[
          _SecurityDevicesBlock(
            block: resource!.devices,
            onOpenDevices: () => widget.onNavigate('devices'),
          ),
          const LoopLabel('授权盘点'),
          _SecurityApprovalsBlock(block: resource.approvals),
          const LoopLabel('通知'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('security-notification-lock'),
                title: '安全事件通知',
                subtitle: '始终开启，无法关闭；保存的是意图，不代表已经能送达。',
                trailingBadge: const LoopBadge('已开启', kind: LoopBadgeKind.up),
                onTap: () => widget.onNavigate('notif-settings'),
              ),
            ],
          ),
          const LoopLabel('最近安全事件'),
          _SecurityEventsBlock(block: resource.recentSecurityEvents),
          LoopProvenanceFooter(
            key: const ValueKey<String>('security-observed-at'),
            text: '观察于 ${loopRelativeTime(resource.observedAt)}',
          ),
        ],
        const LoopNotice(
          key: ValueKey<String>('security-scope-notice'),
          icon: 'shield',
          title: '这一页只说明状态',
          body:
              'LOOP 不会在本地模拟"已开启"。多因素验证、Passkey、恢复与导出都由 Privy 提供，'
              '在完成验证之前，它们对所有账号都不可用。',
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SecurityMethodGroup extends StatelessWidget {
  const _SecurityMethodGroup({
    required this.capabilities,
    required this.onNavigate,
  });

  final LoopSecurityCapabilities capabilities;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final items = capabilities.items;
    return Column(
      children: <Widget>[
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (var index = 0; index < items.length; index += 1)
              _SecurityMethodRow(
                capability: items[index],
                position: LoopRowPosition.middle,
                onTap: switch (items[index].id) {
                  LoopSecurityCapabilityId.socialRecovery => () => onNavigate(
                    'social-recovery',
                  ),
                  LoopSecurityCapabilityId.keyExport => () => onNavigate(
                    'key-export',
                  ),
                  _ => null,
                },
              ),
          ],
        ),
        LoopDisclosure(
          key: const ValueKey<String>('security-methods-guide'),
          summary: '这些保护怎么开启',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.id.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.id.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityDevicesBlock extends StatelessWidget {
  const _SecurityDevicesBlock({
    required this.block,
    required this.onOpenDevices,
  });

  final LoopSecurityDevicesBlock block;
  final VoidCallback onOpenDevices;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      LoopSecurityDevicesUnavailable(fact: final fact) =>
        LoopUnavailableCard.fact(
          key: const ValueKey<String>('security-devices-unavailable'),
          label: '设备与会话读不到',
          fact: fact,
        ),
      LoopSecurityDevicesAvailable(
        deviceCount: final count,
        activeSessionCount: final sessions,
        newSessions24h: final recent,
        highRiskNewDevice: final risky,
        policy: final policy,
      ) =>
        Column(
          children: <Widget>[
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('security-devices-entry'),
                  title: '已登录设备',
                  subtitle:
                      '$sessions 个活跃会话 · 最近 ${policy.windowHours} 小时新增 $recent 个',
                  trailing: '$count',
                  onTap: onOpenDevices,
                ),
              ],
            ),
            if (risky)
              LoopNotice(
                key: const ValueKey<String>('security-high-risk-notice'),
                icon: 'warn',
                tone: LoopNoticeTone.warn,
                title: '最近新增了多个会话',
                body:
                    '最近 ${policy.windowHours} 小时内新建了 $recent 个会话，达到提示阈值 '
                    '${policy.newSessionThreshold}。'
                    '这只是提示，不会因此要求二次验证或冷却。',
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              ),
          ],
        ),
    };
  }
}

class _SecurityApprovalsBlock extends StatelessWidget {
  const _SecurityApprovalsBlock({required this.block});

  final LoopSecurityApprovalsBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      LoopSecurityApprovalsUnavailable(fact: final fact) =>
        LoopUnavailableCard.fact(
          key: const ValueKey<String>('security-approvals-unavailable'),
          label: '授权盘点读不到',
          fact: fact,
        ),
      LoopSecurityApprovalsAvailable(
        activeCount: final active,
        unlimitedCount: final unlimited,
        indexerBlockNumber: final indexed,
        approvalCoverageFromBlockNumber: final coverageFrom,
        headBlockNumber: final head,
        observedAt: final observedAt,
      ) =>
        Column(
          children: <Widget>[
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('security-approvals-active'),
                  title: '有效授权',
                  subtitle: '当前钱包上仍然生效的 ERC-20 授权',
                  trailing: '$active',
                  position: LoopRowPosition.first,
                ),
                LoopRecordRow(
                  key: const ValueKey<String>('security-approvals-unlimited'),
                  title: '无限额度授权',
                  subtitle: '额度没有上限的授权，风险最高',
                  trailing: '$unlimited',
                  position: LoopRowPosition.last,
                ),
              ],
            ),
            LoopProvenanceFooter(
              key: const ValueKey<String>('security-approvals-freshness'),
              text:
                  '授权记录自区块 $coverageFrom 起 · '
                  '索引高度 $indexed / 链头 $head · '
                  '观察于 ${loopRelativeTime(observedAt)}',
            ),
          ],
        ),
    };
  }
}

class _SecurityEventsBlock extends StatelessWidget {
  const _SecurityEventsBlock({required this.block});

  final LoopSecurityEventsBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      LoopSecurityEventsUnavailable(fact: final fact) =>
        LoopUnavailableCard.fact(
          key: const ValueKey<String>('security-events-unavailable'),
          label: '最近安全事件读不到',
          fact: fact,
        ),
      LoopSecurityEventsAvailable(items: final items) when items.isEmpty =>
        const LoopEmpty(
          key: ValueKey<String>('security-events-empty'),
          message: '还没有安全事件',
          reason: '目前只有"撤销其他设备"会记录一条安全事件。',
        ),
      LoopSecurityEventsAvailable(items: final items) => LoopRecordGroup(
        rows: <LoopRecordRow>[
          for (final item in items)
            LoopRecordRow(
              key: ValueKey<String>('security-event-${item.notificationId}'),
              title: item.payload['event'] == 'session_revoked'
                  ? '撤销了一个设备会话'
                  : '安全事件',
              subtitle:
                  '${item.payload['platform'] ?? '未标注平台'} · '
                  '${loopRelativeTime(item.createdAt)}'
                  '${item.source == null ? '' : ' · 来源 ${item.source}'}',
              position: LoopRowPosition.middle,
            ),
        ],
      ),
    };
  }
}

/// `devices` · the session list plus the audit-only revoke command.
class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState
    extends ConsumerState<DeviceManagementScreen> {
  Future<void> _confirmRevoke(LoopDeviceSession device) async {
    final confirmed = await showLoopSheet<bool>(
      context,
      builder: (sheetContext) => _RevokeConfirmSheet(device: device),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(devicesControllerProvider.notifier)
        .revoke(device.sessionId);
    if (!mounted) return;
    LoopToast.show(
      context,
      message: ok ? '已记录撤销，对方访问未终止' : '撤销没有完成',
      kind: ok ? LoopToastKind.warn : LoopToastKind.err,
    );
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.security),
    );
    final mode = ref.watch(securityGatewayProvider).mode;
    final blocked = _securityBlocked(mode, capability);
    final state = ref.watch(devicesControllerProvider);
    if (!blocked && state.resource.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(devicesControllerProvider.notifier).load());
        }
      });
    }
    final directory = state.resource.value;
    final controller = ref.read(devicesControllerProvider.notifier);

    return LoopDashboardPage(
      key: const ValueKey<String>('devices-screen'),
      archetype: LoopPageArchetype.action,
      title: '设备管理',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('devices-folio'),
        archetype: LoopFolioArchetype.action,
        kicker: 'DEVICE SESSIONS',
        heading: directory == null
            ? '设备管理'
            : '${directory.deviceCount} 台设备 · ${directory.activeCount} 个会话',
        caption: '这里不显示设备名称和位置，只显示平台、版本与最后活跃时间。',
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('devices-capability-block'),
              title: '设备管理当前不可用',
              capability: capability,
              fallbackReasonCode: 'SECURITY_RUNTIME_UNAVAILABLE',
            )
          : null,
      sections: <Widget>[
        if (state.commandFailureKind != null)
          LoopErrorState(
            key: const ValueKey<String>('devices-command-error'),
            title: '撤销没有完成',
            reason: loopChainFailureReason(state.commandFailureKind),
            onRetry: () => unawaited(controller.reload()),
          ),
        if (state.outcome != null)
          LoopNotice(
            key: const ValueKey<String>('devices-revoke-outcome'),
            icon: 'info',
            tone: LoopNoticeTone.warn,
            title: '已记录撤销，对方访问未终止',
            body:
                'LOOP 已把该会话标记为已撤销，并拒绝之后携带它的请求。'
                '对方设备的 Privy 访问令牌不受影响'
                '（providerAccessTerminated: '
                '${state.outcome!.providerAccessTerminated}）。',
          ),
        if (!state.resource.isReady)
          LoopChainStateBlock(
            keyPrefix: 'devices',
            phase: state.resource.phase,
            failureKind: state.resource.failureKind,
            emptyMessage: '没有可显示的设备会话',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          if (directory!.riskSignals.highRiskNewDevice)
            LoopNotice(
              key: const ValueKey<String>('devices-high-risk-notice'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '最近新增了多个会话',
              body:
                  '最近 ${directory.riskSignals.policy.windowHours} 小时内新建了 '
                  '${directory.riskSignals.newSessions24h} 个会话，达到提示阈值 '
                  '${directory.riskSignals.policy.newSessionThreshold}。'
                  '这只是提示，不会因此要求二次验证。',
            ),
          if (directory.currentSessionId == null)
            const LoopNotice(
              key: ValueKey<String>('devices-current-unknown'),
              icon: 'info',
              title: '无法标记当前设备',
              body: '本机没有可用的会话标识，因此列表里没有任何一行被标为"当前"。',
            ),
          const LoopLabel('会话'),
          if (directory.devices.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('devices-state-empty'),
              message: '还没有设备会话',
              reason: '这个账号还没有完成过一次设备初始化。',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final device in directory.devices)
                  _deviceRow(device, busy: state.busy),
              ],
            ),
          if (directory.truncated)
            const LoopNotice(
              key: ValueKey<String>('devices-truncated'),
              icon: 'info',
              title: '列表已被截断',
              body: '最多显示 100 条会话，暂时不能翻页。',
            ),
          const LoopLabel('全部设备'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('devices-revoke-all'),
              label: '下线所有其他设备',
              block: true,
              // Always refused: it needs a second factor that does not exist.
              onPressed: null,
            ),
          ),
          LoopUnavailableCard.fact(
            key: const ValueKey<String>('devices-revoke-all-unavailable'),
            label: '需要二次验证，当前不可执行',
            fact: directory.revokeAll,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          ),
          LoopProvenanceFooter(
            key: const ValueKey<String>('devices-observed-at'),
            text: '观察于 ${loopRelativeTime(directory.observedAt)}',
          ),
        ],
        const LoopNotice(
          key: ValueKey<String>('devices-effect-notice'),
          icon: 'shield',
          title: '撤销能做到什么',
          body:
              '撤销会把该会话记为已撤销，并让 LOOP 拒绝之后携带它的请求。'
              '它不会终止对方设备上的 Privy 登录，所以不能理解为对方已经退出。'
              '退出本机请使用设置页的退出登录。',
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  LoopRecordRow _deviceRow(LoopDeviceSession device, {required bool busy}) {
    final revoked = !device.isActive;
    final badge = device.isCurrent
        ? const LoopBadge('当前设备', kind: LoopBadgeKind.up)
        : (revoked
              ? const LoopBadge('已撤销')
              : const LoopBadge('其他设备', kind: LoopBadgeKind.mute));
    return LoopRecordRow(
      key: ValueKey<String>('device-${device.sessionId}'),
      leading: LoopIcon(
        device.platform == LoopDevicePlatform.ios ? 'phone' : 'laptop',
        semanticLabel: device.platform.label,
      ),
      title: device.displayName,
      subtitle: revoked
          ? '已于 ${loopRelativeTime(device.revokedAt!)}撤销'
          : '最后活跃 ${loopRelativeTime(device.lastSeenAt)} · '
                '${device.authStrength.label}',
      trailingBadge: badge,
      position: LoopRowPosition.middle,
      onTap: device.isCurrent || revoked || busy
          ? null
          : () => unawaited(_confirmRevoke(device)),
      semanticLabel: '${device.displayName}，${revoked ? '已撤销' : '活跃'}',
    );
  }
}

/// The confirmation sheet for revoking one other session.
///
/// It states the real effect before the command, not after it.
class _RevokeConfirmSheet extends StatelessWidget {
  const _RevokeConfirmSheet({required this.device});

  final LoopDeviceSession device;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('device-revoke-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('撤销这个会话？', style: Theme.of(context).textTheme.titleLarge),
        ),
        LoopKeyValue(label: '平台', value: device.platform.label),
        LoopKeyValue(label: '客户端版本', value: device.clientVersion),
        LoopKeyValue(label: '最后活跃', value: loopRelativeTime(device.lastSeenAt)),
        const LoopNotice(
          key: ValueKey<String>('device-revoke-sheet-effect'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '撤销后会发生什么',
          body:
              'LOOP 会把这个会话记为已撤销，并拒绝之后携带它的请求，同时写入一条安全事件。'
              '对方设备上的 Privy 登录不会被终止。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('device-revoke-cancel'),
              label: '取消',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            LoopButton(
              key: const ValueKey<String>('device-revoke-confirm'),
              label: '撤销会话',
              primary: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// `key-export` · explanation only. The export itself cannot run.
class KeyExportScreen extends ConsumerStatefulWidget {
  const KeyExportScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<KeyExportScreen> createState() => _KeyExportScreenState();
}

class _KeyExportScreenState extends ConsumerState<KeyExportScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.security),
    );
    final mode = ref.watch(securityGatewayProvider).mode;
    final blocked = _securityBlocked(mode, capability);
    final methods = ref.watch(securityCapabilitiesControllerProvider);
    if (!blocked && methods.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(securityCapabilitiesControllerProvider.notifier).load(),
          );
        }
      });
    }
    final method = methods.value?[LoopSecurityCapabilityId.keyExport];

    return LoopFocusPage(
      key: const ValueKey<String>('key-export-screen'),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('key-export-capability-block'),
              title: '导出私钥当前不可用',
              capability: capability,
              fallbackReasonCode: 'SECURITY_RUNTIME_UNAVAILABLE',
            )
          : null,
      archetype: LoopPageArchetype.action,
      title: '导出私钥',
      onBack: widget.onBack,
      folio: const LoopFolioPrimary(
        key: ValueKey<String>('key-export-folio'),
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.action,
        kicker: 'WALLET KEY CONTROL',
        heading: '私钥由你控制',
        caption: '这是你的逃生舱：导出后可以把资产带到任何钱包，不受 LOOP 或 Privy 限制。',
        stamp: 'SENSITIVE',
      ),
      body: <Widget>[
        const LoopNotice(
          key: ValueKey<String>('key-export-escape-hatch'),
          icon: 'parachute',
          title: '这是你的逃生舱',
          body: '这个入口一直都在，只是导出功能还没有开放。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
        const LoopNotice(
          key: ValueKey<String>('key-export-risk'),
          icon: 'warn',
          tone: LoopNoticeTone.danger,
          title: '导出即全部责任转移',
          body:
              '私钥泄露等于资产全部丢失。不要截图、不要发给任何人、不要存在联网笔记里。'
              '没有任何人能帮你找回被盗的资产。',
        ),
        if (method == null)
          LoopChainStateBlock(
            keyPrefix: 'key-export',
            phase: methods.phase,
            failureKind: methods.failureKind,
            emptyMessage: '读不到导出能力的状态',
            skeleton: LoopSkeletonType.detail,
            onRetry: () => unawaited(
              ref
                  .read(securityCapabilitiesControllerProvider.notifier)
                  .reload(),
            ),
          )
        else
          LoopUnavailableCard(
            key: const ValueKey<String>('key-export-unavailable'),
            label: '导出私钥当前不可用',
            reasonCode: method.reasonCode,
          ),
        const LoopLabel('这一步现在不会发生什么'),
        const LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: ValueKey<String>('key-export-no-verification'),
              title: '不会要求你验证',
              subtitle: '没有 Face ID、没有验证码：验证只在真的能导出时才有意义。',
              position: LoopRowPosition.first,
            ),
            LoopRecordRow(
              key: ValueKey<String>('key-export-no-key'),
              title: '不会显示任何私钥',
              subtitle: '这一页永远不会渲染遮罩后的密钥样例，那会让人误以为已经导出过。',
              position: LoopRowPosition.last,
            ),
          ],
        ),
      ],
      primaryAction: const LoopButton(
        key: ValueKey<String>('key-export-action'),
        label: '验证并导出',
        block: true,
        primary: true,
        onPressed: null,
      ),
    );
  }
}

/// `social-recovery` · the 2-of-3 explanation. No guardian list exists.
class SocialRecoveryScreen extends ConsumerStatefulWidget {
  const SocialRecoveryScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<SocialRecoveryScreen> createState() =>
      _SocialRecoveryScreenState();
}

class _SocialRecoveryScreenState extends ConsumerState<SocialRecoveryScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.security),
    );
    final mode = ref.watch(securityGatewayProvider).mode;
    final blocked = _securityBlocked(mode, capability);
    final methods = ref.watch(securityCapabilitiesControllerProvider);
    if (!blocked && methods.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(securityCapabilitiesControllerProvider.notifier).load(),
          );
        }
      });
    }
    final method = methods.value?[LoopSecurityCapabilityId.socialRecovery];

    return LoopFocusPage(
      key: const ValueKey<String>('social-recovery-screen'),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('social-recovery-capability-block'),
              title: '社交恢复当前不可用',
              capability: capability,
              fallbackReasonCode: 'SECURITY_RUNTIME_UNAVAILABLE',
            )
          : null,
      archetype: LoopPageArchetype.action,
      title: '社交恢复',
      onBack: widget.onBack,
      folio: const LoopFolioPrimary(
        key: ValueKey<String>('social-recovery-folio'),
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.action,
        kicker: 'SOCIAL RECOVERY',
        heading: '2-of-3 守护人',
        caption: '守护人只参与恢复确认，看不到你的资产，也动不了你的钱。',
        stamp: '2 OF 3',
      ),
      body: <Widget>[
        const LoopNotice(
          key: ValueKey<String>('social-recovery-explainer'),
          icon: 'users',
          title: '2-of-3 是什么意思',
          body:
              '指定 3 个你信任的人。丢失设备时，其中 2 人同意即可帮你恢复账户。'
              '守护人需要在自己的 App 里主动确认，未确认的不计入 2-of-3。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
        if (method == null)
          LoopChainStateBlock(
            keyPrefix: 'social-recovery',
            phase: methods.phase,
            failureKind: methods.failureKind,
            emptyMessage: '读不到社交恢复的状态',
            skeleton: LoopSkeletonType.detail,
            onRetry: () => unawaited(
              ref
                  .read(securityCapabilitiesControllerProvider.notifier)
                  .reload(),
            ),
          )
        else
          LoopUnavailableCard(
            key: const ValueKey<String>('social-recovery-unavailable'),
            label: '社交恢复当前不可用',
            reasonCode: method.reasonCode,
          ),
        const LoopNotice(
          key: ValueKey<String>('social-recovery-no-guardians'),
          icon: 'info',
          title: '这里没有守护人名单',
          body: '守护人还没有开放，这里不显示任何守护人。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
      ],
      primaryAction: const LoopButton(
        key: ValueKey<String>('social-recovery-action'),
        label: '添加守护人',
        block: true,
        primary: true,
        onPressed: null,
      ),
    );
  }
}
