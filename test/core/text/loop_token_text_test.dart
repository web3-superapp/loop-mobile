import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_create_screen.dart';

/// Decisions 0199 / 0206 (backend 0154 / 0164, contracts 0016): no language
/// or script rule on a token's name, ticker or description; name and ticker
/// share four.meme's 1–20 UTF-16 units.
void main() {
  test('Chinese, English, mixed and emoji names pass', () {
    for (final name in <String>[
      '币安人生',
      'Loop Doge',
      '狗狗 Doge 2026',
      '🐸 Pepe 青蛙',
      '👨\u{200D}👩\u{200D}👧 家族',
      'ミーム코인',
      'Ünïcödé',
    ]) {
      expect(loopTokenNameError(name), isNull, reason: name);
      expect(launch2FieldError(Launch2Field.name, name), isNull);
    }
  });

  test('name and ticker share four.meme’s 1–20 UTF-16 units', () {
    for (final check in <String? Function(String)>[
      loopTokenNameError,
      loopTokenTickerError,
    ]) {
      expect(check('a' * 20), isNull);
      expect(check('中' * 20), isNull);
      expect(check('🐸' * 10), isNull);
      expect(check('a' * 21), isNotNull);
      expect(check('中' * 21), isNotNull);
      expect(check('🐸' * 10 + 'a'), isNotNull);
      expect(check('  ${'中' * 20}  '), isNull, reason: 'trimmed first');
    }
    expect(loopTokenNameError('a' * 21), loopTokenNameLengthMessage);
    expect(loopTokenTickerError('a' * 21), loopTokenTickerLengthMessage);
    expect(loopTokenTextUnits(' 🐸狗 '), 3);
  });

  test('four.meme tickers pass as typed, never upper-cased', () {
    for (final ticker in <String>[
      '狗狗币',
      r'$1',
      '四',
      '4',
      'フリーダム.オブ.マネー',
      'Hand recognizes hand',
      'doge',
      '2DOGE',
      '牛虾🔶',
      '👨\u{200D}👩\u{200D}👧',
      '🏳\u{FE0F}\u{200D}🌈',
      '\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}',
      '쌀밥',
      '中\u{3000}文',
    ]) {
      expect(loopTokenTickerError(ticker), isNull, reason: ticker);
      expect(launch2FieldError(Launch2Field.ticker, ticker), isNull);
      expect(loopTokenTickerIsWellFormed(ticker), isTrue, reason: ticker);
    }
  });

  test('blank, edge spaces, odd spaces and edge joiners are refused', () {
    expect(loopTokenTickerError('   '), '请填写代码');
    expect(loopTokenNameError(''), '请填写名称');
    // The form trims before it checks and before it submits; a value that
    // still carries an edge space is not one the rule produces.
    expect(loopTokenTickerIsWellFormed(' DOGE'), isFalse);
    expect(loopTokenTickerIsWellFormed('DOGE '), isFalse);
    expect(loopTokenTickerIsWellFormed('\u{3000}狗'), isFalse);
    for (final ticker in <String>[
      'a\u{00A0}b',
      'a\u{2002}b',
      '\u{200D}狗',
      '狗\u{200D}',
      'aㅤb',
      'a⠀b',
      'a${String.fromCharCode(0xd800)}b',
    ]) {
      expect(loopTokenTickerError(ticker), isNotNull, reason: ticker);
    }
  });

  test('blank, control and invisible characters are refused', () {
    expect(loopTokenNameError('   '), '请填写名称');
    for (final name in <String>[
      'a\nb',
      'a\tb',
      'a\u0000b',
      'abc\u202egpj',
      'a\u200bb',
      'a\u2028b',
    ]) {
      expect(loopTokenNameError(name), isNotNull, reason: name);
    }
  });

  test('the description counts characters and keeps line breaks', () {
    expect(loopTokenDescriptionError('第一行\r\n第二行\t🐸'), isNull);
    expect(loopTokenDescriptionError(''), isNull);
    expect(loopTokenDescriptionError('🐸' * 2000), isNull);
    expect(loopTokenDescriptionError('中' * 2001), '简介最多 2000 个字');
    expect(loopTokenDescriptionError('a\u0007b'), isNotNull);
    expect(loopTokenDescriptionError('a\u202eb'), isNotNull);
  });

  test('the catalogue draft takes a Chinese name and ticker', () {
    LaunchProjectDraft draft(String name, [String ticker = 'DOGE']) =>
        LaunchProjectDraft(
          name: name,
          ticker: ticker,
          narrative: '中文简介\n第二行',
          officialLinks: const LaunchOfficialLinks(),
        );
    expect(draft('狗狗币 Doge').invalidField, isNull);
    expect(draft('狗狗币', '狗狗币').invalidField, isNull);
    expect(draft('Doge', r'$1').invalidField, isNull);
    expect(draft('中' * 21).invalidField, LaunchDraftField.name);
    expect(draft('Doge', 'a' * 21).invalidField, LaunchDraftField.ticker);
  });

  test(r'only an ASCII ticker gets the `$`', () {
    expect(loopTickerLabel('DOGE'), r'$DOGE');
    expect(loopTickerLabel('狗狗'), '狗狗');
    expect(loopTickerLabel('🐸'), '🐸');
    expect(loopTickerLabel('PEPE中'), 'PEPE中');
    expect(loopTickerLabel('doge'), r'$doge');
    expect(loopTickerLabel(r'$1'), r'$1');
    expect(loopTickerLabel(r'$DOGE'), r'$DOGE');
    expect(loopTickerLabel('Hand recognizes hand'), 'Hand recognizes hand');
    expect(loopTickerLabel(''), '');
  });

  test('a monogram takes any script', () {
    expect(loopMonogram('狗狗币'), '狗狗');
    expect(loopMonogram('ミーム'), 'ミー');
    expect(loopMonogram('élan'), 'ÉL');
    expect(loopMonogram('e\u{0301}lan'), 'E\u{0301}L');
    expect(loopMonogram('フリーダム'), 'フリ');
    expect(loopMonogram('쌀밥'), '쌀밥');
    expect(loopMonogram(r'$1'), '1');
    expect(loopMonogram('🐸'), '🐸');
    expect(loopMonogram('  '), '·');
    // A cluster keeps at most two marks; a bare mark never leads.
    expect(
      loopMonogram('e\u{0301}\u{0302}\u{0303}\u{0304}x'),
      'E\u{0301}\u{0302}X',
    );
    expect(loopMonogram('\u{0301}\u{0302}'), '·');
    expect(loopMonogram('\u{0301} 🐸'), '🐸');
  });
}
