import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/account/onboarding_communities.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';

/// Mutes one community channel for the signed-in Stream user (S107 §4).
///
/// It waits for the server-authorized Stream session the rest of chat uses
/// and then asks Stream itself; there is no LOOP-side mute record. Without an
/// authorized session it fails, and the onboarding page says that row was
/// joined but not muted.
final class StreamCommunityChannelMuter implements CommunityChannelMuter {
  const StreamCommunityChannelMuter(this._ref);

  final Ref _ref;

  @override
  Future<void> mute(String channelCid) async {
    final session = _ref.read(streamChatSdkSessionProvider);
    if (session == null) throw StateError('stream_unavailable');
    // The authorization is auto-disposed; holding a subscription keeps it
    // alive for exactly the length of this call.
    final subscription = _ref.listen(
      streamChatAuthorizationProvider.future,
      (previous, next) {},
    );
    try {
      final authorization = await subscription.read();
      if (authorization != StreamSessionAuthorization.authorized) {
        throw StateError('stream_unauthorized');
      }
      await session.client.muteChannel(channelCid);
    } finally {
      subscription.close();
    }
  }
}

final streamCommunityChannelMuterProvider = Provider<CommunityChannelMuter>(
  StreamCommunityChannelMuter.new,
);
