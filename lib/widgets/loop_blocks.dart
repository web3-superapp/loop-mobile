import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// Prototype blocks the wallet pages are built out of.
///
/// They are additions, not replacements: every widget here maps to one rule in
/// `docs/prototype/style-v2.css` that `loop_components.dart` had no shape for,
/// and nothing in this file changes an existing component's behaviour.
///
/// The rule they share is the one the visual audit found broken in the wallet
/// module (2026-09-20 §D): a page states a figure or offers an action in the
/// shape the prototype gives it. A figure that was not read renders as
/// [loopFigureDash] — never as `0`, and never as a sentence that replaces the
/// block.

/// What a figure slot shows when the read behind it has no answer.
///
/// The em dash is the whole vocabulary for "not read" inside a figure grid:
/// the reason belongs to the block that owns the read, stated once, and a
/// grid cell that tried to carry it would push the figure off the card.
const String loopFigureDash = '—';

// ---------------------------------------------------------------------------
// .stat-grid / .stat
// ---------------------------------------------------------------------------

/// How a [LoopStat]'s figure is coloured.
enum LoopStatTone {
  /// `.stat b` — the figure is a reading, not a verdict.
  neutral,

  /// `.stat b.up` — Lime.
  up,

  /// `.stat b.down` — Chalk, the prototype's "this is not good news" weight.
  down,
}

/// One cell of a [LoopStatGrid]: `.stat` — a mono figure over an uppercase
/// caption.
@immutable
class LoopStat {
  const LoopStat({
    required this.label,
    required this.value,
    this.tone = LoopStatTone.neutral,
    this.statKey,
  });

  /// The caption under the figure (`.stat span`), rendered uppercase.
  final String label;

  /// The figure itself. [loopFigureDash] when it was not read.
  final String value;
  final LoopStatTone tone;

  /// The widget key for the cell, so a test can name one figure.
  final Key? statKey;

  bool get isUnread => value == loopFigureDash;
}

/// `.stat-grid`: a two-column grid of [LoopStat] cells.
///
/// The prototype's asset and approval pages open with one of these, and it is
/// the block the audit found replaced by key/value tables. It lays out in
/// pairs, so an odd number of cells leaves the last one half-width rather than
/// stretching it: the grid is a grid, whatever it was handed.
class LoopStatGrid extends StatelessWidget {
  const LoopStatGrid({required this.stats, super.key, this.margin});

  final List<LoopStat> stats;
  final EdgeInsets? margin;

  /// `.stat-grid{gap:10px}` / `.refined-page .folio-body>.stat-grid{gap:8px}`.
  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var index = 0; index < stats.length; index += 2) {
      final left = stats[index];
      final right = index + 1 < stats.length ? stats[index + 1] : null;
      rows.add(
        // The grid sits in a sliver, where height is unbounded: `stretch`
        // alone would ask a cell to be infinitely tall. The intrinsic pass
        // measures the taller cell first, which is what makes a pair line up.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _LoopStatCell(stat: left)),
              const SizedBox(width: gap),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : _LoopStatCell(stat: right),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding:
          margin ??
          const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            LoopSpacing.card,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (index, row) in rows.indexed) ...<Widget>[
            if (index > 0) const SizedBox(height: gap),
            row,
          ],
        ],
      ),
    );
  }
}

class _LoopStatCell extends StatelessWidget {
  const _LoopStatCell({required this.stat});

  final LoopStat stat;

  @override
  Widget build(BuildContext context) {
    final figureColor = switch (stat.tone) {
      LoopStatTone.up => LoopColors.lime,
      LoopStatTone.down || LoopStatTone.neutral => LoopGround.inkOf(context),
    };
    return Semantics(
      container: true,
      label: '${stat.label} ${stat.isUnread ? '未读取' : stat.value}',
      child: Container(
        key: stat.statKey,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: LoopGround.tintOf(context),
          borderRadius: LoopRadius.control,
          border: Border.all(color: LoopGround.hairlineOf(context)),
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                stat.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopTypography.figure(13, color: figureColor),
              ),
              const SizedBox(height: 4),
              Text(
                stat.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopTypography.eyebrow(
                  11,
                  color: LoopGround.auxiliaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// .chart-panel
// ---------------------------------------------------------------------------

/// `.chart-panel`: the Graphite plot card with a `.chart-meta` header.
///
/// The header is three slots — range, current value, direction — exactly as
/// the prototype writes them, and [child] is whatever may honestly be drawn
/// under it. A panel with no series draws nothing and states [absence]; it
/// never falls back to a shape, because a shape that is not a price is a
/// claim.
class LoopChartPanel extends StatelessWidget {
  const LoopChartPanel({
    required this.range,
    super.key,
    this.current,
    this.direction,
    this.directionUp,
    this.child,
    this.absence,
    this.height = 156,
  }) : assert(
         child != null || absence != null,
         'A chart panel draws a series or says why it cannot.',
       );

  /// `[data-chart-range]` — the window the series covers.
  final String range;

  /// `[data-chart-current]` — the latest figure, or null when unread.
  final String? current;

  /// `[data-chart-direction]` — the change over the window.
  final String? direction;

  /// true: `.up` Lime; false: Chalk; null: neutral.
  final bool? directionUp;

  /// The plot. Null when there is no series to draw.
  final Widget? child;

  /// Why nothing is drawn. Rendered in the plot's room, left-aligned, so the
  /// panel keeps its place in the page rather than collapsing.
  final String? absence;

  /// `.chart-panel{min-height:156px}`.
  final double height;

  /// The ink of the Graphite ground this panel paints.
  ///
  /// The panel's fill is opaque and does not change with what it was placed
  /// on, so it declares its own ground rather than letting a descendant derive
  /// Ink from a Chalk card it happens to sit inside.
  static const Color _ink = LoopColors.chalk;

  @override
  Widget build(BuildContext context) {
    final plot = child;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        LoopSpacing.card,
      ),
      child: Container(
        key: const ValueKey<String>('loop-chart-panel'),
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LoopColors.graphite,
          borderRadius: LoopRadius.card,
          border: Border.all(color: LoopColors.line),
        ),
        // The panel is Graphite whatever it was put on, so it declares its
        // own ground: a caller that placed it on a Chalk card would otherwise
        // leave every figure in it deriving Ink and painting nothing.
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: _ink),
          child: IconTheme.merge(
            data: const IconThemeData(color: _ink),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        range,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopTypography.figure(
                          11,
                          color: LoopColors.muted,
                        ),
                      ),
                    ),
                    if (current != null) ...<Widget>[
                      const SizedBox(width: 10),
                      Text(
                        current!,
                        style: LoopTypography.figure(11, color: _ink),
                      ),
                    ],
                    if (direction != null) ...<Widget>[
                      const SizedBox(width: 10),
                      Text(
                        direction!,
                        style: LoopTypography.figure(
                          11,
                          color: switch (directionUp) {
                            true => LoopColors.lime,
                            false => _ink,
                            null => LoopColors.muted,
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (plot != null)
                  SizedBox(height: height - 56, child: plot)
                else
                  SizedBox(
                    height: height - 56,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        absence!,
                        key: const ValueKey<String>('loop-chart-panel-absence'),
                        style: LoopTypography.caption(
                          11,
                          color: LoopColors.text3,
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// .row-ico
// ---------------------------------------------------------------------------

/// `.row-ico`: the 44px rounded tile at the head of a record row.
///
/// The audit's item 7 — rows with no leading column — is this widget missing.
/// It takes a sprite glyph or a short monogram; the tint is the prototype's
/// soft ground for the meaning the row carries.
class LoopRowIcon extends StatelessWidget {
  const LoopRowIcon({
    super.key,
    this.icon,
    this.monogram,
    this.tone = LoopRowIconTone.neutral,
    this.semanticLabel,
    this.size = 44,
  }) : assert(
         icon != null || monogram != null,
         'A row icon carries a glyph or a monogram.',
       );

  final String? icon;
  final String? monogram;
  final LoopRowIconTone tone;
  final String? semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      LoopRowIconTone.accent => (LoopColors.limeSoft, LoopColors.lime),
      LoopRowIconTone.neutral => (
        LoopGround.fillOf(context),
        LoopGround.secondaryOf(context),
      ),
    };
    final glyph = icon;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: glyph != null
            ? LoopIcon(glyph, size: 21, color: foreground)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  monogram!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: LoopTypography.figure(11, color: foreground),
                ),
              ),
      ),
    );
  }
}

/// The two grounds a [LoopRowIcon] is painted on.
enum LoopRowIconTone { neutral, accent }

// ---------------------------------------------------------------------------
// .wallet-primary-actions / .wallet-action-grid
// ---------------------------------------------------------------------------

/// One entry of a wallet action group.
///
/// [onPressed] and [blockedReason] are exclusive: an action either runs or
/// states, on the tap, the one sentence that says why it cannot. The shape
/// never changes — that is the whole point of the audit's item 3, where four
/// actions had been demoted to list rows wearing a grey badge.
@immutable
class LoopAction {
  const LoopAction({
    required this.label,
    required this.actionKey,
    this.icon,
    this.onPressed,
    this.blockedReason,
  }) : assert(
         onPressed == null || blockedReason == null,
         'An action either runs or says why it cannot.',
       );

  final String label;
  final Key actionKey;
  final String? icon;
  final VoidCallback? onPressed;

  /// The server's own sentence, shown on tap while the action cannot run.
  final String? blockedReason;

  bool get isBlocked => onPressed == null;
}

/// `.wallet-action-grid`: equal-width tiles, glyph over label.
class LoopActionGrid extends StatelessWidget {
  const LoopActionGrid({
    required this.actions,
    required this.onBlocked,
    super.key,
  });

  final List<LoopAction> actions;

  /// What a blocked tile does with its reason. The page owns the surface the
  /// sentence appears on, so the grid never picks one.
  final void Function(String reason) onBlocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        LoopSpacing.card,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (index, action) in actions.indexed) ...<Widget>[
              if (index > 0) const SizedBox(width: 9),
              Expanded(
                child: _LoopActionTile(action: action, onBlocked: onBlocked),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoopActionTile extends StatelessWidget {
  const _LoopActionTile({required this.action, required this.onBlocked});

  final LoopAction action;
  final void Function(String reason) onBlocked;

  @override
  Widget build(BuildContext context) {
    final blocked = action.isBlocked;
    final reason = action.blockedReason;
    final foreground = LoopGround.inkOf(context);
    final content = Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: LoopGround.fillOf(context),
        borderRadius: LoopRadius.control,
        border: Border.all(color: LoopGround.edgeOf(context)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (action.icon != null) ...<Widget>[
            LoopIcon(action.icon!, size: 17, color: foreground),
            const SizedBox(height: 5),
          ],
          Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoopTypography.label(
              12,
              weight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
    return _LoopGatedSurface(
      surfaceKey: action.actionKey,
      label: action.label,
      blocked: blocked,
      reason: reason,
      onPressed: action.onPressed,
      onBlocked: onBlocked,
      borderRadius: LoopRadius.control,
      child: content,
    );
  }
}

/// `.wallet-primary-actions`: the Pay pill beside the compact swap button.
///
/// Two thirds / one third, 64px tall, exactly as the prototype's grid
/// template. Either entry may be blocked; a blocked entry keeps the shape.
class LoopPrimaryActionRow extends StatelessWidget {
  const LoopPrimaryActionRow({
    required this.primary,
    required this.secondary,
    required this.onBlocked,
    super.key,
  });

  final LoopAction primary;
  final LoopAction secondary;
  final void Function(String reason) onBlocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        10,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 2,
              child: _LoopPayTile(action: primary, onBlocked: onBlocked),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LoopCompactTile(action: secondary, onBlocked: onBlocked),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoopPayTile extends StatelessWidget {
  const _LoopPayTile({required this.action, required this.onBlocked});

  final LoopAction action;
  final void Function(String reason) onBlocked;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[LoopColors.limeHighlight, LoopColors.lime],
          stops: <double>[0, 0.62],
        ),
        borderRadius: LoopRadius.card,
        border: Border.fromBorderSide(BorderSide(color: LoopColors.lime)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x42B8FF20),
            offset: Offset(0, 10),
            blurRadius: 26,
          ),
          BoxShadow(
            color: Color(0x6B050604),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (action.icon != null) ...<Widget>[
            LoopIcon(action.icon!, size: 21, color: LoopColors.ink),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.label(
                16,
                weight: FontWeight.w800,
                color: LoopColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
    return _LoopGatedSurface(
      surfaceKey: action.actionKey,
      label: action.label,
      blocked: action.isBlocked,
      reason: action.blockedReason,
      onPressed: action.onPressed,
      onBlocked: onBlocked,
      borderRadius: LoopRadius.card,
      child: content,
    );
  }
}

class _LoopCompactTile extends StatelessWidget {
  const _LoopCompactTile({required this.action, required this.onBlocked});

  final LoopAction action;
  final void Function(String reason) onBlocked;

  @override
  Widget build(BuildContext context) {
    final foreground = LoopGround.inkOf(context);
    final content = Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: LoopGround.fillOf(context),
        borderRadius: LoopRadius.card,
        border: Border.all(color: LoopGround.edgeOf(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (action.icon != null) ...<Widget>[
            LoopIcon(action.icon!, size: 17, color: foreground),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.label(
                12,
                weight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
    return _LoopGatedSurface(
      surfaceKey: action.actionKey,
      label: action.label,
      blocked: action.isBlocked,
      reason: action.blockedReason,
      onPressed: action.onPressed,
      onBlocked: onBlocked,
      borderRadius: LoopRadius.card,
      child: content,
    );
  }
}

/// A control that keeps its shape while it cannot run.
///
/// Disabled paint, disabled semantics, and a tap that answers with the one
/// sentence the server gave — the same contract [LoopSeg.onBlocked] already
/// holds for a filter chip, applied to an action.
class _LoopGatedSurface extends StatelessWidget {
  const _LoopGatedSurface({
    required this.surfaceKey,
    required this.label,
    required this.blocked,
    required this.child,
    required this.borderRadius,
    required this.onBlocked,
    this.reason,
    this.onPressed,
  });

  final Key surfaceKey;
  final String label;
  final bool blocked;
  final String? reason;
  final VoidCallback? onPressed;
  final void Function(String reason) onBlocked;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sentence = reason;
    final tap = blocked
        ? (sentence == null ? null : () => onBlocked(sentence))
        : onPressed;
    return MergeSemantics(
      child: Semantics(
        key: surfaceKey,
        button: true,
        enabled: !blocked,
        label: label,
        hint: blocked ? sentence : null,
        child: Opacity(
          opacity: blocked ? 0.4 : 1,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: tap,
              borderRadius: borderRadius,
              child: ExcludeSemantics(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// .search-trigger.dapp-omnibox
// ---------------------------------------------------------------------------

/// `.dapp-omnibox`: the address bar that sits above the DApp page's primary.
///
/// It is a field, not a row: the prototype puts the typed origin at the top of
/// the page, where a browser puts it, and the review below reads it.
class LoopOmnibox extends StatelessWidget {
  const LoopOmnibox({
    required this.controller,
    required this.hintText,
    super.key,
    this.onChanged,
    this.trailingKey,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  /// `.search-trigger .key`: the scope chip at the right edge.
  final String? trailingKey;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        LoopSpacing.card,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: LoopColors.card,
          borderRadius: LoopRadius.control,
          border: Border.all(color: LoopColors.line),
        ),
        child: Row(
          children: <Widget>[
            const LoopIcon('search', size: 17, color: LoopColors.text3),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: fieldKey,
                controller: controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: onChanged,
                style: LoopTypography.figure(13),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: hintText,
                  hintStyle: LoopTypography.caption(11),
                ),
              ),
            ),
            if (trailingKey != null) ...<Widget>[
              const SizedBox(width: 10),
              LoopBadge(trailingKey!),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// chip row (.pad > div[display:flex;gap:6px;overflow-x:auto])
// ---------------------------------------------------------------------------

/// The scrollable badge strip the prototype puts under a chalk primary.
class LoopChipRow extends StatelessWidget {
  const LoopChipRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        LoopSpacing.card,
      ),
      child: Row(
        children: <Widget>[
          for (final (index, chip) in children.indexed) ...<Widget>[
            if (index > 0) const SizedBox(width: 6),
            chip,
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// .empty placeholder block (pay's viewfinder)
// ---------------------------------------------------------------------------

/// The large dark placeholder the prototype keeps where a surface would be.
///
/// `pay` renders its viewfinder this way: the block that is not there still
/// occupies the room it will take, so the page reads as a deferred capability
/// rather than as a page with nothing on it (audit item 4).
class LoopPlaceholderStage extends StatelessWidget {
  const LoopPlaceholderStage({
    required this.icon,
    required this.title,
    required this.badge,
    required this.body,
    super.key,
    this.height = 220,
  });

  final String icon;
  final String title;
  final String badge;
  final String body;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        LoopSpacing.card,
      ),
      child: Container(
        key: const ValueKey<String>('loop-placeholder-stage'),
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LoopColors.graphite,
          borderRadius: LoopRadius.card,
          border: Border.all(color: LoopColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            LoopIcon(icon, size: 34, color: LoopColors.text3),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopTypography.title(15),
                  ),
                ),
                const SizedBox(width: 8),
                LoopBadge(badge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: LoopTypography.caption(11),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// .card — a figure box that states what it does not have
// ---------------------------------------------------------------------------

/// The prototype's amount box (`.card` with a caption, a mono figure and a
/// unit badge), used by swap, bridge and send.
///
/// [figure] is [loopFigureDash] when there is no quote. The box is then the
/// shape of the answer that is missing, which is what the prototype's swap and
/// bridge pages look like before a route exists — not an empty page.
class LoopFigureBox extends StatelessWidget {
  const LoopFigureBox({
    required this.caption,
    required this.figure,
    super.key,
    this.unit,
    this.footnote,
    this.margin = const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      0,
      LoopSpacing.page,
      8,
    ),
  });

  final String caption;
  final String figure;
  final String? unit;
  final String? footnote;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LoopGround.tintOf(context),
          borderRadius: LoopRadius.control,
          border: Border.all(color: LoopGround.hairlineOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              caption,
              style: LoopTypography.caption(
                11,
                color: LoopGround.auxiliaryOf(context),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    figure,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopTypography.figure(
                      21,
                      color: LoopGround.inkOf(context),
                    ),
                  ),
                ),
                if (unit != null) ...<Widget>[
                  const SizedBox(width: 8),
                  LoopBadge(unit!),
                ],
              ],
            ),
            if (footnote != null) ...<Widget>[
              const SizedBox(height: 5),
              Text(
                footnote!,
                style: LoopTypography.caption(
                  11,
                  color: LoopGround.auxiliaryOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
