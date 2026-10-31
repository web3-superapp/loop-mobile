import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_provenance_scope.dart';

/// S278 · decision 0236: provenance and explanations are no longer printed;
/// each sits behind a [LoopInfoTrigger] whose accessible name is the whole
/// statement. This finds the trigger whose statement contains [fragment] —
/// the same assertion the tests made on the printed line, without opening a
/// sheet for every one.
///
/// S325 · decision 0255: on a page with a title bar the statement is
/// reported to the bar's one (i) instead ([LoopProvenanceHosted]); the
/// finder matches that report too.
Finder findProvenanceContaining(String fragment) => find.byWidgetPredicate(
  (widget) =>
      (widget is LoopInfoTrigger && widget.semanticsLabel.contains(fragment)) ||
      (widget is LoopProvenanceHosted &&
          widget.entry.spoken.contains(fragment)),
  description: 'LoopInfoTrigger whose statement contains "$fragment"',
);

/// S325 · decision 0255: opens the page's one (i) in its title bar — the
/// sheet that now holds every source and explanation the page's blocks used
/// to open on their own.
Future<void> openPageInfo(WidgetTester tester) async {
  final action = find.byWidgetPredicate(
    (widget) => widget is LoopPageInfoAction,
    description: 'the page (i)',
  );
  await tester.tap(action.first);
  await tester.pumpAndSettle();
}

/// The page (i)'s sheet, whichever key the page gave it.
Finder get pageInfoSheet => find.byWidgetPredicate(
  (widget) =>
      widget is SingleChildScrollView &&
      widget.key is ValueKey<String> &&
      ((widget.key! as ValueKey<String>).value == 'loop-provenance-sheet' ||
          (widget.key! as ValueKey<String>).value.endsWith('-sheet')),
  description: 'the page (i) sheet',
);

/// The page (i) in the title bar.
Finder get pageInfoAction => find.byWidgetPredicate(
  (widget) => widget is LoopPageInfoAction,
  description: 'the page (i)',
);
