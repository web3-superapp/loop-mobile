import 'package:flutter/material.dart';

/// Append on a forward vertical gesture near the end. Pull-to-refresh,
/// horizontal segments and layout/programmatic scrolling never trigger reads.
/// A user drag remains active until its inertial scrolling ends.
class LoopIncrementalList extends StatefulWidget {
  const LoopIncrementalList({
    required this.child,
    required this.canLoadMore,
    required this.loading,
    required this.failed,
    required this.onLoadMore,
    super.key,
  });

  final Widget child;
  final bool canLoadMore, loading, failed;
  final VoidCallback onLoadMore;

  @override
  State<LoopIncrementalList> createState() => _LoopIncrementalListState();
}

class _LoopIncrementalListState extends State<LoopIncrementalList> {
  bool _userScroll = false;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0 ||
              notification.metrics.axis != Axis.vertical) {
            return false;
          }
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _userScroll = true;
          }
          if (notification is ScrollEndNotification) _userScroll = false;
          final forward = switch (notification) {
            ScrollUpdateNotification(:final scrollDelta, :final dragDetails) =>
              (_userScroll || dragDetails != null) && (scrollDelta ?? 0) > 0,
            OverscrollNotification(:final overscroll, :final dragDetails) =>
              (_userScroll || dragDetails != null) && overscroll > 0,
            _ => false,
          };
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical &&
              notification.metrics.extentAfter < 240 &&
              forward &&
              widget.canLoadMore &&
              !widget.loading &&
              !widget.failed) {
            widget.onLoadMore();
          }
          return false;
        },
        child: widget.child,
      );
}

/// Keyboard and assistive-technology fallback for the same append operation.
/// It has no page number or backwards navigation and disappears at the end.
class LoopListLoadMoreFooter extends StatelessWidget {
  const LoopListLoadMoreFooter({required this.onLoadMore, super.key});
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      key: const ValueKey('loop-list-load-more'),
      onPressed: onLoadMore,
      child: const Text('加载更多'),
    ),
  );
}

class LoopListLoadingFooter extends StatelessWidget {
  const LoopListLoadingFooter({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator.adaptive(
          strokeWidth: 2,
          semanticsLabel: '加载更多',
        ),
      ),
    ),
  );
}
