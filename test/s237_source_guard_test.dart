// S237 · client decision 0204: a source guard so a test-only word cannot slip
// back into a user-visible string. 需求方 2026-10-19:「之前已经过了好几次了，
// 为什么还有测试相关提示呢」.
//
// Every string literal under `lib/` is read (comments are skipped, and the
// literal pieces of an interpolation are read on their own). The words below
// may appear in a literal only where the switch owns them.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The banned words. Matching is case-sensitive: `TESTNET` is the stamp,
/// while `testnet` in a key, a URL or a route is not drawn as words.
const List<String> _banned = <String>[
  '测试',
  '水龙头',
  '灰度',
  '试运行',
  '占位产量',
  '占位预算',
  '还在核对，交易',
  '合约还在核对',
  '没有价值',
  'TESTNET',
  'STAGING',
  'tBNB',
  'tUSD1',
];

/// The only file that may hold the switch-on texts.
const String _hintsFile = 'lib/core/config/loop_test_hints.dart';

/// Per-file exceptions, each with its reason.
const Map<String, Set<String>> _allowed = <String, Set<String>>{
  // `loopBackendTier` names the tier; `loopEnvironmentTag` draws it only
  // with the switch on, and 网络诊断 shows it only with the switch on.
  'lib/app/loop_backend_identity.dart': <String>{'STAGING'},
};

/// Server reason codes and capability ids are identifiers, not words: a
/// literal that is exactly one upper-snake code is skipped.
final RegExp _code = RegExp(r'^[A-Z0-9]+(_[A-Z0-9]+)+$');

/// The string literals of one Dart source, as (line, text) pairs. Each
/// literal piece of an interpolation is its own entry; the interpolated
/// expressions are scanned as code.
List<(int, String)> dartStringLiterals(String source) {
  final out = <(int, String)>[];
  var i = 0;
  final n = source.length;

  int line(int at) => '\n'.allMatches(source.substring(0, at)).length + 1;

  // Scans code from [start] until an unmatched `}` (when [inInterpolation])
  // or the end, returning the index after it.
  late int Function(int start, bool inInterpolation) code;

  int string(int start) {
    var at = start;
    var raw = false;
    if (source[at] == 'r') {
      raw = true;
      at++;
    }
    final quote = source[at];
    final triple =
        at + 2 < n && source[at + 1] == quote && source[at + 2] == quote;
    final close = triple ? quote * 3 : quote;
    at += close.length;
    final buffer = StringBuffer();
    var pieceStart = at;
    void flush() {
      if (buffer.isNotEmpty) out.add((line(pieceStart), buffer.toString()));
      buffer.clear();
    }

    while (at < n) {
      if (source.startsWith(close, at)) {
        flush();
        return at + close.length;
      }
      final c = source[at];
      if (!raw && c == r'\') {
        buffer.write(source.substring(at, at + 2));
        at += 2;
        continue;
      }
      if (!raw && c == r'$' && at + 1 < n && source[at + 1] == '{') {
        flush();
        at = code(at + 2, true);
        pieceStart = at;
        continue;
      }
      if (!triple && c == '\n') {
        flush();
        return at;
      }
      buffer.write(c);
      at++;
    }
    flush();
    return at;
  }

  code = (int start, bool inInterpolation) {
    var at = start;
    var depth = 0;
    while (at < n) {
      final c = source[at];
      if (source.startsWith('//', at)) {
        final end = source.indexOf('\n', at);
        at = end < 0 ? n : end;
        continue;
      }
      if (source.startsWith('/*', at)) {
        final end = source.indexOf('*/', at + 2);
        at = end < 0 ? n : end + 2;
        continue;
      }
      if (c == "'" || c == '"') {
        at = string(at);
        continue;
      }
      if (c == 'r' &&
          at + 1 < n &&
          (source[at + 1] == "'" || source[at + 1] == '"') &&
          (at == 0 || !RegExp(r'[A-Za-z0-9_$]').hasMatch(source[at - 1]))) {
        at = string(at);
        continue;
      }
      if (inInterpolation) {
        if (c == '{') depth++;
        if (c == '}') {
          if (depth == 0) return at + 1;
          depth--;
        }
      }
      at++;
    }
    return at;
  };

  i = code(0, false);
  assert(i == n);
  return out;
}

void main() {
  test('the scanner reads literals, skips comments, splits interpolation', () {
    final found = dartStringLiterals('''
// a comment with '测试网'
/* and '测试币' */
final a = 'one \${b('two')} three';
final c = r"raw \$x";
final d = """
multi
""";
''');
    final texts = found.map((entry) => entry.$2).toList();
    expect(texts, contains('one '));
    expect(texts, contains('two'));
    expect(texts, contains(' three'));
    expect(texts, contains(r'raw $x'));
    expect(texts.any((text) => text.contains('multi')), isTrue);
    expect(texts.any((text) => text.contains('测试')), isFalse);
  });

  test('no test-only word in any lib/ string literal (decision 0204)', () {
    final offences = <String>[];
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      if (path == _hintsFile) continue;
      final allowed = _allowed[path] ?? const <String>{};
      for (final (line, text) in dartStringLiterals(file.readAsStringSync())) {
        if (_code.hasMatch(text)) continue;
        for (final word in _banned) {
          if (allowed.contains(word)) continue;
          if (!text.contains(word)) continue;
          // `TESTNET_FAUCET_…` / `LAUNCH2_TESTNET_…` inside a longer literal
          // are still codes.
          if (word == 'TESTNET' &&
              !RegExp(r'(?<![A-Z_])TESTNET(?![A-Z_])').hasMatch(text)) {
            continue;
          }
          offences.add('$path:$line  [$word]  $text');
        }
      }
    }
    expect(offences, isEmpty, reason: offences.join('\n'));
  });

  test('the hints file is where the switch-on words live', () {
    final texts = dartStringLiterals(File(_hintsFile).readAsStringSync())
        .map((entry) => entry.$2)
        .join('\n');
    for (final word in <String>['测试网', 'TESTNET', 'tBNB', 'tUSD1']) {
      expect(texts, contains(word), reason: word);
    }
  });
}
