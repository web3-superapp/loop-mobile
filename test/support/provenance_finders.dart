import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';

/// S278 · decision 0236: provenance and explanations are no longer printed;
/// each sits behind a [LoopInfoTrigger] whose accessible name is the whole
/// statement. This finds the trigger whose statement contains [fragment] —
/// the same assertion the tests made on the printed line, without opening a
/// sheet for every one.
Finder findProvenanceContaining(String fragment) => find.byWidgetPredicate(
  (widget) =>
      widget is LoopInfoTrigger && widget.semanticsLabel.contains(fragment),
  description: 'LoopInfoTrigger whose statement contains "$fragment"',
);
