/// The parts the community home (`#scr-community`) owns on its own.
///
/// Everything here is a direct reading of the frozen prototype: the three
/// topbar tools with their unread badge, the compact `.community-discover-hero`
/// above the index folio, the `.community-message-panel` rows, and the joined
/// community `.row` with its mono second line and Lime unread pill.
///
/// No widget here invents a figure. Every count is nullable, and a count with
/// no source renders as nothing at all rather than as a zero.
library;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/widgets/loop_unread_badge.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// `48,120 成员` — the server's own head count, grouped for reading.
String communityMemberCountLabel(int memberCount) =>
    '${loopGroupedFigure(memberCount.toString())} 成员';

/// `.community-tool`: the round topbar tool Community draws for its three
/// header controls, with `.community-unread-badge` on the message one.
///
/// It is the plain [LoopIconButton] on a 5.5% Chalk disc — the fill is
/// Community's own (`.community-tool{background:rgba(243,245,239,.055)}`), and
/// an open panel turns its tool full Lime
/// (`.community-message-tool[aria-expanded="true"]`) so the reader can see
/// which of the two mutually exclusive panels is showing.
///
/// [unreadCount] is null whenever this client has no unread source, and a zero
/// is not a badge: only a positive count is drawn.
class CommunityToolButton extends StatelessWidget {
  const CommunityToolButton({
    required this.icon,
    required this.label,
    super.key,
    this.unreadCount,
    this.onPressed,
    this.toggled,
  });

  final String icon;
  final String label;
  final int? unreadCount;
  final VoidCallback? onPressed;

  /// Whether the panel this tool owns is open. `null` is a plain tool with no
  /// toggle state to report.
  final bool? toggled;

  static const double _radius = 15;

  @override
  Widget build(BuildContext context) {
    final open = toggled ?? false;
    final count = unreadCount;
    final tool = DecoratedBox(
      decoration: BoxDecoration(
        color: open ? LoopColors.lime : LoopColors.panel,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: LoopIconButton(
        icon: icon,
        label: loopUnreadBadgeLabel(count) == null
            ? label
            : '$label，${loopUnreadBadgeLabel(count)} 条未读',
        color: open ? LoopColors.ink : null,
        toggled: toggled,
        onPressed: onPressed,
      ),
    );
    if (loopUnreadBadgeLabel(count) == null) return tool;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        tool,
        // Decision 0105 · 6: the shared unread mark, 16 dp high, in the
        // warning red so it reads on this tool whether it is Ink or Lime.
        Positioned(
          key: const ValueKey<String>('community-unread-badge'),
          right: 0,
          top: 2,
          child: LoopUnreadBadge(count: count),
        ),
      ],
    );
  }
}

/// `.community-discover-hero`: one compact Lime band above the index folio.
///
/// [verifiedCount] is the kicker's own figure. It is null unless the server
/// published a directory total, and the kicker then reads `DISCOVER` alone —
/// the preview length of the aggregate's `discover` list is not a total and
/// was printed as one.
class CommunityDiscoverHero extends StatelessWidget {
  const CommunityDiscoverHero({
    required this.onTap,
    super.key,
    this.verifiedCount,
  });

  final int? verifiedCount;
  final VoidCallback onTap;

  static const String title = '发现新社区';
  static const String body = '按活跃度、持有人与 Mining 权重找到值得加入的社区';

  @override
  Widget build(BuildContext context) {
    final count = verifiedCount;
    final kicker = count == null ? 'DISCOVER' : 'DISCOVER · $count VERIFIED';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Semantics(
        button: true,
        label: '$title，$body',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(19),
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
              decoration: BoxDecoration(
                color: LoopColors.lime,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          kicker,
                          style: LoopTypography.eyebrow(
                            11,
                            color: LoopColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: LoopTypography.heading(
                            18,
                            color: LoopColors.ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          body,
                          style: LoopTypography.caption(
                            11,
                            color: LoopColors.inkText2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const LoopIcon('chevron', size: 18, color: LoopColors.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one line that says when the page's figures were read.
///
/// It used to be the index folio's caption, where it competed with the only
/// sentence on the page a reader was there for. The reading still has to be
/// datable, so it stays — at the foot of the page, in the smallest voice the
/// palette has.
class CommunityObservedFootnote extends StatelessWidget {
  const CommunityObservedFootnote({required this.observedAt, super.key});

  final DateTime observedAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Text(
        '数据观察于 ${communityObservedAtLabel(observedAt)}',
        style: LoopTypography.eyebrow(11, color: LoopColors.text3),
      ),
    );
  }
}

/// The index folio's activity line, built from what this client can read.
///
/// Every clause is independent and every clause is optional: a figure with no
/// source contributes nothing rather than a zero, and the line is null when
/// none of the three has a source at all. Today that is the usual case —
/// `GET /v2/community/home` publishes unread and live voice as unavailable
/// facts, and the aggregate carries no per-community unread to rank by — so
/// the caller states that instead of printing an empty sentence.
String? communityActivityCaption({
  String? mostDiscussed,
  int? liveVoiceRooms,
  int? unreadMessages,
}) {
  final clauses = <String>[
    if (mostDiscussed != null) '$mostDiscussed 讨论最活跃',
    if (liveVoiceRooms != null) '$liveVoiceRooms 个语音房正在进行',
    if (unreadMessages != null) '$unreadMessages 条未读',
  ];
  if (clauses.isEmpty) return null;
  return '${clauses.join(' · ')}。';
}
