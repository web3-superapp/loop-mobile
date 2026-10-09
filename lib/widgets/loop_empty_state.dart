import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// A collection that has nothing in it yet (decision 0122).
///
/// One line illustration, one title, at most one sentence and at most one
/// next step, centred. It replaces the inline [LoopEmpty] strip — a 17px
/// glyph and two lines of 11px grey in the top-left corner — wherever a whole
/// list or a whole block is empty; the strip stays for the inline cases.
///
/// A page-level state takes roughly half the viewport and centres itself in
/// it, so it sits in the middle of the content area under the page's own
/// chips. [compact] is for a block inside a page — a chart, a holder list —
/// and draws the illustration at 64 with 32 above it.
class LoopEmptyState extends StatelessWidget {
  const LoopEmptyState({
    required this.illustration,
    required this.title,
    super.key,
    this.message,
    this.action,
    this.compact = false,
  });

  final LoopIllustration illustration;
  final String title;
  final String? message;

  /// The one next step, usually a primary [LoopButton].
  final Widget? action;
  final bool compact;

  static const double illustrationSize = 96;
  static const double compactIllustrationSize = 64;

  @override
  Widget build(BuildContext context) {
    final size = compact ? compactIllustrationSize : illustrationSize;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SvgPicture.asset(
          illustration.asset,
          key: ValueKey<String>(
            'loop-empty-illustration-${illustration.fileName}',
          ),
          width: size,
          height: size,
          excludeFromSemantics: true,
        ),
        SizedBox(height: compact ? 12 : 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: compact ? LoopType.title : LoopType.titleLg,
        ),
        if (message case final String line) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            line,
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
