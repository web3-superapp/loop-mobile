import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/v2/chat_conversation_label.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// What the conversation header may say about one Stream channel this client
/// already holds (S253 · decision 0216).
///
/// Both facts are the channel's own: the name the LOOP backend wrote onto it
/// when it created the group, read through the same display gate the inbox
/// uses, and the member count Stream states. Either may be absent, and an
/// absent fact is never replaced by a guess.
@immutable
final class LoopChannelHeading {
  const LoopChannelHeading({this.name, this.memberCount});

  static const LoopChannelHeading none = LoopChannelHeading();

  factory LoopChannelHeading.of(ChannelState? state) {
    final channel = state?.channel;
    if (channel == null) return none;
    final count = channel.memberCount;
    return LoopChannelHeading(
      name: loopStoredConversationName(channel.extraData),
      memberCount: count > 0 ? count : null,
    );
  }

  final String? name;
  final int? memberCount;

  @override
  bool operator ==(Object other) =>
      other is LoopChannelHeading &&
      other.name == name &&
      other.memberCount == memberCount;

  @override
  int get hashCode => Object.hash(name, memberCount);
}

/// The header's member line, `12 位成员`, or `null` when Stream stated none.
String? loopChannelMemberLine(int? memberCount) =>
    memberCount == null || memberCount <= 0 ? null : '$memberCount 位成员';

/// Rebuilds [builder] with the heading of channel [cid] as this client holds
/// it, and again whenever the channel arrives or its name or membership
/// changes. With no session, no cid, or no held channel the heading is
/// [LoopChannelHeading.none].
class LoopStreamChannelHeadingBuilder extends ConsumerWidget {
  const LoopStreamChannelHeadingBuilder({
    required this.cid,
    required this.builder,
    super.key,
    this.client,
  });

  final String? cid;
  final Widget Function(BuildContext context, LoopChannelHeading heading)
  builder;

  /// The client to read. Defaults to the signed-in session's own.
  final StreamChatClient? client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cid = this.cid;
    final client =
        this.client ?? ref.watch(streamChatSdkSessionProvider)?.client;
    if (cid == null || client == null) {
      return builder(context, LoopChannelHeading.none);
    }
    return StreamBuilder<Map<String, Channel>>(
      stream: client.state.channelsStream,
      initialData: client.state.channels,
      builder: (context, snapshot) {
        final channel = snapshot.data?[cid];
        final state = channel?.state;
        if (state == null) return builder(context, LoopChannelHeading.none);
        return StreamBuilder<ChannelState>(
          stream: state.channelStateStream,
          initialData: state.channelState,
          builder: (context, channelSnapshot) =>
              builder(context, LoopChannelHeading.of(channelSnapshot.data)),
        );
      },
    );
  }
}
