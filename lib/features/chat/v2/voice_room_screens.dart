import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/time/loop_foreground_poll.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/active_voice_media.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_voice_room_page.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_link.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_presentation.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_retry.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_share.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_stage.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/loop_id_share.dart';
import 'package:loop_mobile/features/square/live_voice_rooms.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/sharing/system_text_share.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

export 'package:loop_mobile/features/chat/v2/voice_room_stage.dart'
    show
        VoiceRoomListenerGrid,
        VoiceRoomSpeakerGrid,
        showVoiceRoomStartSheet,
        voiceRoomListenerGridLimit,
        voiceRoomStartTitle;

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

  /// The call view's microphone, drawn in the room's bottom bar (decision
  /// 0115). Only the main room view hands it over; the full list keeps the
  /// control in the call view itself.
  final VoiceMicrophoneBridge _microphone = VoiceMicrophoneBridge();

  /// Whether the plaza list was already read again for this page's room.
  var _plazaRefreshed = false;
  VoiceRoomPagePresence? _presence;
  var _entered = false;

  /// The provider's own account of the room changing, while this device holds
  /// a call for it.
  ///
  /// Everything on this page that moves because of somebody else — how many
  /// are in the room, who is on the list, who raised a hand — was read once
  /// and never again. The provider tells a connected device the moment any of
  /// them changes (decision 0069), and each of those cues is answered with the
  /// LOOP read that owns the answer. Nothing here is composed out of an event.
  StreamSubscription<AudioRoomRoomSignal>? _signals;
  AudioRoomCallHandle? _signalSource;

  /// The floor under the cues above, for a device that is not connected — a
  /// member who joined in LOOP and whose audio has not come up, or a provider
  /// connection that dropped. Fifteen seconds is the contract's own floor for
  /// this read (decision 0069); the cues are what make the page answer in
  /// seconds.
  late final LoopForegroundPoll _livePoll = LoopForegroundPoll(
    interval: const Duration(seconds: 15),
    read: _readLiveRoom,
  );

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
    _livePoll.stop();
    unawaited(_signals?.cancel());
    _signals = null;
    _signalSource = null;
    // A page that was closed some other way than a pop — the whole shell
    // going down, an account change — still gives the count back. Riverpod
    // refuses a write from a life-cycle callback, so this one waits a
    // microtask; the pop path below does not have to.
    _releasePresence(immediate: false);
    _presence = null;
    _microphone.dispose();
    super.dispose();
  }

  /// Gives the banner back the moment the reader asked to leave this page.
  ///
  /// Waiting for `dispose` meant waiting for the whole pop transition: the
  /// community page underneath appeared with no strip on it, and for a second
  /// or so a reader who was still in a room was shown a screen that said
  /// nothing about it. The pop is the decision; the animation is not.
  void _releasePresence({required bool immediate}) {
    final presence = _presence;
    if (!_entered || presence == null) return;
    _entered = false;
    if (immediate) {
      _lowerPresence(presence);
      return;
    }
    scheduleMicrotask(() => _lowerPresence(presence));
  }

  static void _lowerPresence(VoiceRoomPagePresence presence) {
    try {
      presence.exit();
    } catch (_) {
      // The container can be torn down before the page is; the banner goes
      // with it either way.
    }
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
    // Decision 0115: the room view lays out the speakers and the listeners
    // both, so both views are read on both pages — the same reads the full
    // list takes, no new kind of request. Each view is asked for once; the
    // controller holds the in-flight guard, so a rebuild does not re-ask.
    if (snapshot != null) {
      for (final view in VoiceRoomRosterView.values) {
        if (state.roster(view).phase == CommunityViewPhase.loading) {
          scheduleMicrotask(() {
            if (mounted) unawaited(controller.loadRoster(view));
          });
        }
      }
    }
    // The provider session is asked for the moment this page opens, not after
    // the room read and the join have both come back.
    //
    // 「正在准备语音连接」 stood on the review device for twenty to thirty
    // seconds after a room was created (walkthrough 2026-09-23 · a34). That
    // step — the LOOP identity, `POST /v2/video/token`, and the provider's own
    // connection — needs nothing from the room, and it used to start only
    // when the media surface mounted, which is after `GET …/current` and
    // after the join. Watched here it runs beside them. It joins no call and
    // opens no microphone; that still happens only inside the media surface.
    if (!blocked) ref.watch(streamVideoAuthorizationProvider);
    // A room that is being shown is a room that keeps being read: the cues
    // from this device's own call, and a floor under them for a device that
    // holds no call at all.
    _bindSignals(ref.watch(activeVoiceMediaProvider));
    if (snapshot != null && !blocked) {
      _livePoll.start();
    } else {
      _livePoll.stop();
    }
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _releasePresence(immediate: true);
      },
      child: _buildPage(context, capability, mode, state, controller, id),
    );
  }

  /// Listens to the call this device holds, and only to that one.
  void _bindSignals(AudioRoomCallHandle? call) {
    if (identical(call, _signalSource)) return;
    unawaited(_signals?.cancel());
    _signals = null;
    _signalSource = call;
    if (call == null) return;
    _signals = call.roomSignals.listen(
      _onRoomSignal,
      onError: (Object _, StackTrace _) {
        // A cue that did not arrive says nothing; the floor below still
        // reads the room.
      },
    );
  }

  /// Answers one provider cue with the LOOP read that owns the answer.
  void _onRoomSignal(AudioRoomRoomSignal signal) {
    if (!mounted) return;
    switch (signal) {
      case AudioRoomRoomSignal.handRaise:
        // Decision 0069: the event says the queue moved and carries no
        // identity at all, so who it was comes from the queue itself.
        unawaited(
          ref.read(voiceRoomControllerProvider.notifier).refreshHandRaises(),
        );
      case AudioRoomRoomSignal.participants:
        // Through the poll, so this read is the one the fifteen seconds are
        // counted from and a burst of cues is one read rather than four
        // requests per cue.
        _livePoll.readNow();
    }
  }

  /// Reads everything about this room that somebody else can change.
  ///
  /// The room record carries the head counts, the queue is the host's own
  /// read, and the rosters are the session page's. Each keeps its own failure:
  /// a read that did not finish leaves that part of the page as it was.
  Future<void> _readLiveRoom() async {
    if (!mounted) return;
    final controller = ref.read(voiceRoomControllerProvider.notifier);
    await controller.refreshRoom();
    if (!mounted) return;
    await controller.refreshHandRaises();
    if (!mounted) return;
    // Both rosters are on both pages (decision 0115), so both are read again.
    for (final view in VoiceRoomRosterView.values) {
      if (!mounted) return;
      await controller.loadRoster(view);
    }
  }

  Future<void> _share(BuildContext context, VoiceRoomRecord room) async {
    final title = voiceRoomTitle(room.communityName, title: room.title);
    final text = voiceRoomShareText(
      communityName: room.communityName,
      roomTitle: title,
      link: voiceRoomShareLink(
        ref.read(loopIdLinkBaseUrlProvider),
        room.communityId,
      ),
    );
    final shared = await ref.read(loopTextShareProvider)(text, subject: title);
    if (shared || !context.mounted) return;
    LoopToast.show(context, message: '无法打开分享', kind: LoopToastKind.warn);
  }

  Widget _buildPage(
    BuildContext context,
    LoopCapabilityProjection capability,
    CommunityGatewayMode mode,
    VoiceRoomPageState state,
    VoiceRoomController controller,
    String? id,
  ) {
    final snapshot = state.snapshot;
    final evidencePending =
        mode != CommunityGatewayMode.preview && capability.evidencePending;
    // A room this page read as over leaves the community page underneath
    // holding the read it took before that happened.
    final back = _backFrom(state);
    // Decision 0115: a live room on the main view is the DeBox layout — the
    // host on a stage, the speakers, the listeners and a fixed control bar.
    // Every other answer (no room, a room that ended, a closed capability)
    // keeps the hero that says which of them it is.
    if (!widget.expanded &&
        snapshot != null &&
        snapshot.room.isLive &&
        id != null &&
        !evidencePending &&
        !communityCapabilityBlocks(mode, capability)) {
      return _buildStage(
        context,
        mode: mode,
        state: state,
        controller: controller,
        snapshot: snapshot,
        communityId: id,
        back: back,
      );
    }
    return LoopDashboardPage(
      key: ValueKey<String>(
        widget.expanded ? 'voiceroom-full-screen' : 'voiceroom-screen',
      ),
      archetype: LoopPageArchetype.listing,
      // The room resource names its own community (decision 0052), so the
      // title says which room this is instead of the word for all of them.
      title: snapshot == null
          ? '语音房'
          : voiceRoomTitle(
              snapshot.room.communityName,
              title: snapshot.room.title,
            ),
      kicker: communityPreviewKicker(mode),
      // `#scr-voiceroom .topbar` carries `● 进行中 · 3,241 在线 · 12 人发言`
      // under the room's name.
      subtitle: voiceRoomTopbarLine(snapshot),
      framedTools: true,
      onBack: back,
      actions: <Widget>[
        // Decision 0105 · 4: the same share control as 我的 (decision 0104),
        // and only for a room that is live — a link to an ended room would
        // open onto 「语音房已结束」.
        if (snapshot != null && snapshot.room.isLive)
          LoopIconButton(
            key: const ValueKey<String>('voiceroom-share'),
            icon: 'share',
            label: '分享语音房',
            onPressed: () => unawaited(_share(context, snapshot.room)),
          ),
        // Decision 0115: every note about the provider is in (i).
        if (snapshot != null) _infoButton(context, snapshot),
      ],
      primary: LoopFolioPrimary(
        // `#scr-voiceroom` and `#scr-voiceroom-full` are Chalk pages, and
        // their heading is a figure — `PEPE 语音房 · 13 人`, `13 人在麦上` —
        // not the word for all voice rooms (audit 2026-09-20 · B.8 / D-1).
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.listing,
        ring: false,
        kicker: widget.expanded ? 'VOICE SESSION' : 'VOICE LOBBY',
        heading: voiceRoomHeading(
          snapshot,
          phase: state.phase,
          expanded: widget.expanded,
        ),
        // The hero and the block below it answer the same question, so they
        // are written from the same two facts: what was read, and what it
        // said. 「语音房状态读不到」 stood above 「当前没有进行中的语音房」 on
        // the review device — one screen claiming both that it knows and that
        // it does not.
        caption: voiceRoomCaption(snapshot, phase: state.phase),
        stamp: voiceRoomStamp(snapshot, expanded: widget.expanded),
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
            // Three different answers used to share one sentence about a
            // list this page never named: LOOP closed the room type, LOOP
            // was never asked, and the ask did not get through. Only the
            // last one is worth another try where the reader stands, and a
            // host who has just opened a room lands here often enough that
            // it has to say which of the three it is.
            reason: capability.unreachable
                ? '这台设备没能读到语音房的开放状态，请检查网络后重试。'
                : capability.reasonCode == null
                ? '这次还没有读到语音房的开放状态，请稍后再试。'
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
          if (snapshot.viewer.hasJoined && snapshot.room.isJoinable)
            if (!snapshot.room.audioOpen)
              // The room is live in LOOP and not open on the provider's side.
              // Connecting anyway is the refusal the review device met three
              // times; the reader is told what is true and given the one
              // thing that can change it — a read, which the server takes as
              // its own cue to open the room again.
              LoopEmpty(
                key: const ValueKey<String>('voiceroom-media-backstage'),
                icon: 'warn',
                message: '这个房间还没有开放收听',
                // One fact, one next step. The fact is the server's own when
                // it named which write is unconfirmed, and the next step is
                // the button below — so it is not said twice.
                reason: snapshot.providerSync.confirmed
                    ? '这里不会发起语音连接。刷新一次，或让主持人重新开启。'
                    : communicationUnavailableReason(
                        snapshot.providerSync.reason,
                      ),
                action: LoopButton(
                  key: const ValueKey<String>(
                    'voiceroom-media-backstage-retry',
                  ),
                  label: state.busy ? '正在刷新…' : '刷新',
                  onPressed: state.busy
                      ? null
                      : () => unawaited(controller.refreshRoom()),
                ),
              )
            else
              _MediaSection(
                roomId: snapshot.room.roomId,
                viewerRole: audioRoomViewerRole(snapshot.viewer.role),
                link: _mediaLink,
                // The full list has no bar: the microphone and the hang-up
                // stay in the call view, and only its tiles are dropped.
                microphone: null,
                // The hang-up inside the call view is the same single exit as
                // the page's own: dropping the audio alone would leave this
                // account a member of a room it can no longer hear. For a host
                // that exit is 结束房间 — the server has no 离开 for the host.
                onExitRequested: () => snapshot.viewer.isHost
                    ? _endRoom(controller)
                    : _leave(controller),
                // 决策 0053: opening the microphone is the device's; taking
                // LOOP's mute mark back off this account's row is the server's,
                // and it is only sent when the server published the command.
                onMicrophoneEnabled: () => _clearOwnMuteIntent(controller),
                onReconnectRequested: () => _refreshMediaConnection(controller),
                // A call the provider stopped is not yet an answer: the
                // network may have dropped, or the host may have ended the
                // room. This page owns the room record, so it reads it again
                // and the surface says nothing about the audio until it does.
                onCallStopped: controller.refreshRoom,
              ),
          // `#scr-voiceroom-full`: 发言人 → 举手队列 → 主持人控制 → 控制条.
          // The listener roster is LOOP's own addition — it is where the
          // lobby's 「查看听众名单」 leads — so it follows the prototype's
          // three blocks rather than splitting them.
          if (widget.expanded) ...<Widget>[
            _RosterSection(
              view: VoiceRoomRosterView.speaker,
              state: state,
              // LOOP's speaker roster holds the parts it granted and never
              // the host (decision 0052), so a room whose only voice is the
              // host read as 「当前没有发言人」 while the host was talking.
              // The host's own row is stated here, and the heading counts it.
              leading: _hostSpeakerRow(snapshot),
              onRetry: () =>
                  unawaited(controller.loadRoster(VoiceRoomRosterView.speaker)),
              onLoadMore: () =>
                  controller.loadMoreRoster(VoiceRoomRosterView.speaker),
              onCommand: (member, command) =>
                  _runMemberCommand(controller, member, command),
            ),
            // The queue resource is a host read, so only a host has a figure
            // for it; a listener has its own place and nothing else, and
            // 「举手队列 0」 over 「第 2 位」 would be one more contradiction.
            LoopLabel(
              snapshot.viewer.isHost
                  ? '举手队列 ${state.handRaises.length}'
                  : '举手队列',
            ),
            _HandRaiseQueue(state: state),
            // A host whose only published control is 结束房间 gets no section
            // here: that control lives in the bar below, on both views.
            if (snapshot.viewer.showsHostControls &&
                (snapshot.viewer.canInviteSpeakers ||
                    snapshot.viewer.canMuteAll)) ...<Widget>[
              const LoopLabel('主持人控制'),
              _HostControls(
                state: state,
                onMuteAll: () => _run(controller.muteAll, '已请求全体静音'),
                onInvite: (profileId) =>
                    _run(() => controller.inviteSpeaker(profileId), '已邀请发言'),
              ),
            ],
            _RosterSection(
              view: VoiceRoomRosterView.listener,
              state: state,
              onRetry: () => unawaited(
                controller.loadRoster(VoiceRoomRosterView.listener),
              ),
              onLoadMore: () =>
                  controller.loadMoreRoster(VoiceRoomRosterView.listener),
              onCommand: (member, command) =>
                  _runMemberCommand(controller, member, command),
            ),
          ],
          _ViewerActions(
            state: state,
            // One command: the LOOP grant, and then the connection it
            // authorizes. The media section below mounts itself the moment
            // the membership exists and connects without a second tap.
            onJoin: () => _run(controller.join, '已加入，正在连接语音'),
            onLeave: () => _leave(controller),
            onRaise: () => _raiseHand(controller),
            onCancel: () => _run(controller.cancelHandRaise, '已取消举手'),
            onEnd: () => _endRoom(controller),
            onBack: back,
          ),
          if (state.failureKind != null)
            LoopNotice(
              key: const ValueKey<String>('voiceroom-action-failure'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '上一次操作没有完成',
              body: voiceRoomFailureText(
                state.failureKind,
                state.failureReasonCode,
              ),
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// The room view after DeBox (decision 0115).
  ///
  /// The top bar names the room and the community it belongs to; the page
  /// below it is the host, the speakers and the listeners, and the controls
  /// stand in a bar that does not scroll.
  Widget _buildStage(
    BuildContext context, {
    required CommunityGatewayMode mode,
    required VoiceRoomPageState state,
    required VoiceRoomController controller,
    required VoiceRoomSnapshot snapshot,
    required String communityId,
    required VoidCallback? back,
  }) {
    final room = snapshot.room;
    final viewer = snapshot.viewer;
    final headcount = VoiceRoomHeadcount.of(snapshot);
    final title = voiceRoomTitle(room.communityName, title: room.title);
    final listing = _listing(snapshot);
    final live = _liveSpeakers(snapshot);
    final speakers = state.roster(VoiceRoomRosterView.speaker);
    final listeners = state.roster(VoiceRoomRosterView.listener);
    final host = _hostIdentity(snapshot, listing);
    final openExpanded = widget.onOpenExpanded;
    // Everybody in the room is listening — the host and the speakers too —
    // so the bar's figure is the room's own total, the same one every other
    // figure on these pages adds up to (decision 0115).
    // Decision 0127: 「N 在听 · 开播 x 分钟」, the room's two figures in the
    // bar's grey line.
    final listening = voiceRoomLiveLine(
      inRoom: headcount.inRoom,
      openedAt: room.createdAt,
      now: ref.watch(loopReadClockProvider)(),
    );
    ValueChanged<VoiceRoomMember>? openMember;
    if (!state.busy) {
      openMember = (member) => unawaited(_openMember(controller, member));
    }
    final sections = <Widget>[
      CommunityPreviewNotice(mode: mode, resource: '语音房'),
      VoiceRoomHostStage(
        name: host.name,
        avatarRef: host.avatarRef,
        mic: _hostMic(snapshot, live, host.knownName, speakers),
        info: _infoButton(context, snapshot),
      ),
      if (viewer.hasJoined && room.isJoinable)
        if (!room.audioOpen)
          LoopEmpty(
            key: const ValueKey<String>('voiceroom-media-backstage'),
            icon: 'warn',
            message: '这个房间还没有开放收听',
            reason: snapshot.providerSync.confirmed
                ? '这里不会发起语音连接。刷新一次，或让主持人重新开启。'
                : communicationUnavailableReason(snapshot.providerSync.reason),
            action: LoopButton(
              key: const ValueKey<String>('voiceroom-media-backstage-retry'),
              label: state.busy ? '正在刷新…' : '刷新',
              onPressed: state.busy
                  ? null
                  : () => unawaited(controller.refreshRoom()),
            ),
          )
        else
          _MediaSection(
            roomId: room.roomId,
            viewerRole: audioRoomViewerRole(viewer.role),
            link: _mediaLink,
            microphone: _microphone,
            onExitRequested: () =>
                viewer.isHost ? _endRoom(controller) : _leave(controller),
            onMicrophoneEnabled: () => _clearOwnMuteIntent(controller),
            onReconnectRequested: () => _refreshMediaConnection(controller),
            onCallStopped: controller.refreshRoom,
          ),
      if (!viewer.hasJoined && !room.isJoinable)
        const LoopEmpty(
          key: ValueKey<String>('voiceroom-not-joinable'),
          icon: 'warn',
          message: '这个房间还不能加入',
          reason: '服务商还没有确认这个房间已经就绪，加入会被拒绝。请稍后刷新再试。',
        ),
      LoopLabel('发言者 ${snapshot.participants.speakerCount}'),
      VoiceRoomSpeakerGrid(
        roster: speakers,
        live: live,
        onRetry: () =>
            unawaited(controller.loadRoster(VoiceRoomRosterView.speaker)),
        onOpenMember: openMember,
      ),
      LoopLabel('听众 ${headcount.listening}'),
      VoiceRoomListenerGrid(
        roster: listeners,
        total: headcount.listening,
        onRetry: () =>
            unawaited(controller.loadRoster(VoiceRoomRosterView.listener)),
        onMore: openExpanded == null ? null : () => openExpanded(communityId),
        onOpenMember: openMember,
      ),
      if (viewer.isHost && !viewer.canEndRoom)
        const LoopEmpty(
          key: ValueKey<String>('voiceroom-host-no-leave'),
          icon: 'warn',
          message: '现在不能结束房间',
          reason: '「结束房间」这次读不到，请稍后再试。返回会把房间收起在顶部。',
        ),
      if (state.failureKind != null)
        LoopNotice(
          key: const ValueKey<String>('voiceroom-action-failure'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '上一次操作没有完成',
          body: voiceRoomFailureText(
            state.failureKind,
            state.failureReasonCode,
          ),
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        ),
      const SizedBox(height: 20),
    ];
    final bar = VoiceRoomControlBar.shows(snapshot)
        ? VoiceRoomControlBar(
            snapshot: snapshot,
            busy: state.busy,
            microphone: _microphone,
            pendingHands: state.handRaises
                .where((entry) => entry.handRaise.isPending)
                .length,
            onJoin: () => unawaited(_run(controller.join, '已加入，正在连接语音')),
            onLeave: () => unawaited(_leave(controller)),
            onRaise: () => unawaited(_raiseHand(controller)),
            onCancel: () =>
                unawaited(_run(controller.cancelHandRaise, '已取消举手')),
            onEnd: () => unawaited(_endRoom(controller)),
            onMuteAll: () => unawaited(_run(controller.muteAll, '已请求全体静音')),
            onStepDown: () => unawaited(_stepDown(controller)),
            onInvite: openExpanded == null
                ? null
                : () => openExpanded(communityId),
          )
        : null;
    return Material(
      color: LoopColors.ink,
      child: Column(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: LoopTopbar(
              key: const ValueKey<String>('voiceroom-topbar'),
              title: title,
              kicker: communityPreviewKicker(mode),
              subtitle: room.title == null
                  ? listening
                  : '${room.communityName} · $listening',
              titleMaxLines: 1,
              framedTools: true,
              dense: true,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (back != null) ...<Widget>[
                    LoopIconButton(
                      key: const ValueKey<String>('loop-topbar-back'),
                      icon: 'back',
                      // Going back keeps the account in the room; the strip
                      // at the top brings it back.
                      label: '收起语音房',
                      onPressed: back,
                      framed: true,
                    ),
                    const SizedBox(width: 6),
                  ],
                  CommunityLogo(
                    key: const ValueKey<String>('voiceroom-community-logo'),
                    identity: room.communityId,
                    name: room.communityName,
                    logoRef: listing?.communityLogoRef,
                    size: 36,
                    radius: 10,
                  ),
                ],
              ),
              actions: <Widget>[
                LoopIconButton(
                  key: const ValueKey<String>('voiceroom-share'),
                  icon: 'share',
                  label: '分享语音房',
                  framed: true,
                  onPressed: () => unawaited(_share(context, room)),
                ),
              ],
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: LoopDashboardPage(
                key: const ValueKey<String>('voiceroom-screen'),
                archetype: LoopPageArchetype.listing,
                title: title,
                embedded: true,
                sections: sections,
                bottomBar: bar,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The (i) control. It wears the warning colour while a provider write is
  /// unconfirmed, which is the one note that used to stand in the page.
  Widget _infoButton(
    BuildContext context,
    VoiceRoomSnapshot snapshot, {
    bool framed = false,
  }) {
    final unconfirmed = !snapshot.providerSync.confirmed;
    return LoopIconButton(
      key: const ValueKey<String>('voiceroom-info'),
      icon: 'info',
      label: unconfirmed ? '房间说明，有一项服务商未确认' : '房间说明',
      color: unconfirmed ? LoopColors.warning : null,
      framed: framed,
      onPressed: () => unawaited(
        showVoiceRoomInfoSheet(
          context,
          snapshot: snapshot,
          caption: voiceRoomCaption(snapshot),
          figures: voiceRoomTopbarLine(snapshot),
          providerSyncText: voiceRoomProviderSyncText(
            snapshot.providerSync.reason,
          ),
        ),
      ),
    );
  }

  /// This room's row on the plaza list, when that list was read.
  ///
  /// The room resource names no host — LOOP's roster leaves the host out
  /// (decision 0052) — and carries no community logo. The plaza's projection
  /// of the same room has both, under the same display rule, so the page
  /// reads it once and draws what it says; until it answers, the stage says
  /// 主持人 and the logo is the community's monogram.
  LiveVoiceRoom? _listing(VoiceRoomSnapshot snapshot) {
    final plaza = ref.watch(liveVoiceRoomsControllerProvider);
    if (plaza.phase == CommunityViewPhase.loading && !plaza.refreshing) {
      scheduleMicrotask(() {
        if (!mounted) return;
        unawaited(ref.read(liveVoiceRoomsControllerProvider.notifier).load());
      });
    }
    for (final item in plaza.items) {
      if (item.voiceRoomId == snapshot.room.voiceRoomId) return item;
    }
    // A list read before this room went live does not hold it. It is read
    // again once, never in a loop.
    if (plaza.phase == CommunityViewPhase.ready &&
        !plaza.refreshing &&
        !_plazaRefreshed) {
      _plazaRefreshed = true;
      scheduleMicrotask(() {
        if (!mounted) return;
        unawaited(
          ref.read(liveVoiceRoomsControllerProvider.notifier).refresh(),
        );
      });
    }
    return null;
  }

  /// Who the host is: the room resource's own `host` when the server sends
  /// it (decision 0115), the plaza's projection of the same room when it does
  /// not, and the word 主持人 when neither has answered.
  ({String name, String? avatarRef, String? knownName}) _hostIdentity(
    VoiceRoomSnapshot snapshot,
    LiveVoiceRoom? listing,
  ) {
    final String? named;
    final String? avatarRef;
    final bool known;
    final own = snapshot.host;
    if (own != null) {
      named = own.displayName;
      avatarRef = own.avatarRef;
      known = true;
    } else if (listing != null) {
      named = listing.host.displayName;
      avatarRef = listing.host.avatarRef;
      known = true;
    } else {
      named = null;
      avatarRef = null;
      known = false;
    }
    if (snapshot.viewer.isHost) {
      return (
        name: named == null ? '我' : '我 · $named',
        avatarRef: avatarRef,
        knownName: named,
      );
    }
    if (!known) return (name: '主持人', avatarRef: null, knownName: null);
    return (
      name:
          named ?? voiceRoomDisplayKeyText('voiceRoom.member.anonymousMember'),
      avatarRef: named == null ? null : avatarRef,
      knownName: named,
    );
  }

  /// What the call this device holds says about the host.
  ///
  /// When the reader is the host, the host is this device's own participant
  /// and the answer is certain. Otherwise the host is matched only by the
  /// name the room (or the plaza) gives it: exactly one voice in the call
  /// with that name, and no speaker on LOOP's roster sharing it. A host this
  /// page cannot name, a roster not read yet, or a name that does not match
  /// exactly once claims nothing.
  VoiceRoomMicState _hostMic(
    VoiceRoomSnapshot snapshot,
    List<AudioRoomSpeaker>? live,
    String? hostName,
    VoiceRoomRosterState speakers,
  ) {
    if (live == null) return VoiceRoomMicState.unknown;
    if (snapshot.viewer.isHost) {
      for (final speaker in live) {
        if (speaker.isLocal) {
          return VoiceRoomMicState(open: true, speaking: speaker.isSpeaking);
        }
      }
      return const VoiceRoomMicState(open: false, speaking: false);
    }
    // An empty roster was read too: it is a fact that nobody shares the name.
    final rosterRead =
        speakers.phase == CommunityViewPhase.ready ||
        speakers.phase == CommunityViewPhase.empty;
    if (hostName == null || !rosterRead) {
      return VoiceRoomMicState.unknown;
    }
    for (final member in speakers.items) {
      if (voiceRoomRosterName(member) == hostName) {
        return VoiceRoomMicState.unknown;
      }
    }
    final matches = <AudioRoomSpeaker>[
      for (final speaker in live)
        if (!speaker.isLocal && speaker.name == hostName) speaker,
    ];
    if (matches.length != 1) return VoiceRoomMicState.unknown;
    return VoiceRoomMicState(open: true, speaking: matches.single.isSpeaking);
  }

  /// Opens the server's commands for one face on a grid.
  Future<void> _openMember(
    VoiceRoomController controller,
    VoiceRoomMember member,
  ) async {
    if (member.commands.isEmpty) return;
    final chosen = await chooseVoiceRoomMemberCommand(context, member);
    if (chosen == null || !mounted) return;
    await _runMemberCommand(controller, member, chosen);
  }

  /// 下麦: this account's own step-down to listener (decision 0115,
  /// `DELETE /v2/voice-rooms/{id}/speakers/me`).
  ///
  /// The answer is the room resource, so the role on the page — and the bar
  /// with it — follows the server. A server that does not serve the command
  /// yet says so; nothing is shown as done that was not.
  Future<void> _stepDown(VoiceRoomController controller) async {
    final failure = await controller.stepDown();
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: '已下麦，回到听众');
      for (final view in VoiceRoomRosterView.values) {
        unawaited(controller.loadRoster(view));
      }
      return;
    }
    LoopToast.show(
      context,
      message:
          failure == CommunityFailureKind.notFound ||
              failure == CommunityFailureKind.unavailable
          ? '下麦暂不可用'
          : voiceRoomFailureText(
              failure,
              ref.read(voiceRoomControllerProvider).failureReasonCode,
            ),
      kind: LoopToastKind.warn,
    );
  }

  /// The host's own row at the top of `发言人`, which LOOP's roster has not
  /// got.
  ///
  /// `GET …/members` lists the parts LOOP granted and the host is in neither
  /// view (decision 0052), so a room whose only voice was the host printed
  /// 「当前没有发言人」 while the host was talking — and the heading above it
  /// counted a person the list did not show. The row states the one thing
  /// that is certain about a live room: it has a host. Who that host is, is
  /// only known here when it is the reader.
  LoopRecordRow? _hostSpeakerRow(VoiceRoomSnapshot snapshot) {
    if (!snapshot.room.isLive) return null;
    final isSelf = snapshot.viewer.isHost;
    final name = isSelf ? '我' : '主持人';
    // Whether the host's microphone is open is the call's answer, and this
    // device only holds the call when the reader is the host.
    var speaking = false;
    var open = false;
    final heard = isSelf ? _liveSpeakers(snapshot) : null;
    for (final speaker in heard ?? const <AudioRoomSpeaker>[]) {
      if (!speaker.isLocal) continue;
      open = true;
      speaking = speaker.isSpeaking;
    }
    return LoopRecordRow(
      key: const ValueKey<String>('voiceroom-speaker-host'),
      leading: LoopInitialsAvatar(label: name),
      title: name,
      subtitle: speaking
          ? '主持人 · 发言中'
          : open
          ? '主持人 · 麦克风已开'
          : '主持人',
      trailingBadge: speaking
          ? const LoopBadge('发言中', kind: LoopBadgeKind.up)
          : null,
      chevron: false,
      position: LoopRowPosition.first,
    );
  }

  /// What this device's own call hears in this room, when it holds one.
  ///
  /// A call for another room, or a connection that is not up, answers
  /// nothing: the grid then falls back to LOOP's record, which says what it
  /// is a record of.
  List<AudioRoomSpeaker>? _liveSpeakers(VoiceRoomSnapshot snapshot) {
    final live = ref.watch(audioRoomLivePresenceProvider);
    if (live == null ||
        live.roomId != snapshot.room.roomId ||
        !live.connected) {
      return null;
    }
    return live.speakers;
  }

  /// The way back, with the community page told what this page just read.
  ///
  /// 「返回社区」 from a room the host ended landed on a community page that
  /// still said 「当前有进行中的语音房」 with a way in, because that row is the
  /// read that page took before the room was over. The reader was told the
  /// room ended and then shown a door into it. The row is dropped on the way
  /// out, so the page reads it again; nothing is assumed about the answer,
  /// and a room that is still running needs no second read at all.
  VoidCallback? _backFrom(VoiceRoomPageState state) {
    final back = widget.onBack;
    if (back == null) return null;
    return () {
      final snapshot = state.snapshot;
      if (snapshot == null || !snapshot.room.isLive) {
        _refreshCommunityProfile();
      }
      back();
    };
  }

  /// Reads the room and the provider session again for a second attempt.
  ///
  /// A refused connection is held by the call this device already made, and
  /// asking that one again sends nothing at all. Both halves of the
  /// authorization are taken again: `GET /v2/voice-rooms/{id}` says whether
  /// the room is still there and under which provider call, and retiring the
  /// video session makes the next authorization fetch a token and build a
  /// client — and therefore a call — that has not been refused.
  Future<void> _refreshMediaConnection(VoiceRoomController controller) {
    return refreshVoiceMediaSession(
      ref,
      refreshRoom: controller.refreshRoom,
      stillMounted: () => mounted,
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
    final CommunityFailureKind? failure;
    try {
      failure = await controller.leave();
    } finally {
      // The media surface is showing this departure. A leave that went
      // through has already taken it off the screen; a leave the server
      // refused leaves it mounted, and it must stop saying 「正在离开」.
      _mediaLink.exitSettled();
    }
    if (!mounted) return;
    // A room that ended while the reader was leaving it refuses every write,
    // including this one (decision 0069). There is nothing left to leave and
    // nothing left on this page, so it says what happened and goes back.
    if (failure == CommunityFailureKind.stale) {
      // The membership went with the room, and the strip is the only sign
      // the account was in one: left standing it offers a way back into a
      // room that is gone.
      final communityId = widget.communityId;
      if (communityId != null) {
        ref.read(voiceRoomSessionProvider.notifier).leave(communityId);
      }
      LoopToast.show(
        context,
        message: '房间已结束 · 主持人已经结束这个语音房',
        kind: LoopToastKind.warn,
      );
      _refreshCommunityProfile();
      widget.onBack?.call();
      return;
    }
    LoopToast.show(
      context,
      message: failure != null
          ? voiceRoomFailureText(
              failure,
              ref.read(voiceRoomControllerProvider).failureReasonCode,
            )
          : disconnected
          ? '已离开语音房'
          : '已离开语音房，语音连接的收尾没有确认',
      kind: failure != null ? LoopToastKind.warn : LoopToastKind.ok,
    );
    _refreshCommunityProfile();
  }

  /// Makes the community page read its voice room row again.
  ///
  /// That row is the community page's own read, taken when it was opened. A
  /// reader who ends a room and goes back arrives at the page that was read
  /// before the room ended, and it said 「当前有进行中的语音房」 with a way in.
  /// The row is dropped here so the page reads it again when it is next
  /// shown; nothing is assumed about what the answer will be.
  void _refreshCommunityProfile() {
    if (!mounted) return;
    final profile = ref.read(communityProfileControllerProvider.notifier);
    if (profile.communityId != widget.communityId) return;
    unawaited(profile.reload());
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
              '对方的设备仍可能自行开麦；之后可以在这一行取消。',
        VoiceRoomMemberCommand.unmute =>
          '目标：$name。只撤回 LOOP 侧的静音意图，'
              '不会替对方打开麦克风——开麦只能由对方的设备完成。',
        VoiceRoomMemberCommand.unmuteSelf =>
          '这是你自己的发言人行。只撤回 LOOP 侧的静音标记，'
              '不会打开麦克风——请在通话里自己开麦。',
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
        VoiceRoomMemberCommand.unmute => '已取消静音意图',
        VoiceRoomMemberCommand.unmuteSelf => '已取消我的静音标记',
      },
    );
  }

  /// Takes LOOP's mute mark off this account's own speaker row once the
  /// device opened the microphone (decision 0053).
  ///
  /// It is silent on success: the reader already heard the microphone open,
  /// and nothing else changed on screen. A row the server published no
  /// `unmute_self` for is not touched at all, so this never reports a failure
  /// for a room that had nothing to clear.
  Future<void> _clearOwnMuteIntent(VoiceRoomController controller) async {
    final failure = await controller.clearOwnMuteIntent();
    if (!mounted || failure == null) return;
    LoopToast.show(
      context,
      message:
          '麦克风已打开，但名单上的静音标记没能撤回：'
          '${communityFailureReason(failure)}',
      kind: LoopToastKind.warn,
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
    try {
      await _run(
        controller.endRoom,
        disconnected ? '房间已结束' : '房间已结束，语音连接的收尾没有确认',
      );
    } finally {
      _mediaLink.exitSettled();
    }
    _refreshCommunityProfile();
  }

  /// Raises this account's hand, and says whether the room was told.
  ///
  /// The queue entry is LOOP's, and the host learns about it from a provider
  /// event the server sends after it (decision 0069). Those are two different
  /// answers: a hand that is recorded and a host who was told. When the event
  /// did not go out the reader is told so here, because the next thing they
  /// will do is wait.
  Future<void> _raiseHand(VoiceRoomController controller) async {
    final failure = await controller.raiseHand();
    if (!mounted) return;
    if (failure != null) {
      LoopToast.show(
        context,
        message: voiceRoomFailureText(
          failure,
          ref.read(voiceRoomControllerProvider).failureReasonCode,
        ),
        kind: LoopToastKind.warn,
      );
      return;
    }
    final sync = controller.lastCommandSync;
    if (sync != null && !sync.confirmed) {
      LoopToast.show(
        context,
        message: voiceRoomProviderSyncText(sync.reason),
        kind: LoopToastKind.warn,
      );
      return;
    }
    LoopToast.show(context, message: '已举手，等待主持人邀请');
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
      message: voiceRoomFailureText(
        failure,
        ref.read(voiceRoomControllerProvider).failureReasonCode,
      ),
      kind: LoopToastKind.warn,
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
    required this.viewerRole,
    required this.link,
    required this.microphone,
    required this.onExitRequested,
    required this.onMicrophoneEnabled,
    required this.onReconnectRequested,
    required this.onCallStopped,
  });

  final String? roomId;

  /// The part LOOP granted this account, so the surface's own sentence about
  /// the microphone and about the way out matches the controls on screen.
  final AudioRoomViewerRole? viewerRole;
  final VoiceMediaLink link;

  /// Where the call view hands its microphone (the room view's bottom bar),
  /// or null to keep it, with the hang-up, in the call view.
  final VoiceMicrophoneBridge? microphone;
  final Future<void> Function() onExitRequested;

  /// Runs before a second connection attempt: the room and the provider
  /// session are read again, so the attempt is not the refused one repeated.
  final Future<void> Function() onReconnectRequested;

  /// Runs after the device opened the microphone. The page uses it to clear
  /// the LOOP-side mute intent on its own roster row; it opens nothing.
  final Future<void> Function() onMicrophoneEnabled;

  /// Runs once a call stopped on its own, before the surface says anything
  /// about it: the page reads the room again, and the room says whether the
  /// audio can come back at all.
  final Future<void> Function() onCallStopped;

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
    // Decision 0115: the call's own tiles are gone from the room page — who
    // is on the microphone is the host stage and the speaker grid, which
    // still read this call's speakers. What is left is the audio and its
    // controls.
    return KeyedSubtree(
      key: const ValueKey<String>('voiceroom-media'),
      child: VoiceMediaPresentation(
        microphone: microphone,
        child: StreamVoiceRoomPage(
          target: target,
          viewerRole: viewerRole,
          inline: true,
          // A member who was let in expects to hear the room. The connection is
          // part of 加入, not a second decision, so it starts on its own — still
          // muted, still without asking for the microphone permission.
          autoConnect: true,
          link: link,
          onExitRequested: onExitRequested,
          onMicrophoneEnabled: onMicrophoneEnabled,
          onReconnectRequested: onReconnectRequested,
          onCallStopped: onCallStopped,
        ),
      ),
    );
  }
}

/// The refusals the server names for a room that is not open yet.
///
/// A join the provider refused because the room has not gone live comes back
/// as one more 「暂时不可用」 unless the name travels with it: the reader is
/// told the module is down when the room simply has not been opened. Only
/// codes this client has a sentence for are recognised; anything else keeps
/// the sentence for its class.
const _voiceRoomNamedRefusals = <String>{
  'VOICE_ROOM_BACKSTAGE_NOT_LIVE',
  'STREAM_CALL_GO_LIVE_UNCONFIRMED',
  'STREAM_CALL_CREATE_UNCONFIRMED',
  'STREAM_CALL_EVENT_UNCONFIRMED',
  'COMMUNITY_VOICE_ROOM_NOT_LIVE',
};

/// What to say about a command the server refused.
String voiceRoomFailureText(CommunityFailureKind? kind, String? reasonCode) =>
    reasonCode != null && _voiceRoomNamedRefusals.contains(reasonCode)
    ? communicationUnavailableReason(reasonCode)
    : communityFailureReason(kind);

/// What the host is told when the room was opened and cannot be entered.
///
/// Two sentences, both in the host's own terms: what is missing, and the one
/// thing that finishes it. The shared `reasonCode` copy is written for whoever
/// is looking at a room — 「刷新一次，或让主持人重新开启」 tells the host to ask
/// themselves — so the host's own moment has its own words.
String voiceRoomOpenUnfinishedText(String? reasonCode) => switch (reasonCode) {
  'STREAM_CALL_CREATE_UNCONFIRMED' => '语音房记下了，但通话还没有建好。再点一次「开启语音房」可以接着建。',
  'STREAM_CALL_GO_LIVE_UNCONFIRMED' => '语音房建好了，但还没有开放收听。再点一次「开启语音房」可以重试。',
  _ => '语音房还没有准备好，现在谁都进不去。再点一次「开启语音房」可以重试。',
};

/// What an unconfirmed provider write means for the reader.
String voiceRoomProviderSyncText(String? reasonCode) =>
    reasonCode != null &&
        (_voiceRoomNamedRefusals.contains(reasonCode) ||
            reasonCode == 'STREAM_CALL_MUTE_UNCONFIRMED')
    ? communicationUnavailableReason(reasonCode)
    : 'LOOP 已经提交这次变更，服务商还没有确认结果。请稍后刷新查看最新状态。';

/// The part this account plays, as the media surface needs to hear it.
///
/// LOOP's role is the only source: the surface derives nothing from the call
/// and grants nothing. A viewer with no role is not in the room, and the
/// surface keeps the listener's sentence for it.
AudioRoomViewerRole? audioRoomViewerRole(VoiceRoomRole? role) => switch (role) {
  VoiceRoomRole.host => AudioRoomViewerRole.host,
  VoiceRoomRole.speaker => AudioRoomViewerRole.speaker,
  VoiceRoomRole.listener => AudioRoomViewerRole.listener,
  null => null,
};

/// What one roster row is called, under the server's display rule.
///
/// A member with anonymous mode on is the server's anonymous label to every
/// other reader, and its own alias to itself; this client never assembles a
/// name from an identifier.
String voiceRoomMemberName(VoiceRoomMember member) =>
    voiceRoomDisplayName(member.name, isSelf: member.isSelf);

/// The same projection for a hand-raise row (decision 0053): the queue names a
/// member exactly the way the roster does.
String voiceRoomDisplayName(VoiceRoomMemberName name, {required bool isSelf}) =>
    switch (name) {
      VoiceRoomMemberAlias(alias: final alias) => isSelf ? '我 · $alias' : alias,
      VoiceRoomMemberAnonymousName(labelKey: final key) =>
        voiceRoomDisplayKeyText(key),
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
    this.leading,
  });

  final VoiceRoomRosterView view;
  final VoiceRoomPageState state;

  /// A row the server's roster does not carry — the host's own — drawn above
  /// the page LOOP read. A view with one of these is never empty.
  final LoopRecordRow? leading;
  final VoidCallback onRetry;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(
    VoiceRoomMember member,
    VoiceRoomMemberCommand command,
  )
  onCommand;

  @override
  Widget build(BuildContext context) {
    final roster = state.roster(view);
    final headcount = VoiceRoomHeadcount.of(state.snapshot!);
    final count = view == VoiceRoomRosterView.speaker
        ? headcount.speaking
        : headcount.listening;
    final slug = view.wireName;
    final extra = leading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopLabel('${view.label} $count'),
        if (extra != null && roster.phase == CommunityViewPhase.empty)
          LoopRecordGroup(
            rows: <LoopRecordRow>[_positioned(extra, LoopRowPosition.single)],
          )
        else
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
              pausedActions: const <String>['邀请上麦', '移出发言', '静音', '取消静音'],
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
        // The roster reads on as it comes into view (decision 0129); its end
        // draws nothing (decision 0127).
        if (roster.isReady)
          LoopLoadMoreFooter(
            key: ValueKey<String>('voiceroom-roster-$slug-footer'),
            keyPrefix: 'voiceroom-roster-$slug',
            cursor: roster.nextCursor,
            canLoadMore: roster.canLoadMore,
            loading: roster.loadingMore,
            onLoadMore: onLoadMore,
          ),
      ],
    );
  }

  Widget _rows(BuildContext context, VoiceRoomRosterState roster) {
    final slug = view.wireName;
    final rows = <LoopRecordRow>[
      ?leading,
      for (var index = 0; index < roster.items.length; index += 1)
        _row(
          context,
          roster.items[index],
          key: ValueKey<String>(
            'voiceroom-member-$slug-'
            '${roster.items[index].publicProfileId ?? index}',
          ),
        ),
    ];
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        for (var index = 0; index < rows.length; index += 1)
          _positioned(
            rows[index],
            index == 0
                ? (rows.length == 1
                      ? LoopRowPosition.single
                      : LoopRowPosition.first)
                : index == rows.length - 1
                ? LoopRowPosition.last
                : LoopRowPosition.middle,
          ),
      ],
    );
  }

  /// One row where it happens to fall, so a list that gained a row at the top
  /// still draws one rounded group.
  static LoopRecordRow _positioned(
    LoopRecordRow row,
    LoopRowPosition position,
  ) => LoopRecordRow(
    key: row.key,
    leading: row.leading,
    title: row.title,
    subtitle: row.subtitle,
    trailing: row.trailing,
    trailingBadge: row.trailingBadge,
    subtitleMaxLines: row.subtitleMaxLines,
    chevron: row.chevron,
    onTap: row.onTap,
    position: position,
  );

  LoopRecordRow _row(
    BuildContext context,
    VoiceRoomMember member, {
    required Key key,
  }) {
    final speaking = view == VoiceRoomRosterView.speaker;
    // Only the server's own row commands say the intent can be taken back
    // here; nothing about the mute mark alone promises a way out of it.
    final canUnmute =
        member.commands.contains(VoiceRoomMemberCommand.unmute) ||
        member.commands.contains(VoiceRoomMemberCommand.unmuteSelf);
    // 发言人 carries the mute mark, 听众 the raised hand: each view shows the
    // state that means something in it.
    final badge = speaking
        ? (member.muted
              ? const LoopBadge('已静音', kind: LoopBadgeKind.mute)
              : null)
        : (member.handRaised
              ? const LoopBadge('已举手', kind: LoopBadgeKind.mining)
              : null);
    final name = voiceRoomMemberName(member);
    return LoopRecordRow(
      key: key,
      leading: LoopInitialsAvatar(label: name),
      title: name,
      // `#scr-voiceroom-full .row-s` is one short phrase — 发言中, 已静音,
      // 第 3 位 — not an account of where the mark came from. The state
      // itself is the badge on the right, so the phrase carries what the
      // badge cannot: the way out of a mute this reader can undo.
      subtitle: speaking
          ? (member.muted
                ? (canUnmute ? '点这一行可以取消静音' : '主持人已在 LOOP 侧静音')
                : '可以发言')
          : (member.handRaised ? '等待主持人邀请发言' : '收听中'),
      trailingBadge: badge,
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
    final chosen = await chooseVoiceRoomMemberCommand(context, member);
    if (chosen == null) return;
    await onCommand(member, chosen);
  }
}

/// The sheet of the server's own commands for one roster row: exactly the
/// row's `commands`, and 取消.
Future<VoiceRoomMemberCommand?> chooseVoiceRoomMemberCommand(
  BuildContext context,
  VoiceRoomMember member,
) {
  return showLoopSheet<VoiceRoomMemberCommand>(
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
            '这一行可以执行的操作由服务端逐行下发，这里只列出真正可用的。',
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
            leading: const LoopInitialsAvatar(label: '我'),
            title: '我',
            subtitle: '第 ${own.sequence} 位 · 等待邀请',
            trailingBadge: LoopBadge(own.sequence, kind: LoopBadgeKind.mining),
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
            leading: LoopInitialsAvatar(
              label: voiceRoomDisplayName(
                entries[index].name,
                isSelf: entries[index].isSelf,
              ),
            ),
            title: voiceRoomDisplayName(
              entries[index].name,
              isSelf: entries[index].isSelf,
            ),
            // `#scr-voiceroom-full` 的队列行：序号在前，状态在后.
            subtitle:
                '第 ${entries[index].handRaise.sequence} 位 · '
                '${entries[index].handRaise.isPending ? '等待邀请' : '已邀请'}',
            trailingBadge: LoopBadge(
              entries[index].handRaise.sequence,
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
    required this.onInvite,
  });

  final VoiceRoomPageState state;
  final Future<void> Function() onMuteAll;
  final Future<void> Function(String publicProfileId) onInvite;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot!;
    final busy = state.busy || !snapshot.room.isLive;
    // The invite list is the server's own: a queue row is offered here only
    // when it carries `invite_speaker`, never because the viewer is the host.
    final pending = <VoiceRoomHandRaiseEntry>[
      for (final entry in state.handRaises)
        if (entry.handRaise.isPending &&
            entry.publicProfileId != null &&
            entry.commands.contains(VoiceRoomMemberCommand.inviteSpeaker))
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
                    'voiceroom-invite-${pending[index].publicProfileId}',
                  ),
                  title: voiceRoomDisplayName(
                    pending[index].name,
                    isSelf: pending[index].isSelf,
                  ),
                  subtitle: '邀请其发言',
                  position: index == 0
                      ? LoopRowPosition.first
                      : index == pending.length - 1
                      ? LoopRowPosition.last
                      : LoopRowPosition.middle,
                  onTap: busy
                      ? null
                      : () => unawaited(
                          onInvite(pending[index].publicProfileId!),
                        ),
                ),
            ],
          ),
        // 移出发言 and 静音 live on the speaker rows above, where the server
        // publishes them per member. A hand raise is a *request* to speak,
        // never proof that the account is speaking, so this block never
        // offered a removal against the queue and no longer has to say so.
        // 结束房间 is the host's own way out and travels with the other
        // controls in the bar below, on both views.
        if (snapshot.viewer.canMuteAll)
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('voiceroom-mute-all'),
                label: '全体静音',
                icon: 'voice-off',
                onPressed: busy ? null : () => unawaited(onMuteAll()),
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
    required this.onEnd,
    required this.onBack,
  });

  final VoiceRoomPageState state;
  final Future<void> Function() onJoin;
  final Future<void> Function() onLeave;
  final Future<void> Function() onRaise;
  final Future<void> Function() onCancel;

  /// The host's own exit. `DELETE …/members/me` refuses the host outright, so
  /// the room's life cycle is the only thing the host can end.
  final Future<void> Function() onEnd;

  /// The one way out of a room that has ended. Every other control on this
  /// page belongs to a room that is still running.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot!;
    final viewer = snapshot.viewer;
    final live = snapshot.room.isLive;
    final busy = state.busy || !live;
    if (!live) {
      // A listener whose audio stopped because the host ended the room must
      // not be told 「语音已断开」 and offered 「重新连接语音」: there is no
      // room left to connect to. The room itself says so, and the only thing
      // left to do here is to go back.
      return LoopEmpty(
        key: const ValueKey<String>('voiceroom-ended'),
        message: '房间已结束',
        reason: '主持人已经结束这个语音房。',
        action: onBack == null
            ? null
            : LoopButton(
                key: const ValueKey<String>('voiceroom-ended-back'),
                label: '返回社区',
                onPressed: onBack,
              ),
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
      // life cycle belongs to whoever opened it, so the host's place in the
      // prototype's control bar is 结束房间. Two paragraphs used to stand
      // here saying that the button the host was looking for did not exist.
      if (!viewer.canEndRoom) {
        return const LoopEmpty(
          key: ValueKey<String>('voiceroom-host-no-leave'),
          icon: 'warn',
          message: '现在不能结束房间',
          reason: '「结束房间」这次读不到，请稍后再试。返回会把房间收起在顶部。',
        );
      }
      return LoopButtonPair(
        children: <Widget>[
          LoopButton(
            key: const ValueKey<String>('voiceroom-end'),
            label: '结束房间',
            icon: 'warn',
            onPressed: busy ? null : () => unawaited(onEnd()),
          ),
        ],
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
/// The whole sentence the strip stands for: which room, what part this
/// account plays in it, and what the call is doing or how many are in it.
///
/// The strip itself sets this in two lines, because one line under an
/// ellipsis loses the end of the sentence (R10-1); this is what those two
/// lines say read together, and it is what assistive tech is given.
///
/// The strip used to print 「上次观察 N 人」 — a reading taken at some earlier
/// moment, which on the review device was 「上次观察 0 人」 under a banner
/// saying the reader was in the room.
///
/// The call now outlives the page, so the strip carries what it is doing: a
/// connection that is being made, one that is being put back, and one that
/// stopped each say so. A strip that stated 「N 人已加入」 through all of them
/// was the reason 「稳定态永远是已加入」 had to be the rule — there was nothing
/// else it could know once the page closed.
String voiceRoomBannerLabel({
  required String communityName,
  required VoiceRoomRole role,
  required int? count,
  required AudioRoomLivePhase phase,
}) =>
    '${voiceRoomBannerTitle(communityName)} · '
    '${voiceRoomBannerStatus(role: role, count: count, phase: phase)}';

/// The half of the strip that can be given up: which room this is.
///
/// R10-1: the strip printed the whole sentence on one line under an
/// ellipsis, with the room's name in the middle and the state at the end, so
/// a name of any length ate exactly the part that could not be guessed —
/// 「正在语音房 · Builders Guild · 听众 · 1 …」 on the review device, where the
/// reader could not tell a call that stands from one that stopped. The name
/// is the part a reader can do without, so it is the part that truncates,
/// and it sits alone on the first line.
String voiceRoomBannerTitle(String communityName) => '正在语音房 · $communityName';

/// The half that is never given up: what part this account plays, and what
/// the call is doing or how many are in it.
///
/// Two different figures can end up here, so each is named for what it
/// counts. While this device is in the call the strip carries the call's own
/// head count — the same number the room page prints — and says 「N 人在通话」.
/// Off the call there is only LOOP's record of who joined the room, which
/// counts memberships and not connections, and that says 「N 人已加入」.
String voiceRoomBannerStatus({
  required VoiceRoomRole role,
  required int? count,
  required AudioRoomLivePhase phase,
}) {
  final part = role.label;
  return switch (phase) {
    // Connected without a count yet: the strip says the connection stands and
    // that the number is still coming, never 0.
    AudioRoomLivePhase.connected =>
      count == null ? '$part · 人数正在统计' : '$part · $count 人在通话',
    AudioRoomLivePhase.connecting => '$part · 正在连接语音',
    AudioRoomLivePhase.reconnecting => '$part · 语音正在重连',
    AudioRoomLivePhase.disconnected => '$part · 语音已断开',
    // No call of this device's own: the only figure there is counts
    // memberships, not connections, and it is named for that.
    AudioRoomLivePhase.idle => count == null ? part : '$part · $count 人已加入',
  };
}

class VoiceRoomMinimizedBanner extends ConsumerStatefulWidget {
  const VoiceRoomMinimizedBanner({
    required this.onOpen,
    super.key,
    this.onTabRoute,
  });

  final ValueChanged<String> onOpen;

  /// Whether the reader is on one of the five tab routes, asked at the moment
  /// something has to be said.
  ///
  /// The strip sits above the router, so its own context is above every tab
  /// scope and a toast raised from here would always be placed as if there
  /// were no bar under it. The shell that owns the router answers instead.
  final bool Function()? onTabRoute;

  @override
  ConsumerState<VoiceRoomMinimizedBanner> createState() =>
      _VoiceRoomMinimizedBannerState();
}

class _VoiceRoomMinimizedBannerState
    extends ConsumerState<VoiceRoomMinimizedBanner> {
  /// True once the reader asked to leave from the strip and before the second
  /// tap that means it.
  ///
  /// 离开 ends the membership, so it asks first here exactly as it does on the
  /// room page. The question is asked in the strip itself rather than in the
  /// page's sheet: this widget sits above the router and has no navigator to
  /// put a sheet on.
  var _confirmingExit = false;
  var _leaving = false;
  AudioRoomNotificationBridge? _bridge;

  @override
  void initState() {
    super.initState();
    // The system's ongoing-call notification (Android, decision 0106) asks
    // the two things this strip already knows how to do: open the room, and
    // leave it. The strip is mounted above the router for the whole sign-in,
    // which is exactly as long as the notification can be tapped.
    final bridge = ref.read(audioRoomNotificationBridgeProvider);
    _bridge = bridge;
    bridge
      ..onOpen = _openFromNotification
      ..onLeave = _leaveFromNotification;
  }

  @override
  void dispose() {
    final bridge = _bridge;
    if (bridge != null) {
      if (bridge.onOpen == _openFromNotification) bridge.onOpen = null;
      if (bridge.onLeave == _leaveFromNotification) bridge.onLeave = null;
    }
    super.dispose();
  }

  Future<void> _openFromNotification() async {
    if (!mounted) return;
    final session = ref.read(voiceRoomSessionProvider);
    // Tapping the notification already brought LOOP to the front; a reader
    // who was on the room page is back on it.
    if (session == null || ref.read(voiceRoomPagePresenceProvider) > 0) return;
    widget.onOpen(session.communityId);
  }

  /// The notification's 离开.
  ///
  /// A listener or a speaker leaves the room exactly as from the strip. The
  /// host has no 离开 — the server refuses it, and ending the room for
  /// everybody from a notification without a confirmation is not an answer
  /// to one tap — so for the host it takes this device's audio down and the
  /// room keeps running, with 「重新连接」 on the strip.
  Future<void> _leaveFromNotification() async {
    if (!mounted) return;
    final session = ref.read(voiceRoomSessionProvider);
    if (session == null || session.role == VoiceRoomRole.host) {
      await ref.read(activeVoiceMediaProvider.notifier).retire();
      return;
    }
    await _leave(session);
  }

  @override
  Widget build(BuildContext context) {
    // A room the host ended takes the membership, and this strip, with it.
    // Said only by disappearing, that is a marker the reader last saw a
    // moment ago and cannot account for.
    ref.listen<VoiceRoomEndedNotice?>(voiceRoomEndedNoticeProvider, (
      previous,
      next,
    ) {
      if (next == null || next == previous) return;
      LoopToast.show(
        context,
        message: '房间已结束 · 主持人已经结束这个语音房',
        kind: LoopToastKind.warn,
        clearsTabBar: _clearsTabBar(context),
      );
    });
    final session = ref.watch(voiceRoomSessionProvider);
    final onRoomPage = ref.watch(voiceRoomPagePresenceProvider) > 0;
    if (session == null || onRoomPage) {
      return const SizedBox.shrink();
    }
    // What this device's own call is doing, when it holds one for this room.
    // Otherwise there is only LOOP's record of who joined, which is a
    // different reading of a different thing, and the label says which.
    final live = ref.watch(audioRoomLivePresenceProvider);
    final thisRoom = live != null && live.roomId == session.callRoomId;
    final phase = thisRoom ? live.phase : AudioRoomLivePhase.idle;
    final count = thisRoom && phase == AudioRoomLivePhase.connected
        ? live.participantCount
        : session.joinedCount;
    // The host has no 离开: the room's life cycle belongs to whoever opened
    // it, and the server refuses the command outright.
    final canLeave = session.role != VoiceRoomRole.host;
    return Material(
      key: const ValueKey<String>('voiceroom-minimized-banner'),
      color: LoopColors.lime,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: _leaving ? null : () => widget.onOpen(session.communityId),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.only(left: LoopSpacing.page),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        // R10-1: two lines, and the room's name is the only
                        // thing on the line that may be cut. On one line the
                        // ellipsis fell on the tail, which is where the state
                        // and the head count were, so a long room name left
                        // the reader unable to tell a call that stands from
                        // one that stopped. Assistive tech is handed the
                        // sentence whole.
                        child: Semantics(
                          container: true,
                          excludeSemantics: true,
                          label: voiceRoomBannerLabel(
                            communityName: session.communityName,
                            role: session.role,
                            count: count,
                            phase: phase,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  voiceRoomBannerTitle(session.communityName),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: LoopTypography.withWeight(
                                    LoopTypography.body(
                                      13,
                                      color: LoopColors.ink,
                                    ),
                                    FontWeight.w600,
                                  ),
                                ),
                                // No maxLines and no ellipsis: this line
                                // wraps rather than drop a word of it.
                                Text(
                                  voiceRoomBannerStatus(
                                    role: session.role,
                                    count: count,
                                    phase: phase,
                                  ),
                                  style: LoopTypography.withWeight(
                                    LoopTypography.body(
                                      12,
                                      color: LoopColors.ink,
                                    ),
                                    FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: LoopSpacing.tight),
                      if (canLeave && !_confirmingExit)
                        _BannerAction(
                          key: const ValueKey<String>('voiceroom-banner-leave'),
                          label: '离开',
                          onPressed: () =>
                              setState(() => _confirmingExit = true),
                        ),
                      _BannerAction(
                        key: const ValueKey<String>('voiceroom-banner-open'),
                        // A stopped call is put back by going into the room,
                        // which connects again on its own.
                        label: phase == AudioRoomLivePhase.disconnected
                            ? '重新连接'
                            : '返回房间',
                        onPressed: _leaving
                            ? null
                            : () => widget.onOpen(session.communityId),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_confirmingExit)
              Padding(
                padding: const EdgeInsets.only(
                  left: LoopSpacing.page,
                  bottom: 6,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '离开后你会退出这次通话，举手也会一并取消。',
                        maxLines: 2,
                        style: LoopTypography.body(12, color: LoopColors.ink),
                      ),
                    ),
                    const SizedBox(width: LoopSpacing.tight),
                    _BannerAction(
                      key: const ValueKey<String>(
                        'voiceroom-banner-leave-cancel',
                      ),
                      label: '取消',
                      onPressed: _leaving
                          ? null
                          : () => setState(() => _confirmingExit = false),
                    ),
                    _BannerAction(
                      key: const ValueKey<String>(
                        'voiceroom-banner-leave-confirm',
                      ),
                      label: _leaving ? '正在离开…' : '确认离开',
                      onPressed: _leaving
                          ? null
                          : () => unawaited(_leave(session)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Whether a toast raised from here has the floating tab bar to clear.
  ///
  /// The strip sits above the router, so its own context is above every tab
  /// scope and would answer `false` on every screen: on the review device the
  /// 「已离开语音房」 toast was placed as if no bar were under it and came out
  /// underneath the bar, with a corner of it showing and nothing readable.
  /// The shell that owns the router says which route it is on, and only the
  /// narrow layout draws a bar at all — the wide one puts a rail beside the
  /// page instead.
  bool _clearsTabBar(BuildContext context) {
    return (widget.onTabRoute?.call() ?? false) &&
        MediaQuery.sizeOf(context).width < LoopLayout.railBreakpoint;
  }

  /// Leaves the room from wherever the reader happens to be.
  ///
  /// The same order as the room page's own 离开: the provider call goes down
  /// first, because releasing the membership under a call this device is
  /// still connected to leaves a connected room this account is not in.
  Future<void> _leave(VoiceRoomSession session) async {
    if (_leaving) return;
    setState(() => _leaving = true);
    final disconnected = await ref
        .read(activeVoiceMediaProvider.notifier)
        .retire();
    if (!mounted) return;
    CommunityFailureKind? failure;
    String? reasonCode;
    try {
      await ref.read(voiceRoomGatewayProvider).leave(session.voiceRoomId);
    } on CommunityGatewayException catch (error) {
      failure = error.kind;
      reasonCode = error.reasonCode;
    } catch (_) {
      failure = CommunityFailureKind.unexpected;
    }
    if (!mounted) return;
    setState(() {
      _leaving = false;
      _confirmingExit = false;
    });
    // A room that ended refuses every write, this one included (decision
    // 0069). The membership went with the room, so the strip goes too — it
    // is the only sign the account was in one, and a strip standing over a
    // room that is gone has no way back in.
    if (failure != null && failure != CommunityFailureKind.stale) {
      LoopToast.show(
        context,
        message: voiceRoomFailureText(failure, reasonCode),
        kind: LoopToastKind.warn,
        clearsTabBar: _clearsTabBar(context),
      );
      return;
    }
    if (failure == CommunityFailureKind.stale) {
      ref.read(voiceRoomSessionProvider.notifier).leave(session.communityId);
      LoopToast.show(
        context,
        message: '房间已结束 · 主持人已经结束这个语音房',
        kind: LoopToastKind.warn,
        clearsTabBar: _clearsTabBar(context),
      );
      return;
    }
    ref.read(voiceRoomSessionProvider.notifier).leave(session.communityId);
    // A room page can be open behind the notification that asked for this.
    // It reads the membership again now rather than on its next poll, so it
    // stops offering the audio back to an account that left.
    if (ref.exists(voiceRoomControllerProvider)) {
      unawaited(ref.read(voiceRoomControllerProvider.notifier).refreshRoom());
    }
    LoopToast.show(
      context,
      message: disconnected ? '已离开语音房' : '已离开语音房，语音连接的收尾没有确认',
      clearsTabBar: _clearsTabBar(context),
    );
  }
}

/// One tappable word on the strip, with a target a thumb can hit.
class _BannerAction extends StatelessWidget {
  const _BannerAction({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: LoopTypography.withWeight(
                  LoopTypography.body(12, color: LoopColors.ink),
                  onPressed == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The three figures a voice room page states, which add up.
///
/// The server publishes three counts under three different rules (decision
/// 0051): `speakerCount` and `listenerCount` are LOOP's role intent and
/// **neither of them counts the host**, and `joinedCount` is everybody in the
/// room, host included. Printed side by side that reads as a contradiction —
/// the review device showed 「1 人在房间里」 above 「发言 0 · 听众 0」, and then
/// a 「正在发言」 grid with the host in it (walkthrough 2026-09-23 · a37/a43).
///
/// One rule instead, for every figure on both views: the host is in the room
/// and the host is on the microphone, so 发言人 counts the host and
/// 听众 is what is left. A live room is `1 + speaker + listener`, so the room
/// figure the server withheld is counted rather than replaced by a word.
@immutable
final class VoiceRoomHeadcount {
  const VoiceRoomHeadcount({
    required this.inRoom,
    required this.speaking,
    required this.listening,
  });

  factory VoiceRoomHeadcount.of(VoiceRoomSnapshot snapshot) {
    final participants = snapshot.participants;
    final listening = participants.listenerCount;
    // A live room always has the host in it: the server refuses the host's
    // 离开 outright, and ending the room is what takes them out of it.
    final host = snapshot.room.isLive ? 1 : 0;
    final inRoom =
        participants.joinedCount ??
        participants.speakerCount + listening + host;
    // Derived from the room total rather than added to the role figure, so
    // the three numbers on the page always add up to each other. A total the
    // server reported below its own parts cannot; the parts win then.
    final speaking = inRoom - listening;
    return VoiceRoomHeadcount(
      inRoom: inRoom,
      speaking: speaking < participants.speakerCount
          ? participants.speakerCount + host
          : speaking,
      listening: listening,
    );
  }

  /// Everybody LOOP has in the room, the host included.
  final int inRoom;

  /// The host plus every speaker: the people who may be heard.
  final int speaking;

  /// Everybody else.
  final int listening;
}

/// The `.folio-heading` of a voice-room page: a figure, or a conclusion.
///
/// `#scr-voiceroom` reads `PEPE 语音房 · 13 人` and `#scr-voiceroom-full`
/// reads `13 人在麦上`. LOOP printed the word 语音房 in both, which turned the
/// hero into a second title bar (audit 2026-09-20 · D-1).
///
/// With no room to describe the heading says what the read itself did. It
/// used to say 「语音房状态读不到」 for all three answers, including the one
/// the block below it stated as 「当前没有进行中的语音房」 — one screen both
/// knowing and not knowing (walkthrough 2026-09-23 · a14).
String voiceRoomHeading(
  VoiceRoomSnapshot? snapshot, {
  CommunityViewPhase phase = CommunityViewPhase.ready,
  bool expanded = false,
}) {
  if (snapshot == null) {
    return switch (phase) {
      CommunityViewPhase.loading => '正在读取语音房',
      CommunityViewPhase.empty => '当前没有语音房',
      _ => '语音房状态读不到',
    };
  }
  if (!snapshot.room.isLive) return '已结束';
  final headcount = VoiceRoomHeadcount.of(snapshot);
  return expanded ? '${headcount.speaking} 人在麦上' : '${headcount.inRoom} 人在房间里';
}

/// The `.folio-caption`, which answers the same question as the heading.
String voiceRoomCaption(
  VoiceRoomSnapshot? snapshot, {
  CommunityViewPhase phase = CommunityViewPhase.ready,
}) {
  if (snapshot == null) {
    return switch (phase) {
      CommunityViewPhase.loading => '正在读取这个社区的语音房。',
      CommunityViewPhase.empty => '这个社区现在没有进行中的语音房。',
      _ => '这次没有读到语音房的状态，下面可以重试。',
    };
  }
  if (!snapshot.room.isLive) return '主持人已经结束这个语音房。';
  // 「返回不等于离开」 was a whole notice at the foot of the page, and the
  // host's copy of it a second one. It is one line, and it belongs where the
  // reader looks first.
  if (snapshot.viewer.hasJoined) return '返回会把房间收起在顶部，随时点开回来。';
  return '进入前确认主持人、在线人数与录音说明。';
}

/// The `.folio-stamp`: `13 LIVE` on the lobby, `ON AIR` on the session page.
String? voiceRoomStamp(VoiceRoomSnapshot? snapshot, {bool expanded = false}) {
  if (snapshot == null) return null;
  // 「ENDED」 was the one bare English word on the page that stood for a state
  // rather than for a section's name (walkthrough 2026-09-23 · 已结束态).
  if (!snapshot.room.isLive) return '已结束';
  if (expanded) return 'ON AIR';
  return '${VoiceRoomHeadcount.of(snapshot).inRoom} LIVE';
}

/// The 11px line under the room's name in the top bar.
///
/// `#scr-voiceroom .topbar` states the room's condition and its two figures.
/// Both figures count the host the same way the hero does.
String? voiceRoomTopbarLine(VoiceRoomSnapshot? snapshot) {
  if (snapshot == null) return null;
  if (!snapshot.room.isLive) return '已结束';
  final headcount = VoiceRoomHeadcount.of(snapshot);
  return '进行中 · 发言 ${headcount.speaking} · 听众 ${headcount.listening}';
}

/// 「N 在听 · 开播 x 分钟」 (decision 0127): everybody in the room and how
/// long ago it opened, in the plaza's own words for the same fact.
String voiceRoomLiveLine({
  required int inRoom,
  required DateTime openedAt,
  required DateTime now,
}) => '$inRoom 在听 · ${liveVoiceRoomElapsedLabel(openedAt, now)}';
