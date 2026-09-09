import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_scroll_behavior.dart';

void main() {
  testWidgets('LoopScrollBehavior draws no overscroll indicator', (
    tester,
  ) async {
    const behavior = LoopScrollBehavior();
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: behavior,
        home: ListView(children: const [SizedBox(height: 2000)]),
      ),
    );
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    final context = tester.element(find.byType(ListView));
    const child = SizedBox(key: Key('child'));
    final built = behavior.buildOverscrollIndicator(
      context,
      child,
      ScrollableDetails(
        direction: AxisDirection.down,
        controller: ScrollController(),
      ),
    );
    expect(identical(built, child), isTrue);
  });
}
