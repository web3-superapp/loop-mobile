import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';

// ---------------------------------------------------------------------------
// S241b-G2 · MEME page pieces in the looplabs language (decision 0210,
// docs/42 附A §2 / §5)
// ---------------------------------------------------------------------------
//
// Shared by the MEME pages (launch2, the classic curve, IDO, market and the
// reward pages) without touching `lib/widgets/`: the two-tone folio heading
// (Yellow line over a Purple line), the stat figures in the Anton
// `statFigure` step, and the stage tag in its three tones.

/// Redraws a folio heading [Text] as two lines: [first] in Yellow over
/// [second] in [secondColor] (Purple by default) — looplabs' 「ATTENTION IS
/// THE START. / COMMUNITY IS THE LOOP.」 heading, on the flat dark card.
/// Anything that is not a [Text] comes back as it is.
Widget memeTwoToneHeading(
  Widget heading, {
  required String first,
  required String second,
  Color secondColor = LoopColors.purple,
}) {
  if (heading is! Text) return heading;
  final style = heading.style ?? const TextStyle();
  return Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(text: first),
        const TextSpan(text: '\n'),
        TextSpan(
          text: second,
          style: TextStyle(color: secondColor),
        ),
      ],
    ),
    key: heading.key,
    maxLines: heading.maxLines,
    overflow: heading.overflow,
    style: style.copyWith(color: LoopColors.yellow),
  );
}

/// The looplabs stat block (`.stat-value`): pairs of flat cells, each figure
/// in [LoopType.statFigure] Yellow (Anton [LoopType.heroFigure] on the project
/// page hero) over a small label. A
/// figure wider than its cell scales down rather than wrapping. Each cell
/// keeps its [LoopStat.statKey] and reads as one sentence, exactly as
/// [LoopStatGrid] did.
class MemeStatFigures extends StatelessWidget {
  const MemeStatFigures({
    required this.stats,
    super.key,
    this.margin,
    this.hero = false,
  });

  final List<LoopStat> stats;
  final EdgeInsets? margin;

  /// The MEME project page's hero figures: the one place Anton survives
  /// ([LoopType.heroFigure], docs/42 附C §2). Elsewhere the figures are the
  /// Arimo [LoopType.statFigure].
  final bool hero;

  /// Between two cells and two rows of cells: 12 (decision 0229).
  static const double gap = LoopSpacing.rowGap;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var index = 0; index < stats.length; index += 2) {
      final left = stats[index];
      final right = index + 1 < stats.length ? stats[index + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _MemeStatCell(stat: left, hero: hero),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : _MemeStatCell(stat: right, hero: hero),
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
            LoopSpacing.rowGap,
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

class _MemeStatCell extends StatelessWidget {
  const _MemeStatCell({required this.stat, required this.hero});

  final LoopStat stat;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    // A figure not read yet (the dash) stays grey: Yellow is for a number.
    final figureColor = stat.isUnread
        ? LoopColors.text3
        : switch (stat.tone) {
            LoopStatTone.up || LoopStatTone.neutral => LoopColors.yellow,
            LoopStatTone.down => LoopColors.chalk,
          };
    return Semantics(
      container: true,
      label: '${stat.label} ${stat.isUnread ? '未读取' : stat.value}',
      child: Container(
        key: stat.statKey,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          color: LoopColors.card,
          borderRadius: LoopRadius.control,
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // A fixed line box: a Han unit (「枚」) falls back to a face
              // with a taller line than Arimo's, and an unfixed box let the
              // pair's IntrinsicHeight under-measure the cell (decision 0229).
              SizedBox(
                height: 36,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stat.value,
                    maxLines: 1,
                    style: (hero ? LoopType.heroFigure : LoopType.statFigure)
                        .copyWith(
                          color: figureColor,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: LoopType.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three tones a stage tag takes on the MEME pages.
enum MemeTagTone {
  /// Takes orders now: Yellow word in a 1px Yellow frame, no fill.
  live,

  /// Done and trading elsewhere (graduated): Purple 9 % ground, Purple
  /// frame, Chalk word.
  done,

  /// Waiting or held: the raised grey ground, Text2 word.
  idle,
}

/// The decoration of a stage tag in [tone] (decision 0212, docs/42 附C §4:
/// a capsule on a soft ground — Yellow 13 % live, Purple 18 % graduated,
/// raised grey waiting; never solid Yellow).
BoxDecoration memeTagDecoration(MemeTagTone tone) => switch (tone) {
  MemeTagTone.live => const BoxDecoration(
    color: LoopColors.yellowSoft,
    borderRadius: LoopRadius.pill,
  ),
  MemeTagTone.done => const BoxDecoration(
    color: LoopColors.purpleTint,
    borderRadius: LoopRadius.pill,
  ),
  MemeTagTone.idle => const BoxDecoration(
    color: LoopColors.card2,
    borderRadius: LoopRadius.pill,
  ),
};

/// The word colour of a stage tag in [tone].
Color memeTagInk(MemeTagTone tone) => switch (tone) {
  MemeTagTone.live => LoopColors.yellow,
  MemeTagTone.done => LoopColors.purple,
  MemeTagTone.idle => LoopColors.text2,
};
