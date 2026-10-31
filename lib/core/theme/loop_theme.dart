import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// LOOP colour tokens — the looplabs.meme palette (decision 0210, docs/42
/// 附A §3). Ink ground, flat solid surfaces, a Yellow first accent and a
/// Purple second accent; app-shaped corners (decision 0211).
///
/// Yellow is the primary brand accent and Purple the secondary one (focus,
/// pressed edges, selected grounds). The retired Lime names ([lime],
/// [limeSoft], [limeHighlight], [mint]) are aliases of the Yellow tokens so
/// that existing call sites move with the palette; new code names [yellow].
///
/// Price movement is not a brand colour. A market rise and fall are painted
/// in [rise] / [fall] (decision 0117, v3 requirement §6.2.1), and only through
/// `LoopPriceMove` or these two tokens — never through [yellow] or [danger],
/// which keep their brand and error meanings. They do not count towards the
/// brand colours.
///
/// 黄紫是品牌强调色；行情涨跌用 rise/fall，不计入品牌色。
abstract final class LoopColors {
  /// Page ground · `--background #09090b`.
  static const Color ink = Color(0xFF09090B);

  /// Primary accent · `--primary/--yellow #ffd600`.
  static const Color yellow = Color(0xFFFFD600);

  /// Pressed / highlighted primary · `#ffe34d`.
  static const Color yellowHighlight = Color(0xFFFFE34D);

  /// A pressed primary button: Yellow deepened (decision 0211).
  static const Color yellowPressed = Color(0xFFE0BC00);

  /// Yellow at 13 % — hints, badges, soft emphasis ground.
  static const Color yellowSoft = Color(0x21FFD600);

  /// Second accent · `--purple #9c36ff`: focus, pressed edge, selection.
  static const Color purple = Color(0xFF9C36FF);

  /// Purple at 9.4 % (`#9c36ff18`) — a selected ground.
  static const Color purpleSoft = Color(0x189C36FF);

  /// The selected ground of a segment, a filter chip or a choice: solid
  /// Purple with a [onPurple] word (decision 0212, docs/42 附C §1 — the 18 %
  /// ground of decision 0211 read too pale and is retired).
  static const Color purpleSelected = purple;

  /// The word on a solid Purple ground. Pure white, because Chalk on Purple
  /// measures 4.28:1 and white clears 4.5:1 (4.79:1).
  static const Color onPurple = Color(0xFFFFFFFF);

  /// Purple at 18 % — only the ground of the 「已毕业」 stage capsule
  /// (docs/42 附C §4). Never a selected ground.
  static const Color purpleTint = Color(0x2E9C36FF);

  /// Purple at 44 % (`#9c36ff70`) — a selected or focused edge.
  static const Color purpleLine = Color(0x709C36FF);

  /// Text input ground: the raised block (S279 · decision 0237 — a field
  /// sits in a block, so it is the second level; decision 0212 had it on the
  /// card surface).
  static const Color input = plateRaised;

  /// Text input edge · `#3b3045`.
  static const Color inputLine = Color(0xFF3B3045);

  /// Foreground · `--foreground/--paper #f2f2f4`.
  static const Color chalk = Color(0xFFF2F2F4);

  /// Surface · `#111114`: the ground a sheet, a dialog or a floating bar is
  /// drawn on — a layer above the page, not a block in it. Blocks are
  /// [plate] (S279 · decision 0237).
  static const Color graphite = Color(0xFF111114);

  /// The block ground, level 1 (S279 · decision 0237, 需求方 2026-10-22 第
  /// 16 条) · `#1a1920`: every card, panel, board and grouped list stands on
  /// it. Light enough to read as a block on the Ink page and on the wall
  /// (#111114 was not), never a light grey.
  static const Color plate = Color(0xFF1A1920);

  /// The block ground, level 2 · `#26252d`: what sits inside a block — a
  /// sub-block, a field, an icon tile, a quiet button — one step above
  /// [plate].
  static const Color plateRaised = Color(0xFF26252D);

  /// Third text grey · `#8e8a98`.
  static const Color muted = Color(0xFF8E8A98);

  /// Console / sunken ground · `#0e0e12`.
  static const Color bg2 = Color(0xFF0E0E12);

  /// Panel · the block ground, level 1 ([plate]).
  static const Color panel = plate;

  /// Card · the block ground, level 1 ([plate]), solid.
  static const Color card = plate;

  /// Card 2 · the block ground, level 2 ([plateRaised]): an inset inside a
  /// card, a field, a pressed card.
  static const Color card2 = plateRaised;

  /// Line · `--border #2a292f` — a divider hairline.
  static const Color line = Color(0xFF2A292F);

  /// Line 2 · `#38333e` — a card edge.
  static const Color line2 = Color(0xFF38333E);

  /// Line 3 · `#4a4754` — an outline button's edge.
  static const Color line3 = Color(0xFF4A4754);

  /// Text 2 · `#b8b4c0` — secondary body.
  static const Color text2 = Color(0xFFB8B4C0);

  /// Text 3 · `#aeacb6` — auxiliary labels.
  static const Color text3 = Color(0xFFAEACB6);

  /// Retired Lime names, now the Yellow tokens (decision 0210).
  static const Color lime = yellow;
  static const Color limeSoft = yellowSoft;
  static const Color limeHighlight = yellowHighlight;

  /// The quiet folio's two tints, now Yellow-based.
  static const Color quietFolioGlow = Color(0x26FFD600);
  static const Color quietFolioTint = Color(0x10FFD600);

  /// The record card's two tints. Flat now: both are the card surface.
  static const Color recordCardGlow = card;
  static const Color recordCardTint = card;

  /// The primary button's glow · `0 0 17px #ffd60035`.
  static const Color primaryGlow = Color(0x35FFD600);

  /// Ink at 40 % — a contact shadow, only where a floating layer needs one.
  static const Color contactShadow = Color(0x6609090B);

  /// Ink at 62% — an unselected glyph on a light ground.
  static const Color inkMuted = Color(0x9E09090B);

  /// Ink at 72% / 62% — secondary text on Yellow or Chalk grounds.
  static const Color inkText2 = Color(0xB809090B);
  static const Color inkText3 = Color(0x9E09090B);

  /// Sheet veil · ink at 76 %.
  static const Color veil = Color(0xC209090B);

  /// Top bar ground · `#09090bf2`.
  static const Color topbar = Color(0xF209090B);

  /// The pressed-state wash every ink response paints (decision 0130).
  static const Color pressHighlight = Color(0x298E8A98);

  /// Market rise · #22C55E. Price movement only (decision 0117).
  static const Color rise = Color(0xFF22C55E);

  /// Market fall · #EF4444. Price movement only (decision 0117).
  static const Color fall = Color(0xFFEF4444);

  /// Rise at 13% — the soft ground behind a rising badge.
  static const Color riseSoft = Color(0x2122C55E);

  /// Fall at 13% — the soft ground behind a falling badge.
  static const Color fallSoft = Color(0x21EF4444);

  /// Second place · #D9B36A. Medals and illustration strokes only (decision
  /// 0122); never a brand accent, a state or a price direction.
  static const Color brass = Color(0xFFD9B36A);

  /// Third place · #B87B5A. Medals and illustration strokes only (decision
  /// 0122).
  static const Color copper = Color(0xFFB87B5A);

  /// Chrome ramp (S264, decision 0220): the MEME home's chrome edge and
  /// default project avatar — light, mid and dark steel.
  static const Color chrome1 = Color(0xFFF0F0F3);
  static const Color chrome2 = Color(0xFF9A9AA3);
  static const Color chrome3 = Color(0xFF3A3A42);

  /// The 已毕业 capsule's word on its Purple 18 % ground (S264).
  static const Color purpleInk = Color(0xFFC9A0FF);

  /// Purple at 18 % — the 已毕业 capsule's ground (S264).
  static const Color purpleCapsule = Color(0x2E9C36FF);

  // Semantic aliases retained for existing widgets.
  static const Color textSecondary = text2;
  static const Color textTertiary = text3;
  static const Color hairline = line;
  static const Color abyss = ink;
  static const Color basalt = graphite;
  static const Color elevated = card2;
  static const Color vapor = muted;
  static const Color mint = yellow;

  // Legacy categorical accents used by not-yet-migrated feature slices. New
  // surfaces must not use these and no further colour may be added to this
  // group.
  static const Color market = Color(0xFF68B9FF);
  static const Color chat = Color(0xFFF2B562);
  static const Color danger = Color(0xFFFF6B82);

  /// Danger at 13 % — a pressed danger button's ground (decision 0211).
  static const Color dangerSoft = Color(0x21FF6B82);

  /// Warning · orange `#FF9F1C`, kept apart from the Yellow accent.
  static const Color warning = Color(0xFFFF9F1C);
}

/// One initials-tile ground: a fill and the letter colour legible on it.
typedef LoopMonogramGround = ({String id, Color fill, Color ink});

/// The six grounds an initials tile (a community with no preset logo) is
/// drawn on (S241c, decision 0210).
///
/// Greys and Purple only: Yellow is reserved for calls to action, labels and
/// key figures, so an identity tile must never be Yellow or a Yellow blend.
/// Purple at full strength measures 4.28:1 against Chalk and 4.15:1 against
/// Ink — under the 4.5:1 floor — so it appears here only deepened over Ink
/// (Chalk letters) or paled toward Chalk (Ink letters). Every pair clears
/// 4.5:1; every fill stays clear of the page, card and Chalk grounds.
abstract final class LoopMonogramPalette {
  static const List<LoopMonogramGround> grounds = <LoopMonogramGround>[
    /// Chalk at 75 % over Ink.
    (id: 'chalk-dim', fill: Color(0xFFB8B8BA), ink: LoopColors.ink),
    (id: 'muted', fill: LoopColors.muted, ink: LoopColors.ink),

    /// Muted at 60 % over Ink.
    (id: 'muted-deep', fill: Color(0xFF595660), ink: LoopColors.chalk),

    /// Purple at 60 % over Ink.
    (id: 'purple-deep', fill: Color(0xFF61249D), ink: LoopColors.chalk),

    /// Purple and Chalk, half each.
    (id: 'purple-pale', fill: Color(0xFFC794FA), ink: LoopColors.ink),

    /// The strong outline grey.
    (id: 'graphite', fill: LoopColors.line3, ink: LoopColors.chalk),
  ];
}

/// The ink of the ground a widget was actually placed on.
///
/// The palette is authored for the Ink page. A shared widget that can land on
/// a light ground (Chalk or Yellow) derives its colours from the ambient
/// [DefaultTextStyle] — which the light grounds set to Ink — instead of
/// naming a fixed token. On the Ink page (a light ambient ink) every derived
/// colour is the solid token itself; on a light ground it is the ground's
/// ink at the weight the token stands for.
///
/// This only works because a light ground *declares itself*: the container
/// that paints Chalk or Yellow wraps its children in a [DefaultTextStyle] and
/// an [IconTheme] carrying that ground's ink — which is why
/// `scripts/check_harness.py` holds the declaration itself.
abstract final class LoopGround {
  /// The ground's own ink at full strength: Chalk on Ink, Ink on Chalk/Yellow.
  ///
  /// The dark page's greys ([LoopColors.text2] / [LoopColors.text3]) are
  /// solid colours since decision 0210, where they used to be Chalk at an
  /// alpha; any light ambient ink therefore reads as the page's Chalk, so a
  /// subtree set in a grey still derives from the Ink page.
  static Color inkOf(BuildContext context) {
    final ink = (DefaultTextStyle.of(context).style.color ?? LoopColors.chalk)
        .withValues(alpha: 1);
    return _onDark(ink) ? LoopColors.chalk : ink;
  }

  /// Whether the ambient ink is the dark page's light ink.
  static bool _onDark(Color ink) => ink.computeLuminance() > 0.3;

  static Color _derive(BuildContext context, Color token, double alpha) {
    final ink = inkOf(context);
    return _onDark(ink) ? token : ink.withValues(alpha: alpha);
  }

  /// [LoopColors.card2] — a filled inset or a placeholder.
  static Color fillOf(BuildContext context) =>
      _derive(context, LoopColors.card2, 0.10);

  /// [LoopColors.card] — the panel a placeholder or an inset sits on.
  static Color tintOf(BuildContext context) =>
      _derive(context, LoopColors.card, 0.06);

  /// [LoopColors.line] — a hairline edge.
  static Color hairlineOf(BuildContext context) =>
      _derive(context, LoopColors.line, 0.13);

  /// [LoopColors.line2] — a strong edge, the one a control draws around
  /// itself.
  static Color edgeOf(BuildContext context) =>
      _derive(context, LoopColors.line2, 0.22);

  /// [LoopColors.text2] — secondary copy.
  static Color secondaryOf(BuildContext context) =>
      _derive(context, LoopColors.text2, 0.68);

  /// [LoopColors.text3] — auxiliary copy and glyphs.
  static Color auxiliaryOf(BuildContext context) =>
      _derive(context, LoopColors.text3, 0.58);
}

/// Spacing semantics — docs/46 字体与间距规范 v3 §3 (decision 0229, which
/// supersedes 0212's 16 / 28). OKX-calibrated: a 20 page margin, 36 above a
/// section heading and 16 under it, rows of 72 (80 with a second line) told
/// apart by space, never by a hairline.
abstract final class LoopSpacing {
  /// 紧凑 · 8 — between two words of one line, an icon and its label.
  static const double tight = 8;

  /// 卡内 · 16 — the padding inside a card or a board.
  static const double card = 16;

  /// 组间 · 24 — a label that follows another label.
  static const double group = 24;

  /// 区块上 · 36 — above a section heading (「内盘」「前三名」「余额」).
  static const double section = 36;

  /// 页边距 · 20 — the page's left and right content line.
  static const double page = 20;

  /// 区块下 · 16 — from a section heading to its first row.
  static const double headingGap = 16;

  /// 区块上 · 36 (v3 name of [section]).
  static const double sectionTop = section;

  /// 区块下 · 16 (v3 name of [headingGap]).
  static const double sectionBottom = headingGap;

  /// 行间 / 卡间 · 12 — between two cards, two boards, two stacked blocks.
  static const double rowGap = 12;

  /// A list row with one line: at least 72 high.
  static const double rowMin = 72;

  /// A list row with a second (caption) line: at least 80 high.
  static const double rowMinWithSub = 80;

  /// From a banner (or a chrome plate) to the next block · 28.
  static const double bannerGap = 28;

  /// From a row of segment / filter capsules to the content under it · 16.
  static const double segmentGap = 16;

  // Existing aliases.
  static const double compact = tight;
  static const double regular = card;
  static const double spacious = section;

  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
}

/// Corner radii (decision 0211, which revises 0210's square corners). The
/// looplabs palette stays; the shape is an app's again: a sheet, the shell and
/// the tab bar at 20, a card at 16, a control and a button at 12, an inner
/// tile at 10, a badge or tag at 6, and [pill] / [round] for avatars, dots and
/// capsules.
abstract final class LoopRadius {
  static const double shellValue = 20;
  static const double cardValue = 16;
  static const double controlValue = 12;
  static const double innerValue = 10;

  /// The bottom tab bar (decision 0211).
  static const double tabBarValue = 20;

  /// Chat bubble tail corner — the one tighter corner of a 16 bubble.
  static const double bubbleTailValue = 6;

  static const double tileValue = 10;
  static const double buttonValue = 12;
  static const double toolValue = 12;
  static const double badgeValue = 6;
  static const double wideButtonValue = 12;

  /// A chat bubble (decision 0211).
  static const double bubbleValue = 16;

  static const BorderRadius shell = BorderRadius.all(
    Radius.circular(shellValue),
  );
  static const BorderRadius card = BorderRadius.all(Radius.circular(cardValue));
  static const BorderRadius control = BorderRadius.all(
    Radius.circular(controlValue),
  );
  static const BorderRadius inner = BorderRadius.all(
    Radius.circular(innerValue),
  );
  static const BorderRadius tabBar = BorderRadius.all(
    Radius.circular(tabBarValue),
  );
  static const Radius bubbleTail = Radius.circular(bubbleTailValue);
  static const BorderRadius tile = BorderRadius.all(Radius.circular(tileValue));
  static const BorderRadius button = BorderRadius.all(
    Radius.circular(buttonValue),
  );
  static const BorderRadius tool = BorderRadius.all(Radius.circular(toolValue));
  static const BorderRadius badge = BorderRadius.all(
    Radius.circular(badgeValue),
  );
  static const BorderRadius wideButton = BorderRadius.all(
    Radius.circular(wideButtonValue),
  );
  static const BorderRadius bubble = BorderRadius.all(
    Radius.circular(bubbleValue),
  );

  /// The top corners of a sheet.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(shellValue),
  );

  /// Fully round — avatars, dots, rings, capsules and progress ends.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
  static const BorderRadius round = pill;

  // Existing aliases.
  static const BorderRadius container = shell;
  static const BorderRadius large = shell;
  static const BorderRadius medium = control;
  static const BorderRadius small = inner;
}

/// Depth (decision 0210). The looplabs surface is flat: a 1px edge instead of
/// a drop shadow, and a coloured glow — never a dark lift — on the one
/// element a page wants to stand out. The lift names survive, empty, so call
/// sites keep compiling; the edge colours are transparent.
abstract final class LoopDepth {
  static const List<BoxShadow> liftPrimary = <BoxShadow>[];
  static const Color liftPrimaryEdge = Color(0x00000000);
  static const List<BoxShadow> liftPrimaryLight = <BoxShadow>[];
  static const Color liftPrimaryLightEdge = Color(0x00000000);
  static const List<BoxShadow> liftCard = <BoxShadow>[];
  static const Color liftCardEdge = Color(0x00000000);
  static const List<BoxShadow> liftInner = <BoxShadow>[];
  static const Color innerEdge = Color(0x00000000);
  static const List<BoxShadow> tabBar = <BoxShadow>[];
  static const Color tabBarEdge = LoopColors.line;
  static const List<BoxShadow> tabSelected = <BoxShadow>[];
  static const Color tabSelectedEdge = Color(0x00000000);

  /// `0 0 24px #9c36ff22` — the Purple glow of a focused or featured card.
  static const List<BoxShadow> glowPurple = <BoxShadow>[
    BoxShadow(color: Color(0x229C36FF), blurRadius: 24),
  ];

  /// `0 0 17px #ffd60035` — the Yellow glow of a primary action or a tag.
  static const List<BoxShadow> glowYellow = <BoxShadow>[
    BoxShadow(color: LoopColors.primaryGlow, blurRadius: 17),
  ];
}

/// z-axis baseline (chapter 4.4). Flutter stacks by widget order; these
/// values document the required ordering for overlays and tests.
abstract final class LoopZ {
  static const int content = 1;
  static const int stickyHeader = 8;
  static const int disclosure = 20;
  static const int communityPanel = 45;
  static const int tabBar = 50;
  static const int statusBar = 55;
  static const int notch = 60;
  static const int veil = 70;
  static const int sheet = 80;
  static const int toast = 90;
}

/// Touch targets and fixed control sizes (chapter 4.3 / 5.4).
abstract final class LoopTouch {
  /// Minimum hit target for every tappable element.
  static const double minimum = 44;

  /// Primary button height (48, decision 0211).
  static const double primaryButton = 48;

  /// Floating tab bar height and its minimum cell height.
  static const double tabBarHeight = 70;
  static const double tabCellMinHeight = 55;
}

/// Page layout reserves (chapter 5.3 / 5.4).
abstract final class LoopLayout {
  /// Design baseline width/height.
  static const Size designBaseline = Size(390, 844);

  /// Top-level tab pages reserve `90 + safe-area-bottom` under the bar.
  static const double tabPageBottomReserve = 90;

  /// Child pages keep `max(24, safe-area-bottom)`.
  static const double childPageBottomMinimum = 24;

  /// Tab bar side and bottom inset on mobile (`8 + safe area`).
  static const double tabBarInset = 8;

  /// Tab bar inner padding.
  static const double tabBarPadding = 7;

  /// Width from which the desktop navigation rail replaces the bar.
  static const double railBreakpoint = 900;

  /// Topbar reserve. Derived from the type ladder, not chosen: 6 top padding
  /// + one 12px eyebrow line at 1.25 + two 22px title lines at the heading
  /// band's 1.25 leading (6 + 15 + 55 = 76), kept at 80 so the reserve did
  /// not move when decision 0080 lowered the ladder — the 4px it gains is
  /// cushion, not a gap a page has to fill. A page title wraps to two lines in
  /// Chinese far more often than in English, so the second line is reserved
  /// rather than clipped.
  static const double topbarHeight = 80;

  /// Content box inside [topbarHeight], after the bar's own top padding.
  static const double topbarContentHeight = 74;
}

/// Font families (decision 0210, which supersedes decision 0080's platform
/// sans). The looplabs.meme voice is Impact for headings and Arial for body;
/// neither may be embedded (Monotype commercial licence), so LOOP bundles their
/// open stand-ins:
///
/// - **Anton** (SIL OFL 1.1) — the condensed display face of every heading
///   band. It has Latin only; a Chinese heading falls through to
///   [cjkDisplay], the bundled Noto Sans SC Bold, so the Han half of a 中英
///   heading is bold as well.
/// - **Arimo** (SIL OFL 1.1, Arial-metric compatible) — every other
///   proportional band, 400 and 700. Its Han fallback is [cjk].
/// - **IBM Plex Mono** — addresses, hashes and code, where a fixed advance is
///   the point. Figures stay proportional-family tabular figures.
abstract final class LoopFonts {
  /// The condensed display face (headings, hero figures).
  static const String display = 'Anton';

  /// The body face (body, captions, labels, figures).
  static const String body = 'Arimo';

  static const String mono = 'IBM Plex Mono';

  /// The bundled CJK family — the controlled Chinese face.
  static const String cjk = 'Noto Sans SC';

  /// Noto Sans SC Bold registered as its own one-face family, so a heading
  /// run in Anton (which asks for 400, Anton's only weight) still lands on
  /// the bold Han face rather than the regular one.
  static const String cjkDisplay = 'Noto Sans SC Display';

  /// Retained names: call sites that asked for "the system face".
  static const String system = body;
  static const String systemDisplay = display;

  /// Retired with decision 0210: a band no longer switches optical cut.
  static String familyFor(double size) => body;

  /// Fallback chain for the body bands: the bundled CJK face first, then the
  /// platform stacks for scripts it does not carry.
  static const List<String> systemFallback = <String>[
    cjk,
    'PingFang SC',
    'HarmonyOS Sans SC',
    'Source Han Sans SC',
    'Microsoft YaHei',
    'sans-serif',
  ];

  /// Fallback chain for the display bands: bold Han, then [systemFallback].
  static const List<String> displayFallback = <String>[
    cjkDisplay,
    ...systemFallback,
  ];

  /// Retained name for the body chain (Stream's theme adapter calls it).
  static const List<String> cjkFallback = systemFallback;

  /// Fallback chain for the fixed-width band. IBM Plex Mono has no Han
  /// coverage, so a Chinese run inside an address line still lands on a real
  /// CJK face instead of the system monospace.
  static const List<String> monoFallback = <String>[
    'SF Mono',
    'Menlo',
    cjk,
    'PingFang SC',
    'monospace',
  ];
}

/// Type builders. Leading is distributed evenly
/// ([TextLeadingDistribution.even]) because a mixed 中英 line resolves two
/// files with different ascent/descent ratios.
abstract final class LoopTypography {
  /// The body builder (Arimo, Noto Sans SC behind it).
  static TextStyle sans({
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
    Color color = LoopColors.chalk,
    bool tabularFigures = false,
  }) {
    return TextStyle(
      fontFamily: LoopFonts.body,
      fontFamilyFallback: LoopFonts.systemFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      // Explicit, never null: a null tracking lets Material's own 2021
      // typography leak through the merge that builds a `Text`'s style.
      letterSpacing: letterSpacing ?? 0,
      color: color,
      fontFeatures: tabularFigures
          ? const <FontFeature>[FontFeature.tabularFigures()]
          : null,
    );
  }

  /// The display builder: Anton, tracked in by [trackingEm] of its size, with
  /// bold Noto Sans SC behind it. Anton has one weight, so the weight is
  /// fixed at 400 (asking for more would only invite synthetic bolding).
  static TextStyle condensed({
    required double size,
    required double height,
    double trackingEm = 0,
    Color color = LoopColors.chalk,
  }) {
    return TextStyle(
      fontFamily: LoopFonts.display,
      fontFamilyFallback: LoopFonts.displayFallback,
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: size * trackingEm,
      color: color,
    );
  }

  /// Fixed width. Addresses, transaction hashes, contract identifiers and
  /// code — never an amount, a price or a percentage: those are band 7.
  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w500,
    double? height,
    double? letterSpacing,
    Color color = LoopColors.chalk,
  }) {
    return TextStyle(
      fontFamily: LoopFonts.mono,
      fontFamilyFallback: LoopFonts.monoFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: letterSpacing ?? 0,
      color: color,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  // ---------------------------------------------------------------------
  // The seven bands. Feature code never writes `fontSize`, `fontWeight` or
  // `fontFamily` — see `scripts/check_harness.py`.
  // ---------------------------------------------------------------------

  /// Band 1 · display — a folio heading: Arimo 700 with Noto Sans SC Bold
  /// behind it, no tracking (decision 0211). Anton is kept for the hero line
  /// and the big stat figure only ([LoopType.heroDisplay],
  /// [LoopType.statFigure]).
  static TextStyle display(double size, {Color color = LoopColors.chalk}) =>
      sans(size: size, weight: FontWeight.w700, height: 1.25, color: color);

  /// Band 2 · heading — page and sheet titles, Arimo 700 / Noto Sans SC Bold,
  /// sentence case and no tracking (decision 0211).
  static TextStyle heading(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = LoopColors.chalk,
  }) => sans(size: size, weight: weight, height: 1.3, color: color);

  /// Band 3 · title — card and row titles, Arimo 700 (`16 / w700`).
  static TextStyle title(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = LoopColors.chalk,
  }) => sans(size: size, weight: weight, height: 1.35, color: color);

  /// Band 4 · body — running prose, Arimo 400 at a 1.5 leading (0211).
  static TextStyle body(double size, {Color color = LoopColors.chalk}) =>
      sans(size: size, weight: FontWeight.w400, height: 1.5, color: color);

  /// Band 5 · caption — supporting copy, 1.5 leading.
  static TextStyle caption(double size, {Color color = LoopColors.text3}) =>
      sans(size: size, weight: FontWeight.w400, height: 1.5, color: color);

  /// Band 6 · label — controls and inline labels, 700.
  static TextStyle label(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = LoopColors.text3,
  }) => sans(size: size, weight: weight, height: 1.3, color: color);

  /// Band 6b · eyebrow / kicker — a small 700 label, sentence case and no
  /// tracking (decision 0211 retired the uppercase +0.15em kicker).
  static TextStyle eyebrow(double size, {Color color = LoopColors.text3}) =>
      sans(size: size, weight: FontWeight.w700, height: 1.3, color: color);

  /// Band 7 · figure — every number the product shows, in the body face with
  /// [FontFeature.tabularFigures]. Addresses and hashes are [code].
  static TextStyle figure(
    double size, {
    FontWeight weight = FontWeight.w700,
    double height = 1.3,
    Color color = LoopColors.chalk,
  }) => sans(
    size: size,
    weight: weight,
    height: height,
    color: color,
    tabularFigures: true,
  );

  /// Band 7b · code — the fixed-width band.
  static TextStyle code(
    double size, {
    FontWeight weight = FontWeight.w500,
    double height = 1.4,
    Color color = LoopColors.chalk,
  }) => mono(size: size, weight: weight, height: height, color: color);

  /// Restate [style] at [weight]. On an Anton step the weight is ignored —
  /// Anton has one weight, and a heavier request would only fake-bold it.
  static TextStyle withWeight(TextStyle style, FontWeight weight) =>
      style.fontFamily == LoopFonts.display
      ? style
      : style.copyWith(fontWeight: weight);
}

/// The named steps — docs/46 字体与间距规范 v3 (decision 0229, OKX-calibrated;
/// it restates 0210 / 0212's ladder one step up and drops everything under
/// 13). `lib/features/**` and `lib/widgets/**` take a step from here and
/// never a raw number.
///
/// The v3 ladder is eight steps; every older name is kept as an alias of the
/// v3 step it now means, so a call site moves with the ladder:
///
/// | v3 step | face | size / weight | height | where | older names on it |
/// | --- | --- | --- | --- | --- | --- |
/// | `plateFigure` | Anton | 40 | 1.0 | 牌面大数字（总资产、我的名次） | |
/// | `sectionIndex` / `heroFigure` | Anton | 30 | 1.0–1.1 | 区块编号 01、项目页价格 | |
/// | `title1` | Noto / Arimo 700 | 28 | 1.25 | 页标题（五个 Tab、无返回键的页） | `headingLg` `displayXl` `display` `displaySm` `stepTitle` |
/// | `title2` | 700 | 22 | 1.3 | 二级页导航栏标题、banner 标题、卡片大标题、弹层标题 | `flatTitle` `heading` |
/// | `headline` | 700 | 18 | 1.3 | 区块标题（内盘、前三名、余额） | `sectionTitle` `headingSm` |
/// | `body1` | 600 | 17 | 1.35 | 行主标题、项目名、社区名、会话名、空态标题 | `title` `titleLg` |
/// | `figure` | Arimo 600 tnum | 17 | 1.3 | 行右侧主数字（价格、数量、涨幅） | `figureMd` |
/// | `body2` | 400 | 16 | 1.5 | 正文、帖子、说明段、输入框 | `body` `bodyLg` `bodySm`(text2) `message` |
/// | `caption` | 400 | 14 | 1.45 | 副标、时间、辅助数字、胶囊文字 | `captionSm` `kicker` `eyebrow` `label` `titleSm` `figureSm` `figureXs` |
/// | `button` | 700 | 16 | 1.3 | 按钮字 | `action` |
/// | `tag` | 600 | 12 | 1.2 | 只给角标 / 未读数 / 极小标签 | |
///
/// Bigger figures keep their own steps: `keyFigure` 32, `figureXl` 28,
/// `statFigure` 28, `figureLg` 22 (an amount input), `figureBody` 16,
/// `figureCompact` 13 (a token card's narrow cell). Code (addresses,
/// hashes) is IBM Plex Mono 13. Nothing on screen is under 13 except a
/// `tag`.
abstract final class LoopType {
  /// Uppercase the Latin letters of a heading or a kicker
  /// (`text-transform: uppercase`). Han characters have no case and pass
  /// through untouched, so a Chinese title is unchanged.
  ///
  /// Decision 0211 retired the uppercase kicker: this is now the identity, so
  /// a label reads exactly as it was written.
  static String caps(String text) => text;

  // ---- v3 steps (decision 0229) -------------------------------------------

  /// title1 · 28 / 700 — a page title: the five Tabs and every page without
  /// a back control.
  static final TextStyle title1 = LoopTypography.sans(
    size: 28,
    weight: FontWeight.w700,
    height: 1.25,
  );

  /// title2 · 22 / 700 — a second-level page's bar title (beside its back
  /// control), a banner title, a card's big title, a sheet title.
  static final TextStyle title2 = LoopTypography.heading(22);

  /// headline · 18 / 700 — a section heading inside a page.
  static final TextStyle headline = LoopTypography.heading(18);

  /// body1 · 17 / 600 — the one primary line of a list row: a project, a
  /// community, a conversation, a person; a centred state's title.
  static final TextStyle body1 = LoopTypography.title(
    17,
    weight: FontWeight.w600,
  );

  /// body2 · 16 / 400 at 1.5 — prose, a post, a note, an input (OKX
  /// calibration, docs/46 §1b: their body measures 16–17).
  static final TextStyle body2 = LoopTypography.body(16);

  /// caption · 14 / 400 Text3 — a row's second line, a time, a supporting
  /// figure, a capsule's word; R5 / R10 / R20 (OKX labels measure 14).
  static final TextStyle caption = LoopTypography.sans(
    size: 14,
    weight: FontWeight.w400,
    height: 1.45,
    color: LoopColors.text3,
  );

  /// button · 16 / 700 — the word on a button.
  static final TextStyle button = LoopTypography.label(
    16,
    weight: FontWeight.w700,
    color: LoopColors.chalk,
  );

  /// tag · 12 / 600 — a corner badge, an unread count, the smallest tag. The
  /// only step under 13.
  static final TextStyle tag = LoopTypography.sans(
    size: 12,
    weight: FontWeight.w600,
    height: 1.2,
    color: LoopColors.text2,
  );

  // Band 1 · display.
  /// A hero line — the one statement on an intro page (`-0.035em`).
  static final TextStyle heroDisplay = LoopTypography.condensed(
    size: 56,
    height: 1.0,
    trackingEm: -0.035,
  );

  /// R9 folio heading on the intro / record / state archetypes — [title1].
  static final TextStyle displayXl = title1;

  /// R9 folio heading on the action archetype — [title1].
  static final TextStyle display = title1;

  /// R9 folio heading on the index archetype and every compact folio; R27
  /// the name on a person's or a community's home — [title1].
  static final TextStyle displaySm = title1;

  /// A big stat value — Arimo 700 tabular, 28 (v3: one step with [title1]).
  static final TextStyle statFigure = LoopTypography.figure(28, height: 1.15);

  /// A key figure — total assets, my rank: Arimo 700 32, Yellow at the call
  /// site (docs/42 附C §6).
  static final TextStyle keyFigure = LoopTypography.figure(32, height: 1.15);

  /// The MEME project page hero price and its big figures: the one place
  /// Anton survives (docs/42 附C §2).
  static final TextStyle heroFigure = LoopTypography.condensed(
    size: 30,
    height: 1.1,
    trackingEm: -0.025,
  );

  /// S265d (decision 0224): the one big figure on a chrome plate — 总资产
  /// and 我的名次 — Anton 40, Yellow at the call site (docs/42 §2 keeps Anton
  /// for big figures).
  static final TextStyle plateFigure = LoopTypography.condensed(
    size: 40,
    height: 1.0,
    trackingEm: 0.01,
  );

  /// S264 (decision 0220): the MEME home's section index 「01」 — Anton 30,
  /// Yellow at the call site.
  static final TextStyle sectionIndex = LoopTypography.condensed(
    size: 30,
    height: 1.0,
    trackingEm: 0.02,
  );

  /// S279 (decision 0237): the same Anton index at the headline step (18),
  /// inside a MEME home tab 「01 内盘」.
  static final TextStyle tabIndex = LoopTypography.condensed(
    size: 18,
    height: 1.0,
    trackingEm: 0.02,
  );

  /// A figure at the body2 size (16 / 600 tabular): a fact table's value, a
  /// record line's amount.
  static final TextStyle figureBody = LoopTypography.figure(
    16,
    weight: FontWeight.w600,
  );

  /// S264: the amount on the MEME home's live trade band — [figureBody].
  static final TextStyle tickerFigure = figureBody;

  // Band 2 · heading.
  /// R1c the heading of an account-opening step page — [title1].
  static final TextStyle stepTitle = title1;

  /// R1 page title of a first-level tab or a ledger page — [title1].
  static final TextStyle headingLg = title1;

  /// R1b the one-line title of a flat second-level page, beside its back
  /// control — [title2].
  static final TextStyle flatTitle = title2;

  /// R2 every sheet's title — drawn only by `LoopSheetHeading` / `LoopSheet`
  /// / `LoopSignSheet` — [title2].
  static final TextStyle heading = title2;

  /// R1d dense (chat) top bar — [headline].
  static final TextStyle headingSm = headline;

  /// R3b a section or group heading inside a page — a flat page's section
  /// title, a date header over a day of history (「9月8日」), a group head —
  /// [headline].
  static final TextStyle sectionTitle = headline;

  // Band 3 · title.
  /// The quote-row title; R31 the title of a centred state — [body1].
  static final TextStyle titleLg = body1;

  /// R4 a row title — ledger rows, flat rows and person rows alike — [body1].
  static final TextStyle title = body1;

  /// A small control word or a label over a form field: the caption size at
  /// 600, Chalk.
  static final TextStyle titleSm = LoopTypography.title(
    14,
    weight: FontWeight.w600,
  );

  // Band 4 · body.
  /// R25 the text of a text input and its placeholder — [body2].
  static final TextStyle bodyLg = body2;

  /// R18 running prose; R26 a search field's placeholder — [body2].
  static final TextStyle body = body2;

  /// A chat message: the body2 size at a chat leading (1.45), because a
  /// conversation reads line by line, not as prose (decision 0210).
  static final TextStyle message = LoopTypography.sans(
    size: 16,
    weight: FontWeight.w400,
    height: 1.45,
  );

  /// R19 the support copy under a sheet title, a note on a page: [body2] in
  /// Text2.
  static final TextStyle bodySm = LoopTypography.body(
    16,
    color: LoopColors.text2,
  );

  // Band 5 · caption.
  /// R21 one grey line of provenance, version or legal footnote — 13 (v3
  /// retired 11).
  static final TextStyle captionSm = caption;

  // Band 6 · label.
  /// The button word and the Material button slot — [button].
  static final TextStyle action = button;

  /// R14 badge, R16 seg, R17 inline text action — the caption size at 700.
  static final TextStyle label = LoopTypography.label(14);

  /// R3 the section label over a group, R3c the first line inside a card —
  /// the caption size at 700.
  static final TextStyle eyebrow = LoopTypography.eyebrow(14);

  /// R8 folio kicker, R11 folio stamp, R13 stat-grid label — 13 (v3 retired
  /// 11).
  static final TextStyle kicker = LoopTypography.eyebrow(14);

  // Band 7 · figure — tabular numbers in the body face.
  /// R22 the one hero figure on a page.
  static final TextStyle figureXl = LoopTypography.figure(28, height: 1.2);

  /// R22b the fraction of a hero figure; R24 an amount input — 22.
  static final TextStyle figureLg = LoopTypography.figure(22, height: 1.25);

  /// R23 a secondary hero figure; the quote-row value — [figure].
  static final TextStyle figureMd = LoopTypography.figure(
    17,
    weight: FontWeight.w600,
  );

  /// figure · 17 / 600 tabular — a row's one trailing figure (price,
  /// amount, change); R12 a stat-grid value.
  static final TextStyle figure = figureMd;

  /// A secondary figure: the caption size, tabular, Text2.
  static final TextStyle figureSm = LoopTypography.figure(
    14,
    weight: FontWeight.w400,
    height: 1.4,
    color: LoopColors.text2,
  );

  /// A dense cell's figure — a third of a token card, budgeted for seven
  /// characters: 13 / 700 tabular. Only for cells that narrow.
  static final TextStyle figureCompact = LoopTypography.figure(13);

  /// R7 a row's secondary figure — [figureSm] (v3 retired 11).
  static final TextStyle figureXs = figureSm;

  // Retired aliases (decision 0189).
  static final TextStyle monoTitle = figureLg;
  static final TextStyle monoStamp = figureXs;

  // Band 7b · code — the only fixed-width steps.
  /// R30 an address, a hash, a contract identifier.
  static final TextStyle code = LoopTypography.code(13);

  /// R30 the same, compact leading (v3 retired the 11 size).
  static final TextStyle codeSm = LoopTypography.code(13, height: 1.35);
}

/// Retired alias layer (decision 0189). These are [LoopType] steps under the
/// names some feature slices and the Stream chat theme still call; `lib/widgets`
/// no longer does, and every `lib/features` call is counted in G1's shrinking
/// allowlist. New code takes the [LoopType] step itself.
abstract final class LoopMono {
  /// Retired: [LoopType.figureXl].
  static final TextStyle display = LoopType.figureXl;

  /// Retired: [LoopType.figureLg].
  static final TextStyle headline = LoopType.figureLg;

  /// Retired: [LoopType.figure].
  static final TextStyle value = LoopType.figure;

  /// Retired: [LoopType.figureSm].
  static final TextStyle body = LoopType.figureSm;

  /// Retired: [LoopType.eyebrow].
  static final TextStyle label = LoopType.eyebrow;

  /// Retired: [LoopType.figureXs].
  static final TextStyle stamp = LoopType.figureXs;

  /// Retired: [LoopType.code].
  static final TextStyle address = LoopType.code;
}

abstract final class LoopTheme {
  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: LoopColors.yellow,
      onPrimary: LoopColors.ink,
      secondary: LoopColors.purple,
      onSecondary: LoopColors.chalk,
      surface: LoopColors.graphite,
      onSurface: LoopColors.chalk,
      outline: LoopColors.line,
      outlineVariant: LoopColors.line2,
      error: LoopColors.danger,
    ).copyWith(tertiary: LoopColors.purple, onTertiary: LoopColors.chalk);

    final base = ThemeData.dark(useMaterial3: true);
    // The Material slots are a view onto the seven bands; nothing here invents
    // a size. `.apply` is deliberately not used — it would overwrite the mono
    // band's family on the slots that carry figures.
    final textTheme = base.textTheme.copyWith(
      // Band 1 · display.
      displayLarge: LoopType.displayXl,
      displayMedium: LoopType.display,
      displaySmall: LoopType.displaySm,
      // Band 2 · heading.
      headlineLarge: LoopType.headingLg,
      headlineMedium: LoopType.heading,
      headlineSmall: LoopType.headingSm,
      // Band 3 · title.
      titleLarge: LoopType.titleLg,
      titleMedium: LoopType.title,
      titleSmall: LoopType.titleSm,
      // Band 4 · body. `bodyLarge` is the slot a bare `TextField` draws in,
      // so it is the input step (R25, decision 0189).
      bodyLarge: LoopType.bodyLg,
      bodyMedium: LoopType.bodySm,
      // Band 5 · caption.
      bodySmall: LoopType.caption,
      // Band 6 · label.
      labelLarge: LoopType.action,
      labelMedium: LoopType.label,
      labelSmall: LoopType.captionSm,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: LoopColors.ink,
      canvasColor: LoopColors.ink,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      // Decision 0130: an iOS-style pressed wash on both platforms, never a
      // Material ripple. Every InkWell that does not say otherwise highlights
      // while held and splashes nothing.
      splashFactory: NoSplash.splashFactory,
      highlightColor: LoopColors.pressHighlight,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: loopPageTransitionsTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: LoopColors.ink,
        foregroundColor: LoopColors.chalk,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: LoopLayout.topbarHeight,
        titleTextStyle: textTheme.headlineLarge,
      ),
      dividerTheme: const DividerThemeData(
        color: LoopColors.line,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: LoopTouch.tabBarHeight,
        elevation: 0,
        backgroundColor: LoopColors.ink,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected)
                ? LoopColors.yellow
                : LoopColors.text3,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? LoopColors.yellow
                : LoopColors.text3,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: LoopColors.ink,
        indicatorColor: Colors.transparent,
        selectedIconTheme: const IconThemeData(
          color: LoopColors.yellow,
          size: 21,
        ),
        unselectedIconTheme: const IconThemeData(
          color: LoopColors.text2,
          size: 21,
        ),
        selectedLabelTextStyle: textTheme.labelLarge,
        unselectedLabelTextStyle: LoopTypography.withWeight(
          textTheme.labelLarge!,
          FontWeight.w600,
        ).copyWith(color: LoopColors.text2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LoopColors.input,
        // R25: a field's placeholder and floating label are the input step,
        // the same size as what is typed into it (decision 0189).
        hintStyle: LoopType.bodyLg.copyWith(color: LoopColors.text3),
        labelStyle: LoopType.bodyLg.copyWith(color: LoopColors.text3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        // Decision 0211: a field is a filled ground with no edge until it
        // takes focus, when it draws 1px Purple.
        border: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.purple),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.danger),
        ),
        // UX-008 (decision 0254): every state of a field keeps the 12 corner,
        // so a field never squares off while it is disabled or focused with
        // an error.
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.danger),
        ),
        disabledBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LoopColors.yellow,
          foregroundColor: LoopColors.ink,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.primaryButton),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: LoopRadius.button),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LoopColors.chalk,
          backgroundColor: LoopColors.card2,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.minimum),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide.none,
          shape: const RoundedRectangleBorder(borderRadius: LoopRadius.button),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LoopColors.chalk,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.minimum),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: LoopColors.chalk,
          minimumSize: const Size.square(LoopTouch.minimum),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide.none,
        backgroundColor: LoopColors.card2,
        selectedColor: LoopColors.purpleSelected,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: LoopColors.onPurple,
        ),
        shape: const RoundedRectangleBorder(borderRadius: LoopRadius.pill),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      // A list tile's title stays prose (R18) now that `bodyLarge` is the
      // input step.
      listTileTheme: ListTileThemeData(
        titleTextStyle: LoopType.body,
        subtitleTextStyle: LoopType.bodySm,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LoopColors.graphite,
        modalBackgroundColor: LoopColors.graphite,
        modalBarrierColor: LoopColors.veil,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: LoopRadius.sheetTop),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: LoopColors.graphite,
        surfaceTintColor: Colors.transparent,
        barrierColor: LoopColors.veil,
        shape: RoundedRectangleBorder(borderRadius: LoopRadius.shell),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: LoopType.body,
        behavior: SnackBarBehavior.floating,
        backgroundColor: LoopColors.card2,
        shape: const RoundedRectangleBorder(borderRadius: LoopRadius.control),
      ),
      focusColor: LoopColors.purpleSoft,
    );
  }
}

/// The push transition every LOOP detail page takes.
///
/// Decision 0085. Chapter 7 asked for "slide in from the right with a fade",
/// and until this build LOOP answered it with one hand-written builder
/// (`LoopPushTransitionsBuilder`) installed on all six platforms. That builder
/// drew the right picture and removed the gesture: on iOS the edge-swipe-back
/// is not a separate feature of the navigator, it lives *inside*
/// [CupertinoPageTransitionsBuilder] — `CupertinoRouteTransitionMixin
/// .buildPageTransitions` is what wraps the page in the back-gesture
/// detector. Replace the builder and the whole right edge of every detail page
/// goes dead. Android's own back animation (predictive back on U and above)
/// was replaced the same way.
///
/// So the transition is the platform's, not ours:
///
/// - **iOS / macOS** — [CupertinoPageTransitionsBuilder]: the native parallax,
///   and with it the edge-swipe-back that a phone user reaches for first.
/// - **Android and the rest** — [PredictiveBackPageTransitionsBuilder]:
///   animates with the system back gesture on Android U and above, and falls
///   back to [FadeForwardsPageTransitionsBuilder] (a horizontal slide with a
///   fade — chapter 7's own description) everywhere else.
///
/// Reduced motion needs no branch here and must not have one. A branch that
/// returns the bare `child` would drop the gesture detector with the
/// animation, and it is not needed: [AnimationController] already reads the
/// platform's own "disable animations" flag and runs every route controller at
/// 0.05× its duration, so a 500ms Cupertino push takes 25ms and the swipe
/// still works. LOOP's own reduced-motion branches stay where they belong —
/// the tab-bar indicator and `LoopTabPage`'s peer fade, neither of which is a
/// route gesture.
const PageTransitionsTheme loopPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.fuchsia: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.linux: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: PredictiveBackPageTransitionsBuilder(),
  },
);

extension LoopTextStyles on BuildContext {
  /// Retired alias for [LoopType.figure] (decision 0189).
  TextStyle get dataStyle => LoopType.figure;

  TextTheme get loopText => Theme.of(this).textTheme;
}
