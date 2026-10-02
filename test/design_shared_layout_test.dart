import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

import 'support/loop_ground_probe.dart';

void main() {
  loopWatchGround();

  testWidgets('short value retains the right edge and gives title its space', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LoopRecordRow(
              title: 'Long asset name',
              trailing: '7',
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // The value stays aligned eight pixels before the chevron.
    expect(
      tester.getRect(find.text('7')).right,
      closeTo(tester.getRect(find.byType(LoopIcon)).left - 8, 1),
    );
    expect(
      tester.getSize(find.text('Long asset name')).width,
      greaterThan(125),
    );
  });
  for (final width in <double>[360, 390]) {
    testWidgets('record values wrap without losing digits at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const value = '123,456,789.12345678';
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: LoopRecordRow(
                title: 'Wrapped Bitcoin',
                subtitle: 'BTC',
                leading: const SizedBox(width: 40, height: 40),
                trailing: value,
                trailingCaption: '资产数据暂不可用，请稍后重试',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final text in <String>[value, '资产数据暂不可用，请稍后重试']) {
        final rect = tester.getRect(find.text(text));
        expect(rect.right, lessThanOrEqualTo(width - 16));
        expect(rect.left, greaterThanOrEqualTo(16));
        expect(
          tester.widget<Text>(find.text(text)).overflow,
          isNot(TextOverflow.ellipsis),
        );
      }
    });
  }
}
