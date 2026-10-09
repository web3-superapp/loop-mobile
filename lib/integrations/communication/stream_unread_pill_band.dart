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
//
// Decision 0135: the pill is drawn here rather than by Stream's
// `UnreadIndicatorButton`, whose two buttons were Stream's small 32 pt
// ghosts. The pill looks the same — Stream's own theme tokens, sizes and
// spacing — but each of its two parts is a [LoopPressable] at least 44 pt
// square that dims while held and plays a light touch when it lands.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
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
        final count = snapshot.data?.unreadMessages ?? 0;
        final unread = count > 0;
        return AnimatedSize(
          duration: LoopMotion.of(context, LoopMotion.contentFadeIn),
          curve: LoopMotion.contentFadeCurve,
          alignment: Alignment.topCenter,
          child: unread
              ? Padding(
                  key: const ValueKey<String>('loop-unread-pill-band'),
                  // The pill's face keeps its old place, [LoopSpacing.x2]
                  // below the band's top; its touch area reaches above it.
                  padding: EdgeInsets.only(
                    top: math.max(
                      0,
                      LoopSpacing.x2 -
                          LoopUnreadJumpPill.verticalBleed(context),
                    ),
                  ),
                  child: Center(
                    child: LoopUnreadJumpPill(
                      label: context.translations.unreadCountIndicatorLabel(
                        unreadCount: count,
                      ),
                      onJump: () => unawaited(_jumpToFirstUnread(channelState)),
                      onDismiss: () =>
                          unawaited(_markRead(channelState.channel)),
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

/// The 「↑ N 条未读 ×」 pill: Stream's jump-to-unread look, with two touch
/// targets of at least [LoopTouch.minimum] (decision 0135).
///
/// The face — background, border, elevation, icon and label — is sized and
/// coloured from Stream's theme exactly as `DefaultStreamJumpToUnreadButton`
/// draws it. The touch areas are laid over it and reach past its edges where
/// the face is smaller than 44 pt, so the visible pill does not grow.
class LoopUnreadJumpPill extends StatelessWidget {
  const LoopUnreadJumpPill({
    super.key,
    required this.label,
    required this.onJump,
    required this.onDismiss,
  });

  final String label;
  final VoidCallback onJump;
  final VoidCallback onDismiss;

  /// Stream's small button: the jump label's height and the dismiss square.
  static const double _button = 32;

  /// Stream's icon size inside both buttons.
  static const double _icon = 16;

  static double _faceHeight(BuildContext context) =>
      _button + 2 * context.streamSpacing.xxs;

  /// How far the touch areas reach above and below the face.
  static double verticalBleed(BuildContext context) =>
      math.max(0, (LoopTouch.minimum - _faceHeight(context)) / 2);

  @override
  Widget build(BuildContext context) {
    final colors = context.streamColorScheme;
    final spacing = context.streamSpacing;
    final icons = context.streamIcons;
    final radius = context.streamRadius;
    final text = context.streamTextTheme;
    final side = BorderSide(color: colors.borderDefault);
    final pad = spacing.xxs;
    final bleed = verticalBleed(context);
    final height = _faceHeight(context) + 2 * bleed;
    // The dismiss square sits after the divider gap, as in Stream's row; its
    // touch area is [LoopTouch.minimum] wide, so it reaches past the face's
    // right edge by [overhang]. The jump side reaches as far past the left
    // edge, which keeps the face centred where it was.
    final dismissWidth = math.max(LoopTouch.minimum, pad + _button + pad);
    final overhang = dismissWidth - (pad + _button + pad);
    return SizedBox(
      key: const ValueKey<String>('loop-unread-pill'),
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: overhang,
            right: overhang,
            top: bleed,
            bottom: bleed,
            child: Material(
              key: const ValueKey<String>('loop-unread-pill-face'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(radius.max),
                side: side,
              ),
              elevation: 3,
              shadowColor: Theme.of(context).shadowColor,
              color: colors.backgroundElevation1,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MergeSemantics(
                child: Semantics(
                  button: true,
                  child: LoopPressable(
                    key: const ValueKey<String>('loop-unread-pill-jump'),
                    haptic: LoopHaptic.light,
                    onTap: onJump,
                    child: SizedBox(
                      height: height,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: overhang + pad,
                          right: pad,
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.xs,
                              vertical: spacing.xxs,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: spacing.xs,
                              children: <Widget>[
                                Icon(
                                  icons.arrowUp,
                                  size: _icon,
                                  color: colors.textPrimary,
                                ),
                                Text(
                                  label,
                                  maxLines: 1,
                                  style: text.captionEmphasis.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: side.width,
                height: _button,
                child: ColoredBox(color: side.color),
              ),
              Semantics(
                button: true,
                label: '标为已读',
                child: LoopPressable(
                  key: const ValueKey<String>('loop-unread-pill-dismiss'),
                  haptic: LoopHaptic.light,
                  onTap: onDismiss,
                  child: SizedBox(
                    width: dismissWidth,
                    height: height,
                    child: Padding(
                      padding: EdgeInsets.only(left: pad),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox.square(
                          dimension: _button,
                          child: Icon(
                            icons.xmark,
                            size: _icon,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
