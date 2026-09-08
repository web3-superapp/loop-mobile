/// A provider-neutral address for the only Stream Chat channel type that LOOP
/// currently exposes through application navigation.
final class LoopStreamChannelAddress {
  const LoopStreamChannelAddress._({required this.type, required this.id});

  final String type;
  final String id;

  String get cid => '$type:$id';

  @override
  bool operator ==(Object other) {
    return other is LoopStreamChannelAddress &&
        other.type == type &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}

final RegExp _forbiddenChannelControlPattern = RegExp(
  r'[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028-\u202e\u2060-\u2069\ufeff]',
);

/// Parses the only channel CID shape enabled by LOOP's current Chat product.
///
/// The application route and any future provider ingress must share this
/// parser so notification data cannot create a broader Chat navigation path.
LoopStreamChannelAddress? parseLoopStreamChannelCid(String cid) {
  if (cid.isEmpty ||
      cid.length > 255 ||
      cid != cid.trim() ||
      cid.contains('/') ||
      _forbiddenChannelControlPattern.hasMatch(cid)) {
    return null;
  }
  final separator = cid.indexOf(':');
  if (separator <= 0 || separator == cid.length - 1) return null;
  final type = cid.substring(0, separator);
  final id = cid.substring(separator + 1);
  if (type != 'messaging' || id.isEmpty || id.contains(':')) return null;
  return LoopStreamChannelAddress._(type: type, id: id);
}

/// The three LOOP conversation surfaces a channel ID can address.
///
/// The prefix is assigned by the LOOP backend when it creates the channel, so
/// it is the only place a destination may be derived from. Display copy, a
/// ticker or a member name never picks a route.
enum LoopChatSurface { communityChat, direct, group }

const String _communityChannelPrefix = 'loop_community_';
const String _directChannelPrefix = 'loop_direct_';
const String _groupChannelPrefix = 'loop_group_';

final RegExp _channelSuffixPattern = RegExp(r'^[0-9a-f]{32}$');

/// Classifies one channel CID. An unknown or malformed shape returns null so
/// the caller fails closed rather than guessing a surface.
LoopChatSurface? loopChatSurfaceForCid(String cid) {
  final address = parseLoopStreamChannelCid(cid);
  if (address == null) return null;
  final id = address.id;
  for (final entry in const <String, LoopChatSurface>{
    _communityChannelPrefix: LoopChatSurface.communityChat,
    _directChannelPrefix: LoopChatSurface.direct,
    _groupChannelPrefix: LoopChatSurface.group,
  }.entries) {
    if (!id.startsWith(entry.key)) continue;
    if (!_channelSuffixPattern.hasMatch(id.substring(entry.key.length))) {
      return null;
    }
    return entry.value;
  }
  return null;
}

/// Restores the community UUID carried by a community channel ID.
///
/// The backend builds the ID as `loop_community_<communityId without dashes>`,
/// so the mapping is exact and reversible. Any other shape returns null.
String? loopCommunityIdForChannelCid(String cid) {
  if (loopChatSurfaceForCid(cid) != LoopChatSurface.communityChat) return null;
  final hex = parseLoopStreamChannelCid(cid)!.id
      .substring(_communityChannelPrefix.length);
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The application location one channel CID opens.
///
/// It is the single mapping shared by notifications, chat search and message
/// forwarding, so no surface can invent a broader navigation path.
String? loopChatLocationForCid(String cid) {
  final surface = loopChatSurfaceForCid(cid);
  final encoded = Uri.encodeComponent(cid);
  return switch (surface) {
    // The community record is the gate for its official channel, so the
    // location carries the community, not the channel.
    LoopChatSurface.communityChat =>
      '/community/chat?id=${loopCommunityIdForChannelCid(cid)}',
    LoopChatSurface.direct => '/chat/dm?cid=$encoded',
    LoopChatSurface.group => '/chat/group?cid=$encoded',
    null => null,
  };
}
