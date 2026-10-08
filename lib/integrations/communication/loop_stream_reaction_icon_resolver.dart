import 'package:loop_mobile/integrations/communication/loop_reactions.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show ReactionIconResolver, StreamEmojiContent, StreamUnicodeEmoji;

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
///   Emoji catalogue filtered by this set; with nothing supported it offers
///   nothing, rather than a grid of system Emoji.
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
