import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// Which segment each v3 tab page was last showing (decision 0110).
///
/// A tab page is rebuilt every time the owner comes back to it, so the
/// segment it was on has to live outside the page. The memory is per tab key
/// and lasts for the process; it holds an index, never data.
final class LoopTabSegmentMemory extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const <String, int>{};

  void select(String tab, int index) {
    if (state[tab] == index) return;
    state = <String, int>{...state, tab: index};
  }
}

final loopTabSegmentMemoryProvider =
    NotifierProvider<LoopTabSegmentMemory, Map<String, int>>(
      LoopTabSegmentMemory.new,
    );

/// A v3 tab page whose content is split into page-level segments
/// (广场：社区 | 语音房, MEME：发射台 | 行情, 情报：算力榜 | 行情).
///
/// The segments are the page's own title row, not a filter strip: the
/// selected one reads as the page heading and carries the Lime rule, the
/// others sit beside it in the auxiliary ink. Filters, where a segment has
/// any, stay inside the segment's own body, so a page never shows two rows
/// of controls that look alike.
///
/// Each segment body is an embedded page (`LoopDashboardPage.embedded` or
/// `LoopStreamPage.embedded`): it draws no bar of its own and owns its
/// states, refresh and bottom inset.
class LoopSegmentedTabPage extends ConsumerWidget {
  const LoopSegmentedTabPage({
    required this.tabKey,
    required this.title,
    required this.segments,
    required this.builder,
    super.key,
    this.actionsBuilder,
    this.updating,
    this.archetype = LoopPageArchetype.listing,
  }) : assert(segments.length > 1, 'A segmented page has two segments or more');

  /// Stable key of the tab (`square`, `meme`, `intel`) for the segment
  /// memory and the widget keys.
  final String tabKey;

  /// The page's name for assistive technology; the visible heading is the
  /// selected segment.
  final String title;
  final List<String> segments;

  /// Builds the body of the selected segment.
  final Widget Function(BuildContext context, int index) builder;

  /// Top-bar controls for the selected segment.
  final List<Widget> Function(BuildContext context, int index)? actionsBuilder;

  /// Whether the selected segment is re-reading rows it already shows.
  ///
  /// An embedded segment page draws no bar, so its own 「更新中」 had nowhere
  /// to go; the segment row carries it instead, beside the actions. Called
  /// for the selected segment only, so a segment that is not on screen is
  /// never read.
  final bool Function(WidgetRef ref, int index)? updating;
  final LoopPageArchetype archetype;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remembered = ref.watch(loopTabSegmentMemoryProvider)[tabKey] ?? 0;
    final selected = remembered.clamp(0, segments.length - 1);
    final actions = actionsBuilder?.call(context, selected) ?? const <Widget>[];
    final isUpdating = updating?.call(ref, selected) ?? false;
    return Semantics(
      container: true,
      identifier: loopPageIdentifier(archetype, LoopLayoutMode.stream),
      explicitChildNodes: true,
      child: Scaffold(
        key: ValueKey<String>('$tabKey-tab-page'),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  6,
                  LoopSpacing.page,
                  0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: LoopLayout.topbarContentHeight,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          header: true,
                          label: title,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: <Widget>[
                                for (
                                  var index = 0;
                                  index < segments.length;
                                  index += 1
                                ) ...<Widget>[
                                  if (index > 0) const SizedBox(width: 18),
                                  _SegmentTab(
                                    key: ValueKey<String>(
                                      '$tabKey-segment-$index',
                                    ),
                                    label: segments[index],
                                    selected: index == selected,
                                    onTap: () => ref
                                        .read(
                                          loopTabSegmentMemoryProvider.notifier,
                                        )
                                        .select(tabKey, index),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isUpdating) ...<Widget>[
                        const SizedBox(width: 8),
                        LoopUpdatingBadge(
                          key: ValueKey<String>('$tabKey-segment-updating'),
                        ),
                      ],
                      for (final action in actions) ...<Widget>[
                        const SizedBox(width: 6),
                        action,
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  // A sideways swipe over the body moves to the neighbouring
                  // segment (S123 m7); a horizontal list or a chart inside
                  // the body keeps its own drag.
                  child: LoopSegmentSwipe(
                    key: ValueKey<String>('$tabKey-segment-swipe'),
                    index: selected,
                    count: segments.length,
                    onSelect: (index) => ref
                        .read(loopTabSegmentMemoryProvider.notifier)
                        .select(tabKey, index),
                    child: KeyedSubtree(
                      key: ValueKey<String>('$tabKey-segment-body-$selected'),
                      child: builder(context, selected),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = LoopGround.inkOf(context);
    final style = selected
        ? LoopType.headingLg.copyWith(color: ink)
        : LoopType.headingSm.copyWith(color: LoopGround.auxiliaryOf(context));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: LoopRadius.control,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: LoopTouch.minimum,
            minWidth: LoopTouch.minimum,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(label, style: style),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: 3,
                width: selected ? 18 : 0,
                // Chalk, not Lime (decision 0122): Lime is kept for primary
                // buttons, round action keys, badges and progress.
                decoration: const BoxDecoration(
                  color: LoopColors.chalk,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets a sideways swipe over a segmented body move to the neighbouring
/// segment (decision 0129, S123 m7). Nothing about the look changes.
///
/// It listens for a horizontal drag and decides only when the finger lifts:
/// past [distanceThreshold] or faster than [velocityThreshold], towards the
/// start moves to the next segment and towards the end to the previous one.
///
/// It never competes with a horizontal element inside the body. A horizontal
/// list is a scrollable deeper in the tree, so the gesture arena gives it the
/// drag first; a region that draws its own horizontal content without a
/// scrollable — a chart — is wrapped in [LoopSegmentSwipeBarrier].
///
/// Swipes nest: a body that is itself segmented (算力榜's three boards inside
/// 情报) handles the swipe first, and passes it to the page's own segments
/// only when it is already on its first or last board.
class LoopSegmentSwipe extends StatefulWidget {
  const LoopSegmentSwipe({
    required this.index,
    required this.count,
    required this.onSelect,
    required this.child,
    super.key,
  });

  static const double distanceThreshold = 72;
  static const double velocityThreshold = 520;

  final int index;
  final int count;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  State<LoopSegmentSwipe> createState() => _LoopSegmentSwipeState();
}

class _LoopSegmentSwipeState extends State<LoopSegmentSwipe> {
  double _dx = 0;

  /// Moves by [step] (+1 next, -1 previous). Answers whether this level or
  /// one above it moved.
  bool _move(int step) {
    final target = widget.index + step;
    if (target >= 0 && target < widget.count) {
      unawaited(HapticFeedback.selectionClick());
      widget.onSelect(target);
      return true;
    }
    return _LoopSegmentSwipeScope.maybeOf(context)?._move(step) ?? false;
  }

  void _end(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dx = _dx;
    _dx = 0;
    final fast = velocity.abs() >= LoopSegmentSwipe.velocityThreshold;
    final far = dx.abs() >= LoopSegmentSwipe.distanceThreshold;
    if (!fast && !far) return;
    final towardsStart = fast ? velocity < 0 : dx < 0;
    // A fling against the drag that carried it is no decision.
    if (fast && far && (velocity < 0) != (dx < 0)) return;
    _move(towardsStart ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (details) => _dx += details.primaryDelta ?? 0,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => _dx = 0,
      child: _LoopSegmentSwipeScope(state: this, child: widget.child),
    );
  }
}

class _LoopSegmentSwipeScope extends InheritedWidget {
  const _LoopSegmentSwipeScope({required this.state, required super.child});

  final _LoopSegmentSwipeState state;

  static _LoopSegmentSwipeState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_LoopSegmentSwipeScope>()?.state;

  @override
  bool updateShouldNotify(_LoopSegmentSwipeScope oldWidget) => false;
}

/// A region inside a segmented body whose horizontal drags are its own — a
/// chart, a horizontally swiped card — and must not switch the segment.
///
/// It claims the horizontal drag in the gesture arena (it sits deeper than
/// [LoopSegmentSwipe]) and does nothing with it; taps, long presses and
/// vertical scrolling pass through untouched.
class LoopSegmentSwipeBarrier extends StatelessWidget {
  const LoopSegmentSwipeBarrier({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) {},
    child: child,
  );
}
