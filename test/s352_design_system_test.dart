// S352 · decision 0277: the shared pieces of the requester's Figma system
// (docs/58 §5) — the title doodle, the tab strip, the filter chips, the tab
// bar, the search field, the page buttons, the row divider, the empty state
// and the tags.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_filter_chips.dart';
import 'package:loop_mobile/widgets/loop_profile_sections.dart';
import 'package:loop_mobile/widgets/loop_search_entry.dart';
import 'package:loop_mobile/widgets/loop_tab_strip.dart';
import 'package:loop_mobile/widgets/loop_title_doodle.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _host(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: SafeArea(child: child)),
    ),
  );
  await tester.pump();
}

BoxDecoration _decoration(WidgetTester tester, Finder finder) =>
    tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;

void main() {
  group('1 · the title doodle', () {
    testWidgets('a page title stands over the 64 × 13 Purple doodle', (
      tester,
    ) async {
      await _host(tester, const LoopTopbar(title: '聊天', pageInfo: false));
      expect(_key('loop-title-doodle'), findsOneWidget);
      expect(tester.getSize(_key('loop-title-doodle')), const Size(64, 13));
      final title = tester.widget<Text>(find.text('聊天'));
      expect(title.style?.fontSize, 28);
      expect(title.style?.fontWeight, FontWeight.w700);
      final image = tester.widget<Image>(_key('loop-title-doodle'));
      expect(
        (image.image as AssetImage).assetName,
        LoopFigmaAssets.titleDoodle,
      );
    });

    testWidgets('a bar with a back control has no doodle', (tester) async {
      await _host(
        tester,
        LoopTopbar(title: '设置', onBack: () {}, pageInfo: false),
      );
      expect(_key('loop-title-doodle'), findsNothing);
    });
  });

  group('2 · the tab strip', () {
    testWidgets('equal cells, the chosen one white 16 / 600 over a 2 px '
        'Yellow line, the rest textSecondary 16 / 500, counts on white 5 %', (
      tester,
    ) async {
      var chosen = 0;
      await _host(
        tester,
        StatefulBuilder(
          builder: (context, setState) => LoopTabStrip(
            labels: const <String>['内盘', 'Upcoming', '已毕业'],
            counts: const <int?>[4, 0, 3],
            keys: const <Key>[
              ValueKey<String>('tab-a'),
              ValueKey<String>('tab-b'),
              ValueKey<String>('tab-c'),
            ],
            selectedIndex: chosen,
            onSelected: (index) => setState(() => chosen = index),
          ),
        ),
      );
      final a = tester.getRect(_key('tab-a'));
      final b = tester.getRect(_key('tab-b'));
      expect(a.width, closeTo(b.width, 0.01));
      expect(a.left, LoopSpacing.page);
      expect(b.left - a.right, LoopTabStrip.gap);
      expect(a.height, greaterThanOrEqualTo(LoopTabStrip.cellHeight));
      final on = tester.widget<Text>(find.text('内盘'));
      expect(on.style?.fontSize, 16);
      expect(on.style?.fontWeight, FontWeight.w600);
      expect(on.style?.color, LoopColors.textOnSelected);
      final off = tester.widget<Text>(find.text('Upcoming'));
      expect(off.style?.fontWeight, FontWeight.w500);
      expect(off.style?.color, LoopColors.textSecondary);
      // The line under the chosen cell spans it, 2 high.
      final line = find.descendant(
        of: _key('tab-a'),
        matching: _key('loop-tab-strip-line-true'),
      );
      expect(tester.getSize(line).width, closeTo(a.width, 0.01));
      expect(tester.getSize(line).height, LoopTabStrip.underline);
      // Counts: Purple on the chosen cell, white 60 % elsewhere.
      expect(
        tester.widget<Text>(find.text('4')).style?.color,
        LoopColors.purple,
      );
      expect(
        tester.widget<Text>(find.text('3')).style?.color,
        LoopColors.white60,
      );
      expect(tester.widget<Text>(find.text('3')).style?.fontSize, 11);
      // The strip's full-bleed rule.
      final rule = _decoration(tester, _key('loop-tab-strip'));
      expect((rule.border! as Border).bottom.color, LoopColors.tabRule);
      await tester.tap(_key('tab-c'));
      await tester.pumpAndSettle();
      expect(chosen, 2);
    });

    testWidgets('the person page bar is the tab strip', (tester) async {
      var chosen = LoopProfileSection.holdings;
      await _host(
        tester,
        StatefulBuilder(
          builder: (context, setState) => LoopProfileSectionsBar(
            selected: chosen,
            onSelected: (section) => setState(() => chosen = section),
          ),
        ),
      );
      expect(find.byType(LoopTabStrip), findsOneWidget);
      await tester.tap(_key('loop-profile-section-communities'));
      await tester.pumpAndSettle();
      expect(chosen, LoopProfileSection.communities);
    });
  });

  group('3 · the filter chips', () {
    testWidgets('54 × 32 at an 8 corner, white 10 % / 4 %, 8 apart, a 44 '
        'target', (tester) async {
      var chosen = 0;
      await _host(
        tester,
        StatefulBuilder(
          builder: (context, setState) => LoopFilterChips(
            labels: const <String>['代币', 'NFT'],
            keys: const <Key>[
              ValueKey<String>('chip-a'),
              ValueKey<String>('chip-b'),
            ],
            selectedIndex: chosen,
            onSelected: (index) => setState(() => chosen = index),
          ),
        ),
      );
      final faceA = find.descendant(
        of: _key('chip-a'),
        matching: _key('loop-filter-chip-face'),
      );
      final faceB = find.descendant(
        of: _key('chip-b'),
        matching: _key('loop-filter-chip-face'),
      );
      expect(tester.getSize(faceA).height, LoopTouch.chipHeight);
      expect(
        tester.getSize(faceA).width,
        greaterThanOrEqualTo(LoopTouch.chipMinWidth),
      );
      expect(tester.getSize(_key('chip-a')).height, LoopTouch.minimum);
      expect(
        tester.getRect(faceB).left - tester.getRect(faceA).right,
        LoopSpacing.chipSpacing,
      );
      expect(_decoration(tester, faceA).color, LoopColors.chipActive);
      expect(_decoration(tester, faceA).borderRadius, LoopRadius.chip);
      expect(_decoration(tester, faceB).color, LoopColors.chipIdle);
      expect(tester.widget<Text>(find.text('代币')).style?.fontSize, 13);
      expect(
        tester.widget<Text>(find.text('代币')).style?.fontWeight,
        FontWeight.w600,
      );
      expect(
        tester.widget<Text>(find.text('NFT')).style?.fontWeight,
        FontWeight.w500,
      );
      await tester.tap(_key('chip-b'));
      await tester.pumpAndSettle();
      expect(chosen, 1);
    });

    testWidgets('a LoopSeg chooses the same way: white, no Purple, no splat', (
      tester,
    ) async {
      await _host(
        tester,
        LoopSegBar(
          labels: const <String>['全部', '代币'],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      );
      expect(_key('loop-seg-splat'), findsNothing);
      expect(LoopSegBar.capsuleHeight, LoopTouch.chipHeight);
      expect(
        tester.widget<Text>(find.text('全部')).style?.color,
        LoopColors.textOnSelected,
      );
    });
  });

  group('4 · the tab bar', () {
    testWidgets('353 × 68 on the 20 margin, 24 off the foot, a 12 corner, '
        'white 3 % with a #34353b edge, the shadow and a 15 blur; the '
        "Figma's glyphs and the halo under the chosen one", (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: LoopShell(location: '/meme', child: const SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.getRect(_key('loop-tab-bar-float'));
      expect(bar.width, 353);
      expect(bar.height, LoopTouch.tabBarHeight);
      expect(bar.left, 20);
      expect(852 - bar.bottom, 24);
      final float = tester.widget<DecoratedBox>(_key('loop-tab-bar-float'));
      final lift = float.decoration as BoxDecoration;
      expect(lift.boxShadow, LoopDepth.tabBar);
      expect(lift.borderRadius, LoopRadius.tabBar);
      expect(LoopRadius.tabBarValue, 12);
      expect(loopTabBarGround, LoopColors.white3);
      expect(loopTabBarEdge, LoopColors.navEdge);
      expect(loopTabBarBlur, 15);
      // The chosen MEME glyph is the Figma's Yellow one on the halo.
      expect(_key('loop-tab-halo-meme'), findsOneWidget);
      expect(_key('loop-tab-halo-chat'), findsNothing);
      expect(_key('loop-tab-glyph-meme-on'), findsOneWidget);
      expect(_key('loop-tab-glyph-chat-off'), findsOneWidget);
      expect(find.byType(SvgPicture), findsWidgets);
      // The words: 12 / 500, MEME 11 / 600; Yellow chosen.
      final meme = tester.widget<Text>(
        find.descendant(of: _key('loop-tab-meme'), matching: find.text('MEME')),
      );
      expect(meme.style?.fontSize, 11);
      expect(meme.style?.fontWeight, FontWeight.w600);
      expect(meme.style?.color, LoopColors.yellow);
      final chat = tester.widget<Text>(
        find.descendant(of: _key('loop-tab-chat'), matching: find.text('Chat')),
      );
      expect(chat.style?.fontSize, 12);
      expect(chat.style?.fontWeight, FontWeight.w500);
      expect(chat.style?.color, LoopColors.textSecondary);
      // The 0261 pill still travels under the chosen cell.
      expect(_key('loop-tab-indicator'), findsOneWidget);
    });
  });

  group('5 · the search field', () {
    for (final tone in LoopSearchTone.values) {
      testWidgets('44 high, a 12 corner, a #1d1f24 edge (${tone.name})', (
        tester,
      ) async {
        var taps = 0;
        await _host(
          tester,
          Padding(
            padding: const EdgeInsets.all(20),
            child: LoopSearchEntry(
              placeholder: '搜索',
              tone: tone,
              inkKey: const ValueKey<String>('search'),
              onTap: () => taps += 1,
            ),
          ),
        );
        expect(tester.getSize(_key('search')).height, LoopTouch.searchField);
        final material = tester.widget<Material>(
          find
              .ancestor(of: _key('search'), matching: find.byType(Material))
              .first,
        );
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, LoopRadius.control);
        expect(shape.side.color, LoopColors.cardEdge);
        final hint = tester.widget<Text>(find.text('搜索'));
        expect(hint.style?.fontSize, tone == LoopSearchTone.chat ? 15 : 14);
        expect(
          hint.style?.color,
          tone == LoopSearchTone.chat
              ? LoopColors.textTertiary
              : LoopColors.textSecondary,
        );
        await tester.tap(_key('search'));
        expect(taps, 1);
      });
    }
  });

  group('6 · the page buttons', () {
    testWidgets('regular 48 at 8, compact 30 at 6, medium 36 at 8, join '
        '54 × 28 at 6 on white 8 % with a Yellow word', (tester) async {
      await _host(
        tester,
        Column(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('b-regular'),
              label: '确认',
              primary: true,
              block: true,
              onPressed: () {},
            ),
            LoopButton(
              key: const ValueKey<String>('b-compact'),
              label: '发射',
              primary: true,
              size: LoopButtonSize.compact,
              onPressed: () {},
            ),
            LoopButton(
              key: const ValueKey<String>('b-medium'),
              label: '生成海报',
              size: LoopButtonSize.medium,
              onPressed: () {},
            ),
            LoopButton(
              key: const ValueKey<String>('b-join'),
              label: '加入',
              size: LoopButtonSize.join,
              onPressed: () {},
            ),
          ],
        ),
      );
      Container face(String key) => tester.widget<Container>(
        find
            .descendant(
              of: _key(key),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    widget.clipBehavior == Clip.antiAlias,
              ),
            )
            .first,
      );
      Size size(String key) => tester.getSize(
        find
            .descendant(
              of: _key(key),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    widget.clipBehavior == Clip.antiAlias,
              ),
            )
            .first,
      );
      BoxDecoration paint(String key) => face(key).decoration! as BoxDecoration;
      expect(size('b-regular').height, LoopTouch.primaryButton);
      expect(paint('b-regular').borderRadius, LoopRadius.button);
      expect(LoopRadius.buttonValue, 8);
      expect(size('b-compact').height, LoopTouch.buttonCompact);
      expect(paint('b-compact').borderRadius, LoopRadius.compactButton);
      expect(size('b-medium').height, LoopTouch.buttonMedium);
      expect(paint('b-medium').borderRadius, LoopRadius.button);
      expect(paint('b-medium').color, LoopColors.buttonGhost);
      expect(
        tester.widget<Text>(find.text('生成海报')).style?.color,
        LoopColors.yellow,
      );
      expect(size('b-join'), const Size(54, 28));
      expect(paint('b-join').color, LoopColors.buttonGhost);
      final join = tester.widget<Text>(find.text('加入'));
      expect(join.style?.fontSize, 12);
      expect(join.style?.fontWeight, FontWeight.w600);
      expect(join.style?.color, LoopColors.yellow);
      final word = tester.widget<Text>(find.text('确认'));
      expect(word.style?.fontSize, 16);
      expect(word.style?.fontWeight, FontWeight.w600);
      // Every small face still answers a 44 finger.
      for (final key in <String>['b-compact', 'b-medium', 'b-join']) {
        expect(
          tester.getSize(_key(key)).height,
          greaterThanOrEqualTo(LoopTouch.minimum),
          reason: key,
        );
      }
    });
  });

  group('7 · the row divider', () {
    testWidgets('off by default; on, 1 px white 5 % across the content', (
      tester,
    ) async {
      await _host(
        tester,
        const Column(
          children: <Widget>[
            LoopRecordRow(title: '无线'),
            LoopRecordRow(title: '有线', divider: true),
          ],
        ),
      );
      expect(find.byKey(LoopRecordRow.dividerKey), findsOneWidget);
      final line = tester.getRect(find.byKey(LoopRecordRow.dividerKey));
      expect(line.height, 1);
      expect(line.left, LoopSpacing.page);
      expect(line.right, 390 - LoopSpacing.page);
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byKey(LoopRecordRow.dividerKey),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        LoopColors.divider,
      );
    });
  });

  group('8 · the empty state', () {
    testWidgets('the colour crown and a 17 / 700 title; no sentence (0248)', (
      tester,
    ) async {
      await _host(
        tester,
        const LoopEmptyState(title: '暂无资产', message: '有余额的资产会出现在这里。'),
      );
      expect(_key('loop-empty-art'), findsOneWidget);
      final crown = tester.widget<Image>(
        find.descendant(
          of: _key('loop-empty-art'),
          matching: find.byType(Image),
        ),
      );
      expect((crown.image as AssetImage).assetName, LoopFigmaAssets.crownEmpty);
      expect(tester.getSize(_key('loop-empty-art')).width, 106);
      final title = tester.widget<Text>(_key('loop-empty-title'));
      expect(title.style?.fontSize, 17);
      expect(title.style?.fontWeight, FontWeight.w700);
      expect(_key('loop-empty-message'), findsNothing);
      expect(find.text('有余额的资产会出现在这里。'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('暂无资产')), findsOneWidget);
    });
  });

  group('9 · the tags', () {
    testWidgets('post 22 at 5, stage 19 at 4 Yellow 11 / 400, buy 17 at 4 '
        'rise 10 / 600; a badge at 5', (tester) async {
      await _host(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LoopStatusTag('置顶', key: ValueKey<String>('t-post')),
            LoopStatusTag(
              '毕业',
              key: ValueKey<String>('t-green'),
              tone: LoopTagTone.green,
            ),
            LoopStatusTag(
              'Public pool',
              key: ValueKey<String>('t-stage'),
              shape: LoopTagShape.stage,
            ),
            LoopStatusTag(
              '买入',
              key: ValueKey<String>('t-buy'),
              tone: LoopTagTone.rise,
              shape: LoopTagShape.buy,
            ),
            LoopBadge('挖矿', key: ValueKey<String>('t-badge')),
          ],
        ),
      );
      BoxDecoration ground(String key) =>
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: _key(key),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(tester.getSize(_key('t-post')).height, 22);
      expect(ground('t-post').borderRadius, LoopRadius.tag);
      expect(ground('t-post').color, LoopColors.yellowSoft);
      expect(ground('t-green').color, LoopColors.tagGreenBg);
      expect(
        tester.widget<Text>(find.text('毕业')).style?.color,
        LoopColors.tagGreen,
      );
      expect(tester.getSize(_key('t-stage')).height, 19);
      expect(ground('t-stage').borderRadius, LoopRadius.stage);
      final stage = tester.widget<Text>(find.text('Public pool'));
      expect(stage.style?.fontSize, 11);
      expect(stage.style?.fontWeight, FontWeight.w400);
      expect(stage.style?.color, LoopColors.yellow);
      expect(tester.getSize(_key('t-buy')).height, 17);
      final buy = tester.widget<Text>(find.text('买入'));
      expect(buy.style?.fontSize, 10);
      expect(buy.style?.color, LoopColors.rise);
      expect(ground('t-buy').color, LoopColors.riseSoft);
      expect(ground('t-badge').borderRadius, LoopRadius.tag);
      expect(tester.widget<Text>(find.text('挖矿')).style?.fontSize, 12);
    });
  });
}
