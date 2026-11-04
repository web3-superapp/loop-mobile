import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// The requester's Figma assets (decision 0277), copied from the design
/// file into `assets/figma/`.
abstract final class LoopFigmaAssets {
  static const String _root = 'assets/figma';

  /// The Purple doodle under a page title, cropped to the Figma's visible
  /// 64 × 13 band (docs/58 §5.1).
  static const String titleDoodle = '$_root/underline-doodle.png';

  /// The colour crown of an empty state (docs/58 §5.19).
  static const String crownEmpty = '$_root/crown-empty.png';

  /// The crown beside the power card's place (docs/58 §5.14).
  static const String crownPowerCard = '$_root/crown-powercard.png';

  /// The tab bar's chosen-item halo, a 38 Yellow radial (docs/58 §5.18).
  static const String navHalo = '$_root/nav-active-halo.svg';

  /// The tab bar's glyph for [slug], idle or chosen (docs/58 §8).
  static String nav(String slug, {required bool active}) =>
      '$_root/nav-$slug${active ? '-active' : ''}.svg';
}

/// The Purple doodle under a page title (docs/58 §5.1): the Figma's bitmap
/// in a 64 × 13 box at a 2 corner. It replaces 0212's 3 × 24 Yellow dash.
class LoopTitleDoodle extends StatelessWidget {
  const LoopTitleDoodle({super.key, this.width = width64});

  /// The Figma's box; MEME's is 78.
  static const double width64 = 64;
  static const double height = 13;

  final double width;

  /// [title] with the doodle 1 under its last line, on its left edge.
  ///
  /// The doodle is painted in the room under the title, not laid out: a bar
  /// keeps the height its title asks for (at any text scale) and the doodle
  /// sits in the bar's own space beneath the words.
  static Widget under(Widget title, {double width = width64}) => Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      title,
      Positioned(
        left: 0,
        bottom: -(height + 1),
        child: LoopTitleDoodle(width: width),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(2)),
      child: Image.asset(
        LoopFigmaAssets.titleDoodle,
        key: const ValueKey<String>('loop-title-doodle'),
        width: width,
        height: height,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) =>
            SizedBox(width: width, height: height),
      ),
    ),
  );
}

/// A page title over its doodle: [LoopType.title1] and, 1 under the line,
/// [LoopTitleDoodle] on the title's left edge (painted in the room under
/// the title, see [LoopTitleDoodle.under]).
class LoopDoodleTitle extends StatelessWidget {
  const LoopDoodleTitle(
    this.title, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.doodle = true,
  });

  final String title;
  final TextStyle? style;
  final int maxLines;

  /// Whether the doodle is drawn (an unchosen segment keeps the room).
  final bool doodle;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style ?? LoopType.title1,
    );
    return doodle ? LoopTitleDoodle.under(text) : text;
  }
}
