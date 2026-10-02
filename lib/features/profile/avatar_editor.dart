import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_upload.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// One avatar and one optional action, shared by setup and profile editing.
class LoopAvatarEditor extends ConsumerWidget {
  const LoopAvatarEditor({
    required this.avatar,
    this.enabled = true,
    this.keyPrefix = 'profile-avatar',
    super.key,
  });
  final Widget avatar;
  final bool enabled;
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(avatarUploadControllerProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: <Widget>[
          Semantics(
            button: true,
            label: '更换头像',
            enabled: enabled && !state.picking,
            child: InkWell(
              key: ValueKey<String>('$keyPrefix-pick'),
              borderRadius: BorderRadius.circular(48),
              onTap: enabled && !state.picking
                  ? () => unawaited(
                      ref.read(avatarUploadControllerProvider.notifier).pick(),
                    )
                  : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: avatar,
              ),
            ),
          ),
          const SizedBox(height: 8),
          LoopButton(
            key: ValueKey<String>('$keyPrefix-upload'),
            label: state.picking ? '正在选择…' : '上传头像',
            onPressed: enabled && !state.picking
                ? () => unawaited(
                    ref.read(avatarUploadControllerProvider.notifier).pick(),
                  )
                : null,
          ),
          if (state.message case final message?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
                key: ValueKey<String>('$keyPrefix-message'),
                textAlign: TextAlign.center,
                style: LoopTypography.caption(11, color: LoopColors.text2),
              ),
            ),
        ],
      ),
    );
  }
}
