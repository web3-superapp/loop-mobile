import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_profile_sections.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

/// S355g (decision 0281): the shared widgets' copy follows the App language.
void main() {
  final now = DateTime.utc(2026, 11, 4, 12);

  group('loopAgeLabel', () {
    test('English: Just now / Ns ago / Nm ago / Nh ago / Nd ago', () {
      expect(loopAgeLabel(now, now: now), 'Just now');
      expect(
        loopAgeLabel(now.subtract(const Duration(seconds: 12)), now: now),
        '12s ago',
      );
      expect(
        loopAgeLabel(now.subtract(const Duration(minutes: 3)), now: now),
        '3m ago',
      );
      expect(
        loopAgeLabel(now.subtract(const Duration(hours: 5)), now: now),
        '5h ago',
      );
      expect(
        loopAgeLabel(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
    });

    test('Simplified Chinese keeps 秒前 / 分钟前 / 小时前 / 天前', () {
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(loopAgeLabel(now, now: now), '刚刚');
      expect(
        loopAgeLabel(now.subtract(const Duration(seconds: 12)), now: now),
        '12 秒前',
      );
      expect(
        loopAgeLabel(now.subtract(const Duration(minutes: 3)), now: now),
        '3 分钟前',
      );
      expect(
        loopAgeLabel(now.subtract(const Duration(hours: 5)), now: now),
        '5 小时前',
      );
      expect(
        loopAgeLabel(now.subtract(const Duration(days: 2)), now: now),
        '2 天前',
      );
    });
  });

  group('defaults read in the current language', () {
    test('offline card: separators and default paused actions', () {
      const card = LoopOfflineState(cachedAtLabel: '09:38');
      expect(
        card.body,
        'Paused: Send, Swap, Bridge, Sign. Cached values may be out of date.',
      );
      const none = LoopOfflineState(pausedActions: <String>[]);
      expect(
        none.body,
        "This read didn't finish and there's no cache to show yet.",
      );
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(card.body, '已暂停：发送、兑换、跨链、签名。缓存值可能已过期。');
      expect(
        const LoopOfflineState().body,
        '这次读取没有完成，还没有可显示的缓存。已暂停：发送、兑换、跨链、签名。',
      );
    });

    test('unreachable page block stays const and switches language', () {
      const block = LoopPageBlock.unreachable();
      expect(block.title, "Can't reach LOOP right now");
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(block.title, '现在连不上 LOOP');
    });

    test('profile sections: Holdings / Trades / Communities', () {
      expect(LoopProfileSection.values.map((s) => s.label), <String>[
        'Holdings',
        'Trades',
        'Communities',
      ]);
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(LoopProfileSection.values.map((s) => s.label), <String>[
        '持仓',
        '交易',
        '社区',
      ]);
    });
  });

  testWidgets('sign sheet defaults render in English', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LoopSignSheet(
              state: LoopSignSheetState.pending,
              facts: <LoopSignFact>[],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Confirm transaction'), findsOneWidget);
    expect(find.text('Confirm signature'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
