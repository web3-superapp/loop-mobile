// S254 · design-revision tails (docs/42 附C, decision 0212).
//
// 1. The segment count bar draws 36-tall capsules and still answers a 48-tall
//    finger (附C §4).
// 2. The document pages (system, the old Launch IDO family) carry no
//    「A · B · C」 middle-dot strings and no upper-case English stamp or
//    section label (附C §2).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: Column(children: <Widget>[child])),
    ),
  );
  await tester.pump();
}

/// The non-comment lines of every Dart file under [directory].
Iterable<(String, int, String)> _codeLines(String directory) sync* {
  final files =
      Directory(directory)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      if (line.trimLeft().startsWith('//')) continue;
      yield (file.path, index + 1, line);
    }
  }
}

final Finder _capsule = find.byKey(const ValueKey<String>('loop-seg-capsule'));

void main() {
  group('segment count bar (附C §4)', () {
    testWidgets('capsules are 36 tall inside a 48 target', (tester) async {
      var chosen = -1;
      await _pump(
        tester,
        LoopSegBar(
          key: const ValueKey<String>('bar'),
          labels: const <String>['铸造中 3', '内盘 12', '预告 0', '已毕业 5'],
          dimmed: const <bool>[false, false, true, false],
          selectedIndex: 0,
          onSelected: (index) => chosen = index,
        ),
      );

      final chips = find.byType(LoopSeg);
      expect(chips, findsNWidgets(4));
      for (var index = 0; index < 4; index += 1) {
        final chip = chips.at(index);
        final target = tester.getRect(chip);
        final capsule = tester.getRect(
          find.descendant(of: chip, matching: _capsule),
        );
        expect(capsule.height, LoopSegBar.capsuleHeight);
        expect(target.height, greaterThanOrEqualTo(LoopSeg.segmentTarget));
        expect(target.width, greaterThanOrEqualTo(LoopSeg.segmentTarget));
        // The capsule sits in the middle of its target.
        expect(capsule.center.dy, closeTo(target.center.dy, 0.01));
      }

      // The selected capsule is solid Purple (附C §4); the others are clear.
      Color? ground(int index) =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: chips.at(index),
                          matching: _capsule,
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      expect(ground(0), LoopColors.purpleSelected);
      expect(ground(1), Colors.transparent);

      // A finger held in the room under a capsule presses that capsule.
      final third = tester.getRect(chips.at(2));
      final gesture = await tester.startGesture(
        Offset(third.center.dx, third.bottom - 2),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(ground(2), isNot(Colors.transparent));
      await gesture.up();
      await tester.pump();
      expect(ground(2), Colors.transparent);
      expect(chosen, 2);

      // A tap in the room above a capsule still chooses that chip.
      final second = tester.getRect(chips.at(1));
      await tester.tapAt(Offset(second.center.dx, second.top + 2));
      await tester.pump();
      expect(chosen, 1);
      // And so does a tap on the capsule itself — the bar scrolls it into
      // view first at the v3 word size (decision 0229).
      await tester.ensureVisible(chips.at(3));
      await tester.pumpAndSettle();
      final fourth = tester.getRect(chips.at(3));
      await tester.tapAt(fourth.center);
      await tester.pump();
      expect(chosen, 3);
    });

    testWidgets('the bar keeps the 14 below its capsules', (tester) async {
      await _pump(
        tester,
        LoopSegBar(
          key: const ValueKey<String>('bar'),
          labels: const <String>['全部', '新币'],
          selectedIndex: 1,
          onSelected: (_) {},
        ),
      );
      final bar = tester.getRect(find.byKey(const ValueKey<String>('bar')));
      final capsule = tester.getRect(
        find.descendant(of: find.byType(LoopSeg).first, matching: _capsule),
      );
      expect(bar.bottom - capsule.bottom, 14);
    });

    testWidgets('a chip outside the bar keeps its 44 capsule', (tester) async {
      await _pump(
        tester,
        LoopSeg(
          key: const ValueKey<String>('seg'),
          label: '1%',
          selected: false,
          onSelected: () {},
        ),
      );
      final chip = find.byKey(const ValueKey<String>('seg'));
      expect(find.descendant(of: chip, matching: _capsule), findsNothing);
      final capsule = tester.getRect(
        find.descendant(of: chip, matching: find.byType(Material)).first,
      );
      expect(capsule.height, LoopTouch.minimum);
    });
  });

  group('document pages speak Chinese in full sentences (附C §2)', () {
    const documentPages = <String>[
      'lib/features/system',
      'lib/features/launch',
    ];

    test('no 「A · B」 middle-dot string on the document pages', () {
      final offenders = <String>[
        for (final directory in documentPages)
          for (final (path, line, text) in _codeLines(directory))
            if (RegExp(r"'[^']*·[^']*'").hasMatch(text)) '$path:$line',
      ];
      expect(offenders, isEmpty);
    });

    test('no upper-case English stamp or section label', () {
      // A stamp, a mono tile or a section label written as an upper-case
      // English word (`'OFFLINE'`, `'2H WINDOW'`, `'Top Holders'`). Brand and
      // asset names are not labels in this sense.
      final label = RegExp(
        r"(stamp:|LoopMonoTile\(label:|shortTitle:|LoopLabel\()[^']*'"
        r"([^']*)'",
      );
      // Product and brand names a label may carry; interpolations are
      // values, not words.
      final names = RegExp(r'\b(LOOP|Passkey|App|USD1)\b');
      final interpolation = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_]\w*');
      final english = RegExp(r'\b[A-Z][A-Za-z]+\b');
      final offenders = <String>[
        for (final directory in <String>[
          ...documentPages,
          'lib/features/profile/security',
          'lib/features/security',
        ])
          for (final (path, line, text) in _codeLines(directory))
            for (final match in label.allMatches(text))
              if (english.hasMatch(
                match
                    .group(2)!
                    .replaceAll(interpolation, '')
                    .replaceAll(names, ''),
              ))
                '$path:$line ${match.group(2)}',
      ];
      expect(offenders, isEmpty);
    });
  });
}
