import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/platform/loop_android_sdk.dart';
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

  /// [clearsTabBar] is for the one caller that is not a page: the voice room
  /// strip sits above the router, so its context is above every tab scope and
  /// would always read `false`. It tells this directly, from the route the
  /// router is actually on. Every page leaves it null and is answered by its
  /// own position in the tree.
  static void show(
    BuildContext context, {
    required String message,
    LoopToastKind kind = LoopToastKind.ok,
    Duration? duration,
    bool? clearsTabBar,
  }) {
    final host = LoopToastHost.maybeOf(context);
    final clears = clearsTabBar ?? LoopTabBarScope.of(context);
    if (host == null) {
      // Decision 0130 made this the only transient message LOOP shows (the
      // SnackBars are gone), so a subtree mounted without the application's
      // host — a sheet built on its own, a page in a test — still gets the
      // same toast, laid on the nearest overlay for the same duration.
      _showOnOverlay(
        context,
        LoopToastEntry(message: message, kind: kind, clearsTabBar: clears),
        duration ?? defaultDuration,
      );
      return;
    }
    host.show(
      message: message,
      kind: kind,
      duration: duration,
      // The host sits above the router and cannot tell which page called it;
      // the caller's own context can.
      clearsTabBar: clears,
    );
  }

  static OverlayEntry? _overlayEntry;

  static void _showOnOverlay(
    BuildContext context,
    LoopToastEntry entry,
    Duration duration,
  ) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final previous = _overlayEntry;
    if (previous != null && previous.mounted) previous.remove();
    late final OverlayEntry inserted;
    inserted = OverlayEntry(
      builder: (context) => _OverlayToast(
        entry: entry,
        duration: duration,
        onDone: () {
          if (inserted.mounted) inserted.remove();
          if (identical(_overlayEntry, inserted)) _overlayEntry = null;
        },
      ),
    );
    _overlayEntry = inserted;
    overlay.insert(inserted);
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
  @override
  void initState() {
    super.initState();
    // Decision 0130: the copy path needs to know, synchronously, whether
    // the system confirms clipboard writes itself. The host is mounted once
    // at start-up, so the one platform read happens here, long before the
    // first copy.
    unawaited(LoopAndroidSdk.level());
  }

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

/// The overlay-borne toast used when no [LoopToastHost] is above the caller.
///
/// Its timer belongs to its own state, so it ends with the tree it was laid
/// on and never outlives it.
class _OverlayToast extends StatefulWidget {
  const _OverlayToast({
    required this.entry,
    required this.duration,
    required this.onDone,
  });

  final LoopToastEntry entry;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_OverlayToast> createState() => _OverlayToastState();
}

class _OverlayToastState extends State<_OverlayToast> {
  Timer? _life;

  @override
  void initState() {
    super.initState();
    _life = Timer(widget.duration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _life?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: LoopSpacing.page,
    right: LoopSpacing.page,
    bottom:
        (widget.entry.clearsTabBar
            ? LoopToast.bottomOffset
            : LoopToast.pageBottomOffset) +
        MediaQuery.paddingOf(context).bottom,
    child: IgnorePointer(child: LoopToastView(entry: widget.entry)),
  );
}
