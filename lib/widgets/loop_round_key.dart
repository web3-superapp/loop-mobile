import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// What a [LoopRoundKey] is for, which decides its disc.
enum LoopRoundKeyTone {
  /// The OKX action key: a solid Lime disc with an Ink glyph.
  primary,

  /// A key on the card ground with a Chalk glyph — the voice-room bar, where
  /// four Lime discs side by side would say nothing about which is on.
  quiet,

  /// The leaving key (结束 / 离开): the fall colour.
  fall,
}

/// The size of a round key's disc (decision 0127, OKX 4908).
const double loopRoundKeyDiameter = 56;

/// One OKX round action key (decision 0127): a 56 disc, a 24 glyph in it and
/// the word under it at 13. A key that cannot act keeps its place on the
/// quiet ground in the auxiliary grey; if it was given a reason, a tap says
/// it.
///
/// The wallet's four keys (decision 0122) are the same shape; this is the
/// shared one for the secondary pages — community, voice room, user profile.
class LoopRoundKey extends StatelessWidget {
  const LoopRoundKey({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.tone = LoopRoundKeyTone.primary,
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
  /// the Lime disc.
  final bool active;

  /// A small Lime count over the disc (pending hands).
  final String? badge;
  final String? semanticLabel;

  /// Answers a tap on a key that cannot act.
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final Color disc;
    final Color glyph;
    if (!enabled) {
      disc = LoopColors.card2;
      glyph = LoopColors.text3;
    } else {
      switch (tone) {
        case LoopRoundKeyTone.primary:
          disc = LoopColors.lime;
          glyph = LoopColors.ink;
        case LoopRoundKeyTone.quiet:
          disc = active ? LoopColors.lime : LoopColors.card2;
          glyph = active ? LoopColors.ink : LoopColors.chalk;
        case LoopRoundKeyTone.fall:
          disc = LoopColors.fall;
          glyph = LoopColors.chalk;
      }
    }
    final count = badge;
    return Semantics(
      button: true,
      enabled: enabled,
      label:
          semanticLabel ??
          (count == null ? label : '$label，$count') + (enabled ? '' : '，暂不可用'),
      // The gesture below is excluded with the subtree; the tap is offered
      // here so a screen reader can press the key (decision 0126).
      onTap: onPressed ?? onBlocked,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed ?? onBlocked,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80, minWidth: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: loopRoundKeyDiameter,
                    height: loopRoundKeyDiameter,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: disc,
                      shape: BoxShape.circle,
                    ),
                    child: LoopIcon(icon, size: 24, color: glyph),
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
                          color: LoopColors.lime,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: LoopColors.ink, width: 2),
                        ),
                        child: Text(
                          count,
                          style: LoopTypography.figure(
                            11,
                            color: LoopColors.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopTypography.title(
                  13,
                  color: enabled ? LoopColors.chalk : LoopColors.text3,
                ),
              ),
            ],
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
