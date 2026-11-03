import 'package:flutter/material.dart';
import 'package:loop_mobile/features/profile/me_attention.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// 我 since S343 (decision 0271): the person, the stranger requests and the
/// account rows at the head and foot of the 我的 tab, without the wallet's
/// own reads. The tests that used to mount the retired `profile` surface
/// mount this instead; `/wallet` mounts the real tab.
Widget loopMeSurface({required ValueChanged<String> onNavigate}) =>
    LoopDashboardPage(
      key: const ValueKey<String>('me-surface'),
      archetype: LoopPageArchetype.record,
      title: '我的',
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('profile-open-settings'),
          icon: 'settings',
          label: '设置',
          onPressed: () => onNavigate('settings'),
        ),
      ],
      sections: <Widget>[
        ProfileIdentitySection(onNavigate: onNavigate),
        MeMessageRequestsEntry(onOpen: () => onNavigate('friend-requests')),
        MeAccountEntries(onNavigate: onNavigate),
      ],
    );
