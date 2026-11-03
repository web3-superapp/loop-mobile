/// The MEME v2 project page route (client decision 0139).
///
/// An instance is addressed by the server's opaque `instanceId` (a UUIDv4)
/// in the `id` query parameter — the manifest admits no path parameter — and
/// nothing else; a missing or malformed one fails closed on the page.
abstract final class Launch2Route {
  static const String instancePath = '/launch2/instance';

  static final RegExp _idPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static bool isInstanceId(String? value) =>
      value != null && _idPattern.hasMatch(value);

  static String instance(String instanceId) => Uri(
    path: instancePath,
    queryParameters: <String, String>{'id': instanceId},
  ).toString();

  /// Decision 0157 · 外盘奖励: one LoopDynamic instance's reward rounds,
  /// addressed by the same `id` query parameter.
  static const String dynamicRewardsPath = '/launch2/dynamic-rewards';

  static String dynamicRewards(String instanceId) => Uri(
    path: dynamicRewardsPath,
    queryParameters: <String, String>{'id': instanceId},
  ).toString();

  /// Decision 0163 · 共识勋章: one instance's NFT mint page, addressed by the
  /// same `id` query parameter.
  static const String nftPath = '/launch2/nft';

  static String nft(String instanceId) => Uri(
    path: nftPath,
    queryParameters: <String, String>{'id': instanceId},
  ).toString();

  /// Decision 0273 · the project page's full-screen chart: the market's own
  /// `chart-full` path (`/market/chart`), addressed by the [chartParameter]
  /// query parameter instead of an `assetId`.
  static const String chartParameter = 'launch2';

  static String chart(String instanceId) => Uri(
    path: '/market/chart',
    queryParameters: <String, String>{chartParameter: instanceId},
  ).toString();

  /// The instance id of a [chart] location, or `null` when [uri] is not one.
  static String? chartIdOf(Uri uri) {
    if (uri.path != '/market/chart' ||
        uri.queryParametersAll.length != 1 ||
        !uri.queryParameters.containsKey(chartParameter)) {
      return null;
    }
    final value = uri.queryParameters[chartParameter];
    return isInstanceId(value) ? value : null;
  }

  /// Whether [uri] asks for a project's full-screen chart at all (well
  /// formed or not).
  static bool isChart(Uri uri) =>
      uri.path == '/market/chart' &&
      uri.queryParameters.containsKey(chartParameter);

  /// The instance id in a route, or `null` when it is missing or malformed.
  static String? idOf(Uri uri) {
    final value = uri.queryParameters['id'];
    return isInstanceId(value) ? value : null;
  }

  /// The wallet's Swap page with the graduated token pre-filled by its
  /// canonical CAIP id (`to`), the same pre-fill the MEME curve uses.
  static String swap({required String chainId, required String memeAddress}) =>
      Uri(
        path: '/wallet/swap',
        queryParameters: <String, String>{'to': '$chainId:$memeAddress'},
      ).toString();
}
