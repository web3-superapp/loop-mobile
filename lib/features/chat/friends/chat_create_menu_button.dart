import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

enum _ChatCreateAction { addFriend, createCommunity, createGroup, scan }

/// The 聊天 tab's 「＋」 (decision 0110, S106 §2): every way to start a
/// relationship, in one bottom sheet.
///
/// 搜索/添加用户 opens the global search, where a person is found and asked;
/// 创建社区 is the same application 发现社区 submits; 创建群聊 opens the group
/// form; 扫一扫 opens the scanner (decision 0113).
/// The face of the bar's Yellow 「＋」 key (docs/58 §5.20: 32 × 32).
const double chatCreateKeySize = 32;

class ChatCreateMenuButton extends ConsumerWidget {
  const ChatCreateMenuButton({super.key, this.floating = false});

  /// The OKX action key (decision 0122): a 56 yellow square (decision 0210)
  /// with an Ink glyph, floated at the foot of 聊天 instead of the bar's 「＋」.
  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (floating) {
      return Semantics(
        button: true,
        label: context.l10n.chatFriends_createMenuButtonChatCreateMenuLabel,
        excludeSemantics: true,
        child: Material(
          key: const ValueKey<String>('chat-create-menu'),
          // Decision 0211: a floating action is a round Yellow key,
          // deepened while pressed.
          color: LoopColors.yellow,
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            highlightColor: LoopColors.yellowPressed,
            splashColor: Colors.transparent,
            onTap: () => unawaited(_open(context, ref)),
            child: const SizedBox.square(
              dimension: LoopLayout.floatingActionExtent,
              child: Center(
                child: LoopIcon('plus', size: 24, color: LoopColors.ink),
              ),
            ),
          ),
        ),
      );
    }
    // S353a · decision 0278 (docs/58 §5.20): the bar's 「＋」 is the Figma's
    // Yellow square key — 32 at a 4 corner, a 22 plus in onYellow — drawn
    // inside the 44 target.
    return Semantics(
      button: true,
      label: context.l10n.chatFriends_createMenuButtonChatCreateMenuLabel2,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey<String>('chat-create-menu'),
        onTap: () => unawaited(_open(context, ref)),
        customBorder: const RoundedRectangleBorder(
          borderRadius: LoopRadius.stage,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: SizedBox.square(
          dimension: LoopTouch.minimum,
          child: Center(
            child: Container(
              key: const ValueKey<String>('chat-create-menu-face'),
              width: chatCreateKeySize,
              height: chatCreateKeySize,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: LoopColors.yellow,
                borderRadius: LoopRadius.stage,
              ),
              child: const LoopIcon(
                'plus',
                size: 22,
                color: LoopColors.onYellow,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final action = await showLoopSheet<_ChatCreateAction>(
      context,
      // Over the floating tab bar, not under it: on the shell's navigator
      // the bar covered 扫一扫 and the sheet had nothing left to scroll.
      useRootNavigator: true,
      builder: (sheetContext) => LoopRecordGroup(
        key: const ValueKey<String>('chat-create-sheet'),
        rows: <LoopRecordRow>[
          _row(
            sheetContext,
            key: 'chat-add-friend-menu-item',
            icon: 'search',
            title: context.l10n.chatFriends_createMenuButtonTitle,
            subtitle: context.l10n.chatFriends_createMenuButtonSubtitle,
            action: _ChatCreateAction.addFriend,
            position: LoopRowPosition.first,
          ),
          _row(
            sheetContext,
            key: 'chat-create-community-menu-item',
            icon: 'community',
            title: context.l10n.chatFriends_createMenuButtonTitle2,
            subtitle: context.l10n.chatFriends_createMenuButtonSubtitle2,
            action: _ChatCreateAction.createCommunity,
          ),
          _row(
            sheetContext,
            key: 'chat-create-group-menu-item',
            icon: 'users',
            title: context.l10n.chatFriends_createMenuButtonTitle3,
            subtitle: context.l10n.chatFriends_createMenuButtonSubtitle3,
            action: _ChatCreateAction.createGroup,
          ),
          _row(
            sheetContext,
            key: 'chat-scan-menu-item',
            icon: 'camera',
            title: context.l10n.common_scan,
            subtitle: context.l10n.chatFriends_createMenuButtonSubtitle4,
            action: _ChatCreateAction.scan,
            position: LoopRowPosition.last,
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _ChatCreateAction.addFriend:
        unawaited(context.push<void>('/search'));
      case _ChatCreateAction.createGroup:
        unawaited(context.push<void>('/chat/groups/create'));
      case _ChatCreateAction.createCommunity:
        await startCommunityApplication(
          context,
          ref,
          onOpenCommunity: (communityId) => unawaited(
            context.push<void>(
              '/community/profile?id=${Uri.encodeQueryComponent(communityId)}',
            ),
          ),
        );
      case _ChatCreateAction.scan:
        unawaited(context.push<void>('/scan'));
    }
  }

  static LoopRecordRow _row(
    BuildContext sheetContext, {
    required String key,
    required String icon,
    required String title,
    required String subtitle,
    required _ChatCreateAction action,
    LoopRowPosition position = LoopRowPosition.middle,
  }) => LoopRecordRow(
    key: ValueKey<String>(key),
    leading: LoopRowIcon(icon: icon),
    title: title,
    subtitle: subtitle,
    position: position,
    onTap: () => Navigator.of(sheetContext).pop(action),
  );
}
