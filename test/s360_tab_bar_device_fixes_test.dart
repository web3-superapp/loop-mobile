// S360 · decision 0285: the tab bar as the Figma draws it on a device — the
// glyph 10 from the bar's top and the word at 39, the selected cell marked
// by a 38 radial halo only (no ground, no pill, no edge), and a 15 blur that
// has something to blur: a tab's list runs on under the bar.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/widgets/loop_dock_bar.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

const Size _screen = Size(390, 844);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _pumpShell(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _screen;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: LoopShell(location: '/square', child: child),
    ),
  );
  await tester.pumpAndSettle();
}

LoopStreamPage _page({required bool underBar}) => LoopStreamPage(
  archetype: LoopPageArchetype.listing,
  title: 'Square',
  tabPage: true,
  scrollsUnderTabBar: underBar,
  collection: Builder(
    builder: (context) => ListView(
      padding: EdgeInsets.only(bottom: loopTabScrollBottom(context)),
      children: <Widget>[
        for (var i = 0; i < 40; i += 1) SizedBox(height: 60, child: Text('$i')),
      ],
    ),
  ),
);

void main() {
  testWidgets('the glyph stands 10 from the bar top and the word at 39', (
    tester,
  ) async {
    await _pumpShell(tester, const SizedBox.expand());
    final bar = tester.getRect(_key('loop-tab-bar-float'));
    expect(bar.height, LoopTouch.tabBarHeight);
    final glyph = tester.getRect(_key('loop-tab-glyph-chat-off'));
    expect(glyph.top - bar.top, moreOrLessEquals(10));
    expect(glyph.height, 22);
    final word = tester.getRect(
      find.descendant(
        of: find.widgetWithText(LoopTabItem, 'Chat'),
        matching: find.text('Chat'),
      ),
    );
    expect(word.top - bar.top, moreOrLessEquals(39));
    expect(word.height, moreOrLessEquals(16));
    // MEME's 24 glyph also tops out at 10, its word at 39.
    final meme = tester.getRect(_key('loop-tab-glyph-meme-off'));
    expect(meme.top - bar.top, moreOrLessEquals(10));
    // The cell fills the bar: a 68-tall target, at least 44 wide.
    final cell = tester.getRect(find.widgetWithText(LoopTabItem, 'Chat'));
    expect(cell.height, moreOrLessEquals(LoopTouch.tabBarHeight));
    expect(cell.width, greaterThanOrEqualTo(LoopTouch.minimum));
  });

  testWidgets('the selected cell has no ground; its halo is a RadialGradient', (
    tester,
  ) async {
    await _pumpShell(tester, const SizedBox.expand());
    final bar = find.byType(LoopDockBar);
    // No pill, no chip, no outline anywhere inside the bar.
    final grounds = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: bar, matching: find.byType(DecoratedBox)),
        )
        .map((box) => box.decoration)
        .where(
          (d) =>
              d is ShapeDecoration ||
              (d is BoxDecoration && (d.color != null || d.border != null)),
        );
    expect(grounds, isEmpty);
    final halo = tester.widget<DecoratedBox>(_key('loop-tab-halo-square'));
    final decoration = halo.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    final gradient = decoration.gradient! as RadialGradient;
    expect(gradient.colors, const <Color>[
      Color(0x3DFFD21C),
      Color(0x00FFD21C),
    ]);
    final haloRect = tester.getRect(_key('loop-tab-halo-square'));
    expect(haloRect.size, const Size.square(38));
    final barRect = tester.getRect(_key('loop-tab-bar-float'));
    final cell = tester.getRect(find.widgetWithText(LoopTabItem, 'Square'));
    // The Figma's (16, 4) in a 70 cell: centred, 4 from the top, so its
    // centre is 2 under the glyph's.
    expect(haloRect.top - barRect.top, moreOrLessEquals(4));
    expect(haloRect.center.dx, moreOrLessEquals(cell.center.dx));
    final glyph = tester.getRect(_key('loop-tab-glyph-square-on'));
    expect(haloRect.center.dy - glyph.center.dy, moreOrLessEquals(2));
    expect(_key('loop-tab-halo-chat'), findsNothing);
  });

  testWidgets(
    'the blur sits under the cells at the Figma 15, inside the clip',
    (tester) async {
      await _pumpShell(tester, const SizedBox.expand());
      final blur = tester.widget<BackdropFilter>(_key('loop-tab-bar-blur'));
      expect(blur.filter, ImageFilter.blur(sigmaX: 15, sigmaY: 15));
      // The cells are the filter's child, painted over the frosted page.
      expect(
        find.descendant(
          of: find.byWidget(blur),
          matching: find.byType(LoopTabItem),
        ),
        findsNWidgets(5),
      );
      // The clip that bounds it is the bar's 12 corner.
      final clip = tester.widget<ClipRRect>(
        find
            .ancestor(of: find.byWidget(blur), matching: find.byType(ClipRRect))
            .first,
      );
      expect(clip.borderRadius, LoopRadius.tabBar);
      // Nothing opaque between the blur and the page: the ground is white 3 %.
      expect(loopTabBarGround.a, lessThan(0.05));
    },
  );

  testWidgets('a tab list runs on under the bar, so the blur has rows behind '
      'it, and its last row still clears the bar', (tester) async {
    await _pumpShell(tester, _page(underBar: true));
    final region = tester.getRect(find.byType(Scrollable));
    expect(region.bottom, _screen.height);
    final bar = tester.getRect(_key('loop-tab-bar-float'));
    final behind = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => RegExp(r'^\d+$').hasMatch(t.data ?? ''))
        .map((t) => tester.getRect(find.byWidget(t)))
        .where((r) => r.overlaps(bar));
    expect(behind, isNotEmpty);
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('39')).bottom, lessThanOrEqualTo(bar.top));
  });

  testWidgets('a page that does not opt in keeps its region above the bar', (
    tester,
  ) async {
    await _pumpShell(tester, _page(underBar: false));
    final region = tester.getRect(find.byType(Scrollable));
    expect(
      region.bottom,
      moreOrLessEquals(_screen.height - LoopLayout.tabPageBottomReserve),
    );
  });
}
