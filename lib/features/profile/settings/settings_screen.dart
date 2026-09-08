import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/settings/settings_controller.dart';
import 'package:loop_mobile/features/profile/settings/settings_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `settings` · the account resource plus the device-local display switch.
///
/// Both account values are fixed constants published by the server, so they
/// are read-only here. `reduceMotion` never leaves the device, and the
/// prototype's "数据用量 142MB" row has no source and is not rendered.
class GeneralSettingsScreen extends ConsumerStatefulWidget {
  const GeneralSettingsScreen({
    required this.onNavigate,
    super.key,
    this.onBack,
    this.onSignOut,
  });

  final ValueChanged<String> onNavigate;
  final VoidCallback? onBack;
  final Future<void> Function()? onSignOut;

  @override
  ConsumerState<GeneralSettingsScreen> createState() =>
      _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends ConsumerState<GeneralSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.settings),
    );
    final mode = ref.watch(accountSettingsGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final state = ref.watch(accountSettingsControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(accountSettingsControllerProvider.notifier).load(),
          );
        }
      });
    }
    final settings = state.value;
    final preferences = ref.watch(loopDisplayPreferencesProvider);
    final persistenceDetail = switch (preferences.persistence) {
      LoopDisplayPreferencesPersistence.available => '只保存在本机，不写入账号，也不调用后端',
      LoopDisplayPreferencesPersistence.saving => '已生效，正在保存到本机',
      LoopDisplayPreferencesPersistence.unavailable => '本次运行内生效；本机保存当前不可用',
    };

    return LoopDashboardPage(
      key: const ValueKey<String>('settings-screen'),
      archetype: LoopPageArchetype.action,
      title: '设置',
      onBack: widget.onBack,
      primary: const LoopFolioPrimary(
        key: ValueKey<String>('settings-folio'),
        archetype: LoopFolioArchetype.action,
        kicker: 'ACCOUNT SETTINGS',
        heading: '设置',
        caption: '语言与货币单位由服务端固定下发，本步只读；减少动效只保存在这台设备上。',
      ),
      sections: <Widget>[
        const LoopLabel('通用'),
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('settings-capability-block'),
            label: '账号设置当前不可用',
            reasonCode: capability.reasonCode ?? 'SETTINGS_RUNTIME_UNAVAILABLE',
          )
        else if (settings == null)
          LoopChainStateBlock(
            keyPrefix: 'settings',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '还没有账号设置',
            onRetry: () => unawaited(
              ref.read(accountSettingsControllerProvider.notifier).reload(),
            ),
          )
        else
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('settings-language'),
                title: '语言',
                subtitle: '由服务端固定为 ${settings.policy.fixed.language}，本步不可更改',
                trailing: settings.values.languageLabel,
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('settings-display-currency'),
                title: '货币单位',
                subtitle: '由服务端固定，本步不可更改；行情仍显示各自的报价币',
                trailing: settings.values.displayCurrency,
                position: LoopRowPosition.last,
              ),
            ],
          ),
        const LoopLabel('这台设备'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('settings-reduce-motion'),
              title: '减少动效',
              subtitle: persistenceDetail,
              trailingBadge: LoopBadge(
                preferences.reduceMotion ? '已开启' : '已关闭',
                kind: preferences.reduceMotion
                    ? LoopBadgeKind.up
                    : LoopBadgeKind.mute,
              ),
              onTap: () => ref
                  .read(loopDisplayPreferencesProvider.notifier)
                  .setReduceMotion(!preferences.reduceMotion),
              semanticLabel: '减少动效，${preferences.reduceMotion ? '已开启' : '已关闭'}',
              position: LoopRowPosition.first,
            ),
            const LoopRecordRow(
              key: ValueKey<String>('settings-theme'),
              title: '主题',
              subtitle: '本构建只有深色一套设计系统，没有可切换的选项',
              trailing: '深色',
              position: LoopRowPosition.last,
            ),
          ],
        ),
        if (preferences.persistence ==
            LoopDisplayPreferencesPersistence.unavailable)
          LoopNotice(
            key: const ValueKey<String>('settings-display-storage-unavailable'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '本机保存不可用',
            body: '减少动效仍会在本次运行内生效。重试只会再读一次本机存储，不会使用账号或后端。',
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            trailing: LoopButton(
              key: const ValueKey<String>('settings-retry-display-storage'),
              label: '重试',
              onPressed: ref
                  .read(loopDisplayPreferencesProvider.notifier)
                  .retryPersistence,
            ),
          ),
        const LoopLabel('账户'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('settings-open-privacy'),
              title: '隐私中心',
              subtitle: '可被搜索与跟单可见性',
              onTap: () => widget.onNavigate('privacy'),
              position: LoopRowPosition.first,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('settings-open-security'),
              title: '安全中心',
              subtitle: '设备、会话与账户保护',
              onTap: () => widget.onNavigate('security'),
            ),
            LoopRecordRow(
              key: const ValueKey<String>('settings-open-notifications'),
              title: '通知',
              subtitle: '十个通知类别；推送投递仍不可用',
              onTap: () => widget.onNavigate('notif-settings'),
            ),
            LoopRecordRow(
              key: const ValueKey<String>('settings-open-networks'),
              title: '网络与 RPC',
              subtitle: '只有 BNB Smart Chain 一条网络',
              onTap: () => widget.onNavigate('networks'),
              position: LoopRowPosition.last,
            ),
          ],
        ),
        const LoopLabel('关于'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('settings-open-about'),
              title: '关于与法务',
              subtitle: '版本、规则快照与开源许可',
              onTap: () => widget.onNavigate('about'),
              position: LoopRowPosition.first,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('settings-open-support'),
              title: '帮助与客服',
              subtitle: '提交工单并查看进度',
              onTap: () => widget.onNavigate('support'),
              position: LoopRowPosition.last,
            ),
          ],
        ),
        if (settings != null)
          LoopProvenanceFooter(
            key: const ValueKey<String>('settings-version'),
            text: settings.updatedAt == null
                ? '账号设置尚未写入过（版本 ${settings.version}，规则 '
                      '${settings.policy.configVersion}）'
                : '版本 ${settings.version} · 更新于 '
                      '${loopRelativeTime(settings.updatedAt!)}',
          ),
        const LoopNotice(
          key: ValueKey<String>('settings-data-usage-absent'),
          icon: 'info',
          title: '没有"数据用量"',
          body: '流量统计没有任何后端或系统来源，与其显示一个编造的数字，不如不显示这一行。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
        if (widget.onSignOut != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('settings-sign-out'),
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
