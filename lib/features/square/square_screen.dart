import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_share.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/square/live_voice_rooms.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `square` · 广场 (decision 0110, S106 §3; the 社区 segment is the club
/// list of decision 0116).
///
/// Two page segments: every community in the directory, and every voice
/// room live on the platform right now. The segment survives leaving the
/// tab and coming back.
class SquareScreen extends StatelessWidget {
  const SquareScreen({
    required this.onOpenCommunity,
    required this.onOpenVoiceRoom,
    super.key,
    this.onOpenSearch,
  });

  /// Opens `/search` from the 社区 segment's entry. Null pushes the route.
  final VoidCallback? onOpenSearch;

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
          ? SquareCommunityList(
              onOpenCommunity: onOpenCommunity,
              onOpenSearch: onOpenSearch,
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
              empty: LoopEmptyState(
                key: const ValueKey<String>('square-voice-room-empty'),
                illustration: LoopIllustration.voiceRoom,
                title: '还没有人开播',
                message: '社区开播时会出现在这里',
                action: LoopButton(
                  key: const ValueKey<String>('square-voice-room-browse'),
                  label: '去社区看看',
                  icon: 'community',
                  primary: true,
                  // Back to the 社区 segment of the same page.
                  onPressed: () => ref
                      .read(loopTabSegmentMemoryProvider.notifier)
                      .select('square', 0),
                ),
              ),
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            Column(
              key: const ValueKey<String>('square-voice-room-group'),
              children: <Widget>[
                for (final room in state.items)
                  LiveVoiceRoomCard(
                    key: ValueKey<String>(
                      'square-voice-room-${room.voiceRoomId}',
                    ),
                    room: room,
                    now: now,
                    inRoom: session?.voiceRoomId == room.voiceRoomId,
                    onTap: () => _open(room),
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
}

/// The faces a card stacks: the server's `speakersPreview` (host first, at
/// most four), or the host alone when the server has not sent one yet.
List<LiveVoiceRoomHost> liveVoiceRoomFaces(LiveVoiceRoom room) {
  final preview = room.speakersPreview;
  if (preview.isNotEmpty) {
    return preview.length > 4 ? preview.sublist(0, 4) : preview;
  }
  return <LiveVoiceRoomHost>[room.host];
}

/// The name a face is called by: its own, or the anonymous label.
String liveVoiceRoomFaceName(LiveVoiceRoomHost person) =>
    person.displayName ??
    voiceRoomDisplayKeyText('voiceRoom.member.anonymousMember');

/// One live room on the plaza (decision 0115): the room's title and its
/// community, the host and the speakers stacked, how many are listening and
/// how long it has been on.
class LiveVoiceRoomCard extends StatelessWidget {
  const LiveVoiceRoomCard({
    required this.room,
    required this.now,
    required this.inRoom,
    required this.onTap,
    super.key,
  });

  final LiveVoiceRoom room;
  final DateTime now;
  final bool inRoom;
  final VoidCallback onTap;

  static const double faceSize = 28;

  @override
  Widget build(BuildContext context) {
    final title = voiceRoomTitle(room.communityName, title: room.title);
    final host = liveVoiceRoomFaceName(room.host);
    // LOOP's role-intent figures exclude the host; the card counts the room
    // the way the room page does — host, speakers and listeners — and it is
    // who joined, not a reading of who is connected right now.
    final listening = '${room.listenerCount + room.speakerCount + 1} 在听';
    final elapsed = liveVoiceRoomElapsedLabel(room.startedAt, now);
    final faces = liveVoiceRoomFaces(room);
    final badge = inRoom
        ? const LoopBadge(
            '已在房间',
            key: ValueKey<String>('square-voice-room-in-room'),
            kind: LoopBadgeKind.up,
          )
        : room.joinable
        ? const LoopBadge('直播中', kind: LoopBadgeKind.up)
        : const LoopBadge('需加入');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Semantics(
        button: true,
        label:
            '$title，${room.communityName}，主持 $host，$listening，$elapsed'
            '${inRoom ? '，你已在房间里' : ''}'
            '${room.joinable ? '' : '，加入社区后可进入'}',
        excludeSemantics: true,
        child: Material(
          color: LoopColors.card,
          borderRadius: BorderRadius.circular(LoopRadius.cardValue),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(LoopRadius.cardValue),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CommunityLogo(
                        identity: room.communityId,
                        name: room.communityName,
                        logoRef: room.communityLogoRef,
                        size: 36,
                        radius: 10,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              key: const ValueKey<String>(
                                'square-voice-room-title',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LoopTypography.title(15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              room.communityName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LoopTypography.caption(
                                12,
                                color: LoopColors.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      badge,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      _FaceStack(faces: faces, size: faceSize),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '主持 $host',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopTypography.caption(
                            12,
                            color: LoopColors.text2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$listening · $elapsed',
                        key: const ValueKey<String>(
                          'square-voice-room-figures',
                        ),
                        style: LoopTypography.figure(
                          12,
                          weight: FontWeight.w500,
                          color: LoopColors.text2,
                        ),
                      ),
                    ],
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

/// Up to four faces, each covering a third of the one before it. Each sits
/// on its own Graphite disc a ring wider than the face, so where one covers
/// another the edge stays clean. An anonymous face is the initials of the
/// anonymous label and never a picture.
class _FaceStack extends StatelessWidget {
  const _FaceStack({required this.faces, required this.size});

  final List<LiveVoiceRoomHost> faces;
  final double size;

  static const double ring = 2;

  @override
  Widget build(BuildContext context) {
    final step = size * 2 / 3;
    final outer = size + ring * 2;
    final width = faces.isEmpty ? 0.0 : outer + step * (faces.length - 1);
    return SizedBox(
      key: const ValueKey<String>('square-voice-room-faces'),
      width: width,
      height: outer,
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < faces.length; index += 1)
            Positioned(
              left: step * index,
              child: Container(
                key: ValueKey<String>('square-voice-room-face-$index'),
                width: outer,
                height: outer,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: LoopColors.graphite,
                ),
                child: LoopProfileAvatar(
                  avatarRef: faces[index].displayName == null
                      ? null
                      : faces[index].avatarRef,
                  alias: liveVoiceRoomFaceName(faces[index]),
                  size: size,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
