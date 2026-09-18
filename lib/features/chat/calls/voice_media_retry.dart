import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';

/// Makes a reader's second attempt an actual second attempt.
///
/// Every refusal this screen can show is held by something this device
/// already made: the authorized provider session, the client it built, and
/// the call that client handed out. Watching the authorization again answers
/// `authorized` without asking for anything — the session short-circuits while
/// it still holds a client — so a retry that only re-read a provider issued no
/// request at all and left the reader tapping a button that did nothing.
///
/// The three steps are always taken together, in this order:
///
/// 1. retire the provider session, so the next authorization goes back for an
///    identity, a token and a client of its own;
/// 2. drop the authorization and the call factory derived from it, so the
///    surface rebuilds on the new client instead of the retired one;
/// 3. read the room again, because a second attempt must also know whether the
///    room is still there and under which provider call.
///
/// [refreshRoom] is the caller's own way of taking that last reading — the
/// LOOP voice room page re-reads its room resource, a surface that resolves
/// the room through a provider invalidates it — and is optional only for a
/// caller that was handed a room it cannot read again.
///
/// [stillMounted] is asked after the retirement completes: a reader who left
/// the screen during it must not have providers invalidated through a ref that
/// is gone.
Future<void> refreshVoiceMediaSession(
  WidgetRef ref, {
  Future<void> Function()? refreshRoom,
  bool Function()? stillMounted,
}) async {
  await ref.read(streamVideoSdkSessionProvider)?.retireForRetry();
  if (stillMounted != null && !stillMounted()) return;
  ref.invalidate(streamVideoAuthorizationProvider);
  ref.invalidate(audioRoomCallFactoryProvider);
  await refreshRoom?.call();
}
