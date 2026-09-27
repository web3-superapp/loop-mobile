import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// A small outlined mono tag naming the backend environment (`DEV`,
/// `STAGING`, …) on a non-release build (decision 0100).
///
/// It is not a control: no touch target, and it reads as 「服务端 DEV」 so a
/// screen reader does not announce a bare acronym. Colours come from the
/// ground it sits on, so it works on the Ink page and on a Chalk card alike.
class LoopEnvironmentTag extends StatelessWidget {
  const LoopEnvironmentTag(this.label, {super.key});

  final String label;

  /// The tag's own box height: 11 px Plex Mono at line height 1 plus 2 px
  /// above and below, plus the 1 px edge.
  static const double height = 16;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '服务端 $label',
      excludeSemantics: true,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          border: Border.all(color: LoopGround.edgeOf(context)),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: LoopTypography.code(
            11,
            height: 1,
            color: LoopGround.secondaryOf(context),
          ),
        ),
      ),
    );
  }
}
