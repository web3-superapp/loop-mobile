import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// `.toast-ok / .toast-warn / .toast-err`.
enum LoopToastKind { ok, warn, err }

/// Toast controller (chapter 5.5): one toast at a time, fixed above the tab
/// bar (`bottom: 94px` + safe area), z 90, 2.6 s, `role=status` /
/// `aria-live=polite` expressed as a Semantics live region.
///
/// Host it once above the router with [LoopToastHost]; call
/// [LoopToast.show] from anywhere with a `BuildContext`.
abstract final class LoopToast {
  static const Duration defaultDuration = Duration(milliseconds: 2600);

  /// Clearance over the floating tab bar, on the five routes that have one.
  static const double bottomOffset = 94;

  /// Clearance on a route with no tab bar: the page gutter, nothing more.
  ///
  /// The tab-bar reserve is 94px of chrome that a pushed child page does not
  /// draw. Applied there it did not lift the toast over anything — it parked
  /// it in the middle of the page's content, and on the voice room that is
  /// exactly where the 「加入语音房」 button is. A toast is allowed to cover
  /// the foot of a page; it is not allowed to cover its primary action.
  static const double pageBottomOffset = LoopSpacing.page;

  static void show(
    BuildContext context, {
    required String message,
    LoopToastKind kind = LoopToastKind.ok,
    Duration? duration,
  }) {
    final host = LoopToastHost.maybeOf(context);
    assert(host != null, 'LoopToastHost is missing above this context.');
    host?.show(
      message: message,
      kind: kind,
      duration: duration,
      // The host sits above the router and cannot tell which page called it;
      // the caller's own context can.
      clearsTabBar: LoopTabBarScope.of(context),
    );
  }
}

/// Marks the subtree that the floating tab bar sits under.
///
/// The five tab routes render inside the shell that draws the bar; every
/// other route is pushed above the shell and has no bar at all. A route below
/// a pushed page stays mounted, so the bar's own widget being alive says
/// nothing — the calling page's position in the tree does.
class LoopTabBarScope extends InheritedWidget {
  const LoopTabBarScope({required super.child, super.key});

  /// Whether [context] is inside the shell that draws the tab bar.
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LoopTabBarScope>() != null;

  @override
  bool updateShouldNotify(LoopTabBarScope oldWidget) => false;
}

@immutable
final class LoopToastEntry {
  const LoopToastEntry({
    required this.message,
    required this.kind,
    this.clearsTabBar = false,
  });

  final String message;
  final LoopToastKind kind;

  /// True when the page that raised this toast draws the floating tab bar.
  final bool clearsTabBar;
}

/// Owns the single visible toast. Place inside `MaterialApp.builder`.
class LoopToastHost extends StatefulWidget {
  const LoopToastHost({required this.child, super.key});

  final Widget child;

  static LoopToastHostState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<LoopToastHostState>();
  }

  @override
  State<LoopToastHost> createState() => LoopToastHostState();
}

class LoopToastHostState extends State<LoopToastHost> {
  LoopToastEntry? _entry;
  bool _visible = false;
  Timer? _hideTimer;
  Timer? _clearTimer;

  LoopToastEntry? get current => _entry;

  void show({
    required String message,
    required LoopToastKind kind,
    Duration? duration,
    bool clearsTabBar = false,
  }) {
    _hideTimer?.cancel();
    _clearTimer?.cancel();
    setState(() {
      _entry = LoopToastEntry(
        message: message,
        kind: kind,
        clearsTabBar: clearsTabBar,
      );
      _visible = true;
    });
    _hideTimer = Timer(duration ?? LoopToast.defaultDuration, dismiss);
  }

  void dismiss() {
    _hideTimer?.cancel();
    if (!mounted || !_visible) return;
    setState(() => _visible = false);
    _clearTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted && !_visible) setState(() => _entry = null);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: <Widget>[
        widget.child,
        if (entry != null)
          Positioned(
            left: LoopSpacing.page,
            right: LoopSpacing.page,
            bottom:
                (entry.clearsTabBar
                    ? LoopToast.bottomOffset
                    : LoopToast.pageBottomOffset) +
                safeBottom,
            child: IgnorePointer(
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, 0.18),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: LoopToastView(entry: entry),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The toast surface: Chalk ground, Ink text, 4px semantic bar on the left
/// (Lime for ok, Ink for warn/err), radius 15, sprite glyph.
class LoopToastView extends StatelessWidget {
  const LoopToastView({required this.entry, super.key});

  final LoopToastEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, bar, label) = switch (entry.kind) {
      LoopToastKind.ok => ('check', LoopColors.lime, '成功'),
      LoopToastKind.warn => ('warn', LoopColors.ink, '警告'),
      LoopToastKind.err => ('close', LoopColors.ink, '错误'),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$label：${entry.message}',
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey<String>('loop-toast-${entry.kind.name}'),
          decoration: const BoxDecoration(
            color: LoopColors.chalk,
            borderRadius: BorderRadius.all(Radius.circular(15)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x9E050604),
                offset: Offset(0, 14),
                blurRadius: 38,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(width: 4, color: bar),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                    child: Row(
                      children: <Widget>[
                        LoopIcon(icon, size: 15, color: LoopColors.ink),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            entry.message,
                            style: LoopTypography.label(
                              12,
                              weight: FontWeight.w700,
                              color: LoopColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
