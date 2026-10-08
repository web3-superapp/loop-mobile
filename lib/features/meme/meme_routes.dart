import 'package:loop_mobile/features/meme/meme_models.dart';

/// The four MEME child routes (client decision 0120, manifest 101 → 105).
///
/// A token is addressed by the server's opaque `memeTokenId` (a UUIDv4) and
/// nothing else; a missing or malformed one fails closed on the page.
abstract final class MemeRoute {
  static const String createPath = '/meme/create';
  static const String tokenPath = '/meme/token';
  static const String holdersPath = '/meme/token/holders';
  static const String tradesPath = '/meme/token/trades';

  static final RegExp _idPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static bool isTokenId(String? value) =>
      value != null && _idPattern.hasMatch(value);

  static String _with(String path, String id) =>
      Uri(path: path, queryParameters: <String, String>{'id': id}).toString();

  static String token(String memeTokenId) => _with(tokenPath, memeTokenId);

  static String holders(String memeTokenId) => _with(holdersPath, memeTokenId);

  static String trades(String memeTokenId) => _with(tradesPath, memeTokenId);

  /// Resumes the creation of a draft this account owns.
  static String resume(String memeTokenId) => Uri(
    path: createPath,
    queryParameters: <String, String>{'draft': memeTokenId},
  ).toString();

  /// The token id in a route, or `null` when it is missing or malformed.
  static String? idOf(Uri uri, {String key = 'id'}) {
    final value = uri.queryParameters[key];
    return isTokenId(value) ? value : null;
  }

  /// The existing Swap page with the pair pre-filled: USD1 (when known) to
  /// the graduated token, both by canonical CAIP id.
  static String swap({required MemeTokenDetail detail, String? usd1Address}) {
    final chainId = detail.contract.chainId;
    final token = detail.row.tokenAddress;
    final query = <String, String>{
      if (usd1Address != null) 'from': '$chainId:$usd1Address',
      if (token != null) 'to': '$chainId:$token',
    };
    if (query.isEmpty) return '/wallet/swap';
    return Uri(path: '/wallet/swap', queryParameters: query).toString();
  }
}
