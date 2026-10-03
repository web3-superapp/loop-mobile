import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/widgets/loop_incremental_list.dart';

void main() {
  testWidgets('loads during drag and inertia but not programmatic scrolling', (
    tester,
  ) async {
    var reads = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoopIncrementalList(
            canLoadMore: true,
            loading: false,
            failed: false,
            onLoadMore: () => reads++,
            child: ListView(
              controller: controller,
              children: const [SizedBox(height: 2000)],
            ),
          ),
        ),
      ),
    );
    controller.jumpTo(controller.position.maxScrollExtent - 100);
    await tester.pump();
    expect(reads, 0);
    final context = tester.element(find.byType(ListView));
    final metrics = controller.position.copyWith();
    ScrollStartNotification(
      metrics: metrics,
      context: context,
      dragDetails: DragStartDetails(),
    ).dispatch(context);
    ScrollUpdateNotification(
      metrics: metrics,
      context: context,
      scrollDelta: 30,
      dragDetails: DragUpdateDetails(
        globalPosition: Offset.zero,
        delta: Offset(0, -30),
      ),
    ).dispatch(context);
    expect(reads, 1);
    // The user's fling continues after the finger lifts.
    ScrollUpdateNotification(
      metrics: metrics,
      context: context,
      scrollDelta: 50,
    ).dispatch(context);
    expect(reads, 2);
    ScrollEndNotification(metrics: metrics, context: context).dispatch(context);
    ScrollUpdateNotification(
      metrics: metrics,
      context: context,
      scrollDelta: 50,
    ).dispatch(context);
    expect(reads, 2);
  });

  for (final (loading, failed, canLoadMore) in [
    (true, false, true),
    (false, true, true),
    (false, false, false),
  ]) {
    testWidgets(
      'does not append when loading=$loading failed=$failed more=$canLoadMore',
      (tester) async {
        var reads = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: LoopIncrementalList(
              canLoadMore: canLoadMore,
              loading: loading,
              failed: failed,
              onLoadMore: () => reads++,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    ScrollUpdateNotification(
                      metrics: FixedScrollMetrics(
                        minScrollExtent: 0,
                        maxScrollExtent: 100,
                        pixels: 100,
                        viewportDimension: 600,
                        axisDirection: AxisDirection.down,
                        devicePixelRatio: 1,
                      ),
                      context: context,
                      scrollDelta: 30,
                      dragDetails: DragUpdateDetails(
                        globalPosition: Offset.zero,
                        delta: Offset(0, -30),
                      ),
                    ).dispatch(context);
                  },
                  child: const Text('scroll'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('scroll'));
        expect(reads, 0);
      },
    );
  }

  testWidgets(
    'load-more fallback has a direct actionable button without page controls',
    (tester) async {
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoopListLoadMoreFooter(onLoadMore: () => reads++),
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      expect(find.text('上一页'), findsNothing);
      expect(find.text('下一页'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('loop-list-load-more')));
      expect(reads, 1);
      semantics.dispose();
    },
  );
}
