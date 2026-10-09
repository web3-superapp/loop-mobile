import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// One person in a [LoopAvatarStack].
@immutable
final class LoopAvatarStackEntry {
  const LoopAvatarStackEntry({required this.label, this.avatarBuilder});

  /// The name the owner already resolved for this person — an alias, a LOOP
  /// ID, or 「匿名成员」 under the owner's own anonymity rule. The stack never
  /// invents one; spread, it prints the first
  /// [LoopAvatarStack.labelMaxCharacters] characters of it under the face
  /// (with 「…」 when longer), and a screen reader hears it whole.
  final String label;

  /// Builds the face at the given diameter; `null` draws the initials of
  /// [label], which is the one thing a LOOP surface may draw for a person it
  /// has no picture of.
  final Widget Function(double size)? avatarBuilder;
}

/// Overlapping faces that spread into a named row (decision 0092).
///
/// Stacked, each face covers a third of the one before it (the offset is
/// `size × 2/3`) and a last 「+N」 disc counts everybody the stack does not
/// draw. A tap spreads them, one after another
/// ([LoopMotion.avatarStagger] apart), into a row that scrolls sideways and
/// names each person under their face; a second tap gathers them back along
/// the same curve. With motion reduced both happen at once.
///
/// Spread, each face just touches the one before it (the offset is `size`,
/// no gap), and a cell is exactly one face wide: a long name is cut to
/// [labelMaxCharacters] characters and 「…」 and never widens its cell (user
/// ruling 2026-09-27 on decision 0092).
///
/// Each face is drawn on a disc of [ringColor], so where one covers another
/// it really covers it: two translucent monograms overlapping would mix into
/// a third tint that belongs to nobody.
class LoopAvatarStack extends StatefulWidget {
  const LoopAvatarStack({
    required this.entries,
    super.key,
    this.total,
    this.size = 40,
    this.ringColor,
    this.semanticLabel,
    this.onExpansionChanged,
  });

  final List<LoopAvatarStackEntry> entries;

  /// How many people the stack stands for. When it is larger than
  /// [entries], the difference is the 「+N」 disc. `null` draws no disc.
  final int? total;

  /// A face's diameter.
  final double size;

  /// The disc under each face; defaults to the ground the stack sits on
  /// (Ink on the Ink page, Chalk on a light card).
  final Color? ringColor;

  /// What a screen reader hears before the names.
  final String? semanticLabel;

  final ValueChanged<bool>? onExpansionChanged;

  /// How many characters of a name the spread row prints before 「…」.
  static const int labelMaxCharacters = 6;

  /// The spread caption for [label]: its first [labelMaxCharacters]
  /// characters, with 「…」 when it had more.
  static String spreadLabel(String label) {
    final characters = label.characters;
    if (characters.length <= labelMaxCharacters) return label;
    return '${characters.take(labelMaxCharacters)}…';
  }

  /// Space between a face and its name when spread.
  static const double labelGap = 6;

  /// One caption line.
  static const double labelHeight = 16;

  /// Ring width around each face.
  static const double ringWidth = 2;

  @override
  State<LoopAvatarStack> createState() => _LoopAvatarStackState();
}

class _LoopAvatarStackState extends State<LoopAvatarStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  final ScrollController _scroll = ScrollController();
  bool _expanded = false;

  /// One curved animation per drawn element, staggered along [_controller].
  List<Animation<double>> _items = const <Animation<double>>[];
  late Animation<double> _overall;
  int _count = -1;

  int get _remaining {
    final total = widget.total;
    if (total == null) return 0;
    return math.max(0, total - widget.entries.length);
  }

  int get _elementCount => widget.entries.length + (_remaining > 0 ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _rebuildTimeline();
  }

  @override
  void didUpdateWidget(LoopAvatarStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_elementCount != _count) _rebuildTimeline();
  }

  void _rebuildTimeline() {
    final count = _elementCount;
    _count = count;
    final spread = LoopMotion.avatarSpread.inMicroseconds;
    final stagger = LoopMotion.avatarStagger.inMicroseconds;
    final total = spread + stagger * math.max<int>(0, count - 1);
    _controller.duration = Duration(microseconds: total);
    _items = <Animation<double>>[
      for (var index = 0; index < count; index += 1)
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * stagger / total,
            (index * stagger + spread) / total,
            curve: LoopMotion.avatarCurve,
          ),
        ),
    ];
    _overall = CurvedAnimation(
      parent: _controller,
      curve: LoopMotion.avatarCurve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toggle() {
    final expanded = !_expanded;
    setState(() => _expanded = expanded);
    final reduced = LoopMotion.reduced(context);
    if (!expanded && _scroll.hasClients && _scroll.offset != 0) {
      // Gathering always returns to the start of the row, where the stack
      // stands; the faces travel home from wherever the row was scrolled to.
      if (reduced) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(
          0,
          duration: LoopMotion.avatarSpread,
          curve: LoopMotion.avatarCurve,
        );
      }
    }
    if (reduced) {
      _controller.value = expanded ? 1 : 0;
    } else if (expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onExpansionChanged?.call(expanded);
  }

  Color _ring(BuildContext context) {
    final explicit = widget.ringColor;
    if (explicit != null) return explicit;
    // The ground's ink is Chalk on the Ink page and Ink on a light card, so
    // the ground itself is the other one.
    final ink = LoopGround.inkOf(context);
    return ink.computeLuminance() > 0.5 ? LoopColors.ink : LoopColors.chalk;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final count = _elementCount;
    final ring = _ring(context);
    final step = size * LoopMotion.avatarStackStep;
    // Spread, a cell is one face wide and the faces touch: offset = size.
    final cell = size;
    final stackedWidth = count == 0 ? 0.0 : size + step * (count - 1);
    final spreadWidth = cell * count;
    // The caption line grows with the reader's text size, so the row that
    // scrolls sideways grows with it and never clips a name.
    final labelHeight = math.max(
      LoopAvatarStack.labelHeight,
      (MediaQuery.textScalerOf(context).scale(_labelFontSize) * 1.35)
          .ceilToDouble(),
    );
    final spreadHeight = size + LoopAvatarStack.labelGap + labelHeight;
    final remaining = _remaining;
    final names = <String>[for (final entry in widget.entries) entry.label];
    final semantics = <String>[
      ?widget.semanticLabel,
      names.join('、'),
      if (remaining > 0) '另外 $remaining 人',
    ].join('，');

    Widget face(int index) {
      final Widget inner;
      if (index < widget.entries.length) {
        final entry = widget.entries[index];
        final innerSize = size - LoopAvatarStack.ringWidth * 2;
        inner =
            entry.avatarBuilder?.call(innerSize) ??
            LoopInitialsAvatar(label: entry.label, size: innerSize);
      } else {
        inner = _OverflowDisc(
          remaining: remaining,
          size: size - LoopAvatarStack.ringWidth * 2,
        );
      }
      return Container(
        key: ValueKey<String>('loop-avatar-stack-face-$index'),
        width: size,
        height: size,
        padding: const EdgeInsets.all(LoopAvatarStack.ringWidth),
        decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
        child: ClipOval(child: inner),
      );
    }

    final content = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _overall.value;
        final width = stackedWidth + (spreadWidth - stackedWidth) * t;
        final height = size + (spreadHeight - size) * t;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (var index = 0; index < count; index += 1) ...<Widget>[
                Positioned(
                  left: _lerp(index * step, index * cell, _items[index].value),
                  top: 0,
                  child: face(index),
                ),
                // Stacked, the names are not built at all: they would be
                // copies of the directory's own rows, clipped to nothing.
                if (index < widget.entries.length && !_controller.isDismissed)
                  Positioned(
                    left: index * cell,
                    top: size + LoopAvatarStack.labelGap,
                    width: cell,
                    height: labelHeight,
                    child: FadeTransition(
                      opacity: _items[index],
                      child: Text(
                        LoopAvatarStack.spreadLabel(
                          widget.entries[index].label,
                        ),
                        key: ValueKey<String>('loop-avatar-stack-name-$index'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: LoopTypography.caption(
                          _labelFontSize,
                          color: LoopGround.secondaryOf(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );

    return Semantics(
      button: true,
      expanded: _expanded,
      label: semantics,
      excludeSemantics: true,
      child: LoopPressable(
        key: const ValueKey<String>('loop-avatar-stack-toggle'),
        scale: false,
        onTap: count == 0 ? null : _toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: SingleChildScrollView(
              key: const ValueKey<String>('loop-avatar-stack-scroll'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: _expanded
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static const double _labelFontSize = 11;
}

/// The last disc of a stack: how many people it does not draw.
class _OverflowDisc extends StatelessWidget {
  const _OverflowDisc({required this.remaining, required this.size});

  final int remaining;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('loop-avatar-stack-more'),
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: LoopGround.fillOf(context),
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '+$remaining',
          maxLines: 1,
          style: LoopTypography.figure(
            size * 0.34,
            color: LoopGround.inkOf(context),
          ),
        ),
      ),
    );
  }
}
