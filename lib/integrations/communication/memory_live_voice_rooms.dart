import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/square/live_voice_rooms.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

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
          communityName:
              LoopL10n.current.integrations_memoryChatGatewaysCommunityName,
          communityLogoRef: 'avatar:preset/community-01',
          title: LoopL10n.current.integrations_memoryLiveVoiceRoomsTitle,
          host: LiveVoiceRoomHost(
            publicProfileId: null,
            displayName:
                LoopL10n.current.integrations_memoryLiveVoiceRoomsDisplayName,
            avatarRef: null,
          ),
          // Decision 0115: host first, then speakers; the last one shows
          // anonymously and carries nothing.
          speakersPreview: <LiveVoiceRoomHost>[
            LiveVoiceRoomHost(
              publicProfileId: null,
              displayName:
                  LoopL10n.current.integrations_memoryLiveVoiceRoomsDisplayName,
              avatarRef: 'avatar:preset/people-01',
            ),
            LiveVoiceRoomHost(
              publicProfileId: null,
              displayName: LoopL10n
                  .current
                  .integrations_memoryLiveVoiceRoomsDisplayName2,
              avatarRef: 'avatar:preset/people-02',
            ),
            LiveVoiceRoomHost(
              publicProfileId: null,
              displayName: null,
              avatarRef: null,
            ),
          ],
          listenerCount: 12,
          speakerCount: 3,
          countsObservedAt: null,
          startedAt: _now.subtract(const Duration(minutes: 18)),
          joinable: true,
        ),
        LiveVoiceRoom(
          voiceRoomId: '6dd85f64-5717-4562-b3fc-2c963f66afd9',
          communityId: '4fb85f64-5717-4562-b3fc-2c963f66afb7',
          communityName:
              LoopL10n.current.integrations_memoryLiveVoiceRoomsCommunityName,
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
