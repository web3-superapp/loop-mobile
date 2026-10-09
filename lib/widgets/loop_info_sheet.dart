import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
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
                    Text(note.title!, style: LoopTypography.title(15)),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    note.body,
                    style: LoopTypography.body(13, color: LoopColors.text2),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
