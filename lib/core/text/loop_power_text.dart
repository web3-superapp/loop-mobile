/// Decision 0252: a mining power (and the holding it weighs) prints as a
/// whole number with thousands separators — `947955.604749012530067131`
/// reads `947,955`. The fraction is floored away, never rounded up, so the
/// figure on screen is never more than the server counted.
///
/// String and [BigInt] arithmetic only: raw values run past 2^53 and must not
/// lose a digit to a `double`. A string that is not a plain decimal number
/// prints as it arrived.
String loopPowerFigure(String raw) {
  final whole = loopPowerWhole(raw);
  return whole == null ? raw : loopPowerFigureOf(whole);
}

/// [loopPowerFigure] for a value already whole.
String loopPowerFigureOf(BigInt value) {
  final negative = value.isNegative;
  final digits = (negative ? -value : value).toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
    grouped.write(digits[index]);
  }
  return negative ? '-$grouped' : '$grouped';
}

/// The whole part of a power, floored, for arithmetic on what the screen
/// shows (the gap to the place above). `null` when [raw] is not a number.
BigInt? loopPowerWhole(String raw) {
  final match = _plainDecimal.firstMatch(raw.trim());
  if (match == null) return null;
  final negative = match.group(1) == '-';
  var whole = BigInt.parse(match.group(2)!);
  // Floor: a negative value with any fraction moves one further from zero.
  if (negative && (match.group(3) ?? '').contains(RegExp('[1-9]'))) {
    whole += BigInt.one;
  }
  return negative ? -whole : whole;
}

final RegExp _plainDecimal = RegExp(r'^([+-]?)([0-9]+)(?:\.([0-9]*))?$');

/// Decision 0252: a token quantity (a holding) keeps its fraction — a
/// balance of 0.5 ETH is not 0. Separators on the whole part, at most six
/// fraction digits (truncated, never rounded), trailing zeros trimmed.
/// String arithmetic only; anything that is not a plain decimal prints as it
/// arrived.
String loopAmountFigure(String raw) {
  final match = _plainDecimal.firstMatch(raw.trim());
  if (match == null) return raw;
  final whole = BigInt.parse(match.group(2)!);
  var fraction = match.group(3) ?? '';
  if (fraction.length > 6) fraction = fraction.substring(0, 6);
  fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  final zero = whole == BigInt.zero && fraction.isEmpty;
  final sign = match.group(1) == '-' && !zero ? '-' : '';
  final body = loopPowerFigureOf(whole);
  return fraction.isEmpty ? '$sign$body' : '$sign$body.$fraction';
}
