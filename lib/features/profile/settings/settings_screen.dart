import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/settings/settings_controller.dart';
import 'package:loop_mobile/features/profile/settings/settings_gateway.dart';
import 'package:loop_mobile/features/profile/sign_out_button.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_gate.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
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

    final appLock = ref.watch(loopAppLockProvider);
    final appLockLabel = appLock.busy
        ? '验证中…'
        : !appLock.isAvailable
        ? '不可用'
        : appLock.enabled
        ? '已开启'
        : '已关闭';
    final appLockDetail = appLock.capability == null
        ? '还没有读到这台设备的锁屏能力'
        : appLock.enabled && !appLock.persisted
        ? '${loopAppLockFactorText(appLock.capability!)} · 这次有效，重开 App 后不会记得'
        : loopAppLockFactorText(appLock.capability!);

    // The one implemented display switch; the row and its switch share it.
    void toggleReduceMotion() => ref
        .read(loopDisplayPreferencesProvider.notifier)
        .setReduceMotion(!preferences.reduceMotion);

    // Decision 0126: flat sections, switches for the two device toggles.
    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('settings-screen'),
        archetype: LoopPageArchetype.action,
        title: '设置',
        onBack: widget.onBack,
        // The prototype opens straight on 通用. A hero here restated the page
        // title as its own heading — 「设置」 above 「设置」 (audit 2026-09-21
        // §D+ #13).
        sections: <Widget>[
          const LoopLabel('通用'),
          if (blocked)
            LoopUnavailableCard(
              key: const ValueKey<String>('settings-capability-block'),
              label: '账号设置当前不可用',
              reasonCode:
                  capability.reasonCode ?? 'SETTINGS_RUNTIME_UNAVAILABLE',
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
            ),
          // `.row`: title, the current value in the figure column, chevron. The
          // 「为什么不能改」 sentence each of these carried turned a one-line
          // state list into a two-line functional catalogue and made the page a
          // screen longer (audit 2026-09-21 §D+ #11, §J.13).
          //
          // 主题 and 减少动效 belong to 通用 in the prototype, and neither reads
          // the account resource: they stay in the card whatever the account
          // half of the page answered.
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              if (settings != null) ...<LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('settings-language'),
                  title: '语言',
                  trailing: settings.values.languageLabel,
                  readOnly: true,
                  position: LoopRowPosition.first,
                ),
                LoopRecordRow(
                  key: const ValueKey<String>('settings-display-currency'),
                  title: '货币单位',
                  trailing: settings.values.displayCurrency,
                  readOnly: true,
                ),
              ],
              LoopRecordRow(
                key: const ValueKey<String>('settings-theme'),
                title: '主题',
                trailing: '深色',
                readOnly: true,
                position: settings == null
                    ? LoopRowPosition.first
                    : LoopRowPosition.middle,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('settings-reduce-motion'),
                title: '减少动效',
                // The storage line is only news when it is not the usual one.
                subtitle:
                    preferences.persistence ==
                        LoopDisplayPreferencesPersistence.available
                    ? null
                    : persistenceDetail,
                trailingBadge: LoopFlatSwitch(
                  value: preferences.reduceMotion,
                  onChanged: toggleReduceMotion,
                ),
                chevron: false,
                onTap: toggleReduceMotion,
                semanticLabel:
                    '减少动效，${preferences.reduceMotion ? '已开启' : '已关闭'}',
              ),
              // The device-local lock belongs beside 减少动效: it is this
              // installation's choice, it reads no account resource, and the
              // account half of the page being unavailable has nothing to do
              // with it. The prototype's three groups stay three.
              LoopRecordRow(
                key: const ValueKey<String>('settings-app-lock'),
                title: '应用锁',
                subtitle: appLockDetail,
                subtitleMaxLines: 2,
                trailingBadge: appLock.isAvailable && !appLock.busy
                    ? LoopFlatSwitch(
                        value: appLock.enabled,
                        onChanged: () => unawaited(
                          appLock.enabled
                              ? ref.read(loopAppLockProvider.notifier).disable()
                              : ref.read(loopAppLockProvider.notifier).enable(),
                        ),
                      )
                    : LoopBadge(
                        appLockLabel,
                        kind: appLock.enabled
                            ? LoopBadgeKind.up
                            : LoopBadgeKind.mute,
                      ),
                chevron: false,
                // Both directions run the system's own prompt first: a lock
                // that could be switched off without it would not be a lock.
                onTap: appLock.isAvailable && !appLock.busy
                    ? () => unawaited(
                        appLock.enabled
                            ? ref.read(loopAppLockProvider.notifier).disable()
                            : ref.read(loopAppLockProvider.notifier).enable(),
                      )
                    : null,
                semanticLabel: appLock.isAvailable
                    ? '应用锁，$appLockLabel，点按后验证身份可切换'
                    : '应用锁，不可用：$appLockDetail',
                position: LoopRowPosition.last,
              ),
            ],
          ),
          // Audit 2026-10-09 m8: 语言 / 货币单位 / 主题 looked like rows to
          // open and did nothing. They are stated values now (no chevron, no
          // pressed state, grey value), and this one line says why.
          Padding(
            key: const ValueKey<String>('settings-fixed-values-note'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              settings == null ? '主题在当前版本固定，不能更改。' : '语言、货币单位与主题在当前版本固定，不能更改。',
              style: LoopTypography.caption(12, color: LoopColors.text3),
            ),
          ),
          if (preferences.persistence ==
              LoopDisplayPreferencesPersistence.unavailable)
            LoopNotice(
              key: const ValueKey<String>(
                'settings-display-storage-unavailable',
              ),
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
          // Decision 0133 (audit m9): 隐私中心, 安全中心 and 通知 are rows on 我,
          // one level up, and 网络 is a row on 钱包. The 账户 group repeated
          // all four; a destination has one entry per hub.
          const LoopLabel('关于'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('settings-open-about'),
                title: '关于与法务',
                onTap: () => widget.onNavigate('about'),
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('settings-open-support'),
                title: '帮助与客服',
                onTap: () => widget.onNavigate('support'),
                position: LoopRowPosition.last,
              ),
            ],
          ),
          if (settings != null)
            LoopProvenanceFooter(
              key: const ValueKey<String>('settings-version'),
              // The CAS version is how the client keeps two devices from
              // overwriting each other; it is not a fact about the account, and
              // 「尚未写入过」 named a row in a table rather than anything the
              // reader did or did not do.
              text: settings.updatedAt == null
                  ? '当前使用默认设置'
                  : '更新于 ${loopRelativeTime(settings.updatedAt!)}',
            ),
          if (widget.onSignOut != null)
            LoopSignOutButton(
              key: const ValueKey<String>('settings-sign-out'),
              onSignOut: widget.onSignOut!,
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
