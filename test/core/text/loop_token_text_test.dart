import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_create_screen.dart';

/// Decision 0199 (backend 0154): no language or script rule on a token's
/// name or description.
void main() {
  test('Chinese, English, mixed and emoji names pass', () {
    for (final name in <String>[
      '币安人生',
      'Loop Doge',
      '狗狗 Doge 2026',
      '🐸 Pepe 青蛙',
      '👨‍👩‍👧 家族',
      'ミーム코인',
      'Ünïcödé',
    ]) {
      expect(loopTokenNameError(name), isNull, reason: name);
      expect(launch2FieldError(Launch2Field.name, name), isNull);
    }
  });

  test('the name is 64 characters and the factory’s 64 UTF-8 bytes', () {
    expect(loopTokenNameError('a' * 64), isNull);
    expect(loopTokenNameError('a' * 65), loopTokenNameLengthMessage);
    expect(loopUtf8Length('中' * 21), 63);
    expect(loopTokenNameError('中' * 21), isNull);
    expect(loopTokenNameError('中' * 22), loopTokenNameLengthMessage);
    expect(loopTokenNameError('🐸' * 16), isNull);
    expect(loopTokenNameError('🐸' * 17), loopTokenNameLengthMessage);
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

  test('the ticker stays on the factory pattern', () {
    expect(launch2FieldError(Launch2Field.ticker, 'doge'), isNull);
    expect(
      launch2FieldError(Launch2Field.ticker, '狗狗'),
      '代码暂只支持 2–12 位英文字母或数字（链上合约限制）',
    );
  });

  test('the catalogue draft takes a Chinese name within 64 bytes', () {
    LaunchProjectDraft draft(String name) => LaunchProjectDraft(
      name: name,
      ticker: 'DOGE',
      narrative: '中文简介\n第二行',
      officialLinks: const LaunchOfficialLinks(),
    );
    expect(draft('狗狗币 Doge').invalidField, isNull);
    expect(draft('中' * 22).invalidField, LaunchDraftField.name);
  });

  test(r'only an ASCII ticker gets the `$`', () {
    expect(loopTickerLabel('DOGE'), r'$DOGE');
    expect(loopTickerLabel('狗狗'), '狗狗');
    expect(loopTickerLabel('🐸'), '🐸');
    expect(loopTickerLabel('PEPE中'), 'PEPE中');
    expect(loopTickerLabel(''), '');
  });

  test('a monogram takes any script', () {
    expect(loopMonogram('狗狗币'), '狗狗');
    expect(loopMonogram('ミーム'), 'ミー');
    expect(loopMonogram('élan'), 'ÉL');
  });
}
