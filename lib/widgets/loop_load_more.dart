import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';

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

/// The foot of a cursor-paged list (decision 0129, S123 M7).
///
/// Lists used to end in a 「载入更多」 button; a native list reads on as the
/// reader scrolls. This footer is the whole contract in one place:
///
/// * no cursor — the list has ended and nothing is drawn;
/// * a cursor and [canLoadMore] — the next page is asked for once, as soon as
///   the footer is built (a lazily built list builds it near the end);
/// * [loading] — one skeleton row stands where the next page will land;
/// * the page came back without moving the cursor — the read failed, and a
///   single 「下一页没有读到 · 重试」 line waits for the reader.
///
/// A cursor is asked for once while it stays the cursor. When the list moves
/// on — a new page, a refresh, the end — the memory is dropped, so a pull that
/// brings back an earlier cursor still reads on.
///
/// Give it a stable key: a notice that appears above it (a failed page does
/// raise one on several pages) would otherwise rebuild it from scratch and
/// lose what it knows about the cursor it asked for.
class LoopLoadMoreFooter extends StatefulWidget {
  const LoopLoadMoreFooter({
    required this.keyPrefix,
    required this.cursor,
    required this.canLoadMore,
    required this.loading,
    required this.onLoadMore,
    super.key,
    this.failedMessage = '下一页没有读到',
    this.skeletonRows = 1,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
  });

  /// Prefix of the stable test keys: `<prefix>-load-more`,
  /// `<prefix>-loading-more`, `<prefix>-more-failed`.
  final String keyPrefix;
  final String? cursor;

  /// Whether the controller would accept a load right now (not busy, not
  /// already loading, not refreshing).
  final bool canLoadMore;
  final bool loading;
  final Future<void> Function() onLoadMore;
  final String failedMessage;
  final int skeletonRows;
  final EdgeInsets padding;

  @override
  State<LoopLoadMoreFooter> createState() => _LoopLoadMoreFooterState();
}

class _LoopLoadMoreFooterState extends State<LoopLoadMoreFooter> {
  String? _asked;
  bool _failed = false;
  bool _checkScheduled = false;
  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    _maybeAsk();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_maybeAsk);
      _position = position?..addListener(_maybeAsk);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_maybeAsk);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LoopLoadMoreFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cursor != _asked) {
      _asked = null;
      _failed = false;
    }
    _maybeAsk();
  }

  bool get _wants {
    final cursor = widget.cursor;
    return cursor != null && !_failed && widget.canLoadMore && _asked != cursor;
  }

  /// A footer inside a list that is not built lazily (a roster inside a
  /// column) is built long before the reader gets there; it waits until it
  /// is within one screen of the viewport.
  bool _nearViewport() {
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    if (box is! RenderBox || !box.attached || scrollable == null) return true;
    final viewport = scrollable.context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return true;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    return top <= viewport.size.height * 2;
  }

  void _maybeAsk() {
    if (!_wants || _checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || !_wants || !_nearViewport()) return;
      final cursor = widget.cursor!;
      _asked = cursor;
      unawaited(_run(cursor));
    });
  }

  Future<void> _run(String cursor) async {
    try {
      await widget.onLoadMore();
    } catch (_) {
      // The controller owns the failure; the footer only notices that the
      // cursor did not move.
    }
    if (!mounted) return;
    if (widget.cursor == cursor && !widget.loading) {
      setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() {
      _failed = false;
      _asked = null;
    });
    _maybeAsk();
  }

  @override
  Widget build(BuildContext context) {
    final prefix = widget.keyPrefix;
    if (widget.cursor == null) {
      // The end of a list draws nothing (decision 0127).
      return const SizedBox.shrink();
    }
    if (_failed && !widget.loading) {
      return Padding(
        padding: EdgeInsets.only(top: widget.padding.top),
        child: LoopInlineUnavailable(
          key: ValueKey<String>('$prefix-more-failed'),
          message: widget.failedMessage,
          onRetry: widget.canLoadMore ? _retry : null,
        ),
      );
    }
    return Column(
      key: ValueKey<String>('$prefix-load-more'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 1),
        if (widget.loading)
          Padding(
            key: ValueKey<String>('$prefix-loading-more'),
            padding: widget.padding,
            child: LoopSkeleton(
              type: LoopSkeletonType.record,
              rows: widget.skeletonRows,
            ),
          ),
      ],
    );
  }
}
