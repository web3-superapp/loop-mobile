import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// The text an unread count is printed as, or null when nothing is drawn.
///
/// Null (no source) and zero both draw nothing; above 99 the badge reads
/// `99+` (decision 0105 · 6).
String? loopUnreadBadgeLabel(int? count) {
  if (count == null || count <= 0) return null;
  return count > 99 ? '99+' : '$count';
}

/// The unread mark: an 8 dp dot, or a 16 dp high pill with the count.
///
/// Drawn in the warning red so it reads on Ink and on a Lime control alike,
/// and excluded from semantics: the control it sits on says the count in its
/// own label.
class LoopUnreadBadge extends StatelessWidget {
  const LoopUnreadBadge({
    required this.count,
    super.key,
    this.dot = false,
    this.color = LoopColors.danger,
  });

  final int? count;

  /// The badge's fill. The inbox rows draw it in Lime (decision 0122); every
  /// other place keeps the warning red, which reads on a Lime control too.
  final Color color;

  /// A dot without a number.
  final bool dot;

  static const double dotSize = 8;
  static const double pillHeight = 16;

  @override
  Widget build(BuildContext context) {
    final label = loopUnreadBadgeLabel(count);
    if (label == null) return const SizedBox.shrink();
    if (dot) {
      return ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey<String>('loop-unread-dot'),
          width: dotSize,
          height: dotSize,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey<String>('loop-unread-pill'),
        height: pillHeight,
        constraints: const BoxConstraints(minWidth: pillHeight),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(pillHeight / 2)),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: LoopTypography.figure(10, color: LoopColors.ink, height: 1),
        ),
      ),
    );
  }
}
