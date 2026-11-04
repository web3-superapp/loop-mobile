import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// What a [LoopRoundKey] is for, which decides its face.
enum LoopRoundKeyTone {
  /// The one main action of a key row: a flat Yellow square with an Ink
  /// glyph. A page names it explicitly; it is no longer the default (S241c).
  primary,

  /// Every other key: the raised `#1C1B22` ground with a Chalk glyph and no
  /// edge (decision 0211). An [LoopRoundKey.active] key (an open microphone,
  /// a raised hand) is selected, so it wears the Purple state.
  quiet,

  /// The leaving key (结束 / 离开): the outlined card with the glyph in the
  /// fall colour.
  fall,
}

/// The side of a key's face (decision 0127, OKX 4908). The face is a 12
/// radius tile since decision 0211.
const double loopRoundKeyDiameter = 56;

/// One action key (decision 0127, reskinned by decision 0210 / S241c): a 56
/// square face, a 24 glyph in it and the word under it at 13. The face is
/// square and flat; a press turns its edge Purple. A key that cannot act
/// keeps its place on the outlined card in the auxiliary grey; if it was
/// given a reason, a tap says it.
///
/// The default is the outlined [LoopRoundKeyTone.quiet] key; a row names its
/// single main action [LoopRoundKeyTone.primary], so a row of keys never
/// reads as several Yellow calls to action at once.
class LoopRoundKey extends StatefulWidget {
  const LoopRoundKey({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.tone = LoopRoundKeyTone.quiet,
    this.active = false,
    this.badge,
    this.semanticLabel,
    this.onBlocked,
    this.bare = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;
  final LoopRoundKeyTone tone;

  /// A quiet key whose state is on (an open microphone, a raised hand) wears
  /// the Purple selected face.
  final bool active;

  /// A small Yellow count over the face (pending hands).
  final String? badge;
  final String? semanticLabel;

  /// Answers a tap on a key that cannot act.
  final VoidCallback? onBlocked;

  /// S353c · decision 0280 (docs/58 §5.11, the wallet frame's quick keys):
  /// no face — the 24 glyph over a 14 / 500 word, primary text colour, a
  /// closed key in the tertiary colour. [tone] only keeps the fall colour.
  final bool bare;

  @override
  State<LoopRoundKey> createState() => _LoopRoundKeyState();
}

class _LoopRoundKeyState extends State<LoopRoundKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    // Decision 0211: a filled 12 radius face with no edge; an active key is
    // the Purple selected ground, and a press deepens the face.
    final Color face;
    final Color? edge;
    final Color glyph;
    if (!enabled) {
      face = LoopColors.card;
      edge = null;
      glyph = LoopColors.text3;
    } else {
      switch (widget.tone) {
        case LoopRoundKeyTone.primary:
          face = LoopColors.yellow;
          edge = null;
          glyph = LoopColors.ink;
        case LoopRoundKeyTone.quiet:
          face = widget.active ? LoopColors.purpleSelected : LoopColors.card2;
          edge = null;
          glyph = widget.active ? LoopColors.onPurple : LoopColors.chalk;
        case LoopRoundKeyTone.fall:
          face = LoopColors.card2;
          edge = null;
          glyph = LoopColors.fall;
      }
    }
    final pressed = _pressed && enabled;
    final count = widget.badge;
    final onTap = widget.onPressed ?? widget.onBlocked;
    final bareInk = !enabled
        ? LoopColors.textTertiary
        : widget.tone == LoopRoundKeyTone.fall
        ? LoopColors.fall
        : LoopColors.textPrimary;
    return Semantics(
      button: true,
      enabled: enabled,
      label:
          widget.semanticLabel ??
          (count == null
                  ? widget.label
                  : '${widget.label}${LoopL10n.current.common_listSeparator}$count') +
              (enabled ? '' : context.l10n.widgets_roundKeyLabel),
      // The gesture below is excluded with the subtree; the tap is offered
      // here so a screen reader can press the key (decision 0126).
      onTap: onTap,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: LoopPressable(
          onTap: onTap,
          child: widget.bare
              ? Container(
                  constraints: const BoxConstraints(minHeight: 58),
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      LoopIcon(
                        widget.icon,
                        key: const ValueKey<String>('loop-round-key-glyph'),
                        size: 24,
                        color: bareInk,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.label,
                        // A long English word (Direct message) takes a second line
                        // rather than an ellipsis.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: LoopType.label.copyWith(color: bareInk),
                      ),
                    ],
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 80,
                    minWidth: 64,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Container(
                            key: const ValueKey<String>('loop-round-key-face'),
                            width: loopRoundKeyDiameter,
                            height: loopRoundKeyDiameter,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: pressed
                                  ? (face == LoopColors.yellow
                                        ? LoopColors.yellowPressed
                                        : LoopColors.line)
                                  : face,
                              borderRadius: LoopRadius.button,
                              border: edge == null
                                  ? null
                                  : Border.all(color: edge),
                            ),
                            child: LoopIcon(
                              widget.icon,
                              size: 24,
                              color: glyph,
                            ),
                          ),
                          if (count != null)
                            Positioned(
                              right: -4,
                              top: -2,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 20),
                                height: 20,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: LoopColors.yellow,
                                  borderRadius: LoopRadius.round,
                                  border: Border.all(
                                    color: LoopColors.ink,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  count,
                                  style: LoopTypography.withWeight(
                                    LoopType.figureXs,
                                    FontWeight.w600,
                                  ).copyWith(color: LoopColors.ink),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            LoopTypography.withWeight(
                              LoopType.titleSm,
                              FontWeight.w600,
                            ).copyWith(
                              color: enabled
                                  ? LoopColors.chalk
                                  : LoopColors.text3,
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

/// A row of [LoopRoundKey]s, each in an equal share of the width.
class LoopRoundKeyRow extends StatelessWidget {
  const LoopRoundKeyRow({
    required this.keys,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(8, 20, 8, 4),
    this.ruled = false,
  });

  final List<Widget> keys;
  final EdgeInsetsGeometry padding;

  /// S353c (docs/58 §5.11): a 1 × 28 `dividerSolid` rule between two keys,
  /// for a row of [LoopRoundKey.bare] keys.
  final bool ruled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < keys.length; index++) ...<Widget>[
          if (ruled && index > 0)
            Container(
              width: 1,
              height: 28,
              // Level with a bare key's glyph and one-line word.
              margin: const EdgeInsets.only(top: 15),
              color: LoopColors.dividerSolid,
            ),
          Expanded(child: keys[index]),
        ],
      ],
    ),
  );
}
