import 'dart:async';

/// The one thread between the LOOP voice room page and the media surface it
/// mounts.
///
/// Joining a voice room is one decision, so leaving is one too: the page's
/// 离开 command must take the provider call down before it releases the LOOP
/// membership, and the media surface must stop reconnecting the moment that
/// exit begins. The page holds the link, the mounted surface attaches its own
/// disconnect to it, and nothing else passes through.
final class VoiceMediaLink {
  Future<void> Function()? _disconnect;

  /// True while a media surface is mounted and has published its disconnect.
  bool get isAttached => _disconnect != null;

  void attach(Future<void> Function() disconnect) {
    _disconnect = disconnect;
  }

  /// Detaches by identity so a surface that was replaced cannot unhook the
  /// one that took its place.
  void detach(Future<void> Function() disconnect) {
    if (identical(_disconnect, disconnect)) _disconnect = null;
  }

  /// Takes the provider call down before the LOOP membership is released.
  ///
  /// Returns false when the surface could not confirm the disconnect. The
  /// LOOP leave still runs: staying in the room against the reader's decision
  /// because a provider command hung is the worse of the two answers, and the
  /// surface keeps its own retirement state either way.
  Future<bool> disconnect() async {
    final disconnect = _disconnect;
    if (disconnect == null) return true;
    try {
      await disconnect();
      return true;
    } catch (_) {
      return false;
    }
  }
}
