import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// What a [LoopRoundKey] is for, which decides its face.
enum LoopRoundKeyTone {
  /// The one main action of a key row: a flat Yellow square with an Ink
  /// glyph. A page names it explicitly; it is no longer the default (S241c).
  primary,

  /// Every other key: the `#111114` card behind a 1px `#4A4754` edge with a
  /// Chalk glyph (decision 0210). An [LoopRoundKey.active] key (an open
  /// microphone, a raised hand) is selected, so it wears the Purple state —
  /// Purple 9 % ground behind a Purple edge.
  quiet,

  /// The leaving key (结束 / 离开): the outlined card with the glyph in the
  /// fall colour.
  fall,
}

/// The side of a key's square face (decision 0127, OKX 4908). The name is
/// retained from the round key; the face is square since S241c.
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
    final Color face;
    final Color edge;
    final Color glyph;
    if (!enabled) {
      face = LoopColors.card;
      edge = LoopColors.line;
      glyph = LoopColors.text3;
    } else {
      switch (widget.tone) {
        case LoopRoundKeyTone.primary:
          face = LoopColors.yellow;
          edge = LoopColors.yellow;
          glyph = LoopColors.ink;
        case LoopRoundKeyTone.quiet:
          face = widget.active ? LoopColors.purpleSoft : LoopColors.card;
          edge = widget.active ? LoopColors.purple : LoopColors.line3;
          glyph = LoopColors.chalk;
        case LoopRoundKeyTone.fall:
          face = LoopColors.card;
          edge = LoopColors.line3;
          glyph = LoopColors.fall;
      }
    }
    final pressed = _pressed && enabled;
    final count = widget.badge;
    final onTap = widget.onPressed ?? widget.onBlocked;
    return Semantics(
      button: true,
      enabled: enabled,
      label:
          widget.semanticLabel ??
          (count == null ? widget.label : '${widget.label}，$count') +
              (enabled ? '' : '，暂不可用'),
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80, minWidth: 64),
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
                        color: face,
                        borderRadius: LoopRadius.button,
                        border: Border.all(
                          color: pressed ? LoopColors.purple : edge,
                        ),
                      ),
                      child: LoopIcon(widget.icon, size: 24, color: glyph),
                    ),
                    if (count != null)
                      Positioned(
                        right: -4,
                        top: -2,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: LoopColors.yellow,
                            borderRadius: LoopRadius.badge,
                            border: Border.all(color: LoopColors.ink, width: 2),
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
                        color: enabled ? LoopColors.chalk : LoopColors.text3,
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
  });

  final List<Widget> keys;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[for (final entry in keys) Expanded(child: entry)],
    ),
  );
}
