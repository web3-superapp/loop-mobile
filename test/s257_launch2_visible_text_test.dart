import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_create_screen.dart';

/// S257 (with loop-api S256): the name and the ticker must draw something.
/// ① at least one `\p{L}\p{N}\p{S}\p{P}`; ② tag characters only inside a
/// 🏴 … U+E007F flag; ③ no leading combining mark. The older rules stand.
void main() {
  const englandFlag =
      '\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}';

  test('invisible names and tickers are refused with the field’s sentence', () {
    for (final raw in <String>[
      '\u{E0041}',
      '\u{FE0F}',
      '\u{0301}abc',
      'ab\u{E0041}c',
      '\u{E0067}\u{E007F}',
      '\u{1F3F4}\u{E0067}\u{E0062}',
    ]) {
      expect(
        launch2FieldError(Launch2Field.name, raw),
        launch2NameInvisibleMessage,
        reason: raw.runes.map((r) => r.toRadixString(16)).join(' '),
      );
      expect(
        launch2FieldError(Launch2Field.ticker, raw),
        launch2TickerInvisibleMessage,
        reason: raw.runes.map((r) => r.toRadixString(16)).join(' '),
      );
    }
  });

  test('visible names and tickers pass, the England flag included', () {
    for (final raw in <String>[
      englandFlag,
      '星夜',
      r'$DOGE',
      'a\u{0301}bc',
      '🏳\u{FE0F}\u{200D}🌈',
      '🐸',
      '狗狗 $englandFlag',
    ]) {
      expect(launch2FieldError(Launch2Field.name, raw), isNull, reason: raw);
      expect(launch2FieldError(Launch2Field.ticker, raw), isNull, reason: raw);
      expect(launch2VisibleTextError(raw, launch2NameInvisibleMessage), isNull);
    }
  });

  test('the older rules answer first and are unchanged', () {
    expect(launch2FieldError(Launch2Field.name, '   '), '请填写名称');
    expect(launch2FieldError(Launch2Field.ticker, ''), '请填写代码');
    expect(launch2FieldError(Launch2Field.name, 'a​b'), '名称不能包含换行、控制符或不可见字符');
    expect(launch2FieldError(Launch2Field.ticker, 'a' * 21), isNotNull);
    expect(
      launch2FieldError(Launch2Field.ticker, 'a' * 21),
      isNot(launch2TickerInvisibleMessage),
    );
  });
}
