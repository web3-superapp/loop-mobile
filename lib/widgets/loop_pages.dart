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

/// Wraps a page's scrolling region in the standard pull-to-refresh gesture.
///
/// A refresh re-reads what the page already shows: the values stay on screen
/// and the topbar keeps the 更新中 mark, so pulling never falls back to a
/// skeleton. The gesture is a plain drag, so it behaves the same under
/// `reduceMotion`; the only thing that moves is the indicator that says a read
/// is running, which is exactly the fact the user asked for.
///
/// A page with nothing to re-read — a step in an action, a device-local
/// setting, a whole-page block — passes no callback and gets no gesture.
///
/// The region that installs the gesture also guarantees the gesture can
/// happen. A `RefreshIndicator` only ever hears a scrollable that overscrolls,
/// so a collection whose rows are shorter than the viewport has no pull at all
/// unless something makes it always scrollable. A vertical scroll view with no
/// controller of its own already gets that from `ScrollView`'s primary
/// inheritance; one that owns a controller — the usual shape once a list
/// paginates — does not, and would silently lose the gesture exactly when its
/// first page is short.
///
/// So the refreshable region states it instead of trusting each caller to
/// remember: a descendant that declares no physics is always scrollable, while
/// one that declares its own keeps it, because `Scrollable` applies the
/// widget's physics over the configuration's rather than the other way round.
Widget loopRefreshable({
  required Widget child,
  required Future<void> Function()? onRefresh,
  double edgeOffset = 0,
  ScrollNotificationPredicate predicate = defaultScrollNotificationPredicate,
}) {
  if (onRefresh == null) return child;
  return RefreshIndicator(
    key: const ValueKey<String>('loop-page-refresh'),
    onRefresh: onRefresh,
    edgeOffset: edgeOffset,
    notificationPredicate: predicate,
    displacement: 24,
    strokeWidth: 2.2,
    // The indicator is a Chalk chip with an Ink arc, the same pairing the tab
    // bar uses. Both colours are opaque on purpose: the translucent card token
    // it used before composited with whatever it was dragged over, and over
    // the Lime folio that came out as a dark olive smudge rather than a
    // control. A chip that does not take its colour from the page behind it
    // reads the same on Ink and on Lime.
    color: LoopColors.ink,
    backgroundColor: LoopColors.chalk,
    child: Builder(
      builder: (context) {
        final ambient = ScrollConfiguration.of(context);
        return ScrollConfiguration(
          // The platform's own physics stay underneath: a configuration's
          // physics is used as given rather than applied on top of the
          // platform default, so composing it here is what keeps Android
          // clamping and iOS bouncing instead of replacing them.
          behavior: ambient.copyWith(
            physics: AlwaysScrollableScrollPhysics(
              parent: ambient.getScrollPhysics(context),
            ),
          ),
          child: child,
        );
      },
    ),
  );
}

/// Hears one scrolling region that is coordinated by a [NestedScrollView].
///
/// Such a region reports the drag from two positions: the header's, which is
/// the notification a [RefreshIndicator] hears at depth 0, and the body's,
/// which is the one that actually overscrolls at the top and arrives a level
/// deeper. Reading only the first, the gesture starts and never accumulates;
/// the pull existed on the page and did nothing. A horizontal region — the
/// chip row is one — is refused by the indicator itself on its axis.
bool loopNestedScrollNotificationPredicate(ScrollNotification notification) =>
    notification.depth <= 1;

/// The physics a refreshable region needs: a short page must still overscroll,
/// or the gesture would exist only on pages that happen to be long.
///
/// [loopRefreshable] now supplies this as the ambient default, so a collection
/// that states nothing gets it anyway. It stays because a scroll view that
/// builds its own physics — the dashboard's `CustomScrollView` does — is
/// clearer stating it, and because passing it remains correct.
ScrollPhysics? loopRefreshablePhysics(Future<void> Function()? onRefresh) =>
    onRefresh == null ? null : const AlwaysScrollableScrollPhysics();

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
    this.actionsFollowBody = false,
    this.updating = false,
    this.block,
  });

  final LoopPageArchetype archetype;
  final String title;
  final String? kicker;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final LoopFolioPrimary? folio;
  final List<Widget> body;

  /// The page has nothing to show at all (a closed capability, a whole-page
  /// refusal). It takes the room the body, the folio and the pinned action
  /// would have used; only the topbar stays, so the user can leave.
  ///
  /// A block inside a page that did load is not this — that is a `LoopEmpty`
  /// strip — and a page that is still reading is not this either, that is a
  /// `LoopSkeleton`.
  final Widget? block;

  /// Pinned under the body (`.btn-pair` / `.btn-block`).
  final Widget? primaryAction;
  final LoopDisclosure? disclosure;

  /// Prototype order: the primary action sits above the disclosure so it stays
  /// reachable on the first screen. Set false only when the disclosure is the
  /// page's own risk copy and must be read before acting.
  final bool primaryActionBeforeDisclosure;

  /// The action and the disclosure flow at the end of the body instead of
  /// being pinned above the bottom inset.
  ///
  /// Pinning is right for a page whose body is a list the reader may scroll
  /// for a while: the one next step stays on the first screen. It is wrong for
  /// the prototype's step pages, which lay the button out in normal flow
  /// directly under the last row (`identity-*` carries no pinned bar, and the
  /// single `margin-top:auto` in `style-v2.css` belongs to `wallet-create`
  /// alone). Pinned, 验证邮箱 / 连接钱包 / 创建 LOOP ID put 400–500 px of empty
  /// screen between their last line and their button — audit 2026-09-20 §D#9.
  ///
  /// Default false, so every page that does not ask keeps the pinned bar.
  final bool actionsFollowBody;

  /// The page is re-reading data it already shows (`state.refreshing`).
  final bool updating;

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
                minHeight: LoopLayout.topbarContentHeight,
                updating: updating,
              ),
              if (block != null)
                Expanded(child: block!)
              else ...<Widget>[
                ?folio,
                // Focus bodies are short step pages: build them eagerly so
                // every control exists for ensureVisible / assistive tech.
                Expanded(
                  child: SingleChildScrollView(
                    // A pinned action is a sibling of the body, so it cannot
                    // overlay it — but with 12 of room the last row ended
                    // flush against the bar and read as covered by it:
                    // 隐私's last visibility row and 编辑资料's fourth 关注赛道
                    // chip were both reported that way. A group's worth of
                    // room makes the boundary unambiguous.
                    padding: EdgeInsets.only(
                      bottom: primaryAction == null || actionsFollowBody
                          ? bottom
                          : LoopSpacing.group,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        ...body,
                        if (actionsFollowBody) ..._flowingActions(),
                      ],
                    ),
                  ),
                ),
              ],
              if (block == null && !actionsFollowBody) ...<Widget>[
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
            ],
          ),
        ),
      ),
    );
  }

  /// The same two regions the pinned bar carries, in the same order, laid out
  /// in the body's normal flow.
  List<Widget> _flowingActions() => <Widget>[
    if (!primaryActionBeforeDisclosure) ?disclosure,
    if (primaryAction != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          LoopSpacing.tight,
          LoopSpacing.page,
          0,
        ),
        child: primaryAction,
      ),
    if (primaryActionBeforeDisclosure) ?disclosure,
  ];
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
    this.updating = false,
    this.block,
    this.onRefresh,
    this.subtitle,
    this.framedTools = false,
  });

  final LoopPageArchetype archetype;
  final String title;
  final String? kicker;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// The 11px line under the title (`LoopTopbar.subtitle`).
  final String? subtitle;

  /// Whether the bar's controls take the `.tool-btn` frame.
  final bool framedTools;

  /// The one `[data-page-primary]` region (usually a [LoopFolioPrimary]).
  final Widget primary;
  final List<Widget> sections;

  /// Top-level tab page: bottom inset comes from the shell.
  final bool tabPage;

  /// The page is re-reading data it already shows (`state.refreshing`).
  final bool updating;

  /// The page has nothing to show at all. It replaces the primary region and
  /// every section; the topbar stays so the user can leave. See
  /// [LoopFocusPage.block] for how it differs from an inline empty strip.
  final Widget? block;

  /// Pull-to-refresh over the reads this page owns. A blocked page has nothing
  /// to re-read, so the gesture is withheld while [block] is set.
  final Future<void> Function()? onRefresh;

  static const LoopLayoutMode layoutMode = LoopLayoutMode.dashboard;

  @override
  Widget build(BuildContext context) {
    final bottom = tabPage
        ? MediaQuery.paddingOf(context).bottom
        : loopChildPageBottomInset(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final refresh = block == null ? onRefresh : null;
    return Semantics(
      container: true,
      identifier: loopPageIdentifier(archetype, layoutMode),
      explicitChildNodes: true,
      child: Scaffold(
        key: ValueKey<String>('loop-page-${layoutMode.name}'),
        body: loopRefreshable(
          onRefresh: refresh,
          // The sticky topbar scrolls inside this view, so the indicator is
          // pushed below it rather than over the title.
          edgeOffset: LoopLayout.topbarHeight + topPadding,
          child: CustomScrollView(
            physics: loopRefreshablePhysics(refresh),
            slivers: <Widget>[
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTopbar(
                  topPadding: topPadding,
                  child: LoopTopbar(
                    title: title,
                    kicker: kicker,
                    subtitle: subtitle,
                    onBack: onBack,
                    actions: actions,
                    minHeight: LoopLayout.topbarContentHeight,
                    updating: updating,
                    framedTools: framedTools,
                  ),
                ),
              ),
              if (block != null)
                SliverFillRemaining(hasScrollBody: false, child: block!)
              else ...<Widget>[
                SliverToBoxAdapter(
                  child: KeyedSubtree(
                    key: const ValueKey<String>('loop-page-primary'),
                    child: primary,
                  ),
                ),
                SliverList.list(children: sections),
              ],
              SliverPadding(padding: EdgeInsets.only(bottom: bottom)),
            ],
          ),
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
  double get minExtent => LoopLayout.topbarHeight + topPadding;

  @override
  double get maxExtent => LoopLayout.topbarHeight + topPadding;

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

/// `stream`: fixed topbar and chip row, a scrolling collection region that
/// carries the folio with it, and an optional composer that never scrolls
/// away or hides under the tab bar.
///
/// The topbar says where the reader is, the chips say what is being listed,
/// and both are worth their space at row 200. The folio is not: it reads the
/// list once — 「311 名成员」 — and after that it is a heading the reader has
/// already read, so it scrolls with the rows and comes back whole at the top.
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
    this.folioCollapsed = false,
    this.filters,
    this.composer,
    this.tabPage = false,
    this.updating = false,
    this.block,
    this.onRefresh,
    this.titleField,
    this.framedTools = false,
  });

  final LoopPageArchetype archetype;
  final String title;
  final String? kicker;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// A field that takes the whole title column (`LoopTopbar.titleField`).
  final Widget? titleField;

  /// Whether the bar's controls take the `.tool-btn` frame.
  final bool framedTools;

  /// The one `[data-page-primary]` region. It scrolls with [collection]:
  /// see [_StreamBody].
  final LoopFolioPrimary? folio;

  /// Hides the folio while keeping the page's shape.
  ///
  /// A page that folds its heading away — the member directory does it while
  /// the soft keyboard is up — must not do it by dropping [folio] to `null`:
  /// that switches [_StreamBody] between its two layouts, and everything
  /// below, including a focused `TextField`, is rebuilt at a new place in the
  /// element tree. The field then loses focus on the very frame the keyboard
  /// opens, which closes the keyboard, which unfolds the page, which gives the
  /// field back — a loop in which no character can be typed (R3-3). Collapsing
  /// reclaims the same space and leaves every element below it where it was.
  final bool folioCollapsed;

  /// A [LoopSegBar] or equivalent, pinned above the collection: it stays put
  /// while the folio and the rows scroll under it.
  final Widget? filters;

  /// The scrollable region (`[data-collection-region]`).
  ///
  /// It does not have to state overscroll physics: while [onRefresh] is set,
  /// the refreshable region makes always-scrollable the ambient default, so a
  /// collection shorter than the viewport still has the gesture.
  final Widget collection;
  final LoopComposer? composer;
  final bool tabPage;

  /// The page is re-reading data it already shows (`state.refreshing`).
  final bool updating;

  /// The page has nothing to show at all: it replaces the folio, the filters,
  /// the collection and the composer. See [LoopFocusPage.block].
  final Widget? block;

  /// Pull-to-refresh over the collection this page owns. The collection must
  /// be a scrolling region; a blocked page takes no gesture.
  final Future<void> Function()? onRefresh;

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
                minHeight: LoopLayout.topbarContentHeight,
                updating: updating,
                titleField: titleField,
                framedTools: framedTools,
              ),
              if (block != null)
                Expanded(child: block!)
              else ...<Widget>[
                Expanded(
                  child: _StreamBody(
                    folio: folio,
                    folioCollapsed: folioCollapsed,
                    filters: filters,
                    onRefresh: onRefresh,
                    bottom: bottom,
                    collection: collection,
                  ),
                ),
                ?composer,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The scrolling half of a [LoopStreamPage]: the folio, the filters and the
/// collection.
///
/// The folio used to stand between the topbar and the collection and never
/// move, which on a 390×2280 device left a directory of hundreds of members
/// about four rows of room: 41–47% of the screen was a heading that had
/// already been read. The heading is worth its space at the top of the list
/// and worth nothing at row 200, so it now scrolls with the rows, while the
/// filter chips stay — the one control the reader still needs after scrolling
/// is the one that changes what is being listed.
///
/// The frozen prototype lays both out in normal flow (`.folio-primary` and
/// `.segs` carry no sticky rule, and the only `position:sticky` in
/// `style-v2.css` is the desktop nav), so it settles nothing here; this is the
/// mobile reading of the same order.
class _StreamBody extends StatelessWidget {
  const _StreamBody({
    required this.folio,
    required this.folioCollapsed,
    required this.filters,
    required this.collection,
    required this.onRefresh,
    required this.bottom,
  });

  final LoopFolioPrimary? folio;

  /// The folio is hidden, but the page keeps the shape it has with one: the
  /// coordinated scroll view stays mounted, so nothing under it is rebuilt.
  final bool folioCollapsed;
  final Widget? filters;
  final Widget collection;
  final Future<void> Function()? onRefresh;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final scrolls = folio != null;
    // The folio and the rows are one gesture, and a collection only joins it
    // through the inherited controller. One that brings its own — or refuses
    // the primary one — would scroll alone and leave the heading standing,
    // which is the layout this replaced.
    assert(
      !scrolls ||
          collection is! ScrollView ||
          ((collection as ScrollView).controller == null &&
              (collection as ScrollView).primary != false),
      'A stream page with a folio scrolls both regions together: its '
      'collection may not own a controller or opt out of the primary one.',
    );
    final region = KeyedSubtree(
      key: const ValueKey<String>('loop-page-collection'),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        // A folio page hands the whole coordinated view to the gesture
        // instead: the drag at the top belongs to the header, and an
        // indicator installed under the header would never hear it.
        child: scrolls
            ? collection
            : loopRefreshable(onRefresh: onRefresh, child: collection),
      ),
    );
    final under = filters == null
        ? region
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              filters!,
              Expanded(child: region),
            ],
          );
    if (!scrolls) return under;
    // A page with a folio hands the two regions to one gesture: the header
    // takes the drag until it is gone, then the collection continues from
    // where the header stopped, so nothing is scrolled twice. A collection
    // that owns a controller stays outside that coordination, which is why
    // the folio pages leave their lists on the inherited one.
    return loopRefreshable(
      onRefresh: onRefresh,
      predicate: loopNestedScrollNotificationPredicate,
      child: NestedScrollView(
        key: const ValueKey<String>('loop-page-stream-scroll'),
        headerSliverBuilder: (context, innerScrolled) => <Widget>[
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: const ValueKey<String>('loop-page-primary'),
              child: folioCollapsed ? const SizedBox.shrink() : folio!,
            ),
          ),
        ],
        body: under,
      ),
    );
  }
}
