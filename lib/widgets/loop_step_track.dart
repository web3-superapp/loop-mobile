import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// Where a multi-step flow or a project's milestones stand (decision 0169).
///
/// One part for what MEME 创建, v2 发射创建 and the v2 项目状态页 each drew
/// by hand with their own literal corners:
///
/// - [LoopStepTrack.dots]: the step dots of a flow — every reached step a
///   Lime dot, the current one a 22 px Lime bar, the rest Line2 — and
///   「2 / 3 · 名称」 beside them.
/// - [LoopStepTrack.milestones]: a row of equal 4 px segments, each with its
///   name under it. Reached segments are Lime; a current one that failed is
///   drawn in Chalk, not in a red the prototype does not have — the page's
///   own `LoopNotice` says what went wrong.
///
/// Both read as one sentence to a screen reader ([semanticLabel]).
class LoopStepTrack extends StatelessWidget {
  const LoopStepTrack.dots({
    required this.labels,
    required this.current,
    super.key,
  }) : milestones = false,
       reachedCurrent = false,
       failed = false,
       semanticLabel = null;

  const LoopStepTrack.milestones({
    required this.labels,
    required this.current,
    required String this.semanticLabel,
    super.key,
    this.reachedCurrent = false,
    this.failed = false,
  }) : milestones = true;

  final List<String> labels;

  /// Index of the step the flow or project is on.
  final int current;

  /// Draw [labels] as milestone segments rather than step dots.
  final bool milestones;

  /// The current milestone is complete itself (the project is active).
  final bool reachedCurrent;

  /// The current milestone failed.
  final bool failed;

  /// What a screen reader hears; the dots say 「第 N 步，共 M 步，名称」.
  final String? semanticLabel;

  static const double dotSize = 8;
  static const double currentDotWidth = 22;
  static const double segmentHeight = 4;

  @override
  Widget build(BuildContext context) {
    final label =
        semanticLabel ??
        '第 ${current + 1} 步，共 ${labels.length} 步，${labels[current]}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        LoopSpacing.page,
        LoopSpacing.x1,
        LoopSpacing.page,
        milestones ? LoopSpacing.x5 : 14,
      ),
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: milestones ? _segments() : _dots(),
      ),
    );
  }

  Widget _dots() => Row(
    children: <Widget>[
      for (var i = 0; i < labels.length; i += 1) ...<Widget>[
        Container(
          width: i == current ? currentDotWidth : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: i <= current ? LoopColors.lime : LoopColors.line2,
            borderRadius: LoopRadius.pill,
          ),
        ),
        const SizedBox(width: 6),
      ],
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          '${current + 1} / ${labels.length} · ${labels[current]}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LoopType.caption.copyWith(color: LoopColors.text2),
        ),
      ),
    ],
  );

  /// The fill of milestone [i].
  Color segmentColor(int i) {
    if (i < current || (i == current && reachedCurrent)) return LoopColors.lime;
    if (i == current) return failed ? LoopColors.chalk : LoopColors.lime;
    return LoopColors.line2;
  }

  Widget _segments() => Row(
    children: <Widget>[
      for (var i = 0; i < labels.length; i += 1) ...<Widget>[
        Expanded(
          child: Column(
            children: <Widget>[
              Container(
                key: ValueKey<String>('loop-step-track-segment-$i'),
                height: segmentHeight,
                decoration: BoxDecoration(
                  color: segmentColor(i),
                  borderRadius: LoopRadius.pill,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                style: LoopType.captionSm.copyWith(
                  color: i <= current ? LoopColors.chalk : LoopColors.text3,
                ),
              ),
            ],
          ),
        ),
        if (i < labels.length - 1) const SizedBox(width: LoopSpacing.x1),
      ],
    ],
  );
}
