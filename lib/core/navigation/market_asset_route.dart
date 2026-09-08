/// Canonical navigation contract for one registry asset.
///
/// The route carries the canonical CAIP `assetId` and nothing else. A ticker,
/// a symbol, an address on its own, or a display string is never a route
/// identity: two contracts may share a ticker, and a page that recovered its
/// subject from display text would show the wrong asset's facts.
abstract final class MarketAssetRoute {
  static const String tokenPath = '/market/token';
  static const String chartPath = '/market/chart';
  static const String holdersPath = '/market/holders';
  static const String tradesPath = '/market/trades';
  static const String alertsPath = '/market/alerts';
  static const String walletAssetPath = '/wallet/asset';
  static const String assetParameter = 'assetId';

  static final RegExp _assetIdPattern = RegExp(
    r'^eip155:[1-9][0-9]{0,9}:(native|0x[0-9a-f]{40})$',
  );

  static bool isCanonical(String assetId) => _assetIdPattern.hasMatch(assetId);

  static String location(String path, String assetId) {
    if (!isCanonical(assetId)) {
      throw ArgumentError.value(
        assetId,
        'assetId',
        'must be a canonical CAIP id',
      );
    }
    return Uri(
      path: path,
      queryParameters: <String, String>{assetParameter: assetId},
    ).toString();
  }

  static String token(String assetId) => location(tokenPath, assetId);

  static String chart(String assetId) => location(chartPath, assetId);

  static String holders(String assetId) => location(holdersPath, assetId);

  static String trades(String assetId) => location(tradesPath, assetId);

  static String alerts(String assetId) => location(alertsPath, assetId);

  static String walletAsset(String assetId) =>
      location(walletAssetPath, assetId);

  /// Parses only the exact identity produced by [location].
  ///
  /// A missing, repeated, extra, or malformed parameter fails closed: the page
  /// then renders its unavailable state rather than substituting an asset.
  static String? parse(Uri uri, String path) {
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.fragment.isNotEmpty ||
        uri.path != path ||
        uri.queryParametersAll.length != 1) {
      return null;
    }
    final values = uri.queryParametersAll[assetParameter];
    if (values == null || values.length != 1) return null;
    final raw = values.single;
    if (!isCanonical(raw)) return null;
    if (uri.toString() != location(path, raw)) return null;
    return raw;
  }
}

/// Canonical navigation contract for one owned wallet.
///
/// The opaque `walletId` is the only accepted addressing value; an address is
/// never a route parameter.
abstract final class WalletRoute {
  static const String receivePath = '/wallet/receive';
  static const String historyPath = '/wallet/history';
  static const String walletParameter = 'walletId';

  static final RegExp _walletIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static bool isCanonical(String walletId) =>
      _walletIdPattern.hasMatch(walletId);

  static String location(String path, String walletId) {
    if (!isCanonical(walletId)) {
      throw ArgumentError.value(walletId, 'walletId', 'must be a UUIDv4');
    }
    return Uri(
      path: path,
      queryParameters: <String, String>{walletParameter: walletId},
    ).toString();
  }

  static String receive(String walletId) => location(receivePath, walletId);

  static String history(String walletId) => location(historyPath, walletId);

  static String? parse(Uri uri, String path) {
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.fragment.isNotEmpty ||
        uri.path != path ||
        uri.queryParametersAll.length != 1) {
      return null;
    }
    final values = uri.queryParametersAll[walletParameter];
    if (values == null || values.length != 1) return null;
    final raw = values.single;
    if (!isCanonical(raw)) return null;
    if (uri.toString() != location(path, raw)) return null;
    return raw;
  }
}
