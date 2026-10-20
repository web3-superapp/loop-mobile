/// Invite links `https://<backend host>/i/{code}` (S239, decision 0214;
/// loop-api decision 0162 §B.3 / §5).
///
/// Like the profile link `/u/{loopId}` (decision 0104) the link is not a
/// page: the router turns it into the existing `referral` route with the code
/// as a query, where the binding form opens pre-filled. No route is added to
/// the manifest for the link itself.
library;

/// The invite link path segment: `/i/{code}`.
const String inviteLinkPathPrefix = '/i/';

/// The `referral` route (manifest slug `referral`).
const String referralRoutePath = '/profile/referral';

final RegExp _inviteCodeBody = RegExp(r'^[0-9A-HJKMNP-TV-Z]{5}$');

/// The invite code an `/i/{code}` link names, normalised the way the server
/// normalises it (upper case, `LOOP-` optional, Crockford `I`/`L` → `1`,
/// `O` → `0`), or `null` when [path] is not such a link. One trailing slash
/// is tolerated. Whether the code was ever issued stays the server's call.
String? inviteCodeFromLinkPath(String path) {
  if (!path.startsWith(inviteLinkPathPrefix)) return null;
  var rest = path.substring(inviteLinkPathPrefix.length);
  if (rest.endsWith('/')) rest = rest.substring(0, rest.length - 1);
  if (rest.isEmpty || rest.contains('/') || rest.length > 16) return null;
  final String decoded;
  try {
    decoded = Uri.decodeComponent(rest);
  } catch (_) {
    return null;
  }
  final upper = decoded.trim().toUpperCase();
  final body = upper.startsWith('LOOP-')
      ? upper.substring(5)
      : (upper.startsWith('LOOP') ? upper.substring(4) : upper);
  final substituted = body
      .replaceAll('I', '1')
      .replaceAll('L', '1')
      .replaceAll('O', '0');
  if (!_inviteCodeBody.hasMatch(substituted)) return null;
  return 'LOOP-$substituted';
}

/// Where an invite link opens: the `referral` page with the code.
String referralClaimLocation(String code) => Uri(
  path: referralRoutePath,
  queryParameters: <String, String>{'code': code},
).toString();

/// The code a `referral` location carries, if it is well formed.
String? referralClaimCodeFromQuery(Map<String, String> query) {
  final raw = query['code'];
  if (raw == null) return null;
  return inviteCodeFromLinkPath('$inviteLinkPathPrefix$raw');
}
