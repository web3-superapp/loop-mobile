/// Shared scalar validation for human-readable values sent to the LOOP API.
///
/// The backend rejects the Unicode general categories Cc, Cf, Cs, Zl and Zp.
/// Dart's Unicode-mode property escapes apply the locked SDK's category table
/// consistently on every Flutter platform and include malformed lone
/// surrogates through Cs, without a locale or platform-ICU dependency.
final RegExp _loopForbiddenHumanTextPattern = RegExp(
  r'[\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}]',
  unicode: true,
);

bool containsLoopForbiddenHumanTextCodePoint(String value) =>
    _loopForbiddenHumanTextPattern.hasMatch(value);

/// Counts a trimmed search value after the backend's ASCII-space folding.
///
/// The server remains authoritative for its additional NFKC validation. LOOP
/// deliberately does not add a second Unicode-normalization dependency merely
/// for client-side preflight; the submitted value itself remains unchanged.
int loopSearchValidationCodePointLength(String trimmedValue) =>
    trimmedValue.replaceAll(RegExp(r' +'), ' ').runes.length;
