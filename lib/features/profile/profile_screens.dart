import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/features/profile/about/about_screen.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_screen.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/features/profile/settings/settings_screen.dart';
import 'package:loop_mobile/features/profile/support/support_screen.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

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
    'security',
    'devices',
    'key-export',
    'social-recovery',
    'notif-settings',
    'settings',
    'about',
    'support',
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
    LoopToast.show(context, message: 'This setting is ready to open.');
  }

  @override
  Widget build(BuildContext context) {
    void navigate(String destination) => _navigate(context, destination);
    return switch (_id) {
      'profile' => ProfileHomeScreen(
        onNavigate: navigate,
        onBack: onBack,
        walletAddress: identity.address,
      ),
      'profile-edit' => ProfileEditScreen(onNavigate: navigate, onBack: onBack),
      'privacy' => PrivacyCenterScreen(onNavigate: navigate, onBack: onBack),
      'security' => SecurityCenterScreen(onNavigate: navigate, onBack: onBack),
      'devices' => DeviceManagementScreen(onBack: onBack),
      'key-export' => KeyExportScreen(onBack: onBack),
      'social-recovery' => SocialRecoveryScreen(onBack: onBack),
      'notif-settings' => NotificationPreferencesScreen(
        onBack: onBack,
        onOpenSecurity: () => navigate('security'),
      ),
      'settings' => GeneralSettingsScreen(
        onNavigate: navigate,
        onBack: onBack,
        onSignOut: onSignOut,
      ),
      'about' => AboutScreen(onBack: onBack),
      'support' => SupportScreen(onNavigate: navigate, onBack: onBack),
      _ => const _UnknownProfileScreen(),
    };
  }
}

/// An id outside [ProfileSurfaceScreen.supportedIds]: no route reaches it,
/// so it only states that nothing changed (decision 0172).
class _UnknownProfileScreen extends StatelessWidget {
  const _UnknownProfileScreen();

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return LoopFocusPage(
      key: const ValueKey<String>('unknown-profile-surface'),
      archetype: LoopPageArchetype.state,
      title: '设置不可用',
      onBack: navigator.canPop() ? () => unawaited(navigator.maybePop()) : null,
      body: const <Widget>[],
      block: const SingleChildScrollView(
        child: LoopEmptyState(
          illustration: LoopIllustration.profile,
          title: '没有做任何更改',
          message: '回到「我」，选择其它设置。',
        ),
      ),
    );
  }
}
