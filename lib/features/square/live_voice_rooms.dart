import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_state.dart';

/// The host line of one live room, under the leaderboard display rule.
///
/// [displayName] is null when the host shows anonymously or has no alias;
/// the row then says 匿名成员 and never borrows another name.
@immutable
final class LiveVoiceRoomHost {
  const LiveVoiceRoomHost({
    required this.publicProfileId,
    required this.displayName,
    required this.avatarRef,
  });

  final String? publicProfileId;
  final String? displayName;
  final String? avatarRef;
}

/// One row of `GET /v2/voice-rooms/live` (S106 §7).
@immutable
final class LiveVoiceRoom {
  const LiveVoiceRoom({
    required this.voiceRoomId,
    required this.communityId,
    required this.communityName,
    required this.communityLogoRef,
    required this.title,
    required this.host,
    required this.listenerCount,
    required this.speakerCount,
    required this.countsObservedAt,
    required this.startedAt,
    required this.joinable,
  });

  final String voiceRoomId;
  final String communityId;
  final String communityName;
  final String? communityLogoRef;

  /// Rooms carry no title today; the row shows the community name instead.
  final String? title;
  final LiveVoiceRoomHost host;

  /// LOOP role-intent counts, host excluded. Not provider presence.
  final int listenerCount;
  final int speakerCount;

  /// When the counts were observed, or null when they were not observed at
  /// all — then the row does not present them as live presence.
  final DateTime? countsObservedAt;
  final DateTime startedAt;

  /// The reader is a member of the room's community and may enter.
  final bool joinable;
}

@immutable
final class LiveVoiceRoomPage {
  const LiveVoiceRoomPage({
    required this.items,
    required this.nextCursor,
    required this.observedAt,
  });

  final List<LiveVoiceRoom> items;
  final String? nextCursor;
  final DateTime observedAt;
}

/// Feature port for the plaza's live-room list.
abstract interface class LiveVoiceRoomGateway {
  CommunityGatewayMode get mode;

  Future<LiveVoiceRoomPage> listLive({String? cursor});
}

/// The production default while any input is missing: no request, no rows.
final class UnavailableLiveVoiceRoomGateway implements LiveVoiceRoomGateway {
  const UnavailableLiveVoiceRoomGateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.unavailable;

  @override
  Future<LiveVoiceRoomPage> listLive({String? cursor}) =>
      Future<LiveVoiceRoomPage>.error(
        const CommunityGatewayException(CommunityFailureKind.unavailable),
      );
}

final liveVoiceRoomGatewayProvider = Provider<LiveVoiceRoomGateway>(
  (ref) => const UnavailableLiveVoiceRoomGateway(),
);

@immutable
final class LiveVoiceRoomsState {
  const LiveVoiceRoomsState({
    required this.mode,
    required this.phase,
    this.items = const <LiveVoiceRoom>[],
    this.nextCursor,
    this.observedAt,
    this.failureKind,
    this.loadingMore = false,
    this.refreshing = false,
  });

  factory LiveVoiceRoomsState.initial(CommunityGatewayMode mode) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return LiveVoiceRoomsState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final List<LiveVoiceRoom> items;
  final String? nextCursor;
  final DateTime? observedAt;
  final CommunityFailureKind? failureKind;
  final bool loadingMore;
  final bool refreshing;

  bool get canLoadMore => nextCursor != null && !loadingMore;
}

/// Reads the live list one cursor page at a time; the reader never sees a
/// page number. A failed next page keeps the rows already shown.
final class LiveVoiceRoomsController extends Notifier<LiveVoiceRoomsState>
    with CommunitySingleFlight {
  @override
  LiveVoiceRoomsState build() {
    nextGeneration();
    ref.onDispose(nextGeneration);
    return LiveVoiceRoomsState.initial(
      ref.watch(liveVoiceRoomGatewayProvider).mode,
    );
  }

  Future<void> load() {
    if (state.phase != CommunityViewPhase.loading) return Future<void>.value();
    return _fetch(append: false);
  }

  Future<void> reload() => _fetch(append: false);

  Future<void> refresh() => _fetch(append: false, refresh: true);

  Future<void> loadMore() {
    if (!state.canLoadMore) return Future<void>.value();
    return _fetch(append: true);
  }

  Future<void> _fetch({required bool append, bool refresh = false}) => single(
    () async {
      final gateway = ref.read(liveVoiceRoomGatewayProvider);
      final previous = state;
      if (previous.mode == CommunityGatewayMode.unavailable) return;
      final generation = nextGeneration();
      final keepRows = !append && refresh && previous.items.isNotEmpty;
      state = LiveVoiceRoomsState(
        mode: previous.mode,
        phase: append || keepRows ? previous.phase : CommunityViewPhase.loading,
        items: append || keepRows ? previous.items : const <LiveVoiceRoom>[],
        nextCursor: append ? previous.nextCursor : null,
        observedAt: previous.observedAt,
        loadingMore: append,
        refreshing: keepRows,
      );
      try {
        final page = await gateway.listLive(
          cursor: append ? previous.nextCursor : null,
        );
        if (!isCurrent(generation)) return;
        final seen = <String>{
          for (final room in previous.items) room.voiceRoomId,
        };
        final merged = append
            ? <LiveVoiceRoom>[
                ...previous.items,
                for (final room in page.items)
                  if (seen.add(room.voiceRoomId)) room,
              ]
            : page.items;
        state = LiveVoiceRoomsState(
          mode: previous.mode,
          phase: merged.isEmpty
              ? CommunityViewPhase.empty
              : CommunityViewPhase.ready,
          items: List<LiveVoiceRoom>.unmodifiable(merged),
          nextCursor: page.nextCursor,
          observedAt: page.observedAt,
        );
      } on CommunityGatewayException catch (error) {
        if (!isCurrent(generation)) return;
        state = _failed(previous, append || keepRows, error.kind);
      } catch (_) {
        if (!isCurrent(generation)) return;
        state = _failed(
          previous,
          append || keepRows,
          CommunityFailureKind.unexpected,
        );
      }
    },
  );

  static LiveVoiceRoomsState _failed(
    LiveVoiceRoomsState previous,
    bool keepRows,
    CommunityFailureKind kind,
  ) => LiveVoiceRoomsState(
    mode: previous.mode,
    phase: keepRows && previous.items.isNotEmpty
        ? CommunityViewPhase.ready
        : communityPhaseForFailure(kind),
    items: keepRows ? previous.items : const <LiveVoiceRoom>[],
    nextCursor: keepRows ? previous.nextCursor : null,
    observedAt: previous.observedAt,
    failureKind: kind,
  );
}

final liveVoiceRoomsControllerProvider =
    NotifierProvider.autoDispose<LiveVoiceRoomsController, LiveVoiceRoomsState>(
      LiveVoiceRoomsController.new,
    );

/// `开播 12 分钟` / `开播 2 小时`. A clock that runs behind the server's
/// start time reads as just started rather than a negative duration.
String liveVoiceRoomElapsedLabel(DateTime startedAt, DateTime now) {
  final elapsed = now.difference(startedAt);
  if (elapsed.inMinutes < 1) return '刚开播';
  if (elapsed.inMinutes < 60) return '开播 ${elapsed.inMinutes} 分钟';
  if (elapsed.inHours < 24) return '开播 ${elapsed.inHours} 小时';
  return '开播 ${elapsed.inDays} 天';
}
