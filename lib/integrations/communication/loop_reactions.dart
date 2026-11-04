import 'package:loop_mobile/l10n/loop_l10n.dart';

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
Map<String, String> loopReactionLabels = <String, String>{
  'like': LoopL10n.current.integrations_reactionsS,
  'haha': LoopL10n.current.integrations_reactionsS2,
  'love': LoopL10n.current.integrations_reactionsS3,
  'wow': LoopL10n.current.integrations_reactionsS4,
  'sad': LoopL10n.current.integrations_reactionsS5,
};

/// The word a reaction that is not one of LOOP's five is drawn as.
///
/// Another client can store any type on a message; LOOP neither guesses an
/// Emoji for it nor prints the raw type string.
String get loopReactionFallbackLabel =>
    LoopL10n.current.integrations_reactionsLoopReactionFallbackLabel;

/// The word [type] is drawn as.
String loopReactionLabel(String type) =>
    loopReactionLabels[type] ?? loopReactionFallbackLabel;

/// The sprite glyph [type] is drawn as, or `null` for a type that is not one
/// of LOOP's five (it is then printed as [loopReactionFallbackLabel]).
String? loopReactionIconName(String type) => loopReactionIconNames[type];
