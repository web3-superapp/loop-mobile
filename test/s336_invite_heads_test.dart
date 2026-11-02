import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_screen.dart';

import 'support/loop_shots.dart';

/// S336 · decision 0265: the 五级邀请 heads read whole at 390 wide in the
/// app's own faces — 「有效邀请」 was 「有效…」 on a device.
void main() {
  MiningInvites invites(String figure) => MiningInvites(
    levels: <MiningInviteLevel>[
      for (final (level, rate) in <(int, String)>[
        (1, '10'),
        (2, '5'),
        (3, '3'),
        (4, '2'),
        (5, '1'),
      ])
        MiningInviteLevel(
          level: level,
          ratePercent: Decimal.parse(rate),
          activeMembers: 128,
          nftPower: Decimal.parse(figure),
          assetPower: Decimal.parse(figure),
        ),
    ],
    total: MiningInviteTotal(
      activeMembers: 640,
      nftPower: Decimal.parse(figure),
      assetPower: Decimal.parse(figure),
    ),
  );

  Future<void> pumpTable(WidgetTester tester, MiningInvites data) async {
    await tester.runAsync(loopLoadShotFonts);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(child: MiningInviteTable(invites: data)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final figure in <String>['0', '5000000']) {
    testWidgets('the five heads are one line each, figures $figure', (
      tester,
    ) async {
      await pumpTable(tester, invites(figure));
      expect(tester.takeException(), isNull);
      final widths = <double>[];
      for (var index = 0; index < miningInviteHeads.length; index += 1) {
        final head = find.byKey(ValueKey<String>('mining-invite-head-$index'));
        final text = tester.widget<Text>(head);
        expect(text.data, miningInviteHeads[index]);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: head, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: text.data);
        final painter = TextPainter(
          text: TextSpan(text: text.data, style: text.style),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: paragraph.size.width);
        expect(painter.computeLineMetrics(), hasLength(1), reason: text.data);
        painter.dispose();
        widths.add(paragraph.size.width);
      }
      expect(widths[2], widths[3]);
      expect(widths[3], widths[4]);
      // Every figure is drawn whole: it shrinks to its column, never «…».
      expect(find.textContaining('…'), findsNothing);
      expect(find.text(figure == '0' ? '0' : '5,000,000'), findsNWidgets(12));
    });
  }
}
