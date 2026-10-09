/// LOOP's five message reactions: the glyph each one is drawn as and the word
/// that names it to a screen reader.
///
/// The keys are the reaction types stored on the provider (`like`, `haha`,
/// `love`, `wow`, `sad` — the provider's own quick set, so reactions already
/// on a message keep their meaning). LOOP draws none of them as a system
/// Emoji (decision 0117); decision 0121 drew five line glyphs for them in the
/// sprite's own pen (`assets/icons/i-react-*.svg`), replacing the single Han
/// characters that read as stray text on the device (report 2026-10-09 · 7).
const Map<String, String> loopReactionIconNames = <String, String>{
  'like': 'react-like',
  'haha': 'react-laugh',
  'love': 'react-heart',
  'wow': 'react-wow',
  'sad': 'react-sad',
};

/// The word each reaction is announced as, and printed as wherever a glyph
/// cannot be drawn.
const Map<String, String> loopReactionLabels = <String, String>{
  'like': '点赞',
  'haha': '大笑',
  'love': '喜欢',
  'wow': '惊讶',
  'sad': '难过',
};

/// The word a reaction that is not one of LOOP's five is drawn as.
///
/// Another client can store any type on a message; LOOP neither guesses an
/// Emoji for it nor prints the raw type string.
const String loopReactionFallbackLabel = '表态';

/// The word [type] is drawn as.
String loopReactionLabel(String type) =>
    loopReactionLabels[type] ?? loopReactionFallbackLabel;

/// The sprite glyph [type] is drawn as, or `null` for a type that is not one
/// of LOOP's five (it is then printed as [loopReactionFallbackLabel]).
String? loopReactionIconName(String type) => loopReactionIconNames[type];
