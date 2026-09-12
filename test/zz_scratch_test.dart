import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

import 'support/loop_ground_probe.dart';

void main() {
  for (final enabled in <bool>[true, false]) {
    testWidgets('filled button enabled=$enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            backgroundColor: LoopColors.ink,
            body: Center(
              child: FilledButton.icon(
                onPressed: enabled ? () {} : null,
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final probe in loopProbeGround(
        tester.element(find.byType(Scaffold)),
        LoopColors.ink,
      )) {
        if (probe.kind == 'text' || probe.kind == 'fill') {
          // ignore: avoid_print
          print('SCRATCH inactive=${probe.inactive} $probe');
        }
      }
    });
  }
}
