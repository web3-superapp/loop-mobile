import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// S355a (decision 0281, glossary §1.7–8): the launch2 formatters follow the
/// App language — English compact figures, month names and `5m ago`; zh-CN
/// keeps 「亿 / 万」, `MM-dd` and 「分钟前」.
void main() {
  final whole = BigInt.from(10).pow(18);
  BigInt tokens(int count) => BigInt.from(count) * whole;
  final now = DateTime(2026, 11, 4, 14, 5);

  group('English (default)', () {
    test('supply reads K / M / B', () {
      expect(launch2SupplyLabel(tokens(1000000000)), '1B');
      expect(launch2SupplyLabel(tokens(800000000)), '800M');
      expect(launch2SupplyLabel(tokens(5000000)), '5M');
      expect(launch2SupplyLabel(tokens(1234)), '1,234');
    });

    test('relative time and dates', () {
      expect(launch2RelativeTime(now, now), 'Just now');
      expect(
        launch2RelativeTime(now.subtract(const Duration(minutes: 5)), now),
        '5m ago',
      );
      expect(
        launch2ShortDateTime(DateTime(2026, 10, 18, 17, 32)),
        'Oct 18, 17:32',
      );
      expect(launch2MonthDay(DateTime(2026, 1, 3)), 'Jan 3');
      expect(
        launch2CountdownText(const Duration(days: 2, hours: 3)),
        '2d 03:00:00',
      );
      expect(
        launch2SpokenDuration(const Duration(hours: 2, minutes: 14)),
        '2h 14m',
      );
    });

    test('an action name opens a label in sentence case', () {
      expect(launch2SentenceCase('mint'), 'Mint');
      expect(launch2SentenceCase(''), '');
    });
  });

  group('简体中文', () {
    setUp(() => LoopL10n.use(LoopL10n.simplifiedChinese));

    test('supply keeps 亿 / 万', () {
      expect(launch2SupplyLabel(tokens(1000000000)), '10 亿');
      expect(launch2SupplyLabel(tokens(5000000)), '500 万');
    });

    test('relative time and dates keep the zh-CN shapes', () {
      expect(
        launch2RelativeTime(now.subtract(const Duration(minutes: 5)), now),
        '5 分钟前',
      );
      expect(
        launch2ShortDateTime(DateTime(2026, 10, 18, 17, 32)),
        '10-18 17:32',
      );
      expect(
        launch2CountdownText(const Duration(days: 2, hours: 3)),
        '2天 03:00:00',
      );
      expect(launch2SentenceCase('铸造'), '铸造');
    });
  });
}
