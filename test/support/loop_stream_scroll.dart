import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The vertical position a [LoopStreamPage] with a folio scrolls: the one that
/// carries the hero past the topbar and then hands the drag to the rows.
///
/// A test that wants to read the hero after a step that scrolled — tapping a
/// chip through `ensureVisible` is one — asks this to go back to the top
/// first, because a hero that is off screen is a hero the page has correctly
/// stopped building.
ScrollableState loopStreamScrollable(WidgetTester tester) => tester.state(
  find
      .descendant(
        of: find.byKey(const ValueKey<String>('loop-page-stream-scroll')),
        matching: find.byType(Scrollable),
      )
      .first,
);

/// Puts a stream page's hero back at the top of the reading order.
Future<void> loopStreamScrollToTop(WidgetTester tester) async {
  loopStreamScrollable(tester).position.jumpTo(0);
  await tester.pumpAndSettle();
}
