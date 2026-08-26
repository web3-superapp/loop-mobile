import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

/// Exact local projection of the one published transfer amount lexical rule.
///
/// Passing this check does not prove balance, asset precision, minimums, fees,
/// recipient validity, network support, or backend canonicalization. [wire]
/// preserves the user's exact accepted String, including trailing zeros.
@immutable
final class TransferAmount {
  const TransferAmount._({required this.wire});

  static const int maxWireLength = 128;
  static final RegExp _wirePattern = RegExp(
    r'^(?:[1-9][0-9]*(?:\.[0-9]+)?|0\.[0-9]*[1-9][0-9]*)$',
  );

  final String wire;

  static TransferAmount? tryParse(String source) {
    if (source.isEmpty || source.length > maxWireLength) return null;
    final match = _wirePattern.firstMatch(source);
    if (match == null || match.start != 0 || match.end != source.length) {
      return null;
    }

    final value = Decimal.tryParse(source);
    if (value == null || value <= Decimal.zero) return null;
    return TransferAmount._(wire: source);
  }

  String displayWithAsset(String asset) => '$wire $asset';
}
