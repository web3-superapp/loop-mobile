import 'package:flutter/widgets.dart';

/// Asks again for the read that left a page with nothing to show.
///
/// It answers only "the read finished"; what it answered is published by the
/// observation itself, so a caller can show a running state without ever
/// having to decide whether the page recovered.
typedef LoopPageRetry = Future<void> Function();

/// Carries the re-read down to a whole-page block.
///
/// A blocked page has no scrolling region, so the scaffolds deliberately
/// withhold pull-to-refresh while it is blocked. That left the one block whose
/// own sentence asks the owner to try again with nothing to press, and the
/// page did not heal when the network came back — it took leaving the page and
/// returning to it.
///
/// The scope exists so the action reaches the block without threading a
/// callback through all 43 gates that can close a page. The application
/// composition installs it and decides what "ask again" means; a tree without
/// it simply offers no retry, which is what a block pumped on its own gets.
class LoopPageRecoveryScope extends InheritedWidget {
  const LoopPageRecoveryScope({
    required this.retry,
    required super.child,
    super.key,
  });

  /// `null` when this tree has no re-read to offer.
  final LoopPageRetry? retry;

  static LoopPageRetry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LoopPageRecoveryScope>()
      ?.retry;

  @override
  bool updateShouldNotify(LoopPageRecoveryScope oldWidget) =>
      oldWidget.retry != retry;
}
