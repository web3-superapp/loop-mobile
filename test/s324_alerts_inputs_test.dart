// S324 · decision 0254 · UX-008 / UX-010.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/widgets/loop_alert_card.dart';
import 'package:loop_mobile/widgets/loop_inputs.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

void main() {
  group('UX-010 · the top notice', () {
    testWidgets('sits below the status bar, closes, swipes away and times '
        'out', (tester) async {
      var closed = <String>[];
      late StateSetter rebuild;
      final shown = <String>{'a', 'b', 'c'};
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 47),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Scaffold(
                  body: Stack(
                    children: <Widget>[
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LoopTopNoticeLayer(
                          notices: <LoopTopNotice>[
                            for (final id in shown)
                              LoopTopNotice(
                                id: id,
                                onDismissed: () => closed.add(id),
                                child: _Notice(
                                  id: id,
                                  onClose: () =>
                                      rebuild(() => shown.remove(id)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Below the status bar, never under the clock.
      for (final id in shown) {
        expect(
          tester.getTopLeft(find.byKey(ValueKey<String>('notice-$id'))).dy,
          greaterThanOrEqualTo(47),
        );
      }

      // Its own close control.
      await tester.tap(find.byKey(const ValueKey('notice-a-close')));
      await tester.pump();
      expect(find.byKey(const ValueKey('notice-a')), findsNothing);

      // Swiped up.
      await tester.fling(
        find.byKey(const ValueKey('notice-b')),
        const Offset(0, -300),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notice-b')), findsNothing);
      expect(closed, contains('b'));

      // Left alone, it goes on its own.
      expect(find.byKey(const ValueKey('notice-c')), findsOneWidget);
      await tester.pump(LoopTopNoticeLayer.defaultLife);
      await tester.pump();
      expect(find.byKey(const ValueKey('notice-c')), findsNothing);
      expect(closed, contains('c'));
      closed = <String>[];
    });
  });

  group('UX-010 · in-page warnings are one card', () {
    testWidgets('a missing block is the compact warning card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: LoopUnavailableLine(label: '跨链与挖矿领取记录不可用', reasonCode: null),
          ),
        ),
      );

      final card = find.byKey(const ValueKey('unavailable-unstated'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.byType(LoopAlertCard),
          matchRoot: true,
        ),
        findsOneWidget,
        reason: 'the key sits on the card itself',
      );
      final box = tester.widget<Container>(
        find.byKey(const ValueKey('loop-alert-card')),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, LoopAlertCard.ground);
      expect((decoration.border! as Border).top.color, LoopAlertCard.edge);
      expect(decoration.borderRadius, LoopRadius.control);
      expect(find.text('跨链与挖矿领取记录不可用'), findsOneWidget);
    });
  });

  group('UX-008 · focus', () {
    testWidgets('a hand-drawn field box turns Purple while it has focus', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: LoopFocusRing(
              child: TextField(
                focusNode: focus,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
        ),
      );
      Color edge() =>
          ((tester
                              .widget<DecoratedBox>(
                                find.byKey(LoopFocusRing.edgeKey),
                              )
                              .decoration
                          as BoxDecoration)
                      .border!
                  as Border)
              .top
              .color;
      expect(edge(), Colors.transparent);

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(edge(), LoopColors.purple);
      final decoration =
          tester
                  .widget<DecoratedBox>(find.byKey(LoopFocusRing.edgeKey))
                  .decoration
              as BoxDecoration;
      expect(decoration.borderRadius, LoopRadius.control);
      // Focus arriving never rebuilds the field: what was typed stays.
      expect(find.text('abc'), findsOneWidget);

      focus.unfocus();
      await tester.pump();
      expect(edge(), Colors.transparent);
    });

    test('every field state in the theme keeps the 12 corner', () {
      final theme = LoopTheme.dark.inputDecorationTheme;
      for (final border in <InputBorder?>[
        theme.border,
        theme.enabledBorder,
        theme.focusedBorder,
        theme.errorBorder,
        theme.focusedErrorBorder,
        theme.disabledBorder,
      ]) {
        expect(border, isA<OutlineInputBorder>());
        expect(
          (border! as OutlineInputBorder).borderRadius,
          LoopRadius.control,
        );
      }
      expect(theme.focusedBorder!.borderSide.color, LoopColors.purple);
    });
  });
}

class _Notice extends StatelessWidget {
  const _Notice({required this.id, required this.onClose});

  final String id;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: SizedBox(
      key: ValueKey<String>('notice-$id'),
      height: 64,
      child: Row(
        children: <Widget>[
          Expanded(child: Text('notice $id')),
          IconButton(
            key: ValueKey<String>('notice-$id-close'),
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}
