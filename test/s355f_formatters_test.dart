import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

// S355f (decision 0281): the chart period chips, the MEME list's age label
// and the community mining panel's daily estimate follow the App language.
void main() {
  final created = DateTime.utc(2026, 11, 4, 12);

  group('English (default)', () {
    test('chart periods are Latin', () {
      expect(loopChartIntervalLabel(LoopCandleInterval.oneDay), '1D');
      expect(loopChartIntervalLabel(LoopCandleInterval.fifteenMinutes), '15m');
      expect(loopChartIntervalLabel(LoopCandleInterval.oneWeek), '1W');
      expect(MemeCandleInterval.oneDay.label, '1D');
    });

    test('MEME age label is compact', () {
      expect(
        memeAgeLabel(created, now: created.add(const Duration(seconds: 30))),
        'Just now',
      );
      expect(
        memeAgeLabel(created, now: created.add(const Duration(minutes: 11))),
        '11m',
      );
      expect(
        memeAgeLabel(created, now: created.add(const Duration(hours: 12))),
        '12h',
      );
      expect(
        memeAgeLabel(created, now: created.add(const Duration(days: 3))),
        '3d',
      );
    });

    test('daily estimate label', () {
      expect(LoopL10n.current.community_widgetsFor3, 'Est./day');
    });
  });

  group('Simplified Chinese', () {
    setUp(() => LoopL10n.use(LoopL10n.simplifiedChinese));
    tearDown(LoopL10n.debugReset);

    test('chart periods keep the Chinese chips', () {
      expect(loopChartIntervalLabel(LoopCandleInterval.oneDay), '1日');
      expect(loopChartIntervalLabel(LoopCandleInterval.oneHour), '1时');
      expect(MemeCandleInterval.oneDay.label, '1日');
    });

    test('MEME age label keeps Chinese units', () {
      expect(
        memeAgeLabel(created, now: created.add(const Duration(minutes: 11))),
        '11 分钟',
      );
      expect(
        memeAgeLabel(created, now: created.add(const Duration(days: 1))),
        '1 天',
      );
      expect(LoopL10n.current.community_widgetsFor3, '预估/日');
    });
  });
}
