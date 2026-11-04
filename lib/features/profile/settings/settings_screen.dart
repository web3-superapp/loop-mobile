import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/app/loop_locale.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/profile/settings/language_sheet.dart';
import 'package:loop_mobile/features/profile/settings/settings_controller.dart';
import 'package:loop_mobile/features/profile/settings/settings_gateway.dart';
import 'package:loop_mobile/features/profile/sign_out_button.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_gate.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `settings` · 隐私与安全 (S343 · decision 0271), the account resource
/// and the device-local display switch.
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
    final locale = ref.watch(loopLocaleProvider);
    final persistenceDetail = switch (preferences.persistence) {
      LoopDisplayPreferencesPersistence.available =>
        context.l10n.profileSettings_displaySavedLocally,
      LoopDisplayPreferencesPersistence.saving =>
        context.l10n.profileSettings_displaySaving,
      LoopDisplayPreferencesPersistence.unavailable =>
        context.l10n.profileSettings_displaySessionOnly,
    };

    final appLock = ref.watch(loopAppLockProvider);
    final appLockLabel = appLock.busy
        ? context.l10n.common_verifying
        : !appLock.isAvailable
        ? context.l10n.common_unavailable
        : appLock.enabled
        ? context.l10n.common_on
        : context.l10n.profileSettings_appLockOff;
    final appLockDetail = appLock.capability == null
        ? context.l10n.profileSettings_appLockCapabilityUnknown
        : appLock.enabled && !appLock.persisted
        ? context.l10n.profileSettings_appLockNotPersisted(
            loopAppLockFactorText(appLock.capability!),
          )
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
        title: context.l10n.common_settings,
        onBack: widget.onBack,
        // The prototype opens straight on 通用. A hero here restated the page
        // title as its own heading — 「设置」 above 「设置」 (audit 2026-09-21
        // §D+ #13).
        sections: <Widget>[
          // S343 · decision 0271: 隐私与安全, 通用, 关于 and 退出登录. The
          // account rows moved to 我的; 分享名片 is on its identity card.
          ProfileSettingsEntries(onNavigate: widget.onNavigate),
          LoopLabel(context.l10n.profileSettings_general),
          if (blocked)
            LoopUnavailableLine(
              key: const ValueKey<String>('settings-capability-block'),
              label: context.l10n.profileSettings_capabilityBlocked,
              reasonCode:
                  capability.reasonCode ?? 'SETTINGS_RUNTIME_UNAVAILABLE',
            )
          else if (settings == null)
            LoopChainStateBlock(
              keyPrefix: 'settings',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: context.l10n.profileSettings_empty,
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
              // Decision 0281: the application language is this
              // installation's choice, read from the device, not the account
              // value the server publishes; it stays whatever the account
              // half of the page answered.
              LoopRecordRow(
                key: const ValueKey<String>('settings-language'),
                title: context.l10n.common_language,
                trailing: LoopL10n.nativeName(locale),
                onTap: () => unawaited(showLoopLanguageSheet(context)),
                position: LoopRowPosition.first,
              ),
              if (settings != null)
                LoopRecordRow(
                  key: const ValueKey<String>('settings-display-currency'),
                  title: context.l10n.profileSettings_currency,
                  trailing: settings.values.displayCurrency,
                  readOnly: true,
                ),
              LoopRecordRow(
                key: const ValueKey<String>('settings-theme'),
                title: context.l10n.profileSettings_theme,
                trailing: context.l10n.profileSettings_themeDark,
                readOnly: true,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('settings-reduce-motion'),
                title: context.l10n.profileSettings_reduceMotion,
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
                semanticLabel: context.l10n
                    .profileSettings_reduceMotionSemantic(
                      preferences.reduceMotion
                          ? context.l10n.common_on
                          : context.l10n.profileSettings_appLockOff,
                    ),
              ),
              // The device-local lock belongs beside 减少动效: it is this
              // installation's choice, it reads no account resource, and the
              // account half of the page being unavailable has nothing to do
              // with it. The prototype's three groups stay three.
              LoopRecordRow(
                key: const ValueKey<String>('settings-app-lock'),
                title: context.l10n.profileSettings_appLock,
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
                    ? context.l10n.profileSettings_appLockSemantic(appLockLabel)
                    : context.l10n.profileSettings_appLockUnavailableSemantic(
                        appLockDetail,
                      ),
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
              settings == null
                  ? context.l10n.profileSettings_fixedThemeNote
                  : context.l10n.profileSettings_fixedValuesNote,
              style: LoopType.caption,
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
              title: context.l10n.profileSettings_storageUnavailableTitle,
              body: context.l10n.profileSettings_storageUnavailableBody,
              margin: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                12,
                LoopSpacing.page,
                0,
              ),
              trailing: LoopButton(
                key: const ValueKey<String>('settings-retry-display-storage'),
                label: context.l10n.common_retry,
                onPressed: ref
                    .read(loopDisplayPreferencesProvider.notifier)
                    .retryPersistence,
              ),
            ),
          // Decision 0133 (audit m9): a destination has one entry per hub.
          // 隐私中心, 安全中心 and 通知设置 are rows of
          // [ProfileSettingsEntries] above.
          LoopLabel(context.l10n.common_aboutSection),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('settings-open-about'),
                title: context.l10n.profileSettings_aboutAndLegal,
                onTap: () => widget.onNavigate('about'),
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('settings-open-support'),
                title: context.l10n.profileSettings_helpAndSupport,
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
                  ? context.l10n.profileSettings_usingDefaults
                  : context.l10n.profileSettings_updatedAt(
                      loopRelativeTime(settings.updatedAt!),
                    ),
            ),
          if (widget.onSignOut != null)
            LoopSignOutButton(
              key: const ValueKey<String>('settings-sign-out'),
              onSignOut: widget.onSignOut!,
            ),
          const ProfileVersionFootnote(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
