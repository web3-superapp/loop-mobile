import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/square/live_voice_rooms.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `square` · 广场 (decision 0110, S106 §3).
///
/// Two page segments: every community in the directory, and every voice
/// room live on the platform right now. The segment survives leaving the
/// tab and coming back.
class SquareScreen extends StatelessWidget {
  const SquareScreen({
    required this.onOpenCommunity,
    required this.onOpenVoiceRoom,
    super.key,
  });

  /// Opens one community's record.
  final ValueChanged<String> onOpenCommunity;

  /// Opens the live room of one community (`/chat/voice?id=`).
  final ValueChanged<String> onOpenVoiceRoom;

  static const segments = <String>['社区', '语音房'];

  @override
  Widget build(BuildContext context) {
    return LoopSegmentedTabPage(
      key: const ValueKey<String>('square-screen'),
      tabKey: 'square',
      title: '广场',
      segments: segments,
      // The segment bodies are embedded pages with no bar of their own, so
      // their 更新中 is drawn on the segment row (S106b).
      updating: (ref, index) => index == 0
          ? ref.watch(
              communityDiscoverControllerProvider.select(
                (state) => state.refreshing,
              ),
            )
          : ref.watch(
              liveVoiceRoomsControllerProvider.select(
                (state) => state.refreshing,
              ),
            ),
      builder: (context, index) => index == 0
          ? CommunityDiscoverScreen(
              embedded: true,
              onOpenCommunity: onOpenCommunity,
            )
          : LiveVoiceRoomList(
              onOpenCommunity: onOpenCommunity,
              onOpenVoiceRoom: onOpenVoiceRoom,
            ),
    );
  }
}

/// The 语音房 segment: `GET /v2/voice-rooms/live`, newest room first.
class LiveVoiceRoomList extends ConsumerStatefulWidget {
  const LiveVoiceRoomList({
    required this.onOpenCommunity,
    required this.onOpenVoiceRoom,
    super.key,
    this.now,
  });

  final ValueChanged<String> onOpenCommunity;
  final ValueChanged<String> onOpenVoiceRoom;

  /// The clock the 开播时长 is measured against. Tests pin it.
  final DateTime Function()? now;

  @override
  ConsumerState<LiveVoiceRoomList> createState() => _LiveVoiceRoomListState();
}

class _LiveVoiceRoomListState extends ConsumerState<LiveVoiceRoomList> {
  void _open(LiveVoiceRoom room) {
    if (room.joinable) {
      widget.onOpenVoiceRoom(room.communityId);
      return;
    }
    // A room belongs to its community: a reader who is not a member is taken
    // to the community, where joining is, and told why.
    widget.onOpenCommunity(room.communityId);
    LoopToast.show(
      context,
      message: '加入「${room.communityName}」后才能进入语音房',
      kind: LoopToastKind.warn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveVoiceRoomsControllerProvider);
    final controller = ref.read(liveVoiceRoomsControllerProvider.notifier);
    if (state.phase == CommunityViewPhase.loading && !state.refreshing) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final now = (widget.now ?? DateTime.now)().toUtc();
    // The room this account is in, so its row says so (decision 0111).
    final session = ref.watch(voiceRoomSessionProvider);
    return LoopStreamPage(
      key: const ValueKey<String>('square-voice-rooms'),
      archetype: LoopPageArchetype.listing,
      title: '语音房',
      embedded: true,
      tabPage: true,
      updating: state.refreshing,
      onRefresh: controller.refresh,
      collection: ListView(
        key: const ValueKey<String>('square-voice-room-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          CommunityPreviewNotice(mode: state.mode, resource: '语音房列表'),
          // A refresh that failed over rows already shown keeps them and
          // says so here; its retry is the refresh, not a next page.
          LoopFreshnessStrip(
            key: const ValueKey<String>('square-voice-room-freshness'),
            refreshing: state.refreshing,
            refreshFailed: state.refreshFailed,
            readAt: state.observedAt,
            onRetry: () => unawaited(controller.refresh()),
          ),
          if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              key: const ValueKey<String>('square-voice-room-state'),
              phase: state.phase,
              failureKind: state.failureKind,
              skeleton: LoopSkeletonType.record,
              rows: 4,
              emptyMessage: '现在没有正在直播的语音房',
              emptyReason: '有社区开播时会出现在这里。',
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            LoopRecordGroup(
              key: const ValueKey<String>('square-voice-room-group'),
              rows: <LoopRecordRow>[
                for (var index = 0; index < state.items.length; index += 1)
                  _row(
                    state.items[index],
                    now,
                    communityRowPosition(index, state.items.length),
                    inRoom:
                        session?.voiceRoomId == state.items[index].voiceRoomId,
                  ),
              ],
            ),
            if (state.appendFailed && !state.loadingMore)
              // A failed next page keeps the rows and waits for the reader.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LoopButton(
                  key: const ValueKey<String>('square-voice-room-retry-more'),
                  label: '重试',
                  block: true,
                  onPressed: () => unawaited(controller.loadMore()),
                ),
              )
            else if (state.nextCursor case final String cursor) ...<Widget>[
              // The sentinel stays mounted while its page loads: replaced by
              // the skeleton, it forgot which cursor it had asked for and a
              // page answering with the same cursor was asked again.
              LoopLoadMoreSentinel(
                key: const ValueKey<String>('square-voice-room-load-more'),
                cursor: cursor,
                onLoadMore: () => unawaited(controller.loadMore()),
              ),
              if (state.loadingMore)
                const Padding(
                  key: ValueKey<String>('square-voice-room-loading-more'),
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: LoopSkeleton(type: LoopSkeletonType.record, rows: 1),
                ),
            ] else
              const LoopProvenanceFooter(
                key: ValueKey<String>('square-voice-room-end'),
                text: '没有更多语音房',
              ),
            if (state.observedAt case final DateTime observedAt)
              LoopProvenanceFooter(
                key: const ValueKey<String>('square-voice-room-observed'),
                text: '读取于 ${loopLocalClockLabel(observedAt)}',
              ),
          ],
        ],
      ),
    );
  }

  LoopRecordRow _row(
    LiveVoiceRoom room,
    DateTime now,
    LoopRowPosition position, {
    required bool inRoom,
  }) {
    final host =
        room.host.displayName ??
        voiceRoomDisplayKeyText('voiceRoom.member.anonymousMember');
    // LOOP's own 已加入 count, host excluded — not who is online right now.
    final listeners = '${room.listenerCount + room.speakerCount} 人已加入';
    final elapsed = liveVoiceRoomElapsedLabel(room.startedAt, now);
    final title = room.title ?? room.communityName;
    final subtitle = room.title == null
        ? '主持 $host · $listeners · $elapsed'
        : '${room.communityName} · 主持 $host · $listeners · $elapsed';
    return LoopRecordRow(
      key: ValueKey<String>('square-voice-room-${room.voiceRoomId}'),
      leading: CommunityLogo(
        identity: room.communityId,
        name: room.communityName,
        logoRef: room.communityLogoRef,
      ),
      title: title,
      subtitle: subtitle,
      subtitleMaxLines: 2,
      trailingBadge: inRoom
          ? const LoopBadge(
              '已在房间',
              key: ValueKey<String>('square-voice-room-in-room'),
              kind: LoopBadgeKind.up,
            )
          : room.joinable
          ? const LoopBadge('直播中', kind: LoopBadgeKind.up)
          : const LoopBadge('需加入'),
      position: position,
      onTap: () => _open(room),
      semanticLabel:
          '$title，主持 $host，$listeners，$elapsed'
          '${inRoom ? '，你已在房间里' : ''}'
          '${room.joinable ? '' : '，加入社区后可进入'}',
    );
  }
}
