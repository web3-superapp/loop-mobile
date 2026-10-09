import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/communication/loop_reactions.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show
        DefaultStreamReactionPicker,
        ReactionIconResolver,
        StreamChatConfiguration,
        StreamEmojiContent,
        StreamIntrinsicBoundedCrossAxis,
        StreamIntrinsicColumn,
        StreamMessageAlignment,
        StreamMessageLayout,
        StreamReactionPickerProps,
        StreamReactionsItem,
        StreamReactionsProps,
        StreamThemeExtension,
        StreamUnicodeEmoji;

/// The reaction resolver every Stream message widget in LOOP reads.
///
/// Stream's `DefaultReactionIconResolver` renders each reaction as a system
/// Emoji. LOOP renders none (decision 0117). LOOP's own reaction bar
/// ([loopStreamReactionPickerBuilder]) and the chips under a bubble
/// ([loopStreamReactionsBuilder]) draw the sprite glyph for each type
/// (decision 0121) and never read this content; it only reaches a Stream
/// surface LOOP has not replaced, which then prints the reaction's word.
/// Stream's content model is sealed to a Unicode string or an image URL, so
/// the word travels as the "Unicode" content — it is plain text.
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

/// One reaction drawn as LOOP's glyph, or as its word when [type] is not one
/// of the five.
class LoopReactionGlyph extends StatelessWidget {
  const LoopReactionGlyph({
    required this.type,
    required this.size,
    required this.color,
    super.key,
  });

  final String type;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = loopReactionIconName(type);
    if (icon == null) {
      return Text(
        loopReactionLabel(type),
        style: LoopType.captionSm.copyWith(color: color),
      );
    }
    return LoopIcon(
      icon,
      key: ValueKey<String>('loop-reaction-glyph-$type'),
      size: size,
      color: color,
    );
  }
}

/// The long-press reaction bar, without the 「+」 when there is nothing
/// behind it (decision 0117), drawn with LOOP's glyphs (decision 0121).
///
/// Stream's `DefaultStreamReactionPicker` always pins a 「+」 at the trailing
/// edge that opens the Emoji catalogue filtered by
/// `ReactionIconResolver.supportedReactions`. LOOP's resolver supports none,
/// so the button opened an empty sheet. When the configured resolver
/// supports nothing, this builder draws the quick reactions — LOOP's five
/// glyphs — in Stream's own bar shape and omits the 「+」; any other resolver
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

/// Stream's reaction bar with the quick reactions only: five 28px glyphs on
/// 48px targets, the member's own reaction in Lime.
class LoopStreamReactionBar extends StatelessWidget {
  const LoopStreamReactionBar({required this.props, super.key});

  /// The glyph's size inside its 48px target.
  static const double glyphSize = 28;

  /// LOOP's 44px touch floor; Stream's default target is 40.
  static const double targetSize = 48;

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
              Semantics(
                key: Key(item.key),
                button: true,
                selected: item.isSelected,
                label: loopReactionLabel(item.key),
                excludeSemantics: true,
                child: InkResponse(
                  onTap: onPicked == null ? null : () => onPicked(item),
                  radius: targetSize / 2,
                  child: SizedBox.square(
                    dimension: targetSize,
                    child: Center(
                      child: LoopReactionGlyph(
                        type: item.key,
                        size: glyphSize,
                        color: item.isSelected
                            ? LoopColors.lime
                            : LoopColors.chalk,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The reactions on a message: small 「glyph + count」 capsules under the
/// bubble, from its leading edge (decision 0121).
///
/// Stream's default puts them on the bubble's top trailing corner,
/// overlapping it, and prints a count only once one reaction has two; on
/// the device they read as misplaced (report 2026-10-09 · 7). LOOP's are
/// laid out the same way in a group and in a direct message: the bubble,
/// then one row of capsules starting at the bubble's own leading edge — the
/// left edge of an incoming bubble and of an outgoing one alike. The
/// capsules are labels; `onReactionPressed` is not wired, because LOOP's
/// message items leave the detail sheet shut anyway.
Widget loopStreamReactionsBuilder(
  BuildContext context,
  StreamReactionsProps props,
) => LoopStreamReactions(props: props);

class LoopStreamReactions extends StatelessWidget {
  const LoopStreamReactions({required this.props, super.key});

  final StreamReactionsProps props;

  @override
  Widget build(BuildContext context) {
    final child = props.child;
    if (props.items.isEmpty) return child ?? const SizedBox.shrink();
    final strip = Wrap(
      key: const ValueKey<String>('loop-reaction-strip'),
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final item in props.items) LoopReactionCapsule(item: item),
      ],
    );
    if (child == null) return strip;
    final alignment = StreamMessageLayout.messageAlignmentOf(context);
    return StreamIntrinsicColumn(
      spacing: 4,
      crossAxisAlignment: switch (alignment) {
        StreamMessageAlignment.start => CrossAxisAlignment.start,
        StreamMessageAlignment.end => CrossAxisAlignment.end,
      },
      clipBehavior: props.clipBehavior,
      children: <Widget>[
        StreamIntrinsicBoundedCrossAxis(child: child),
        Align(alignment: AlignmentDirectional.centerStart, child: strip),
      ],
    );
  }
}

/// The reaction types the reader has put on the message being built.
///
/// `LoopStreamMessageRow` provides it around every LOOP message item, so a
/// capsule can light the reader's own reaction (decision 0121). Outside a
/// row nothing is lit.
class LoopOwnReactionScope extends InheritedWidget {
  const LoopOwnReactionScope({
    required this.types,
    required super.child,
    super.key,
  });

  final Set<String> types;

  static Set<String> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LoopOwnReactionScope>()
          ?.types ??
      const <String>{};

  @override
  bool updateShouldNotify(LoopOwnReactionScope oldWidget) =>
      !setEquals(types, oldWidget.types);
}

/// One 「glyph + count」 capsule under a bubble (OKX reference, S121 §1.1.1):
/// a 16px glyph and a 12px count on a dark grey pill; the reader's own
/// reaction has a Lime edge and a Lime glyph.
///
/// It is a label, not a control: LOOP keeps Stream's reaction detail sheet
/// shut in groups and in direct messages alike (decision 0117), so a tap on
/// a capsule has nothing to open, and a 24px capsule is no touch target.
/// Reacting is done from the long-press bar.
class LoopReactionCapsule extends StatelessWidget {
  const LoopReactionCapsule({required this.item, super.key});

  final StreamReactionsItem item;

  @override
  Widget build(BuildContext context) {
    final type = item.key ?? '';
    final count = item.count ?? 1;
    final own = LoopOwnReactionScope.of(context).contains(type);
    final capsule = Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: LoopColors.elevated,
        border: own ? Border.all(color: LoopColors.lime) : null,
        borderRadius: LoopRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LoopReactionGlyph(
            type: type,
            size: 16,
            color: own ? LoopColors.lime : LoopColors.chalk,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: LoopType.caption.copyWith(
              color: LoopColors.text2,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      key: ValueKey<String>('loop-reaction-capsule-$type'),
      selected: own,
      label: '${loopReactionLabel(type)} $count',
      excludeSemantics: true,
      child: capsule,
    );
  }
}
