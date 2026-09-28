import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A profile link (`/u/{loopId}`, decision 0104) opened before the session
/// could show it.
///
/// A link that arrives on a cold start lands on the credential or launch page
/// first. The router keeps the LOOP ID here and hands the owner to the search
/// page with it once the account has landed, instead of to Community. Only the
/// latest link is kept, and it is handed over once.
final class LoopProfileLinkInbox {
  String? _loopId;
  String? _roomCommunityId;

  /// The community whose room link (`/c/{id}/room`, decision 0105) is
  /// waiting to be opened, if any.
  String? get pendingRoom => _roomCommunityId;

  void holdRoom(String communityId) => _roomCommunityId = communityId;

  /// Returns the waiting room link's community and forgets it.
  String? takeRoom() {
    final id = _roomCommunityId;
    _roomCommunityId = null;
    return id;
  }

  /// The LOOP ID waiting to be opened, if any.
  String? get pending => _loopId;

  void hold(String loopId) => _loopId = loopId;

  /// Returns the waiting LOOP ID and forgets it.
  String? take() {
    final loopId = _loopId;
    _loopId = null;
    return loopId;
  }
}

final loopProfileLinkInboxProvider = Provider<LoopProfileLinkInbox>(
  (ref) => LoopProfileLinkInbox(),
);
