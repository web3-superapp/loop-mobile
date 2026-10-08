import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_models.dart';
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
  // S110 (decision 0115): the start sheet asks for an optional title and runs
  // the open command itself; null means the host cancelled.
  final outcome = await showVoiceRoomStartSheet(
    context,
    detail.community.communityId,
  );
  if (outcome == null || !context.mounted) return;
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
