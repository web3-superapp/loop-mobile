import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';

/// Copying, sharing and recognising a LOOP ID (decision 0104).
///
/// Text rules only: no clipboard, no share sheet and no network live here, so
/// the profile page, the public-profile sheet, the search page and the link
/// redirect all read one definition of what a LOOP ID looks like.

/// A LOOP ID in any surrounding text: `LOOP-` and eight letters or digits,
/// in any letter case, not glued to a longer run of letters or digits.
///
/// The match is deliberately looser than the server's Crockford alphabet
/// (`^LOOP-[0-9A-HJKMNP-TV-Z]{8}$`): a pasted ID is upper-cased and handed to
/// search, and search is what answers whether the account exists. The
/// five-symbol invite code (`LOOP-XXXXC`) is never taken for one.
final RegExp _loopIdInText = RegExp(
  r'(?<![0-9A-Za-z])LOOP-([0-9A-Za-z]{8})(?![0-9A-Za-z])',
  caseSensitive: false,
);

final RegExp _loopIdExact = RegExp(r'^LOOP-[0-9A-Z]{8}$');

/// The first LOOP ID in [text], upper-cased, or null when there is none.
String? loopIdFromText(String? text) {
  if (text == null || text.isEmpty) return null;
  final match = _loopIdInText.firstMatch(text);
  if (match == null) return null;
  return 'LOOP-${match.group(1)!.toUpperCase()}';
}

/// Whether [value] is exactly one upper-cased LOOP ID and nothing else.
bool isLoopIdQuery(String value) => _loopIdExact.hasMatch(value.trim());

/// The profile link path segment: `/u/{loopId}`.
const String loopIdLinkPathPrefix = '/u/';

/// The LOOP ID a `/u/{loopId}` link names, upper-cased, or null when [path]
/// is not such a link. One trailing slash is tolerated.
String? loopIdFromLinkPath(String path) {
  if (!path.startsWith(loopIdLinkPathPrefix)) return null;
  var rest = path.substring(loopIdLinkPathPrefix.length);
  if (rest.endsWith('/')) rest = rest.substring(0, rest.length - 1);
  if (rest.contains('/')) return null;
  final decoded = Uri.decodeComponent(rest);
  final id = loopIdFromText(decoded);
  return id != null && id.length == decoded.length ? id : null;
}

/// The in-app location a profile link opens: the search page (manifest
/// `search`, which is where a friend is added) with the ID in its field.
String loopIdSearchLocation(String loopId) => Uri(
  path: '/search',
  queryParameters: <String, String>{'q': loopId},
).toString();

/// The readable link for [loopId] on the configured LOOP backend host, or
/// null when this build has no backend: a link to nowhere is not offered.
String? loopIdProfileLink(String backendBaseUrl, String loopId) {
  final trimmed = backendBaseUrl.trim();
  if (trimmed.isEmpty) return null;
  final base = Uri.tryParse(trimmed);
  if (base == null || base.host.isEmpty || !base.hasScheme) return null;
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '$loopIdLinkPathPrefix$loopId',
  ).toString();
}

/// The text handed to the system share sheet for the viewer's own ID.
@visibleForTesting
String loopIdShareText(String loopId, {String? link}) {
  final line = '在 LOOP 上加我为好友：$loopId';
  return link == null ? line : '$line\n$link';
}

/// Share text built from the configured backend.
String loopIdShareTextFor(String loopId, {required String backendBaseUrl}) =>
    loopIdShareText(loopId, link: loopIdProfileLink(backendBaseUrl, loopId));

/// The base a profile link is built on: the build's `LOOP_BACKEND_BASE_URL`.
/// A provider so a test can name a host without configuring a backend.
final loopIdLinkBaseUrlProvider = Provider<String>(
  (ref) =>
      ref.watch(appConfigProvider.select((config) => config.backendBaseUrl)),
);
