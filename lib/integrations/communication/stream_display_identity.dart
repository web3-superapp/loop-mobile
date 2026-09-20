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
