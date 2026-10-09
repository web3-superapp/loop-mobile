import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// `.sheet` + `.veil` (chapter 5.5): bottom sheet with top-only 26px radius,
/// Line2 top edge, Ink ground with a faint Lime glow, veil rgba(5,6,4,.76),
/// max height minus both safe areas. The barrier is a real ModalBarrier
/// (background is inert) and focus returns to the opener when it closes.
Future<T?> showLoopSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String barrierLabel = '关闭弹层',
  bool isDismissible = true,

  /// Decision 0128 (B3): every sheet goes on the root navigator, over the
  /// floating tab bar. A sheet opened from a tab page used to land on the
  /// branch navigator, under the bar, and its last row could not be tapped.
  /// Passing `false` is refused by the harness.
  bool useRootNavigator = true,

  /// Whether a downward drag closes the sheet. Defaults to [isDismissible].
  /// A drag closes the route directly, past any `PopScope` inside the sheet,
  /// so a sheet that must stay open for a while turns it off.
  bool? enableDrag,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final result = await showModalBottomSheet<T>(
    context: context,
    // A sheet opened from a tab page would be pushed on the tab's own
    // navigator, which the floating tab bar is painted over: the last row
    // of a tall sheet sat under it (S106b, S123 B3). The root navigator lays
    // the sheet and its veil over the bar instead.
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag ?? isDismissible,
    barrierColor: LoopColors.veil,
    barrierLabel: barrierLabel,
    backgroundColor: Colors.transparent,
    elevation: 0,
    transitionAnimationController: reduceMotion
        ? AnimationController(
            vsync: Navigator.of(context, rootNavigator: useRootNavigator),
            duration: Duration.zero,
          )
        : null,
    builder: (context) => LoopSheet(child: builder(context)),
  );
  // Focus restoration: the opener regains focus after the sheet closes.
  if (previousFocus != null && previousFocus.context?.mounted == true) {
    previousFocus.requestFocus();
  }
  return result;
}

const BorderRadius _radius = BorderRadius.vertical(top: Radius.circular(26));

/// The sheet surface itself (also usable inline for showcase pages).
class LoopSheet extends StatelessWidget {
  const LoopSheet({required this.child, super.key, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A modal bottom sheet is not moved by the keyboard on its own: on an
    // iPhone the 二次验证 sheet's code field and its buttons sat under the
    // keypad (2026-09-22). The sheet gives up the keyboard's height at its
    // foot, so its scroll view shrinks and the focused field is scrolled
    // into what is left.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboard),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Semantics(
        scopesRoute: true,
        namesRoute: title != null,
        label: title,
        explicitChildNodes: true,
        child: FocusScope(
          autofocus: true,
          child: Container(
            key: const ValueKey<String>('loop-sheet'),
            // The sheet's own ground, and nothing else in this decoration.
            // Flutter paints a gradient *instead of* the colour declared beside
            // it, so an Ink ground and a Lime glow cannot share one box: with
            // both declared the sheet painted only the 5% glow and the page
            // underneath read straight through the words on it.
            decoration: const BoxDecoration(
              color: LoopColors.ink,
              borderRadius: _radius,
              border: Border(top: BorderSide(color: LoopColors.line2)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0xD1050604),
                  offset: Offset(0, -20),
                  blurRadius: 60,
                ),
              ],
            ),
            // The glow sits on that ground as its own layer.
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -1),
                  radius: 1.1,
                  colors: <Color>[Color(0x0DB8FF20), Color(0x00B8FF20)],
                  stops: <double>[0, 0.64],
                ),
                borderRadius: _radius,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          title!,
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                    Flexible(child: SingleChildScrollView(child: child)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
