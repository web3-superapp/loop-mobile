import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_controllers.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

/// Whether the 意见反馈 entry is drawn: the build switch is on and a
/// session may enter the product (S332 · decision 0262).
final betaFeedbackEntryVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(loopFeatureSwitchesProvider).betaFeedbackVisible) {
    return false;
  }
  return ref.watch(
    loopSessionProvider.select((session) => session.canEnterProduct),
  );
});

/// The floating 意见反馈 key over the five tabs (S332 · decision 0262;
/// S337 · decision 0266 turned the glass capsule into this key).
///
/// A 56 Yellow square, radius 16, an Ink glyph over the word, on the right
/// edge, 12 above the tab bar by default — or, where a page keeps its own
/// floating key in that corner (聊天's 「发起」), 12 above that key: the
/// shell passes the difference as [floorLift]. It can be dragged anywhere;
/// let go, it slides back onto the right edge at the height it was left,
/// never lower than its default place, so it never covers the bar or the
/// other key. The height is kept for the run. Under reduced motion it jumps
/// back instead of sliding. It steps aside while the keyboard is up.
///
/// It lives inside `LoopShell`, so every page pushed over the tabs covers
/// it, and the credential pages never have it.
class BetaFeedbackEntry extends ConsumerStatefulWidget {
  const BetaFeedbackEntry({
    required this.location,
    required this.lowestBottom,
    required this.onOpen,
    this.floorLift = 0,
    super.key,
  });

  /// The router location under the entry, carried into the form.
  final String location;

  /// The distance from the screen's bottom edge to the key's lowest place:
  /// the tab bar's reserve, the safe area and 12.
  final double lowestBottom;

  /// How far above [lowestBottom] this page's default place is, and the
  /// lowest it may be dragged to here: `0` on most pages; on 聊天 the
  /// 「发起」 key's height, so the two never overlap.
  final double floorLift;

  final ValueChanged<BetaFeedbackOrigin> onOpen;

  /// The drawn key, which is also its touch target.
  static const double size = 56;

  /// The touch target: the key itself.
  static const double targetHeight = size;

  static const double radius = 16;

  static const double glyphSize = 22;

  /// The gap over the tab bar, or over the page's own floating key, at the
  /// default place.
  static const double gapOverTabBar = 12;

  static const Duration snapDuration = Duration(milliseconds: 220);

  static const String label = '意见反馈';

  @override
  ConsumerState<BetaFeedbackEntry> createState() => _BetaFeedbackEntryState();
}

class _BetaFeedbackEntryState extends ConsumerState<BetaFeedbackEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: BetaFeedbackEntry.snapDuration,
  );

  /// Leftward pull from the right edge while dragging (≥ 0).
  double _pull = 0;
  double _pullAtRelease = 0;

  /// The lift over [BetaFeedbackEntry.lowestBottom] while dragging.
  double? _dragLift;

  @override
  void initState() {
    super.initState();
    _snap.addListener(() {
      setState(() {
        _pull =
            _pullAtRelease * (1 - Curves.easeOutCubic.transform(_snap.value));
      });
    });
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  double _maximumLift(BoxConstraints constraints, EdgeInsets padding) {
    final top = padding.top + LoopLayout.topbarContentHeight;
    return math.max(
      0,
      constraints.maxHeight -
          top -
          widget.lowestBottom -
          BetaFeedbackEntry.targetHeight,
    );
  }

  void _open() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    widget.onOpen(
      BetaFeedbackOrigin(
        route: widget.location,
        locale: locale.toLanguageTag(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(betaFeedbackEntryVisibleProvider)) {
      return const SizedBox.shrink();
    }
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final padding = MediaQuery.paddingOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final storedLift = ref.watch(betaFeedbackEntryLiftProvider);
    final rightInset = math.max(LoopLayout.tabBarInset, padding.right);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maximumLift = _maximumLift(constraints, padding);
        final minimumLift = math.min(
          math.max(0.0, widget.floorLift),
          maximumLift,
        );
        final lift = (_dragLift ?? storedLift).clamp(minimumLift, maximumLift);
        final maximumPull = math.max(
          0.0,
          constraints.maxWidth - rightInset - BetaFeedbackEntry.size,
        );
        // The tap is the key's own pressable; the detector around it only
        // moves it.
        final key = Semantics(
          button: true,
          label: BetaFeedbackEntry.label,
          excludeSemantics: true,
          onTap: _open,
          child: LoopPressable(onTap: _open, child: const _BetaFeedbackKey()),
        );
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              key: const ValueKey<String>('beta-feedback-entry-position'),
              right: rightInset + _pull.clamp(0.0, maximumPull),
              bottom: widget.lowestBottom + lift,
              child: GestureDetector(
                key: const ValueKey<String>('beta-feedback-entry'),
                behavior: HitTestBehavior.opaque,
                // The key stays under the finger from the first move.
                dragStartBehavior: DragStartBehavior.down,
                onPanStart: (_) {
                  _snap.stop();
                  setState(() => _dragLift = lift);
                },
                onPanUpdate: (details) {
                  setState(() {
                    _dragLift = ((_dragLift ?? lift) - details.delta.dy).clamp(
                      minimumLift,
                      maximumLift,
                    );
                    _pull = (_pull - details.delta.dx).clamp(0.0, maximumPull);
                  });
                },
                onPanEnd: (_) => _release(reduceMotion),
                onPanCancel: () => _release(reduceMotion),
                child: key,
              ),
            ),
          ],
        );
      },
    );
  }

  void _release(bool reduceMotion) {
    final lift = _dragLift;
    if (lift != null) {
      ref.read(betaFeedbackEntryLiftProvider.notifier).set(lift);
    }
    setState(() => _dragLift = null);
    if (_pull <= 0) return;
    if (reduceMotion) {
      _snap.stop();
      setState(() => _pull = 0);
      return;
    }
    _pullAtRelease = _pull;
    unawaited(_snap.forward(from: 0));
  }
}

class _BetaFeedbackKey extends StatelessWidget {
  const _BetaFeedbackKey();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('beta-feedback-entry-key'),
      width: BetaFeedbackEntry.size,
      height: BetaFeedbackEntry.size,
      decoration: const BoxDecoration(
        color: LoopColors.yellow,
        borderRadius: BorderRadius.all(
          Radius.circular(BetaFeedbackEntry.radius),
        ),
        // The tab bar's shadow (decision 0256): the same lift off the page.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const LoopIcon(
            'feedback',
            size: BetaFeedbackEntry.glyphSize,
            color: LoopColors.ink,
          ),
          const SizedBox(height: 4),
          Text(
            BetaFeedbackEntry.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textScaler: TextScaler.noScaling,
            style: LoopTypography.sans(
              size: 10,
              weight: FontWeight.w600,
              height: 1.2,
              color: LoopColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
