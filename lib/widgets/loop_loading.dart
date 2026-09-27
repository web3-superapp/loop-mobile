import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// How long ago [at] was, in the product's own words: 「12 秒前」,
/// 「3 分钟前」. A time ahead of this device's clock is 「刚刚」.
String loopAgeLabel(DateTime at, {DateTime? now}) {
  final delta = (now ?? DateTime.now()).toUtc().difference(at.toUtc());
  if (delta.isNegative || delta.inSeconds < 1) return '刚刚';
  if (delta.inSeconds < 60) return '${delta.inSeconds} 秒前';
  if (delta.inMinutes < 60) return '${delta.inMinutes} 分钟前';
  if (delta.inHours < 24) return '${delta.inHours} 小时前';
  return '${delta.inDays} 天前';
}

/// The one line at the top of a page that says how old the answer on screen
/// is, whenever that is not obvious (decision 0095).
///
/// * Over a snapshot an earlier run stored: 「数据来自 N 秒前，正在更新」. It
///   fades in with the snapshot and out once the live answer replaced it.
/// * Over an answer a refresh failed to replace: 「更新失败，显示的是 N 前读到的
///   数据」, with a retry. The answer stays; only this line changes.
/// * Otherwise nothing, and it takes no room.
///
/// Under reduced motion it appears and disappears without a fade.
class LoopFreshnessStrip extends StatelessWidget {
  const LoopFreshnessStrip({
    required this.refreshing,
    required this.refreshFailed,
    super.key,
    this.restoredAt,
    this.readAt,
    this.onRetry,
    this.now,
  });

  /// When the snapshot on screen was received, if the page is showing one.
  final DateTime? restoredAt;

  /// When the answer on screen was received, live or restored.
  final DateTime? readAt;

  /// A read is running over the answer on screen.
  final bool refreshing;

  /// The last read failed and the answer on screen is the one before it.
  final bool refreshFailed;
  final VoidCallback? onRetry;

  /// Test hook for the age wording.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final at = restoredAt ?? readAt;
    final failed = refreshFailed && !refreshing;
    final String? text;
    if (failed) {
      text = at == null
          ? '更新失败，显示的是上次读到的数据'
          : '更新失败，显示的是${loopAgeLabel(at, now: now)}读到的数据';
    } else if (restoredAt != null) {
      final age = loopAgeLabel(restoredAt!, now: now);
      text = refreshing ? '数据来自$age，正在更新' : '数据来自$age';
    } else {
      text = null;
    }
    final duration = LoopMotion.of(context, LoopMotion.freshnessFade);
    return AnimatedSize(
      duration: duration,
      curve: LoopMotion.freshnessCurve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: LoopMotion.freshnessCurve,
        switchOutCurve: LoopMotion.freshnessCurve,
        child: text == null
            ? const SizedBox(
                key: ValueKey<String>('loop-freshness-none'),
                width: double.infinity,
              )
            : _FreshnessLine(
                key: ValueKey<String>(
                  failed ? 'loop-freshness-failed' : 'loop-freshness-snapshot',
                ),
                text: text,
                failed: failed,
                onRetry: failed ? onRetry : null,
              ),
      ),
    );
  }
}

class _FreshnessLine extends StatelessWidget {
  const _FreshnessLine({
    required this.text,
    required this.failed,
    super.key,
    this.onRetry,
  });

  final String text;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = failed ? LoopColors.warning : LoopColors.text2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        10,
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
          padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
          decoration: BoxDecoration(
            color: failed
                ? LoopColors.warning.withValues(alpha: 0.08)
                : LoopColors.card,
            borderRadius: LoopRadius.control,
            border: Border.all(
              color: failed
                  ? LoopColors.warning.withValues(alpha: 0.32)
                  : LoopColors.line,
            ),
          ),
          child: Row(
            children: <Widget>[
              LoopIcon(failed ? 'warn' : 'clock', size: 14, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  key: const ValueKey<String>('loop-freshness-text'),
                  style: LoopType.caption.copyWith(color: color),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  key: const ValueKey<String>('loop-freshness-retry'),
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      LoopTouch.minimum,
                      LoopTouch.minimum,
                    ),
                    foregroundColor: LoopColors.chalk,
                    textStyle: LoopType.titleSm,
                  ),
                  child: const Text('重试'),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Content taking the place of its skeleton (decision 0095).
///
/// When [animate] is true the child fades in once, over
/// [LoopMotion.contentFadeIn], the first time it is built. A page passes
/// `false` when the content was already on screen — a retained answer, a
/// refresh — so nothing that was readable a moment ago blinks. Under reduced
/// motion it never fades.
class LoopContentArrival extends StatefulWidget {
  const LoopContentArrival({
    required this.child,
    required this.animate,
    super.key,
  });

  final Widget child;
  final bool animate;

  @override
  State<LoopContentArrival> createState() => _LoopContentArrivalState();
}

class _LoopContentArrivalState extends State<LoopContentArrival>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LoopMotion.contentFadeIn,
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: LoopMotion.contentFadeCurve,
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_controller.value >= 1) return;
    if (LoopMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}
