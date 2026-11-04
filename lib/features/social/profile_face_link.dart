import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// 我的, the reader's own page (S343 · decision 0271: the `/wallet` tab).
const String loopOwnProfileLocation = '/wallet';

/// Where a face opens (S239, decision 0214): the reader's own face opens 我,
/// anybody else's opens their `user-profile` page. `null` when there is no
/// public profile to open — a bare wallet address opens nothing.
String? loopProfileFaceLocation(
  String? publicProfileId, {
  bool isSelf = false,
}) {
  if (isSelf) return loopOwnProfileLocation;
  if (publicProfileId == null || publicProfileId.isEmpty) return null;
  return userProfileLocation(publicProfileId);
}

/// Makes one avatar open its owner's page (需求方 2026-10-19: 所有头像都能点进
/// 主页).
///
/// With nothing to open ([loopProfileFaceLocation] is `null`) the child is
/// returned untouched: no gesture, no button semantics. The hit area is at
/// least 44 × 44 whatever size the face is drawn at. [onOpen] defaults to
/// pushing the location on the ambient router.
class LoopProfileFaceLink extends StatelessWidget {
  const LoopProfileFaceLink({
    required this.publicProfileId,
    required this.name,
    required this.child,
    this.isSelf = false,
    this.onOpen,
    super.key,
  });

  final String? publicProfileId;
  final bool isSelf;

  /// Spoken as 「查看 {name} 的主页」.
  final String name;
  final Widget child;
  final ValueChanged<String>? onOpen;

  /// Pushes [location] on the ambient router, if there is one. The
  /// reader's own page is a tab, so it is switched to rather than pushed.
  static void push(BuildContext context, String location) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (location == loopOwnProfileLocation) {
      router.go(location);
      return;
    }
    unawaited(router.push<void>(location));
  }

  @override
  Widget build(BuildContext context) {
    final location = loopProfileFaceLocation(publicProfileId, isSelf: isSelf);
    if (location == null) return child;
    return Semantics(
      button: true,
      label: isSelf
          ? context.l10n.social_profileFaceLinkLabel
          : context.l10n.social_profileFaceLinkLabel2(name),
      child: LoopPressable(
        onTap: () {
          final open = onOpen;
          if (open != null) {
            open(location);
            return;
          }
          push(context, location);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: LoopTouch.minimum,
            minHeight: LoopTouch.minimum,
          ),
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }
}
