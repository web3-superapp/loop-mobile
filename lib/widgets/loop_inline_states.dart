import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// Compact data-dense states (decision 0117)
// ---------------------------------------------------------------------------
//
// A market list, a wallet's asset rows and a token's holder tab are read in a
// glance. The block-sized state strip (`LoopUnavailableCard`) and a provenance
// footer under every block took more of that glance than the figures did. The
// two widgets here say the same things in one 44px line each: what could not
// be read and why, and where the figures came from and when.

/// One weak 44px line that says a fact could not be read.
///
/// Glyph, one sentence of reason, and — when the caller can try again — a
/// 「重试」 text action at the trailing edge. While [retrying] is true the
/// action reads 「重试中」 and takes no tap, so a second request is never
/// started over the first.
///
/// It never renders a figure, a zero or a dash in place of the missing fact;
/// [message] is the whole content. The block-sized `LoopUnavailableCard`
/// stays for pages that are not data-dense.
class LoopInlineUnavailable extends StatelessWidget {
  const LoopInlineUnavailable({
    required this.message,
    super.key,
    this.onRetry,
    this.retrying = false,
    this.icon = 'warn',
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// The minimum height of the line — one touch target.
  static const double height = 44;

  /// What is missing and why, in one sentence.
  final String message;

  /// Starts the read again. `null` shows no action.
  final VoidCallback? onRetry;

  /// Whether the retry the caller started is still in flight.
  final bool retrying;
  final String icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final auxiliary = LoopGround.auxiliaryOf(context);
    final retry = onRetry;
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        key: const ValueKey<String>('loop-inline-unavailable'),
        constraints: const BoxConstraints(minHeight: height),
        child: Row(
          children: <Widget>[
            LoopIcon(icon, size: 15, color: auxiliary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.captionSm.copyWith(color: auxiliary),
              ),
            ),
            if (retry != null || retrying)
              _InlineTextAction(
                key: const ValueKey<String>('loop-inline-unavailable-retry'),
                label: retrying ? '重试中' : '重试',
                onTap: retrying ? null : retry,
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineTextAction extends StatelessWidget {
  const _InlineTextAction({required this.label, super.key, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final ink = enabled
        ? LoopGround.inkOf(context)
        : LoopGround.auxiliaryOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: LoopPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: LoopInlineUnavailable.height,
            minHeight: LoopInlineUnavailable.height,
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: Text(label, style: LoopType.label.copyWith(color: ink)),
            ),
          ),
        ),
      ),
    );
  }
}

/// "HH:mm" in the device's local time.
String loopClockLabel(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

/// "yyyy-MM-dd HH:mm" in the device's local time.
String loopDateTimeLabel(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${loopClockLabel(local)}';
}

/// The single, weak line that states where a block's figures came from.
///
/// 「来源 X · 观察于 HH:mm」 at 11px in the ground's auxiliary ink; a figure
/// observed on an earlier day carries its date as well. A tap opens the full
/// statement — every source, the exact observation time and the caller's
/// [detail] — in a sheet. It replaces the per-block provenance footers and
/// the 「数据诚实」 explanation cards on data-dense pages, and it keeps
/// AGENTS rule 25: the source and the time are still on the page.
///
/// A line with no source and no time has nothing to attribute and renders
/// nothing at all.
class LoopProvenanceLine extends StatelessWidget {
  const LoopProvenanceLine({
    required this.sources,
    super.key,
    this.observedAt,
    this.prefix,
    this.detail,
    this.now,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// Provider labels, in the order they should be named. Duplicates are
  /// named once.
  final List<String> sources;

  /// The oldest observation time among the figures the line covers.
  final DateTime? observedAt;

  /// What the line is about (e.g. 「公式 v3」); printed first when present.
  final String? prefix;

  /// The full explanation the sheet adds under the source and the time.
  final String? detail;

  /// The clock the "today" comparison reads; tests pin it.
  final DateTime? now;
  final EdgeInsets padding;

  List<String> get _distinctSources => <String>{...sources}.toList();

  String _timeLabel(DateTime at) {
    final reference = (now ?? DateTime.now()).toLocal();
    final local = at.toLocal();
    final sameDay =
        local.year == reference.year &&
        local.month == reference.month &&
        local.day == reference.day;
    if (sameDay) return loopClockLabel(local);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.month)}-${two(local.day)} ${loopClockLabel(local)}';
  }

  /// The text the line prints.
  String get text {
    final named = _distinctSources;
    final at = observedAt;
    return <String>[
      ?prefix,
      if (named.isNotEmpty) '来源 ${named.join(' · ')}',
      if (at != null) '观察于 ${_timeLabel(at)}',
    ].join(' · ');
  }

  Future<void> _open(BuildContext context) {
    final named = _distinctSources;
    final at = observedAt;
    return showLoopSheet<void>(
      context,
      barrierLabel: '关闭数据来源说明',
      builder: (sheetContext) => Padding(
        key: const ValueKey<String>('loop-provenance-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('数据来源', style: LoopType.headingSm),
            const SizedBox(height: 12),
            if (prefix != null)
              LoopKeyValue(
                label: '范围',
                value: prefix!,
                padding: EdgeInsets.zero,
              ),
            LoopKeyValue(
              label: '来源',
              value: named.isEmpty ? '来源未标注' : named.join(' · '),
              padding: EdgeInsets.zero,
            ),
            if (at != null)
              LoopKeyValue(
                label: '观察于',
                value: loopDateTimeLabel(at),
                padding: EdgeInsets.zero,
              ),
            if (detail != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                detail!,
                style: LoopType.bodySm.copyWith(
                  color: LoopGround.secondaryOf(sheetContext),
                ),
              ),
            ],
            const SizedBox(height: 16),
            LoopButton(
              label: '知道了',
              block: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_distinctSources.isEmpty && observedAt == null && prefix == null) {
      return const SizedBox.shrink(
        key: ValueKey<String>('loop-provenance-none'),
      );
    }
    final auxiliary = LoopGround.auxiliaryOf(context);
    final line = text;
    return Padding(
      padding: padding,
      child: Semantics(
        button: true,
        label: '$line，查看数据来源说明',
        excludeSemantics: true,
        child: LoopPressable(
          key: const ValueKey<String>('loop-provenance-line'),
          scale: false,
          onTap: () => _open(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: LoopInlineUnavailable.height,
            ),
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.captionSm.copyWith(color: auxiliary),
                  ),
                ),
                const SizedBox(width: 4),
                LoopIcon('info', size: 12, color: auxiliary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
