import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_voice_room_page.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_link.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `voiceroom` (lobby) and `voiceroom-full` (session) share one controller and
/// one gate; the flag only chooses how much of the room is laid out.
class VoiceRoomScreen extends ConsumerStatefulWidget {
  const VoiceRoomScreen({
    required this.communityId,
    super.key,
    this.expanded = false,
    this.onBack,
    this.onOpenExpanded,
  });

  final String? communityId;

  /// True for `voiceroom-full`: the speaker list, the hand-raise queue and the
  /// host controls are laid out in one screen.
  final bool expanded;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenExpanded;

  @override
  ConsumerState<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends ConsumerState<VoiceRoomScreen> {
  /// The thread to the mounted media surface.
  ///
  /// 加入 is one command and so is 离开: this page takes the provider call
  /// down through the link before it releases the LOOP membership.
  final VoiceMediaLink _mediaLink = VoiceMediaLink();
  VoiceRoomPagePresence? _presence;
  var _entered = false;

  @override
  void initState() {
    super.initState();
    // While this page is on screen the shell's banner would only repeat it.
    // The count is raised after the frame that mounts the page: Riverpod
    // refuses a write from a life-cycle callback.
    final presence = ref.read(voiceRoomPagePresenceProvider.notifier);
    _presence = presence;
    scheduleMicrotask(() {
      if (!mounted) return;
      _entered = true;
      presence.enter();
    });
  }

  @override
  void dispose() {
    final presence = _presence;
    _presence = null;
    if (_entered && presence != null) {
      // Riverpod refuses a write from a life-cycle callback, so the count is
      // lowered after this frame. The notifier outlives the page.
      scheduleMicrotask(() {
        try {
          presence.exit();
        } catch (_) {
          // The container can be torn down before the page is; the banner
          // goes with it either way.
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.voiceRooms),
    );
    final mode = ref.watch(voiceRoomGatewayProvider).mode;
    final state = ref.watch(voiceRoomControllerProvider);
    final controller = ref.read(voiceRoomControllerProvider.notifier);
    final id = widget.communityId;

    // Decision 0005: while the provider role evidence is pending the whole
    // page stays closed, even though the capability itself reads `available`.
    // Decision 0068 adds the answer that opens it again: once the operator
    // records the `audio_room` role evidence the status reads `confirmed`,
    // and the page runs its ordinary five states against the pre-created
    // room and the member role it already required.
    final evidencePending =
        mode != CommunityGatewayMode.preview && capability.evidencePending;
    final blocked =
        communityCapabilityBlocks(mode, capability) || evidencePending;
    if (!blocked && id != null && state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(id));
      });
    }

    final snapshot = state.snapshot;
    // The roster is the session page's read alone: the lobby never asks for
    // it, and each view is asked for once — the controller holds the in-flight
    // guard, so a rebuild does not re-ask.
    if (widget.expanded && snapshot != null) {
      for (final view in VoiceRoomRosterView.values) {
        if (state.roster(view).phase == CommunityViewPhase.loading) {
          scheduleMicrotask(() {
            if (mounted) unawaited(controller.loadRoster(view));
          });
        }
      }
    }
    return LoopDashboardPage(
      key: ValueKey<String>(
        widget.expanded ? 'voiceroom-full-screen' : 'voiceroom-screen',
      ),
      archetype: LoopPageArchetype.listing,
      // The room resource names its own community (decision 0052), so the
      // title says which room this is instead of the word for all of them.
      title: snapshot == null ? '语音房' : '${snapshot.room.communityName} 语音房',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      actions: <Widget>[
        if (!widget.expanded && snapshot != null && id != null)
          LoopIconButton(
            key: const ValueKey<String>('voiceroom-open-full'),
            icon: 'expand',
            label: '展开',
            onPressed: () => widget.onOpenExpanded?.call(id),
          ),
      ],
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.listing,
        kicker: widget.expanded ? 'VOICE SESSION' : 'VOICE LOBBY',
        heading: snapshot == null
            ? '语音房'
            : snapshot.room.isLive
            ? '进行中'
            : '已结束',
        caption: snapshot == null
            ? '语音房状态暂时读不到，这里不显示人数。'
            : '进入前请确认主持人、发言人与录音说明。',
        stamp: snapshot == null
            ? null
            : (snapshot.room.isLive ? 'LIVE' : 'ENDED'),
      ),
      sections: <Widget>[
        CommunityPreviewNotice(mode: mode, resource: '语音房'),
        if (evidencePending)
          LoopEmpty(
            key: const ValueKey<String>('voiceroom-evidence-pending'),
            icon: 'shield',
            message: '语音房当前不可用',
            reason: communicationUnavailableReason(
              capability.evidenceReasonCode ??
                  'AUDIO_ROOM_USER_ROLE_EVIDENCE_PENDING',
            ),
          )
        else if (communityCapabilityBlocks(mode, capability))
          LoopEmpty(
            key: const ValueKey<String>('voiceroom-capability-unavailable'),
            icon: 'warn',
            message: '语音房当前不可用',
            reason: capability.reasonCode == null
                ? '尚未读取到能力清单，本页不请求任何语音房。'
                : communicationUnavailableReason(capability.reasonCode),
          )
        else if (id == null)
          const LoopEmpty(
            key: ValueKey<String>('voiceroom-missing-id'),
            icon: 'warn',
            message: '缺少社区标识',
            reason: '请从社区主页或社区官方群进入，本页不会猜测要打开哪个社区的语音房。',
          )
        else if (snapshot == null)
          CommunityStateBlock(
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '当前没有进行中的语音房',
            emptyReason: communicationUnavailableReason(
              state.notLiveReasonCode,
            ),
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          _RoomFacts(snapshot: snapshot),
          if (snapshot.viewer.hasJoined && snapshot.room.isJoinable)
            _MediaSection(
              roomId: snapshot.room.roomId,
              link: _mediaLink,
              // The hang-up inside the call view is the same single exit as
              // the page's own: dropping the audio alone would leave this
              // account a member of a room it can no longer hear. For a host
              // that exit is 结束房间 — the server has no 离开 for the host.
              onExitRequested: () => snapshot.viewer.isHost
                  ? _endRoom(controller)
                  : _leave(controller),
            ),
          if (widget.expanded) ...<Widget>[
            for (final view in VoiceRoomRosterView.values)
              _RosterSection(
                view: view,
                state: state,
                onRetry: () => unawaited(controller.loadRoster(view)),
                onLoadMore: () => unawaited(controller.loadMoreRoster(view)),
                onCommand: (member, command) =>
                    _runMemberCommand(controller, member, command),
              ),
            const LoopLabel('举手队列'),
            _HandRaiseQueue(state: state),
          ],
          if (snapshot.viewer.showsHostControls) ...<Widget>[
            const LoopLabel('主持人控制'),
            _HostControls(
              state: state,
              onMuteAll: () => _run(controller.muteAll, '已请求全体静音'),
              onEnd: () => _endRoom(controller),
              onInvite: (profileId) =>
                  _run(() => controller.inviteSpeaker(profileId), '已邀请发言'),
            ),
          ],
          _ViewerActions(
            state: state,
            // One command: the LOOP grant, and then the connection it
            // authorizes. The media section below mounts itself the moment
            // the membership exists and connects without a second tap.
            onJoin: () => _run(controller.join, '已加入，正在连接语音'),
            onLeave: () => _leave(controller),
            onRaise: () => _run(controller.raiseHand, '已举手，等待主持人邀请'),
            onCancel: () => _run(controller.cancelHandRaise, '已取消举手'),
          ),
          if (state.failureKind != null)
            LoopNotice(
              key: const ValueKey<String>('voiceroom-action-failure'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '上一次操作没有完成',
              body: communityFailureReason(state.failureKind),
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          if (snapshot.viewer.hasJoined && snapshot.room.isLive)
            LoopNotice(
              key: const ValueKey<String>('voiceroom-back-note'),
              icon: 'info',
              title: '返回不等于离开',
              body: snapshot.viewer.isHost
                  ? '返回只是把语音房收起：房间仍在进行，顶部会留一条提示，'
                        '点它随时回来。主持人没有「离开」，'
                        '真要结束请点这一页的「结束房间」。'
                  : '返回只是把语音房收起：你仍然在房间里，顶部会留一条提示，'
                        '点它随时回来。要真正离开，请点这一页的「离开」。',
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          const LoopNotice(
            key: ValueKey<String>('voiceroom-provider-note'),
            icon: 'info',
            title: '语音由 Stream 承载',
            body:
                '连接状态、发言权限与麦克风状态全部来自 Stream 的官方通话状态；'
                'LOOP 只负责房间记录、角色与举手队列。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// Leaving is a decision, not a gesture.
  ///
  /// The room page's back affordance only puts the room in the background —
  /// the account stays in it — so the one control that ends the membership
  /// asks first. Only a listener or a speaker reaches it: the host owns the
  /// room's life cycle and `DELETE /v2/voice-rooms/{id}/members/me` refuses
  /// the host outright, so the host's exit is 结束房间 instead.
  Future<void> _leave(VoiceRoomController controller) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: '离开语音房？',
      body: '离开后你会退出这次通话，举手也会一并取消；想继续收听需要重新加入。',
      confirmLabel: '离开',
      sheetKey: 'voiceroom-leave-sheet',
    );
    if (!confirmed || !mounted) return;
    // The provider call goes down first: leaving LOOP while the call is still
    // up would leave a connected room this account is no longer in.
    final disconnected = await _mediaLink.disconnect();
    if (!mounted) return;
    await _run(
      controller.leave,
      disconnected ? '已离开语音房' : '已离开语音房，语音连接的收尾没有确认',
    );
  }

  /// Runs one row command the server published, after naming the target.
  ///
  /// The sheet offers exactly the row's `commands`; nothing here derives a
  /// command from the viewer's role, and a row the server sent no command for
  /// never opens it.
  Future<void> _runMemberCommand(
    VoiceRoomController controller,
    VoiceRoomMember member,
    VoiceRoomMemberCommand command,
  ) async {
    final target = member.publicProfileId;
    if (target == null) return;
    final name = voiceRoomMemberName(member);
    final confirmed = await confirmCommunityAction(
      context,
      title: '${command.label}？',
      body: switch (command) {
        VoiceRoomMemberCommand.inviteSpeaker =>
          '目标：$name。邀请后对方成为发言人，可以在这次通话里说话。',
        VoiceRoomMemberCommand.removeSpeaker => '目标：$name。移出后对方回到听众，仍然留在房间里。',
        VoiceRoomMemberCommand.mute =>
          '目标：$name。静音是 LOOP 侧的意图，'
              '对方的设备仍可能自行开麦；没有取消静音的命令。',
      },
      confirmLabel: command.label,
      sheetKey: 'voiceroom-member-confirm-sheet',
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => controller.runMemberCommand(
        command: command,
        publicProfileId: target,
      ),
      switch (command) {
        VoiceRoomMemberCommand.inviteSpeaker => '已邀请发言',
        VoiceRoomMemberCommand.removeSpeaker => '已移出发言',
        VoiceRoomMemberCommand.mute => '已请求静音',
      },
    );
  }

  /// The host's only exit, and it ends the room for everybody.
  ///
  /// The confirmation says the whole consequence, because there is no smaller
  /// one to choose instead: the host cannot leave a room and keep it running.
  Future<void> _endRoom(VoiceRoomController controller) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: '结束语音房？',
      body:
          '结束后房间里的所有人都会立刻断开，这个房间不能再进入，举手队列也会作废。'
          '主持人没有「离开」：房间的存续由主持人决定。'
          '只是想暂时离开这一页，请用返回键，房间会收起在顶部，随时可以回来。'
          '社区可以再开一个新的。',
      confirmLabel: '结束房间',
      sheetKey: 'voiceroom-end-sheet',
    );
    if (!confirmed || !mounted) return;
    // Same order as 离开 (S32a): the provider call goes down first, so the
    // room is never ended under a call this device is still connected to.
    final disconnected = await _mediaLink.disconnect();
    if (!mounted) return;
    await _run(
      controller.endRoom,
      disconnected ? '房间已结束' : '房间已结束，语音连接的收尾没有确认',
    );
  }

  Future<void> _run(
    Future<CommunityFailureKind?> Function() command,
    String successMessage,
  ) async {
    final failure = await command();
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: successMessage);
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.warn,
    );
  }
}

class _RoomFacts extends StatelessWidget {
  const _RoomFacts({required this.snapshot});

  final VoiceRoomSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final observed = snapshot.participants.observed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('房间'),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            // Decision 0051 separates the three figures that were read as one
            // number: who is connected now, who is allowed in, and who LOOP
            // has joined. Each keeps its own sentence.
            LoopRecordRow(
              key: const ValueKey<String>('voiceroom-live'),
              // Two different numbers were both called 「在线」 on one screen:
              // this one, which the server observed at a past moment, and the
              // call view's own live 「N 人在通话」, which this device reads
              // from Stream right now. They disagree whenever the server's
              // observation is older than the connection — 「当前在线 0」 sat
              // directly above 「1 人在通话」. Each keeps the name of where it
              // came from instead of the word they were sharing.
              title: '服务端观测在线',
              subtitle: !observed.isAvailable
                  ? communicationUnavailableReason(
                      observed.unavailable!.reasonCode,
                    )
                  : observed.participantCount == null
                  ? '当前服务端没有给出这一项。'
                  : '服务端在这个时刻观察到的通话连接人数，'
                        '观察于 ${communityObservedAtLabel(observed.observedAt!)}',
              subtitleMaxLines: 2,
              trailing: observed.participantCount == null
                  ? communityMissingFigure
                  : '${observed.participantCount}',
              position: LoopRowPosition.first,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('voiceroom-observed'),
              title: '服务商已授权成员',
              subtitle: observed.isAvailable
                  ? '服务商允许进入的账号，不代表现在连着；'
                        '观察于 ${communityObservedAtLabel(observed.observedAt!)}'
                  : communicationUnavailableReason(
                      observed.unavailable!.reasonCode,
                    ),
              subtitleMaxLines: 2,
              trailing: observed.isAvailable
                  ? '${observed.memberCount}'
                  : communityMissingFigure,
              position: LoopRowPosition.middle,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('voiceroom-joined'),
              title: 'LOOP 已加入',
              subtitle: '在 LOOP 记录里已加入这个房间的人，含主持人。',
              trailing: snapshot.participants.joinedCount == null
                  ? communityMissingFigure
                  : '${snapshot.participants.joinedCount}',
              position: LoopRowPosition.middle,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('voiceroom-role-intent'),
              title: '发言人 / 听众',
              // Three facts on one line: a single line cut them at
              // 「也不是…」, which drops the whole disclaimer this row exists
              // for.
              subtitle: '按 LOOP 记录的角色统计，不含主持人，也不是在线人数。',
              subtitleMaxLines: 2,
              trailing:
                  '${snapshot.participants.speakerCount} / '
                  '${snapshot.participants.listenerCount}',
              position: LoopRowPosition.middle,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('voiceroom-role'),
              title: '我的角色',
              subtitle: snapshot.viewer.hasJoined
                  ? '由 LOOP 授予，不是通话里的发言权限'
                  : '尚未加入这个房间',
              trailing: snapshot.viewer.role?.label ?? '未加入',
              position: LoopRowPosition.last,
            ),
          ],
        ),
        if (!snapshot.providerSync.confirmed)
          LoopNotice(
            key: const ValueKey<String>('voiceroom-provider-unconfirmed'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '服务商侧未确认',
            body:
                'LOOP 已经提交这次变更，但服务商还没有确认结果'
                '（${snapshot.providerSync.reason ?? '原因未提供'}）。'
                '请稍后刷新查看最新状态。',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
      ],
    );
  }
}

/// The official foreground call surface.
///
/// It is mounted only after the LOOP join grant exists, and it receives only a
/// room ID: the call type stays fixed in Flutter and connection, participants,
/// capabilities and microphone state come from Stream's own `CallState`.
class _MediaSection extends StatelessWidget {
  const _MediaSection({
    required this.roomId,
    required this.link,
    required this.onExitRequested,
  });

  final String? roomId;
  final VoiceMediaLink link;
  final Future<void> Function() onExitRequested;

  @override
  Widget build(BuildContext context) {
    final id = roomId;
    final target = id == null
        ? null
        : AudioRoomTarget.tryParse(
            callType: AudioRoomTarget.callType,
            roomId: id,
          );
    if (target == null) {
      return const LoopEmpty(
        key: ValueKey<String>('voiceroom-media-unavailable'),
        icon: 'warn',
        message: '语音连接不可用',
        reason: '这个语音房暂时打不开，没有发起任何连接。',
      );
    }
    // The authorized room is handed straight to the reviewed lobby: no scoped
    // provider is involved, so the locator can never resolve to the
    // fail-closed production default by accident.
    //
    // It is mounted inline. Mounting the lobby as a page inside a fixed box
    // gave the screen a second scrolling region — the reader could scroll the
    // middle of the page and the page itself, with no way to tell which one
    // would move — and an app bar with a second back affordance inside a card.
    return KeyedSubtree(
      key: const ValueKey<String>('voiceroom-media'),
      child: StreamVoiceRoomPage(
        target: target,
        inline: true,
        // A member who was let in expects to hear the room. The connection is
        // part of 加入, not a second decision, so it starts on its own — still
        // muted, still without asking for the microphone permission.
        autoConnect: true,
        link: link,
        onExitRequested: onExitRequested,
      ),
    );
  }
}

/// What one roster row is called, under the server's display rule.
///
/// A member with anonymous mode on is the server's anonymous label to every
/// other reader, and its own alias to itself; this client never assembles a
/// name from an identifier.
String voiceRoomMemberName(VoiceRoomMember member) => switch (member.name) {
  VoiceRoomMemberAlias(alias: final alias) =>
    member.isSelf ? '我 · $alias' : alias,
  VoiceRoomMemberAnonymousName(labelKey: final key) => voiceRoomDisplayKeyText(
    key,
  ),
};

/// One roster view: 发言人 or 听众.
///
/// The count in the heading is the room's own role figure; the rows are the
/// roster page. The two are read separately, so a heading with a figure above
/// a list that could not be read is the honest picture, not a contradiction.
class _RosterSection extends StatelessWidget {
  const _RosterSection({
    required this.view,
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
    required this.onCommand,
  });

  final VoiceRoomRosterView view;
  final VoiceRoomPageState state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final Future<void> Function(
    VoiceRoomMember member,
    VoiceRoomMemberCommand command,
  )
  onCommand;

  @override
  Widget build(BuildContext context) {
    final roster = state.roster(view);
    final participants = state.snapshot!.participants;
    final count = view == VoiceRoomRosterView.speaker
        ? participants.speakerCount
        : participants.listenerCount;
    final slug = view.wireName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopLabel('${view.label} $count'),
        switch (roster.phase) {
          CommunityViewPhase.loading => LoopSkeleton(
            key: ValueKey<String>('voiceroom-roster-$slug-loading'),
            type: LoopSkeletonType.list,
            rows: 2,
          ),
          // An empty roster that was read is a fact about the room; it is not
          // the same sentence as a roster that could not be read.
          CommunityViewPhase.empty => LoopEmpty(
            key: ValueKey<String>('voiceroom-roster-$slug-empty'),
            message: '当前没有${view.label}',
            reason: view == VoiceRoomRosterView.speaker
                ? 'LOOP 记录里这个房间还没有发言人。主持人不在这份名单里。'
                : 'LOOP 记录里这个房间还没有听众。主持人不在这份名单里。',
          ),
          CommunityViewPhase.offline => LoopOfflineState(
            key: ValueKey<String>('voiceroom-roster-$slug-offline'),
            pausedActions: const <String>['邀请上麦', '移出发言', '静音'],
            onRetry: onRetry,
          ),
          CommunityViewPhase.permission => LoopPermissionState(
            key: ValueKey<String>('voiceroom-roster-$slug-permission'),
            icon: 'shield',
            title: '没有权限查看${view.label}名单',
            purpose: communityFailureReason(roster.failureKind),
          ),
          CommunityViewPhase.unavailable => LoopEmpty(
            key: ValueKey<String>('voiceroom-roster-$slug-unavailable'),
            icon: 'warn',
            message: '${view.label}名单当前不可用',
            reason: communityFailureReason(roster.failureKind),
          ),
          CommunityViewPhase.error => LoopErrorState(
            key: ValueKey<String>('voiceroom-roster-$slug-error'),
            title: '${view.label}名单读不到',
            reason: communityFailureReason(roster.failureKind),
            onRetry: onRetry,
          ),
          CommunityViewPhase.ready => _rows(context, roster),
        },
        if (roster.isReady && roster.nextCursor != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LoopButton(
              key: ValueKey<String>('voiceroom-roster-$slug-load-more'),
              label: roster.loadingMore ? '正在载入…' : '载入更多',
              block: true,
              onPressed: roster.loadingMore ? null : onLoadMore,
            ),
          )
        else if (roster.isReady)
          LoopProvenanceFooter(
            key: ValueKey<String>('voiceroom-roster-$slug-end'),
            text: '没有更多${view.label}',
          ),
      ],
    );
  }

  Widget _rows(BuildContext context, VoiceRoomRosterState roster) {
    final slug = view.wireName;
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        for (var index = 0; index < roster.items.length; index += 1)
          _row(
            context,
            roster.items[index],
            key: ValueKey<String>(
              'voiceroom-member-$slug-'
              '${roster.items[index].publicProfileId ?? index}',
            ),
            position: index == 0
                ? (roster.items.length == 1
                      ? LoopRowPosition.single
                      : LoopRowPosition.first)
                : index == roster.items.length - 1
                ? LoopRowPosition.last
                : LoopRowPosition.middle,
          ),
      ],
    );
  }

  LoopRecordRow _row(
    BuildContext context,
    VoiceRoomMember member, {
    required Key key,
    required LoopRowPosition position,
  }) {
    final speaking = view == VoiceRoomRosterView.speaker;
    // 发言人 carries the mute mark, 听众 the raised hand: each view shows the
    // state that means something in it.
    final badge = speaking
        ? (member.muted
              ? const LoopBadge('已静音', kind: LoopBadgeKind.mute)
              : null)
        : (member.handRaised
              ? const LoopBadge('已举手', kind: LoopBadgeKind.mining)
              : null);
    return LoopRecordRow(
      key: key,
      title: voiceRoomMemberName(member),
      subtitle: speaking
          ? (member.muted ? '主持人已在 LOOP 侧静音，麦克风状态以 Stream 为准' : '可以在这次通话里发言')
          : (member.handRaised ? '等待主持人邀请发言' : '只收听，未申请发言'),
      subtitleMaxLines: 2,
      trailingBadge: badge,
      position: position,
      // Exactly the server's commands for this row: a row with none is not
      // tappable, which is what a non-host viewer sees on every row.
      onTap: member.commands.isEmpty || state.busy
          ? null
          : () => unawaited(_openCommands(context, member)),
    );
  }

  Future<void> _openCommands(
    BuildContext context,
    VoiceRoomMember member,
  ) async {
    final chosen = await showLoopSheet<VoiceRoomMemberCommand>(
      context,
      barrierLabel: '关闭成员操作弹层',
      builder: (sheetContext) => Padding(
        key: const ValueKey<String>('voiceroom-member-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              voiceRoomMemberName(member),
              style: LoopTypography.heading(18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '主持人可以执行的操作由服务端逐行下发，这里只列出这一行真正可用的。',
              style: LoopTypography.body(13, color: LoopColors.muted),
            ),
            const SizedBox(height: 18),
            for (final command in member.commands)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LoopButton(
                  key: ValueKey<String>(
                    'voiceroom-member-command-${command.wireName}',
                  ),
                  label: command.label,
                  block: true,
                  onPressed: () => Navigator.of(sheetContext).pop(command),
                ),
              ),
            LoopButton(
              key: const ValueKey<String>('voiceroom-member-command-cancel'),
              label: '取消',
              block: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await onCommand(member, chosen);
  }
}

class _HandRaiseQueue extends StatelessWidget {
  const _HandRaiseQueue({required this.state});

  final VoiceRoomPageState state;

  @override
  Widget build(BuildContext context) {
    final viewer = state.snapshot!.viewer;
    // The queue resource is a host read. A listener or a speaker is told what
    // it can actually see — its own position — instead of an empty list that
    // reads as "nobody has raised a hand".
    if (!viewer.isHost) {
      final own = viewer.handRaise;
      if (own == null || !own.isPending) {
        return const LoopEmpty(
          key: ValueKey<String>('voiceroom-queue-self-only'),
          message: '你还没有举手',
          reason: '完整的举手队列只有主持人能看到。举手之后，这里会显示你的位置。',
        );
      }
      return LoopRecordGroup(
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('voiceroom-queue-self'),
            title: '我',
            subtitle: '等待主持人邀请',
            trailing: '第 ${own.sequence} 位',
            position: LoopRowPosition.single,
          ),
        ],
      );
    }
    final entries = state.handRaises;
    if (entries.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('voiceroom-queue-empty'),
        message: '举手队列为空',
        reason: '没有成员在排队。有人举手后会按顺序列在这里。',
      );
    }
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        for (var index = 0; index < entries.length; index += 1)
          LoopRecordRow(
            key: ValueKey<String>(
              'voiceroom-queue-${entries[index].handRaise.handRaiseId}',
            ),
            title: entries[index].profile.displayName,
            subtitle: '第 ${entries[index].handRaise.sequence} 位',
            trailingBadge: LoopBadge(
              entries[index].handRaise.isPending ? '等待邀请' : '已邀请',
              kind: entries[index].handRaise.isPending
                  ? LoopBadgeKind.mute
                  : LoopBadgeKind.up,
            ),
            position: index == 0
                ? LoopRowPosition.first
                : index == entries.length - 1
                ? LoopRowPosition.last
                : LoopRowPosition.middle,
          ),
      ],
    );
  }
}

class _HostControls extends StatelessWidget {
  const _HostControls({
    required this.state,
    required this.onMuteAll,
    required this.onEnd,
    required this.onInvite,
  });

  final VoiceRoomPageState state;
  final Future<void> Function() onMuteAll;
  final Future<void> Function() onEnd;
  final Future<void> Function(String publicProfileId) onInvite;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot!;
    final busy = state.busy || !snapshot.room.isLive;
    final pending = <VoiceRoomHandRaiseEntry>[
      for (final entry in state.handRaises)
        if (entry.handRaise.isPending && entry.profile.publicProfileId != null)
          entry,
    ];
    return Column(
      key: const ValueKey<String>('voiceroom-host-controls'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (snapshot.viewer.canInviteSpeakers && pending.isEmpty)
          const LoopEmpty(
            key: ValueKey<String>('voiceroom-invite-empty'),
            message: '没有待邀请的举手',
            reason: '有人举手后会按顺序列在这里。',
          )
        else if (pending.isNotEmpty)
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (var index = 0; index < pending.length; index += 1)
                LoopRecordRow(
                  key: ValueKey<String>(
                    'voiceroom-invite-'
                    '${pending[index].profile.publicProfileId}',
                  ),
                  title: pending[index].profile.displayName,
                  subtitle: '邀请其发言',
                  position: index == 0
                      ? LoopRowPosition.first
                      : index == pending.length - 1
                      ? LoopRowPosition.last
                      : LoopRowPosition.middle,
                  onTap: busy
                      ? null
                      : () => unawaited(
                          onInvite(pending[index].profile.publicProfileId!),
                        ),
                ),
            ],
          ),
        // 移出发言 and 静音 live on the speaker rows above, where the server
        // publishes them per member. A hand raise is a *request* to speak,
        // never proof that the account is speaking, so this block never
        // offered a removal against the queue and no longer has to say so.
        LoopButtonPair(
          children: <Widget>[
            if (snapshot.viewer.canMuteAll)
              LoopButton(
                key: const ValueKey<String>('voiceroom-mute-all'),
                label: '全体静音',
                icon: 'voice-off',
                onPressed: busy ? null : () => unawaited(onMuteAll()),
              ),
            if (snapshot.viewer.canEndRoom)
              LoopButton(
                key: const ValueKey<String>('voiceroom-end'),
                label: '结束房间',
                icon: 'warn',
                onPressed: busy ? null : () => unawaited(onEnd()),
              ),
          ],
        ),
      ],
    );
  }
}

class _ViewerActions extends StatelessWidget {
  const _ViewerActions({
    required this.state,
    required this.onJoin,
    required this.onLeave,
    required this.onRaise,
    required this.onCancel,
  });

  final VoiceRoomPageState state;
  final Future<void> Function() onJoin;
  final Future<void> Function() onLeave;
  final Future<void> Function() onRaise;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot!;
    final viewer = snapshot.viewer;
    final live = snapshot.room.isLive;
    final busy = state.busy || !live;
    if (!live) {
      return const LoopEmpty(
        key: ValueKey<String>('voiceroom-ended'),
        message: '这个语音房已经结束',
        reason: '房间结束后所有操作都会失效。',
      );
    }
    if (!viewer.hasJoined) {
      // A room whose provider call is not confirmed cannot be joined. The
      // refusal is stated: a disabled button with no sentence beside it is
      // read as a tap that did nothing.
      if (!snapshot.room.isJoinable) {
        return const LoopEmpty(
          key: ValueKey<String>('voiceroom-not-joinable'),
          icon: 'warn',
          message: '这个房间还不能加入',
          reason: '服务商还没有确认这个房间已经就绪，加入会被拒绝。请稍后刷新再试。',
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: LoopButton(
          key: const ValueKey<String>('voiceroom-join'),
          label: state.busy ? '正在加入…' : '加入语音房',
          block: true,
          primary: true,
          icon: 'voice',
          onPressed: busy ? null : () => unawaited(onJoin()),
        ),
      );
    }
    if (viewer.isHost) {
      // `DELETE /v2/voice-rooms/{id}/members/me` refuses the host: the room's
      // life cycle belongs to whoever opened it, so the only exit the server
      // accepts is 结束房间. A 离开 button here was a command that could only
      // ever come back as "没有权限".
      return LoopEmpty(
        key: const ValueKey<String>('voiceroom-host-no-leave'),
        icon: 'info',
        message: '主持人不能离开房间',
        reason: viewer.canEndRoom
            ? '房间的存续由主持人决定，所以没有「离开」：'
                  '要退出请用上面的「结束房间」，房间里的所有人都会断开。'
                  '只是想暂时离开这一页，用返回键即可，房间会收起在顶部。'
            : '房间的存续由主持人决定，所以没有「离开」；'
                  '「结束房间」当前也读不到，暂时无法结束这个房间。'
                  '用返回键可以先把房间收起在顶部。',
      );
    }
    final raised = viewer.handRaise?.isPending ?? false;
    // Prototype `voiceroom` / `voiceroom-full`: a listener raises a hand, a
    // speaker does not. Raising a hand is a request for a role the account
    // already holds, so it is not offered to a speaker or to the host.
    final canRaise = viewer.role == VoiceRoomRole.listener;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!canRaise)
          // `DELETE /v2/voice-rooms/{id}/speakers/{profile}` refuses the
          // caller's own account, so LOOP has no self-demotion command to
          // offer. The fact is stated instead of a button that would fail.
          const LoopEmpty(
            key: ValueKey<String>('voiceroom-step-down-unavailable'),
            icon: 'warn',
            message: '自助下麦当前不可用',
            reason: '后端只允许主持人调整发言人。要退出发言，请联系主持人，或离开房间。',
          ),
        LoopButtonPair(
          children: <Widget>[
            if (canRaise)
              LoopButton(
                key: ValueKey<String>(
                  raised ? 'voiceroom-cancel-hand' : 'voiceroom-raise-hand',
                ),
                label: raised ? '取消举手' : '举手',
                icon: 'hand',
                onPressed: busy
                    ? null
                    : () => unawaited(raised ? onCancel() : onRaise()),
              ),
            LoopButton(
              key: const ValueKey<String>('voiceroom-leave'),
              label: '离开',
              onPressed: busy ? null : () => unawaited(onLeave()),
            ),
          ],
        ),
      ],
    );
  }
}

/// The shell strip that says the account is still in a voice room.
///
/// Going back from the room page only puts the room behind what the reader
/// does next: the LOOP membership, and the provider call with it, end on the
/// 离开 command and nowhere else. Without a standing marker the reader has no
/// way to tell the two apart, and no way back short of walking the community
/// again. It is hidden on the room page itself, which already shows all of
/// this.
class VoiceRoomMinimizedBanner extends ConsumerWidget {
  const VoiceRoomMinimizedBanner({required this.onOpen, super.key});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(voiceRoomSessionProvider);
    final onRoomPage = ref.watch(voiceRoomPagePresenceProvider) > 0;
    if (session == null || onRoomPage) {
      return const SizedBox.shrink();
    }
    final count = session.participantCount;
    return Material(
      key: const ValueKey<String>('voiceroom-minimized-banner'),
      color: LoopColors.lime,
      child: InkWell(
        onTap: () => onOpen(session.communityId),
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LoopSpacing.page,
                vertical: 10,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      // The same server observation the room page shows, so
                      // it carries the same name: it is not what this device
                      // is connected to right now.
                      count == null
                          ? '正在语音房 · ${session.communityName}'
                          : '正在语音房 · ${session.communityName} · '
                                '服务端观测 $count 人',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopTypography.withWeight(
                        LoopTypography.body(13, color: LoopColors.ink),
                        FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: LoopSpacing.tight),
                  Text(
                    '返回房间',
                    style: LoopTypography.body(12, color: LoopColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
