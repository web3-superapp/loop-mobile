/// A dependency-free QR Code (ISO/IEC 18004 model 2) encoder.
///
/// WHY this exists instead of a package: the receive page needs to render a
/// wallet address (an EIP-681 `ethereum:<address>@<chainId>` string) as a QR
/// symbol, and the repository's dependency policy keeps every direct pin exact
/// and requires official-source research plus both native builds before a new
/// pin is added. A QR renderer is a pure, fully specified, offline
/// transformation of a short ASCII string into a boolean matrix; it carries no
/// platform channel, no network access and no asset. Paying the pin-change
/// cost — and taking on a transitive graph and its upgrade cadence — for ~600
/// lines of table-driven arithmetic was judged the worse trade, so the encoder
/// lives here as first-party source. It is written from the specification and
/// borrows no third-party code, so it adds nothing to the open-source
/// attribution register.
///
/// Scope is deliberately narrow, which is what keeps the implementation small
/// and reviewable:
///
/// * byte mode (`0100`) only, ISO-8859-1 (Latin-1) — every LOOP payload that
///   reaches a QR symbol is an address, a URI or an invite token, all ASCII;
/// * versions 1 through 10 (21x21 up to 57x57 modules), auto-selected as the
///   smallest version that fits at the requested error-correction level;
/// * all four error-correction levels, all eight data masks, and the standard
///   penalty-based mask selection.
///
/// Anything outside that scope returns `null` from [LoopQrCode.encode] instead
/// of degrading silently — a symbol LOOP cannot encode correctly must not be
/// painted at all, because an unreadable or wrong QR code for a funding
/// address is a fund-loss surface.
///
/// The encoder is strictly deterministic: no randomness, no clock, no I/O, no
/// `dart:ui`. The same input always yields the same matrix, which is what lets
/// widget tests assert on module values and lets a `CustomPainter` cache by
/// payload.
///
/// The result is a bare module matrix. The mandatory 4-module quiet zone is
/// *not* part of [LoopQrCode.size]; the painter is responsible for the margin,
/// because padding is a layout concern and baking it in would make the matrix
/// coordinates disagree with the specification.
library;

import 'package:flutter/foundation.dart';

/// Error-correction level, in increasing order of redundancy.
///
/// Higher levels survive more damage but consume data capacity, so the same
/// payload may need a larger version. [medium] is the default: it recovers
/// ~15% of the symbol, which is the usual choice for a screen-displayed code
/// scanned at close range.
enum LoopQrErrorCorrection {
  /// ~7% recovery capacity. Format indicator bits `01`.
  low,

  /// ~15% recovery capacity. Format indicator bits `00`.
  medium,

  /// ~25% recovery capacity. Format indicator bits `11`.
  quartile,

  /// ~30% recovery capacity. Format indicator bits `10`.
  high,
}

/// An encoded QR symbol: an immutable square matrix of dark/light modules.
///
/// Obtain one through [encode]; the constructor is private because a matrix
/// that did not come out of the encoder is not a valid symbol.
@immutable
final class LoopQrCode {
  const LoopQrCode._(
    this._modules, {
    required this.size,
    required this.version,
    required this.errorCorrection,
  });

  /// Modules per side, `version * 4 + 17`. Excludes the quiet zone.
  final int size;

  /// Symbol version, 1 through 10.
  final int version;

  /// The level the symbol was encoded at.
  final LoopQrErrorCorrection errorCorrection;

  /// Row-major `size * size` matrix, one byte per module, 0 light / 1 dark.
  ///
  /// Never handed out: [LoopQrCode] is immutable and a `Uint8List` is not.
  final Uint8List _modules;

  /// Whether the module at column [x], row [y] is dark.
  ///
  /// The origin is the top-left corner of the symbol, matching the coordinate
  /// system a `CustomPainter` uses. Throws [RangeError] outside `[0, size)`;
  /// silently treating an out-of-range read as light would let a painter draw
  /// a subtly truncated symbol without ever failing a test.
  bool isDark(int x, int y) {
    if (x < 0 || x >= size) {
      throw RangeError.range(x, 0, size - 1, 'x');
    }
    if (y < 0 || y >= size) {
      throw RangeError.range(y, 0, size - 1, 'y');
    }
    return _modules[y * size + x] != 0;
  }

  /// Encodes [data] in byte mode, or returns `null` when it cannot be encoded.
  ///
  /// Returns `null` when [data] contains a code unit above `0xFF` (byte mode
  /// here is ISO-8859-1, so it cannot carry CJK or emoji) or when the byte
  /// length exceeds the capacity of version 10 at [errorCorrection].
  static LoopQrCode? encode(
    String data, {
    LoopQrErrorCorrection errorCorrection = LoopQrErrorCorrection.medium,
  }) {
    final Uint8List? bytes = _latin1Bytes(data);
    if (bytes == null) {
      return null;
    }
    final int? version = _smallestVersion(bytes.length, errorCorrection);
    if (version == null) {
      return null;
    }
    final Uint8List codewords = _codewords(bytes, version, errorCorrection);
    final Uint8List modules = _buildMatrix(codewords, version, errorCorrection);
    return LoopQrCode._(
      modules,
      size: version * 4 + 17,
      version: version,
      errorCorrection: errorCorrection,
    );
  }

  /// The final interleaved codeword stream (data blocks, then EC blocks).
  ///
  /// Exposed so tests can assert a known answer at the codeword layer — the
  /// stage where the specification gives exact byte values — instead of only
  /// checking structural invariants of the painted matrix. Returns an empty
  /// list when [data] cannot be encoded, mirroring [encode] returning `null`.
  @visibleForTesting
  static List<int> debugCodewords(
    String data,
    LoopQrErrorCorrection errorCorrection,
  ) {
    final Uint8List? bytes = _latin1Bytes(data);
    if (bytes == null) {
      return <int>[];
    }
    final int? version = _smallestVersion(bytes.length, errorCorrection);
    if (version == null) {
      return <int>[];
    }
    return List<int>.unmodifiable(_codewords(bytes, version, errorCorrection));
  }

  // ---------------------------------------------------------------------
  // Stage 1 — data analysis and encoding.
  // ---------------------------------------------------------------------

  /// Latin-1 bytes of [value], or `null` if any code unit does not fit a byte.
  static Uint8List? _latin1Bytes(String value) {
    final Uint8List bytes = Uint8List(value.length);
    for (int i = 0; i < value.length; i++) {
      final int unit = value.codeUnitAt(i);
      if (unit > 0xFF) {
        return null;
      }
      bytes[i] = unit;
    }
    return bytes;
  }

  /// Smallest version 1..10 whose data capacity holds [byteCount], or `null`.
  static int? _smallestVersion(
    int byteCount,
    LoopQrErrorCorrection errorCorrection,
  ) {
    for (int version = 1; version <= _maxVersion; version++) {
      final _BlockPlan plan = _BlockPlan.forSymbol(version, errorCorrection);
      final int bitsNeeded = 4 + _characterCountBits(version) + byteCount * 8;
      if (bitsNeeded <= plan.dataCodewords * 8) {
        return version;
      }
    }
    return null;
  }

  /// Byte-mode character-count indicator width: 8 bits for v1-9, 16 for v10+.
  static int _characterCountBits(int version) => version <= 9 ? 8 : 16;

  /// Builds the full interleaved codeword stream for [bytes].
  static Uint8List _codewords(
    Uint8List bytes,
    int version,
    LoopQrErrorCorrection errorCorrection,
  ) {
    final _BlockPlan plan = _BlockPlan.forSymbol(version, errorCorrection);
    final int capacityBits = plan.dataCodewords * 8;

    final _BitBuffer buffer = _BitBuffer();
    buffer.put(0x4, 4); // Byte mode indicator.
    buffer.put(bytes.length, _characterCountBits(version));
    for (final int byte in bytes) {
      buffer.put(byte, 8);
    }

    // Terminator: up to four zero bits, truncated against the capacity.
    final int terminator = capacityBits - buffer.length;
    buffer.put(0, terminator < 4 ? terminator : 4);

    // Pad the last codeword out to a byte boundary with zero bits.
    if (buffer.length % 8 != 0) {
      buffer.put(0, 8 - (buffer.length % 8));
    }

    // Fill the remaining capacity with the alternating pad codewords.
    final Uint8List dataCodewords = Uint8List(plan.dataCodewords);
    final Uint8List encoded = buffer.toBytes();
    dataCodewords.setRange(0, encoded.length, encoded);
    bool useEc = true;
    for (int i = encoded.length; i < plan.dataCodewords; i++) {
      dataCodewords[i] = useEc ? 0xEC : 0x11;
      useEc = !useEc;
    }

    return _interleave(dataCodewords, plan);
  }

  /// Splits the data codewords into blocks, appends Reed-Solomon parity to
  /// each and interleaves the result as the specification prescribes.
  static Uint8List _interleave(Uint8List dataCodewords, _BlockPlan plan) {
    final List<Uint8List> dataBlocks = <Uint8List>[];
    final List<Uint8List> ecBlocks = <Uint8List>[];
    int offset = 0;
    for (int group = 0; group < 2; group++) {
      final int blockCount = group == 0 ? plan.group1Blocks : plan.group2Blocks;
      final int blockSize = group == 0
          ? plan.group1DataCodewords
          : plan.group2DataCodewords;
      for (int block = 0; block < blockCount; block++) {
        final Uint8List data = Uint8List.sublistView(
          dataCodewords,
          offset,
          offset + blockSize,
        );
        offset += blockSize;
        dataBlocks.add(data);
        ecBlocks.add(_reedSolomon(data, plan.ecCodewordsPerBlock));
      }
    }

    final int longestBlock = plan.group2Blocks > 0
        ? plan.group2DataCodewords
        : plan.group1DataCodewords;
    final Uint8List result = Uint8List(plan.totalCodewords);
    int index = 0;
    for (int i = 0; i < longestBlock; i++) {
      for (final Uint8List block in dataBlocks) {
        if (i < block.length) {
          result[index++] = block[i];
        }
      }
    }
    for (int i = 0; i < plan.ecCodewordsPerBlock; i++) {
      for (final Uint8List block in ecBlocks) {
        result[index++] = block[i];
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------
  // Stage 2 — error correction coding.
  // ---------------------------------------------------------------------

  /// Reed-Solomon parity of [data] over GF(256), [ecCount] codewords long.
  ///
  /// Plain polynomial long division of `data * x^ecCount` by the QR generator
  /// polynomial; the remainder is the parity.
  static Uint8List _reedSolomon(Uint8List data, int ecCount) {
    final Uint8List generator = _gf.generatorPolynomial(ecCount);
    final Uint8List remainder = Uint8List(data.length + ecCount);
    remainder.setRange(0, data.length, data);
    for (int i = 0; i < data.length; i++) {
      final int lead = remainder[i];
      if (lead == 0) {
        continue;
      }
      for (int j = 0; j < generator.length; j++) {
        remainder[i + j] ^= _gf.multiply(generator[j], lead);
      }
    }
    return Uint8List.sublistView(remainder, data.length);
  }

  // ---------------------------------------------------------------------
  // Stage 3 — module placement, masking and format/version information.
  // ---------------------------------------------------------------------

  /// Draws every function pattern, places the codewords, then picks the mask
  /// with the lowest penalty score and returns that candidate's modules.
  ///
  /// Each candidate is scored as a *finished* symbol: the mask is applied and
  /// the format (and, from version 7, version) information is written before
  /// the penalty rules run, because those rules are defined over the whole
  /// symbol. Encoders differ here — some score the symbol while the
  /// information areas are still blank — and on a near-tie the two
  /// conventions pick different masks. Either symbol decodes identically; what
  /// matters for LOOP is that the choice is fixed, so ties break toward the
  /// lower mask number.
  static Uint8List _buildMatrix(
    Uint8List codewords,
    int version,
    LoopQrErrorCorrection errorCorrection,
  ) {
    final int size = version * 4 + 17;
    final Uint8List base = Uint8List(size * size);
    // 1 marks a module owned by a function pattern or reserved for the
    // format/version information; data must not be written there and the mask
    // must not be applied to it.
    final Uint8List reserved = Uint8List(size * size);

    _drawFinderPatterns(base, reserved, size);
    _drawTimingPatterns(base, reserved, size);
    _drawAlignmentPatterns(base, reserved, size, version);
    _reserveInformationAreas(reserved, size, version);
    // The dark module is a fixed function module, not part of the format bits.
    base[(size - 8) * size + 8] = 1;
    reserved[(size - 8) * size + 8] = 1;

    _placeCodewords(base, reserved, size, codewords);

    Uint8List? best;
    int bestPenalty = 0;
    for (int mask = 0; mask < 8; mask++) {
      final Uint8List candidate = Uint8List.fromList(base);
      _applyMask(candidate, reserved, size, mask);
      _drawFormatInformation(candidate, size, errorCorrection, mask);
      if (version >= 7) {
        _drawVersionInformation(candidate, size, version);
      }
      final int penalty = _penalty(candidate, size);
      if (best == null || penalty < bestPenalty) {
        best = candidate;
        bestPenalty = penalty;
      }
    }
    return best!;
  }

  /// The three 7x7 finder patterns plus their one-module separators.
  static void _drawFinderPatterns(
    Uint8List modules,
    Uint8List reserved,
    int size,
  ) {
    const List<List<int>> origins = <List<int>>[
      <int>[0, 0],
      <int>[1, 0],
      <int>[0, 1],
    ];
    for (final List<int> origin in origins) {
      final int left = origin[0] == 0 ? 0 : size - 7;
      final int top = origin[1] == 0 ? 0 : size - 7;
      // Sweep one module beyond the pattern on every side: that band is the
      // separator, which is light and equally off-limits to data.
      for (int dy = -1; dy <= 7; dy++) {
        for (int dx = -1; dx <= 7; dx++) {
          final int x = left + dx;
          final int y = top + dy;
          if (x < 0 || x >= size || y < 0 || y >= size) {
            continue;
          }
          final bool outerRing =
              (dx >= 0 && dx <= 6 && (dy == 0 || dy == 6)) ||
              (dy >= 0 && dy <= 6 && (dx == 0 || dx == 6));
          final bool core = dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4;
          modules[y * size + x] = (outerRing || core) ? 1 : 0;
          reserved[y * size + x] = 1;
        }
      }
    }
  }

  /// Row 6 and column 6, alternating dark/light between the finder patterns.
  static void _drawTimingPatterns(
    Uint8List modules,
    Uint8List reserved,
    int size,
  ) {
    for (int i = 8; i < size - 8; i++) {
      final int value = i.isEven ? 1 : 0;
      modules[6 * size + i] = value;
      reserved[6 * size + i] = 1;
      modules[i * size + 6] = value;
      reserved[i * size + 6] = 1;
    }
  }

  /// The 5x5 alignment patterns at every centre pair for this version, minus
  /// the three that would collide with a finder pattern.
  static void _drawAlignmentPatterns(
    Uint8List modules,
    Uint8List reserved,
    int size,
    int version,
  ) {
    final List<int> centres = _alignmentCentres[version - 1];
    for (final int centreY in centres) {
      for (final int centreX in centres) {
        final bool collidesWithFinder =
            (centreX == 6 && centreY == 6) ||
            (centreX == 6 && centreY == size - 7) ||
            (centreX == size - 7 && centreY == 6);
        if (collidesWithFinder) {
          continue;
        }
        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
            final int x = centreX + dx;
            final int y = centreY + dy;
            final bool dark =
                dx.abs() == 2 || dy.abs() == 2 || (dx == 0 && dy == 0);
            modules[y * size + x] = dark ? 1 : 0;
            reserved[y * size + x] = 1;
          }
        }
      }
    }
  }

  /// Marks the format-information strips (and, from version 7, the two
  /// version-information blocks) as unavailable to the data placement pass.
  static void _reserveInformationAreas(
    Uint8List reserved,
    int size,
    int version,
  ) {
    for (int i = 0; i < 9; i++) {
      reserved[8 * size + i] = 1;
      reserved[i * size + 8] = 1;
    }
    for (int i = 0; i < 8; i++) {
      reserved[8 * size + (size - 1 - i)] = 1;
      reserved[(size - 1 - i) * size + 8] = 1;
    }
    if (version < 7) {
      return;
    }
    for (int i = 0; i < 18; i++) {
      final int a = i ~/ 3;
      final int b = size - 11 + (i % 3);
      reserved[a * size + b] = 1;
      reserved[b * size + a] = 1;
    }
  }

  /// Writes the codeword bits along the standard two-module-wide zigzag,
  /// starting at the bottom-right corner and skipping column 6.
  ///
  /// Free modules beyond the codeword stream are the version's remainder bits
  /// and stay light, which the `bitIndex` bound below produces implicitly.
  static void _placeCodewords(
    Uint8List modules,
    Uint8List reserved,
    int size,
    Uint8List codewords,
  ) {
    final int totalBits = codewords.length * 8;
    int bitIndex = 0;
    int direction = -1; // -1 = upward, +1 = downward.
    int row = size - 1;
    for (int column = size - 1; column > 0; column -= 2) {
      // Column 6 is the vertical timing pattern; the pairing shifts left.
      if (column == 6) {
        column = 5;
      }
      while (true) {
        for (int offset = 0; offset < 2; offset++) {
          final int x = column - offset;
          if (reserved[row * size + x] != 0) {
            continue;
          }
          int bit = 0;
          if (bitIndex < totalBits) {
            bit = (codewords[bitIndex >> 3] >> (7 - (bitIndex & 7))) & 1;
          }
          modules[row * size + x] = bit;
          bitIndex++;
        }
        row += direction;
        if (row < 0 || row >= size) {
          row -= direction;
          direction = -direction;
          break;
        }
      }
    }
  }

  /// Inverts every non-function module for which the [mask] condition holds.
  static void _applyMask(
    Uint8List modules,
    Uint8List reserved,
    int size,
    int mask,
  ) {
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final int index = y * size + x;
        if (reserved[index] != 0) {
          continue;
        }
        if (_maskCondition(mask, y, x)) {
          modules[index] ^= 1;
        }
      }
    }
  }

  /// The eight standard data-mask conditions, on row [y] and column [x].
  static bool _maskCondition(int mask, int y, int x) {
    switch (mask) {
      case 0:
        return (y + x).isEven;
      case 1:
        return y.isEven;
      case 2:
        return x % 3 == 0;
      case 3:
        return (y + x) % 3 == 0;
      case 4:
        return ((y ~/ 2) + (x ~/ 3)).isEven;
      case 5:
        return (y * x) % 2 + (y * x) % 3 == 0;
      case 6:
        return ((y * x) % 2 + (y * x) % 3).isEven;
      case 7:
        return ((y + x) % 2 + (y * x) % 3).isEven;
      default:
        throw ArgumentError.value(mask, 'mask', 'must be 0..7');
    }
  }

  /// Writes both copies of the 15-bit format information.
  static void _drawFormatInformation(
    Uint8List modules,
    int size,
    LoopQrErrorCorrection errorCorrection,
    int mask,
  ) {
    final int bits = _formatBits(
      (_formatIndicator[errorCorrection.index] << 3) | mask,
    );
    for (int i = 0; i < 15; i++) {
      final int bit = (bits >> i) & 1;
      // Copy 1: the column beside the top-left finder, running downwards.
      final int y = i < 6
          ? i
          : i < 8
          ? i + 1
          : size - 15 + i;
      modules[y * size + 8] = bit;
      // Copy 2: the row under the top-left finder and beside the top-right.
      final int x = i < 8
          ? size - 1 - i
          : i == 8
          ? 7
          : 14 - i;
      modules[8 * size + x] = bit;
    }
  }

  /// Writes both copies of the 18-bit version information (versions 7+).
  static void _drawVersionInformation(
    Uint8List modules,
    int size,
    int version,
  ) {
    final int bits = _versionBits(version);
    for (int i = 0; i < 18; i++) {
      final int bit = (bits >> i) & 1;
      final int a = i ~/ 3;
      final int b = size - 11 + (i % 3);
      modules[a * size + b] = bit; // Above the top-right finder.
      modules[b * size + a] = bit; // Left of the bottom-left finder.
    }
  }

  /// Appends the BCH(15,5) check bits to [data] and applies the 0x5412 mask.
  static int _formatBits(int data) {
    int remainder = data << 10;
    while (_bitLength(remainder) >= _bitLength(_formatGenerator)) {
      remainder ^=
          _formatGenerator <<
          (_bitLength(remainder) - _bitLength(_formatGenerator));
    }
    return ((data << 10) | remainder) ^ _formatMask;
  }

  /// Appends the BCH(18,6) check bits to the version number.
  static int _versionBits(int version) {
    int remainder = version << 12;
    while (_bitLength(remainder) >= _bitLength(_versionGenerator)) {
      remainder ^=
          _versionGenerator <<
          (_bitLength(remainder) - _bitLength(_versionGenerator));
    }
    return (version << 12) | remainder;
  }

  /// Position of the most significant set bit of [value], one-based.
  static int _bitLength(int value) {
    int length = 0;
    int rest = value;
    while (rest != 0) {
      length++;
      rest >>= 1;
    }
    return length;
  }

  // ---------------------------------------------------------------------
  // Stage 4 — mask evaluation.
  // ---------------------------------------------------------------------

  /// Total penalty score of a masked candidate under the four standard rules.
  /// Lower is better; the encoder keeps the first minimum, which makes the
  /// choice deterministic when two masks tie.
  static int _penalty(Uint8List modules, int size) =>
      _penaltyAdjacent(modules, size) +
      _penaltyBlocks(modules, size) +
      _penaltyFinderLike(modules, size) +
      _penaltyBalance(modules, size);

  /// Rule 1: runs of five or more same-coloured modules in a row or column.
  static int _penaltyAdjacent(Uint8List modules, int size) {
    int penalty = 0;
    for (int line = 0; line < size; line++) {
      for (int horizontal = 0; horizontal < 2; horizontal++) {
        int runValue = -1;
        int runLength = 0;
        for (int i = 0; i < size; i++) {
          final int value = horizontal == 0
              ? modules[line * size + i]
              : modules[i * size + line];
          if (value == runValue) {
            runLength++;
          } else {
            if (runLength >= 5) {
              penalty += runLength - 2;
            }
            runValue = value;
            runLength = 1;
          }
        }
        if (runLength >= 5) {
          penalty += runLength - 2;
        }
      }
    }
    return penalty;
  }

  /// Rule 2: every 2x2 block of a single colour.
  static int _penaltyBlocks(Uint8List modules, int size) {
    int penalty = 0;
    for (int y = 0; y < size - 1; y++) {
      for (int x = 0; x < size - 1; x++) {
        final int value = modules[y * size + x];
        if (modules[y * size + x + 1] == value &&
            modules[(y + 1) * size + x] == value &&
            modules[(y + 1) * size + x + 1] == value) {
          penalty += 3;
        }
      }
    }
    return penalty;
  }

  /// Rule 3: the 1:1:3:1:1 finder-like sequence next to four light modules.
  static int _penaltyFinderLike(Uint8List modules, int size) {
    const List<int> forward = <int>[1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0];
    const List<int> backward = <int>[0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1];
    int penalty = 0;
    for (int line = 0; line < size; line++) {
      for (int start = 0; start + 11 <= size; start++) {
        bool matchesForward = true;
        bool matchesBackward = true;
        bool matchesForwardVertical = true;
        bool matchesBackwardVertical = true;
        for (int i = 0; i < 11; i++) {
          final int horizontal = modules[line * size + start + i];
          final int vertical = modules[(start + i) * size + line];
          if (horizontal != forward[i]) {
            matchesForward = false;
          }
          if (horizontal != backward[i]) {
            matchesBackward = false;
          }
          if (vertical != forward[i]) {
            matchesForwardVertical = false;
          }
          if (vertical != backward[i]) {
            matchesBackwardVertical = false;
          }
        }
        if (matchesForward) {
          penalty += 40;
        }
        if (matchesBackward) {
          penalty += 40;
        }
        if (matchesForwardVertical) {
          penalty += 40;
        }
        if (matchesBackwardVertical) {
          penalty += 40;
        }
      }
    }
    return penalty;
  }

  /// Rule 4: deviation of the dark-module proportion from 50%.
  ///
  /// `|dark/total * 100 - 50| / 5` is evaluated as `|dark * 20 - total * 10| /
  /// total` so the score stays in integer arithmetic.
  static int _penaltyBalance(Uint8List modules, int size) {
    final int total = size * size;
    int dark = 0;
    for (int i = 0; i < total; i++) {
      dark += modules[i];
    }
    return ((dark * 20 - total * 10).abs() ~/ total) * 10;
  }
}

/// Highest version this encoder supports.
const int _maxVersion = 10;

/// BCH(15,5) generator for the format information: `10100110111`.
const int _formatGenerator = 0x537;

/// Constant XOR mask applied to the format information: `101010000010010`.
const int _formatMask = 0x5412;

/// BCH(18,6) generator for the version information: `1111100100101`.
const int _versionGenerator = 0x1F25;

/// Two-bit format indicator per [LoopQrErrorCorrection], in enum order.
const List<int> _formatIndicator = <int>[0x1, 0x0, 0x3, 0x2];

/// Alignment-pattern centre coordinates, indexed by `version - 1`.
///
/// A pattern is drawn at every pair drawn from the version's row, except the
/// three pairs that would sit on a finder pattern.
const List<List<int>> _alignmentCentres = <List<int>>[
  <int>[], // v1 has no alignment pattern.
  <int>[6, 18],
  <int>[6, 22],
  <int>[6, 26],
  <int>[6, 30],
  <int>[6, 34],
  <int>[6, 22, 38],
  <int>[6, 24, 42],
  <int>[6, 26, 46],
  <int>[6, 28, 50],
];

/// Error-correction block structure, indexed by `version - 1` then by
/// [LoopQrErrorCorrection.index].
///
/// Each row is `[ecCodewordsPerBlock, group1Blocks, group1DataCodewords,
/// group2Blocks, group2DataCodewords]`. Group 2 blocks, when present, always
/// hold exactly one data codeword more than group 1 blocks.
const List<List<List<int>>> _blockStructure = <List<List<int>>>[
  <List<int>>[
    <int>[7, 1, 19, 0, 0],
    <int>[10, 1, 16, 0, 0],
    <int>[13, 1, 13, 0, 0],
    <int>[17, 1, 9, 0, 0],
  ],
  <List<int>>[
    <int>[10, 1, 34, 0, 0],
    <int>[16, 1, 28, 0, 0],
    <int>[22, 1, 22, 0, 0],
    <int>[28, 1, 16, 0, 0],
  ],
  <List<int>>[
    <int>[15, 1, 55, 0, 0],
    <int>[26, 1, 44, 0, 0],
    <int>[18, 2, 17, 0, 0],
    <int>[22, 2, 13, 0, 0],
  ],
  <List<int>>[
    <int>[20, 1, 80, 0, 0],
    <int>[18, 2, 32, 0, 0],
    <int>[26, 2, 24, 0, 0],
    <int>[16, 4, 9, 0, 0],
  ],
  <List<int>>[
    <int>[26, 1, 108, 0, 0],
    <int>[24, 2, 43, 0, 0],
    <int>[18, 2, 15, 2, 16],
    <int>[22, 2, 11, 2, 12],
  ],
  <List<int>>[
    <int>[18, 2, 68, 0, 0],
    <int>[16, 4, 27, 0, 0],
    <int>[24, 4, 19, 0, 0],
    <int>[28, 4, 15, 0, 0],
  ],
  <List<int>>[
    <int>[20, 2, 78, 0, 0],
    <int>[18, 4, 31, 0, 0],
    <int>[18, 2, 14, 4, 15],
    <int>[26, 4, 13, 1, 14],
  ],
  <List<int>>[
    <int>[24, 2, 97, 0, 0],
    <int>[22, 2, 38, 2, 39],
    <int>[22, 4, 18, 2, 19],
    <int>[26, 4, 14, 2, 15],
  ],
  <List<int>>[
    <int>[30, 2, 116, 0, 0],
    <int>[22, 3, 36, 2, 37],
    <int>[20, 4, 16, 4, 17],
    <int>[24, 4, 12, 4, 13],
  ],
  <List<int>>[
    <int>[18, 2, 68, 2, 69],
    <int>[26, 4, 43, 1, 44],
    <int>[24, 6, 19, 2, 20],
    <int>[28, 6, 15, 2, 16],
  ],
];

/// The block layout of one (version, error-correction level) pair.
@immutable
final class _BlockPlan {
  const _BlockPlan({
    required this.ecCodewordsPerBlock,
    required this.group1Blocks,
    required this.group1DataCodewords,
    required this.group2Blocks,
    required this.group2DataCodewords,
  });

  factory _BlockPlan.forSymbol(
    int version,
    LoopQrErrorCorrection errorCorrection,
  ) {
    final List<int> row = _blockStructure[version - 1][errorCorrection.index];
    return _BlockPlan(
      ecCodewordsPerBlock: row[0],
      group1Blocks: row[1],
      group1DataCodewords: row[2],
      group2Blocks: row[3],
      group2DataCodewords: row[4],
    );
  }

  final int ecCodewordsPerBlock;
  final int group1Blocks;
  final int group1DataCodewords;
  final int group2Blocks;
  final int group2DataCodewords;

  int get blocks => group1Blocks + group2Blocks;

  int get dataCodewords =>
      group1Blocks * group1DataCodewords + group2Blocks * group2DataCodewords;

  int get totalCodewords => dataCodewords + blocks * ecCodewordsPerBlock;
}

/// A big-endian bit accumulator, the natural shape of a QR bit stream.
final class _BitBuffer {
  final List<int> _bytes = <int>[];
  int _length = 0;

  int get length => _length;

  /// Appends the low [bitCount] bits of [value], most significant bit first.
  void put(int value, int bitCount) {
    for (int i = bitCount - 1; i >= 0; i--) {
      if (_length % 8 == 0) {
        _bytes.add(0);
      }
      if ((value >> i) & 1 != 0) {
        _bytes[_length ~/ 8] |= 0x80 >> (_length % 8);
      }
      _length++;
    }
  }

  Uint8List toBytes() => Uint8List.fromList(_bytes);
}

/// GF(256) arithmetic with the QR primitive polynomial `x^8 + x^4 + x^3 + x^2
/// + 1` (0x11D) and generator element 2.
///
/// Built once, lazily, on first use; the tables are pure functions of the
/// constants above, so the object carries no state that could vary.
final _GaloisField _gf = _GaloisField();

final class _GaloisField {
  _GaloisField() {
    int value = 1;
    for (int i = 0; i < 255; i++) {
      _exp[i] = value;
      _log[value] = i;
      value <<= 1;
      if (value >= 0x100) {
        value ^= 0x11D;
      }
    }
    // Duplicate the cycle so an exponent sum below 510 needs no modulo.
    for (int i = 255; i < 512; i++) {
      _exp[i] = _exp[i - 255];
    }
  }

  final Uint8List _exp = Uint8List(512);
  final Uint8List _log = Uint8List(256);

  int multiply(int a, int b) =>
      (a == 0 || b == 0) ? 0 : _exp[_log[a] + _log[b]];

  /// The generator polynomial of degree [degree], `degree + 1` coefficients
  /// long, highest term first. The leading coefficient is always 1, which is
  /// what makes the division step in [LoopQrCode._reedSolomon] clear the
  /// current leading term.
  Uint8List generatorPolynomial(int degree) {
    Uint8List polynomial = Uint8List.fromList(<int>[1]);
    for (int i = 0; i < degree; i++) {
      // Multiply by (x - a^i), which over GF(2) is (x + a^i).
      final Uint8List next = Uint8List(polynomial.length + 1);
      for (int j = 0; j < polynomial.length; j++) {
        next[j] ^= polynomial[j];
        next[j + 1] ^= multiply(polynomial[j], _exp[i]);
      }
      polynomial = next;
    }
    return polynomial;
  }
}
