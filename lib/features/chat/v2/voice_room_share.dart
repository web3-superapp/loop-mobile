/// Sharing a community's live voice room (decision 0105 · 4).
///
/// Text rules only, like `loop_id_share.dart` (decision 0104): no share sheet,
/// no router and no network live here, so the room page, the link redirect and
/// the tests read one definition of what a room link looks like.
library;

/// `/c/{communityId}/room`. The community is the stable address; which room
/// is live is read again when the link is opened, never carried in it.
final RegExp _roomLinkPath = RegExp(r'^/c/([A-Za-z0-9_-]{1,64})/room/?$');

/// The community a `/c/{communityId}/room` link names, or null when [path]
/// is not such a link.
String? communityIdFromRoomLinkPath(String path) =>
    _roomLinkPath.firstMatch(path)?.group(1);

/// The in-app location a room link opens: the community's record, asked to
/// open its live room on arrival (manifest `community-profile`; no route is
/// added for the link).
String voiceRoomLinkLocation(String communityId) => Uri(
  path: '/community/profile',
  queryParameters: <String, String>{
    'id': communityId,
    voiceRoomArrivalParameter: voiceRoomArrivalValue,
  },
).toString();

/// The query parameter that asks `community-profile` to open the live room.
const String voiceRoomArrivalParameter = 'room';
const String voiceRoomArrivalValue = 'live';

/// The readable link for [communityId]'s room on the configured LOOP backend
/// host, or null when this build has no backend: a link to nowhere is not
/// offered.
String? voiceRoomShareLink(String backendBaseUrl, String communityId) {
  final trimmed = backendBaseUrl.trim();
  if (trimmed.isEmpty) return null;
  final base = Uri.tryParse(trimmed);
  if (base == null || base.host.isEmpty || !base.hasScheme) return null;
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/c/${Uri.encodeComponent(communityId)}/room',
  ).toString();
}

/// The room's title as the room page prints it. The room resource carries
/// no title of its own (decision 0052), so it is the community's room.
String voiceRoomTitle(String communityName) => '$communityName 语音房';

/// The text handed to the system share sheet.
String voiceRoomShareText({
  required String communityName,
  required String roomTitle,
  String? link,
}) {
  final line = '来 LOOP 的『$communityName』语音房：$roomTitle';
  return link == null ? line : '$line\n$link';
}
