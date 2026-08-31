import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_controller.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_gateway.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_controller.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
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
    this.recoveryPhraseRevealAvailable = false,
    this.socialRecoveryAvailable = false,
    this.secureScreenProtectionActive = false,
  });

  const PrivyProfileCapabilities.unavailable() : this();

  final bool mfaAvailable;
  final bool appLockAvailable;
  final bool deviceManagementAvailable;
  final bool recoveryPhraseRevealAvailable;
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
    this.onAuthenticateSensitiveAction,
    this.recoveryWords,
  });

  static const supportedIds = <String>{
    'profile',
    'profile-edit',
    'privacy',
    'copytrade-perms',
    'security',
    'devices',
    'seed-backup',
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
  final SensitiveProfileAuthentication? onAuthenticateSensitiveAction;

  /// Injected only after a secure, freshly authorized recovery operation.
  final List<String>? recoveryWords;

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
      'profile' => _ProfilePresentationSurface(
        editing: false,
        identity: identity,
        onNavigate: navigate,
        onSignOut: onSignOut,
      ),
      'profile-edit' => _ProfilePresentationSurface(
        editing: true,
        identity: identity,
        onNavigate: navigate,
        onSignOut: onSignOut,
      ),
      'privacy' => const _PrivacyCenter(),
      'copytrade-perms' => const _CopyTradePermissions(),
      'security' => _SecurityCenter(
        capabilities: capabilities,
        onNavigate: navigate,
      ),
      'devices' => _DeviceManagement(
        capabilityAvailable: capabilities.deviceManagementAvailable,
      ),
      'seed-backup' => _RecoveryPhraseAccess(
        capabilities: capabilities,
        authenticate: onAuthenticateSensitiveAction,
        recoveryWords: recoveryWords,
      ),
      'social-recovery' => _SocialRecovery(
        capabilityAvailable: capabilities.socialRecoveryAvailable,
      ),
      'notif-settings' => const _NotificationSettings(),
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

/// Owns the providerless Profile-presentation lifecycle for H1 and H2 only.
///
/// Other Profile settings remain independent; opening Security or Privacy does
/// not start a Profile request. Production stays unavailable until an
/// authenticated integration adapter replaces the default gateway.
class _ProfilePresentationSurface extends ConsumerStatefulWidget {
  const _ProfilePresentationSurface({
    required this.editing,
    required this.identity,
    required this.onNavigate,
    required this.onSignOut,
  });

  final bool editing;
  final ProfileIdentity identity;
  final ValueChanged<String> onNavigate;
  final Future<void> Function()? onSignOut;

  @override
  ConsumerState<_ProfilePresentationSurface> createState() =>
      _ProfilePresentationSurfaceState();
}

class _ProfilePresentationSurfaceState
    extends ConsumerState<_ProfilePresentationSurface> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    if (state.phase == ProfilePhase.initial) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(profileControllerProvider.notifier).load());
        }
      });
    }
    final controller = ref.read(profileControllerProvider.notifier);
    final projectedIdentity = _projectIdentity(widget.identity, state);

    if (widget.editing) {
      return _ProfileEdit(
        identity: projectedIdentity,
        state: state,
        controller: controller,
        onOpenPrivacy: () => widget.onNavigate('privacy'),
      );
    }
    return _ProfileHome(
      identity: projectedIdentity,
      state: state,
      controller: controller,
      onNavigate: widget.onNavigate,
      onSignOut: widget.onSignOut,
    );
  }

  ProfileIdentity _projectIdentity(
    ProfileIdentity sessionIdentity,
    ProfileState state,
  ) {
    final resource = state.resource;
    return ProfileIdentity(
      alias: resource == null
          ? sessionIdentity.alias
          : resource.values.alias ?? 'No alias set',
      address: sessionIdentity.address,
      bio: resource == null
          ? sessionIdentity.bio
          : 'Bio is not part of the reviewed Profile presentation contract.',
      connections: sessionIdentity.connections,
      groups: sessionIdentity.groups,
      watchlistItems: sessionIdentity.watchlistItems,
    );
  }
}

class _ProfileHome extends StatelessWidget {
  const _ProfileHome({
    required this.identity,
    required this.state,
    required this.controller,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ProfileIdentity identity;
  final ProfileState state;
  final ProfileController controller;
  final ValueChanged<String> onNavigate;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: state.mode == ProfileMode.preview
          ? '开发预览 · YOUR IDENTITY'
          : 'YOUR IDENTITY',
      title: 'Profile',
      actions: <Widget>[
        IconButton(
          tooltip: 'Edit profile',
          onPressed: () => onNavigate('profile-edit'),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Sign out of LOOP',
          onPressed: onSignOut == null ? null : () => onSignOut!(),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      children: <Widget>[
        _ProfileModeBanner(mode: state.mode),
        const SizedBox(height: 14),
        ..._profileHomeStatus(state, controller),
        _IdentityThreadCard(identity: identity),
        const LoopSectionLabel('Control'),
        _SettingsGroup(
          children: <Widget>[
            _SettingsTile(
              icon: Icons.visibility_outlined,
              title: 'Privacy center',
              detail: 'Discoverability and copy visibility preferences',
              tone: LoopTone.conversation,
              onTap: () => onNavigate('privacy'),
            ),
            _SettingsTile(
              icon: Icons.content_copy_rounded,
              title: 'Copy-trade permissions',
              detail: 'Unavailable; visibility alone grants nothing',
              onTap: () => onNavigate('copytrade-perms'),
            ),
            _SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Security center',
              detail: 'MFA, app lock, devices, and recovery',
              tone: LoopTone.positive,
              onTap: () => onNavigate('security'),
              last: true,
            ),
          ],
        ),
        const LoopSectionLabel('People & communication'),
        _SettingsGroup(
          children: <Widget>[
            _SettingsTile(
              icon: Icons.people_alt_outlined,
              title: '我的好友',
              detail: '查看已接受的 LOOP 好友',
              tone: LoopTone.conversation,
              onTap: () => onNavigate('friends'),
            ),
            _SettingsTile(
              icon: Icons.people_outline_rounded,
              title: 'Connections',
              detail: '${identity.connections} people in your network',
              onTap: () => onNavigate('connections'),
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              detail: 'Four owner intents; delivery unavailable',
              onTap: () => onNavigate('notif-settings'),
            ),
            _SettingsTile(
              icon: Icons.block_outlined,
              title: 'Blocked items',
              detail: 'People, contracts, and domains',
              onTap: () => onNavigate('blocklist'),
              last: true,
            ),
          ],
        ),
        const LoopSectionLabel('LOOP'),
        _SettingsGroup(
          children: <Widget>[
            _SettingsTile(
              icon: Icons.tune_rounded,
              title: 'General settings',
              detail: 'Language, currency, theme, and data',
              onTap: () => onNavigate('settings'),
            ),
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              title: 'Help & support',
              detail: 'Guides and account help',
              onTap: () => onNavigate('support'),
            ),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About & legal',
              detail: 'Terms, privacy, risks, and licenses',
              onTap: () => onNavigate('about'),
              last: true,
            ),
          ],
        ),
        const LoopSectionLabel('Later'),
        Row(
          children: <Widget>[
            Expanded(
              child: _LaterTile(
                icon: Icons.hexagon_outlined,
                title: 'Mining',
                onTap: () => onNavigate('mining'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LaterTile(
                icon: Icons.group_add_outlined,
                title: 'Referrals',
                onTap: () => onNavigate('referral'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _profileHomeStatus(
    ProfileState state,
    ProfileController controller,
  ) {
    if (state.resource != null) {
      return <Widget>[
        _ProfileSummary(state: state),
        const SizedBox(height: 14),
      ];
    }
    return switch (state.phase) {
      ProfilePhase.initial || ProfilePhase.loading => const <Widget>[
        _ProfileLoadingCard(),
        SizedBox(height: 14),
      ],
      ProfilePhase.unavailable => const <Widget>[
        LoopStateCard(
          title: 'Profile presentation is not connected',
          message: 'The current session identity remains visible, but no saved Alias or avatar is being claimed and no private request was sent.',
          icon: Icons.link_off_rounded,
          tone: LoopTone.warning,
        ),
        SizedBox(height: 14),
      ],
      _ => <Widget>[
        LoopStateCard(
          title: 'Profile presentation could not be loaded',
          message: _profileFailureMessage(state.failureKind),
          icon: Icons.sync_problem_rounded,
          tone: LoopTone.danger,
          action: OutlinedButton.icon(
            key: const ValueKey<String>('profile-home-retry-load'),
            onPressed: state.isBusy
                ? null
                : () => unawaited(controller.reload()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
        const SizedBox(height: 14),
      ],
    };
  }
}

class _ProfileEdit extends StatefulWidget {
  const _ProfileEdit({
    required this.identity,
    required this.state,
    required this.controller,
    required this.onOpenPrivacy,
  });

  final ProfileIdentity identity;
  final ProfileState state;
  final ProfileController controller;
  final VoidCallback onOpenPrivacy;

  @override
  State<_ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<_ProfileEdit> {
  static const _aliases = <String>[
    'QuietComet',
    'NorthSignal',
    'VelvetOrbit',
    'ClearCurrent',
  ];
  late final TextEditingController _alias;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _alias = TextEditingController(text: _draftAlias(widget.state));
  }

  @override
  void didUpdateWidget(covariant _ProfileEdit oldWidget) {
    super.didUpdateWidget(oldWidget);
    final resourceChanged = oldWidget.state.resource != widget.state.resource;
    final draftWasDiscarded = oldWidget.state.isDirty && !widget.state.isDirty;
    if (resourceChanged || draftWasDiscarded) {
      _replaceAliasText(_draftAlias(widget.state));
      _validationMessage = null;
    }
  }

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stackActions =
        MediaQuery.sizeOf(context).width < 480 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final discardButton = OutlinedButton(
      key: const ValueKey<String>('profile-discard'),
      onPressed:
          widget.state.isDirty &&
              !widget.state.isBusy &&
              !widget.state.requiresReload
          ? widget.controller.discard
          : null,
      child: Text(widget.state.requiresReload ? 'Reload required' : 'Discard'),
    );
    final saveButton = FilledButton.icon(
      key: const ValueKey<String>('profile-save'),
      onPressed: widget.state.canSave && _validationMessage == null
          ? () => unawaited(widget.controller.save())
          : null,
      icon: widget.state.phase == ProfilePhase.saving
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(
        widget.state.phase == ProfilePhase.saving ? 'Saving…' : 'Save changes',
      ),
    );
    return LoopPage(
      eyebrow: 'PUBLIC PROFILE',
      title: 'Edit profile',
      subtitle: 'Edit the reviewed Profile presentation resource. Wallet addresses and visibility remain separate.',
      padding: EdgeInsets.fromLTRB(20, 12, 20, stackActions ? 210 : 120),
      bottom: widget.state.resource == null
          ? null
          : LoopActionDock(
              child: stackActions
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        discardButton,
                        const SizedBox(height: 10),
                        saveButton,
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(child: discardButton),
                        const SizedBox(width: 12),
                        Expanded(child: saveButton),
                      ],
                    ),
            ),
      children: <Widget>[
        _ProfileModeBanner(mode: widget.state.mode),
        const SizedBox(height: 16),
        ..._stateContent(context),
      ],
    );
  }

  List<Widget> _stateContent(BuildContext context) {
    final state = widget.state;
    if (state.resource == null) {
      return switch (state.phase) {
        ProfilePhase.initial ||
        ProfilePhase.loading => const <Widget>[_ProfileLoadingCard()],
        ProfilePhase.unavailable => const <Widget>[
          LoopStateCard(
            title: 'Profile editing is not connected',
            message: 'The production Profile adapter is intentionally unavailable. No private request was sent and no demo profile is being shown.',
            icon: Icons.link_off_rounded,
            tone: LoopTone.warning,
          ),
        ],
        _ => <Widget>[
          LoopStateCard(
            title: 'Profile could not be loaded',
            message: _profileFailureMessage(state.failureKind),
            icon: Icons.sync_problem_rounded,
            tone: LoopTone.danger,
            action: OutlinedButton.icon(
              key: const ValueKey<String>('profile-retry-load'),
              onPressed: state.isBusy
                  ? null
                  : () => unawaited(widget.controller.reload()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ],
      };
    }

    final content = <Widget>[_ProfileSummary(state: state)];
    if (state.requiresReload) {
      final reloadInProgress = state.phase == ProfilePhase.loading;
      final reloadFailed =
          state.failureKind != null &&
          state.failureKind != ProfileGatewayFailureKind.versionConflict;
      content.addAll(<Widget>[
        const SizedBox(height: 14),
        LoopStateCard(
          key: const ValueKey<String>('profile-conflict'),
          title: reloadInProgress
              ? 'Reloading the latest Profile…'
              : reloadFailed
              ? 'Latest Profile could not be reloaded'
              : 'Version conflict — nothing was overwritten',
          message: reloadFailed
              ? '${_profileFailureMessage(state.failureKind)} The local Alias draft is still preserved.'
              : 'This Alias draft is based on an older account version. Reload the latest Profile before editing or saving again; reload discards this local draft.',
          icon: Icons.call_split_rounded,
          tone: LoopTone.warning,
          action: reloadInProgress
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Reloading…'),
                  ],
                )
              : FilledButton.icon(
                  key: const ValueKey<String>('profile-conflict-reload'),
                  onPressed: () => unawaited(widget.controller.reload()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(reloadFailed ? 'Retry reload' : 'Reload latest'),
                ),
        ),
      ]);
    } else if (state.phase == ProfilePhase.failure ||
        state.phase == ProfilePhase.unavailable) {
      content.addAll(<Widget>[
        const SizedBox(height: 14),
        LoopStateCard(
          title: 'Changes were not saved',
          message: _profileFailureMessage(state.failureKind),
          icon: Icons.cloud_off_rounded,
          tone: LoopTone.danger,
          action: OutlinedButton.icon(
            key: const ValueKey<String>('profile-retry-save'),
            onPressed: state.canSave && _validationMessage == null
                ? () => unawaited(widget.controller.save())
                : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry save'),
          ),
        ),
      ]);
    }

    content.addAll(<Widget>[
      const SizedBox(height: 24),
      Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            const _ProfileAvatar(size: 92),
            Positioned(
              right: -6,
              bottom: -6,
              child: IconButton.filled(
                tooltip: 'Avatar source unavailable',
                onPressed: null,
                icon: const Icon(Icons.camera_alt_outlined, size: 19),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 30),
      Text('Alias', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey<String>('profile-alias-input'),
        controller: _alias,
        enabled: state.canEdit,
        maxLength: 256,
        onChanged: _editAlias,
        decoration: InputDecoration(
          errorText: _validationMessage,
          helperText: '1–40 visible Unicode characters after trimming. Empty removes the Alias.',
          suffixIcon: IconButton(
            tooltip: 'Generate another alias',
            onPressed: state.canEdit
                ? () {
                    final current = _aliases.indexOf(_alias.text);
                    _replaceAliasText(
                      _aliases[(current + 1) % _aliases.length],
                    );
                    _editAlias(_alias.text);
                  }
                : null,
            icon: const Icon(Icons.shuffle_rounded),
          ),
        ),
      ),
      const SizedBox(height: 18),
      LoopStateCard(
        title: 'Only Alias is editable here',
        message: 'Bio is not part of the reviewed Profile contract. Profile visibility belongs to the separate Privacy resource, and avatar changes wait for an approved reference source.',
        icon: Icons.rule_folder_outlined,
        action: OutlinedButton.icon(
          key: const ValueKey<String>('profile-open-privacy'),
          onPressed: widget.onOpenPrivacy,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Open Privacy'),
        ),
      ),
    ]);
    return content;
  }

  String _draftAlias(ProfileState state) =>
      state.resource == null ? '' : state.draft.alias ?? '';

  void _replaceAliasText(String value) {
    _alias.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _editAlias(String rawAlias) {
    try {
      widget.controller.editAlias(rawAlias.trim().isEmpty ? null : rawAlias);
      if (_validationMessage != null) {
        setState(() => _validationMessage = null);
      }
    } on InvalidProfileContractException {
      setState(() {
        _validationMessage = 'Use 1–40 visible characters. Control and text-direction override characters are not accepted.';
      });
    } on StateError {
      // The field is disabled while loading, saving, or resolving a conflict.
    }
  }
}

class _ProfileModeBanner extends StatelessWidget {
  const _ProfileModeBanner({required this.mode});

  final ProfileMode mode;

  @override
  Widget build(BuildContext context) {
    return LoopStateCard(
      title: switch (mode) {
        ProfileMode.preview => '开发预览 · in-memory Profile',
        ProfileMode.production => 'Account Profile',
        ProfileMode.unavailable => 'Production connection unavailable',
      },
      message: switch (mode) {
        ProfileMode.preview => 'Edits persist only for this running Preview and do not update an account or provider.',
        ProfileMode.production => 'Alias and opaque avatar references are synchronized through the authenticated LOOP boundary.',
        ProfileMode.unavailable => 'The app is fail-closed until the authenticated Profile adapter is connected.',
      },
      icon: mode == ProfileMode.preview
          ? Icons.science_outlined
          : Icons.badge_outlined,
      tone: mode == ProfileMode.preview ? LoopTone.warning : LoopTone.neutral,
    );
  }
}

class _ProfileLoadingCard extends StatelessWidget {
  const _ProfileLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const LoopCard(
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('Loading Profile presentation…')),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.state});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final resource = state.resource!;
    final compactLabels =
        MediaQuery.sizeOf(context).width < 480 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        LoopStatusPill(
          label: 'VERSION ${resource.version}',
          tone: LoopTone.conversation,
        ),
        LoopStatusPill(
          label: state.isDirty
              ? (compactLabels ? 'DRAFT' : 'UNSAVED DRAFT')
              : (compactLabels ? 'NO CHANGES' : 'NO LOCAL CHANGES'),
          tone: state.isDirty ? LoopTone.warning : LoopTone.positive,
        ),
        LoopStatusPill(
          label: state.draft.alias == null ? 'ALIAS NOT SET' : 'ALIAS SET',
        ),
      ],
    );
  }
}

String _profileFailureMessage(ProfileGatewayFailureKind? kind) =>
    switch (kind) {
      ProfileGatewayFailureKind.unavailable =>
        'The Profile service is unavailable. No change was presented as saved.',
      ProfileGatewayFailureKind.versionConflict => 'The account Profile changed elsewhere. Reload is required before another save.',
      ProfileGatewayFailureKind.invalidData => 'The Profile source returned data outside the reviewed contract. Nothing was accepted.',
      ProfileGatewayFailureKind.unexpected =>
        'The Profile operation failed. Provider details were not exposed.',
      null => 'The Profile operation could not be completed.',
    };

class _PrivacyCenter extends ConsumerStatefulWidget {
  const _PrivacyCenter();

  @override
  ConsumerState<_PrivacyCenter> createState() => _PrivacyCenterState();
}

class _PrivacyCenterState extends ConsumerState<_PrivacyCenter> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(privacyControllerProvider);
    if (state.phase == PrivacyPhase.initial) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(privacyControllerProvider.notifier).load());
        }
      });
    }
    final controller = ref.read(privacyControllerProvider.notifier);
    final stackActions =
        MediaQuery.sizeOf(context).width < 480 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final discardButton = OutlinedButton(
      key: const ValueKey<String>('privacy-discard'),
      onPressed: state.isDirty && !state.isBusy && !state.requiresReload
          ? controller.discard
          : null,
      child: Text(state.requiresReload ? 'Reload required' : 'Discard draft'),
    );
    final applyButton = FilledButton.icon(
      key: const ValueKey<String>('privacy-apply'),
      onPressed: state.canSave ? () => unawaited(controller.save()) : null,
      icon: state.phase == PrivacyPhase.saving
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.task_alt_rounded),
      label: Text(
        state.phase == PrivacyPhase.saving ? 'Applying…' : 'Apply draft',
      ),
    );
    return LoopPage(
      eyebrow: state.mode == PrivacyMode.preview ? '开发预览 · PRIVACY' : 'PRIVACY',
      title: 'Privacy preferences',
      subtitle: 'Review the two owner preferences defined by the LOOP backend contract. They do not expose wallet, activity, or position data.',
      padding: EdgeInsets.fromLTRB(20, 12, 20, stackActions ? 210 : 120),
      bottom: state.resource == null
          ? null
          : LoopActionDock(
              child: stackActions
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        discardButton,
                        const SizedBox(height: 10),
                        applyButton,
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(child: discardButton),
                        const SizedBox(width: 12),
                        Expanded(child: applyButton),
                      ],
                    ),
            ),
      children: <Widget>[
        _PrivacyModeBanner(mode: state.mode),
        const SizedBox(height: 16),
        ..._privacyContent(state, controller),
      ],
    );
  }

  List<Widget> _privacyContent(
    PrivacyState state,
    PrivacyController controller,
  ) {
    if (state.resource == null) {
      return switch (state.phase) {
        PrivacyPhase.initial ||
        PrivacyPhase.loading => const <Widget>[_PrivacyLoadingCard()],
        PrivacyPhase.unavailable => const <Widget>[
          LoopStateCard(
            title: 'Privacy preferences are not connected',
            message: 'The production Privacy adapter is intentionally unavailable. No private request was sent and no demo preference is being shown.',
            icon: Icons.link_off_rounded,
            tone: LoopTone.warning,
          ),
        ],
        _ => <Widget>[
          LoopStateCard(
            title: 'Privacy preferences could not be loaded',
            message: _privacyFailureMessage(state.failureKind),
            icon: Icons.sync_problem_rounded,
            tone: LoopTone.danger,
            action: OutlinedButton.icon(
              key: const ValueKey<String>('privacy-retry-load'),
              onPressed: state.isBusy
                  ? null
                  : () => unawaited(controller.reload()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ],
      };
    }

    final content = <Widget>[_PrivacySummary(state: state)];
    if (state.requiresReload) {
      final reloadInProgress = state.phase == PrivacyPhase.loading;
      final reloadFailed =
          state.failureKind != null &&
          state.failureKind != PrivacyGatewayFailureKind.versionConflict;
      content.addAll(<Widget>[
        const SizedBox(height: 14),
        LoopStateCard(
          key: const ValueKey<String>('privacy-conflict'),
          title: reloadInProgress
              ? 'Reloading the latest preferences…'
              : reloadFailed
              ? 'Latest preferences could not be reloaded'
              : 'Version conflict — nothing was overwritten',
          message: reloadFailed
              ? '${_privacyFailureMessage(state.failureKind)} The local draft is still preserved.'
              : 'This draft is based on an older account version. Reload before editing or applying it again; reload discards this local draft.',
          icon: Icons.call_split_rounded,
          tone: LoopTone.warning,
          action: reloadInProgress
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Reloading…'),
                  ],
                )
              : FilledButton.icon(
                  key: const ValueKey<String>('privacy-conflict-reload'),
                  onPressed: () => unawaited(controller.reload()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(reloadFailed ? 'Retry reload' : 'Reload latest'),
                ),
        ),
      ]);
    } else if (state.phase == PrivacyPhase.failure ||
        state.phase == PrivacyPhase.unavailable) {
      content.addAll(<Widget>[
        const SizedBox(height: 14),
        LoopStateCard(
          title: 'Preferences were not committed',
          message: _privacyFailureMessage(state.failureKind),
          icon: Icons.cloud_off_rounded,
          tone: LoopTone.danger,
          action: OutlinedButton.icon(
            key: const ValueKey<String>('privacy-retry-apply'),
            onPressed: state.canSave
                ? () => unawaited(controller.save())
                : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry apply'),
          ),
        ),
      ]);
    }

    content.addAll(<Widget>[
      const SizedBox(height: 24),
      LoopCard(
        child: Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            key: const ValueKey<String>('privacy-discoverable-switch'),
            contentPadding: EdgeInsets.zero,
            value: state.draft.discoverable,
            onChanged: state.canEdit ? controller.editDiscoverable : null,
            title: const Text('Discoverability preference'),
            subtitle: const Text(
              'Records whether you want a future LOOP discovery surface to include this profile. No public discovery service is connected here.',
            ),
            secondary: const Icon(Icons.travel_explore_rounded),
          ),
        ),
      ),
      const LoopSectionLabel('Copy-trade presentation preference'),
      LoopCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Choose the audience value stored with Privacy. This value cannot authorize followers, wallets, orders, or copy execution.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CopyTradeVisibility.values
                  .map(
                    (visibility) => ChoiceChip(
                      key: ValueKey<String>(
                        'privacy-visibility-${visibility.wireValue}',
                      ),
                      label: Text(_copyTradeVisibilityLabel(visibility)),
                      selected: state.draft.copyTradeVisibility == visibility,
                      onSelected: state.canEdit
                          ? (_) =>
                                controller.editCopyTradeVisibility(visibility)
                          : null,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const _PrivacyFootnote(
        text: 'These are owner preferences only. LOOP has not connected public-profile discovery, a follower graph, copy-trade authorization, or copy execution.',
      ),
    ]);
    return content;
  }
}

class _PrivacyModeBanner extends StatelessWidget {
  const _PrivacyModeBanner({required this.mode});

  final PrivacyMode mode;

  @override
  Widget build(BuildContext context) {
    return LoopStateCard(
      title: switch (mode) {
        PrivacyMode.preview => '开发预览 · in-memory Privacy',
        PrivacyMode.production => 'Account Privacy preferences',
        PrivacyMode.unavailable => 'Production connection unavailable',
      },
      message: switch (mode) {
        PrivacyMode.preview => 'Drafts persist only for this running Preview and do not change an account, social graph, or trading permission.',
        PrivacyMode.production => 'The two owner preferences are synchronized through the authenticated LOOP boundary.',
        PrivacyMode.unavailable => 'The app is fail-closed until the authenticated Privacy adapter is connected.',
      },
      icon: mode == PrivacyMode.preview
          ? Icons.science_outlined
          : Icons.visibility_outlined,
      tone: mode == PrivacyMode.preview ? LoopTone.warning : LoopTone.neutral,
    );
  }
}

class _PrivacyLoadingCard extends StatelessWidget {
  const _PrivacyLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const LoopCard(
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('Loading Privacy preferences…')),
        ],
      ),
    );
  }
}

class _PrivacySummary extends StatelessWidget {
  const _PrivacySummary({required this.state});

  final PrivacyState state;

  @override
  Widget build(BuildContext context) {
    final resource = state.resource!;
    final compactLabels =
        MediaQuery.sizeOf(context).width < 480 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        LoopStatusPill(
          label: compactLabels
              ? 'V${resource.version}'
              : 'VERSION ${resource.version}',
          tone: LoopTone.conversation,
        ),
        LoopStatusPill(
          label: state.isDirty
              ? (compactLabels ? 'DRAFT' : 'UNSAVED DRAFT')
              : (compactLabels ? 'NO CHANGES' : 'NO LOCAL CHANGES'),
          tone: state.isDirty ? LoopTone.warning : LoopTone.positive,
        ),
        LoopStatusPill(
          label: state.draft.discoverable
              ? (compactLabels ? 'DISC ON' : 'DISCOVERY PREFERENCE ON')
              : (compactLabels ? 'DISC OFF' : 'DISCOVERY PREFERENCE OFF'),
        ),
        LoopStatusPill(
          label: compactLabels
              ? _compactCopyVisibilityLabel(state.draft.copyTradeVisibility)
              : 'COPY ${state.draft.copyTradeVisibility.wireValue.toUpperCase()}',
        ),
      ],
    );
  }
}

String _copyTradeVisibilityLabel(CopyTradeVisibility visibility) =>
    switch (visibility) {
      CopyTradeVisibility.private => 'Private',
      CopyTradeVisibility.followers => 'Followers',
      CopyTradeVisibility.public => 'Public',
    };

String _compactCopyVisibilityLabel(CopyTradeVisibility visibility) =>
    switch (visibility) {
      CopyTradeVisibility.private => 'COPY PRI',
      CopyTradeVisibility.followers => 'COPY FOL',
      CopyTradeVisibility.public => 'COPY PUB',
    };

String _privacyFailureMessage(PrivacyGatewayFailureKind? kind) =>
    switch (kind) {
      PrivacyGatewayFailureKind.unavailable => 'The Privacy service is unavailable. No preference was presented as committed.',
      PrivacyGatewayFailureKind.versionConflict => 'The account Privacy resource changed elsewhere. Reload is required before another apply.',
      PrivacyGatewayFailureKind.invalidData => 'The Privacy source returned data outside the reviewed contract. Nothing was accepted.',
      PrivacyGatewayFailureKind.unexpected =>
        'The Privacy operation failed. Provider details were not exposed.',
      null => 'The Privacy operation could not be completed.',
    };

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
              icon: Icons.password_rounded,
              title: 'Recovery phrase',
              detail: capabilities.recoveryPhraseRevealAvailable
                  ? 'Capability is available; enrollment status is unknown.'
                  : 'Capability is not available for this wallet.',
              trailing: _CapabilityPill(
                available: capabilities.recoveryPhraseRevealAvailable,
              ),
              onTap: () => onNavigate('seed-backup'),
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

class _RecoveryPhraseAccess extends StatefulWidget {
  const _RecoveryPhraseAccess({
    required this.capabilities,
    required this.authenticate,
    required this.recoveryWords,
  });

  final PrivyProfileCapabilities capabilities;
  final SensitiveProfileAuthentication? authenticate;
  final List<String>? recoveryWords;

  @override
  State<_RecoveryPhraseAccess> createState() => _RecoveryPhraseAccessState();
}

class _RecoveryPhraseAccessState extends State<_RecoveryPhraseAccess>
    with WidgetsBindingObserver {
  bool _authenticating = false;
  bool _revealed = false;
  String? _message;

  bool get _available =>
      widget.capabilities.recoveryPhraseRevealAvailable &&
      widget.capabilities.secureScreenProtectionActive &&
      widget.authenticate != null &&
      widget.recoveryWords != null &&
      widget.recoveryWords!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() => _revealed = false);
    }
  }

  Future<void> _authenticate() async {
    if (!_available) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    bool allowed;
    try {
      allowed = await widget.authenticate!();
    } on Object {
      allowed = false;
    }
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _revealed = allowed;
      _message = allowed
          ? null
          : 'Identity check failed. Recovery words remain hidden.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      eyebrow: 'RECOVERY',
      title: 'View recovery words',
      subtitle: 'A fresh identity check is required every time. Words hide as soon as LOOP leaves the foreground.',
      children: <Widget>[
        const LoopStateCard(
          title: 'Never share these words',
          message: 'Anyone with the full phrase can control the wallet. Support will never ask you for it.',
          icon: Icons.warning_amber_rounded,
          tone: LoopTone.danger,
        ),
        const SizedBox(height: 16),
        if (!_available)
          LoopStateCard(
            title: 'Recovery words unavailable',
            message: widget.capabilities.secureScreenProtectionActive
                ? 'This wallet has not authorized a secure recovery-word reveal. Nothing is displayed.'
                : 'Screen-capture protection could not be confirmed, so recovery words stay hidden.',
            icon: Icons.lock_outline_rounded,
            tone: LoopTone.warning,
          )
        else if (!_revealed) ...<Widget>[
          LoopCard(
            child: Column(
              children: <Widget>[
                const Icon(
                  Icons.fingerprint_rounded,
                  color: LoopColors.mint,
                  size: 52,
                ),
                const SizedBox(height: 14),
                Text(
                  'Confirm it’s you',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 7),
                Text(
                  'Use your configured passkey, biometrics, or app PIN.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _authenticating ? null : _authenticate,
                    child: Text(
                      _authenticating ? 'Checking…' : 'Verify identity',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_message != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: LoopColors.danger),
            ),
          ],
        ] else ...<Widget>[
          _RecoveryWordGrid(words: widget.recoveryWords!),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _revealed = false),
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('Hide recovery words'),
            ),
          ),
        ],
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

class _NotificationSettings extends ConsumerStatefulWidget {
  const _NotificationSettings();

  @override
  ConsumerState<_NotificationSettings> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<_NotificationSettings> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationPreferencesControllerProvider);
    if (state.phase == NotificationPreferencesPhase.initial) {
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
    final stackActions =
        MediaQuery.sizeOf(context).width < 480 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final discardButton = OutlinedButton(
      key: const ValueKey<String>('notification-preferences-discard'),
      onPressed: state.isDirty && !state.isBusy && !state.requiresReload
          ? controller.discard
          : null,
      child: Text(state.requiresReload ? 'Reload required' : 'Discard draft'),
    );
    final applyButton = FilledButton.icon(
      key: const ValueKey<String>('notification-preferences-apply'),
      onPressed: state.canSave ? () => unawaited(controller.save()) : null,
      icon: state.phase == NotificationPreferencesPhase.saving
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.task_alt_rounded),
      label: Text(
        state.phase == NotificationPreferencesPhase.saving
            ? 'Applying…'
            : 'Apply draft',
      ),
    );
    return LoopPage(
      eyebrow: state.mode == NotificationPreferencesMode.preview
          ? '开发预览 · NOTIFICATIONS'
          : 'NOTIFICATIONS',
      title: 'Notification preferences',
      subtitle: 'Store the four owner intents defined by the LOOP backend contract. A saved preference does not prove device permission or provider delivery.',
      padding: EdgeInsets.fromLTRB(20, 12, 20, stackActions ? 210 : 120),
      bottom: state.resource == null
          ? null
          : LoopActionDock(
              child: stackActions
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        discardButton,
                        const SizedBox(height: 10),
                        applyButton,
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(child: discardButton),
                        const SizedBox(width: 12),
                        Expanded(child: applyButton),
                      ],
                    ),
            ),
      children: <Widget>[
        _NotificationPreferencesModeBanner(mode: state.mode),
        const SizedBox(height: 16),
        ..._notificationPreferencesContent(state, controller),
      ],
    );
  }

  List<Widget> _notificationPreferencesContent(
    NotificationPreferencesState state,
    NotificationPreferencesController controller,
  ) {
    if (state.resource == null) {
      return switch (state.phase) {
        NotificationPreferencesPhase.initial ||
        NotificationPreferencesPhase.loading => const <Widget>[
          _NotificationPreferencesLoadingCard(),
        ],
        NotificationPreferencesPhase.unavailable => const <Widget>[
          LoopStateCard(
            title: 'Notification preferences are not connected',
            message: 'The production Notification Preferences adapter is intentionally unavailable. No account request was sent and no demo preference or delivery state is being shown.',
            icon: Icons.link_off_rounded,
            tone: LoopTone.warning,
          ),
        ],
        _ => <Widget>[
          LoopStateCard(
            title: 'Notification preferences could not be loaded',
            message: _notificationPreferencesFailureMessage(state.failureKind),
            icon: Icons.sync_problem_rounded,
            tone: LoopTone.danger,
            action: OutlinedButton.icon(
              key: const ValueKey<String>(
                'notification-preferences-retry-load',
              ),
              onPressed: state.isBusy
                  ? null
                  : () => unawaited(controller.reload()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ],
      };
    }

    final content = <Widget>[_NotificationPreferencesSummary(state: state)];
    if (state.requiresReload) {
      final reloadInProgress =
          state.phase == NotificationPreferencesPhase.loading;
      final reloadFailed =
          state.failureKind != null &&
          state.failureKind !=
              NotificationPreferencesGatewayFailureKind.versionConflict;
      content.addAll(<Widget>[
        const SizedBox(height: 14),
        LoopStateCard(
          key: const ValueKey<String>('notification-preferences-conflict'),
          title: reloadInProgress
              ? 'Reloading the latest preferences…'
              : reloadFailed
              ? 'Latest preferences could not be reloaded'
              : 'Version conflict — nothing was overwritten',
          message: reloadFailed
              ? '${_notificationPreferencesFailureMessage(state.failureKind)} The local draft is still preserved.'
              : 'This draft is based on an older account version. Reload before editing or applying it again; reload discards this local draft.',
          icon: Icons.call_split_rounded,
          tone: LoopTone.warning,
          action: reloadInProgress
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Reloading…'),
                  ],
                )
              : FilledButton.icon(
                  key: const ValueKey<String>(
                    'notification-preferences-conflict-reload',
                  ),
                  onPressed: () => unawaited(controller.reload()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(reloadFailed ? 'Retry reload' : 'Reload latest'),
                ),
        ),
      ]);
    } else if (state.phase == NotificationPreferencesPhase.failure ||
        state.phase == NotificationPreferencesPhase.unavailable) {
      content.addAll(<Widget>[
        const SizedBox(height: 14),
        LoopStateCard(
          title: 'Preferences were not committed',
          message: _notificationPreferencesFailureMessage(state.failureKind),
          icon: Icons.cloud_off_rounded,
          tone: LoopTone.danger,
          action: OutlinedButton.icon(
            key: const ValueKey<String>('notification-preferences-retry-apply'),
            onPressed: state.canSave
                ? () => unawaited(controller.save())
                : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry apply'),
          ),
        ),
      ]);
    }

    content.addAll(<Widget>[
      const SizedBox(height: 18),
      const LoopStateCard(
        title: 'Delivery unavailable',
        message: 'These switches record owner intent only. Firebase, APNs/FCM, operating-system permission, and background delivery are not connected by this resource.',
        icon: Icons.notifications_paused_outlined,
        tone: LoopTone.warning,
      ),
      const LoopSectionLabel('Owner preferences'),
      for (final event in NotificationPreferenceEvent.values) ...<Widget>[
        LoopCard(
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              key: ValueKey<String>(
                'notification-preference-${event.wireValue}',
              ),
              contentPadding: EdgeInsets.zero,
              value: state.draft.enabledFor(event),
              onChanged: state.canEdit
                  ? (enabled) => controller.edit(event, enabled)
                  : null,
              title: Text(_notificationPreferenceLabel(event)),
              subtitle: Text(_notificationPreferenceDetail(event)),
              secondary: Icon(_notificationPreferenceIcon(event)),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      const _PrivacyFootnote(
        text: 'Enabled means only that the owner intent is stored. It never proves that an alert exists, a provider accepted it, or a device received it.',
      ),
    ]);
    return content;
  }
}

class _NotificationPreferencesModeBanner extends StatelessWidget {
  const _NotificationPreferencesModeBanner({required this.mode});

  final NotificationPreferencesMode mode;

  @override
  Widget build(BuildContext context) {
    return LoopStateCard(
      title: switch (mode) {
        NotificationPreferencesMode.preview => '开发预览 · in-memory preferences',
        NotificationPreferencesMode.production =>
          'Account Notification preferences',
        NotificationPreferencesMode.unavailable =>
          'Production connection unavailable',
      },
      message: switch (mode) {
        NotificationPreferencesMode.preview => 'Drafts persist only for this running Preview and do not change an account, provider, device permission, or delivery state.',
        NotificationPreferencesMode.production => 'When the authenticated adapter is available, this boundary can synchronize only the four reviewed owner intents. Delivery remains unavailable.',
        NotificationPreferencesMode.unavailable => 'The app is fail-closed until the authenticated Notification Preferences adapter is connected.',
      },
      icon: mode == NotificationPreferencesMode.preview
          ? Icons.science_outlined
          : Icons.notifications_outlined,
      tone: mode == NotificationPreferencesMode.preview
          ? LoopTone.warning
          : LoopTone.neutral,
    );
  }
}

class _NotificationPreferencesLoadingCard extends StatelessWidget {
  const _NotificationPreferencesLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const LoopCard(
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('Loading Notification preferences…')),
        ],
      ),
    );
  }
}

class _NotificationPreferencesSummary extends StatelessWidget {
  const _NotificationPreferencesSummary({required this.state});

  final NotificationPreferencesState state;

  @override
  Widget build(BuildContext context) {
    final resource = state.resource!;
    final compactLabels =
        MediaQuery.sizeOf(context).width < 480 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final statePills = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        LoopStatusPill(
          label: compactLabels
              ? 'V${resource.version}'
              : 'VERSION ${resource.version}',
          tone: LoopTone.conversation,
        ),
        LoopStatusPill(
          label: state.isDirty
              ? (compactLabels ? 'DRAFT' : 'UNSAVED DRAFT')
              : (compactLabels ? 'NO CHANGES' : 'NO LOCAL CHANGES'),
          tone: state.isDirty ? LoopTone.warning : LoopTone.positive,
        ),
        LoopStatusPill(label: '${state.draft.enabledCount} OF 4 ENABLED'),
      ],
    );
    if (!compactLabels) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          statePills,
          const LoopStatusPill(
            label: 'DELIVERY UNAVAILABLE',
            tone: LoopTone.warning,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        statePills,
        const SizedBox(height: 8),
        const _NotificationDeliveryBadge(),
      ],
    );
  }
}

class _NotificationDeliveryBadge extends StatelessWidget {
  const _NotificationDeliveryBadge();

  @override
  Widget build(BuildContext context) {
    final color = loopToneColor(LoopTone.warning);
    return Semantics(
      label: 'DELIVERY UNAVAILABLE',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: LoopRadius.pill,
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            'DELIVERY UNAVAILABLE',
            softWrap: true,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

String _notificationPreferenceLabel(NotificationPreferenceEvent event) =>
    switch (event) {
      NotificationPreferenceEvent.priceAlertTriggered => 'Price alert events',
      NotificationPreferenceEvent.providerActivityProjected =>
        'Provider activity projections',
      NotificationPreferenceEvent.securityNotice => 'Security notices',
      NotificationPreferenceEvent.supportUpdate => 'Support updates',
    };

String _notificationPreferenceDetail(NotificationPreferenceEvent event) =>
    switch (event) {
      NotificationPreferenceEvent.priceAlertTriggered => 'Intent to receive a notification after a separately configured price alert is triggered.',
      NotificationPreferenceEvent.providerActivityProjected => 'Intent to receive projections derived from supported provider activity; no provider feed is connected here.',
      NotificationPreferenceEvent.securityNotice => 'Intent to receive account-security notices when a supported delivery path exists.',
      NotificationPreferenceEvent.supportUpdate => 'Intent to receive updates for support activity associated with this account.',
    };

IconData _notificationPreferenceIcon(NotificationPreferenceEvent event) =>
    switch (event) {
      NotificationPreferenceEvent.priceAlertTriggered =>
        Icons.price_change_outlined,
      NotificationPreferenceEvent.providerActivityProjected =>
        Icons.insights_outlined,
      NotificationPreferenceEvent.securityNotice => Icons.shield_outlined,
      NotificationPreferenceEvent.supportUpdate => Icons.support_agent_outlined,
    };

String _notificationPreferencesFailureMessage(
  NotificationPreferencesGatewayFailureKind? kind,
) => switch (kind) {
  NotificationPreferencesGatewayFailureKind.unavailable => 'The Notification Preferences service is unavailable. No preference was presented as committed.',
  NotificationPreferencesGatewayFailureKind.versionConflict => 'The account Notification Preferences resource changed elsewhere. Reload is required before another apply.',
  NotificationPreferencesGatewayFailureKind.invalidData => 'The Notification Preferences source returned data outside the reviewed contract. Nothing was accepted.',
  NotificationPreferencesGatewayFailureKind.unexpected => 'The Notification Preferences operation failed. Provider details were not exposed.',
  null => 'The Notification Preferences operation could not be completed.',
};

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

class _IdentityThreadCard extends StatelessWidget {
  const _IdentityThreadCard({required this.identity});

  final ProfileIdentity identity;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      accent: true,
      tone: LoopTone.conversation,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _ProfileAvatar(size: 70),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      identity.alias,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      identity.bio,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(
                        color: LoopColors.elevated,
                        borderRadius: LoopRadius.pill,
                      ),
                      child: Text(
                        identity.address,
                        style: context.dataStyle.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _IdentityThread(),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(
                child: LoopMetric(
                  label: 'CONNECTIONS',
                  value: '${identity.connections}',
                ),
              ),
              Expanded(
                child: LoopMetric(label: 'GROUPS', value: '${identity.groups}'),
              ),
              Expanded(
                child: LoopMetric(
                  label: 'WATCHLIST',
                  value: '${identity.watchlistItems}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IdentityThread extends StatelessWidget {
  const _IdentityThread();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Alias public, wallet private, activity private',
      child: Row(
        children: <Widget>[
          const _ThreadNode(
            label: 'ALIAS',
            icon: Icons.theater_comedy_outlined,
            color: LoopColors.chat,
          ),
          Expanded(child: Container(height: 1, color: LoopColors.line)),
          const _ThreadNode(
            label: 'WALLET',
            icon: Icons.account_balance_wallet_outlined,
            color: LoopColors.mint,
          ),
          Expanded(child: Container(height: 1, color: LoopColors.line)),
          const _ThreadNode(
            label: 'ACTIVITY',
            icon: Icons.show_chart_rounded,
            color: LoopColors.market,
          ),
        ],
      ),
    );
  }
}

class _ThreadNode extends StatelessWidget {
  const _ThreadNode({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 9),
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
    this.tone = LoopTone.neutral,
    this.trailing,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;
  final LoopTone tone;
  final Widget? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = loopToneColor(tone);
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
              Icon(
                icon,
                size: 21,
                color: tone == LoopTone.neutral ? LoopColors.vapor : color,
              ),
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

class _LaterTile extends StatelessWidget {
  const _LaterTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: LoopColors.vapor),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text('Coming later', style: Theme.of(context).textTheme.labelMedium),
        ],
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

class _RecoveryWordGrid extends StatelessWidget {
  const _RecoveryWordGrid({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return LoopCard(
      accent: true,
      tone: LoopTone.danger,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: words.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.25,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
            color: LoopColors.elevated,
            borderRadius: LoopRadius.small,
          ),
          child: Text(
            '${index + 1}. ${words[index]}',
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: context.dataStyle.copyWith(fontSize: 12),
          ),
        ),
      ),
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[LoopColors.market, LoopColors.chat],
        ),
        border: Border.all(color: LoopColors.chalk.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.blur_on_rounded,
        color: LoopColors.abyss,
        size: size * 0.48,
      ),
    );
  }
}
