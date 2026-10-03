import 'dart:async';

import 'package:loop_mobile/features/social/social_qr.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_application_flow.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

enum _ChatCreateAction { createGroup, addFriend, createCommunity, scan, myQr }

/// WeChat-style creation menu shared by Preview and production Chat headers.
class ChatCreateMenuButton extends ConsumerWidget {
  const ChatCreateMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ChatCreateAction>(
      key: const ValueKey<String>('chat-create-menu'),
      tooltip: '添加',
      icon: const Icon(Icons.add_rounded),
      offset: const Offset(0, 8),
      color: LoopColors.basalt,
      shape: RoundedRectangleBorder(
        borderRadius: LoopRadius.medium,
        side: const BorderSide(color: LoopColors.line),
      ),
      onSelected: (action) {
        switch (action) {
          case _ChatCreateAction.createGroup:
            context.push('/chat/groups/create');
          case _ChatCreateAction.createCommunity:
            unawaited(openCommunityApplication(context, ref));
          case _ChatCreateAction.addFriend:
            context.push('/search');
          case _ChatCreateAction.scan:
            unawaited(openSocialScan(context, ref));
          case _ChatCreateAction.myQr:
            unawaited(_myQr(context, ref));
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<_ChatCreateAction>>[
        PopupMenuItem<_ChatCreateAction>(
          key: ValueKey<String>('chat-create-community-menu-item'),
          value: _ChatCreateAction.createCommunity,
          child: _ChatCreateMenuRow(
            icon: Icons.diversity_3_outlined,
            label: '创建社区',
          ),
        ),
        PopupMenuItem<_ChatCreateAction>(
          key: ValueKey<String>('chat-create-group-menu-item'),
          value: _ChatCreateAction.createGroup,
          child: _ChatCreateMenuRow(
            icon: Icons.group_add_outlined,
            label: '创建群组',
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<_ChatCreateAction>(
          value: _ChatCreateAction.scan,
          child: _ChatCreateMenuRow(
            icon: Icons.qr_code_scanner_rounded,
            label: '扫一扫',
          ),
        ),
        PopupMenuItem<_ChatCreateAction>(
          value: _ChatCreateAction.myQr,
          child: _ChatCreateMenuRow(
            icon: Icons.qr_code_2_rounded,
            label: '我的二维码',
          ),
        ),
        PopupMenuItem<_ChatCreateAction>(
          key: ValueKey<String>('chat-add-friend-menu-item'),
          value: _ChatCreateAction.addFriend,
          // The item opens search, and search is where the path starts: find
          // the account, open its card, send the request. Naming only 「添加
          // 好友」 left a reader who landed on a search field with no idea
          // that this was the same errand.
          child: _ChatCreateMenuRow(
            icon: Icons.person_add_alt_1_outlined,
            label: '添加好友',
          ),
        ),
      ],
    );
  }

  Future<void> _myQr(BuildContext context, WidgetRef ref) async {
    await ref.read(profileControllerProvider.notifier).load();
    if (!context.mounted) return;
    final id = ref.read(profileControllerProvider).resource?.loopId;
    if (id == null) {
      LoopToast.show(context, message: '暂时无法读取个人二维码', kind: LoopToastKind.warn);
      return;
    }
    await showSocialQr(
      context,
      title: '我的二维码',
      payload: userQrPayload(id),
      caption: '$id · 扫码加好友',
    );
  }
}

class _ChatCreateMenuRow extends StatelessWidget {
  const _ChatCreateMenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: LoopColors.chat),
      const SizedBox(width: 12),
      Text(label),
    ],
  );
}
