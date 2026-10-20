import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// LOOP colour tokens — the looplabs.meme palette (decision 0210, docs/42
/// 附A §3). Ink ground, flat solid surfaces, a Yellow first accent and a
/// Purple second accent; every corner square.
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

  /// Yellow at 13 % — hints, badges, soft emphasis ground.
  static const Color yellowSoft = Color(0x21FFD600);

  /// Second accent · `--purple #9c36ff`: focus, pressed edge, selection.
  static const Color purple = Color(0xFF9C36FF);

  /// Purple at 9.4 % (`#9c36ff18`) — a selected ground.
  static const Color purpleSoft = Color(0x189C36FF);

  /// Purple at 44 % (`#9c36ff70`) — a selected or focused edge.
  static const Color purpleLine = Color(0x709C36FF);

  /// Text input ground · `#16111c`.
  static const Color input = Color(0xFF16111C);

  /// Text input edge · `#3b3045`.
  static const Color inputLine = Color(0xFF3B3045);

  /// Foreground · `--foreground/--paper #f2f2f4`.
  static const Color chalk = Color(0xFFF2F2F4);

  /// Card / surface · `--card #111114`.
  static const Color graphite = Color(0xFF111114);

  /// Third text grey · `#8e8a98`.
  static const Color muted = Color(0xFF8E8A98);

  /// Console / sunken ground · `#0e0e12`.
  static const Color bg2 = Color(0xFF0E0E12);

  /// Panel · the card surface.
  static const Color panel = graphite;

  /// Card · `#111114`, solid. It no longer tints the ground it sits on.
  static const Color card = graphite;

  /// Card 2 · a stronger inset or a pressed card (`#1c1b22`).
  static const Color card2 = Color(0xFF1C1B22);

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
  static const Color recordCardGlow = graphite;
  static const Color recordCardTint = graphite;

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

/// Spacing semantics (docs/42 附A §4, decision 0210).
abstract final class LoopSpacing {
  /// 紧凑 · 8
  static const double tight = 8;

  /// 卡内 · 20
  static const double card = 20;

  /// 组间 · 22
  static const double group = 22;

  /// 章节间 · 40
  static const double section = 40;

  /// 页面左右内容基线 · 20
  static const double page = 20;

  /// 标题到正文 · 18
  static const double headingGap = 18;

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

/// Corner radii (decision 0210): every surface corner is square. The step
/// names survive so that call sites keep their meaning, but each is 0. Only
/// [pill] / [round] is round, and only for an avatar, a dot, a ring or a
/// progress end — never a card, a button, a field or a tag.
abstract final class LoopRadius {
  static const double shellValue = 0;
  static const double cardValue = 0;
  static const double controlValue = 0;
  static const double innerValue = 0;

  /// The tab bar: square, like everything else (decision 0210).
  static const double tabBarValue = 0;

  /// Chat bubble tail corner — square like the other three.
  static const double bubbleTailValue = 0;

  static const double tileValue = 0;
  static const double buttonValue = 0;
  static const double toolValue = 0;
  static const double badgeValue = 0;
  static const double wideButtonValue = 0;

  static const BorderRadius shell = BorderRadius.zero;
  static const BorderRadius card = BorderRadius.zero;
  static const BorderRadius control = BorderRadius.zero;
  static const BorderRadius inner = BorderRadius.zero;
  static const BorderRadius tabBar = BorderRadius.zero;
  static const Radius bubbleTail = Radius.zero;
  static const BorderRadius tile = BorderRadius.zero;
  static const BorderRadius button = BorderRadius.zero;
  static const BorderRadius tool = BorderRadius.zero;
  static const BorderRadius badge = BorderRadius.zero;
  static const BorderRadius wideButton = BorderRadius.zero;

  /// Fully round — avatars, dots, rings and progress ends only.
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

  /// Primary button height (`min-height 52`, decision 0210).
  static const double primaryButton = 52;

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

  /// Band 1 · display — Anton, tracked -0.02em (`--heading-font`).
  static TextStyle display(double size, {Color color = LoopColors.chalk}) =>
      condensed(size: size, height: 1.1, trackingEm: -0.02, color: color);

  /// Band 2 · heading — Anton at page-title sizes, tracked -0.01em. The
  /// weight argument survives for call sites; Anton has only one.
  static TextStyle heading(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = LoopColors.chalk,
  }) => condensed(size: size, height: 1.15, trackingEm: -0.01, color: color);

  /// Band 3 · title — card and row titles, Arimo 700 (`16 / w700`).
  static TextStyle title(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = LoopColors.chalk,
  }) => sans(size: size, weight: weight, height: 1.35, color: color);

  /// Band 4 · body — running prose, Arimo 400 at a 1.7 leading.
  static TextStyle body(double size, {Color color = LoopColors.chalk}) =>
      sans(size: size, weight: FontWeight.w400, height: 1.7, color: color);

  /// Band 5 · caption — supporting copy, 1.6 leading.
  static TextStyle caption(double size, {Color color = LoopColors.text3}) =>
      sans(size: size, weight: FontWeight.w400, height: 1.6, color: color);

  /// Band 6 · label — controls and inline labels, 700.
  static TextStyle label(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = LoopColors.text3,
  }) => sans(size: size, weight: weight, height: 1.3, color: color);

  /// Band 6b · eyebrow / kicker — 800, tracked +0.15em, uppercased by the
  /// widget that draws it (`LoopType.caps`).
  static TextStyle eyebrow(double size, {Color color = LoopColors.text3}) =>
      sans(
        size: size,
        weight: FontWeight.w800,
        height: 1.3,
        letterSpacing: size * 0.15,
        color: color,
      );

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

/// The named steps of the seven bands (decision 0210 restates decision
/// 0189's ladder in the looplabs voice; docs/42 附A §2). `lib/features/**`
/// and `lib/widgets/**` take a step from here and never a raw number.
///
/// | band | step | face | size | height | roles |
/// | --- | --- | --- | --- | --- | --- |
/// | display | `heroDisplay` | Anton | 56 | 1.0 | a hero line (intro pages) |
/// | display | `displayXl` | Anton | 36 | 1.1 | R9 folio heading (intro / record / state) |
/// | display | `display` | Anton | 32 | 1.1 | R9 folio heading (action) |
/// | display | `displaySm` | Anton | 28 | 1.1 | R9 folio heading (index), R27 profile name |
/// | display | `statFigure` | Anton | 30 | 1.1 | a big stat value |
/// | heading | `stepTitle` | Anton | 28 | 1.15 | R1c step-page title |
/// | heading | `headingLg` | Anton | 24 | 1.15 | R1 page title |
/// | heading | `flatTitle` | Anton | 22 | 1.15 | R1b flat second-level title |
/// | heading | `heading` | Anton | 22 | 1.15 | R2 sheet title |
/// | heading | `headingSm` | Anton | 18 | 1.15 | R1d dense top bar |
/// | title | `sectionTitle` | Arimo 700 | 18 | 1.35 | R3b section / date / group heading |
/// | title | `titleLg` | Arimo 700 | 16 | 1.35 | R15 wide button, R31 state title |
/// | title | `title` | Arimo 700 | 15 | 1.35 | R4 row title |
/// | title | `titleSm` | Arimo 700 | 13 | 1.35 | small control word, form label |
/// | body | `bodyLg` | Arimo 400 | 15 | 1.6 | R25 text input |
/// | body | `body` | Arimo 400 | 14 | 1.7 | R18 prose |
/// | body | `message` | Arimo 400 | 14 | 1.45 | a chat message bubble |
/// | body | `bodySm` | Arimo 400 | 13 | 1.7 | R19 sheet support copy |
/// | caption | `caption` | Arimo 400 | 12 | 1.6 | R5 row subtitle, R20 notice |
/// | caption | `captionSm` | Arimo 400 | 11 | 1.6 | R21 footnote |
/// | label | `action` | Arimo 800 | 13 | 1.3 | button word |
/// | label | `label` | Arimo 700 | 12 | 1.3 | R14 badge, R16 seg, R17 inline action |
/// | label | `eyebrow` | Arimo 800 +0.15em | 12 | 1.3 | R3 section label |
/// | label | `kicker` | Arimo 800 +0.15em | 11 | 1.3 | R8 folio kicker, R13 stat label |
/// | figure | `figureXl` | Arimo 700 tnum | 28 | 1.2 | R22 hero figure |
/// | figure | `figureLg` | Arimo 700 tnum | 20 | 1.25 | R24 amount input |
/// | figure | `figureMd` | Arimo 700 tnum | 17 | 1.3 | R23 secondary hero |
/// | figure | `figure` | Arimo 700 tnum | 13 | 1.3 | R6 row value |
/// | figure | `figureSm` | Arimo 400 tnum | 12 | 1.4 | secondary value |
/// | figure | `figureXs` | Arimo 400 tnum | 11 | 1.35 | R7 row secondary value |
/// | code | `code` | Plex Mono | 13 | 1.4 | R30 address / hash |
/// | code | `codeSm` | Plex Mono | 11 | 1.35 | R30 compact address |
abstract final class LoopType {
  /// Uppercase the Latin letters of a heading or a kicker
  /// (`text-transform: uppercase`). Han characters have no case and pass
  /// through untouched, so a Chinese title is unchanged.
  static String caps(String text) => text.toUpperCase();

  // Band 1 · display.
  /// A hero line — the one statement on an intro page (`-0.035em`).
  static final TextStyle heroDisplay = LoopTypography.condensed(
    size: 56,
    height: 1.0,
    trackingEm: -0.035,
  );

  /// R9 folio heading on the intro / record / state archetypes.
  static final TextStyle displayXl = LoopTypography.display(36);

  /// R9 folio heading on the action archetype.
  static final TextStyle display = LoopTypography.display(32);

  /// R9 folio heading on the index archetype and every compact folio; R27
  /// the name on a person's or a community's home.
  static final TextStyle displaySm = LoopTypography.display(28);

  /// A big stat value (`stat-value`, yellow at the call site, -0.025em).
  static final TextStyle statFigure = LoopTypography.condensed(
    size: 30,
    height: 1.1,
    trackingEm: -0.025,
  );

  // Band 2 · heading.
  /// R1c the heading of an account-opening step page.
  static final TextStyle stepTitle = LoopTypography.heading(28);

  /// R1 page title of a first-level tab or a ledger second-level page.
  static final TextStyle headingLg = LoopTypography.heading(24);

  /// R1b the one-line title of a flat second-level page (decision 0126).
  static final TextStyle flatTitle = LoopTypography.heading(22);

  /// R2 every sheet's title — drawn only by `LoopSheetHeading` / `LoopSheet`
  /// / `LoopSignSheet`.
  static final TextStyle heading = LoopTypography.heading(22);

  /// R1d dense (chat) top bar. Anton stays for page-level titles only.
  static final TextStyle headingSm = LoopTypography.heading(18);

  /// R3b a section or group heading inside a page — a flat page's section
  /// title, a date header over a day of history (「9月8日」), a group head.
  /// Arimo 700 with the bundled Noto Sans SC Bold behind it (S241c): Anton's
  /// narrow figures beside a bold Han run read as two faces in one word.
  static final TextStyle sectionTitle = LoopTypography.title(18);

  // Band 3 · title.
  /// The quote-row title; R15 a flat wide button's word; R31 the title of a
  /// centred state (empty / error / locked).
  static final TextStyle titleLg = LoopTypography.title(16);

  /// R4 a row title — ledger rows, flat rows and person rows alike.
  static final TextStyle title = LoopTypography.title(15);

  /// A small control word or a label over a form field.
  static final TextStyle titleSm = LoopTypography.title(13);

  // Band 4 · body.
  /// R25 the text of a text input and its placeholder.
  static final TextStyle bodyLg = LoopTypography.sans(
    size: 15,
    weight: FontWeight.w400,
    height: 1.6,
  );

  /// R18 running prose; R26 a search field's placeholder.
  static final TextStyle body = LoopTypography.body(14);

  /// A chat message: the body size at a chat leading (1.45), because a
  /// conversation reads line by line, not as prose (decision 0210).
  static final TextStyle message = LoopTypography.sans(
    size: 14,
    weight: FontWeight.w400,
    height: 1.45,
  );

  /// R19 the support copy under a sheet title; the quote-row grey line.
  static final TextStyle bodySm = LoopTypography.body(
    13,
    color: LoopColors.text2,
  );

  // Band 5 · caption.
  /// R5 a row's second line; R10 a folio caption; R20 a notice.
  static final TextStyle caption = LoopTypography.caption(12);

  /// R21 one grey line of provenance, version or legal footnote.
  static final TextStyle captionSm = LoopTypography.caption(11);

  // Band 6 · label.
  /// The button word (`13 / w800`) and the Material button slot.
  static final TextStyle action = LoopTypography.label(
    13,
    weight: FontWeight.w800,
    color: LoopColors.chalk,
  );

  /// R14 badge, R15 button, R16 segment, R17 inline text action.
  static final TextStyle label = LoopTypography.label(12);

  /// R3 the section label over a group, R3c the first line inside a card.
  static final TextStyle eyebrow = LoopTypography.eyebrow(12);

  /// R8 folio kicker, R11 folio stamp, R13 stat-grid label (`11 / w800 /
  /// +0.15em`).
  static final TextStyle kicker = LoopTypography.eyebrow(11);

  // Band 7 · figure — tabular numbers in the body face.
  /// R22 the one hero figure on a page.
  static final TextStyle figureXl = LoopTypography.figure(28, height: 1.2);

  /// R22b the fraction of a hero figure; R24 an amount input.
  static final TextStyle figureLg = LoopTypography.figure(20, height: 1.25);

  /// R23 a secondary hero figure; the quote-row value.
  static final TextStyle figureMd = LoopTypography.figure(17);

  /// R6 a row's trailing value; R12 a stat-grid value.
  static final TextStyle figure = LoopTypography.figure(13);

  /// The quote-row secondary value.
  static final TextStyle figureSm = LoopTypography.figure(
    12,
    weight: FontWeight.w400,
    height: 1.4,
    color: LoopColors.text2,
  );

  /// R7 a row's secondary value; a price move restates it at 600.
  static final TextStyle figureXs = LoopTypography.figure(
    11,
    weight: FontWeight.w400,
    height: 1.35,
    color: LoopColors.text2,
  );

  // Retired aliases (decision 0189).
  static final TextStyle monoTitle = figureLg;
  static final TextStyle monoStamp = figureXs;

  // Band 7b · code — the only fixed-width steps.
  /// R30 an address, a hash, a contract identifier.
  static final TextStyle code = LoopTypography.code(13);

  /// R30 the same at the compact size.
  static final TextStyle codeSm = LoopTypography.code(11, height: 1.35);
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
        indicatorColor: LoopColors.yellow,
        indicatorShape: const RoundedRectangleBorder(),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected)
                ? LoopColors.ink
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
        indicatorColor: LoopColors.yellow,
        indicatorShape: const RoundedRectangleBorder(),
        selectedIconTheme: const IconThemeData(color: LoopColors.ink, size: 21),
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
        border: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.inputLine),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.inputLine),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.purple),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LoopColors.yellow,
          foregroundColor: LoopColors.ink,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.primaryButton),
          padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: LoopRadius.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LoopColors.chalk,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.minimum),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: LoopColors.line3),
          shape: const RoundedRectangleBorder(borderRadius: LoopRadius.control),
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
        side: const BorderSide(color: LoopColors.line2),
        backgroundColor: LoopColors.card,
        selectedColor: LoopColors.purpleSoft,
        labelStyle: textTheme.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: LoopRadius.badge),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LoopRadius.shellValue),
          ),
          side: BorderSide(color: LoopColors.line2),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: LoopColors.graphite,
        surfaceTintColor: Colors.transparent,
        barrierColor: LoopColors.veil,
        shape: RoundedRectangleBorder(
          borderRadius: LoopRadius.shell,
          side: BorderSide(color: LoopColors.line2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LoopColors.graphite,
        contentTextStyle: LoopType.body,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: LoopRadius.control,
          side: BorderSide(color: LoopColors.line2),
        ),
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
