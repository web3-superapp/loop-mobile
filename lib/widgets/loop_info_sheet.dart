import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';

/// One paragraph of an (i) sheet: an optional short heading and its text.
@immutable
class LoopInfoNote {
  const LoopInfoNote({required this.body, this.title, this.key});

  final String? title;
  final String body;

  /// Pins the paragraph for tests; the sheet keys nothing on its own.
  final Key? key;
}

/// What an (i) opens (decision 0133, S121 §1 提示分级): explanations that
/// need no action from the reader are said once, here, instead of standing on
/// the page as cards.
///
/// The sheet is the shared [showLoopSheet] surface (root navigator, drag
/// handle, focus return); it carries no button — closing it is the drag,
/// the veil or the system back.
Future<void> showLoopInfoSheet(
  BuildContext context, {
  required String title,
  required List<LoopInfoNote> notes,
  String sheetKey = 'loop-info-sheet',
}) {
  return showLoopSheet<void>(
    context,
    barrierLabel: '关闭说明',
    builder: (sheetContext) => SingleChildScrollView(
      key: ValueKey<String>(sheetKey),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopSheetHeading(title),
          for (final note in notes)
            Padding(
              key: note.key,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (note.title != null) ...<Widget>[
                    Text(note.title!, style: LoopType.title),
                    const SizedBox(height: 4),
                  ],
                  Text(note.body, style: LoopType.bodySm),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// The 44 dp (i) that opens [showLoopInfoSheet] (S278 · decision 0236).
///
/// An explanation that used to stand on the page as a sentence under a row
/// or a card under a block is this button now: beside the row's state, or at
/// the end of the section title ([LoopInfoLabel]).
class LoopInfoButton extends StatelessWidget {
  const LoopInfoButton({
    required this.title,
    required this.notes,
    super.key,
    this.label,
    this.sheetKey = 'loop-info-sheet',
    this.color,
  });

  /// The sheet's heading.
  final String title;
  final List<LoopInfoNote> notes;

  /// The control's accessible name; 「关于[title]」 by default.
  final String? label;
  final String sheetKey;
  final Color? color;

  @override
  Widget build(BuildContext context) => LoopIconButton(
    icon: 'info',
    label: label ?? '关于$title',
    color: color ?? LoopColors.text3,
    onPressed: () => unawaited(
      showLoopInfoSheet(
        context,
        title: title,
        notes: notes,
        sheetKey: sheetKey,
      ),
    ),
  );
}

/// A section title with an (i) at its end (S278 · decision 0236) — the
/// [LoopLabel] a page already draws, and the explanation that used to stand
/// under the section behind [info] (usually a [LoopInfoButton]).
class LoopInfoLabel extends StatelessWidget {
  const LoopInfoLabel(
    this.text, {
    required this.info,
    super.key,
    this.followsLabel = false,
  });

  final String text;
  final Widget info;
  final bool followsLabel;

  @override
  Widget build(BuildContext context) {
    final flat = LoopFlat.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: flat
              ? LoopLabel(text, followsLabel: followsLabel)
              // A ledger label is a 10 px line; it stands this much higher
              // so the 44 dp box's centre sits on its centre (as
              // Launch2SectionLabel does).
              : Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: LoopLabel(text, followsLabel: followsLabel),
                ),
        ),
        Padding(
          padding: EdgeInsets.only(right: 4, bottom: flat ? 4 : 0),
          child: info,
        ),
      ],
    );
  }
}
