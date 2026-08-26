/// Canonical navigation contract for one admitted public Spot market.
///
/// The route carries only the provider's non-negative Spot index. The detail
/// screen must still resolve that index from the current public market
/// snapshot and fail closed when it is absent.
abstract final class SpotMarketRoute {
  static const String path = '/market/token';
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
}
