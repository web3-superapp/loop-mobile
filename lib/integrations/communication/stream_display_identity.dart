import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The only name a LOOP surface may print for a chat user.
///
/// Device report 2026-09-19 · F5. LOOP publishes no profile facts to Stream:
/// every account is upserted as `{ id }` alone, so `User.name` is empty and the
/// SDK's own getter falls back to the id
/// (`stream_chat-10.3.0/lib/src/core/models/user.dart:89`). That id is the
/// LOOP row key with its dashes removed, identical in every room the account
/// is in, which is the one string a chat surface must never print.
///
/// So neither [User.name] nor [User.id] is a name here. A label is written
/// onto the display copy of a user by the surface that resolved it — today
/// that is the group Alias projection carried on the channel's own member —
/// and read back through [loopStreamDisplayLabelOf]. Absent a label there is
/// no name to draw, and the surface draws none.
const String loopStreamDisplayLabelField = 'loop_display_label';

/// A display-only [User] carrying [label] as its name.
///
/// The id is kept because Stream's own widgets route on it (own-message
/// alignment, reactions, mention anchors). It is never drawn: every LOOP site
/// that prints a name reads [loopStreamDisplayLabelOf].
///
/// This copy is built for the presentation tree and is never sent anywhere.
User loopStreamDisplayUser({required String id, required String label}) => User(
  id: id,
  name: label,
  extraData: <String, Object?>{loopStreamDisplayLabelField: label},
);

/// The label LOOP assigned to this user projection, or `null` when it assigned
/// none.
///
/// `null` is the honest answer for every user the client has not resolved a
/// channel-scoped name for — a direct peer, a sender in a long-press preview
/// that was mounted away from its channel — and a caller renders nothing
/// rather than falling back to an account-level value.
String? loopStreamDisplayLabelOf(User? user) {
  final raw = user?.extraData[loopStreamDisplayLabelField];
  if (raw is! String) return null;
  final label = raw.trim();
  return label.isEmpty ? null : label;
}

/// Where the real-identity projection keeps the account's image URL.
const String loopStreamDisplayImageField = 'loop_display_image';

/// Where the real-identity projection keeps the account's public profile id.
const String loopStreamDisplayProfileField = 'loop_display_public_profile_id';

/// The custom field the backend's Stream user sync may carry with the
/// account's `publicProfileId` (S107 §2 proposal). Read-only here.
const String loopStreamPublicProfileIdField = 'publicProfileId';

final RegExp _loopStreamProfileIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// The real identity the backend published on one Stream user (S107 §2).
///
/// Since S107 the backend upserts every activated account as
/// `{ id, name: alias, image: absolute URL | null }`. [name] is read from the
/// raw `name` field only — never from [User.name], whose getter falls back to
/// the id — and a name equal to the id is not a name. [imageUrl] is accepted
/// only as an absolute `https` address (or a loopback `http` address outside
/// release builds, the Development backend's own media).
@immutable
final class LoopStreamRealIdentity {
  const LoopStreamRealIdentity({
    required this.name,
    this.imageUrl,
    this.publicProfileId,
  });

  final String name;
  final String? imageUrl;

  /// The account's public profile, when the Stream user carries it. Without
  /// it the avatar is drawn but is not a way into a profile.
  final String? publicProfileId;
}

/// Reads the real identity off a Stream [User], or `null` when the user
/// carries no real name (a pre-S107 account, or a user Stream only knows by
/// id).
LoopStreamRealIdentity? loopStreamRealIdentityOf(User? user) {
  if (user == null) return null;
  final rawName = user.extraData['name'];
  if (rawName is! String) return null;
  final name = rawName.trim();
  if (name.isEmpty || name == user.id) return null;
  final rawProfile = user.extraData[loopStreamPublicProfileIdField];
  return LoopStreamRealIdentity(
    name: name,
    imageUrl: loopStreamImageUrl(user.extraData['image']),
    publicProfileId:
        rawProfile is String && _loopStreamProfileIdPattern.hasMatch(rawProfile)
        ? rawProfile
        : null,
  );
}

/// An image address a chat avatar may fetch, or `null`.
String? loopStreamImageUrl(Object? raw) {
  if (raw is! String) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme == 'https') return uri.toString();
  final host = uri.host.toLowerCase();
  final loopback = host == 'localhost' || host == '127.0.0.1' || host == '::1';
  if (uri.scheme == 'http' && loopback && !kReleaseMode) {
    return uri.toString();
  }
  return null;
}

/// A display-only [User] that carries the account's real identity: the name
/// as its label, plus the image and the public profile it opens.
User loopStreamRealDisplayUser({
  required String id,
  required LoopStreamRealIdentity identity,
}) => User(
  id: id,
  name: identity.name,
  extraData: <String, Object?>{
    loopStreamDisplayLabelField: identity.name,
    loopStreamDisplayImageField: ?identity.imageUrl,
    loopStreamDisplayProfileField: ?identity.publicProfileId,
  },
);

/// The image the real-identity projection carries, or `null`.
String? loopStreamDisplayImageOf(User? user) {
  final raw = user?.extraData[loopStreamDisplayImageField];
  return raw is String && raw.isNotEmpty ? raw : null;
}

/// The public profile the real-identity projection opens, or `null`.
String? loopStreamDisplayProfileOf(User? user) {
  final raw = user?.extraData[loopStreamDisplayProfileField];
  return raw is String && raw.isNotEmpty ? raw : null;
}

/// Opens the public profile behind a chat avatar.
///
/// The router owns the location, so the app installs one handler above every
/// conversation and the Stream builders — plain functions with no route of
/// their own — read it here. Without a scope an avatar is a picture only.
class LoopChatAvatarTapScope extends InheritedWidget {
  const LoopChatAvatarTapScope({
    required this.onOpenProfile,
    required super.child,
    super.key,
  });

  final void Function(String publicProfileId) onOpenProfile;

  static void Function(String publicProfileId)? maybeOf(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<LoopChatAvatarTapScope>()
          ?.onOpenProfile;

  @override
  bool updateShouldNotify(LoopChatAvatarTapScope oldWidget) =>
      !identical(oldWidget.onOpenProfile, onOpenProfile);
}
