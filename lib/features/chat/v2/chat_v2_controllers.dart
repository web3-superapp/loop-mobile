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
    // Opening a conversation for the first time has nothing cached behind it,
    // so an `offline` phase here replaces the whole room. A socket the peer
    // closed while the app sat idle fails exactly like that and carries no
    // server answer, so the first read gets one silent re-attempt; the page
    // stays in its loading phase meanwhile rather than claiming an outage.
    final firstRead = state.value == null;
    state = state.loading();
    var reattempted = false;
    while (true) {
      try {
        final detail = await gateway.loadCommunity(id);
        if (!isCurrent(generation)) return;
        state = state.ready(detail);
        return;
      } on CommunityGatewayException catch (error) {
        if (!isCurrent(generation)) return;
        if (firstRead &&
            !reattempted &&
            error.kind == CommunityFailureKind.offline) {
          reattempted = true;
          continue;
        }
        state = state.failed(error.kind);
        return;
      } catch (_) {
        if (!isCurrent(generation)) return;
        state = state.failed(CommunityFailureKind.unexpected);
        return;
      }
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
    this.requestFailure,
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

  /// Why the last message request did not go through.
  ///
  /// The send is a write this page owns on its own: it is not the channel
  /// read, so it does not move [phase], and it is not forgotten when the page
  /// rebuilds. A toast that has already faded is not feedback — the refusal
  /// stays on screen next to the control that produced it until the reader
  /// tries again (device walkthrough 2026-09-23 · i06/i07).
  final CommunityFailureKind? requestFailure;

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

  /// Records that the message request was refused, with the server's kind.
  ///
  /// The channel state is untouched: the conversation is still closed for the
  /// same reason it was closed before, and the control stays on screen so the
  /// reader can try the same send again.
  void markRequestFailed(CommunityFailureKind kind) {
    state = DirectChannelState(
      mode: state.mode,
      phase: state.phase,
      streamCid: state.streamCid,
      failureKind: state.failureKind,
      block: state.block,
      requestSent: state.requestSent,
      requestFailure: kind,
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
      requestFailure: busy ? null : state.requestFailure,
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

/// One roster view's own five states.
///
/// The roster is a second read beside the room: it fails, empties and pages on
/// its own, and a room that is readable never disappears because its member
/// list is not. An empty list that was read is not the same fact as a list that
/// could not be read, so the two keep different phases.
@immutable
final class VoiceRoomRosterState {
  const VoiceRoomRosterState({
    required this.view,
    required this.phase,
    this.items = const <VoiceRoomMember>[],
    this.nextCursor,
    this.failureKind,
    this.loadingMore = false,
  });

  const VoiceRoomRosterState.initial(this.view)
    : phase = CommunityViewPhase.loading,
      items = const <VoiceRoomMember>[],
      nextCursor = null,
      failureKind = null,
      loadingMore = false;

  final VoiceRoomRosterView view;
  final CommunityViewPhase phase;
  final List<VoiceRoomMember> items;

  /// Non-null only while the server says another page exists.
  final String? nextCursor;
  final CommunityFailureKind? failureKind;
  final bool loadingMore;

  bool get isReady => phase == CommunityViewPhase.ready;

  bool get canLoadMore => nextCursor != null && !loadingMore;
}

@immutable
final class VoiceRoomPageState {
  const VoiceRoomPageState({
    required this.mode,
    required this.phase,
    this.snapshot,
    this.handRaises = const <VoiceRoomHandRaiseEntry>[],
    this.speakers = const VoiceRoomRosterState.initial(
      VoiceRoomRosterView.speaker,
    ),
    this.listeners = const VoiceRoomRosterState.initial(
      VoiceRoomRosterView.listener,
    ),
    this.notLiveReasonCode,
    this.failureKind,
    this.failureReasonCode,
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
  final VoiceRoomRosterState speakers;
  final VoiceRoomRosterState listeners;

  /// The server's own explanation when no room is live.
  final String? notLiveReasonCode;
  final CommunityFailureKind? failureKind;

  /// The refusal the server named for the last command, when it named one.
  /// A kind alone says 「不可用」 for a room that is simply not open yet.
  final String? failureReasonCode;
  final bool busy;

  bool get isPreview => mode == CommunityGatewayMode.preview;

  bool get isReady => phase == CommunityViewPhase.ready && snapshot != null;

  VoiceRoomRosterState roster(VoiceRoomRosterView view) =>
      view == VoiceRoomRosterView.speaker ? speakers : listeners;

  VoiceRoomPageState withRoster(VoiceRoomRosterState roster) => copyWith(
    speakers: roster.view == VoiceRoomRosterView.speaker ? roster : null,
    listeners: roster.view == VoiceRoomRosterView.listener ? roster : null,
  );

  VoiceRoomPageState copyWith({
    CommunityViewPhase? phase,
    VoiceRoomSnapshot? snapshot,
    List<VoiceRoomHandRaiseEntry>? handRaises,
    VoiceRoomRosterState? speakers,
    VoiceRoomRosterState? listeners,
    String? notLiveReasonCode,
    CommunityFailureKind? failureKind,
    String? failureReasonCode,
    bool? busy,
    bool clearFailure = false,
  }) => VoiceRoomPageState(
    mode: mode,
    phase: phase ?? this.phase,
    snapshot: snapshot ?? this.snapshot,
    handRaises: handRaises ?? this.handRaises,
    speakers: speakers ?? this.speakers,
    listeners: listeners ?? this.listeners,
    notLiveReasonCode: notLiveReasonCode,
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    failureReasonCode: clearFailure
        ? null
        : (failureReasonCode ??
              (failureKind == null ? this.failureReasonCode : null)),
    busy: busy ?? this.busy,
  );
}

/// The room the account is still a member of while it looks at something else.
///
/// Going back from the room page does not leave the room — only the 离开
/// command does — so this outlives the page, and the shell keeps one banner
/// that says so and takes the reader back.
@immutable
final class VoiceRoomSession {
  const VoiceRoomSession({
    required this.communityId,
    required this.communityName,
    required this.voiceRoomId,
    required this.callRoomId,
    required this.role,
    required this.joinedCount,
  });

  final String communityId;

  /// Which community's room this is, in words. It comes from the room
  /// resource (decision 0052), so the banner names the room without a second
  /// read and without the shell holding a community cache.
  final String communityName;
  final String voiceRoomId;

  /// The provider room this account is in, when the room record carries one.
  /// It is what a live reading from this device's own call is matched
  /// against; nothing is keyed by it.
  final String? callRoomId;
  final VoiceRoomRole role;

  /// How many people LOOP has recorded in this room, host included, or null
  /// when the server did not give the figure. It is what the strip prints
  /// while this device holds no call of its own: an account that joined is in
  /// it, which is the question a reader asks the strip. A live count, when
  /// this device is connected, replaces it.
  final int? joinedCount;

  @override
  bool operator ==(Object other) =>
      other is VoiceRoomSession &&
      other.communityId == communityId &&
      other.communityName == communityName &&
      other.voiceRoomId == voiceRoomId &&
      other.callRoomId == callRoomId &&
      other.role == role &&
      other.joinedCount == joinedCount;

  @override
  int get hashCode => Object.hash(
    communityId,
    communityName,
    voiceRoomId,
    callRoomId,
    role,
    joinedCount,
  );
}

final class VoiceRoomSessionController extends Notifier<VoiceRoomSession?> {
  @override
  VoiceRoomSession? build() {
    // Principal-scoped: a new account, or a sign-out, rotates the gateway and
    // takes the banner with it.
    ref.watch(voiceRoomGatewayProvider);
    return null;
  }

  void enter(VoiceRoomSession session) {
    if (state != session) state = session;
  }

  /// Clears the banner raised for one community. A banner another room raised
  /// is left alone.
  void leave(String communityId) {
    if (state?.communityId == communityId) state = null;
  }
}

/// How many voice room pages are mounted.
///
/// The shell's banner is a marker for a room the reader cannot see; on the
/// room page it would repeat what the page already says. Counting the mounted
/// pages answers that without the shell having to listen to the router, which
/// would rebuild it in the middle of the router's own build.
final class VoiceRoomPagePresence extends Notifier<int> {
  @override
  int build() => 0;

  void enter() => state = state + 1;

  void exit() => state = state > 0 ? state - 1 : 0;
}

final voiceRoomPagePresenceProvider =
    NotifierProvider<VoiceRoomPagePresence, int>(VoiceRoomPagePresence.new);

final voiceRoomSessionProvider =
    NotifierProvider<VoiceRoomSessionController, VoiceRoomSession?>(
      VoiceRoomSessionController.new,
    );

/// Owns the LOOP-side room record, the hand-raise queue and the host commands.
///
/// It never claims a media connection: joining here only obtains the LOOP
/// grant. Connection, participants and microphone state come from Stream's own
/// `CallState` once the foreground call is mounted.
final class VoiceRoomController extends Notifier<VoiceRoomPageState>
    with CommunitySingleFlight {
  String? _communityId;

  /// One roster read per view at a time. The page asks on every build until a
  /// view leaves its loading phase, so the guard is what makes that one call.
  final Set<VoiceRoomRosterView> _rosterInFlight = <VoiceRoomRosterView>{};

  VoiceRoomProviderSync? _lastCommandSync;

  /// One queue read at a time: a burst of cues is one question.
  var _queueInFlight = false;

  /// How many commands are in flight.
  ///
  /// A command that was superseded must not clear the 忙 flag the command
  /// that superseded it raised, and the last one out must always clear it.
  var _commandsInFlight = 0;

  /// What the server said about the provider write its last command made.
  ///
  /// The page state carries the room as it was last *read*, and a read reports
  /// only its own provider work — so the answer a command gave about its own
  /// write is gone by the time the room has been read again. One command needs
  /// it: raising a hand is told to the room through a provider event (decision
  /// 0069), and an event that was not sent means the hand is recorded and the
  /// host has not been told. It is read straight after awaiting the command.
  VoiceRoomProviderSync? get lastCommandSync => _lastCommandSync;

  @override
  VoiceRoomPageState build() {
    nextGeneration();
    final mode = ref.watch(voiceRoomGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return VoiceRoomPageState.initial(mode);
  }

  String? get communityId => _communityId;

  /// Opens one community's room, and reads it every time.
  ///
  /// It used to answer a community it had already read with the snapshot it
  /// was still holding. That snapshot outlives the room it describes: a host
  /// who ends a room and opens a new one for the same community reaches a page
  /// that shows the old one — 「房间已结束」 over a room created seconds before
  /// — and `GET …/voice-rooms/current` is never sent at all, which is a create
  /// that looks like a failure with a 201 behind it. A page that opens reads.
  Future<void> open(String communityId) {
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
        _publishSession(null);
        state = VoiceRoomPageState(
          mode: state.mode,
          phase: CommunityViewPhase.empty,
          notLiveReasonCode: current.reasonCode,
        );
        return;
      }
      final queue = await _loadQueue(gateway, snapshot);
      if (!isCurrent(generation)) return;
      _publishSession(snapshot);
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
        failureReasonCode: error.reasonCode,
      );
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(
        phase: CommunityViewPhase.error,
        failureKind: CommunityFailureKind.unexpected,
      );
    }
  });

  /// Reads this room again for a reader who asked for the audio back.
  ///
  /// `GET /v2/voice-rooms/{id}`: the room record, and with it the provider
  /// call id and whether the room is still live, is exactly what a second
  /// connection attempt needs to start from. A failure leaves the page as it
  /// was read — the membership did not change because a read did not finish.
  Future<void> refreshRoom() {
    final snapshot = state.snapshot;
    if (snapshot == null) return reload();
    // A command is already reading this room for itself, and its read is the
    // one the page will take. A refresh that ran beside it used to retire it:
    // the command then returned "nothing went wrong" without ever clearing
    // 忙, and every control on the page stayed disabled for as long as the
    // page was open.
    if (state.busy) return Future<void>.value();
    return single(() async {
      final gateway = ref.read(voiceRoomGatewayProvider);
      // Taken, never advanced: this read retires nothing.
      final generation = currentGeneration;
      final roomId = snapshot.room.voiceRoomId;
      try {
        final next = await gateway.load(roomId);
        if (!_mayWriteRead(generation)) return;
        _publishSession(next);
        state = state.copyWith(
          phase: CommunityViewPhase.ready,
          snapshot: next,
          clearFailure: true,
        );
      } on CommunityGatewayException catch (error) {
        if (!_mayWriteRead(generation)) return;
        state = state.copyWith(
          failureKind: error.kind,
          failureReasonCode: error.reasonCode,
        );
      } catch (_) {
        if (!_mayWriteRead(generation)) return;
        state = state.copyWith(failureKind: CommunityFailureKind.unexpected);
      }
    });
  }

  /// Whether a read that started at [generation] may still write.
  ///
  /// It may not once a command or a reload has begun: those own the page, and
  /// an answer read before them describes the room as it was.
  bool _mayWriteRead(int generation) => isCurrent(generation) && !state.busy;

  /// Reads the hand-raise queue again, and nothing else.
  ///
  /// The queue is the host's own read and it changes because of somebody
  /// else: on the review devices a listener raised a hand and the host's page,
  /// which had read the queue when it opened, went on showing an empty one.
  /// The provider's own event is what triggers this (decision 0069) — the
  /// event says only that the queue moved, and the identities, the order and
  /// the commands all come from this read.
  ///
  /// It touches neither the room nor the rosters: a queue that could not be
  /// read leaves the page exactly as it was.
  Future<void> refreshHandRaises() async {
    final snapshot = state.snapshot;
    if (snapshot == null || !snapshot.viewer.isHost) return;
    // A command reads the queue as part of itself, and two cues arriving
    // together are one read.
    if (state.busy || _queueInFlight) return;
    final generation = currentGeneration;
    final roomId = snapshot.room.voiceRoomId;
    final List<VoiceRoomHandRaiseEntry> queue;
    _queueInFlight = true;
    try {
      queue = await ref.read(voiceRoomGatewayProvider).listHandRaises(roomId);
    } catch (_) {
      return;
    } finally {
      _queueInFlight = false;
    }
    if (!_mayWriteRead(generation) ||
        state.snapshot?.room.voiceRoomId != roomId) {
      return;
    }
    state = state.copyWith(handRaises: queue);
  }

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
    _lastCommandSync = null;
    _commandsInFlight += 1;
    try {
      final committed = await body(gateway, snapshot.room.voiceRoomId);
      // Superseded by a later command or a whole reload: the page belongs to
      // that one now. It is not a success and is not reported as one —
      // 「已加入」 over a page that had moved on was a sentence about nothing —
      // and it is not a refusal either: the server may well have applied it,
      // so the reader is told to look rather than told it failed. The one
      // word the page keeps for a refusal the *server* named (`stale`, a
      // room that has ended) stays that refusal's alone.
      if (!isCurrent(generation)) return CommunityFailureKind.cancelled;
      _lastCommandSync = committed.providerSync;
      final next = await _reread(gateway, committed);
      if (!isCurrent(generation)) return CommunityFailureKind.cancelled;
      final queue = await _loadQueue(gateway, next);
      if (!isCurrent(generation)) return CommunityFailureKind.cancelled;
      _publishSession(next);
      state = VoiceRoomPageState(
        mode: state.mode,
        phase: CommunityViewPhase.ready,
        snapshot: next,
        handRaises: queue,
      );
      return null;
    } on CommunityGatewayException catch (error) {
      if (isCurrent(generation)) {
        state = state.copyWith(
          failureKind: error.kind,
          failureReasonCode: error.reasonCode,
        );
      }
      return error.kind;
    } catch (_) {
      if (isCurrent(generation)) {
        state = state.copyWith(failureKind: CommunityFailureKind.unexpected);
      }
      return CommunityFailureKind.unexpected;
    } finally {
      _commandsInFlight -= 1;
      // The last command out puts the flag down, whatever became of it. A
      // command that is still running owns it and keeps it up.
      if (_commandsInFlight == 0 && state.busy) {
        state = state.copyWith(busy: false);
      }
    }
  }

  /// Publishes, or withdraws, the shell's "still in a voice room" banner.
  ///
  /// The banner follows the membership the server reports, never a local
  /// guess: a room that ended, or one this account has not joined, raises
  /// nothing.
  void _publishSession(VoiceRoomSnapshot? snapshot) {
    final communityId = _communityId;
    if (communityId == null) return;
    final session = ref.read(voiceRoomSessionProvider.notifier);
    final role = snapshot?.viewer.role;
    if (snapshot == null || !snapshot.room.isLive || role == null) {
      session.leave(communityId);
      return;
    }
    session.enter(
      VoiceRoomSession(
        communityId: communityId,
        communityName: snapshot.room.communityName,
        voiceRoomId: snapshot.room.voiceRoomId,
        callRoomId: snapshot.room.roomId,
        role: role,
        joinedCount: snapshot.participants.joinedCount,
      ),
    );
  }

  /// Re-reads the room after a command.
  ///
  /// A command answers with the transition it committed, and the server fills
  /// `participants.observed` only on a read — every command returns it as
  /// unavailable. Showing that answer directly made a successful join look
  /// like a room with no one in it. The committed answer is kept when the
  /// follow-up read fails: the command still happened.
  Future<VoiceRoomSnapshot> _reread(
    VoiceRoomGateway gateway,
    VoiceRoomSnapshot committed,
  ) async {
    try {
      return await gateway.load(committed.room.voiceRoomId);
    } catch (_) {
      return committed;
    }
  }

  /// Reads one roster view's first page.
  ///
  /// It is lazy: the lobby never asks for it, and the session page asks once
  /// per view. A failure here is the roster's own — the room above it stays
  /// exactly as it was read.
  Future<void> loadRoster(VoiceRoomRosterView view) =>
      _fetchRoster(view, append: false);

  Future<void> loadMoreRoster(VoiceRoomRosterView view) {
    if (!state.roster(view).canLoadMore) return Future<void>.value();
    return _fetchRoster(view, append: true);
  }

  Future<void> _fetchRoster(
    VoiceRoomRosterView view, {
    required bool append,
  }) async {
    final snapshot = state.snapshot;
    if (snapshot == null) return;
    if (!_rosterInFlight.add(view)) return;
    final roomId = snapshot.room.voiceRoomId;
    final before = state.roster(view);
    final cursor = append ? before.nextCursor : null;
    if (append && cursor == null) {
      _rosterInFlight.remove(view);
      return;
    }
    if (append) {
      state = state.withRoster(
        VoiceRoomRosterState(
          view: view,
          phase: before.phase,
          items: before.items,
          nextCursor: before.nextCursor,
          loadingMore: true,
        ),
      );
    }
    final gateway = ref.read(voiceRoomGatewayProvider);
    try {
      final page = await gateway.listMembers(
        voiceRoomId: roomId,
        view: view,
        cursor: cursor,
      );
      // The room may have been re-read, or left, while this page was in
      // flight; a roster for a room that is no longer on screen is dropped.
      if (state.snapshot?.room.voiceRoomId != roomId) return;
      final items = <VoiceRoomMember>[
        if (append) ...before.items,
        ...page.items,
      ];
      state = state.withRoster(
        VoiceRoomRosterState(
          view: view,
          phase: items.isEmpty
              ? CommunityViewPhase.empty
              : CommunityViewPhase.ready,
          items: List<VoiceRoomMember>.unmodifiable(items),
          nextCursor: page.nextCursor,
        ),
      );
    } on CommunityGatewayException catch (error) {
      if (state.snapshot?.room.voiceRoomId != roomId) return;
      state = state.withRoster(
        VoiceRoomRosterState(
          view: view,
          // An appended page that failed keeps the rows already read: the
          // list is short, not unreadable.
          phase: append ? before.phase : communityPhaseForFailure(error.kind),
          items: before.items,
          nextCursor: before.nextCursor,
          failureKind: error.kind,
        ),
      );
    } catch (_) {
      if (state.snapshot?.room.voiceRoomId != roomId) return;
      state = state.withRoster(
        VoiceRoomRosterState(
          view: view,
          phase: append ? before.phase : CommunityViewPhase.error,
          items: before.items,
          nextCursor: before.nextCursor,
          failureKind: CommunityFailureKind.unexpected,
        ),
      );
    } finally {
      _rosterInFlight.remove(view);
    }
  }

  /// Runs exactly one command the server published on one roster row.
  ///
  /// The client maps the server's command to the server's own endpoint and
  /// invents no other: a row without the command never reaches this.
  Future<CommunityFailureKind?> runMemberCommand({
    required VoiceRoomMemberCommand command,
    required String publicProfileId,
  }) => switch (command) {
    VoiceRoomMemberCommand.inviteSpeaker => inviteSpeaker(publicProfileId),
    VoiceRoomMemberCommand.removeSpeaker => removeSpeaker(publicProfileId),
    VoiceRoomMemberCommand.mute => muteSpeaker(publicProfileId),
    VoiceRoomMemberCommand.unmute ||
    VoiceRoomMemberCommand.unmuteSelf => unmuteSpeaker(publicProfileId),
  };

  Future<CommunityFailureKind?> muteSpeaker(String publicProfileId) => _command(
    (gateway, roomId) => gateway.muteSpeaker(
      voiceRoomId: roomId,
      publicProfileId: publicProfileId,
    ),
  );

  Future<CommunityFailureKind?> unmuteSpeaker(String publicProfileId) =>
      _command(
        (gateway, roomId) => gateway.unmuteSpeaker(
          voiceRoomId: roomId,
          publicProfileId: publicProfileId,
        ),
      );

  /// Clears this account's own mute intent after the device opened the
  /// microphone (decision 0053).
  ///
  /// The target and the permission both come from the server's own row: only
  /// a speaker row marked [VoiceRoomMember.isSelf] that carries
  /// [VoiceRoomMemberCommand.unmuteSelf] is acted on. A room where the server
  /// published no such command — the row is not muted, or this account is not
  /// a speaker — has nothing to clear, so this does nothing and reports no
  /// failure. It never opens or closes a microphone.
  Future<CommunityFailureKind?> clearOwnMuteIntent() async {
    if (state.roster(VoiceRoomRosterView.speaker).phase ==
        CommunityViewPhase.loading) {
      await loadRoster(VoiceRoomRosterView.speaker);
    }
    for (final member in state.roster(VoiceRoomRosterView.speaker).items) {
      final target = member.publicProfileId;
      if (member.isSelf &&
          target != null &&
          member.commands.contains(VoiceRoomMemberCommand.unmuteSelf)) {
        final failure = await unmuteSpeaker(target);
        // The roster row still carries the old intent; the room was re-read,
        // the list was not.
        if (failure == null) await loadRoster(VoiceRoomRosterView.speaker);
        return failure;
      }
    }
    return null;
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

/// Opens a community voice room.
///
/// The entry is shown from the server's own viewer projection, but the
/// admission is still the server's: a member gets `PERMISSION_DENIED`, and a
/// community that already has a live room gets `RESOURCE_CONFLICT`. The state
/// is the in-flight flag, so one confirmed tap cannot become two rooms.
final class VoiceRoomOpenController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<VoiceRoomOpenOutcome> openRoom(String communityId) async {
    if (state) {
      return const VoiceRoomOpenOutcome.refused(CommunityFailureKind.stale);
    }
    state = true;
    try {
      final room = await ref
          .read(voiceRoomGatewayProvider)
          .createRoom(communityId);
      state = false;
      return VoiceRoomOpenOutcome.opened(room);
    } on CommunityGatewayException catch (error) {
      state = false;
      return VoiceRoomOpenOutcome.refused(error.kind);
    } catch (_) {
      state = false;
      return const VoiceRoomOpenOutcome.refused(
        CommunityFailureKind.unexpected,
      );
    }
  }
}

/// What came back from opening a room.
///
/// A 201 is not the same answer as a room the community can enter: the room
/// row commits before the provider calls, and the response says which of them
/// landed. A room that exists and cannot be entered is a command that is not
/// finished — the page says so instead of walking the host into a room nobody
/// can hear, and opening it again repeats the provider half of the same
/// command rather than asking for a second room.
@immutable
final class VoiceRoomOpenOutcome {
  const VoiceRoomOpenOutcome.opened(VoiceRoomSnapshot this.room)
    : failure = null;

  const VoiceRoomOpenOutcome.refused(CommunityFailureKind this.failure)
    : room = null;

  final VoiceRoomSnapshot? room;
  final CommunityFailureKind? failure;

  /// The room was opened and this account can be let into the call.
  bool get isOpen => room?.room.audioOpen ?? false;

  /// The server's own name for the write it could not confirm.
  String? get unconfirmedReason => room != null && !room!.providerSync.confirmed
      ? room!.providerSync.reason
      : null;
}

/// Whether one community has a live voice room right now.
///
/// The community record carries the same fact and is read once, when the page
/// opens. A reader standing on a community page while somebody opens a room
/// therefore saw nothing at all: on the review devices the second phone kept a
/// dark voice control for as long as it was looked at. This is that one row,
/// read again on the page's own interval and only while the page is on screen.
///
/// It is read-only and it only ever *adds* a room: a read that did not finish
/// leaves the page with what it already had, and never takes a live room off a
/// page that was told about one.
@immutable
final class CommunityVoiceLive {
  const CommunityVoiceLive({
    required this.communityId,
    required this.isLive,
    required this.voiceRoomId,
  });

  final String communityId;
  final bool isLive;

  /// The room the community has, when it has one.
  final String? voiceRoomId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityVoiceLive &&
          other.communityId == communityId &&
          other.isLive == isLive &&
          other.voiceRoomId == voiceRoomId;

  @override
  int get hashCode => Object.hash(communityId, isLive, voiceRoomId);
}

final class CommunityVoiceLiveController extends Notifier<CommunityVoiceLive?>
    with CommunitySingleFlight {
  @override
  CommunityVoiceLive? build() {
    nextGeneration();
    // Principal-scoped, like every other voice read: a sign-out takes the
    // answer with it rather than carrying it into the next account.
    ref.watch(voiceRoomGatewayProvider);
    ref.onDispose(nextGeneration);
    return null;
  }

  /// Reads `GET …/voice-rooms/current` once for [communityId].
  Future<void> read(String communityId) => single(() async {
    final generation = nextGeneration();
    try {
      final current = await ref
          .read(voiceRoomGatewayProvider)
          .loadCurrent(communityId);
      if (!isCurrent(generation)) return;
      state = CommunityVoiceLive(
        communityId: communityId,
        isLive: current.isLive,
        voiceRoomId: current.snapshot?.room.voiceRoomId,
      );
    } catch (_) {
      // A read that did not finish says nothing. The page keeps the row it
      // was opened with.
    }
  });
}

final communityVoiceLiveControllerProvider =
    NotifierProvider.autoDispose<
      CommunityVoiceLiveController,
      CommunityVoiceLive?
    >(CommunityVoiceLiveController.new);

final voiceRoomOpenControllerProvider =
    NotifierProvider.autoDispose<VoiceRoomOpenController, bool>(
      VoiceRoomOpenController.new,
    );
