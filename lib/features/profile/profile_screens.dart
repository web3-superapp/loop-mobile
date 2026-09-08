import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_screen.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

@immutable
class ProfileIdentity {
  const ProfileIdentity({
    this.alias = 'Profile unavailable',
    this.address = 'No wallet connected',
    this.bio = 'Profile presentation is not connected.',
    this.connections = 0,
    this.groups = 0,
    this.watchlistItems = 0,
  });

  final String alias;
  final String address;
  final String bio;
  final int connections;
  final int groups;
  final int watchlistItems;
}

/// Privy-backed capabilities used by Profile security and recovery surfaces.
/// Sensitive capabilities remain unavailable until the integration confirms
/// them for the current account and device.
@immutable
class PrivyProfileCapabilities {
  const PrivyProfileCapabilities({
    this.mfaAvailable = false,
    this.appLockAvailable = false,
    this.deviceManagementAvailable = false,
    this.privateKeyExportAvailable = false,
    this.socialRecoveryAvailable = false,
    this.secureScreenProtectionActive = false,
  });

  const PrivyProfileCapabilities.unavailable() : this();

  final bool mfaAvailable;
  final bool appLockAvailable;
  final bool deviceManagementAvailable;
  final bool privateKeyExportAvailable;
  final bool socialRecoveryAvailable;
  final bool secureScreenProtectionActive;
}

typedef ProfileNavigation = void Function(String destination);
typedef SensitiveProfileAuthentication = Future<bool> Function();

/// Single routing surface for H1-H16.
class ProfileSurfaceScreen extends StatelessWidget {
  const ProfileSurfaceScreen.fromId(
    this.surfaceId, {
    super.key,
    this.identity = const ProfileIdentity(),
    this.capabilities = const PrivyProfileCapabilities.unavailable(),
    this.onNavigate,
    this.onSignOut,
    this.onBack,
    this.leading,
    this.onAuthenticateSensitiveAction,
  });

  static const supportedIds = <String>{
    'profile',
    'profile-edit',
    'privacy',
    'copytrade-perms',
    'security',
    'devices',
    'social-recovery',
    'notif-settings',
    'connections',
    'blocklist',
    'settings',
    'about',
    'support',
    'mining',
    'referral',
  };

  final String surfaceId;
  final ProfileIdentity identity;
  final PrivyProfileCapabilities capabilities;
  final ProfileNavigation? onNavigate;
  final Future<void> Function()? onSignOut;
  final VoidCallback? onBack;
  final Widget? leading;
  final SensitiveProfileAuthentication? onAuthenticateSensitiveAction;

  String get _id => surfaceId.replaceFirst('#', '').toLowerCase();

  void _navigate(BuildContext context, String destination) {
    if (onNavigate != null) {
      onNavigate!(destination);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This setting is ready to open.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    void navigate(String destination) => _navigate(context, destination);
    return switch (_id) {
      'profile' => ProfileHomeScreen(
        onNavigate: navigate,
        onBack: onBack,
        onSignOut: onSignOut,
        walletAddress: identity.address,
      ),
      'profile-edit' => ProfileEditScreen(onNavigate: navigate, onBack: onBack),
      'privacy' => PrivacyCenterScreen(onNavigate: navigate, onBack: onBack),
      'copytrade-perms' => const _CopyTradePermissions(),
      'security' => _SecurityCenter(
        capabilities: capabilities,
        onNavigate: navigate,
      ),
      'devices' => _DeviceManagement(
        capabilityAvailable: capabilities.deviceManagementAvailable,
      ),
      'social-recovery' => _SocialRecovery(
        capabilityAvailable: capabilities.socialRecoveryAvailable,
      ),
      'notif-settings' => NotificationPreferencesScreen(onBack: onBack),
      'connections' => const _ConnectionsScreen(),
      'blocklist' => const _BlocklistScreen(),
      'settings' => const _GeneralSettings(),
      'about' => const _AboutAndLegal(),
      'support' => const _SupportScreen(),
      'mining' => const _ComingLaterScreen(
        eyebrow: 'MINING & REWARDS',
        title: 'Rewards are coming later',
        message: 'Tasks, contribution rewards, and daily claims are planned for Phase 2. No points are accruing yet.',
        icon: Icons.hexagon_outlined,
        accent: LoopColors.market,
      ),
      'referral' => const _ComingLaterScreen(
        eyebrow: 'INVITE FRIENDS',
        title: 'Referrals are coming later',
        message: 'Invite codes and reward rules are planned for Phase 2. Sharing now will not create a referral.',
        icon: Icons.group_add_outlined,
        accent: LoopColors.chat,
      ),
      _ => const _UnknownProfileScreen(),
    };
  }
}

class _CopyTradePermissions extends StatelessWidget {
  const _CopyTradePermissions();

  @override
  Widget build(BuildContext context) {
    return const LoopPage(
      eyebrow: 'COPY TRADING',
      title: 'Copy trading is not connected',
      subtitle: 'No copy-trade authorization, limits, follower enforcement, or execution path is available in this app build.',
      children: <Widget>[
        LoopStateCard(
          title: 'No permission can be granted here',
          message: 'The previous local controls were removed because they could not create a backend authorization or protect an order.',
          icon: Icons.lock_outline_rounded,
          tone: LoopTone.warning,
        ),
        SizedBox(height: 14),
        LoopStateCard(
          title: 'Visibility is not authorization',
          message: 'The separate Privacy resource stores only a private, followers, or public presentation preference. It never lets another account trade or access a wallet.',
          icon: Icons.rule_folder_outlined,
        ),
      ],
    );
  }
}

class _SecurityCenter extends StatelessWidget {
  const _SecurityCenter({required this.capabilities, required this.onNavigate});

  final PrivyProfileCapabilities capabilities;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: 'SECURITY',
      title: 'Protect the account',
      subtitle: 'Capability availability is shown separately from enrollment and account status.',
      children: <Widget>[
        const LoopStateCard(
          key: ValueKey<String>('protection-status-unavailable'),
          title: 'Protection status is not connected',
          message: 'No provider-backed enrollment state was loaded. This page does not claim that MFA, app lock, or a recovery method is configured.',
          icon: Icons.policy_outlined,
          tone: LoopTone.warning,
        ),
        const LoopSectionLabel('Account protection'),
        _SettingsGroup(
          children: <Widget>[
            _SettingsTile(
              icon: Icons.verified_user_outlined,
              title: 'Wallet multi-factor authentication',
              detail: capabilities.mfaAvailable
                  ? 'Wallet capability is available; enrollment status is unknown.'
                  : 'Wallet capability is not available in this build.',
              trailing: _CapabilityPill(available: capabilities.mfaAvailable),
              onTap: null,
            ),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'App lock',
              detail: capabilities.appLockAvailable
                  ? 'Capability is available; enrollment status is unknown.'
                  : 'Capability is not available on this device.',
              trailing: _CapabilityPill(
                available: capabilities.appLockAvailable,
              ),
              onTap: null,
            ),
            _SettingsTile(
              icon: Icons.devices_other_outlined,
              title: 'Devices & sessions',
              detail: capabilities.deviceManagementAvailable
                  ? 'Capability is available; session data is not connected.'
                  : 'Session management is unavailable.',
              trailing: _CapabilityPill(
                available: capabilities.deviceManagementAvailable,
              ),
              onTap: () => onNavigate('devices'),
              last: true,
            ),
          ],
        ),
        const LoopSectionLabel('Recovery'),
        _SettingsGroup(
          children: <Widget>[
            _SettingsTile(
              icon: Icons.vpn_key_outlined,
              title: '导出私钥',
              detail: capabilities.privateKeyExportAvailable
                  ? '能力可用；导出流程仍需要一次显式授权。'
                  : '当前构建没有可用的私钥导出通道。LOOP 不使用助记词。',
              trailing: _CapabilityPill(
                available: capabilities.privateKeyExportAvailable,
              ),
              onTap: null,
            ),
            _SettingsTile(
              icon: Icons.group_outlined,
              title: 'Social recovery',
              detail: capabilities.socialRecoveryAvailable
                  ? 'Capability is available; enrollment status is unknown.'
                  : 'Capability is not available for this wallet.',
              trailing: _CapabilityPill(
                available: capabilities.socialRecoveryAvailable,
              ),
              onTap: () => onNavigate('social-recovery'),
              last: true,
            ),
          ],
        ),
        const LoopSectionLabel('Recent sign-ins'),
        const LoopStateCard(
          key: ValueKey<String>('recent-sign-ins-unavailable'),
          title: 'Recent sign-ins are not connected',
          message: 'No device or location history was loaded, so this screen does not show sample sessions as account activity.',
          icon: Icons.devices_other_outlined,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class _DeviceManagement extends StatelessWidget {
  const _DeviceManagement({required this.capabilityAvailable});

  final bool capabilityAvailable;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: 'SESSIONS',
      title: 'Devices with access',
      subtitle: 'Session history and revocation require provider-backed account data.',
      children: <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('device-management-unavailable'),
          title: capabilityAvailable
              ? 'Session data is not connected'
              : 'Session controls unavailable',
          message: capabilityAvailable
              ? 'The account may support session management, but no reviewed device list or revocation adapter is available in this build.'
              : 'Device access cannot be read or changed right now. Your current session is unchanged.',
          icon: Icons.phonelink_erase_outlined,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class _SocialRecovery extends StatelessWidget {
  const _SocialRecovery({required this.capabilityAvailable});

  final bool capabilityAvailable;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: 'SOCIAL RECOVERY',
      title: 'Two of three guardians',
      subtitle: 'Guardian configuration requires provider-backed wallet recovery data.',
      children: <Widget>[
        LoopStateCard(
          key: const ValueKey<String>('social-recovery-unavailable'),
          title: capabilityAvailable
              ? 'Guardian data is not connected'
              : 'Social recovery unavailable',
          message: capabilityAvailable
              ? 'The wallet may support social recovery, but no reviewed guardian list or invitation adapter is available in this build.'
              : 'This wallet has not confirmed guardian-based recovery. No invitations can be sent.',
          icon: Icons.group_off_outlined,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class _ConnectionsScreen extends StatelessWidget {
  const _ConnectionsScreen();

  @override
  Widget build(BuildContext context) {
    return const LoopPage(
      eyebrow: 'NETWORK',
      title: 'Connections',
      subtitle:
          'Connections belong to your LOOP account, not a wallet address.',
      children: <Widget>[
        LoopStateCard(
          key: ValueKey<String>('connections-unavailable'),
          title: 'Connections are not connected',
          message: 'No follower graph was loaded and no sample people are being presented as account data.',
          icon: Icons.people_outline_rounded,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class _BlocklistScreen extends StatelessWidget {
  const _BlocklistScreen();

  @override
  Widget build(BuildContext context) {
    return const LoopPage(
      eyebrow: 'BLOCKED ITEMS',
      title: 'Control what you see',
      subtitle: 'A future account service will own blocked people, contracts, and domains.',
      children: <Widget>[
        LoopStateCard(
          key: ValueKey<String>('blocklist-unavailable'),
          title: 'Blocklist is not connected',
          message: 'No block records were loaded and this build will not pretend a local removal changed an account-level rule.',
          icon: Icons.block_outlined,
          tone: LoopTone.warning,
        ),
      ],
    );
  }
}

class _GeneralSettings extends ConsumerWidget {
  const _GeneralSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(loopDisplayPreferencesProvider);
    final persistenceDetail = switch (preferences.persistence) {
      LoopDisplayPreferencesPersistence.available =>
        'Stored locally when changed; no account or backend is used',
      LoopDisplayPreferencesPersistence.saving =>
        'Applied now and saving locally on this device',
      LoopDisplayPreferencesPersistence.unavailable =>
        'Applied for this app run; local saving is unavailable',
    };
    return LoopPage(
      eyebrow: 'GENERAL',
      title: 'Settings',
      subtitle: 'Local display controls that work without an account service.',
      children: <Widget>[
        _SwitchSetting(
          key: const ValueKey<String>('reduce-motion-setting'),
          icon: Icons.motion_photos_off_outlined,
          title: 'Reduce motion',
          detail: persistenceDetail,
          value: preferences.reduceMotion,
          onChanged: ref
              .read(loopDisplayPreferencesProvider.notifier)
              .setReduceMotion,
        ),
        if (preferences.persistence ==
            LoopDisplayPreferencesPersistence.unavailable)
          LoopStateCard(
            key: const ValueKey<String>('display-preferences-unavailable'),
            title: 'Local storage unavailable',
            message: 'Reduce motion still applies for this app run. Retry checks local storage again without using an account or backend.',
            icon: Icons.save_outlined,
            tone: LoopTone.warning,
            action: OutlinedButton(
              key: const ValueKey<String>('retry-display-preferences'),
              onPressed: ref
                  .read(loopDisplayPreferencesProvider.notifier)
                  .retryPersistence,
              child: const Text('Retry local storage'),
            ),
          ),
        const LoopSectionLabel('Current build'),
        const _SettingsGroup(
          children: <Widget>[
            _SettingsTile(
              icon: Icons.language_rounded,
              title: 'Language',
              detail: 'Build-defined copy; localization is not connected',
              onTap: null,
            ),
            _SettingsTile(
              icon: Icons.attach_money_rounded,
              title: 'Display currency',
              detail: 'No conversion; markets show their actual quote asset',
              onTap: null,
            ),
            _SettingsTile(
              icon: Icons.dark_mode_outlined,
              title: 'Theme',
              detail: 'Dark design system only in this build',
              onTap: null,
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _PrivacyFootnote(
          text: 'Reduce motion is a non-sensitive device preference and always respects a stricter system accessibility setting. It is not tied to an account, and no backend request is made.',
        ),
      ],
    );
  }
}

class _AboutAndLegal extends StatelessWidget {
  const _AboutAndLegal();

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: 'ABOUT LOOP',
      title: 'Clear terms, one place',
      subtitle: 'Review the rules and risks that apply before using wallet or trading features.',
      children: <Widget>[
        LoopCard(
          accent: true,
          tone: LoopTone.positive,
          child: Row(
            children: <Widget>[
              const _LoopMark(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'LOOP mobile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 0.1.0 (1)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const LoopStatusPill(label: 'Current', tone: LoopTone.positive),
            ],
          ),
        ),
        const LoopSectionLabel('Legal'),
        _SettingsGroup(
          children: <Widget>[
            const _DocumentTile(
              title: 'Terms of use',
              detail: 'Document not included in this build',
            ),
            const _DocumentTile(
              title: 'Privacy policy',
              detail: 'Document not included in this build',
            ),
            const _DocumentTile(
              title: 'Trading risk disclosure',
              detail: 'Document not included; Spot execution is disabled',
            ),
            _DocumentTile(
              title: 'Open-source licenses',
              detail: 'Licenses registered by the running Flutter build',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'LOOP',
                applicationVersion: '0.1.0 (1)',
              ),
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _PrivacyFootnote(
          text: 'Availability of wallet and trading features may vary by account, product, and region.',
        ),
      ],
    );
  }
}

class _SupportScreen extends StatefulWidget {
  const _SupportScreen();

  @override
  State<_SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<_SupportScreen> {
  static const _articles = <({String title, String answer, String keywords})>[
    (
      title: 'Why does Chat say Stream not connected?',
      answer: 'A Stream API key is public configuration, not user authorization. Production Chat needs the LOOP backend to validate Privy and issue a server-derived Stream user ID plus short-lived user token. Use Loop (Preview) to inspect labelled offline cells and rooms.',
      keywords: 'chat stream token preview user id 聊天 未连接',
    ),
    (
      title: 'What does the Spot market show?',
      answer: 'It shows public, read-only Hyperliquid Testnet spot marks and 24-hour volume. These discovery facts are not executable quotes and the app cannot place an order from this feed.',
      keywords: 'spot market hyperliquid testnet price volume 现货 行情',
    ),
    (
      title: 'Why can’t I access a wallet action?',
      answer: 'Wallet creation and signing require an authenticated Privy capability for the current account and device. Preview never creates a real wallet or signs an action.',
      keywords: 'wallet privy sign preview 钱包 签名',
    ),
    (
      title: 'How do I recover my account?',
      answer: 'Open Security center to see only the recovery capabilities confirmed for the current wallet. LOOP does not invent a recovery phrase or guardian state.',
      keywords: 'security recover account phrase guardian 安全 恢复',
    ),
    (
      title: 'How do I report a suspicious message?',
      answer: 'Production reporting is unavailable until server-authorized Stream moderation is connected. Do not share a recovery phrase, private key, or one-time code with anyone claiming to be support.',
      keywords: 'report suspicious message scam moderation 举报 可疑 消息',
    ),
  ];

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final articles = _articles
        .where((article) {
          if (normalized.isEmpty) return true;
          return '${article.title} ${article.answer} ${article.keywords}'
              .toLowerCase()
              .contains(normalized);
        })
        .toList(growable: false);
    return LoopPage(
      eyebrow: 'HELP · BUNDLED LOCALLY',
      title: 'Find an answer first',
      subtitle: 'LOOP support will never ask for a recovery phrase, private key, or one-time code.',
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('local-help-search'),
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Search local help',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        LoopSectionLabel('Local answers · ${articles.length}'),
        if (articles.isEmpty)
          const LoopStateCard(
            key: ValueKey<String>('local-help-empty'),
            title: 'No local answer found',
            message: 'Try Stream, Spot, wallet, recovery, or report. Online support is not connected.',
            icon: Icons.search_off_rounded,
          )
        else
          LoopCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: <Widget>[
                for (final article in articles)
                  Material(
                    type: MaterialType.transparency,
                    child: ExpansionTile(
                      key: ValueKey<String>('help-${article.title}'),
                      title: Text(article.title),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(article.answer),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const LoopSectionLabel('Contact'),
        const LoopStateCard(
          title: 'Online support is not connected',
          message: 'No request will be submitted from this build. Never put secret wallet information into an unverified support channel.',
          icon: Icons.support_agent_rounded,
          tone: LoopTone.warning,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Contact unavailable'),
          ),
        ),
      ],
    );
  }
}

class _ComingLaterScreen extends StatelessWidget {
  const _ComingLaterScreen({
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
  });

  final String eyebrow;
  final String title;
  final String message;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: eyebrow,
      title: title,
      subtitle: message,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.2,
          child: LoopCard(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                ),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.1),
                    border: Border.all(color: accent.withValues(alpha: 0.42)),
                  ),
                  child: Icon(icon, color: accent, size: 48),
                ),
                Positioned(
                  right: 18,
                  top: 18,
                  child: LoopStatusPill(
                    label: 'COMING LATER',
                    tone: accent == LoopColors.chat
                        ? LoopTone.conversation
                        : LoopTone.market,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _PrivacyFootnote(
          text: 'This page is informational. No rewards, balances, codes, or eligibility are active.',
        ),
      ],
    );
  }
}

class _UnknownProfileScreen extends StatelessWidget {
  const _UnknownProfileScreen();

  @override
  Widget build(BuildContext context) {
    return const LoopPage(
      key: ValueKey<String>('unknown-profile-surface'),
      eyebrow: 'PROFILE',
      title: 'Setting unavailable',
      subtitle: 'This profile setting could not be opened.',
      children: <Widget>[
        LoopStateCard(
          title: 'No changes made',
          message: 'Return to Profile and choose another setting.',
          icon: Icons.settings_backup_restore_rounded,
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.trailing,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: '$title. $detail',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: LoopColors.line)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 21, color: LoopColors.vapor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  (onTap == null
                      ? const LoopStatusPill(
                          label: 'Unavailable',
                          tone: LoopTone.neutral,
                        )
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: LoopColors.vapor,
                        )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      child: Row(
        children: <Widget>[
          Icon(icon, color: value ? LoopColors.mint : LoopColors.vapor),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PrivacyFootnote extends StatelessWidget {
  const _PrivacyFootnote({
    this.text = 'Changing visibility affects future views. Content already shared in a conversation may remain visible to its participants.',
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: LoopColors.vapor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _CapabilityPill extends StatelessWidget {
  const _CapabilityPill({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    return LoopStatusPill(
      label: available ? 'Available' : 'Unavailable',
      tone: LoopTone.neutral,
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.title,
    required this.detail,
    this.onTap,
    this.last = false,
  });

  final String title;
  final String detail;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.description_outlined,
      title: title,
      detail: detail,
      onTap: onTap,
      last: last,
    );
  }
}

class _LoopMark extends StatelessWidget {
  const _LoopMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: LoopColors.mint, width: 2),
      ),
      child: Text(
        'L',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(color: LoopColors.mint),
      ),
    );
  }
}
