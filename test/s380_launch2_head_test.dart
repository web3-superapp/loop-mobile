// S380 · decision 0304 (需求方 11-06 18:30), amending 0303 §3: the MEME
// detail page's bar carries no title at any width; the token's symbol is
// the heading beside the logo (19 / 700 Chalk, up to three lines, then
// 16 / 700, never cut); under it 「name | address + copy」 at the start and
// the stage capsule flush with the end, one line that never wraps.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_parts.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/launch2_fixtures.dart';
import 'support/s285_page.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _longTicker = '猫猫啦咯啦咯啦咯啦咯啦咯啦咯';
const String _longName = '猫猫猫猫猫猫猫猫猫猫猫猫猫猫猫猫猫猫猫猫猫猫猫猫';

Map<String, Object?> _json({
  required String name,
  required String ticker,
  String stage = 'public',
  bool countdown = false,
}) {
  final json = l2DetailJson(stage: stage, noNextChange: !countdown);
  (json['instance']! as Map<String, Object?>)
    ..['name'] = name
    ..['ticker'] = ticker;
  return json;
}

Widget _head({
  required String name,
  required String ticker,
  bool countdown = false,
}) => Launch2InstanceHead(
  detail: LoopV2Launch2Codec.detail(
    _json(name: name, ticker: ticker, countdown: countdown),
    mediaUrl: (_) => null,
  ),
  onCopy: () {},
  onElapsed: () {},
);

Future<void> _host(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double scale = 1,
}) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
}

RenderParagraph _paragraph(WidgetTester tester, String key) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: _key(key), matching: find.byType(RichText)),
    );

void main() {
  group('the bar carries no title', () {
    for (final width in <double>[360, 390, 412]) {
      testWidgets('only the back control and the (i) ($width)', (tester) async {
        await pumpS285Project(
          tester,
          launch2: S285Launch2(
            detail: LoopV2Launch2Codec.detail(
              _json(name: '猫猫', ticker: _longTicker),
              mediaUrl: (_) => null,
            ),
          ),
          size: Size(width, 2400),
        );
        final bar = find.byType(LoopTopbar);
        expect(bar, findsOneWidget);
        expect(_key('launch2-instance-no-title'), findsOneWidget);
        expect(
          find.descendant(of: bar, matching: find.byType(Text)),
          findsNothing,
        );
        expect(
          find.descendant(
            of: bar,
            matching: find.byKey(
              const ValueKey<String>('loop-page-info-action'),
            ),
          ),
          findsOneWidget,
        );
        // The symbol is drawn once — in the head, not in the bar.
        expect(find.text(_longTicker), findsOneWidget);
        expect(
          find.descendant(
            of: _key('launch2-instance-folio'),
            matching: find.text(_longTicker),
          ),
          findsOneWidget,
        );
        // The bar keeps the symbol as its accessible name.
        expect(tester.widget<LoopTopbar>(bar).title, _longTicker);
        expect(tester.takeException(), isNull);
        await drainS285(tester);
      });
    }
  });

  group('the symbol is the heading', () {
    for (final width in <double>[360, 390, 412]) {
      testWidgets('beside the logo, 19 / 700 Chalk, wrapped, whole ($width)', (
        tester,
      ) async {
        await _host(
          tester,
          _head(name: '猫猫', ticker: _longTicker),
          width: width,
        );
        final text = tester.widget<Text>(_key('launch2-head-ticker'));
        expect(text.data, loopTickerLabel(_longTicker));
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.maxLines, isNull);
        expect(text.style!.fontSize, LoopType.headline.fontSize);
        expect(text.style!.fontSize, 19);
        expect(text.style!.fontWeight, FontWeight.w700);
        expect(text.style!.color, LoopColors.chalk);
        expect(
          _paragraph(tester, 'launch2-head-ticker').didExceedMaxLines,
          isFalse,
        );
        // Beside the logo, not under it.
        final logo = tester.getRect(find.byType(MemeLogo));
        final symbol = tester.getRect(_key('launch2-head-ticker'));
        expect(symbol.left, greaterThanOrEqualTo(logo.right));
        expect(symbol.top, lessThan(logo.bottom));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an ASCII symbol reads with its \$', (tester) async {
      await _host(tester, _head(name: 'Frog Launch', ticker: 'FROG'));
      expect(tester.widget<Text>(_key('launch2-head-ticker')).data, r'$FROG');
    });

    testWidgets('a symbol past three lines steps to 16 / 700, still whole', (
      tester,
    ) async {
      // A twenty-unit symbol needs more than three lines only on an enlarged
      // text scale.
      await _host(
        tester,
        _head(name: '猫猫', ticker: '猫猫啦咯啦咯啦咯啦咯啦咯啦咯啦咯啦咯'),
        width: 360,
        scale: 2.4,
      );
      final text = tester.widget<Text>(_key('launch2-head-ticker'));
      expect(text.data, '猫猫啦咯啦咯啦咯啦咯啦咯啦咯啦咯啦咯');
      expect(text.style!.fontSize, LoopType.headlineSm.fontSize);
      expect(text.style!.fontWeight, FontWeight.w700);
      expect(text.maxLines, isNull);
      expect(
        _paragraph(tester, 'launch2-head-ticker').didExceedMaxLines,
        isFalse,
      );
    });

    test('styleFor: three lines at 19, more at 16', () {
      final small = Launch2HeadSymbol.styleFor(
        'AB',
        200,
        TextScaler.noScaling,
        TextDirection.ltr,
      );
      expect(small.fontSize, LoopType.headline.fontSize);
      final long = Launch2HeadSymbol.styleFor(
        '猫' * 40,
        100,
        TextScaler.noScaling,
        TextDirection.ltr,
      );
      expect(long.fontSize, LoopType.headlineSm.fontSize);
    });
  });

  group('name | address + copy, the stage flush right', () {
    for (final width in <double>[360, 390, 412]) {
      testWidgets('one line in order, the stage at the content edge ($width)', (
        tester,
      ) async {
        await _host(
          tester,
          _head(name: '猫猫', ticker: _longTicker, countdown: true),
          width: width,
        );
        final name = tester.getRect(_key('launch2-head-name'));
        final rule = tester.getRect(_key('launch2-head-rule'));
        final address = tester.getRect(_key('launch2-head-address'));
        final copy = tester.getRect(_key('launch2-copy-address'));
        final stage = tester.getRect(_key('launch2-stage-capsule'));
        final line = tester.getRect(_key('launch2-identity'));
        final symbol = tester.getRect(_key('launch2-head-ticker'));
        expect(line.top, greaterThanOrEqualTo(symbol.bottom));
        for (final rect in <Rect>[name, address, copy, stage]) {
          expect(rect.top, greaterThanOrEqualTo(line.top - 8));
          expect(rect.bottom, lessThanOrEqualTo(line.bottom + 8));
        }
        // Name, rule, address and copy at the start, in that order.
        expect(name.left, closeTo(symbol.left, 0.01));
        expect(name.right, lessThanOrEqualTo(rule.left));
        expect(rule.right, lessThanOrEqualTo(address.left));
        expect(address.right, lessThanOrEqualTo(copy.left + 0.01));
        expect(copy.right, lessThanOrEqualTo(stage.left));
        expect(stage.right, closeTo(width - LoopSpacing.page, 0.01));
        final nameText = tester.widget<Text>(_key('launch2-head-name'));
        expect(nameText.data, '猫猫');
        expect(nameText.maxLines, 1);
        expect(nameText.style!.fontSize, LoopType.caption.fontSize);
        expect(nameText.style!.color, LoopColors.text2);
        expect(tester.widget<Text>(_key('launch2-head-address')).maxLines, 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a long symbol and a long name at 360: nothing overflows, the '
        'address gives way before the name, the stage keeps its place', (
      tester,
    ) async {
      await _host(
        tester,
        _head(name: _longName, ticker: _longTicker, countdown: true),
        width: 360,
      );
      expect(tester.takeException(), isNull);
      final name = tester.getRect(_key('launch2-head-name'));
      final address = tester.getRect(_key('launch2-head-address'));
      final copy = tester.getRect(_key('launch2-copy-address'));
      final stage = tester.getRect(_key('launch2-stage-capsule'));
      expect(stage.right, closeTo(360 - LoopSpacing.page, 0.01));
      expect(copy.right, lessThanOrEqualTo(stage.left));
      // The address is squeezed to nothing before the name is cut.
      expect(address.width, lessThan(1));
      expect(name.right, lessThanOrEqualTo(copy.left));
      expect(_paragraph(tester, 'launch2-head-name').didExceedMaxLines, isTrue);
      expect(
        tester.widget<Text>(_key('launch2-head-ticker')).data,
        _longTicker,
      );
    });

    testWidgets('a short name keeps its width; the address takes the rest', (
      tester,
    ) async {
      await _host(tester, _head(name: '猫猫', ticker: 'FROG'), width: 360);
      final name = tester.getRect(_key('launch2-head-name'));
      final address = tester.getRect(_key('launch2-head-address'));
      final copy = tester.getRect(_key('launch2-copy-address'));
      expect(
        _paragraph(tester, 'launch2-head-name').didExceedMaxLines,
        isFalse,
      );
      expect(
        address.left,
        closeTo(name.right + Launch2HeadSymbol.ruleRoom, 0.01),
      );
      expect(address.width, greaterThan(0));
      expect(copy.left, closeTo(address.right, 0.01));
      expect(tester.takeException(), isNull);
    });
  });
}
