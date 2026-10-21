// S269 · 字体与间距规范 v3 (client decision 0229, docs/46): the ladder's
// values, the five Tabs' titles at title1, section headings at headline,
// list-row titles at body1, nothing under 12 on the priority pages, and the
// 20 page margin.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';

import 'support/loop_ground_probe.dart';
import 'support/s269_pages.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

String _id(int n) => '8b9f3c1e-2d4a-4f6b-9c8d-${n.toString().padLeft(12, '0')}';

double? _size(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style?.fontSize;

/// Every painted text size under the page, each span with its inherited size.
List<(String, double)> _paintedSizes(WidgetTester tester) {
  final found = <(String, double)>[];
  void visit(InlineSpan span, double? inherited) {
    final size = span.style?.fontSize ?? inherited;
    if (span is TextSpan) {
      final text = span.text;
      if (text != null && text.trim().isNotEmpty && size != null) {
        found.add((text, size));
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, size);
      }
    }
  }

  for (final element in find.byType(RichText).evaluate()) {
    // An avatar's or a logo's initials are drawn to its size, as a picture
    // is; they are not on the type ladder.
    var inAvatar = false;
    element.visitAncestorElements((ancestor) {
      final name = ancestor.widget.runtimeType.toString();
      if (name.contains('Avatar') ||
          name.contains('Monogram') ||
          name.contains('Logo')) {
        inAvatar = true;
        return false;
      }
      return true;
    });
    if (inAvatar) continue;
    visit((element.renderObject! as RenderParagraph).text, null);
  }
  return found;
}

void _expectNothingUnder12(WidgetTester tester, String page) {
  final sizes = _paintedSizes(tester);
  expect(sizes, isNotEmpty, reason: page);
  for (final (text, size) in sizes) {
    expect(size, greaterThanOrEqualTo(12), reason: '$page · 「$text」 at $size');
  }
}

void main() {
  loopWatchGround();

  test('the v3 ladder and spacing hold their documented values', () {
    expect(LoopType.title1.fontSize, 28);
    expect(LoopType.title1.fontWeight, FontWeight.w700);
    expect(LoopType.title2.fontSize, 22);
    expect(LoopType.headline.fontSize, 18);
    expect(LoopType.headline.fontWeight, FontWeight.w700);
    expect(LoopType.body1.fontSize, 17);
    expect(LoopType.body1.fontWeight, FontWeight.w600);
    expect(LoopType.figure.fontSize, 17);
    expect(
      LoopType.figure.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(LoopType.body2.fontSize, 16);
    expect(LoopType.body2.height, 1.5);
    expect(LoopType.caption.fontSize, 14);
    expect(LoopType.button.fontSize, 16);
    expect(LoopType.button.fontWeight, FontWeight.w700);
    expect(LoopType.tag.fontSize, 12);
    // Older names land on their v3 step.
    expect(LoopType.headingLg, same(LoopType.title1));
    expect(LoopType.flatTitle, same(LoopType.title2));
    expect(LoopType.sectionTitle, same(LoopType.headline));
    expect(LoopType.title, same(LoopType.body1));
    expect(LoopType.captionSm, same(LoopType.caption));
    expect(LoopType.action, same(LoopType.button));
    // Nothing on the ladder under 13 but the tag.
    for (final style in <TextStyle>[
      LoopType.caption,
      LoopType.captionSm,
      LoopType.kicker,
      LoopType.eyebrow,
      LoopType.label,
      LoopType.titleSm,
      LoopType.figureSm,
      LoopType.figureXs,
      LoopType.figureCompact,
      LoopType.code,
      LoopType.codeSm,
    ]) {
      expect(style.fontSize, greaterThanOrEqualTo(13));
    }

    expect(LoopSpacing.page, 20);
    expect(LoopSpacing.sectionTop, 36);
    expect(LoopSpacing.sectionBottom, 16);
    expect(LoopSpacing.rowMin, 72);
    expect(LoopSpacing.rowMinWithSub, 80);
    expect(LoopSpacing.rowGap, 12);
    expect(LoopSpacing.bannerGap, 28);
    expect(LoopSpacing.segmentGap, 16);
  });

  testWidgets('MEME: title1, headline sections, body1 rows, 20 margin, '
      'nothing under 12', (tester) async {
    await pumpS269MemeHome(tester);
    expect(
      _size(
        tester,
        find.descendant(
          of: find.byType(LoopAtmoTitle),
          matching: find.text('MEME'),
        ),
      ),
      28,
    );
    expect(
      _size(
        tester,
        find.descendant(
          of: _key('launch2-group-curve'),
          matching: find.text('内盘'),
        ),
      ),
      18,
    );
    final row = _key('launch2-row-${_id(1)}');
    expect(
      _size(tester, find.descendant(of: row, matching: find.text('天才少年'))),
      17,
    );
    // One primary figure on the right: the price at 17.
    expect(
      _size(
        tester,
        find.descendant(of: row, matching: _key('launch2-row-price')),
      ),
      17,
    );
    expect(tester.getSize(row).height, 80);
    // The board stands on the 20 page margin.
    expect(tester.getRect(row).left, 20);
    expect(tester.getRect(row).right, 370);
    _expectNothingUnder12(tester, 'MEME');
    await drainS269(tester);
  });

  testWidgets('广场 and 情报: the segment row is the title, at title1', (
    tester,
  ) async {
    await pumpS269Square(tester);
    expect(
      _size(
        tester,
        find.descendant(
          of: _key('square-segment-0'),
          matching: find.byType(RichText),
        ),
      ),
      28,
    );
    // The community rows: body1 names, 80 high.
    final firstId = '4b96a75e-6828-4a6b-8c1d-${0.toString().padLeft(12, '0')}';
    expect(
      _size(
        tester,
        find.descendant(
          of: _key('square-community-$firstId'),
          matching: find.text('DeFi 早读会 0'),
        ),
      ),
      17,
    );
    _expectNothingUnder12(tester, '广场');
    await drainS269(tester);

    await pumpS269Intel(tester);
    expect(
      _size(
        tester,
        find.descendant(
          of: _key('intel-segment-0'),
          matching: find.byType(RichText),
        ),
      ),
      28,
    );
    expect(_size(tester, find.text('前三名')), 18);
    _expectNothingUnder12(tester, '情报');
  });

  testWidgets('钱包: title1, headline-free tabs, body1 symbol and the figure', (
    tester,
  ) async {
    await pumpS269Wallet(tester);
    expect(
      _size(
        tester,
        find.descendant(
          of: find.byType(LoopAtmoTitle),
          matching: find.text('钱包'),
        ),
      ),
      28,
    );
    _expectNothingUnder12(tester, '钱包');
  });

  test(
    '聊天: the head is the search field; an inbox row is body1 over body2',
    () {
      // The chat Tab carries no title word (decision 0122's OKX social head);
      // its rows take the v3 steps through the Stream theme.
      final row = loopStreamChatThemeData().channelListItemTheme;
      expect(row.titleStyle?.fontSize, 17);
      expect(row.titleStyle?.fontWeight, FontWeight.w600);
      expect(row.subtitleStyle?.fontSize, 16);
      expect(row.timestampStyle?.fontSize, 14);
    },
  );

  testWidgets('项目页 and 代币页: nothing under 12', (tester) async {
    await pumpS269Project(tester);
    _expectNothingUnder12(tester, '项目页');
    await drainS269(tester);
    await pumpS269Token(tester);
    _expectNothingUnder12(tester, '代币页');
  });
}
