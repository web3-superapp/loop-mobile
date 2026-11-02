import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_controllers.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
// The tab bar's ground, edge and blur (decision 0256): one glass for both.
import 'package:loop_mobile/features/shell/loop_shell.dart'
    show loopTabBarBlur, loopTabBarEdge, loopTabBarGround;

/// Whether the 内测反馈 entry is drawn: the build switch is on and a
/// session may enter the product (S332 · decision 0262).
final betaFeedbackEntryVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(loopFeatureSwitchesProvider).betaFeedbackVisible) {
    return false;
  }
  return ref.watch(
    loopSessionProvider.select((session) => session.canEnterProduct),
  );
});

/// The floating 内测反馈 capsule over the five tabs (S332 · decision 0262).
///
/// A 32 tall glass capsule — the tab bar's ground, edge and blur — on the
/// right edge, 12 above the tab bar by default. It can be dragged anywhere;
/// let go, it slides back onto the right edge at the height it was left,
/// never lower than its default place, so it never covers the bar. The
/// height is kept for the run. Under reduced motion it jumps back instead
/// of sliding. It steps aside while the keyboard is up.
///
/// It lives inside `LoopShell`, so every page pushed over the tabs covers
/// it, and the credential pages never have it.
class BetaFeedbackEntry extends ConsumerStatefulWidget {
  const BetaFeedbackEntry({
    required this.location,
    required this.lowestBottom,
    required this.onOpen,
    super.key,
  });

  /// The router location under the entry, carried into the form.
  final String location;

  /// The distance from the screen's bottom edge to the capsule's touch
  /// target at its default place: the tab bar's reserve, the safe area
  /// and 12.
  final double lowestBottom;

  final ValueChanged<BetaFeedbackOrigin> onOpen;

  /// The drawn capsule.
  static const double capsuleHeight = 32;

  /// The touch target around it.
  static const double targetHeight = LoopTouch.minimum;

  /// The gap over the tab bar at the default place.
  static const double gapOverTabBar = 12;

  static const Duration snapDuration = Duration(milliseconds: 220);

  static const String label = '内测反馈';

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
        final lift = (_dragLift ?? storedLift).clamp(0.0, maximumLift);
        final maximumPull = math.max(
          0.0,
          constraints.maxWidth - rightInset - 120,
        );
        // The tap is the capsule's own pressable; the detector around it
        // only moves it.
        final capsule = Semantics(
          button: true,
          label: BetaFeedbackEntry.label,
          excludeSemantics: true,
          onTap: _open,
          child: LoopPressable(
            onTap: _open,
            child: const _BetaFeedbackCapsule(),
          ),
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
                // The capsule stays under the finger from the first move.
                dragStartBehavior: DragStartBehavior.down,
                onPanStart: (_) {
                  _snap.stop();
                  setState(() => _dragLift = lift);
                },
                onPanUpdate: (details) {
                  setState(() {
                    _dragLift = ((_dragLift ?? lift) - details.delta.dy).clamp(
                      0.0,
                      maximumLift,
                    );
                    _pull = (_pull - details.delta.dx).clamp(0.0, maximumPull);
                  });
                },
                onPanEnd: (_) => _release(reduceMotion),
                onPanCancel: () => _release(reduceMotion),
                child: capsule,
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

class _BetaFeedbackCapsule extends StatelessWidget {
  const _BetaFeedbackCapsule();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: BetaFeedbackEntry.targetHeight,
      child: Center(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: LoopRadius.pill,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x52000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: LoopRadius.pill,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: loopTabBarBlur,
                sigmaY: loopTabBarBlur,
              ),
              child: DecoratedBox(
                key: const ValueKey<String>('beta-feedback-entry-glass'),
                decoration: BoxDecoration(
                  color: loopTabBarGround,
                  borderRadius: LoopRadius.pill,
                  border: Border.all(color: loopTabBarEdge),
                ),
                child: Container(
                  key: const ValueKey<String>('beta-feedback-entry-capsule'),
                  height: BetaFeedbackEntry.capsuleHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  child: Text(
                    BetaFeedbackEntry.label,
                    maxLines: 1,
                    style: LoopType.label.copyWith(color: LoopColors.chalk),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
