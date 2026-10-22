import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

/// Ensures the direct channel with a friend the viewer has just accepted
/// (decision 0231).
///
/// Accepting a request (`POST /v2/message-requests/:id/decision`) writes the
/// friendship and nothing else: no `direct_channels` row and no Stream
/// channel. The inbox lists Stream channels, so until someone opened the
/// conversation from a profile card the new friend was nowhere under 好友.
/// The accepting side therefore asks the backend's idempotent
/// get-or-create (`POST /v2/chat/direct-channels`) right after the accept.
/// The channel it creates has both accounts as members, so the requester's
/// inbox gets the same row through Stream's own membership event.
///
/// This is best effort and never surfaces a failure: the friendship already
/// exists, and opening the conversation from the profile card runs the very
/// same get-or-create again. It is held by a non-disposing provider so that
/// leaving the requests page does not cancel the operation half way.
final class AcceptedFriendDirectChannel {
  AcceptedFriendDirectChannel(this._ref);

  /// The same poll budget the conversation page uses.
  static const int maximumPolls = 12;

  final Ref _ref;
  final Map<String, Future<bool>> _inFlight = <String, Future<bool>>{};

  /// Resolves `true` once the backend reports the channel created (or
  /// reused), `false` on any failure or an exhausted poll budget.
  Future<bool> ensure(String publicProfileId) {
    final active = _inFlight[publicProfileId];
    if (active != null) return active;
    final gateway = _ref.read(chatV2GatewayProvider);
    if (gateway.mode == CommunityGatewayMode.unavailable) {
      return Future<bool>.value(false);
    }
    // A block body: `Map.remove` would return this very future, and
    // `whenComplete` waits on a returned future — a self-wait.
    final operation = _run(gateway, publicProfileId).whenComplete(() {
      _inFlight.remove(publicProfileId);
    });
    _inFlight[publicProfileId] = operation;
    return operation;
  }

  Future<bool> _run(ChatV2Gateway gateway, String publicProfileId) async {
    try {
      var operation = await gateway.openDirectChannel(publicProfileId);
      var polls = 0;
      while (!operation.terminal && polls < maximumPolls) {
        await Future<void>.delayed(
          Duration(milliseconds: operation.retryAfterMs ?? 500),
        );
        operation = await gateway.pollOperation(operation.operationId);
        polls += 1;
      }
      final created = operation.isSucceeded && operation.streamCid != null;
      // The inbox names a direct row from this index; a new channel needs a
      // fresh read or it would show under the neutral label.
      if (created) _ref.invalidate(directChannelDirectoryProvider);
      return created;
    } catch (_) {
      return false;
    }
  }
}

final acceptedFriendDirectChannelProvider =
    Provider<AcceptedFriendDirectChannel>(AcceptedFriendDirectChannel.new);
