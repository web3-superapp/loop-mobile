/// Canonical navigation contract for one launch.
///
/// The route carries the opaque `launchId` and nothing else. A ticker, a name
/// or a contract address is never a route identity: two projects may share a
/// ticker, and a page that recovered its subject from display text would show
/// the wrong project's facts.
abstract final class LaunchRoute {
  static const String detailPath = '/launch/detail';
  static const String tierPath = '/launch/tier';
  static const String tradePath = '/launch/trade';
  static const String holdersPath = '/launch/holders';
  static const String graduationPath = '/launch/graduation';
  static const String historyPath = '/launch/history';
  static const String roundsPath = '/launch/rounds';
  static const String launchParameter = 'launchId';

  static final RegExp _idPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static bool isCanonical(String launchId) => _idPattern.hasMatch(launchId);

  static String location(String path, String launchId) {
    if (!isCanonical(launchId)) {
      throw ArgumentError.value(launchId, 'launchId', 'must be a UUID');
    }
    return Uri(
      path: path,
      queryParameters: <String, String>{launchParameter: launchId},
    ).toString();
  }

  static String detail(String launchId) => location(detailPath, launchId);

  static String tier(String launchId) => location(tierPath, launchId);

  static String trade(String launchId) => location(tradePath, launchId);

  static String holders(String launchId) => location(holdersPath, launchId);

  static String graduation(String launchId) =>
      location(graduationPath, launchId);

  static String history(String launchId) => location(historyPath, launchId);

  static String rounds(String launchId) => location(roundsPath, launchId);

  /// Parses only the exact identity produced by [location].
  ///
  /// A missing, repeated, extra or malformed parameter fails closed: the page
  /// then renders its unavailable state rather than substituting a launch.
  static String? parse(Uri uri, String path) {
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.fragment.isNotEmpty ||
        uri.path != path ||
        uri.queryParametersAll.length != 1) {
      return null;
    }
    final values = uri.queryParametersAll[launchParameter];
    if (values == null || values.length != 1) return null;
    final raw = values.single;
    if (!isCanonical(raw)) return null;
    if (uri.toString() != location(path, raw)) return null;
    return raw;
  }
}

/// Canonical navigation contract for one community mining panel.
///
/// The opaque `communityId` is the only accepted addressing value; a slug, a
/// name or a bound asset address is never a route parameter.
abstract final class MiningRoute {
  static const String communityPath = '/mining/community';
  static const String communityParameter = 'communityId';

  static final RegExp _idPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static bool isCanonical(String communityId) =>
      _idPattern.hasMatch(communityId);

  static String location(String path, String communityId) {
    if (!isCanonical(communityId)) {
      throw ArgumentError.value(communityId, 'communityId', 'must be a UUID');
    }
    return Uri(
      path: path,
      queryParameters: <String, String>{communityParameter: communityId},
    ).toString();
  }

  static String community(String communityId) =>
      location(communityPath, communityId);

  static String? parse(Uri uri, String path) {
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.fragment.isNotEmpty ||
        uri.path != path ||
        uri.queryParametersAll.length != 1) {
      return null;
    }
    final values = uri.queryParametersAll[communityParameter];
    if (values == null || values.length != 1) return null;
    final raw = values.single;
    if (!isCanonical(raw)) return null;
    if (uri.toString() != location(path, raw)) return null;
    return raw;
  }
}
