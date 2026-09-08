import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/qr/loop_qr_code.dart';

void main() {
  group('LoopQrCode.encode', () {
    test(
      'encodes the receive-page EIP-681 payload at the expected version',
      () {
        final code = LoopQrCode.encode(_eip681Payload);

        expect(code, isNotNull);
        expect(code!.version, 4);
        expect(code.size, code.version * 4 + 17);
        expect(code.size, 33);
        expect(code.errorCorrection, LoopQrErrorCorrection.medium);

        // The three finder patterns, module for module, at the corners the
        // specification puts them at. The fourth corner deliberately has none.
        _expectFinderPattern(code, 0, 0);
        _expectFinderPattern(code, code.size - 7, 0);
        _expectFinderPattern(code, 0, code.size - 7);
      },
    );

    test('timing patterns alternate along row 6 and column 6', () {
      final code = LoopQrCode.encode(_eip681Payload);
      expect(code, isNotNull);

      // Between the separators the timing patterns run dark at even
      // coordinates and light at odd ones, in both directions.
      for (var i = 8; i < code!.size - 8; i++) {
        expect(code.isDark(i, 6), i.isEven, reason: 'row 6, column $i');
        expect(code.isDark(6, i), i.isEven, reason: 'column 6, row $i');
      }
    });

    test('is deterministic for the same input', () {
      final first = LoopQrCode.encode(_eip681Payload);
      final second = LoopQrCode.encode(_eip681Payload);

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(_render(second!), _render(first!));
    });

    test('different payloads produce different matrices', () {
      final first = LoopQrCode.encode(_eip681Payload);
      final second = LoopQrCode.encode(
        'ethereum:0x00000000000000000000000000000000000000a2@56',
      );

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first!.size, second!.size);
      expect(_render(second), isNot(_render(first)));
    });

    test('every error-correction level encodes and never shrinks', () {
      var previousVersion = 0;
      for (final level in LoopQrErrorCorrection.values) {
        final code = LoopQrCode.encode(_eip681Payload, errorCorrection: level);
        expect(code, isNotNull, reason: '$level');
        expect(code!.errorCorrection, level);
        expect(code.size, code.version * 4 + 17);
        expect(code.version, greaterThanOrEqualTo(previousVersion));
        previousVersion = code.version;
      }
    });
  });

  group('LoopQrCode.encode rejects what it cannot represent', () {
    test('returns null for a non Latin-1 character', () {
      expect(LoopQrCode.encode('中'), isNull);
      expect(LoopQrCode.encode('ethereum:0x00 中'), isNull);
      // Latin-1 above ASCII still encodes.
      expect(LoopQrCode.encode('café'), isNotNull);
    });

    test('returns null when the payload exceeds version 10', () {
      // Version 10-M holds 216 data codewords, so byte mode fits at most
      // (216 * 8 - 4 - 16) / 8 = 213 bytes.
      expect(LoopQrCode.encode('a' * 213), isNotNull);
      expect(LoopQrCode.encode('a' * 214), isNull);
      expect(LoopQrCode.encode('a' * 4000), isNull);
    });

    test('capacity shrinks as the error-correction level rises', () {
      expect(
        LoopQrCode.encode(
          'a' * 271,
          errorCorrection: LoopQrErrorCorrection.low,
        ),
        isNotNull,
      );
      expect(
        LoopQrCode.encode(
          'a' * 272,
          errorCorrection: LoopQrErrorCorrection.low,
        ),
        isNull,
      );
      // Version 10-H holds only 122 data codewords: 119 bytes at most.
      expect(
        LoopQrCode.encode(
          'a' * 119,
          errorCorrection: LoopQrErrorCorrection.high,
        ),
        isNotNull,
      );
      expect(
        LoopQrCode.encode(
          'a' * 120,
          errorCorrection: LoopQrErrorCorrection.high,
        ),
        isNull,
      );
    });
  });

  group('LoopQrCode capacity', () {
    test('every version and level switches over at the standard boundary', () {
      // Walks all 40 (version, error-correction level) pairs. The boundary
      // byte counts and total codeword counts come from the standard block
      // table, so a transcription slip anywhere in it surfaces here.
      for (var version = 1; version <= 10; version++) {
        for (final level in LoopQrErrorCorrection.values) {
          final label = 'version $version, $level';
          final maxBytes = _maxByteCapacity[version - 1][level.index];

          final atBoundary = LoopQrCode.encode(
            'a' * maxBytes,
            errorCorrection: level,
          );
          expect(atBoundary, isNotNull, reason: label);
          expect(atBoundary!.version, version, reason: label);
          expect(
            LoopQrCode.debugCodewords('a' * maxBytes, level),
            hasLength(_totalCodewords[version - 1]),
            reason: label,
          );

          final overBoundary = LoopQrCode.encode(
            'a' * (maxBytes + 1),
            errorCorrection: level,
          );
          if (version == 10) {
            expect(overBoundary, isNull, reason: label);
          } else {
            expect(overBoundary, isNotNull, reason: label);
            expect(overBoundary!.version, version + 1, reason: label);
          }
        }
      }
    });
  });

  group('LoopQrCode.isDark', () {
    test('throws RangeError outside the matrix', () {
      final code = LoopQrCode.encode('A');
      expect(code, isNotNull);
      final size = code!.size;

      expect(() => code.isDark(-1, 0), throwsRangeError);
      expect(() => code.isDark(0, -1), throwsRangeError);
      expect(() => code.isDark(size, 0), throwsRangeError);
      expect(() => code.isDark(0, size), throwsRangeError);
      expect(() => code.isDark(size, size), throwsRangeError);
      // The extremes of the valid range must not throw.
      expect(code.isDark(0, 0), isTrue);
      expect(() => code.isDark(size - 1, size - 1), returnsNormally);
    });
  });

  group('LoopQrCode quiet zone', () {
    test('the matrix carries modules only, never the 4-module margin', () {
      final code = LoopQrCode.encode('A');
      expect(code, isNotNull);

      // A version-1 symbol is exactly 21x21. If the mandatory quiet zone were
      // baked in the matrix would be 29x29 and (0, 0) would be light.
      expect(code!.version, 1);
      expect(code.size, 21);
      expect(code.isDark(0, 0), isTrue);
      expect(code.isDark(6, 6), isTrue);
      expect(code.isDark(7, 7), isFalse); // Separator, still inside the matrix.
    });
  });

  group('LoopQrCode known answers', () {
    // The expectations below were produced independently of this encoder, by
    // reading the codeword stream and the module matrix back out of symbols
    // built by a separate reference implementation, and the version-1 data
    // codewords additionally agree with a by-hand derivation:
    //
    //   mode 0100 | count 00000001 | 'A' 01000001 | terminator 0000
    //     -> 0x40 0x14 0x10, then the 0xEC / 0x11 pad codewords.
    //
    // The three matrices are payloads whose mask choice is unambiguous. Mask
    // selection is the one step ISO/IEC 18004 leaves room in: encoders differ
    // over whether the format and version modules are scored, and near-ties
    // then land on different masks. Every mask yields a valid, equally
    // scannable symbol, so a payload sitting on such a tie would assert a
    // convention rather than correctness.
    test('version 1 medium codewords match the derived stream', () {
      final codewords = LoopQrCode.debugCodewords(
        'A',
        LoopQrErrorCorrection.medium,
      );

      // Version 1-M: 16 data codewords + 10 error-correction codewords.
      expect(codewords, hasLength(26));
      expect(codewords.sublist(0, 5), <int>[
        0x40,
        0x14,
        0x10,
        0xEC,
        0x11,
      ], reason: 'mode + length + data + first pad codewords');
      expect(codewords, _codewordsVersion1Medium);
    });

    test('debugCodewords mirrors encode returning null', () {
      expect(
        LoopQrCode.debugCodewords('中', LoopQrErrorCorrection.medium),
        isEmpty,
      );
      expect(
        LoopQrCode.debugCodewords('a' * 4000, LoopQrErrorCorrection.medium),
        isEmpty,
      );
    });

    test('version 1 matrix matches the reference symbol', () {
      final code = LoopQrCode.encode('a');
      expect(code, isNotNull);
      expect(code!.version, 1);
      expect(_render(code), _matrixVersion1Medium);
    });

    test('version 4 receive-payload matrix matches the reference symbol', () {
      final code = LoopQrCode.encode(_eip681Payload);
      expect(code, isNotNull);
      expect(_render(code!), _matrixVersion4Medium);
    });

    test('version 7 matrix matches the reference symbol', () {
      // Versions 7 and above carry the two BCH(18,6) version-information
      // blocks; this is the only case here that exercises them.
      final code = LoopQrCode.encode(_version7Payload);
      expect(code, isNotNull);
      expect(code!.version, 7);
      expect(code.size, 45);
      expect(_render(code), _matrixVersion7Medium);
    });
  });
}

/// The exact receive-page payload: an EIP-681 address URI on BNB Smart Chain.
const String _eip681Payload =
    'ethereum:0x00000000000000000000000000000000000000a1@56';

/// A 110-byte payload, one byte past the version-6 medium capacity.
const String _version7Payload =
    'loop-receive:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// Renders a symbol as one string per row, '#' dark and '.' light.
List<String> _render(LoopQrCode code) {
  return <String>[
    for (var y = 0; y < code.size; y++)
      String.fromCharCodes(<int>[
        for (var x = 0; x < code.size; x++)
          code.isDark(x, y) ? 0x23 /* # */ : 0x2E /* . */,
      ]),
  ];
}

/// Asserts a full 7x7 finder pattern with its origin at ([left], [top]).
void _expectFinderPattern(LoopQrCode code, int left, int top) {
  const List<String> pattern = <String>[
    '#######',
    '#.....#',
    '#.###.#',
    '#.###.#',
    '#.###.#',
    '#.....#',
    '#######',
  ];
  for (var dy = 0; dy < 7; dy++) {
    for (var dx = 0; dx < 7; dx++) {
      expect(
        code.isDark(left + dx, top + dy),
        pattern[dy][dx] == '#',
        reason: 'finder at ($left, $top), offset ($dx, $dy)',
      );
    }
  }
}

/// Largest byte-mode payload each version holds, indexed by `version - 1`
/// then by [LoopQrErrorCorrection.index].
const List<List<int>> _maxByteCapacity = <List<int>>[
  <int>[17, 14, 11, 7],
  <int>[32, 26, 20, 14],
  <int>[53, 42, 32, 24],
  <int>[78, 62, 46, 34],
  <int>[106, 84, 60, 44],
  <int>[134, 106, 74, 58],
  <int>[154, 122, 86, 64],
  <int>[192, 152, 108, 84],
  <int>[230, 180, 130, 98],
  <int>[271, 213, 151, 119],
];

/// Total codewords (data plus error correction) per version, indexed by
/// `version - 1`. Identical for all four error-correction levels.
const List<int> _totalCodewords = <int>[
  26,
  44,
  70,
  100,
  134,
  172,
  196,
  242,
  292,
  346,
];

/// The full interleaved codeword stream of 'A' at medium correction.
const List<int> _codewordsVersion1Medium = <int>[
  0x40,
  0x14,
  0x10,
  0xEC,
  0x11,
  0xEC,
  0x11,
  0xEC,
  0x11,
  0xEC,
  0x11,
  0xEC,
  0x11,
  0xEC,
  0x11,
  0xEC,
  0x6B,
  0x70,
  0xF4,
  0x18,
  0xA3,
  0x7A,
  0x11,
  0x5F,
  0x34,
  0xFC,
];

/// Reference matrix for 'a' at medium correction (version 1, mask 5).
const List<String> _matrixVersion1Medium = <String>[
  '#######..#.##.#######',
  '#.....#.#.##..#.....#',
  '#.###.#.##.#..#.###.#',
  '#.###.#.#.##..#.###.#',
  '#.###.#..#..#.#.###.#',
  '#.....#...##..#.....#',
  '#######.#.#.#.#######',
  '........##...........',
  '#.....#.#.##.##..###.',
  '#..##......###.###..#',
  '..#.###..##.#.##.....',
  '.#.#.#.##..#####.#.#.',
  '##.#..####.##########',
  '........##..#.....#.#',
  '#######..###.#..####.',
  '#.....#...#...#...###',
  '#.###.#..###.#..###..',
  '#.###.#..#.#####.#...',
  '#.###.#..#.###.###.##',
  '#.....#...######.#...',
  '#######.#.#.#..#..##.',
];

/// Reference matrix for [_eip681Payload] at medium correction
/// (version 4, mask 0).
const List<String> _matrixVersion4Medium = <String>[
  '#######..#####.##..##..##.#######',
  '#.....#.###...##.###.#.#..#.....#',
  '#.###.#..##..##.#...#.#.#.#.###.#',
  '#.###.#....#.####..##..##.#.###.#',
  '#.###.#.#.#...#.#..##..##.#.###.#',
  '#.....#...##.#.###.#.#.#..#.....#',
  '#######.#.#.#.#.#.#.#.#.#.#######',
  '.........#####.#.#.#.#.#.........',
  '#.#.#.#..#..###..##..##.....#..#.',
  '.##......##.###..##..##..##.....#',
  '.###..##..#...#.##..#.#.#.###.#.#',
  '#.#.#..#...#.###.#.#.#.#.#.....#.',
  '####..##.#....#.#.#.###...##....#',
  '###.#..##.....####.####...##.#..#',
  '#.##.##.#.#...###.#...#.##..#.###',
  '###....####..#..##.#.#.#...#.#...',
  '...##.##..#.#..#.##..##...##.#.##',
  '#####..#.##.###...#..##...#..##.#',
  '##...##...####..##..#.#.#.###.#.#',
  '.##.#..###.#...#...#.#.#.#.....#.',
  '#...#####....#.......###..##....#',
  '....#..#....#..#.#...##...##.#.##',
  '#..##.##..#...#...#...#.#...#.###',
  '.#.##..#....##.#.#.#.#.#.###.#.##',
  '#.#..###.....##..##..##.######.##',
  '........#.#...#..##..##.#...#...#',
  '#######..##.#...#.#.#.###.#.###.#',
  '#.....#..#..##.#.###.#..#...#..#.',
  '#.###.#.###.....#.#.###.######..#',
  '#.###.#..#.########.####.#.###..#',
  '#.###.#.##...####.#.#.#.##.##.#.#',
  '#.....#...#..#..##.#.#..##.###.#.',
  '#######.###.#.##.##..##.#.#.##.##',
];

/// Reference matrix for [_version7Payload] at medium correction
/// (version 7, mask 1).
const List<String> _matrixVersion7Medium = <String>[
  '#######.#.#......#..####..#.#.#.##..#.#######',
  '#.....#...####..#..#.#.#..#...#..#.#..#.....#',
  '#.###.#.#..#..##..###.#.####.###.#.#..#.###.#',
  '#.###.#..###.#.#.#..#.#..#.#.#.#.#.##.#.###.#',
  '#.###.#...###.##.#..#######.#.#.#.###.#.###.#',
  '#.....#.##.#.######.#...##....#.......#.....#',
  '#######.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#######',
  '............#.##..###...#...#...##...........',
  '#.#...##....#.#.#..######.#.#.#.#.##...#..#.#',
  '##..#..###...#..#......#.#.#.#.#.#.#.#.#....#',
  '..##..#..##......##.#.####.###.###..#.....#.#',
  '..##...###....##.#...#.#........#.......##...',
  '###..##.##....#...#.##.##.#...#.#.##..#.##...',
  '##...#.##...##.##.#..##.##..##.#.#.#.#.#....#',
  '#...#.#....##.#..###.#..##...#.###..##.##.#.#',
  '##..#....#....#..#.#.###....#...#.......##.#.',
  '.#..######.....#..#.#####.#.#.#.#.##..#.##.##',
  '.#.....###..#.....#.....##.#.#..##.#.#.#....#',
  '#..#..###..####.####..#.##.###.#.#...#.##.#.#',
  '.##..#..##......##.#.#.#.##.#...#.......##.#.',
  '.#.#######..##.#..#.######..#.#.#.########.##',
  '#.#.#...##....#.#.#.#...####.#.#.#.##...###.#',
  '##..#.#.#...##..#####.#.######.###..#.#.#...#',
  '###.#...###.###..#..#...#...#...#.#.#...##.#.',
  '.#.######...#..#.########.#.#.#.#.#.######.##',
  '###......###..#.##.##.#..#.#.#.#.#...#.#....#',
  '##...####...##..####.###.#.###.##..##.#.#.#.#',
  '###..#.#.##.###..##..#.#........#..##.#..#..#',
  '.####.#.#.###..##..##.#.#.###.#.#.##.###.#...',
  '##.....##...#.##....#.#..#.#.#.#.#....#.....#',
  '#....###....#....##.######.###.###.##.###.#.#',
  '##...#.##.##..##..####.##...#..##..##.#..#.#.',
  '.##...#.#..##.##....#.##..#.#.###.##.###.#.##',
  '#.#..#.##.#.#..######.####.#.#.#.#...#.#....#',
  '....#.##....#...####.###.#.###..##.##.#.#.#.#',
  '.####..##.##.###..#..#.#....#...#..##.#..#.#.',
  '#..##.#....##.###..######.#.#.#.#.########.##',
  '........#.###..####.#...#..#.#.#.#.##...###.#',
  '#######.#.#..#.####.#.#.#.####.###.##.#.#...#',
  '#.....#...#....#...##...#...#...##.##...##.#.',
  '#.###.#..#..##.##.#######.#.#.#.##.######..##',
  '#.###.#..#.###.#####...#.#.#.#.#.#..#...#...#',
  '#.###.#.##.#.#.##..##.####.###.###..#.#.#.#.#',
  '#.....#..###...#....#...#...#...#..#.#.#.#...',
  '#######.#.#.##..##..#.#.#.#.#.#.#.####.###..#',
];
