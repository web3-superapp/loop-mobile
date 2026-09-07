import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: padding),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('focus page keeps the primary action reachable and inset', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      LoopFocusPage(
        archetype: LoopPageArchetype.action,
        title: '发送',
        onBack: () {},
        folio: const LoopFolioPrimary(
          heading: '确认收款方',
          archetype: LoopFolioArchetype.action,
        ),
        body: List<Widget>.generate(
          20,
          (index) => LoopSurfaceCard(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text('row $index'),
          ),
        ),
        primaryAction: LoopButton(
          label: '继续',
          primary: true,
          block: true,
          onPressed: () {},
        ),
        disclosure: const LoopDisclosure(summary: '更多说明', child: Text('说明')),
      ),
      padding: const EdgeInsets.only(bottom: 34),
    );
    expect(
      find.byKey(const ValueKey<String>('loop-page-focus')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('loop-page:action:focus'),
      findsOneWidget,
    );
    expect(LoopFocusPage.layoutMode, LoopLayoutMode.focus);
    final button = find.byKey(const ValueKey<String>('loop-button-primary'));
    expect(button, findsOneWidget);
    // Pinned: visible without scrolling, with max(24, safe) below it.
    expect(844 - tester.getRect(button).bottom, 34);
    // Body rows scroll under the pinned action; the last row starts below it.
    expect(tester.getRect(find.text('row 19')).top, greaterThan(844));
    semantics.dispose();
  });

  testWidgets(
    'dashboard page pins the topbar and puts the primary region first',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        LoopDashboardPage(
          archetype: LoopPageArchetype.listing,
          title: '钱包总览',
          primary: const LoopFolioPrimary(
            heading: '总资产',
            variant: LoopFolioVariant.lime,
          ),
          sections: List<Widget>.generate(
            30,
            (index) => LoopSurfaceCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text('section $index'),
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsIdentifier('loop-page:index:dashboard'),
        findsOneWidget,
      );
      final primaryTop = tester
          .getRect(find.byKey(const ValueKey<String>('loop-page-primary')))
          .top;
      final topbarBottom = tester.getRect(find.byType(LoopTopbar)).bottom;
      expect(primaryTop, greaterThanOrEqualTo(topbarBottom));
      expect(primaryTop, lessThan(tester.getRect(find.text('section 0')).top));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(find.text('钱包总览'), findsOneWidget);
      expect(tester.getRect(find.byType(LoopTopbar)).top, 0);
      semantics.dispose();
    },
  );

  testWidgets(
    'stream page scrolls the collection independently under fixed chrome',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var sent = '';
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        LoopStreamPage(
          archetype: LoopPageArchetype.record,
          title: '普通群聊',
          onBack: () {},
          filters: LoopSegBar(
            labels: const <String>['全部', '@我'],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
          collection: ListView.builder(
            controller: controller,
            itemCount: 60,
            itemBuilder: (context, index) =>
                SizedBox(height: 48, child: Text('msg $index')),
          ),
          composer: LoopComposer(onSend: (value) => sent = value),
        ),
        padding: const EdgeInsets.only(bottom: 34),
      );
      expect(
        find.bySemanticsIdentifier('loop-page:record:stream'),
        findsOneWidget,
      );
      final composer = find.byType(LoopComposer);
      expect(tester.getRect(composer).bottom, 844);
      final topbarBefore = tester.getRect(find.byType(LoopTopbar));
      controller.jumpTo(1000);
      await tester.pump();
      expect(tester.getRect(find.byType(LoopTopbar)), topbarBefore);
      expect(tester.getRect(composer).bottom, 844);
      expect(find.text('msg 0'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey<String>('loop-composer-input')),
        'hi',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-composer-send')),
      );
      expect(sent, 'hi');
      // The composer respects the safe area so the send button clears the edge.
      expect(
        844 -
            tester
                .getRect(
                  find.byKey(const ValueKey<String>('loop-composer-send')),
                )
                .bottom,
        greaterThanOrEqualTo(34),
      );
      semantics.dispose();
    },
  );
}
