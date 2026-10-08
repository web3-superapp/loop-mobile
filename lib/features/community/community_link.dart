/// A community's card link, `/c/{communityId}` (decision 0113).
///
/// Text rules only, like `loop_id_share.dart` (decision 0104) and
/// `voice_room_share.dart` (decision 0105): no share sheet, no router and no
/// network live here, so the QR card, the link redirect, the scanner and the
/// tests read one definition of what a community link looks like.
library;

/// `/c/{uuid}` with at most one trailing slash. The room link
/// (`/c/{id}/room`) is a different link and never matches here.
final RegExp _communityLinkPath = RegExp(
  r'^/c/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{12})/?$',
);

/// The community a `/c/{communityId}` link names, lower-cased, or null when
/// [path] is not such a link.
String? communityIdFromLinkPath(String path) =>
    _communityLinkPath.firstMatch(path)?.group(1)?.toLowerCase();

/// The in-app location a community link opens: the community's record
/// (manifest `community-profile`; no route is added for the link).
String communityProfileLocation(String communityId) => Uri(
  path: '/community/profile',
  queryParameters: <String, String>{'id': communityId},
).toString();

/// The readable link for [communityId] on the configured LOOP backend host,
/// or null when this build has no backend: a link to nowhere is not offered.
String? communityCardLink(String backendBaseUrl, String communityId) {
  final trimmed = backendBaseUrl.trim();
  if (trimmed.isEmpty) return null;
  final base = Uri.tryParse(trimmed);
  if (base == null || base.host.isEmpty || !base.hasScheme) return null;
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/c/${Uri.encodeComponent(communityId)}',
  ).toString();
}

/// The manage center's location (manifest `community-manage`).
String communityManageLocation(String communityId) => Uri(
  path: '/community/manage',
  queryParameters: <String, String>{'id': communityId},
).toString();
