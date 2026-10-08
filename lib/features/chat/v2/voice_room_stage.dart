import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_presentation.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_share.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// The room page after DeBox (decision 0115, S108–S110 §5): the host on a
/// stage, the speakers in a four-wide grid, the listeners in a six-wide grid,
/// and the controls in a bar fixed at the bottom of the screen.
///
/// Everything here draws what the page hands it. Who holds which part is
/// LOOP's roster; who is heard right now is this device's own call.

/// Listener faces the room page draws before it hands the rest to
/// `/chat/voice/full`.
const int voiceRoomListenerGridLimit = 18;

/// Speakers per grid row.
const int voiceRoomSpeakerColumns = 4;

/// Listeners per grid row.
const int voiceRoomListenerColumns = 6;

/// The longest title a host may give a room, in code points (S109b-api).
const int voiceRoomTitleMaxCodePoints = 40;

/// What the call says about one person on the microphone grid.
@immutable
final class VoiceRoomMicState {
  const VoiceRoomMicState({required this.open, required this.speaking});

  /// The microphone is open in the call; null when this device holds no call
  /// and LOOP has no mute mark on the row either — then nothing is claimed.
  final bool? open;

  /// The call hears this person right now.
  final bool speaking;

  static const unknown = VoiceRoomMicState(open: null, speaking: false);
}

/// Who a roster speaker is in the call this device holds.
///
/// The reader's own row is the local participant, and that answer is certain
/// either way. Anybody else can only be matched by the name both sides print,
/// so a match is claimed only when exactly one voice in the call carries a
/// name exactly one roster row carries ([nameUnique]). An anonymous row, a
/// name shared by two rows, and a name the call does not carry claim nothing
/// about the microphone: the row then shows LOOP's own mute mark, or no mark.
VoiceRoomMicState voiceRoomMemberMicState(
  VoiceRoomMember member,
  List<AudioRoomSpeaker>? live, {
  bool nameUnique = true,
}) {
  final fallback = member.muted
      ? const VoiceRoomMicState(open: false, speaking: false)
      : VoiceRoomMicState.unknown;
  if (live == null) return fallback;
  if (member.isSelf) {
    for (final speaker in live) {
      if (speaker.isLocal) {
        return VoiceRoomMicState(open: true, speaking: speaker.isSpeaking);
      }
    }
    return const VoiceRoomMicState(open: false, speaking: false);
  }
  if (member.name is VoiceRoomMemberAnonymousName || !nameUnique) {
    return fallback;
  }
  final name = voiceRoomRosterName(member);
  final matches = <AudioRoomSpeaker>[
    for (final speaker in live)
      if (!speaker.isLocal && speaker.name == name) speaker,
  ];
  if (matches.length != 1) return fallback;
  return VoiceRoomMicState(open: true, speaking: matches.single.isSpeaking);
}

/// The roster's display rule, restated here so the stage does not import the
/// page: an anonymous row is the server's anonymous label, and the reader's
/// own row is 「我 · alias」.
String voiceRoomRosterName(VoiceRoomMember member) => switch (member.name) {
  VoiceRoomMemberAlias(alias: final alias) =>
    member.isSelf ? '我 · $alias' : alias,
  VoiceRoomMemberAnonymousName(labelKey: final key) => voiceRoomDisplayKeyText(
    key,
  ),
};

/// The host's place on the stage.
///
/// [name] is the best the page knows: the reader's own 我 when the reader is
/// the host, the plaza's projection of the host when it was read, and the
/// word 主持人 when neither — LOOP's roster never carries the host.
class VoiceRoomHostStage extends StatelessWidget {
  const VoiceRoomHostStage({
    required this.name,
    required this.mic,
    super.key,
    this.avatarRef,
  });

  final String name;
  final String? avatarRef;
  final VoiceRoomMicState mic;

  @override
  Widget build(BuildContext context) {
    final caption = mic.speaking
        ? '正在发言'
        : mic.open == true
        ? '麦克风已开'
        : mic.open == false
        ? '已静音'
        : null;
    return Semantics(
      container: true,
      label: '主持人 $name${caption == null ? '' : '，$caption'}',
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey<String>('voiceroom-host'),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            VoiceRoomSpeakingRing(
              size: 72,
              speaking: mic.speaking,
              child: LoopProfileAvatar(
                avatarRef: avatarRef,
                alias: name,
                size: 72,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              key: const ValueKey<String>('voiceroom-host-name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.title(16),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // A host this page cannot name is already called 主持人;
                // the badge would only say it twice.
                if (name != '主持人')
                  const LoopBadge('主持人', kind: LoopBadgeKind.up),
                if (caption != null) ...<Widget>[
                  if (name != '主持人') const SizedBox(width: 8),
                  Text(
                    caption,
                    style: LoopTypography.caption(
                      12,
                      color: mic.speaking ? LoopColors.lime : LoopColors.text2,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The Lime ring a face wears while the call hears that person.
///
/// It eases on and off; with motion reduced it simply switches.
class VoiceRoomSpeakingRing extends StatelessWidget {
  const VoiceRoomSpeakingRing({
    required this.size,
    required this.speaking,
    required this.child,
    super.key,
  });

  final double size;
  final bool speaking;
  final Widget child;

  static const double width = 3;

  @override
  Widget build(BuildContext context) {
    final outer = size + (width + 2) * 2;
    return AnimatedContainer(
      duration: LoopMotion.of(context, const Duration(milliseconds: 180)),
      curve: Curves.easeOutCubic,
      width: outer,
      height: outer,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: speaking ? LoopColors.lime : Colors.transparent,
          width: width,
        ),
      ),
      child: SizedBox.square(dimension: size, child: child),
    );
  }
}

/// One face on a grid: the avatar, the name under it, and a mark in the
/// corner — the microphone on the speaker grid, a raised hand on the
/// listener grid.
class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.name,
    required this.avatarSize,
    required this.width,
    super.key,
    this.avatarRef,
    this.mic,
    this.handRaised = false,
    this.onTap,
  });

  final String name;
  final String? avatarRef;
  final double avatarSize;
  final double width;
  final VoiceRoomMicState? mic;
  final bool handRaised;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = mic;
    final speaking = state?.speaking ?? false;
    final markIcon = state == null
        ? (handRaised ? 'hand' : null)
        : state.open == false
        ? 'voice-off'
        : state.open == true
        ? 'mic'
        : null;
    final description = <String>[
      name,
      if (speaking) '正在发言',
      if (state?.open == false) '已静音',
      if (state?.open == true && !speaking) '麦克风已开',
      if (handRaised) '已举手',
    ].join('，');
    final ring = VoiceRoomSpeakingRing.width + 2;
    final tile = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              VoiceRoomSpeakingRing(
                size: avatarSize,
                speaking: speaking,
                child: LoopProfileAvatar(
                  avatarRef: avatarRef,
                  alias: name,
                  size: avatarSize,
                ),
              ),
              if (markIcon != null)
                Positioned(
                  right: ring - 4,
                  bottom: ring - 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: markIcon == 'mic' || markIcon == 'hand'
                          ? LoopColors.lime
                          : LoopColors.graphite,
                      border: Border.all(color: LoopColors.ink, width: 2),
                    ),
                    child: LoopIcon(
                      markIcon,
                      size: 10,
                      color: markIcon == 'voice-off'
                          ? LoopColors.text2
                          : LoopColors.ink,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: LoopTypography.caption(
              11,
              color: speaking ? LoopColors.lime : LoopColors.text2,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: description,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: tile,
        ),
      ),
    );
  }
}

/// Lays [count] cells out [columns] to a row across the width it is given.
class _GridRows extends StatelessWidget {
  const _GridRows({
    required this.columns,
    required this.count,
    required this.cell,
    super.key,
  });

  final int columns;
  final int count;
  final Widget Function(int index, double width) cell;

  static const double gap = 8;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: <Widget>[
            for (var index = 0; index < count; index += 1) cell(index, width),
          ],
        );
      },
    ),
  );
}

/// The speakers: four to a row, a 48 face, the name, and the microphone.
///
/// The faces are LOOP's speaker roster — the parts LOOP granted, host
/// excluded (decision 0052). Whether each microphone is open and who is
/// being heard comes from this device's own call when it holds one
/// ([live]); the roster's mute mark is all there is without it.
class VoiceRoomSpeakerGrid extends StatelessWidget {
  const VoiceRoomSpeakerGrid({
    required this.roster,
    required this.onRetry,
    super.key,
    this.live,
    this.onOpenMember,
  });

  final VoiceRoomRosterState roster;
  final VoidCallback onRetry;
  final List<AudioRoomSpeaker>? live;

  /// Opens the server's commands for one row; null when nothing may be done
  /// right now.
  final ValueChanged<VoiceRoomMember>? onOpenMember;

  @override
  Widget build(BuildContext context) => switch (roster.phase) {
    CommunityViewPhase.loading => const LoopSkeleton(
      key: ValueKey<String>('voiceroom-speakers-loading'),
      type: LoopSkeletonType.list,
      rows: 1,
    ),
    CommunityViewPhase.empty => const _QuietLine(
      key: ValueKey<String>('voiceroom-speakers-empty'),
      text: '还没有人上麦',
    ),
    CommunityViewPhase.offline => LoopOfflineState(
      key: const ValueKey<String>('voiceroom-speakers-offline'),
      pausedActions: const <String>['查看发言人'],
      onRetry: onRetry,
    ),
    CommunityViewPhase.permission => LoopPermissionState(
      key: const ValueKey<String>('voiceroom-speakers-permission'),
      icon: 'shield',
      title: '没有权限查看发言人名单',
      purpose: communityFailureReason(roster.failureKind),
    ),
    CommunityViewPhase.unavailable => LoopEmpty(
      key: const ValueKey<String>('voiceroom-speakers-unavailable'),
      icon: 'warn',
      message: '发言人名单当前不可用',
      reason: communityFailureReason(roster.failureKind),
    ),
    CommunityViewPhase.error => LoopErrorState(
      key: const ValueKey<String>('voiceroom-speakers-error'),
      title: '发言人名单读不到',
      reason: communityFailureReason(roster.failureKind),
      onRetry: onRetry,
    ),
    CommunityViewPhase.ready =>
      roster.items.isEmpty
          ? const _QuietLine(
              key: ValueKey<String>('voiceroom-speakers-empty'),
              text: '还没有人上麦',
            )
          : _speakerRows(),
  };

  Widget _speakerRows() {
    final names = <String, int>{};
    for (final member in roster.items) {
      final name = voiceRoomRosterName(member);
      names[name] = (names[name] ?? 0) + 1;
    }
    return _GridRows(
      key: const ValueKey<String>('voiceroom-speakers'),
      columns: voiceRoomSpeakerColumns,
      count: roster.items.length,
      cell: (index, width) {
        final member = roster.items[index];
        final open = onOpenMember;
        return _MemberTile(
          key: ValueKey<String>(
            'voiceroom-speaker-tile-'
            '${member.publicProfileId ?? index}',
          ),
          name: voiceRoomRosterName(member),
          avatarRef: member.avatarRef,
          avatarSize: 48,
          width: width,
          mic: voiceRoomMemberMicState(
            member,
            live,
            nameUnique: names[voiceRoomRosterName(member)] == 1,
          ),
          onTap: member.commands.isEmpty || open == null
              ? null
              : () => open(member),
        );
      },
    );
  }
}

/// The listeners: six to a row, a 40 face and the name, a hand on whoever
/// raised one, and after [voiceRoomListenerGridLimit] faces a 「+N」 that
/// opens the whole list.
class VoiceRoomListenerGrid extends StatelessWidget {
  const VoiceRoomListenerGrid({
    required this.roster,
    required this.total,
    required this.onRetry,
    super.key,
    this.onMore,
    this.onOpenMember,
  });

  final VoiceRoomRosterState roster;

  /// The room's own listener figure; the roster page may hold fewer rows.
  final int total;
  final VoidCallback onRetry;

  /// Opens `/chat/voice/full`; null leaves the 「+N」 as a count only.
  final VoidCallback? onMore;
  final ValueChanged<VoiceRoomMember>? onOpenMember;

  /// How many faces are drawn and what the 「+N」 says, for [shown] rows read
  /// out of a room of [total] listeners, with [more] when another roster page
  /// exists.
  static ({int faces, int? more}) layout({
    required int rows,
    required int total,
    required bool more,
  }) {
    final everyone = total > rows ? total : (more ? rows + 1 : rows);
    if (everyone <= voiceRoomListenerGridLimit) {
      return (faces: rows, more: null);
    }
    // The last cell of the eighteen becomes the count, so the grid stays three
    // rows tall however large the room is.
    const faces = voiceRoomListenerGridLimit - 1;
    final shown = rows < faces ? rows : faces;
    return (faces: shown, more: everyone - shown);
  }

  @override
  Widget build(BuildContext context) => switch (roster.phase) {
    CommunityViewPhase.loading => const LoopSkeleton(
      key: ValueKey<String>('voiceroom-listeners-loading'),
      type: LoopSkeletonType.list,
      rows: 1,
    ),
    CommunityViewPhase.empty => _ready(),
    CommunityViewPhase.offline => LoopOfflineState(
      key: const ValueKey<String>('voiceroom-listeners-offline'),
      pausedActions: const <String>['查看听众'],
      onRetry: onRetry,
    ),
    CommunityViewPhase.permission => LoopPermissionState(
      key: const ValueKey<String>('voiceroom-listeners-permission'),
      icon: 'shield',
      title: '没有权限查看听众名单',
      purpose: communityFailureReason(roster.failureKind),
    ),
    CommunityViewPhase.unavailable => LoopEmpty(
      key: const ValueKey<String>('voiceroom-listeners-unavailable'),
      icon: 'warn',
      message: '听众名单当前不可用',
      reason: communityFailureReason(roster.failureKind),
    ),
    CommunityViewPhase.error => LoopErrorState(
      key: const ValueKey<String>('voiceroom-listeners-error'),
      title: '听众名单读不到',
      reason: communityFailureReason(roster.failureKind),
      onRetry: onRetry,
    ),
    CommunityViewPhase.ready => _ready(),
  };

  Widget _ready() {
    final items = roster.items;
    if (items.isEmpty && total <= 0) {
      return const _QuietLine(
        key: ValueKey<String>('voiceroom-listeners-empty'),
        text: '还没有听众',
      );
    }
    if (items.isEmpty) {
      // The room counts listeners the roster page has not listed (yet): the
      // figure is not contradicted by an empty grid, it is the way to them.
      return _GridRows(
        key: const ValueKey<String>('voiceroom-listeners'),
        columns: voiceRoomListenerColumns,
        count: 1,
        cell: (index, width) => _MoreTile(
          key: const ValueKey<String>('voiceroom-listeners-more'),
          count: total,
          width: width,
          onTap: onMore,
        ),
      );
    }
    final plan = layout(
      rows: items.length,
      total: total,
      more: roster.nextCursor != null,
    );
    final more = plan.more;
    return _GridRows(
      key: const ValueKey<String>('voiceroom-listeners'),
      columns: voiceRoomListenerColumns,
      count: plan.faces + (more == null ? 0 : 1),
      cell: (index, width) {
        if (index == plan.faces) {
          return _MoreTile(
            key: const ValueKey<String>('voiceroom-listeners-more'),
            count: more!,
            width: width,
            onTap: onMore,
          );
        }
        final member = items[index];
        final open = onOpenMember;
        return _MemberTile(
          key: ValueKey<String>(
            'voiceroom-listener-tile-${member.publicProfileId ?? index}',
          ),
          name: voiceRoomRosterName(member),
          avatarRef: member.avatarRef,
          avatarSize: 40,
          width: width,
          handRaised: member.handRaised,
          onTap: member.commands.isEmpty || open == null
              ? null
              : () => open(member),
        );
      },
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.count,
    required this.width,
    required this.onTap,
    super.key,
  });

  final int count;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    final outer = size + (VoiceRoomSpeakingRing.width + 2) * 2;
    return Semantics(
      button: onTap != null,
      label: '还有 $count 位听众${onTap == null ? '' : '，查看完整名单'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox.square(
                  dimension: outer,
                  child: Center(
                    child: Container(
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: LoopColors.card2,
                      ),
                      child: Text(
                        '+$count',
                        maxLines: 1,
                        style: LoopTypography.figure(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '全部',
                  style: LoopTypography.caption(11, color: LoopColors.text2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One quiet line where a grid would be: an empty grid is a fact about the
/// room, not a failure, and it does not need a block of its own.
class _QuietLine extends StatelessWidget {
  const _QuietLine({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Text(text, style: LoopTypography.caption(12)),
  );
}

/// The bar fixed at the bottom of the room page (decision 0115).
///
/// Three shapes, by the part LOOP granted this account:
/// - 听众: 举手 / 取消举手 · 离开
/// - 发言人: 静音 / 取消静音 · 下麦 · 离开
/// - 主持人: 麦克风 · 邀请发言 · 全体静音 · 结束房间
///
/// A reader who has not joined gets the one control there is, 加入语音房.
class VoiceRoomControlBar extends StatelessWidget {
  const VoiceRoomControlBar({
    required this.snapshot,
    required this.busy,
    required this.microphone,
    required this.pendingHands,
    required this.onJoin,
    required this.onLeave,
    required this.onRaise,
    required this.onCancel,
    required this.onEnd,
    required this.onMuteAll,
    required this.onStepDown,
    super.key,
    this.onInvite,
  });

  final VoiceRoomSnapshot snapshot;
  final bool busy;

  /// The call view's microphone, when one is mounted on the page.
  final VoiceMicrophoneBridge microphone;

  /// Pending hands in the host's queue, for the count on 邀请发言.
  final int pendingHands;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onRaise;
  final VoidCallback onCancel;
  final VoidCallback onEnd;
  final VoidCallback onMuteAll;
  final VoidCallback onStepDown;

  /// Opens the queue (`/chat/voice/full`); null when there is nowhere to go.
  final VoidCallback? onInvite;

  /// Whether [snapshot] has a bar at all: a room that is over, or one this
  /// reader cannot join yet, says so in the page instead.
  static bool shows(VoiceRoomSnapshot snapshot) {
    if (!snapshot.room.isLive) return false;
    return snapshot.viewer.hasJoined || snapshot.room.isJoinable;
  }

  @override
  Widget build(BuildContext context) {
    final viewer = snapshot.viewer;
    final disabled = busy || !snapshot.room.isLive;
    final Widget content;
    if (!viewer.hasJoined) {
      content = LoopButton(
        key: const ValueKey<String>('voiceroom-join'),
        label: busy ? '正在加入…' : '加入语音房',
        block: true,
        primary: true,
        icon: 'voice',
        onPressed: disabled ? null : onJoin,
      );
    } else {
      final items = switch (viewer.role) {
        VoiceRoomRole.host => <Widget>[
          _MicrophoneItem(microphone: microphone, disabled: disabled),
          _BarItem(
            key: const ValueKey<String>('voiceroom-invite-open'),
            icon: 'hand',
            label: '邀请发言',
            badge: pendingHands > 0 ? '$pendingHands' : null,
            onPressed: disabled || onInvite == null ? null : onInvite,
          ),
          _BarItem(
            key: const ValueKey<String>('voiceroom-mute-all'),
            icon: 'voice-off',
            label: '全体静音',
            onPressed: disabled || !viewer.canMuteAll ? null : onMuteAll,
          ),
          _BarItem(
            key: const ValueKey<String>('voiceroom-end'),
            icon: 'close',
            label: '结束房间',
            danger: true,
            onPressed: disabled || !viewer.canEndRoom ? null : onEnd,
          ),
        ],
        VoiceRoomRole.speaker => <Widget>[
          _MicrophoneItem(microphone: microphone, disabled: disabled),
          _BarItem(
            key: const ValueKey<String>('voiceroom-step-down'),
            icon: 'arrow-down',
            label: '下麦',
            onPressed: disabled ? null : onStepDown,
          ),
          _BarItem(
            key: const ValueKey<String>('voiceroom-leave'),
            icon: 'close',
            label: '离开',
            danger: true,
            onPressed: disabled ? null : onLeave,
          ),
        ],
        _ => <Widget>[
          if (viewer.handRaise?.isPending ?? false)
            _BarItem(
              key: const ValueKey<String>('voiceroom-cancel-hand'),
              icon: 'hand',
              label: '取消举手',
              active: true,
              onPressed: disabled ? null : onCancel,
            )
          else
            _BarItem(
              key: const ValueKey<String>('voiceroom-raise-hand'),
              icon: 'hand',
              label: '举手',
              onPressed: disabled ? null : onRaise,
            ),
          _BarItem(
            key: const ValueKey<String>('voiceroom-leave'),
            icon: 'close',
            label: '离开',
            danger: true,
            onPressed: disabled ? null : onLeave,
          ),
        ],
      };
      content = Row(
        children: <Widget>[for (final item in items) Expanded(child: item)],
      );
    }
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      key: const ValueKey<String>('voiceroom-control-bar'),
      decoration: const BoxDecoration(
        color: LoopColors.ink,
        border: Border(top: BorderSide(color: LoopColors.line)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          LoopSpacing.page,
          8,
          LoopSpacing.page,
          8 + bottom,
        ),
        child: content,
      ),
    );
  }
}

/// The microphone slot: the call view's own control, drawn here.
class _MicrophoneItem extends StatelessWidget {
  const _MicrophoneItem({required this.microphone, required this.disabled});

  final VoiceMicrophoneBridge microphone;
  final bool disabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: microphone,
    builder: (context, _) {
      final control = microphone.control;
      if (control == null) {
        // No call on the page yet — it is still connecting, or the room is
        // not open for listening. The slot says so rather than pretend.
        return const _BarItem(
          key: ValueKey<String>('voiceroom-bar-mic'),
          icon: 'voice-off',
          label: '未连接',
          onPressed: null,
        );
      }
      return _BarItem(
        key: const ValueKey<String>('voiceroom-bar-mic'),
        icon: control.open ? 'mic' : 'voice-off',
        label: control.label,
        active: control.open,
        onPressed: disabled || !control.enabled ? null : microphone.press,
      );
    },
  );
}

/// One slot of the bar: a glyph over a word, at least 56 tall.
class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.active = false,
    this.danger = false,
    this.badge,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;

  /// The state this slot toggles is on (a raised hand, an open microphone).
  final bool active;
  final bool danger;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? LoopColors.text3
        : danger
        ? LoopColors.danger
        : active
        ? LoopColors.lime
        : LoopColors.chalk;
    return Semantics(
      button: true,
      enabled: enabled,
      label: badge == null ? label : '$label，$badge 人举手',
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    LoopIcon(icon, size: 22, color: color),
                    if (badge != null)
                      Positioned(
                        right: -12,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: LoopColors.lime,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge!,
                            style: LoopTypography.figure(
                              11,
                              color: LoopColors.ink,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopTypography.label(12, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The (i) sheet: the room's facts and every note about the provider that
/// used to stand in the page (decision 0115).
Future<void> showVoiceRoomInfoSheet(
  BuildContext context, {
  required VoiceRoomSnapshot snapshot,
  required String caption,
  required String? figures,
  required String providerSyncText,
}) {
  final room = snapshot.room;
  final role = snapshot.viewer.role;
  return showLoopSheet<void>(
    context,
    barrierLabel: '关闭房间说明',
    builder: (sheetContext) => Padding(
      key: const ValueKey<String>('voiceroom-info-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            voiceRoomTitle(room.communityName, title: room.title),
            style: LoopTypography.heading(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: LoopTypography.body(13, color: LoopColors.muted),
          ),
          const SizedBox(height: 12),
          LoopKeyValue(
            label: '社区',
            value: room.communityName,
            padding: EdgeInsets.zero,
          ),
          LoopKeyValue(
            label: '开播',
            value: loopLocalClockLabel(room.createdAt),
            padding: EdgeInsets.zero,
          ),
          if (figures != null)
            LoopKeyValue(label: '人数', value: figures, padding: EdgeInsets.zero),
          LoopKeyValue(
            label: '我的身份',
            value: role?.label ?? '还没有加入',
            padding: EdgeInsets.zero,
          ),
          if (!snapshot.providerSync.confirmed)
            LoopNotice(
              key: const ValueKey<String>('voiceroom-provider-unconfirmed'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '服务商侧未确认',
              body: providerSyncText,
              margin: const EdgeInsets.only(top: 14),
            ),
          const LoopNotice(
            key: ValueKey<String>('voiceroom-provider-note'),
            icon: 'info',
            title: 'Stream Video / Audio Rooms',
            body: '语音连接、发言权限与在线状态由 Stream 提供。',
            margin: EdgeInsets.only(top: 14),
          ),
          const SizedBox(height: 16),
          LoopButton(
            key: const ValueKey<String>('voiceroom-info-close'),
            label: '知道了',
            block: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}

/// The 开播 sheet: a title (it may stay empty), then the room is opened
/// (decision 0115).
///
/// Reusable from wherever an owner or an admin opens a room — the community
/// record today, the community management page (S109b-mobile) next. It
/// returns what came back from `POST …/voice-rooms`, or null when the reader
/// closed the sheet; what to say about the answer stays the caller's, which
/// knows where it stands.
Future<VoiceRoomOpenOutcome?> showVoiceRoomStartSheet(
  BuildContext context,
  String communityId,
) => showLoopSheet<VoiceRoomOpenOutcome>(
  context,
  barrierLabel: '关闭开播弹层',
  // The sheet carries the answer of a write that may be in flight, so it is
  // closed by its own buttons (and the system back while idle) only: a drag
  // or a tap outside would drop that answer on the floor.
  isDismissible: false,
  builder: (sheetContext) => _VoiceRoomStartSheet(communityId: communityId),
);

/// The title a host typed, as it is sent: trimmed, and nothing when empty.
String? voiceRoomStartTitle(String raw) {
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _VoiceRoomStartSheet extends ConsumerStatefulWidget {
  const _VoiceRoomStartSheet({required this.communityId});

  final String communityId;

  @override
  ConsumerState<_VoiceRoomStartSheet> createState() =>
      _VoiceRoomStartSheetState();
}

class _VoiceRoomStartSheetState extends ConsumerState<_VoiceRoomStartSheet> {
  final TextEditingController _title = TextEditingController();

  /// An opening of this community's room that is not finished: its retry
  /// carries the first title, so the field shows it and cannot change it.
  VoiceRoomPendingOpen? _pending;

  @override
  void initState() {
    super.initState();
    _pending = ref
        .read(voiceRoomGatewayProvider)
        .pendingOpen(widget.communityId);
    _title.text = _pending?.title ?? '';
    _title.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _title
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(voiceRoomOpenControllerProvider.notifier)
        .openRoom(widget.communityId, title: voiceRoomStartTitle(_title.text));
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final opening = ref.watch(voiceRoomOpenControllerProvider);
    final used = _title.text.runes.length;
    final pending = _pending;
    return PopScope<VoiceRoomOpenOutcome>(
      // While the room is being opened the sheet stays: its answer is what
      // the caller reports, and a pop here would swallow it.
      canPop: !opening,
      child: Padding(
        key: const ValueKey<String>('community-open-voice-room-sheet'),
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          8 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '开播',
              style: LoopTypography.heading(18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '房间会立刻对社区成员可见，任何成员都能进来收听。你是主持人，'
              '邀请发言、全体静音和结束房间都由你或其他管理员操作；麦克风默认关闭。',
              style: LoopTypography.body(13, color: LoopColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey<String>('voiceroom-start-title'),
              controller: _title,
              enabled: !opening && pending == null,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                _CodePointLimit(voiceRoomTitleMaxCodePoints),
              ],
              decoration: const InputDecoration(
                labelText: '房间标题（可留空）',
                hintText: '留空时显示「社区名 语音房」',
              ),
              onSubmitted: opening ? null : (_) => unawaited(_submit()),
            ),
            if (pending != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '上一次开播还没有完成，再开播会接着完成它，标题沿用当时填写的内容。',
                key: const ValueKey<String>('voiceroom-start-pending'),
                style: LoopTypography.caption(12, color: LoopColors.text2),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$used / $voiceRoomTitleMaxCodePoints',
                style: LoopTypography.figure(11, color: LoopColors.text3),
              ),
            ),
            const SizedBox(height: 12),
            LoopButtonPair(
              padded: false,
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('voiceroom-start-submit'),
                  label: opening ? '正在开播…' : '开播',
                  primary: true,
                  icon: 'voice',
                  onPressed: opening ? null : () => unawaited(_submit()),
                ),
                LoopButton(
                  key: const ValueKey<String>('voiceroom-start-cancel'),
                  label: '取消',
                  onPressed: opening ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Holds a field to [limit] code points, so an emoji or a supplementary Han
/// character counts once — the server's own rule (1–40 code points).
final class _CodePointLimit extends TextInputFormatter {
  _CodePointLimit(this.limit);

  final int limit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // An IME still composing (pinyin, kana) is left alone: cutting its
    // provisional text would break the composition. The cut happens once the
    // text is committed.
    if (newValue.composing.isValid) return newValue;
    if (newValue.text.runes.length <= limit) return newValue;
    final text = String.fromCharCodes(newValue.text.runes.take(limit));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
