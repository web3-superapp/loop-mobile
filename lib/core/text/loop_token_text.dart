import 'dart:convert';

/// Decision 0206 (backend 0164, contracts 0016; supersedes the length and
/// ticker parts of 0199): a MEME / launch token's name and ticker follow
/// four.meme's rule — one rule for both. After `trim`, 1–20 UTF-16 units
/// (Dart `String.length`, as four.meme's JS `string.length`: a Chinese
/// character is 1, most emoji 2). Any script, spaces, `$`, lower case and a
/// leading digit are allowed; nothing is upper-cased and nothing has to be
/// unique. Only hazards are refused: control characters, invisible format
/// characters (bidi overrides, zero-width spaces; the emoji zero-width
/// joiner — only between two characters — and tag characters stay), line /
/// paragraph separators, spaces other than U+0020 / U+3000, and the blank
/// look-alikes the launch factory's `LaunchText` refuses.
const int loopTokenTextMaxUnits = 20;
const int loopTokenDescriptionMaxCharacters = 2000;

/// The rule as the form states it.
const String loopTokenTextRule = '名称和代码各 1–20 个字，可用中文、字母、数字、emoji';

/// Shown for a name or ticker over 20 units.
const String loopTokenNameLengthMessage = '名称最多 20 个字（emoji 算 2 个字）';
const String loopTokenTickerLengthMessage = '代码最多 20 个字（emoji 算 2 个字）';

final RegExp _format = RegExp(r'[\p{Cf}\p{Zl}\p{Zp}]', unicode: true);
final RegExp _allowedFormat = RegExp(
  r'[\u{200D}\u{E0020}-\u{E007F}]',
  unicode: true,
);
final RegExp _control = RegExp(r'\p{Cc}', unicode: true);
final RegExp _controlButLayout = RegExp(r'(?![\n\t])\p{Cc}', unicode: true);

/// Spaces other than the plain and the ideographic one (NBSP, U+2000–200A,
/// U+202F, U+205F, U+1680): they look like a space and the factory
/// refuses them anywhere.
final RegExp _oddSpace = RegExp(r'(?![\u{0020}\u{3000}])\p{Zs}', unicode: true);

/// What the factory's `LaunchText` refuses outside `\p{Cc}`, `\p{Cf}` and
/// `\p{Zs}`: the combining grapheme joiner, Mongolian variation selectors,
/// Khmer inherent vowels, the hangul fillers, the braille blank and the
/// non-characters.
final RegExp _factoryRefused = RegExp(
  r'[\u{034F}\u{115F}\u{1160}\u{17B4}\u{17B5}\u{180B}-\u{180F}\u{2800}'
  r'\u{3164}\u{FFA0}\u{FDD0}-\u{FDEF}\u{FFFE}\u{FFFF}]',
  unicode: true,
);

/// The emoji zero-width joiner; allowed only between two characters.
const String _zeroWidthJoiner = '\u{200D}';

/// Whether [value] holds a UTF-16 surrogate that is not in a pair.
bool _hasLoneSurrogate(String value) {
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      final next = i + 1 < value.length ? value.codeUnitAt(i + 1) : 0;
      if (next < 0xDC00 || next > 0xDFFF) return true;
      i++;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return true;
    }
  }
  return false;
}

final RegExp _asciiTicker = RegExp(r'^[A-Za-z0-9]+$');

/// UTF-8 length of [value].
int loopUtf8Length(String value) => utf8.encode(value).length;

/// Unicode characters (code points) in [value].
int loopCharacterCount(String value) => value.runes.length;

/// Units [raw] counts against the 20 once trimmed (UTF-16, as four.meme).
int loopTokenTextUnits(String raw) => raw.trim().length;

bool _hasForbiddenFormat(String value) =>
    _format.hasMatch(value.replaceAll(_allowedFormat, ''));

bool _hasHazard(String value) =>
    _control.hasMatch(value) ||
    _hasForbiddenFormat(value) ||
    _oddSpace.hasMatch(value) ||
    _factoryRefused.hasMatch(value) ||
    _hasLoneSurrogate(value) ||
    value.startsWith(_zeroWidthJoiner) ||
    value.endsWith(_zeroWidthJoiner);

String? _tokenTextError(String raw, String label, String lengthMessage) {
  final value = raw.trim();
  if (value.isEmpty) return '请填写$label';
  if (value.length > loopTokenTextMaxUnits) return lengthMessage;
  if (_hasHazard(value)) {
    return '$label不能包含换行、控制符或不可见字符';
  }
  return null;
}

/// Why [raw] is not a token name, or `null`.
String? loopTokenNameError(String raw) =>
    _tokenTextError(raw, '名称', loopTokenNameLengthMessage);

/// Why [raw] is not a token ticker, or `null` — the name's rule.
String? loopTokenTickerError(String raw) =>
    _tokenTextError(raw, '代码', loopTokenTickerLengthMessage);

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

/// The token's symbol as shown: `$DOGE` for an ASCII letters-and-digits
/// ticker, the bare symbol otherwise — `狗狗`, `🐸`, and one that already
/// starts with `$` (`$1`) or holds a space or sign. A `$` before a Chinese
/// or emoji symbol reads as a price.
String loopTickerLabel(String symbol) {
  final value = symbol.trim();
  if (value.isEmpty) return value;
  return _asciiTicker.hasMatch(value) ? '\$$value' : value;
}

/// Whether a ticker or token symbol the server sends is one the rule
/// produces: already trimmed, 1–[maxUnits] UTF-16 units, no hazard
/// character. The read side checks with the same rule, so a Chinese, emoji
/// or ZWJ-sequence symbol decodes (decision 0206). [maxUnits] lets a
/// field with a wider published bound (a wallet asset's 32) keep it.
bool loopTokenTickerIsWellFormed(
  String value, {
  int maxUnits = loopTokenTextMaxUnits,
}) {
  return value.isNotEmpty &&
      value == value.trim() &&
      value.length <= maxUnits &&
      !_hasHazard(value);
}
