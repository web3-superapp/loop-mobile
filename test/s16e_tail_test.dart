import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

Widget _app(Widget child) => MaterialApp(
  theme: LoopTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  group('the stage rail is read out in the reader’s own language', () {
    testWidgets('the rail announces one Chinese sentence, not an identifier', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const Center(child: LoopContextRail(stage: LoopStage.discuss))),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('当前阶段：讨论'), findsOneWidget);
      // The Dart identifier never reaches the reader, and neither does the
      // English sentence it used to sit in.
      expect(find.bySemanticsLabel(RegExp('discuss')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Current loop stage')), findsNothing);
      // The visible chips are the prototype's own Latin tokens and stay.
      expect(find.text('DISCUSS'), findsOneWidget);
      handle.dispose();
    });

    test('every stage carries both a chip and a spoken label', () {
      for (final stage in LoopStage.values) {
        expect(stage.chip, stage.chip.toUpperCase());
        expect(stage.label, isNot(stage.chip));
        expect(RegExp(r'^[\x00-\x7F]+$').hasMatch(stage.label), isFalse);
      }
    });
  });

  group('a crowded chat header still says which channel it is', () {
    testWidgets('a dense bar prints its title at the heading step below', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          LoopTopbar(
            title: 'Builders Hub',
            onBack: () {},
            minHeight: 72,
            titleMaxLines: 2,
            dense: true,
            actions: <Widget>[
              for (final icon in <String>['search', 'shuffle', 'voice', 'info'])
                LoopIconButton(icon: icon, label: icon, onPressed: () {}),
            ],
          ),
        ),
      );
      await tester.pump();

      final title = tester.renderObject<RenderParagraph>(
        find.text('Builders Hub'),
      );
      // The whole name, in the same bar, with all four tools still in it.
      expect(title.didExceedMaxLines, isFalse);
      expect(title.text.style!.fontSize, 17);
      expect(find.byType(LoopIconButton), findsNWidgets(5));
      expect(tester.getSize(find.byType(LoopTopbar)).height, lessThan(90));
    });

    testWidgets('an ordinary bar keeps the full heading step', (tester) async {
      await tester.pumpWidget(_app(LoopTopbar(title: '关于', onBack: () {})));
      await tester.pump();

      expect(
        tester
            .renderObject<RenderParagraph>(find.text('关于'))
            .text
            .style!
            .fontSize,
        22,
      );
    });
  });
}
