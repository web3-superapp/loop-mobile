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
