import 'package:flutter/material.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';

/// A collection that has nothing in it yet (decision 0122).
///
/// One drawing, one title, at most one sentence and at most one next step,
/// centred. It replaced the inline `LoopEmpty` strip — a 17px glyph and two
/// lines of 11px grey in the top-left corner — everywhere; the strip itself
/// was deleted by decision 0183.
///
/// S325 · decision 0255 (UX-003): every empty state draws the same grey
/// spray-paint crown ([LoopEmptyArt]) — the line drawings in Yellow and
/// white read as a different product from the wall pages around them. A
/// page that needs its own drawing passes [art]; [illustration] is what the
/// collection is (kept for callers and their tests), no longer a drawing.
///
/// A page-level state takes roughly half the viewport and centres itself in
/// it, so it sits in the middle of the content area under the page's own
/// chips. [compact] is for a block inside a page — a chart, a holder list —
/// and draws a smaller crown with 32 above it.
class LoopEmptyState extends StatelessWidget {
  const LoopEmptyState({
    required this.title,
    super.key,
    this.illustration,
    this.art,
    this.message,
    this.action,
    this.compact = false,
  });

  /// What the empty collection is. Not drawn since decision 0255.
  final LoopIllustration? illustration;

  /// Replaces the crown when a page has a drawing of its own.
  final Widget? art;
  final String title;

  /// The one sentence under the title: what will appear here, never how to
  /// use the page.
  final String? message;

  /// The one next step, usually a primary [LoopButton].
  final Widget? action;
  final bool compact;

  /// The crown's width on a page and inside a block.
  static const double illustrationSize = 72;
  static const double compactIllustrationSize = 56;

  @override
  Widget build(BuildContext context) {
    final size = compact ? compactIllustrationSize : illustrationSize;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The drawing is keyed by the collection it stands for, so a page
        // can still be told which empty state it shows.
        KeyedSubtree(
          key: switch (illustration) {
            final LoopIllustration kind => ValueKey<String>(
              'loop-empty-illustration-${kind.fileName}',
            ),
            null => null,
          },
          child: art ?? LoopEmptyArt(width: size),
        ),
        SizedBox(height: compact ? 12 : 16),
        Text(
          title,
          key: const ValueKey<String>('loop-empty-title'),
          textAlign: TextAlign.center,
          style: compact ? LoopType.title : LoopType.titleLg,
        ),
        if (message case final String line) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            line,
            key: const ValueKey<String>('loop-empty-message'),
            textAlign: TextAlign.center,
            style: LoopType.bodySm.copyWith(color: LoopColors.text2),
          ),
        ],
        if (action case final Widget next) ...<Widget>[
          SizedBox(height: compact ? 14 : 20),
          next,
        ],
      ],
    );
    final padded = Padding(
      padding: EdgeInsets.fromLTRB(32, compact ? 32 : 24, 32, 24),
      child: Semantics(container: true, child: body),
    );
    if (compact) {
      return Center(
        key: const ValueKey<String>('loop-empty-state'),
        child: padded,
      );
    }
    final viewport = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      key: const ValueKey<String>('loop-empty-state'),
      constraints: BoxConstraints(minHeight: viewport * 0.64),
      child: Center(child: padded),
    );
  }
}
