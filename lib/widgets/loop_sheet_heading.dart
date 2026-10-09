import 'package:flutter/material.dart';

/// The title line of a sheet's content (decision 0131).
///
/// `showLoopSheet` already wraps its builder in the one [LoopSheet] surface.
/// A content widget that returned a second `LoopSheet` to get a title drew a
/// sheet inside a sheet: two paddings, two scroll views and — because both
/// gave up the keyboard's height at their foot — twice the keyboard's height
/// of empty space, which is what pushed MEME's 「确认买入」 half under the
/// keypad (audit 2026-10-09 M16). Content draws this heading instead, at the
/// same place and in the same style `LoopSheet.title` used.
class LoopSheetHeading extends StatelessWidget {
  const LoopSheetHeading(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
