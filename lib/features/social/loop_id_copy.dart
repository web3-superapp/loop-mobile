import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// A printed LOOP ID with its copy glyph right behind it (decision 0104,
/// S97b layout).
///
/// The glyph is the ID's own control rather than a button under it: 16 dp in
/// the ID's colour, a 44×44 target (audit 2026-10-09 m3; it was 32), spoken as 「复制 LOOP ID」. A long press on
/// the ID itself copies too. Both put only the ID on the clipboard and say
/// 「已复制 LOOP ID」.
class LoopIdCopyLine extends StatelessWidget {
  const LoopIdCopyLine({
    required this.loopId,
    required this.style,
    required this.textKey,
    required this.copyKey,
    super.key,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  final String loopId;
  final TextStyle style;
  final Key textKey;
  final Key copyKey;
  final MainAxisAlignment mainAxisAlignment;

  /// The glyph's edge and its target, in logical pixels.
  static const double glyphSize = 16;
  static const double targetSize = 44;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      children: <Widget>[
        Flexible(
          child: LoopPressable(
            scale: false,
            // The copy glyph beside it is the accessible way to copy; the
            // long press on the printed ID is the shortcut for the finger.
            excludeFromSemantics: true,
            onLongPress: () => unawaited(copyLoopId(context, loopId)),
            child: Text(loopId, key: textKey, style: style),
          ),
        ),
        Semantics(
          key: copyKey,
          button: true,
          label: '复制 LOOP ID',
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => unawaited(copyLoopId(context, loopId)),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: targetSize,
                height: targetSize,
                child: Center(
                  child: LoopIcon('copy', size: glyphSize, color: style.color),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Puts [loopId] alone on the clipboard and says so.
Future<void> copyLoopId(BuildContext context, String loopId) async {
  await LoopCopy.text(context, loopId, message: '已复制 LOOP ID');
}
