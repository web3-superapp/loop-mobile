import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// Business archetype (`data-page-archetype`): what the page is for.
/// `listing` is the prototype's `index` (reserved on Dart enums).
enum LoopPageArchetype {
  intro('intro'),
  listing('index'),
  record('record'),
  action('action'),
  state('state');

  const LoopPageArchetype(this.wireName);

  /// Prototype `data-page-archetype` value.
  final String wireName;
}

/// Layout mode (`data-layout-mode`): how the page is arranged. The two
/// dimensions are kept separate on purpose (chapter 6.2).
enum LoopLayoutMode { focus, dashboard, stream }

/// Semantic identifier shared by the three scaffolds so tests and analytics
/// can read both dimensions: `loop-page:<archetype>:<mode>`.
String loopPageIdentifier(LoopPageArchetype archetype, LoopLayoutMode mode) =>
    'loop-page:${archetype.wireName}:${mode.name}';

/// Bottom inset for child pages: `max(24, safe-area-bottom)`. Top-level tab
/// pages already receive `90 + safe-area` from the shell's `extendBody`.
double loopChildPageBottomInset(BuildContext context) => math.max(
  LoopLayout.childPageBottomMinimum,
  MediaQuery.paddingOf(context).bottom,
);

/// `focus`: single-task step page. Topbar, optional folio, scrolling body,
/// then the primary action pinned so it is reachable on the first screen;
/// extra copy lives in a disclosure.
class LoopFocusPage extends StatelessWidget {
  const LoopFocusPage({
    required this.archetype,
    required this.title,
    required this.body,
    super.key,
    this.kicker,
    this.onBack,
    this.actions = const <Widget>[],
    this.folio,
    this.primaryAction,
    this.disclosure,
    this.primaryActionBeforeDisclosure = true,
  });

  final LoopPageArchetype archetype;
  final String title;
  final String? kicker;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final LoopFolioPrimary? folio;
  final List<Widget> body;

  /// Pinned under the body (`.btn-pair` / `.btn-block`).
  final Widget? primaryAction;
  final LoopDisclosure? disclosure;

  /// Prototype order: the primary action sits above the disclosure so it stays
  /// reachable on the first screen. Set false only when the disclosure is the
  /// page's own risk copy and must be read before acting.
  final bool primaryActionBeforeDisclosure;

  static const LoopLayoutMode layoutMode = LoopLayoutMode.focus;

  @override
  Widget build(BuildContext context) {
    final bottom = loopChildPageBottomInset(context);
    return Semantics(
      container: true,
      identifier: loopPageIdentifier(archetype, layoutMode),
      explicitChildNodes: true,
      child: Scaffold(
        key: ValueKey<String>('loop-page-${layoutMode.name}'),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopTopbar(
                title: title,
                kicker: kicker,
                onBack: onBack,
                actions: actions,
                minHeight: 72,
              ),
              ?folio,
              // Focus bodies are short step pages: build them eagerly so
              // every control exists for ensureVisible / assistive tech.
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: primaryAction == null ? bottom : 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: body,
                  ),
                ),
              ),
              if (!primaryActionBeforeDisclosure) ?disclosure,
              if (primaryAction != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    LoopSpacing.page,
                    LoopSpacing.tight,
                    LoopSpacing.page,
                    primaryActionBeforeDisclosure && disclosure != null
                        ? LoopSpacing.tight
                        : bottom,
                  ),
                  child: primaryAction,
                ),
              if (primaryActionBeforeDisclosure && disclosure != null)
                Padding(
                  padding: EdgeInsets.only(bottom: bottom),
                  child: disclosure,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `dashboard`: sticky topbar (z 8 over Ink), the single primary region first,
/// then metrics and records.
class LoopDashboardPage extends StatelessWidget {
  const LoopDashboardPage({
    required this.archetype,
    required this.title,
    required this.primary,
    required this.sections,
    super.key,
    this.kicker,
    this.onBack,
    this.actions = const <Widget>[],
    this.tabPage = false,
  });

  final LoopPageArchetype archetype;
  final String title;
  final String? kicker;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// The one `[data-page-primary]` region (usually a [LoopFolioPrimary]).
  final Widget primary;
  final List<Widget> sections;

  /// Top-level tab page: bottom inset comes from the shell.
  final bool tabPage;

  static const LoopLayoutMode layoutMode = LoopLayoutMode.dashboard;

  @override
  Widget build(BuildContext context) {
    final bottom = tabPage
        ? MediaQuery.paddingOf(context).bottom
        : loopChildPageBottomInset(context);
    return Semantics(
      container: true,
      identifier: loopPageIdentifier(archetype, layoutMode),
      explicitChildNodes: true,
      child: Scaffold(
        key: ValueKey<String>('loop-page-${layoutMode.name}'),
        body: CustomScrollView(
          slivers: <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTopbar(
                topPadding: MediaQuery.paddingOf(context).top,
                child: LoopTopbar(
                  title: title,
                  kicker: kicker,
                  onBack: onBack,
                  actions: actions,
                  minHeight: 72,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: const ValueKey<String>('loop-page-primary'),
                child: primary,
              ),
            ),
            SliverList.list(children: sections),
            SliverPadding(padding: EdgeInsets.only(bottom: bottom)),
          ],
        ),
      ),
    );
  }
}

class _StickyTopbar extends SliverPersistentHeaderDelegate {
  const _StickyTopbar({required this.child, required this.topPadding});

  final Widget child;
  final double topPadding;

  @override
  double get minExtent => 72 + topPadding;

  @override
  double get maxExtent => 72 + topPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: LoopColors.ink,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTopbar oldDelegate) =>
      oldDelegate.child != child || oldDelegate.topPadding != topPadding;
}

/// `stream`: fixed topbar (and optional folio/segs), an independently
/// scrolling collection region, and an optional composer that never scrolls
/// away or hides under the tab bar.
class LoopStreamPage extends StatelessWidget {
  const LoopStreamPage({
    required this.archetype,
    required this.title,
    required this.collection,
    super.key,
    this.kicker,
    this.onBack,
    this.actions = const <Widget>[],
    this.folio,
    this.filters,
    this.composer,
    this.tabPage = false,
  });

  final LoopPageArchetype archetype;
  final String title;
  final String? kicker;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final LoopFolioPrimary? folio;

  /// A [LoopSegBar] or equivalent, pinned above the collection.
  final Widget? filters;

  /// The scrollable region (`[data-collection-region]`).
  final Widget collection;
  final LoopComposer? composer;
  final bool tabPage;

  static const LoopLayoutMode layoutMode = LoopLayoutMode.stream;

  @override
  Widget build(BuildContext context) {
    final bottom = composer != null
        ? 0.0
        : tabPage
        ? MediaQuery.paddingOf(context).bottom
        : loopChildPageBottomInset(context);
    return Semantics(
      container: true,
      identifier: loopPageIdentifier(archetype, layoutMode),
      explicitChildNodes: true,
      child: Scaffold(
        key: ValueKey<String>('loop-page-${layoutMode.name}'),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopTopbar(
                title: title,
                kicker: kicker,
                onBack: onBack,
                actions: actions,
                minHeight: 72,
              ),
              ?folio,
              ?filters,
              Expanded(
                child: KeyedSubtree(
                  key: const ValueKey<String>('loop-page-collection'),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottom),
                    child: collection,
                  ),
                ),
              ),
              ?composer,
            ],
          ),
        ),
      ),
    );
  }
}
