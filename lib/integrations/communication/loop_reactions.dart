/// LOOP's five message reactions and the word each one is drawn as.
///
/// The keys are the reaction types stored on the provider (`like`, `haha`,
/// `love`, `wow`, `sad` — the provider's own quick set, so reactions already
/// on a message keep their meaning). LOOP draws none of them as a system
/// Emoji: the icon set has no glyph for any of the five, so each is the one
/// Han character that names it (decision 0117).
const Map<String, String> loopReactionLabels = <String, String>{
  'like': '赞',
  'haha': '哈',
  'love': '心',
  'wow': '哇',
  'sad': '叹',
};

/// The word a reaction that is not one of LOOP's five is drawn as.
///
/// Another client can store any type on a message; LOOP neither guesses an
/// Emoji for it nor prints the raw type string.
const String loopReactionFallbackLabel = '表态';

/// The word [type] is drawn as.
String loopReactionLabel(String type) =>
    loopReactionLabels[type] ?? loopReactionFallbackLabel;
