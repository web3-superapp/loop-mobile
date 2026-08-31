import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

enum _ChatCreateAction { createGroup, addFriend }

/// WeChat-style creation menu shared by Preview and production Chat headers.
class ChatCreateMenuButton extends StatelessWidget {
  const ChatCreateMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
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
          case _ChatCreateAction.addFriend:
            context.push('/chat/friends/add');
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<_ChatCreateAction>>[
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
          key: ValueKey<String>('chat-add-friend-menu-item'),
          value: _ChatCreateAction.addFriend,
          child: _ChatCreateMenuRow(
            icon: Icons.person_add_alt_1_outlined,
            label: '添加好友',
          ),
        ),
      ],
    );
  }
}

class _ChatCreateMenuRow extends StatelessWidget {
  const _ChatCreateMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: LoopColors.chat),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
