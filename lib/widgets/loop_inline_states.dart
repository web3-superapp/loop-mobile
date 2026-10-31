import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart' show LoopInfoNote;
import 'package:loop_mobile/widgets/loop_provenance_scope.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// Compact data-dense states (decision 0117)
// ---------------------------------------------------------------------------
//
// A market list, a wallet's asset rows and a token's holder tab are read in a
// glance. The block-sized v1 state strip (since retired, decision 0172) and a provenance
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
/// [message] is the whole content. `LoopUnavailableLine` is this line with a
/// server reason under it (decision 0172).
class LoopInlineUnavailable extends StatelessWidget {
  const LoopInlineUnavailable({
    required this.message,
    super.key,
    this.onRetry,
    this.retrying = false,
    this.icon = 'warn',
    this.padding = const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
    this.detail,
    this.maxLines = 1,
    this.detailMaxLines = 1,
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

  /// An optional second line under [message] (when it started, …).
  final String? detail;

  /// Lines [message] may take; one by default.
  final int maxLines;

  /// Lines [detail] may take; one by default. A server reason sentence takes
  /// three (decision 0172), so the reason is never cut mid-word.
  final int detailMaxLines;

  @override
  Widget build(BuildContext context) {
    final auxiliary = LoopGround.auxiliaryOf(context);
    final text = Text(
      message,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: LoopType.captionSm.copyWith(color: auxiliary),
    );
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
              child: switch (detail) {
                final String second => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      text,
                      const SizedBox(height: 2),
                      Text(
                        second,
                        maxLines: detailMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.captionSm.copyWith(color: auxiliary),
                      ),
                    ],
                  ),
                ),
                null => text,
              },
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
              // R17 an inline text action: label at 600 (decision 0189).
              child: Text(
                label,
                style: LoopTypography.withWeight(
                  LoopType.label,
                  FontWeight.w600,
                ).copyWith(color: ink),
              ),
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

/// The single, weak control that states where a block's figures came from.
///
/// S278 · decision 0236: the page shows only 「(i) 来源」 at the block's
/// trailing edge; [text] — 「来源 X · 观察于 HH:mm」, with the date for a
/// figure observed on an earlier day — is its accessible name and the sheet's
/// content. A tap opens the full
/// statement — every source, the exact observation time and the caller's
/// [detail] — in a sheet. It replaces the per-block provenance footers and
/// the 「数据诚实」 explanation cards on data-dense pages. AGENTS rule 25
/// still holds: the source and the time are one tap away on the same page,
/// and a stale / derived marker stays printed beside its figure.
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
    this.padding = const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
    this.marker,
  });

  /// A quality marker that must stay visible (AGENTS rule 25: stale,
  /// derived and proxied figures carry a visible marker) — printed before
  /// the (i) even though the rest of the line is behind it (S278).
  final String? marker;

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
    return showLoopProvenanceSheet(
      context,
      prefix: prefix,
      sources: named,
      observedAt: observedAt,
      detail: detail,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_distinctSources.isEmpty && observedAt == null && prefix == null) {
      return const SizedBox.shrink(
        key: ValueKey<String>('loop-provenance-none'),
      );
    }
    // S278 · decision 0236: the line is no longer printed. S325 · decision
    // 0255 (UX-009): on a page with a title bar the statement joins the
    // page's one (i); only a quality marker stays beside the block (AGENTS
    // rule 25). Without a page (i) the block keeps its own 「(i) 来源」.
    final marker = this.marker;
    return LoopProvenanceReport(
      entry: LoopProvenanceEntry(
        heading: prefix,
        sources: _distinctSources,
        observedAt: observedAt,
        attributed: true,
        notes: <LoopInfoNote>[?_detailNote],
        statement: text,
      ),
      hosted: marker == null
          ? const SizedBox.shrink()
          : Padding(
              padding: padding,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Semantics(
                  label: '$text，数据来源在页面右上角的说明里',
                  excludeSemantics: true,
                  child: Text(
                    marker,
                    key: const ValueKey<String>('loop-provenance-marker'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.captionSm.copyWith(
                      color: LoopGround.auxiliaryOf(context),
                    ),
                  ),
                ),
              ),
            ),
      fallback: Padding(
        padding: padding,
        child: LoopInfoTrigger(
          key: const ValueKey<String>('loop-provenance-line'),
          semanticsLabel: '$text，查看数据来源说明',
          expand: true,
          leading: marker,
          onTap: () => _open(context),
        ),
      ),
    );
  }

  LoopInfoNote? get _detailNote {
    final body = detail;
    return body == null || body.isEmpty ? null : LoopInfoNote(body: body);
  }
}

/// The provenance sheet [LoopProvenanceLine] opens (S278 · decision 0236).
///
/// 范围 · 来源 · 观察于 as key–value rows, then the caller's [detail], then
/// any further [notes]. Shared so an (i) beside a section title can open the
/// same statement the compact line does.
Future<void> showLoopProvenanceSheet(
  BuildContext context, {
  required List<String> sources,
  DateTime? observedAt,
  String? prefix,
  String? detail,
  List<String> notes = const <String>[],
  String title = '数据来源',
}) {
  final named = <String>{...sources}.toList();
  final at = observedAt;
  return showLoopSheet<void>(
    context,
    barrierLabel: '关闭数据来源说明',
    builder: (sheetContext) => SingleChildScrollView(
      key: const ValueKey<String>('loop-provenance-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: LoopType.headingSm),
          const SizedBox(height: 12),
          if (prefix != null)
            LoopKeyValue(label: '范围', value: prefix, padding: EdgeInsets.zero),
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
          for (final note in <String>[?detail, ...notes]) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              note,
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

/// The one compact (i) trigger (S278 · decision 0236, 需求方 2026-10-22
/// 第 11–14 条): explanatory text and provenance do not stand on the page;
/// this 44 dp control does, with an optional two-character [label]
/// (「来源」 / 「说明」) after the glyph, in the ground's auxiliary ink.
class LoopInfoTrigger extends StatelessWidget {
  const LoopInfoTrigger({
    required this.semanticsLabel,
    required this.onTap,
    super.key,
    this.label = '来源',
    this.expand = false,
    this.leading,
  });

  /// A short word printed before the glyph that must not hide (a quality
  /// marker).
  final String? leading;

  /// What a screen reader hears — the whole statement, so nothing the page
  /// stopped printing is lost to it.
  final String semanticsLabel;
  final VoidCallback onTap;

  /// The word after the glyph; null draws the glyph alone.
  final String? label;

  /// The line under a block: the whole 44 dp row answers the finger (as the
  /// printed line did), and the glyph sits at its trailing edge.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final auxiliary = LoopGround.auxiliaryOf(context);
    final label = this.label;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: LoopPressable(
        scale: false,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: LoopTouch.minimum,
            minWidth: LoopTouch.minimum,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: expand
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.center,
              children: <Widget>[
                if (leading case final String word) ...<Widget>[
                  Flexible(
                    child: Text(
                      word,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopType.captionSm.copyWith(color: auxiliary),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                LoopIcon('info', size: 13, color: auxiliary),
                if (label != null) ...<Widget>[
                  const SizedBox(width: 3),
                  Text(
                    label,
                    maxLines: 1,
                    style: LoopType.captionSm.copyWith(color: auxiliary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
