import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart'
    show loopDateTimeLabel;
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';

// ---------------------------------------------------------------------------
// One page, one (i) (S325 · decision 0255, UX-009)
// ---------------------------------------------------------------------------
//
// 「(i) 来源」 used to stand under every data block, and each explanation had
// its own (i) beside a row or a section title. The requester's UX review
// (2026-10-31, UX-009) read a page full of identical dots as noise. The
// disclosure itself is a product rule, so it is not removed: every source and
// explanation a page holds is gathered here and opened from one (i) at the
// right of the page's title bar.
//
// A page scaffold (`LoopFocusPage`, `LoopDashboardPage`, `LoopStreamPage`,
// `LoopTabSegments`) puts a [LoopProvenanceScope] around itself. Inside it,
// `LoopProvenanceLine`, `LoopProvenanceFooter`, `LoopFactLine`'s source and
// `LoopInfoButton` report what they would have said and draw nothing; the
// title bar's [LoopPageInfoAction] reads the scope and opens all of it in one
// sheet. Outside a scope — a sheet, a page with its own header — they keep
// their own (i), so nothing is ever lost.

/// What one block of a page would have said behind its own (i).
@immutable
final class LoopProvenanceEntry {
  const LoopProvenanceEntry({
    this.heading,
    this.sources = const <String>[],
    this.observedAt,
    this.attributed = false,
    this.notes = const <LoopInfoNote>[],
    this.statement,
  });

  /// The whole statement in one line, as the block's own (i) used to speak
  /// it (「来源 X · 观察于 HH:mm」).
  final String? statement;

  /// [statement], or the paragraphs joined when there is none.
  String get spoken => statement ?? notes.map((note) => note.body).join('\n');

  /// The block the entry belongs to (「挖矿说明」, 「多因素验证」, a scope
  /// prefix). `null` for a page-wide statement.
  final String? heading;

  /// Provider labels, named once each.
  final List<String> sources;

  /// The oldest observation time among the figures the entry covers.
  final DateTime? observedAt;

  /// Whether the entry states 「来源」 / 「观察于」 rows (a provenance line)
  /// rather than only paragraphs (an explanation).
  final bool attributed;

  /// Paragraphs under the rows.
  final List<LoopInfoNote> notes;

  @override
  bool operator ==(Object other) =>
      other is LoopProvenanceEntry &&
      other.heading == heading &&
      listEquals(other.sources, sources) &&
      other.observedAt == observedAt &&
      other.attributed == attributed &&
      other.statement == statement &&
      listEquals(other.notes, notes);

  @override
  int get hashCode => Object.hash(
    heading,
    Object.hashAll(sources),
    observedAt,
    attributed,
    statement,
    Object.hashAll(notes),
  );
}

/// The entries one page has reported, in the order the page built them.
///
/// Reporting happens while the page builds; listeners hear about it after the
/// frame, so the title bar never rebuilds in the middle of a build.
class LoopProvenanceRegistry extends ChangeNotifier {
  final Map<Object, LoopProvenanceEntry> _entries =
      <Object, LoopProvenanceEntry>{};
  bool _scheduled = false;
  bool _disposed = false;

  /// Every distinct entry, first report first.
  List<LoopProvenanceEntry> get entries =>
      <LoopProvenanceEntry>{..._entries.values}.toList(growable: false);

  bool get isEmpty => _entries.isEmpty;

  /// Records (or replaces) what [owner] reports.
  void put(Object owner, LoopProvenanceEntry entry) {
    if (_entries[owner] == entry) return;
    _entries[owner] = entry;
    _schedule();
  }

  /// Forgets what [owner] reported.
  void remove(Object owner) {
    if (_entries.remove(owner) != null) _schedule();
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
    binding.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The page-wide collector. Page scaffolds put one around the page that
/// draws a title bar; nothing else needs to.
class LoopProvenanceScope extends StatefulWidget {
  const LoopProvenanceScope({required this.child, super.key});

  final Widget child;

  /// The nearest page's registry, or `null` outside one.
  static LoopProvenanceRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_LoopProvenanceInherited>()
      ?.registry;

  @override
  State<LoopProvenanceScope> createState() => _LoopProvenanceScopeState();
}

class _LoopProvenanceScopeState extends State<LoopProvenanceScope> {
  final LoopProvenanceRegistry _registry = LoopProvenanceRegistry();

  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _LoopProvenanceInherited(registry: _registry, child: widget.child);
}

class _LoopProvenanceInherited extends InheritedWidget {
  const _LoopProvenanceInherited({
    required this.registry,
    required super.child,
  });

  final LoopProvenanceRegistry registry;

  @override
  bool updateShouldNotify(_LoopProvenanceInherited oldWidget) =>
      registry != oldWidget.registry;
}

/// Reports [entry] to the page's (i) and draws [hosted] in its place; outside
/// a page scope it draws [fallback] — the block's own (i) — instead.
class LoopProvenanceReport extends StatefulWidget {
  const LoopProvenanceReport({
    required this.entry,
    required this.fallback,
    super.key,
    this.hosted = const SizedBox.shrink(),
  });

  final LoopProvenanceEntry entry;
  final Widget fallback;

  /// What stays on the page once the entry has moved to the title bar: by
  /// default nothing; a quality marker that must stay visible otherwise.
  final Widget hosted;

  @override
  State<LoopProvenanceReport> createState() => _LoopProvenanceReportState();
}

class _LoopProvenanceReportState extends State<LoopProvenanceReport> {
  LoopProvenanceRegistry? _registry;

  @override
  void dispose() {
    _registry?.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = LoopProvenanceScope.maybeOf(context);
    if (!identical(registry, _registry)) {
      _registry?.remove(this);
      _registry = registry;
    }
    if (registry == null) return widget.fallback;
    registry.put(this, widget.entry);
    return LoopProvenanceHosted(
      key: const ValueKey<String>('loop-provenance-hosted'),
      entry: widget.entry,
      child: widget.hosted,
    );
  }
}

/// What a [LoopProvenanceReport] leaves on the page once its entry has moved
/// to the title bar's (i): [child] (usually nothing), tagged with the
/// [entry] it handed over.
class LoopProvenanceHosted extends StatelessWidget {
  const LoopProvenanceHosted({
    required this.entry,
    required this.child,
    super.key,
  });

  final LoopProvenanceEntry entry;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The page's one (i), at the right end of its title bar.
///
/// It is drawn only while it has something to open: the page's own [notes]
/// (a page that already had an (i) in its bar, such as 我的挖矿's 挖矿说明)
/// or anything the page's blocks reported. The sheet opens with [notes],
/// then one section per reported entry, then [footer].
class LoopPageInfoAction extends StatefulWidget {
  const LoopPageInfoAction({
    super.key,
    this.title = '数据来源',
    this.label,
    this.notes = const <LoopInfoNote>[],
    this.footer,
    this.sheetKey = 'loop-provenance-sheet',
  });

  /// The sheet's heading.
  final String title;

  /// The control's accessible name; 「数据来源与说明」 by default.
  final String? label;
  final List<LoopInfoNote> notes;
  final Widget Function(BuildContext sheetContext)? footer;
  final String sheetKey;

  @override
  State<LoopPageInfoAction> createState() => _LoopPageInfoActionState();
}

class _LoopPageInfoActionState extends State<LoopPageInfoAction> {
  LoopProvenanceRegistry? _registry;

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = LoopProvenanceScope.maybeOf(context);
    if (identical(registry, _registry)) return;
    _registry?.removeListener(_changed);
    _registry = registry?..addListener(_changed);
  }

  @override
  void dispose() {
    _registry?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _registry?.entries ?? const <LoopProvenanceEntry>[];
    if (widget.notes.isEmpty && entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return LoopIconButton(
      icon: 'info',
      // Android's 48 dp guideline: this control is often the bar's only one.
      target: 48,
      label: widget.label ?? '数据来源与说明',
      onPressed: () => unawaited(
        showLoopPageInfoSheet(
          context,
          title: widget.title,
          notes: widget.notes,
          entries: _registry?.entries ?? const <LoopProvenanceEntry>[],
          footer: widget.footer,
          sheetKey: widget.sheetKey,
        ),
      ),
    );
  }
}

/// The one sheet a page's (i) opens: the page's own [notes], then every
/// reported entry as its own section.
Future<void> showLoopPageInfoSheet(
  BuildContext context, {
  required String title,
  List<LoopInfoNote> notes = const <LoopInfoNote>[],
  List<LoopProvenanceEntry> entries = const <LoopProvenanceEntry>[],
  Widget Function(BuildContext sheetContext)? footer,
  String sheetKey = 'loop-provenance-sheet',
}) {
  return showLoopSheet<void>(
    context,
    barrierLabel: '关闭说明',
    builder: (sheetContext) => SingleChildScrollView(
      key: ValueKey<String>(sheetKey),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopSheetHeading(title),
          for (final note in notes) _LoopInfoParagraph(note),
          for (final (index, entry) in entries.indexed)
            _LoopProvenanceSection(
              key: ValueKey<String>('loop-provenance-section-$index'),
              entry: entry,
            ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: footer(sheetContext),
            ),
        ],
      ),
    ),
  );
}

class _LoopInfoParagraph extends StatelessWidget {
  const _LoopInfoParagraph(this.note);

  final LoopInfoNote note;

  @override
  Widget build(BuildContext context) => Padding(
    key: note.key,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (note.title != null) ...<Widget>[
          Text(note.title!, style: LoopType.title),
          const SizedBox(height: 4),
        ],
        Text(note.body, style: LoopType.bodySm),
      ],
    ),
  );
}

class _LoopProvenanceSection extends StatelessWidget {
  const _LoopProvenanceSection({required this.entry, super.key});

  final LoopProvenanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final heading = entry.heading;
    final at = entry.observedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (heading != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(heading, style: LoopType.title),
          ),
        if (entry.attributed) ...<Widget>[
          LoopKeyValue(
            label: '来源',
            value: entry.sources.isEmpty
                ? '来源未标注'
                : <String>{...entry.sources}.join(' · '),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          ),
          if (at != null)
            LoopKeyValue(
              label: '观察于',
              value: loopDateTimeLabel(at),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
          const SizedBox(height: 8),
        ],
        for (final note in entry.notes) _LoopInfoParagraph(note),
      ],
    );
  }
}
