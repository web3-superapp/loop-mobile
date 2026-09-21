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
        label: count == null || count <= 0 ? label : '$label，$count 条未读',
        color: open ? LoopColors.ink : null,
        toggled: toggled,
        onPressed: onPressed,
      ),
    );
    if (count == null || count <= 0) return tool;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        tool,
        Positioned(
          right: 0,
          top: 2,
          child: ExcludeSemantics(
            child: Container(
              key: const ValueKey<String>('community-unread-badge'),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: LoopColors.lime,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: LoopColors.ink, width: 2),
              ),
              child: Text(
                '$count',
                style: LoopTypography.figure(11, color: LoopColors.ink),
              ),
            ),
          ),
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

/// `.community-message-head`: the panel's own title and its `N NEW` pill.
class CommunityMessagePanelHead extends StatelessWidget {
  const CommunityMessagePanelHead({super.key, this.newCount});

  /// How many of the rows below are new. Null — no source — prints no pill.
  final int? newCount;

  @override
  Widget build(BuildContext context) {
    final count = newCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'MESSAGE CENTER',
                  style: LoopTypography.eyebrow(11, color: LoopColors.text3),
                ),
                const SizedBox(height: 3),
                Text('社区消息', style: LoopType.headingSm),
              ],
            ),
          ),
          if (count != null && count > 0) ...<Widget>[
            const SizedBox(width: 10),
            LoopBadge(
              '$count NEW',
              key: const ValueKey<String>('community-message-new-count'),
              kind: LoopBadgeKind.up,
            ),
          ],
        ],
      ),
    );
  }
}

/// `.community-message-row`: a glyph tile, two lines, and one trailing mark.
class CommunityMessageRow extends StatelessWidget {
  const CommunityMessageRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
    this.leading,
    this.stamp,
    this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;

  /// The identity tile this row stands for, when it stands for one. A row
  /// about a named community shows that community's own face; the rows that
  /// name a kind of message rather than a community keep the glyph, because
  /// there is no identity behind them to draw.
  final Widget? leading;

  /// `.community-message-live` — a Lime stamp such as `LIVE`.
  final String? stamp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mark = stamp;
    final content = Container(
      constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          leading ??
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LoopGround.fillOf(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: LoopIcon(
                  icon,
                  size: 19,
                  color: LoopGround.secondaryOf(context),
                ),
              ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopTypography.title(
                    15,
                    color: LoopGround.inkOf(context),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopTypography.caption(
                    11,
                    color: LoopGround.secondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          if (mark != null) ...<Widget>[
            const SizedBox(width: 10),
            LoopBadge(mark, kind: LoopBadgeKind.up),
          ] else if (onTap != null) ...<Widget>[
            const SizedBox(width: 8),
            LoopIcon(
              'chevron',
              size: 15,
              color: LoopGround.auxiliaryOf(context),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: '$title，$subtitle',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(LoopRadius.innerValue),
          child: content,
        ),
      ),
    );
  }
}

/// `.community-message-search`: the panel's own footer control.
class CommunityMessageSearchButton extends StatelessWidget {
  const CommunityMessageSearchButton({
    required this.onPressed,
    super.key,
    this.label = '搜索消息',
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(LoopRadius.innerValue),
          child: Container(
            constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
            decoration: BoxDecoration(
              color: LoopColors.limeSoft,
              borderRadius: BorderRadius.circular(LoopRadius.innerValue),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const LoopIcon('search', size: 17, color: LoopColors.lime),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: LoopTypography.label(
                    12,
                    weight: FontWeight.w700,
                    color: LoopColors.lime,
                  ),
                ),
              ],
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
