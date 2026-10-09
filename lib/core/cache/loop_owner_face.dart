import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two facts the heads that draw the owner need: the alias the monogram
/// is made of and the avatar reference the picture is resolved from
/// (decision 0132).
///
/// It is a display copy of the owner's own profile, kept so the first frame
/// after a cold start draws the same face the last run ended on instead of a
/// monogram that turns into a picture a moment later. It is never a profile:
/// the editor still opens only on the profile the server answers, and the
/// face is replaced by that answer as soon as it lands.
@immutable
final class LoopOwnerFace {
  const LoopOwnerFace({required this.alias, required this.avatarRef});

  final String? alias;
  final String? avatarRef;

  static final RegExp _avatarReference = RegExp(
    r'^avatar:[A-Za-z0-9][A-Za-z0-9._/-]{0,126}$',
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'alias': alias,
    'avatarRef': avatarRef,
  };

  /// The face [body] describes, or `null` for any other shape. Strict like
  /// every snapshot decoder: an unknown key or an out-of-range value is not a
  /// face.
  static LoopOwnerFace? decode(Object? body) {
    if (body is! Map) return null;
    if (body.keys.any((key) => key != 'alias' && key != 'avatarRef')) {
      return null;
    }
    final alias = body['alias'];
    final avatarRef = body['avatarRef'];
    if (alias != null &&
        (alias is! String || alias.trim().isEmpty || alias.runes.length > 40)) {
      return null;
    }
    if (avatarRef != null &&
        (avatarRef is! String || !_avatarReference.hasMatch(avatarRef))) {
      return null;
    }
    if (alias == null && avatarRef == null) return null;
    return LoopOwnerFace(
      alias: alias as String?,
      avatarRef: avatarRef as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LoopOwnerFace &&
      other.alias == alias &&
      other.avatarRef == avatarRef;

  @override
  int get hashCode => Object.hash(alias, avatarRef);
}

/// Hands a display-only answer to the snapshot store (decision 0132).
///
/// `null` — the default, every Preview and test build — stores nothing.
/// Production wires it to the signed-in account's snapshot session, which
/// files the answer under that account and drops it on sign-out.
final loopSnapshotRecorderProvider =
    Provider<void Function(String resource, Object? body)?>((ref) => null);
