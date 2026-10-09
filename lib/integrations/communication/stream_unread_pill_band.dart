// The 「↑ N 条未读 ×」 pill, docked above a channel's message list
// (decision 0134).
//
// Stream draws this pill in a `Stack` over its own list, `spacing.sm` from the
// list's top edge, so it covers whatever row the list rests on there. On a
// channel opened with unread messages Stream anchors the first unread message
// at the middle of the viewport, and the row at the top edge was the oldest
// day's chip: on the S123f device run 「9月28日」 sat under 「4 条未读」.
// Padding inside the list cannot help — with the list anchored on the unread
// message, extra space above the chip only grows the content upward,
// off-screen.
//
// So a LOOP channel list turns Stream's overlay off and this band shows the
// same Stream pill in its own strip above the list. While the channel reports
// unread messages the list starts below the pill and nothing is drawn under
// it; once the unread is read or dismissed the band collapses and the list
// takes the space back.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:stream_chat_flutter/scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The list configuration a LOOP channel list passes: whatever the app
/// configured, with Stream's own floating unread pill turned off because
/// [LoopStreamUnreadPillBand] shows it instead.
StreamMessageListViewConfiguration loopChannelListConfiguration(
  BuildContext context,
) =>
    StreamChatConfiguration.of(context).messageListViewConfiguration
        .copyWith(showUnreadIndicator: false);

/// A channel message list with the unread pill docked above it.
///
/// [list] must be a [StreamMessageListView] built with
/// [loopChannelListConfiguration] and the same [scrollController], which the
/// pill's 「↑」 uses to bring the first unread message to the middle of the
/// list, as Stream's own pill does.
class LoopStreamUnreadDockedList extends StatelessWidget {
  const LoopStreamUnreadDockedList({
    super.key,
    required this.scrollController,
    required this.list,
  });

  final ItemScrollController scrollController;
  final Widget list;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      LoopStreamUnreadPillBand(scrollController: scrollController),
      Expanded(child: list),
    ],
  );
}

/// The strip that holds the unread pill, empty and zero-high when nothing is
/// unread.
class LoopStreamUnreadPillBand extends StatelessWidget {
  const LoopStreamUnreadPillBand({super.key, required this.scrollController});

  final ItemScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final channelState = StreamChannel.maybeOf(context);
    final state = channelState?.channel.state;
    if (channelState == null || state == null) return const SizedBox.shrink();
    return StreamBuilder<Read?>(
      initialData: state.currentUserRead,
      stream: state.currentUserReadStream,
      builder: (context, snapshot) {
        final unread = (snapshot.data?.unreadMessages ?? 0) > 0;
        return AnimatedSize(
          duration: LoopMotion.of(context, LoopMotion.contentFadeIn),
          curve: LoopMotion.contentFadeCurve,
          alignment: Alignment.topCenter,
          child: unread
              ? Padding(
                  key: const ValueKey<String>('loop-unread-pill-band'),
                  padding: const EdgeInsets.only(top: LoopSpacing.x2),
                  child: Center(
                    child: UnreadIndicatorButton(
                      onJumpTap: (_) => _jumpToFirstUnread(channelState),
                      onDismissTap: () => _markRead(channelState.channel),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }

  /// Stream's own jump (`scrollToUnreadDefaultTapAction`): the first unread
  /// message, centred. The index is the one the list itself uses — the
  /// channel's messages through the default filter, newest first, after the
  /// list's two bottom slots.
  Future<void> _jumpToFirstUnread(StreamChannelState channelState) async {
    final firstUnread = channelState.getFirstUnreadMessage();
    final channel = channelState.channel;
    final messages = channel.state?.messages;
    if (firstUnread == null || messages == null) return;
    final filter = defaultMessageFilter(channel.client.state.currentUser?.id);
    final newestFirst = messages.where(filter).toList().reversed.toList();
    final index = newestFirst.lastIndexWhere((it) => it.id == firstUnread.id);
    if (index == -1 || !scrollController.isAttached) return;
    await scrollController.scrollTo(index: index + 2, alignment: 0.5);
  }

  /// Stream's own dismiss: the channel is marked read, which empties the
  /// read state and with it this band. A refusal leaves the pill where it is.
  Future<void> _markRead(Channel channel) async {
    try {
      await channel.markRead();
    } on Object catch (error) {
      debugPrint('LOOP unread pill: markRead failed: $error');
    }
  }
}
