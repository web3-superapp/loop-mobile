import 'package:flutter/widgets.dart';

/// Asks for the next cursor page when the end of a list comes into view
/// (v3 需求 6.2 · 4: lists scroll on, they have no 「下一页」).
///
/// It sits after the last row of a lazily built list, so it is only built
/// once the reader has scrolled near the end — or at once, when the first
/// page does not fill the screen. Each cursor is asked for once: a page that
/// answers with the same cursor again does not start a loop, and a failed
/// page waits for the reader's own retry.
class LoopLoadMoreSentinel extends StatefulWidget {
  const LoopLoadMoreSentinel({
    required this.cursor,
    required this.onLoadMore,
    super.key,
  });

  final String cursor;
  final VoidCallback onLoadMore;

  @override
  State<LoopLoadMoreSentinel> createState() => _LoopLoadMoreSentinelState();
}

class _LoopLoadMoreSentinelState extends State<LoopLoadMoreSentinel> {
  String? _asked;

  void _ask() {
    if (_asked == widget.cursor) return;
    _asked = widget.cursor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void didUpdateWidget(covariant LoopLoadMoreSentinel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ask();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 1);
}
