import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/square/live_voice_rooms.dart';

/// Development Preview adapter for the plaza's live-room list.
///
/// Mounted only by `main_preview.dart`. Its mode is `preview`, so the page
/// carries the 演示数据 notice above every row it draws; nothing here is
/// read from or written to a server.
final class MemoryLiveVoiceRoomGateway implements LiveVoiceRoomGateway {
  MemoryLiveVoiceRoomGateway({DateTime? now})
    : _now = now ?? DateTime.now().toUtc();

  final DateTime _now;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.preview;

  @override
  Future<LiveVoiceRoomPage> listLive({String? cursor}) async {
    return LiveVoiceRoomPage(
      items: <LiveVoiceRoom>[
        LiveVoiceRoom(
          voiceRoomId: '5cc85f64-5717-4562-b3fc-2c963f66afc8',
          communityId: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
          communityName: '开发预览社区',
          communityLogoRef: 'avatar:preset/community-01',
          title: null,
          host: const LiveVoiceRoomHost(
            publicProfileId: null,
            displayName: '预览主持人',
            avatarRef: null,
          ),
          listenerCount: 12,
          speakerCount: 3,
          countsObservedAt: null,
          startedAt: _now.subtract(const Duration(minutes: 18)),
          joinable: true,
        ),
        LiveVoiceRoom(
          voiceRoomId: '6dd85f64-5717-4562-b3fc-2c963f66afd9',
          communityId: '4fb85f64-5717-4562-b3fc-2c963f66afb7',
          communityName: '预览未加入社区',
          communityLogoRef: 'avatar:preset/community-02',
          title: null,
          host: const LiveVoiceRoomHost(
            publicProfileId: null,
            displayName: null,
            avatarRef: null,
          ),
          listenerCount: 4,
          speakerCount: 1,
          countsObservedAt: null,
          startedAt: _now.subtract(const Duration(hours: 2)),
          joinable: false,
        ),
      ],
      nextCursor: null,
      observedAt: _now,
    );
  }
}
