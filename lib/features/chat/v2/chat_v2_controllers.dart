import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';

// ---------------------------------------------------------------------------
// community-chat · the official community channel locator
// ---------------------------------------------------------------------------

/// Reads one community record for the `community-chat` page.
///
/// It is deliberately separate from `CommunityProfileController` so opening
/// the channel never disturbs the record page's own state, and so a `syncing`
/// channel can be re-read without re-entering the profile.
final class CommunityChatController
    extends Notifier<CommunityResourceState<CommunityDetail>>
    with CommunitySingleFlight {
  String? _communityId;

  @override
  CommunityResourceState<CommunityDetail> build() {
    nextGeneration();
    final mode = ref.watch(communityGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return CommunityResourceState<CommunityDetail>.initial(mode);
  }

  String? get communityId => _communityId;

  Future<void> open(String communityId) {
    if (_communityId == communityId && state.isReady) {
      return Future<void>.value();
    }
    _communityId = communityId;
    return reload();
  }

  Future<void> reload() => single(() async {
    final id = _communityId;
    if (id == null) {
      state = state.failed(CommunityFailureKind.notFound);
      return;
    }
    final gateway = ref.read(communityGatewayProvider);
    final generation = nextGeneration();
    state = state.loading();
    try {
      final detail = await gateway.loadCommunity(id);
      if (!isCurrent(generation)) return;
      state = state.ready(detail);
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.failed(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.failed(CommunityFailureKind.unexpected);
    }
  });
}

final communityChatControllerProvider =
    NotifierProvider.autoDispose<
      CommunityChatController,
      CommunityResourceState<CommunityDetail>
    >(CommunityChatController.new);

// ---------------------------------------------------------------------------
// dm · friendship-gated direct channel resolution
// ---------------------------------------------------------------------------

/// Why a direct conversation cannot be opened yet.
enum DirectChannelBlock {
  /// No friendship exists. The only way forward is a message request.
  friendshipRequired,

  /// The server accepted the command but a human must finish it.
  operatorRequired,

  /// The operation reached a terminal rejection.
  rejected,
}

@immutable
final class DirectChannelState {
  const DirectChannelState({
    required this.mode,
    required this.phase,
    this.streamCid,
    this.failureKind,
    this.block,
    this.busy = false,
    this.requestSent = false,
  });

  factory DirectChannelState.initial(CommunityGatewayMode mode) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return DirectChannelState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;

  /// The only value that may open an official Stream channel.
  final String? streamCid;
  final CommunityFailureKind? failureKind;
  final DirectChannelBlock? block;
  final bool busy;

  /// A message request was confirmed by the server in this session.
  final bool requestSent;

  bool get isPreview => mode == CommunityGatewayMode.preview;

  bool get isReady => streamCid != null;
}

/// Resolves one direct-channel CID for a public profile.
///
/// A friendship is the only admission: an unreachable target is answered with
/// a single non-enumerable not-found, which this controller presents as
/// "send a message request first" without claiming the account exists.
final class DirectChannelController extends Notifier<DirectChannelState>
    with CommunitySingleFlight {
  static const maximumPolls = 12;

  String? _targetPublicProfileId;

  @override
  DirectChannelState build() {
    nextGeneration();
    final mode = ref.watch(chatV2GatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return DirectChannelState.initial(mode);
  }

  String? get targetPublicProfileId => _targetPublicProfileId;

  Future<void> open(String targetPublicProfileId) {
    if (_targetPublicProfileId == targetPublicProfileId && state.isReady) {
      return Future<void>.value();
    }
    _targetPublicProfileId = targetPublicProfileId;
    return resolve();
  }

  Future<void> resolve() => single(() async {
    final target = _targetPublicProfileId;
    if (target == null) {
      state = DirectChannelState(
        mode: state.mode,
        phase: CommunityViewPhase.empty,
        failureKind: CommunityFailureKind.notFound,
      );
      return;
    }
    final gateway = ref.read(chatV2GatewayProvider);
    final generation = nextGeneration();
    state = DirectChannelState(
      mode: state.mode,
      phase: CommunityViewPhase.loading,
      requestSent: state.requestSent,
    );
    try {
      var operation = await gateway.openDirectChannel(target);
      var polls = 0;
      while (!operation.terminal && polls < maximumPolls) {
        if (!isCurrent(generation)) return;
        final delay = operation.retryAfterMs ?? 500;
        await Future<void>.delayed(Duration(milliseconds: delay));
        if (!isCurrent(generation)) return;
        operation = await gateway.pollOperation(operation.operationId);
        polls += 1;
      }
      if (!isCurrent(generation)) return;
      _applyOperation(operation);
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = DirectChannelState(
        mode: state.mode,
        phase: error.kind == CommunityFailureKind.notFound
            ? CommunityViewPhase.permission
            : communityPhaseForFailure(error.kind),
        failureKind: error.kind,
        block: error.kind == CommunityFailureKind.notFound
            ? DirectChannelBlock.friendshipRequired
            : null,
        requestSent: state.requestSent,
      );
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = DirectChannelState(
        mode: state.mode,
        phase: CommunityViewPhase.error,
        failureKind: CommunityFailureKind.unexpected,
        requestSent: state.requestSent,
      );
    }
  });

  void _applyOperation(ChatOperation operation) {
    if (operation.isSucceeded && operation.streamCid != null) {
      state = DirectChannelState(
        mode: state.mode,
        phase: CommunityViewPhase.ready,
        streamCid: operation.streamCid,
        requestSent: state.requestSent,
      );
      return;
    }
    if (!operation.terminal) {
      // The poll budget ran out. The operation may still finish server-side,
      // so this is an unresolved outcome, not a failure.
      state = DirectChannelState(
        mode: state.mode,
        phase: CommunityViewPhase.error,
        failureKind: CommunityFailureKind.outcomeUnknown,
        requestSent: state.requestSent,
      );
      return;
    }
    state = DirectChannelState(
      mode: state.mode,
      phase: CommunityViewPhase.error,
      failureKind: operation.needsOperator
          ? CommunityFailureKind.outcomeUnknown
          : CommunityFailureKind.unexpected,
      block: operation.needsOperator
          ? DirectChannelBlock.operatorRequired
          : DirectChannelBlock.rejected,
      requestSent: state.requestSent,
    );
  }

  /// Records a confirmed message request. The caller sends it through the
  /// social port; this only remembers the server's 2xx.
  void markRequestSent() {
    state = DirectChannelState(
      mode: state.mode,
      phase: state.phase,
      streamCid: state.streamCid,
      failureKind: state.failureKind,
      block: state.block,
      requestSent: true,
    );
  }

  void setBusy(bool busy) {
    state = DirectChannelState(
      mode: state.mode,
      phase: state.phase,
      streamCid: state.streamCid,
      failureKind: busy ? null : state.failureKind,
      block: state.block,
      busy: busy,
      requestSent: state.requestSent,
    );
  }
}

final directChannelControllerProvider =
    NotifierProvider.autoDispose<DirectChannelController, DirectChannelState>(
      DirectChannelController.new,
    );

// ---------------------------------------------------------------------------
// group-info · membership exit
// ---------------------------------------------------------------------------

/// Leaves one small group through the LOOP backend.
///
/// Stream's own `leave` is deliberately not used: the backend owns the member
/// removal, and a lost response is replayed with the same idempotency key.
final class GroupMembershipController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<CommunityFailureKind?> leave(String groupId) async {
    if (state) return CommunityFailureKind.stale;
    state = true;
    try {
      await ref.read(chatV2GatewayProvider).leaveGroup(groupId);
      state = false;
      return null;
    } on CommunityGatewayException catch (error) {
      state = false;
      return error.kind;
    } catch (_) {
      state = false;
      return CommunityFailureKind.unexpected;
    }
  }
}

final groupMembershipControllerProvider =
    NotifierProvider.autoDispose<GroupMembershipController, bool>(
      GroupMembershipController.new,
    );

// ---------------------------------------------------------------------------
// voiceroom / voiceroom-full
// ---------------------------------------------------------------------------

@immutable
final class VoiceRoomPageState {
  const VoiceRoomPageState({
    required this.mode,
    required this.phase,
    this.snapshot,
    this.handRaises = const <VoiceRoomHandRaiseEntry>[],
    this.notLiveReasonCode,
    this.failureKind,
    this.busy = false,
  });

  factory VoiceRoomPageState.initial(CommunityGatewayMode mode) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return VoiceRoomPageState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final VoiceRoomSnapshot? snapshot;
  final List<VoiceRoomHandRaiseEntry> handRaises;

  /// The server's own explanation when no room is live.
  final String? notLiveReasonCode;
  final CommunityFailureKind? failureKind;
  final bool busy;

  bool get isPreview => mode == CommunityGatewayMode.preview;

  bool get isReady => phase == CommunityViewPhase.ready && snapshot != null;

  VoiceRoomPageState copyWith({
    CommunityViewPhase? phase,
    VoiceRoomSnapshot? snapshot,
    List<VoiceRoomHandRaiseEntry>? handRaises,
    String? notLiveReasonCode,
    CommunityFailureKind? failureKind,
    bool? busy,
    bool clearFailure = false,
  }) => VoiceRoomPageState(
    mode: mode,
    phase: phase ?? this.phase,
    snapshot: snapshot ?? this.snapshot,
    handRaises: handRaises ?? this.handRaises,
    notLiveReasonCode: notLiveReasonCode,
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    busy: busy ?? this.busy,
  );
}

/// Owns the LOOP-side room record, the hand-raise queue and the host commands.
///
/// It never claims a media connection: joining here only obtains the LOOP
/// grant. Connection, participants and microphone state come from Stream's own
/// `CallState` once the foreground call is mounted.
final class VoiceRoomController extends Notifier<VoiceRoomPageState>
    with CommunitySingleFlight {
  String? _communityId;

  @override
  VoiceRoomPageState build() {
    nextGeneration();
    final mode = ref.watch(voiceRoomGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return VoiceRoomPageState.initial(mode);
  }

  String? get communityId => _communityId;

  Future<void> open(String communityId) {
    if (_communityId == communityId && state.isReady) {
      return Future<void>.value();
    }
    _communityId = communityId;
    return reload();
  }

  Future<void> reload() => single(() async {
    final id = _communityId;
    if (id == null) {
      state = state.copyWith(
        phase: CommunityViewPhase.empty,
        failureKind: CommunityFailureKind.notFound,
      );
      return;
    }
    final gateway = ref.read(voiceRoomGatewayProvider);
    final generation = nextGeneration();
    state = state.copyWith(
      phase: state.snapshot == null
          ? CommunityViewPhase.loading
          : CommunityViewPhase.ready,
      clearFailure: true,
    );
    try {
      final current = await gateway.loadCurrent(id);
      if (!isCurrent(generation)) return;
      final snapshot = current.snapshot;
      if (snapshot == null) {
        state = VoiceRoomPageState(
          mode: state.mode,
          phase: CommunityViewPhase.empty,
          notLiveReasonCode: current.reasonCode,
        );
        return;
      }
      final queue = await _loadQueue(gateway, snapshot);
      if (!isCurrent(generation)) return;
      state = VoiceRoomPageState(
        mode: state.mode,
        phase: CommunityViewPhase.ready,
        snapshot: snapshot,
        handRaises: queue,
      );
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(
        phase: communityPhaseForFailure(error.kind),
        failureKind: error.kind,
      );
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(
        phase: CommunityViewPhase.error,
        failureKind: CommunityFailureKind.unexpected,
      );
    }
  });

  /// The queue is a host-facing read. A failure there must not take the room
  /// down, so it degrades to an empty queue.
  Future<List<VoiceRoomHandRaiseEntry>> _loadQueue(
    VoiceRoomGateway gateway,
    VoiceRoomSnapshot snapshot,
  ) async {
    if (!snapshot.viewer.isHost) return const <VoiceRoomHandRaiseEntry>[];
    try {
      return await gateway.listHandRaises(snapshot.room.voiceRoomId);
    } catch (_) {
      return const <VoiceRoomHandRaiseEntry>[];
    }
  }

  Future<CommunityFailureKind?> _command(
    Future<VoiceRoomSnapshot> Function(VoiceRoomGateway gateway, String roomId)
    body,
  ) async {
    final snapshot = state.snapshot;
    if (snapshot == null) return CommunityFailureKind.notFound;
    if (state.busy) return CommunityFailureKind.stale;
    final gateway = ref.read(voiceRoomGatewayProvider);
    final generation = nextGeneration();
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      final next = await body(gateway, snapshot.room.voiceRoomId);
      if (!isCurrent(generation)) return null;
      final queue = await _loadQueue(gateway, next);
      if (!isCurrent(generation)) return null;
      state = VoiceRoomPageState(
        mode: state.mode,
        phase: CommunityViewPhase.ready,
        snapshot: next,
        handRaises: queue,
      );
      return null;
    } on CommunityGatewayException catch (error) {
      if (isCurrent(generation)) {
        state = state.copyWith(busy: false, failureKind: error.kind);
      }
      return error.kind;
    } catch (_) {
      if (isCurrent(generation)) {
        state = state.copyWith(
          busy: false,
          failureKind: CommunityFailureKind.unexpected,
        );
      }
      return CommunityFailureKind.unexpected;
    }
  }

  Future<CommunityFailureKind?> join() =>
      _command((gateway, roomId) => gateway.join(roomId));

  Future<CommunityFailureKind?> leave() =>
      _command((gateway, roomId) => gateway.leave(roomId));

  Future<CommunityFailureKind?> raiseHand() =>
      _command((gateway, roomId) => gateway.raiseHand(roomId));

  Future<CommunityFailureKind?> cancelHandRaise() =>
      _command((gateway, roomId) => gateway.cancelHandRaise(roomId));

  Future<CommunityFailureKind?> inviteSpeaker(String publicProfileId) =>
      _command(
        (gateway, roomId) => gateway.inviteSpeaker(
          voiceRoomId: roomId,
          publicProfileId: publicProfileId,
        ),
      );

  Future<CommunityFailureKind?> removeSpeaker(String publicProfileId) =>
      _command(
        (gateway, roomId) => gateway.removeSpeaker(
          voiceRoomId: roomId,
          publicProfileId: publicProfileId,
        ),
      );

  Future<CommunityFailureKind?> muteAll() =>
      _command((gateway, roomId) => gateway.muteAll(roomId));

  Future<CommunityFailureKind?> endRoom() =>
      _command((gateway, roomId) => gateway.endRoom(roomId));
}

final voiceRoomControllerProvider =
    NotifierProvider.autoDispose<VoiceRoomController, VoiceRoomPageState>(
      VoiceRoomController.new,
    );
