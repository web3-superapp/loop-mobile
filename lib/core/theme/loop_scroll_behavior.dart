import 'package:flutter/material.dart';

/// Product-wide scroll behaviour.
///
/// Android 12+ ships a stretch overscroll effect that scales the whole
/// scrolled page while the finger drags past the edge, which visibly distorts
/// avatars and cards on every LOOP screen (seen on the LOOP ID page during
/// emulator acceptance). LOOP draws no overscroll indicator at all: the page
/// stops at its edge on Android and keeps the platform bounce on iOS, where
/// the physics come from the platform and not from an indicator.
///
/// Decision 0234: dragging any scroll view puts the soft keyboard away
/// (`onDrag`), so a page or sheet with an input never traps the keyboard.
/// A scroll view that passes its own `keyboardDismissBehavior` keeps it —
/// Stream's message list does.
class LoopScrollBehavior extends MaterialScrollBehavior {
  const LoopScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) => ScrollViewKeyboardDismissBehavior.onDrag;
}
