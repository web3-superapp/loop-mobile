import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// Opens a room for this community. The button exists only for a viewer the
/// server reports as owner or admin, but the admission is still the
/// server's: this states what came back and never claims a room that was
/// not confirmed.
Future<void> openCommunityVoiceRoom(
  BuildContext context,
  WidgetRef ref,
  CommunityDetail detail, {
  ValueChanged<String>? onOpened,
}) async {
  final confirmed = await confirmCommunityAction(
    context,
    title: '开启语音房？',
    body:
        '房间会立刻对社区成员可见，任何成员都能进来收听。你是主持人，'
        '邀请发言、全体静音和结束房间都由你或其他管理员操作；麦克风默认关闭。',
    confirmLabel: '开启',
    sheetKey: 'community-open-voice-room-sheet',
  );
  if (!confirmed || !context.mounted) return;
  final outcome = await ref
      .read(voiceRoomOpenControllerProvider.notifier)
      .openRoom(detail.community.communityId);
  if (!context.mounted) return;
  final failure = outcome.failure;
  if (failure == null) {
    if (outcome.isOpen) {
      LoopToast.show(context, message: '语音房已开启');
      unawaited(ref.read(communityProfileControllerProvider.notifier).reload());
      onOpened?.call(detail.community.communityId);
      return;
    }
    // The room row exists and the call behind it does not, so nobody can be
    // let in — including the host who just opened it. This is the state the
    // review device met as a room it entered and could not hear. The page
    // stays where it is and 「开启语音房」 stays on it: the next tap repeats
    // the provider half of the same command, which is the one recovery
    // there is. Asking for a second room would be refused — the room that
    // cannot be entered is still the community's one live room.
    LoopToast.show(
      context,
      message: voiceRoomOpenUnfinishedText(outcome.unconfirmedReason),
      kind: LoopToastKind.warn,
    );
    return;
  }
  LoopToast.show(
    context,
    message: failure == CommunityFailureKind.resourceConflict
        // The shared copy for this code is about a taken slug; here the
        // conflict is a room that is already live.
        ? '这个社区已经有进行中的语音房，没有重复创建。请刷新后进入。'
        : communityFailureReason(failure),
    kind: LoopToastKind.err,
  );
  if (failure == CommunityFailureKind.resourceConflict) {
    unawaited(ref.read(communityProfileControllerProvider.notifier).reload());
  }
}
