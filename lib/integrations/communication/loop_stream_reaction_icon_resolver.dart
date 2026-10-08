import 'package:flutter/material.dart';
import 'package:loop_mobile/integrations/communication/loop_reactions.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show
        DefaultStreamReactionPicker,
        ReactionIconResolver,
        StreamChatConfiguration,
        StreamEmojiButton,
        StreamEmojiButtonSize,
        StreamEmojiContent,
        StreamReactionPickerProps,
        StreamThemeExtension,
        StreamUnicodeEmoji;

/// The reaction resolver every Stream message widget in LOOP reads.
///
/// Stream's `DefaultReactionIconResolver` renders each reaction as a system
/// Emoji. LOOP renders none (decision 0117): the reaction bar, the chips under
/// a bubble and the reaction detail sheet draw the word from
/// [loopReactionLabels] instead. Stream's content model is sealed to a
/// Unicode string or an image URL, so the word travels as the "Unicode"
/// content — it is plain text, laid out by the platform's own CJK face.
///
/// Two consequences are deliberate:
///
/// * [supportedReactions] is empty. The picker's 「+」 opens Stream's full
///   Emoji catalogue filtered by this set; with nothing supported there is
///   nothing to open, and [loopStreamReactionPickerBuilder] drops the 「+」.
/// * [emojiCode] answers `null`, so a reaction LOOP sends carries no Emoji
///   code for another client to render.
final class LoopStreamReactionIconResolver extends ReactionIconResolver {
  const LoopStreamReactionIconResolver();

  @override
  Set<String> get defaultReactions => loopReactionLabels.keys.toSet();

  @override
  Set<String> get supportedReactions => const <String>{};

  @override
  String? emojiCode(String type) => null;

  @override
  StreamEmojiContent resolve(String type) =>
      StreamUnicodeEmoji(loopReactionLabel(type));
}

/// The long-press reaction bar, without the 「+」 when there is nothing
/// behind it (decision 0117).
///
/// Stream's `DefaultStreamReactionPicker` always pins a 「+」 at the trailing
/// edge that opens the Emoji catalogue filtered by
/// `ReactionIconResolver.supportedReactions`. LOOP's resolver supports none,
/// so the button opened an empty sheet. When the configured resolver
/// supports nothing, this builder draws the quick reactions — LOOP's five
/// words — in Stream's own bar shape and omits the 「+」; any other resolver
/// gets Stream's default picker unchanged.
Widget loopStreamReactionPickerBuilder(
  BuildContext context,
  StreamReactionPickerProps props,
) {
  final resolver = StreamChatConfiguration.of(context).reactionIconResolver;
  if (resolver.supportedReactions.isNotEmpty) {
    return DefaultStreamReactionPicker(props: props);
  }
  return LoopStreamReactionBar(props: props);
}

/// Stream's reaction bar with the quick reactions only.
class LoopStreamReactionBar extends StatelessWidget {
  const LoopStreamReactionBar({required this.props, super.key});

  final StreamReactionPickerProps props;

  @override
  Widget build(BuildContext context) {
    final theme = context.streamReactionPickerTheme;
    final colors = context.streamColorScheme;
    final spacing = context.streamSpacing;
    final radius = context.streamRadius;
    final shape =
        (theme.shape ??
                RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(radius.xxxxl),
                ))
            .copyWith(
              side: theme.side ?? BorderSide(color: colors.borderDefault),
            );
    final onPicked = props.onReactionPicked;
    return Material(
      key: const ValueKey<String>('loop-reaction-bar'),
      shape: shape,
      elevation: theme.elevation ?? 3,
      clipBehavior: Clip.antiAlias,
      color: theme.backgroundColor ?? colors.backgroundElevation2,
      child: SingleChildScrollView(
        padding:
            theme.padding ??
            EdgeInsetsDirectional.symmetric(horizontal: spacing.xxs),
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.spacing ?? spacing.xxxs,
          children: <Widget>[
            for (final item in props.items)
              StreamEmojiButton(
                key: Key(item.key),
                // 48px: LOOP's 44px touch floor; Stream's default is 40.
                size: StreamEmojiButtonSize.xl,
                emoji: item.emoji,
                isSelected: item.isSelected,
                onPressed: onPicked == null ? null : () => onPicked(item),
              ),
          ],
        ),
      ),
    );
  }
}
