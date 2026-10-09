import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_owner_face.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';

/// The owner's face for the heads that draw it — 聊天's top bar, the Intel
/// ranking's own row (decision 0132, audit 2026-10-09 m19).
///
/// The profile the server answered wins whenever there is one. Before it
/// lands — the first frames of a cold start — the face the last run stored is
/// drawn instead, so the head opens on the owner's picture rather than on a
/// monogram that becomes a picture a moment later. Every answer the server
/// gives is stored again for the next cold start. Display only: the profile
/// editor never opens on this.
final ownerFaceProvider = Provider<LoopOwnerFace?>((ref) {
  final values = ref.watch(
    profileControllerProvider.select((state) => state.resource?.values),
  );
  if (values != null) {
    final face = LoopOwnerFace(
      alias: values.alias,
      avatarRef: values.avatarRef,
    );
    if (face.alias != null || face.avatarRef != null) {
      ref
          .read(loopSnapshotRecorderProvider)
          ?.call(LoopSnapshotResource.ownerFace, face.toJson());
    }
    return face;
  }
  final restored = ref
      .watch(loopSnapshotRestorerProvider)
      ?.restore(LoopSnapshotResource.ownerFace);
  final value = restored?.value;
  return value is LoopOwnerFace ? value : null;
});
