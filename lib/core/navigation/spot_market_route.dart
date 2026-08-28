/// Canonical navigation contract for one admitted public Spot market.
///
/// The route carries only the provider's non-negative Spot index. The detail
/// screen must still resolve that index from the current public market
/// snapshot and fail closed when it is absent.
abstract final class SpotMarketRoute {
  static const String path = '/market/token';
  static const String chartPath = '/market/chart';
  static const String indexParameter = 'spotIndex';

  static String location(int spotIndex) {
    if (spotIndex < 0) {
      throw ArgumentError.value(spotIndex, 'spotIndex', 'must be non-negative');
    }
    return Uri(
      path: path,
      queryParameters: <String, String>{indexParameter: spotIndex.toString()},
    ).toString();
  }

  /// Builds the canonical full-chart location for one admitted Spot market.
  static String chartLocation(int spotIndex) {
    if (spotIndex < 0) {
      throw ArgumentError.value(spotIndex, 'spotIndex', 'must be non-negative');
    }
    return Uri(
      path: chartPath,
      queryParameters: <String, String>{indexParameter: spotIndex.toString()},
    ).toString();
  }

  /// Parses only the exact C3 route identity accepted by [chartLocation].
  ///
  /// Missing, repeated, extra, signed, padded, negative, malformed, or
  /// overflowing parameters fail closed. The chart must never recover an asset
  /// from display text, navigation extras, or a default symbol.
  static int? parseChartSpotIndex(Uri uri) {
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.fragment.isNotEmpty ||
        uri.path != chartPath ||
        uri.queryParametersAll.length != 1) {
      return null;
    }
    final values = uri.queryParametersAll[indexParameter];
    if (values == null || values.length != 1) return null;

    final raw = values.single;
    if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(raw)) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0 || parsed.toString() != raw) return null;
    if (uri.toString() != chartLocation(parsed)) return null;
    return parsed;
  }
}
