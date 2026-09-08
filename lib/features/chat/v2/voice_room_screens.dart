import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_voice_room_page.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
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
    return LoopDashboardPage(
      key: ValueKey<String>(
        widget.expanded ? 'voiceroom-full-screen' : 'voiceroom-screen',
      ),
      archetype: LoopPageArchetype.listing,
      title: '语音房',
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
            ? '语音房状态尚未读取成功，本页不展示任何推测人数。'
            : '进入前确认主持人、发言人与录音说明。在线人数只来自服务端观测。',
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
            _MediaSection(roomId: snapshot.room.roomId),
          if (widget.expanded) ...<Widget>[
            const LoopLabel('举手队列'),
            _HandRaiseQueue(state: state),
          ],
          if (snapshot.viewer.showsHostControls) ...<Widget>[
            const LoopLabel('主持人控制'),
            _HostControls(
              state: state,
              onMuteAll: () => _run(controller.muteAll, '已请求全体静音'),
              onEnd: () => _run(controller.endRoom, '房间已结束'),
              onInvite: (profileId) =>
                  _run(() => controller.inviteSpeaker(profileId), '已邀请发言'),
              onRemove: (profileId) =>
                  _run(() => controller.removeSpeaker(profileId), '已移出发言'),
            ),
          ],
          _ViewerActions(
            state: state,
            onJoin: () => _run(controller.join, '已加入语音房'),
            onLeave: () => _run(controller.leave, '已离开语音房'),
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
            LoopRecordRow(
              key: const ValueKey<String>('voiceroom-role'),
              title: '我的角色',
              subtitle: snapshot.viewer.hasJoined
                  ? '由服务端授予，不代表 Stream 的通话角色'
                  : '尚未加入这个房间',
              trailing: snapshot.viewer.role?.label ?? communityMissingFigure,
              position: LoopRowPosition.first,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('voiceroom-role-intent'),
              title: '发言人 / 听众（LOOP 角色意图）',
              subtitle: '这是 LOOP 的角色记录，不是 Stream 的在线人数。',
              trailing:
                  '${snapshot.participants.speakerCount} / '
                  '${snapshot.participants.listenerCount}',
              position: LoopRowPosition.middle,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('voiceroom-observed'),
              title: '服务端观测在线人数',
              subtitle: observed.isAvailable
                  ? '观察于 ${communityObservedAtLabel(observed.observedAt!)}'
                  : communicationUnavailableReason(
                      observed.unavailable!.reasonCode,
                    ),
              trailing: observed.isAvailable
                  ? '${observed.memberCount}'
                  : communityMissingFigure,
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
  const _MediaSection({required this.roomId});

  final String? roomId;

  @override
  Widget build(BuildContext context) {
    final id = roomId;
    if (id == null) {
      return const LoopEmpty(
        key: ValueKey<String>('voiceroom-media-unavailable'),
        icon: 'warn',
        message: '语音连接不可用',
        reason: '服务端返回的通话地址不符合约定，本页没有发起任何连接。',
      );
    }
    return SizedBox(
      key: const ValueKey<String>('voiceroom-media'),
      height: 420,
      child: ProviderScope(
        overrides: [
          audioRoomTargetSourceProvider.overrideWithValue(
            _JoinedAudioRoomTargetSource(id),
          ),
        ],
        child: const StreamVoiceRoomPage(),
      ),
    );
  }
}

/// Hands the reviewed lobby exactly one authorized room ID.
final class _JoinedAudioRoomTargetSource implements AudioRoomTargetSource {
  const _JoinedAudioRoomTargetSource(this._roomId);

  final String _roomId;

  @override
  Future<AudioRoomTarget?> loadTarget() async => AudioRoomTarget.tryParse(
    callType: AudioRoomTarget.callType,
    roomId: _roomId,
  );
}

class _HandRaiseQueue extends StatelessWidget {
  const _HandRaiseQueue({required this.state});

  final VoiceRoomPageState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.handRaises;
    if (entries.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('voiceroom-queue-empty'),
        message: '举手队列为空',
        reason: '完整的队列只对主持人可见；没有排队的成员时这里不显示任何人。',
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
    required this.onRemove,
  });

  final VoiceRoomPageState state;
  final Future<void> Function() onMuteAll;
  final Future<void> Function() onEnd;
  final Future<void> Function(String publicProfileId) onInvite;
  final Future<void> Function(String publicProfileId) onRemove;

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
        if (pending.isNotEmpty)
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
        if (snapshot.viewer.canInviteSpeakers && pending.isEmpty)
          const LoopEmpty(
            key: ValueKey<String>('voiceroom-invite-empty'),
            message: '没有待邀请的举手',
            reason: '有人举手后，这里会按服务端分配的顺序号列出。',
          ),
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
        if (snapshot.viewer.canInviteSpeakers && pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('voiceroom-remove-speaker'),
              label: '移出第一位发言人',
              block: true,
              onPressed: busy
                  ? null
                  : () => unawaited(
                      onRemove(pending.first.profile.publicProfileId!),
                    ),
            ),
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
        reason: '房间结束后所有操作都会被服务端拒绝。',
      );
    }
    if (!viewer.hasJoined) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: LoopButton(
          key: const ValueKey<String>('voiceroom-join'),
          label: snapshot.room.isJoinable ? '加入语音房' : '房间尚未就绪',
          block: true,
          primary: true,
          icon: 'voice',
          onPressed: busy || !snapshot.room.isJoinable
              ? null
              : () => unawaited(onJoin()),
        ),
      );
    }
    final raised = viewer.handRaise?.isPending ?? false;
    return LoopButtonPair(
      children: <Widget>[
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
    );
  }
}
