import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';

/// Keeps a read's last answer for a while after its page went away
/// (decision 0095).
///
/// The read providers are `autoDispose`, and the tab shell mounts one page at
/// a time: before this, leaving 钱包 for 行情 destroyed the balances, and
/// coming back issued every read again behind a skeleton. A retained read
/// comes back drawn, marked 更新中, and re-reads in the background.
///
/// Call it once from `build`. It
///
/// * holds the provider alive with a [KeepAliveLink] that is released
///   [LoopSnapshotPolicy.memoryRetention] after the last listener left — or
///   was paused, which is what a covered route does;
/// * calls [onRevisit] once a listener comes back, on a microtask so the
///   state it writes is never written while a widget is building. The
///   callback decides whether the answer is old enough to read again.
void loopRetainRead(Ref ref, {required void Function() onRevisit}) {
  final link = ref.keepAlive();
  Timer? expiry;
  var disposed = false;
  ref.onCancel(() {
    expiry?.cancel();
    expiry = Timer(LoopSnapshotPolicy.memoryRetention, link.close);
  });
  ref.onResume(() {
    expiry?.cancel();
    expiry = null;
    scheduleMicrotask(() {
      if (!disposed) onRevisit();
    });
  });
  ref.onDispose(() {
    disposed = true;
    expiry?.cancel();
    expiry = null;
  });
}

/// Whether a retained answer read at [readAt] is due for a background re-read
/// at [now]. A block with no answer at all — never read, or failed — is
/// always due.
bool loopRevisitIsDue({
  required bool hasValue,
  required bool inFlight,
  required DateTime? readAt,
  required DateTime now,
}) {
  if (inFlight) return false;
  if (!hasValue || readAt == null) return true;
  return now.difference(readAt) >= LoopSnapshotPolicy.revisitFloor;
}
