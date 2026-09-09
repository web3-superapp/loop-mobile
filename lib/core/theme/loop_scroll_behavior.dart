import 'package:flutter/material.dart';

/// Product-wide scroll behaviour.
///
/// Android 12+ ships a stretch overscroll effect that scales the whole
/// scrolled page while the finger drags past the edge, which visibly distorts
/// avatars and cards on every LOOP screen (seen on the LOOP ID page during
/// emulator acceptance). LOOP draws no overscroll indicator at all: the page
/// stops at its edge on Android and keeps the platform bounce on iOS, where
/// the physics come from the platform and not from an indicator.
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
}
