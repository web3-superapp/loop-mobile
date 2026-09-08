import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/about/about_screen.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_screen.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/features/profile/settings/settings_screen.dart';
import 'package:loop_mobile/features/profile/support/support_screen.dart';
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
    'key-export',
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
      'security' => SecurityCenterScreen(onNavigate: navigate, onBack: onBack),
      'devices' => DeviceManagementScreen(onBack: onBack),
      'key-export' => KeyExportScreen(onBack: onBack),
      'social-recovery' => SocialRecoveryScreen(onBack: onBack),
      'notif-settings' => NotificationPreferencesScreen(onBack: onBack),
      'connections' => const _ConnectionsScreen(),
      'blocklist' => const _BlocklistScreen(),
      'settings' => GeneralSettingsScreen(
        onNavigate: navigate,
        onBack: onBack,
        onSignOut: onSignOut,
      ),
      'about' => AboutScreen(onBack: onBack),
      'support' => SupportScreen(onNavigate: navigate, onBack: onBack),
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
