import 'dart:convert';

/// Decision 0199 (backend 0154): a MEME / launch token's name and
/// description take any language or script — Chinese, English, mixed,
/// emoji. Only hazards are refused: control characters, invisible format
/// characters (bidi overrides, zero-width spaces; the emoji zero-width
/// joiner and tag characters stay) and blank text. Lengths count Unicode
/// characters; the name also has the launch factory's on-chain bound of
/// 64 UTF-8 bytes (64 English letters, 21 Chinese characters, 16 emoji).
const int loopTokenNameMaxCharacters = 64;
const int loopTokenNameMaxBytes = 64;
const int loopTokenDescriptionMaxCharacters = 2000;

/// Shown for a name over either bound.
const String loopTokenNameLengthMessage = '名称最多 64 个字（中文最多 21 个字）';

final RegExp _format = RegExp(r'[\p{Cf}\p{Zl}\p{Zp}]', unicode: true);
final RegExp _allowedFormat = RegExp(
  r'[\u200d\u{e0020}-\u{e007f}]',
  unicode: true,
);
final RegExp _control = RegExp(r'\p{Cc}', unicode: true);
final RegExp _controlButLayout = RegExp(r'(?![\n\t])\p{Cc}', unicode: true);
final RegExp _asciiTicker = RegExp(r'^[A-Za-z0-9]+$');

/// UTF-8 length of [value].
int loopUtf8Length(String value) => utf8.encode(value).length;

/// Unicode characters (code points) in [value], as the backend counts.
int loopCharacterCount(String value) => value.runes.length;

bool _hasForbiddenFormat(String value) =>
    _format.hasMatch(value.replaceAll(_allowedFormat, ''));

/// Why [raw] is not a token name, or `null`.
String? loopTokenNameError(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '请填写名称';
  if (loopCharacterCount(value) > loopTokenNameMaxCharacters ||
      loopUtf8Length(value) > loopTokenNameMaxBytes) {
    return loopTokenNameLengthMessage;
  }
  if (_control.hasMatch(value) || _hasForbiddenFormat(value)) {
    return '名称不能包含换行、控制符或不可见字符';
  }
  return null;
}

/// Why [raw] is not a token description, or `null` (empty is allowed).
String? loopTokenDescriptionError(String raw) {
  final value = raw.trim();
  if (loopCharacterCount(value) > loopTokenDescriptionMaxCharacters) {
    return '简介最多 $loopTokenDescriptionMaxCharacters 个字';
  }
  if (_controlButLayout.hasMatch(value.replaceAll('\r', '')) ||
      _hasForbiddenFormat(value)) {
    return '简介不能包含控制符或不可见字符';
  }
  return null;
}

/// The token's symbol as shown: `$DOGE` for an ASCII ticker, the bare
/// symbol (`狗狗`, `🐸`) otherwise — a `$` before a Chinese or emoji
/// symbol reads as a price, so non-ASCII symbols go without it.
String loopTickerLabel(String symbol) {
  final value = symbol.trim();
  if (value.isEmpty) return value;
  return _asciiTicker.hasMatch(value) ? '\$$value' : value;
}
