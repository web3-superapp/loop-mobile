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
