import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
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
  final LoopPageArchetype archetype;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remembered = ref.watch(loopTabSegmentMemoryProvider)[tabKey] ?? 0;
    final selected = remembered.clamp(0, segments.length - 1);
    final actions = actionsBuilder?.call(context, selected) ?? const <Widget>[];
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
                  child: KeyedSubtree(
                    key: ValueKey<String>('$tabKey-segment-body-$selected'),
                    child: builder(context, selected),
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
                decoration: const BoxDecoration(
                  color: LoopColors.lime,
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
