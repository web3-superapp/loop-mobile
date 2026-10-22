// S241c (decision 0210): the shared-widget follow-ups the page groups could
// not make themselves — square outlined action keys, the quiet selected state
// on every chooser, one card ground for a composite, no corner ring by
// default, a dark `.chalk-card`, the page gutter on inline lines, a monogram
// palette without Yellow and an Arimo section title.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_round_key.dart';

import 'support/provenance_finders.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

BoxDecoration _faceOf(WidgetTester tester, Key key) {
  final face = tester.widget<Container>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byKey(const ValueKey<String>('loop-round-key-face')),
    ),
  );
  return face.decoration! as BoxDecoration;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('1 · action keys are 12 radius filled tiles (0211)', () {
    testWidgets('default is the outlined key; primary is Yellow; '
        'a press turns the edge Purple', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        LoopRoundKeyRow(
          keys: <Widget>[
            LoopRoundKey(
              key: const ValueKey<String>('k-main'),
              icon: 'chat',
              label: '进群聊',
              tone: LoopRoundKeyTone.primary,
              onPressed: () => taps += 1,
            ),
            LoopRoundKey(
              key: const ValueKey<String>('k-share'),
              icon: 'share',
              label: '分享',
              onPressed: () => taps += 1,
            ),
            const LoopRoundKey(
              key: ValueKey<String>('k-off'),
              icon: 'voice-off',
              label: '语音房',
              onPressed: null,
            ),
            LoopRoundKey(
              key: const ValueKey<String>('k-on'),
              icon: 'mic',
              label: '麦克风',
              tone: LoopRoundKeyTone.quiet,
              active: true,
              onPressed: () {},
            ),
          ],
        ),
      );

      final main = _faceOf(tester, const ValueKey<String>('k-main'));
      expect(main.shape, BoxShape.rectangle);
      expect(main.borderRadius, LoopRadius.button);
      expect(main.color, LoopColors.yellow);

      final share = _faceOf(tester, const ValueKey<String>('k-share'));
      expect(share.shape, BoxShape.rectangle);
      expect(share.color, LoopColors.card2);
      expect(share.border, isNull);
      expect(
        tester.getSize(
          find.descendant(
            of: find.byKey(const ValueKey<String>('k-share')),
            matching: find.byKey(const ValueKey<String>('loop-round-key-face')),
          ),
        ),
        const Size(loopRoundKeyDiameter, loopRoundKeyDiameter),
      );

      final off = _faceOf(tester, const ValueKey<String>('k-off'));
      expect(off.color, isNot(LoopColors.yellow));

      final on = _faceOf(tester, const ValueKey<String>('k-on'));
      // Decision 0212: solid Purple, no edge, a white glyph.
      expect(on.color, LoopColors.purpleSelected);
      expect(on.border, isNull);

      // A press deepens the face; it never moves.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey<String>('k-share'))),
      );
      await tester.pump();
      expect(
        _faceOf(tester, const ValueKey<String>('k-share')).color,
        LoopColors.line,
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);
      expect(
        _faceOf(tester, const ValueKey<String>('k-share')).color,
        LoopColors.card2,
      );
    });
  });

  group('2 · a chosen chip or button is never a solid Yellow block', () {
    testWidgets('framed and quiet LoopSeg choose alike', (tester) async {
      await _pump(
        tester,
        Wrap(
          children: <Widget>[
            LoopSeg(
              key: const ValueKey<String>('framed-on'),
              label: 'A',
              selected: true,
              onSelected: () {},
            ),
            LoopSeg(
              key: const ValueKey<String>('framed-off'),
              label: 'B',
              selected: false,
              onSelected: () {},
            ),
            LoopSeg(
              key: const ValueKey<String>('quiet-on'),
              label: 'C',
              quiet: true,
              selected: true,
              onSelected: () {},
            ),
          ],
        ),
      );
      Material materialOf(String key) => tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(ValueKey<String>(key)),
              matching: find.byType(Material),
            )
            .first,
      );
      // Decision 0211: a Purple 18 % block — 12 radius framed, a capsule
      // quiet — with no underline and no edge.
      for (final key in <String>['framed-on', 'quiet-on']) {
        final material = materialOf(key);
        expect(material.color, LoopColors.purpleSelected, reason: key);
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.side, BorderSide.none, reason: key);
      }
      // Decision 0212: every chip is a capsule.
      expect(
        (materialOf('framed-on').shape! as RoundedRectangleBorder).borderRadius,
        LoopRadius.pill,
      );
      expect(
        (materialOf('quiet-on').shape! as RoundedRectangleBorder).borderRadius,
        LoopRadius.pill,
      );
      expect(materialOf('framed-off').color, LoopColors.card2);
      expect(
        tester.widget<Text>(find.text('A')).style?.color,
        LoopColors.onPurple,
      );
      expect(
        tester.widget<Text>(find.text('C')).style?.color,
        LoopColors.onPurple,
      );
      expect(
        tester.widget<Text>(find.text('B')).style?.color,
        LoopColors.text2,
      );
    });

    testWidgets('LoopButton(selected:) paints the quiet chosen state', (
      tester,
    ) async {
      await _pump(
        tester,
        Row(
          children: <Widget>[
            Expanded(
              child: LoopButton(
                key: const ValueKey<String>('b-on'),
                label: '一',
                primary: true,
                selected: true,
                onPressed: () {},
              ),
            ),
            Expanded(
              child: LoopButton(
                key: const ValueKey<String>('b-off'),
                label: '二',
                selected: false,
                onPressed: () {},
              ),
            ),
          ],
        ),
      );
      Container faceOf(String key) => tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(ValueKey<String>(key)),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).borderRadius ==
                        LoopRadius.button,
              ),
            )
            .first,
      );
      final on = faceOf('b-on');
      expect(
        (on.decoration! as BoxDecoration).color,
        LoopColors.purpleSelected,
      );
      expect(on.foregroundDecoration, isNull);
      expect(
        tester.widget<Text>(find.text('一')).style?.color,
        LoopColors.onPurple,
      );
      final off = faceOf('b-off');
      expect((off.decoration! as BoxDecoration).color, LoopColors.card2);
      expect(
        tester.getSemantics(find.byKey(const ValueKey<String>('b-on'))),
        matchesSemantics(
          label: '一',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
    });
  });

  testWidgets('3 · a composite strip is the card above it', (tester) async {
    await _pump(
      tester,
      const LoopLedgerComposite(
        ground: LoopCompositeGround.chalk,
        primary: LoopFolioPrimary(
          heading: '记录',
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        detail: <Widget>[Text('明细'), LoopHairline()],
      ),
    );
    final strip = tester.widget<Container>(
      find.byKey(const ValueKey<String>('loop-ledger-composite-detail')),
    );
    final decoration = strip.decoration! as BoxDecoration;
    expect(decoration.color, LoopColors.card);
    // Decision 0211: only the seam above the strip is drawn.
    final border = decoration.border! as Border;
    expect(border.top.color, LoopColors.line);
    expect(border.left, BorderSide.none);
    expect(border.bottom, BorderSide.none);
    expect(
      DefaultTextStyle.of(tester.element(find.text('明细'))).style.color,
      LoopColors.chalk,
    );
    final rule = tester.widget<Container>(
      find.descendant(
        of: find.byType(LoopHairline),
        matching: find.byType(Container),
      ),
    );
    expect(rule.color, LoopColors.line);
    // The welded folio keeps only its top corners round and has no edge.
    final folio = tester.widget<Container>(
      find.byKey(const ValueKey<String>('loop-folio-primary')),
    );
    final folioDecoration = folio.decoration! as BoxDecoration;
    expect(folioDecoration.border, isNull);
    expect(
      folioDecoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(LoopRadius.cardValue)),
    );
  });

  testWidgets('4 · a folio draws no corner ring unless asked', (tester) async {
    bool hasRing() => find
        .byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        )
        .evaluate()
        .isNotEmpty;
    await _pump(tester, const LoopFolioPrimary(heading: '默认'));
    expect(hasRing(), isFalse);
    await _pump(tester, const LoopFolioPrimary(heading: '要环', ring: true));
    expect(hasRing(), isTrue);
  });

  testWidgets('5 · .chalk-card is the dark card with a Chalk heading; '
      'light keeps the plate', (tester) async {
    await _pump(
      tester,
      const Column(
        children: <Widget>[
          LoopChalkCard(child: Text('深')),
          LoopChalkCard(light: true, child: Text('浅')),
        ],
      ),
    );
    BoxDecoration groundOf(String text) =>
        tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(
                        of: find.text(text),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(groundOf('深').color, LoopColors.card);
    expect(
      DefaultTextStyle.of(tester.element(find.text('深'))).style.color,
      LoopColors.chalk,
    );
    expect(groundOf('浅').color, LoopColors.chalk);
    expect(
      DefaultTextStyle.of(tester.element(find.text('浅'))).style.color,
      LoopColors.ink,
    );
  });

  testWidgets('6 · inline lines and field labels sit on the page gutter', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const LoopInlineUnavailable(message: '读不到'),
          LoopProvenanceLine(
            sources: const <String>['LOOP'],
            observedAt: DateTime(2026, 10, 20, 9),
            now: DateTime(2026, 10, 20, 10),
          ),
          const LoopFlatField(label: '内容', child: TextField()),
        ],
      ),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('loop-inline-unavailable')),
          )
          .dx,
      LoopSpacing.page,
    );
    // S278 · decision 0236: the provenance line is a (i) row on the same
    // gutter.
    expect(
      tester.getTopLeft(findProvenanceContaining('来源 LOOP')).dx,
      greaterThanOrEqualTo(LoopSpacing.page),
    );
    expect(
      tester.getTopLeft(findProvenanceContaining('来源 LOOP')).dx,
      lessThan(LoopSpacing.page + 1),
    );
    expect(tester.getTopLeft(find.text('内容')).dx, LoopSpacing.page);
    expect(
      tester.getTopLeft(find.byType(TextField)).dx,
      tester.getTopLeft(find.text('内容')).dx,
    );
  });

  test('7 · the monogram palette has no Yellow and every pair reads', () {
    final grounds = LoopMonogramPalette.grounds;
    expect(grounds, hasLength(6));
    expect(grounds.map((g) => g.id).toSet(), hasLength(6));
    for (final ground in grounds) {
      final fill = ground.fill;
      // No Yellow and no Yellow blend: a Yellow hue has red and green high
      // and blue clearly lower.
      final yellowish =
          fill.r > 0.5 && fill.g > 0.5 && fill.b < (fill.r + fill.g) / 2 - 0.15;
      expect(yellowish, isFalse, reason: ground.id);
      expect(fill, isNot(LoopColors.yellow), reason: ground.id);
      expect(
        _contrast(fill, ground.ink),
        greaterThanOrEqualTo(4.5),
        reason: ground.id,
      );
      for (final page in <Color>[
        LoopColors.ink,
        LoopColors.card,
        LoopColors.chalk,
      ]) {
        expect(fill, isNot(page), reason: ground.id);
      }
    }
    expect(
      grounds.where((g) => g.id.startsWith('purple')),
      isNotEmpty,
      reason: 'Purple is part of the identity palette',
    );
  });

  test('8 · a section / date heading is Arimo 700, not Anton', () {
    expect(LoopType.sectionTitle.fontFamily, LoopFonts.body);
    expect(LoopType.sectionTitle.fontWeight, FontWeight.w700);
    expect(loopFlatSectionStyle().fontFamily, LoopFonts.body);
    expect(LoopType.sectionTitle.fontFamilyFallback, contains(LoopFonts.cjk));
  });
}
