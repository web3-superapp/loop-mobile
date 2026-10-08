import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
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
class ChatCreateMenuButton extends ConsumerWidget {
  const ChatCreateMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LoopIconButton(
      key: const ValueKey<String>('chat-create-menu'),
      icon: 'plus',
      label: '添加',
      onPressed: () => unawaited(_open(context, ref)),
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
            title: '搜索 / 添加用户',
            subtitle: '按 LOOP ID 或昵称找人，发送消息请求',
            action: _ChatCreateAction.addFriend,
            position: LoopRowPosition.first,
          ),
          _row(
            sheetContext,
            key: 'chat-create-community-menu-item',
            icon: 'community',
            title: '创建社区',
            subtitle: '提交入驻申请，审核通过后上线',
            action: _ChatCreateAction.createCommunity,
          ),
          _row(
            sheetContext,
            key: 'chat-create-group-menu-item',
            icon: 'users',
            title: '创建群聊',
            subtitle: '和好友建一个小群',
            action: _ChatCreateAction.createGroup,
          ),
          _row(
            sheetContext,
            key: 'chat-scan-menu-item',
            icon: 'camera',
            title: '扫一扫',
            subtitle: '扫名片、社区码或钱包地址',
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
